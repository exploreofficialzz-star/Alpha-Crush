extends CharacterBody3D
class_name AlphaCrushPlayer

var interaction_source: Node
var settings: SettingsManager
var camera_sensitivity := 1.0
var speed := 5.5
var sprint_speed := 8.0
var jump_velocity := 5.0
var gravity := 14.0
var camera: Camera3D
var pivot: Node3D
var yaw := 0.0
var pitch := -10.0
var mobile_move := Vector2.ZERO
var mobile_sprint := false
var interact_cooldown := 0.0
var carry_socket: Node3D
var carried_letters: Array[LetterObject] = []
var visual_root: Node3D
var name_label: Label3D
var profile_style := "default"
signal footstep

var rig: AvatarRig
var _step_distance := 0.0
var body_type := "male"
var _avatar_seed := 1

const LIMB_PHASE := {"LeftArm": 1.0, "RightLeg": 1.0, "RightArm": -1.0, "LeftLeg": -1.0}

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1 | 4 | 8
    _build_body()
    _build_camera()

func _build_body() -> void:
    visual_root = Node3D.new()
    visual_root.name = "HumanVisual"
    add_child(visual_root)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38
    capsule.height = 1.75
    shape.shape = capsule
    shape.position.y = 0.9
    add_child(shape)
    if not _build_rig():
        _build_fallback_body()
    name_label = Label3D.new()
    name_label.text = "EXPLORER"
    name_label.font_size = 16
    name_label.outline_size = 6
    name_label.position = Vector3(0, 2.2 if rig != null else 2.45, 0)
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    visual_root.add_child(name_label)
    carry_socket = Node3D.new()
    carry_socket.name = "CarrySocket"
    carry_socket.position = Vector3(0, 1.25, -0.55)
    add_child(carry_socket)

func _build_rig() -> bool:
    var candidate := AvatarRig.new()
    candidate.name = "AvatarRig"
    visual_root.add_child(candidate)
    if candidate.build(body_type, AvatarRig.outfit_for(profile_style, _avatar_seed)):
        rig = candidate
        return true
    visual_root.remove_child(candidate)
    candidate.free()
    return false

## Switch between the male and female base model at runtime (settings toggle).
func set_body_type(value: String) -> void:
    if value == body_type or visual_root == null:
        return
    body_type = value
    if rig != null:
        visual_root.remove_child(rig)
        rig.free()
        rig = null
    if not _build_rig():
        body_type = "male" if value != "male" else value

func _build_fallback_body() -> void:
    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.38
    cap.height = 1.75
    body.mesh = cap
    body.position.y = 0.9
    body.material_override = _mat(Color("#24364b"))
    visual_root.add_child(body)
    visual_root.add_child(_limb("LeftArm", Vector3(-0.52, 1.0, 0), Vector3(0.16, 0.75, 0.16)))
    visual_root.add_child(_limb("RightArm", Vector3(0.52, 1.0, 0), Vector3(0.16, 0.75, 0.16)))
    visual_root.add_child(_limb("LeftLeg", Vector3(-0.18, 0.25, 0), Vector3(0.18, 0.9, 0.18)))
    visual_root.add_child(_limb("RightLeg", Vector3(0.18, 0.25, 0), Vector3(0.18, 0.9, 0.18)))
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.3
    sphere.height = 0.6
    head.mesh = sphere
    head.position = Vector3(0, 2, 0)
    head.material_override = _mat(Color("#c98d6b"))
    visual_root.add_child(head)

func _limb(limb_name: String, pos: Vector3, size: Vector3) -> MeshInstance3D:
    var limb := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = size.x
    mesh.height = size.y
    limb.mesh = mesh
    limb.position = pos
    limb.name = limb_name
    limb.material_override = _mat(Color("#24364b"))
    return limb

func _mat(c: Color) -> Material:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m

func _build_camera() -> void:
    pivot = Node3D.new()
    pivot.name = "CameraPivot"
    pivot.position = Vector3(0, 2.4, 0)
    add_child(pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 2.2, 7.5)
    camera.rotation_degrees = Vector3(-10, 0, 0)
    camera.current = true
    camera.fov = 62
    pivot.add_child(camera)

