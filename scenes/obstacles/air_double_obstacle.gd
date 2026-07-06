class_name AirDoubleObstacle
extends BaseObstacle

# Source: AirDoubleObstacle.cpp
# Texture: obstaculo_1_c.png
# ObstacleType::Normal (default) — controls pool routing in GameLayer

func _init_obstacle(size: Vector2) -> void:
	content_size  = size
	obstacle_type = ObstacleType.NORMAL
	_local_rects  = ObstaclePhysics.air_obstacle_local_rects(size)

func collision(vehicle: BaseVehicle) -> bool:
	return ObstaclePhysics.air_collision(
		vehicle.state == BaseVehicle.ActorState.JUMP,
		vehicle.get_airborne_height(),
		_local_rects, position, content_size,
		vehicle.get_air_collision()
	)
