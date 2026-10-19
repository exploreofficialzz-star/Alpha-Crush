extends RefCounted
class_name VillageArt

## Builds the starter village from the generated models.  Every function mirrors one of the old
## primitive-box builders in world.gd, keeps its node names (the story code finds nodes by name) and
## returns false when the model is missing so the caller can fall back to the old placeholder.

static var exclusions: Array[Rect2] = []

static func place(w: Node3D, id: String, pos: Vector3, yaw_deg: float = 0.0, node_name: String = "", collision: bool = true) -> Node3D:
    var node := PropFactory.spawn(id, collision, true)
    if node == null:
        return null
    if node_name != "":
        node.name = node_name
    node.position = pos
    node.rotation_degrees.y = yaw_deg
    w.add_child(node)
    return node

static func _label(w: Node3D, pos: Vector3, text_value: String, label_name: String = "") -> Label3D:
    var label: Label3D = w.call("_label", pos, text_value)
    if label_name != "":
        label.name = label_name
    return label

static func _wood(uv_scale: Vector3) -> StandardMaterial3D:
    var m := (MaterialLibrary.get_material("wood_planks") as StandardMaterial3D).duplicate() as StandardMaterial3D
    m.uv1_scale = uv_scale
    return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, box_name: String = "") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = mat
    if box_name != "":
        mi.name = box_name
    parent.add_child(mi)
    return mi

static func _block(rect: Rect2, margin: float = 1.5) -> void:
    exclusions.append(rect.grow(margin))

# ---------------------------------------------------------------- ground, water, paths

static func ground(w: Node3D, seed_value: int) -> bool:
    if MaterialLibrary.terrain_material().shader == null:
        return false
    exclusions.clear()
    var patch := TerrainField.build_patch(-48.0, -48.0, 96.0, 3.0, seed_value)
    var body := TerrainField.make_body(patch, "Ground")
    body.position = Vector3(-48.0, 0.0, -48.0)
    w.add_child(body)
    var water := MeshInstance3D.new()
    water.name = "RiverWater"
    var plane := PlaneMesh.new()
    plane.size = Vector2(TerrainField.RIVER_RECT.size.x, TerrainField.RIVER_RECT.size.y)
    plane.subdivide_width = 42
    plane.subdivide_depth = 10
    water.mesh = plane
    var c := TerrainField.RIVER_RECT.get_center()
    water.position = Vector3(c.x, TerrainField.WATER_LEVEL, c.y)
    water.material_override = MaterialLibrary.water_material()
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    w.add_child(water)
    _block(TerrainField.RIVER_RECT, 0.5)
    _block(TerrainField.RAVINE_RECT, 0.5)
    return true

