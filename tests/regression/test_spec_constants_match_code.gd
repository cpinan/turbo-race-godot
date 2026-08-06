extends GutTest

# ---------------------------------------------------------------------------
# Spec-vs-code guard.
#
# The hitbox regression that shipped in 1.0.0 and the level-map redesign that
# shipped in 1.1.0 had the same root cause: the values in code drifted away
# from docs/SPEC.md (which is derived from the Cocos2d-x source), and the unit
# tests were rewritten to assert the drifted values. CI then certified the
# divergence green for three releases.
#
# These tests read SPEC.md at runtime and fail if the numbers in the document
# and the numbers in the physics layer disagree — in either direction. Editing
# one without the other is now a test failure, so the drift cannot be silent.
#
# SPEC.md is a port artefact, not prose: if a value here genuinely needs to
# change, the C++ source is the authority and both files change together.
# ---------------------------------------------------------------------------

const SPEC_PATH: String = "res://docs/SPEC.md"

var _spec: String = ""

func before_all() -> void:
	var f: FileAccess = FileAccess.open(SPEC_PATH, FileAccess.READ)
	assert_not_null(f, "docs/SPEC.md is readable — it is the parity authority")
	if f != null:
		_spec = f.get_as_text()
		f.close()

# Pull the fenced code block that follows a given "### Heading".
func _section(heading: String) -> String:
	var at: int = _spec.find(heading)
	if at < 0:
		return ""
	var open_fence: int = _spec.find("```", at)
	if open_fence < 0:
		return ""
	var start: int = open_fence + 3
	var close_fence: int = _spec.find("```", start)
	if close_fence < 0:
		return ""
	return _spec.substr(start, close_fence - start)

# Read `<field> = ... * <number>` out of a spec block.
func _factor(block: String, field: String) -> float:
	for raw_line in block.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with(field):
			continue
		# Trailing prose after the expression (e.g. "← uses WIDTH") is ignored.
		var star: int = line.rfind("*")
		if star < 0:
			continue
		var tail: String = line.substr(star + 1).strip_edges()
		var num: String = ""
		for ch in tail:
			if ch.is_valid_int() or ch == ".":
				num += ch
			else:
				break
		if num.is_valid_float():
			return num.to_float()
	return NAN

# ---------------------------------------------------------------------------
# §5 Collision Rectangles
# ---------------------------------------------------------------------------

func test_spec_declares_ground_rect_factors() -> void:
	var block: String = _section("### Player — Ground Collision")
	assert_ne(block, "", "SPEC.md still has a 'Player — Ground Collision' section")
	assert_almost_eq(_factor(block, "x"), VehiclePhysics.RECT_X_INSET, 0.0001,
		"SPEC.md ground-rect x inset matches VehiclePhysics.RECT_X_INSET")
	assert_almost_eq(_factor(block, "width"), VehiclePhysics.RECT_WIDTH, 0.0001,
		"SPEC.md ground-rect width matches VehiclePhysics.RECT_WIDTH")

func test_spec_declares_air_rect_factors() -> void:
	var block: String = _section("### Player — Air Collision")
	assert_ne(block, "", "SPEC.md still has a 'Player — Air Collision' section")
	assert_almost_eq(_factor(block, "x"), VehiclePhysics.RECT_X_INSET, 0.0001,
		"SPEC.md air-rect x inset matches VehiclePhysics.RECT_X_INSET")
	assert_almost_eq(_factor(block, "width"), VehiclePhysics.RECT_WIDTH, 0.0001,
		"SPEC.md air-rect width matches VehiclePhysics.RECT_WIDTH")

