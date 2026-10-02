extends Node
class_name AdService

signal reward_granted(kind: String)
signal ad_failed(kind: String, reason: String)

var sdk_available := false
var remove_ads := false
var consent_manager: Node
var app_id := ""
var ad_unit_ids: Dictionary = {}

func initialize() -> void:
    sdk_available = false
    var f := FileAccess.open("res://data/monetization/store.json", FileAccess.READ)
    if f:
        var config = JSON.parse_string(f.get_as_text())
        if config is Dictionary:
            app_id = str(config.get("android_app_id", ""))
            ad_unit_ids = config.get("ads", {}).duplicate(true)

func configure_consent(manager: Node) -> void:
    consent_manager = manager

func show_rewarded(kind: String) -> bool:
    if not sdk_available:
        ad_failed.emit(kind, "sdk_unavailable")
        return false
    # A real SDK callback must call complete_rewarded() after verifying the ad
    # completion. Requesting an ad alone never grants gameplay currency.
    return true

func complete_rewarded(kind: String, verified: bool) -> void:
    if not verified:
        ad_failed.emit(kind, "reward_not_verified")
        return
    reward_granted.emit(kind)

func show_interstitial() -> bool:
    if remove_ads or not sdk_available:
        return false
    return true

func can_personalize() -> bool:
    return consent_manager != null and consent_manager.allows_personalized_ads()
