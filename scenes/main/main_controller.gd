extends Node
# Root scene controller — manages transitions: Home → Game → GameOver/Pause → …
# Mirrors the HomeScene/GameLayer orchestration from C++.

@onready var _game_scene:   GameScene      = $GameScene
@onready var _hud:          HUD            = $HUD
@onready var _pause_screen: PauseScreen    = $PauseScreen
@onready var _game_over:    GameOverScreen = $GameOverScreen

var _current_level: String = "easy"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()

func _ready() -> void:
	# Show home screen on launch
	_show_home()

	# Wire HUD
	_hud.pause_pressed.connect(_on_pause)

	# Wire pause screen
	_pause_screen.resume_pressed.connect(_on_resume)
	_pause_screen.restart_pressed.connect(func(): _restart())
	_pause_screen.home_pressed.connect(func(): _go_home())

	# Wire game over
	_game_over.restart_pressed.connect(func(): _restart())
	_game_over.home_pressed.connect(func(): _go_home())

	# Wire GameManager game_over signal
	GameManager.game_over.connect(_on_game_over)

func _show_home() -> void:
	_hud.hide_hud()
	_game_scene.reset_for_home()
	AudioManager.stop_music()

	var home_scene: PackedScene = load("res://scenes/ui/home_screen.tscn")
	var home: HomeScreen = home_scene.instantiate()
	add_child(home)
	home.level_selected.connect(_on_level_selected)

func _on_level_selected(level_name: String) -> void:
	_current_level = level_name
	_game_scene.restart(level_name)
	_hud.show_hud()
	AudioManager.play_music()

func _on_pause() -> void:
	_game_scene.pause()
	_pause_screen.show_pause()

func _on_resume() -> void:
	_pause_screen.hide_pause()
	_game_scene.resume()

func _restart() -> void:
	_pause_screen.hide_pause()
	_game_over.hide()
	_game_scene.restart(_current_level)
	AudioManager.play_music()

func _go_home() -> void:
	_pause_screen.hide_pause()
	_game_over.hide()
	_show_home()

func _on_game_over() -> void:
	AudioManager.stop_music()
	var score: GameScore = ScoreModel.current_score()
	_game_over.show_result(_current_level, score)
