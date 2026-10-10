extends RefCounted
class_name TestConsentManager

static func run() -> bool:
    var consent: ConsentManager = preload("res://ads/consent/consent_manager.gd").new()
    consent.child_directed = false  # exercise the adult-audience path
    var ads: AdService = preload("res://ads/admob/ad_service.gd").new()
    ads.configure_consent(consent)
    if ads.can_personalize():
        return false
    consent.set_consent(true)
    if not ads.can_personalize():
        return false
    var saved: Dictionary = consent.snapshot()
    var restored: ConsentManager = preload("res://ads/consent/consent_manager.gd").new()
    restored.child_directed = false
    restored.restore(saved)
    ads.configure_consent(restored)
    if not ads.can_personalize():
        return false
    restored.set_consent(false)
    if ads.can_personalize() or not restored.consent_collected:
        return false
    # A children's build can never turn personalised ads on, even from an old save that says yes.
    var kids: ConsentManager = preload("res://ads/consent/consent_manager.gd").new()
    kids.child_directed = true
    kids.set_consent(true)
    if kids.allows_personalized_ads():
        return false
    kids.restore({"consent_collected": true, "personalized_ads": true})
    return not kids.allows_personalized_ads()
