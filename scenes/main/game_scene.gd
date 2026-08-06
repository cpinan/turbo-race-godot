class_name GameScene
extends Node2D

# Orchestrates the full play loop.
# Mirrors GameLayer.cpp: spawning, parallax, collision, scoring, game-over.

signal entrance_done

# Prefill must cover the worst-case concurrent count for MAX_OBSTACLE_GROUPS
# consecutive map entries on any level. Measured peaks across easy/normal/hard/
# story: single 20, ground 14, air 13. Sized with margin so acquire() never has
# to take its growth path mid-run.
const PREFILL_SINGLE: int = 24
const PREFILL_DOUBLE: int = 18
const PREFILL_AIR:    int = 18

# Source: GameLayer::_initElements — spawns exactly MAX_OBSTACLES *groups*,
# not obstacles. A group is 1-3 obstacles depending on map entry.
const MAX_OBSTACLE_GROUPS: int = 10

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

# Z-order — mirrors the GameDeep enum in GameLayer.hpp.
#
# C++ spawns with `addChild(node, int(WIN_H - z_param) + toZ(GameDeep::X))`.
# The raw GameDeep values (-9999 … -2500) fall outside Godot's z_index range of
# ±4096, so the background constants below are rescaled — only their ordering
# matters, and nothing is interleaved between them.
#
# Game elements keep the C++ formula exactly, minus the constant GameElements
# base: `z_index = int(WIN_H - z_param)`, which lands in 372…768. That is 1px
# depth granularity, matching C++. 1.0.0 divided by 10, collapsing the whole
# range into ~8 buckets — the player tied with bottom-lane walls (both 46) and
# rendered *behind* ground obstacles it was colliding with at the top of its
# lane range.
const Z_SKY:      int = -600
const Z_CLOUD:    int = -590
const Z_BG_BACK:  int = -580
const Z_BG_MID:   int = -570
const Z_BG_FRONT: int = -560
const Z_TRACKS:   int = -550
const Z_DEBUG:    int = 1000   # above every game element (max 768)

# Press to toggle the collision overlay at runtime — the exported flag alone
# needs an editor round-trip, which is useless while play-testing.
const DEBUG_TOGGLE_KEY: Key = KEY_F1

# z_param per lane, from GameLayer::_spawnObstacleGroup's switch on LanePos.
const Z_PARAM_DOUBLE_AIR:    float = 0.0
const Z_PARAM_DOUBLE_GROUND: float = WIN_H * 0.5

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
		_ensure_debug_overlay()

# The overlay is also reachable at runtime via DEBUG_TOGGLE_KEY, so it is built
# lazily rather than only from _ready().
func _ensure_debug_overlay() -> void:
	if _debug_overlay != null:
		return
	var overlay_script: Script = load("res://scripts/debug_collision_overlay.gd")
	_debug_overlay = Node2D.new()
	_debug_overlay.set_script(overlay_script)
	_debug_overlay.z_index = Z_DEBUG
	add_child(_debug_overlay)
	(_debug_overlay as Node2D).set("game_scene", self)

func toggle_debug_collision() -> void:
	debug_collision = not debug_collision
	if debug_collision:
		_ensure_debug_overlay()
	if _debug_overlay != null:
		_debug_overlay.visible = debug_collision
		_debug_overlay.queue_redraw()
	print("[DEBUG] collision overlay ", "ON" if debug_collision else "OFF")

func _create_background() -> void:
	# Background layers in back-to-front draw order.
	# Non-centered sprites: position.y = Cocos2d anchor(0,0) y + texture height (Y-up).
	# Each Sprite2D has scale=(1,-1) to counter the root Y-flip, keeping textures upright.
	_make_tile_row(_sky_sprites,      "cielo.png",        WIN_H, Z_SKY)
	_make_cloud()
	_make_tile_row(_bg_back_sprites,  "background_2.png", 594.0, Z_BG_BACK)
	_make_tile_row(_bg_mid_sprites,   "background_1.png", 583.0, Z_BG_MID)
	_make_tile_row(_bg_front_sprites, "humo.png",         501.0, Z_BG_FRONT)
	_make_tile_row(_floor_sprites,    "pista.png",        TRACK_H, Z_TRACKS)

func _make_tile_row(arr: Array, fname: String, y_pos: float, z: int) -> void:
	var tex: Texture2D = load("res://resources/assets/" + fname)
	var tw: float      = tex.get_width()
	var n: int         = ceili(WIN_W / tw) + 2
	for i in range(n):
		var sp := Sprite2D.new()
		sp.texture  = tex
		sp.centered = false
		sp.scale    = Vector2(1.0, -1.0)
		sp.position = Vector2(i * tw, y_pos)
		sp.z_index  = z
		add_child(sp)
		arr.append(sp)

