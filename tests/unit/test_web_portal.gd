extends GutTest

# Tests for WebPortal graceful degradation and ad pacing.
#
# CI and the editor are not a browser, so `OS.has_feature("web")` is false here
# and every SDK path must be an inert no-op — same contract AdManager has on
# non-Android. The pacing rule itself is a pure static function so it can be
# tested without a browser at all.


# ---------------------------------------------------------------------------
# Off-web: everything inert
# ---------------------------------------------------------------------------

func test_not_web_in_test_environment() -> void:
	assert_false(OS.has_feature("web"), "pre-condition: tests do not run in a browser")

func test_is_web_false_off_web() -> void:
	assert_false(WebPortal.is_web(), "is_web() false when not running in a browser")

func test_portal_defaults_to_owned() -> void:
	assert_eq(WebPortal.portal_name(), "owned",
		"untagged build reports the owned-channel variant")

func test_no_sdk_interface_off_web() -> void:
	assert_null(WebPortal._iface, "_iface stays null with no browser bridge")

func test_state_changes_do_not_crash_without_sdk() -> void:
	WebPortal._on_game_state_changed(GameManager.GameState.READY)
	WebPortal._on_game_state_changed(GameManager.GameState.PAUSED)
	WebPortal._on_game_state_changed(GameManager.GameState.FINISH)
	WebPortal._on_game_state_changed(GameManager.GameState.END)
	assert_true(true, "gameplay start/stop are no-ops when no SDK is present")

func test_open_play_store_is_noop_off_web() -> void:
	# Must not launch a browser during a headless test run.
	WebPortal.open_play_store()
	assert_true(true, "open_play_store() is a no-op when the CTA is not shown")


# ---------------------------------------------------------------------------
# Play Store CTA gating
# ---------------------------------------------------------------------------

func test_cta_hidden_off_web() -> void:
	assert_false(WebPortal.show_play_cta(),
		"no store CTA on Android/desktop — the player is already in the app")

func test_play_url_matches_android_package() -> void:
	assert_string_contains(WebPortal.PLAY_URL, "com.carlos.pinan.turborace.godot",
		"CTA must deep-link to this game's own Play listing")


# ---------------------------------------------------------------------------
# Ad pacing — pure rule, no SDK needed
# ---------------------------------------------------------------------------

func test_no_ad_before_the_gap_elapses() -> void:
	assert_false(WebPortal.should_show_ad(1, 3), "run 1 of 3: too soon")
	assert_false(WebPortal.should_show_ad(2, 3), "run 2 of 3: too soon")

func test_ad_shows_once_the_gap_elapses() -> void:
	assert_true(WebPortal.should_show_ad(3, 3), "run 3 of 3: show")

func test_ad_shows_when_counter_overshoots() -> void:
	# Guards the exact-match bug class that broke the in-app review gate: a
	# counter that has run past the threshold must still open the gate.
	assert_true(WebPortal.should_show_ad(9, 3), "overshooting the gap still shows")

func test_runs_between_ads_is_conservative() -> void:
	assert_true(WebPortal.RUNS_BETWEEN_ADS >= 2,
		"an ad on every game-over is a portal QA rejection")


# ---------------------------------------------------------------------------
# request_break_ad() always answers
# ---------------------------------------------------------------------------

func test_request_break_ad_emits_false_without_sdk() -> void:
	# The caller may await this signal; a path that never emits would hang the
	# game-over screen.
	watch_signals(WebPortal)
	WebPortal.request_break_ad()
	# NOTE: this assert's 4th parameter is an emission index, not a message.
	assert_signal_emitted_with_parameters(WebPortal, "ad_finished", [false])

func test_request_break_ad_leaves_audio_unmuted_without_sdk() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	WebPortal.request_break_ad()
	assert_false(AudioServer.is_bus_mute(master),
		"the no-SDK path must not mute audio it will never unmute")


# ---------------------------------------------------------------------------
# CTA construction
#
# PlayStoreCta.attach() is unreachable in a headless run because
# show_play_cta() is false there, so the whole factory — theme overrides,
# StyleBoxFlat, signal wiring — would ship to itch.io never having executed
# once. Forcing the variant flags is the only way to exercise it off-browser.
#
# The web build exists to drive Android installs, so every screen a player can
# sit on must carry the CTA, and no portal build may carry any of them.
# ---------------------------------------------------------------------------

