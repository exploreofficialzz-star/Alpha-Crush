extends Node3D
class_name AlphaCrushWorld

signal discovery_message(text: String)
signal objective_changed(title: String, detail: String)
signal context_changed(text: String)
signal crafting_requested
signal resource_harvested(item_id: String, amount: int)

var word_system: WordSystem
var inventory: Inventory
var world_state: WorldState
var discovery: DiscoveryManager
var economy: EconomyManager
var progression: ProgressionManager
var opportunities: OpportunityManager
var campaign: CampaignManager
var market_orders: MarketOrderBoard
var postgame: PostgameManager
var world_authority: WorldAuthority
var daily: DailyManager
var live_events: LiveEventManager
var map_manager: MapManager
var letters: Array[LetterObject] = []
var current_word_letters: Array[LetterObject] = []
var fruit_nodes: Array[HarvestNode] = []
var resource_nodes: Array[HarvestNode] = []
var assembly: WordAssembly
var ladder_built := false
var garden_unlocked := false
var market_open := false
var harvest_count := 0
var completed_words: Dictionary = {}
var garden_harvest_active := false
var context_timer := 0.0
var last_context := ""
var garden_upgrade_visual: Node3D
var field_crops_spawned := false
var cave_ore_spawned := false
var word_progress: Dictionary = {}
var harvest_state: Dictionary = {}

const VILLAGE_CENTER := Vector3(0, 0, 0)
const GARDEN_POS := Vector3(11, 0, -10)
const MARKET_POS := Vector3(-10, 0, -5)
const RIVER_GATE_POS := Vector3(-22, 0, -18)
const WORKSHOP_POS := Vector3(18, 0, 8)
const CAVE_SIGN_POS := Vector3(22, 0, -27)
const FIELD_POS := Vector3(-20, 0, 12)
const BOAT_POS := Vector3(-31, 0, -16)
const STORAGE_POS := Vector3(-14, 0, 10)
const REPAIR_BRIDGE_POS := Vector3(-36, 0, -30)
const DOCK_POS := Vector3(-9, 0, -25)
const OLD_GATE_POS := Vector3(32, 0, 18)
const BEACON_POS := Vector3(32, 0, -36)
const COMMUNITY_HALL_POS := Vector3(0, 0, -14)

func _ready() -> void:
    opportunities = null
    if get_parent():
        opportunities = get_parent().get_node_or_null("OpportunityManager") as OpportunityManager
    assembly = preload("res://words/assembly/word_assembly.gd").new()
    assembly.name = "WordAssembly"
    add_child(assembly)
    _build_world()
    _spawn_npcs()
    _spawn_animals()
    _ensure_tutorial_word()

func _process(delta: float) -> void:
    context_timer -= delta
    if context_timer > 0.0:
        return
    context_timer = 0.15
    var player_node: AlphaCrushPlayer = null
    if get_parent():
        player_node = get_parent().get_node_or_null("Player") as AlphaCrushPlayer
    if player_node == null:
        return
    var context := ""
    if player_node.get("carried_letters") is Array and player_node.carried_letters.size() > 0:
        context = "Q  DROP LETTER"
    else:
        for node in letters:
            if is_instance_valid(node) and player_node.global_position.distance_to(node.global_position) < 2.8:
                context = "E  PICK UP %s" % str(node.letter)
                break
    if context.is_empty():
        for node in fruit_nodes:
            if is_instance_valid(node) and player_node.global_position.distance_to(node.global_position) < 2.4 and bool(node.get("available")):
                context = "E  HARVEST"
                break
    if context.is_empty() and player_node.global_position.distance_to(GARDEN_POS) < 8.0:
        context = "E  BUILD GARDEN UPGRADE" if world_state.get_state("garden_development") == "ACTIVE" else "E  GARDEN"
    if context.is_empty() and player_node.global_position.distance_to(MARKET_POS) < 6.0:
        context = "E  FULFILL ORDER / SELL" if market_open else "MARKET LOCKED — DISCOVER OPEN"
    if context.is_empty() and player_node.global_position.distance_to(WORKSHOP_POS) < 6.0:
        context = "E  WORKSHOP"
    if context.is_empty() and player_node.global_position.distance_to(RIVER_GATE_POS) < 6.0:
        context = "E  DISCOVER"
    if context.is_empty() and player_node.global_position.distance_to(CAVE_SIGN_POS) < 7.0:
        context = "E  DISCOVER"
    if context.is_empty() and player_node.global_position.distance_to(FIELD_POS) < 6.0:
        context = "E  FIELD"
    if context.is_empty() and player_node.global_position.distance_to(BOAT_POS) < 6.0:
        context = "E  BOAT"
    if context.is_empty() and player_node.global_position.distance_to(STORAGE_POS) < 5.0:
        context = "E  STORAGE"
    if context.is_empty() and player_node.global_position.distance_to(REPAIR_BRIDGE_POS) < 6.0:
        context = "E  REPAIR BRIDGE"
    if context.is_empty() and player_node.global_position.distance_to(DOCK_POS) < 6.0:
        context = "E  DOCK"
    if context.is_empty() and player_node.global_position.distance_to(OLD_GATE_POS) < 6.0:
        context = "E  OLD GATE"
    if context.is_empty() and player_node.global_position.distance_to(BEACON_POS) < 6.0:
        context = "E  BEACON"
    if context.is_empty():
        context = "Explore the world"
    if context != last_context:
        last_context = context
        context_changed.emit(context)

func configure(daily_manager: Node, event_manager: Node, map: Node) -> void:
    daily = daily_manager
    live_events = event_manager
    map_manager = map

func _ensure_tutorial_word() -> void:
    # A saved in-progress word takes priority over selecting a fresh tutorial objective.
    # The service snapshot is restored before the world enters _ready().
    if word_system and word_system.has_active_word() and not word_system.is_complete():
        resume_saved_word(word_system.active_word)
        return
    if word_system and word_system.has_active_word() and word_system.is_complete():
        word_system.clear_active_word()
    if not world_state.is_complete("garden_gate"):
        _start_word("LADDER", [Vector3(-2, 1, -1), Vector3(3, 1, -2), Vector3(-5, 1, -4), Vector3(5, 1, 3), Vector3(-8, 1, 4), Vector3(8, 1, 1)])
        discovery.discover("garden_gate", "Elevated Garden")
        if opportunities:
            opportunities.register("garden_gate", "Elevated Garden", "LADDER", GARDEN_POS, "starter_village")
        if map_manager:
            map_manager.discover("garden_gate", GARDEN_POS, "Elevated Garden", "starter_village")
        discovery_message.emit("Something is blocking the elevated garden. Walk toward the gate.")
        objective_changed.emit("DISCOVER", "Find out what the elevated garden needs.")
    else:
        garden_unlocked = true
        if not world_state.is_complete("orange_harvest"):
            _start_word("ORANGE", [Vector3(7, 1, -8), Vector3(12, 1, -12), Vector3(16, 1, -7), Vector3(9, 1, -15), Vector3(5, 1, -12), Vector3(14, 1, -15)])
        elif not world_state.is_complete("basket_upgrade"):
            _start_word("BASKET", [Vector3(3, 1, -2), Vector3(6, 1, 2), Vector3(-4, 1, -5), Vector3(15, 1, -3), Vector3(-8, 1, 4), Vector3(4, 1, 7)])
        elif not world_state.is_complete("market"):
            _start_word("MARKET", [Vector3(-4, 1, -8), Vector3(-14, 1, -5), Vector3(-7, 1, 4), Vector3(3, 1, 5), Vector3(-17, 1, 2), Vector3(8, 1, -4)])
        elif not world_state.is_complete("garden_development"):
            _start_word("UPGRADE", [Vector3(15, 1, 6), Vector3(19, 1, 9), Vector3(12, 1, 12), Vector3(23, 1, 4), Vector3(8, 1, 7), Vector3(20, 1, 13), Vector3(16, 1, -1)])

func _spawn_animals() -> void:
    var animal_script = preload("res://world/simulation/animal_agent.gd")
    var animal_data := [
        [Vector3(-8, 0, 14), "cow", 101],
        [Vector3(-13, 0, 13), "cow", 102],
        [Vector3(6, 0, 12), "goat", 103],
        [Vector3(10, 0, 14), "goat", 104],
        [Vector3(-15, 0, -2), "deer", 105],
        [Vector3(14, 0, -16), "deer", 106],
        [Vector3(4, 0, -5), "chicken", 107],
        [Vector3(-2, 0, -2), "chicken", 108]
    ]
    for item in animal_data:
        var animal: AnimalAgent = animal_script.new()
        animal.name = "Animal_%s_%d" % [str(item[1]).capitalize(), int(item[2])]
        add_child(animal)
        animal.setup(str(item[1]), item[0], int(item[2]))

func _spawn_npcs() -> void:
    var npc_script = preload("res://player/npc/npc_agent.gd")
    var npc_data := [
        [Vector3(-7, 0, -4), "merchant", "Maya"],
        [Vector3(5, 0, 4), "farmer", "Jonah"],
        [Vector3(14, 0, -2), "gardener", "Amara"],
        [Vector3(-17, 0, -10), "traveler", "David"],
        [Vector3(7, 0, 13), "builder", "Lina"]
    ]
    for item in npc_data:
        var npc = npc_script.new()
        npc.name = "Human_%s" % str(item[2])
        add_child(npc)
        npc.setup(item[0], str(item[1]), str(item[2]))

