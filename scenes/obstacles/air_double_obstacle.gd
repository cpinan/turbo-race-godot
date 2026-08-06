class_name AirDoubleObstacle
extends BaseObstacle

# Source: AirDoubleObstacle.cpp
# Texture: obstaculo_1_c.png (152 x 178)
# ObstacleType::Normal — lethal only when jumping at height >= 63 units

const SHADOW_X_FACTOR: float = 0.6    # of shadow width  — C++ _shadowInitialX
const SHADOW_Y_FACTOR: float = 0.4    # of shadow height — C++ initial Y offset

var _shadow: Sprite2D    = null
var _shadow_init_x: float = 0.0

func _ready() -> void:
	var tex: Texture2D = load("res://resources/assets/obstaculo_1_c.png")
	$Sprite2D.texture = tex
	_init_obstacle(tex.get_size())
	_setup_shadow()

func _init_obstacle(size: Vector2) -> void:
	content_size  = size
	obstacle_type = ObstacleType.NORMAL
	_local_rects  = ObstaclePhysics.air_obstacle_local_rects(size)

# Ground shadow — source: AirDoubleObstacle.cpp ctor.
# C++ child coords are relative to the parent's bottom-left corner, so
#   world = (posX - w*0.5 + shadow_w*0.6,  posY - h*0.5 - shadow_h*0.4)
# which in Godot local space (relative to the node origin) is the same
# expression minus the node position.
func _setup_shadow() -> void:
	if _shadow != null:
		return
	var tex: Texture2D = load("res://resources/assets/sombra_obstaculo_1c.png")
	_shadow = Sprite2D.new()
	_shadow.texture = tex
	_shadow.scale   = Vector2(1.0, -1.0)   # counter the scene-root Y-flip
	_shadow.z_index = -1                   # C++ addChild(spriteShadow, -1)
	_shadow_init_x  = -content_size.x * 0.5 + tex.get_width() * SHADOW_X_FACTOR
	_shadow.position = Vector2(
		_shadow_init_x,
		-content_size.y * 0.5 - tex.get_height() * SHADOW_Y_FACTOR)
	add_child(_shadow)

# Source: AirDoubleObstacle::doUpdate — the shadow is scrolled a second time on
# top of the parent's movement, so it travels at 2x the obstacle's world speed.
# That drift is the fake-perspective cue that reads as "this obstacle is
# airborne"; without it a floating obstacle is indistinguishable from a ground
# one until you are already committed to a jump.
func do_update(speed_delta: float) -> void:
	super(speed_delta)
	if _shadow != null:
		_shadow.position.x -= speed_delta

# Source: AirDoubleObstacle::reset — restore shadow drift on pool reuse.
func reset() -> void:
	super()
	if _shadow != null:
		_shadow.position.x = _shadow_init_x

func collision(vehicle: BaseVehicle) -> bool:
	return ObstaclePhysics.air_collision(
		vehicle.state == BaseVehicle.ActorState.JUMP,
		vehicle.get_airborne_height(),
		_local_rects, position, content_size,
		vehicle.get_air_collision()
	)
