extends Node
# Autoload: LevelLoader
# Caches loaded LevelData per level name.

var _cache: Dictionary = {}

func load(level_name: String) -> LevelData:
	if _cache.has(level_name):
		return _cache[level_name]
	var data: LevelData = LevelData.load_level(level_name)
	if data != null:
		_cache[level_name] = data
	return data

func clear_cache() -> void:
	_cache.clear()
