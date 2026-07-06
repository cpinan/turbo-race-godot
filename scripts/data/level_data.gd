class_name LevelData
extends RefCounted

# Source: LevelLoader.hpp LevelData struct
var speed_multiplier: float    = 1.0
var distance_multiplier: float = 1.0
var speed_acceleration: float  = 2.0
var max_world_speed: float     = 0.0   # 0 = uncapped; no current level uses 0
var map: Array                 = []

# Load from JSON file. Returns null on parse failure.
# Source: TurboRace::loadLevel()
static func load_level(level_name: String) -> LevelData:
	var path := "res://resources/levels/%s.json" % level_name
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return null

	var d: Dictionary = parsed
	var data := LevelData.new()

	if d.has("speedMultiplier"):
		data.speed_multiplier = float(d["speedMultiplier"])
	if d.has("distanceMultiplier"):
		data.distance_multiplier = float(d["distanceMultiplier"])
	if d.has("speedAcceleration"):
		data.speed_acceleration = float(d["speedAcceleration"])
	if d.has("maxWorldSpeed"):
		data.max_world_speed = float(d["maxWorldSpeed"])
	if d.has("map") and d["map"] is Array:
		data.map = d["map"].duplicate()

	return data