static func path(w: Node3D, pos: Vector3, length: float, node_name: String = "Path") -> bool:
    if MaterialLibrary.terrain_material().shader == null:
        return false
    var half_w := 1.7
    var xs := [-half_w, -half_w * 0.72, 0.0, half_w * 0.72, half_w]
    var alphas := [0.0, 1.0, 1.0, 1.0, 0.0]
    var segs := maxi(2, int(ceil(length / 2.0)))
    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for j in range(segs + 1):
        var z := -length * 0.5 + length * float(j) / float(segs)
        for i in range(xs.size()):
            var x: float = xs[i]
            verts.append(Vector3(x, 0.035, z))
            uvs.append(Vector2((pos.x + x) * 0.5, (pos.z + z) * 0.5))
            colors.append(Color(1, 1, 1, alphas[i]))
            normals.append(Vector3.UP)
    var stride := xs.size()
    for j in range(segs):
        for i in range(stride - 1):
            var a := j * stride + i
            var b := a + 1
            var c := a + stride
            var d := c + 1
            indices.append_array(PackedInt32Array([a, c, d, a, d, b]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mat := (MaterialLibrary.get_material("dirt") as StandardMaterial3D).duplicate() as StandardMaterial3D
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0, mat)
    var mi := MeshInstance3D.new()
    mi.name = node_name
    mi.mesh = mesh
    mi.position = Vector3(pos.x, 0.0, pos.z)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    w.add_child(mi)
    _block(Rect2(pos.x - half_w, pos.z - length * 0.5, half_w * 2.0, length), 0.4)
    return true

# ---------------------------------------------------------------- main buildings

static func home(w: Node3D, pos: Vector3) -> bool:
    if place(w, "house_cottage", pos, 180.0, "HOME") == null:
        return false
    _block(Rect2(pos.x - 3.4, pos.z - 3.0, 6.8, 6.0), 1.0)
    _label(w, pos + Vector3(0, 5.6, 0), "HOME")
    return true

static func market(w: Node3D, pos: Vector3) -> bool:
    if place(w, "market_hall", pos, -90.0, "MARKET") == null:
        return false
    _block(Rect2(pos.x - 3.4, pos.z - 3.8, 6.8, 7.6), 1.0)
    _label(w, pos + Vector3(0, 4.9, 0), "CLOSED MARKET  •  REQUIRES OPEN", "ClosedMarketLabel")
    var shutter := Node3D.new()
    shutter.name = "MarketShutter"
    shutter.position = pos + Vector3(1.55, 0.0, 0.0)
    w.add_child(shutter)
    var wood := _wood(Vector3(2.0, 1.0, 1.0))
    _box(shutter, Vector3(0.14, 2.35, 5.4), Vector3(0, 1.45, 0), wood)
    _box(shutter, Vector3(0.2, 0.16, 5.6), Vector3(0.02, 2.7, 0), wood)
    _box(shutter, Vector3(0.18, 2.5, 0.16), Vector3(0.04, 1.5, -2.2), wood)
    _box(shutter, Vector3(0.18, 2.5, 0.16), Vector3(0.04, 1.5, 2.2), wood)
    var lock_mat := MaterialLibrary.get_material("iron")
    _box(shutter, Vector3(0.12, 0.28, 0.2), Vector3(0.12, 1.4, 0.0), lock_mat)
    return true

static func garden(w: Node3D, pos: Vector3) -> bool:
    if place(w, "garden_bed", pos, 0.0, "GARDEN") == null:
        return false
    _block(Rect2(pos.x - 5.2, pos.z - 4.2, 10.4, 8.4), 0.5)
    return true

static func workshop(w: Node3D, pos: Vector3) -> bool:
    if place(w, "workshop_shed", pos, 90.0, "WORKSHOP") == null:
        return false
    _block(Rect2(pos.x - 3.0, pos.z - 3.6, 6.0, 7.2), 1.0)
    _label(w, pos + Vector3(0, 4.9, 0), "BROKEN WORKSHOP  •  REQUIRES TOOLS", "BrokenWorkshopLabel")
    var boards := Node3D.new()
    boards.name = "BrokenWorkshopBoard"
    boards.position = pos + Vector3(-2.15, 1.35, 0.0)
    w.add_child(boards)
    var wood := _wood(Vector3(2.0, 1.0, 1.0))
    var b1 := _box(boards, Vector3(0.12, 0.26, 3.2), Vector3.ZERO, wood)
    b1.rotation_degrees.x = 24.0
    var b2 := _box(boards, Vector3(0.12, 0.26, 3.2), Vector3(0.02, -0.35, 0.0), wood)
    b2.rotation_degrees.x = -30.0
    return true

static func community_hall(w: Node3D, pos: Vector3) -> bool:
    if place(w, "community_hall", pos, 180.0, "COMMUNITY_HALL") == null:
        return false
    _block(Rect2(pos.x - 4.2, pos.z - 3.4, 8.4, 6.8), 1.5)
    _label(w, pos + Vector3(0, 7.6, 0), "COMMUNITY HALL")
    return true

static func storage(w: Node3D, pos: Vector3) -> bool:
    var hut := place(w, "storage_hut", pos, -90.0, "LockedStorage")
    if hut == null:
        return false
    _block(Rect2(pos.x - 2.2, pos.z - 2.2, 4.4, 4.4), 1.0)
    var lock := Node3D.new()
    lock.name = "Lock"
    lock.position = Vector3(0.4, 1.3, -1.78)
    hut.add_child(lock)
    var gold := StandardMaterial3D.new()
    gold.albedo_color = Color(0.83, 0.68, 0.22)
    gold.metallic = 0.9
    gold.roughness = 0.3
    var body := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.2, 0.17, 0.08)
    body.mesh = bm
    body.material_override = gold
    lock.add_child(body)
    var shackle := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.045
    tm.outer_radius = 0.065
    shackle.mesh = tm
    shackle.rotation_degrees.x = 90.0
    shackle.position = Vector3(0, 0.12, 0)
    shackle.material_override = gold
    lock.add_child(shackle)
    _label(w, pos + Vector3(0, 3.9, 0), "LOCKED STORAGE  •  REQUIRES KEY", "LockedStorageLabel")
    return true

