extends Node
class_name WordDatabase

var definitions: Dictionary = {}

func _ready() -> void:
    var f := FileAccess.open("res://data/words/words.json", FileAccess.READ)
    if not f:
        return
    var d = JSON.parse_string(f.get_as_text())
    if typeof(d) == TYPE_ARRAY:
        for item in d:
            if item is Dictionary:
                definitions[str(item.get("id", ""))] = item

func get_word(id: String) -> Dictionary:
    return definitions.get(id.to_lower(), {})

func get_words_for_region(region: String) -> Array:
    var result: Array = []
    for item in definitions.values():
        var environment := str(item.get("environment", "all"))
        if environment == "all" or environment == region:
            result.append(item)
    return result

func is_valid(id: String) -> bool:
    return definitions.has(id.to_lower())
