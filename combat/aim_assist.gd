extends RefCounted
class_name AimAssist

## Touch screens cannot aim like a mouse, so the game helps in the way mobile shooters do: it softly prefers the enemy
## closest to where the player is already facing. One formula (angle first, then distance, plus a small bonus for the
## enemy that is already locked) keeps the choice predictable. Nothing here fires the weapon; it only chooses a target.
const LOCK_BONUS := 0.18
const ANGLE_WEIGHT := 0.65
const RANGE_WEIGHT := 0.35
## An existing lock survives until the target leaves a cone this much wider than the one needed to acquire it.
const LOCK_HOLD_FACTOR := 1.35

## 0..1 (higher is better); -1.0 means the target is not a candidate at all.
static func score(from: Vector3, forward: Vector3, target: Vector3, max_range: float, cone_degrees: float, locked: bool = false) -> float:
    var offset := target - from
    offset.y = 0.0
    var distance := offset.length()
    if distance < 0.05 or distance > max_range:
        return -1.0
    var flat_forward := Vector3(forward.x, 0.0, forward.z)
    if flat_forward.length() < 0.001:
        return -1.0
    var angle := rad_to_deg(flat_forward.normalized().angle_to(offset / distance))
    var half_cone := maxf(cone_degrees * 0.5, 1.0)
    if angle > half_cone:
        if not locked or angle > half_cone * LOCK_HOLD_FACTOR:
            return -1.0
    var angle_part := 1.0 - clampf(angle / half_cone, 0.0, 1.0)
    var range_part := 1.0 - clampf(distance / maxf(max_range, 0.1), 0.0, 1.0)
    var total := angle_part * ANGLE_WEIGHT + range_part * RANGE_WEIGHT
    if locked:
        total += LOCK_BONUS
    return total

## Best candidate (Node3D) or null. `current` is the target locked on the previous frame.
static func pick(from: Vector3, forward: Vector3, candidates: Array, max_range: float, cone_degrees: float, current: Node3D = null) -> Node3D:
    var best: Node3D = null
    var best_score := -1.0
    for candidate in candidates:
        if not is_instance_valid(candidate):
            continue
        var node := candidate as Node3D
        if node == null:
            continue
        var value := score(from, forward, node.global_position, max_range, cone_degrees, node == current)
        if value > best_score:
            best_score = value
            best = node
    return best
