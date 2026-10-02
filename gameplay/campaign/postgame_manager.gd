extends Node
class_name PostgameManager

signal challenge_started(id: String, word: String, title: String)
signal challenge_completed(id: String, reward: Dictionary)

const CHALLENGES := [
    {"id":"forest_revival","title":"Forest Revival","word":"FOREST","reward":{"coins":120,"xp":180}},
    {"id":"river_care","title":"River Care","word":"WATER","reward":{"coins":130,"xp":190}},
    {"id":"harvest_day","title":"Great Harvest","word":"HARVEST","reward":{"coins":150,"xp":210}},
    {"id":"build_day","title":"Builders' Day","word":"BUILD","reward":{"coins":170,"xp":230}},
    {"id":"friendship","title":"New Friends","word":"FRIEND","reward":{"coins":180,"xp":250}},
    {"id":"exploration","title":"Far Horizons","word":"EXPLORE","reward":{"coins":200,"xp":280}},
    {"id":"festival","title":"Village Festival","word":"FESTIVAL","reward":{"coins":250,"xp":320}},
    {"id":"future","title":"Tomorrow's City","word":"FUTURE","reward":{"coins":300,"xp":400}}
]

var completed: Dictionary = {}
var active_id := ""
var cycle := 0

func restore(value: Dictionary) -> void:
    completed = value.get("completed", {}).duplicate(true)
    active_id = str(value.get("active_id", ""))
    cycle = int(value.get("cycle", 0))

func snapshot() -> Dictionary:
    return {"completed":completed.duplicate(true), "active_id":active_id, "cycle":cycle}

func next_challenge() -> Dictionary:
    var available: Array = []
    for item in CHALLENGES:
        if not bool(completed.get(str(item["id"]), false)):
            available.append(item)
    if available.is_empty():
        completed.clear()
        cycle += 1
        available = CHALLENGES.duplicate(true)
    var index := cycle % available.size()
    var chosen: Dictionary = available[index].duplicate(true)
    active_id = str(chosen["id"])
    challenge_started.emit(active_id, str(chosen["word"]), str(chosen["title"]))
    return chosen

func complete_word(word: String) -> Dictionary:
    var normalized := word.to_upper()
    for item in CHALLENGES:
        if str(item["word"]) != normalized:
            continue
        var id := str(item["id"])
        if id != active_id:
            return {}
        completed[id] = true
        active_id = ""
        var reward: Dictionary = item["reward"].duplicate(true)
        challenge_completed.emit(id, reward)
        return item
    return {}
