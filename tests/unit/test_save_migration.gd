extends RefCounted
class_name TestSaveMigration

static func run() -> bool:
    var save_script = preload("res://core/services/save_system.gd")
    var save = save_script.new()
    var migrated: Dictionary = save.migrate({"version": 1, "inventory": {"coins": 25}})
    var json_roundtrip: Dictionary = save.migrate({"version": 13, "inventory_capacity": 60.0})
    if int(json_roundtrip.get("inventory_capacity", 0)) != 60 or typeof(json_roundtrip.get("inventory_capacity")) != TYPE_INT:
        return false
    return int(migrated.get("version", 0)) == save_script.SAVE_VERSION and migrated.has("achievements") and migrated.has("profile") and migrated.has("session") and migrated.has("settings") and migrated.has("world_clock") and migrated.has("weather") and migrated.has("inventory_capacity") and migrated.has("harvest_state")
