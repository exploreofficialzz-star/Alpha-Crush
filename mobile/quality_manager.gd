extends Node
class_name QualityManager

signal changed(level: String)
var quality := "medium"
var settings := {
    "low": {"shadow": false, "distance": 0.65, "effects": 0.45},
    "medium": {"shadow": true, "distance": 0.8, "effects": 0.65},
    "high": {"shadow": true, "distance": 1.0, "effects": 0.85},
    "ultra": {"shadow": true, "distance": 1.2, "effects": 1.0}
}

func apply(value: String) -> void:
    quality = value.to_lower()
    if not settings.has(quality): quality = "medium"
    changed.emit(quality)

func current() -> Dictionary:
    return settings.get(quality, settings["medium"])

func presets() -> Array:
    return ["low", "medium", "high", "ultra"]
