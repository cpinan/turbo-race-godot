extends Node

# WebPortal — web build variant detection + portal SDK bridge.
#
# Same guard pattern as AdManager / LeaderboardService / ReviewService: every
# native/platform call is behind a feature check, so on Android, desktop, and
# headless CI this autoload is inert and costs one `OS.has_feature` per state
# change.
#
# The web build ships in three flavours, selected by the export preset's
# `custom_features` (see docs/WEB_PORTALS.md §4):
#
#   (no tag)           — your own channels: itch.io, GitHub Pages, local test.
#                        Shows the "Get it on Google Play" CTA. No ads.
#   "crazygames"       — CrazyGames. CrazyGames SDK ads. CTA suppressed.
#   "gamedistribution" — GameDistribution. GD SDK ads. CTA suppressed.
#
# Portals restrict outbound links and forbid third-party ad code, which is why
# the CTA and the SDK are mutually exclusive rather than both always on.
#
# GDScript never talks to a portal SDK directly. Each shell in web/shells/
# installs a `window.TurboPortal` façade with a fixed four-method surface, and
# the portal-specific glue lives in that shell's JavaScript. When a portal
# changes its SDK, the shell changes and this file does not.

enum Portal { OWNED, CRAZYGAMES, GAMEDISTRIBUTION }

# Mute reasons. Audio is silenced while any of them is active.
const MUTE_AD: StringName = &"ad"
const MUTE_PORTAL: StringName = &"portal"

# Emitted after a portal ad closes (or is refused / errors out). `shown` is
# false when no ad played, which is the common case — never gate progress on it.
signal ad_finished(shown: bool)

const PLAY_URL: String = "https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot"

# Portals reject builds that ask for an ad on every game-over. Two gates, and
# both must pass.
#
# CrazyGames documents the midgame interval as ~3 minutes and returns an
# "adCooldown" error if asked sooner. A run-count gate alone is time-blind: this
# is an endless runner where a bad run lasts seconds, so three runs can be under
# a minute and every request would be refused.
const RUNS_BETWEEN_ADS: int = 3
const MIN_SECONDS_BETWEEN_ADS: float = 180.0

var _portal: Portal = Portal.OWNED
var _is_web: bool = false
var _iface: JavaScriptObject = null

# create_callback() results must be held: the bridge does not own them and a
# collected callback fires into freed memory.
var _ad_callback: JavaScriptObject = null

var _runs_since_ad: int = 0
var _ad_in_flight: bool = false
var _gameplay_active: bool = false

# Wall clock of the last ad that actually started, for the cooldown gate.
# Negative sentinel so the first ad is not blocked by the initial cooldown.
var _last_ad_msec: float = -MIN_SECONDS_BETWEEN_ADS * 1000.0

# Audio is silenced for more than one reason and they overlap: an ad can start
# while CrazyGames' own site chrome already has the game muted. Tracking
# reasons rather than a bool stops the end of an ad from unmuting a game the
# portal wants silent.
var _mute_reasons: Dictionary = {}

var _mute_callback: JavaScriptObject = null


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return

	if OS.has_feature("crazygames"):
		_portal = Portal.CRAZYGAMES
	elif OS.has_feature("gamedistribution"):
		_portal = Portal.GAMEDISTRIBUTION
	else:
		_portal = Portal.OWNED

	if _portal != Portal.OWNED:
		_iface = JavaScriptBridge.get_interface("TurboPortal")
		if _iface == null:
			push_warning("WebPortal: build tagged for a portal but window.TurboPortal is missing — wrong HTML shell? Ads disabled.")
		else:
			_ad_callback = JavaScriptBridge.create_callback(_on_js_ad_event)
			_mute_callback = JavaScriptBridge.create_callback(_on_js_mute_changed)
			# Registered immediately: the shell replays the current value once
			# the SDK resolves, so a game that loads already muted is silenced
			# rather than playing a burst of audio first.
			_iface.onMuteChanged(_mute_callback)

	GameManager.game_state_changed.connect(_on_game_state_changed)
	print("WebPortal: variant=", portal_name(), " sdk=", _iface != null)


# ---------------------------------------------------------------------------
# Public queries
# ---------------------------------------------------------------------------

func is_web() -> bool:
	return _is_web


