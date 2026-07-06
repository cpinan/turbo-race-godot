extends GutTest

# Tests for LevelData schema validation (Phase 4).

# ---------------------------------------------------------------------------
# Valid cases
# ---------------------------------------------------------------------------

func test_schema_version_constant() -> void:
	assert_eq(LevelData.CURRENT_SCHEMA_VERSION, 1,
		"current schema version is 1")

func test_valid_full_document() -> void:
	var d := {
		"schemaVersion": 1,
		"speedMultiplier": 1.0,
		"distanceMultiplier": 2.0,
		"speedAcceleration": 2.0,
		"maxWorldSpeed": 1200.0,
		"map": [0, 1, 2, 3]
	}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.OK,
		"valid doc → OK")

func test_valid_minimal_document() -> void:
	# Only schemaVersion and map are required; other fields fall back to defaults
	var d := {"schemaVersion": 1, "map": [0]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.OK,
		"minimal valid doc → OK")

func test_easy_json_validates() -> void:
	var data: LevelData = LevelData.load_level("easy")
	assert_not_null(data, "easy.json loads after adding schemaVersion")
	assert_eq(data.schema_version, 1)

func test_all_levels_validate() -> void:
	for name in ["easy", "normal", "hard", "story"]:
		var d: LevelData = LevelData.load_level(name)
		assert_not_null(d, "%s.json validates" % name)

# ---------------------------------------------------------------------------
# Missing / wrong schema version
# ---------------------------------------------------------------------------

func test_missing_schema_version() -> void:
	var d := {"speedMultiplier": 1.0, "map": [0]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.MISSING_SCHEMA_VERSION,
		"missing schemaVersion → error")

func test_wrong_schema_version() -> void:
	var d := {"schemaVersion": 99, "map": [0]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.UNSUPPORTED_SCHEMA_VERSION,
		"schemaVersion=99 → unsupported")

func test_schema_version_zero() -> void:
	var d := {"schemaVersion": 0, "map": [0]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.UNSUPPORTED_SCHEMA_VERSION,
		"schemaVersion=0 → unsupported")

# ---------------------------------------------------------------------------
# Invalid map
# ---------------------------------------------------------------------------

func test_missing_map() -> void:
	var d := {"schemaVersion": 1}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.INVALID_MAP,
		"missing map → error")

func test_map_not_array() -> void:
	var d := {"schemaVersion": 1, "map": "not an array"}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.INVALID_MAP,
		"map as string → error")

func test_map_value_too_high() -> void:
	var d := {"schemaVersion": 1, "map": [0, 5, 10]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.INVALID_MAP_VALUE,
		"map value 10 > 9 → error")

func test_map_value_negative() -> void:
	var d := {"schemaVersion": 1, "map": [-1, 0, 1]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.INVALID_MAP_VALUE,
		"negative map value → error")

func test_map_all_valid_codes() -> void:
	var d := {"schemaVersion": 1, "map": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]}
	assert_eq(LevelData.validate(d), LevelData.ValidationError.OK,
		"all valid codes [0-9] → OK")

# ---------------------------------------------------------------------------
# Extension: WideObstacle collision rects don't modify base classes
# ---------------------------------------------------------------------------

func test_wide_obstacle_uses_base_physics() -> void:
	# Prove WideObstacle.collision delegates to ObstaclePhysics.base_collision
	# without any changes to BaseObstacle or ObstaclePhysics.
	var size := Vector2(80, 60)
	var rects: Array = WideObstacle._build_rects(size)
	assert_eq(rects.size(), 1, "WideObstacle has 1 collision rect")
	var r: Rect2 = rects[0]
	assert_almost_eq(r.size.x, size.x * 0.8, 0.001, "width = 80% of sprite width")
	assert_almost_eq(r.size.y, size.y * 0.25, 0.001, "height = 25% of sprite height")

func test_wide_obstacle_type_is_jump() -> void:
	# WideObstacle is ObstacleType.JUMP so player must jump over it
	# (same routing as DoubleObstacle in the pool)
	var obs := WideObstacle.new()
	obs._init_obstacle(Vector2(80, 60))
	assert_eq(obs.obstacle_type, BaseObstacle.ObstacleType.JUMP,
		"WideObstacle is JUMP type — player must jump")
	obs.free()
