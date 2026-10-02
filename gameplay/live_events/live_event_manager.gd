extends Node
class_name LiveEventManager

signal event_changed(event_id: String)
var catalog: Array = []
var active_events: Array = []
var event_state: Dictionary = {}

func _ready() -> void:
    var f := FileAccess.open("res://data/events/events.json", FileAccess.READ)
    if f:
        var d = JSON.parse_string(f.get_as_text())
        if typeof(d) == TYPE_ARRAY:
            catalog = d.duplicate(true)
    refresh()

func refresh() -> void:
    active_events.clear()
    var now := int(Time.get_unix_time_from_system())
    for event_data in catalog:
        var id := str(event_data.get("id", ""))
        var state: Dictionary = event_state.get(id, {})
        var start := int(state.get("start", 0))
        if start == 0:
            start = now
            event_state[id] = {"start": start, "expires": start + int(event_data.get("duration_hours", 24)) * 3600}
        var expires := int(event_state[id].get("expires", 0))
        if now < expires:
            active_events.append(event_data)
            event_changed.emit(id)

func is_active(id: String) -> bool:
    for event_data in active_events:
        if str(event_data.get("id", "")) == id:
            return true
    return false

func multiplier(kind: String) -> float:
    var value := 1.0
    for event_data in active_events:
        if str(event_data.get("type", "")) == kind:
            value = maxf(value, float(event_data.get("multiplier", 1.0)))
    return value

func snapshot() -> Dictionary:
    return event_state.duplicate(true)

func restore(value: Dictionary) -> void:
    event_state = value.duplicate(true)
    refresh()
