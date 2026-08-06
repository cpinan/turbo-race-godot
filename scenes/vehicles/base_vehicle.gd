class_name BaseVehicle
extends Node2D

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
var _jump_t: float            = 0.0
var _dead: bool               = false
var _shadow: Sprite2D         = null
var _death_tween: Tween       = null

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

# Ground shadow — source: BaseVehicle.cpp ctor + updateShadow().
# Subclasses must call this from _ready() once content_size is known.
#
# C++ places the shadow in child space, which in Cocos2d-x is relative to the
# parent's bottom-left corner (position - contentSize * 0.5 for a 0.5 anchor):
#   local  = (w * 0.5,  _playerY - posY + h * 0.55)
#   world  = (posX,     _playerY + h * 0.05)
# Godot child coords are relative to the parent's origin, so the same world
# point is (0, player_y + h * 0.05 - position.y) in local space.
#
# This is not decoration: the shadow is the only visual indicator of player_y,
# which is what the ground hitbox and SingleObstacle's lane-band test both use.
func _setup_shadow() -> void:
	if _shadow != null:
		return
	_shadow = Sprite2D.new()
	_shadow.texture = load("res://resources/assets/shadow.png")
	_shadow.scale   = Vector2(1.0, -1.0)   # counter the scene-root Y-flip
	_shadow.z_index = -1                   # C++ addChild(spriteShadow, -1)
	add_child(_shadow)
	_update_shadow()

func _update_shadow() -> void:
	if _shadow == null:
		return
	_shadow.position = Vector2(0.0, player_y + content_size.y * 0.05 - position.y)

# ---------------------------------------------------------------------------
# Jump
# ---------------------------------------------------------------------------

func do_jump() -> void:
	var ah: float = VehiclePhysics.airborne_height(
		position.y, player_y, content_size.y)
	if not VehiclePhysics.can_jump(ah, state == ActorState.JUMP):
		return

	state   = ActorState.JUMP
	_jump_t = 0.0
	AudioManager.play_sfx(AudioManager.SFX_JUMP)
	emit_signal("jumped")

# Advance the jump arc by one physics frame. Driven explicitly by GameScene
# rather than _physics_process so that (a) pause/state gating stays in one
# place and (b) the arc is guaranteed to run *after* do_move() has updated
# player_y for this frame.
#
# The arc is applied on top of the LIVE player_y, mirroring Cocos2d-x JumpBy,
# which folds external position changes into its start point and adds the arc
# on top. The 1.0.0 port tweened from a frozen launch Y instead, which meant a
# lane change made mid-jump was reverted on landing and, while airborne, left
# the air hitbox (position.y) in the old lane while the ground hitbox
# (player_y) tracked the new one.
func advance_jump(delta: float) -> void:
	if _dead or state != ActorState.JUMP:
		return

	_jump_t += delta / VehiclePhysics.JUMP_DURATION
	if _jump_t >= 1.0:
		_jump_t    = 0.0
		state      = ActorState.IDLE
		position.y = player_y + content_size.y * 0.5
		_update_shadow()
		emit_signal("landed")
		return

	position.y = (player_y + content_size.y * 0.5
		+ VehiclePhysics.jump_arc_offset(_jump_t))
	_update_shadow()

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
	_update_shadow()

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
	var was_jumping: bool = state == ActorState.JUMP
	_dead = true
	AudioManager.play_sfx(AudioManager.SFX_SMASH)
	emit_signal("died")

	# Source: BaseVehicle::dead() — dying mid-air falls back to the ground over
	# 1.0s while the shadow is re-synced 30 times.
	# The C++ target Y is `spriteShadow->getPositionY() + getPositionY()`, which
	# mixes child-local and world Y and lands at player_y + h*0.55 rather than
	# the shadow's true world Y (player_y + h*0.05). Ported verbatim — the
	# original ships this and it reads as a normal fall.
	if was_jumping:
		if _death_tween:
			_death_tween.kill()
		var target := Vector2(
			position.x + content_size.x * 0.15,
			player_y + content_size.y * 0.55)
		_death_tween = create_tween()
		_death_tween.tween_method(_apply_death_fall, position, target, 1.0)

func _apply_death_fall(p: Vector2) -> void:
	position = p
	_update_shadow()

# ---------------------------------------------------------------------------
# Reset for game restart
# ---------------------------------------------------------------------------

func reset_state() -> void:
	if _death_tween:
		_death_tween.kill()
		_death_tween = null
	_jump_t = 0.0
	_dead   = false
	state   = ActorState.IDLE
	_update_shadow()
	_on_reset()

func _on_reset() -> void:
	pass
