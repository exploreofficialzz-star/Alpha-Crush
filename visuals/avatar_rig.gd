extends Node3D
class_name AvatarRig

## Skinned humanoid built from assets/models/avatar_<kind>.glb where <kind> is boy | girl (children) or
## man | woman (villagers). The mesh is one continuous skin weighted to a 16-bone skeleton (plus an optional
## ponytail bone) and is animated procedurally: idle breathing, walk/run cycle, jump pose, carrying pose and
## an interact reach. The model faces -Z like everything else in Godot.
##
## Every lookup is null-safe: if a bone, texture or surface is missing the rig keeps working with whatever
## it found instead of raising script errors every frame.

const JOINT_NAMES := ["Hips", "Spine", "Neck", "Head", "UpperArm_R", "Forearm_R", "Hand_R", "UpperArm_L", "Forearm_L", "Hand_L",
    "Thigh_R", "Shin_R", "Foot_R", "Thigh_L", "Shin_L", "Foot_L"]
const SKIN_TONES := [Color(0.93, 0.76, 0.64), Color(0.84, 0.64, 0.49), Color(0.72, 0.52, 0.38), Color(0.56, 0.38, 0.27), Color(0.40, 0.27, 0.19)]
const HAIR_COLORS := [Color(0.10, 0.07, 0.05), Color(0.22, 0.13, 0.07), Color(0.42, 0.26, 0.10), Color(0.70, 0.55, 0.28), Color(0.55, 0.20, 0.10), Color(0.62, 0.62, 0.62)]
const TEX := "res://assets/textures/avatar/"
const ARM_ADDUCT := 0.13
const SURFACE_ORDER := ["avatar_skin_head", "avatar_skin_body", "avatar_shirt", "avatar_pants", "avatar_shoe", "avatar_sole", "avatar_hair", "avatar_eye"]

static var _tex_cache: Dictionary = {}

var gender := "male"
var kind := "man"
var model: Node3D
var skeleton: Skeleton3D
var spec: Dictionary = {}
var head_top := 1.8
var carrying := false
var look_offset := 0.0

var _materials: Dictionary = {}
var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _tail := -1
var _attach_head: BoneAttachment3D
var _attach_back: BoneAttachment3D
var _accessories: Array[Node3D] = []

var phase := 0.0
var move_amount := 0.0
var run_amount := 0.0
var air_amount := 0.0
var carry_amount := 0.0
var _idle_time := 0.0
var _reach_time := 0.0

## Combat poses (gun stance, punches, kicks, hit reaction, slam, cheer). They blend on top of the walk / idle pose.
const PUNCH_SECONDS := 0.28
const KICK_SECONDS := 0.40
const HIT_SECONDS := 0.32
const SLAM_SECONDS := 0.70
const CHEER_SECONDS := 1.60

var aim_blend := 0.0
var _aim_on := false
var _punch_time := 0.0
var _punch_right := true
var _kick_time := 0.0
var _hit_time := 0.0
var _slam_time := 0.0
var _cheer_time := 0.0
var _flash := 0.0
var _flash_color := Color(1, 1, 1, 1)
var _flash_applied := -1.0

# bone indices, -1 when the model lacks the bone
var _i_hips := -1
var _i_spine := -1
var _i_neck := -1
var _i_head := -1
var _i_ua_r := -1
var _i_fa_r := -1
var _i_hand_r := -1
var _i_ua_l := -1
var _i_fa_l := -1
var _i_hand_l := -1
var _i_th_r := -1
var _i_sh_r := -1
var _i_ft_r := -1
var _i_th_l := -1
var _i_sh_l := -1
var _i_ft_l := -1

## outfit keys: skin, shirt, pants, leather, hair (Color); hat: "", "straw", "hard", "sun"; pack: bool; pack_color: Color
static func outfit_for(style: String, role_seed: int = 0, p_gender: String = "") -> Dictionary:
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
            elif p_gender == "female":
                outfit["shirt"] = Color(0.86, 0.34, 0.45)
                outfit["pants"] = Color(0.26, 0.30, 0.50)
                outfit["leather"] = Color(0.62, 0.36, 0.74)
            elif p_gender == "male":
                outfit["shirt"] = Color(0.22, 0.52, 0.80)
                outfit["pants"] = Color(0.18, 0.28, 0.46)
                outfit["leather"] = Color(0.80, 0.22, 0.16)
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

