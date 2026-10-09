extends Node3D
class_name AvatarRig

## Humanoid built from assets/models/avatar_male|female.glb (rigid, ball-jointed segments) and animated
## procedurally: idle breathing, walk/run cycle, jump pose, carrying pose and an interact reach.
## The model faces -Z like everything else in Godot.

const JOINT_NAMES := ["Hips", "Spine", "Neck", "Head", "UpperArm_R", "Forearm_R", "Hand_R", "UpperArm_L", "Forearm_L", "Hand_L",
    "Thigh_R", "Shin_R", "Foot_R", "Thigh_L", "Shin_L", "Foot_L"]
const SKIN_TONES := [Color(0.93, 0.76, 0.64), Color(0.84, 0.64, 0.49), Color(0.72, 0.52, 0.38), Color(0.56, 0.38, 0.27), Color(0.40, 0.27, 0.19)]
const HAIR_COLORS := [Color(0.10, 0.07, 0.05), Color(0.22, 0.13, 0.07), Color(0.42, 0.26, 0.10), Color(0.70, 0.55, 0.28), Color(0.55, 0.20, 0.10), Color(0.62, 0.62, 0.62)]

var gender := "male"
var model: Node3D
var body_material: ShaderMaterial
var hair_material: StandardMaterial3D
var carrying := false
var look_offset := 0.0

var hips: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var ua_r: Node3D
var fa_r: Node3D
var hand_r: Node3D
var ua_l: Node3D
var fa_l: Node3D
var hand_l: Node3D
var th_r: Node3D
var sh_r: Node3D
var ft_r: Node3D
var th_l: Node3D
var sh_l: Node3D
var ft_l: Node3D
var attach_back: Node3D
var attach_hat: Node3D
var _accessories: Array[Node3D] = []

var phase := 0.0
var move_amount := 0.0
var run_amount := 0.0
var air_amount := 0.0
var carry_amount := 0.0
var _idle_time := 0.0
var _reach_time := 0.0
var _hips_rest_y := 0.95

## outfit keys: skin, shirt, pants, leather, hair (Color); hat: "", "straw", "hard", "sun"; pack: bool; pack_color: Color
static func outfit_for(style: String, role_seed: int = 0) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = role_seed
    var outfit := {
        "skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()], "hair": HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
        "shirt": Color(0.27, 0.36, 0.50), "pants": Color(0.31, 0.34, 0.22), "leather": Color(0.30, 0.19, 0.11),
        "hat": "", "pack": false, "pack_color": Color(0.55, 0.42, 0.22)
    }
    match style:
        "default", "explorer", "traveler":
            outfit["pack"] = true
            if style == "traveler":
                outfit["shirt"] = Color(0.18, 0.46, 0.50)
                outfit["pants"] = Color(0.40, 0.30, 0.20)
        "sunrise":
            outfit["shirt"] = Color(0.69, 0.42, 0.26)
            outfit["pack"] = true
        "forest":
            outfit["shirt"] = Color(0.32, 0.46, 0.30)
            outfit["pants"] = Color(0.36, 0.30, 0.20)
            outfit["pack"] = true
        "coastal":
            outfit["shirt"] = Color(0.24, 0.47, 0.57)
            outfit["pants"] = Color(0.78, 0.72, 0.58)
            outfit["pack"] = true
        "farmer":
            outfit["shirt"] = Color(0.62, 0.28, 0.22)
            outfit["pants"] = Color(0.22, 0.30, 0.45)
            outfit["hat"] = "straw"
        "gardener":
            outfit["shirt"] = Color(0.30, 0.52, 0.30)
            outfit["pants"] = Color(0.52, 0.45, 0.32)
            outfit["hat"] = "sun"
        "merchant":
            outfit["shirt"] = Color(0.88, 0.80, 0.62)
            outfit["pants"] = Color(0.26, 0.22, 0.20)
        "builder":
            outfit["shirt"] = Color(0.85, 0.50, 0.15)
            outfit["pants"] = Color(0.35, 0.36, 0.38)
            outfit["hat"] = "hard"
    return outfit

