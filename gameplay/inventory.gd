extends Node
class_name Inventory

signal changed
signal rejected(item_id: String, amount: int)
var items: Dictionary = {}
var capacity := 48
var base_capacity := 48

# Currencies live in the same dictionary but never consume item-stack capacity.
const CURRENCY_IDS: Array[String] = ["coins", "gems"]

func _is_currency(id: String) -> bool:
    return CURRENCY_IDS.has(id)

func add_item(id: String, amount: int = 1) -> bool:
    if amount <= 0:
        return false
    if not _is_currency(id) and not items.has(id) and used_slots() >= capacity:
        rejected.emit(id, amount)
        return false
    items[id] = int(items.get(id, 0)) + amount
    changed.emit()
    return true

func remove_item(id: String, amount: int = 1) -> bool:
    if amount <= 0 or count(id) < amount:
        return false
    items[id] = count(id) - amount
    if items[id] <= 0:
        items.erase(id)
    changed.emit()
    return true

func has_item(id: String, amount: int = 1) -> bool:
    return count(id) >= amount

func count(id: String) -> int:
    return int(items.get(id, 0))

func used_slots() -> int:
    # Capacity represents occupied item stacks, not the quantity inside a stack.
    # This allows a stack of 20 wood to occupy one slot, like a mobile inventory.
    var slots := 0
    for item_id in items.keys():
        if _is_currency(str(item_id)):
            continue
        if int(items[item_id]) > 0:
            slots += 1
    return slots

func snapshot() -> Dictionary:
    return items.duplicate(true)

func increase_capacity(amount: int) -> void:
    if amount <= 0:
        return
    capacity += amount
    changed.emit()

func restore(value: Dictionary) -> void:
    items.clear()
    for item_id in value.keys():
        var amount := int(value[item_id])
        if amount > 0:
            items[str(item_id)] = amount
    changed.emit()
