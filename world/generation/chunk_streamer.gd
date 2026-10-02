extends Node3D
class_name ChunkStreamer

signal chunk_loaded(coord: Vector2i, region: String)
signal chunk_unloaded(coord: Vector2i)

var player: AlphaCrushPlayer
var world_seed := 482913
var chunk_size := 48.0
var radius := 2
var loaded: Dictionary = {}
var generator: SeededGenerator
var catalog: RegionCatalog
var map_manager: MapManager
var max_new_chunks_per_frame := 2

func setup(p: AlphaCrushPlayer, seed_number: int, map: MapManager = null) -> void:
    player = p
    map_manager = map
    world_seed = seed_number
    generator = SeededGenerator.new(seed_number)
    catalog = preload("res://world/regions/region_catalog.gd").new()
    add_child(catalog)

func _process(_delta: float) -> void:
    if player == null or generator == null:
        return
    var cx := int(floor(player.global_position.x / chunk_size))
    var cz := int(floor(player.global_position.z / chunk_size))
    _discover_current_region(Vector2i(cx, cz))
    var pending: Array[Vector2i] = []
    for x in range(cx - radius, cx + radius + 1):
        for z in range(cz - radius, cz + radius + 1):
            var coord := Vector2i(x, z)
            if not loaded.has(coord):
                pending.append(coord)
    var center := Vector2i(cx, cz)
    pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        return (a - center).length_squared() < (b - center).length_squared()
    )
    var created := 0
    for coord in pending:
        if created >= max_new_chunks_per_frame:
            break
        _ensure_chunk(coord)
        created += 1
    var remove_list: Array[Vector2i] = []
    for key in loaded.keys():
        var c: Vector2i = key
        if abs(c.x - cx) > radius or abs(c.y - cz) > radius:
            remove_list.append(c)
    for coord in remove_list:
        var node: Node = loaded.get(coord)
        if is_instance_valid(node):
            node.queue_free()
        loaded.erase(coord)
        chunk_unloaded.emit(coord)

func _ensure_chunk(coord: Vector2i) -> void:
    if loaded.has(coord):
        return
    var chunk := Node3D.new()
    chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
    chunk.position = Vector3(coord.x * chunk_size, 0, coord.y * chunk_size)
    add_child(chunk)
    loaded[coord] = chunk
    var region := generator.region_for(coord.x, coord.y)
    if not _is_authored_village_chunk(coord):
        _build_terrain_chunk(chunk, coord, region)
    _decorate(chunk, coord)
    chunk_loaded.emit(coord, region)

func _is_authored_village_chunk(coord: Vector2i) -> bool:
    # The central four chunks are hand-authored for the starter village and
    # its first surrounding landmarks; procedural terrain begins beyond them.
    return coord.x >= -1 and coord.x <= 0 and coord.y >= -1 and coord.y <= 0

func _build_terrain_chunk(chunk: Node3D, coord: Vector2i, region: String) -> void:
    var resolution := 12
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var collision_faces := PackedVector3Array()
    for z in range(resolution):
        for x in range(resolution):
            var x0 := float(x) / float(resolution) * chunk_size
            var x1 := float(x + 1) / float(resolution) * chunk_size
            var z0 := float(z) / float(resolution) * chunk_size
            var z1 := float(z + 1) / float(resolution) * chunk_size
            var p00 := _terrain_vertex(coord, x0, z0)
            var p10 := _terrain_vertex(coord, x1, z0)
            var p01 := _terrain_vertex(coord, x0, z1)
            var p11 := _terrain_vertex(coord, x1, z1)
            # Godot treats CLOCKWISE (seen from the front) as the front face. Viewed from above
            # (+Y looking down, +X right, +Z toward the viewer) p00 -> p10 -> p11 is clockwise,
            # so the surface faces up: it is visible from above and the concave collision
            # faces catch a falling player. The previous order faced DOWN, which made the
            # procedural terrain invisible and let the player fall straight through it.
            for point in [p00, p10, p11, p00, p11, p01]:
                surface.add_vertex(point)
                collision_faces.append(point)
    surface.generate_normals()
    var terrain_mesh := surface.commit()
    var terrain := MeshInstance3D.new()
    terrain.name = "TerrainSurface"
    terrain.mesh = terrain_mesh
    terrain.material_override = _terrain_material(region)
    chunk.add_child(terrain)
    var body := StaticBody3D.new()
    body.name = "TerrainCollision"
    var collision := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(collision_faces)
    shape.backface_collision = true
    collision.shape = shape
    body.add_child(collision)
    chunk.add_child(body)

func _terrain_vertex(coord: Vector2i, local_x: float, local_z: float) -> Vector3:
    var world_x := float(coord.x) * chunk_size + local_x
    var world_z := float(coord.y) * chunk_size + local_z
    var height := maxf(0.08, generator.height_at(world_x, world_z) * 0.16 + 0.18)
    return Vector3(local_x, height, local_z)

func _terrain_material(region: String) -> Material:
    var material := StandardMaterial3D.new()
    material.roughness = 0.94
    match region:
        "forest": material.albedo_color = Color("#486f43")
        "orchard": material.albedo_color = Color("#719b4e")
        "riverlands": material.albedo_color = Color("#698b78")
        "farmland": material.albedo_color = Color("#9a855c")
        "caves": material.albedo_color = Color("#656d70")
        "coastal_town", "beach", "harbor": material.albedo_color = Color("#c4b48b")
        "mountain", "canyon": material.albedo_color = Color("#887565")
        "desert": material.albedo_color = Color("#b88958")
        "snow": material.albedo_color = Color("#d5e1e8")
        "wetlands": material.albedo_color = Color("#587d68")
        "ruins": material.albedo_color = Color("#70706d")
        "industrial": material.albedo_color = Color("#56606b")
        "futuristic_city": material.albedo_color = Color("#4e6e8f")
        "highlands": material.albedo_color = Color("#76905d")
        _: material.albedo_color = Color("#63864e")
    return material

