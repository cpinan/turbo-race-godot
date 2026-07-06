class_name GameScene
extends Node2D

# ---------------------------------------------------------------------------
# Game scene — orchestrates the full play loop.
# Mirrors GameLayer.cpp: spawning, parallax, collision checking, game-over.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Pool prefill counts — from GameLayer constructor
# ---------------------------------------------------------------------------
const PREFILL_SINGLE: int = 4
const PREFILL_DOUBLE: int = 3
const PREFILL_AIR:    int = 3
const MAX_OBSTACLES:  int = 10   # from Constants.h

# ---------------------------------------------------------------------------
# Parallax speed multipliers — from GameLayer.cpp DT_SPEED_* constants
# ---------------------------------------------------------------------------
const SPEED_FLOOR:    float = 1.0
const SPEED_OBSTACLE: float = 1.0
const SPEED_BG_FRONT: float = 1.3
const SPEED_BG_MID:   float = 1.0
const SPEED_BG_BACK:  float = 0.5
const SPEED_CLOUD:    float = 0.2

# ---------------------------------------------------------------------------
# Color pulse constants — from GameLayer.cpp
# ---------------------------------------------------------------------------
const COLOR_PULSE_RATE: float = 3.0
const COLOR_MIN:        float = 100.0
const COLOR_MAX:        float = 255.0

# ---------------------------------------------------------------------------
# Scene nodes (assigned in editor or via code)
# ---------------------------------------------------------------------------
@export var single_scene: PackedScene
@export var double_scene: PackedScene
@export var air_scene:    PackedScene

var _player: BaseVehicle
var _lane: LaneLayout
var _obstacles: Array       = []   # Array[BaseObstacle]
var _single_pool: ObstaclePool
var _double_pool: ObstaclePool
var _air_pool: ObstaclePool
var _color: float           = COLOR_MAX
var _color_sign: int        = -1
var _paused: bool           = false

# Parallax sprite arrays
var _floor_sprites:    Array = []
var _bg_back_sprites:  Array = []
var _bg_mid_sprites:   Array = []
var _bg_front_sprites: Array = []
var _cloud_sprite: Sprite2D

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func setup(lane: LaneLayout, level_name: String) -> void:
	_lane = lane
	GameManager.configure(level_name, lane)
	GameManager.game_over.connect(_on_game_over)

	_setup_pools()
	_spawn_initial_obstacles()

func _setup_pools() -> void:
	_single_pool = ObstaclePool.new()
	_double_pool = ObstaclePool.new()
	_air_pool    = ObstaclePool.new()

	if single_scene:
		_single_pool.setup(single_scene, PREFILL_SINGLE, self)
	if double_scene:
		_double_pool.setup(double_scene, PREFILL_DOUBLE, self)
	if air_scene:
		_air_pool.setup(air_scene, PREFILL_AIR, self)

# ---------------------------------------------------------------------------
# Obstacle spawning
# Source: GameLayer::_spawnObstacleGroup, _initElements
# ---------------------------------------------------------------------------

func _spawn_initial_obstacles() -> void:
	var x: float = WorldSpeed.START_X_OBSTACLES
	for _i in range(MAX_OBSTACLES):
		_spawn_group(x)
		if not _obstacles.is_empty():
			x = _obstacles.back().position.x + GameManager._min_dist

func _spawn_group(x: float) -> void:
	var def: Dictionary = GameManager.next_map_entry()
	var y: float = GameManager.lane_y_for(def["lane"])
	var count: int = def["count"]
	var dt_factor: float = def["dt"]

	for i in range(count):
		var obs: BaseObstacle = _acquire_obstacle(def["kind"])
		if obs == null:
			continue

		var dist: float = obs.content_size.x * WorldSpeed.DT_DISTANCE * dt_factor

		if count > 1:
			obs.num_objects = i if i == 0 else 0   # i==0 → stores count; others → 0
			if i == 0:
				obs.num_objects  = count
				obs.distance_objects = dist
			obs.set_meta("tag", (i - 1) * -1 if i > 0 else 1)
		else:
			obs.set_meta("tag", 1)

		obs.position = Vector2(x, y)
		_obstacles.append(obs)
		x += dist

