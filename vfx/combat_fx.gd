extends Node3D
class_name CombatFX

## Every battle effect in one pooled place: muzzle flashes, tracers, impact sparks, explosions, shock-wave rings,
## floating damage numbers, "poof" stars when an enemy is crushed, plus the camera-shake / hit-stop / bullet-time hooks.
## Nothing is allocated during a fight after the pools warm up, and every effect degrades with the graphics tier
## (no dynamic lights and fewer particles on low-end phones). Effects are cosmetic: when a pool is empty they are skipped.
signal shake_requested(strength: float)

const POOL_CAP := {"flash": 6, "tracer": 16, "impact": 10, "number": 14, "ring": 6, "boom": 3, "poof": 6}
const HIT_STOP_SCALE := 0.06

var effects_level := 0.65
var use_lights := true

var _quality: QualityManager
var _free: Dictionary = {}
var _count: Dictionary = {}
var _live: Array[Dictionary] = []
var _materials: Dictionary = {}
var _light_nodes := 0
var _stop_until_msec := 0
var _slow_until_msec := 0
var _slow_scale := 1.0

func _ready() -> void:
    for kind in POOL_CAP.keys():
        _free[kind] = []
        _count[kind] = 0

func setup(quality: QualityManager) -> void:
    _quality = quality
    if quality == null:
        return
    apply_quality(quality.current())
    if not quality.changed.is_connected(_on_quality_changed):
        quality.changed.connect(_on_quality_changed)

func _on_quality_changed(_level: String) -> void:
    if _quality != null:
        apply_quality(_quality.current())

func apply_quality(values: Dictionary) -> void:
    effects_level = float(values.get("effects", 0.65))
    use_lights = effects_level >= 0.6

func _exit_tree() -> void:
    Engine.time_scale = 1.0

# ------------------------------------------------------------------------------------------------ time control
## Freezes the game for a few real milliseconds so a heavy hit "lands".
func hit_stop(seconds: float) -> void:
    _stop_until_msec = maxi(_stop_until_msec, Time.get_ticks_msec() + int(seconds * 1000.0))

## Slow motion measured in REAL seconds (bullet time after a perfect dodge).
func slow_motion(time_scale: float, real_seconds: float) -> void:
    _slow_scale = clampf(time_scale, 0.1, 1.0)
    _slow_until_msec = Time.get_ticks_msec() + int(real_seconds * 1000.0)

func is_slow_motion() -> bool:
    return Time.get_ticks_msec() < _slow_until_msec

func clear_time_effects() -> void:
    _stop_until_msec = 0
    _slow_until_msec = 0
    Engine.time_scale = 1.0

func shake(strength: float) -> void:
    shake_requested.emit(strength)

func _update_time() -> void:
    var now := Time.get_ticks_msec()
    var wanted := 1.0
    if now < _slow_until_msec:
        wanted = _slow_scale
    if now < _stop_until_msec:
        wanted = minf(wanted, HIT_STOP_SCALE)
    if not is_equal_approx(Engine.time_scale, wanted):
        Engine.time_scale = wanted

# ------------------------------------------------------------------------------------------------ public effects
func muzzle_flash(pos: Vector3, dir: Vector3, size: float = 1.0) -> void:
    var node := _acquire("flash")
    if node == null:
        return
    node.global_position = pos + dir * 0.04
    node.scale = Vector3.ONE * size * randf_range(0.8, 1.25)
    var light := node.get_node_or_null("Light") as OmniLight3D
    if light != null:
        light.visible = use_lights
    _arm(node, "flash", 0.055)

func tracer(from: Vector3, to: Vector3, color: Color) -> void:
    var span := to - from
    var length := span.length()
    if length < 0.6:
        return
    var node := _acquire("tracer") as MeshInstance3D
    if node == null:
        return
    var up := Vector3.UP if absf(span.normalized().y) < 0.97 else Vector3.RIGHT
    node.global_position = (from + to) * 0.5
    node.look_at_from_position((from + to) * 0.5, to, up)
    node.scale = Vector3(1.0, 1.0, minf(length, 60.0))
    node.material_override = _glow_material(color, false)
    _arm(node, "tracer", 0.07)

