class_name ObstaclePool
extends RefCounted

# Godot equivalent of ObstaclePool<T> from ObstaclePool.hpp.
# Stores pre-instantiated obstacle nodes ready to reuse.

var _scene: PackedScene
var _parent: Node = null
var _free: Array = []   # Array[BaseObstacle]

func setup(scene: PackedScene, prefill_count: int, parent: Node) -> void:
	_scene = scene
	_parent = parent
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
	# Pool exhausted — grow on demand (mirrors C++ ObstaclePool::acquire `new T()`).
	# The instance MUST be parented: an obstacle that never enters the scene tree
	# never runs _ready(), so content_size stays ZERO and _local_rects stays empty
	# — it renders nothing, can never collide, still scores when it passes, and
	# poisons the free list for the rest of the session once recycled.
	push_warning("ObstaclePool: pool exhausted, allocating new instance")
	var extra: BaseObstacle = _scene.instantiate()
	if _parent == null:
		push_error("ObstaclePool: no parent set — call setup() before acquire()")
	else:
		_parent.add_child(extra)
	extra.visible = true
	return extra

func recycle(obj: BaseObstacle) -> void:
	obj.reset()
	obj.visible = false
	_free.push_back(obj)

func clear() -> void:
	for obj in _free:
		obj.queue_free()
	_free.clear()