func test_code_rects_use_the_spec_factors() -> void:
	# Guards against the constants being right while a call site hard-codes
	# something else.
	var w: float = 175.0
	var h: float = 128.0
	var g: Rect2 = VehiclePhysics.ground_collision_rect(400.0, 210.0, w, h)
	var a: Rect2 = VehiclePhysics.air_collision_rect(400.0, 274.0, w, h)
	assert_almost_eq(g.position.x, 400.0 - w * 0.5 + w * VehiclePhysics.RECT_X_INSET, 0.001,
		"ground_collision_rect uses RECT_X_INSET")
	assert_almost_eq(g.size.x, w * VehiclePhysics.RECT_WIDTH, 0.001,
		"ground_collision_rect uses RECT_WIDTH")
	assert_almost_eq(a.position.x, 400.0 - w * 0.5 + w * VehiclePhysics.RECT_X_INSET, 0.001,
		"air_collision_rect uses RECT_X_INSET")
	assert_almost_eq(a.size.x, w * VehiclePhysics.RECT_WIDTH, 0.001,
		"air_collision_rect uses RECT_WIDTH")

# ---------------------------------------------------------------------------
# §2 Jump Physics
# ---------------------------------------------------------------------------

func test_spec_declares_jump_constants() -> void:
	assert_true(_spec.contains("MAX_PLAYER_JUMP        = 140.0f"),
		"SPEC.md still declares MAX_PLAYER_JUMP = 140")
	assert_true(_spec.contains("JUMP_DURATION          = 0.6f"),
		"SPEC.md still declares JUMP_DURATION = 0.6")
	assert_almost_eq(VehiclePhysics.MAX_PLAYER_JUMP, 140.0, 0.001, "code agrees")
	assert_almost_eq(VehiclePhysics.JUMP_DURATION, 0.6, 0.001, "code agrees")

func test_spec_and_code_agree_the_arc_is_parabolic() -> void:
	# SPEC.md §2 says "a parabolic Y trajectory". Cocos2d-x JumpBy::update is
	# `_height * 4 * frac * (1 - frac)`. A sine arc satisfies the endpoints and
	# the peak but not the quarter point — that is what 1.0.0 shipped.
	assert_true(_spec.contains("parabolic"),
		"SPEC.md still describes the jump arc as parabolic")
	assert_almost_eq(VehiclePhysics.jump_arc_offset(0.25),
		VehiclePhysics.MAX_PLAYER_JUMP * 0.75, 0.001,
		"jump_arc_offset is the parabola, not sin(PI*t) (which gives 0.7071)")

# ---------------------------------------------------------------------------
# Level content — maps are ported, not authored
# ---------------------------------------------------------------------------

func test_level_maps_are_the_ported_length() -> void:
	# All four Cocos2d-x level maps are 133 entries. A map of any other length
	# means level content was authored rather than ported; that is a decision
	# to record in MIGRATION_NOTES.md, not a silent edit.
	for level_name in ["easy", "normal", "hard", "story"]:
		var d: LevelData = LevelData.load_level(level_name)
		assert_not_null(d, "%s.json loads" % level_name)
		if d != null:
			assert_eq(d.map.size(), 133,
				"%s map is the ported 133-entry C++ map" % level_name)

func test_level_multipliers_match_cpp() -> void:
	# Values from Resources/levels/*.json in the Cocos2d-x repo.
	var expected: Dictionary = {
		"easy":   {"speed": 1.0, "dist": 2.0, "accel": 2.0, "max": 1200.0},
		"normal": {"speed": 1.7, "dist": 1.3, "accel": 2.0, "max": 1400.0},
		"hard":   {"speed": 2.2, "dist": 1.0, "accel": 2.0, "max": 1600.0},
		"story":  {"speed": 1.5, "dist": 1.6, "accel": 1.5, "max": 1000.0},
	}
	for level_name in expected:
		var e: Dictionary = expected[level_name]
		var d: LevelData = LevelData.load_level(level_name)
		if d == null:
			continue
		assert_almost_eq(d.speed_multiplier, e["speed"], 0.001,
			"%s speedMultiplier" % level_name)
		assert_almost_eq(d.distance_multiplier, e["dist"], 0.001,
			"%s distanceMultiplier" % level_name)
		assert_almost_eq(d.speed_acceleration, e["accel"], 0.001,
			"%s speedAcceleration" % level_name)
		assert_almost_eq(d.max_world_speed, e["max"], 0.001,
			"%s maxWorldSpeed" % level_name)
