extends RefCounted
class_name TestSettingsManager

static func run() -> bool:
    var settings = preload("res://ui/settings/settings_manager.gd").new()
    settings.set_value("music", false)
    settings.set_value("camera_sensitivity", 1.6)
    settings.set_value("high_contrast", true)
    var snapshot: Dictionary = settings.snapshot()
    var restored = preload("res://ui/settings/settings_manager.gd").new()
    restored.restore(snapshot)
    return not bool(restored.get_value("music", true)) and is_equal_approx(float(restored.get_value("camera_sensitivity", 1.0)), 1.6) and bool(restored.get_value("high_contrast", false))