func _build_world() -> void:
    _ground()
    _path(Vector3(0, 0, -3), Vector3(0, 0, 1), 34)
    _home(Vector3(0, 0, 7))
    _market(MARKET_POS)
    _garden(GARDEN_POS)
    _workshop(WORKSHOP_POS)
    _riverland_approach(RIVER_GATE_POS)
    _cave_approach(CAVE_SIGN_POS)
    _field(FIELD_POS)
    _boat(BOAT_POS)
    _storage(STORAGE_POS)
    _repair_bridge_approach(REPAIR_BRIDGE_POS)
    _closed_dock(DOCK_POS)
    _old_gate(OLD_GATE_POS)
    _dark_beacon(BEACON_POS)
    _community_hall(COMMUNITY_HALL_POS)
    _build_trees()
    _locked_gate(Vector3(10, 0, -7))
    _build_landmarks()
    _spawn_basic_resources()

func _ground() -> void:
    var body := StaticBody3D.new()
    body.name = "Ground"
    add_child(body)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(240, 0.5, 240)
    shape.shape = box
    shape.position.y = -0.25
    body.add_child(shape)
    var mesh := MeshInstance3D.new()
    var plane := BoxMesh.new()
    plane.size = Vector3(240, 0.5, 240)
    mesh.mesh = plane
    mesh.position.y = -0.25
    mesh.material_override = _mat(Color("#78966d"))
    body.add_child(mesh)

func _home(pos: Vector3) -> void:
    _building("HOME", pos, Vector3(5, 3.5, 4), Color("#d9c8a5"))
    _label(pos + Vector3(0, 4, 0), "HOME")

func _market(pos: Vector3) -> void:
    _building("MARKET", pos, Vector3(6, 3, 4), Color("#cba16e"))
    var label := _label(pos + Vector3(0, 3.6, 0), "CLOSED MARKET  •  REQUIRES OPEN")
    label.name = "ClosedMarketLabel"
    var shutter := MeshInstance3D.new()
    shutter.name = "MarketShutter"
    var shutter_mesh := BoxMesh.new()
    shutter_mesh.size = Vector3(4.6, 1.8, 0.18)
    shutter.mesh = shutter_mesh
    shutter.position = pos + Vector3(0, 1.0, -2.1)
    shutter.material_override = _mat(Color("#75553b"))
    add_child(shutter)

func _garden(pos: Vector3) -> void:
    _building("GARDEN", pos, Vector3(9, 0.5, 7), Color("#9fbc68"))
    for i in range(10):
        var p := pos + Vector3(-4 + i * 0.85, 0, -1 + float(i % 3) * 1.6)
        _fruit_tree(p, "fruit_%s" % ["apple", "orange", "mango"][i % 3])

func _workshop(pos: Vector3) -> void:
    _building("WORKSHOP", pos, Vector3(5, 3.2, 4), Color("#7e8795"))
    var label := _label(pos + Vector3(0, 3.7, 0), "BROKEN WORKSHOP  •  REQUIRES TOOLS")
    label.name = "BrokenWorkshopLabel"
    var board := MeshInstance3D.new()
    board.name = "BrokenWorkshopBoard"
    var board_mesh := BoxMesh.new()
    board_mesh.size = Vector3(2.4, 0.22, 0.18)
    board.mesh = board_mesh
    board.position = pos + Vector3(0.5, 0.75, -2.2)
    board.rotation_degrees.z = 18
    board.material_override = _mat(Color("#6e4c35"))
    add_child(board)

func _riverland_approach(pos: Vector3) -> void:
    var water := MeshInstance3D.new()
    water.name = "RiverWater"
    var water_mesh := BoxMesh.new()
    water_mesh.size = Vector3(42, 0.08, 10)
    water.mesh = water_mesh
    water.position = pos + Vector3(-5, 0.06, 0)
    var water_material := StandardMaterial3D.new()
    water_material.albedo_color = Color("#3f9fb7", 0.82)
    water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water_material.roughness = 0.24
    water_material.metallic = 0.08
    water.material_override = water_material
    add_child(water)
    for i in range(8):
        var ripple := MeshInstance3D.new()
        var ripple_mesh := BoxMesh.new()
        ripple_mesh.size = Vector3(1.2 + float(i % 3) * 0.4, 0.015, 0.035)
        ripple.mesh = ripple_mesh
        ripple.position = pos + Vector3(-23 + i * 5.0, 0.12, -3.0 + float(i % 2) * 5.0)
        ripple.material_override = _mat(Color("#a1dce5", 0.55))
        add_child(ripple)
    _path(pos + Vector3(0, 0, 5), Vector3(1, 0, 0), 12)
    var bridge_label := _label(pos + Vector3(0, 2.5, 0), "BLOCKED PATH  •  REQUIRES BRIDGE")
    bridge_label.name = "RiverBridgeRequirementLabel"
    var bridge := StaticBody3D.new()
    bridge.name = "BrokenBridge"
    bridge.position = pos
    add_child(bridge)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(7, 0.45, 3)
    shape.shape = box
    shape.position.y = 0.5
    bridge.add_child(shape)
    var mesh := MeshInstance3D.new()
    var plank := BoxMesh.new()
    plank.size = Vector3(7, 0.45, 3)
    mesh.mesh = plank
    mesh.position.y = 0.5
    mesh.material_override = _mat(Color("#56616b"))
    bridge.add_child(mesh)

func _cave_approach(pos: Vector3) -> void:
    var cave_label := _label(pos, "CAVE  •  REQUIRES LANTERN")
    cave_label.name = "CaveRequirementLabel"
    var rock := MeshInstance3D.new()
    rock.name = "CaveEntranceRock"
    var sphere := SphereMesh.new()
    sphere.radius = 4.0
    sphere.height = 6.0
    rock.mesh = sphere
    rock.position = pos + Vector3(0, 2, 0)
    rock.material_override = _mat(Color("#4d5660"))
    add_child(rock)

func _field(pos: Vector3) -> void:
    var plot := MeshInstance3D.new()
    plot.name = "EmptyField"
    var plot_mesh := BoxMesh.new()
    plot_mesh.size = Vector3(10, 0.22, 7)
    plot.mesh = plot_mesh
    plot.position = pos + Vector3(0, 0.05, 0)
    plot.material_override = _mat(Color("#8b6a4b"))
    add_child(plot)
    for row in range(5):
        var furrow := MeshInstance3D.new()
        var furrow_mesh := BoxMesh.new()
        furrow_mesh.size = Vector3(8.8, 0.035, 0.08)
        furrow.mesh = furrow_mesh
        furrow.position = pos + Vector3(0, 0.18, -2.4 + row * 1.2)
        furrow.material_override = _mat(Color("#5c4937"))
        add_child(furrow)
    var label := _label(pos + Vector3(0, 2.3, 0), "EMPTY FIELD  •  REQUIRES SEEDS")
    label.name = "EmptyFieldLabel"

func _boat(pos: Vector3) -> void:
    var boat := Node3D.new()
    boat.name = "DamagedBoat"
    boat.position = pos
    add_child(boat)
    var hull := MeshInstance3D.new()
    var hull_mesh := BoxMesh.new()
    hull_mesh.size = Vector3(3.2, 0.55, 1.25)
    hull.mesh = hull_mesh
    hull.position.y = 0.45
    hull.rotation_degrees.z = -8
    hull.material_override = _mat(Color("#77513a"))
    boat.add_child(hull)
    var broken_board := MeshInstance3D.new()
    var board_mesh := BoxMesh.new()
    board_mesh.size = Vector3(1.0, 0.12, 0.25)
    broken_board.mesh = board_mesh
    broken_board.position = Vector3(0.2, 0.85, 0.1)
    broken_board.rotation_degrees.z = 28
    broken_board.material_override = _mat(Color("#b88958"))
    boat.add_child(broken_board)
    var label := _label(pos + Vector3(0, 2.0, 0), "DAMAGED BOAT  •  REQUIRES ENGINE")
    label.name = "DamagedBoatLabel"

func _storage(pos: Vector3) -> void:
    var storage := Node3D.new()
    storage.name = "LockedStorage"
    storage.position = pos
    add_child(storage)
    var crate := MeshInstance3D.new()
    var crate_mesh := BoxMesh.new()
    crate_mesh.size = Vector3(2.2, 1.6, 1.6)
    crate.mesh = crate_mesh
    crate.position.y = 0.8
    crate.material_override = _mat(Color("#8b633f"))
    storage.add_child(crate)
    var lock := MeshInstance3D.new()
    lock.name = "Lock"
    var lock_mesh := BoxMesh.new()
    lock_mesh.size = Vector3(0.3, 0.42, 0.12)
    lock.mesh = lock_mesh
    lock.position = Vector3(0, 0.85, -0.86)
    lock.material_override = _mat(Color("#d5b34e"))
    storage.add_child(lock)
    var label := _label(pos + Vector3(0, 2.1, 0), "LOCKED STORAGE  •  REQUIRES KEY")
    label.name = "LockedStorageLabel"

func _repair_bridge_approach(pos: Vector3) -> void:
    var bridge := Node3D.new()
    bridge.name = "BrokenFootbridge"
    bridge.position = pos
    add_child(bridge)
    for i in range(4):
        var plank := MeshInstance3D.new()
        var plank_mesh := BoxMesh.new()
        plank_mesh.size = Vector3(2.4, 0.18, 0.55)
        plank.mesh = plank_mesh
        plank.position = Vector3(-1.8 + i * 1.2, 0.25 + (0.18 if i == 2 else 0.0), 0)
        plank.rotation_degrees.z = 5 if i % 2 == 0 else -4
        plank.material_override = _mat(Color("#77513a"))
        bridge.add_child(plank)
    var label := _label(pos + Vector3(0, 2.0, 0), "BROKEN BRIDGE  •  REQUIRES REPAIR")
    label.name = "RepairBridgeLabel"

