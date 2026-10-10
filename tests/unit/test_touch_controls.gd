extends RefCounted
class_name TestTouchControls

## Move-stick maths and the guide director's picture-friendly target choice.
static func run() -> bool:
    if AlphaCrushVirtualJoystick.remap_stick(Vector2(0.05, 0.0), 0.14) != Vector2.ZERO:
        return false
    var full := AlphaCrushVirtualJoystick.remap_stick(Vector2(1.0, 0.0), 0.14)
    if not full.is_equal_approx(Vector2(1.0, 0.0)):
        return false
    var half := AlphaCrushVirtualJoystick.remap_stick(Vector2(0.57, 0.0), 0.14)
    if absf(half.x - 0.5) > 0.001:
        return false
    # Direction is preserved on diagonals and the magnitude never exceeds 1.
    var diagonal := AlphaCrushVirtualJoystick.remap_stick(Vector2(2.0, 2.0), 0.14)
    if diagonal.length() > 1.0001 or absf(diagonal.x - diagonal.y) > 0.0001:
        return false
    var director := GuideDirector.new()
    var inventory: Inventory = preload("res://gameplay/inventory.gd").new()
    var sites: OpportunityManager = preload("res://gameplay/opportunities/opportunity_manager.gd").new()
    director.setup(null, null, inventory, sites)
    var passed := true
    if director.carries_sellables():
        passed = false
    inventory.add_item("fruit_orange", 2)
    if not director.carries_sellables():
        passed = false
    sites.register("far", "Far Ladder", "LADDER", Vector3(40, 0, 0))
    sites.register("near", "Near Basket", "BASKET", Vector3(5, 0, 0))
    var target := director.nearest_site(Vector3.ZERO)
    if str(target.get("icon", "")) != "basket" or str(target.get("kind", "")) != "site":
        passed = false
    sites.complete("near")
    if str(director.nearest_site(Vector3.ZERO).get("icon", "")) != "ladder":
        passed = false
    inventory.free()
    sites.free()
    return passed
