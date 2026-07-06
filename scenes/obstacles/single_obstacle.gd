class_name SingleObstacle
extends BaseObstacle

# Source: SingleObstacle.cpp
# Texture: muro_2b.png
# ObstacleType::Simple

func _init_obstacle(size: Vector2) -> void:
	content_size  = size
	obstacle_type = ObstacleType.SIMPLE
	_local_rects  = ObstaclePhysics.single_obstacle_local_rects(size)

func collision(vehicle: BaseVehicle) -> bool:
	return ObstaclePhysics.single_collision(
		position, content_size, _local_rects,
		vehicle.get_air_collision(),
		vehicle.get_ground_collision(),
		vehicle.player_y,
		vehicle.content_size.y
	)
