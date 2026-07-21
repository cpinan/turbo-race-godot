extends Node
# Autoload: ReviewService
# Prompts the player to rate Turbo Race at a happy moment (after their 3rd game).
# Mirrors the fire-and-forget, Android-guarded pattern used by LeaderboardService
# and AdManager — a failure must never block gameplay, and it parses cleanly in
# headless/test mode.
#
# Two tiers, best available wins:
#   1. Native In-App Review overlay (Play Core ReviewManager) via the
#      InappReviewPlugin addon (res://addons/InappReviewPlugin). In-place,
#      no app-leave. Preferred. See docs/IN_APP_REVIEW_SETUP.md.
#   2. Fallback: deep-link to the Play Store listing (market://) so a review is
#      always one tap away, including when the native singleton isn't present
#      (desktop/editor, or a debug build without Play services).
#
# Trigger policy: exactly once, ever, the first game-over on or after
# total_games_played reaches REVIEW_AT_GAME — not just an exact match, so
# players who already had 3+ games logged before this feature shipped (or any
# save-state edge case) still get prompted once, instead of the gate closing
# forever. Game 3 never coincides with the interstitial (every 5th game), so
# the two never stack for a player who hits the gate exactly on schedule.

const REVIEW_AT_GAME: int = 3
const PACKAGE_NAME: String = "com.carlos.pinan.turborace.godot"

# Singleton name the InappReviewPlugin addon registers on Android; the addon's
# own InappReview.gd node wrapper checks this via Engine.has_singleton().
const _NATIVE_SINGLETON_NAME: String = "InappReviewPlugin"

const _REVIEWER_SCRIPT_PATH: String = "res://addons/InappReviewPlugin/InappReview.gd"

var _reviewer: Node = null   # addon wrapper node, or null off Android

func _ready() -> void:
	if not OS.has_feature("android"):
		return
	# Loaded by path at runtime, not by `InappReview` class name, and only on
	# Android: the addon's InappReview.gd references its own GmpLogger helper
	# by bare class_name, which resolves only once the project's global class
	# cache is built (normal in the editor/export flow). A fresh headless CI
	# checkout never builds that cache, so touching this script off-Android
	# would break test runs — this guard keeps it untouched there entirely.
	_reviewer = (load(_REVIEWER_SCRIPT_PATH) as GDScript).new()
	add_child(_reviewer)
	_reviewer.connect("review_info_generated", _on_review_info_generated)
	_reviewer.connect("review_info_generation_failed", _on_native_review_failed)
	_reviewer.connect("review_flow_launch_failed", _on_native_review_failed)
	if is_native_available():
		print("ReviewService: using native plugin '", _NATIVE_SINGLETON_NAME, "'")
	else:
		print("ReviewService: no native review plugin — will use store deep-link fallback")

# ---------------------------------------------------------------------------
# Public API — call from the game-over flow.
# ---------------------------------------------------------------------------

# Requests a review only if the player just finished their Nth game and has
# never been prompted before. Safe no-op on every other platform/state.
func maybe_request_review() -> void:
	if not OS.has_feature("android"):
		return
	if SaveManager.was_review_prompted():
		return
	if SaveManager.get_total_games_played() < REVIEW_AT_GAME:
		return
	SaveManager.mark_review_prompted()
	_launch_review()

# Force a review flow regardless of the game-count gate — wire this to a
# "Rate us" button if you add one. Still respects nothing; always attempts.
func request_review_now() -> void:
	if not OS.has_feature("android"):
		return
	_launch_review()

func _launch_review() -> void:
	if is_native_available():
		# Async flow: generate_review_info() -> review_info_generated signal ->
		# launch_review_flow(). Failure at either step falls back to the store.
		print("ReviewService: native flow via generate_review_info()")
		_reviewer.generate_review_info()
	else:
		_open_store_listing()

func _on_review_info_generated() -> void:
	_reviewer.launch_review_flow()

func _on_native_review_failed() -> void:
	_open_store_listing()

func _open_store_listing() -> void:
	# market:// opens the Play Store app directly; https fallback for safety.
	var market: String = "market://details?id=" + PACKAGE_NAME
	var web: String = "https://play.google.com/store/apps/details?id=" + PACKAGE_NAME
	var err: int = OS.shell_open(market)
	if err != OK:
		OS.shell_open(web)
	print("ReviewService: opened store listing (fallback)")

func is_native_available() -> bool:
	return Engine.has_singleton(_NATIVE_SINGLETON_NAME)
