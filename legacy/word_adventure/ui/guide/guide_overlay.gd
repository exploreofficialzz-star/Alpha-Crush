extends Control
class_name GuideOverlay

## Draws the "go there" marker: a bouncing picture bubble over the target when it is on screen,
## or a bubble with an arrow stuck to the screen edge when it is off screen or behind the player.
## It hides when the player is standing at the target so the action button takes over.
const ARRIVE_DISTANCE := 3.4
const TOP_MARGIN := 130.0
const BOTTOM_MARGIN := 230.0
const SIDE_MARGIN := 70.0

var player: AlphaCrushPlayer
var director: GuideDirector
var enabled := true
var boost := 0.0
var _target: Dictionary = {}
var _refresh := 0.0
var _time := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)

## Makes the marker bigger and ringed for a few seconds (the lightbulb hint button).
func show_boost(seconds: float = 7.0) -> void:
    boost = seconds
    _refresh = 0.0

func current_target() -> Dictionary:
    return _target

func _process(delta: float) -> void:
    _time += delta
    boost = maxf(0.0, boost - delta)
    _refresh -= delta
    if _refresh <= 0.0:
        _refresh = 0.25
        _target = director.pick_target() if director != null else {}
    queue_redraw()

func _draw() -> void:
    if not enabled or player == null or player.camera == null or _target.is_empty():
        return
    var pos: Vector3 = _target.get("pos", Vector3.ZERO)
    var flat := Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length()
    if flat < ARRIVE_DISTANCE and boost <= 0.0:
        return
    var cam: Camera3D = player.camera
    var anchor := pos + Vector3(0.0, 2.3, 0.0)
    var behind := cam.is_position_behind(anchor)
    var screen := cam.unproject_position(anchor)
    var area := Rect2(Vector2(SIDE_MARGIN, TOP_MARGIN), Vector2(maxf(40.0, size.x - SIDE_MARGIN * 2.0), maxf(40.0, size.y - TOP_MARGIN - BOTTOM_MARGIN)))
    var radius := 46.0 if boost > 0.0 else 38.0
    var bob := sin(_time * 4.2) * 9.0
    var icon_name := str(_target.get("icon", "sparkle"))
    var letter := str(_target.get("letter", ""))
    if boost > 0.0:
        var pulse := fmod(_time * 1.4, 1.0)
        var ring_center := screen if (not behind and area.has_point(screen)) else _edge_point(screen, behind, area)
        draw_arc(ring_center, radius + 10.0 + pulse * 46.0, 0.0, TAU, 48, Color(1, 0.9, 0.4, 0.8 * (1.0 - pulse)), 5.0, true)
    if not behind and area.has_point(screen):
        _draw_marker(screen + Vector2(0, bob), icon_name, letter, radius)
    else:
        var edge := _edge_point(screen, behind, area)
        var direction := _direction(screen, behind)
        _draw_edge_arrow(edge + direction * bob * 0.5, direction, icon_name, letter, radius)

func _direction(screen: Vector2, behind: bool) -> Vector2:
    var direction := (screen - size * 0.5)
    if behind:
        direction = -direction
    if direction.length() < 1.0:
        direction = Vector2.UP if not behind else Vector2.DOWN
    return direction.normalized()

func _edge_point(screen: Vector2, behind: bool, area: Rect2) -> Vector2:
    var center := area.get_center()
    var direction := _direction(screen, behind)
    var half := area.size * 0.5
    var tx := INF if absf(direction.x) < 0.0001 else half.x / absf(direction.x)
    var ty := INF if absf(direction.y) < 0.0001 else half.y / absf(direction.y)
    return center + direction * minf(tx, ty)

func _draw_face(center: Vector2, radius: float, icon_name: String, letter: String) -> void:
    draw_circle(center, radius, Color("#fff4d6"))
    if not letter.is_empty():
        var font := ThemeDB.fallback_font
        var font_size := int(radius * 1.35)
        draw_string_outline(font, Vector2(center.x - radius, center.y + font_size * 0.34), letter, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, 8, Color(0.04, 0.09, 0.25, 1))
        draw_string(font, Vector2(center.x - radius, center.y + font_size * 0.34), letter, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, KidUI.GOLD)
        return
    var tex := KidUI.icon(icon_name)
    if tex != null:
        var side := radius * 1.45
        draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)

func _draw_marker(center: Vector2, icon_name: String, letter: String, radius: float) -> void:
    var tip := center + Vector2(0, radius + 26.0)
    draw_circle(center + Vector2(0, 6), radius + 5.0, Color(0.02, 0.05, 0.15, 0.30))
    draw_colored_polygon(PackedVector2Array([tip, center + Vector2(-18, radius - 8), center + Vector2(18, radius - 8)]), Color(1, 1, 1, 0.97))
    draw_circle(center, radius + 5.0, Color(1, 1, 1, 0.97))
    draw_circle(center, radius, KidUI.GOLD)
    _draw_face(center, radius - 5.0, icon_name, letter)

func _draw_edge_arrow(center: Vector2, direction: Vector2, icon_name: String, letter: String, radius: float) -> void:
    var side := Vector2(-direction.y, direction.x)
    var tip := center + direction * (radius + 30.0)
    var base := center + direction * (radius - 4.0)
    draw_circle(center + Vector2(0, 6), radius + 5.0, Color(0.02, 0.05, 0.15, 0.30))
    draw_colored_polygon(PackedVector2Array([tip, base + side * 22.0, base - side * 22.0]), Color(1, 1, 1, 0.97))
    draw_circle(center, radius + 5.0, Color(1, 1, 1, 0.97))
    draw_circle(center, radius, KidUI.ORANGE)
    _draw_face(center, radius - 5.0, icon_name, letter)
