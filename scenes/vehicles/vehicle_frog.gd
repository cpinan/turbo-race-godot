class_name VehicleFrog
extends BaseVehicle

# Source: VehicleFrog.cpp
# Animations: idle toggling bicho_0001/0002 at 12fps, jump = bicho_0003, dead = bicho_0004

const IDLE_FPS: float = 12.0

var _sprite: Sprite2D
var _tex_idle_0: Texture2D
var _tex_idle_1: Texture2D
var _tex_jump: Texture2D
var _tex_dead: Texture2D
var _anim_timer: float = 0.0
var _idle_frame: int   = 0

func _ready() -> void:
	_sprite      = $Sprite2D
	_tex_idle_0  = load("res://resources/assets/bicho_0001.png")
	_tex_idle_1  = load("res://resources/assets/bicho_0002.png")
	_tex_jump    = load("res://resources/assets/bicho_0003.png")
	_tex_dead    = load("res://resources/assets/bicho_0004.png")
	_sprite.texture = _tex_idle_0
	content_size    = _tex_idle_0.get_size()   # 175 x 128
	player_y        = position.y - content_size.y * 0.5
	jumped.connect(_on_jumped)
	landed.connect(_on_landed)
	died.connect(_on_died)

func _on_jumped() -> void:
	if _sprite:
		_sprite.texture = _tex_jump

func _on_landed() -> void:
	if _sprite:
		_sprite.texture = _tex_idle_0
		_idle_frame = 0

func _on_died() -> void:
	state = ActorState.RUN
	if _sprite:
		_sprite.texture = _tex_dead
	# Blink 8 times in 1.5s — mirrors BaseVehicle::dead() Blink action.
	var tw := create_tween()
	tw.set_loops(8)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.09)
	tw.tween_property(_sprite, "modulate:a", 1.0, 0.09)

func _on_reset() -> void:
	_anim_timer = 0.0
	_idle_frame = 0
	if _sprite:
		_sprite.texture = _tex_idle_0

func _process(delta: float) -> void:
	if state == ActorState.IDLE and _sprite:
		_anim_timer += delta
		if _anim_timer >= 1.0 / IDLE_FPS:
			_anim_timer = 0.0
			_idle_frame = (_idle_frame + 1) % 2
			_sprite.texture = _tex_idle_0 if _idle_frame == 0 else _tex_idle_1
