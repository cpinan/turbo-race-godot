class_name VehicleFrog
extends BaseVehicle

# Source: VehicleFrog.cpp
# Animations: idle (bicho_0001/0002 at 12fps), jump (bicho_0003 at 10fps)
# Textures:   default=bicho_0001, dead=bicho_0004

# ---------------------------------------------------------------------------
# Idle animation timing
# ---------------------------------------------------------------------------
const IDLE_FPS:  float = 12.0
const JUMP_FPS:  float = 10.0

var _sprite: Sprite2D
var _anim_timer: float = 0.0
var _idle_frame: int   = 0

func _ready() -> void:
	_sprite = $Sprite2D
	if _sprite:
		content_size = _sprite.texture.get_size() if _sprite.texture else Vector2(64, 64)
		player_y = position.y - content_size.y * 0.5
	_connect_signals()

func _connect_signals() -> void:
	jumped.connect(_on_jumped)
	landed.connect(_on_landed)

func _on_jumped() -> void:
	if _sprite:
		_sprite.frame = 2   # bicho_0003 frame index (jump frame)

func _on_landed() -> void:
	if _sprite:
		_sprite.frame = 0   # return to idle

func _process(delta: float) -> void:
	if state == ActorState.IDLE:
		_anim_timer += delta
		if _anim_timer >= 1.0 / IDLE_FPS:
			_anim_timer = 0.0
			_idle_frame = (_idle_frame + 1) % 2   # toggle frame 0/1
			if _sprite:
				_sprite.frame = _idle_frame
