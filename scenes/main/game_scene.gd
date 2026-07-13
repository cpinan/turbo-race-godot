class_name GameScene
extends Node2D

# Orchestrates the full play loop.
# Mirrors GameLayer.cpp: spawning, parallax, collision, scoring, game-over.

signal entrance_done

const PREFILL_SINGLE: int = 12   # easy.json starts with 10 consecutive singles
const PREFILL_DOUBLE: int = 6
const PREFILL_AIR:    int = 6
const MAX_OBSTACLES:  int = 10

const SPEED_FLOOR:    float = 1.0
const SPEED_OBSTACLE: float = 1.0
const SPEED_BG_FRONT: float = 1.3
const SPEED_BG_MID:   float = 1.0
const SPEED_BG_BACK:  float = 0.5
const SPEED_CLOUD:    float = 0.2

const COLOR_PULSE_RATE: float = 3.0
const COLOR_MIN:        float = 100.0
const COLOR_MAX:        float = 255.0

const WIN_W:   float = 1024.0
const WIN_H:   float = 768.0
const TRACK_H: float = 400.0   # pista.png height

# Joystick constants — mirrors HudLayer joypad velocity behaviour.
const JOY_DEAD_ZONE: float  = 20.0   # screen pixels before registering input
const JOY_MAX_DIST:  float  = 80.0   # screen pixels for full ±1 velocity
const PHYSICS_FPS:   float  = 60.0   # reference frame rate for velocity scaling

# Tilt (accelerometer) constants.
# accel.x in landscape = roll axis (left/right tilt of device).
# Negate so tilting left side down → player moves up (positive Y in game).
# Tune TILT_MAX_DIST if sensitivity needs adjustment after on-device testing.
const TILT_DEAD_ZONE: float = 1.5    # m/s² — below this threshold, no movement
const TILT_MAX_DIST:  float = 5.0    # m/s² — at this tilt, full-speed movement
const TILT_X_MULT:    float = 2.0    # extra speed factor for horizontal tilt axis

@export var single_scene: PackedScene
@export var double_scene: PackedScene
@export var air_scene:    PackedScene
@export var debug_collision: bool = false

var _player: BaseVehicle
var _lane: LaneLayout
var _obstacles: Array       = []
var _single_pool: ObstaclePool
var _double_pool: ObstaclePool
var _air_pool: ObstaclePool
var _color: float           = COLOR_MAX
var _color_sign: int        = -1
var _paused: bool           = false

# Virtual joystick state — mirrors SneakyJoystick velocity (x and y axes).
var _joy_active: bool    = false
var _joy_index: int      = -1
var _joy_anchor_x: float = 0.0
var _joy_anchor_y: float = 0.0
var _joy_norm_x: float   = 0.0
var _joy_norm_y: float   = 0.0

var _debug_overlay: Node2D = null
var _tilt_log_frame: int    = 0
var _tilt_baseline: float   = 0.0   # accel.y baseline sampled at game start
var _tilt_baseline_x: float = 0.0   # accel.x baseline for horizontal movement
var _tilt_dbg_canvas: CanvasLayer = null
var _tilt_dbg_label: Label = null

var _floor_sprites:    Array = []
var _sky_sprites:      Array = []
var _bg_back_sprites:  Array = []
var _bg_mid_sprites:   Array = []
var _bg_front_sprites: Array = []
var _cloud_sprite: Sprite2D

# ---------------------------------------------------------------------------
# World setup
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Y-up coordinate system matching Cocos2d-x (origin at bottom-left).
	scale    = Vector2(1.0, -1.0)
	position = Vector2(0.0, WIN_H)

	single_scene = load("res://scenes/obstacles/single_obstacle.tscn")
	double_scene = load("res://scenes/obstacles/double_obstacle.tscn")
	air_scene    = load("res://scenes/obstacles/air_double_obstacle.tscn")

	_lane = LaneLayout.compute(TRACK_H, 0.0)
	_create_background()
	_create_player()
	setup(_lane, "easy")
	GameManager.set_state(GameManager.GameState.READY)
	if debug_collision:
		var overlay_script: Script = load("res://scripts/debug_collision_overlay.gd")
		_debug_overlay = Node2D.new()
		_debug_overlay.set_script(overlay_script)
		_debug_overlay.z_index = 1000
		add_child(_debug_overlay)
		(_debug_overlay as Node2D).set("game_scene", self)

