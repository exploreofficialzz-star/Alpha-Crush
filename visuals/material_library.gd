extends RefCounted
class_name MaterialLibrary

## Central place that turns the material *names* used inside the generated models
## (assets/models/*.glb) into real PBR materials built from assets/textures/*.
## Everything degrades gracefully: a missing texture just leaves a flat colour.

const TEX := "res://assets/textures/"
const SHADERS := "res://visuals/shaders/"

# id -> [texture base name, fallback colour]
const TEXTURED := {
    "grass": ["grass", Color(0.25, 0.40, 0.10)], "dirt": ["dirt", Color(0.36, 0.27, 0.18)], "rock": ["rock", Color(0.45, 0.43, 0.40)],
    "sand": ["sand", Color(0.80, 0.72, 0.52)], "cobble": ["cobble", Color(0.52, 0.49, 0.43)], "wood_planks": ["wood_planks", Color(0.45, 0.32, 0.20)],
    "bark": ["bark", Color(0.25, 0.18, 0.12)], "plaster": ["plaster", Color(0.86, 0.80, 0.68)], "brick": ["brick", Color(0.55, 0.25, 0.17)],
    "roof_tiles": ["roof_tiles", Color(0.65, 0.28, 0.17)], "awning": ["awning", Color(0.85, 0.5, 0.45)], "cloth": ["cloth", Color(0.72, 0.66, 0.52)],
    "iron": ["iron", Color(0.2, 0.2, 0.22)],
}
const FLAT := {
    "foliage_core": Color(0.035, 0.085, 0.03), "paint_white": Color(0.93, 0.92, 0.88), "paint_red": Color(0.70, 0.15, 0.12),
    "paint_blue": Color(0.18, 0.36, 0.62), "paint_yellow": Color(0.95, 0.75, 0.10), "paint_green": Color(0.20, 0.50, 0.25),
    "straw": Color(0.85, 0.72, 0.42), "rope": Color(0.62, 0.52, 0.34), "soil": Color(0.22, 0.15, 0.10), "leather": Color(0.34, 0.20, 0.11),
    "accessory_cloth": Color(0.55, 0.42, 0.22), "accessory_leather": Color(0.35, 0.22, 0.12), "cloth_light": Color(0.85, 0.82, 0.70),
    "fruit_red": Color(0.75, 0.10, 0.08), "fruit_orange": Color(0.95, 0.50, 0.08), "fruit_mango": Color(0.95, 0.65, 0.12),
    "hay": Color(0.82, 0.68, 0.30), "canvas": Color(0.86, 0.82, 0.70), "wheat": Color(0.85, 0.70, 0.28),
}
const FOLIAGE := ["foliage_broad", "foliage_fruit", "foliage_pine", "foliage_bush"]

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _night := 0.0

static func load_tex(path: String) -> Texture2D:
    if _tex_cache.has(path):
        return _tex_cache[path]
    var tex: Texture2D = null
    if ResourceLoader.exists(path):
        tex = load(path) as Texture2D
    _tex_cache[path] = tex
    return tex

static func get_material(id: String) -> Material:
    if _cache.has(id):
        return _cache[id]
    var mat: Material = _build(id)
    if mat != null:
        mat.resource_name = id
    _cache[id] = mat
    return mat

static func _build(id: String) -> Material:
    if TEXTURED.has(id):
        return _textured(id)
    if FOLIAGE.has(id):
        return _foliage(id)
    if FLAT.has(id):
        return _flat(FLAT[id], 0.85)
    match id:
        "glass_window":
            var g := StandardMaterial3D.new()
            g.albedo_color = Color(0.45, 0.62, 0.72)
            g.roughness = 0.06
            g.metallic = 0.1
            g.metallic_specular = 0.9
            g.emission_enabled = true
            g.emission = Color(1.0, 0.72, 0.38)
            g.emission_energy_multiplier = 0.0
            return g
        "lantern_glow":
            var l := StandardMaterial3D.new()
            l.albedo_color = Color(1.0, 0.82, 0.5)
            l.emission_enabled = true
            l.emission = Color(1.0, 0.72, 0.32)
            l.emission_energy_multiplier = 0.6
            l.roughness = 0.4
            return l
        "beacon_glow":
            var b := StandardMaterial3D.new()
            b.albedo_color = Color(1.0, 0.9, 0.6)
            b.emission_enabled = true
            b.emission = Color(1.0, 0.82, 0.45)
            b.emission_energy_multiplier = 3.0
            return b
        "beacon_off":
            return _flat(Color(0.20, 0.20, 0.22), 0.5)
        "water_dark":
            var w := StandardMaterial3D.new()
            w.albedo_color = Color(0.02, 0.09, 0.12)
            w.roughness = 0.04
            w.metallic_specular = 0.9
            return w
        "gem":
            var gem := StandardMaterial3D.new()
            gem.albedo_color = Color(0.3, 0.5, 0.95)
            gem.roughness = 0.12
            gem.metallic_specular = 0.9
            gem.emission_enabled = true
            gem.emission = Color(0.3, 0.5, 0.95)
            gem.emission_energy_multiplier = 0.55
            gem.rim_enabled = true
            gem.rim = 0.6
            gem.rim_tint = 0.2
            return gem
        "ore_crystal":
            var o := StandardMaterial3D.new()
            o.albedo_color = Color(0.35, 0.6, 0.95)
            o.roughness = 0.15
            o.metallic = 0.3
            o.emission_enabled = true
            o.emission = Color(0.2, 0.5, 1.0)
            o.emission_energy_multiplier = 0.9
            return o
        "animal_hide":
            var a := StandardMaterial3D.new()
            a.vertex_color_use_as_albedo = true
            a.roughness = 0.9
            a.rim_enabled = true
            a.rim = 0.25
            a.rim_tint = 0.5
            return a
        "avatar_eye":
            var e := StandardMaterial3D.new()
            e.vertex_color_use_as_albedo = true
            e.roughness = 0.1
            e.metallic_specular = 0.9
            return e
        "avatar_hair":
            var h := StandardMaterial3D.new()
            h.albedo_color = Color(0.13, 0.08, 0.05)
            h.roughness = 0.62
            h.rim_enabled = true
            h.rim = 0.3
            h.rim_tint = 0.6
            return h
        "accessory_metal":
            var m := StandardMaterial3D.new()
            m.albedo_color = Color(0.7, 0.7, 0.72)
            m.metallic = 0.9
            m.roughness = 0.35
            return m
        "mountain":
            var mt := StandardMaterial3D.new()
            mt.vertex_color_use_as_albedo = true
            mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mt.disable_fog = true
            return mt
    return _flat(Color(0.6, 0.6, 0.6), 0.85)

