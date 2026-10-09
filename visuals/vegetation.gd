extends RefCounted
class_name Vegetation

## Region-driven scenery for streamed terrain chunks: trees / bushes / rocks as MultiMeshes (one draw call
## per model per chunk), a few collision shapes, plus grass tufts and flowers for chunks near the player.

const PROFILES := {
    "starter_village": {"trees": [["oak", 3], ["fruit", 2]], "tree": 3, "bush": 8, "rock": 2, "flowers": 1.0, "grass": 1.0},
    "forest": {"trees": [["oak", 4], ["pine", 6]], "tree": 24, "bush": 14, "rock": 3, "flowers": 0.35, "grass": 0.9, "tint": Color(0.82, 0.95, 0.78)},
    "orchard": {"trees": [["fruit", 8], ["oak", 2]], "tree": 14, "bush": 8, "rock": 1, "flowers": 1.6, "grass": 1.1, "tint": Color(1.05, 1.05, 0.82)},
    "riverlands": {"trees": [["oak", 1]], "tree": 7, "bush": 14, "rock": 7, "flowers": 0.8, "grass": 1.0, "tint": Color(0.9, 1.0, 0.88)},
    "farmland": {"trees": [["oak", 1]], "tree": 3, "bush": 4, "rock": 1, "flowers": 0.6, "grass": 0.8, "tint": Color(1.12, 1.04, 0.72)},
    "caves": {"trees": [["pine", 1]], "tree": 4, "bush": 2, "rock": 18, "flowers": 0.1, "grass": 0.4, "tint": Color(0.78, 0.86, 0.78)},
    "coastal_town": {"trees": [["oak", 1]], "tree": 4, "bush": 6, "rock": 5, "flowers": 0.5, "grass": 0.6, "sand": 0.55},
    "mountain": {"trees": [["pine", 1]], "tree": 8, "bush": 2, "rock": 22, "flowers": 0.05, "grass": 0.3, "tint": Color(0.82, 0.88, 0.82)},
    "beach": {"trees": [["oak", 1]], "tree": 1, "bush": 3, "rock": 4, "flowers": 0.1, "grass": 0.1, "sand": 0.95},
    "desert": {"trees": [], "tree": 0, "bush": 4, "rock": 14, "flowers": 0.0, "grass": 0.0, "sand": 1.0},
    "snow": {"trees": [["pine", 1]], "tree": 10, "bush": 1, "rock": 10, "flowers": 0.0, "grass": 0.0, "snow": 0.92},
    "wetlands": {"trees": [["oak", 1]], "tree": 5, "bush": 20, "rock": 2, "flowers": 1.2, "grass": 1.2, "tint": Color(0.72, 0.95, 0.78)},
    "canyon": {"trees": [["pine", 1]], "tree": 2, "bush": 2, "rock": 26, "flowers": 0.0, "grass": 0.2, "sand": 0.5, "tint": Color(1.25, 0.9, 0.7)},
    "ruins": {"trees": [["oak", 1]], "tree": 5, "bush": 10, "rock": 16, "flowers": 0.5, "grass": 0.8, "tint": Color(0.95, 1.0, 0.85)},
    "industrial": {"trees": [["oak", 1]], "tree": 2, "bush": 3, "rock": 8, "flowers": 0.1, "grass": 0.3},
    "futuristic_city": {"trees": [["oak", 1]], "tree": 3, "bush": 6, "rock": 3, "flowers": 0.4, "grass": 0.5},
    "harbor": {"trees": [["oak", 1]], "tree": 3, "bush": 4, "rock": 7, "flowers": 0.2, "grass": 0.4, "sand": 0.7},
    "highlands": {"trees": [["pine", 3], ["oak", 2]], "tree": 12, "bush": 6, "rock": 14, "flowers": 0.5, "grass": 0.8, "tint": Color(0.88, 0.98, 0.85)},
}
const TREE_IDS := {"oak": ["tree_oak_0", "tree_oak_1", "tree_oak_2"], "pine": ["tree_pine_0", "tree_pine_1"], "fruit": ["tree_fruit_0", "tree_fruit_1", "tree_fruit_2"]}
const BUSH_IDS := ["bush_0", "bush_1"]
const ROCK_IDS := ["rock_0", "rock_1", "rock_2", "rock_3"]
const ROCK_RADIUS := {"rock_0": 0.77, "rock_1": 1.28, "rock_2": 0.47, "rock_3": 2.04}

static var _material_cache: Dictionary = {}
static var _tuft_meshes: Dictionary = {}
static var _flower_mesh: ArrayMesh

static func profile(region: String) -> Dictionary:
    return PROFILES.get(region, PROFILES["starter_village"])

static func region_material(region: String) -> ShaderMaterial:
    if _material_cache.has(region):
        return _material_cache[region]
    var base := MaterialLibrary.terrain_material()
    var m := base.duplicate() as ShaderMaterial
    var p := profile(region)
    m.set_shader_parameter("grass_tint", p.get("tint", Color(1, 1, 1)))
    m.set_shader_parameter("sand_mix", float(p.get("sand", 0.0)))
    m.set_shader_parameter("snow_mix", float(p.get("snow", 0.0)))
    _material_cache[region] = m
    return m

