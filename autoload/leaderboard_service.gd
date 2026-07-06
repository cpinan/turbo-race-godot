extends Node
# Autoload: LeaderboardService
#
# Platform-agnostic interface for Google Play Game Services.
# On Android with the plugin loaded: delegates to GodotPlayGameServices.
# On any other platform (or if plugin unavailable): no-ops silently.
# A leaderboard or sign-in failure MUST NEVER block gameplay.
#
# Source: Constants.h achievement/leaderboard IDs

# ---------------------------------------------------------------------------
# Leaderboard IDs (Android — from Constants.h)
# ---------------------------------------------------------------------------
const LEAD_EASY_MODE:   String = "CgkIyb_B9_4ZEAIQAg"
const LEAD_NORMAL_MODE: String = "CgkIyb_B9_4ZEAIQAw"
const LEAD_HARD_MODE:   String = "CgkIyb_B9_4ZEAIQBA"

# Achievement IDs (Android — from Constants.h)
const ACH_MORE_THAN_3000:                   String = "CgkIyb_B9_4ZEAIQBQ"
const ACH_PLAY_10_TIMES:                    String = "CgkIyb_B9_4ZEAIQCg"
const ACH_PLAY_100_TIMES:                   String = "CgkIyb_B9_4ZEAIQCQ"
const ACH_PLAY_1000_TIMES:                  String = "CgkIyb_B9_4ZEAIQCw"
const ACH_AVOID_25_IN_HARD:                 String = "CgkIyb_B9_4ZEAIQBg"
const ACH_AVOID_50_IN_NORMAL:               String = "CgkIyb_B9_4ZEAIQBw"
const ACH_AVOID_100_IN_EASY:                String = "CgkIyb_B9_4ZEAIQCA"
const ACH_JUMP_50:                          String = "CgkIyb_B9_4ZEAIQDA"
const ACH_JUMP_1000:                        String = "CgkIyb_B9_4ZEAIQFg"
const ACH_GET_10000_EASY:                   String = "CgkIyb_B9_4ZEAIQDQ"
const ACH_GET_8000_NORMAL:                  String = "CgkIyb_B9_4ZEAIQDg"
const ACH_GET_5000_HARD:                    String = "CgkIyb_B9_4ZEAIQDw"
const ACH_GET_30K_EASY:                     String = "CgkIyb_B9_4ZEAIQGw"
const ACH_GET_15K_NORMAL:                   String = "CgkIyb_B9_4ZEAIQHA"
const ACH_GET_10K_HARD:                     String = "CgkIyb_B9_4ZEAIQHQ"
const ACH_AVOID_100_HARD:                   String = "CgkIyb_B9_4ZEAIQFw"
const ACH_ACCELEROMETER:                    String = "CgkIyb_B9_4ZEAIQEg"
const ACH_ACCELEROMETER_3000:              String = "CgkIyb_B9_4ZEAIQEw"
const ACH_AVERAGE_1000_IN_50_GAMES:        String = "CgkIyb_B9_4ZEAIQEA"
const ACH_TOTAL_SCORE_100000:              String = "CgkIyb_B9_4ZEAIQEQ"

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _signed_in: bool = false
var _available: bool = false   # true only when plugin singleton exists

signal signed_in
signal sign_in_failed

func _ready() -> void:
	_available = Engine.has_singleton("GodotPlayGameServices")
	if _available:
		_try_sign_in()

# ---------------------------------------------------------------------------
# Sign-in
# ---------------------------------------------------------------------------

func _try_sign_in() -> void:
	if not _available:
		return
	var plugin = Engine.get_singleton("GodotPlayGameServices")
	if plugin.has_signal("user_authenticated"):
		plugin.user_authenticated.connect(_on_signed_in)
	if plugin.has_method("initialize"):
		plugin.initialize()

func _on_signed_in(is_authenticated: bool) -> void:
	_signed_in = is_authenticated
	if is_authenticated:
		emit_signal("signed_in")
	else:
		emit_signal("sign_in_failed")

# ---------------------------------------------------------------------------
# Score submission
# Source: GameLayer::_checkAchievements → leaderboard submit
# Fails silently — never blocks gameplay.
# ---------------------------------------------------------------------------

func submit_score(leaderboard_id: String, score: int) -> void:
	if not _available or not _signed_in:
		return
	var plugin = Engine.get_singleton("GodotPlayGameServices")
	if plugin.has_method("submitScore"):
		plugin.submitScore(leaderboard_id, score)

func submit_score_for_level(level_name: String, score: int) -> void:
	var lid: String = _leaderboard_id_for_level(level_name)
	if lid.is_empty():
		return
	submit_score(lid, score)

func _leaderboard_id_for_level(level_name: String) -> String:
	match level_name:
		"easy":   return LEAD_EASY_MODE
		"normal": return LEAD_NORMAL_MODE
		"hard":   return LEAD_HARD_MODE
		_:        return ""

# ---------------------------------------------------------------------------
# Achievement unlock
# Source: GameLayer::_checkAchievements
# ---------------------------------------------------------------------------

func unlock_achievement(ach_id: String) -> void:
	if not _available or not _signed_in:
		return
	var plugin = Engine.get_singleton("GodotPlayGameServices")
	if plugin.has_method("unlockAchievement"):
		plugin.unlockAchievement(ach_id)

# ---------------------------------------------------------------------------
# Public availability checks
# ---------------------------------------------------------------------------

func is_available() -> bool:
	return _available

func is_signed_in() -> bool:
	return _signed_in
