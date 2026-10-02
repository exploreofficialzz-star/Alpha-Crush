extends RefCounted
class_name TestInventoryCapacity

static func run() -> bool:
    var inventory = preload("res://gameplay/inventory.gd").new()
    inventory.capacity = 2
    if not inventory.add_item("wood", 1):
        return false
    if not inventory.add_item("stone", 1):
        return false
    if inventory.add_item("ore", 1):
        return false
    inventory.increase_capacity(2)
    if not inventory.add_item("ore", 1) or inventory.used_slots() != 3:
        return false
    # Currency must never consume item-stack capacity.
    return inventory.add_item("coins", 100000) and inventory.used_slots() == 3
