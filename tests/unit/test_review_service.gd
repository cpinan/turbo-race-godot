extends GutTest

# Tests for ReviewService graceful degradation + trigger gate.
# No native review plugin exists in CI / non-Android environments, so every
# call must be a silent no-op that never touches the store or blocks the
# game-over flow.

func test_not_android_maybe_request_review_does_not_crash() -> void:
	assert_false(OS.has_feature("android"), "pre-condition: not on Android in CI")
	ReviewService.maybe_request_review()
	assert_true(true, "maybe_request_review() is a silent no-op when not on Android")

func test_not_android_request_review_now_does_not_crash() -> void:
	ReviewService.request_review_now()
	assert_true(true, "request_review_now() is a silent no-op when not on Android")

func test_native_unavailable_on_non_android() -> void:
	assert_false(ReviewService.is_native_available(),
		"_plugin stays null when no native plugin is present")

func test_review_at_game_constant() -> void:
	assert_eq(ReviewService.REVIEW_AT_GAME, 3,
		"Review is prompted after the 3rd game")

func test_trigger_game_never_collides_with_interstitial() -> void:
	# Interstitial fires on multiples of 5; the review game must not be one,
	# so the two full-screen prompts never stack on the same game-over.
	assert_ne(ReviewService.REVIEW_AT_GAME % AdManager.INTERSTITIAL_EVERY_N_GAMES, 0,
		"REVIEW_AT_GAME must not be a multiple of INTERSTITIAL_EVERY_N_GAMES")

func test_package_name_matches_store() -> void:
	assert_eq(ReviewService.PACKAGE_NAME, "com.carlos.pinan.turborace.godot",
		"Fallback deep-link must target the published package")

func test_save_manager_exposes_review_flag_getter() -> void:
	# Read-only check — do not mutate the persistent save from a test.
	var flag: bool = SaveManager.was_review_prompted()
	assert_typeof(flag, TYPE_BOOL,
		"was_review_prompted() returns a bool the gate can read")
