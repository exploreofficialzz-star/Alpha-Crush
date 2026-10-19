extends CharacterBody3D
class_name Fighter

## The shared body of every combatant: the player, the squad-mates and every enemy. It owns health and armour, hit reactions,
## knock-back, hit-scan shooting, grenades and kung-fu strikes. Subclasses decide WHEN to act (player input or enemy AI).
## Defeated fighters are never shown bleeding: they are knocked out, fall over and vanish in a puff of stars.
signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
signal damaged(info: DamageInfo, applied: float)
signal died(info: DamageInfo)
signal landed_hit(victim: Node3D, info: DamageInfo, applied: float)
signal fired_weapon(weapon_id: String)

const GRAVITY := 24.0
const HEADSHOT_FRACTION := 0.82
const HEADSHOT_MULTIPLIER := 1.6
const KNOCK_DECAY := 26.0

var team: int = Teams.ALPHA
var display_name := "FIGHTER"
var max_health := 100.0
var health := 100.0
var max_armor := 0.0
var armor := 0.0
var armor_absorb := 0.6
var alive := true
var invulnerable := 0.0
var stunned := 0.0
## 0..1: share of stagger / knock-back ignored (heavy enemies barely flinch).
var stagger_resist := 0.0
var knock_resist := 0.0
var body_scale := 1.0
var body_height := 1.75
var director: CombatDirector
var fx: CombatFX
var audio: AudioManager
var rig: AvatarRig
var visual_root: Node3D
var weapon_socket: Node3D
var weapon_model: Node3D
var weapon: WeaponController
var aiming := false
var weapon_visible := true
var last_damage_msec := -100000
var tracer_color := Color(1.0, 0.86, 0.45)

var _knock := Vector3.ZERO
var _socket_aim := Vector3(0.12, 1.1, -0.45)
var _socket_rest := Vector3(0.20, 0.80, -0.10)

# ------------------------------------------------------------------------------------------------ construction
## Builds collision + the human model. p_gender "male"/"female", p_age "child" (the playable kids) or "adult" (soldiers).
func setup_body(p_gender: String, p_age: String, outfit: Dictionary, p_scale: float) -> void:
    body_scale = p_scale
    collision_layer = Teams.layer_for(team)
    collision_mask = Teams.body_mask()
    visual_root = Node3D.new()
    visual_root.name = "Visual"
    visual_root.scale = Vector3.ONE * p_scale
    add_child(visual_root)
    var candidate := AvatarRig.new()
    candidate.name = "AvatarRig"
    visual_root.add_child(candidate)
    if candidate.build(p_gender, outfit, p_age):
        rig = candidate
        body_height = rig.head_top * p_scale
    else:
        visual_root.remove_child(candidate)
        candidate.free()
        body_height = 1.7 * p_scale
        _build_fallback_body(outfit)
    var capsule := CapsuleShape3D.new()
    capsule.height = clampf(body_height + 0.1, 1.5, 2.3)
    capsule.radius = clampf(0.34 * p_scale, 0.3, 0.46)
    var shape := CollisionShape3D.new()
    shape.name = "Body"
    shape.shape = capsule
    shape.position = Vector3(0.0, capsule.height * 0.5, 0.0)
    add_child(shape)
    weapon_socket = Node3D.new()
    weapon_socket.name = "WeaponSocket"
    visual_root.add_child(weapon_socket)
    var rig_height := body_height / maxf(p_scale, 0.01)
    var shoulder := rig_height * 0.80
    var reach := rig_height * 0.30
    _socket_aim = Vector3(0.10 * rig_height / 1.7, shoulder - 0.04, -reach)
    _socket_rest = Vector3(0.20 * rig_height / 1.7, rig_height * 0.50, -0.10)
    weapon_socket.position = _socket_rest

func _build_fallback_body(outfit: Dictionary) -> void:
    var shirt: Color = outfit.get("shirt", Color(0.3, 0.4, 0.55))
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.3
    capsule.height = 1.5
    body.mesh = capsule
    body.position.y = 0.85
    var material := StandardMaterial3D.new()
    material.albedo_color = shirt
    body.material_override = material
    visual_root.add_child(body)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    head.mesh = sphere
    head.position.y = 1.65
    var skin := StandardMaterial3D.new()
    skin.albedo_color = outfit.get("skin", Color(0.8, 0.6, 0.45))
    head.material_override = skin
    visual_root.add_child(head)

## Registers with the referee and receives the shared services. Call after `team` is set.
func join_battle(p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager) -> void:
    director = p_director
    fx = p_fx
    audio = p_audio
    if director != null:
        director.register(self, team)

