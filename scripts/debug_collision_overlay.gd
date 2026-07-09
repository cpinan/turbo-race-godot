extends Node2D
# Child of GameScene with z_index=1000 — draws collision rects on top of all sprites.
# Coordinate space is identical to parent (Y-up, inherited transform).

var game_scene: GameScene = null

func _draw() -> void:
	if not game_scene:
		return
	var player: BaseVehicle = game_scene._player
	if player:
		draw_rect(player.get_ground_collision(), Color(0.0, 1.0, 0.0, 1.0), false, 3.0)
		draw_rect(player.get_air_collision(),    Color(0.0, 1.0, 1.0, 1.0), false, 3.0)
	for obs: BaseObstacle in game_scene._obstacles:
		for r: Rect2 in obs.get_world_rects():
			draw_rect(r, Color(1.0, 0.2, 0.0, 1.0), false, 3.0)
