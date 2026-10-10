extends TouchTarget
class_name KidTouchButton

## Big round picture button. Fires on touch-down by default (children expect instant feedback)
## and is forgiving: the hit circle is larger than what is drawn.
signal pressed
signal released

const PAD := 14.0

var icon_name := "hand"
var button_color := Color("#ff8a1c")
var radius := 60.0
var disabled := false
var trigger_on_release := false
var glyph := ""
var corner_icon := ""
var dimmed := false:
    set(value):
        dimmed = value
        queue_redraw()
var attention := false:
    set(value):
        attention = value
        set_process(value)
        queue_redraw()
var press_scale := 1.0:
    set(value):
        press_scale = value
        queue_redraw()
var _icon_tex: Texture2D
var _corner_tex: Texture2D
var _down := false
var _time := 0.0
var _tween: Tween

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_mode = Control.FOCUS_NONE
    set_process(attention)

func setup(p_icon: String, color: Color, p_radius: float) -> void:
    button_color = color
    radius = p_radius
    var side := (p_radius + PAD) * 2.0
    custom_minimum_size = Vector2(side, side)
    size = Vector2(side, side)
    set_icon(p_icon)

func set_icon(p_icon: String) -> void:
    if p_icon == icon_name and _icon_tex != null:
        return
    icon_name = p_icon
    _icon_tex = KidUI.icon(p_icon)
    queue_redraw()

func set_corner_icon(p_icon: String) -> void:
    corner_icon = p_icon
    _corner_tex = KidUI.icon(p_icon) if not p_icon.is_empty() else null
    queue_redraw()

func set_glyph(letter: String) -> void:
    glyph = letter
    queue_redraw()

func touch_hit(pos: Vector2) -> bool:
    if disabled:
        return false
    return canvas_center().distance_to(pos) <= radius + PAD

func touch_down(_index: int, _pos: Vector2) -> void:
    _begin_press()

func touch_up(_index: int, pos: Vector2) -> void:
    _end_press(touch_hit(pos))

func touch_cancel() -> void:
    if _down:
        _down = false
        _animate_scale(1.0)

func _begin_press() -> void:
    _down = true
    _animate_scale(0.9)
    KidUI.buzz(12)
    if not trigger_on_release:
        pressed.emit()

func _end_press(inside: bool) -> void:
    if not _down:
        return
    _down = false
    _animate_scale(1.0)
    released.emit()
    if trigger_on_release and inside:
        pressed.emit()

func _animate_scale(target: float) -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    if not is_inside_tree():
        press_scale = target
        return
    _tween = create_tween()
    _tween.tween_property(self, "press_scale", target, 0.09 if target < 1.0 else 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    _time += delta
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var r := radius * press_scale
    var alpha := 0.58 if dimmed else 1.0
    if attention:
        var pulse := 0.5 + 0.5 * sin(_time * 5.0)
        draw_circle(center, r + 6.0 + pulse * 16.0, Color(1, 1, 1, 0.07 + 0.14 * (1.0 - pulse)))
        draw_arc(center, r + 8.0 + pulse * 12.0, 0.0, TAU, 48, Color(1, 0.94, 0.55, 0.9 * (1.0 - pulse)), 4.0, true)
    draw_circle(center + Vector2(0, 7), r, Color(0.02, 0.05, 0.15, 0.36 * alpha))
    draw_circle(center, r + 4.0, Color(1, 1, 1, 0.96 * alpha))
    var face := button_color
    face.a = alpha
    draw_circle(center, r - 2.0, face)
    draw_circle(center + Vector2(0, -r * 0.34), r * 0.56, Color(1, 1, 1, 0.13 * alpha))
    var icon_size := r * 1.18
    if not glyph.is_empty():
        var font_size := int(r * 1.15)
        var font := ThemeDB.fallback_font
        draw_string_outline(font, Vector2(center.x - r, center.y + font_size * 0.34), glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, font_size, 8, Color(0.04, 0.09, 0.25, alpha))
        draw_string(font, Vector2(center.x - r, center.y + font_size * 0.34), glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, font_size, Color(1, 1, 1, alpha))
    elif _icon_tex != null:
        draw_texture_rect(_icon_tex, Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, Color(1, 1, 1, alpha))
    if _corner_tex != null:
        var badge_center := center + Vector2(r * 0.68, r * 0.68)
        draw_circle(badge_center, r * 0.36, Color(1, 1, 1, alpha))
        draw_texture_rect(_corner_tex, Rect2(badge_center - Vector2(r * 0.3, r * 0.3), Vector2(r * 0.6, r * 0.6)), false, Color(1, 1, 1, alpha))
