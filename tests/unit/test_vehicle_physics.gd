extends GutTest

# ---------------------------------------------------------------------------
# VehiclePhysics unit tests
# All expected values derived from BaseVehicle.cpp source.
# ---------------------------------------------------------------------------

# --- can_jump ---

func test_can_jump_on_ground() -> void:
	assert_true(VehiclePhysics.can_jump(0.0, false), "ground, not jumping → can jump")

func test_can_jump_exactly_at_threshold() -> void:
	assert_true(VehiclePhysics.can_jump(1.0, false), "airborne_height=1 → can jump")

func test_cannot_jump_when_airborne() -> void:
	assert_false(VehiclePhysics.can_jump(2.0, false), "airborne_height>1 → cannot jump")

func test_cannot_jump_when_already_jumping() -> void:
	assert_false(VehiclePhysics.can_jump(0.0, true), "already jumping → cannot jump")

func test_cannot_jump_when_airborne_and_jumping() -> void:
	assert_false(VehiclePhysics.can_jump(50.0, true), "airborne+jumping → cannot jump")

# --- jump_arc_offset ---

func test_jump_arc_zero_at_start() -> void:
	assert_almost_eq(VehiclePhysics.jump_arc_offset(0.0), 0.0, 0.001,
		"t=0 → offset=0")

func test_jump_arc_peak_at_midpoint() -> void:
	assert_almost_eq(VehiclePhysics.jump_arc_offset(0.5), VehiclePhysics.MAX_PLAYER_JUMP, 0.001,
		"t=0.5 → peak = MAX_PLAYER_JUMP = 140")

func test_jump_arc_zero_at_end() -> void:
	assert_almost_eq(VehiclePhysics.jump_arc_offset(1.0), 0.0, 0.001,
		"t=1 → offset=0")

func test_jump_arc_symmetric() -> void:
	var a: float = VehiclePhysics.jump_arc_offset(0.25)
	var b: float = VehiclePhysics.jump_arc_offset(0.75)
	assert_almost_eq(a, b, 0.001, "arc symmetric around t=0.5")

func test_jump_arc_max_constant() -> void:
	assert_almost_eq(VehiclePhysics.MAX_PLAYER_JUMP, 140.0, 0.001,
		"MAX_PLAYER_JUMP = 140")

# --- airborne_height ---

func test_airborne_height_on_ground() -> void:
	# pos_y = player_y + content_h * 0.5  (sprite center at ground-level center)
	# → airborne_height = 0
	var h: float = VehiclePhysics.airborne_height(100.0 + 32.0, 100.0, 64.0)
	assert_almost_eq(h, 0.0, 0.001, "on ground → airborne_height = 0")

func test_airborne_height_at_peak() -> void:
	# player_y=100, content_h=64, pos_y = player_y + content_h*0.5 + MAX_PLAYER_JUMP
	var pos_y: float = 100.0 + 32.0 + VehiclePhysics.MAX_PLAYER_JUMP
	var h: float = VehiclePhysics.airborne_height(pos_y, 100.0, 64.0)
	assert_almost_eq(h, VehiclePhysics.MAX_PLAYER_JUMP, 0.001, "at peak → airborne_height = 140")

# --- ground_collision_rect ---

func test_ground_rect_x_position() -> void:
	# pos_x=200, content_w=60 → bbox_min_x = 200 - 30 = 170; rect.x = 170 + 60*0.355 = 191.3
	var r: Rect2 = VehiclePhysics.ground_collision_rect(200.0, 50.0, 60.0, 40.0)
	assert_almost_eq(r.position.x, 200.0 - 60.0 * 0.5 + 60.0 * 0.355, 0.001,
		"ground rect x = bbox_min_x + w*0.355")

func test_ground_rect_y_is_player_y() -> void:
	var r: Rect2 = VehiclePhysics.ground_collision_rect(200.0, 50.0, 60.0, 40.0)
	assert_almost_eq(r.position.y, 50.0, 0.001, "ground rect y = player_y")

func test_ground_rect_width() -> void:
	var r: Rect2 = VehiclePhysics.ground_collision_rect(200.0, 50.0, 60.0, 40.0)
	assert_almost_eq(r.size.x, 60.0 * 0.34, 0.001, "ground rect width = content_w * 0.34")

func test_ground_rect_height() -> void:
	var r: Rect2 = VehiclePhysics.ground_collision_rect(200.0, 50.0, 60.0, 40.0)
	assert_almost_eq(r.size.y, 40.0 * 0.3, 0.001, "ground rect height = content_h * 0.3")

# --- air_collision_rect ---

func test_air_rect_x_same_as_ground() -> void:
	var rg: Rect2 = VehiclePhysics.ground_collision_rect(200.0, 50.0, 60.0, 40.0)
	var ra: Rect2 = VehiclePhysics.air_collision_rect(200.0, 80.0, 60.0, 40.0)
	assert_almost_eq(ra.position.x, rg.position.x, 0.001,
		"air rect x = ground rect x (same horizontal offset)")

func test_air_rect_height_uses_width() -> void:
	# height field = content_w * 0.2, NOT content_h * 0.2
	var r: Rect2 = VehiclePhysics.air_collision_rect(200.0, 80.0, 60.0, 40.0)
	assert_almost_eq(r.size.y, 60.0 * 0.2, 0.001,
		"air rect height = content_WIDTH * 0.2 (exact C++ semantics)")

func test_air_rect_y_offset() -> void:
	# y = (pos_y - content_h*0.5) + content_h*0.16
	var pos_y: float = 80.0
	var h: float = 40.0
	var r: Rect2 = VehiclePhysics.air_collision_rect(200.0, pos_y, 60.0, h)
	var expected_y: float = (pos_y - h * 0.5) + h * 0.16
	assert_almost_eq(r.position.y, expected_y, 0.001, "air rect y = bbox_min_y + h*0.16")

# --- clamp_x ---

func test_clamp_x_too_small() -> void:
	assert_almost_eq(VehiclePhysics.clamp_x(0.0, 60.0, 1024.0), 30.0, 0.001,
		"x < content_w*0.5 → clamp to content_w*0.5")

func test_clamp_x_too_large() -> void:
	assert_almost_eq(VehiclePhysics.clamp_x(900.0, 60.0, 1024.0), 1024.0 * 0.8, 0.001,
		"x > win_w*0.8 → clamp to win_w*0.8")

func test_clamp_x_in_range() -> void:
	assert_almost_eq(VehiclePhysics.clamp_x(400.0, 60.0, 1024.0), 400.0, 0.001,
		"x in range → unchanged")

# --- compute_y_limits ---

func test_y_limits_bottom() -> void:
	var limits: Dictionary = VehiclePhysics.compute_y_limits(100.0, 50.0)
	assert_almost_eq(limits["bottom"], 100.0 - 50.0 * 0.1, 0.001,
		"limit_bottom = playerStartY - wallHeight * 0.1")

func test_y_limits_top() -> void:
	var limits: Dictionary = VehiclePhysics.compute_y_limits(100.0, 50.0)
	var expected_top: float = (100.0 - 50.0 * 0.1) + 50.0 * 0.9
	assert_almost_eq(limits["top"], expected_top, 0.001,
		"limit_top = limit_bottom + wallHeight * 0.9")
