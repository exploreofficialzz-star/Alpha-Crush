extends RefCounted
class_name TestMarketOrderBoard

static func run() -> bool:
    var board: MarketOrderBoard = preload("res://gameplay/marketplace/order_board.gd").new()
    var economy: EconomyManager = preload("res://economy/currencies/economy_manager.gd").new()
    var inventory: Inventory = preload("res://gameplay/inventory.gd").new()
    economy.inventory = inventory
    economy.prices = {"fruit_apple": 10, "fruit_orange": 12, "fruit_mango": 20, "crop_wheat": 5, "wood": 8, "stone": 9, "ore": 25}
    board.setup(null, inventory, economy, null)
    if board.active_order.is_empty() or board.fulfill() != 0:
        return false
    var item := str(board.active_order["item"])
    var amount := int(board.active_order["amount"])
    inventory.add_item(item, amount)
    var payout := board.fulfill()
    var expected := int(round(float(int(economy.prices[item]) * amount) * 1.25))
    # Fulfilling pays the bonus price, consumes the goods and immediately queues the next order.
    return payout == expected and inventory.count(item) == 0 and inventory.count("coins") == expected and not board.active_order.is_empty()
