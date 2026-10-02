extends Node
class_name AnalyticsService

signal event_recorded(event_name: String, payload: Dictionary)

var enabled := true
var session_id := ""
var buffer: Array = []
const MAX_BUFFER := 64

func _ready() -> void:
    session_id = "%s-%s" % [str(Time.get_unix_time_from_system()), str(randi())]

func track(event_name: String, payload: Dictionary = {}) -> void:
    if not enabled:
        return
    var record := {
        "event": event_name,
        "time": Time.get_unix_time_from_system(),
        "session": session_id,
        "payload": payload.duplicate(true)
    }
    buffer.append(record)
    if buffer.size() >= MAX_BUFFER:
        flush()
    event_recorded.emit(event_name, payload)

func flush() -> void:
    buffer.clear()

func snapshot() -> Array:
    return buffer.duplicate(true)
