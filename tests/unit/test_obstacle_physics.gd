extends GutTest

# ---------------------------------------------------------------------------
# ObstaclePhysics unit tests
# Expected values derived from BaseObstacle.cpp, SingleObstacle.cpp,
# AirDoubleObstacle.cpp source.
# ---------------------------------------------------------------------------

# Helpers — build player rects at a known position
func _make_rects(pos_x: float, pos_y: float, player_y: float,
		cw: float, ch: float) -> Dictionary:
	return {
		"floor": VehiclePhysics.ground_collision_rect(pos_x, player_y, cw, ch),
		"air":   VehiclePhysics.air_collision_rect(pos_x, pos_y, cw, ch),
	}

# ---------------------------------------------------------------------------
# world_rect
# ---------------------------------------------------------------------------

func test_world_rect_translation() -> void:
	# obstacle at (100, 100), size (80, 80)
	# local rect at (10, 10, 20, 20)
	# expected world: offset = (100 - 40, 100 - 40) = (60, 60)
	# world pos = (10+60, 10+60) = (70, 70)
	var local := Rect2(10, 10, 20, 20)
	var w: Rect2 = ObstaclePhysics.world_rect(
		local, Vector2(100, 100), Vector2(80, 80))
	assert_almost_eq(w.position.x, 70.0, 0.001, "world rect x = local.x + (obs_x - obs_w*0.5)")
	assert_almost_eq(w.position.y, 70.0, 0.001, "world rect y = local.y + (obs_y - obs_h*0.5)")
	assert_almost_eq(w.size.x, 20.0, 0.001, "world rect width preserved")
	assert_almost_eq(w.size.y, 20.0, 0.001, "world rect height preserved")

# ---------------------------------------------------------------------------
# base_collision
# ---------------------------------------------------------------------------

func test_base_collision_hits_both_rects() -> void:
	# Overlap scenario: a single large local rect that covers both air and floor
	var obstacle_pos  := Vector2(200, 100)
	var obstacle_size := Vector2(80, 80)
	# Local rect spans full obstacle (0,0,80,80) → world = (160, 60, 80, 80)
	var local_rects := [Rect2(0, 0, 80, 80)]
	# Place player fully inside obstacle world rect
	var rect_floor := Rect2(180, 70, 20, 10)
	var rect_air   := Rect2(180, 80, 20, 10)
	assert_true(
		ObstaclePhysics.base_collision(local_rects, obstacle_pos, obstacle_size, rect_air, rect_floor),
		"both rects overlap → collision"
	)

func test_base_collision_misses_when_only_floor_hits() -> void:
	var obstacle_pos  := Vector2(200, 100)
	var obstacle_size := Vector2(80, 80)
	var local_rects := [Rect2(0, 0, 80, 80)]
	var rect_floor := Rect2(180, 70, 20, 10)  # inside
	var rect_air   := Rect2(500, 70, 20, 10)  # far right — no overlap
	assert_false(
		ObstaclePhysics.base_collision(local_rects, obstacle_pos, obstacle_size, rect_air, rect_floor),
		"only floor overlaps → no collision"
	)

func test_base_collision_misses_when_no_x_overlap() -> void:
	var obstacle_pos  := Vector2(200, 100)
	var obstacle_size := Vector2(80, 80)
	var local_rects := [Rect2(0, 0, 80, 80)]
	var rect_floor := Rect2(500, 70, 20, 10)
	var rect_air   := Rect2(500, 80, 20, 10)
	assert_false(
		ObstaclePhysics.base_collision(local_rects, obstacle_pos, obstacle_size, rect_air, rect_floor),
		"no X overlap → no collision"
	)

# ---------------------------------------------------------------------------
# single_collision — lane band guard
# ---------------------------------------------------------------------------

func test_single_collision_player_above_band() -> void:
	# obstacle at (200, 50), size (80, 100)
	# top = 50 - 50 = 0; bottom = 0 + 37 = 37
	# player_y = 100 → y_eff = 100 + player_h*0.15
	# If y_eff > 37 → false
	var obs_pos  := Vector2(200, 50)
	var obs_size := Vector2(80, 100)
	var local_rects := ObstaclePhysics.single_obstacle_local_rects(obs_size)
	# player_y=100, player_h=64 → y_eff = 100 + 9.6 = 109.6 > 37
	var player_y: float = 100.0
	var player_h: float = 64.0
	# rects don't matter — guard fires first
	var rf := Rect2(180, 100, 20, 10)
	var ra := Rect2(180, 110, 20, 5)
	assert_false(
		ObstaclePhysics.single_collision(obs_pos, obs_size, local_rects, ra, rf, player_y, player_h),
		"player above band → false (GR-005)"
	)

