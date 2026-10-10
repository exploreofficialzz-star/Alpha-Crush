extends RefCounted
class_name GuideDirector

## Works out what a child who cannot read should be pointed at next, using only picture-friendly
## signals: the nearest letter gem still lying around, the market when they carry things to sell,
## otherwise the nearest unfinished place. Pure data in, one small dictionary out.
const SELLABLE: Array[String] = ["fruit_apple", "fruit_orange", "fruit_mango", "fruit_berry", "crop_wheat", "wood", "stone", "ore", "flower"]

var player: AlphaCrushPlayer
var world: AlphaCrushWorld
var inventory: Inventory
var opportunities: OpportunityManager

func setup(local_player: AlphaCrushPlayer, local_world: AlphaCrushWorld, local_inventory: Inventory, local_opportunities: OpportunityManager) -> void:
    player = local_player
    world = local_world
    inventory = local_inventory
    opportunities = local_opportunities

## {} when there is nothing to point at, otherwise {kind, pos, icon, letter}.
func pick_target() -> Dictionary:
    if player == null or world == null:
        return {}
    var from := player.global_position
    var letter := nearest_letter(from)
    if letter != null:
        return {"kind": "letter", "pos": letter.global_position, "icon": "gem", "letter": letter.letter}
    if world.market_open and carries_sellables():
        return {"kind": "market", "pos": AlphaCrushWorld.MARKET_POS, "icon": "market", "letter": ""}
    return nearest_site(from)

func nearest_letter(from: Vector3) -> LetterObject:
    var best: LetterObject = null
    var best_distance := INF
    for candidate in world.letters:
        if not is_instance_valid(candidate) or candidate.carried or not candidate.is_inside_tree():
            continue
        var distance := from.distance_to(candidate.global_position)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

func carries_sellables() -> bool:
    if inventory == null:
        return false
    for item_id in SELLABLE:
        if inventory.count(item_id) > 0:
            return true
    return false

func nearest_site(from: Vector3) -> Dictionary:
    if opportunities == null:
        return {}
    var best: Dictionary = {}
    var best_distance := INF
    for entry in opportunities.active():
        var data: Dictionary = entry.get("data", {})
        var coords: Array = data.get("position", [])
        if coords.size() < 3:
            continue
        var site := Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
        var distance := from.distance_to(site)
        if distance < best_distance:
            best_distance = distance
            best = {"kind": "site", "pos": site, "icon": KidUI.word_icon(str(data.get("requirement", ""))), "letter": ""}
    return best
