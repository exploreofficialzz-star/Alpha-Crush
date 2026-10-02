extends Node
class_name ConsentManager

signal changed(personalized_ads: bool)
var personalized_ads := false
var consent_collected := false

func set_consent(personalized: bool) -> void:
    personalized_ads = personalized
    consent_collected = true
    changed.emit(personalized_ads)

func allows_personalized_ads() -> bool:
    return consent_collected and personalized_ads

func snapshot() -> Dictionary:
    return {"consent_collected": consent_collected, "personalized_ads": personalized_ads}

func restore(value: Dictionary) -> void:
    consent_collected = bool(value.get("consent_collected", false))
    personalized_ads = consent_collected and bool(value.get("personalized_ads", false))
    changed.emit(personalized_ads)