## kind: "spark" (bullets on props), "dust" (bullets on ground), "hit" (a fighter was hit).
func impact(pos: Vector3, normal: Vector3, kind: String = "spark") -> void:
    if effects_level < 0.3:
        return
    var node := _acquire("impact") as CPUParticles3D
    if node == null:
        return
    node.global_position = pos + normal * 0.05
    match kind:
        "dust":
            node.color = Color(0.78, 0.70, 0.55, 0.9)
            node.gravity = Vector3(0.0, -3.0, 0.0)
            node.initial_velocity_min = 1.0
            node.initial_velocity_max = 2.5
        "hit":
            node.color = Color(1.0, 0.95, 0.65, 1.0)
            node.gravity = Vector3(0.0, -6.0, 0.0)
            node.initial_velocity_min = 2.0
            node.initial_velocity_max = 4.5
        _:
            node.color = Color(1.0, 0.82, 0.35, 1.0)
            node.gravity = Vector3(0.0, -9.0, 0.0)
            node.initial_velocity_min = 2.5
            node.initial_velocity_max = 5.5
    node.direction = normal if normal.length() > 0.1 else Vector3.UP
    node.amount = 8 if effects_level >= 0.6 else 4
    node.emitting = false
    node.restart()
    node.emitting = true
    _arm(node, "impact", 0.5)

func explosion(pos: Vector3, radius: float) -> void:
    shake(clampf(radius * 0.22, 0.4, 1.4))
    ring(pos + Vector3(0.0, 0.1, 0.0), radius, Color(1.0, 0.75, 0.3, 0.8), 0.45)
    var node := _acquire("boom") as MeshInstance3D
    if node == null:
        return
    node.global_position = pos + Vector3(0.0, 0.4, 0.0)
    node.set_meta("radius", radius)
    node.scale = Vector3.ONE * 0.3
    var material := node.material_override as StandardMaterial3D
    if material != null:
        material.albedo_color = Color(1.0, 0.62, 0.18, 0.85)
    var light := node.get_node_or_null("Light") as OmniLight3D
    if light != null:
        light.visible = use_lights
        light.omni_range = radius * 2.6
        light.light_energy = 3.0
    var debris := node.get_node_or_null("Debris") as CPUParticles3D
    if debris != null:
        debris.visible = effects_level >= 0.45
        # top_level particles ignore the (scaling) parent, so they must be placed in world space by hand.
        debris.global_position = node.global_position
        debris.emitting = false
        debris.restart()
        debris.emitting = true
    _arm(node, "boom", 0.6)

## A flat shock-wave ring on the ground (crush moves, grenade warnings, boss slams, capture zones).
func ring(pos: Vector3, radius: float, color: Color, seconds: float = 0.5) -> void:
    var node := _acquire("ring") as MeshInstance3D
    if node == null:
        return
    node.global_position = pos
    node.set_meta("radius", radius)
    node.set_meta("base_alpha", color.a)
    node.scale = Vector3(0.2, 1.0, 0.2)
    var material := node.material_override as StandardMaterial3D
    if material != null:
        material.albedo_color = color
    _arm(node, "ring", maxf(seconds, 0.1))

## style: "normal", "crit", "heal", "crush", "xp". `text_override` replaces the number (for words like "PERFECT!").
func damage_number(pos: Vector3, amount: float, style: String = "normal", text_override: String = "") -> void:
    var node := _acquire("number") as Label3D
    if node == null:
        return
    node.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0.2, randf_range(-0.25, 0.25))
    node.text = text_override if text_override != "" else str(int(round(amount)))
    match style:
        "crit":
            node.modulate = Color(1.0, 0.82, 0.2, 1.0)
            node.font_size = 78
        "heal":
            node.modulate = Color(0.45, 1.0, 0.55, 1.0)
            node.font_size = 60
        "crush":
            node.modulate = Color(1.0, 0.45, 0.2, 1.0)
            node.font_size = 90
        "xp":
            node.modulate = Color(0.65, 0.85, 1.0, 1.0)
            node.font_size = 56
        _:
            node.modulate = Color(1.0, 1.0, 1.0, 1.0)
            node.font_size = 52
    _arm(node, "number", 0.8)

