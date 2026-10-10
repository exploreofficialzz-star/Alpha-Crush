extends TouchTarget
class_name AlphaCrushVirtualJoystick

## Floating move stick for the right thumb. The control is a big touch ZONE; the stick appears
## wherever the thumb lands inside it and the base follows if the thumb drifts, so a small child
## never "slides off". While idle a ghost ring with four arrows shows where to put the thumb.
signal input_changed(value: Vector2)

@export var radius := 96.0
@export var knob_radius := 46.0
@export var deadzone := 0.14

var touch_id := -1
var value := Vector2.ZERO
var mirrored := false
var attention := false:
    set(new_value):
        attention = new_value
        set_process(new_value)
        queue_redraw()
var _active := false
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _time := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_mode = Control.FOCUS_NONE
    resized.connect(queue_redraw)
    set_process(attention)

func is_active() -> bool:
    return _active

## Where the idle ghost sits, in canvas coordinates (the tutorial hand points here).
func rest_canvas_position() -> Vector2:
    return global_position + _rest_local()

func _rest_local() -> Vector2:
    var margin := radius + 34.0
    var x := margin if mirrored else size.x - margin
    return Vector2(x, size.y - margin)

func touch_down(index: int, pos: Vector2) -> void:
    touch_id = index
    _active = true
    _origin = _clamp_origin(pos - global_position)
    _knob = Vector2.ZERO
    KidUI.buzz(8)
    _update(pos - global_position)

func touch_move(index: int, pos: Vector2, _relative: Vector2) -> void:
    if index == touch_id:
        _update(pos - global_position)

func touch_up(index: int, _pos: Vector2) -> void:
    if index == touch_id:
        _release()

func touch_cancel() -> void:
    _release()

func _release() -> void:
    touch_id = -1
    _active = false
    _knob = Vector2.ZERO
    value = Vector2.ZERO
    input_changed.emit(value)
    queue_redraw()

func _clamp_origin(p: Vector2) -> Vector2:
    if size.x < radius * 2.0 or size.y < radius * 2.0:
        return p
    return Vector2(clampf(p.x, radius, size.x - radius), clampf(p.y, radius, size.y - radius))

func _update(local_pos: Vector2) -> void:
    var offset := local_pos - _origin
    var length := offset.length()
    if length > radius:
        # The base follows a drifting thumb instead of letting it fall off the edge.
        _origin = _clamp_origin(_origin + offset.normalized() * (length - radius))
        offset = local_pos - _origin
        length = offset.length()
        if length > radius:
            offset = offset.normalized() * radius
    _knob = offset
    value = remap_stick(offset / radius, deadzone)
    input_changed.emit(value)
    queue_redraw()

## Dead-zone remap: nothing inside the zone, then a smooth ramp so there is no jump at the edge.
static func remap_stick(raw: Vector2, zone: float) -> Vector2:
    var magnitude := raw.length()
    if magnitude < zone:
        return Vector2.ZERO
    return raw.normalized() * minf(1.0, (magnitude - zone) / (1.0 - zone))

func _process(delta: float) -> void:
    _time += delta
    queue_redraw()

func _draw_arrows(center: Vector2, distance: float, color: Color) -> void:
    for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
        var side := Vector2(-direction.y, direction.x)
        var tip: Vector2 = center + direction * distance
        var base: Vector2 = center + direction * (distance - 20.0)
        draw_colored_polygon(PackedVector2Array([tip, base + side * 13.0, base - side * 13.0]), color)

func _draw() -> void:
    if _active:
        draw_circle(_origin, radius + 6.0, Color(0.02, 0.05, 0.2, 0.30))
        draw_arc(_origin, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.8), 5.0, true)
        _draw_arrows(_origin, radius * 0.66, Color(1, 1, 1, 0.55))
        var knob_pos := _origin + _knob
        draw_circle(knob_pos + Vector2(0, 6), knob_radius, Color(0.02, 0.05, 0.15, 0.35))
        draw_circle(knob_pos, knob_radius + 3.0, Color(1, 1, 1, 0.96))
        draw_circle(knob_pos, knob_radius - 2.0, KidUI.GOLD)
        draw_circle(knob_pos + Vector2(0, -knob_radius * 0.3), knob_radius * 0.55, Color(1, 1, 1, 0.22))
    else:
        var rest := _rest_local()
        var pulse := (0.5 + 0.5 * sin(_time * 3.2)) if attention else 0.0
        var alpha := 0.32 + 0.4 * pulse
        draw_circle(rest, radius + pulse * 8.0, Color(1, 1, 1, 0.09 + 0.10 * pulse))
        draw_arc(rest, radius + pulse * 8.0, 0.0, TAU, 64, Color(1, 1, 1, alpha + 0.2), 4.0, true)
        _draw_arrows(rest, radius * 0.66, Color(1, 1, 1, alpha + 0.2))
        draw_circle(rest, knob_radius * 0.8, Color(1, 0.84, 0.3, alpha))