func _physics_process(delta: float) -> void:
    interact_cooldown = maxf(0.0, interact_cooldown - delta)
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if mobile_move.length() > 0.1:
        input_vec = mobile_move
    # Movement is relative to where the camera is looking (yaw), not to fixed world axes;
    # otherwise "forward" drifts sideways as soon as the camera has been turned.
    var dir := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(input_vec.x, 0.0, input_vec.y)
    var target_speed := sprint_speed if (Input.is_action_pressed("sprint") or mobile_sprint) else speed
    if dir.length() > 0.1:
        dir = dir.normalized()
        velocity.x = dir.x * target_speed
        velocity.z = dir.z * target_speed
        var facing := Vector3(dir.x, 0, dir.z)
        rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 10.0))
    else:
        velocity.x = move_toward(velocity.x, 0, target_speed * 8 * delta)
        velocity.z = move_toward(velocity.z, 0, target_speed * 8 * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity
    move_and_slide()
    if is_on_floor():
        var planar := Vector2(velocity.x, velocity.z).length()
        if planar > 0.6:
            _step_distance += planar * delta
            if _step_distance >= (2.4 if planar > 4.0 else 1.7):
                _step_distance = 0.0
                footstep.emit()
    if global_position.y < -30.0:
        # Safety net: never leave the player in endless freefall (e.g. a chunk that failed to load).
        global_position = Vector3(0.0, 2.0, 10.0)
        velocity = Vector3.ZERO
    _update_camera_rig()
    _animate_body(delta, dir.length())
    if Input.is_action_just_pressed("interact"):
        interact()
    if Input.is_action_just_pressed("drop"):
        drop_latest_letter()

func interact() -> void:
    if interact_cooldown > 0.0 or interaction_source == null:
        return
    interact_cooldown = 0.2
    if rig != null:
        rig.play_reach()
    interaction_source.call("try_interact", self)
    if settings and bool(settings.get_value("vibration", true)):
        Input.vibrate_handheld(25)

func set_mobile_move(vector: Vector2) -> void:
    mobile_move = vector

func set_mobile_sprint(enabled: bool) -> void:
    mobile_sprint = enabled

func carry_letter(letter: LetterObject) -> void:
    if letter == null or not is_instance_valid(letter) or carry_socket == null:
        return
    if letter.has_method("pick"):
        var offset := Vector3((carried_letters.size() % 3 - 1) * 0.35, 0.15 + carried_letters.size() * 0.12, 0)
        letter.pick(carry_socket, offset)
    carried_letters.append(letter)

func drop_latest_letter() -> void:
    if carried_letters.is_empty():
        return
    var letter = carried_letters.pop_back()
    if not is_instance_valid(letter):
        return
    var forward := -global_transform.basis.z
    forward.y = 0.0
    var drop_position := global_position + forward.normalized() * 1.1 + Vector3(0, 0.2, 0)
    letter.drop_at(drop_position)
    if interaction_source and interaction_source.has_method("register_dropped_letter"):
        interaction_source.call("register_dropped_letter", letter)
    if interaction_source and interaction_source.has_method("release_collected_letter"):
        interaction_source.call("release_collected_letter", str(letter.letter))

func clear_carried_letters() -> void:
    for letter in carried_letters:
        if is_instance_valid(letter):
            letter.queue_free()
    carried_letters.clear()

func _animate_body(delta: float, movement: float) -> void:
    if visual_root == null:
        return
    if rig != null:
        rig.carrying = not carried_letters.is_empty()
        rig.animate(delta, Vector2(velocity.x, velocity.z).length(), is_on_floor(), Input.is_action_pressed("sprint") or mobile_sprint, velocity.y)
        return
    var cadence := Time.get_ticks_msec() * 0.012
    var swing: float = sin(cadence) * minf(1.0, movement) * 0.22
    for child in visual_root.get_children():
        var limb_name := String(child.name)
        if not LIMB_PHASE.has(limb_name):
            continue
        # Diagonal limbs move together (left arm with right leg), like a real walk cycle.
        var target: float = swing * float(LIMB_PHASE[limb_name])
        child.rotation.x = lerpf(child.rotation.x, target, minf(1.0, delta * 14.0))

func apply_profile(profile: PlayerProfileManager) -> void:
    if profile == null:
        return
    profile_style = str(profile.avatar_style)
    _avatar_seed = absi(hash(str(profile.display_name))) + 1
    if name_label:
        name_label.text = str(profile.display_name).to_upper()
    if rig != null:
        rig.apply_outfit(AvatarRig.outfit_for(profile_style, _avatar_seed))
        return
    var palette := {
        "default": Color("#24364b"),
        "sunrise": Color("#b16b42"),
        "forest": Color("#52754d"),
        "coastal": Color("#3e7890")
    }
    var chosen: Color = palette.get(profile_style, palette["default"])
    if visual_root:
        for child in visual_root.get_children():
            if child is MeshInstance3D and child.name != "":
                var material := child.material_override as StandardMaterial3D
                if material and child.position.y < 1.8:
                    material.albedo_color = chosen

const CAMERA_DEGREES_PER_PIXEL := 0.22

func nudge_camera(delta: Vector2) -> void:
    yaw -= delta.x * CAMERA_DEGREES_PER_PIXEL * camera_sensitivity
    pitch = clampf(pitch - delta.y * CAMERA_DEGREES_PER_PIXEL * camera_sensitivity, -40.0, 20.0)
    _update_camera_rig()

func _update_camera_rig() -> void:
    if pivot == null:
        return
    # The pivot is a child of the body, which turns to face the walking direction.
    # Cancel that turn so the camera orbit only follows the player's own yaw input.
    pivot.rotation_degrees = Vector3(pitch, yaw - rotation_degrees.y, 0.0)

func _input(event: InputEvent) -> void:
    # Desktop: hold the right mouse button and move to orbit the camera (touch uses CameraDrag).
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        var motion := event as InputEventMouseMotion
        nudge_camera(motion.relative)