## Star burst when an enemy is crushed (no gore: they are knocked out in a cloud of stars).
func poof(pos: Vector3, color: Color = Color(1.0, 0.85, 0.3, 1.0)) -> void:
    if effects_level < 0.3:
        return
    var node := _acquire("poof") as CPUParticles3D
    if node == null:
        return
    node.global_position = pos
    node.color = color
    node.amount = 14 if effects_level >= 0.6 else 7
    node.emitting = false
    node.restart()
    node.emitting = true
    _arm(node, "poof", 0.9)

# ------------------------------------------------------------------------------------------------ pooling
func _acquire(kind: String) -> Node3D:
    var pool: Array = _free.get(kind, [])
    var node: Node3D = null
    if not pool.is_empty():
        node = pool.pop_back() as Node3D
    elif int(_count.get(kind, 0)) < int(POOL_CAP.get(kind, 4)):
        node = _make(kind)
        if node != null:
            add_child(node)
            _count[kind] = int(_count.get(kind, 0)) + 1
    if node == null:
        return null
    node.visible = true
    return node

func _arm(node: Node3D, kind: String, seconds: float) -> void:
    _live.append({"node": node, "kind": kind, "left": seconds, "total": seconds})

func _release(entry: Dictionary) -> void:
    var node := entry["node"] as Node3D
    var kind := str(entry["kind"])
    if node == null or not is_instance_valid(node):
        return
    node.visible = false
    var particles := node as CPUParticles3D
    if particles != null:
        particles.emitting = false
    var pool: Array = _free.get(kind, [])
    pool.append(node)
    _free[kind] = pool

func _process(_delta: float) -> void:
    _update_time()
    var index := _live.size() - 1
    while index >= 0:
        var entry: Dictionary = _live[index]
        # Real-time aging: effects must not linger for seconds during slow motion or look frozen in a hit-stop.
        var step := get_process_delta_time() / maxf(Engine.time_scale, 0.05)
        entry["left"] = float(entry["left"]) - step
        var node := entry["node"] as Node3D
        var progress := 1.0 - clampf(float(entry["left"]) / maxf(float(entry["total"]), 0.01), 0.0, 1.0)
        if node != null and is_instance_valid(node):
            _animate(entry, node, progress, step)
        if float(entry["left"]) <= 0.0:
            _release(entry)
            _live.remove_at(index)
        index -= 1

func _animate(entry: Dictionary, node: Node3D, progress: float, step: float) -> void:
    match str(entry["kind"]):
        "number":
            node.position.y += 1.5 * step
            var label := node as Label3D
            if label != null:
                var color := label.modulate
                color.a = clampf(2.0 * (1.0 - progress), 0.0, 1.0)
                label.modulate = color
        "ring":
            var target := float(node.get_meta("radius", 3.0))
            var eased := 1.0 - pow(1.0 - progress, 3.0)
            node.scale = Vector3(maxf(target * eased, 0.2), 1.0, maxf(target * eased, 0.2))
            var ring_material := (node as MeshInstance3D).material_override as StandardMaterial3D
            if ring_material != null:
                var ring_color := ring_material.albedo_color
                ring_color.a = float(node.get_meta("base_alpha", 0.8)) * (1.0 - progress)
                ring_material.albedo_color = ring_color
        "boom":
            var blast_radius := float(node.get_meta("radius", 4.0))
            var swell := 1.0 - pow(1.0 - progress, 2.0)
            node.scale = Vector3.ONE * lerpf(0.3, blast_radius * 0.9, swell)
            var boom_material := (node as MeshInstance3D).material_override as StandardMaterial3D
            if boom_material != null:
                var boom_color := boom_material.albedo_color
                boom_color.a = 0.85 * (1.0 - progress)
                boom_material.albedo_color = boom_color
            var light := node.get_node_or_null("Light") as OmniLight3D
            if light != null:
                light.light_energy = 3.0 * (1.0 - progress)

