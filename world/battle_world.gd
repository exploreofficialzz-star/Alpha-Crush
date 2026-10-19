extends Node3D
class_name BattleWorld

## Builds one battlefield: the ground, an invisible boundary, the ALPHA base, rings of cover (sandbags, containers, crates,
## explosive barrels, concrete barriers, ruined walls), a few real buildings, trees and rocks. Everything is seeded, so the same
## operation always produces the same map. Building yields every few frames so the game never freezes while loading.
signal built
signal crate_broken(position: Vector3)

## Far from the old village so the river ambience never leaks into a battle.
const CENTER := Vector3(600.0, 0.0, 600.0)
const BOUNDARY_RADIUS := 66.0
const BASE_OFFSET := Vector3(0.0, 0.0, 44.0)
const ENEMY_ARC_RADIUS := 54.0

var arena_id := "farmstead"
var arena: Dictionary = {}
var seed_value := 1
var quality: QualityManager
var director: CombatDirector
var fx: CombatFX
var audio: AudioManager

var alpha_spawn := Vector3.ZERO
var alpha_ally_spawns: Array[Vector3] = []
var enemy_spawns: Array[Vector3] = []
var capture_points: Array[Vector3] = []
var pickup_points: Array[Vector3] = []
var cover_points: Array[Vector3] = []
var boss_spawn := Vector3.ZERO
var props_root: Node3D

var _rng := RandomNumberGenerator.new()
var _pick_rng := RandomNumberGenerator.new()
var _hills := 5.0
var _blockers: Array[Dictionary] = []
var _shadows := true
var _tree_shadows := false
var _props_factor := 1.0
var _materials: Dictionary = {}

# ------------------------------------------------------------------------------------------------ public queries
func ground_y(x: float, z: float) -> float:
    return ArenaTerrain.height_at(x, z, CENTER, _hills, seed_value)

func snap(point: Vector3) -> Vector3:
    return Vector3(point.x, ground_y(point.x, point.z), point.z)

## angle 0 = north (towards -Z, where the opposition comes from), positive angles swing clockwise (east).
func polar(angle_degrees: float, radius: float) -> Vector3:
    var angle := deg_to_rad(angle_degrees)
    return snap(CENTER + Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius))

func pick_enemy_spawn(avoid: Vector3, min_distance: float = 26.0) -> Vector3:
    var options: Array[Vector3] = []
    for point in enemy_spawns:
        if point.distance_to(avoid) >= min_distance:
            options.append(point)
    if options.is_empty():
        options = enemy_spawns
    if options.is_empty():
        return snap(CENTER)
    var chosen := options[_pick_rng.randi() % options.size()]
    return snap(chosen + Vector3(_pick_rng.randf_range(-3.0, 3.0), 0.0, _pick_rng.randf_range(-3.0, 3.0)))

## A random walkable point between two radii around `around` (kept inside the boundary).
func random_point_near(around: Vector3, min_radius: float, max_radius: float) -> Vector3:
    for attempt in 12:
        var angle := _pick_rng.randf() * TAU
        var radius := _pick_rng.randf_range(min_radius, max_radius)
        var point := around + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        if Vector2(point.x - CENTER.x, point.z - CENTER.z).length() < BOUNDARY_RADIUS - 4.0:
            return snap(point)
    return snap(around)

func is_inside_arena(point: Vector3) -> bool:
    return Vector2(point.x - CENTER.x, point.z - CENTER.z).length() < BOUNDARY_RADIUS - 1.0

# ------------------------------------------------------------------------------------------------ build pipeline
func build(p_arena_id: String, p_seed: int, p_quality: QualityManager, p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager) -> void:
    arena_id = p_arena_id if ArenaCatalog.is_valid(p_arena_id) else ArenaCatalog.ORDER[0]
    arena = ArenaCatalog.arena(arena_id)
    seed_value = p_seed
    _rng.seed = p_seed
    _pick_rng.randomize()
    quality = p_quality
    director = p_director
    fx = p_fx
    audio = p_audio
    _hills = float(arena.get("hills", 5.0))
    var values: Dictionary = quality.current() if quality != null else {}
    _props_factor = clampf(float(values.get("props", 0.85)), 0.45, 1.0)
    _shadows = bool(values.get("shadow", true))
    _tree_shadows = bool(values.get("tree_shadows", false))
    props_root = Node3D.new()
    props_root.name = "Props"
    add_child(props_root)
    _build_terrain()
    await get_tree().process_frame
    _build_boundary()
    _layout_zones()
    _build_base()
    await get_tree().process_frame
    _build_clusters()
    await get_tree().process_frame
    _build_buildings()
    _build_scenery()
    await get_tree().process_frame
    _build_pickup_points()
    built.emit()

