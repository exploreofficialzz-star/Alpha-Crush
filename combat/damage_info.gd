extends RefCounted
class_name DamageInfo

## One hit travelling from an attacker to a victim. Built by weapons, kung-fu strikes, explosions and crush moves.
const KIND_BULLET := 0
const KIND_MELEE := 1
const KIND_EXPLOSION := 2
const KIND_CRUSH := 3
const KIND_ENVIRONMENT := 4

var amount := 0.0
var kind: int = KIND_BULLET
var source: Node3D = null
var source_team := -1
var hit_point := Vector3.ZERO
## Direction the hit travels (attacker towards victim); used for knock-back and the damage arrow.
var direction := Vector3.ZERO
## Metres per second pushed into the victim.
var knockback := 0.0
## Seconds the victim cannot act after the hit.
var stagger := 0.0
var headshot := false
var weapon_id := ""

static func make(p_amount: float, p_kind: int, p_source: Node3D, p_team: int, p_point: Vector3, p_direction: Vector3) -> DamageInfo:
    var info := DamageInfo.new()
    info.amount = p_amount
    info.kind = p_kind
    info.source = p_source
    info.source_team = p_team
    info.hit_point = p_point
    info.direction = p_direction
    return info

func is_ranged() -> bool:
    return kind == KIND_BULLET or kind == KIND_EXPLOSION
