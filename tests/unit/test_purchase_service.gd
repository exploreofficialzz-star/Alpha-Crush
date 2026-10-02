extends RefCounted
class_name TestPurchaseService

static func run() -> bool:
    var service: PurchaseService = preload("res://economy/purchases/purchase_service.gd").new()
    service.products = {
        "remove_ads": {"type": "non_consumable"},
        "coin_pack_small": {"type": "consumable"}
    }
    service.plugin_available = true
    var completed: Array[String] = []
    var owned_before_restore := false
    service.purchase_completed.connect(func(product_id: String): completed.append(product_id))
    if not service.begin_purchase("remove_ads"):
        return false
    service.confirm_purchase("remove_ads", true)
    if not service.begin_purchase("coin_pack_small"):
        return false
    service.confirm_purchase("coin_pack_small", true)
    owned_before_restore = service.has_entitlement("remove_ads")
    service.restore()
    # Regression: consumables used to be stored as permanent entitlements.
    var consumable_not_owned: bool = not service.has_entitlement("coin_pack_small")
    service.free()
    return owned_before_restore and completed == ["remove_ads", "coin_pack_small", "remove_ads"] and consumable_not_owned
