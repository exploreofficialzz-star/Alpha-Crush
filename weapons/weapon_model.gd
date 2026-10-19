extends RefCounted
class_name WeaponModel

## Builds a stylised gun from boxes and tubes (no imported art, so it can never fail to load and costs a handful of
## draw calls). The model's origin is the hand position, the barrel points down -Z, and a Marker3D called "Muzzle"
## marks where bullets and flashes start.
static var _materials: Dictionary = {}

static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var key := "%s_%.2f_%.2f" % [color.to_html(), metallic, roughness]
    if _materials.has(key):
        return _materials[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    _materials[key] = material
    return material

static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, node_name: String = "") -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if node_name != "":
        instance.name = node_name
    parent.add_child(instance)
    return instance

## A cylinder lying along the Z axis, centred at (0, y, z).
static func _tube(parent: Node3D, radius: float, length: float, y: float, z: float, material: Material, node_name: String = "") -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 8
    mesh.rings = 1
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    instance.position = Vector3(0.0, y, z)
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if node_name != "":
        instance.name = node_name
    parent.add_child(instance)
    return instance

static func build(id: String) -> Node3D:
    var root := Node3D.new()
    root.name = "Gun_" + id
    var data := WeaponCatalog.get_weapon(id)
    var muzzle := Marker3D.new()
    muzzle.name = "Muzzle"
    root.add_child(muzzle)
    if data.is_empty():
        return root
    var spec: Dictionary = data.get("model", {})
    var kind := str(data.get("kind", "pistol"))
    var length := float(spec.get("length", 0.3))
    var height := float(spec.get("height", 0.15))
    var barrel := float(spec.get("barrel", 0.1))
    var stock := float(spec.get("stock", 0.0))
    var mag_height := float(spec.get("mag", 0.0))
    var has_scope := bool(spec.get("scope", false))
    var base_color: Color = spec.get("color", Color(0.2, 0.2, 0.22))
    var accent_color: Color = spec.get("accent", Color(0.9, 0.6, 0.2))
    var dark := _mat(base_color, 0.55, 0.45)
    var accent := _mat(accent_color, 0.2, 0.5)
    var grip_material := _mat(base_color.darkened(0.35), 0.1, 0.8)
    if kind == "launcher":
        _build_launcher(root, muzzle, length, height, base_color, accent_color)
        return root
    var body_z := -length * 0.5 + 0.08
    _box(root, Vector3(0.055, height, length), Vector3(0.0, 0.0, body_z), dark, "Receiver")
    _box(root, Vector3(0.058, height * 0.28, length * 0.5), Vector3(0.0, height * 0.14, body_z - length * 0.05), accent, "Stripe")
    var barrel_radius := 0.024 if kind == "shotgun" else 0.017
    if barrel > 0.0:
        _tube(root, barrel_radius, barrel, height * 0.14, -(length - 0.08) - barrel * 0.5, dark, "Barrel")
    var grip := _box(root, Vector3(0.045, 0.12, 0.05), Vector3(0.0, -height * 0.5 - 0.04, 0.04), grip_material, "Grip")
    grip.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
    if stock > 0.0:
        _box(root, Vector3(0.04, height * 0.9, stock), Vector3(0.0, -height * 0.08, 0.08 + stock * 0.5), grip_material, "Stock")
    if mag_height > 0.0:
        _box(root, Vector3(0.04, mag_height, 0.055), Vector3(0.0, -height * 0.5 - mag_height * 0.5, -length * 0.42), grip_material, "Magazine")
    if has_scope:
        _tube(root, 0.022, 0.18, height * 0.5 + 0.04, body_z - 0.02, dark, "Scope")
        _tube(root, 0.016, 0.19, height * 0.5 + 0.04, body_z - 0.02, accent, "ScopeGlass")
    _box(root, Vector3(0.012, 0.03, 0.02), Vector3(0.0, height * 0.5 + 0.015, -(length - 0.08) - barrel), dark, "FrontSight")
    muzzle.position = Vector3(0.0, height * 0.14, -(length - 0.08) - barrel - 0.02)
    return root

static func _build_launcher(root: Node3D, muzzle: Marker3D, length: float, height: float, base_color: Color, accent_color: Color) -> void:
    var dark := _mat(base_color, 0.4, 0.55)
    var accent := _mat(accent_color, 0.2, 0.5)
    var grip_material := _mat(base_color.darkened(0.4), 0.1, 0.8)
    var tube_radius := height * 0.34
    _tube(root, tube_radius, length, 0.02, -length * 0.5 + 0.18, dark, "Tube")
    _tube(root, tube_radius * 1.25, 0.12, 0.02, -length + 0.16, accent, "Muzzle_Ring")
    _tube(root, tube_radius * 1.18, 0.10, 0.02, 0.22, accent, "Rear_Ring")
    var grip := _box(root, Vector3(0.05, 0.13, 0.06), Vector3(0.0, -0.12, -0.05), grip_material, "Grip")
    grip.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
    _box(root, Vector3(0.04, 0.08, 0.16), Vector3(0.0, tube_radius + 0.05, -length * 0.35), grip_material, "Sight")
    muzzle.position = Vector3(0.0, 0.02, -length + 0.12)
