extends RefCounted
class_name TestAdService

static func run() -> bool:
    var service: AdService = preload("res://ads/admob/ad_service.gd").new()
    var rewards: Array[String] = []
    service.reward_granted.connect(func(kind: String): rewards.append(kind))
    service.sdk_available = true
    var request_ok := service.show_rewarded("coins")
    if not request_ok or not rewards.is_empty():
        return false
    service.complete_rewarded("coins", false)
    if not rewards.is_empty():
        return false
    service.complete_rewarded("coins", true)
    return rewards == ["coins"]
