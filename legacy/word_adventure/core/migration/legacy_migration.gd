extends RefCounted
class_name LegacyMigration

const CURRENT_VERSION := 5

static func migrate_legacy(input: Dictionary) -> Dictionary:
    var result := {
        "version": CURRENT_VERSION,
        "inventory": {"coins": 100, "gems": 0},
        "progression": {"level": 1, "xp": 0},
        "world_state": {},
        "discoveries": [],
        "upgrades": {},
        "settings": {}
    }
    if input.has("coins"):
        result["inventory"]["coins"] = max(0, int(input["coins"]))
    if input.has("gems"):
        result["inventory"]["gems"] = max(0, int(input["gems"]))
    if input.has("level"):
        result["progression"]["level"] = max(1, int(input["level"]))
    if input.has("xp"):
        result["progression"]["xp"] = max(0, int(input["xp"]))
    if input.has("completed_words") and input["completed_words"] is Array:
        for word in input["completed_words"]:
            result["world_state"]["word_%s" % str(word).to_lower()] = "COMPLETE"
    if input.has("discoveries") and input["discoveries"] is Array:
        result["discoveries"] = input["discoveries"].duplicate(true)
    return result
