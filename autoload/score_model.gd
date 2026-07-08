extends Node
# Autoload: ScoreModel
# Wraps GameScore data and exposes signals for UI.

signal score_changed(new_score: int)
signal reset_done

var _data: GameScore = GameScore.new()

func get_total_score() -> int:
	return _data.total_score()

func get_obstacles_avoided() -> int:
	return _data.obstacles_avoided

func get_obstacles_jumped() -> int:
	return _data.obstacles_jumped

func add_avoided(is_jump_type: bool) -> void:
	_data.obstacles_avoided += 1
	if is_jump_type:
		_data.obstacles_jumped += 1
	emit_signal("score_changed", _data.total_score())

func reset() -> void:
	_data.reset()
	emit_signal("reset_done")

func current_score() -> GameScore:
	return _data
