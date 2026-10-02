extends Node
class_name PurchaseService

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var plugin_available := false
var entitlements: Dictionary = {}
var pending: Dictionary = {}
var products: Dictionary = {}

func initialize() -> void:
    plugin_available = false
    var f := FileAccess.open("res://data/monetization/store.json", FileAccess.READ)
    if f:
        var config = JSON.parse_string(f.get_as_text())
        if config is Dictionary:
            products = config.get("products", {}).duplicate(true)

func begin_purchase(product_id: String) -> bool:
    if product_id.is_empty() or not products.has(product_id):
        purchase_failed.emit(product_id, "unknown_product")
        return false
    if not plugin_available:
        purchase_failed.emit(product_id, "store_sdk_unavailable")
        return false
    pending[product_id] = Time.get_unix_time_from_system()
    return true

func purchase(product_id: String) -> bool:
    return begin_purchase(product_id)

func restore() -> bool:
    if not plugin_available:
        purchase_failed.emit("restore", "store_sdk_unavailable")
        return false
    for product_id in entitlements.keys():
        var product: Dictionary = products.get(str(product_id), {})
        if str(product.get("type", "")) == "non_consumable":
            purchase_completed.emit(str(product_id))
    return true

func confirm_purchase(product_id: String, verified: bool) -> void:
    if not pending.has(product_id):
        return
    pending.erase(product_id)
    if verified:
        # Only non-consumables are permanent entitlements. A consumable (coin pack) is
        # granted once by the purchase_completed handler and must never be "restored".
        var product: Dictionary = products.get(product_id, {})
        if str(product.get("type", "")) == "non_consumable":
            entitlements[product_id] = true
        purchase_completed.emit(product_id)
    else:
        purchase_failed.emit(product_id, "verification_failed")

func has_entitlement(product_id: String) -> bool:
    return bool(entitlements.get(product_id, false))
