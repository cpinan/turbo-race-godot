class_name LaneLayout
extends RefCounted

# Source: LayoutUtils.hpp LaneLayout::compute
var player_start_y: float  = 0.0
var wall_height: float     = 0.0
var simple_bot_y: float    = 0.0
var simple_top_y: float    = 0.0
var double_ground_y: float = 0.0
var double_air_y: float    = 0.0

# Compute lane positions from floor sprite dimensions.
# Source: LaneLayout::compute(trackHeight, trackOffsetY)
static func compute(track_height: float, track_offset_y: float) -> LaneLayout:
	var l := LaneLayout.new()
	l.player_start_y  = track_height * 0.55 + track_offset_y
	l.wall_height     = track_height * 0.25
	l.simple_bot_y    = l.player_start_y + l.wall_height * 0.85
	l.double_ground_y = l.player_start_y + l.wall_height * 0.70
	l.simple_top_y    = l.player_start_y + l.wall_height * 1.55
	l.double_air_y    = l.player_start_y + l.wall_height * 1.80
	return l
