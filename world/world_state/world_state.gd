extends Node
class_name WorldState

signal state_changed(object_id: String, state: String)
signal property_changed(object_id: String, property: String, value: Variant)

var states: Dictionary = {}

func get_state(object_id: String) -> String:
    var value: Variant = states.get(object_id, "LOCKED")
    if value is Dictionary:
        return str(value.get("state", "LOCKED"))
    return str(value)

func set_state(object_id: String, state: String) -> void:
    var previous := get_state(object_id)
    var existing: Variant = states.get(object_id, {})
    if existing is Dictionary:
        var record: Dictionary = existing.duplicate(true)
        record["state"] = state
        if not record.has("properties"):
            record["properties"] = {}
        states[object_id] = record
    else:
        states[object_id] = state
    if previous != state:
        state_changed.emit(object_id, state)

func set_property(object_id: String, property: String, value: Variant) -> void:
    var existing: Variant = states.get(object_id, {"state": "LOCKED", "properties": {}})
    var record: Dictionary
    if existing is Dictionary:
        record = existing.duplicate(true)
    else:
        record = {"state": str(existing), "properties": {}}
    var properties: Dictionary = record.get("properties", {}).duplicate(true)
    properties[property] = value
    record["properties"] = properties
    states[object_id] = record
    property_changed.emit(object_id, property, value)

func get_property(object_id: String, property: String, fallback: Variant = null) -> Variant:
    var record = states.get(object_id, {})
    if record is Dictionary:
        return record.get("properties", {}).get(property, fallback)
    return fallback

func is_complete(object_id: String) -> bool:
    return get_state(object_id) in ["COMPLETE", "ACTIVE", "UPGRADED"]

func is_discovered(object_id: String) -> bool:
    return get_state(object_id) != "LOCKED"

func snapshot() -> Dictionary:
    return states.duplicate(true)

func restore(value: Dictionary) -> void:
    states = value.duplicate(true)
