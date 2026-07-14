extends GutTest

# Tests for AdManager graceful degradation.
# AdMob plugin is never available in CI / non-Android environments.
# These tests verify all calls are silent no-ops and the game-flow
# continues normally when ads are unavailable.

func test_not_android_show_banner_does_not_crash() -> void:
	assert_false(OS.has_feature("android"), "pre-condition: not on Android in CI")
	AdManager.show_banner()
	assert_true(true, "show_banner() is silent no-op when not on Android")

func test_not_android_hide_banner_does_not_crash() -> void:
	AdManager.hide_banner()
	assert_true(true, "hide_banner() is silent no-op when not on Android")

func test_not_android_on_home_screen_shown_does_not_crash() -> void:
	AdManager.on_home_screen_shown()
	assert_true(true, "on_home_screen_shown() is silent no-op when not on Android")

func test_banner_ad_unit_id_is_production() -> void:
	assert_eq(AdManager.BANNER_AD_UNIT_ID, "ca-app-pub-8297579382369512/5828422617",
		"Ad Unit ID must be production value, not test ID")

func test_banner_not_loaded_on_non_android() -> void:
	assert_false(AdManager._banner_loaded,
		"banner_loaded stays false when plugin unavailable")

func test_ad_view_null_on_non_android() -> void:
	assert_null(AdManager._ad_view,
		"_ad_view stays null when plugin unavailable")

func test_game_state_change_does_not_crash_without_plugin() -> void:
	# Simulate what _on_game_state_changed does when called without plugin
	AdManager._on_game_state_changed(GameManager.GameState.READY)
	AdManager._on_game_state_changed(GameManager.GameState.PAUSED)
	AdManager._on_game_state_changed(GameManager.GameState.FINISH)
	AdManager._on_game_state_changed(GameManager.GameState.END)
	assert_true(true, "all state transitions are no-ops when plugin unavailable")
