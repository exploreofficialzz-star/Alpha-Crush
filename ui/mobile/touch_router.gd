extends Node
class_name TouchRouter

## Hands each finger to exactly one on-screen control (first match in `targets`, in priority
## order) and keeps routing that finger's drags and release to the same control by touch index.
## Touches that start inside an open panel (`blockers`) or while `enabled` is false are left to
## Godot's normal GUI so ordinary buttons and sliders still work. With no touchscreen, the left
## mouse button acts as one finger so the HUD can be tried on a desktop.

const MOUSE_INDEX := 99

var targets: Array[TouchTarget] = []
var blockers: Array[Control] = []
var enabled := true:
    set(value):
        if enabled and not value:
            cancel_all()
        enabled = value
var _owners: Dictionary = {}

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        _on_touch(touch.index, touch.position, touch.pressed)
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        _on_move(drag.index, drag.position, drag.relative)
    elif not DisplayServer.is_touchscreen_available():
        if event is InputEventMouseButton:
            var button := event as InputEventMouseButton
            if button.button_index == MOUSE_BUTTON_LEFT:
                _on_touch(MOUSE_INDEX, button.position, button.pressed)
        elif event is InputEventMouseMotion:
            var motion := event as InputEventMouseMotion
            if _owners.has(MOUSE_INDEX):
                _on_move(MOUSE_INDEX, motion.position, motion.relative)

func _on_touch(index: int, pos: Vector2, pressed: bool) -> void:
    if pressed:
        if not enabled or _owners.has(index) or _is_blocked(pos):
            return
        for target in targets:
            if is_instance_valid(target) and target.is_visible_in_tree() and target.touch_hit(pos):
                _owners[index] = target
                target.touch_down(index, pos)
                get_viewport().set_input_as_handled()
                return
    elif _owners.has(index):
        var owner_node := _owners[index] as TouchTarget
        _owners.erase(index)
        if is_instance_valid(owner_node):
            owner_node.touch_up(index, pos)
        get_viewport().set_input_as_handled()

func _on_move(index: int, pos: Vector2, relative: Vector2) -> void:
    if not _owners.has(index):
        return
    var owner_node := _owners[index] as TouchTarget
    if is_instance_valid(owner_node):
        owner_node.touch_move(index, pos, relative)
    get_viewport().set_input_as_handled()

func _is_blocked(pos: Vector2) -> bool:
    for blocker in blockers:
        if is_instance_valid(blocker) and blocker.is_visible_in_tree() and blocker.get_global_rect().has_point(pos):
            return true
    return false

func cancel_all() -> void:
    for index in _owners.keys():
        var owner_node := _owners[index] as TouchTarget
        if is_instance_valid(owner_node):
            owner_node.touch_cancel()
    _owners.clear()

func active_touches() -> int:
    return _owners.size()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        cancel_all()