func build(p_gender: String, outfit: Dictionary) -> bool:
    gender = p_gender
    model = PropFactory.spawn("avatar_female" if gender == "female" else "avatar_male", false, true)
    if model == null:
        return false
    add_child(model)
    hips = _joint("Hips")
    spine = _joint("Spine")
    neck = _joint("Neck")
    head = _joint("Head")
    ua_r = _joint("UpperArm_R")
    fa_r = _joint("Forearm_R")
    hand_r = _joint("Hand_R")
    ua_l = _joint("UpperArm_L")
    fa_l = _joint("Forearm_L")
    hand_l = _joint("Hand_L")
    th_r = _joint("Thigh_R")
    sh_r = _joint("Shin_R")
    ft_r = _joint("Foot_R")
    th_l = _joint("Thigh_L")
    sh_l = _joint("Shin_L")
    ft_l = _joint("Foot_L")
    attach_back = model.find_child("Attach_Back", true, false) as Node3D
    attach_hat = model.find_child("Attach_Hat", true, false) as Node3D
    if hips != null:
        _hips_rest_y = hips.position.y
    _idle_time = randf() * 20.0
    body_material = MaterialLibrary.make_avatar_material(outfit)
    hair_material = (MaterialLibrary.get_material("avatar_hair") as StandardMaterial3D).duplicate() as StandardMaterial3D
    var eye_material := MaterialLibrary.get_material("avatar_eye")
    var meshes: Array[MeshInstance3D] = []
    _meshes_under(model, meshes)
    for mi in meshes:
        if mi.mesh == null:
            continue
        for i in range(mi.mesh.get_surface_count()):
            var src := mi.mesh.surface_get_material(i)
            var id := src.resource_name if src != null else ""
            if id == "avatar_body":
                mi.set_surface_override_material(i, body_material)
            elif id == "avatar_hair":
                mi.set_surface_override_material(i, hair_material)
            elif id == "avatar_eye":
                mi.set_surface_override_material(i, eye_material)
    apply_outfit(outfit)
    return true

func apply_outfit(outfit: Dictionary) -> void:
    if body_material != null:
        for key in ["skin", "shirt", "pants", "leather", "hair"]:
            if outfit.has(key):
                body_material.set_shader_parameter(key + "_color", outfit[key])
    if hair_material != null and outfit.has("hair"):
        hair_material.albedo_color = outfit["hair"]
    for node in _accessories:
        if is_instance_valid(node):
            node.queue_free()
    _accessories.clear()
    var hat := str(outfit.get("hat", ""))
    if hat != "" and attach_hat != null:
        var hat_node := PropFactory.spawn("hat_" + hat, false, true)
        if hat_node != null:
            attach_hat.add_child(hat_node)
            _accessories.append(hat_node)
    if bool(outfit.get("pack", false)) and attach_back != null:
        var pack := PropFactory.spawn("backpack", false, true)
        if pack != null:
            attach_back.add_child(pack)
            _accessories.append(pack)
            var tint: Color = outfit.get("pack_color", Color(0.55, 0.42, 0.22))
            var meshes: Array[MeshInstance3D] = []
            _meshes_under(pack, meshes)
            for mi in meshes:
                if mi.mesh == null:
                    continue
                for i in range(mi.mesh.get_surface_count()):
                    var src := mi.mesh.surface_get_material(i)
                    if src != null and src.resource_name == "accessory_cloth":
                        var tinted := (MaterialLibrary.get_material("accessory_cloth") as StandardMaterial3D).duplicate() as StandardMaterial3D
                        tinted.albedo_color = tint
                        mi.set_surface_override_material(i, tinted)

func play_reach() -> void:
    _reach_time = 0.55

func _joint(joint_name: String) -> Node3D:
    return model.find_child(joint_name, true, false) as Node3D

