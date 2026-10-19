extends Area3D
class_name HarvestNode

signal harvested(item_id: String, amount: int)
signal state_changed(resource_id: String, state: String)

var resource_id := ""
var item_id := "wood"
var amount := 1
var display_name := "Resource"
var available := true
var cooldown := 0.0
var respawn_seconds := 20.0
var resource_state := "ACTIVE"
var visual_mesh: Node3D
var visual_label: Label3D

func setup(id: String, count: int, label_text: String) -> void:
    item_id = id
    amount = count
    display_name = label_text
    if resource_id.is_empty():
        resource_id = id
    collision_layer = 8
    collision_mask = 2
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.75
    shape.shape = sphere
    add_child(shape)
    visual_mesh = _build_visual(id)
    add_child(visual_mesh)
    visual_label = Label3D.new()
    visual_label.text = display_name
    visual_label.font_size = 18
    visual_label.outline_size = 6
    visual_label.position.y = 2.2
    visual_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(visual_label)
    set_available(true)

const MODEL_FOR_ITEM := {"wood": "res_wood", "stone": "res_stone", "ore": "res_ore", "fruit_apple": "res_apple", "fruit_orange": "res_orange",
    "fruit_mango": "res_mango", "crop_wheat": "crop_wheat"}
# fruit hangs in a small cluster just off the trunk, where the player can see and reach it
const FRUIT_OFFSETS := [Vector3(0.62, 1.75, 0.10), Vector3(0.50, 1.48, -0.30), Vector3(0.82, 1.58, -0.12)]

func _build_visual(id: String) -> Node3D:
    var model_id := str(MODEL_FOR_ITEM.get(id, ""))
    if model_id != "" and PropFactory.has_model(model_id):
        var root := Node3D.new()
        root.name = "Visual"
        if id.begins_with("fruit_"):
            for off in FRUIT_OFFSETS:
                var fruit := PropFactory.spawn(model_id, false, true)
                if fruit != null:
                    fruit.position = off
                    root.add_child(fruit)
        else:
            var item := PropFactory.spawn(model_id, false, true)
            if item != null:
                item.position.y = 0.04
                root.add_child(item)
        if root.get_child_count() > 0:
            return root
        root.free()
    # placeholder when the generated models are not available
    var mesh := MeshInstance3D.new()
    var sphere_mesh := SphereMesh.new()
    sphere_mesh.radius = 0.28
    sphere_mesh.height = 0.56
    mesh.mesh = sphere_mesh
    mesh.material_override = _material_for_item(id)
    mesh.position.y = 1.6
    return mesh

func _material_for_item(id: String) -> Material:
    var material := StandardMaterial3D.new()
    match id:
        "wood": material.albedo_color = Color("#9a6b43")
        "stone": material.albedo_color = Color("#a1a8b0")
        "fruit_apple": material.albedo_color = Color("#e24d4d")
        "fruit_orange": material.albedo_color = Color("#ff9b35")
        "fruit_mango": material.albedo_color = Color("#f0c54a")
        "crop_wheat": material.albedo_color = Color("#d6bd55")
        "ore": material.albedo_color = Color("#70b9c4")
        _: material.albedo_color = Color("#75a85b")
    return material

func _process(delta: float) -> void:
    if cooldown > 0.0:
        cooldown = maxf(0.0, cooldown - delta)
    var next_state := "LOCKED" if not available else ("REFRESHING" if cooldown > 0.0 else "ACTIVE")
    _set_resource_state(next_state)

func _set_resource_state(value: String) -> void:
    if resource_state == value:
        return
    resource_state = value
    _apply_visual_state()
    state_changed.emit(resource_id, resource_state)

func _apply_visual_state() -> void:
    # Only a ready node shows its fruit; while regrowing the label stays as a dimmed marker.
    var ready_to_harvest := available and cooldown <= 0.0
    if visual_mesh:
        visual_mesh.visible = ready_to_harvest
    if visual_label:
        visual_label.visible = available
        visual_label.modulate = Color.WHITE if ready_to_harvest else Color(1, 1, 1, 0.45)

func set_available(value: bool) -> void:
    available = value
    _apply_visual_state()
    for child in get_children():
        if child is CollisionShape3D:
            child.disabled = not value
    _set_resource_state("LOCKED" if not value else ("REFRESHING" if cooldown > 0.0 else "ACTIVE"))

func try_harvest(inventory: Inventory) -> bool:
    if not available or cooldown > 0.0:
        return false
    if not inventory.add_item(item_id, amount):
        return false
    cooldown = respawn_seconds
    _set_resource_state("REFRESHING")
    harvested.emit(item_id, amount)
    return true

func snapshot_state() -> Dictionary:
    return {
        "resource_id": resource_id,
        "available": available,
        "cooldown": cooldown,
        "state": resource_state
    }

func restore_state(value: Dictionary) -> void:
    available = bool(value.get("available", available))
    cooldown = clampf(float(value.get("cooldown", 0.0)), 0.0, respawn_seconds)
    set_available(available)
    _set_resource_state("LOCKED" if not available else ("REFRESHING" if cooldown > 0.0 else "ACTIVE"))
