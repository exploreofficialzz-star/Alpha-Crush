extends RefCounted
class_name CrushMeter

## The signature resource of Alpha Crush. Every landed hit fills it (kung-fu fills it fastest); when it is full the
## player can unleash a CRUSH move that clears the crowd around them.
signal became_ready
signal spent

const MAX_VALUE := 100.0

var value := 0.0
var locked := false

func add(amount: float) -> void:
    if locked or amount <= 0.0:
        return
    var was_ready := is_ready()
    value = minf(MAX_VALUE, value + amount)
    if not was_ready and is_ready():
        became_ready.emit()

func is_ready() -> bool:
    return value >= MAX_VALUE - 0.001

func fraction() -> float:
    return clampf(value / MAX_VALUE, 0.0, 1.0)

## Empties the meter; returns false (and does nothing) when it was not full.
func spend() -> bool:
    if not is_ready():
        return false
    value = 0.0
    spent.emit()
    return true

func reset() -> void:
    value = 0.0
    locked = false
