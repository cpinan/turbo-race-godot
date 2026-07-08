class_name VehiclePhysics

# From BaseVehicle.hpp / Constants.h
const MAX_PLAYER_JUMP: float = 140.0
const JUMP_DURATION: float   = 0.6
const DEFAULT_SPEED: float   = 11.0

# Jump arc: t in [0,1] → Y offset from ground.
# Matches Cocos2d-x JumpBy formula: height * |sin(π * frac)| with jumps=1.
static func jump_arc_offset(t: float) -> float:
	return MAX_PLAYER_JUMP * sin(t * PI)

# Can the vehicle initiate a jump?
# Source: BaseVehicle::doJump guard: y <= 1 AND state != Jump
static func can_jump(airborne_height: float, is_jumping: bool) -> bool:
	return airborne_height <= 1.0 and not is_jumping

# Height above ground while airborne.
# Source: BaseVehicle::dead/AirDoubleObstacle: posY - playerY - contentH * 0.5
static func airborne_height(pos_y: float, player_y: float, content_h: float) -> float:
	return pos_y - player_y - content_h * 0.5

# Ground collision rect (world space, Y-up).
# Source: BaseVehicle::getGroundCollision
static func ground_collision_rect(
		pos_x: float, player_y: float, content_w: float, content_h: float) -> Rect2:
	var bbox_min_x: float = pos_x - content_w * 0.5
	return Rect2(
		bbox_min_x + content_w * 0.3,
		player_y,
		content_w * 0.55,
		content_h * 0.3
	)

# Air collision rect (world space, Y-up).
# Source: BaseVehicle::getAirCollision — note: height uses WIDTH, not height.
static func air_collision_rect(
		pos_x: float, pos_y: float, content_w: float, content_h: float) -> Rect2:
	var bbox_min_x: float = pos_x - content_w * 0.5
	var bbox_min_y: float = pos_y - content_h * 0.5
	return Rect2(
		bbox_min_x + content_w * 0.3,
		bbox_min_y + content_h * 0.16,
		content_w * 0.55,
		content_w * 0.2   # intentionally uses width
	)

# Y limits from LevelLayout values.
# Source: GameLayer::_createPlayer → setLimits
static func compute_y_limits(player_start_y: float, wall_height: float) -> Dictionary:
	var bottom: float = player_start_y - wall_height * 0.1
	return {"bottom": bottom, "top": bottom + wall_height * 0.9}

# Clamp a new Y velocity when airborne to stay inside limits.
# Source: BaseVehicle::doMove Y clamping block
static func clamp_airborne_velocity_y(
		player_y: float, vel_y: float, limit_bot: float, limit_top: float) -> float:
	if player_y + vel_y > limit_top:
		return 0.0
	if player_y + vel_y < limit_bot:
		return 0.0
	return vel_y

# Clamp X position to valid range.
# Source: BaseVehicle::doMove X clamping
static func clamp_x(pos_x: float, content_w: float, win_w: float) -> float:
	return clampf(pos_x, content_w * 0.5, win_w * 0.8)
