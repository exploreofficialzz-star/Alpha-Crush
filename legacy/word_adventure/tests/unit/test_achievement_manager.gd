extends RefCounted
class_name TestAchievementManager

static func run() -> bool:
    var inventory = preload("res://gameplay/inventory.gd").new()
    var manager = preload("res://gameplay/achievements/achievement_manager.gd").new()
    manager.inventory = inventory
    manager.definitions = {
        "first_word": {"id": "first_word", "event": "word_completed", "target": 1, "title": "Word Weaver", "reward": {"coins": 40}},
        "pathfinder": {"id": "pathfinder", "event": "region_discovered", "target": 2, "title": "Pathfinder", "reward": {"gems": 2}}
    }
    manager.progress = {"first_word": 0, "pathfinder": 0}
    manager.record("word_completed")
    if not manager.claimed.get("first_word", false) or inventory.count("coins") != 40:
        return false
    manager.record("region_discovered", 1, "forest")
    manager.record("region_discovered", 1, "forest")
    if int(manager.progress["pathfinder"]) != 1:
        return false
    manager.record("region_discovered", 1, "riverlands")
    return bool(manager.claimed.get("pathfinder", false)) and inventory.count("gems") == 2
