class_name HUD
extends CanvasLayer

# In-game HUD: score label, pause button, and virtual joystick visual.
# Score/pause mirror GameLayer; joystick mirrors HudLayer/SneakyJoystick from C++.

signal pause_pressed

const WIN_W: float       = 1024.0
const JOY_DEAD_ZONE: float = 20.0
const JOY_MAX_DIST:  float = 80.0
const JOY_RADIUS:    float = 45.0   # max thumb travel inside BG (px)

# Thumb rest position = offset_left/top from hud.tscn
const THUMB_REST: Vector2 = Vector2(45.0, 45.0)

@onready var _score_label: Label        = $ScoreLabel
@onready var _btn_pause:   TextureButton = $BtnPause
@onready var _joy_bg:      TextureRect   = $JoystickBG
@onready var _joy_thumb:   TextureRect   = $JoystickBG/JoystickThumb

var _joy_active:   bool  = false
var _joy_index:    int   = -1
var _joy_anchor_x: float = 0.0
var _joy_anchor_y: float = 0.0

func _ready() -> void:
	_btn_pause.pressed.connect(func(): emit_signal("pause_pressed"))
	ScoreModel.score_changed.connect(_on_score_changed)
	_on_score_changed(0)

func _on_score_changed(_total: int) -> void:
	_score_label.text = str(ScoreModel.get_obstacles_avoided())

func show_hud() -> void:
	visible = true
	if _joy_bg:
		var tilt_mode: bool = OS.has_feature("android") and SaveManager.get_control_type() == "tilt"
		_joy_bg.visible = not tilt_mode
	_reset_thumb()

func hide_hud() -> void:
	visible = false
	_joy_active = false
	_reset_thumb()

# ---------------------------------------------------------------------------
# Joystick thumb visual — independent of game_scene physics tracking.
# Mirrors SneakyJoystickSkinnedBase thumb tracking from C++.
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _joy_bg or not _joy_bg.visible:
		return

	if event is InputEventScreenTouch:
		if event.position.x < WIN_W * 0.5:
			if event.pressed:
				_joy_active   = true
				_joy_index    = event.index
				_joy_anchor_x = event.position.x
				_joy_anchor_y = event.position.y
			elif event.index == _joy_index:
				_joy_active = false
				_reset_thumb()

	elif event is InputEventScreenDrag:
		if _joy_active and event.index == _joy_index:
			_move_thumb(event.position.x - _joy_anchor_x,
						event.position.y - _joy_anchor_y)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x < WIN_W * 0.5:
			if event.pressed:
				_joy_active   = true
				_joy_index    = -1
				_joy_anchor_x = event.position.x
				_joy_anchor_y = event.position.y
			else:
				_joy_active = false
				_reset_thumb()

	elif event is InputEventMouseMotion and _joy_active and _joy_index == -1:
		_move_thumb(event.position.x - _joy_anchor_x,
					event.position.y - _joy_anchor_y)

func _move_thumb(dx: float, dy: float) -> void:
	if not _joy_thumb:
		return
	var nx: float = clampf(dx / JOY_MAX_DIST, -1.0, 1.0)
	var ny: float = clampf(dy / JOY_MAX_DIST, -1.0, 1.0)
	if absf(dx) < JOY_DEAD_ZONE: nx = 0.0
	if absf(dy) < JOY_DEAD_ZONE: ny = 0.0
	_joy_thumb.position = THUMB_REST + Vector2(nx * JOY_RADIUS, ny * JOY_RADIUS)

func _reset_thumb() -> void:
	if _joy_thumb:
		_joy_thumb.position = THUMB_REST

func show_song_label(track_name: String) -> void:
	var lbl := Label.new()
	lbl.text = "Playing " + track_name
	lbl.add_theme_font_override("font", load("res://resources/fonts/Carton_Six.ttf"))
	lbl.add_theme_font_size_override("font_size", 35)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.position             = Vector2(0.0, 960.0)
	lbl.size                 = Vector2(WIN_W, 50.0)
	add_child(lbl)
	# Mirror C++ setPositionX(visibleWidth - textWidth * 1.1) with left anchor.
	await get_tree().process_frame
	if not is_instance_valid(lbl):
		return
	var text_w: float = lbl.get_minimum_size().x
	lbl.position.x = maxf(WIN_W - text_w * 1.1, 0.0)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", 718.0, 1.0)
	tw.tween_interval(2.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(func(): lbl.queue_free())
