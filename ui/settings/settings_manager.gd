extends Node
class_name SettingsManager

signal changed
var settings := {
    "quality": "medium",
    "music": true,
    "sfx": true,
    "vibration": true,
    "text_scale": 1.0,
    "high_contrast": false,
    "camera_sensitivity": 1.0
}

func set_value(key: String, value: Variant) -> void:
    settings[key] = value
    changed.emit()

func get_value(key: String, fallback: Variant = null) -> Variant:
    return settings.get(key, fallback)

func snapshot() -> Dictionary:
    return settings.duplicate(true)

func restore(value: Dictionary) -> void:
    for key in value.keys():
        settings[key] = value[key]
    changed.emit()