# ---------------------------------------------------------------- river, bridges, boat, dock

static func river_approach(w: Node3D, pos: Vector3) -> bool:
    var bridge := place(w, "bridge_broken", pos, 0.0, "BrokenBridge", false)
    if bridge == null:
        return false
    var body := StaticBody3D.new()
    body.name = "BlockingCollision"
    var cs := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(2.8, 1.2, 10.6)
    cs.shape = box
    cs.position = Vector3(0, 0.6, 0)
    body.add_child(cs)
    bridge.add_child(body)
    path(w, pos + Vector3(0, 0, 11.0), 8.0)
    _label(w, pos + Vector3(0, 2.8, 0), "BLOCKED PATH  •  REQUIRES BRIDGE", "RiverBridgeRequirementLabel")
    return true

static func restored_bridge(w: Node3D, pos: Vector3) -> bool:
    return place(w, "bridge_wood", pos, 0.0, "RestoredBridge") != null

static func repair_bridge_approach(w: Node3D, pos: Vector3) -> bool:
    if place(w, "bridge_broken", pos, 0.0, "BrokenFootbridge", false) == null:
        return false
    var bridge := w.get_node_or_null("BrokenFootbridge")
    var body := StaticBody3D.new()
    body.name = "BlockingCollision"
    var cs := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(2.8, 1.2, 10.6)
    cs.shape = box
    cs.position = Vector3(0, 0.6, 0)
    body.add_child(cs)
    bridge.add_child(body)
    _label(w, pos + Vector3(0, 2.8, 0), "BROKEN BRIDGE  •  REQUIRES REPAIR", "RepairBridgeLabel")
    return true

static func repaired_footbridge(w: Node3D, pos: Vector3) -> bool:
    return place(w, "bridge_wood", pos, 0.0, "RepairedFootbridge") != null

static func boat(w: Node3D, pos: Vector3) -> bool:
    if place(w, "boat_damaged", pos + Vector3(0, -0.2, 0), 25.0, "DamagedBoat") == null:
        return false
    _label(w, pos + Vector3(0, 2.4, 0), "DAMAGED BOAT  •  REQUIRES ENGINE", "DamagedBoatLabel")
    return true

static func usable_boat(w: Node3D, pos: Vector3) -> bool:
    return place(w, "boat_sound", pos + Vector3(0, -0.2, 0), 25.0, "UsableBoat") != null

static func closed_dock(w: Node3D, pos: Vector3) -> bool:
    var dock := place(w, "dock_pier", pos + Vector3(0, -0.36, 0), 0.0, "ClosedDock")
    if dock == null:
        return false
    _block(Rect2(pos.x - 1.6, pos.z - 4.0, 3.2, 8.0), 0.8)
    var wood := _wood(Vector3(2.0, 1.0, 1.0))
    var barrier := Node3D.new()
    barrier.name = "DockBarrier"
    barrier.position = Vector3(0, 0.95, -2.9)
    dock.add_child(barrier)
    _box(barrier, Vector3(2.1, 0.14, 0.1), Vector3(0, 0.0, 0), wood)
    _box(barrier, Vector3(2.1, 0.14, 0.1), Vector3(0, -0.4, 0), wood)
    _label(w, pos + Vector3(0, 2.6, 0), "CLOSED DOCK  •  REQUIRES BOAT", "ClosedDockLabel")
    return true

