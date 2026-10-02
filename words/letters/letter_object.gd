extends Area3D
class_name LetterObject

signal picked(letter: String)
signal dropped(letter: String, position: Vector3)

var letter := "A"
var carried := false
var base_y := 0.0
var label: Label3D
var ring: MeshInstance3D
var body_mesh: MeshInstance3D
var home_position := Vector3.ZERO

func setup(value: String) -> void:
    letter = value.to_upper()
    name = "Letter_%s_%s" % [letter, str(get_instance_id())]
    home_position = global_position
    collision_layer = 4
    collision_mask = 0
    _build()

func _build() -> void:
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.65
    shape.shape = sphere
    add_child(shape)
    body_mesh = MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3(0.9, 0.9, 0.35)
    body_mesh.mesh = cube
    body_mesh.material_override = _mat(Color("#284b63"))
    add_child(body_mesh)

    label = Label3D.new()
    label.text = letter
    label.font_size = 64
    label.outline_size = 12
    label.modulate = Color("#f4d35e")
    label.position = Vector3(0, 0.8, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)
    ring = MeshInstance3D.new()
    var tor := TorusMesh.new()
    tor.inner_radius = 0.42
    tor.outer_radius = 0.5
    ring.mesh = tor
    ring.rotation_degrees.x = 90
    ring.material_override = _mat(Color("#9ee7ff"))
    add_child(ring)

func _mat(c: Color) -> Material:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c * 0.22
    return m

func _process(delta: float) -> void:
    if not carried:
        rotation.y += delta
        position.y = base_y + sin(Time.get_ticks_msec() / 300.0) * 0.08

func set_highlight(enabled: bool) -> void:
    if label:
        label.modulate = Color("#ffffff") if enabled else Color("#f4d35e")
    if ring:
        ring.scale = Vector3.ONE * (1.18 if enabled else 1.0)
    if body_mesh:
        var material := body_mesh.material_override as StandardMaterial3D
        if material:
            material.emission_enabled = enabled
            material.emission = Color("#9ee7ff") if enabled else Color("#284b63")

func pick(holder: Node3D, local_offset: Vector3 = Vector3.ZERO) -> void:
    carried = true
    collision_layer = 0
    collision_mask = 0
    reparent(holder)
    position = local_offset
    rotation = Vector3.ZERO
    picked.emit(letter)

func drop_at(pos: Vector3) -> void:
    carried = false
    var scene_root: Node = get_tree().current_scene
    if scene_root == null:
        scene_root = get_tree().root
    reparent(scene_root)
    global_position = pos
    home_position = pos
    base_y = pos.y
    collision_layer = 4
    collision_mask = 0
    dropped.emit(letter, pos)