func _make_cloud() -> void:
	var tex: Texture2D = load("res://resources/assets/nube.png")
	_cloud_sprite          = Sprite2D.new()
	_cloud_sprite.texture  = tex
	_cloud_sprite.scale    = Vector2(1.0, -1.0)
	_cloud_sprite.position = Vector2(WIN_W * 1.2, WIN_H * 0.85)
	_cloud_sprite.z_index  = Z_CLOUD
	add_child(_cloud_sprite)

func _create_player() -> void:
	var frog_scene: PackedScene = load("res://scenes/vehicles/vehicle_frog.tscn")
	_player = frog_scene.instantiate() as BaseVehicle
	add_child(_player)
	# VehiclePhysics.compute_y_limits() already applies the
	# `-wallHeight*0.1` / `+wallHeight*0.9` transform from
	# GameLayer::_createPlayer, so it takes the RAW lane values. Passing
	# pre-adjusted ones (as 1.0.0 did) applied the transform twice and shrank
	# the playfield from [210, 300] to [201, 282] — 9 units of headroom lost at
	# the top lane, 9 gained below the bottom lane.
	_player.set_limits(_lane.player_start_y, _lane.wall_height)
	var center_y: float     = _lane.player_start_y + _lane.wall_height * 0.5
	_player.position.y      = center_y
	_player.position.x      = _player.content_size.x * 2.5
	_player.player_y        = center_y - _player.content_size.y * 0.5
	_update_player_z()

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
		_update_player_z()

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
	for _i in range(MAX_OBSTACLE_GROUPS):
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

		# Z-depth — GameLayer::_spawnObstacleGroup:
		#   addChild(obstacle, int(WIN_H - z_param) + toZ(GameDeep::GameElements))
		var z_param: float = y                               # SIMPLE → its lane Y
		match obs.obstacle_type:
			BaseObstacle.ObstacleType.NORMAL: z_param = Z_PARAM_DOUBLE_AIR
			BaseObstacle.ObstacleType.JUMP:   z_param = Z_PARAM_DOUBLE_GROUND
		obs.z_index = int(WIN_H - z_param)

		_obstacles.append(obs)
		x += dist

# Dynamic player depth — GameLayer::_updatePlayer:
#   reorderChild(_player, int(WIN_H - (playerY + height*0.75)) + GameElements)
# Also called at spawn/restart so the player is never drawn at the default z=0
# for the frame before _physics_process first runs.
func _update_player_z() -> void:
	if _player == null:
		return
	var z_param: float = _player.player_y + _player.content_size.y * 0.75
	_player.z_index = int(WIN_H - z_param)

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
		var spd: float = VehiclePhysics.DEFAULT_SPEED * delta * PHYSICS_FPS
		var vel := Vector2.ZERO

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
			vel = Vector2(norm_x * spd * TILT_X_MULT, norm_y * spd)
		elif _joy_active:
			vel = Vector2(_joy_norm_x * spd, _joy_norm_y * spd)
		else:
			# Keyboard fallback for web/desktop — arrows or WASD move, Space jumps (jump in _unhandled_input).
			var key_x: float = 0.0
			var key_y: float = 0.0
			if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A): key_x -= 1.0
			if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): key_x += 1.0
			if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W): key_y += 1.0
			if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S): key_y -= 1.0
			vel = Vector2(key_x * spd, key_y * spd)

		# do_move() is called unconditionally, including with a zero vector —
		# GameLayer::_updatePlayer calls updateControl()/doMove() every frame
		# regardless of stick deflection, and doMove's zero-velocity path is
		# what clamps player_y into [limit_bot, limit_top] and re-syncs
		# position.y to it. Skipping it (as 1.0.0 did) left the player resting
		# 4 units below the intended floor until the first input arrived.
		_player.do_move(vel, WIN_W)

	# Jump arc — must run after do_move() so the arc sits on top of this frame's
	# lane movement (mirrors Cocos2d-x JumpBy folding in external position deltas).
	if _player:
		_player.advance_jump(delta)

	_update_player_z()

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
	# Checked before the pause/state guard so the overlay can be toggled from
	# the menu, mid-run, or on the game-over screen.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == DEBUG_TOGGLE_KEY:
			toggle_debug_collision()
			get_viewport().set_input_as_handled()
			return

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
		# Joystick-by-drag is a touch-control stand-in; on web/desktop keyboard
		# covers movement, so left-half clicks jump too instead of driving a
		# joystick with no visible thumb.
		var left_half: bool = event.position.x < WIN_W * 0.5 and OS.has_feature("android")
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

	elif event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed and not event.echo and _player:
			_player.do_jump()

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
		_update_player_z()

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
