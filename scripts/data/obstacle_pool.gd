class_name ObstaclePool
extends RefCounted

# Godot equivalent of ObstaclePool<T> from ObstaclePool.hpp.
# Stores pre-instantiated obstacle nodes ready to reuse.

var _scene: PackedScene
var _free: Array = []   # Array[BaseObstacle]

func setup(scene: PackedScene, prefill_count: int, parent: Node) -> void:
	_scene = scene
	for _i in range(prefill_count):
		var obj: BaseObstacle = _scene.instantiate()
		parent.add_child(obj)
		obj.visible = false
		_free.push_back(obj)

func acquire() -> BaseObstacle:
	if not _free.is_empty():
		var obj: BaseObstacle = _free.pop_back()
		obj.visible = true
		return obj
	# Pool exhausted — instantiate on demand (should not happen in steady state)
	push_warning("ObstaclePool: pool exhausted, allocating new instance")
	return _scene.instantiate()

func recycle(obj: BaseObstacle) -> void:
	obj.reset()
	obj.visible = false
	_free.push_back(obj)

func clear() -> void:
	for obj in _free:
		obj.queue_free()
	_free.clear()
