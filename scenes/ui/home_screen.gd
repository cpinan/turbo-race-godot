class_name HomeScreen
extends CanvasLayer

# Mirrors HomeLayer.cpp
# Shows logo, level buttons (easy/normal/hard), sound toggle, settings.

signal level_selected(level_name: String)

const HIDE_TIME: float = 0.4

var _disabled: bool = false

@onready var _logo:         TextureRect = $Logo
@onready var _tablero:      TextureRect = $Tablero
@onready var _btn_easy:     TextureButton = $Menu/BtnEasy
@onready var _btn_normal:   TextureButton = $Menu/BtnNormal
@onready var _btn_hard:     TextureButton = $Menu/BtnHard
@onready var _btn_sound:    TextureButton = $Menu/BtnSound
@onready var _btn_settings: TextureButton = $Menu/BtnSettings
@onready var _settings_overlay: Control = $SettingsOverlay

func _ready() -> void:
	# Logo slides in from left
	_logo.position.x = -_logo.size.x * 1.2
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(_logo, "position:x", 1024.0 * 0.65 - _logo.size.x * 0.5, 0.9)

	# Sound toggle state
	_update_sound_btn()

	_btn_easy.pressed.connect(func(): _on_level("easy"))
	_btn_normal.pressed.connect(func(): _on_level("normal"))
	_btn_hard.pressed.connect(func(): _on_level("hard"))
	_btn_sound.pressed.connect(_on_sound)
	_btn_settings.pressed.connect(_on_settings)

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

func _on_settings() -> void:
	if _disabled:
		return
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	_settings_overlay.visible = true
	_disabled = true

func resume_from_settings() -> void:
	_settings_overlay.visible = false
	_disabled = false

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
	for node in [_tablero, _btn_easy, _btn_normal, _btn_hard, _btn_sound]:
		if node:
			tween.tween_property(node, "position",
				node.position + off_left, HIDE_TIME)
	for node in [_btn_settings, _logo]:
		if node:
			tween.tween_property(node, "position",
				node.position + off_right, HIDE_TIME)
