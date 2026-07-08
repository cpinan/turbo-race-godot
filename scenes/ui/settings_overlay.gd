class_name SettingsOverlay
extends Control

# Mirrors SettingsLayer.cpp — joypad vs tilt control picker.

const ALPHA_INACTIVE: float = 100.0 / 255.0

@onready var _btn_joypad: TextureButton = $BG/BtnJoypad
@onready var _btn_tilt:   TextureButton = $BG/BtnTilt
@onready var _btn_home:   TextureButton = $BG/BtnHome

func _ready() -> void:
	_btn_joypad.pressed.connect(func(): _select(true))
	_btn_tilt.pressed.connect(func():   _select(false))
	_btn_home.pressed.connect(_close)
	_refresh()

func _select(joypad: bool) -> void:
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	SaveManager.set_control_type(joypad)
	_refresh()

func _refresh() -> void:
	var joypad: bool = SaveManager.is_using_joypad()
	_btn_joypad.modulate.a = 1.0 if joypad else ALPHA_INACTIVE
	_btn_tilt.modulate.a   = ALPHA_INACTIVE if joypad else 1.0

func _close() -> void:
	AudioManager.play_sfx(AudioManager.SFX_BUTTON)
	visible = false
	var home: HomeScreen = get_parent() as HomeScreen
	if home:
		home.resume_from_settings()
