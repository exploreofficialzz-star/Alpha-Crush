extends Control
class_name MapView

var map_manager: Node
var player: Node
var zoom := 2.5

func setup(manager: Node, local_player: Node) -> void:
    map_manager = manager
    player = local_player
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.06, 0.09, 0.84), true)
    draw_circle(center, 8.0, Color("#f4d35e"))
    if map_manager == null:
        return
    for id in map_manager.discovered.keys():
        var item: Dictionary = map_manager.discovered[id]
        var p = item.get("position", [0, 0, 0])
        var world_pos := Vector3(float(p[0]), 0, float(p[2]))
        var player_pos := Vector3.ZERO
        if player:
            player_pos = player.global_position
        var delta := Vector2(world_pos.x - player_pos.x, world_pos.z - player_pos.z) / zoom
        delta.x = clampf(delta.x, -size.x * 0.43, size.x * 0.43)
        delta.y = clampf(delta.y, -size.y * 0.43, size.y * 0.43)
        var point := center + delta
        draw_circle(point, 6.0, Color("#9ee7ff"))
        draw_string(ThemeDB.fallback_font, point + Vector2(9, 4), str(item.get("title", id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