func _closed_dock(pos: Vector3) -> void:
    var dock := Node3D.new()
    dock.name = "ClosedDock"
    dock.position = pos
    add_child(dock)
    for i in range(5):
        var plank := MeshInstance3D.new()
        var plank_mesh := BoxMesh.new()
        plank_mesh.size = Vector3(1.1, 0.18, 4.0)
        plank.mesh = plank_mesh
        plank.position = Vector3(-2.2 + i * 1.1, 0.35, 0)
        plank.material_override = _mat(Color("#8b6544"))
        dock.add_child(plank)
    var post := MeshInstance3D.new()
    var post_mesh := CylinderMesh.new()
    post_mesh.top_radius = 0.08
    post_mesh.bottom_radius = 0.12
    post_mesh.height = 1.6
    post.mesh = post_mesh
    post.position = Vector3(0, 0.8, -1.7)
    post.material_override = _mat(Color("#6c513b"))
    dock.add_child(post)
    var label := _label(pos + Vector3(0, 2.2, 0), "CLOSED DOCK  •  REQUIRES BOAT")
    label.name = "ClosedDockLabel"

func _old_gate(pos: Vector3) -> void:
    var gate := Node3D.new()
    gate.name = "LockedMeadowGate"
    gate.position = pos
    add_child(gate)
    for side in [-2.0, 2.0]:
        var post := MeshInstance3D.new()
        var post_mesh := BoxMesh.new()
        post_mesh.size = Vector3(0.35, 3.5, 0.35)
        post.mesh = post_mesh
        post.position = Vector3(side, 1.75, 0)
        post.material_override = _mat(Color("#725238"))
        gate.add_child(post)
    for i in range(5):
        var bar := MeshInstance3D.new()
        var bar_mesh := BoxMesh.new()
        bar_mesh.size = Vector3(0.18, 2.6, 0.18)
        bar.mesh = bar_mesh
        bar.position = Vector3(-1.6 + i * 0.8, 1.3, 0)
        bar.material_override = _mat(Color("#9b754b"))
        gate.add_child(bar)
    var label := _label(pos + Vector3(0, 4.1, 0), "OLD MEADOW GATE  •  REQUIRES GATE")
    label.name = "OldGateLabel"

func _dark_beacon(pos: Vector3) -> void:
    var beacon := Node3D.new()
    beacon.name = "DarkBeacon"
    beacon.position = pos
    add_child(beacon)
    var tower := MeshInstance3D.new()
    var tower_mesh := CylinderMesh.new()
    tower_mesh.top_radius = 0.5
    tower_mesh.bottom_radius = 0.8
    tower_mesh.height = 3.6
    tower.mesh = tower_mesh
    tower.position.y = 1.8
    tower.material_override = _mat(Color("#555b61"))
    beacon.add_child(tower)
    var lamp := MeshInstance3D.new()
    lamp.name = "BeaconLamp"
    var lamp_mesh := SphereMesh.new()
    lamp_mesh.radius = 0.38
    lamp_mesh.height = 0.76
    lamp.mesh = lamp_mesh
    lamp.position.y = 3.8
    lamp.material_override = _mat(Color("#35383b"))
    beacon.add_child(lamp)
    var label := _label(pos + Vector3(0, 5.1, 0), "DARK BEACON  •  REQUIRES LIGHT")
    label.name = "DarkBeaconLabel"

func _locked_gate(pos: Vector3) -> void:
    var gate := StaticBody3D.new()
    gate.name = "LockedGarden"
    gate.position = pos
    add_child(gate)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(4, 3, 0.6)
    shape.shape = box
    shape.position.y = 1.5
    gate.add_child(shape)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3(4, 3, 0.6)
    mesh.mesh = cube
    mesh.position.y = 1.5
    mesh.material_override = _mat(Color("#48535d"))
    gate.add_child(mesh)
    _label(pos + Vector3(0, 3.4, 0), "REQUIRES: LADDER")

func _build_landmarks() -> void:
    _label(Vector3(18, 2, 5), "FOREST  →")
    _label(Vector3(-18, 2, -16), "RIVERLANDS  →")
    _label(Vector3(18, 2, -25), "ORCHARD  →")
    _label(Vector3(-21, 2, 8), "FARMLAND  →")

func _build_trees() -> void:
    for p in [Vector3(7, 0, -5), Vector3(14, 0, -5), Vector3(17, 0, -12), Vector3(-6, 0, -7), Vector3(-12, 0, 1), Vector3(-17, 0, -10), Vector3(5, 0, 8)]:
        _tree(p)

func _spawn_basic_resources() -> void:
    var resource_data := [
        [Vector3(-4, 0, 9), "wood", 2, "Wood"],
        [Vector3(-7, 0, 7), "wood", 1, "Wood"],
        [Vector3(5, 0, -2), "stone", 2, "Stone"],
        [Vector3(-14, 0, 6), "stone", 1, "Stone"]
    ]
    var script = preload("res://world/harvesting/harvest_node.gd")
    for item in resource_data:
        var node: HarvestNode = script.new()
        add_child(node)
        node.global_position = item[0]
        node.resource_id = "starter_%s_%d" % [str(item[1]), resource_nodes.size()]
        node.setup(str(item[1]), int(item[2]), str(item[3]))
        node.harvested.connect(_on_resource_harvested)
        node.state_changed.connect(_on_resource_state_changed)
        resource_nodes.append(node)

