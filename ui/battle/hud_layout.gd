extends RefCounted
class_name HudLayout

## Pure layout maths for the battle HUD (no nodes), so it can be unit-tested for overlaps at every screen shape.
## Convention: the MOVE stick lives under the right thumb; every other control sits on the left and middle of the screen
## (mirrored for left-handed players). `x` is the distance from the thumb-side edge to a button's centre and `y` the distance
## from the bottom edge (negative = up). Radii are in logical UI units, the same units the touch buttons use.
const EDGE := 18.0
const TOUCH_PAD := 14.0
const MIN_GAP := 24.0
const STREAK_RADIUS := 34.0
const STREAK_SPACING := 104.0

const BUTTONS := {
    "attack": {"r": 88.0, "x": 190.0, "y": -170.0},
    "dodge": {"r": 52.0, "x": 405.0, "y": -105.0},
    "jump": {"r": 46.0, "x": 395.0, "y": -232.0},
    "crush": {"r": 62.0, "x": 150.0, "y": -352.0},
    "grenade": {"r": 42.0, "x": 300.0, "y": -352.0},
    "reload": {"r": 38.0, "x": 525.0, "y": -95.0},
    "swap": {"r": 38.0, "x": 525.0, "y": -205.0}
}

## id -> {"center": Vector2, "radius": float} in canvas coordinates.
static func buttons(size: Vector2, margins: Vector4, left_handed: bool) -> Dictionary:
    var result: Dictionary = {}
    for id in BUTTONS.keys():
        var spec: Dictionary = BUTTONS[id]
        var reach := float(spec["x"])
        var cx := size.x - margins.z - reach if left_handed else margins.x + reach
        var cy := size.y - margins.w + float(spec["y"])
        result[id] = {"center": Vector2(cx, cy), "radius": float(spec["r"])}
    return result

## Three killstreak buttons in a row under the objective banner (top centre).
static func streak_centers(size: Vector2, margins: Vector4) -> Array[Vector2]:
    var out: Array[Vector2] = []
    for i in 3:
        out.append(Vector2(size.x * 0.5 + float(i - 1) * STREAK_SPACING, margins.y + 128.0))
    return out

## The invisible zone where a thumb may land to start the floating move stick.
static func stick_zone(size: Vector2, margins: Vector4, left_handed: bool) -> Rect2:
    var top := size.y * 0.30
    var width := maxf(260.0, size.x * 0.46) - (margins.x if left_handed else margins.z)
    var x := margins.x if left_handed else size.x - margins.z - width
    return Rect2(x, top, width, size.y - top - margins.w)

static func pause_center(size: Vector2, margins: Vector4) -> Vector2:
    return Vector2(size.x - margins.z - EDGE - 36.0, margins.y + 52.0)

## Smallest gap between any two touch circles (negative = they overlap). Used by the unit test.
static func min_button_gap(size: Vector2, margins: Vector4, left_handed: bool) -> float:
    var circles: Array[Dictionary] = []
    var placed := buttons(size, margins, left_handed)
    for id in placed.keys():
        circles.append({"c": placed[id]["center"], "r": float(placed[id]["radius"]) + TOUCH_PAD})
    for center in streak_centers(size, margins):
        circles.append({"c": center, "r": STREAK_RADIUS + TOUCH_PAD})
    circles.append({"c": pause_center(size, margins), "r": 36.0 + TOUCH_PAD})
    var worst := 100000.0
    for i in circles.size():
        for j in range(i + 1, circles.size()):
            var gap := (circles[i]["c"] as Vector2).distance_to(circles[j]["c"] as Vector2) - float(circles[i]["r"]) - float(circles[j]["r"])
            worst = minf(worst, gap)
    return worst

## True when every touch circle lies fully inside the visible screen.
static func all_on_screen(size: Vector2, margins: Vector4, left_handed: bool) -> bool:
    var placed := buttons(size, margins, left_handed)
    for id in placed.keys():
        var center: Vector2 = placed[id]["center"]
        var reach := float(placed[id]["radius"]) + TOUCH_PAD
        if center.x - reach < 0.0 or center.y - reach < 0.0 or center.x + reach > size.x or center.y + reach > size.y:
            return false
    return true
