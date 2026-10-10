extends Control
class_name MapView

## A friendly radar: you are the gold arrow in the middle (it points where the camera looks),
## each place you have found is a picture bubble, and places beyond the edge stick to the rim.
## North (the way the world's -Z points) is up.
var map_manager: Node
var player: Node
var zoom := 2.5

func setup(manager: Node, local_player: Node) -> void:
    map_manager = manager
    player = local_player
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _process(_delta: float) -> void:
    if is_visible_in_tree():
        queue_redraw()

func _heading() -> float:
    if player != null and "yaw" in player:
        return deg_to_rad(float(player.get("yaw")))
    return 0.0

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.46
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.07, 0.14, 0.9), true)
    for step in [0.33, 0.66, 1.0]:
        draw_arc(center, radius * step, 0.0, TAU, 64, Color(1, 1, 1, 0.14), 2.0, true)
    draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), Color(1, 1, 1, 0.08), 2.0)
    draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), Color(1, 1, 1, 0.08), 2.0)
    draw_string(ThemeDB.fallback_font, center + Vector2(-8, -radius - 6), "N", HORIZONTAL_ALIGNMENT_CENTER, 16, 22, Color(1, 1, 1, 0.7))
    if map_manager != null:
        var player_pos := player.global_position if player != null else Vector3.ZERO
        for id in map_manager.discovered.keys():
            var item: Dictionary = map_manager.discovered[id]
            var p = item.get("position", [0, 0, 0])
            var delta := Vector2(float(p[0]) - player_pos.x, float(p[2]) - player_pos.z) / zoom
            delta.x = clampf(delta.x, -size.x * 0.43, size.x * 0.43)
            delta.y = clampf(delta.y, -size.y * 0.43, size.y * 0.43)
            var point := center + delta
            var title := str(item.get("title", id))
            draw_circle(point + Vector2(0, 3), 25.0, Color(0, 0, 0, 0.3))
            draw_circle(point, 25.0, Color.WHITE)
            draw_circle(point, 22.0, KidUI.BLUE)
            var tex := KidUI.icon(KidUI.place_icon_name(title))
            if tex != null:
                draw_texture_rect(tex, Rect2(point - Vector2(18, 18), Vector2(36, 36)), false)
            draw_string_outline(ThemeDB.fallback_font, point + Vector2(-70, 44), title, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, 5, Color(0.02, 0.05, 0.15, 1))
            draw_string(ThemeDB.fallback_font, point + Vector2(-70, 44), title, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color.WHITE)
    var heading := _heading()
    var forward := Vector2(-sin(heading), -cos(heading))
    var side := Vector2(-forward.y, forward.x)
    draw_circle(center + Vector2(0, 3), 22.0, Color(0, 0, 0, 0.3))
    draw_colored_polygon(PackedVector2Array([center + forward * 26.0, center - forward * 16.0 + side * 17.0, center - forward * 6.0, center - forward * 16.0 - side * 17.0]), KidUI.GOLD)
    draw_polyline(PackedVector2Array([center + forward * 26.0, center - forward * 16.0 + side * 17.0, center - forward * 6.0, center - forward * 16.0 - side * 17.0, center + forward * 26.0]), Color.WHITE, 3.0, true)
