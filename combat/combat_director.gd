extends Node
class_name CombatDirector

## The referee of a match. It knows who is alive on each side (so aim assist, AI, the radar and explosions can ask
## "who is near?"), and it hands out ATTACK TOKENS: only a few enemies may attack the player at once, the rest circle and
## wait. That keeps a crowd fight readable and fair instead of an unavoidable pile-on.
## Fighters are handled as plain Node3D with duck-typed properties so this class never depends on Fighter.
signal fighter_added(fighter: Node3D, team: int)
signal fighter_removed(fighter: Node3D, team: int)

const KIND_RANGED := "ranged"
const KIND_MELEE := "melee"

var ranged_tokens := 2
var melee_tokens := 2
var player: Node3D = null

var _rosters: Dictionary = {}
var _holders: Dictionary = {}

func _init() -> void:
    _rosters[Teams.ALPHA] = []
    _rosters[Teams.OPPOSITION] = []
    _holders[KIND_RANGED] = []
    _holders[KIND_MELEE] = []

func register(node: Node3D, team: int) -> void:
    if node == null:
        return
    var list: Array = _rosters.get(team, [])
    if list.has(node):
        return
    list.append(node)
    _rosters[team] = list
    fighter_added.emit(node, team)

func unregister(node: Node3D) -> void:
    for team in _rosters.keys():
        var list: Array = _rosters[team]
        if list.has(node):
            list.erase(node)
            release_all(node)
            fighter_removed.emit(node, int(team))
            return

func _is_alive(node: Node3D) -> bool:
    if not is_instance_valid(node):
        return false
    var flag: Variant = node.get("alive")
    return flag == null or bool(flag)

## Alive fighters of `team` (the internal array: read it, do not modify it).
func roster(team: int) -> Array:
    var list: Array = _rosters.get(team, [])
    var index := list.size() - 1
    while index >= 0:
        if not _is_alive(list[index] as Node3D):
            list.remove_at(index)
        index -= 1
    return list

func count(team: int) -> int:
    return roster(team).size()

func nearest(from: Vector3, team: int, max_distance: float = 100000.0, exclude: Node3D = null) -> Node3D:
    var best: Node3D = null
    var best_distance := max_distance * max_distance
    for candidate in roster(team):
        var node := candidate as Node3D
        if node == null or node == exclude:
            continue
        var distance := node.global_position.distance_squared_to(from)
        if distance < best_distance:
            best_distance = distance
            best = node
    return best

func in_radius(center: Vector3, radius: float, team: int) -> Array:
    var found: Array = []
    var limit := radius * radius
    for candidate in roster(team):
        var node := candidate as Node3D
        if node != null and node.global_position.distance_squared_to(center) <= limit:
            found.append(node)
    return found

## All-or-nothing: returns true when `holder` may attack now (it keeps the token until it calls release_token).
func request_token(holder: Node3D, kind: String) -> bool:
    var list: Array = _holders.get(kind, [])
    if list.has(holder):
        return true
    var index := list.size() - 1
    while index >= 0:
        if not _is_alive(list[index] as Node3D):
            list.remove_at(index)
        index -= 1
    var cap := ranged_tokens if kind == KIND_RANGED else melee_tokens
    if list.size() >= cap:
        return false
    list.append(holder)
    _holders[kind] = list
    return true

func release_token(holder: Node3D, kind: String) -> void:
    var list: Array = _holders.get(kind, [])
    list.erase(holder)

func release_all(holder: Node3D) -> void:
    for kind in _holders.keys():
        var list: Array = _holders[kind]
        list.erase(holder)

func token_count(kind: String) -> int:
    var list: Array = _holders.get(kind, [])
    return list.size()

func holds_token(holder: Node3D, kind: String) -> bool:
    var list: Array = _holders.get(kind, [])
    return list.has(holder)

## A spot on a circle around `center`; used so waiting enemies spread out instead of stacking up.
static func surround_point(center: Vector3, index: int, total: int, radius: float, phase: float = 0.0) -> Vector3:
    var count_safe := maxi(total, 1)
    var angle := phase + TAU * float(index) / float(count_safe)
    return center + Vector3(cos(angle), 0.0, sin(angle)) * radius

## Scales how aggressive the whole opposition is (1 = gentle, 4+ = relentless).
func set_aggression(level: float) -> void:
    ranged_tokens = clampi(int(round(1.0 + level)), 1, 6)
    melee_tokens = clampi(int(round(1.0 + level * 0.8)), 1, 5)
