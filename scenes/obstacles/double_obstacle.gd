class_name DoubleObstacle
extends BaseObstacle

# Source: DoubleObstacle.cpp
# Texture: obstaculo_1.png (152 x 178)
# ObstacleType::Jump

func _ready() -> void:
	var tex: Texture2D = load("res://resources/assets/obstaculo_1.png")
	$Sprite2D.texture = tex
	_init_obstacle(tex.get_size())

func _init_obstacle(size: Vector2) -> void:
	content_size  = size
	obstacle_type = ObstacleType.JUMP
	_local_rects  = ObstaclePhysics.double_obstacle_local_rects(size)

# Uses default BaseObstacle::collision (base_collision — both rects)