func _build_terrain() -> void:
    var ground := Vegetation.region_material(str(arena.get("region", "farmland")))
    var patch := ArenaTerrain.build_patch(CENTER, _hills, seed_value, ground)
    var body := TerrainField.make_body(patch, "Terrain")
    body.collision_layer = Teams.LAYER_WORLD
    body.collision_mask = 0
    body.position = patch["origin"]
    add_child(body)

func _build_boundary() -> void:
    var count := 16
    var length := 2.0 * BOUNDARY_RADIUS * sin(PI / float(count)) + 2.0
    for k in count:
        var angle := TAU * float(k) / float(count)
        var wall := StaticBody3D.new()
        wall.name = "Boundary_%d" % k
        wall.collision_layer = Teams.LAYER_WORLD
        wall.collision_mask = 0
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(length, 40.0, 2.0)
        shape.shape = box
        wall.add_child(shape)
        wall.position = Vector3(CENTER.x + cos(angle) * BOUNDARY_RADIUS, 12.0, CENTER.z + sin(angle) * BOUNDARY_RADIUS)
        wall.rotation.y = -angle - PI * 0.5
        add_child(wall)

func _layout_zones() -> void:
    alpha_spawn = snap(CENTER + BASE_OFFSET)
    alpha_ally_spawns.clear()
    alpha_ally_spawns.append(snap(alpha_spawn + Vector3(-3.5, 0.0, -2.5)))
    alpha_ally_spawns.append(snap(alpha_spawn + Vector3(3.5, 0.0, -2.5)))
    alpha_ally_spawns.append(snap(alpha_spawn + Vector3(0.0, 0.0, -5.0)))
    enemy_spawns.clear()
    for i in 9:
        enemy_spawns.append(polar(lerpf(-64.0, 64.0, float(i) / 8.0), ENEMY_ARC_RADIUS))
    enemy_spawns.append(snap(CENTER + Vector3(-52.0, 0.0, 8.0)))
    enemy_spawns.append(snap(CENTER + Vector3(52.0, 0.0, 8.0)))
    capture_points.clear()
    capture_points.append(snap(CENTER + Vector3(-30.0, 0.0, -6.0)))
    capture_points.append(snap(CENTER + Vector3(0.0, 0.0, -16.0)))
    capture_points.append(snap(CENTER + Vector3(30.0, 0.0, -6.0)))
    boss_spawn = snap(CENTER + Vector3(0.0, 0.0, -44.0))
    _blockers.clear()
    _block(alpha_spawn, 14.0)
    for point in enemy_spawns:
        _block(point, 5.0)
    for point in capture_points:
        _block(point, 4.0)
    _block(boss_spawn, 6.0)

func _block(point: Vector3, radius: float) -> void:
    _blockers.append({"x": point.x, "z": point.z, "r": radius})

func _is_clear(x: float, z: float, radius: float) -> bool:
    for blocker in _blockers:
        var dx := x - float(blocker["x"])
        var dz := z - float(blocker["z"])
        var limit := radius + float(blocker["r"])
        if dx * dx + dz * dz < limit * limit:
            return false
    return true

## A free spot between two radii (measured from the arena centre); Vector3.INF when none was found.
func _find_spot(min_radius: float, max_radius: float, clearance: float) -> Vector3:
    for attempt in 40:
        var angle := _rng.randf() * TAU
        var radius := _rng.randf_range(min_radius, max_radius)
        var x := CENTER.x + cos(angle) * radius
        var z := CENTER.z + sin(angle) * radius
        if _is_clear(x, z, clearance):
            return snap(Vector3(x, 0.0, z))
    return Vector3.INF

