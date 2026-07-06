extends Node
# Autoload: GameManager
# Game state machine and obstacle spawning/recycling.
# Mirrors GameLayer.cpp logic, extracted to autoload so it's testable separately.

# ---------------------------------------------------------------------------
# Obstacle map code table
# Source: GameLayer.cpp kObstacleTable
# ---------------------------------------------------------------------------
enum SpawnKind { SINGLE, GROUND, AIR }
enum LanePos   { BOT_SIMPLE, TOP_SIMPLE, DOUBLE_GROUND, DOUBLE_AIR }

const OBSTACLE_TABLE: Array = [
	# { kind, lane, count, dt_factor }
	{ "kind": SpawnKind.SINGLE, "lane": LanePos.BOT_SIMPLE,    "count": 1, "dt": 1.0 }, # 0
	{ "kind": SpawnKind.SINGLE, "lane": LanePos.TOP_SIMPLE,    "count": 1, "dt": 1.0 }, # 1
	{ "kind": SpawnKind.GROUND, "lane": LanePos.DOUBLE_GROUND, "count": 1, "dt": 1.0 }, # 2
	{ "kind": SpawnKind.AIR,    "lane": LanePos.DOUBLE_AIR,    "count": 1, "dt": 1.0 }, # 3
	{ "kind": SpawnKind.SINGLE, "lane": LanePos.BOT_SIMPLE,    "count": 2, "dt": 1.5 }, # 4
	{ "kind": SpawnKind.SINGLE, "lane": LanePos.TOP_SIMPLE,    "count": 2, "dt": 1.5 }, # 5
	{ "kind": SpawnKind.GROUND, "lane": LanePos.DOUBLE_GROUND, "count": 3, "dt": 1.0 }, # 6
	{ "kind": SpawnKind.AIR,    "lane": LanePos.DOUBLE_AIR,    "count": 3, "dt": 1.0 }, # 7
	{ "kind": SpawnKind.GROUND, "lane": LanePos.DOUBLE_GROUND, "count": 2, "dt": 1.0 }, # 8
	{ "kind": SpawnKind.AIR,    "lane": LanePos.DOUBLE_AIR,    "count": 2, "dt": 1.0 }, # 9
]

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------
enum GameState { STARTING, PREPARING, READY, PAUSED, FINISH, END }

signal game_state_changed(new_state: GameState)
signal game_over
signal obstacle_passed(obstacle: BaseObstacle)

var game_state: GameState   = GameState.STARTING
var world_speed: float      = 0.0
var _speed_accel: float     = 0.0
var _max_speed: float       = 0.0
var _min_dist: float        = 0.0
var _map: Array             = []
var _map_index: int         = 0
var _lane: LaneLayout       = null

# ---------------------------------------------------------------------------
# Level configuration
# Source: GameLayer::configureGame
# ---------------------------------------------------------------------------

func configure(level_name: String, lane: LaneLayout) -> void:
	_lane = lane
	var data: LevelData = LevelLoader.load(level_name)
	if data == null:
		push_error("GameManager: failed to load level '%s'" % level_name)
		return

	world_speed    = WorldSpeed.initial_speed(data.speed_multiplier)
	_min_dist      = WorldSpeed.initial_min_distance(data.distance_multiplier)
	_speed_accel   = data.speed_acceleration
	_max_speed     = data.max_world_speed
	_map           = data.map
	_map_index     = 0

	ScoreModel.reset()
	game_state = GameState.STARTING

# ---------------------------------------------------------------------------
# Per-frame update
# Source: GameLayer::_updatePlayer (speed portion)
# ---------------------------------------------------------------------------

func advance_speed(dt: float) -> void:
	world_speed = WorldSpeed.advance(world_speed, _speed_accel, _max_speed, dt)

# ---------------------------------------------------------------------------
# Map iteration — returns next obstacle def, wraps cyclically
# Source: GameLayer::_spawnObstacleGroup map index logic
# ---------------------------------------------------------------------------

func next_map_entry() -> Dictionary:
	var entry: Dictionary = OBSTACLE_TABLE[_map[_map_index]]
	_map_index = (_map_index + 1) % _map.size()
	return entry

# ---------------------------------------------------------------------------
# Obstacle pass / scoring
# Source: GameLayer::_updateObstacles scoring block
# ---------------------------------------------------------------------------

func check_pass(obstacle: BaseObstacle, player_pos_x: float) -> void:
	if obstacle.pass_player_sfx:
		return
	if obstacle.has_passed(player_pos_x):
		obstacle.pass_player_sfx = true
		var is_jump_type: bool = (obstacle.obstacle_type == BaseObstacle.ObstacleType.JUMP)
		ScoreModel.add_avoided(is_jump_type)
		emit_signal("obstacle_passed", obstacle)

# ---------------------------------------------------------------------------
# Lane Y positions from current layout
# ---------------------------------------------------------------------------

func lane_y_for(lane_pos: LanePos) -> float:
	match lane_pos:
		LanePos.BOT_SIMPLE:    return _lane.simple_bot_y
		LanePos.TOP_SIMPLE:    return _lane.simple_top_y
		LanePos.DOUBLE_GROUND: return _lane.double_ground_y
		LanePos.DOUBLE_AIR:    return _lane.double_air_y
	return 0.0

# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func set_state(s: GameState) -> void:
	game_state = s
	emit_signal("game_state_changed", s)

func trigger_game_over() -> void:
	set_state(GameState.FINISH)
	emit_signal("game_over")
