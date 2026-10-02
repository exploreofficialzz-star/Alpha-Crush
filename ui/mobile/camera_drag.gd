extends Control
class_name CameraDrag

var player: Node
var touch_id := -1

func setup(local_player: Node) -> void:
    player = local_player
    mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and touch_id == -1:
            touch_id = touch.index
            accept_event()
        elif not touch.pressed and touch.index == touch_id:
            touch_id = -1
            accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index != touch_id:
            return
        if player and player.has_method("nudge_camera"):
            player.nudge_camera(drag.relative)
        accept_event()
