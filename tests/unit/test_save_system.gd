extends RefCounted
class_name TestSaveSystem

static func run() -> bool:
    var save_script = preload("res://core/services/save_system.gd")
    var system = save_script.new()
    var data: Dictionary = system.default_data()
    return int(data.get("version", 0)) == save_script.SAVE_VERSION and data.has("world_seed") and data.has("inventory") and data.has("settings") and data.has("inventory_capacity") and data.has("harvest_state")