func _discover_current_region(coord: Vector2i) -> void:
    if map_manager == null or generator == null:
        return
    var region_id := "region_%d_%d" % [coord.x, coord.y]
    if map_manager.discovered.has(region_id):
        return
    var region := generator.region_for(coord.x, coord.y)
    var world_pos := Vector3((coord.x + 0.5) * chunk_size, 0, (coord.y + 0.5) * chunk_size)
    map_manager.discover(region_id, world_pos, region.capitalize(), region)

func _decorate(chunk: Node3D, coord: Vector2i) -> void:
    var rng := generator.rng_for(coord.x, coord.y)
    var region := generator.region_for(coord.x, coord.y)
    var count := 8
    if region == "forest": count = 18
    elif region == "orchard": count = 14
    elif region == "caves": count = 4
    elif region == "riverlands": count = 10
    for i in range(count):
        var pos := Vector3(rng.randf_range(3.0, chunk_size - 3.0), 0.0, rng.randf_range(3.0, chunk_size - 3.0))
        var world_position := chunk.position + pos
        # Keep the authored starter village readable; streamed scenery begins outside it.
        if absf(world_position.x) < 48.0 and absf(world_position.z) < 48.0:
            continue
        if not _is_authored_village_chunk(coord):
            pos.y = _terrain_vertex(coord, pos.x, pos.z).y
        _spawn_region_prop(chunk, region, pos, rng)

func _spawn_region_prop(parent: Node3D, region: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
    var root := Node3D.new()
    root.position = pos
    parent.add_child(root)
    match region:
        "forest", "orchard": _make_tree(root, region, rng)
        "caves": _make_rock(root, rng)
        "riverlands": _make_reed(root, rng)
        "farmland": _make_crop(root, rng)
        "coastal_town", "harbor": _make_lamp(root)
        "mountain", "canyon": _make_rock(root, rng)
        "desert": _make_rock(root, rng)
        "snow": _make_snow_marker(root, rng)
        "wetlands": _make_reed(root, rng)
        "ruins", "industrial", "futuristic_city": _make_lamp(root)
        "highlands": _make_tree(root, "forest", rng)
        _ : _make_bush(root, rng)

func _make_tree(root: Node3D, region: String, rng: RandomNumberGenerator) -> void:
    var trunk := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.18
    cylinder.bottom_radius = 0.28
    cylinder.height = 2.0 + rng.randf_range(0, 0.7)
    trunk.mesh = cylinder
    trunk.position.y = cylinder.height * 0.5
    trunk.material_override = _material(Color("#76533a"))
    root.add_child(trunk)
    var crown := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.1 if region == "forest" else 1.0
    sphere.height = 2.0
    crown.mesh = sphere
    crown.position.y = cylinder.height + 0.6
    crown.material_override = _material(Color("#4f8d5b") if region == "forest" else Color("#78a84b"))
    root.add_child(crown)

func _make_rock(root: Node3D, rng: RandomNumberGenerator) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = rng.randf_range(0.4, 0.9)
    sphere.height = rng.randf_range(0.7, 1.5)
    mesh.mesh = sphere
    mesh.position.y = sphere.height * 0.45
    mesh.material_override = _material(Color("#68737e"))
    root.add_child(mesh)

func _make_reed(root: Node3D, rng: RandomNumberGenerator) -> void:
    for i in range(3):
        var mesh := MeshInstance3D.new()
        var c := CylinderMesh.new()
        c.top_radius = 0.025
        c.bottom_radius = 0.05
        c.height = rng.randf_range(0.8, 1.5)
        mesh.mesh = c
        mesh.position = Vector3(rng.randf_range(-0.35, 0.35), c.height * 0.5, rng.randf_range(-0.35, 0.35))
        mesh.material_override = _material(Color("#86a95b"))
        root.add_child(mesh)

func _make_crop(root: Node3D, rng: RandomNumberGenerator) -> void:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.3, rng.randf_range(0.4, 0.8), 0.3)
    mesh.mesh = box
    mesh.position.y = box.size.y * 0.5
    mesh.material_override = _material(Color("#c9b34a"))
    root.add_child(mesh)

func _make_snow_marker(root: Node3D, rng: RandomNumberGenerator) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = rng.randf_range(0.25, 0.6)
    sphere.height = sphere.radius * 1.6
    mesh.mesh = sphere
    mesh.position.y = sphere.height * 0.45
    mesh.material_override = _material(Color("#dcebf4"))
    root.add_child(mesh)

func _make_lamp(root: Node3D) -> void:
    var mesh := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.top_radius = 0.08
    c.bottom_radius = 0.1
    c.height = 2.2
    mesh.mesh = c
    mesh.position.y = 1.1
    mesh.material_override = _material(Color("#33404d"))
    root.add_child(mesh)

func _make_bush(root: Node3D, rng: RandomNumberGenerator) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = rng.randf_range(0.35, 0.65)
    sphere.height = 0.8
    mesh.mesh = sphere
    mesh.position.y = 0.4
    mesh.material_override = _material(Color("#547e52"))
    root.add_child(mesh)

func _material(c: Color) -> Material:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m