func equip(weapon_id: String) -> void:
    if weapon_model != null and is_instance_valid(weapon_model):
        weapon_model.queue_free()
        weapon_model = null
    if weapon_socket == null or not WeaponCatalog.is_valid(weapon_id):
        return
    weapon_model = WeaponModel.build(weapon_id)
    weapon_socket.add_child(weapon_model)
    weapon_model.visible = weapon_visible
    tracer_color = WeaponCatalog.get_weapon(weapon_id).get("tracer", Color(1.0, 0.86, 0.45))

func is_alive() -> bool:
    return alive

## Sound from other fighters gets quieter with distance to the player: -0.22 dB per metre, down to -22 dB.
func sfx_offset(base_db: float) -> float:
    if director != null and director.player != null and director.player != self and is_instance_valid(director.player):
        return base_db - clampf(global_position.distance_to(director.player.global_position) * 0.22, 0.0, 22.0)
    return base_db

# ------------------------------------------------------------------------------------------------ stance and movement helpers
func set_stance(aim: bool) -> void:
    aiming = aim
    if rig != null:
        rig.set_aiming(aim)

func show_weapon(value: bool) -> void:
    weapon_visible = value
    if weapon_model != null and is_instance_valid(weapon_model):
        weapon_model.visible = value

## Moves the gun between "raised at the shoulder" and "hanging by the side". `aim_pitch` is in radians (up is positive).
func update_weapon_pose(delta: float, aim_pitch: float = 0.0) -> void:
    if weapon_socket == null:
        return
    var blend := minf(1.0, delta * 14.0)
    weapon_socket.position = weapon_socket.position.lerp(_socket_aim if aiming else _socket_rest, blend)
    weapon_socket.rotation.x = lerpf(weapon_socket.rotation.x, aim_pitch if aiming else -0.9, blend)

func face_direction(direction: Vector3, delta: float, rate: float = 12.0) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length() < 0.01:
        return
    rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * rate))

func forward_flat() -> Vector3:
    var forward := -global_transform.basis.z
    forward.y = 0.0
    if forward.length() < 0.001:
        return Vector3.FORWARD
    return forward.normalized()

func apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

## Planar velocity with the current knock-back added on top.
func with_knock(desired: Vector3) -> Vector3:
    return Vector3(desired.x + _knock.x, 0.0, desired.z + _knock.z)

func decay_knock(delta: float) -> void:
    if _knock.length_squared() > 0.0001:
        _knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)

func add_knock(impulse: Vector3) -> void:
    _knock += Vector3(impulse.x, 0.0, impulse.z)

func tick_timers(delta: float) -> void:
    invulnerable = maxf(0.0, invulnerable - delta)
    stunned = maxf(0.0, stunned - delta)

# ------------------------------------------------------------------------------------------------ health
func heal(amount: float) -> void:
    if not alive or amount <= 0.0:
        return
    health = minf(max_health, health + amount)
    health_changed.emit(health, max_health)

func add_armor(amount: float) -> void:
    if not alive or amount <= 0.0 or max_armor <= 0.0:
        return
    armor = minf(max_armor, armor + amount)
    armor_changed.emit(armor, max_armor)

func health_fraction() -> float:
    return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

## Returns the damage that actually landed (0 when ignored: dead, friendly, or inside dodge i-frames).
func take_damage(info: DamageInfo) -> float:
    if not alive:
        return 0.0
    if info.source == self:
        return 0.0
    if info.source_team == team and info.kind != DamageInfo.KIND_ENVIRONMENT:
        return 0.0
    if invulnerable > 0.0:
        _on_attack_evaded(info)
        return 0.0
    var amount := maxf(info.amount, 0.0)
    if amount <= 0.0:
        return 0.0
    var soak := 0.0
    if armor > 0.0:
        soak = minf(armor, amount * armor_absorb)
        armor -= soak
        armor_changed.emit(armor, max_armor)
    health = maxf(0.0, health - (amount - soak))
    last_damage_msec = Time.get_ticks_msec()
    var push := Vector3(info.direction.x, 0.0, info.direction.z)
    if info.knockback > 0.0 and push.length() > 0.01:
        _knock += push.normalized() * info.knockback * (1.0 - knock_resist)
    if info.stagger > 0.0:
        stunned = maxf(stunned, info.stagger * (1.0 - stagger_resist))
    if rig != null:
        if info.stagger > 0.0 or amount >= 18.0:
            rig.play_hit()
        rig.flash(0.75)
    health_changed.emit(health, max_health)
    damaged.emit(info, amount)
    _on_damaged(info, amount)
    if health <= 0.0:
        _die(info)
    return amount

## Called when a hit lands on somebody else (by bullets, kicks, blasts). Public so explosions can credit their caster.
func register_hit(victim: Node3D, info: DamageInfo, applied: float) -> void:
    landed_hit.emit(victim, info, applied)
    _on_hit_landed(victim, info, applied)