static func is_blocked(x: float, z: float, exclusions: Array[Rect2]) -> bool:
    var pt := Vector2(x, z)
    for r in exclusions:
        if r.has_point(pt):
            return true
    return false

# ------------------------------------------------------------------ trees, bushes, rocks

static func decorate_chunk(chunk: Node3D, coord: Vector2i, chunk_size: float, generator: SeededGenerator, region: String, quality: Dictionary, exclusions: Array[Rect2], seed_value: int) -> void:
    var p := profile(region)
    var rng := generator.rng_for(coord.x, coord.y)
    var props_scale := float(quality.get("props", 1.0))
    var groups: Dictionary = {}
    var shapes: Array = []
    var origin := Vector2(float(coord.x) * chunk_size, float(coord.y) * chunk_size)
    var tree_kinds: Array = p["trees"]
    var weights := 0
    for entry in tree_kinds:
        weights += int(entry[1])
    _scatter(groups, shapes, rng, origin, chunk_size, int(round(float(p["tree"]) * props_scale)), exclusions, seed_value, 0.80, 0.85, 1.3, "tree", tree_kinds, weights)
    _scatter(groups, shapes, rng, origin, chunk_size, int(round(float(p["bush"]) * props_scale)), exclusions, seed_value, 0.78, 0.8, 1.4, "bush", tree_kinds, weights)
    _scatter(groups, shapes, rng, origin, chunk_size, int(round(float(p["rock"]) * props_scale)), exclusions, seed_value, 0.70, 0.8, 1.5, "rock", tree_kinds, weights)
    var tree_shadows := bool(quality.get("tree_shadows", false))
    for id in groups.keys():
        var kind_is_tree := str(id).begins_with("tree_")
        _add_multimesh(chunk, str(id), groups[id], tree_shadows if kind_is_tree else false, 170.0 if kind_is_tree else 120.0)
    if not shapes.is_empty():
        var body := StaticBody3D.new()
        body.name = "Colliders"
        for spec in shapes:
            var cs := CollisionShape3D.new()
            cs.shape = spec["shape"]
            cs.position = spec["pos"]
            body.add_child(cs)
        chunk.add_child(body)

static func _pick_id(kind: String, rng: RandomNumberGenerator, tree_kinds: Array, weights: int) -> String:
    if kind == "bush":
        return str(BUSH_IDS[rng.randi() % BUSH_IDS.size()])
    if kind == "rock":
        return str(ROCK_IDS[rng.randi() % ROCK_IDS.size()])
    var roll := rng.randi() % maxi(weights, 1)
    for entry in tree_kinds:
        roll -= int(entry[1])
        if roll < 0:
            var ids: Array = TREE_IDS[str(entry[0])]
            return str(ids[rng.randi() % ids.size()])
    return ""

static func _scatter(groups: Dictionary, shapes: Array, rng: RandomNumberGenerator, origin: Vector2, size: float, count: int, exclusions: Array[Rect2], seed_value: int, min_up: float, scale_lo: float, scale_hi: float, kind: String, tree_kinds: Array, weights: int) -> void:
    for i in range(count):
        var lx := rng.randf_range(3.0, size - 3.0)
        var lz := rng.randf_range(3.0, size - 3.0)
        var wx := origin.x + lx
        var wz := origin.y + lz
        var yaw := rng.randf() * TAU
        var sc := rng.randf_range(scale_lo, scale_hi)
        var id := _pick_id(kind, rng, tree_kinds, weights)
        if id == "":
            continue
        if absf(wx) < 48.0 and absf(wz) < 48.0:
            continue
        if is_blocked(wx, wz, exclusions):
            continue
        var h := TerrainField.height_at(wx, wz, seed_value)
        if h < -0.25 or TerrainField.normal_at(wx, wz, seed_value).y < min_up:
            continue
        var basis := Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc))
        var xf := Transform3D(basis, Vector3(lx, h - 0.04, lz))
        if not groups.has(id):
            groups[id] = [] as Array[Transform3D]
        (groups[id] as Array[Transform3D]).append(xf)
        if kind == "tree":
            var cyl := CylinderShape3D.new()
            cyl.radius = 0.32 * sc
            cyl.height = 4.0
            shapes.append({"shape": cyl, "pos": Vector3(lx, h + 2.0, lz)})
        elif kind == "rock":
            var sph := SphereShape3D.new()
            sph.radius = float(ROCK_RADIUS.get(id, 0.8)) * sc
            shapes.append({"shape": sph, "pos": Vector3(lx, h + sph.radius * 0.6, lz)})

static func _add_multimesh(parent: Node3D, id: String, xforms: Array, shadows: bool, range_end: float) -> void:
    var mesh := PropFactory.mesh_of(id)
    if mesh == null or xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in range(xforms.size()):
        mm.set_instance_transform(i, xforms[i])
    var inst := MultiMeshInstance3D.new()
    inst.name = "MM_" + id
    inst.multimesh = mm
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    inst.visibility_range_end = range_end
    inst.visibility_range_end_margin = 12.0
    parent.add_child(inst)

