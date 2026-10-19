extends Node
class_name AchievementManager

signal progress_changed(achievement_id: String, progress: int, target: int)
signal unlocked(achievement_id: String, title: String, reward: Dictionary)

var definitions: Dictionary = {}
var progress: Dictionary = {}
var claimed: Dictionary = {}
var inventory: Node

func _ready() -> void:
    var file := FileAccess.open("res://data/objectives/achievements.json", FileAccess.READ)
    if file == null:
        push_error("Achievement definitions could not be loaded")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_ARRAY:
        push_error("Achievement definitions must be an array")
        return
    for entry in parsed:
        if entry is Dictionary and entry.has("id"):
            definitions[str(entry.id)] = entry.duplicate(true)
            progress[str(entry.id)] = 0

func record(event: String, amount: int = 1, unique_key: String = "") -> void:
    if amount <= 0:
        return
    for id in definitions.keys():
        var definition: Dictionary = definitions[id]
        if str(definition.get("event", "")) != event or bool(claimed.get(id, false)):
            continue
        if event == "region_discovered" and not unique_key.is_empty():
            var unique_id := "%s:%s" % [id, unique_key]
            var seen: Dictionary = progress.get("_unique", {})
            if seen.has(unique_id):
                continue
            seen[unique_id] = true
            progress["_unique"] = seen
        var target := maxi(1, int(definition.get("target", 1)))
        var next_value := mini(target, int(progress.get(id, 0)) + amount)
        progress[id] = next_value
        progress_changed.emit(str(id), next_value, target)
        if next_value >= target:
            _unlock(str(id), definition)

func _unlock(id: String, definition: Dictionary) -> void:
    if bool(claimed.get(id, false)):
        return
    claimed[id] = true
    var reward: Dictionary = definition.get("reward", {}).duplicate(true)
    if inventory:
        for currency in reward.keys():
            inventory.add_item(str(currency), int(reward[currency]))
    unlocked.emit(id, str(definition.get("title", id)), reward)

func snapshot() -> Dictionary:
    return {"progress": progress.duplicate(true), "claimed": claimed.duplicate(true)}

func restore(value: Dictionary) -> void:
    var saved_progress = value.get("progress", {})
    var saved_claimed = value.get("claimed", {})
    if typeof(saved_progress) == TYPE_DICTIONARY:
        for id in definitions.keys():
            progress[id] = clampi(int(saved_progress.get(id, 0)), 0, maxi(1, int(definitions[id].get("target", 1))))
        progress["_unique"] = saved_progress.get("_unique", {}).duplicate(true) if typeof(saved_progress.get("_unique", {})) == TYPE_DICTIONARY else {}
    if typeof(saved_claimed) == TYPE_DICTIONARY:
        claimed = saved_claimed.duplicate(true)
