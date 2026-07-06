extends GutTest

# Source: ScoreModel.hpp, Constants.h

func test_score_factor() -> void:
	assert_almost_eq(GameScore.K_SCORE_FACTOR, 100.0, 0.001,
		"kScoreFactor = 100.0")

func test_initial_state_zero() -> void:
	var s := GameScore.new()
	assert_eq(s.obstacles_avoided, 0)
	assert_eq(s.obstacles_jumped, 0)

func test_total_score_zero() -> void:
	var s := GameScore.new()
	assert_eq(s.total_score(), 0)

func test_total_score_formula() -> void:
	# GR-004: obstaclesAvoided=30 → score=3000
	var s := GameScore.new()
	s.obstacles_avoided = 30
	assert_eq(s.total_score(), 3000, "GR-004: 30 * 100 = 3000")

func test_total_score_100_obstacles() -> void:
	var s := GameScore.new()
	s.obstacles_avoided = 100
	assert_eq(s.total_score(), 10000)

func test_jumps_not_included_in_score() -> void:
	var s := GameScore.new()
	s.obstacles_avoided = 10
	s.obstacles_jumped  = 99
	assert_eq(s.total_score(), 1000, "obstaclesJumped does not affect totalScore")

func test_reset_clears_all() -> void:
	var s := GameScore.new()
	s.obstacles_avoided = 50
	s.obstacles_jumped  = 20
	s.reset()
	assert_eq(s.obstacles_avoided, 0)
	assert_eq(s.obstacles_jumped, 0)
	assert_eq(s.total_score(), 0)

func test_achievement_threshold_3001() -> void:
	# ACH_MORE_THAN_3000: score >= 3001
	var s := GameScore.new()
	s.obstacles_avoided = 30  # score = 3000
	assert_false(s.total_score() >= 3001, "30 obstacles → 3000, does not unlock >3000 ach")
	s.obstacles_avoided = 31  # score = 3100
	assert_true(s.total_score() >= 3001, "31 obstacles → 3100, unlocks >3000 ach")
