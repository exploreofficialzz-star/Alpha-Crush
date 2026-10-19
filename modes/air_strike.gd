extends Node3D
class_name AirStrike

## Killstreak: after a short warning (a red ring on the ground and a whistle) a salvo of bombs lands inside the ring.
const WARNING_SECONDS := 1.6
const BOMBS := 7
const BOMB_GAP := 0.22
const BOMB_RADIUS := 4.6
const BOMB_DAMAGE := 130.0

var director: CombatDirector
var fx: CombatFX
var audio: AudioManager
var caller: Node3D = null
var strike_radius := 8.0

var _warning: float = WARNING_SECONDS
var _remaining: int = BOMBS
var _gap := 0.0
var _centre := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

static func create(p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager, p_caller: Node3D) -> AirStrike:
    var strike := AirStrike.new()
    strike.name = "AirStrike"
    strike.director = p_director
    strike.fx = p_fx
    strike.audio = p_audio
    strike.caller = p_caller
    strike._rng.randomize()
    return strike

func start(ground_centre: Vector3) -> void:
    _centre = ground_centre
    global_position = ground_centre
    if fx != null:
        fx.ring(ground_centre + Vector3(0.0, 0.12, 0.0), strike_radius, Color(1.0, 0.2, 0.15, 0.85), WARNING_SECONDS)
        fx.ring(ground_centre + Vector3(0.0, 0.14, 0.0), strike_radius * 0.5, Color(1.0, 0.5, 0.2, 0.85), WARNING_SECONDS)
    if audio != null:
        audio.play_sfx("airstrike_whistle", 1.0, 0.0)

func _process(delta: float) -> void:
    if _warning > 0.0:
        _warning -= delta
        return
    _gap -= delta
    if _gap > 0.0 or _remaining <= 0:
        if _remaining <= 0 and _gap < -1.0:
            queue_free()
        return
    _gap = BOMB_GAP
    _remaining -= 1
    var angle := _rng.randf() * TAU
    var radius := sqrt(_rng.randf()) * strike_radius
    var point := _centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
    var source: Node3D = caller if is_instance_valid(caller) else null
    Explosion.detonate(director, fx, point, BOMB_RADIUS, BOMB_DAMAGE, Teams.ALPHA, source, 13.0, 1.0, true, DamageInfo.KIND_CRUSH)
    if audio != null:
        audio.play_sfx("explosion", _rng.randf_range(0.85, 1.1), -1.0)
