extends Control
class_name AlphaCrushVirtualJoystick

signal input_changed(value: Vector2)
@export var radius := 72.0
@export var deadzone := 0.12
var touch_id := -1
var value := Vector2.ZERO
var knob: ColorRect

func _ready() -> void:
    custom_minimum_size = Vector2(radius * 2.3, radius * 2.3)
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and touch_id == -1:
            touch_id = touch.index
            _set_from_position(touch.position)
            accept_event()
        elif not touch.pressed and touch.index == touch_id:
            touch_id = -1
            value = Vector2.ZERO
            input_changed.emit(value)
            queue_redraw()
            accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == touch_id:
            _set_from_position(drag.position)
            accept_event()

func _set_from_position(pos: Vector2) -> void:
    # Events delivered to _gui_input are already in this control's local space, so the
    # position must not be offset by global_position a second time.
    var center := size * 0.5
    var offset := (pos - center) / radius
    if offset.length() > 1.0:
        offset = offset.normalized()
    if offset.length() < deadzone:
        offset = Vector2.ZERO
    value = offset
    input_changed.emit(value)
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    draw_circle(center, radius, Color(0.03, 0.08, 0.12, 0.28))
    draw_circle(center + value * radius * 0.68, radius * 0.35, Color(0.95, 0.83, 0.35, 0.72))
