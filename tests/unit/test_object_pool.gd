extends RefCounted
class_name TestObjectPool

static func run() -> bool:
    var holder := Node.new()
    var scene := PackedScene.new()
    var template := Node3D.new()
    template.name = "PooledThing"
    scene.pack(template)
    template.free()
    var pool: ObjectPool = preload("res://core/pooling/object_pool.gd").new()
    pool.setup(scene, holder, 0)
    # Regression: a node created because the pool was empty used to be tracked as both available and
    # active, so the next acquire() handed out the very same node twice.
    var first: Node = pool.acquire()
    var second: Node = pool.acquire()
    var distinct: bool = first != null and second != null and first != second and pool.active.size() == 2 and pool.available.is_empty()
    pool.release(first)
    var reused: Node = pool.acquire()
    var recycled: bool = reused == first and pool.active.size() == 2
    pool.release(second)
    pool.release(second)  # double release must not duplicate the node in the free list
    var no_dupes: bool = pool.available.size() == 1
    holder.free()
    pool.free()
    return distinct and recycled and no_dupes
