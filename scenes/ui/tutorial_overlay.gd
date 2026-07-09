class_name TutorialOverlay
extends CanvasLayer

# Mirrors GameLayer::_showTutorial — joystick-only version (tilt removed).
# Shows on top of game during PREPARING state; dismisses to READY.

signal dismissed

@onready var _tap_sprite: Sprite2D = $TapSprite

func _ready() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_tap_sprite, "position:y", _tap_sprite.position.y + 9.0, 0.5)
	tw.tween_property(_tap_sprite, "position:y", _tap_sprite.position.y - 9.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
	if pressed:
		emit_signal("dismissed")
		queue_free()