static func open_dock(w: Node3D, pos: Vector3) -> bool:
    var dock := place(w, "dock_pier", pos + Vector3(0, -0.36, 0), 0.0, "OpenDock")
    if dock == null:
        return false
    var moored := PropFactory.spawn("boat_sound", false, true)
    if moored != null:
        moored.position = Vector3(2.4, 0.36 - 0.2, 0.5)
        moored.rotation_degrees.y = 90.0
        dock.add_child(moored)
    _label(w, pos + Vector3(0, 2.6, 0), "RIVER DOCK OPEN", "OpenDockLabel")
    return true

# ---------------------------------------------------------------- the rest of the story sites

static func cave_approach(w: Node3D, pos: Vector3) -> bool:
    var rocks := place(w, "cave_mouth", pos, 0.0, "CaveEntranceRock", false)
    if rocks == null:
        return false
    # permanent rock arch + dark opening behind the loose boulders
    for spec in [["rock_3", Vector3(-3.3, 0.0, 2.6)], ["rock_3", Vector3(3.3, 0.0, 2.6)], ["rock_1", Vector3(0, 2.7, 2.7)]]:
        var arch := PropFactory.spawn(str(spec[0]), false, true)
        if arch != null:
            arch.position = pos + (spec[1] as Vector3)
            w.add_child(arch)
    var dark := MeshInstance3D.new()
    dark.name = "CaveDarkness"
    var q := QuadMesh.new()
    q.size = Vector2(4.6, 3.4)
    dark.mesh = q
    var dm := StandardMaterial3D.new()
    dm.albedo_color = Color(0.01, 0.01, 0.015)
    dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dark.material_override = dm
    dark.position = pos + Vector3(0, 1.7, 2.3)
    w.add_child(dark)
    _block(Rect2(pos.x - 6.0, pos.z - 3.0, 12.0, 8.0), 0.5)
    _label(w, pos + Vector3(0, 6.2, 0), "CAVE  •  REQUIRES LANTERN", "CaveRequirementLabel")
    return true

static func field(w: Node3D, pos: Vector3) -> bool:
    if MaterialLibrary.get_material("dirt") == null or not PropFactory.has_model("scarecrow"):
        return false
    var plot := Node3D.new()
    plot.name = "EmptyField"
    plot.position = pos
    w.add_child(plot)
    var soil := (MaterialLibrary.get_material("dirt") as StandardMaterial3D).duplicate() as StandardMaterial3D
    soil.albedo_color = Color(0.55, 0.45, 0.38)
    soil.uv1_scale = Vector3(2.0, 2.0, 1.0)
    _box(plot, Vector3(10.0, 0.12, 7.0), Vector3(0, 0.04, 0), soil)
    var ridge := (MaterialLibrary.get_material("dirt") as StandardMaterial3D).duplicate() as StandardMaterial3D
    ridge.albedo_color = Color(0.42, 0.33, 0.26)
    ridge.uv1_scale = Vector3(3.0, 1.0, 1.0)
    for row in range(6):
        _box(plot, Vector3(8.8, 0.16, 0.5), Vector3(0, 0.12, -2.5 + float(row)), ridge)
    place(w, "scarecrow", pos + Vector3(-4.4, 0.0, -3.2), 20.0, "Scarecrow")
    fence_line(w, pos + Vector3(-5.4, 0, -4.0), pos + Vector3(5.4, 0, -4.0))
    fence_line(w, pos + Vector3(-5.4, 0, 4.0), pos + Vector3(5.4, 0, 4.0))
    fence_line(w, pos + Vector3(-5.4, 0, -4.0), pos + Vector3(-5.4, 0, 4.0))
    fence_line(w, pos + Vector3(5.4, 0, -4.0), pos + Vector3(5.4, 0, -1.2))
    fence_line(w, pos + Vector3(5.4, 0, 1.2), pos + Vector3(5.4, 0, 4.0))
    _block(Rect2(pos.x - 6.0, pos.z - 4.6, 12.0, 9.2), 0.6)
    _label(w, pos + Vector3(0, 2.6, 0), "EMPTY FIELD  •  REQUIRES SEEDS", "EmptyFieldLabel")
    return true

