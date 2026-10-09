extends Node3D
class_name AnimalAgent

var species := "deer"
var roam_radius := 5.0
var home := Vector3.ZERO
var target := Vector3.ZERO
var speed := 1.1
var body: Node3D
var head: Node3D
var model: Node3D
var legs: Array[Node3D] = []
var tail: Node3D
var walk_phase := 0.0
var idle_time := 0.0
var graze_until := 0.0
var _body_rest_y := 0.0
var rng := RandomNumberGenerator.new()
var change_timer := 0.0

func setup(kind: String, origin: Vector3, seed_value: int) -> void:
    species = kind
    home = origin
    global_position = origin
    rng.seed = seed_value
    _build_visual()
    _choose_target()

func _build_visual() -> void:
    model = PropFactory.spawn("animal_" + species, false, true)
    if model != null:
        add_child(model)
        body = model.find_child("Body", true, false) as Node3D
        head = model.find_child("Head", true, false) as Node3D
        tail = model.find_child("Tail", true, false) as Node3D
        for leg_name in ["Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Leg_L", "Leg_R"]:
            var leg := model.find_child(leg_name, true, false) as Node3D
            if leg != null:
                legs.append(leg)
        if body != null:
            _body_rest_y = body.position.y
            return
        model.queue_free()
        legs.clear()
    _build_fallback_visual()

func _build_fallback_visual() -> void:
    var body_mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.35
    capsule.height = 0.9
    body_mesh.mesh = capsule
    body_mesh.position.y = 0.55
    body_mesh.rotation_degrees.z = 90
    body_mesh.material_override = _mat(_species_color())
    add_child(body_mesh)
    body = body_mesh
    _body_rest_y = 0.55
    var head_mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.25
    sphere.height = 0.5
    head_mesh.mesh = sphere
    head_mesh.position = Vector3(0.45, 0.78, -0.1)
    head_mesh.material_override = _mat(_species_color().lightened(0.08))
    add_child(head_mesh)
    head = head_mesh
    for x in [-0.25, 0.25]:
        for z in [-0.16, 0.16]:
            var leg := MeshInstance3D.new()
            var mesh := BoxMesh.new()
            mesh.size = Vector3(0.11, 0.5, 0.11)
            leg.mesh = mesh
            leg.position = Vector3(x, 0.25, z)
            leg.material_override = _mat(Color("#47382f"))
            add_child(leg)

func _species_color() -> Color:
    match species:
        "cow": return Color("#d8d0c4")
        "goat": return Color("#b7a78f")
        "deer": return Color("#9b6a43")
        "chicken": return Color("#eee6cf")
        _ : return Color("#8c7a5b")

func _mat(c: Color) -> Material:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m

func _process(delta: float) -> void:
    change_timer -= delta
    if change_timer <= 0.0 or global_position.distance_to(target) < 0.7:
        _choose_target()
    var flat := target - global_position
    flat.y = 0
    var moving := flat.length() > 0.1 and Time.get_ticks_msec() * 0.001 > graze_until
    if moving:
        var step := flat.normalized() * speed * delta
        global_position += step
        global_position.y = TerrainField.height_at(global_position.x, global_position.z)
        rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 4.0))
    _animate(delta, moving)

func _animate(delta: float, moving: bool) -> void:
    if body == null:
        return
    idle_time += delta
    if moving:
        walk_phase += delta * speed * 6.0
    var swing := sin(walk_phase) * 0.5 if moving else 0.0
    var gait := 0
    for leg in legs:
        # diagonal pairs move together; the chicken just alternates its two legs
        var sign_value := 1.0 if (gait == 0 or gait == 3) else -1.0
        if legs.size() == 2:
            sign_value = 1.0 if gait == 0 else -1.0
        leg.rotation.x = lerpf(leg.rotation.x, swing * sign_value, minf(1.0, delta * 12.0))
        gait += 1
    if model != null:
        body.position.y = _body_rest_y + (absf(sin(walk_phase)) * 0.02 if moving else 0.0)
    else:
        body.position.y = _body_rest_y + (sin(Time.get_ticks_msec() * 0.012) * 0.025 if moving else 0.0)
    if head != null and model != null:
        var target_tilt := 0.06 * sin(walk_phase * 2.0) if moving else (-0.75 if sin(idle_time * 0.35) > 0.45 else 0.04 * sin(idle_time * 1.1))
        if species == "chicken" and not moving:
            target_tilt = -0.55 * maxf(0.0, sin(idle_time * 4.5))
        head.rotation.x = lerpf(head.rotation.x, target_tilt, minf(1.0, delta * 5.0))
    if tail != null:
        tail.rotation.z = sin(idle_time * 3.1) * 0.25

func _choose_target() -> void:
    change_timer = rng.randf_range(2.0, 5.0)
    target = home + Vector3(rng.randf_range(-roam_radius, roam_radius), 0, rng.randf_range(-roam_radius, roam_radius))
