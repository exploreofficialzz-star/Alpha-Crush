extends Control
class_name DamageArrows

## Red wedges around the crosshair that point towards whoever just hurt the player. Direction is relative to where the camera looks.
const LIFE := 1.1
const RING_RADIUS := 128.0

var _marks: Array[Dictionary] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)

## `screen_angle`: 0 = straight ahead, positive = clockwise (to the right), in radians.
func add_hit(screen_angle: float) -> void:
    _marks.append({"angle": screen_angle, "life": LIFE})
    if _marks.size() > 6:
        _marks.pop_front()
    set_process(true)
    queue_redraw()

func clear_all() -> void:
    _marks.clear()
    set_process(false)
    queue_redraw()

func _process(delta: float) -> void:
    var index := _marks.size() - 1
    while index >= 0:
        _marks[index]["life"] = float(_marks[index]["life"]) - delta
        if float(_marks[index]["life"]) <= 0.0:
            _marks.remove_at(index)
        index -= 1
    if _marks.is_empty():
        set_process(false)
    queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    for mark in _marks:
        var fade := clampf(float(mark["life"]) / LIFE, 0.0, 1.0)
        var base := float(mark["angle"]) - PI * 0.5
        draw_arc(c, RING_RADIUS, base - 0.32, base + 0.32, 12, Color(0.03, 0.0, 0.0, 0.55 * fade), 20.0, true)
        draw_arc(c, RING_RADIUS, base - 0.28, base + 0.28, 12, Color(1.0, 0.18, 0.15, 0.95 * fade), 14.0, true)
