extends TouchTarget
class_name CameraDrag

## Swipe anywhere that is not a button or the stick to look around. It is the lowest-priority
## touch target, so it covers the left and middle of the screen.
signal dragged(relative: Vector2)

var player: Node
var touch_id := -1

func setup(local_player: Node) -> void:
    player = local_player
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func touch_down(index: int, _pos: Vector2) -> void:
    touch_id = index

func touch_move(index: int, _pos: Vector2, relative: Vector2) -> void:
    if index != touch_id:
        return
    if player and player.has_method("nudge_camera"):
        player.nudge_camera(relative)
    dragged.emit(relative)

func touch_up(index: int, _pos: Vector2) -> void:
    if index == touch_id:
        touch_id = -1

func touch_cancel() -> void:
    touch_id = -1
