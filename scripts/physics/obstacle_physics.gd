class_name ObstaclePhysics

# Lethal height threshold for AirDoubleObstacle.
# Source: AirDoubleObstacle::collision: y < MAX_PLAYER_JUMP * 0.45
const AIR_LETHAL_THRESHOLD: float = VehiclePhysics.MAX_PLAYER_JUMP * 0.45  # 63.0

# ---------------------------------------------------------------------------
# World-space transform
# ---------------------------------------------------------------------------

# Transform a local obstacle rect to world space.
# Source: BaseObstacle::currentCollisionArea
# Obstacle anchor = center (0.5, 0.5) in Cocos2d-x → subtract half content size.
static func world_rect(
		local: Rect2, obstacle_pos: Vector2, obstacle_size: Vector2) -> Rect2:
	var offset := Vector2(
		obstacle_pos.x - obstacle_size.x * 0.5,
		obstacle_pos.y - obstacle_size.y * 0.5
	)
	return Rect2(local.position + offset, local.size)

# ---------------------------------------------------------------------------
# Local collision rect definitions (proportional — require size at call time)
# ---------------------------------------------------------------------------

# Source: SingleObstacle constructor
static func single_obstacle_local_rects(size: Vector2) -> Array:
	return [Rect2(size.x * 0.25, size.y * 0.1, size.x * 0.6, size.y * 0.8)]

# Source: DoubleObstacle constructor
static func double_obstacle_local_rects(size: Vector2) -> Array:
	return [
		Rect2(size.x * 0.1, size.y * 0.5, size.x * 0.5, size.y * 0.5),
		Rect2(size.x * 0.3, 0.0,          size.x * 0.5, size.y * 0.5),
	]

# Source: AirDoubleObstacle constructor (staircase pattern)
static func air_obstacle_local_rects(size: Vector2) -> Array:
	return [
		Rect2(size.x * 0.05, size.y * 0.65, size.x * 0.20, size.y * 0.25),
		Rect2(size.x * 0.20, size.y * 0.50, size.x * 0.20, size.y * 0.25),
		Rect2(size.x * 0.30, size.y * 0.35, size.x * 0.20, size.y * 0.25),
		Rect2(size.x * 0.40, size.y * 0.25, size.x * 0.20, size.y * 0.25),
		Rect2(size.x * 0.50, size.y * 0.10, size.x * 0.20, size.y * 0.25),
	]

# ---------------------------------------------------------------------------
# Collision checks
# ---------------------------------------------------------------------------

# BaseObstacle::collision — true if any world rect intersects BOTH rectAir AND rectFloor.
static func base_collision(
		local_rects: Array, obstacle_pos: Vector2, obstacle_size: Vector2,
		rect_air: Rect2, rect_floor: Rect2) -> bool:
	for local in local_rects:
		var w: Rect2 = world_rect(local, obstacle_pos, obstacle_size)
		if w.intersects(rect_air) and w.intersects(rect_floor):
			return true
	return false

# SingleObstacle::collision — lane-band guard + base collision.
# Source: SingleObstacle::collision
static func single_collision(
		obstacle_pos: Vector2, obstacle_size: Vector2, local_rects: Array,
		rect_air: Rect2, rect_floor: Rect2,
		player_y: float, player_content_h: float) -> bool:
	var obstacle_bbox_min_y: float = obstacle_pos.y - obstacle_size.y * 0.5
	var top: float    = obstacle_bbox_min_y
	var bottom: float = top + obstacle_size.y * 0.37
	var y_eff: float  = player_y + player_content_h * 0.3 * 0.5
	if y_eff < top or y_eff > bottom:
		return false
	return base_collision(local_rects, obstacle_pos, obstacle_size, rect_air, rect_floor)

# AirDoubleObstacle::collision — state + height guards + air-only rect check.
# Source: AirDoubleObstacle::collision
static func air_collision(
		is_jumping: bool, airborne_h: float,
		local_rects: Array, obstacle_pos: Vector2, obstacle_size: Vector2,
		rect_air: Rect2) -> bool:
	if not is_jumping:
		return false
	if airborne_h < AIR_LETHAL_THRESHOLD:
		return false
	for local in local_rects:
		var w: Rect2 = world_rect(local, obstacle_pos, obstacle_size)
		if w.intersects(rect_air):
			return true
	return false

# ---------------------------------------------------------------------------
# Scoring predicate
# ---------------------------------------------------------------------------

# Returns true when an obstacle has just passed the player (score event).
# Source: GameLayer::_updateObstacles scoring block
static func has_passed_player(
		obstacle_pos_x: float, obstacle_content_w: float,
		player_pos_x: float) -> bool:
	return obstacle_pos_x + obstacle_content_w < player_pos_x
