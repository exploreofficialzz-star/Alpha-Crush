extends RefCounted
class_name TerrainField

## Single source of truth for the ground height.  The authored village is perfectly flat (everything
## in the game was placed at y = 0), rolling hills fade in beyond it, and the river bed is carved
## into the village so the water plane sits in a real channel.

const FLAT_RADIUS := 54.0
const BLEND_WIDTH := 80.0
const RIVER_RECT := Rect2(-48.0, -23.0, 42.0, 10.0)
const RIVER_DEPTH := 0.55
# dry ravine the repairable footbridge crosses (x -52..-22, z -33..-27)
const RAVINE_RECT := Rect2(-52.0, -33.0, 30.0, 6.0)
const RAVINE_DEPTH := 2.0
const WATER_LEVEL := -0.12

static var _noise: FastNoiseLite
static var _noise_seed := -2147483648

static func _field(seed_value: int) -> FastNoiseLite:
    if _noise == null or _noise_seed != seed_value:
        var n := FastNoiseLite.new()
        n.seed = seed_value
        n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
        n.fractal_type = FastNoiseLite.FRACTAL_FBM
        n.fractal_octaves = 4
        n.frequency = 0.006
        _noise = n
        _noise_seed = seed_value
    return _noise

static func height_at(x: float, z: float, seed_value: int = 482913) -> float:
    var dist := maxf(absf(x), absf(z))
    var blend := smoothstep(FLAT_RADIUS, FLAT_RADIUS + BLEND_WIDTH, dist)
    var h := 0.0
    if blend > 0.0:
        var n := _field(seed_value).get_noise_2d(x, z)
        var amp := 4.0 + 16.0 * clampf((dist - FLAT_RADIUS) / 300.0, 0.0, 1.0)
        h = (n * 0.5 + 0.5) * amp * blend
    return h + _river_carve(x, z) + _ravine_carve(x, z)

static func _river_carve(x: float, z: float) -> float:
    var inside := minf(minf(x - RIVER_RECT.position.x, RIVER_RECT.end.x - x), minf(z - RIVER_RECT.position.y, RIVER_RECT.end.y - z))
    if inside <= 0.0:
        return 0.0
    return -RIVER_DEPTH * smoothstep(0.0, 3.5, inside)

static func _ravine_carve(x: float, z: float) -> float:
    var inside := minf(minf(x - RAVINE_RECT.position.x, RAVINE_RECT.end.x - x), minf(z - RAVINE_RECT.position.y, RAVINE_RECT.end.y - z))
    if inside <= 0.0:
        return 0.0
    # V-shaped, ~34 degree walls: steep enough to read as a ravine, shallow enough to climb out of
    return -RAVINE_DEPTH * smoothstep(0.0, 3.2, inside)

static func normal_at(x: float, z: float, seed_value: int = 482913) -> Vector3:
    var e := 0.6
    var hl := height_at(x - e, z, seed_value)
    var hr := height_at(x + e, z, seed_value)
    var hd := height_at(x, z - e, seed_value)
    var hu := height_at(x, z + e, seed_value)
    return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

## Builds a terrain patch whose local origin is (x0, 0, z0).  Triangles are clockwise seen from above
## (Godot's front-face convention), so the surface is visible and solid from above.
static func build_patch(x0: float, z0: float, size: float, step: float, seed_value: int = 482913) -> Dictionary:
    var cells := maxi(1, int(round(size / step)))
    var stride := cells + 1
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    verts.resize(stride * stride)
    normals.resize(stride * stride)
    uvs.resize(stride * stride)
    for j in range(stride):
        for i in range(stride):
            var wx := x0 + float(i) * step
            var wz := z0 + float(j) * step
            var idx := j * stride + i
            verts[idx] = Vector3(float(i) * step, height_at(wx, wz, seed_value), float(j) * step)
            normals[idx] = normal_at(wx, wz, seed_value)
            uvs[idx] = Vector2(wx, wz) * 0.1
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
    mesh.surface_set_material(0, MaterialLibrary.terrain_material())
    return {"mesh": mesh, "faces": faces}

static func make_body(patch: Dictionary, body_name: String = "Terrain") -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = body_name
    var mi := MeshInstance3D.new()
    mi.name = "Mesh"
    mi.mesh = patch["mesh"]
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.add_child(mi)
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(patch["faces"])
    shape.backface_collision = true
    var cs := CollisionShape3D.new()
    cs.name = "Shape"
    cs.shape = shape
    body.add_child(cs)
    return body
