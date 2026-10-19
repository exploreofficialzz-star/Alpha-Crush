extends RefCounted
class_name TestSaveMigration

static func run() -> bool:
    var save_script = preload("res://core/services/save_system.gd")
    var save = save_script.new()
    var ok := true
    # A 2.x word-adventure save: coins are carried over as a welcome bonus, the old keys disappear, the new career appears.
    var old_save := {"version": 13, "inventory": {"coins": 400}, "inventory_capacity": 60.0, "harvest_state": {"x": 1}, "word_system": {"y": 2}, "settings": {"sfx": false}}
    var migrated: Dictionary = save.migrate(old_save)
    ok = TestSupport.expect(int(migrated.get("version", 0)) == save_script.SAVE_VERSION, "migration stamps the current version") and ok
    for key in save_script.OBSOLETE_KEYS:
        ok = TestSupport.expect(not migrated.has(key), "old key %s is dropped" % key) and ok
    var career: Dictionary = migrated["progress"]
    ok = TestSupport.expect(int(career["coins"]) == GameConfig.STARTING_COINS + 400, "old coins become a welcome bonus") and ok
    ok = TestSupport.expect(typeof(career["coins"]) == TYPE_INT and int(career["rank"]) == 1, "the combat career starts fresh") and ok
    ok = TestSupport.expect(migrated["settings"].get("sfx", true) == false, "the player's own settings survive") and ok
    for key in ["profile", "session", "consent", "purchases"]:
        ok = TestSupport.expect(migrated.has(key), "%s is present after migration" % key) and ok
    var rich: Dictionary = save.migrate({"version": 5, "inventory": {"coins": 99999}})
    ok = TestSupport.expect(int(rich["progress"]["coins"]) == GameConfig.STARTING_COINS + 1500, "carried coins are capped") and ok
    var current: Dictionary = save.migrate({"version": save_script.SAVE_VERSION, "progress": {"xp": 500, "coins": 7}})
    ok = TestSupport.expect(int(current["progress"]["xp"]) == 500 and int(current["progress"]["coins"]) == 7, "a current save is left alone") and ok
    save.free()
    return ok
