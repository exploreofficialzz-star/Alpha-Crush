extends Node3D
class_name MultiplayerAvatar

var peer_id := 0
var target_position := Vector3.ZERO
var target_rotation := Vector3.ZERO

func setup(id: int, position_value: Vector3) -> void:
    peer_id = id
    global_position = position_value
    target_position = position_value
    _build_visual()

func _build_visual() -> void:
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.65
    body.mesh = capsule
    body.position.y = 0.83
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#2f6c90")
    material.emission_enabled = true
    material.emission = Color("#2f6c90") * 0.08
    body.material_override = material
    add_child(body)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.28
    sphere.height = 0.56
    head.mesh = sphere
    head.position.y = 1.85
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color("#c98d6b")
    head.material_override = skin
    add_child(head)
    var label := Label3D.new()
    label.text = "PLAYER %d" % peer_id
    label.font_size = 16
    label.outline_size = 6
    label.position.y = 2.4
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

func network_update(position_value: Vector3, rotation_value: Vector3) -> void:
    target_position = position_value
    target_rotation = rotation_value

func _process(delta: float) -> void:
    var weight := minf(1.0, delta * 12.0)
    global_position = global_position.lerp(target_position, weight)
    # Players only turn about Y; lerping raw Euler angles would spin the long way round at +/-PI.
    rotation.y = lerp_angle(rotation.y, target_rotation.y, weight)
