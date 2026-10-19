extends RefCounted
class_name Explosion

## Area damage shared by rockets, grenades, explosive barrels, air strikes and the boss slam. Victims are handled
## through duck typing (take_damage, body_height) so this file has no dependency on Fighter.
const EDGE_FACTOR := 0.30

## Damage at `distance` from the centre: full in the middle, EDGE_FACTOR at the rim, nothing outside.
static func damage_at(distance: float, radius: float, base_damage: float) -> float:
    if distance >= radius or radius <= 0.01:
        return 0.0
    var t := clampf(distance / radius, 0.0, 1.0)
    return base_damage * lerpf(1.0, EDGE_FACTOR, t)

## Hurts the side hostile to `team` (never the caster's own side), plus breakable props. Returns how many fighters were hit.
static func detonate(p_director: CombatDirector, p_fx: CombatFX, center: Vector3, radius: float, base_damage: float, team: int, source: Node3D, knockback: float = 10.0, stagger: float = 0.7, show_effect: bool = true, damage_kind: int = DamageInfo.KIND_EXPLOSION) -> int:
    if show_effect and p_fx != null:
        p_fx.explosion(center, radius)
    if p_director == null:
        return 0
    var hits := 0
    for candidate in p_director.in_radius(center, radius + 0.8, Teams.hostile_of(team)):
        var victim := candidate as Node3D
        if victim == null or not victim.has_method("take_damage"):
            continue
        var height_value: Variant = victim.get("body_height")
        var height := 1.7 if height_value == null else float(height_value)
        var chest := victim.global_position + Vector3(0.0, height * 0.5, 0.0)
        var offset := chest - center
        var distance := offset.length()
        var amount := damage_at(maxf(distance - 0.5, 0.0), radius, base_damage)
        if amount <= 0.0:
            continue
        var push := Vector3(offset.x, 0.0, offset.z)
        if push.length() < 0.05:
            push = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
        push = push.normalized() + Vector3(0.0, 0.35, 0.0)
        var info := DamageInfo.make(amount, damage_kind, source, team, chest, push.normalized())
        info.knockback = knockback * clampf(1.0 - distance / (radius + 0.8), 0.3, 1.0)
        info.stagger = stagger
        var applied := float(victim.call("take_damage", info))
        if applied > 0.0:
            hits += 1
            if source != null and is_instance_valid(source) and source.has_method("register_hit"):
                source.call("register_hit", victim, info, applied)
    for prop in p_director.get_tree().get_nodes_in_group("breakable"):
        var node := prop as Node3D
        if node == null or not node.has_method("take_damage"):
            continue
        var gap := node.global_position.distance_to(center)
        if gap > radius + 0.5:
            continue
        var prop_info := DamageInfo.make(damage_at(gap, radius + 0.5, base_damage), DamageInfo.KIND_EXPLOSION, source, team, node.global_position, (node.global_position - center).normalized())
        node.call("take_damage", prop_info)
    return hits
