extends Node3D
class_name AnimalAgent

var species := "deer"
var roam_radius := 5.0
var home := Vector3.ZERO
var target := Vector3.ZERO
var speed := 1.1
var body: MeshInstance3D
var head: MeshInstance3D
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
    body = MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.35
    capsule.height = 0.9
    body.mesh = capsule
    body.position.y = 0.55
    body.rotation_degrees.z = 90
    body.material_override = _mat(_species_color())
    add_child(body)
    head = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.25
    sphere.height = 0.5
    head.mesh = sphere
    head.position = Vector3(0.45, 0.78, -0.1)
    head.material_override = _mat(_species_color().lightened(0.08))
    add_child(head)
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
    if flat.length() > 0.1:
        var step := flat.normalized() * speed * delta
        global_position += step
        rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 4.0))
        body.position.y = 0.55 + sin(Time.get_ticks_msec() * 0.012) * 0.025

func _choose_target() -> void:
    change_timer = rng.randf_range(2.0, 5.0)
    target = home + Vector3(rng.randf_range(-roam_radius, roam_radius), 0, rng.randf_range(-roam_radius, roam_radius))
