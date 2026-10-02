extends Node
class_name WordSystem

signal word_started(word: String)
signal letter_collected(letter: String)
signal assembly_ready(word: String)
signal word_completed(word: String)

var database: Node
var world: Node
var active_word := ""
var required: Dictionary = {}
var collected: Dictionary = {}
var completed_words: Dictionary = {}
var history: Array = []

func _ready() -> void:
    database = preload("res://words/database/word_database.gd").new()
    database.name = "WordDatabase"
    add_child(database)

func begin_word(word: String) -> void:
    active_word = word.to_upper()
    required.clear()
    collected.clear()
    for c in active_word:
        required[c] = int(required.get(c, 0)) + 1
    word_started.emit(active_word)

func has_active_word() -> bool:
    return not active_word.is_empty()

func clear_active_word() -> void:
    active_word = ""
    required.clear()
    collected.clear()

func collect_letter(letter: String) -> bool:
    var c := letter.to_upper()
    if not required.has(c):
        return false
    var have := int(collected.get(c, 0))
    var need := int(required[c])
    if have >= need:
        return false
    collected[c] = have + 1
    letter_collected.emit(c)
    if is_complete():
        assembly_ready.emit(active_word)
        # Complete on the deferred tick so the world can finish the physical
        # letter pickup/reparent operation before the consequence clears it.
        call_deferred("_complete_if_ready", active_word)
    return true

func _complete_if_ready(word: String) -> void:
    if word == active_word and is_complete():
        complete_word()


func release_letter(letter: String) -> bool:
    var c := letter.to_upper()
    var have := int(collected.get(c, 0))
    if have <= 0 or not required.has(c):
        return false
    collected[c] = have - 1
    if collected[c] <= 0:
        collected.erase(c)
    return true

func next_missing_letter() -> String:
    for c in active_word:
        if int(collected.get(c, 0)) < int(required.get(c, 0)):
            return c
    return "?"

func is_complete() -> bool:
    if active_word.is_empty():
        return false
    for c in required.keys():
        if int(collected.get(c, 0)) < int(required[c]):
            return false
    return true

func complete_word() -> void:
    if not is_complete() or completed_words.has(active_word):
        return
    completed_words[active_word] = true
    history.append({"word": active_word, "time": Time.get_unix_time_from_system()})
    word_completed.emit(active_word)

func progress_text() -> String:
    if active_word.is_empty():
        return ""
    var out := ""
    for c in active_word:
        out += c if int(collected.get(c, 0)) > 0 else "_"
    return out + "  " + str(total_collected()) + "/" + str(active_word.length())

func total_collected() -> int:
    var n := 0
    for value in collected.values():
        n += int(value)
    return n

func snapshot() -> Dictionary:
    return {"active_word": active_word, "collected": collected.duplicate(true), "completed": completed_words.duplicate(true), "history": history.duplicate(true)}

func restore(value: Dictionary) -> void:
    completed_words = value.get("completed", {}).duplicate(true)
    history = value.get("history", []).duplicate(true)
    active_word = str(value.get("active_word", "")).to_upper()
    collected = value.get("collected", {}).duplicate(true)
    required.clear()
    for c in active_word:
        required[c] = int(required.get(c, 0)) + 1
