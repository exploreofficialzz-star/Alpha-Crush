extends CharacterBody3D
class_name HumanNPCAgent

var role := "villager"
var display_name := "Human"
var home_position := Vector3.ZERO
var destination := Vector3.ZERO
var speed := 1.8
var phase := 0.0
var wander_radius := 4.0
var body_material: Material
var dialogue_cooldown := 0.0
var rig: AvatarRig

func setup(pos: Vector3, npc_role: String, npc_name: String = "Human") -> void:
    global_position = pos
    home_position = pos
    role = npc_role
    display_name = npc_name
    phase = float(get_instance_id() % 100) * 0.1
    destination = home_position
    _build_body()

func _build_body() -> void:
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.5
    shape.shape = capsule
    shape.position.y = 0.75
    add_child(shape)
    var label_y := 2.4
    var candidate := AvatarRig.new()
    candidate.name = "AvatarRig"
    add_child(candidate)
    var seed_value := absi(hash(display_name + role)) + 3
    var gender := "female" if (role == "gardener" or role == "builder" or seed_value % 2 == 0) else "male"
    if candidate.build(gender, AvatarRig.outfit_for(role, seed_value)):
        rig = candidate
        label_y = 2.15
    else:
        remove_child(candidate)
        candidate.free()
        _build_fallback_visual()
    var label := Label3D.new()
    label.text = display_name
    label.font_size = 18
    label.outline_size = 6
    label.position.y = label_y
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

func _build_fallback_visual() -> void:
    var body := MeshInstance3D.new()
    var capsule_mesh := CapsuleMesh.new()
    capsule_mesh.radius = 0.3
    capsule_mesh.height = 1.5
    body.mesh = capsule_mesh
    body.position.y = 0.75
    var palette := ["#31577d", "#6f8f4f", "#8a5f8f", "#b16b42", "#556879"]
    body_material = _material(Color(palette[get_instance_id() % palette.size()]))
    body.material_override = body_material
    add_child(body)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.27
    sphere.height = 0.54
    head.mesh = sphere
    head.position = Vector3(0, 1.8, 0)
    head.material_override = _material(Color("#c98d6b"))
    add_child(head)

func interact() -> void:
    var lines := {
        "merchant": "Bring fruit and materials to the market. The village grows when people trade.",
        "farmer": "The fields need seeds, water, and a little patience.",
        "gardener": "Some gardens wake only when the right word is found.",
        "traveler": "The riverlands and caves are full of unfinished stories.",
        "builder": "Words like BRIDGE and REPAIR can change more than a path."
    }
    var line := str(lines.get(role, "Welcome, traveler. Explore and see what needs changing."))
    var bubble := Label3D.new()
    bubble.text = line
    bubble.font_size = 13
    bubble.outline_size = 5
    bubble.modulate = Color("#f5f0d0")
    bubble.position = Vector3(0, 3.0, 0)
    bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(bubble)
    var tween := create_tween()
    tween.tween_interval(3.5)
    tween.tween_callback(bubble.queue_free)

func _process(delta: float) -> void:
    phase += delta
    if phase > 2.5:
        phase = 0.0
        destination = home_position + Vector3(sin(Time.get_ticks_msec() * 0.001 + get_instance_id()) * wander_radius, 0, cos(Time.get_ticks_msec() * 0.0012 + get_instance_id()) * wander_radius)

func _physics_process(delta: float) -> void:
    if not is_inside_tree():
        return
    var offset := destination - global_position
    offset.y = 0
    if offset.length() > 0.5:
        velocity.x = offset.normalized().x * speed
        velocity.z = offset.normalized().z * speed
        move_and_slide()
        rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), delta * 3.0)
    else:
        velocity = Vector3.ZERO
    if rig != null:
        rig.animate(delta, Vector2(velocity.x, velocity.z).length(), true, false, 0.0)

func _material(c: Color) -> Material:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m