func _building(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.name = id
    body.position = pos
    add_child(body)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position.y = size.y / 2.0
    body.add_child(shape)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    mesh.position.y = size.y / 2.0
    mesh.material_override = _mat(color)
    body.add_child(mesh)

func _path(pos: Vector3, _dir: Vector3, length: float) -> void:
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3(3, 0.08, length)
    mesh.mesh = cube
    mesh.position = pos
    mesh.material_override = _mat(Color("#c6b58c"))
    add_child(mesh)

func _tree(pos: Vector3) -> void:
    var root := Node3D.new()
    root.position = pos
    add_child(root)
    var trunk := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.22
    cylinder.bottom_radius = 0.32
    cylinder.height = 2.2
    trunk.mesh = cylinder
    trunk.position.y = 1.1
    trunk.material_override = _mat(Color("#76533a"))
    root.add_child(trunk)
    var crown := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.25
    sphere.height = 2.4
    crown.mesh = sphere
    crown.position.y = 2.5
    crown.material_override = _mat(Color("#4f8d5b"))
    root.add_child(crown)

func _fruit_tree(pos: Vector3, item_id: String) -> void:
    _tree(pos)
    var fruit: HarvestNode = preload("res://world/harvesting/harvest_node.gd").new()
    add_child(fruit)
    fruit.global_position = pos
    var fruit_name := item_id.replace("fruit_", "").capitalize()
    fruit.resource_id = "fruit_%s_%d_%d" % [item_id, int(pos.x), int(pos.z)]
    fruit.setup(item_id, 1, fruit_name)
    fruit.set_available(false)
    fruit.harvested.connect(_on_resource_harvested)
    fruit.state_changed.connect(_on_resource_state_changed)
    fruit_nodes.append(fruit)

func try_interact(player: AlphaCrushPlayer) -> void:
    if player == null:
        return
    var nearest: LetterObject = null
    var best := 2.8
    for node in letters:
        if is_instance_valid(node):
            var distance := player.global_position.distance_to(node.global_position)
            if distance < best:
                best = distance
                nearest = node
    if nearest:
        var l := str(nearest.letter)
        if word_system.collect_letter(l):
            player.carry_letter(nearest)
            letters.erase(nearest)
            discovery_message.emit("Collected physical letter %s" % l)
            return
    for node in resource_nodes:
        if is_instance_valid(node) and player.global_position.distance_to(node.global_position) < 2.4 and node.has_method("try_harvest"):
            if node.try_harvest(inventory):
                return
    for node in fruit_nodes:
        if is_instance_valid(node) and player.global_position.distance_to(node.global_position) < 2.4 and node.has_method("try_harvest"):
            if node.try_harvest(inventory):
                return
    _interact_with_world(player)

func release_collected_letter(letter_value: String) -> void:
    if word_system:
        word_system.release_letter(letter_value)

func register_dropped_letter(letter: Node) -> void:
    if letter == null or not is_instance_valid(letter):
        return
    if not letters.has(letter):
        letters.append(letter)
        if not current_word_letters.has(letter):
            current_word_letters.append(letter)

func _interact_with_world(player: AlphaCrushPlayer) -> void:
    for npc in get_children():
        if npc is HumanNPCAgent and player.global_position.distance_to(npc.global_position) < 2.6:
            if npc.has_method("interact"):
                npc.interact()
            return
    var gate := get_node_or_null("LockedGarden")
    if gate and player.global_position.distance_to(gate.global_position) < 4.5:
        discovery_message.emit("REQUIRES LADDER — the clue is in the world. Collect every physical letter.")
        return
    if garden_unlocked and player.global_position.distance_to(GARDEN_POS) < 9:
        if world_state.get_state("garden_development") == "ACTIVE":
            if economy.upgrade("garden"):
                world_state.set_state("garden_development", "UPGRADED")
                _build_garden_upgrade_visual()
                discovery_message.emit("Garden upgrade built. Production is improved!")
            else:
                discovery_message.emit("Garden blueprint ready. Earn more coins at the MARKET to build it.")
        elif world_state.get_state("garden_development") == "UPGRADED":
            discovery_message.emit("Your garden is upgraded. Keep exploring for new opportunities.")
        else:
            _resume_garden_progression()
        return
    if player.global_position.distance_to(MARKET_POS) < 6:
        _market_interaction()
        return
    if player.global_position.distance_to(WORKSHOP_POS) < 6:
        if not world_state.is_complete("workshop"):
            _discover_word_site("workshop", "Broken Workshop", "TOOLS", WORKSHOP_POS, "workshop")
        else:
            crafting_requested.emit()
            discovery_message.emit("Workshop opened. Craft useful gear from gathered materials.")
        return
    if player.global_position.distance_to(FIELD_POS) < 6:
        _field_interaction()
        return
    if player.global_position.distance_to(BOAT_POS) < 6:
        _boat_interaction()
        return
    if player.global_position.distance_to(STORAGE_POS) < 5:
        _storage_interaction()
        return
    if player.global_position.distance_to(REPAIR_BRIDGE_POS) < 6:
        _repair_bridge_interaction()
        return
    if player.global_position.distance_to(DOCK_POS) < 6:
        _dock_interaction()
        return
    if player.global_position.distance_to(OLD_GATE_POS) < 6:
        _old_gate_interaction()
        return
    if player.global_position.distance_to(BEACON_POS) < 6:
        _beacon_interaction()
        return
    if player.global_position.distance_to(COMMUNITY_HALL_POS) < 7:
        _community_hall_interaction()
        return
    if player.global_position.distance_to(RIVER_GATE_POS) < 6:
        _river_interaction()
        return
    if player.global_position.distance_to(CAVE_SIGN_POS) < 7:
        _cave_interaction()
        return

func _resume_garden_progression() -> void:
    if not world_state.is_complete("orange_harvest"):
        _start_word("ORANGE", [Vector3(7, 1, -8), Vector3(12, 1, -12), Vector3(16, 1, -7), Vector3(9, 1, -15), Vector3(5, 1, -12), Vector3(14, 1, -15)])
        discovery_message.emit("The garden is dormant. Assemble ORANGE to activate harvesting.")
    elif not world_state.is_complete("basket_upgrade"):
        _start_word("BASKET", [Vector3(3, 1, -2), Vector3(6, 1, 2), Vector3(-4, 1, -5), Vector3(15, 1, -3), Vector3(-8, 1, 4), Vector3(4, 1, 7)])
        discovery_message.emit("The harvest needs capacity. Assemble BASKET to carry more.")
    elif not world_state.is_complete("market"):
        _start_word("MARKET", [Vector3(-4, 1, -8), Vector3(-14, 1, -5), Vector3(-7, 1, 4), Vector3(3, 1, 5), Vector3(-17, 1, 2), Vector3(8, 1, -4)])
        discovery_message.emit("The harvest needs a buyer. Assemble MARKET to unlock selling.")
    elif not world_state.is_complete("garden_development"):
        _start_word("UPGRADE", [Vector3(15, 1, 6), Vector3(19, 1, 9), Vector3(12, 1, 12), Vector3(23, 1, 4), Vector3(8, 1, 7), Vector3(20, 1, 13), Vector3(16, 1, -1)])
        discovery_message.emit("Production can improve. Assemble UPGRADE to unlock the garden blueprint.")
    else:
        discovery_message.emit("Garden production is established. Explore nearby landmarks for new opportunities.")

func _market_interaction() -> void:
    if not market_open:
        if word_system.active_word != "MARKET" and word_system.active_word != "OPEN":
            _discover_word_site("closed_market", "Closed Market", "OPEN", MARKET_POS, "starter_village")
        else:
            discovery_message.emit("The market is closed. Finish assembling %s." % word_system.active_word)
        return
    if market_orders and market_orders.can_fulfill():
        var order_payout := market_orders.fulfill()
        if order_payout > 0:
            progression.grant(35)
            daily.progress("daily_harvest", 1)
            discovery_message.emit("ORDER FULFILLED • +%d coins" % order_payout)
            return
    var sale := 0
    for item in ["fruit_apple", "fruit_orange", "fruit_mango", "crop_wheat", "wood", "stone", "ore"]:
        var amount := inventory.count(item)
        if amount > 0:
            sale += economy.sell(item, amount)
    if sale > 0:
        progression.grant(20)
        daily.progress("daily_harvest", 1)
        discovery_message.emit("Marketplace sale complete: +%d coins" % sale)
    elif market_orders and not market_orders.active_order.is_empty():
        discovery_message.emit("MARKET ORDER • Bring %d %s" % [int(market_orders.active_order.get("amount", 0)), str(market_orders.active_order.get("title", "goods"))])
    else:
        discovery_message.emit("Marketplace is open. Bring resources here to sell.")

func _river_interaction() -> void:
    if not world_state.is_complete("river_bridge"):
        discovery.discover("river_bridge", "Broken Bridge")
        if opportunities:
            opportunities.register("river_bridge", "Broken Bridge", "BRIDGE", RIVER_GATE_POS, "riverlands")
        if map_manager: map_manager.discover("river_bridge", RIVER_GATE_POS, "Broken Bridge", "riverlands")
        if word_system.active_word != "BRIDGE":
            _start_word("BRIDGE", [Vector3(-16, 1, -13), Vector3(-20, 1, -8), Vector3(-24, 1, -20), Vector3(-28, 1, -17), Vector3(-14, 1, -20), Vector3(-23, 1, -12)])
        discovery_message.emit("Broken Bridge discovered. REQUIREMENT: BRIDGE")
        objective_changed.emit("REPAIR THE PATH", "Find BRIDGE letters in the riverlands.")
    else:
        discovery_message.emit("The bridge is restored. New regions are reachable.")

func _cave_interaction() -> void:
    discovery.discover("cave", "Whispering Cave")
    if opportunities:
        opportunities.register("cave", "Whispering Cave", "LANTERN", CAVE_SIGN_POS, "caves")
    if map_manager: map_manager.discover("cave", CAVE_SIGN_POS, "Whispering Cave", "caves")
    if not world_state.is_complete("cave_light") and word_system.active_word != "LANTERN":
        _start_word("LANTERN", [Vector3(15, 1, -22), Vector3(19, 1, -26), Vector3(23, 1, -30), Vector3(28, 1, -26), Vector3(24, 1, -20), Vector3(18, 1, -31), Vector3(31, 1, -24)])
    discovery_message.emit("The cave is dark. REQUIREMENT: LANTERN")
    objective_changed.emit("LIGHT THE CAVE", "Find the LANTERN letters.")

func apply_word_consequence(word: String) -> void:
    var normalized := word.to_upper()
    if world_authority and NetworkStatus.is_online(self):
        var object_id := "word_%s" % normalized.to_lower()
        if multiplayer.is_server():
            world_authority.commit(object_id, "COMPLETE")
        else:
            world_authority.request(object_id, "COMPLETE")
        return
    _apply_word_consequence_local(normalized)

func apply_word_consequence_from_authority(object_id: String) -> void:
    var prefix := "word_"
    if not object_id.begins_with(prefix):
        return
    var normalized := object_id.substr(prefix.length()).to_upper()
    if completed_words.has(normalized):
        return
    _apply_word_consequence_local(normalized)

func _apply_word_consequence_local(normalized: String) -> void:
    completed_words[normalized] = true
    word_progress.erase(normalized)
    world_state.set_state("word_%s" % normalized.to_lower(), "COMPLETE")
    if opportunities:
        for id in opportunities.opportunities.keys():
            if str(opportunities.opportunities[id].get("requirement", "")) == normalized:
                opportunities.complete(str(id))
    match normalized:
        "LADDER": _complete_ladder()
        "ORANGE": _complete_orange()
        "BASKET": _complete_basket()
        "MARKET": _complete_market()
        "BRIDGE": _complete_bridge()
        "SEEDS": _complete_seeds()
        "TOOLS": _complete_tools()
        "LANTERN": _complete_lantern()
        "BOAT": _complete_boat_route()
        "ENGINE": _complete_engine()
        "GATE": _complete_old_gate()
        "LIGHT": _complete_beacon_light()
        "KEY": _complete_key()
        "OPEN": _complete_market()
        "REPAIR": _complete_repair()
        "UPGRADE": _complete_upgrade()
        "TOGETHER": _complete_together()
        "FOREST", "WATER", "HARVEST", "BUILD", "FRIEND", "EXPLORE", "FESTIVAL", "FUTURE": _complete_postgame_word(normalized)
        _:
            world_state.set_state("word_%s" % normalized.to_lower(), "COMPLETE")

func _postgame_anchors(word: String) -> Array:
    var base := Vector3(-18, 1, -12)
    var anchors: Array = []
    for i in range(word.length()):
        var angle := float(i) / maxf(1.0, float(word.length())) * TAU
        anchors.append(base + Vector3(cos(angle) * 7.0, 0, sin(angle) * 5.0))
    return anchors

func _complete_postgame_word(word: String) -> void:
    world_state.set_state("postgame_%s" % word.to_lower(), "COMPLETE")
    if postgame:
        var challenge := postgame.complete_word(word)
        if not challenge.is_empty():
            discovery_message.emit("%s restored a little more of the world." % word)
    _clear_current_word()

func _community_hall(pos: Vector3) -> void:
    _building("COMMUNITY_HALL", pos, Vector3(7, 3.8, 5), Color("#8f98a8"))
    _label(pos + Vector3(0, 4.3, 0), "COMMUNITY HALL")
    var banner := MeshInstance3D.new()
    var banner_mesh := BoxMesh.new()
    banner_mesh.size = Vector3(4.6, 1.2, 0.12)
    banner.mesh = banner_mesh
    banner.position = pos + Vector3(0, 2.7, -2.6)
    banner.material_override = _mat(Color("#e0b65d"))
    add_child(banner)

func _community_hall_interaction() -> void:
    if campaign == null:
        discovery_message.emit("The Community Hall is waiting for the village story to unfold.")
        return
    if campaign.finale_ready and not campaign.finale_done:
        if word_system.active_word != "TOGETHER":
            _start_word("TOGETHER", [Vector3(-8, 1, -12), Vector3(-4, 1, -16), Vector3(2, 1, -18), Vector3(7, 1, -13), Vector3(10, 1, -8), Vector3(4, 1, -10), Vector3(-1, 1, -6), Vector3(-10, 1, -7)])
        discovery_message.emit("Everyone has helped restore the world. Find the letters of TOGETHER.")
        objective_changed.emit("FINAL WORD", "Bring every restored community together at the Community Hall.")
        return
    if campaign.finale_done:
        if postgame:
            var challenge := postgame.next_challenge()
            _start_word(str(challenge["word"]), _postgame_anchors(str(challenge["word"])))
            discovery_message.emit("POSTGAME DISCOVERY • %s" % str(challenge["title"]))
            objective_changed.emit("POSTGAME", "Solve %s to earn a world reward." % str(challenge["word"]))
        else:
            discovery_message.emit("The celebration continues. The world is yours to explore without end.")
        return
    discovery_message.emit(campaign.postgame_status())

func _complete_together() -> void:
    world_state.set_state("community_united", "COMPLETE")
    if campaign:
        campaign.complete_finale()
    _build_finale_visual()
    objective_changed.emit("WORLD COMPLETE", "The world is restored. Explore, build, trade, and discover without end.")
    discovery_message.emit("TOGETHER changed everything. Alpha Crush is complete — and the world keeps growing.")
    _clear_current_word()

func _build_finale_visual() -> void:
    var existing := get_node_or_null("FinaleCelebration")
    if existing:
        return
    var root := Node3D.new()
    root.name = "FinaleCelebration"
    root.position = COMMUNITY_HALL_POS + Vector3(0, 0.2, 0)
    add_child(root)
    for i in range(12):
        var light := OmniLight3D.new()
        light.omni_range = 8.0
        light.light_energy = 2.0
        light.position = Vector3(cos(float(i) * TAU / 12.0) * 5.0, 2.2, sin(float(i) * TAU / 12.0) * 3.5)
        root.add_child(light)
    for i in range(8):
        var pillar := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.16
        mesh.bottom_radius = 0.22
        mesh.height = 2.0
        pillar.mesh = mesh
        pillar.position = Vector3(-3.5 + i, 1.0, 2.8)
        pillar.material_override = _mat(Color("#d9c06d"))
        root.add_child(pillar)
    _label(COMMUNITY_HALL_POS + Vector3(0, 5.0, 0), "ALPHA CRUSH • TOGETHER")

func _complete_ladder() -> void:
    ladder_built = true
    garden_unlocked = true
    world_state.set_state("garden_gate", "COMPLETE")
    var gate := get_node_or_null("LockedGarden")
    if gate:
        gate.queue_free()
    _ladder(Vector3(9, 0, -6))
    discovery.discover("orchard_garden", "Elevated Garden")
    objective_changed.emit("DISCOVER", "The garden needs a harvest variety. Find the ORANGE word letters.")
    discovery_message.emit("LADDER assembled. The garden is open — but something is still dormant.")
    _start_word("ORANGE", [Vector3(7, 1, -8), Vector3(12, 1, -12), Vector3(16, 1, -7), Vector3(9, 1, -15), Vector3(5, 1, -12), Vector3(14, 1, -15)])

func _complete_orange() -> void:
    garden_harvest_active = true
    world_state.set_state("orange_harvest", "ACTIVE")
    for node in fruit_nodes:
        if is_instance_valid(node) and str(node.item_id) == "fruit_orange":
            node.set_available(true)
    discovery_message.emit("ORANGE complete. The orchard fruit is ready to harvest.")
    objective_changed.emit("HARVEST", "Harvest the orchard, then find the BASKET letters to carry more.")
    _start_word("BASKET", [Vector3(3, 1, -2), Vector3(6, 1, 2), Vector3(-4, 1, -5), Vector3(15, 1, -3), Vector3(-8, 1, 4), Vector3(4, 1, 7)])

func _complete_basket() -> void:
    world_state.set_state("basket_upgrade", "COMPLETE")
    inventory.increase_capacity(12)
    inventory.add_item("basket", 1)
    for node in fruit_nodes:
        if is_instance_valid(node):
            node.set_available(true)
    discovery_message.emit("BASKET complete. Your harvest capacity is improved.")
    objective_changed.emit("DEVELOP", "Use the market to sell resources, then explore the next world problem.")
    _start_word("MARKET", [Vector3(-4, 1, -8), Vector3(-14, 1, -5), Vector3(-7, 1, 4), Vector3(3, 1, 5), Vector3(-17, 1, 2), Vector3(8, 1, -4)])

func _build_open_market_visual() -> void:
    var shutter := get_node_or_null("MarketShutter")
    if shutter:
        shutter.queue_free()
    var closed_label := get_node_or_null("ClosedMarketLabel")
    if closed_label:
        closed_label.queue_free()
    if get_node_or_null("OpenMarketLabel") == null:
        var open_label := _label(MARKET_POS + Vector3(0, 3.6, 0), "MARKET OPEN  •  SELL")
        open_label.name = "OpenMarketLabel"

func _complete_market() -> void:
    market_open = true
    world_state.set_state("market", "ACTIVE")
    word_progress.erase("MARKET")
    word_progress.erase("OPEN")
    _build_open_market_visual()
    discovery_message.emit("MARKET activated. Trade resources and develop the village.")
    objective_changed.emit("DEVELOP", "Find the UPGRADE letters around the workshop, then keep exploring.")
    _start_word("UPGRADE", [Vector3(15, 1, 6), Vector3(19, 1, 9), Vector3(12, 1, 12), Vector3(23, 1, 4), Vector3(8, 1, 7), Vector3(20, 1, 13), Vector3(16, 1, -1)])

func _complete_bridge() -> void:
    world_state.set_state("river_bridge", "COMPLETE")
    var bridge := get_node_or_null("BrokenBridge")
    if bridge:
        bridge.queue_free()
    _bridge(Vector3(-22, 0, -18))
    discovery_message.emit("BRIDGE restored. The riverlands path is open.")
    objective_changed.emit("EXPLORE", "Cross the restored path and discover new regions.")
    _clear_current_word()

func _complete_lantern() -> void:
    world_state.set_state("cave_light", "ACTIVE")
    _build_cave_lighting()
    discovery_message.emit("LANTERN activated. Warm light spills into the cave; it is now safe to explore.")
    objective_changed.emit("EXPLORE", "Enter the cave and look for rare materials.")
    _clear_current_word()

func _complete_seeds() -> void:
    world_state.set_state("starter_field", "ACTIVE")
    _build_field_crops()
    discovery_message.emit("SEEDS planted. The empty field is now growing wheat you can harvest.")
    objective_changed.emit("HARVEST", "Gather wheat from the field and bring it to the market.")
    _clear_current_word()

func _complete_tools() -> void:
    world_state.set_state("workshop", "ACTIVE")
    _build_workshop_tools()
    discovery_message.emit("TOOLS restored the workshop. Crafting is now available.")
    _clear_current_word()

func _complete_engine() -> void:
    world_state.set_state("starter_boat", "ACTIVE")
    var damaged := get_node_or_null("DamagedBoat")
    if damaged:
        damaged.queue_free()
    var label := get_node_or_null("DamagedBoatLabel")
    if label:
        label.queue_free()
    _build_usable_boat()
    discovery_message.emit("ENGINE installed. The boat is ready for river exploration.")
    _clear_current_word()

func _complete_key() -> void:
    world_state.set_state("storage", "ACTIVE")
    _unlock_storage_visual()
    inventory.add_item("wood", 3)
    inventory.add_item("stone", 2)
    discovery_message.emit("KEY unlocked the storage. You found building materials inside.")
    _clear_current_word()

func _complete_repair() -> void:
    world_state.set_state("repaired_footbridge", "COMPLETE")
    var broken := get_node_or_null("BrokenFootbridge")
    if broken:
        broken.queue_free()
    var label := get_node_or_null("RepairBridgeLabel")
    if label:
        label.queue_free()
    if get_node_or_null("RepairedFootbridge") == null:
        _build_repaired_footbridge(REPAIR_BRIDGE_POS)
    discovery_message.emit("REPAIR completed the footbridge. The ravine crossing is stable.")
    _clear_current_word()

func _complete_upgrade() -> void:
    # The word unlocks the production upgrade. Currency gates the physical build,
    # so a player who has spent their coins can return after selling resources.
    world_state.set_state("garden_development", "ACTIVE")
    if economy.upgrade("garden"):
        world_state.set_state("garden_development", "UPGRADED")
        _build_garden_upgrade_visual()
        discovery_message.emit("UPGRADE complete. Your garden has visibly expanded.")
    else:
        discovery_message.emit("Garden upgrade blueprint unlocked. Sell resources at the MARKET, then return to build it.")
    objective_changed.emit("EXPLORE", "Travel beyond the starter village and discover new world situations.")
    _clear_current_word()

func _start_word(word: String, positions: Array) -> void:
    var target := word.to_upper()
    if word_system.has_active_word() and not word_system.is_complete():
        word_progress[word_system.active_word] = word_system.collected.duplicate(true)
    _clear_current_word()
    word_system.begin_word(target)
    var collected_counts: Dictionary = word_progress.get(target, {}).duplicate(true)
    word_system.collected = collected_counts.duplicate(true)
    _spawn_missing_letters(target, positions, collected_counts)

func _spawn_missing_letters(word: String, positions: Array, collected_counts: Dictionary) -> void:
    var player_node: AlphaCrushPlayer = null
    if get_parent():
        player_node = get_parent().get_node_or_null("Player") as AlphaCrushPlayer
    var remaining := collected_counts.duplicate(true)
    for i in range(word.length()):
        var c := word.substr(i, 1)
        var have := int(remaining.get(c, 0))
        if have > 0:
            remaining[c] = have - 1
            var carried_obj: LetterObject = preload("res://words/letters/letter_object.gd").new()
            add_child(carried_obj)
            carried_obj.global_position = positions[i % positions.size()]
            carried_obj.base_y = carried_obj.position.y
            carried_obj.setup(c)
            if player_node and player_node.has_method("carry_letter"):
                player_node.carry_letter(carried_obj)
            current_word_letters.append(carried_obj)
            continue
        var obj: LetterObject = preload("res://words/letters/letter_object.gd").new()
        add_child(obj)
        obj.global_position = positions[i % positions.size()]
        obj.base_y = obj.position.y
        obj.setup(c)
        letters.append(obj)
        current_word_letters.append(obj)

func _clear_current_word() -> void:
    for node in current_word_letters:
        if is_instance_valid(node):
            letters.erase(node)
            node.queue_free()
    current_word_letters.clear()
    var local_player := get_parent().get_node_or_null("Player") as AlphaCrushPlayer
    if local_player and local_player.has_method("clear_carried_letters"):
        local_player.clear_carried_letters()


func snapshot_word_progress() -> Dictionary:
    return word_progress.duplicate(true)

func restore_word_progress(value: Dictionary) -> void:
    word_progress = value.duplicate(true)

func snapshot_harvest_state() -> Dictionary:
    var result: Dictionary = {}
    for node in resource_nodes + fruit_nodes:
        if is_instance_valid(node) and not node.resource_id.is_empty():
            result[node.resource_id] = node.snapshot_state()
    return result

func restore_harvest_state(value: Dictionary) -> void:
    harvest_state = value.duplicate(true)

func _apply_harvest_state() -> void:
    for node in resource_nodes + fruit_nodes:
        if is_instance_valid(node) and harvest_state.has(node.resource_id):
            var saved_state: Variant = harvest_state[node.resource_id]
            if saved_state is Dictionary:
                node.restore_state(saved_state)

func _on_resource_state_changed(resource_id: String, state: String) -> void:
    if resource_id.is_empty():
        return
    world_state.set_state("resource_%s" % resource_id, state)

func resume_saved_word(word: String) -> void:
    if word.is_empty() or word_system.is_complete():
        return
    var anchors := {
        "LADDER": [Vector3(-2, 1, -1), Vector3(3, 1, -2), Vector3(-5, 1, -4), Vector3(5, 1, 3), Vector3(-8, 1, 4), Vector3(8, 1, 1)],
        "ORANGE": [Vector3(7, 1, -8), Vector3(12, 1, -12), Vector3(16, 1, -7), Vector3(9, 1, -15), Vector3(5, 1, -12), Vector3(14, 1, -15)],
        "BASKET": [Vector3(3, 1, -2), Vector3(6, 1, 2), Vector3(-4, 1, -5), Vector3(15, 1, -3), Vector3(-8, 1, 4), Vector3(4, 1, 7)],
        "MARKET": [Vector3(-4, 1, -8), Vector3(-14, 1, -5), Vector3(-7, 1, 4), Vector3(3, 1, 5), Vector3(-17, 1, 2), Vector3(8, 1, -4)],
        "BRIDGE": [Vector3(-16, 1, -13), Vector3(-20, 1, -8), Vector3(-24, 1, -20), Vector3(-28, 1, -17), Vector3(-14, 1, -20), Vector3(-23, 1, -12)],
        "LANTERN": [Vector3(15, 1, -22), Vector3(19, 1, -26), Vector3(23, 1, -30), Vector3(28, 1, -26), Vector3(24, 1, -20), Vector3(18, 1, -31), Vector3(31, 1, -24)],
        "OPEN": [Vector3(-4, 1, -8), Vector3(-14, 1, -5), Vector3(-7, 1, 4), Vector3(3, 1, 5)],
        "SEEDS": [Vector3(-18, 1, 9), Vector3(-22, 1, 10), Vector3(-25, 1, 13), Vector3(-18, 1, 15), Vector3(-23, 1, 16)],
        "TOOLS": [Vector3(15, 1, 6), Vector3(19, 1, 9), Vector3(12, 1, 12), Vector3(23, 1, 4), Vector3(8, 1, 7)],
        "ENGINE": [Vector3(-29, 1, -7), Vector3(-33, 1, -10), Vector3(-28, 1, -12), Vector3(-34, 1, -5), Vector3(-31, 1, -14), Vector3(-26, 1, -9)],
        "KEY": [Vector3(-12, 1, 8), Vector3(-17, 1, 12), Vector3(-14, 1, 14)],
        "REPAIR": [Vector3(-33, 1, -28), Vector3(-38, 1, -31), Vector3(-34, 1, -34), Vector3(-40, 1, -27), Vector3(-30, 1, -32), Vector3(-36, 1, -24)],
        "BOAT": [Vector3(-8, 1, -23), Vector3(-11, 1, -27), Vector3(-6, 1, -29), Vector3(-14, 1, -24)],
        "GATE": [Vector3(29, 1, 15), Vector3(35, 1, 16), Vector3(31, 1, 21), Vector3(38, 1, 18)],
        "LIGHT": [Vector3(28, 1, -33), Vector3(33, 1, -39), Vector3(36, 1, -34), Vector3(30, 1, -42), Vector3(39, 1, -38)],
        "UPGRADE": [Vector3(15, 1, 6), Vector3(19, 1, 9), Vector3(12, 1, 12), Vector3(23, 1, 4), Vector3(8, 1, 7), Vector3(20, 1, 13), Vector3(16, 1, -1)]
        ,"TOGETHER": [Vector3(-8, 1, -12), Vector3(-4, 1, -16), Vector3(2, 1, -18), Vector3(7, 1, -13), Vector3(10, 1, -8), Vector3(4, 1, -10), Vector3(-1, 1, -6), Vector3(-10, 1, -7)]
        ,"FOREST": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12), Vector3(-6,1,-7)]
        ,"WATER": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12)]
        ,"HARVEST": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12), Vector3(-6,1,-7), Vector3(-10,1,-7)]
        ,"BUILD": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12)]
        ,"FRIEND": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12), Vector3(-6,1,-7)]
        ,"EXPLORE": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12), Vector3(-6,1,-7), Vector3(-10,1,-7)]
        ,"FESTIVAL": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12), Vector3(-6,1,-7), Vector3(-10,1,-7), Vector3(-14,1,-7)]
        ,"FUTURE": [Vector3(-18,1,-12), Vector3(-14,1,-17), Vector3(-10,1,-12), Vector3(-6,1,-17), Vector3(-2,1,-12), Vector3(-6,1,-7)]
    }
    if anchors.has(word):
        _clear_current_word()
        _spawn_missing_letters(word, anchors[word], word_system.collected)

