extends RefCounted
class_name TestConsentManager

static func run() -> bool:
    var consent: ConsentManager = preload("res://ads/consent/consent_manager.gd").new()
    var ads: AdService = preload("res://ads/admob/ad_service.gd").new()
    ads.configure_consent(consent)
    if ads.can_personalize():
        return false
    consent.set_consent(true)
    if not ads.can_personalize():
        return false
    var saved: Dictionary = consent.snapshot()
    var restored: ConsentManager = preload("res://ads/consent/consent_manager.gd").new()
    restored.restore(saved)
    ads.configure_consent(restored)
    if not ads.can_personalize():
        return false
    restored.set_consent(false)
    return not ads.can_personalize() and restored.consent_collected
