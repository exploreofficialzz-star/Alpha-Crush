extends Fighter
class_name EnemyFighter

## Opposition fighters AND the player's squad-mates (team decides). A small state machine reads its numbers from EnemyCatalog.
## Fair-fight rules: only a few enemies may attack at once (attack tokens from the CombatDirector), every melee swing and every
## special (grenade, dash, boss slam, sniper shot) is telegraphed with a flash, a ground ring or a laser, and shooters fire in
## short bursts with pauses, so a crowd can always be read and dodged.
signal summon_requested(count: int)

const S_IDLE := 0
const S_ADVANCE := 1
const S_ENGAGE := 2
const S_WINDUP := 3
const S_RECOVER := 4
const S_SPECIAL := 5
const S_DASH := 6

const SLAM_RADIUS := 5.5
const SLAM_TELEGRAPH := 1.25
const GRENADE_RING_RADIUS := 4.2

var type_id := "grunt"
var faction_id := "jackals"
var data: Dictionary = {}
var is_ally := false
var is_boss := false
var difficulty := 1.0
var score_value := 100
var coin_value := 5
var ally_index := 0
var ally_count := 2
## Domination defenders stay near their flag and only chase enemies that come within sight.
var hold_point := Vector3.ZERO
var has_hold_point := false
var hunt_player := true

var _state: int = S_IDLE
var _target: Node3D = null
var _target_timer := 0.0
var _ai_timer := 0.0
var _desired := Vector3.ZERO
var _detour := 0.0
var _los := false
var _alert_time := 0.0
var _burst_left := 0
var _burst_gap := 0.0
var _pause_timer := 0.0
var _aim_left := -1.0
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _windup := 0.0
var _recover := 0.0
var _special_timer := 3.0
var _special_time := 0.0
var _special_kind := ""
var _dash_time := 0.0
var _dash_velocity := Vector3.ZERO
var _slam_point := Vector3.ZERO
var _summoned_mid := false
var _summoned_late := false
var _flash_timer := 0.0
var _anim_accum := 0.0
var _damage_scale := 1.0

# ------------------------------------------------------------------------------------------------ construction
func build(p_type: String, p_faction: String, p_team: int, p_difficulty: float, role_seed: int) -> void:
    type_id = p_type
    faction_id = p_faction
    data = EnemyCatalog.type_data(p_type)
    team = p_team
    is_ally = p_team == Teams.ALPHA
    is_boss = bool(data.get("boss", false))
    difficulty = maxf(p_difficulty, 0.5)
    display_name = str(data.get("name", "ENEMY"))
    score_value = int(data.get("score", 100))
    coin_value = int(data.get("coins", 5))
    _damage_scale = 0.8 + 0.2 * difficulty
    max_health = float(data.get("hp", 60.0)) * (0.85 + 0.15 * difficulty)
    if is_ally:
        max_health = float(data.get("hp", 160.0))
    health = max_health
    max_armor = float(data.get("armor", 0.0))
    armor = max_armor
    stagger_resist = float(data.get("stagger_resist", 0.0))
    knock_resist = float(data.get("knock_resist", 0.0))
    var gender := "female" if role_seed % 3 == 0 else "male"
    var outfit := EnemyCatalog.outfit_for(p_faction, p_type, role_seed, gender, is_ally)
    setup_body(gender, "adult", outfit, float(data.get("scale", 1.0)))
    var weapon_id := str(data.get("weapon", ""))
    if weapon_id != "":
        weapon = WeaponController.new()
        weapon.name = "Weapons"
        add_child(weapon)
        weapon.infinite_reserve = true
        weapon.damage_scale = float(data.get("damage", 0.3)) * _damage_scale
        weapon.fire_rate_scale = float(data.get("rate", 0.6))
        weapon.setup(weapon_id, "", {})
        equip(weapon_id)
    _strafe_sign = 1.0 if role_seed % 2 == 0 else -1.0
    _special_timer = randf_range(2.0, float(data.get("special_cooldown", 6.0)))
    _ai_timer = randf() * 0.2

