extends GutTest

# Tests for LevelData.load_level — valid file parsing and field values.
# Source: LevelLoader.hpp, Resources/levels/*.json

func test_easy_speed_multiplier() -> void:
	var d: LevelData = LevelData.load_level("easy")
	assert_not_null(d, "easy.json loaded")
	assert_almost_eq(d.speed_multiplier, 1.0, 0.001)

func test_easy_distance_multiplier() -> void:
	var d: LevelData = LevelData.load_level("easy")
	assert_almost_eq(d.distance_multiplier, 2.0, 0.001)

func test_easy_speed_acceleration() -> void:
	var d: LevelData = LevelData.load_level("easy")
	assert_almost_eq(d.speed_acceleration, 2.0, 0.001)

func test_easy_max_world_speed() -> void:
	var d: LevelData = LevelData.load_level("easy")
	assert_almost_eq(d.max_world_speed, 1200.0, 0.001)

func test_easy_map_size() -> void:
	var d: LevelData = LevelData.load_level("easy")
	assert_eq(d.map.size(), 665, "easy map has 665 entries")

func test_normal_speed_multiplier() -> void:
	var d: LevelData = LevelData.load_level("normal")
	assert_almost_eq(d.speed_multiplier, 1.7, 0.001)

func test_normal_distance_multiplier() -> void:
	var d: LevelData = LevelData.load_level("normal")
	assert_almost_eq(d.distance_multiplier, 1.3, 0.001)

func test_normal_max_world_speed() -> void:
	var d: LevelData = LevelData.load_level("normal")
	assert_almost_eq(d.max_world_speed, 1400.0, 0.001)

func test_hard_speed_multiplier() -> void:
	var d: LevelData = LevelData.load_level("hard")
	assert_almost_eq(d.speed_multiplier, 2.2, 0.001)

func test_hard_max_world_speed() -> void:
	var d: LevelData = LevelData.load_level("hard")
	assert_almost_eq(d.max_world_speed, 1600.0, 0.001)

func test_story_speed_acceleration() -> void:
	var d: LevelData = LevelData.load_level("story")
	assert_almost_eq(d.speed_acceleration, 1.5, 0.001,
		"Story uses 1.5 acceleration (others use 2.0)")

func test_story_max_world_speed() -> void:
	var d: LevelData = LevelData.load_level("story")
	assert_almost_eq(d.max_world_speed, 1000.0, 0.001)

func test_map_values_in_range() -> void:
	for level_name in ["easy", "normal", "hard", "story"]:
		var d: LevelData = LevelData.load_level(level_name)
		for v in d.map:
			assert_true(v >= 0 and v <= 9,
				"%s: map value %d out of [0,9] range" % [level_name, v])

func test_invalid_level_returns_null() -> void:
	var d: LevelData = LevelData.load_level("nonexistent")
	assert_null(d, "nonexistent level returns null")
