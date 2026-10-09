extends RefCounted
class_name PropFactory

## Spawns generated models.  Material slots are matched by name (see MaterialLibrary) and nodes named
## COL_BOX_w_h_d / COL_CYL_r_h_0 / COL_SPH_r_squash_0 (centimetres / percent) become static collision.

const MODELS := "res://assets/models/"

static var _scene_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

static func has_model(id: String) -> bool:
    return scene(id) != null

static func scene(id: String) -> PackedScene:
    if _scene_cache.has(id):
        return _scene_cache[id]
    var packed: PackedScene = null
    var path := MODELS + id + ".glb"
    if ResourceLoader.exists(path):
        packed = load(path) as PackedScene
    _scene_cache[id] = packed
    return packed

## Returns null if the model is unavailable so callers can fall back to a simple placeholder.
static func spawn(id: String, with_collision: bool = true, shadows: bool = true) -> Node3D:
    var packed := scene(id)
    if packed == null:
        return null
    var root := packed.instantiate() as Node3D
    if root == null:
        return null
    root.name = id
    var markers: Array[Node3D] = []
    var meshes: Array[MeshInstance3D] = []
    _collect(root, markers, meshes)
    for mi in meshes:
        _apply_materials(mi)
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if with_collision and not markers.is_empty():
        var body := StaticBody3D.new()
        body.name = "Collision"
        for marker in markers:
            var cs := _shape_for(marker)
            if cs != null:
                body.add_child(cs)
        root.add_child(body)
    for marker in markers:
        if marker.get_parent() != null:
            marker.get_parent().remove_child(marker)
        marker.free()
    return root

## Shared mesh (materials applied) for MultiMesh scattering; null if the model is missing.
static func mesh_of(id: String) -> Mesh:
    if _mesh_cache.has(id):
        return _mesh_cache[id]
    var result: Mesh = null
    var packed := scene(id)
    if packed != null:
        var tmp := packed.instantiate()
        var markers: Array[Node3D] = []
        var meshes: Array[MeshInstance3D] = []
        _collect(tmp, markers, meshes)
        if not meshes.is_empty() and meshes[0].mesh != null:
            result = meshes[0].mesh.duplicate() as Mesh
            for i in range(result.get_surface_count()):
                var src := result.surface_get_material(i)
                if src != null and not src.resource_name.is_empty():
                    var m := MaterialLibrary.get_material(src.resource_name)
                    if m != null:
                        result.surface_set_material(i, m)
        tmp.free()
    _mesh_cache[id] = result
    return result

static func collision_marker_info(marker_name: String) -> Dictionary:
    var parts := marker_name.split("_")
    if parts.size() < 4 or parts[0] != "COL":
        return {}
    return {"kind": parts[1], "a": float(parts[2]) / 100.0, "b": float(parts[3]) / 100.0, "c": (float(parts[4]) / 100.0) if parts.size() > 4 else 0.0}

static func _collect(node: Node, markers: Array[Node3D], meshes: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and not meshes.has(node):
        meshes.append(node as MeshInstance3D)
    for child in node.get_children():
        if String(child.name).begins_with("COL_") and child is Node3D:
            markers.append(child as Node3D)
            continue
        if child is MeshInstance3D:
            meshes.append(child as MeshInstance3D)
        _collect(child, markers, meshes)

static func _apply_materials(mi: MeshInstance3D) -> void:
    var mesh := mi.mesh
    if mesh == null:
        return
    for i in range(mesh.get_surface_count()):
        var src := mesh.surface_get_material(i)
        if src == null or src.resource_name.is_empty():
            continue
        var m := MaterialLibrary.get_material(src.resource_name)
        if m != null:
            mi.set_surface_override_material(i, m)

static func _shape_for(marker: Node3D) -> CollisionShape3D:
    var info := collision_marker_info(String(marker.name))
    if info.is_empty():
        return null
    var cs := CollisionShape3D.new()
    cs.name = String(marker.name)
    match str(info["kind"]):
        "BOX":
            var box := BoxShape3D.new()
            box.size = Vector3(float(info["a"]), float(info["b"]), float(info["c"]))
            cs.shape = box
            cs.position = marker.position
        "CYL":
            var cyl := CylinderShape3D.new()
            cyl.radius = float(info["a"])
            cyl.height = float(info["b"])
            cs.shape = cyl
            cs.position = marker.position + Vector3(0.0, float(info["b"]) * 0.5, 0.0)
        "SPH":
            var sph := SphereShape3D.new()
            sph.radius = float(info["a"])
            cs.shape = sph
            cs.position = marker.position + Vector3(0.0, float(info["a"]) * float(info["b"]) * 0.8, 0.0)
        _:
            cs.free()
            return null
    return cs