func _has_gun() -> bool:
    return weapon != null and weapon.current_id() != ""

# ------------------------------------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
    if not alive:
        return
    tick_timers(delta)
    _alert_time += delta
    _special_timer = maxf(0.0, _special_timer - delta)
    _pause_timer = maxf(0.0, _pause_timer - delta)
    _strafe_timer -= delta
    if _strafe_timer <= 0.0:
        _strafe_timer = randf_range(1.2, 2.6)
        if randf() < 0.45:
            _strafe_sign = -_strafe_sign
    _ai_timer -= delta
    if _ai_timer <= 0.0:
        _ai_timer = _ai_interval()
        _ai_tick()
    if stunned > 0.0:
        _desired = Vector3.ZERO
    else:
        _run_state(delta)
    _move(delta)
    _animate(delta)

func _ai_interval() -> float:
    if director != null and director.player != null and is_instance_valid(director.player):
        if director.player.global_position.distance_to(global_position) > 32.0:
            return 0.28
    return 0.13

func _ai_tick() -> void:
    _acquire_target()
    if _target == null or not is_instance_valid(_target):
        _los = false
    else:
        var eye := global_position + Vector3(0.0, body_height * 0.75, 0.0)
        var aim_point := _target.global_position + Vector3(0.0, 1.2, 0.0)
        var target_fighter := _target as Fighter
        if target_fighter != null:
            aim_point = target_fighter.chest_position()
        var query := PhysicsRayQueryParameters3D.create(eye, aim_point, Teams.LAYER_WORLD | Teams.LAYER_BREAKABLE)
        _los = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
    _update_detour()
    if is_boss:
        var fraction := health / maxf(max_health, 1.0)
        if not _summoned_mid and fraction <= 0.6:
            _summoned_mid = true
            summon_requested.emit(3)
        if not _summoned_late and fraction <= 0.25:
            _summoned_late = true
            summon_requested.emit(4)

## Finds clear ground around the current heading so enemies slide around crates and walls instead of pushing into them.
func _update_detour() -> void:
    _detour = 0.0
    if _desired.length() < 0.2:
        return
    var heading := _desired.normalized()
    var from := global_position + Vector3(0.0, 0.6, 0.0)
    var space := get_world_3d().direct_space_state
    var clear_found := false
    for angle in [0.0, 50.0, -50.0, 90.0, -90.0]:
        var test := heading.rotated(Vector3.UP, deg_to_rad(float(angle)))
        var query := PhysicsRayQueryParameters3D.create(from, from + test * 1.9, Teams.LAYER_WORLD | Teams.LAYER_BREAKABLE)
        if space.intersect_ray(query).is_empty():
            _detour = float(angle)
            clear_found = true
            break
    if not clear_found:
        _detour = 120.0

func _acquire_target() -> void:
    if director == null:
        return
    var best: Node3D = null
    var best_score := 1.0e12
    var sight := float(data.get("sight", 45.0))
    for candidate in director.roster(Teams.hostile_of(team)):
        var node := candidate as Node3D
        if node == null:
            continue
        var distance := node.global_position.distance_to(global_position)
        if distance > sight * 1.6:
            continue
        var score := distance
        if not is_ally and node == director.player:
            score *= 0.7
        if node == _target:
            score *= 0.8
        if score < best_score:
            best_score = score
            best = node
    if best == null and not is_ally and hunt_player and director.player != null and is_instance_valid(director.player) and bool(director.player.get("alive")):
        best = director.player
    if best != _target:
        _target = best
        _alert_time = 0.0
        if _burst_left > 0 or _aim_left >= 0.0:
            _end_burst()
        _burst_left = 0
        _aim_left = -1.0