# ------------------------------------------------------------------------------------------------ materials and primitives
func _flat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
    var key := "flat_%s_%.2f" % [color.to_html(), roughness]
    if _materials.has(key):
        return _materials[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    _materials[key] = material
    return material

## A library texture mapped in world space (BoxMesh UVs would stretch it over long faces).
func _tri(id: String, density: float, tint: Color = Color.WHITE) -> Material:
    var key := "tri_%s_%.2f_%s" % [id, density, tint.to_html()]
    if _materials.has(key):
        return _materials[key]
    var base := MaterialLibrary.get_material(id) as StandardMaterial3D
    if base == null:
        return _flat(tint, 0.9)
    var copy := base.duplicate() as StandardMaterial3D
    copy.uv1_triplanar = true
    copy.uv1_world_triplanar = true
    copy.uv1_scale = Vector3.ONE * density
    copy.albedo_color = tint
    _materials[key] = copy
    return copy

## A solid box standing on the ground (its bottom edge at local y = 0). Returns the body so callers can add details.
func _box(parent: Node3D, size: Vector3, local_pos: Vector3, yaw: float, material: Material, collide: bool = true, group_cover: bool = true) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.collision_layer = Teams.LAYER_WORLD
    body.collision_mask = 0
    body.position = local_pos
    body.rotation.y = yaw
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = Vector3(0.0, size.y * 0.5, 0.0)
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.add_child(instance)
    if collide:
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        shape.position = Vector3(0.0, size.y * 0.5, 0.0)
        body.add_child(shape)
        if group_cover:
            body.add_to_group("cover")
    parent.add_child(body)
    return body

func _cluster_root(point: Vector3, yaw: float, label: String) -> Node3D:
    var root := Node3D.new()
    root.name = label
    root.position = point
    root.rotation.y = yaw
    props_root.add_child(root)
    return root

func _breakable(kind: String, point: Vector3) -> BreakableProp:
    var prop := BreakableProp.new()
    prop.setup(kind)
    prop.configure(director, fx, audio)
    prop.loot_callback = Callable(self, "_on_crate_loot")
    prop.position = point
    prop.rotation.y = _rng.randf() * TAU
    props_root.add_child(prop)
    return prop

func _on_crate_loot(point: Vector3) -> void:
    crate_broken.emit(point)

# ------------------------------------------------------------------------------------------------ base
func _build_base() -> void:
    var disc := MeshInstance3D.new()
    disc.name = "BaseMarker"
    var disc_mesh := CylinderMesh.new()
    disc_mesh.top_radius = 7.0
    disc_mesh.bottom_radius = 7.0
    disc_mesh.height = 0.04
    disc_mesh.radial_segments = 28
    disc_mesh.rings = 1
    disc.mesh = disc_mesh
    disc.position = alpha_spawn + Vector3(0.0, 0.08, 0.0)
    disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glow.albedo_color = Color(0.2, 0.85, 0.88, 0.22)
    disc.material_override = glow
    props_root.add_child(disc)
    var sandbag := _flat(Color(0.62, 0.55, 0.38))
    var wall_back := _cluster_root(snap(alpha_spawn + Vector3(0.0, 0.0, 7.0)), 0.0, "BaseWallBack")
    _box(wall_back, Vector3(9.0, 1.1, 0.9), Vector3.ZERO, 0.0, sandbag)
    var wall_left := _cluster_root(snap(alpha_spawn + Vector3(-7.5, 0.0, 3.5)), 0.6, "BaseWallLeft")
    _box(wall_left, Vector3(5.0, 1.1, 0.9), Vector3.ZERO, 0.0, sandbag)
    var wall_right := _cluster_root(snap(alpha_spawn + Vector3(7.5, 0.0, 3.5)), -0.6, "BaseWallRight")
    _box(wall_right, Vector3(5.0, 1.1, 0.9), Vector3.ZERO, 0.0, sandbag)
    var crate_material := _tri("wood_planks", 0.7)
    for side in [-1.0, 1.0]:
        var stack := _cluster_root(snap(alpha_spawn + Vector3(5.2 * float(side), 0.0, 5.0)), 0.3 * float(side), "BaseCrates")
        _box(stack, Vector3(1.0, 1.0, 1.0), Vector3.ZERO, 0.0, crate_material)
        _box(stack, Vector3(0.9, 0.9, 0.9), Vector3(0.1, 1.0, 0.0), 0.2, crate_material, false)
    var pole := _cluster_root(snap(alpha_spawn + Vector3(0.0, 0.0, 4.5)), 0.0, "BaseBanner")
    var mast := MeshInstance3D.new()
    var mast_mesh := CylinderMesh.new()
    mast_mesh.top_radius = 0.07
    mast_mesh.bottom_radius = 0.09
    mast_mesh.height = 5.0
    mast_mesh.radial_segments = 6
    mast_mesh.rings = 1
    mast.mesh = mast_mesh
    mast.position = Vector3(0.0, 2.5, 0.0)
    mast.material_override = _flat(Color(0.75, 0.77, 0.8), 0.4)
    mast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pole.add_child(mast)
    var banner := MeshInstance3D.new()
    var banner_mesh := BoxMesh.new()
    banner_mesh.size = Vector3(1.8, 1.1, 0.05)
    banner.mesh = banner_mesh
    banner.position = Vector3(0.95, 4.3, 0.0)
    var banner_material := StandardMaterial3D.new()
    banner_material.albedo_color = Color(0.2, 0.85, 0.88)
    banner_material.emission_enabled = true
    banner_material.emission = Color(0.2, 0.85, 0.88)
    banner_material.emission_energy_multiplier = 0.5
    banner.material_override = banner_material
    banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pole.add_child(banner)

# ------------------------------------------------------------------------------------------------ cover clusters
func _build_clusters() -> void:
    var wanted := int(round(float(arena.get("clusters", 14)) * _props_factor))
    var placed := 0
    var guard := 0
    while placed < wanted and guard < wanted * 6:
        guard += 1
        var spot := _find_spot(9.0, 56.0, 6.5)
        if not spot.is_finite():
            continue
        var kind := ArenaCatalog.pick_cluster(arena_id, _rng.randf())
        _build_cluster(kind, spot, _rng.randf() * TAU)
        _block(spot, 5.0)
        placed += 1

func _build_cluster(kind: String, point: Vector3, yaw: float) -> void:
    if kind == "sandbag":
        _sandbags(point, yaw)
    elif kind == "container":
        _containers(point, yaw)
    elif kind == "barrel":
        _barrels(point, yaw)
    elif kind == "barrier":
        _barriers(point, yaw)
    elif kind == "ruin":
        _ruins(point, yaw)
    else:
        _crates(point, yaw)
    cover_points.append(point)

func _sandbags(point: Vector3, yaw: float) -> void:
    var root := _cluster_root(point, yaw, "Sandbags")
    var length := _rng.randf_range(4.0, 6.5)
    var khaki := _flat(Color(0.64, 0.56, 0.38))
    var darker := _flat(Color(0.55, 0.48, 0.32))
    var body := _box(root, Vector3(length, 1.1, 0.85), Vector3.ZERO, 0.0, khaki)
    var top := MeshInstance3D.new()
    var top_mesh := BoxMesh.new()
    top_mesh.size = Vector3(length - 0.9, 0.35, 0.7)
    top.mesh = top_mesh
    top.position = Vector3(0.0, 1.1 + 0.17, 0.0)
    top.material_override = darker
    top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.add_child(top)

func _containers(point: Vector3, yaw: float) -> void:
    var root := _cluster_root(point, yaw, "Containers")
    var palette: Array[Color] = [Color(0.70, 0.18, 0.14), Color(0.18, 0.34, 0.62), Color(0.20, 0.50, 0.28), Color(0.90, 0.62, 0.12), Color(0.45, 0.45, 0.48)]
    var door := _flat(Color(0.12, 0.12, 0.14), 0.7)
    for side in [-1.0, 1.0]:
        var color := palette[_rng.randi() % palette.size()]
        var shell := _box(root, Vector3(2.5, 2.6, 6.0), Vector3(2.15 * float(side), 0.0, 0.0), 0.0, _flat(color, 0.6))
        var end_door := MeshInstance3D.new()
        var door_mesh := BoxMesh.new()
        door_mesh.size = Vector3(2.2, 2.3, 0.06)
        end_door.mesh = door_mesh
        end_door.position = Vector3(0.0, 1.3, 3.0)
        end_door.material_override = door
        end_door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        shell.add_child(end_door)

func _crates(point: Vector3, yaw: float) -> void:
    var root := _cluster_root(point, yaw, "Crates")
    var wood := _tri("wood_planks", 0.7)
    _box(root, Vector3(1.0, 1.0, 1.0), Vector3(-0.55, 0.0, 0.0), 0.0, wood)
    _box(root, Vector3(1.0, 1.0, 1.0), Vector3(0.55, 0.0, 0.0), 0.05, wood)
    _box(root, Vector3(0.95, 0.95, 0.95), Vector3(0.0, 1.0, 0.0), 0.2, wood, false)
    _breakable("crate", snap(point + Vector3(2.4, 0.0, 0.6)))
    _breakable("crate", snap(point + Vector3(-2.3, 0.0, -0.5)))
    if _rng.randf() < 0.4:
        _breakable("barrel", snap(point + Vector3(0.4, 0.0, 2.3)))

func _barrels(point: Vector3, _yaw: float) -> void:
    _breakable("barrel", point)
    _breakable("barrel", snap(point + Vector3(1.05, 0.0, 0.45)))
    _breakable("barrel", snap(point + Vector3(-0.95, 0.0, 0.55)))
    var root := _cluster_root(point, 0.0, "BarrelPad")
    _box(root, Vector3(1.0, 1.0, 1.0), Vector3(0.1, 0.0, -1.9), 0.3, _tri("wood_planks", 0.7))

func _barriers(point: Vector3, yaw: float) -> void:
    var root := _cluster_root(point, yaw, "Barriers")
    var concrete := _flat(Color(0.62, 0.62, 0.60), 0.95)
    _box(root, Vector3(2.6, 1.05, 0.65), Vector3(-1.4, 0.0, 0.0), 0.0, concrete)
    _box(root, Vector3(2.6, 1.05, 0.65), Vector3(1.4, 0.0, 0.9), 0.0, concrete)
    _box(root, Vector3(2.6, 1.05, 0.65), Vector3(-0.2, 0.0, -2.2), 1.2, concrete)

func _ruins(point: Vector3, yaw: float) -> void:
    var root := _cluster_root(point, yaw, "Ruins")
    var brick := _tri("brick", 0.5, Color(0.9, 0.85, 0.8))
    var wall := _box(root, Vector3(4.6, 2.4, 0.5), Vector3.ZERO, 0.0, brick)
    var chip := MeshInstance3D.new()
    var chip_mesh := BoxMesh.new()
    chip_mesh.size = Vector3(1.8, 0.9, 0.5)
    chip.mesh = chip_mesh
    chip.position = Vector3(-1.2, 2.4 + 0.45, 0.0)
    chip.material_override = brick
    chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    wall.add_child(chip)
    _box(root, Vector3(0.5, 1.9, 3.2), Vector3(2.1, 0.0, 1.6), 0.0, brick)
    for i in 3:
        _box(root, Vector3(0.6, 0.35, 0.45), Vector3(_rng.randf_range(-2.0, 1.0), 0.0, _rng.randf_range(1.0, 2.6)), _rng.randf() * TAU, brick, false)

# ------------------------------------------------------------------------------------------------ buildings and scenery
func _build_buildings() -> void:
    var ids: Array = arena.get("buildings", [])
    var count := mini(int(arena.get("building_count", 2)), 4)
    if ids.is_empty():
        return
    for i in count:
        var side := 1.0 if i % 2 == 0 else -1.0
        var angle := side * (100.0 + 22.0 * float(i >> 1))
        var spot := polar(angle, 49.0 + _rng.randf_range(-3.0, 3.0))
        if not _is_clear(spot.x, spot.z, 8.0):
            continue
        var id := str(ids[i % ids.size()])
        var building := PropFactory.spawn(id, true, _shadows)
        if building == null:
            continue
        building.position = spot
        building.rotation.y = float(_rng.randi_range(0, 3)) * PI * 0.5 + _rng.randf_range(-0.2, 0.2)
        props_root.add_child(building)
        _block(spot, 9.0)
        cover_points.append(spot)

func _build_scenery() -> void:
    var kinds: Array = arena.get("woods", [])
    var tree_count := int(round(float(arena.get("trees", 0)) * _props_factor))
    if not kinds.is_empty():
        for i in tree_count:
            var spot := _find_spot(12.0, 60.0, 2.6)
            if not spot.is_finite():
                continue
            var ids: Array = Vegetation.TREE_IDS.get(str(kinds[_rng.randi() % kinds.size()]), Vegetation.TREE_IDS["oak"])
            var tree := PropFactory.spawn(str(ids[_rng.randi() % ids.size()]), true, _tree_shadows)
            if tree == null:
                continue
            tree.position = spot
            tree.rotation.y = _rng.randf() * TAU
            tree.scale = Vector3.ONE * _rng.randf_range(0.9, 1.3)
            props_root.add_child(tree)
            _block(spot, 1.5)
    var rock_count := int(round(float(arena.get("rocks", 6)) * _props_factor))
    for i in rock_count:
        var spot := _find_spot(10.0, 60.0, 2.4)
        if not spot.is_finite():
            continue
        var rock := PropFactory.spawn(str(Vegetation.ROCK_IDS[_rng.randi() % Vegetation.ROCK_IDS.size()]), true, false)
        if rock == null:
            continue
        rock.position = spot
        rock.rotation.y = _rng.randf() * TAU
        rock.scale = Vector3.ONE * _rng.randf_range(0.8, 1.4)
        props_root.add_child(rock)
        _block(spot, 1.8)
    _build_far_scenery(kinds)

## Trees and rocks beyond the boundary: one MultiMesh per model (a single draw call each), no collision.
func _build_far_scenery(kinds: Array) -> void:
    var far_root := Node3D.new()
    far_root.name = "FarScenery"
    add_child(far_root)
    if not kinds.is_empty():
        var groups: Dictionary = {}
        var far_count := int(round(float(clampi(int(arena.get("trees", 0)) * 3, 30, 90)) * _props_factor))
        for i in far_count:
            var angle := _rng.randf() * TAU
            var radius := _rng.randf_range(BOUNDARY_RADIUS + 5.0, 108.0)
            var x := CENTER.x + cos(angle) * radius
            var z := CENTER.z + sin(angle) * radius
            var ids: Array = Vegetation.TREE_IDS.get(str(kinds[_rng.randi() % kinds.size()]), Vegetation.TREE_IDS["oak"])
            var id := str(ids[_rng.randi() % ids.size()])
            var spin := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.0, 1.7))
            var list: Array = groups.get(id, [])
            list.append(Transform3D(spin, Vector3(x, ground_y(x, z), z)))
            groups[id] = list
        for id in groups.keys():
            Vegetation._add_multimesh(far_root, str(id), groups[id], false, 220.0)
    var rock_groups: Dictionary = {}
    for i in int(round(24.0 * _props_factor)):
        var angle := _rng.randf() * TAU
        var radius := _rng.randf_range(BOUNDARY_RADIUS + 3.0, 104.0)
        var x := CENTER.x + cos(angle) * radius
        var z := CENTER.z + sin(angle) * radius
        var id := str(Vegetation.ROCK_IDS[_rng.randi() % Vegetation.ROCK_IDS.size()])
        var spin := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.2, 2.6))
        var list: Array = rock_groups.get(id, [])
        list.append(Transform3D(spin, Vector3(x, ground_y(x, z) - 0.2, z)))
        rock_groups[id] = list
    for id in rock_groups.keys():
        Vegetation._add_multimesh(far_root, str(id), rock_groups[id], false, 200.0)

func _build_pickup_points() -> void:
    pickup_points.clear()
    var wanted := 10
    var guard := 0
    while pickup_points.size() < wanted and guard < 60:
        guard += 1
        var spot := _find_spot(8.0, 54.0, 1.6)
        if spot.is_finite():
            pickup_points.append(spot)
            _block(spot, 6.0)
    pickup_points.append(snap(alpha_spawn + Vector3(-9.0, 0.0, -4.0)))
    pickup_points.append(snap(alpha_spawn + Vector3(9.0, 0.0, -4.0)))
