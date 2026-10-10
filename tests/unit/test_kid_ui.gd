extends RefCounted
class_name TestKidUI

## Every word goal, inventory item and action context must have a real picture, because the HUD
## teaches by pictures for children who cannot read yet.
const CONTEXT_KINDS: Array[String] = ["pickup", "harvest", "talk", "garden", "market", "workshop", "discover", "field", "boat", "storage", "bridge", "dock", "gate", "beacon"]
const ITEM_IDS: Array[String] = ["coins", "gems", "fruit_apple", "fruit_orange", "fruit_mango", "fruit_berry", "crop_wheat", "wood", "stone", "ore", "flower", "basket", "lantern", "seeds", "crate", "letter"]

static func _icon_exists(icon_name: String) -> bool:
    return FileAccess.file_exists("%s%s.png" % [KidUI.ICON_DIR, icon_name])

static func run() -> bool:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/words/words.json"))
    if not (parsed is Array) or (parsed as Array).is_empty():
        return false
    for entry in parsed:
        var word := str((entry as Dictionary).get("display_word", ""))
        var icon_name := KidUI.word_icon(word)
        if icon_name == "sparkle" or not _icon_exists(icon_name):
            return false
    for item_id in ITEM_IDS:
        if not _icon_exists(KidUI.item_icon_name(item_id)):
            return false
    for kind in CONTEXT_KINDS:
        if not _icon_exists(KidUI.context_icon_name(kind)):
            return false
    for fixed in ["hand", "jump", "bag", "map", "bulb", "gear", "close", "lock", "play", "boy", "girl", "coin", "gem", "star_gold", "pointer", "sparkle", "explore"]:
        if not _icon_exists(fixed):
            return false
    return KidUI.word_icon("not-a-word") == "sparkle" and KidUI.place_icon_name("Elevated Garden") == "seeds"
