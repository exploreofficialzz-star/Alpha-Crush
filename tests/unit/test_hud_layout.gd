extends RefCounted
class_name TestHudLayout

static func run() -> bool:
    var ok := true
    var sizes: Array[Vector2] = [Vector2(1280, 720), Vector2(1440, 720), Vector2(1600, 720), Vector2(1560, 720), Vector2(1024, 720), Vector2(960, 720)]
    var margin_sets: Array[Vector4] = [Vector4(0, 0, 0, 0), Vector4(48, 0, 48, 24), Vector4(0, 24, 0, 34)]
    for size in sizes:
        for margins in margin_sets:
            for left_handed in [false, true]:
                var tag := "%s %s %s" % [str(size), str(margins), "left" if left_handed else "right"]
                ok = TestSupport.expect(HudLayout.min_button_gap(size, margins, left_handed) >= 0.0, "no touch circles overlap at " + tag) and ok
                ok = TestSupport.expect(HudLayout.all_on_screen(size, margins, left_handed), "all buttons on screen at " + tag) and ok
                var zone := HudLayout.stick_zone(size, margins, left_handed)
                ok = TestSupport.expect(zone.position.x >= 0.0 and zone.end.x <= size.x + 0.01 and zone.size.y > 100.0, "stick zone fits at " + tag) and ok
                var placed := HudLayout.buttons(size, margins, left_handed)
                var attack_x := float((placed["attack"]["center"] as Vector2).x)
                ok = TestSupport.expect((attack_x < size.x * 0.5) != left_handed, "attack sits opposite the move stick at " + tag) and ok
                ok = TestSupport.expect((zone.get_center().x > size.x * 0.5) != left_handed, "the stick zone is on the movement side at " + tag) and ok
    ok = TestSupport.expect(HudLayout.streak_centers(Vector2(1280, 720), Vector4.ZERO).size() == 3, "three killstreak buttons") and ok
    return ok
