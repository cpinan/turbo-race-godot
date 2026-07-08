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

	# Position labels relative to badge per PopUpLoseLayer.cpp:
	# score at (badge.width*0.5, -badge.height*0.1) from BG center → just right of badge center, slightly below
	# best  at score.y - badge.height*0.28 further down
	var bx: float = _badge.offset_left
	var br: float = _badge.offset_right
	var bb: float = _badge.offset_bottom
	var bw: float = br - bx
	var row_h: float = 36.0
	_score_label.offset_left  = bx
	_score_label.offset_right = bx + bw + 80.0  # extend right of badge
	_score_label.offset_top   = bb + 4.0
	_score_label.offset_bottom = bb + 4.0 + row_h
	_score_label.rotation_degrees = -3.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_best_label.offset_left  = bx
	_best_label.offset_right = bx + bw + 80.0
	_best_label.offset_top   = bb + 4.0 + row_h + 6.0
	_best_label.offset_bottom = bb + 4.0 + row_h + 6.0 + row_h
	_best_label.rotation_degrees = -3.0
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

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