# ------------------------------------------------------------------------------------------------ behaviour
func _run_state(delta: float) -> void:
    if _state == S_SPECIAL:
        _run_special(delta)
        return
    if _state == S_DASH:
        _run_dash(delta)
        return
    if _state == S_WINDUP:
        _run_windup(delta)
        return
    if _state == S_RECOVER:
        _run_recover(delta)
        return
    if _target == null or not is_instance_valid(_target):
        _idle_behaviour()
        return
    if str(data.get("role", "gunner")) == "melee":
        _run_melee()
    else:
        _run_gunner(delta)

func _flat_offset(to_node: Node3D) -> Vector3:
    var offset := to_node.global_position - global_position
    offset.y = 0.0
    return offset

func _steer(direction: Vector3, speed_scale: float = 1.0) -> void:
    var steered := direction
    if absf(_detour) > 0.1:
        steered = direction.rotated(Vector3.UP, deg_to_rad(_detour))
    _desired = steered * float(data.get("speed", 3.5)) * speed_scale

func _strafe_direction(toward: Vector3) -> Vector3:
    return toward.rotated(Vector3.UP, deg_to_rad(90.0) * _strafe_sign)

func _idle_behaviour() -> void:
    _state = S_IDLE
    _desired = Vector3.ZERO
    # Nothing to fight: give back any attack token so the others are not starved.
    if director != null:
        director.release_token(self, CombatDirector.KIND_MELEE)
        director.release_token(self, CombatDirector.KIND_RANGED)
    _burst_left = 0
    _aim_left = -1.0
    if is_ally and director != null and director.player != null and is_instance_valid(director.player):
        var anchor := CombatDirector.surround_point(director.player.global_position, ally_index, maxi(ally_count, 1), 4.5, 0.6)
        var offset := anchor - global_position
        offset.y = 0.0
        if offset.length() > 1.6:
            _steer(offset.normalized(), 1.25 if offset.length() > 9.0 else 0.8)
    elif has_hold_point:
        var back := hold_point - global_position
        back.y = 0.0
        if back.length() > 3.0:
            _steer(back.normalized(), 0.8)

func _run_gunner(delta: float) -> void:
    var offset := _flat_offset(_target)
    var distance := offset.length()
    var toward := offset / maxf(distance, 0.01)
    var band_min := float(data.get("band_min", 8.0))
    var band_max := float(data.get("band_max", 20.0))
    if _aim_left >= 0.0:
        _run_sniper_aim(delta, distance)
        return
    if distance > band_max or not _los:
        _state = S_ADVANCE
        _steer(toward)
    elif distance < band_min:
        _state = S_ENGAGE
        _steer((-toward * 0.8 + _strafe_direction(toward) * 0.5).normalized(), 0.9)
    else:
        _state = S_ENGAGE
        _steer(_strafe_direction(toward), 0.6)
    _gunner_fire(delta, distance)
    _maybe_special(distance)

func _gunner_fire(delta: float, distance: float) -> void:
    if not _has_gun():
        return
    var weapon_range := float(weapon.spec().get("range", 40.0))
    if _burst_left > 0:
        _burst_gap -= delta
        if weapon.is_reloading():
            _end_burst()
            return
        if _burst_gap <= 0.0 and weapon.can_fire():
            if _los and distance <= weapon_range:
                _fire_at_target()
            _burst_left -= 1
            _burst_gap = 1.0 / maxf(float(weapon.spec().get("rate", 4.0)) * weapon.fire_rate_scale, 0.5)
            if _burst_left <= 0:
                _end_burst()
        return
    if _pause_timer > 0.0 or not _los or distance > weapon_range or weapon.is_reloading():
        return
    if _alert_time < float(data.get("reaction", 0.7)):
        return
    if not is_ally and director != null and not director.request_token(self, CombatDirector.KIND_RANGED):
        return
    if float(data.get("aim_time", 0.0)) > 0.0:
        _aim_left = float(data.get("aim_time", 1.2))
        return
    _burst_left = int(data.get("burst", 3))
    _burst_gap = 0.0