static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.vertex_color_use_as_albedo = true
    return m

static func _textured(id: String) -> StandardMaterial3D:
    var info: Array = TEXTURED[id]
    var base := str(info[0])
    var m := StandardMaterial3D.new()
    var albedo := load_tex(TEX + base + "_albedo.jpg")
    if albedo != null:
        m.albedo_texture = albedo
    else:
        m.albedo_color = info[1]
    var normal := load_tex(TEX + base + "_normal.jpg")
    if normal != null:
        m.normal_enabled = true
        m.normal_texture = normal
        m.normal_scale = 1.0
    var orm := load_tex(TEX + base + "_orm.png")
    if orm != null:
        m.ao_enabled = true
        m.ao_texture = orm
        m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
        m.roughness_texture = orm
        m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
        if id == "iron":
            m.metallic = 1.0
            m.metallic_texture = orm
            m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    m.roughness = 1.0
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    m.vertex_color_use_as_albedo = true
    return m

static func _foliage(_id: String) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    var shader := _load_shader("foliage")
    if shader != null:
        m.shader = shader
    m.set_shader_parameter("leaf_tex", load_tex(TEX + "leaves.png"))
    return m

static func _load_shader(shader_name: String) -> Shader:
    var path := SHADERS + shader_name + ".gdshader"
    if ResourceLoader.exists(path):
        return load(path) as Shader
    return null

# --- shared special materials ----------------------------------------------------------------

static func terrain_material() -> ShaderMaterial:
    if _cache.has("@terrain"):
        return _cache["@terrain"]
    var m := ShaderMaterial.new()
    var shader := _load_shader("terrain")
    if shader != null:
        m.shader = shader
    for layer in ["grass", "dirt", "rock"]:
        m.set_shader_parameter(layer + "_albedo", load_tex(TEX + layer + "_albedo.jpg"))
        m.set_shader_parameter(layer + "_normal", load_tex(TEX + layer + "_normal.jpg"))
    m.set_shader_parameter("sand_albedo", load_tex(TEX + "sand_albedo.jpg"))
    _cache["@terrain"] = m
    return m

static func water_material() -> ShaderMaterial:
    if _cache.has("@water"):
        return _cache["@water"]
    var m := ShaderMaterial.new()
    var shader := _load_shader("water")
    if shader != null:
        m.shader = shader
    m.set_shader_parameter("wave_normal", load_tex(TEX + "water_normal.jpg"))
    _cache["@water"] = m
    return m

static func grass_material(kind: String) -> ShaderMaterial:
    var key := "@grass_" + kind
    if _cache.has(key):
        return _cache[key]
    var m := ShaderMaterial.new()
    var shader := _load_shader("grass")
    if shader != null:
        m.shader = shader
    m.set_shader_parameter("tex", load_tex(TEX + ("flowers.png" if kind == "flowers" else "grass_tufts.png")))
    if kind == "flowers":
        m.set_shader_parameter("tint_a", Color(1.0, 1.0, 1.0))
        m.set_shader_parameter("tint_b", Color(1.0, 1.0, 1.0))
        m.set_shader_parameter("wind", 0.08)
        m.set_shader_parameter("atlas_scale", Vector2(0.5, 0.5))
        m.set_shader_parameter("fade_start", 22.0)
        m.set_shader_parameter("fade_end", 34.0)
    _cache[key] = m
    return m

static func make_avatar_material(outfit: Dictionary) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    var shader := _load_shader("avatar")
    if shader != null:
        m.shader = shader
    m.set_shader_parameter("detail_normal", load_tex(TEX + "detail_normal.jpg"))
    for key in ["skin", "shirt", "pants", "leather", "hair"]:
        if outfit.has(key):
            m.set_shader_parameter(key + "_color", outfit[key])
    return m

static func sky_material() -> ShaderMaterial:
    var m := ShaderMaterial.new()
    var shader := _load_shader("sky")
    if shader != null:
        m.shader = shader
    return m

## 0 = full daylight, 1 = deep night.  Lamps and lit windows glow accordingly.
static func set_night_amount(amount: float) -> void:
    var n := clampf(amount, 0.0, 1.0)
    if is_equal_approx(n, _night):
        return
    _night = n
    var window := get_material("glass_window") as StandardMaterial3D
    if window != null:
        window.emission_energy_multiplier = n * 1.8
    var lantern := get_material("lantern_glow") as StandardMaterial3D
    if lantern != null:
        lantern.emission_energy_multiplier = 0.5 + n * 2.6
