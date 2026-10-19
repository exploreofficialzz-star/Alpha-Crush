extends Area3D
class_name LetterObject

signal picked(letter: String)
signal dropped(letter: String, position: Vector3)

var letter := "A"
var carried := false
var base_y := 0.0
var label: Label3D
var ring: MeshInstance3D
var body_mesh: Node3D
var gem_material: StandardMaterial3D
var faces: Array[Label3D] = []
## A tall soft light beam so a child can spot a gem from across the meadow without reading anything.
var beam: MeshInstance3D
var beam_material: StandardMaterial3D

const GEM_COLORS := [Color("#3b82f6"), Color("#f59e0b"), Color("#ec4899"), Color("#22c55e"), Color("#8b5cf6"), Color("#06b6d4")]
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
    var tint: Color = GEM_COLORS[(letter.unicode_at(0) * 7) % GEM_COLORS.size()]
    var gem := PropFactory.spawn("letter_gem", false, true)
    if gem != null:
        gem.position.y = -0.28
        body_mesh = gem
        add_child(gem)
        gem_material = (MaterialLibrary.get_material("gem") as StandardMaterial3D).duplicate() as StandardMaterial3D
        gem_material.albedo_color = tint
        gem_material.emission = tint
        _apply_gem_material(gem)
    else:
        var cube_mesh := MeshInstance3D.new()
        var cube := BoxMesh.new()
        cube.size = Vector3(0.9, 0.9, 0.35)
        cube_mesh.mesh = cube
        cube_mesh.material_override = _mat(Color("#284b63"))
        body_mesh = cube_mesh
        add_child(cube_mesh)
    # the letter is printed on all four sides of the gem so it reads from any direction
    for k in range(4):
        var face := Label3D.new()
        face.text = letter
        face.font_size = 96
        face.pixel_size = 0.0042
        face.outline_size = 14
        face.outline_modulate = tint.darkened(0.55)
        face.modulate = Color(1, 1, 1)
        face.double_sided = false
        face.rotation_degrees.y = float(k) * 90.0
        face.position = Basis(Vector3.UP, deg_to_rad(float(k) * 90.0)) * Vector3(0, 0, 0.292)
        add_child(face)
        faces.append(face)
    label = faces[0]
    ring = MeshInstance3D.new()
    var tor := TorusMesh.new()
    tor.inner_radius = 0.42
    tor.outer_radius = 0.5
    ring.mesh = tor
    ring.rotation_degrees.x = 90
    ring.material_override = _mat(Color("#9ee7ff"))
    add_child(ring)
    _build_beam(tint)

func _build_beam(tint: Color) -> void:
    beam = MeshInstance3D.new()
    beam.name = "Beacon"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.1
    cylinder.bottom_radius = 0.36
    cylinder.height = 7.0
    cylinder.radial_segments = 10
    cylinder.rings = 1
    cylinder.cap_top = false
    cylinder.cap_bottom = false
    beam.mesh = cylinder
    beam.position = Vector3(0.0, 3.5, 0.0)
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    beam_material = StandardMaterial3D.new()
    beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    beam_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.3)
    beam.material_override = beam_material
    add_child(beam)

func _apply_gem_material(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var mi := child as MeshInstance3D
            if mi.mesh != null:
                for i in range(mi.mesh.get_surface_count()):
                    mi.set_surface_override_material(i, gem_material)
        _apply_gem_material(child)

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
        if beam_material != null:
            var glow := beam_material.albedo_color
            glow.a = 0.24 + 0.1 * sin(Time.get_ticks_msec() / 420.0)
            beam_material.albedo_color = glow

func set_highlight(enabled: bool) -> void:
    for face in faces:
        face.modulate = Color("#fff6a8") if enabled else Color(1, 1, 1)
    if ring:
        ring.scale = Vector3.ONE * (1.18 if enabled else 1.0)
    if gem_material != null:
        gem_material.emission_energy_multiplier = 1.6 if enabled else 0.55
    elif body_mesh is MeshInstance3D:
        var material := (body_mesh as MeshInstance3D).material_override as StandardMaterial3D
        if material:
            material.emission_enabled = enabled
            material.emission = Color("#9ee7ff") if enabled else Color("#284b63")

func pick(holder: Node3D, local_offset: Vector3 = Vector3.ZERO) -> void:
    carried = true
    if beam != null:
        beam.visible = false
    collision_layer = 0
    collision_mask = 0
    reparent(holder)
    position = local_offset
    rotation = Vector3.ZERO
    picked.emit(letter)

func drop_at(pos: Vector3) -> void:
    carried = false
    if beam != null:
        beam.visible = true
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