func apply_persistent_state() -> void:
    if campaign and campaign.finale_done:
        _build_finale_visual()
    completed_words = word_system.completed_words.duplicate(true)
    for object_id in world_state.states.keys():
        var id_text := str(object_id)
        if id_text.begins_with("word_") and world_state.is_complete(id_text):
            completed_words[id_text.substr(5).to_upper()] = true
    garden_unlocked = world_state.is_complete("garden_gate")
    ladder_built = garden_unlocked
    market_open = world_state.is_complete("market")
    if market_open:
        _build_open_market_visual()
    if garden_unlocked:
        var gate := get_node_or_null("LockedGarden")
        if gate:
            gate.queue_free()
        if get_node_or_null("GardenLadder") == null:
            _ladder(Vector3(9, 0, -6))
    if world_state.is_complete("river_bridge"):
        var broken_bridge := get_node_or_null("BrokenBridge")
        if broken_bridge:
            broken_bridge.queue_free()
        var bridge_label := get_node_or_null("RiverBridgeRequirementLabel")
        if bridge_label:
            bridge_label.queue_free()
        if get_node_or_null("RestoredBridge") == null:
            _bridge(Vector3(-22, 0, -18))
    if world_state.is_complete("cave_light"):
        _build_cave_lighting()
    if world_state.is_complete("starter_field"):
        _build_field_crops()
    if world_state.is_complete("workshop"):
        _build_workshop_tools()
    if world_state.is_complete("starter_boat"):
        var damaged_boat := get_node_or_null("DamagedBoat")
        if damaged_boat:
            damaged_boat.queue_free()
        var damaged_label := get_node_or_null("DamagedBoatLabel")
        if damaged_label:
            damaged_label.queue_free()
        _build_usable_boat()
    if world_state.is_complete("storage"):
        _unlock_storage_visual()
    if world_state.is_complete("boat_route"):
        var closed_dock := get_node_or_null("ClosedDock")
        if closed_dock:
            closed_dock.queue_free()
        var closed_dock_label := get_node_or_null("ClosedDockLabel")
        if closed_dock_label:
            closed_dock_label.queue_free()
        _build_open_dock_visual()
    if world_state.is_complete("old_gate"):
        var old_gate := get_node_or_null("LockedMeadowGate")
        if old_gate:
            old_gate.queue_free()
        var old_gate_label := get_node_or_null("OldGateLabel")
        if old_gate_label:
            old_gate_label.queue_free()
        _build_meadow_gate_path_visual()
    if world_state.is_complete("beacon_light"):
        _build_beacon_light_visual()
    if world_state.is_complete("repaired_footbridge"):
        var broken_footbridge := get_node_or_null("BrokenFootbridge")
        if broken_footbridge:
            broken_footbridge.queue_free()
        var repair_label := get_node_or_null("RepairBridgeLabel")
        if repair_label:
            repair_label.queue_free()
        if get_node_or_null("RepairedFootbridge") == null:
            _build_repaired_footbridge(REPAIR_BRIDGE_POS)
    if world_state.is_complete("orange_harvest"):
        garden_harvest_active = true
        for node in fruit_nodes:
            if is_instance_valid(node) and str(node.item_id) == "fruit_orange":
                node.set_available(true)
    if world_state.is_complete("basket_upgrade"):
        for node in fruit_nodes:
            if is_instance_valid(node):
                node.set_available(true)
    if world_state.get_state("garden_development") == "UPGRADED":
        _build_garden_upgrade_visual()
    _apply_harvest_state()

