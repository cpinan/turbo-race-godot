class_name LevelData
extends RefCounted

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------
const CURRENT_SCHEMA_VERSION: int = 1

# Source: LevelLoader.hpp LevelData struct
var schema_version: int        = CURRENT_SCHEMA_VERSION
var speed_multiplier: float    = 1.0
var distance_multiplier: float = 1.0
var speed_acceleration: float  = 2.0
var max_world_speed: float     = 0.0   # 0 = uncapped
var map: Array                 = []

# ---------------------------------------------------------------------------
# Validation errors
# ---------------------------------------------------------------------------
enum ValidationError {
	OK = 0,
	FILE_NOT_FOUND,
	JSON_PARSE_ERROR,
	MISSING_SCHEMA_VERSION,
	UNSUPPORTED_SCHEMA_VERSION,
	INVALID_MAP,
	INVALID_MAP_VALUE,
}

# ---------------------------------------------------------------------------
# Load from res:// (built-in levels)
# Source: TurboRace::loadLevel()
# ---------------------------------------------------------------------------
static func load_level(level_name: String) -> LevelData:
	var path := "res://resources/levels/%s.json" % level_name
	return _load_path(path)

# ---------------------------------------------------------------------------
# Load from user:// (external authored levels)
# Phase 4: external level loading without rebuild
# ---------------------------------------------------------------------------
static func load_external(path: String) -> LevelData:
	return _load_path(path)

# ---------------------------------------------------------------------------
# Internal loader — shared by both paths
# ---------------------------------------------------------------------------
static func _load_path(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return null

	var err: int = _validate(parsed)
	if err != ValidationError.OK:
		return null

	return _parse(parsed)

# ---------------------------------------------------------------------------
# Validation — returns ValidationError
# ---------------------------------------------------------------------------
static func _validate(d: Dictionary) -> int:
	if not d.has("schemaVersion"):
		return ValidationError.MISSING_SCHEMA_VERSION

	var sv: Variant = d["schemaVersion"]
	if not (sv is int or sv is float):
		return ValidationError.MISSING_SCHEMA_VERSION
	if int(sv) != CURRENT_SCHEMA_VERSION:
		return ValidationError.UNSUPPORTED_SCHEMA_VERSION

	if not d.has("map"):
		return ValidationError.INVALID_MAP
	if not (d["map"] is Array):
		return ValidationError.INVALID_MAP
	for v in d["map"]:
		if not (v is int or v is float):
			return ValidationError.INVALID_MAP_VALUE
		if int(v) < 0 or int(v) > 9:
			return ValidationError.INVALID_MAP_VALUE

	return ValidationError.OK

# Expose for tests
static func validate(d: Dictionary) -> int:
	return _validate(d)

# ---------------------------------------------------------------------------
# Parse after validation
# ---------------------------------------------------------------------------
static func _parse(d: Dictionary) -> LevelData:
	var data := LevelData.new()
	data.schema_version = int(d.get("schemaVersion", CURRENT_SCHEMA_VERSION))

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
