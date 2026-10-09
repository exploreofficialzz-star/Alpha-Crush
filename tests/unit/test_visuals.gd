extends RefCounted
class_name TestVisuals

## Engine-side checks for the realism layer. They deliberately avoid loading GLB models so they
## also pass on a fresh clone; the models/textures themselves are validated by tests/asset_audit.py.

static func run() -> bool:
    return _terrain() and _terrain_patch() and _sun() and _markers() and _vegetation_profiles() and _outfits() and _materials()

static func _terrain() -> bool:
    # village stays flat (everything was authored at y = 0), the river and the ravine are carved, hills only rise
    if absf(TerrainField.height_at(0.0, 0.0)) > 0.0001 or absf(TerrainField.height_at(20.0, 20.0)) > 0.0001:
        return false
    if TerrainField.height_at(-27.0, -18.0) > -0.5 or absf(TerrainField.height_at(-27.0, -24.5)) > 0.0001:
        return false
    if TerrainField.height_at(-37.0, -30.0) > -1.5:
        return false
    for p in [Vector2(120, 120), Vector2(-300, 40), Vector2(75, -210)]:
        var h := TerrainField.height_at(p.x, p.y)
        if h < 0.0 or h > 21.0:
            return false
    return TerrainField.normal_at(10.0, 10.0).y > 0.999

static func _terrain_patch() -> bool:
    # Regression: the old chunk triangles were wound clockwise seen from BELOW, so the ground was invisible and not solid.
    var patch := TerrainField.build_patch(96.0, 96.0, 24.0, 3.0)
    var faces: PackedVector3Array = patch["faces"]
    if faces.size() != 8 * 8 * 6:
        return false
    for i in range(0, faces.size(), 3):
        var n := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
        # Godot front faces are clockwise: for a clockwise triangle seen from above the cross product points DOWN (-Y)
        # in a right-handed system, so the (CW) winding must produce a negative y here.
        if n.y >= 0.0:
            return false
    return true

static func _sun() -> bool:
    var noon := Atmosphere.sun_direction(0.45)
    var midnight := Atmosphere.sun_direction(0.915)
    if noon.y < 0.8 or midnight.y > -0.5:
        return false
    # the day/night cycle wraps seamlessly
    if (Atmosphere.sun_direction(0.0) - Atmosphere.sun_direction(1.0)).length() > 0.0001:
        return false
    # sun rises in the east and sets in the west
    return Atmosphere.sun_direction(0.0).x > 0.9 and Atmosphere.sun_direction(0.87).x < -0.9

static func _markers() -> bool:
    var box := PropFactory.collision_marker_info("COL_BOX_540_400_440")
    var cyl := PropFactory.collision_marker_info("COL_CYL_32_400_0")
    var stepped := PropFactory.collision_marker_info("COL_BOX_260_40_48_3")
    if box.is_empty() or str(box["kind"]) != "BOX" or not is_equal_approx(float(box["a"]), 5.4) or not is_equal_approx(float(box["c"]), 4.4):
        return false
    if cyl.is_empty() or str(cyl["kind"]) != "CYL" or not is_equal_approx(float(cyl["b"]), 4.0):
        return false
    return not stepped.is_empty() and PropFactory.collision_marker_info("Hips").is_empty()

static func _vegetation_profiles() -> bool:
    for region in SeededGenerator.REGION_TYPES:
        if not Vegetation.PROFILES.has(str(region)):
            return false
    return Vegetation.is_blocked(5.0, 5.0, [Rect2(0, 0, 10, 10)] as Array[Rect2]) and not Vegetation.is_blocked(50.0, 5.0, [Rect2(0, 0, 10, 10)] as Array[Rect2])

static func _outfits() -> bool:
    var a := AvatarRig.outfit_for("farmer", 5)
    var b := AvatarRig.outfit_for("farmer", 5)
    var c := AvatarRig.outfit_for("builder", 5)
    if a["skin"] != b["skin"] or a["hair"] != b["hair"] or str(a["hat"]) != "straw" or str(c["hat"]) != "hard":
        return false
    return a["shirt"] != c["shirt"] and bool(AvatarRig.outfit_for("explorer", 1)["pack"])

static func _materials() -> bool:
    var red := MaterialLibrary.get_material("paint_red")
    var unknown := MaterialLibrary.get_material("this_material_does_not_exist")
    var glass := MaterialLibrary.get_material("glass_window") as StandardMaterial3D
    if red == null or unknown == null or glass == null:
        return false
    # lamps and lit windows follow the time of day
    MaterialLibrary.set_night_amount(1.0)
    var lit: bool = glass.emission_energy_multiplier > 1.0
    MaterialLibrary.set_night_amount(0.0)
    return lit and glass.emission_energy_multiplier < 0.01