func _discover_word_site(id: String, title: String, requirement: String, pos: Vector3, region: String) -> void:
    if discovery:
        discovery.discover(id, title)
    if opportunities:
        opportunities.register(id, title, requirement, pos, region)
    if map_manager:
        map_manager.discover(id, pos, title, region)
    var anchors: Dictionary = {
        "TOOLS": [Vector3(15, 1, 6), Vector3(19, 1, 9), Vector3(12, 1, 12), Vector3(23, 1, 4), Vector3(8, 1, 7)],
        "ENGINE": [Vector3(-29, 1, -7), Vector3(-33, 1, -10), Vector3(-28, 1, -12), Vector3(-34, 1, -5), Vector3(-31, 1, -14), Vector3(-26, 1, -9)],
        "KEY": [Vector3(-12, 1, 8), Vector3(-17, 1, 12), Vector3(-14, 1, 14)],
        "SEEDS": [Vector3(-18, 1, 9), Vector3(-22, 1, 10), Vector3(-25, 1, 13), Vector3(-18, 1, 15), Vector3(-23, 1, 16)],
        "REPAIR": [Vector3(-33, 1, -28), Vector3(-38, 1, -31), Vector3(-34, 1, -34), Vector3(-40, 1, -27), Vector3(-30, 1, -32), Vector3(-36, 1, -24)],
        "OPEN": [Vector3(-4, 1, -8), Vector3(-14, 1, -5), Vector3(-7, 1, 4), Vector3(3, 1, 5)],
        "BOAT": [Vector3(-8, 1, -23), Vector3(-11, 1, -27), Vector3(-6, 1, -29), Vector3(-14, 1, -24)],
        "GATE": [Vector3(29, 1, 15), Vector3(35, 1, 16), Vector3(31, 1, 21), Vector3(38, 1, 18)],
        "LIGHT": [Vector3(28, 1, -33), Vector3(33, 1, -39), Vector3(36, 1, -34), Vector3(30, 1, -42), Vector3(39, 1, -38)]
    }
    if anchors.has(requirement) and not world_state.is_complete(id):
        if word_system.active_word != requirement:
            _start_word(requirement, anchors[requirement])
        discovery_message.emit("%s discovered. REQUIREMENT: %s" % [title, requirement])
        objective_changed.emit("DISCOVER", "Find physical %s letters and assemble the word." % requirement)

