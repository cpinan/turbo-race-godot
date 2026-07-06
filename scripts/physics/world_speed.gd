class_name WorldSpeed

# Source: Constants.h (designResolutionSize = 1024x768)
const DESIGN_WIDTH: float           = 1024.0
const START_WORLD_SPEED: float      = DESIGN_WIDTH * 0.5         # 512.0 px/s
const MIN_DISTANCE_OBSTACLES: float = DESIGN_WIDTH / 1.8         # ~568.89 px
const START_X_OBSTACLES: float      = DESIGN_WIDTH * 1.9         # 1945.6 px
const DT_DISTANCE: float            = 0.8                        # intra-group spacing multiplier

# Advance world speed by one frame.
# Source: GameLayer::_updatePlayer
static func advance(current: float, acceleration: float, max_speed: float, dt: float) -> float:
	var next: float = current + dt * acceleration
	if max_speed > 0.0 and next > max_speed:
		next = max_speed
	return next

# Initial world speed for a level.
# Source: GameLayer::configureGame
static func initial_speed(speed_multiplier: float) -> float:
	return START_WORLD_SPEED * speed_multiplier

# Initial minimum obstacle distance for a level.
# Source: GameLayer::configureGame
static func initial_min_distance(distance_multiplier: float) -> float:
	return MIN_DISTANCE_OBSTACLES * distance_multiplier
