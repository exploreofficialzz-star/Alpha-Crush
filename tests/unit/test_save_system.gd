extends RefCounted
class_name TestSaveSystem

static func run() -> bool:
    var save_script = preload("res://core/services/save_system.gd")
    var system = save_script.new()
    var data: Dictionary = system.default_data()
    var ok := TestSupport.expect(int(data.get("version", 0)) == save_script.SAVE_VERSION, "default data carries the current version")
    for key in ["progress", "settings", "consent", "purchases", "profile", "session", "analytics"]:
        ok = TestSupport.expect(data.has(key), "default data has %s" % key) and ok
    for key in save_script.OBSOLETE_KEYS:
        ok = TestSupport.expect(not data.has(key), "default data no longer has the old %s" % key) and ok
    ok = TestSupport.expect(int(data["progress"].get("coins", -1)) == GameConfig.STARTING_COINS, "a new career starts with the welcome coins") and ok
    system.free()
    return ok