func _field_interaction() -> void:
    if world_state.is_complete("starter_field"):
        discovery_message.emit("The field is growing. Harvest the wheat when it is ready.")
        return
    _discover_word_site("starter_field", "Empty Field", "SEEDS", FIELD_POS, "farmland")

func _boat_interaction() -> void:
    if world_state.is_complete("starter_boat"):
        discovery_message.emit("Your boat is repaired and ready for a future river expedition.")
        return
    _discover_word_site("damaged_boat", "Damaged Boat", "ENGINE", BOAT_POS, "riverlands")

func _storage_interaction() -> void:
    if world_state.is_complete("storage"):
        discovery_message.emit("The storage is open. You already collected its starter materials.")
        return
    _discover_word_site("locked_storage", "Locked Storage", "KEY", STORAGE_POS, "starter_village")

func _repair_bridge_interaction() -> void:
    if world_state.is_complete("repaired_footbridge"):
        discovery_message.emit("The footbridge is repaired and stable.")
        return
    _discover_word_site("broken_footbridge", "Broken Footbridge", "REPAIR", REPAIR_BRIDGE_POS, "riverlands")

func _dock_interaction() -> void:
    if world_state.is_complete("boat_route"):
        discovery_message.emit("The dock route is open. Repair the boat with ENGINE to prepare for a journey.")
        return
    _discover_word_site("closed_dock", "Closed River Dock", "BOAT", DOCK_POS, "riverlands")

func _old_gate_interaction() -> void:
    if world_state.is_complete("old_gate"):
        discovery_message.emit("The old gate is open. The meadow path is accessible.")
        return
    _discover_word_site("old_meadow_gate", "Old Meadow Gate", "GATE", OLD_GATE_POS, "starter_village")

func _beacon_interaction() -> void:
    if world_state.is_complete("beacon_light"):
        discovery_message.emit("The beacon is lit and marks this region after dark.")
        return
    _discover_word_site("dark_beacon", "Dark Beacon", "LIGHT", BEACON_POS, "caves")

func _complete_boat_route() -> void:
    world_state.set_state("boat_route", "ACTIVE")
    var dock := get_node_or_null("ClosedDock")
    if dock:
        dock.queue_free()
    var label := get_node_or_null("ClosedDockLabel")
    if label:
        label.queue_free()
    _build_open_dock_visual()
    discovery_message.emit("BOAT opened the river dock and unlocked a new travel route.")
    _clear_current_word()

func _build_open_dock_visual() -> void:
    if get_node_or_null("OpenDock"):
        return
    var open_dock := Node3D.new()
    open_dock.name = "OpenDock"
    open_dock.position = DOCK_POS
    add_child(open_dock)
    for i in range(5):
        var plank := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(1.1, 0.18, 4.0)
        plank.mesh = mesh
        plank.position = Vector3(-2.2 + i * 1.1, 0.35, 0)
        plank.material_override = _mat(Color("#b58b58"))
        open_dock.add_child(plank)
    var label_open := _label(DOCK_POS + Vector3(0, 2.2, 0), "RIVER DOCK OPEN")
    label_open.name = "OpenDockLabel"

func _complete_old_gate() -> void:
    world_state.set_state("old_gate", "ACTIVE")
    var gate := get_node_or_null("LockedMeadowGate")
    if gate:
        gate.queue_free()
    var label := get_node_or_null("OldGateLabel")
    if label:
        label.queue_free()
    _build_meadow_gate_path_visual()
    discovery_message.emit("GATE opened the old meadow and revealed a new route.")
    _clear_current_word()

func _build_meadow_gate_path_visual() -> void:
    if get_node_or_null("MeadowGatePath"):
        return
    var path := MeshInstance3D.new()
    path.name = "MeadowGatePath"
    var path_mesh := BoxMesh.new()
    path_mesh.size = Vector3(4.0, 0.08, 12.0)
    path.mesh = path_mesh
    path.position = OLD_GATE_POS + Vector3(0, 0.04, 6.0)
    path.material_override = _mat(Color("#c6b58c"))
    add_child(path)

func _complete_beacon_light() -> void:
    world_state.set_state("beacon_light", "ACTIVE")
    _build_beacon_light_visual()
    discovery_message.emit("LIGHT activated the beacon, illuminating the cave-side path.")
    _clear_current_word()

func _build_beacon_light_visual() -> void:
    var lamp := get_node_or_null("DarkBeacon/BeaconLamp") as MeshInstance3D
    if lamp:
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("#ffd17b")
        material.emission_enabled = true
        material.emission = Color("#ffb84d")
        material.emission_energy_multiplier = 2.5
        lamp.material_override = material
    if get_node_or_null("BeaconLight") == null:
        var light := OmniLight3D.new()
        light.name = "BeaconLight"
        light.position = BEACON_POS + Vector3(0, 4.0, 0)
        light.light_color = Color("#ffc76e")
        light.light_energy = 2.0
        light.omni_range = 22.0
        add_child(light)
    var label := get_node_or_null("DarkBeaconLabel")
    if label:
        label.queue_free()

func _build_field_crops() -> void:
    if field_crops_spawned:
        return
    field_crops_spawned = true
    var harvest_script = preload("res://world/harvesting/harvest_node.gd")
    for i in range(8):
        var crop: HarvestNode = harvest_script.new()
        crop.name = "FieldWheat_%02d" % i
        add_child(crop)
        crop.global_position = FIELD_POS + Vector3(-3.5 + float(i % 4) * 2.3, 0, -1.5 + floorf(float(i) / 4.0) * 2.5)
        crop.resource_id = "field_wheat_%02d" % i
        crop.setup("crop_wheat", 1, "Wheat")
        crop.set_available(true)
        crop.harvested.connect(_on_resource_harvested)
        crop.state_changed.connect(_on_resource_state_changed)
        resource_nodes.append(crop)