func _acquire_obstacle(kind: int) -> BaseObstacle:
	match kind:
		GameManager.SpawnKind.SINGLE: return _single_pool.acquire()
		GameManager.SpawnKind.GROUND: return _double_pool.acquire()
		GameManager.SpawnKind.AIR:    return _air_pool.acquire()
	return null

func _recycle_obstacle(obs: BaseObstacle) -> void:
	_obstacles.erase(obs)
	match obs.obstacle_type:
		BaseObstacle.ObstacleType.SIMPLE: _single_pool.recycle(obs)
		BaseObstacle.ObstacleType.JUMP:   _double_pool.recycle(obs)
		BaseObstacle.ObstacleType.NORMAL: _air_pool.recycle(obs)

# ---------------------------------------------------------------------------
# Per-frame update
# Source: GameLayer::_gameLogic, _updateObstacles
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _paused or GameManager.game_state != GameManager.GameState.READY:
		return

	GameManager.advance_speed(delta)
	_update_obstacles(delta)
	_update_parallax(delta)

func _update_obstacles(dt: float) -> void:
	var speed_delta: float = GameManager.world_speed * dt * SPEED_OBSTACLE
	var to_recycle: Array  = []

	for obs in _obstacles:
		obs.do_update(speed_delta)

		if obs.position.x < -obs.content_size.x * 0.5:
			to_recycle.append(obs)
		else:
			# Collision check
			if obs.position.x < get_viewport().get_visible_rect().size.x and obs.position.x > 0:
				if _player and obs.collision(_player):
					_player.die()
					GameManager.trigger_game_over()
					return
			# Scoring
			if _player:
				GameManager.check_pass(obs, _player.position.x)

	for obs in to_recycle:
		var tag: int = obs.get_meta("tag", 1)
		var last: BaseObstacle = _obstacles.back() if not _obstacles.is_empty() else null
		_recycle_obstacle(obs)
		if tag == 1 and last != null:
			_spawn_group(last.position.x + GameManager._min_dist)

func _update_parallax(dt: float) -> void:
	var ws: float = GameManager.world_speed * dt

	# Color pulse
	_color += dt * _color_sign * COLOR_PULSE_RATE
	if _color < COLOR_MIN and _color_sign == -1:
		_color_sign = 1
	elif _color > COLOR_MAX and _color_sign == 1:
		_color_sign = -1
	_color = clampf(_color, COLOR_MIN, COLOR_MAX)

	_scroll_sprites(_floor_sprites,    ws * SPEED_FLOOR)
	_scroll_sprites(_bg_back_sprites,  ws * SPEED_BG_BACK)
	_scroll_sprites(_bg_mid_sprites,   ws * SPEED_BG_MID)
	_scroll_sprites(_bg_front_sprites, ws * SPEED_BG_FRONT)

	if _cloud_sprite:
		var vw: float = get_viewport().get_visible_rect().size.x
		_cloud_sprite.position.x -= ws * SPEED_CLOUD
		if _cloud_sprite.position.x <= -_cloud_sprite.texture.get_width() * 0.5:
			_cloud_sprite.position.x = vw + _cloud_sprite.texture.get_width() * 0.7

func _scroll_sprites(sprites: Array, delta: float) -> void:
	if sprites.is_empty():
		return
	var sw: float = (sprites[0] as Sprite2D).texture.get_width()
	for sp in sprites:
		var s: Sprite2D = sp
		s.position.x -= delta
		if s.position.x <= -sw:
			var diff: float = sw + s.position.x
			s.position.x = (sprites.size() - 1) * sw + diff

# ---------------------------------------------------------------------------
# Input — touch right-half jumps
# Source: GameLayer::onTouchBegan
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _paused or GameManager.game_state != GameManager.GameState.READY:
		return
	if event is InputEventScreenTouch and event.pressed:
		var vw: float = get_viewport().get_visible_rect().size.x
		if event.position.x >= vw * 0.5 and _player:
			_player.do_jump()

# ---------------------------------------------------------------------------
# Pause / resume
# ---------------------------------------------------------------------------

func pause() -> void:
	_paused = true
	GameManager.set_state(GameManager.GameState.PAUSED)

func resume() -> void:
	_paused = false
	GameManager.set_state(GameManager.GameState.READY)

# ---------------------------------------------------------------------------
# Game over
# ---------------------------------------------------------------------------

func _on_game_over() -> void:
	_paused = true