func portal_name() -> String:
	match _portal:
		Portal.CRAZYGAMES:       return "crazygames"
		Portal.GAMEDISTRIBUTION: return "gamedistribution"
		_:                       return "owned"


# True only where an outbound store link is allowed: our own site, itch.io, and
# local testing. Both ad portals forbid it.
func show_play_cta() -> bool:
	return _is_web and _portal == Portal.OWNED


func open_play_store() -> void:
	if show_play_cta():
		OS.shell_open(PLAY_URL)


# ---------------------------------------------------------------------------
# Portal SDK — gameplay session signalling
#
# Both portals use these to decide when it is rude to interrupt, and to
# attribute engagement. Getting them wrong is a QA rejection, not a crash.
# ---------------------------------------------------------------------------

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.READY:
			_gameplay_start()
		GameManager.GameState.PAUSED, GameManager.GameState.FINISH, GameManager.GameState.END:
			_gameplay_stop()


func _gameplay_start() -> void:
	if _iface == null or _gameplay_active:
		return
	_gameplay_active = true
	_iface.gameplayStart()


func _gameplay_stop() -> void:
	if _iface == null or not _gameplay_active:
		return
	_gameplay_active = false
	_iface.gameplayStop()


# ---------------------------------------------------------------------------
# Portal SDK — interstitial between runs
#
# Call from the game-over flow. Emits `ad_finished` either way, including the
# no-SDK and rate-limited paths, so a caller can always await it.
# ---------------------------------------------------------------------------

# Pure so the pacing rule is unit-testable without a browser or an SDK, per
# CLAUDE.md's rule that logic lives in plain functions.
#
# Both gates must pass. The run gate stops an ad landing after a four-second
# run; the time gate is the one the portal actually enforces.
static func should_show_ad(runs_since_ad: int, runs_between: int,
		seconds_since_ad: float, min_seconds: float) -> bool:
	return runs_since_ad >= runs_between and seconds_since_ad >= min_seconds


func request_break_ad() -> void:
	if _iface == null or _ad_in_flight:
		ad_finished.emit(false)
		return

	_runs_since_ad += 1
	var since: float = (Time.get_ticks_msec() - _last_ad_msec) / 1000.0
	if not should_show_ad(_runs_since_ad, RUNS_BETWEEN_ADS, since, MIN_SECONDS_BETWEEN_ADS):
		ad_finished.emit(false)
		return

	_ad_in_flight = true
	# Audio and pause are handled in the "started" branch, not here: an ad
	# refused on cooldown never starts, and muting first would blip the sound
	# off and on for an ad that never played.
	_iface.requestAd(_ad_callback)


# The shell reports one of "started" / "finished" / "error". "started" may or
# may not arrive; exactly one of "finished"/"error" always does.
func _on_js_ad_event(args: Array) -> void:
	var event: String = String(args[0]) if args.size() > 0 else "error"
	match event:
		"started":
			# CrazyGames requires the game silent and paused for the ad's
			# duration, restored when it ends or fails.
			_last_ad_msec = Time.get_ticks_msec()
			_runs_since_ad = 0
			_gameplay_stop()
			set_mute_reason(MUTE_AD, true)
		"finished", "error":
			_ad_in_flight = false
			set_mute_reason(MUTE_AD, false)
			ad_finished.emit(event == "finished")


# ---------------------------------------------------------------------------
# Audio muting
#
# Two independent sources: an ad in progress, and the portal's own mute
# control. CrazyGames' docs say their muteAudio setting "should take priority
# over your in-game audio settings", so this is applied at the Master bus —
# above AudioManager, which only consults the player's saved preference. A
# player toggling sound on in-game therefore cannot override the portal.
# ---------------------------------------------------------------------------

func set_mute_reason(reason: StringName, active: bool) -> void:
	if active:
		_mute_reasons[reason] = true
	else:
		_mute_reasons.erase(reason)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted())


func is_muted() -> bool:
	return not _mute_reasons.is_empty()


func has_mute_reason(reason: StringName) -> bool:
	return _mute_reasons.has(reason)


func _on_js_mute_changed(args: Array) -> void:
	var muted: bool = args.size() > 0 and bool(args[0])
	set_mute_reason(MUTE_PORTAL, muted)
