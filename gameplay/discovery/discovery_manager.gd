extends Node
class_name DiscoveryManager

signal discovered_new(id: String, title: String)
var entries: Dictionary = {}

func discover(id: String, title: String) -> bool:
    if entries.has(id):
        return false
    entries[id] = {"title": title, "time": Time.get_unix_time_from_system()}
    discovered_new.emit(id, title)
    return true

func has(id: String) -> bool:
    return entries.has(id)

func snapshot() -> Array:
    var result: Array = []
    for id in entries.keys():
        result.append({"id": id, "data": entries[id]})
    return result

func restore(value: Array) -> void:
    entries.clear()
    for item in value:
        if item is Dictionary and item.has("id"):
            entries[str(item["id"])] = item.get("data", {})
