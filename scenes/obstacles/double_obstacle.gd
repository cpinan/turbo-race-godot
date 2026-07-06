class_name DoubleObstacle
extends BaseObstacle

# Source: DoubleObstacle.cpp
# Texture: obstaculo_1.png
# ObstacleType::Jump

func _init_obstacle(size: Vector2) -> void:
	content_size  = size
	obstacle_type = ObstacleType.JUMP
	_local_rects  = ObstaclePhysics.double_obstacle_local_rects(size)

# Uses default BaseObstacle::collision (base_collision — both rects)
