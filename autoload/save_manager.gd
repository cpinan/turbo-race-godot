extends Node
# Autoload: SaveManager
# Mirrors LocalStorageManager — persists best scores, mute state, control type.

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
