extends Node
class_name ObjectPool

var scene: PackedScene
var available: Array[Node] = []
var active: Array[Node] = []
var parent_node: Node

func setup(resource: PackedScene, parent: Node, warm_count: int = 0) -> void:
    scene = resource
    parent_node = parent
    for i in range(warm_count):
        _create_available()

func _instantiate() -> Node:
    if scene == null or parent_node == null:
        return null
    var node: Node = scene.instantiate()
    parent_node.add_child(node)
    return node

func _create_available() -> Node:
    var node: Node = _instantiate()
    if node == null:
        return null
    node.process_mode = Node.PROCESS_MODE_DISABLED
    available.append(node)
    return node

func acquire() -> Node:
    var node: Node = null
    if not available.is_empty():
        node = available.pop_back()
    else:
        # A freshly built node goes straight to `active`; it must not also sit in
        # `available`, or the next acquire() would hand out the same node twice.
        node = _instantiate()
    if node == null:
        return null
    node.process_mode = Node.PROCESS_MODE_INHERIT
    active.append(node)
    return node

func release(node: Node) -> void:
    if not is_instance_valid(node):
        return
    active.erase(node)
    if available.has(node):
        return
    node.process_mode = Node.PROCESS_MODE_DISABLED
    available.append(node)