static func fence_line(w: Node3D, a: Vector3, b: Vector3) -> void:
    var length := a.distance_to(b)
    var count := maxi(1, int(round(length / 2.0)))
    var step := (b - a) / float(count)
    var yaw := rad_to_deg(atan2(-step.z, step.x))
    for i in range(count):
        var seg := PropFactory.spawn("fence_segment", false, true)
        if seg == null:
            return
        seg.position = a + step * float(i)
        seg.rotation_degrees.y = yaw
        seg.scale = Vector3(step.length() / 2.0, 1.0, 1.0)
        w.add_child(seg)
    var end_post := PropFactory.spawn("fence_segment", false, true)
    if end_post != null:
        end_post.position = b
        end_post.rotation_degrees.y = yaw
        end_post.scale = Vector3(0.02, 1.0, 1.0)
        w.add_child(end_post)

static func old_gate(w: Node3D, pos: Vector3) -> bool:
    if place(w, "gate_old", pos, 90.0, "LockedMeadowGate") == null:
        return false
    _label(w, pos + Vector3(0, 3.9, 0), "OLD MEADOW GATE  •  REQUIRES GATE", "OldGateLabel")
    return true

static func dark_beacon(w: Node3D, pos: Vector3) -> bool:
    var tower := place(w, "beacon_tower", pos, 0.0, "DarkBeacon")
    if tower == null:
        return false
    set_beacon_lit(w, false)
    _block(Rect2(pos.x - 3.0, pos.z - 3.0, 6.0, 6.0), 1.0)
    _label(w, pos + Vector3(0, 13.0, 0), "DARK BEACON  •  REQUIRES LIGHT", "DarkBeaconLabel")
    return true

static func set_beacon_lit(w: Node3D, lit: bool) -> void:
    var tower := w.get_node_or_null("DarkBeacon")
    if tower == null:
        return
    var meshes: Array[MeshInstance3D] = []
    _meshes(tower, meshes)
    for mi in meshes:
        if mi.mesh == null:
            continue
        for i in range(mi.mesh.get_surface_count()):
            var src := mi.mesh.surface_get_material(i)
            if src != null and src.resource_name == "beacon_glow":
                mi.set_surface_override_material(i, MaterialLibrary.get_material("beacon_glow" if lit else "beacon_off"))

static func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and not out.has(node):
        out.append(node as MeshInstance3D)
    for child in node.get_children():
        if child is MeshInstance3D:
            out.append(child as MeshInstance3D)
        _meshes(child, out)

static func locked_garden_gate(w: Node3D, pos: Vector3) -> bool:
    var gate := w.get_node_or_null("LockedGarden")
    if gate == null or not PropFactory.has_model("fence_segment"):
        return false
    for off in [-2.0, 0.0]:
        var seg := PropFactory.spawn("fence_segment", false, true)
        if seg != null:
            seg.position = Vector3(off, 0.0, 0.0)
            gate.add_child(seg)
    var wood := _wood(Vector3(1.5, 1.0, 1.0))
    var panel := Node3D.new()
    panel.name = "GatePanel"
    gate.add_child(panel)
    _box(panel, Vector3(1.6, 1.3, 0.08), Vector3(0, 0.75, 0.0), wood)
    _box(panel, Vector3(0.08, 1.3, 0.1), Vector3(-0.78, 0.75, 0.0), wood)
    _box(panel, Vector3(0.08, 1.3, 0.1), Vector3(0.78, 0.75, 0.0), wood)
    var chain := MeshInstance3D.new()
    var cm := TorusMesh.new()
    cm.inner_radius = 0.16
    cm.outer_radius = 0.2
    chain.mesh = cm
    chain.rotation_degrees.x = 90.0
    chain.position = Vector3(0, 0.78, -0.07)
    chain.material_override = MaterialLibrary.get_material("iron")
    panel.add_child(chain)
    return true

static func garden_ladder(w: Node3D, pos: Vector3) -> bool:
    var ladder := place(w, "ladder", pos, 0.0, "GardenLadder", false)
    return ladder != null

# ---------------------------------------------------------------- scenery

