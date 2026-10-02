extends Node
class_name CraftingManager

signal crafted(recipe_id: String, output: String)
var inventory: Node
var recipes: Dictionary = {}

func _ready() -> void:
    var f := FileAccess.open("res://data/recipes/recipes.json", FileAccess.READ)
    if f:
        var d = JSON.parse_string(f.get_as_text())
        if typeof(d) == TYPE_ARRAY:
            for recipe in d:
                recipes[str(recipe.get("id", ""))] = recipe

func can_craft(id: String) -> bool:
    if not recipes.has(id) or inventory == null:
        return false
    var recipe: Dictionary = recipes[id]
    var inputs: Dictionary = recipe.get("inputs", {})
    for item in inputs.keys():
        if not inventory.has_item(str(item), int(inputs[item])):
            return false
    # Simulate resulting distinct stacks before consuming ingredients.
    var projected: Dictionary = inventory.items.duplicate(true)
    for item in inputs.keys():
        var item_id := str(item)
        projected[item_id] = int(projected.get(item_id, 0)) - int(inputs[item])
        if int(projected[item_id]) <= 0:
            projected.erase(item_id)
    var output := str(recipe.get("output", id))
    projected[output] = int(projected.get(output, 0)) + int(recipe.get("amount", 1))
    var slots := 0
    for item_id in projected.keys():
        if str(item_id) != "coins" and str(item_id) != "gems" and int(projected[item_id]) > 0:
            slots += 1
    return slots <= int(inventory.capacity)

func craft(id: String) -> bool:
    if not can_craft(id):
        return false
    var recipe: Dictionary = recipes[id]
    var removed: Dictionary = {}
    for item in recipe.get("inputs", {}).keys():
        var item_id := str(item)
        var needed := int(recipe["inputs"][item])
        if not inventory.remove_item(item_id, needed):
            # Defensive rollback if an inventory implementation rejects a removal.
            for rollback_id in removed.keys():
                inventory.add_item(str(rollback_id), int(removed[rollback_id]))
            return false
        removed[item_id] = needed
    var output := str(recipe.get("output", id))
    var output_amount := int(recipe.get("amount", 1))
    if not inventory.add_item(output, output_amount):
        for rollback_id in removed.keys():
            inventory.add_item(str(rollback_id), int(removed[rollback_id]))
        return false
    crafted.emit(id, output)
    return true

func recipe_summary(id: String) -> String:
    if not recipes.has(id):
        return "Unknown recipe"
    var recipe: Dictionary = recipes[id]
    var parts: Array[String] = []
    for item in recipe.get("inputs", {}).keys():
        parts.append("%s × %d" % [str(item).replace("_", " ").capitalize(), int(recipe["inputs"][item])])
    return "%s → %s × %d" % [", ".join(parts), str(recipe.get("output", id)).replace("_", " ").capitalize(), int(recipe.get("amount", 1))]
