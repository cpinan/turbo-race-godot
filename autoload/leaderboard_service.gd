extends Node
# Autoload: LeaderboardService
# Platform-agnostic interface for Google Play Game Services.
# Uses GodotPlayGameServices plugin (v3.2.0) via GodotPlayGameServices.android_plugin.
# All calls are fire-and-forget — a failure must never block gameplay.

# ---------------------------------------------------------------------------
# Leaderboard IDs (Android — from Constants.h)
# ---------------------------------------------------------------------------
const LEAD_EASY_MODE:   String = "CgkIyb_B9_4ZEAIQAg"
const LEAD_NORMAL_MODE: String = "CgkIyb_B9_4ZEAIQAw"
const LEAD_HARD_MODE:   String = "CgkIyb_B9_4ZEAIQBA"

# ---------------------------------------------------------------------------
# Achievement IDs (Android — from Constants.h)
# ---------------------------------------------------------------------------
const ACH_MORE_THAN_3000:            String = "CgkIyb_B9_4ZEAIQBQ"
const ACH_PLAY_10_TIMES:             String = "CgkIyb_B9_4ZEAIQCg"
const ACH_PLAY_100_TIMES:            String = "CgkIyb_B9_4ZEAIQCQ"
const ACH_PLAY_1000_TIMES:           String = "CgkIyb_B9_4ZEAIQCw"
const ACH_AVOID_25_IN_HARD:          String = "CgkIyb_B9_4ZEAIQBg"
const ACH_AVOID_50_IN_NORMAL:        String = "CgkIyb_B9_4ZEAIQBw"
const ACH_AVOID_100_IN_EASY:         String = "CgkIyb_B9_4ZEAIQCA"
const ACH_JUMP_50:                   String = "CgkIyb_B9_4ZEAIQDA"
const ACH_JUMP_1000:                 String = "CgkIyb_B9_4ZEAIQFg"
const ACH_GET_10000_EASY:            String = "CgkIyb_B9_4ZEAIQDQ"
const ACH_GET_8000_NORMAL:           String = "CgkIyb_B9_4ZEAIQDg"
const ACH_GET_5000_HARD:             String = "CgkIyb_B9_4ZEAIQDw"
const ACH_GET_30K_EASY:              String = "CgkIyb_B9_4ZEAIQGw"
const ACH_GET_15K_NORMAL:            String = "CgkIyb_B9_4ZEAIQHA"
const ACH_GET_10K_HARD:              String = "CgkIyb_B9_4ZEAIQHQ"
const ACH_AVOID_100_HARD:            String = "CgkIyb_B9_4ZEAIQFw"
const ACH_ACCELEROMETER:             String = "CgkIyb_B9_4ZEAIQEg"
const ACH_ACCELEROMETER_3000:        String = "CgkIyb_B9_4ZEAIQEw"
const ACH_AVERAGE_1000_IN_50_GAMES:  String = "CgkIyb_B9_4ZEAIQEA"
const ACH_TOTAL_SCORE_100000:        String = "CgkIyb_B9_4ZEAIQEQ"

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _signed_in: bool  = false
var _plugin:    Object = null   # GodotPlayGameServices.android_plugin once ready

signal signed_in
signal sign_in_failed

func _ready() -> void:
	if not OS.has_feature("android"):
		return
	var err: int = GodotPlayGameServices.initialize()
	if err != GodotPlayGameServices.PlayGamesPluginError.OK:
		printerr("LeaderboardService: GPGS plugin not found")
		return
	_plugin = GodotPlayGameServices.android_plugin
	_plugin.userAuthenticated.connect(_on_authenticated)
	_plugin.isAuthenticated()   # triggers sign-in popup / check

func _on_authenticated(ok: bool) -> void:
	_signed_in = ok
	if ok:
		emit_signal("signed_in")
	else:
		emit_signal("sign_in_failed")

# ---------------------------------------------------------------------------
# Score submission — call every game-over; GPGS deduplicates if not a new high.
# Source: GameLayer leaderboard submit (was stubbed in C++, now completed).
# ---------------------------------------------------------------------------

func submit_score(leaderboard_id: String, score: int) -> void:
	if _plugin == null or not _signed_in:
		return
	_plugin.submitScore(leaderboard_id, score)

func submit_score_for_level(level_name: String, score: int) -> void:
	var lid: String = _leaderboard_id_for_level(level_name)
	if lid.is_empty():
		return
	submit_score(lid, score)

# ---------------------------------------------------------------------------
# Achievement unlock — guard against re-submission handled by AchievementChecker
# ---------------------------------------------------------------------------

func unlock_achievement(id: String) -> void:
	if _plugin == null or not _signed_in:
		return
	_plugin.unlockAchievement(id)

# ---------------------------------------------------------------------------
# UI overlays — new, never existed in C++ (buttons were commented out)
# ---------------------------------------------------------------------------

func show_achievements() -> void:
	if _plugin == null or not _signed_in:
		return
	_plugin.showAchievements()

func show_leaderboard_for_level(level_name: String) -> void:
	if _plugin == null or not _signed_in:
		return
	var lid: String = _leaderboard_id_for_level(level_name)
	if lid.is_empty():
		_plugin.showAllLeaderboards()
	else:
		_plugin.showLeaderboard(lid)

func show_all_leaderboards() -> void:
	if _plugin == null or not _signed_in:
		return
	_plugin.showAllLeaderboards()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func is_signed_in() -> bool:
	return _signed_in

func is_available() -> bool:
	return _plugin != null

func _leaderboard_id_for_level(level_name: String) -> String:
	match level_name:
		"easy":   return LEAD_EASY_MODE
		"normal": return LEAD_NORMAL_MODE
		"hard":   return LEAD_HARD_MODE
		_:        return ""
