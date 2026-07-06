class_name GameScore
extends RefCounted

# Source: Constants.h
const K_SCORE_FACTOR: float = 100.0

var obstacles_avoided: int = 0
var obstacles_jumped: int  = 0

func total_score() -> int:
	return int(obstacles_avoided * K_SCORE_FACTOR)

func reset() -> void:
	obstacles_avoided = 0
	obstacles_jumped  = 0
