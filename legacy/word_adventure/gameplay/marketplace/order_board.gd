extends Node
class_name MarketOrderBoard

signal order_ready(order: Dictionary)
signal order_fulfilled(order_id: String, payout: int)

var manager: MarketplaceManager
var inventory: Inventory
var economy: EconomyManager
var live_events: LiveEventManager
var active_order: Dictionary = {}
var sequence := 0

const ORDER_POOL := [
    {"item":"fruit_apple","amount":4,"title":"Fresh apples"},
    {"item":"fruit_orange","amount":3,"title":"Orchard oranges"},
    {"item":"fruit_mango","amount":2,"title":"Sweet mangoes"},
    {"item":"crop_wheat","amount":6,"title":"Wheat shipment"},
    {"item":"wood","amount":8,"title":"Building timber"},
    {"item":"stone","amount":7,"title":"Stone delivery"},
    {"item":"ore","amount":3,"title":"Refined ore"}
]

func setup(market_manager: MarketplaceManager, inv: Inventory, econ: EconomyManager, events: LiveEventManager) -> void:
    manager = market_manager
    inventory = inv
    economy = econ
    live_events = events
    refresh_order()

func refresh_order() -> void:
    if not active_order.is_empty():
        return
    var item: Dictionary = ORDER_POOL[sequence % ORDER_POOL.size()].duplicate(true)
    sequence += 1
    var bonus := 1.25
    if live_events:
        bonus *= live_events.multiplier("market_bonus")
    active_order = {
        "id":"market_order_%d" % sequence,
        "item":str(item["item"]),
        "amount":int(item["amount"]),
        "title":str(item["title"]),
        "bonus":bonus
    }
    order_ready.emit(active_order.duplicate(true))

func can_fulfill() -> bool:
    return not active_order.is_empty() and inventory != null and inventory.has_item(str(active_order["item"]), int(active_order["amount"]))

func fulfill() -> int:
    if active_order.is_empty() or not can_fulfill():
        return 0
    var item := str(active_order["item"])
    var amount := int(active_order["amount"])
    inventory.remove_item(item, amount)
    var base := economy.price(item) if economy else 0
    var payout := int(round(float(base * amount) * float(active_order.get("bonus", 1.25))))
    if economy:
        economy.add_coins(payout)
    var id := str(active_order["id"])
    active_order.clear()
    order_fulfilled.emit(id, payout)
    refresh_order()
    return payout

func snapshot() -> Dictionary:
    return {"active_order":active_order.duplicate(true), "sequence":sequence}

func restore(value: Dictionary) -> void:
    active_order = value.get("active_order", {}).duplicate(true)
    sequence = int(value.get("sequence", 0))
    if active_order.is_empty():
        refresh_order()