func test_single_collision_player_below_band() -> void:
	# top = 0, bottom = 37; player_y = -50 → y_eff = -50 + 9.6 = -40.4 < 0
	var obs_pos  := Vector2(200, 50)
	var obs_size := Vector2(80, 100)
	var local_rects := ObstaclePhysics.single_obstacle_local_rects(obs_size)
	var rf := Rect2(180, -50, 20, 10)
	var ra := Rect2(180, -40, 20, 5)
	assert_false(
		ObstaclePhysics.single_collision(obs_pos, obs_size, local_rects, ra, rf, -50.0, 64.0),
		"player below band → false"
	)

# ---------------------------------------------------------------------------
# air_collision — state and height guards
# ---------------------------------------------------------------------------

func test_air_collision_not_jumping() -> void:
	# GR-001: player not jumping → false
	var obs_pos  := Vector2(200, 100)
	var obs_size := Vector2(80, 80)
	var local_rects := ObstaclePhysics.air_obstacle_local_rects(obs_size)
	var ra := Rect2(180, 90, 20, 10)
	assert_false(
		ObstaclePhysics.air_collision(false, 80.0, local_rects, obs_pos, obs_size, ra),
		"GR-001: not jumping → false"
	)

func test_air_collision_below_threshold() -> void:
	# GR-002: jumping but airborne_height = 62.0 < 63.0 → false
	var obs_pos  := Vector2(200, 100)
	var obs_size := Vector2(80, 80)
	var local_rects := ObstaclePhysics.air_obstacle_local_rects(obs_size)
	var ra := Rect2(180, 90, 20, 10)
	assert_false(
		ObstaclePhysics.air_collision(true, 62.0, local_rects, obs_pos, obs_size, ra),
		"GR-002: airborne_height < 63.0 → false"
	)

func test_air_collision_threshold_constant() -> void:
	# AIR_LETHAL_THRESHOLD = MAX_PLAYER_JUMP * 0.45 = 140 * 0.45 = 63.0
	assert_almost_eq(ObstaclePhysics.AIR_LETHAL_THRESHOLD, 63.0, 0.001,
		"lethal threshold = 140 * 0.45 = 63.0"
	)

func test_air_collision_above_threshold_no_x_overlap() -> void:
	# GR-006: guards pass but rects don't overlap
	var obs_pos  := Vector2(800, 100)
	var obs_size := Vector2(80, 80)
	var local_rects := ObstaclePhysics.air_obstacle_local_rects(obs_size)
	var ra := Rect2(50, 90, 20, 10)  # player rect far left, no X overlap
	assert_false(
		ObstaclePhysics.air_collision(true, 80.0, local_rects, obs_pos, obs_size, ra),
		"GR-006: guards pass but no X overlap → false"
	)

func test_air_collision_above_threshold_with_overlap() -> void:
	# jumping, airborne_height=80 >= 63, rects overlap → true
	var obs_pos  := Vector2(200, 100)
	var obs_size := Vector2(80, 80)
	# Place player air rect to overlap the first staircase rect
	# First rect world: local=(0.05*80, 0.65*80, 0.2*80, 0.25*80) = (4, 52, 16, 20)
	# world offset = (200-40, 100-40) = (160, 60)
	# world rect = (164, 112, 16, 20)
	var ra := Rect2(164, 112, 16, 20)  # exact overlap with first staircase zone
	var local_rects := ObstaclePhysics.air_obstacle_local_rects(obs_size)
	assert_true(
		ObstaclePhysics.air_collision(true, 80.0, local_rects, obs_pos, obs_size, ra),
		"jumping, above threshold, rects overlap → collision"
	)

# ---------------------------------------------------------------------------
# local rect proportions
# ---------------------------------------------------------------------------

func test_single_local_rects_count() -> void:
	var rects: Array = ObstaclePhysics.single_obstacle_local_rects(Vector2(80, 100))
	assert_eq(rects.size(), 1, "SingleObstacle has 1 local collision rect")

func test_double_local_rects_count() -> void:
	var rects: Array = ObstaclePhysics.double_obstacle_local_rects(Vector2(80, 100))
	assert_eq(rects.size(), 2, "DoubleObstacle has 2 local collision rects")

func test_air_local_rects_count() -> void:
	var rects: Array = ObstaclePhysics.air_obstacle_local_rects(Vector2(80, 100))
	assert_eq(rects.size(), 5, "AirDoubleObstacle has 5 local collision rects")

# ---------------------------------------------------------------------------
# has_passed_player
# ---------------------------------------------------------------------------

func test_has_passed_player_true() -> void:
	# obs_x + obs_w < player_x → passed
	assert_true(ObstaclePhysics.has_passed_player(100.0, 50.0, 200.0),
		"100 + 50 = 150 < 200 → passed")

func test_has_passed_player_false_not_yet() -> void:
	assert_false(ObstaclePhysics.has_passed_player(200.0, 50.0, 200.0),
		"200 + 50 = 250 > 200 → not passed")

func test_has_passed_player_exact_edge() -> void:
	# obs_x + obs_w == player_x → not passed (strict less-than)
	assert_false(ObstaclePhysics.has_passed_player(150.0, 50.0, 200.0),
		"150 + 50 == 200 → not yet passed (strict <)")