# scene path -> node path the CTA is expected at within that scene
const CTA_SCREENS: Dictionary = {
	"res://scenes/ui/home_screen.tscn":      "Menu/PlayStoreCTA",
	"res://scenes/ui/pause_screen.tscn":     "PlayStoreCTA",
	"res://scenes/ui/game_over_screen.tscn": "PlayStoreCTA",
}

func _set_variant(is_web: bool, portal: int) -> Array:
	var prev: Array = [WebPortal._is_web, WebPortal._portal]
	WebPortal._is_web = is_web
	WebPortal._portal = portal
	return prev

func _restore_variant(prev: Array) -> void:
	WebPortal._is_web = prev[0]
	WebPortal._portal = prev[1]

func test_cta_shown_for_owned_web_variant() -> void:
	var prev := _set_variant(true, WebPortal.Portal.OWNED)
	assert_true(WebPortal.show_play_cta(), "owned web variant shows the store CTA")
	_restore_variant(prev)

func test_cta_hidden_for_portal_variants() -> void:
	var prev := _set_variant(true, WebPortal.Portal.OWNED)
	for portal in [WebPortal.Portal.CRAZYGAMES, WebPortal.Portal.GAMEDISTRIBUTION]:
		WebPortal._portal = portal
		assert_false(WebPortal.show_play_cta(),
			"%s forbids outbound store links" % WebPortal.portal_name())
	_restore_variant(prev)

func test_cta_built_on_every_screen_for_owned_build() -> void:
	var prev := _set_variant(true, WebPortal.Portal.OWNED)
	for scene_path in CTA_SCREENS:
		var node_path: String = CTA_SCREENS[scene_path]
		var screen: CanvasLayer = load(scene_path).instantiate()
		add_child_autofree(screen)
		var cta: Button = screen.get_node_or_null(node_path)
		assert_not_null(cta, "%s builds the CTA at %s" % [scene_path, node_path])
		if cta != null:
			assert_string_contains(cta.text, "Google Play", "%s CTA names the destination" % scene_path)
			assert_true(cta.pressed.get_connections().size() > 0,
				"%s CTA is wired to a handler" % scene_path)
	_restore_variant(prev)

func test_cta_absent_on_every_screen_for_portal_build() -> void:
	var prev := _set_variant(true, WebPortal.Portal.CRAZYGAMES)
	for scene_path in CTA_SCREENS:
		var screen: CanvasLayer = load(scene_path).instantiate()
		add_child_autofree(screen)
		assert_null(screen.get_node_or_null(CTA_SCREENS[scene_path]),
			"%s must not build an outbound store link on a portal build" % scene_path)
	_restore_variant(prev)

func test_cta_absent_on_every_screen_off_web() -> void:
	# Android: the player is already in the app.
	for scene_path in CTA_SCREENS:
		var screen: CanvasLayer = load(scene_path).instantiate()
		add_child_autofree(screen)
		assert_null(screen.get_node_or_null(CTA_SCREENS[scene_path]),
			"%s must not build the CTA off-web" % scene_path)

func test_attach_returns_null_when_not_allowed() -> void:
	var host := Node.new()
	add_child_autofree(host)
	assert_null(PlayStoreCta.attach(host, Rect2(0, 0, 100, 40), "x"),
		"attach() returns null rather than an invisible button")
	assert_eq(host.get_child_count(), 0, "attach() adds no node at all when disallowed")


# ---------------------------------------------------------------------------
# CTA label glyph coverage
#
# Carton_Six.ttf is a 194-glyph display face — no arrows, no guillemets, not
# even ">". A decorative leading glyph silently renders as fallback tofu, which
# no logic test catches and which only shows up by looking at the screen. This
# asserts the labels stay inside what the font can actually draw.
# ---------------------------------------------------------------------------

func test_cta_labels_are_fully_renderable_in_the_button_font() -> void:
	var font: Font = load("res://resources/fonts/Carton_Six.ttf")
	assert_not_null(font, "CTA font loads")
	for label in [PlayStoreCta.TEXT_LONG, PlayStoreCta.TEXT_SHORT]:
		for i in label.length():
			var c: int = label.unicode_at(i)
			if c == 32:  # space is not in every cmap and needs no glyph
				continue
			assert_true(font.has_char(c),
				"%s: font has no glyph for %s (U+%04X) — it would render as tofu"
					% [label, label[i], c])
