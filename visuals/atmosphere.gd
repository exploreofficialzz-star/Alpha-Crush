extends Node
class_name Atmosphere

## Sky, sun/moon, fog, tone-mapping, distant mountains and rain.  Driven by the world clock and the
## weather manager; lighting is continuous (no more four hard presets).

const F_RISE := -0.04     # sunrise, as a fraction of the clock cycle (wraps)
const F_SET := 0.875      # sunset
const DAY_TOP := Color(0.14, 0.36, 0.82)
const DAY_HORIZON := Color(0.60, 0.77, 0.95)
const DUSK_TOP := Color(0.28, 0.30, 0.55)
const DUSK_HORIZON := Color(1.0, 0.52, 0.28)
const NIGHT_TOP := Color(0.012, 0.018, 0.055)
const NIGHT_HORIZON := Color(0.03, 0.05, 0.10)

var player: Node3D
var clock: WorldClock
var weather: WeatherManager
var quality: QualityManager
var audio: AudioManager

var environment: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_material: ShaderMaterial
var mountains: Node3D
var far_ground: MeshInstance3D
var rain: GPUParticles3D

var _cover := 0.4
var _light := 1.0
var _fog := 1.0
var _overcast := 0.0
var _camera_fixed := false

func setup(p_player: Node3D, p_clock: WorldClock, p_weather: WeatherManager, p_quality: QualityManager) -> void:
    player = p_player
    clock = p_clock
    weather = p_weather
    quality = p_quality
    if quality != null and not quality.changed.is_connected(_on_quality_changed):
        quality.changed.connect(_on_quality_changed)

func _ready() -> void:
    _build()
    _update(1.0, true)

func _build() -> void:
    sky_material = MaterialLibrary.sky_material()
    var sky := Sky.new()
    sky.sky_material = sky_material
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.0
    environment.tonemap_white = 6.0
    environment.fog_enabled = true
    environment.fog_density = 0.010
    environment.fog_sky_affect = 0.0
    environment.glow_enabled = true
    environment.glow_intensity = 0.6
    environment.glow_bloom = 0.04
    environment.glow_hdr_threshold = 1.1
    environment.adjustment_enabled = true
    environment.adjustment_contrast = 1.07
    environment.adjustment_saturation = 1.12
    if RenderingServer.get_current_rendering_method() == "forward_plus":
        # Screen-space effects only exist in Forward+, desktop builds get them for free.
        environment.ssao_enabled = true
        environment.ssao_radius = 1.4
        environment.ssao_intensity = 1.6
        environment.ssil_enabled = true
    world_env = WorldEnvironment.new()
    world_env.name = "WorldEnvironment"
    world_env.environment = environment
    add_child(world_env)

    sun = DirectionalLight3D.new()
    sun.name = "Sun"
    sun.shadow_enabled = true
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_blend_splits = true
    sun.shadow_normal_bias = 1.2
    sun.shadow_bias = 0.04
    sun.shadow_blur = 1.2
    add_child(sun)
    moon = DirectionalLight3D.new()
    moon.name = "Moon"
    moon.light_color = Color(0.55, 0.65, 1.0)
    moon.shadow_enabled = false
    add_child(moon)

    var far_mesh := CylinderMesh.new()
    far_mesh.top_radius = 1500.0
    far_mesh.bottom_radius = 1500.0
    far_mesh.height = 0.2
    far_mesh.radial_segments = 48
    far_mesh.rings = 1
    far_ground = MeshInstance3D.new()
    far_ground.name = "FarGround"
    far_ground.mesh = far_mesh
    var far_mat := StandardMaterial3D.new()
    far_mat.albedo_color = Color(0.36, 0.45, 0.24)
    far_mat.roughness = 1.0
    far_ground.material_override = far_mat
    far_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(far_ground)

    var ring := PropFactory.spawn("mountains", false, false)
    if ring != null:
        ring.name = "Mountains"
        add_child(ring)
        mountains = ring
        _no_shadow(ring)

    rain = GPUParticles3D.new()
    rain.name = "Rain"
    rain.amount = 900
    rain.lifetime = 0.9
    rain.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
    rain.local_coords = false
    rain.emitting = false
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = Vector3(18.0, 0.5, 18.0)
    pm.direction = Vector3(0.1, -1.0, 0.0)
    pm.spread = 2.0
    pm.initial_velocity_min = 22.0
    pm.initial_velocity_max = 27.0
    pm.gravity = Vector3.ZERO
    rain.process_material = pm
    var drop := QuadMesh.new()
    drop.size = Vector2(0.025, 0.65)
    var drop_mat := StandardMaterial3D.new()
    drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    drop_mat.albedo_color = Color(0.78, 0.84, 0.92, 0.38)
    drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
    drop.material = drop_mat
    rain.draw_pass_1 = drop
    rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(rain)
    _on_quality_changed(quality.quality if quality != null else "medium")

