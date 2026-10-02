extends Node
class_name CampaignManager

signal chapter_started(id: String, title: String, word: String)
signal chapter_completed(id: String, reward: Dictionary)
signal finale_unlocked
signal finale_completed

const CHAPTERS := [
    {"id":"garden","title":"Elevated Garden","word":"LADDER","reward":{"coins":40,"xp":80}},
    {"id":"orchard","title":"Wake the Orchard","word":"ORANGE","reward":{"coins":55,"xp":100}},
    {"id":"basket","title":"Carry the Harvest","word":"BASKET","reward":{"coins":70,"xp":120}},
    {"id":"market","title":"Open the Market","word":"MARKET","reward":{"coins":90,"xp":150}},
    {"id":"bridge","title":"Reconnect the Riverlands","word":"BRIDGE","reward":{"coins":110,"xp":180}},
    {"id":"farmland","title":"Bring Back the Fields","word":"SEEDS","reward":{"coins":125,"xp":210}},
    {"id":"workshop","title":"Restore the Workshop","word":"TOOLS","reward":{"coins":140,"xp":240}},
    {"id":"cave","title":"Light the Deep","word":"LANTERN","reward":{"coins":160,"xp":270}},
    {"id":"harbor","title":"Return to the Water","word":"ENGINE","reward":{"coins":180,"xp":300}},
    {"id":"storage","title":"Unlock the Old Stores","word":"KEY","reward":{"coins":200,"xp":340}},
    {"id":"beacon","title":"Light the Horizon","word":"LIGHT","reward":{"coins":230,"xp":380}},
    {"id":"unity","title":"Bring Everyone Together","word":"TOGETHER","reward":{"coins":500,"xp":800}}
]

# The last chapter is the finale word itself. It can only be played once every other
# chapter is restored, so "finale ready" must not depend on the finale chapter being done.
const FINALE_CHAPTER_ID := "unity"

# Some chapters can be reached through an alternate word (the closed market asks for OPEN when the
# player arrives before the MARKET chain). Both must restore the same chapter, or the story stalls.
const WORD_ALIASES := {"OPEN": "MARKET"}

var current_index := 0
var completed: Dictionary = {}
var finale_ready := false
var finale_done := false
var postgame_unlocked := false

func restore(value: Dictionary) -> void:
    completed = value.get("completed", {}).duplicate(true)
    finale_done = bool(value.get("finale_done", false))
    postgame_unlocked = bool(value.get("postgame_unlocked", false)) or finale_done
    current_index = _first_incomplete_index()
    # Self-heal saves made before the finale unlock was fixed: if every story chapter is
    # already restored the Community Hall must offer the final word.
    finale_ready = bool(value.get("finale_ready", false)) or finale_done or _story_chapters_complete()

func _first_incomplete_index() -> int:
    for i in range(CHAPTERS.size()):
        if not bool(completed.get(str(CHAPTERS[i]["id"]), false)):
            return i
    return CHAPTERS.size()

func _story_chapters_complete() -> bool:
    for chapter in CHAPTERS:
        var chapter_id := str(chapter["id"])
        if chapter_id == FINALE_CHAPTER_ID:
            continue
        if not bool(completed.get(chapter_id, false)):
            return false
    return true

func snapshot() -> Dictionary:
    return {"current_index": current_index, "completed": completed.duplicate(true), "finale_ready": finale_ready, "finale_done": finale_done, "postgame_unlocked": postgame_unlocked}

func current() -> Dictionary:
    if current_index >= CHAPTERS.size():
        return {}
    return CHAPTERS[current_index].duplicate(true)

func is_complete(id: String) -> bool:
    return bool(completed.get(id, false))

func start_next() -> Dictionary:
    if current_index >= CHAPTERS.size():
        return {}
    var chapter: Dictionary = current()
    chapter_started.emit(str(chapter["id"]), str(chapter["title"]), str(chapter["word"]))
    return chapter

func complete_for_word(word: String) -> Dictionary:
    var normalized := word.to_upper()
    normalized = str(WORD_ALIASES.get(normalized, normalized))
    for i in range(CHAPTERS.size()):
        var chapter: Dictionary = CHAPTERS[i]
        if str(chapter["word"]) != normalized:
            continue
        var id := str(chapter["id"])
        if bool(completed.get(id, false)):
            return {}
        completed[id] = true
        current_index = _first_incomplete_index()
        if not finale_ready and not finale_done and _story_chapters_complete():
            finale_ready = true
            finale_unlocked.emit()
        var reward: Dictionary = chapter["reward"].duplicate(true)
        chapter_completed.emit(id, reward)
        return chapter
    return {}

func complete_finale() -> void:
    if not finale_ready or finale_done:
        return
    finale_done = true
    postgame_unlocked = true
    finale_completed.emit()

func is_game_complete() -> bool:
    return finale_done

func postgame_status() -> String:
    if finale_done:
        return "WORLD COMPLETE • ENDLESS EXPLORATION UNLOCKED"
    if finale_ready:
        return "FINALE READY • Gather at the Community Hall"
    return "%d / %d world chapters restored" % [completed.size(), CHAPTERS.size()]
