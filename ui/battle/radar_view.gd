extends Control
class_name RadarView

## Round mini-map: enemies are red dots, squad-mates teal, flags coloured squares, the boss a big gold dot. Up is where the
## camera looks. Targets beyond RANGE slide to the rim so the player always knows which way trouble is.
const RANGE := 42.0

var player: Node3D
var director: CombatDirector
var zones: Array[CaptureZone] = []
var boss: Node3D
var _timer := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    _timer -= delta
    if _timer <= 0.0:
        _timer = 0.1
        queue_redraw()

func _blip(offset: Vector2, forward: Vector2, right: Vector2, radius: float) -> Vector2:
    var local := Vector2(offset.dot(right), -offset.dot(forward)) * (radius / RANGE)
    if local.length() > radius - 5.0:
        local = local.normalized() * (radius - 5.0)
    return local

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.5 - 4.0
    draw_circle(center, radius, Color(0.03, 0.07, 0.2, 0.62))
    draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
    draw_arc(center, radius * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.14), 2.0, true)
    draw_line(center + Vector2(0.0, -radius + 2.0), center + Vector2(0.0, -radius + 13.0), Color(1, 1, 1, 0.85), 3.0)
    if player == null or not is_instance_valid(player):
        return
    var yaw := deg_to_rad(float(player.get("yaw")))
    var forward := Vector2(-sin(yaw), -cos(yaw))
    var right := Vector2(-forward.y, forward.x)
    var origin := Vector2(player.global_position.x, player.global_position.z)
    for zone in zones:
        if not is_instance_valid(zone):
            continue
        var spot := _blip(Vector2(zone.global_position.x, zone.global_position.z) - origin, forward, right, radius)
        draw_rect(Rect2(center + spot - Vector2(6, 6), Vector2(12, 12)), zone.owner_color(), true)
    if director != null:
        for candidate in director.roster(Teams.ALPHA):
            var ally := candidate as Node3D
            if ally != null and ally != player:
                draw_circle(center + _blip(Vector2(ally.global_position.x, ally.global_position.z) - origin, forward, right, radius), 4.0, Color(0.3, 0.95, 0.95))
        for candidate in director.roster(Teams.OPPOSITION):
            var enemy := candidate as Node3D
            if enemy == null:
                continue
            var big := enemy == boss
            draw_circle(center + _blip(Vector2(enemy.global_position.x, enemy.global_position.z) - origin, forward, right, radius), 7.0 if big else 4.5, Color(1.0, 0.85, 0.2) if big else Color(1.0, 0.32, 0.28))
    var tip := center + Vector2(0.0, -9.0)
    draw_colored_polygon(PackedVector2Array([tip, center + Vector2(-7.0, 8.0), center + Vector2(7.0, 8.0)]), Color(1, 1, 1, 1))