func _create_background() -> void:
	# Background layers in back-to-front draw order.
	# Non-centered sprites: position.y = Cocos2d anchor(0,0) y + texture height (Y-up).
	# Each Sprite2D has scale=(1,-1) to counter the root Y-flip, keeping textures upright.
	_make_tile_row(_sky_sprites,      "cielo.png",        WIN_H)
	_make_cloud()
	_make_tile_row(_bg_back_sprites,  "background_2.png", 594.0)
	_make_tile_row(_bg_mid_sprites,   "background_1.png", 583.0)
	_make_tile_row(_bg_front_sprites, "humo.png",         501.0)
	_make_tile_row(_floor_sprites,    "pista.png",        TRACK_H)

func _make_tile_row(arr: Array, fname: String, y_pos: float) -> void:
	var tex: Texture2D = load("res://resources/assets/" + fname)
	var tw: float      = tex.get_width()
	var n: int         = ceili(WIN_W / tw) + 2
	for i in range(n):
		var sp := Sprite2D.new()
		sp.texture  = tex
		sp.centered = false
		sp.scale    = Vector2(1.0, -1.0)
		sp.position = Vector2(i * tw, y_pos)
		add_child(sp)
		arr.append(sp)

func _make_cloud() -> void:
	var tex: Texture2D = load("res://resources/assets/nube.png")
	_cloud_sprite          = Sprite2D.new()
	_cloud_sprite.texture  = tex
	_cloud_sprite.scale    = Vector2(1.0, -1.0)
	_cloud_sprite.position = Vector2(WIN_W * 1.2, WIN_H * 0.85)
	add_child(_cloud_sprite)

func _create_player() -> void:
	var frog_scene: PackedScene = load("res://scenes/vehicles/vehicle_frog.tscn")
	_player = frog_scene.instantiate() as BaseVehicle
	add_child(_player)
	_player.set_limits(
		_lane.player_start_y - _lane.wall_height * 0.1,
		_lane.wall_height * 0.9
	)
	var center_y: float     = _lane.player_start_y + _lane.wall_height * 0.5
	_player.position.y      = center_y
	_player.position.x      = _player.content_size.x * 2.5
	_player.player_y        = center_y - _player.content_size.y * 0.5

# ---------------------------------------------------------------------------
# Initialisation — wires level config and spawns initial obstacles
# ---------------------------------------------------------------------------

func _calibrate_tilt() -> void:
	if OS.has_feature("android") and SaveManager.get_control_type() == "tilt":
		var a: Vector3 = Input.get_accelerometer()
		_tilt_baseline   = a.y
		_tilt_baseline_x = a.x

func _setup_tilt_debug() -> void:
	if not debug_collision:
		return
	if not OS.has_feature("android"):
		return
	if SaveManager.get_control_type() != "tilt":
		return
	if _tilt_dbg_canvas != null:
		return
	_tilt_dbg_canvas = CanvasLayer.new()
	_tilt_dbg_canvas.layer = 50
	add_child(_tilt_dbg_canvas)
	_tilt_dbg_label = Label.new()
	_tilt_dbg_label.position = Vector2(10.0, 10.0)
	_tilt_dbg_label.add_theme_font_size_override("font_size", 40)
	_tilt_dbg_label.add_theme_color_override("font_color", Color.YELLOW)
	_tilt_dbg_canvas.add_child(_tilt_dbg_label)

func setup(lane: LaneLayout, level_name: String) -> void:
	_calibrate_tilt()
	_setup_tilt_debug()
	_lane = lane
	GameManager.configure(level_name, lane)
	if not GameManager.game_over.is_connected(_on_game_over):
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
# Game restart — reuses pools; no new obstacle nodes created.
# ---------------------------------------------------------------------------

