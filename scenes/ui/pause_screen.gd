class_name PauseScreen
extends CanvasLayer

# Mirrors PauseLayer.cpp — semi-transparent overlay with resume/restart/home.

signal resume_pressed
signal restart_pressed
signal home_pressed

@onready var _btn_resume:  TextureButton = $BG/BtnResume
@onready var _btn_restart: TextureButton = $BG/BtnRestart
@onready var _btn_home:    TextureButton = $BG/BtnHome

func _ready() -> void:
	_btn_resume.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		emit_signal("resume_pressed"))
	_btn_restart.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		emit_signal("restart_pressed"))
	_btn_home.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		emit_signal("home_pressed"))
	hide()

func show_pause() -> void:
	show()

func hide_pause() -> void:
	hide()
