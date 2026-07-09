class_name HomeScreen
extends CanvasLayer

# Mirrors HomeLayer.cpp
# Shows logo, level buttons (easy/normal/hard), sound toggle, how-to-play.

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

func _start_button_animations() -> void:
	# Mirrors C++ RepeatForever ScaleTo sequence — scale=1.05, time_dt=1.3s
	# Each button pulses in sequence with 1.3s offset
	_pulse_button(_btn_easy,   0.0)
	_pulse_button(_btn_normal, 1.3)
	_pulse_button(_btn_hard,   2.6)

	# Set pivot to center for each button
	for btn in [_btn_easy, _btn_normal, _btn_hard]:
		var b := btn as TextureButton
		b.pivot_offset = b.size * 0.5

	# "How to Play" wobbles like in C++ — RotateTo(-2°) ↔ RotateTo(2°)
	var htw := create_tween().set_loops()
	htw.tween_property(_btn_how_to_play, "rotation_degrees", -2.0, 0.5)
	htw.tween_property(_btn_how_to_play, "rotation_degrees",  2.0, 0.5)
	_btn_how_to_play.pivot_offset = _btn_how_to_play.size * 0.5

func _pulse_button(btn: TextureButton, delay: float) -> void:
	var tw := create_tween().set_loops()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.65)
	tw.tween_property(btn, "scale", Vector2(1.0,  1.0),  0.65)
	tw.tween_interval(3.9 - delay - 1.3)

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

func _update_sound_btn() -> void:
	if _btn_sound == null:
		return
	var mute: bool = SaveManager.is_mute()
	_btn_sound.texture_normal = load(
		"res://resources/assets/sound_off_off.png" if mute else "res://resources/assets/sound_on_off.png")
	_btn_sound.texture_pressed = load(
		"res://resources/assets/sound_off.png" if mute else "res://resources/assets/sound_on.png")

func _animate_hide() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var off_left  := Vector2(-1024.0 * 0.8, 0.0)
	var off_right := Vector2( 1024.0 * 0.8, 0.0)
	for node in [_tablero, _btn_easy, _btn_normal, _btn_hard, _btn_sound, _btn_how_to_play]:
		if node:
			tween.tween_property(node, "position",
				node.position + off_left, HIDE_TIME)
	tween.tween_property(_logo, "position",
		_logo.position + off_right, HIDE_TIME)
