extends Node
class_name DailyManager

signal changed
signal completed_reward(objective_id: String, reward: Dictionary)

var date_key := ""
var objectives: Array = []

func _ready() -> void:
    refresh(Time.get_date_string_from_system())

func refresh(new_date_key: String) -> void:
    if date_key == new_date_key and not objectives.is_empty():
        return
    date_key = new_date_key
    objectives = [
        {"id": "daily_harvest", "title": "Harvest 5 resources", "target": 5, "progress": 0, "reward": {"coins": 50}},
        {"id": "daily_word", "title": "Complete 1 world-changing word", "target": 1, "progress": 0, "reward": {"gems": 2}},
        {"id": "daily_discover", "title": "Discover 2 things", "target": 2, "progress": 0, "reward": {"coins": 40}}
    ]
    changed.emit()

func progress(id: String, amount: int = 1) -> void:
    for objective in objectives:
        if str(objective.get("id", "")) != id:
            continue
        var before := int(objective.get("progress", 0))
        var target := int(objective.get("target", 1))
        objective["progress"] = mini(target, before + amount)
        if before < target and int(objective["progress"]) >= target:
            completed_reward.emit(id, objective.get("reward", {}))
        changed.emit()
        return

func completed(id: String) -> bool:
    for objective in objectives:
        if str(objective.get("id", "")) == id:
            return int(objective.get("progress", 0)) >= int(objective.get("target", 1))
    return false

func snapshot() -> Dictionary:
    return {"date": date_key, "objectives": objectives.duplicate(true)}

func restore(value: Dictionary) -> void:
    if str(value.get("date", "")) != date_key:
        return
    var stored: Variant = value.get("objectives", [])
    if typeof(stored) == TYPE_ARRAY:
        objectives = stored.duplicate(true)
        changed.emit()