static func tree(w: Node3D, pos: Vector3) -> bool:
    var id := "tree_oak_%d" % (absi(int(pos.x * 7.0 + pos.z * 13.0)) % 3)
    var node := place(w, id, pos, float((int(pos.x) * 53 + int(pos.z) * 29) % 360), "Tree")
    if node == null:
        return false
    exclusions.append(Rect2(pos.x - 1.4, pos.z - 1.4, 2.8, 2.8))
    return true

static func fruit_tree(w: Node3D, pos: Vector3) -> bool:
    var id := "tree_fruit_%d" % (absi(int(pos.x * 5.0 + pos.z * 11.0)) % 3)
    var node := place(w, id, pos, float((int(pos.x * 3.0) * 71 + int(pos.z * 3.0) * 37) % 360), "FruitTree")
    if node == null:
        return false
    return true

static func dress_village(w: Node3D, seed_value: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ 0x5f3759df
    for p in [Vector3(2.7, 0, 12.5), Vector3(-2.7, 0, 12.5), Vector3(2.7, 0, 2.5), Vector3(-2.7, 0, 2.5), Vector3(2.7, 0, -6.5), Vector3(-2.7, 0, -6.5)]:
        place(w, "lamp_post", p, 0.0, "LampPost")
    place(w, "bench", Vector3(-4.6, 0, 3.0), 90.0, "Bench")
    place(w, "bench", Vector3(4.6, 0, -8.0), -90.0, "Bench")
    place(w, "well", Vector3(6.5, 0, 3.5), 0.0, "Well")
    _block(Rect2(5.4, 2.4, 2.2, 2.2), 0.5)
    place(w, "haystack", Vector3(-26.5, 0, 17.5), 30.0, "Haystack")
    place(w, "haystack", Vector3(-12.5, 0, 17.0), -20.0, "Haystack")
    place(w, "stall_small", Vector3(-6.0, 0, 11.0), 90.0, "Stall")
    _block(Rect2(-8.0, 9.5, 4.0, 3.0), 0.5)
    for spec in [["signpost", Vector3(16.0, 0, 5.0), -40.0], ["signpost", Vector3(-16.0, 0, -15.5), 35.0], ["signpost", Vector3(16.0, 0, -24.0), -30.0], ["signpost", Vector3(-19.0, 0, 6.5), 60.0]]:
        place(w, str(spec[0]), spec[1], float(spec[2]), "Signpost")
    # fences along the garden entrance and the path
    fence_line(w, Vector3(7.0, 0, -5.4), Vector3(14.0, 0, -5.4))
    fence_line(w, Vector3(8.0, 0, 15.0), Vector3(14.0, 0, 15.0))
    # scattered natural scenery just inside the village boundary (outside the story sites)
    _scatter(w, rng, ["tree_oak_0", "tree_oak_1", "tree_oak_2", "tree_pine_0"], 26, 24.0, 47.0, true)
    _scatter(w, rng, ["bush_0", "bush_1"], 34, 6.0, 47.0, false)
    _scatter(w, rng, ["rock_0", "rock_1", "rock_2"], 14, 8.0, 46.0, true)

static func _blocked(x: float, z: float, pad: float) -> bool:
    var p := Vector2(x, z)
    for r in exclusions:
        if r.grow(pad).has_point(p):
            return true
    return false

static func _scatter(w: Node3D, rng: RandomNumberGenerator, ids: Array, count: int, min_r: float, max_r: float, with_collision: bool) -> void:
    var placed := 0
    var tries := 0
    while placed < count and tries < count * 30:
        tries += 1
        var a := rng.randf() * TAU
        var r := rng.randf_range(min_r, max_r)
        var x := cos(a) * r
        var z := sin(a) * r
        if absf(x) > 47.0 or absf(z) > 47.0 or _blocked(x, z, 2.0):
            continue
        var id: String = ids[rng.randi() % ids.size()]
        var node := PropFactory.spawn(id, with_collision, true)
        if node == null:
            return
        node.position = Vector3(x, TerrainField.height_at(x, z), z)
        node.rotation_degrees.y = rng.randf() * 360.0
        w.add_child(node)
        exclusions.append(Rect2(x - 1.2, z - 1.2, 2.4, 2.4))
        placed += 1
