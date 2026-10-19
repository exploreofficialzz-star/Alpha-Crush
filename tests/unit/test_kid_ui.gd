extends RefCounted
class_name TestKidUI

## The shared UI kit: icons load and cache, panels are rounded boxes, and safe-area margins are never negative.
static func run() -> bool:
    var ok := true
    for icon_name in ["jump", "hand", "gear", "close", "lock", "play", "boy", "girl", "coin", "gem", "star_gold", "bag", "map"]:
        ok = TestSupport.expect(FileAccess.file_exists("%s%s.png" % [KidUI.ICON_DIR, icon_name]), "icon %s exists" % icon_name) and ok
    var first := KidUI.icon("jump")
    ok = TestSupport.expect(first != null and KidUI.icon("jump") == first, "icons load once and are cached") and ok
    ok = TestSupport.expect(KidUI.icon("this_icon_does_not_exist") == null, "a missing icon is null, not a crash") and ok
    var style := KidUI.panel_style(KidUI.PANEL, 24, Color.WHITE, 3)
    ok = TestSupport.expect(style.corner_radius_top_left == 24 and style.border_width_left == 3, "panel style applies radius and border") and ok
    var margins := KidUI.safe_margins(TestSupport.tree_root() as Viewport)
    ok = TestSupport.expect(margins.x >= 0.0 and margins.y >= 0.0 and margins.z >= 0.0 and margins.w >= 0.0, "safe margins are never negative") and ok
    var label := KidUI.number_label(30, KidUI.GOLD)
    ok = TestSupport.expect(label.get_theme_font_size("font_size") == 30, "number labels use the requested size") and ok
    label.free()
    return ok
