extends RefCounted
class_name TestEconomy

static func run() -> bool:
    var inventory = preload("res://gameplay/inventory.gd").new()
    inventory.capacity = 2
    inventory.add_item("coins", 100)
    inventory.add_item("wood", 3)
    inventory.add_item("stone", 2)
    if inventory.add_item("ore", 1):
        return false
    var economy = preload("res://economy/currencies/economy_manager.gd").new()
    economy.inventory = inventory
    economy._ready()
    var payout: int = economy.sell("wood", 2)
    return payout == 16 and inventory.count("wood") == 1 and inventory.count("coins") == 116
