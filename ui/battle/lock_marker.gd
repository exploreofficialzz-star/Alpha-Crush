extends Control
class_name LockMarker

## Four red corner brackets that sit on top of the enemy the aim assist has locked.
var pulse := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(54, 54)
    size = Vector2(54, 54)
    set_process(true)

func _process(delta: float) -> void:
    pulse += delta
    if visible:
        queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    var reach := 22.0 + sin(pulse * 8.0) * 2.0
    var arm := 11.0
    var color := Color(1.0, 0.35, 0.3, 0.95)
    for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
        var v: Vector2 = corner
        var tip := c + v * reach
        draw_line(tip, tip - Vector2(v.x * arm, 0.0), Color(0.05, 0.0, 0.0, 0.7), 6.0)
        draw_line(tip, tip - Vector2(0.0, v.y * arm), Color(0.05, 0.0, 0.0, 0.7), 6.0)
        draw_line(tip, tip - Vector2(v.x * arm, 0.0), color, 3.5)
        draw_line(tip, tip - Vector2(0.0, v.y * arm), color, 3.5)