func _no_shadow(node: Node) -> void:
    if node is GeometryInstance3D:
        (node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _no_shadow(child)

func _on_quality_changed(level: String) -> void:
    if sun == null:
        return
    var q: Dictionary = quality.current() if quality != null else {}
    sun.shadow_enabled = bool(q.get("shadow", true))
    sun.directional_shadow_max_distance = 130.0 * float(q.get("distance", 0.8))
    if rain != null:
        rain.amount = int(900.0 * float(q.get("effects", 0.65)))
    if level == "low":
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    else:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

func _process(delta: float) -> void:
    if environment == null:
        return
    _update(delta, false)

## Fraction of the clock cycle -> sun angle (0..PI is day, PI..2PI is night).
static func sun_angle(f: float) -> float:
    var ff := fposmod(f, 1.0)
    var night_end := 1.0 + F_RISE
    if ff >= night_end:
        return PI * (ff - night_end) / (F_SET - F_RISE)
    if ff > F_SET:
        return PI + PI * (ff - F_SET) / (night_end - F_SET)
    return PI * (ff - F_RISE) / (F_SET - F_RISE)

static func sun_direction(f: float) -> Vector3:
    var a := sun_angle(f)
    return Vector3(cos(a), sin(a) * 0.9, -0.38).normalized()

func _update(delta: float, snap: bool) -> void:
    var f := 0.3
    if clock != null:
        f = clock.elapsed / WorldClock.CYCLE_SECONDS
    var sun_dir := sun_direction(f)
    var e := sun_dir.y
    var daylight := smoothstep(-0.10, 0.25, e)
    var twilight := clampf(1.0 - absf(e) / 0.30, 0.0, 1.0)
    twilight = twilight * twilight * (3.0 - 2.0 * twilight)

    var target_cover := 0.38
    var target_light := 1.0
    var target_fog := 1.0
    var raining := false
    if weather != null:
        match str(weather.weather):
            "cloudy":
                target_cover = 0.72
                target_light = 0.74
                target_fog = 1.35
            "rain":
                target_cover = 0.95
                target_light = 0.45
                target_fog = 2.2
                raining = true
    var k := 1.0 if snap else minf(1.0, delta * 0.5)
    _cover = lerpf(_cover, target_cover, k)
    _light = lerpf(_light, target_light, k)
    _fog = lerpf(_fog, target_fog, k)
    _overcast = clampf((_cover - 0.4) / 0.55, 0.0, 1.0)

    var top := NIGHT_TOP.lerp(DAY_TOP, daylight).lerp(DUSK_TOP, twilight * 0.5)
    var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, daylight).lerp(DUSK_HORIZON, twilight * 0.8)
    var grey := Color(0.46, 0.50, 0.55) * (0.15 + 0.85 * daylight)
    top = top.lerp(grey, _overcast * 0.7)
    horizon = horizon.lerp(grey.lightened(0.15), _overcast * 0.6)
    var sun_col := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.56, 0.28), 1.0 - smoothstep(0.05, 0.45, e))

    sky_material.set_shader_parameter("sky_top", top)
    sky_material.set_shader_parameter("sky_horizon", horizon)
    sky_material.set_shader_parameter("ground_color", horizon.darkened(0.45))
    sky_material.set_shader_parameter("sun_dir", sun_dir)
    sky_material.set_shader_parameter("sun_color", sun_col)
    sky_material.set_shader_parameter("sun_energy", daylight * (1.0 - _overcast * 0.85))
    sky_material.set_shader_parameter("cloud_cover", _cover)
    sky_material.set_shader_parameter("cloud_light", Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.72, 0.55), twilight) * (0.12 + 0.88 * daylight))
    sky_material.set_shader_parameter("cloud_dark", Color(0.62, 0.68, 0.80).lerp(Color(0.55, 0.40, 0.45), twilight) * (0.10 + 0.9 * daylight) * (1.0 - _overcast * 0.35))
    sky_material.set_shader_parameter("star_amount", clampf(1.0 - daylight * 1.5, 0.0, 1.0) * (1.0 - _overcast))

    sun.basis = Basis.looking_at(-sun_dir, Vector3.UP)
    sun.light_color = sun_col
    sun.light_energy = 1.25 * daylight * _light
    sun.visible = daylight > 0.01
    moon.basis = Basis.looking_at(sun_dir, Vector3.UP)
    moon.light_energy = 0.28 * (1.0 - daylight) * (1.0 - _overcast * 0.6)
    moon.visible = moon.light_energy > 0.01

    environment.ambient_light_energy = lerpf(0.55, 1.0, daylight) * lerpf(1.0, 0.8, _overcast)
    environment.fog_light_color = horizon
    environment.fog_light_energy = lerpf(0.5, 1.0, daylight)
    environment.fog_density = 0.010 * _fog
    MaterialLibrary.set_night_amount(1.0 - daylight)
    var mountain_mat := MaterialLibrary.get_material("mountain") as StandardMaterial3D
    if mountain_mat != null:
        mountain_mat.albedo_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.72, 0.62), twilight * 0.6) * (0.10 + 0.90 * daylight) * (1.0 - _overcast * 0.25)
    far_ground.visible = true
    (far_ground.material_override as StandardMaterial3D).albedo_color = Color(0.36, 0.45, 0.24) * (0.12 + 0.88 * daylight)

    if player != null and is_instance_valid(player):
        var p := player.global_position
        far_ground.global_position = Vector3(p.x, -0.9, p.z)
        if mountains != null:
            mountains.global_position = Vector3(p.x, -4.0, p.z)
        rain.global_position = p + Vector3(0.0, 14.0, 0.0)
    rain.emitting = raining
    if audio != null and player != null and is_instance_valid(player):
        var pp := player.global_position
        var rc := Vector2(clampf(pp.x, TerrainField.RIVER_RECT.position.x, TerrainField.RIVER_RECT.end.x), clampf(pp.z, TerrainField.RIVER_RECT.position.y, TerrainField.RIVER_RECT.end.y))
        var river_dist := Vector2(pp.x, pp.z).distance_to(rc)
        audio.update_ambience(daylight, raining, 1.0 - clampf(river_dist / 40.0, 0.0, 1.0), delta)
    if not _camera_fixed:
        var cam := get_viewport().get_camera_3d()
        if cam != null:
            cam.far = maxf(cam.far, 3200.0)
            _camera_fixed = true
