extends Node3D
class_name Pickup

## Things enemies drop and crates hold. Kinds: coin, health, ammo, armor, grenade. The MatchDirector applies the effect when
## `collected` fires. Coins drift towards the player (a magnet) so collecting never needs precise steering.
signal collected(pickup: Pickup)

const PICKUP_RADIUS := 1.7
const MAGNET_RADIUS := 4.5
const LIFETIME := 40.0

var kind := "coin"
var amount := 5
var player: Node3D = null

var _age := 0.0
var _visual: Node3D
var _taken := false

static func create(p_kind: String, p_amount: int) -> Pickup:
    var pickup := Pickup.new()
    pickup.kind = p_kind
    pickup.amount = p_amount
    pickup.name = "Pickup_" + p_kind
    pickup._build_visual()
    return pickup

static func _glow(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.7
    material.roughness = 0.4
    return material

func _part(mesh: Mesh, position_value: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = position_value
    part.material_override = _glow(color)
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visual.add_child(part)
    return part

func _build_visual() -> void:
    _visual = Node3D.new()
    _visual.name = "Visual"
    add_child(_visual)
    if kind == "health":
        var block := BoxMesh.new()
        block.size = Vector3(0.5, 0.5, 0.5)
        _part(block, Vector3.ZERO, Color(0.96, 0.96, 0.98))
        var bar_a := BoxMesh.new()
        bar_a.size = Vector3(0.34, 0.1, 0.52)
        _part(bar_a, Vector3.ZERO, Color(0.9, 0.15, 0.18))
        var bar_b := BoxMesh.new()
        bar_b.size = Vector3(0.1, 0.34, 0.52)
        _part(bar_b, Vector3.ZERO, Color(0.9, 0.15, 0.18))
    elif kind == "ammo":
        var crate := BoxMesh.new()
        crate.size = Vector3(0.55, 0.38, 0.38)
        _part(crate, Vector3.ZERO, Color(0.98, 0.8, 0.15))
        var stripe := BoxMesh.new()
        stripe.size = Vector3(0.58, 0.1, 0.4)
        _part(stripe, Vector3(0.0, 0.0, 0.0), Color(0.25, 0.22, 0.18))
    elif kind == "armor":
        var shield := CylinderMesh.new()
        shield.top_radius = 0.3
        shield.bottom_radius = 0.3
        shield.height = 0.12
        shield.radial_segments = 6
        shield.rings = 1
        var part := _part(shield, Vector3.ZERO, Color(0.25, 0.6, 1.0))
        part.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    elif kind == "grenade":
        var ball := SphereMesh.new()
        ball.radius = 0.2
        ball.height = 0.4
        ball.radial_segments = 8
        ball.rings = 4
        _part(ball, Vector3.ZERO, Color(0.3, 0.75, 0.3))
        var cap := CylinderMesh.new()
        cap.top_radius = 0.06
        cap.bottom_radius = 0.06
        cap.height = 0.12
        _part(cap, Vector3(0.0, 0.22, 0.0), Color(1.0, 0.85, 0.2))
    else:
        var coin := CylinderMesh.new()
        coin.top_radius = 0.28
        coin.bottom_radius = 0.28
        coin.height = 0.07
        coin.radial_segments = 12
        coin.rings = 1
        var coin_part := _part(coin, Vector3.ZERO, Color(1.0, 0.82, 0.2))
        coin_part.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    _visual.position.y = 0.7

func _process(delta: float) -> void:
    if _taken:
        return
    _age += delta
    _visual.rotation.y += delta * 2.4
    _visual.position.y = 0.7 + sin(_age * 3.0) * 0.1
    if _age > LIFETIME - 5.0:
        _visual.visible = int(_age * 6.0) % 2 == 0
    if _age >= LIFETIME:
        queue_free()
        return
    if player == null or not is_instance_valid(player) or not bool(player.get("alive")):
        return
    var offset := player.global_position - global_position
    offset.y = 0.0
    var distance := offset.length()
    if kind == "coin" and distance < MAGNET_RADIUS:
        global_position += offset.normalized() * minf(distance, (9.0 - distance) * delta * 2.0 + 3.0 * delta)
    if distance < PICKUP_RADIUS:
        _taken = true
        collected.emit(self)
        queue_free()
