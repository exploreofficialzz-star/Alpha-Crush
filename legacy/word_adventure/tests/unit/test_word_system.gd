extends RefCounted
class_name TestWordSystem

static func run() -> bool:
    var word = preload("res://words/word_system.gd").new()
    word.begin_word("BASKET")
    for letter in ["B", "A", "S", "K", "E", "T"]:
        if not word.collect_letter(letter):
            return false
    if not word.is_complete() or word.total_collected() != 6:
        return false
    if word.collect_letter("B"):
        return false
    return word.next_missing_letter() == "?"
