class_name GameOverScreen
extends CanvasLayer

# Mirrors PopUpLoseLayer.cpp
# Score format: "N = obstacles x 100"
# Saves + shows best score per level. Updates badge sprite on new record.

signal restart_pressed
signal home_pressed

@onready var _badge:       TextureRect = $BG/Badge
@onready var _score_label: Label       = $BG/ScoreLabel
@onready var _best_label:  Label       = $BG/BestLabel
@onready var _btn_home:    TextureButton = $BG/BtnHome
@onready var _btn_restart: TextureButton = $BG/BtnRestart

var _tex_normal: Texture2D
var _tex_record: Texture2D

func _ready() -> void:
	_tex_normal = load("res://resources/assets/bicho_0004.png")
	_tex_record = load("res://resources/assets/bicho_0003.png")
	_btn_home.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		emit_signal("home_pressed"))
	_btn_restart.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		emit_signal("restart_pressed"))
	hide()

func show_result(level_name: String, score: GameScore) -> void:
	var total: int     = score.total_score()
	var avoided: int   = score.obstacles_avoided
	_score_label.text  = "%d = %d x %d" % [total, avoided, GameScore.K_SCORE_FACTOR]

	var is_record: bool = SaveManager.set_best_score(level_name, total)
	var best: int       = SaveManager.get_best_score(level_name)
	_best_label.text    = str(best)
	_badge.texture      = _tex_record if is_record else _tex_normal

	show()
