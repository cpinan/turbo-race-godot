extends Node
# Root scene controller — manages transitions: Home → Game → GameOver/Pause → …
# Mirrors the HomeScene/GameLayer orchestration from C++.

@onready var _game_scene:   GameScene      = $GameScene
@onready var _hud:          HUD            = $HUD
@onready var _pause_screen: PauseScreen    = $PauseScreen
@onready var _game_over:    GameOverScreen = $GameOverScreen

var _current_level: String = "easy"
var _show_tutorial: bool   = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			get_tree().quit()

func _ready() -> void:
	_show_home()

	_hud.pause_pressed.connect(_on_pause)
	_pause_screen.resume_pressed.connect(_on_resume)
	_pause_screen.restart_pressed.connect(func(): _restart())
	_pause_screen.home_pressed.connect(func(): _go_home())
	_game_over.restart_pressed.connect(func(): _restart())
	_game_over.home_pressed.connect(func(): _go_home())
	GameManager.game_over.connect(_on_game_over)
	_game_scene.entrance_done.connect(_on_entrance_done)

func _show_home() -> void:
	_hud.hide_hud()
	_game_scene.reset_for_home()
	AudioManager.stop_music()
	AdManager.on_home_screen_shown()

	var home_scene: PackedScene = load("res://scenes/ui/home_screen.tscn")
	var home: HomeScreen = home_scene.instantiate()
	add_child(home)
	home.level_selected.connect(_on_level_selected)
	home.how_to_play_pressed.connect(_on_how_to_play)

func _on_level_selected(level_name: String) -> void:
	_show_tutorial = false
	_current_level = level_name
	AdManager.hide_banner()
	_game_scene.restart(level_name)
	_hud.show_hud()
	var track: String = AudioManager.play_music()
	if not track.is_empty():
		_hud.show_song_label(track)

func _on_how_to_play() -> void:
	_show_tutorial = true
	_current_level = "easy"
	_game_scene.restart("easy")
	_hud.show_hud()
	var track: String = AudioManager.play_music()
	if not track.is_empty():
		_hud.show_song_label(track)

func _on_entrance_done() -> void:
	if _show_tutorial:
		_show_tutorial = false
		var overlay_scene: PackedScene = load("res://scenes/ui/tutorial_overlay.tscn")
		var overlay: TutorialOverlay = overlay_scene.instantiate()
		add_child(overlay)
		overlay.dismissed.connect(func():
			GameManager.set_state(GameManager.GameState.READY))
	else:
		GameManager.set_state(GameManager.GameState.READY)

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
	var track: String = AudioManager.play_music()
	if not track.is_empty():
		_hud.show_song_label(track)

func _go_home() -> void:
	_pause_screen.hide_pause()
	_game_over.hide()
	_show_home()

func _on_game_over() -> void:
	AudioManager.stop_music()
	await get_tree().create_timer(1.5).timeout
	var score: GameScore = ScoreModel.current_score()
	var score_val:  int  = score.total_score()
	var avoided:    int  = score.obstacles_avoided
	var jumped:     int  = score.obstacles_jumped
	var used_tilt:  bool = OS.has_feature("android") and SaveManager.get_control_type() == "tilt"

	SaveManager.record_game_result(score_val, jumped)
	LeaderboardService.submit_score_for_level(_current_level, score_val)
	AchievementChecker.check(_current_level, score_val, avoided, used_tilt)
	AdManager.try_show_interstitial()
	ReviewService.maybe_request_review()

	_game_over.show_result(_current_level, score)
