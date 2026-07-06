class_name WideObstacle
extends BaseObstacle

# Extension proof for Phase 4: new obstacle type added without modifying any
# Phase 2 base class. Wider, lower collision profile than SingleObstacle.
# Would use a different texture (not yet in assets — placeholder).
#
# Collision: covers 80% width, lower 25% of sprite height only.
# Player must jump to clear it (similar to DoubleObstacle but only ground-level).

const COLLISION_X_FACTOR: float = 0.1   # rect starts 10% from left
const COLLISION_W_FACTOR: float = 0.80  # 80% width
const COLLISION_Y_FACTOR: float = 0.0   # starts at bottom
const COLLISION_H_FACTOR: float = 0.25  # 25% height — low profile

func _init_obstacle(size: Vector2) -> void:
	content_size  = size
	obstacle_type = ObstacleType.JUMP   # player must jump to avoid
	_local_rects  = _build_rects(size)

static func _build_rects(size: Vector2) -> Array:
	return [Rect2(
		size.x * COLLISION_X_FACTOR,
		size.y * COLLISION_Y_FACTOR,
		size.x * COLLISION_W_FACTOR,
		size.y * COLLISION_H_FACTOR
	)]

# Uses default BaseObstacle::collision (base_collision — both rects must intersect)
