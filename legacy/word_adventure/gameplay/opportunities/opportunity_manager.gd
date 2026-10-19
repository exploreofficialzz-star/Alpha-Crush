extends Node
class_name OpportunityManager

signal opportunity_added(id: String)
signal opportunity_completed(id: String)

var opportunities: Dictionary = {}

func register(id: String, title: String, requirement: String, at_position: Vector3, region: String = "") -> void:
    if opportunities.has(id):
        return
    opportunities[id] = {
        "title": title,
        "requirement": requirement.to_upper(),
        "position": [at_position.x, at_position.y, at_position.z],
        "region": region,
        "state": "DISCOVERED"
    }
    opportunity_added.emit(id)

func activate(id: String) -> bool:
    if not opportunities.has(id):
        return false
    opportunities[id]["state"] = "ACTIVE"
    return true

func complete(id: String) -> void:
    if not opportunities.has(id):
        return
    opportunities[id]["state"] = "COMPLETE"
    opportunity_completed.emit(id)

func active() -> Array:
    var result: Array = []
    for id in opportunities.keys():
        if str(opportunities[id].get("state", "")) in ["DISCOVERED", "ACTIVE"]:
            result.append({"id": id, "data": opportunities[id].duplicate(true)})
    return result

func snapshot() -> Dictionary:
    return opportunities.duplicate(true)

func restore(value: Dictionary) -> void:
    opportunities = value.duplicate(true)
