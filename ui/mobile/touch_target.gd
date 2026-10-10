extends Control
class_name TouchTarget

## Base for on-screen controls that are driven by TouchRouter instead of Godot's GUI input.
## GUI delivery of multi-touch is unreliable (only the first finger is emulated as a mouse, and
## drags of later fingers are routed by position), which makes "hold the stick and tap a button"
## fail on real phones. Positions passed in are canvas (viewport) coordinates.

func touch_hit(pos: Vector2) -> bool:
    return get_global_rect().has_point(pos)

func touch_down(_index: int, _pos: Vector2) -> void:
    pass

func touch_move(_index: int, _pos: Vector2, _relative: Vector2) -> void:
    pass

func touch_up(_index: int, _pos: Vector2) -> void:
    pass

func touch_cancel() -> void:
    pass

## Centre of this control in canvas coordinates.
func canvas_center() -> Vector2:
    return global_position + size * 0.5
