extends GutTest

# ---------------------------------------------------------------------------
# Regression tests for the five parity defects found by diffing the shipped
# Godot port against Classes/models/*.cpp and Classes/ui/game/GameLayer.cpp.
# Each test fails against the 1.3.0 behaviour.
# ---------------------------------------------------------------------------

const SINGLE_SCENE: String = "res://scenes/obstacles/single_obstacle.tscn"
const AIR_SCENE:    String = "res://scenes/obstacles/air_double_obstacle.tscn"
const FROG_SCENE:   String = "res://scenes/vehicles/vehicle_frog.tscn"

# Lane values for a 400px-tall track at offset 0 — LaneLayout::compute.
const TRACK_H: float = 400.0

var _was_mute: bool = false

# do_jump() plays a SFX; leaving audio on keeps the stream alive past headless
# exit and reports as a leaked ObjectDB instance. Flip the SaveManager flag
# directly — AudioManager.set_mute() also starts/stops music, which would swap
# one live stream for another.
func before_all() -> void:
	_was_mute = SaveManager.is_mute()
	SaveManager.set_mute(true)

func after_all() -> void:
	SaveManager.set_mute(_was_mute)

func _make_frog() -> BaseVehicle:
	var frog: BaseVehicle = (load(FROG_SCENE) as PackedScene).instantiate()
	add_child_autofree(frog)
	var lane: LaneLayout = LaneLayout.compute(TRACK_H, 0.0)
	frog.set_limits(lane.player_start_y, lane.wall_height)
	var center_y: float = lane.player_start_y + lane.wall_height * 0.5
	frog.position   = Vector2(400.0, center_y)
	frog.player_y   = center_y - frog.content_size.y * 0.5
	return frog

# ---------------------------------------------------------------------------
# 1. ObstaclePool growth — an obstacle acquired past the prefill count must be
#    a fully initialised, tree-resident node.
#    Before: `return _scene.instantiate()` with no add_child → _ready() never
#    ran → content_size ZERO, _local_rects empty → invisible, never collided,
#    still scored, and poisoned the free list once recycled.
# ---------------------------------------------------------------------------

func test_pool_growth_returns_initialised_obstacle() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var pool := ObstaclePool.new()
	pool.setup(load(SINGLE_SCENE), 1, host)

	var first: BaseObstacle  = pool.acquire()
	var grown: BaseObstacle  = pool.acquire()   # past prefill → growth path

	assert_not_null(grown, "growth path returns an obstacle")
	assert_true(grown.is_inside_tree(), "grown obstacle is parented into the scene tree")
	assert_eq(grown.content_size, first.content_size,
		"grown obstacle ran _ready() so content_size matches a prefilled one")
	assert_gt(grown.get_world_rects().size(), 0,
		"grown obstacle has collision rects and can therefore kill the player")

func test_recycled_grown_obstacle_stays_usable() -> void:
	var host := Node2D.new()
	add_child_autofree(host)
	var pool := ObstaclePool.new()
	pool.setup(load(SINGLE_SCENE), 1, host)
	pool.acquire()
	var grown: BaseObstacle = pool.acquire()
	pool.recycle(grown)

	var reused: BaseObstacle = pool.acquire()
	assert_gt(reused.get_world_rects().size(), 0,
		"a grown obstacle returned to the pool is still collidable when reused")

# ---------------------------------------------------------------------------
# 2. Jump arc rides the live player_y (Cocos2d-x JumpBy is additive).
#    Before: the arc was tweened from a frozen launch Y, so a lane change made
#    mid-jump was reverted on landing and the air hitbox (position.y) stayed in
#    the old lane while the ground hitbox (player_y) tracked the new one.
# ---------------------------------------------------------------------------

func test_lane_change_during_jump_persists_after_landing() -> void:
	var frog: BaseVehicle = _make_frog()
	var start_player_y: float = frog.player_y

	frog.do_jump()
	assert_eq(frog.state, BaseVehicle.ActorState.JUMP, "jump started")

	# Move up one lane step while airborne.
	frog.advance_jump(0.1)
	frog.do_move(Vector2(0.0, 20.0), 1024.0)
	frog.advance_jump(0.1)

	assert_almost_eq(frog.player_y, start_player_y + 20.0, 0.001,
		"player_y tracks lane movement while airborne")

	# Run out the rest of the 0.6s arc.
	for _i in range(60):
		frog.advance_jump(0.02)

	assert_eq(frog.state, BaseVehicle.ActorState.IDLE, "jump finished")
	assert_almost_eq(frog.player_y, start_player_y + 20.0, 0.001,
		"lane change made mid-jump survives the landing")
	assert_almost_eq(frog.position.y, frog.player_y + frog.content_size.y * 0.5, 0.001,
		"sprite lands on the lane the player actually moved to")

func test_air_and_ground_hitboxes_stay_aligned_mid_jump() -> void:
	var frog: BaseVehicle = _make_frog()
	frog.do_jump()
	frog.advance_jump(0.15)
	frog.do_move(Vector2(0.0, 15.0), 1024.0)
	frog.advance_jump(0.05)

	var arc: float = VehiclePhysics.jump_arc_offset(0.2 / VehiclePhysics.JUMP_DURATION)
	assert_almost_eq(frog.position.y,
		frog.player_y + frog.content_size.y * 0.5 + arc, 0.001,
		"sprite Y = live player_y + half height + arc offset")
	assert_almost_eq(frog.get_airborne_height(), arc, 0.001,
		"airborne height stays equal to the arc offset after a lane change")

# ---------------------------------------------------------------------------
# 3. Vehicle collision rects match BaseVehicle.cpp / docs/SPEC.md §5 exactly.
#    Before: 0.355 inset / 0.34 width ("tuned"), a 38% narrower hitbox.
# ---------------------------------------------------------------------------

