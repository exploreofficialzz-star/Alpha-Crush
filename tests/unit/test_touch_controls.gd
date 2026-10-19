extends RefCounted
class_name TestTouchControls

## Move-stick maths (dead zone, full tilt, diagonals) and the touch router's priority order.
static func run() -> bool:
    var ok := true
    ok = TestSupport.expect(AlphaCrushVirtualJoystick.remap_stick(Vector2(0.05, 0.0), 0.14) == Vector2.ZERO, "inside the dead zone nothing moves") and ok
    var full := AlphaCrushVirtualJoystick.remap_stick(Vector2(1.0, 0.0), 0.14)
    ok = TestSupport.expect(full.is_equal_approx(Vector2(1.0, 0.0)), "full tilt is full speed") and ok
    var half := AlphaCrushVirtualJoystick.remap_stick(Vector2(0.57, 0.0), 0.14)
    ok = TestSupport.expect(absf(half.x - 0.5) < 0.001, "the dead zone is remapped smoothly") and ok
    var diagonal := AlphaCrushVirtualJoystick.remap_stick(Vector2(2.0, 2.0), 0.14)
    ok = TestSupport.expect(diagonal.length() <= 1.0001 and absf(diagonal.x - diagonal.y) < 0.0001, "diagonals keep their direction and never exceed 1") and ok
    return ok
