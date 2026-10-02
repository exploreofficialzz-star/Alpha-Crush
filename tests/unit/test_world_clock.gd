extends RefCounted
class_name TestWorldClock

static func run() -> bool:
    var clock = preload("res://world/time/world_clock.gd").new()
    clock.restore({"elapsed": 185.0, "period": "morning"})
    if clock.period != "evening":
        return false
    var saved: Dictionary = clock.snapshot()
    var restored = preload("res://world/time/world_clock.gd").new()
    restored.restore(saved)
    return is_equal_approx(restored.elapsed, 185.0) and restored.period == "evening"