func test_ground_rect_matches_cpp_proportions() -> void:
	var r: Rect2 = VehiclePhysics.ground_collision_rect(400.0, 210.0, 175.0, 128.0)
	assert_almost_eq(r.position.x, 400.0 - 87.5 + 175.0 * 0.30, 0.001,
		"BaseVehicle::getGroundCollision x inset = width * 0.30")
	assert_almost_eq(r.size.x, 175.0 * 0.55, 0.001,
		"BaseVehicle::getGroundCollision width = contentSize.width * 0.55")

func test_air_rect_matches_cpp_proportions() -> void:
	var r: Rect2 = VehiclePhysics.air_collision_rect(400.0, 274.0, 175.0, 128.0)
	assert_almost_eq(r.position.x, 400.0 - 87.5 + 175.0 * 0.30, 0.001,
		"BaseVehicle::getAirCollision x inset = width * 0.30")
	assert_almost_eq(r.size.x, 175.0 * 0.55, 0.001,
		"BaseVehicle::getAirCollision width = contentSize.width * 0.55")

# ---------------------------------------------------------------------------
# 4. Shadows. Player shadow marks player_y — the value the ground hitbox and
#    SingleObstacle's lane-band test both key off. Air-obstacle shadow drifts
#    at 2x world speed (AirDoubleObstacle::doUpdate scrolls it a second time on
#    top of the parent's movement).
# ---------------------------------------------------------------------------

func test_player_shadow_sits_at_the_ground_lane() -> void:
	var frog: BaseVehicle = _make_frog()
	var shadow: Sprite2D = frog.get_node_or_null("Sprite2D2") as Sprite2D
	# The shadow is created in code, so find it by texture rather than name.
	for child in frog.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			if (child as Sprite2D).texture.resource_path.ends_with("shadow.png"):
				shadow = child
	assert_not_null(shadow, "vehicle has a ground shadow sprite")

	# World Y = parent position + child local offset.
	var world_y: float = frog.position.y + shadow.position.y
	assert_almost_eq(world_y, frog.player_y + frog.content_size.y * 0.05, 0.001,
		"shadow world Y = player_y + contentHeight * 0.05 (BaseVehicle::updateShadow)")

func test_player_shadow_stays_on_ground_during_jump() -> void:
	var frog: BaseVehicle = _make_frog()
	var shadow: Sprite2D = null
	for child in frog.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			if (child as Sprite2D).texture.resource_path.ends_with("shadow.png"):
				shadow = child
	var ground_y: float = frog.player_y + frog.content_size.y * 0.05

	frog.do_jump()
	frog.advance_jump(0.3)   # near the apex

	assert_gt(frog.get_airborne_height(), 100.0, "frog is high in the air")
	assert_almost_eq(frog.position.y + shadow.position.y, ground_y, 0.001,
		"shadow stays pinned to the ground lane while the sprite rises")

func test_air_obstacle_shadow_drifts_at_double_speed() -> void:
	var obs: AirDoubleObstacle = (load(AIR_SCENE) as PackedScene).instantiate()
	add_child_autofree(obs)
	obs.position = Vector2(800.0, 400.0)

	var shadow: Sprite2D = obs._shadow
	assert_not_null(shadow, "air obstacle has a shadow sprite")

	var obs_x0: float    = obs.position.x
	var shadow_x0: float = obs.position.x + shadow.position.x

	obs.do_update(10.0)

	assert_almost_eq(obs.position.x, obs_x0 - 10.0, 0.001,
		"obstacle moves at world speed")
	assert_almost_eq(obs.position.x + shadow.position.x, shadow_x0 - 20.0, 0.001,
		"shadow moves at 2x world speed (AirDoubleObstacle::doUpdate)")

func test_air_obstacle_shadow_resets_on_recycle() -> void:
	var obs: AirDoubleObstacle = (load(AIR_SCENE) as PackedScene).instantiate()
	add_child_autofree(obs)
	var initial_x: float = obs._shadow.position.x
	obs.do_update(50.0)
	obs.reset()
	assert_almost_eq(obs._shadow.position.x, initial_x, 0.001,
		"AirDoubleObstacle::reset restores the shadow offset for pool reuse")

# ---------------------------------------------------------------------------
# 5. Y limits are computed once, not twice.
#    Before: GameScene passed pre-adjusted lane values into set_limits(), which
#    re-applied the transform → playfield [201, 282] instead of [210, 300].
# ---------------------------------------------------------------------------

func test_player_y_limits_match_cpp_playfield() -> void:
	var lane: LaneLayout = LaneLayout.compute(TRACK_H, 0.0)
	var frog: BaseVehicle = _make_frog()

	# GameLayer::_createPlayer → setLimits(playerStartY - wallHeight*0.1,
	#                                      wallHeight*0.9)
	# setLimits stores bottom as-is and top = bottom + height.
	var expected_bottom: float = lane.player_start_y - lane.wall_height * 0.1
	var expected_top: float    = expected_bottom + lane.wall_height * 0.9

	# Drive the player hard against each limit and read where it settles.
	for _i in range(200):
		frog.do_move(Vector2(0.0, -20.0), 1024.0)
	assert_almost_eq(frog.player_y, expected_bottom, 0.001,
		"bottom limit = playerStartY - wallHeight * 0.1 (210 on a 400px track)")

	for _i in range(200):
		frog.do_move(Vector2(0.0, 20.0), 1024.0)
	assert_almost_eq(frog.player_y, expected_top, 0.001,
		"top limit = bottom + wallHeight * 0.9 (300 on a 400px track)")