func _end_burst() -> void:
    _burst_left = 0
    _pause_timer = float(data.get("pause", 1.5)) * randf_range(0.8, 1.3)
    if director != null:
        director.release_token(self, CombatDirector.KIND_RANGED)

## Snipers stand still and paint the player with a red laser before the shot, which is the cue to dodge or break line of sight.
func _run_sniper_aim(delta: float, distance: float) -> void:
    _desired = Vector3.ZERO
    _aim_left -= delta
    if _target == null or not _los or distance > float(weapon.spec().get("range", 60.0)):
        _aim_left = -1.0
        _end_burst()
        return
    if fx != null:
        var target_fighter := _target as Fighter
        var point := target_fighter.chest_position() if target_fighter != null else _target.global_position
        fx.tracer(muzzle_position(), point, Color(1.0, 0.15, 0.15, 0.55))
    if _aim_left <= 0.0:
        _aim_left = -1.0
        _burst_left = 1
        _burst_gap = 0.0

func _fire_at_target() -> void:
    var origin := muzzle_position()
    var target_fighter := _target as Fighter
    var point := target_fighter.chest_position() if target_fighter != null else _target.global_position + Vector3(0.0, 1.2, 0.0)
    var direction := (point - origin).normalized()
    var inaccuracy := float(data.get("accuracy", 3.0)) / (0.8 + 0.2 * difficulty)
    if target_fighter != null and Vector2(target_fighter.velocity.x, target_fighter.velocity.z).length() > 3.0:
        inaccuracy *= 1.4
    shoot(_spread_direction(direction, inaccuracy))

# ------------------------------------------------------------------------------------------------ melee fighters
func _run_melee() -> void:
    var offset := _flat_offset(_target)
    var distance := offset.length()
    var toward := offset / maxf(distance, 0.01)
    var reach := float(data.get("reach", 1.8))
    if str(data.get("special", "")) == "dash" and _special_timer <= 0.0 and _los and distance > 5.0 and distance < 12.0:
        if is_ally or director == null or director.request_token(self, CombatDirector.KIND_MELEE):
            _begin_dash(toward, distance)
            return
    if distance > 9.0:
        # Far away: just close the gap. Tokens are only handed out to fighters that are actually close enough to attack.
        _state = S_ADVANCE
        _steer(toward)
        if director != null:
            director.release_token(self, CombatDirector.KIND_MELEE)
        return
    var has_token := is_ally or director == null or director.request_token(self, CombatDirector.KIND_MELEE)
    if has_token:
        _state = S_ADVANCE
        _steer(toward)
        if distance <= reach + 0.15 and _alert_time >= float(data.get("reaction", 0.4)):
            _begin_windup()
    else:
        _state = S_ENGAGE
        var ring_radius := 4.6
        if distance < ring_radius - 0.8:
            _steer(-toward, 0.6)
        elif distance > ring_radius + 1.0:
            _steer(toward, 0.8)
        else:
            _steer(_strafe_direction(toward), 0.55)

func _begin_windup() -> void:
    _state = S_WINDUP
    _windup = float(data.get("windup", 0.5))
    _desired = Vector3.ZERO

func _run_windup(delta: float) -> void:
    _desired = Vector3.ZERO
    _windup -= delta
    _flash_timer -= delta
    if _flash_timer <= 0.0 and rig != null:
        _flash_timer = 0.1
        rig.flash(0.5, Color(1.0, 0.25, 0.2))
    if _target != null and is_instance_valid(_target):
        face_direction(_flat_offset(_target), delta, 14.0)
    if _windup <= 0.0:
        _melee_hit()

