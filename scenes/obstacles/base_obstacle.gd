class_name BaseObstacle
extends Node2D

# ---------------------------------------------------------------------------
# Obstacle type — mirrors ObstacleType from GameTypes.hpp
# ---------------------------------------------------------------------------
enum ObstacleType { NORMAL = 0, JUMP = 1, SIMPLE = 2 }

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
var obstacle_type: ObstacleType  = ObstacleType.NORMAL
var content_size: Vector2        = Vector2.ZERO
var pass_player_sfx: bool        = false
var num_objects: int             = 1
var distance_objects: float      = 0.0

# Collision rects (local, set by subclass constructors).
var _local_rects: Array = []

# ---------------------------------------------------------------------------
# Pool lifecycle
# ---------------------------------------------------------------------------

func reset() -> void:
	pass_player_sfx   = false
	num_objects       = 1
	distance_objects  = 0.0

# ---------------------------------------------------------------------------
# Per-frame update
# Source: BaseObstacle::doUpdate
# ---------------------------------------------------------------------------

func do_update(speed_delta: float) -> void:
	position.x -= speed_delta

# ---------------------------------------------------------------------------
# Collision check — delegates to pure functions.
# Overridden by subclasses with custom logic.
# ---------------------------------------------------------------------------

func collision(vehicle: BaseVehicle) -> bool:
	return ObstaclePhysics.base_collision(
		_local_rects, position, content_size,
		vehicle.get_air_collision(),
		vehicle.get_ground_collision()
	)

# ---------------------------------------------------------------------------
# Scoring predicate
# ---------------------------------------------------------------------------

func has_passed(player_pos_x: float) -> bool:
	return ObstaclePhysics.has_passed_player(
		position.x, content_size.x, player_pos_x)
