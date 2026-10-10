extends Node
class_name QualityManager

## Graphics tiers. "lowest" is only ever reached automatically (AdaptiveQuality) when a phone
## cannot hold frame rate on "low". Keys used by other systems: shadow, distance, effects, grass,
## props, stream_radius, tree_shadows. Keys applied to the viewport here: scale_3d, msaa, fps,
## shadow_size, shadow_filter, aniso, mip_bias.
signal changed(level: String)

const ORDER: Array[String] = ["lowest", "low", "medium", "high", "ultra"]

var quality := "medium"
var _viewport_level := ""
var settings := {
    "lowest": {"shadow": false, "distance": 0.5, "effects": 0.25, "grass": 0.0, "props": 0.4, "stream_radius": 1, "tree_shadows": false,
        "scale_3d": 0.55, "msaa": 0, "fps": 30, "shadow_size": 1024, "shadow_filter": 0, "aniso": 0, "mip_bias": 1.0},
    "low": {"shadow": false, "distance": 0.65, "effects": 0.45, "grass": 0.0, "props": 0.6, "stream_radius": 1, "tree_shadows": false,
        "scale_3d": 0.7, "msaa": 0, "fps": 30, "shadow_size": 1024, "shadow_filter": 0, "aniso": 0, "mip_bias": 0.5},
    "medium": {"shadow": true, "distance": 0.8, "effects": 0.65, "grass": 0.55, "props": 0.85, "stream_radius": 2, "tree_shadows": false,
        "scale_3d": 0.85, "msaa": 0, "fps": 60, "shadow_size": 2048, "shadow_filter": 1, "aniso": 1, "mip_bias": 0.0},
    "high": {"shadow": true, "distance": 1.0, "effects": 0.85, "grass": 1.0, "props": 1.0, "stream_radius": 2, "tree_shadows": true,
        "scale_3d": 1.0, "msaa": 1, "fps": 60, "shadow_size": 2048, "shadow_filter": 2, "aniso": 2, "mip_bias": 0.0},
    "ultra": {"shadow": true, "distance": 1.2, "effects": 1.0, "grass": 1.5, "props": 1.2, "stream_radius": 3, "tree_shadows": true,
        "scale_3d": 1.0, "msaa": 2, "fps": 60, "shadow_size": 4096, "shadow_filter": 3, "aniso": 3, "mip_bias": 0.0}
}

func apply(value: String) -> void:
    var next := value.to_lower()
    if not settings.has(next):
        next = "medium"
    quality = next
    if quality != _viewport_level and is_inside_tree():
        _viewport_level = quality
        apply_to_viewport(get_viewport())
    changed.emit(quality)

func current() -> Dictionary:
    return settings.get(quality, settings["medium"])

func presets() -> Array:
    return ["low", "medium", "high", "ultra"]

## The next tier down from `level`, or `level` itself when already at the floor.
func lower_level(level: String = "") -> String:
    var from := quality if level.is_empty() else level
    var index := ORDER.find(from)
    if index <= 0:
        return ORDER[0]
    return ORDER[index - 1]

func is_floor() -> bool:
    return quality == ORDER[0]

## Render-resolution, anti-aliasing, shadow-atlas and frame-rate limits for this tier.
func apply_to_viewport(vp: Viewport) -> void:
    if vp == null:
        return
    var q: Dictionary = current()
    vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    vp.scaling_3d_scale = clampf(float(q.get("scale_3d", 1.0)), 0.5, 1.0)
    vp.msaa_3d = int(q.get("msaa", 0)) as Viewport.MSAA
    vp.anisotropic_filtering_level = int(q.get("aniso", 1)) as Viewport.AnisotropicFiltering
    if "texture_mipmap_bias" in vp:
        vp.set("texture_mipmap_bias", float(q.get("mip_bias", 0.0)))
    Engine.max_fps = int(q.get("fps", 60))
    RenderingServer.directional_shadow_atlas_set_size(int(q.get("shadow_size", 2048)), true)
    RenderingServer.directional_soft_shadow_filter_set_quality(int(q.get("shadow_filter", 1)) as RenderingServer.ShadowQuality)