func restart(level_name: String) -> void:
	_calibrate_tilt()
	_paused      = false
	_joy_active  = false
	_joy_norm_x  = 0.0
	_joy_norm_y  = 0.0

	# Return all active obstacles to their pools.
	var to_recycle: Array = _obstacles.duplicate()
	_obstacles.clear()
	for obs in to_recycle:
		match obs.obstacle_type:
			BaseObstacle.ObstacleType.SIMPLE: _single_pool.recycle(obs)
			BaseObstacle.ObstacleType.JUMP:   _double_pool.recycle(obs)
			BaseObstacle.ObstacleType.NORMAL: _air_pool.recycle(obs)

	if _player:
		var center_y: float   = _lane.player_start_y + _lane.wall_height * 0.5
		_player.position.y    = center_y
		_player.position.x    = _player.content_size.x * 2.5
		_player.player_y      = center_y - _player.content_size.y * 0.5
		_player.reset_state()

	# Reconfigure GameManager and re-spawn.
	if GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.disconnect(_on_game_over)
	GameManager.configure(level_name, _lane)
	GameManager.game_over.connect(_on_game_over)
	_spawn_initial_obstacles()
	GameManager.set_state(GameManager.GameState.PAUSED)
	_on_entrance_done.call_deferred()

# ---------------------------------------------------------------------------
# Obstacle spawning — mirrors GameLayer::_spawnObstacleGroup
# ---------------------------------------------------------------------------

func _spawn_initial_obstacles() -> void:
	var x: float = WorldSpeed.START_X_OBSTACLES
	while _obstacles.size() < MAX_OBSTACLES:
		_spawn_group(x)
		if not _obstacles.is_empty():
			x = _obstacles.back().position.x + GameManager._min_dist

func _spawn_group(x: float) -> void:
	var def: Dictionary  = GameManager.next_map_entry()
	var y: float         = GameManager.lane_y_for(def["lane"])
	var count: int       = def["count"]
	var dt_factor: float = def["dt"]

	for i in range(count):
		var obs: BaseObstacle = _acquire_obstacle(def["kind"])
		if obs == null:
			continue

		var dist: float = obs.content_size.x * WorldSpeed.DT_DISTANCE * dt_factor

		if count > 1:
			if i == 0:
				obs.num_objects      = count
				obs.distance_objects = dist
				obs.set_meta("tag", 1)
			else:
				obs.num_objects = 0
				obs.set_meta("tag", 0)
		else:
			obs.set_meta("tag", 1)

		obs.position = Vector2(x, y)

		# Z-depth — mirrors C++ addChild(obs, int(WIN_H - z) + GameDeep::GameElements)
		# z_param per lane: NORMAL(Air)=0, JUMP(Ground)=WIN_H*0.5, SIMPLE(Single)=lane_y
		match obs.obstacle_type:
			BaseObstacle.ObstacleType.NORMAL:
				obs.z_index = int(WIN_H / 10.0)               # 76 — always in front
			BaseObstacle.ObstacleType.JUMP:
				obs.z_index = int((WIN_H - WIN_H * 0.5) / 10.0)  # 38 — behind player
			BaseObstacle.ObstacleType.SIMPLE:
				obs.z_index = int((WIN_H - y) / 10.0)         # 39-46 depending on lane

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
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _paused:
		return

	if GameManager.game_state != GameManager.GameState.READY:
		return

	# Apply movement — tilt (accelerometer) or virtual joystick.
	if _player:
		var is_android: bool    = OS.has_feature("android")
		var ctrl_type: String   = SaveManager.get_control_type()
		var tilt_active: bool   = is_android and ctrl_type == "tilt"
		var accel_dbg: Vector3 = Input.get_accelerometer()
		if _tilt_dbg_label != null:
			var dx: float = accel_dbg.x - _tilt_baseline_x
			var dy: float = accel_dbg.y - _tilt_baseline
			_tilt_dbg_label.text = (
				"x=%.1f dx=%.1f\ny=%.1f dy=%.1f" % [accel_dbg.x, dx, accel_dbg.y, dy])
		_tilt_log_frame += 1
		if _tilt_log_frame >= 60:
			_tilt_log_frame = 0
			print("[TILT] x=", snapped(accel_dbg.x, 0.01),
				" dx=", snapped(accel_dbg.x - _tilt_baseline_x, 0.01),
				" y=", snapped(accel_dbg.y, 0.01),
				" dy=", snapped(accel_dbg.y - _tilt_baseline, 0.01))
		if tilt_active:
			var accel: Vector3 = Input.get_accelerometer()
			var raw_y: float = accel.y - _tilt_baseline
			var raw_x: float = accel.x - _tilt_baseline_x
			var norm_y: float = 0.0
			var norm_x: float = 0.0
			if absf(raw_y) > TILT_DEAD_ZONE:
				var t: float = clampf((absf(raw_y) - TILT_DEAD_ZONE) / (TILT_MAX_DIST - TILT_DEAD_ZONE), 0.0, 1.0)
				norm_y = t if raw_y > 0.0 else -t
			if absf(raw_x) > TILT_DEAD_ZONE:
				var t: float = clampf((absf(raw_x) - TILT_DEAD_ZONE) / (TILT_MAX_DIST - TILT_DEAD_ZONE), 0.0, 1.0)
				norm_x = t if raw_x > 0.0 else -t
			if norm_y != 0.0 or norm_x != 0.0:
				var spd: float = VehiclePhysics.DEFAULT_SPEED * delta * PHYSICS_FPS
				_player.do_move(Vector2(norm_x * spd * TILT_X_MULT, norm_y * spd), WIN_W)
		elif _joy_active and (_joy_norm_x != 0.0 or _joy_norm_y != 0.0):
			var spd: float = VehiclePhysics.DEFAULT_SPEED * delta * PHYSICS_FPS
			_player.do_move(Vector2(_joy_norm_x * spd, _joy_norm_y * spd), WIN_W)

	# Dynamic z_index — mirrors C++ reorderChild(_player, z) in _updatePlayer.
	# Formula: (WIN_H - (playerY + height*0.75)) / 10  ≈ 45 at center lane.
	if _player:
		var z_param: float = _player.player_y + _player.content_size.y * 0.75
		_player.z_index = int((WIN_H - z_param) / 10.0)

	GameManager.advance_speed(delta)
	_update_obstacles(delta)
	_update_parallax(delta)
	if debug_collision and _debug_overlay:
		_debug_overlay.queue_redraw()

