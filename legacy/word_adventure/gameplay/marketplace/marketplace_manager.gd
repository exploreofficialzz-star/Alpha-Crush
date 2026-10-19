extends Node
class_name MarketplaceManager

signal order_created(order: Dictionary)
signal order_fulfilled(order_id: String, payout: int)

var economy: Node
var active_orders: Array = []

func create_order(item: String, amount: int, bonus: float = 1.25) -> Dictionary:
    var order := {
        "id": "%s-%s-%s" % [str(Time.get_unix_time_from_system()), item, str(active_orders.size())],
        "item": item,
        "amount": amount,
        "bonus": bonus
    }
    active_orders.append(order)
    order_created.emit(order)
    return order

func fulfill(order_id: String, inventory: Node) -> int:
    for order in active_orders:
        if str(order.get("id", "")) != order_id:
            continue
        var item := str(order.get("item", ""))
        var amount := int(order.get("amount", 0))
        if inventory == null or not inventory.has_item(item, amount):
            return 0
        inventory.remove_item(item, amount)
        var base: int = int(economy.price(item)) if economy and economy.has_method("price") else 0
        var payout := int(round(float(base * amount) * float(order.get("bonus", 1.0))))
        if economy:
            economy.add_coins(payout)
        active_orders.erase(order)
        order_fulfilled.emit(order_id, payout)
        return payout
    return 0
