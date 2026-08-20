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
# _build_play_cta() is unreachable in a headless run because show_play_cta() is
# false there, so the whole function — theme overrides, StyleBoxFlat, signal
# wiring — would ship to itch.io never having executed once. Forcing the flags
# is the only way to exercise it off-browser.
# ---------------------------------------------------------------------------

func _with_owned_web_variant(body: Callable) -> void:
	var was_web: bool = WebPortal._is_web
	var was_portal: int = WebPortal._portal
	WebPortal._is_web = true
	WebPortal._portal = WebPortal.Portal.OWNED
	body.call()
	WebPortal._is_web = was_web
	WebPortal._portal = was_portal

func test_cta_shown_for_owned_web_variant() -> void:
	_with_owned_web_variant(func():
		assert_true(WebPortal.show_play_cta(), "owned web variant shows the store CTA"))

func test_cta_hidden_for_portal_variants() -> void:
	var was_web: bool = WebPortal._is_web
	var was_portal: int = WebPortal._portal
	WebPortal._is_web = true
	for portal in [WebPortal.Portal.CRAZYGAMES, WebPortal.Portal.GAMEDISTRIBUTION]:
		WebPortal._portal = portal
		assert_false(WebPortal.show_play_cta(),
			"%s forbids outbound store links" % WebPortal.portal_name())
	WebPortal._is_web = was_web
	WebPortal._portal = was_portal

func test_cta_button_builds_without_error() -> void:
	_with_owned_web_variant(func():
		var screen: GameOverScreen = load("res://scenes/ui/game_over_screen.tscn").instantiate()
		add_child_autofree(screen)
		var cta: Button = screen.get_node_or_null("PlayStoreCTA")
		assert_not_null(cta, "owned web build builds the CTA button")
		assert_string_contains(cta.text, "Google Play", "CTA names the destination")
		assert_true(cta.pressed.get_connections().size() > 0, "CTA is wired to a handler"))

func test_cta_button_absent_on_portal_build() -> void:
	var was_web: bool = WebPortal._is_web
	var was_portal: int = WebPortal._portal
	WebPortal._is_web = true
	WebPortal._portal = WebPortal.Portal.CRAZYGAMES
	var screen: GameOverScreen = load("res://scenes/ui/game_over_screen.tscn").instantiate()
	add_child_autofree(screen)
	assert_null(screen.get_node_or_null("PlayStoreCTA"),
		"portal build must not construct an outbound store link at all")
	WebPortal._is_web = was_web
	WebPortal._portal = was_portal