func _update_obstacles(dt: float) -> void:
	var speed_delta: float = GameManager.world_speed * dt * SPEED_OBSTACLE
	var to_recycle: Array  = []

	for obs in _obstacles:
		obs.do_update(speed_delta)

		if obs.position.x < -obs.content_size.x * 0.5:
			to_recycle.append(obs)
		else:
			if obs.position.x < WIN_W and obs.position.x > 0.0:
				if _player and obs.collision(_player):
					_player.die()
					GameManager.trigger_game_over()
					return
			if _player:
				GameManager.check_pass(obs, _player.position.x)

	for obs in to_recycle:
		var tag: int          = obs.get_meta("tag", 1)
		var last: BaseObstacle = _obstacles.back() if not _obstacles.is_empty() else null
		_recycle_obstacle(obs)
		if tag == 1 and last != null:
			_spawn_group(last.position.x + GameManager._min_dist)

func _update_parallax(dt: float) -> void:
	var ws: float = GameManager.world_speed * dt

	_color += dt * _color_sign * COLOR_PULSE_RATE
	if _color < COLOR_MIN and _color_sign == -1:
		_color_sign = 1
	elif _color > COLOR_MAX and _color_sign == 1:
		_color_sign = -1
	_color = clampf(_color, COLOR_MIN, COLOR_MAX)

	_scroll_sprites(_sky_sprites,      ws * SPEED_BG_BACK)
	_scroll_sprites(_bg_back_sprites,  ws * SPEED_BG_BACK)
	_scroll_sprites(_bg_mid_sprites,   ws * SPEED_BG_MID)
	_scroll_sprites(_bg_front_sprites, ws * SPEED_BG_FRONT)
	_scroll_sprites(_floor_sprites,    ws * SPEED_FLOOR)

	if _cloud_sprite:
		_cloud_sprite.position.x -= ws * SPEED_CLOUD
		if _cloud_sprite.position.x <= -_cloud_sprite.texture.get_width() * 0.5:
			_cloud_sprite.position.x = WIN_W + _cloud_sprite.texture.get_width() * 0.7

func _scroll_sprites(sprites: Array, delta: float) -> void:
	if sprites.is_empty():
		return
	var sw: float = (sprites[0] as Sprite2D).texture.get_width()
	for sp in sprites:
		var s: Sprite2D = sp
		s.position.x -= delta
		if s.position.x <= -sw:
			var diff: float = sw + s.position.x
			s.position.x   = (sprites.size() - 1) * sw + diff

