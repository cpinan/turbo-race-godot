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
	_build_play_cta()
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

	# Portal builds only, and only every Nth run — WebPortal rate-limits and
	# no-ops off the web, so this is a single feature check on Android.
	WebPortal.request_break_ad()


# ---------------------------------------------------------------------------
# "Get it on Google Play" CTA — web builds on our own channels only.
#
# Built in code rather than in game_over_screen.tscn because it must not exist
# at all on Android (where the player is already in the app) or on a portal
# build (CrazyGames and GameDistribution both restrict outbound links, see
# docs/WEB_PORTALS.md §4). A scene node would have to be hidden in three of the
# four build targets.
# ---------------------------------------------------------------------------

func _build_play_cta() -> void:
	if not WebPortal.show_play_cta():
		return

	var btn := Button.new()
	btn.name = "PlayStoreCTA"
	btn.text = "▶  Get the full game on Google Play"
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Sits just below the game-over panel (BG ends at y=624 in the 1024x768
	# viewport), so it never overlaps the Home/Restart buttons.
	btn.offset_left   = 262.0
	btn.offset_top    = 638.0
	btn.offset_right  = 762.0
	btn.offset_bottom = 694.0

	btn.add_theme_font_override("font", load("res://resources/fonts/Carton_Six.ttf"))
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.95, 0.85))

	btn.add_theme_stylebox_override("normal", _cta_style(Color(0.18, 0.60, 0.24)))
	btn.add_theme_stylebox_override("hover", _cta_style(Color(0.22, 0.70, 0.29)))
	btn.add_theme_stylebox_override("pressed", _cta_style(Color(0.14, 0.48, 0.19)))

	btn.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		WebPortal.open_play_store())

	add_child(btn)


func _cta_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.35)
	return sb