# ------------------------------------------------------------------ grass & flowers

static func _tuft_mesh(width: float, height: float) -> ArrayMesh:
    var key := "%s_%s" % [width, height]
    if _tuft_meshes.has(key):
        return _tuft_meshes[key]
    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for q in range(3):
        var ang := float(q) * PI / 3.0
        var dx := cos(ang) * width * 0.5
        var dz := sin(ang) * width * 0.5
        var base := verts.size()
        verts.append_array(PackedVector3Array([Vector3(-dx, 0, -dz), Vector3(dx, 0, dz), Vector3(dx, height, dz), Vector3(-dx, height, -dz)]))
        uvs.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
        colors.append_array(PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1)]))
        normals.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
        indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    _tuft_meshes[key] = mesh
    return mesh

## Grass + flowers for one chunk.  Returns null when the region/quality has none.
static func build_grass(coord: Vector2i, chunk_size: float, region: String, quality: Dictionary, exclusions: Array[Rect2], seed_value: int) -> Node3D:
    var p := profile(region)
    var density := float(p.get("grass", 0.8)) * float(quality.get("grass", 1.0))
    if density <= 0.02 or MaterialLibrary.grass_material("grass").shader == null:
        return null
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(Vector3i(coord.x, coord.y, 77)) ^ seed_value
    var origin := Vector2(float(coord.x) * chunk_size, float(coord.y) * chunk_size)
    var root := Node3D.new()
    root.name = "Grass"
    root.position = Vector3(origin.x, 0.0, origin.y)
    var want := int(chunk_size * chunk_size * 0.20 * density)
    var tufts: Array[Transform3D] = []
    var cells: Array[float] = []
    var tries := 0
    while tufts.size() < want and tries < want * 2:
        tries += 1
        var lx := rng.randf() * chunk_size
        var lz := rng.randf() * chunk_size
        var wx := origin.x + lx
        var wz := origin.y + lz
        if is_blocked(wx, wz, exclusions):
            continue
        var h := TerrainField.height_at(wx, wz, seed_value)
        if h < -0.12 or absf(TerrainField.height_at(wx + 1.0, wz, seed_value) - h) > 0.9 or absf(TerrainField.height_at(wx, wz + 1.0, seed_value) - h) > 0.9:
            continue
        var sc := rng.randf_range(0.8, 1.45)
        tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), Vector3(lx, h - 0.02, lz)))
        cells.append(0.5 if rng.randf() < 0.14 else 0.0)
    if not tufts.is_empty():
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_custom_data = true
        mm.mesh = _tuft_mesh(0.95, 0.75)
        mm.instance_count = tufts.size()
        for i in range(tufts.size()):
            mm.set_instance_transform(i, tufts[i])
            mm.set_instance_custom_data(i, Color(cells[i], 0.0, 0.0, 0.0))
        var inst := MultiMeshInstance3D.new()
        inst.name = "Tufts"
        inst.multimesh = mm
        inst.material_override = MaterialLibrary.grass_material("grass")
        inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(inst)
    var flower_target := int(chunk_size * chunk_size * 0.010 * float(p.get("flowers", 0.5)) * float(quality.get("grass", 1.0)))
    if flower_target > 0:
        var flowers: Array[Transform3D] = []
        var fcells: Array[Vector2] = []
        var clusters := maxi(1, flower_target / 9)
        for c in range(clusters):
            var cx := rng.randf_range(3.0, chunk_size - 3.0)
            var cz := rng.randf_range(3.0, chunk_size - 3.0)
            var kind := rng.randi() % 4
            for k in range(9):
                var lx := cx + rng.randf_range(-1.8, 1.8)
                var lz := cz + rng.randf_range(-1.8, 1.8)
                var wx := origin.x + lx
                var wz := origin.y + lz
                if lx < 0.0 or lz < 0.0 or lx > chunk_size or lz > chunk_size or is_blocked(wx, wz, exclusions):
                    continue
                var h := TerrainField.height_at(wx, wz, seed_value)
                if h < -0.1:
                    continue
                var sc := rng.randf_range(0.7, 1.15)
                flowers.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(lx, h - 0.02, lz)))
                var which := kind if rng.randf() < 0.8 else rng.randi() % 4
                fcells.append(Vector2(0.5 * float(which % 2), 0.5 * float(which >> 1)))
        if not flowers.is_empty():
            var fm := MultiMesh.new()
            fm.transform_format = MultiMesh.TRANSFORM_3D
            fm.use_custom_data = true
            fm.mesh = _tuft_mesh(0.55, 0.62)
            fm.instance_count = flowers.size()
            for i in range(flowers.size()):
                fm.set_instance_transform(i, flowers[i])
                fm.set_instance_custom_data(i, Color(fcells[i].x, fcells[i].y, 0.0, 0.0))
            var finst := MultiMeshInstance3D.new()
            finst.name = "Flowers"
            finst.multimesh = fm
            finst.material_override = MaterialLibrary.grass_material("flowers")
            finst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            root.add_child(finst)
    if root.get_child_count() == 0:
        root.free()
        return null
    return root