static func kind_for(p_gender: String, p_age: String) -> String:
    if p_age == "child":
        return "girl" if p_gender == "female" else "boy"
    return "woman" if p_gender == "female" else "man"

## p_age: "adult" (villagers) or "child" (the playable boy / girl).
func build(p_gender: String, outfit: Dictionary, p_age: String = "adult") -> bool:
    gender = p_gender
    kind = kind_for(p_gender, p_age)
    spec = AvatarSpecs.get_spec(kind)
    model = PropFactory.spawn("avatar_" + kind, false, true)
    if model == null:
        return false
    skeleton = _find_skeleton(model)
    if skeleton == null:
        push_warning("AvatarRig: avatar_%s has no skeleton" % kind)
        model.free()
        model = null
        return false
    add_child(model)
    _cache_bones()
    head_top = float(spec.get("crown", 1.8))
    _idle_time = randf() * 20.0
    _make_materials(outfit)
    _assign_materials()
    apply_outfit(outfit)
    return true

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _cache_bones() -> void:
    _bones.clear()
    _rest.clear()
    for joint_name in JOINT_NAMES:
        var idx := skeleton.find_bone(joint_name)
        _bones[joint_name] = idx
        if idx >= 0:
            _rest[joint_name] = skeleton.get_bone_rest(idx).origin
    _tail = skeleton.find_bone("Ponytail")
    _i_hips = int(_bones.get("Hips", -1))
    _i_spine = int(_bones.get("Spine", -1))
    _i_neck = int(_bones.get("Neck", -1))
    _i_head = int(_bones.get("Head", -1))
    _i_ua_r = int(_bones.get("UpperArm_R", -1))
    _i_fa_r = int(_bones.get("Forearm_R", -1))
    _i_hand_r = int(_bones.get("Hand_R", -1))
    _i_ua_l = int(_bones.get("UpperArm_L", -1))
    _i_fa_l = int(_bones.get("Forearm_L", -1))
    _i_hand_l = int(_bones.get("Hand_L", -1))
    _i_th_r = int(_bones.get("Thigh_R", -1))
    _i_sh_r = int(_bones.get("Shin_R", -1))
    _i_ft_r = int(_bones.get("Foot_R", -1))
    _i_th_l = int(_bones.get("Thigh_L", -1))
    _i_sh_l = int(_bones.get("Shin_L", -1))
    _i_ft_l = int(_bones.get("Foot_L", -1))

# ---------------------------------------------------------------------------------------------- materials
static func _tex(file_name: String) -> Texture2D:
    if _tex_cache.has(file_name):
        return _tex_cache[file_name]
    var tex: Texture2D = null
    var path := TEX + file_name
    if ResourceLoader.exists(path):
        tex = load(path) as Texture2D
    _tex_cache[file_name] = tex
    return tex

