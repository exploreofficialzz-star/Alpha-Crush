extends Node
class_name MapManager

signal map_changed
var discovered: Dictionary = {}

func discover(id: String, at_position: Vector3, title: String, region: String = "") -> void:
    if discovered.has(id):
        return
    discovered[id] = {"title": title, "position": [at_position.x, at_position.y, at_position.z], "region": region}
    map_changed.emit()

func is_discovered(id: String) -> bool:
    return discovered.has(id)

func nearest(from_position: Vector3) -> Dictionary:
    var best := {}
    var best_distance := INF
    for id in discovered.keys():
        var p = discovered[id].get("position", [0, 0, 0])
        var point := Vector3(float(p[0]), float(p[1]), float(p[2]))
        var distance := point.distance_to(from_position)
        if distance < best_distance:
            best_distance = distance
            best = {"id": id, "title": discovered[id].get("title", id), "distance": distance}
    return best

func snapshot() -> Array:
    var result: Array = []
    for id in discovered.keys():
        result.append({"id": id, "data": discovered[id].duplicate(true)})
    return result

func restore(value: Array) -> void:
    discovered.clear()
    for item in value:
        if item is Dictionary and item.has("id"):
            discovered[str(item["id"])] = item.get("data", {}).duplicate(true)
    map_changed.emit()