# ------------------------------------------------------------------------------------------------ builders
func _glow_material(color: Color, billboard: bool) -> StandardMaterial3D:
    var key := "%s_%s" % [color.to_html(true), str(billboard)]
    if _materials.has(key):
        return _materials[key]
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.albedo_color = color
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if billboard:
        material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    _materials[key] = material
    return material

func _particle_mesh(size: float) -> QuadMesh:
    var quad := QuadMesh.new()
    quad.size = Vector2(size, size)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    quad.material = material
    return quad

func _make(kind: String) -> Node3D:
    match kind:
        "flash":
            var flash := MeshInstance3D.new()
            var quad := QuadMesh.new()
            quad.size = Vector2(0.55, 0.55)
            flash.mesh = quad
            flash.material_override = _glow_material(Color(1.0, 0.8, 0.3, 0.95), true)
            flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            if _light_nodes < 2:
                var light := OmniLight3D.new()
                light.name = "Light"
                light.light_color = Color(1.0, 0.75, 0.4)
                light.light_energy = 1.6
                light.omni_range = 6.0
                light.shadow_enabled = false
                flash.add_child(light)
                _light_nodes += 1
            return flash
        "tracer":
            var tracer_node := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(0.03, 0.03, 1.0)
            tracer_node.mesh = box
            tracer_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            return tracer_node
        "impact":
            var sparks := CPUParticles3D.new()
            sparks.one_shot = true
            sparks.emitting = false
            sparks.lifetime = 0.35
            sparks.explosiveness = 0.95
            sparks.spread = 70.0
            sparks.scale_amount_min = 0.5
            sparks.scale_amount_max = 1.0
            sparks.mesh = _particle_mesh(0.07)
            return sparks
        "poof":
            var stars := CPUParticles3D.new()
            stars.one_shot = true
            stars.emitting = false
            stars.lifetime = 0.8
            stars.explosiveness = 1.0
            stars.spread = 180.0
            stars.direction = Vector3.UP
            stars.initial_velocity_min = 2.5
            stars.initial_velocity_max = 5.5
            stars.gravity = Vector3(0.0, -4.0, 0.0)
            stars.scale_amount_min = 0.7
            stars.scale_amount_max = 1.5
            stars.mesh = _particle_mesh(0.18)
            return stars
        "ring":
            var ring_node := MeshInstance3D.new()
            var torus := TorusMesh.new()
            torus.inner_radius = 0.46
            torus.outer_radius = 0.5
            torus.rings = 24
            torus.ring_segments = 4
            ring_node.mesh = torus
            ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var ring_material := StandardMaterial3D.new()
            ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
            ring_node.material_override = ring_material
            return ring_node
        "boom":
            var boom := MeshInstance3D.new()
            var sphere := SphereMesh.new()
            sphere.radius = 1.0
            sphere.height = 2.0
            sphere.radial_segments = 12
            sphere.rings = 6
            boom.mesh = sphere
            boom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var boom_material := StandardMaterial3D.new()
            boom_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            boom_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            boom_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
            boom.material_override = boom_material
            var boom_light := OmniLight3D.new()
            boom_light.name = "Light"
            boom_light.light_color = Color(1.0, 0.6, 0.25)
            boom_light.shadow_enabled = false
            boom.add_child(boom_light)
            var debris := CPUParticles3D.new()
            debris.name = "Debris"
            debris.top_level = true
            debris.one_shot = true
            debris.emitting = false
            debris.amount = 16
            debris.lifetime = 0.9
            debris.explosiveness = 1.0
            debris.spread = 180.0
            debris.direction = Vector3.UP
            debris.initial_velocity_min = 4.0
            debris.initial_velocity_max = 9.0
            debris.gravity = Vector3(0.0, -14.0, 0.0)
            debris.color = Color(0.35, 0.28, 0.22, 1.0)
            debris.mesh = _particle_mesh(0.22)
            boom.add_child(debris)
            return boom
        "number":
            var label := Label3D.new()
            label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            label.no_depth_test = true
            label.shaded = false
            label.pixel_size = 0.006
            label.outline_size = 10
            label.outline_modulate = Color(0.05, 0.08, 0.2, 1.0)
            label.font_size = 52
            return label
    return null