func _melee_hit() -> void:
    var damage := float(data.get("melee_damage", 9.0)) * _damage_scale
    var reach := float(data.get("reach", 1.8))
    melee_strike(damage, reach + 0.35, 110.0, 4.0, 0.25)
    if rig != null:
        if randf() < 0.5:
            rig.play_punch(randf() < 0.5)
        else:
            rig.play_kick()
    if audio != null:
        audio.play_sfx("punch_light", randf_range(0.8, 0.95), sfx_offset(-5.0))
    _state = S_RECOVER
    _recover = float(data.get("cooldown", 1.4)) * randf_range(0.9, 1.25)
    if director != null:
        director.release_token(self, CombatDirector.KIND_MELEE)

func _run_recover(delta: float) -> void:
    _recover -= delta
    _desired = Vector3.ZERO
    if _target != null and is_instance_valid(_target):
        var toward := _flat_offset(_target).normalized()
        _steer(-toward, 0.45)
    if _recover <= 0.0:
        _state = S_ADVANCE

# ------------------------------------------------------------------------------------------------ specials
func _maybe_special(distance: float) -> void:
    if _special_timer > 0.0 or _target == null:
        return
    var kind := str(data.get("special", ""))
    if kind == "grenade" and _los and distance > 8.0 and distance < 26.0:
        _special_timer = float(data.get("special_cooldown", 6.5)) * randf_range(0.9, 1.3)
        var point := _target.global_position
        throw_grenade_at(point)
        if fx != null:
            fx.ring(point + Vector3(0.0, 0.1, 0.0), GRENADE_RING_RADIUS, Color(1.0, 0.25, 0.2, 0.8), 1.9)
        if rig != null:
            rig.play_punch(true)
    elif kind == "slam" and distance < 14.0:
        _begin_slam()

func _begin_slam() -> void:
    _state = S_SPECIAL
    _special_kind = "slam"
    _special_time = SLAM_TELEGRAPH
    _slam_point = global_position
    _special_timer = float(data.get("special_cooldown", 7.0)) * randf_range(0.9, 1.2)
    _desired = Vector3.ZERO
    _burst_left = 0
    if fx != null:
        fx.ring(_slam_point + Vector3(0.0, 0.1, 0.0), SLAM_RADIUS, Color(1.0, 0.25, 0.15, 0.85), SLAM_TELEGRAPH)
    if audio != null:
        audio.play_sfx("alarm_warning", 0.8, -4.0)

func _run_special(delta: float) -> void:
    _desired = Vector3.ZERO
    _special_time -= delta
    _flash_timer -= delta
    if _flash_timer <= 0.0 and rig != null:
        _flash_timer = 0.1
        rig.flash(0.55, Color(1.0, 0.45, 0.15))
    if _special_time > 0.0:
        return
    if _special_kind == "dash":
        _state = S_DASH
        _dash_time = 0.32
        return
    if _special_kind == "slam":
        if rig != null:
            rig.play_slam()
        Explosion.detonate(director, fx, _slam_point, SLAM_RADIUS, 38.0 * _damage_scale, team, self, 13.0, 0.8, false)
        if fx != null:
            fx.ring(_slam_point + Vector3(0.0, 0.15, 0.0), SLAM_RADIUS, Color(1.0, 0.7, 0.3, 0.9), 0.4)
            fx.shake(0.9)
        if audio != null:
            audio.play_sfx("crush_slam", 0.8, sfx_offset(0.0))
    _state = S_RECOVER
    _recover = 0.9

func _begin_dash(toward: Vector3, distance: float) -> void:
    _state = S_SPECIAL
    _special_kind = "dash"
    _special_time = 0.55
    _special_timer = float(data.get("special_cooldown", 7.0)) * randf_range(0.9, 1.2)
    _desired = Vector3.ZERO
    _dash_velocity = toward * minf(maxf(distance - 1.3, 1.0) / 0.32, 22.0)
    if audio != null:
        audio.play_sfx("whoosh", 0.7, sfx_offset(-3.0))

