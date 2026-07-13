extends Node
# Autoload: AchievementChecker
# Ports GameLayer::_checkAchievements() exactly.
# Reads cumulative stats from SaveManager (already updated by record_game_result
# before this is called), evaluates all 20 rules, and submits newly unlocked
# achievements to LeaderboardService. Never blocks gameplay — all GPGS calls
# are fire-and-forget.

func check(level_name: String, score: int, avoided: int, used_tilt: bool) -> void:
	var jumped: int = SaveManager.get_total_obstacles_jumped()
	var games:  int = SaveManager.get_total_games_played()
	var avg:   float = SaveManager.get_average_score()
	var total:  int = SaveManager.get_total_score()

	# Obstacles avoided per level
	_try(LeaderboardService.ACH_AVOID_100_IN_EASY,  level_name == "easy"   and avoided >= 100)
	_try(LeaderboardService.ACH_AVOID_50_IN_NORMAL, level_name == "normal" and avoided >= 50)
	_try(LeaderboardService.ACH_AVOID_25_IN_HARD,   level_name == "hard"   and avoided >= 25)
	_try(LeaderboardService.ACH_AVOID_100_HARD,     level_name == "hard"   and avoided >= 100)

	# Score any level
	_try(LeaderboardService.ACH_MORE_THAN_3000, score >= 3001)

	# Score per level
	_try(LeaderboardService.ACH_GET_10000_EASY,   level_name == "easy"   and score >= 10000)
	_try(LeaderboardService.ACH_GET_30K_EASY,     level_name == "easy"   and score >= 30000)
	_try(LeaderboardService.ACH_GET_8000_NORMAL,  level_name == "normal" and score >= 8000)
	_try(LeaderboardService.ACH_GET_15K_NORMAL,   level_name == "normal" and score >= 15000)
	_try(LeaderboardService.ACH_GET_5000_HARD,    level_name == "hard"   and score >= 5000)
	_try(LeaderboardService.ACH_GET_10K_HARD,     level_name == "hard"   and score >= 10000)

	# Play count milestones
	_try(LeaderboardService.ACH_PLAY_10_TIMES,   games >= 10)
	_try(LeaderboardService.ACH_PLAY_100_TIMES,  games >= 100)
	_try(LeaderboardService.ACH_PLAY_1000_TIMES, games >= 1000)

	# Cumulative jump milestones
	_try(LeaderboardService.ACH_JUMP_50,   jumped >= 50)
	_try(LeaderboardService.ACH_JUMP_1000, jumped >= 1000)

	# Tilt/accelerometer mode
	_try(LeaderboardService.ACH_ACCELEROMETER,      used_tilt)
	_try(LeaderboardService.ACH_ACCELEROMETER_3000, used_tilt and score >= 3000)

	# Cumulative stat achievements
	_try(LeaderboardService.ACH_AVERAGE_1000_IN_50_GAMES, games >= 50 and avg >= 1000.0)
	_try(LeaderboardService.ACH_TOTAL_SCORE_100000,       total >= 100000)

func _try(id: String, condition: bool) -> void:
	if not condition:
		return
	if SaveManager.is_achievement_unlocked(id):
		return
	SaveManager.mark_achievement_unlocked(id)
	LeaderboardService.unlock_achievement(id)
