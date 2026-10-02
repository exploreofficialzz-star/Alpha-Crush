extends RefCounted
class_name TestCraftingManager

static func run() -> bool:
    var inv = preload("res://gameplay/inventory.gd").new()
    inv.capacity = 5
    inv.add_item("wood", 5)
    var manager = preload("res://gameplay/crafting/crafting_manager.gd").new()
    manager.inventory = inv
    manager.recipes = {"basket": {"inputs": {"wood": 5}, "output": "basket", "amount": 1}}
    if not manager.can_craft("basket"):
        return false
    if not manager.craft("basket"):
        return false
    if inv.count("wood") != 0 or inv.count("basket") != 1:
        return false
    inv.remove_item("basket", 1)
    inv.capacity = 2
    inv.add_item("stone", 1)
    inv.add_item("wood", 1)
    inv.capacity = 1
    manager.recipes["crate"] = {"inputs": {"stone": 1}, "output": "crate", "amount": 2}
    return not manager.craft("crate") and inv.count("stone") == 1 and inv.count("crate") == 0
