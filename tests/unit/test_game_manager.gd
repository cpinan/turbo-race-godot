extends GutTest

# Tests for GameManager OBSTACLE_TABLE and map cycling logic.
# Does not require a full scene — tests data and pure-logic portions only.

func test_obstacle_table_size() -> void:
	assert_eq(GameManager.OBSTACLE_TABLE.size(), 10,
		"OBSTACLE_TABLE has entries for map codes 0-9")

func test_map_code_0_is_single_bot() -> void:
	var def: Dictionary = GameManager.OBSTACLE_TABLE[0]
	assert_eq(def["kind"], GameManager.SpawnKind.SINGLE)
	assert_eq(def["lane"], GameManager.LanePos.BOT_SIMPLE)
	assert_eq(def["count"], 1)

func test_map_code_3_is_air_single() -> void:
	var def: Dictionary = GameManager.OBSTACLE_TABLE[3]
	assert_eq(def["kind"], GameManager.SpawnKind.AIR)
	assert_eq(def["lane"], GameManager.LanePos.DOUBLE_AIR)
	assert_eq(def["count"], 1)

func test_map_code_4_is_x2_single_bot() -> void:
	var def: Dictionary = GameManager.OBSTACLE_TABLE[4]
	assert_eq(def["count"], 2)
	assert_almost_eq(def["dt"], 1.5, 0.001, "x2 single bottom has dt_factor 1.5")

func test_map_code_6_is_x3_ground() -> void:
	var def: Dictionary = GameManager.OBSTACLE_TABLE[6]
	assert_eq(def["kind"], GameManager.SpawnKind.GROUND)
	assert_eq(def["count"], 3)

func test_map_code_9_is_x2_air() -> void:
	var def: Dictionary = GameManager.OBSTACLE_TABLE[9]
	assert_eq(def["kind"], GameManager.SpawnKind.AIR)
	assert_eq(def["count"], 2)

func test_world_speed_advances() -> void:
	# Direct test of WorldSpeed.advance via GameManager
	var speed_before: float = 512.0
	var next: float = WorldSpeed.advance(speed_before, 2.0, 1200.0, 1.0)
	assert_almost_eq(next, 514.0, 0.001)

func test_world_speed_caps() -> void:
	var next: float = WorldSpeed.advance(1199.0, 2.0, 1200.0, 1.0)
	assert_almost_eq(next, 1200.0, 0.001)