func _std(albedo_file: String, normal_file: String, tint: Color, roughness: float, specular: float, repeat: bool, rim: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.albedo_color = tint
    var albedo: Texture2D = _tex(albedo_file) if albedo_file != "" else null
    if albedo != null:
        m.albedo_texture = albedo
    var normal: Texture2D = _tex(normal_file) if normal_file != "" else null
    if normal != null:
        m.normal_enabled = true
        m.normal_texture = normal
        m.normal_scale = 0.9
    m.roughness = roughness
    m.metallic_specular = specular
    m.texture_repeat = repeat
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    if rim > 0.0:
        m.rim_enabled = true
        m.rim = rim
        m.rim_tint = 0.55
    return m

func _make_materials(outfit: Dictionary) -> void:
    _materials.clear()
    var skin: Color = outfit.get("skin", SKIN_TONES[0])
    var head := _std("skin_head_%s.png" % kind, "skin_head_%s_n.png" % kind, skin, 0.58, 0.30, false, 0.30)
    var body := _std("skin_body.png", "skin_body_n.png", skin, 0.60, 0.28, true, 0.26)
    var shirt := _std("fabric_knit.png", "fabric_knit_n.png", outfit.get("shirt", Color(0.27, 0.36, 0.50)), 0.92, 0.10, true, 0.12)
    var pants := _std("fabric_denim.png", "fabric_denim_n.png", outfit.get("pants", Color(0.31, 0.34, 0.22)), 0.88, 0.10, true, 0.10)
    var shoe := _std("fabric_canvas.png", "fabric_canvas_n.png", outfit.get("leather", Color(0.30, 0.19, 0.11)), 0.75, 0.15, true, 0.08)
    var sole := _std("rubber.png", "rubber_n.png", Color(0.90, 0.88, 0.82), 0.85, 0.10, true)
    var hair := _std("hair_%s.png" % kind, "hair_%s_n.png" % kind, outfit.get("hair", HAIR_COLORS[1]), 0.48, 0.40, true, 0.30)
    var eye := _std("eye.png", "", Color.WHITE, 0.06, 0.90, false)
    eye.vertex_color_use_as_albedo = false
    _materials = {"avatar_skin_head": head, "avatar_skin_body": body, "avatar_shirt": shirt, "avatar_pants": pants,
        "avatar_shoe": shoe, "avatar_sole": sole, "avatar_hair": hair, "avatar_eye": eye}

func _assign_materials() -> void:
    var meshes: Array[MeshInstance3D] = []
    _meshes_under(model, meshes)
    for mi in meshes:
        if mi.mesh == null:
            continue
        var count := mi.mesh.get_surface_count()
        for i in range(count):
            var src := mi.mesh.surface_get_material(i)
            var id := src.resource_name if src != null else ""
            if id == "" and count == SURFACE_ORDER.size():
                id = SURFACE_ORDER[i]
            if _materials.has(id):
                mi.set_surface_override_material(i, _materials[id])
        mi.extra_cull_margin = 0.5

func apply_outfit(outfit: Dictionary) -> void:
    if _materials.has("avatar_skin_head"):
        var skin: Color = outfit.get("skin", SKIN_TONES[0])
        (_materials["avatar_skin_head"] as StandardMaterial3D).albedo_color = skin
        (_materials["avatar_skin_body"] as StandardMaterial3D).albedo_color = skin
        if outfit.has("shirt"):
            (_materials["avatar_shirt"] as StandardMaterial3D).albedo_color = outfit["shirt"]
        if outfit.has("pants"):
            (_materials["avatar_pants"] as StandardMaterial3D).albedo_color = outfit["pants"]
        if outfit.has("leather"):
            (_materials["avatar_shoe"] as StandardMaterial3D).albedo_color = outfit["leather"]
        if outfit.has("hair"):
            (_materials["avatar_hair"] as StandardMaterial3D).albedo_color = outfit["hair"]
    for node in _accessories:
        if is_instance_valid(node):
            node.queue_free()
    _accessories.clear()
    if skeleton == null:
        return
    var hat := str(outfit.get("hat", ""))
    if hat != "":
        var anchor := _attachment("Head")
        var hat_node := PropFactory.spawn("hat_" + hat, false, true)
        if anchor != null and hat_node != null:
            var rest_y := float(_rest_global("Head").y)
            hat_node.scale = Vector3.ONE * float(spec.get("hat_scale", 0.5))
            hat_node.position = Vector3(0.0, float(spec.get("hat_y", head_top - 0.08)) - rest_y, 0.0)
            anchor.add_child(hat_node)
            _accessories.append(hat_node)
    if bool(outfit.get("pack", false)):
        var anchor_back := _attachment("Spine")
        var pack := PropFactory.spawn("backpack", false, true)
        if anchor_back != null and pack != null:
            var rest_back := float(_rest_global("Spine").y)
            var where: Vector3 = spec.get("pack", Vector3(0.0, 1.2, 0.11))
            var pack_scale := float(spec.get("pack_scale", 0.5))
            pack.scale = Vector3.ONE * pack_scale
            pack.position = Vector3(0.05 * pack_scale, where.y - rest_back, where.z)
            anchor_back.add_child(pack)
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
                        var base := MaterialLibrary.get_material("accessory_cloth") as StandardMaterial3D
                        if base != null:
                            var tinted := base.duplicate() as StandardMaterial3D
                            tinted.albedo_color = tint
                            mi.set_surface_override_material(i, tinted)

func _attachment(bone_name: String) -> BoneAttachment3D:
    var existing: BoneAttachment3D = _attach_head if bone_name == "Head" else _attach_back
    if existing != null and is_instance_valid(existing):
        return existing
    if skeleton == null or skeleton.find_bone(bone_name) < 0:
        return null
    var att := BoneAttachment3D.new()
    att.name = "Attach_" + bone_name
    skeleton.add_child(att)
    att.bone_name = bone_name
    if bone_name == "Head":
        _attach_head = att
    else:
        _attach_back = att
    return att

func _rest_global(joint_name: String) -> Vector3:
    var idx := int(_bones.get(joint_name, -1))
    if skeleton == null or idx < 0:
        return Vector3.ZERO
    return skeleton.get_bone_global_rest(idx).origin

func play_reach() -> void:
    _reach_time = 0.55

func _meshes_under(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and not out.has(node):
        out.append(node as MeshInstance3D)
    for child in node.get_children():
        _meshes_under(child, out)

# ---------------------------------------------------------------------------------------------- animation
func _rot(bone: int, euler: Vector3) -> void:
    if bone >= 0:
        skeleton.set_bone_pose_rotation(bone, Quaternion.from_euler(euler))

func animate(delta: float, planar_speed: float, on_floor: bool, _sprinting: bool = false, _vertical_speed: float = 0.0) -> void:
    if skeleton == null or _i_hips < 0 or _i_spine < 0 or _i_head < 0:
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
    _rot(_i_th_r, Vector3(th_r_x, 0.0, 0.0))
    _rot(_i_th_l, Vector3(th_l_x, 0.0, 0.0))
    _rot(_i_sh_r, Vector3(sh_r_x, 0.0, 0.0))
    _rot(_i_sh_l, Vector3(sh_l_x, 0.0, 0.0))
    _rot(_i_ft_r, Vector3(-(th_r_x + sh_r_x) * 0.7, 0.0, 0.0))
    _rot(_i_ft_l, Vector3(-(th_l_x + sh_l_x) * 0.7, 0.0, 0.0))

    # arms counter-swing the legs; carrying raises them in front of the chest; airborne spreads them
    var arm_swing := (0.42 + 0.30 * run) * amp
    var elbow := 0.12 + (0.30 + 0.60 * run) * amp
    var ua_r_x := -s * arm_swing
    var ua_l_x := s * arm_swing
    # the model is modelled in an A-pose (arms 16 degrees out) so that skin never fuses with the hips;
    # at rest the arms are drawn in again by ARM_ADDUCT so they hang naturally
    var ua_r_z := -ARM_ADDUCT + 0.012 * breathe * idle
    var ua_l_z := ARM_ADDUCT - 0.012 * breathe * idle
    var fa_x := elbow
    ua_r_x = lerpf(ua_r_x, 0.85, carry_amount)
    ua_l_x = lerpf(ua_l_x, 0.85, carry_amount)
    fa_x = lerpf(fa_x, 1.15, carry_amount)
    ua_r_z = lerpf(ua_r_z, -0.30, carry_amount)
    ua_l_z = lerpf(ua_l_z, 0.30, carry_amount)
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
    _rot(_i_ua_r, Vector3(ua_r_x, 0.0, ua_r_z))
    _rot(_i_ua_l, Vector3(ua_l_x, 0.0, ua_l_z))
    _rot(_i_fa_r, Vector3(fa_r_x, 0.0, 0.0))
    _rot(_i_fa_l, Vector3(fa_x, 0.0, 0.0))
    _rot(_i_hand_r, Vector3(0.12, 0.0, 0.0))
    _rot(_i_hand_l, Vector3(0.12, 0.0, 0.0))

    # torso: bob twice per stride, counter-rotate shoulders against hips, lean into the run
    var rest_hips: Vector3 = _rest.get("Hips", Vector3.ZERO)
    skeleton.set_bone_pose_position(_i_hips, rest_hips + Vector3(0.0, 0.034 * amp * (absf(c) - 1.0) * (1.0 + 0.6 * run) - 0.02 * air, 0.0))
    _rot(_i_hips, Vector3(-0.04 * amp, -s * 0.14 * amp, c * 0.03 * amp))
    var lean := -(0.05 + 0.16 * run) * amp - 0.012 * breathe * idle
    _rot(_i_spine, Vector3(lean + air * 0.06, s * 0.20 * amp, 0.0))
    _rot(_i_neck, Vector3(-lean * 0.45, 0.0, 0.0))
    _rot(_i_head, Vector3(0.03 + sin(_idle_time * 0.31) * 0.04 * idle - lean * 0.45, sin(_idle_time * 0.43) * 0.18 * idle + look_offset, 0.0))
    if _tail >= 0:
        _rot(_tail, Vector3(0.05 * sin(_idle_time * 1.3) + 0.24 * amp * sin(phase * 2.0 + 0.6) - 0.10 * air,
            0.0, 0.10 * amp * sin(phase + 1.2) + 0.03 * sin(_idle_time * 0.9)))
    _apply_combat_overlay(delta)

# ---------------------------------------------------------------------------------------------- combat poses
func set_aiming(value: bool) -> void:
    _aim_on = value

func play_punch(use_right: bool) -> void:
    _punch_time = PUNCH_SECONDS
    _punch_right = use_right

func play_kick() -> void:
    _kick_time = KICK_SECONDS

func play_hit() -> void:
    _hit_time = HIT_SECONDS

func play_slam() -> void:
    _slam_time = SLAM_SECONDS

func play_cheer() -> void:
    _cheer_time = CHEER_SECONDS

## Brief colour wash on the body (white when hit, orange while a crush move charges). Fades by itself.
func flash(amount: float, color: Color = Color(1, 1, 1, 1)) -> void:
    _flash = clampf(amount, 0.0, 1.0)
    _flash_color = color

func is_busy() -> bool:
    return _punch_time > 0.0 or _kick_time > 0.0 or _slam_time > 0.0

## Slerps one bone from the pose the walk / idle code just wrote towards `euler`, `weight` of the way.
func _blend_rot(bone: int, euler: Vector3, weight: float) -> void:
    if bone < 0 or weight <= 0.001:
        return
    var current := skeleton.get_bone_pose_rotation(bone)
    skeleton.set_bone_pose_rotation(bone, current.slerp(Quaternion.from_euler(euler), clampf(weight, 0.0, 1.0)))

func _apply_combat_overlay(delta: float) -> void:
    if skeleton == null:
        return
    aim_blend = lerpf(aim_blend, 1.0 if _aim_on else 0.0, minf(1.0, delta * 12.0))
    _punch_time = maxf(0.0, _punch_time - delta)
    _kick_time = maxf(0.0, _kick_time - delta)
    _hit_time = maxf(0.0, _hit_time - delta)
    _slam_time = maxf(0.0, _slam_time - delta)
    _cheer_time = maxf(0.0, _cheer_time - delta)
    _flash = maxf(0.0, _flash - delta * 4.0)
    _apply_flash()
    # Gun stance: both arms raised to hold the weapon in front of the chest.
    if aim_blend > 0.01:
        _blend_rot(_i_ua_r, Vector3(1.38, 0.0, -0.06), aim_blend)
        _blend_rot(_i_fa_r, Vector3(0.32, 0.0, 0.0), aim_blend)
        _blend_rot(_i_ua_l, Vector3(1.22, 0.0, 0.42), aim_blend)
        _blend_rot(_i_fa_l, Vector3(0.95, 0.0, 0.0), aim_blend)
    # Kung-fu punch: the striking arm snaps forward while the torso twists into it and the other hand guards.
    if _punch_time > 0.0:
        var strike := sin(clampf(1.0 - _punch_time / PUNCH_SECONDS, 0.0, 1.0) * PI)
        var side := 1.0 if _punch_right else -1.0
        if _punch_right:
            _blend_rot(_i_ua_r, Vector3(1.50, 0.0, -0.05), strike)
            _blend_rot(_i_fa_r, Vector3(0.10, 0.0, 0.0), strike)
            _blend_rot(_i_ua_l, Vector3(0.90, 0.0, 0.50), strike * 0.8)
            _blend_rot(_i_fa_l, Vector3(1.60, 0.0, 0.0), strike * 0.8)
        else:
            _blend_rot(_i_ua_l, Vector3(1.50, 0.0, 0.05), strike)
            _blend_rot(_i_fa_l, Vector3(0.10, 0.0, 0.0), strike)
            _blend_rot(_i_ua_r, Vector3(0.90, 0.0, -0.50), strike * 0.8)
            _blend_rot(_i_fa_r, Vector3(1.60, 0.0, 0.0), strike * 0.8)
        _blend_rot(_i_spine, Vector3(-0.12, 0.45 * side, 0.0), strike)
        _blend_rot(_i_hips, Vector3(0.0, 0.25 * side, 0.0), strike * 0.6)
    # Kick: the right leg whips up in front, arms spread for balance, torso leans back.
    if _kick_time > 0.0:
        var lift := sin(clampf(1.0 - _kick_time / KICK_SECONDS, 0.0, 1.0) * PI)
        _blend_rot(_i_th_r, Vector3(1.45, 0.0, 0.0), lift)
        _blend_rot(_i_sh_r, Vector3(-0.12, 0.0, 0.0), lift)
        _blend_rot(_i_ft_r, Vector3(0.40, 0.0, 0.0), lift)
        _blend_rot(_i_spine, Vector3(0.28, 0.0, 0.0), lift)
        _blend_rot(_i_ua_r, Vector3(0.30, 0.0, 0.90), lift)
        _blend_rot(_i_ua_l, Vector3(0.30, 0.0, -0.90), lift)
    # Hit reaction: a quick snap backwards that decays.
    if _hit_time > 0.0:
        var snap := clampf(_hit_time / HIT_SECONDS, 0.0, 1.0)
        _blend_rot(_i_spine, Vector3(0.38, 0.0, 0.0), snap)
        _blend_rot(_i_head, Vector3(0.30, 0.0, 0.0), snap)
        _blend_rot(_i_ua_r, Vector3(0.50, 0.0, 0.50), snap * 0.8)
        _blend_rot(_i_ua_l, Vector3(0.50, 0.0, -0.50), snap * 0.8)
    # Ground slam (the QUAKE crush): arms overhead, then smashed down with the torso bending forward.
    if _slam_time > 0.0:
        var progress := clampf(1.0 - _slam_time / SLAM_SECONDS, 0.0, 1.0)
        var raise := smoothstep(0.0, 0.45, progress) * (1.0 - smoothstep(0.50, 0.62, progress))
        var smash := smoothstep(0.50, 0.62, progress) * (1.0 - smoothstep(0.85, 1.0, progress))
        _blend_rot(_i_ua_r, Vector3(2.90, 0.0, -0.15), raise)
        _blend_rot(_i_ua_l, Vector3(2.90, 0.0, 0.15), raise)
        _blend_rot(_i_fa_r, Vector3(0.30, 0.0, 0.0), raise)
        _blend_rot(_i_fa_l, Vector3(0.30, 0.0, 0.0), raise)
        _blend_rot(_i_ua_r, Vector3(0.50, 0.0, -0.10), smash)
        _blend_rot(_i_ua_l, Vector3(0.50, 0.0, 0.10), smash)
        _blend_rot(_i_spine, Vector3(-0.55, 0.0, 0.0), smash)
    # Victory cheer: both arms pumping overhead.
    if _cheer_time > 0.0:
        var pump := 0.5 + 0.5 * sin(_idle_time * 14.0)
        var fade := clampf(_cheer_time / CHEER_SECONDS, 0.0, 1.0)
        _blend_rot(_i_ua_r, Vector3(2.6 + 0.3 * pump, 0.0, -0.35), fade)
        _blend_rot(_i_ua_l, Vector3(2.6 + 0.3 * (1.0 - pump), 0.0, 0.35), fade)
        _blend_rot(_i_fa_r, Vector3(0.4, 0.0, 0.0), fade)
        _blend_rot(_i_fa_l, Vector3(0.4, 0.0, 0.0), fade)

func _apply_flash() -> void:
    if is_equal_approx(_flash, _flash_applied):
        return
    _flash_applied = _flash
    for id in ["avatar_shirt", "avatar_pants", "avatar_skin_body", "avatar_skin_head"]:
        var material := _materials.get(id) as StandardMaterial3D
        if material == null:
            continue
        material.emission_enabled = _flash > 0.01
        if _flash > 0.01:
            material.emission = _flash_color
            material.emission_energy_multiplier = _flash * 1.4