func _on_damaged(_info: DamageInfo, _applied: float) -> void:
    pass

func _on_hit_landed(_victim: Node3D, _info: DamageInfo, _applied: float) -> void:
    pass

func _on_attack_evaded(_info: DamageInfo) -> void:
    pass

func _die(info: DamageInfo) -> void:
    alive = false
    health = 0.0
    collision_layer = 0
    velocity = Vector3.ZERO
    stunned = 0.0
    if director != null:
        director.unregister(self)
    if rig != null:
        rig.set_aiming(false)
    health_changed.emit(0.0, max_health)
    died.emit(info)
    _play_defeat(info)

## Default knock-out: fall backwards, rest a moment, shrink away in a puff of stars. The player overrides this.
func _play_defeat(_info: DamageInfo) -> void:
    set_physics_process(false)
    if fx != null:
        fx.poof(global_position + Vector3(0.0, body_height * 0.55, 0.0))
    if visual_root == null:
        queue_free()
        return
    var tween := create_tween()
    tween.tween_property(visual_root, "rotation_degrees:x", 88.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(visual_root, "position:y", 0.1, 0.45)
    tween.tween_interval(0.9)
    tween.tween_property(visual_root, "scale", Vector3.ONE * 0.01, 0.35)
    tween.tween_callback(queue_free)

# ------------------------------------------------------------------------------------------------ shooting
func muzzle_position() -> Vector3:
    if weapon_model != null and is_instance_valid(weapon_model):
        var marker := weapon_model.get_node_or_null("Muzzle") as Node3D
        if marker != null:
            return marker.global_position
    return global_position + Vector3(0.0, body_height * 0.72, 0.0) + forward_flat() * 0.5

func chest_position() -> Vector3:
    return global_position + Vector3(0.0, body_height * 0.62, 0.0)

## Fires the active weapon along `aim_dir`. Returns true when a shot actually left the barrel.
func shoot(aim_dir: Vector3) -> bool:
    if weapon == null or not alive:
        return false
    var shot: Dictionary = weapon.try_fire()
    if shot.is_empty():
        return false
    var origin := muzzle_position()
    var base_dir := aim_dir.normalized()
    if fx != null:
        fx.muzzle_flash(origin, base_dir, 1.4 if str(shot.get("projectile", "")) != "" else 1.0)
    if audio != null:
        audio.play_sfx(str(shot.get("sfx", "")), randf_range(0.96, 1.04), sfx_offset(-2.0))
    var projectile_kind := str(shot.get("projectile", ""))
    if projectile_kind != "":
        _launch_projectile(projectile_kind, shot, origin, base_dir)
    else:
        for i in int(shot.get("pellets", 1)):
            _fire_ray(shot, origin, base_dir)
    _after_shot(shot)
    fired_weapon.emit(str(shot.get("id", "")))
    return true

func _after_shot(_shot: Dictionary) -> void:
    pass

func _spread_direction(direction: Vector3, spread_degrees: float) -> Vector3:
    var forward := direction.normalized()
    if spread_degrees <= 0.01:
        return forward
    var helper := Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT
    var right := forward.cross(helper).normalized()
    var up := right.cross(forward).normalized()
    var angle := deg_to_rad(spread_degrees) * sqrt(randf())
    var around := randf() * TAU
    return (forward + (right * cos(around) + up * sin(around)) * tan(angle)).normalized()

func _fire_ray(shot: Dictionary, origin: Vector3, base_dir: Vector3) -> void:
    var direction := _spread_direction(base_dir, float(shot.get("spread", 0.0)))
    var reach := float(shot.get("range", 40.0))
    var target := origin + direction * reach
    var query := PhysicsRayQueryParameters3D.create(origin, target, Teams.bullet_mask_for(team))
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var tracer: Color = shot.get("tracer", tracer_color)
    if hit.is_empty():
        if fx != null:
            fx.tracer(origin, target, tracer)
        return
    var end_point: Vector3 = hit["position"]
    var normal: Vector3 = hit["normal"]
    var collider: Object = hit["collider"]
    if fx != null:
        fx.tracer(origin, end_point, tracer)
    var weapon_id := str(shot.get("id", ""))
    var amount := float(shot.get("damage", 10.0)) * WeaponCatalog.range_multiplier(weapon_id, origin.distance_to(end_point))
    var victim := collider as Fighter
    if victim != null:
        var info := DamageInfo.make(amount, DamageInfo.KIND_BULLET, self, team, end_point, direction)
        info.knockback = float(shot.get("knockback", 1.0))
        info.weapon_id = weapon_id
        var relative_height := (end_point.y - victim.global_position.y) / maxf(victim.body_height, 0.5)
        if relative_height >= HEADSHOT_FRACTION:
            info.headshot = true
            info.amount *= HEADSHOT_MULTIPLIER
        var applied := victim.take_damage(info)
        if applied > 0.0:
            register_hit(victim, info, applied)
        if fx != null:
            fx.impact(end_point, normal, "hit")
        return
    if collider != null and collider.has_method("take_damage"):
        var prop_info := DamageInfo.make(amount, DamageInfo.KIND_BULLET, self, team, end_point, direction)
        prop_info.weapon_id = weapon_id
        collider.call("take_damage", prop_info)
        if fx != null:
            fx.impact(end_point, normal, "spark")
        return
    if fx != null:
        fx.impact(end_point, normal, "dust" if normal.y > 0.7 else "spark")

func _launch_projectile(kind: String, shot: Dictionary, origin: Vector3, direction: Vector3) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        return
    var projectile := Projectile.create(kind)
    parent_node.add_child(projectile)
    projectile.global_position = origin
    projectile.configure(director, fx, audio, team, self)
    projectile.velocity = _spread_direction(direction, float(shot.get("spread", 0.0))) * float(shot.get("projectile_speed", 30.0))
    projectile.blast_damage = float(shot.get("damage", 100.0))
    projectile.blast_radius = float(shot.get("blast", 4.0))

## Lobs a grenade towards `direction` (need not be flat). `strength` 0..1.2 scales the throw distance (about 10 m at 1.0).
func throw_grenade(direction: Vector3, strength: float = 1.0) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length() < 0.01:
        flat = forward_flat()
    throw_grenade_at(global_position + flat.normalized() * 10.0 * clampf(strength, 0.3, 1.3))

## Lobs a grenade so that it lands on `point`: flight time grows with distance, so far throws arc higher instead of faster.
func throw_grenade_at(point: Vector3) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        return
    var start := global_position + Vector3(0.0, body_height * 0.75, 0.0)
    var flat := Vector3(point.x - start.x, 0.0, point.z - start.z)
    var distance := flat.length()
    var direction := forward_flat() if distance < 0.05 else flat / distance
    start += direction * 0.5
    var flight := clampf(distance / 14.0, 0.6, 1.5)
    var projectile := Projectile.create("grenade")
    parent_node.add_child(projectile)
    projectile.global_position = start
    projectile.configure(director, fx, audio, team, self)
    projectile.gravity = 18.0
    projectile.fuse = flight + 1.0
    projectile.explode_on_impact = false
    projectile.blast_damage = 110.0
    projectile.blast_radius = 4.2
    var rise := 0.5 * projectile.gravity * flight + (point.y - start.y) / flight
    projectile.velocity = direction * (maxf(distance - 0.5, 0.0) / flight) + Vector3(0.0, rise, 0.0)
    if audio != null:
        audio.play_sfx("grenade_pin", 1.0, -2.0)

# ------------------------------------------------------------------------------------------------ kung fu
## Hits every hostile fighter (and breakable prop) in a cone in front of this fighter. Returns the fighters that were hit.
func melee_strike(damage: float, reach: float, arc_degrees: float, knockback: float, stagger: float) -> Array:
    var victims: Array = []
    if director == null or not alive:
        return victims
    var forward := forward_flat()
    var half_arc := deg_to_rad(arc_degrees * 0.5)
    for candidate in director.in_radius(global_position, reach + 0.7, Teams.hostile_of(team)):
        var victim := candidate as Fighter
        if victim == null:
            continue
        var offset := victim.global_position - global_position
        offset.y = 0.0
        var distance := offset.length()
        if distance > reach + 0.4 * victim.body_scale:
            continue
        if distance > 0.25 and forward.angle_to(offset / distance) > half_arc:
            continue
        var direction := forward if distance < 0.05 else offset / distance
        var info := DamageInfo.make(damage, DamageInfo.KIND_MELEE, self, team, victim.chest_position(), direction)
        info.knockback = knockback
        info.stagger = stagger
        var applied := victim.take_damage(info)
        if applied > 0.0:
            victims.append(victim)
            register_hit(victim, info, applied)
    for prop in get_tree().get_nodes_in_group("breakable"):
        var node := prop as Node3D
        if node == null or not node.has_method("take_damage"):
            continue
        var gap := node.global_position - global_position
        gap.y = 0.0
        if gap.length() > reach + 0.5 or (gap.length() > 0.3 and forward.angle_to(gap.normalized()) > half_arc):
            continue
        var prop_info := DamageInfo.make(damage, DamageInfo.KIND_MELEE, self, team, node.global_position, forward)
        node.call("take_damage", prop_info)
    return victims
