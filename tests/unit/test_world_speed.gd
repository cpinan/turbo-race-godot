extends GutTest

# Source: Constants.h, GameLayer.cpp::configureGame, _updatePlayer

func test_design_constants() -> void:
	assert_almost_eq(WorldSpeed.START_WORLD_SPEED, 512.0, 0.01,
		"START_WORLD_SPEED = 1024 * 0.5 = 512")
	assert_almost_eq(WorldSpeed.MIN_DISTANCE_OBSTACLES, 1024.0 / 1.8, 0.01,
		"MIN_DISTANCE_OBSTACLES = 1024 / 1.8")
	assert_almost_eq(WorldSpeed.START_X_OBSTACLES, 1024.0 * 1.9, 0.01,
		"START_X_OBSTACLES = 1024 * 1.9")

func test_initial_speed_easy() -> void:
	assert_almost_eq(WorldSpeed.initial_speed(1.0), 512.0, 0.01,
		"Easy: 512 * 1.0 = 512")

func test_initial_speed_normal() -> void:
	assert_almost_eq(WorldSpeed.initial_speed(1.7), 512.0 * 1.7, 0.01,
		"Normal: 512 * 1.7 = 870.4")

func test_initial_speed_hard() -> void:
	assert_almost_eq(WorldSpeed.initial_speed(2.2), 512.0 * 2.2, 0.01,
		"Hard: 512 * 2.2 = 1126.4")

func test_initial_min_distance_easy() -> void:
	assert_almost_eq(WorldSpeed.initial_min_distance(2.0), (1024.0 / 1.8) * 2.0, 0.01,
		"Easy min_dist = MIN_DISTANCE * 2.0")

func test_advance_speed_increases() -> void:
	var next: float = WorldSpeed.advance(512.0, 2.0, 0.0, 1.0)
	assert_almost_eq(next, 514.0, 0.01, "speed increases by acceleration * dt")

func test_advance_speed_capped() -> void:
	var next: float = WorldSpeed.advance(1195.0, 2.0, 1200.0, 10.0)
	assert_almost_eq(next, 1200.0, 0.01, "speed capped at maxWorldSpeed")

func test_advance_speed_uncapped_when_zero() -> void:
	# maxWorldSpeed = 0 → uncapped
	var next: float = WorldSpeed.advance(2000.0, 2.0, 0.0, 1.0)
	assert_almost_eq(next, 2002.0, 0.01, "maxWorldSpeed=0 → no cap")

func test_advance_does_not_exceed_cap_by_fraction() -> void:
	var next: float = WorldSpeed.advance(1199.9, 2.0, 1200.0, 1.0)
	assert_almost_eq(next, 1200.0, 0.01, "fractional overshoot clamped to cap")

func test_lane_layout_proportions() -> void:
	var l: LaneLayout = LaneLayout.compute(200.0, 0.0)
	assert_almost_eq(l.player_start_y, 200.0 * 0.55, 0.001)
	assert_almost_eq(l.wall_height, 200.0 * 0.25, 0.001)
	assert_almost_eq(l.simple_bot_y, l.player_start_y + l.wall_height * 0.85, 0.001)
	assert_almost_eq(l.double_ground_y, l.player_start_y + l.wall_height * 0.70, 0.001)
	assert_almost_eq(l.simple_top_y, l.player_start_y + l.wall_height * 1.55, 0.001)
	assert_almost_eq(l.double_air_y, l.player_start_y + l.wall_height * 1.80, 0.001)

func test_lane_layout_with_offset() -> void:
	var l: LaneLayout = LaneLayout.compute(200.0, 30.0)
	assert_almost_eq(l.player_start_y, 200.0 * 0.55 + 30.0, 0.001,
		"playerStartY includes trackOffsetY")
