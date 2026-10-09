extends Node
class_name QualityManager

signal changed(level: String)
var quality := "medium"
var settings := {
    "low": {"shadow": false, "distance": 0.65, "effects": 0.45, "grass": 0.0, "props": 0.6, "stream_radius": 1, "tree_shadows": false},
    "medium": {"shadow": true, "distance": 0.8, "effects": 0.65, "grass": 0.55, "props": 0.85, "stream_radius": 2, "tree_shadows": false},
    "high": {"shadow": true, "distance": 1.0, "effects": 0.85, "grass": 1.0, "props": 1.0, "stream_radius": 2, "tree_shadows": true},
    "ultra": {"shadow": true, "distance": 1.2, "effects": 1.0, "grass": 1.5, "props": 1.2, "stream_radius": 3, "tree_shadows": true}
}

func apply(value: String) -> void:
    quality = value.to_lower()
    if not settings.has(quality): quality = "medium"
    changed.emit(quality)

func current() -> Dictionary:
    return settings.get(quality, settings["medium"])

func presets() -> Array:
    return ["low", "medium", "high", "ultra"]
