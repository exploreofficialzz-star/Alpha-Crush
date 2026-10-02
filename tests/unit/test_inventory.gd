extends RefCounted
class_name TestInventory

static func run() -> bool:
    var inv: Inventory = preload("res://gameplay/inventory.gd").new()
    inv.capacity = 2
    var added_wood: bool = inv.add_item("wood", 5)
    var removed_wood: bool = inv.remove_item("wood", 2)
    var wood_left: bool = inv.count("wood") == 3
    var added_stone: bool = inv.add_item("stone", 1)
    var rejected_ore: bool = not inv.add_item("ore", 1)
    # Regression: Inventory called an undefined _is_currency(), so the whole script failed to compile.
    # Currencies share the item dictionary but must never consume a stack slot.
    var coins_free: bool = inv.add_item("coins", 100) and inv.add_item("gems", 3) and inv.used_slots() == 2
    return added_wood and removed_wood and wood_left and added_stone and rejected_ore and coins_free
