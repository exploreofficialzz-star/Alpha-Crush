extends Node
class_name RegionCatalog

var regions: Dictionary = {}

func _ready() -> void:
    var f := FileAccess.open("res://data/regions/regions.json", FileAccess.READ)
    if f:
        var d = JSON.parse_string(f.get_as_text())
        if typeof(d) == TYPE_ARRAY:
            for r in d:
                if r is Dictionary:
                    regions[str(r.get("id", ""))] = r

func get_region(id: String) -> Dictionary:
    return regions.get(id, {})

func ids() -> Array:
    return regions.keys()
