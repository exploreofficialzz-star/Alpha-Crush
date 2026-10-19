extends Control
class_name CrosshairView

## The aiming reticle (turns red while an enemy is locked) plus the hit marker that flashes when a shot connects:
## a white X for a hit, a bigger red X for a kill, gold for a headshot.
const MARKER_SECONDS := 0.22

var locked := false
var _marker := 0.0
var _kill := false
var _headshot := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_hit(kill: bool, headshot: bool) -> void:
    _marker = MARKER_SECONDS
    _kill = kill
    _headshot = headshot
    set_process(true)
    queue_redraw()

func set_locked(value: bool) -> void:
    if value != locked:
        locked = value
        queue_redraw()

func _process(delta: float) -> void:
    if _marker > 0.0:
        _marker = maxf(0.0, _marker - delta)
        queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    var color := Color(1.0, 0.4, 0.35, 0.95) if locked else Color(1, 1, 1, 0.85)
    var gap := 9.0
    var length := 11.0
    for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
        var d: Vector2 = direction
        draw_line(c + d * gap, c + d * (gap + length), Color(0.03, 0.07, 0.2, 0.7), 5.0)
        draw_line(c + d * gap, c + d * (gap + length), color, 3.0)
    draw_circle(c, 2.5, color)
    if locked:
        draw_arc(c, 24.0, 0.0, TAU, 28, Color(1.0, 0.4, 0.35, 0.55), 2.0, true)
    if _marker > 0.0:
        var fade := _marker / MARKER_SECONDS
        var tint := Color(1, 1, 1, fade)
        var reach := 14.0
        if _kill:
            tint = Color(1.0, 0.3, 0.25, fade)
            reach = 22.0
        if _headshot:
            tint = Color(1.0, 0.85, 0.2, fade)
            reach = 24.0
        for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
            var v: Vector2 = corner
            draw_line(c + v * 8.0, c + v * reach, tint, 4.0)
