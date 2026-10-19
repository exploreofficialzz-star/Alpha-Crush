extends Node
class_name EconomyManager

signal coins_changed(value: int)
signal upgrade_changed(id: String, level: int)
signal sold(item_id: String, amount: int, payout: int)

var inventory: Node
var prices: Dictionary = {}
var upgrade_costs: Dictionary = {}
var upgrades: Dictionary = {}
var live_event_manager: Node

func _ready() -> void:
    var f := FileAccess.open("res://data/economy/economy.json", FileAccess.READ)
    if f:
        var d = JSON.parse_string(f.get_as_text())
        if typeof(d) == TYPE_DICTIONARY:
            prices = d.get("base_prices", {}).duplicate(true)
            upgrade_costs = d.get("upgrade_costs", {}).duplicate(true)

func set_live_events(manager: Node) -> void:
    live_event_manager = manager

func add_coins(amount: int) -> void:
    if amount <= 0:
        return
    inventory.add_item("coins", amount)
    coins_changed.emit(inventory.count("coins"))

func spend_coins(amount: int) -> bool:
    if amount <= 0 or not inventory.has_item("coins", amount):
        return false
    inventory.remove_item("coins", amount)
    coins_changed.emit(inventory.count("coins"))
    return true

func price(item: String) -> int:
    return int(prices.get(item, 0))

func sell(item: String, amount: int) -> int:
    # An item without a price is not for sale; removing it would destroy goods for 0 coins.
    if amount <= 0 or price(item) <= 0 or not inventory.has_item(item, amount):
        return 0
    var payout := price(item) * amount
    if live_event_manager:
        payout = int(round(float(payout) * live_event_manager.multiplier("market_bonus")))
    if not inventory.remove_item(item, amount):
        return 0
    add_coins(payout)
    sold.emit(item, amount, payout)
    return payout

func upgrade(id: String) -> bool:
    var level := int(upgrades.get(id, 0))
    var base_cost := int(upgrade_costs.get(id, 100))
    var cost := base_cost * (level + 1)
    if not spend_coins(cost):
        return false
    upgrades[id] = level + 1
    upgrade_changed.emit(id, int(upgrades[id]))
    return true

func upgrade_level(id: String) -> int:
    return int(upgrades.get(id, 0))
