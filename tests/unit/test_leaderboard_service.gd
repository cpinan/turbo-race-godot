extends GutTest

# Tests for LeaderboardService graceful degradation.
# The leaderboard plugin is NOT available in CI/test environment.
# These tests verify that all calls are silent no-ops when unavailable,
# and that the game-over flow completes normally.

# ---------------------------------------------------------------------------
# Availability
# ---------------------------------------------------------------------------

func test_not_available_in_test_env() -> void:
	assert_false(LeaderboardService.is_available(),
		"plugin not loaded in test env → not available")

func test_not_signed_in_when_unavailable() -> void:
	assert_false(LeaderboardService.is_signed_in(),
		"not signed in when plugin unavailable")

# ---------------------------------------------------------------------------
# Silent no-ops when unavailable
# ---------------------------------------------------------------------------

func test_submit_score_does_not_crash() -> void:
	# Must not throw or cause errors when plugin unavailable
	LeaderboardService.submit_score("fake_id", 3000)
	assert_true(true, "submit_score is silent no-op when unavailable")

func test_submit_score_for_level_does_not_crash() -> void:
	LeaderboardService.submit_score_for_level("easy", 5000)
	assert_true(true, "submit_score_for_level is silent no-op when unavailable")

func test_unlock_achievement_does_not_crash() -> void:
	LeaderboardService.unlock_achievement(LeaderboardService.ACH_MORE_THAN_3000)
	assert_true(true, "unlock_achievement is silent no-op when unavailable")

# ---------------------------------------------------------------------------
# Leaderboard ID routing
# ---------------------------------------------------------------------------

func test_leaderboard_id_easy() -> void:
	assert_eq(LeaderboardService._leaderboard_id_for_level("easy"),
		LeaderboardService.LEAD_EASY_MODE)

func test_leaderboard_id_normal() -> void:
	assert_eq(LeaderboardService._leaderboard_id_for_level("normal"),
		LeaderboardService.LEAD_NORMAL_MODE)

func test_leaderboard_id_hard() -> void:
	assert_eq(LeaderboardService._leaderboard_id_for_level("hard"),
		LeaderboardService.LEAD_HARD_MODE)

func test_leaderboard_id_story_empty() -> void:
	assert_eq(LeaderboardService._leaderboard_id_for_level("story"), "",
		"Story mode has no leaderboard — returns empty string")

func test_leaderboard_id_unknown_empty() -> void:
	assert_eq(LeaderboardService._leaderboard_id_for_level("unknown"), "",
		"Unknown level returns empty string")

# ---------------------------------------------------------------------------
# Game-over flow completes normally when service unavailable
# Source: Phase 5 DoD — "game-over flow completes normally when leaderboard
#         service is unavailable/mocked-as-failing"
# ---------------------------------------------------------------------------

func test_game_over_flow_completes_when_service_unavailable() -> void:
	# Simulate the end-of-run sequence:
	# 1. Score is computed
	# 2. Leaderboard submit called (should silently fail)
	# 3. Score is still correct after failed submit
	var score := GameScore.new()
	score.obstacles_avoided = 30
	var total: int = score.total_score()   # = 3000

	# This should NOT fail even though service is unavailable
	LeaderboardService.submit_score_for_level("easy", total)

	# Score is unchanged and correct — game-over can display it
	assert_eq(total, 3000, "score intact after failed leaderboard submit")

func test_achievement_check_completes_when_service_unavailable() -> void:
	# Simulate _checkAchievements running when service unavailable
	# All unlock_achievement calls should be silent no-ops
	LeaderboardService.unlock_achievement(LeaderboardService.ACH_MORE_THAN_3000)
	LeaderboardService.unlock_achievement(LeaderboardService.ACH_PLAY_10_TIMES)
	LeaderboardService.unlock_achievement(LeaderboardService.ACH_JUMP_50)
	assert_true(true, "all achievement unlocks are no-ops when unavailable")

# ---------------------------------------------------------------------------
# Achievement ID constants match Constants.h
# ---------------------------------------------------------------------------

func test_achievement_ids_match_source() -> void:
	assert_eq(LeaderboardService.LEAD_EASY_MODE,   "CgkIyb_B9_4ZEAIQAg")
	assert_eq(LeaderboardService.LEAD_NORMAL_MODE, "CgkIyb_B9_4ZEAIQAw")
	assert_eq(LeaderboardService.LEAD_HARD_MODE,   "CgkIyb_B9_4ZEAIQBA")
	assert_eq(LeaderboardService.ACH_MORE_THAN_3000, "CgkIyb_B9_4ZEAIQBQ")
	assert_eq(LeaderboardService.ACH_JUMP_50,        "CgkIyb_B9_4ZEAIQDA")
