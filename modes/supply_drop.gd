extends Node3D
class_name SupplyDrop

## Killstreak: a crate on a parachute falls from the sky; when it lands the match drops supplies around it.
signal landed(position: Vector3)

const FALL_SECONDS := 2.2
const START_HEIGHT := 28.0

var fx: CombatFX
var audio: AudioManager

var _age := 0.0
var _ground := Vector3.ZERO
var _done := false
var _chute: MeshInstance3D

static func create(p_fx: CombatFX, p_audio: AudioManager) -> SupplyDrop:
    var drop := SupplyDrop.new()
    drop.fx = p_fx
    drop.audio = p_audio
    drop._build_visual()
    return drop

func _build_visual() -> void:
    name = "SupplyDrop"
    var crate := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.1, 0.9, 1.1)
    crate.mesh = box
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.2, 0.55, 0.9)
    wood.emission_enabled = true
    wood.emission = Color(0.2, 0.55, 0.9)
    wood.emission_energy_multiplier = 0.5
    crate.material_override = wood
    add_child(crate)
    _chute = MeshInstance3D.new()
    var dome := CylinderMesh.new()
    dome.top_radius = 0.1
    dome.bottom_radius = 1.8
    dome.height = 1.1
    dome.radial_segments = 10
    dome.rings = 1
    _chute.mesh = dome
    _chute.position = Vector3(0.0, 2.6, 0.0)
    var cloth := StandardMaterial3D.new()
    cloth.albedo_color = Color(1.0, 0.85, 0.2)
    cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
    _chute.material_override = cloth
    add_child(_chute)

## `ground_point` is where the crate will land; it starts START_HEIGHT above it.
func start(ground_point: Vector3) -> void:
    _ground = ground_point
    global_position = ground_point + Vector3(0.0, START_HEIGHT, 0.0)
    if fx != null:
        fx.ring(ground_point + Vector3(0.0, 0.1, 0.0), 2.6, Color(0.3, 0.7, 1.0, 0.8), FALL_SECONDS)
    if audio != null:
        audio.play_sfx("streak_use", 0.8, -2.0)

func _process(delta: float) -> void:
    if _done:
        return
    _age += delta
    var t := clampf(_age / FALL_SECONDS, 0.0, 1.0)
    global_position = _ground + Vector3(sin(_age * 3.0) * 0.25 * (1.0 - t), (1.0 - t) * START_HEIGHT + 0.45, 0.0)
    if t >= 1.0:
        _done = true
        if _chute != null:
            _chute.visible = false
        if fx != null:
            fx.poof(_ground + Vector3(0.0, 0.8, 0.0), Color(0.5, 0.8, 1.0, 1.0))
            fx.shake(0.35)
        landed.emit(_ground)
        var timer := get_tree().create_timer(0.4)
        timer.timeout.connect(queue_free)