# ---------------------------------------------------------------------------
# Input — right-half: jump; left-half: virtual joystick (x + y axes).
# Mirrors GameLayer (jump) + HudLayer/SneakyJoystick (joystick) from C++.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _paused or GameManager.game_state != GameManager.GameState.READY:
		return

	var tilt_mode: bool = OS.has_feature("android") and SaveManager.get_control_type() == "tilt"

	if event is InputEventScreenTouch:
		var left_half: bool = event.position.x < WIN_W * 0.5
		if left_half and not tilt_mode:
			if event.pressed:
				_joy_active   = true
				_joy_index    = event.index
				_joy_anchor_x = event.position.x
				_joy_anchor_y = event.position.y
				_joy_norm_x   = 0.0
				_joy_norm_y   = 0.0
			elif event.index == _joy_index:
				_joy_active = false
				_joy_norm_x = 0.0
				_joy_norm_y = 0.0
		elif event.pressed and _player:
			_player.do_jump()

	elif event is InputEventScreenDrag:
		if not tilt_mode and _joy_active and event.index == _joy_index:
			var dx: float = event.position.x - _joy_anchor_x
			var dy: float = event.position.y - _joy_anchor_y
			_joy_norm_x = clampf(dx / JOY_MAX_DIST, -1.0, 1.0)
			# Screen Y-down → invert so dragging up moves player up (Cocos Y-up world).
			_joy_norm_y = clampf(-dy / JOY_MAX_DIST, -1.0, 1.0)
			if absf(dx) < JOY_DEAD_ZONE: _joy_norm_x = 0.0
			if absf(dy) < JOY_DEAD_ZONE: _joy_norm_y = 0.0

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var left_half: bool = event.position.x < WIN_W * 0.5
		if left_half and not tilt_mode:
			if event.pressed:
				_joy_active   = true
				_joy_index    = -1
				_joy_anchor_x = event.position.x
				_joy_anchor_y = event.position.y
				_joy_norm_x   = 0.0
				_joy_norm_y   = 0.0
			else:
				_joy_active = false
				_joy_norm_x = 0.0
				_joy_norm_y = 0.0
		elif event.pressed and _player:
			_player.do_jump()

	elif event is InputEventMouseMotion and not tilt_mode and _joy_active and _joy_index == -1:
		var dx: float = event.position.x - _joy_anchor_x
		var dy: float = event.position.y - _joy_anchor_y
		_joy_norm_x = clampf(dx / JOY_MAX_DIST, -1.0, 1.0)
		_joy_norm_y = clampf(-dy / JOY_MAX_DIST, -1.0, 1.0)
		if absf(dx) < JOY_DEAD_ZONE: _joy_norm_x = 0.0
		if absf(dy) < JOY_DEAD_ZONE: _joy_norm_y = 0.0

# ---------------------------------------------------------------------------
# Pause / resume
# ---------------------------------------------------------------------------

func pause() -> void:
	_paused = true
	GameManager.set_state(GameManager.GameState.PAUSED)

# Called when returning to home screen — pauses and clears active obstacles so
# the background is visible and clean behind the home menu (mirrors C++ HomeScene
# replacing GameScene which always kept GameLayer rendering in background).
func reset_for_home() -> void:
	_paused     = true
	_joy_active = false
	_joy_norm_x = 0.0
	_joy_norm_y = 0.0
	GameManager.set_state(GameManager.GameState.PAUSED)

	if _single_pool != null:
		var to_recycle: Array = _obstacles.duplicate()
		_obstacles.clear()
		for obs in to_recycle:
			match obs.obstacle_type:
				BaseObstacle.ObstacleType.SIMPLE: _single_pool.recycle(obs)
				BaseObstacle.ObstacleType.JUMP:   _double_pool.recycle(obs)
				BaseObstacle.ObstacleType.NORMAL: _air_pool.recycle(obs)

	if _player:
		var center_y: float = _lane.player_start_y + _lane.wall_height * 0.5
		_player.position.y  = center_y
		_player.position.x  = _player.content_size.x * 2.5
		_player.player_y    = center_y - _player.content_size.y * 0.5
		_player.reset_state()

func resume() -> void:
	_paused = false
	GameManager.set_state(GameManager.GameState.READY)

# ---------------------------------------------------------------------------
# Game over
# ---------------------------------------------------------------------------

func _on_game_over() -> void:
	_paused = true

func _on_entrance_done() -> void:
	emit_signal("entrance_done")
