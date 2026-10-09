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

var quality: QualityManager

func setup(p: AlphaCrushPlayer, seed_number: int, map: MapManager = null, quality_manager: QualityManager = null) -> void:
    player = p
    map_manager = map
    quality = quality_manager
    world_seed = seed_number
    generator = SeededGenerator.new(seed_number)
    catalog = preload("res://world/regions/region_catalog.gd").new()
    add_child(catalog)

func _quality() -> Dictionary:
    if quality != null:
        return quality.current()
    return {"grass": 0.55, "props": 0.85, "stream_radius": 2, "tree_shadows": false}

func _process(_delta: float) -> void:
    if player == null or generator == null:
        return
    radius = int(_quality().get("stream_radius", 2))
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
    _update_grass(cx, cz)

## Grass is only worth drawing close to the player: build it for the 3x3 chunks around them, drop it elsewhere.
func _update_grass(cx: int, cz: int) -> void:
    var built := 0
    for key in loaded.keys():
        var c: Vector2i = key
        var chunk: Node3D = loaded[c]
        if not is_instance_valid(chunk):
            continue
        var near: bool = absi(c.x - cx) <= 1 and absi(c.y - cz) <= 1
        var existing: Node = chunk.get_node_or_null("Grass")
        if near and existing == null and not chunk.has_meta("grass_done") and built < 1:
            chunk.set_meta("grass_done", true)
            var grass_region := "starter_village" if _is_authored_village_chunk(c) else generator.region_for(c.x, c.y)
            var grass := Vegetation.build_grass(c, chunk_size, grass_region, _quality(), VillageArt.exclusions, world_seed)
            if grass != null:
                grass.position -= chunk.position
                chunk.add_child(grass)
            built += 1
        elif not near and existing != null:
            chunk.remove_child(existing)
            existing.queue_free()
            chunk.remove_meta("grass_done")

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
        Vegetation.decorate_chunk(chunk, coord, chunk_size, generator, region, _quality(), VillageArt.exclusions, world_seed)
    chunk_loaded.emit(coord, region)

func _is_authored_village_chunk(coord: Vector2i) -> bool:
    # The central four chunks (x,z in -48..48) are built by VillageArt / World; procedural terrain begins beyond.
    return coord.x >= -1 and coord.x <= 0 and coord.y >= -1 and coord.y <= 0

func _build_terrain_chunk(chunk: Node3D, coord: Vector2i, region: String) -> void:
    var patch := TerrainField.build_patch(float(coord.x) * chunk_size, float(coord.y) * chunk_size, chunk_size, 3.0, world_seed)
    (patch["mesh"] as ArrayMesh).surface_set_material(0, Vegetation.region_material(region))
    chunk.add_child(TerrainField.make_body(patch, "Terrain"))

func _discover_current_region(coord: Vector2i) -> void:
    if map_manager == null or generator == null:
        return
    var region_id := "region_%d_%d" % [coord.x, coord.y]
    if map_manager.discovered.has(region_id):
        return
    var region := generator.region_for(coord.x, coord.y)
    var world_pos := Vector3((coord.x + 0.5) * chunk_size, 0, (coord.y + 0.5) * chunk_size)
    map_manager.discover(region_id, world_pos, region.capitalize(), region)
