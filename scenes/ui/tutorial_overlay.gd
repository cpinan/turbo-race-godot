class_name TutorialOverlay
extends CanvasLayer

# Mirrors GameLayer::_showTutorial (joystick-only).
# Tap anywhere to dismiss → main_controller sets GameState::READY.

signal dismissed

func _ready() -> void:
	var tap: Sprite2D = $Root/TapSprite

	# Bounce tap.png — MoveBy(0.5s, Vec2(0,-9)) → MoveBy(0.5s, Vec2(0,9))
	var tw := create_tween().set_loops()
	tw.tween_property(tap, "position:y", tap.position.y - 9.0, 0.5)
	tw.tween_property(tap, "position:y", tap.position.y + 9.0, 0.5)

	# Wobble "Tap here to continue" — pivot set in .tscn
	var btn: Button = $Root/BtnContinue
	var bw := create_tween().set_loops()
	bw.tween_property(btn, "rotation_degrees", -2.0, 0.5)
	bw.tween_property(btn, "rotation_degrees",  2.0, 0.5)

	# Root Control (mouse_filter=STOP) catches any tap anywhere to dismiss.
	$Root.gui_input.connect(_on_root_input)

func _on_root_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
	if pressed:
		emit_signal("dismissed")
		queue_free()