func _meshes_under(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and not out.has(node):
        out.append(node as MeshInstance3D)
    for child in node.get_children():
        if child is MeshInstance3D:
            out.append(child as MeshInstance3D)
        _meshes_under(child, out)

func animate(delta: float, planar_speed: float, on_floor: bool, _sprinting: bool = false, _vertical_speed: float = 0.0) -> void:
    if hips == null or spine == null or head == null:
        return
    _idle_time += delta
    _reach_time = maxf(0.0, _reach_time - delta)
    move_amount = lerpf(move_amount, clampf(planar_speed / 4.5, 0.0, 1.0), minf(1.0, delta * 9.0))
    run_amount = lerpf(run_amount, clampf((planar_speed - 3.2) / 2.8, 0.0, 1.0), minf(1.0, delta * 6.0))
    air_amount = lerpf(air_amount, 0.0 if on_floor else 1.0, minf(1.0, delta * 10.0))
    carry_amount = lerpf(carry_amount, 1.0 if carrying else 0.0, minf(1.0, delta * 6.0))
    if on_floor:
        phase += delta * (4.5 + planar_speed * 1.9)

    var amp := move_amount * (1.0 - air_amount)
    var idle := 1.0 - move_amount
    var run := run_amount
    var s := sin(phase)
    var c := cos(phase)
    var breathe := sin(_idle_time * 1.9)
    var air := air_amount

    # legs: positive rotation.x swings a hanging limb forward (-Z); a knee only bends backwards (negative)
    var swing := (0.50 + 0.28 * run) * amp
    var knee_gain := 0.70 + 0.35 * run
    var th_r_x := lerpf(s * swing, 0.85, air)
    var th_l_x := lerpf(-s * swing, -0.15, air)
    var sh_r_x := lerpf(-(0.10 + knee_gain * maxf(0.0, c)) * amp, -1.05, air)
    var sh_l_x := lerpf(-(0.10 + knee_gain * maxf(0.0, -c)) * amp, -0.55, air)
    th_r.rotation.x = th_r_x
    th_l.rotation.x = th_l_x
    sh_r.rotation.x = sh_r_x
    sh_l.rotation.x = sh_l_x
    ft_r.rotation.x = -(th_r_x + sh_r_x) * 0.7
    ft_l.rotation.x = -(th_l_x + sh_l_x) * 0.7

    # arms counter-swing the legs; carrying raises them in front of the chest; airborne spreads them
    var arm_swing := (0.42 + 0.30 * run) * amp
    var elbow := 0.12 + (0.30 + 0.60 * run) * amp
    var ua_r_x := -s * arm_swing
    var ua_l_x := s * arm_swing
    var ua_r_z := 0.045 + 0.012 * breathe * idle
    var ua_l_z := -0.045 - 0.012 * breathe * idle
    var fa_x := elbow
    ua_r_x = lerpf(ua_r_x, 0.85, carry_amount)
    ua_l_x = lerpf(ua_l_x, 0.85, carry_amount)
    fa_x = lerpf(fa_x, 1.15, carry_amount)
    ua_r_z = lerpf(ua_r_z, -0.12, carry_amount)
    ua_l_z = lerpf(ua_l_z, 0.12, carry_amount)
    ua_r_x = lerpf(ua_r_x, -0.35, air)
    ua_l_x = lerpf(ua_l_x, -0.35, air)
    ua_r_z = lerpf(ua_r_z, 0.85, air)
    ua_l_z = lerpf(ua_l_z, -0.85, air)
    var fa_r_x := fa_x
    if _reach_time > 0.0:
        var reach := sin(clampf(_reach_time / 0.55, 0.0, 1.0) * PI)
        ua_r_x = lerpf(ua_r_x, 1.35, reach)
        ua_r_z = lerpf(ua_r_z, 0.05, reach)
        fa_r_x = lerpf(fa_r_x, 0.25, reach)
    ua_r.rotation = Vector3(ua_r_x, 0.0, ua_r_z)
    ua_l.rotation = Vector3(ua_l_x, 0.0, ua_l_z)
    fa_r.rotation.x = fa_r_x
    fa_l.rotation.x = fa_x
    hand_r.rotation.x = 0.12
    hand_l.rotation.x = 0.12

    # torso: bob twice per stride, counter-rotate shoulders against hips, lean into the run
    hips.position.y = _hips_rest_y + 0.034 * amp * (absf(c) - 1.0) * (1.0 + 0.6 * run) - 0.02 * air
    hips.rotation = Vector3(-0.04 * amp, -s * 0.14 * amp, c * 0.03 * amp)
    var lean := -(0.05 + 0.16 * run) * amp - 0.012 * breathe * idle
    spine.rotation = Vector3(lean + air * 0.06, s * 0.20 * amp, 0.0)
    neck.rotation.x = -lean * 0.45
    head.rotation = Vector3(0.03 + sin(_idle_time * 0.31) * 0.04 * idle - lean * 0.45, sin(_idle_time * 0.43) * 0.18 * idle + look_offset, 0.0)