func _run_dash(delta: float) -> void:
    _dash_time -= delta
    _desired = _dash_velocity
    if _dash_time <= 0.0:
        _dash_velocity = Vector3.ZERO
        _desired = Vector3.ZERO
        var damage := float(data.get("melee_damage", 12.0)) * 1.5 * _damage_scale
        melee_strike(damage, float(data.get("reach", 2.0)) + 0.6, 120.0, 7.0, 0.4)
        if rig != null:
            rig.play_kick()
        if audio != null:
            audio.play_sfx("kick_hit", 0.9, sfx_offset(-3.0))
        _state = S_RECOVER
        _recover = 1.0
        if director != null:
            director.release_token(self, CombatDirector.KIND_MELEE)

# ------------------------------------------------------------------------------------------------ movement and animation
func _separation() -> Vector3:
    if director == null:
        return Vector3.ZERO
    var push := Vector3.ZERO
    for candidate in director.roster(team):
        var other := candidate as Node3D
        if other == null or other == self:
            continue
        var offset := global_position - other.global_position
        offset.y = 0.0
        var distance := offset.length()
        if distance < 1.2 and distance > 0.01:
            push += offset / distance * (1.2 - distance) * 3.0
    return push

func _move(delta: float) -> void:
    apply_gravity(delta)
    var wish := _desired + _separation()
    var planar := with_knock(wish)
    var blend := minf(1.0, delta * 12.0)
    velocity.x = lerpf(velocity.x, planar.x, blend)
    velocity.z = lerpf(velocity.z, planar.z, blend)
    move_and_slide()
    decay_knock(delta)

func _animate(delta: float) -> void:
    var facing_target := _target != null and is_instance_valid(_target)
    if facing_target:
        var offset := _flat_offset(_target)
        var close_enough := offset.length() < float(data.get("sight", 45.0))
        if close_enough and (_state == S_ENGAGE or _state == S_WINDUP or _state == S_SPECIAL or _burst_left > 0 or _aim_left >= 0.0):
            face_direction(offset, delta, 10.0)
        elif _desired.length() > 0.2:
            face_direction(_desired, delta, 8.0)
    elif _desired.length() > 0.2:
        face_direction(_desired, delta, 8.0)
    var gun_up := _has_gun() and facing_target and _los and (_state == S_ENGAGE or _burst_left > 0 or _aim_left >= 0.0)
    set_stance(gun_up)
    show_weapon(_has_gun())
    var pitch := 0.0
    if facing_target:
        var offset_3d := _target.global_position - global_position
        pitch = atan2(offset_3d.y, maxf(Vector2(offset_3d.x, offset_3d.z).length(), 0.5)) * 0.6
    update_weapon_pose(delta, pitch)
    _anim_accum += delta
    var far := director != null and director.player != null and is_instance_valid(director.player) and director.player.global_position.distance_to(global_position) > 45.0
    if far and (Engine.get_physics_frames() + get_instance_id()) % 3 != 0:
        return
    if rig != null:
        rig.animate(_anim_accum, Vector2(velocity.x, velocity.z).length(), is_on_floor())
    _anim_accum = 0.0

# ------------------------------------------------------------------------------------------------ reactions
func _on_damaged(info: DamageInfo, _applied: float) -> void:
    if info.source != null and is_instance_valid(info.source):
        var attacker := info.source as Fighter
        if attacker != null and attacker.team != team and (_target == null or randf() < 0.4):
            _target = attacker
            _alert_time = maxf(_alert_time, float(data.get("reaction", 0.5)))
    if info.stagger > 0.2 and stagger_resist < 0.5:
        if _state == S_WINDUP or _state == S_SPECIAL:
            _state = S_RECOVER
            _recover = 0.7
        _aim_left = -1.0
        if _burst_left > 0:
            _end_burst()
        if director != null:
            director.release_token(self, CombatDirector.KIND_MELEE)

func _die(info: DamageInfo) -> void:
    if director != null:
        director.release_all(self)
    super._die(info)
