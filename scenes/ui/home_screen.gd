class_name HomeScreen
extends CanvasLayer

# Mirrors HomeLayer.cpp
# Shows logo, level buttons (easy/normal/hard), sound toggle, how-to-play.
# On Android: also shows settings gear → control-type panel (joystick vs tilt).

signal level_selected(level_name: String)
signal how_to_play_pressed

const HIDE_TIME: float = 0.4

var _disabled: bool = false

@onready var _logo:            TextureRect   = $Logo
@onready var _tablero:         TextureRect   = $Tablero
@onready var _menu:            Control       = $Menu
@onready var _btn_easy:        TextureButton = $Menu/BtnEasy
@onready var _btn_normal:      TextureButton = $Menu/BtnNormal
@onready var _btn_hard:        TextureButton = $Menu/BtnHard
@onready var _btn_sound:       TextureButton = $Menu/BtnSound
@onready var _btn_how_to_play: Button        = $Menu/BtnHowToPlay
@onready var _btn_settings:      TextureButton = $Menu/BtnSettings
@onready var _btn_achievements:  TextureButton = $Menu/BtnAchievements
@onready var _btn_leaderboard:   TextureButton = $Menu/BtnLeaderboard
@onready var _control_panel:     Control       = $ControlPanel
@onready var _dim_bg:          ColorRect     = $ControlPanel/DimBackground
@onready var _btn_joystick:    TextureButton = $ControlPanel/BtnJoystick
@onready var _btn_tilt:        TextureButton = $ControlPanel/BtnTilt

func _ready() -> void:
	_menu.visible = false

	_logo.position.x = -_logo.size.x * 1.2
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(_logo, "position:x", 1024.0 * 0.65 - _logo.size.x * 0.5, 0.9)
	tween.tween_callback(func():
		_menu.visible = true
		_start_button_animations())

	_update_sound_btn()

	_btn_easy.pressed.connect(func(): _on_level("easy"))
	_btn_normal.pressed.connect(func(): _on_level("normal"))
	_btn_hard.pressed.connect(func(): _on_level("hard"))
	_btn_sound.pressed.connect(_on_sound)
	_btn_how_to_play.pressed.connect(_on_how_to_play)

	# Achievements, leaderboard, settings gear — Android only (all require GPGS)
	var is_mobile: bool = OS.has_feature("android")
	_btn_settings.visible     = is_mobile
	_btn_achievements.visible = is_mobile
	_btn_leaderboard.visible  = is_mobile
	if is_mobile:
		_btn_settings.pressed.connect(_on_settings)
		_btn_joystick.pressed.connect(func(): _set_control("joystick"))
		_btn_tilt.pressed.connect(func(): _set_control("tilt"))
		_dim_bg.gui_input.connect(_on_dim_bg_input)
		_update_control_buttons()
		_btn_achievements.pressed.connect(_on_achievements)
		_btn_leaderboard.pressed.connect(_on_leaderboard)

	_control_panel.visible = false

func _start_button_animations() -> void:
	# Mirrors C++ RepeatForever ScaleTo sequence — scale=1.05, time_dt=1.3s
	# pivot_offset is set in .tscn so size is always correct
	_pulse_button(_btn_easy,   0.0)
	_pulse_button(_btn_normal, 1.3)
	_pulse_button(_btn_hard,   2.6)

	# "How to Play" wobbles — pivot set in .tscn
	var htw := create_tween().set_loops()
	htw.tween_property(_btn_how_to_play, "rotation_degrees", -2.0, 0.5)
	htw.tween_property(_btn_how_to_play, "rotation_degrees",  2.0, 0.5)

func _pulse_button(btn: TextureButton, delay: float) -> void:
	var tw := create_tween().set_loops()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.65)
	tw.tween_property(btn, "scale", Vector2(1.0,  1.0),  0.65)
	var idle: float = 3.9 - delay - 1.3
	if idle > 0.01:
		tw.tween_interval(idle)

func _on_level(level_name: String) -> void:
	if _disabled:
		return
	_disabled = true
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	_animate_hide()
	await get_tree().create_timer(HIDE_TIME + 0.1).timeout
	emit_signal("level_selected", level_name)
	queue_free()

func _on_sound() -> void:
	if _disabled:
		return
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	AudioManager.set_mute(!SaveManager.is_mute())
	_update_sound_btn()

func _on_how_to_play() -> void:
	if _disabled:
		return
	_disabled = true
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	_animate_hide()
	await get_tree().create_timer(HIDE_TIME + 0.1).timeout
	emit_signal("how_to_play_pressed")
	queue_free()

func _on_settings() -> void:
	if _disabled:
		return
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	_control_panel.visible = true

func _on_achievements() -> void:
	print("HomeScreen: _on_achievements pressed disabled=", _disabled)
	if _disabled:
		return
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	LeaderboardService.show_achievements()

func _on_leaderboard() -> void:
	print("HomeScreen: _on_leaderboard pressed disabled=", _disabled)
	if _disabled:
		return
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	LeaderboardService.show_all_leaderboards()

func _set_control(type: String) -> void:
	SaveManager.set_control_type(type)
	_update_control_buttons()
	_control_panel.visible = false

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_control_panel.visible = false
	elif event is InputEventScreenTouch and event.pressed:
		_control_panel.visible = false

func _update_sound_btn() -> void:
	if _btn_sound == null:
		return
	var mute: bool = SaveManager.is_mute()
	_btn_sound.texture_normal = load(
		"res://resources/assets/sound_off_off.png" if mute else "res://resources/assets/sound_on_off.png")
	_btn_sound.texture_pressed = load(
		"res://resources/assets/sound_off.png" if mute else "res://resources/assets/sound_on.png")

func _update_control_buttons() -> void:
	var current: String = SaveManager.get_control_type()
	_btn_joystick.modulate = Color(1.0, 1.0, 1.0, 1.0) if current == "joystick" else Color(0.45, 0.45, 0.45, 1.0)
	_btn_tilt.modulate     = Color(1.0, 1.0, 1.0, 1.0) if current == "tilt"     else Color(0.45, 0.45, 0.45, 1.0)

func _animate_hide() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var off_left  := Vector2(-1024.0 * 0.8, 0.0)
	var off_right := Vector2( 1024.0 * 0.8, 0.0)
	var left_nodes: Array = [_tablero, _btn_easy, _btn_normal, _btn_hard, _btn_sound, _btn_how_to_play]
	if _btn_settings.visible:
		left_nodes.append(_btn_settings)
	if _btn_achievements.visible:
		left_nodes.append(_btn_achievements)
	if _btn_leaderboard.visible:
		left_nodes.append(_btn_leaderboard)
	for node in left_nodes:
		if node:
			tween.tween_property(node, "position",
				node.position + off_left, HIDE_TIME)
	tween.tween_property(_logo, "position",
		_logo.position + off_right, HIDE_TIME)
