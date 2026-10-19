extends Node3D
class_name GuardianDrone

## Killstreak: a hovering drone follows the player for a while and shoots the nearest enemy every third of a second.
const LIFETIME := 20.0
const SHOT_GAP := 0.33
const SHOT_DAMAGE := 17.0
const RANGE := 32.0

var director: CombatDirector
var fx: CombatFX
var audio: AudioManager
var owner_node: Node3D = null

var _age := 0.0
var _shot_timer := 0.5
var _rotors: Array[MeshInstance3D] = []
var _leaving := false

static func create(p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager, p_owner: Node3D) -> GuardianDrone:
    var drone := GuardianDrone.new()
    drone.name = "GuardianDrone"
    drone.director = p_director
    drone.fx = p_fx
    drone.audio = p_audio
    drone.owner_node = p_owner
    drone._build_visual()
    return drone

func _build_visual() -> void:
    var body := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.32
    sphere.height = 0.5
    sphere.radial_segments = 10
    sphere.rings = 5
    body.mesh = sphere
    var shell := StandardMaterial3D.new()
    shell.albedo_color = Color(0.2, 0.85, 0.88)
    shell.metallic = 0.5
    shell.emission_enabled = true
    shell.emission = Color(0.2, 0.85, 0.88)
    shell.emission_energy_multiplier = 0.45
    body.material_override = shell
    add_child(body)
    var blade := StandardMaterial3D.new()
    blade.albedo_color = Color(0.9, 0.95, 1.0, 0.6)
    blade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    blade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for corner in [Vector3(0.45, 0.12, 0.45), Vector3(-0.45, 0.12, 0.45), Vector3(0.45, 0.12, -0.45), Vector3(-0.45, 0.12, -0.45)]:
        var rotor := MeshInstance3D.new()
        var disc := CylinderMesh.new()
        disc.top_radius = 0.3
        disc.bottom_radius = 0.3
        disc.height = 0.02
        disc.radial_segments = 10
        disc.rings = 1
        rotor.mesh = disc
        rotor.position = corner
        rotor.material_override = blade
        rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(rotor)
        _rotors.append(rotor)

func start(spawn_point: Vector3) -> void:
    global_position = spawn_point
    if fx != null:
        fx.poof(spawn_point, Color(0.5, 0.95, 1.0, 1.0))

func _process(delta: float) -> void:
    _age += delta
    for rotor in _rotors:
        rotor.rotation.y += delta * 40.0
    if owner_node == null or not is_instance_valid(owner_node):
        queue_free()
        return
    var goal := owner_node.global_position + Vector3(1.9, 3.3 + sin(_age * 2.0) * 0.2, 0.6)
    if _age > LIFETIME:
        _leaving = true
        goal = owner_node.global_position + Vector3(0.0, 40.0, 0.0)
        if _age > LIFETIME + 2.5:
            queue_free()
            return
    global_position = global_position.lerp(goal, minf(1.0, delta * (1.2 if _leaving else 4.0)))
    if _leaving or director == null:
        return
    _shot_timer -= delta
    if _shot_timer > 0.0:
        return
    var victim := director.nearest(global_position, Teams.OPPOSITION, RANGE) as Node3D
    if victim == null or not victim.has_method("take_damage"):
        _shot_timer = 0.15
        return
    _shot_timer = SHOT_GAP
    var height_value: Variant = victim.get("body_height")
    var chest := victim.global_position + Vector3(0.0, (1.7 if height_value == null else float(height_value)) * 0.6, 0.0)
    var direction := (chest - global_position).normalized()
    var info := DamageInfo.make(SHOT_DAMAGE, DamageInfo.KIND_BULLET, owner_node, Teams.ALPHA, chest, direction)
    info.knockback = 0.5
    info.weapon_id = "hornet"
    var applied := float(victim.call("take_damage", info))
    if applied > 0.0 and owner_node.has_method("register_hit"):
        owner_node.call("register_hit", victim, info, applied)
    if fx != null:
        fx.muzzle_flash(global_position, direction, 0.6)
        fx.tracer(global_position, chest, Color(0.4, 0.95, 1.0, 0.9))
        fx.impact(chest, -direction, "hit")
    if audio != null:
        audio.play_sfx("gun_smg", 1.3, -9.0)
