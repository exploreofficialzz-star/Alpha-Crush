extends RefCounted
class_name TestQualityManager

const LEGACY_KEYS: Array[String] = ["shadow", "distance", "effects", "grass", "props", "stream_radius", "tree_shadows"]
const RENDER_KEYS: Array[String] = ["scale_3d", "msaa", "fps", "shadow_size", "shadow_filter", "aniso", "mip_bias"]

static func run() -> bool:
    var quality: QualityManager = preload("res://mobile/quality_manager.gd").new()
    for level in QualityManager.ORDER:
        var tier: Dictionary = quality.settings.get(level, {})
        for key in LEGACY_KEYS:
            if not tier.has(key):
                return false
        for key in RENDER_KEYS:
            if not tier.has(key):
                return false
    # Lower tiers must really be lighter: smaller render scale, never a higher frame cap.
    var previous_scale := 0.0
    for level in QualityManager.ORDER:
        var scale_value := float(quality.settings[level]["scale_3d"])
        if scale_value < previous_scale:
            return false
        previous_scale = scale_value
    if int(quality.settings["low"]["fps"]) != 30 or int(quality.settings["lowest"]["fps"]) != 30:
        return false
    if bool(quality.settings["low"]["shadow"]):
        return false
    # Stepping down walks the ladder and stops at the floor.
    if quality.lower_level("ultra") != "high" or quality.lower_level("medium") != "low":
        return false
    if quality.lower_level("lowest") != "lowest":
        return false
    quality.apply("not-a-tier")
    if quality.quality != "medium":
        return false
    quality.apply("lowest")
    var floor_ok := quality.is_floor()
    quality.free()
    return floor_ok
