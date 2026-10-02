extends Node
class_name HintManager

signal hint_ready(text: String)
var world: Node
var word_system: Node
var hint_cooldown := 0.0

func _process(delta: float) -> void:
    hint_cooldown = maxf(0.0, hint_cooldown - delta)

func request_hint() -> String:
    if hint_cooldown > 0.0:
        return "A hint is cooling down. Explore a little more."
    hint_cooldown = 4.0
    if word_system and not word_system.is_complete():
        var letter: String = word_system.next_missing_letter()
        var message := "Look for a glowing %s nearby. Follow landmarks and paths." % letter
        hint_ready.emit(message)
        return message
    var message := "Look for the next unfinished object with a visible clue."
    hint_ready.emit(message)
    return message
