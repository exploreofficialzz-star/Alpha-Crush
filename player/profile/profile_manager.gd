extends Node
class_name PlayerProfileManager

signal changed

var display_name := "Explorer"
var avatar_style := "default"
var outfit := "field_jacket"
var backpack := "starter_pack"
var emotes: Array[String] = ["wave", "celebrate"]

func configure(name_value: String = "Explorer") -> void:
    display_name = name_value.strip_edges()
    if display_name.is_empty():
        display_name = "Explorer"
    changed.emit()

func set_customization(style_id: String, outfit_id: String, backpack_id: String) -> void:
    avatar_style = style_id
    outfit = outfit_id
    backpack = backpack_id
    changed.emit()

func snapshot() -> Dictionary:
    return {
        "display_name": display_name,
        "avatar_style": avatar_style,
        "outfit": outfit,
        "backpack": backpack,
        "emotes": emotes.duplicate()
    }

func restore(value: Dictionary) -> void:
    display_name = str(value.get("display_name", display_name))
    avatar_style = str(value.get("avatar_style", avatar_style))
    outfit = str(value.get("outfit", outfit))
    backpack = str(value.get("backpack", backpack))
    var saved_emotes = value.get("emotes", emotes)
    if saved_emotes is Array:
        emotes = []
        for item in saved_emotes:
            emotes.append(str(item))
    changed.emit()
