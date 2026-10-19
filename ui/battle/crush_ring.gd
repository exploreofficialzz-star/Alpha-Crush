extends Control
class_name CrushRing

## Orange progress ring drawn around the CRUSH button; it flashes when the meter is full.
var fraction := 0.0:
    set(value):
        fraction = clampf(value, 0.0, 1.0)
        queue_redraw()
var inner_radius := 62.0
var _time := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func _process(delta: float) -> void:
    _time += delta
    if fraction >= 0.999:
        queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    var radius := inner_radius + 12.0
    draw_arc(c, radius, 0.0, TAU, 48, Color(0.03, 0.07, 0.2, 0.55), 10.0, true)
    if fraction <= 0.001:
        return
    var color := Color(1.0, 0.6, 0.15, 1.0)
    if fraction >= 0.999:
        var pulse := 0.5 + 0.5 * sin(_time * 8.0)
        color = Color(1.0, 0.85, 0.3, 0.7 + 0.3 * pulse)
        draw_arc(c, radius + 6.0 + pulse * 6.0, 0.0, TAU, 48, Color(1.0, 0.8, 0.3, 0.35 * (1.0 - pulse)), 6.0, true)
    draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 48, color, 8.0, true)
