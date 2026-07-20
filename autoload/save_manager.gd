extends Node
# Autoload: SaveManager
# Mirrors LocalStorageManager — persists best scores, mute state, control type,
# cumulative stats, and local achievement unlock state.

const SAVE_PATH: String = "user://save.cfg"

var _cfg: ConfigFile

func _ready() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(SAVE_PATH)  # no-op if file doesn't exist

# ---------------------------------------------------------------------------
# Mute
# ---------------------------------------------------------------------------

func is_mute() -> bool:
	return _cfg.get_value("audio", "mute", false)

func set_mute(v: bool) -> void:
	_cfg.set_value("audio", "mute", v)
	_cfg.save(SAVE_PATH)

# ---------------------------------------------------------------------------
# Best score per level
# ---------------------------------------------------------------------------

func get_best_score(level_name: String) -> int:
	return _cfg.get_value("scores", level_name, 0)

func set_best_score(level_name: String, score: int) -> bool:
	if score > get_best_score(level_name):
		_cfg.set_value("scores", level_name, score)
		_cfg.save(SAVE_PATH)
		return true
	return false

# ---------------------------------------------------------------------------
# Control type: "joystick" (default) or "tilt"
# ---------------------------------------------------------------------------

func get_control_type() -> String:
	return _cfg.get_value("controls", "type", "joystick")

func set_control_type(v: String) -> void:
	_cfg.set_value("controls", "type", v)
	_cfg.save(SAVE_PATH)

# ---------------------------------------------------------------------------
# Cumulative stats — mirrors LocalStorageManager USER_TOTAL_* keys
# ---------------------------------------------------------------------------

func get_total_games_played() -> int:
	return _cfg.get_value("stats", "total_games_played", 0)

func get_total_score() -> int:
	return _cfg.get_value("stats", "total_score", 0)

func get_total_obstacles_jumped() -> int:
	return _cfg.get_value("stats", "total_obstacles_jumped", 0)

func get_average_score() -> float:
	var games: int = get_total_games_played()
	if games == 0:
		return 0.0
	return float(get_total_score()) / float(games)

# Called once per game-over. Updates all cumulative stats in one save.
func record_game_result(score: int, obstacles_jumped: int) -> void:
	_cfg.set_value("stats", "total_games_played",     get_total_games_played() + 1)
	_cfg.set_value("stats", "total_score",            get_total_score() + score)
	_cfg.set_value("stats", "total_obstacles_jumped", get_total_obstacles_jumped() + obstacles_jumped)
	_cfg.save(SAVE_PATH)

# ---------------------------------------------------------------------------
# Achievement local state — mirrors LocalStorageManager::isAchievementUnlocked
# Keys are the raw GPGS achievement IDs (user_data_id was always "" in C++).
# ---------------------------------------------------------------------------

func is_achievement_unlocked(id: String) -> bool:
	return _cfg.get_value("achievements", id, false)

func mark_achievement_unlocked(id: String) -> void:
	_cfg.set_value("achievements", id, true)
	_cfg.save(SAVE_PATH)

# ---------------------------------------------------------------------------
# In-app review — prompt at most once ever (ReviewService gates on this flag)
# ---------------------------------------------------------------------------

func was_review_prompted() -> bool:
	return _cfg.get_value("stats", "review_prompted", false)

func mark_review_prompted() -> void:
	_cfg.set_value("stats", "review_prompted", true)
	_cfg.save(SAVE_PATH)
