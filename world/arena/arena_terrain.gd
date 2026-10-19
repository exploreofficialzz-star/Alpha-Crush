extends RefCounted
class_name ArenaTerrain

## The battlefield ground: an almost flat fighting floor (gentle swells only) ringed by hills that act as a natural wall.
## Same triangle winding as TerrainField (clockwise seen from above, which is Godot's front face).
const PLAY_RADIUS := 62.0
const RIM_WIDTH := 28.0
const EXTENT := 112.0
const STEP := 4.0

static var _noise: FastNoiseLite
static var _noise_seed := -2147483648

static func _field(seed_value: int) -> FastNoiseLite:
    if _noise == null or _noise_seed != seed_value:
        _noise = FastNoiseLite.new()
        _noise.seed = seed_value
        _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
        _noise.frequency = 0.035
        _noise.fractal_type = FastNoiseLite.FRACTAL_FBM
        _noise.fractal_octaves = 3
        _noise_seed = seed_value
    return _noise

static func height_at(x: float, z: float, center: Vector3, hills: float, seed_value: int) -> float:
    var dx := x - center.x
    var dz := z - center.z
    var distance := sqrt(dx * dx + dz * dz)
    var n := _field(seed_value).get_noise_2d(x, z)
    var rim := smoothstep(PLAY_RADIUS - 8.0, PLAY_RADIUS + RIM_WIDTH, distance)
    var floor_part := n * 0.30 * (1.0 - rim)
    var hill_part := hills * (0.55 + 0.45 * (n * 0.5 + 0.5)) * rim
    return center.y + floor_part + hill_part

static func normal_at(x: float, z: float, center: Vector3, hills: float, seed_value: int) -> Vector3:
    var e := 0.8
    var hl := height_at(x - e, z, center, hills, seed_value)
    var hr := height_at(x + e, z, center, hills, seed_value)
    var hd := height_at(x, z - e, center, hills, seed_value)
    var hu := height_at(x, z + e, center, hills, seed_value)
    return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

## Mesh + collision faces for a square patch centred on `center`. The patch's local origin is its south-west corner.
static func build_patch(center: Vector3, hills: float, seed_value: int, ground_material: Material) -> Dictionary:
    var x0 := center.x - EXTENT
    var z0 := center.z - EXTENT
    var cells := int(round(EXTENT * 2.0 / STEP))
    var stride := cells + 1
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    verts.resize(stride * stride)
    normals.resize(stride * stride)
    uvs.resize(stride * stride)
    for j in range(stride):
        for i in range(stride):
            var wx := x0 + float(i) * STEP
            var wz := z0 + float(j) * STEP
            var index := j * stride + i
            verts[index] = Vector3(float(i) * STEP, height_at(wx, wz, center, hills, seed_value), float(j) * STEP)
            normals[index] = normal_at(wx, wz, center, hills, seed_value)
            uvs[index] = Vector2(wx, wz) * 0.1
    var indices := PackedInt32Array()
    var faces := PackedVector3Array()
    for j in range(cells):
        for i in range(cells):
            var p00 := j * stride + i
            var p10 := p00 + 1
            var p01 := p00 + stride
            var p11 := p01 + 1
            indices.append_array(PackedInt32Array([p00, p10, p11, p00, p11, p01]))
            faces.append_array(PackedVector3Array([verts[p00], verts[p10], verts[p11], verts[p00], verts[p11], verts[p01]]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh.surface_set_material(0, ground_material)
    return {"mesh": mesh, "faces": faces, "origin": Vector3(x0, 0.0, z0)}
