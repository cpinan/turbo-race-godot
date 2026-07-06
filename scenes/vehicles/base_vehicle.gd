class_name BaseVehicle
extends CharacterBody2D

# ---------------------------------------------------------------------------
# State — mirrors ActorState enum from GameTypes.hpp
# ---------------------------------------------------------------------------
enum ActorState { NOTHING = 0, IDLE = 1, JUMP = 2, RUN = 3, BACK = 4 }

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
var state: ActorState         = ActorState.IDLE
var player_y: float           = 0.0
var speed: float              = VehiclePhysics.DEFAULT_SPEED
var content_size: Vector2     = Vector2.ZERO

var _limit_bot: float         = 0.0
var _limit_top: float         = 0.0
var _jump_tween: Tween        = null
var _jump_start_y: float      = 0.0

# Signals
signal jumped
signal landed
signal died

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func set_limits(limit_bot: float, height: float) -> void:
	var lim: Dictionary = VehiclePhysics.compute_y_limits(limit_bot, height)
	_limit_bot = lim["bottom"]
	_limit_top = lim["top"]

# ---------------------------------------------------------------------------
# Jump
# ---------------------------------------------------------------------------

func do_jump() -> void:
	var ah: float = VehiclePhysics.airborne_height(
		position.y, player_y, content_size.y)
	if not VehiclePhysics.can_jump(ah, state == ActorState.JUMP):
		return

	state = ActorState.JUMP
	_jump_start_y = player_y + content_size.y * 0.5  # sprite center on ground
	emit_signal("jumped")

	if _jump_tween:
		_jump_tween.kill()
	_jump_tween = create_tween()
	_jump_tween.tween_method(_apply_jump, 0.0, 1.0, VehiclePhysics.JUMP_DURATION)
	_jump_tween.tween_callback(_on_jump_finished)

func _apply_jump(t: float) -> void:
	var offset: float = VehiclePhysics.jump_arc_offset(t)
	position.y = _jump_start_y + offset

func _on_jump_finished() -> void:
	state = ActorState.IDLE
	position.y = _jump_start_y
	player_y = position.y - content_size.y * 0.5
	emit_signal("landed")

# ---------------------------------------------------------------------------
# Move (joypad / accelerometer velocity per frame)
# ---------------------------------------------------------------------------

func do_move(vel: Vector2, win_w: float) -> void:
	if state != ActorState.JUMP:
		player_y = position.y - content_size.y * 0.5
	else:
		# Clamp Y velocity while airborne
		vel.y = VehiclePhysics.clamp_airborne_velocity_y(
			player_y, vel.y, _limit_bot, _limit_top)

	var new_pos: Vector2 = position + vel
	new_pos.x = VehiclePhysics.clamp_x(new_pos.x, content_size.x, win_w)
	player_y += vel.y

	player_y = clampf(player_y, _limit_bot, _limit_top)

	if state != ActorState.JUMP:
		new_pos.y = player_y + content_size.y * 0.5

	position = new_pos

# ---------------------------------------------------------------------------
# Collision rects (world space)
# ---------------------------------------------------------------------------

func get_ground_collision() -> Rect2:
	return VehiclePhysics.ground_collision_rect(
		position.x, player_y, content_size.x, content_size.y)

func get_air_collision() -> Rect2:
	return VehiclePhysics.air_collision_rect(
		position.x, position.y, content_size.x, content_size.y)

func get_airborne_height() -> float:
	return VehiclePhysics.airborne_height(position.y, player_y, content_size.y)

# ---------------------------------------------------------------------------
# Dead
# ---------------------------------------------------------------------------

func die() -> void:
	if _jump_tween:
		_jump_tween.kill()
	emit_signal("died")
