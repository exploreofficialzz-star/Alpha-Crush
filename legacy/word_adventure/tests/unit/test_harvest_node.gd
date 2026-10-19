extends RefCounted
class_name TestHarvestNode

static func run() -> bool:
    var inventory: Inventory = preload("res://gameplay/inventory.gd").new()
    inventory.capacity = 1
    inventory.add_item("wood", 1)
    var harvest: HarvestNode = preload("res://world/harvesting/harvest_node.gd").new()
    harvest.setup("stone", 1, "Stone")
    var harvested := harvest.try_harvest(inventory)
    if harvested or inventory.count("stone") != 0 or not harvest.available or not is_equal_approx(harvest.cooldown, 0.0):
        return false
    # Regression: a regrowing node must hide its fruit until it is harvestable again.
    harvest.cooldown = 7.0
    harvest.set_available(true)
    var hidden_while_regrowing: bool = not harvest.visual_mesh.visible
    var saved: Dictionary = harvest.snapshot_state()
    var restored: HarvestNode = preload("res://world/harvesting/harvest_node.gd").new()
    restored.setup("stone", 1, "Stone")
    restored.restore_state(saved)
    var ok: bool = hidden_while_regrowing and restored.available and restored.resource_state == "REFRESHING" and is_equal_approx(restored.cooldown, 7.0)
    harvest.free()
    restored.free()
    inventory.free()
    return ok