func _build_workshop_tools() -> void:
    var broken_label := get_node_or_null("BrokenWorkshopLabel")
    if broken_label:
        broken_label.queue_free()
    var broken_board := get_node_or_null("BrokenWorkshopBoard")
    if broken_board:
        broken_board.queue_free()
    if get_node_or_null("WorkshopOpenLabel") == null:
        var open_label := _label(WORKSHOP_POS + Vector3(0, 3.7, 0), "WORKSHOP OPEN  •  CRAFT")
        open_label.name = "WorkshopOpenLabel"
    if get_node_or_null("WorkshopTools"):
        return
    var rack := Node3D.new()
    rack.name = "WorkshopTools"
    rack.position = WORKSHOP_POS + Vector3(0, 0, 2.2)
    add_child(rack)
    for i in range(3):
        var handle := MeshInstance3D.new()
        var handle_mesh := CylinderMesh.new()
        handle_mesh.top_radius = 0.06
        handle_mesh.bottom_radius = 0.06
        handle_mesh.height = 1.0
        handle.mesh = handle_mesh
        handle.position = Vector3(-0.7 + i * 0.7, 0.6, 0)
        handle.rotation_degrees.z = 90
        handle.material_override = _mat(Color("#8a5c38"))
        rack.add_child(handle)
        var head := MeshInstance3D.new()
        var head_mesh := BoxMesh.new()
        head_mesh.size = Vector3(0.45, 0.18, 0.18)
        head.mesh = head_mesh
        head.position = Vector3(-0.7 + i * 0.7, 1.1, 0)
        head.material_override = _mat(Color("#9aa5b1"))
        rack.add_child(head)

func _build_cave_lighting() -> void:
    var cave_rock := get_node_or_null("CaveEntranceRock")
    if cave_rock:
        cave_rock.queue_free()
    var cave_label := get_node_or_null("CaveRequirementLabel")
    if cave_label:
        cave_label.queue_free()
    _build_cave_ore()
    if get_node_or_null("CaveLanternLight"):
        return
    var light := OmniLight3D.new()
    light.name = "CaveLanternLight"
    light.position = CAVE_SIGN_POS + Vector3(0, 2.5, -2.0)
    light.light_color = Color("#ffc66e")
    light.light_energy = 2.4
    light.omni_range = 18.0
    add_child(light)
    var crystal := MeshInstance3D.new()
    crystal.name = "CaveLanternCrystal"
    var crystal_mesh := SphereMesh.new()
    crystal_mesh.radius = 0.28
    crystal_mesh.height = 0.56
    crystal.mesh = crystal_mesh
    crystal.position = light.position
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#ffcc76")
    material.emission_enabled = true
    material.emission = Color("#ff9c38")
    material.emission_energy_multiplier = 2.0
    crystal.material_override = material
    add_child(crystal)

func _build_cave_ore() -> void:
    # The lit cave is where "rare materials" are found; ore feeds the lantern recipe and the
    # refined-ore market order, so it must actually be obtainable somewhere.
    if cave_ore_spawned:
        return
    cave_ore_spawned = true
    var harvest_script = preload("res://world/harvesting/harvest_node.gd")
    var offsets := [Vector3(-2.2, 0, -3.2), Vector3(0.4, 0, -4.0), Vector3(2.6, 0, -3.0)]
    for i in range(offsets.size()):
        var deposit: HarvestNode = harvest_script.new()
        deposit.name = "CaveOre_%02d" % i
        add_child(deposit)
        deposit.global_position = CAVE_SIGN_POS + offsets[i]
        deposit.resource_id = "cave_ore_%02d" % i
        deposit.setup("ore", 1, "Ore")
        deposit.set_available(true)
        deposit.harvested.connect(_on_resource_harvested)
        deposit.state_changed.connect(_on_resource_state_changed)
        resource_nodes.append(deposit)

func _build_usable_boat() -> void:
    if get_node_or_null("UsableBoat"):
        return
    var boat := Node3D.new()
    boat.name = "UsableBoat"
    boat.position = BOAT_POS
    add_child(boat)
    var hull := MeshInstance3D.new()
    var hull_mesh := BoxMesh.new()
    hull_mesh.size = Vector3(3.2, 0.55, 1.25)
    hull.mesh = hull_mesh
    hull.position.y = 0.45
    hull.material_override = _mat(Color("#a87949"))
    boat.add_child(hull)
    var motor := MeshInstance3D.new()
    var motor_mesh := CylinderMesh.new()
    motor_mesh.top_radius = 0.16
    motor_mesh.bottom_radius = 0.22
    motor_mesh.height = 0.7
    motor.mesh = motor_mesh
    motor.position = Vector3(-1.25, 0.85, 0)
    motor.material_override = _mat(Color("#66747e"))
    boat.add_child(motor)
    var label := _label(BOAT_POS + Vector3(0, 2, 0), "BOAT READY")
    label.name = "UsableBoatLabel"

func _unlock_storage_visual() -> void:
    var storage := get_node_or_null("LockedStorage")
    if storage:
        var lock := storage.get_node_or_null("Lock")
        if lock:
            lock.queue_free()
        var crate := storage.get_node_or_null("MeshInstance3D") as MeshInstance3D
        if crate:
            crate.material_override = _mat(Color("#b58a55"))
    var label := get_node_or_null("LockedStorageLabel")
    if label:
        label.queue_free()
    if get_node_or_null("UnlockedStorageLabel") == null:
        var unlocked_label := _label(STORAGE_POS + Vector3(0, 2.1, 0), "STORAGE OPEN")
        unlocked_label.name = "UnlockedStorageLabel"

func _build_repaired_footbridge(pos: Vector3) -> void:
    var bridge := StaticBody3D.new()
    bridge.name = "RepairedFootbridge"
    bridge.position = pos
    add_child(bridge)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(5.0, 0.35, 2.0)
    shape.shape = box
    shape.position.y = 0.3
    bridge.add_child(shape)
    var mesh := MeshInstance3D.new()
    var plank := BoxMesh.new()
    plank.size = Vector3(5.0, 0.35, 2.0)
    mesh.mesh = plank
    mesh.position.y = 0.3
    mesh.material_override = _mat(Color("#a87949"))
    bridge.add_child(mesh)

func _build_garden_upgrade_visual() -> void:
    if is_instance_valid(garden_upgrade_visual):
        return
    garden_upgrade_visual = Node3D.new()
    garden_upgrade_visual.name = "GardenUpgrade"
    garden_upgrade_visual.position = GARDEN_POS + Vector3(0, 0.4, 2.0)
    add_child(garden_upgrade_visual)
    var base := MeshInstance3D.new()
    var base_mesh := BoxMesh.new()
    base_mesh.size = Vector3(5.5, 0.25, 3.2)
    base.mesh = base_mesh
    base.material_override = _mat(Color("#5c7e5b"))
    garden_upgrade_visual.add_child(base)
    for x in [-2.3, 2.3]:
        var post := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.08
        cylinder.bottom_radius = 0.08
        cylinder.height = 2.4
        post.mesh = cylinder
        post.position = Vector3(x, 1.2, 0)
        post.material_override = _mat(Color("#d8c29a"))
        garden_upgrade_visual.add_child(post)
    var upgrade_label := _label(GARDEN_POS + Vector3(0, 4.0, 2.0), "UPGRADED GARDEN")
    upgrade_label.name = "GardenUpgradeLabel"

func assemble_word(word: String, at_position: Vector3) -> void:
    assembly.assemble(word, at_position)

func _on_resource_harvested(item_id: String, amount: int) -> void:
    harvest_count += amount
    resource_harvested.emit(item_id, amount)
    progression.grant(10 * amount)
    daily.progress("daily_harvest", amount)
    discovery_message.emit("Harvested %s x%d" % [item_id, amount])

func _ladder(pos: Vector3) -> void:
    var root := Node3D.new()
    root.name = "GardenLadder"
    root.position = pos
    add_child(root)
    for side in [-0.6, 0.6]:
        var mesh := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.08
        cylinder.bottom_radius = 0.08
        cylinder.height = 3.0
        mesh.mesh = cylinder
        mesh.position = Vector3(side, 1.5, 0)
        mesh.material_override = _mat(Color("#9a6a3a"))
        root.add_child(mesh)
    for i in range(5):
        var rung := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.06
        cylinder.bottom_radius = 0.06
        cylinder.height = 1.3
        rung.mesh = cylinder
        rung.position = Vector3(0, 0.35 + i * 0.6, 0)
        rung.rotation_degrees = Vector3(0, 0, 90)
        rung.material_override = _mat(Color("#b47a40"))
        root.add_child(rung)

func _bridge(pos: Vector3) -> void:
    var bridge := StaticBody3D.new()
    bridge.name = "RestoredBridge"
    bridge.position = pos
    add_child(bridge)
    var shape := CollisionShape3D.new()
    var collision := BoxShape3D.new()
    collision.size = Vector3(9, 0.45, 4)
    shape.shape = collision
    shape.position.y = 0.55
    bridge.add_child(shape)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(9, 0.45, 4)
    mesh.mesh = box
    mesh.position.y = 0.55
    mesh.material_override = _mat(Color("#9f7549"))
    bridge.add_child(mesh)
    for side in [-1.6, 1.6]:
        var rail := MeshInstance3D.new()
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.06
        cylinder.bottom_radius = 0.06
        cylinder.height = 1.1
        rail.mesh = cylinder
        rail.position = Vector3(0, 1.0, side)
        rail.material_override = _mat(Color("#725338"))
        bridge.add_child(rail)

func _label(pos: Vector3, text_value: String) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = 26
    label.outline_size = 8
    label.modulate = Color.WHITE
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)
    return label

func _mat(c: Color) -> Material:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    if c.a < 0.99:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return m
