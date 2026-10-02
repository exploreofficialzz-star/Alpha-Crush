extends Node
class_name WorldClock

signal period_changed(period: String)
var elapsed := 0.0
var period := "morning"
const CYCLE_SECONDS := 240.0

func _process(delta: float) -> void:
    elapsed = fmod(elapsed + delta, CYCLE_SECONDS)
    var next := "night"
    if elapsed < 60.0:
        next = "morning"
    elif elapsed < 150.0:
        next = "day"
    elif elapsed < 210.0:
        next = "evening"
    if next != period:
        period = next
        period_changed.emit(period)

func snapshot() -> Dictionary:
    return {"elapsed": elapsed, "period": period}

func restore(value: Dictionary) -> void:
    elapsed = fposmod(float(value.get("elapsed", 0.0)), CYCLE_SECONDS)
    # Derive the period from the normalized clock to avoid inconsistent saves.
    period = _period_for_elapsed()
    period_changed.emit(period)

func _period_for_elapsed() -> String:
    if elapsed < 60.0:
        return "morning"
    if elapsed < 150.0:
        return "day"
    if elapsed < 210.0:
        return "evening"
    return "night"
