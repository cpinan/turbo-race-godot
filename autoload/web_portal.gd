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

# Emitted after a portal ad closes (or is refused / errors out). `shown` is
# false when no ad played, which is the common case — never gate progress on it.
signal ad_finished(shown: bool)

const PLAY_URL: String = "https://play.google.com/store/apps/details?id=com.carlos.pinan.turborace.godot"

# Portals reject builds that ask for an ad on every game-over. Skip this many
# runs between requests.
const RUNS_BETWEEN_ADS: int = 3

var _portal: Portal = Portal.OWNED
var _is_web: bool = false
var _iface: JavaScriptObject = null

# create_callback() results must be held: the bridge does not own them and a
# collected callback fires into freed memory.
var _ad_callback: JavaScriptObject = null

var _runs_since_ad: int = 0
var _ad_in_flight: bool = false
var _gameplay_active: bool = false


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
			_ad_callback = JavaScriptBridge.create_callback(_on_js_ad_finished)

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
static func should_show_ad(runs_since_ad: int, runs_between: int) -> bool:
	return runs_since_ad >= runs_between


func request_break_ad() -> void:
	if _iface == null or _ad_in_flight:
		ad_finished.emit(false)
		return

	_runs_since_ad += 1
	if not should_show_ad(_runs_since_ad, RUNS_BETWEEN_ADS):
		ad_finished.emit(false)
		return

	_runs_since_ad = 0
	_ad_in_flight = true
	# Portals require the game silent and stopped for the duration of the ad.
	_gameplay_stop()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_iface.requestAd(_ad_callback)


func _on_js_ad_finished(args: Array) -> void:
	_ad_in_flight = false
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	var shown: bool = args.size() > 0 and bool(args[0])
	ad_finished.emit(shown)
