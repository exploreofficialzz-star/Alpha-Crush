extends Fighter
class_name PlayerFighter

## The hero. One thumb walks (the touch HUD feeds `mobile_move`), the other aims by dragging and presses ATTACK.
## SMART STANCE: the single ATTACK button is context aware. With an enemy in arm's reach it throws a kung-fu combo
## (punch, punch, kick, flying kick); otherwise it fires the equipped gun at the enemy the aim assist has locked.
## Hits fill the CRUSH meter; a full meter unleashes a crush move. A well-timed dodge triggers bullet time.
signal downed
signal respawned
signal crush_triggered(move_id: String)
signal streak_ready(slot: int, streak_id: String)
signal streak_triggered(streak_id: String)
signal streak_progress(kills: int)
signal hit_confirmed(kill: bool, headshot: bool)
signal announce(text: String, color: Color)
signal damage_from(world_direction: Vector3)
signal grenades_changed(count: int)
signal kill_scored(victim: Node3D, points: int, headshot: bool)
signal dodge_started
signal target_changed(new_target: Node3D)

const WALK_SPEED := 6.4
const JUMP_VELOCITY := 6.6
const DODGE_SPEED := 12.5
const DODGE_TIME := 0.34
const DODGE_COOLDOWN := 0.85
const DODGE_IFRAMES := 0.42
const MELEE_ENGAGE := 2.7
const AIM_RANGE := 58.0
const AIM_CONE := 76.0
const STANCE_SECONDS := 1.8
const REGEN_DELAY := 4.5
const REGEN_RATE := 16.0
const CAMERA_DISTANCE := 3.7
const CAMERA_HEIGHT := 1.45
const MAX_GRENADES := 4
const COMBO_WINDOW := 0.95
const GRENADE_COOLDOWN := 0.8
const QUAKE_RADIUS := 7.5
const MELEE_HIT_DELAY := 0.10
const STORM_SECONDS := 4.0
const MULTI_KILL_WINDOW := 2.2

const MELEE_DAMAGE: Array[float] = [14.0, 16.0, 24.0, 42.0]
const MELEE_REACH: Array[float] = [2.2, 2.2, 2.5, 3.0]
const MELEE_ARC: Array[float] = [110.0, 110.0, 130.0, 160.0]
const MELEE_INTERVAL: Array[float] = [0.30, 0.30, 0.42, 0.66]
const MELEE_KNOCK: Array[float] = [2.2, 2.2, 5.0, 9.5]
const MELEE_STAGGER: Array[float] = [0.20, 0.20, 0.45, 0.85]
const MELEE_LUNGE: Array[float] = [3.0, 3.0, 4.0, 9.0]
const MULTI_KILL_TEXT: Array[String] = ["", "", "DOUBLE CRUSH!", "TRIPLE CRUSH!", "QUAD CRUSH!", "MEGA CRUSH!"]

var settings: SettingsManager
var simple_mode := true
var aim_assist := 1.0
var camera_sensitivity := 1.0
var loadout: Dictionary = {}
var style: Dictionary = {}
var crush_move := "quake"
var streak_ids: Array[String] = ["supply", "airstrike", "drone"]
var combo := ComboTracker.new()
var crush_meter := CrushMeter.new()
var kill_streak := 0
var kills := 0
var headshots := 0
var grenades := 2
var camera: Camera3D
var camera_rig: Node3D
var spring: SpringArm3D
var yaw := 0.0
var pitch := -8.0
var target: Node3D = null
var stats := {"damage_dealt": 0.0, "damage_taken": 0.0, "shots": 0, "hits": 0, "melee_kills": 0, "crushes": 0, "perfect_dodges": 0, "best_combo": 0}

# Input state (written by the touch HUD, the keyboard or tests).
var mobile_move := Vector2.ZERO
var attack_held := false

var _jump_buffer := 0.0
var _want_dodge := false
var _want_grenade := false
var _want_reload := false
var _want_swap := false
var _want_crush := false
var _want_streak := -1

var _dodge_time := 0.0
var _dodge_cooldown := 0.0
var _dodge_dir := Vector3.ZERO
var _perfect_used := false
var _melee_cooldown := 0.0
var _combo_step := 0
var _combo_window := 0.0
var _strike_delay := -1.0
var _strike_step := 0
var _lunge := Vector3.ZERO
var _combat_timer := 0.0
var _crush_time := 0.0
var _crush_delay := -1.0
var _dragon_time := 0.0
var _dragon_velocity := Vector3.ZERO
var _storm_time := 0.0
var _storm_fire_rate := 1.0
var _storm_infinite := false
var _in_crush_strike := false
var _grenade_cooldown := 0.0
var _target_timer := 0.0
var _since_drag := 10.0
var _shake := 0.0
var _recoil := 0.0
var _glow_timer := 0.0
var _footstep_timer := 0.0
var _multi_kill_count := 0
var _multi_kill_timer := 0.0
var _streak_is_ready: Array[bool] = [false, false, false]
var _streak_used: Array[bool] = [false, false, false]
var _roll_tween: Tween = null

func _ready() -> void:
    InputActions.ensure()
    floor_snap_length = 0.5
    floor_max_angle = deg_to_rad(50.0)

func _exit_tree() -> void:
    Engine.time_scale = 1.0

# ------------------------------------------------------------------------------------------------ construction
func build(p_gender: String, p_outfit: Dictionary, p_loadout: Dictionary, p_settings: SettingsManager) -> void:
    team = Teams.ALPHA
    display_name = "YOU"
    settings = p_settings
    loadout = p_loadout
    style = LoadoutCatalog.style_data(str(p_loadout.get("style", "tiger")))
    crush_move = str(p_loadout.get("crush", "quake"))
    var chosen_streaks: Array = p_loadout.get("streaks", ["supply", "airstrike", "drone"])
    streak_ids.clear()
    for id in chosen_streaks:
        streak_ids.append(str(id))
    while streak_ids.size() < 3:
        streak_ids.append("supply")
    max_health = 100.0 * float(style.get("health", 1.0))
    health = max_health
    max_armor = 50.0 + float(style.get("armor", 0.0))
    armor = max_armor
    setup_body(p_gender, "child", p_outfit, 1.2)
    weapon = WeaponController.new()
    weapon.name = "Weapons"
    add_child(weapon)
    weapon.damage_scale = float(style.get("gun_damage", 1.0))
    weapon.reload_scale = float(style.get("reload", 1.0))
    weapon.setup(str(p_loadout.get("primary", "viper")), str(p_loadout.get("secondary", "")), p_loadout.get("levels", {}))
    weapon.weapon_changed.connect(_on_weapon_changed)
    equip(weapon.current_id())
    _build_camera()
    _apply_settings()

func _apply_settings() -> void:
    if settings == null:
        return
    simple_mode = bool(settings.get_value("simple_mode", true))
    aim_assist = clampf(float(settings.get_value("aim_assist", 1.0)), 0.0, 1.0)
    camera_sensitivity = clampf(float(settings.get_value("camera_sensitivity", 1.0)), 0.4, 2.2)

func _build_camera() -> void:
    camera_rig = Node3D.new()
    camera_rig.name = "CameraRig"
    camera_rig.top_level = true
    add_child(camera_rig)
    spring = SpringArm3D.new()
    spring.name = "Arm"
    spring.spring_length = CAMERA_DISTANCE
    spring.collision_mask = Teams.LAYER_WORLD
    spring.margin = 0.25
    spring.position = Vector3(0.55, 0.0, 0.0)
    camera_rig.add_child(spring)
    camera = Camera3D.new()
    camera.name = "Camera"
    camera.fov = 68.0
    camera.near = 0.08
    camera.far = 600.0
    camera.current = true
    spring.add_child(camera)
    camera_rig.global_position = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)

func join_battle(p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager) -> void:
    super.join_battle(p_director, p_fx, p_audio)
    if director != null:
        director.player = self
    if fx != null and not fx.shake_requested.is_connected(_on_fx_shake):
        fx.shake_requested.connect(_on_fx_shake)

func _on_fx_shake(strength: float) -> void:
    _shake = maxf(_shake, strength)

func _on_weapon_changed(weapon_id: String) -> void:
    equip(weapon_id)

# ------------------------------------------------------------------------------------------------ input API (touch HUD / keyboard)
func set_mobile_move(value: Vector2) -> void:
    mobile_move = value

func set_attack_held(value: bool) -> void:
    attack_held = value

func request_jump() -> void:
    _jump_buffer = 0.16

func request_dodge() -> void:
    _want_dodge = true

func request_grenade() -> void:
    _want_grenade = true

func request_reload() -> void:
    _want_reload = true

func request_swap() -> void:
    _want_swap = true

func request_crush() -> void:
    _want_crush = true

func request_streak(slot: int) -> void:
    _want_streak = slot

## Dragging on the screen turns the camera (and therefore the aim). Called by the CameraDrag control.
func nudge_camera(delta_pixels: Vector2) -> void:
    yaw = wrapf(yaw - delta_pixels.x * 0.20 * camera_sensitivity, -180.0, 180.0)
    pitch = clampf(pitch - delta_pixels.y * 0.14 * camera_sensitivity, -38.0, 24.0)
    _since_drag = 0.0

func reset_camera_behind() -> void:
    yaw = rad_to_deg(rotation.y)
    pitch = -8.0
    snap_camera()

## Jumps the camera rig to the hero at once (used after spawning or respawning far from where the camera was).
func snap_camera() -> void:
    if camera_rig != null:
        camera_rig.global_position = global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
        camera_rig.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)

func _unhandled_input(event: InputEvent) -> void:
    var motion := event as InputEventMouseMotion
    if motion != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        nudge_camera(motion.relative * 1.4)

# ------------------------------------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
    if not alive:
        return
    tick_timers(delta)
    _tick_cooldowns(delta)
    combo.tick(delta)
    stats["best_combo"] = maxi(int(stats["best_combo"]), combo.best)
    _regen(delta)
    _read_keyboard_actions()
    var wish := _read_move()
    _update_target(delta)
    _handle_requests(wish)
    _tick_strike(delta)
    _tick_crush(delta)
    _handle_attack()
    var planar := _compute_planar(wish, delta)
    _face(wish, delta)
    apply_gravity(delta)
    if _jump_buffer > 0.0 and is_on_floor() and _dodge_time <= 0.0 and _crush_time <= 0.0:
        velocity.y = JUMP_VELOCITY
        _jump_buffer = 0.0
    velocity.x = planar.x
    velocity.z = planar.z
    move_and_slide()
    decay_knock(delta)
    _animate(delta, planar)

func _tick_cooldowns(delta: float) -> void:
    _jump_buffer = maxf(0.0, _jump_buffer - delta)
    _dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
    _dodge_time = maxf(0.0, _dodge_time - delta)
    _melee_cooldown = maxf(0.0, _melee_cooldown - delta)
    _combo_window = maxf(0.0, _combo_window - delta)
    _combat_timer = maxf(0.0, _combat_timer - delta)
    _grenade_cooldown = maxf(0.0, _grenade_cooldown - delta)
    _multi_kill_timer = maxf(0.0, _multi_kill_timer - delta)
    if _multi_kill_timer <= 0.0:
        _multi_kill_count = 0
    _lunge = _lunge.move_toward(Vector3.ZERO, 40.0 * delta)

func _regen(delta: float) -> void:
    if health >= max_health:
        return
    if Time.get_ticks_msec() - last_damage_msec > int(REGEN_DELAY * 1000.0):
        heal(REGEN_RATE * delta)

func _read_keyboard_actions() -> void:
    if Input.is_action_just_pressed("jump"):
        request_jump()
    if Input.is_action_just_pressed("dodge"):
        request_dodge()
    if Input.is_action_just_pressed("grenade"):
        request_grenade()
    if Input.is_action_just_pressed("reload"):
        request_reload()
    if Input.is_action_just_pressed("swap"):
        request_swap()
    if Input.is_action_just_pressed("crush"):
        request_crush()
    for slot in 3:
        if Input.is_action_just_pressed("streak_%d" % (slot + 1)):
            request_streak(slot)

## Desired planar direction in world space (length 0..1).
func _read_move() -> Vector3:
    var input := mobile_move
    var keys := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if keys.length() > input.length():
        input = keys
    if input.length() > 1.0:
        input = input.normalized()
    return Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(input.x, 0.0, input.y)

func _camera_forward_flat() -> Vector3:
    var radians := deg_to_rad(yaw)
    return Vector3(-sin(radians), 0.0, -cos(radians))

func _aim_flat_direction() -> Vector3:
    if target != null and is_instance_valid(target) and bool(target.get("alive")):
        var offset := target.global_position - global_position
        offset.y = 0.0
        if offset.length() > 0.1:
            return offset.normalized()
    return _camera_forward_flat()

func _compute_planar(wish: Vector3, _delta: float) -> Vector3:
    var speed := WALK_SPEED * float(style.get("speed", 1.0))
    var planar := wish * speed
    if _dodge_time > 0.0:
        planar = _dodge_dir * DODGE_SPEED
    elif _dragon_time > 0.0:
        planar = _dragon_velocity
    elif _crush_time > 0.0 and crush_move == "quake":
        planar = Vector3.ZERO
    else:
        if stunned > 0.0:
            planar *= 0.3
        elif aiming and attack_held:
            planar *= 0.88
        planar += _lunge
    return with_knock(planar)

func _face(wish: Vector3, delta: float) -> void:
    if _dodge_time > 0.0:
        return
    if _dragon_time > 0.0:
        face_direction(_dragon_velocity, delta, 30.0)
        return
    var aim_flat := _aim_flat_direction()
    if _combat_timer > 0.0:
        face_direction(aim_flat, delta, 16.0)
    elif wish.length() > 0.1:
        face_direction(wish, delta, 12.0)

# ------------------------------------------------------------------------------------------------ targeting
func _update_target(delta: float) -> void:
    _target_timer -= delta
    if _target_timer > 0.0:
        if target != null and not (is_instance_valid(target) and bool(target.get("alive"))):
            target = null
            target_changed.emit(null)
        return
    _target_timer = 0.12
    var previous := target
    if director == null or aim_assist <= 0.01:
        target = null
    else:
        var cone := AIM_CONE * (0.6 + 0.6 * aim_assist) * (2.0 if _storm_time > 0.0 else 1.0)
        var in_view: Array = []
        var eye := global_position + Vector3(0.0, body_height * 0.75, 0.0)
        var space := get_world_3d().direct_space_state
        for candidate in director.roster(Teams.OPPOSITION):
            var enemy := candidate as Fighter
            if enemy == null or enemy.global_position.distance_to(global_position) > AIM_RANGE:
                continue
            var query := PhysicsRayQueryParameters3D.create(eye, enemy.chest_position(), Teams.LAYER_WORLD)
            if space.intersect_ray(query).is_empty():
                in_view.append(enemy)
        target = AimAssist.pick(global_position, _camera_forward_flat(), in_view, AIM_RANGE, cone, target)
    if target != previous:
        target_changed.emit(target)

func _aim_direction() -> Vector3:
    var origin := muzzle_position()
    if target != null and is_instance_valid(target) and bool(target.get("alive")):
        var enemy := target as Fighter
        var point := enemy.chest_position() if enemy != null else target.global_position
        return (point - origin).normalized()
    if camera == null:
        return forward_flat()
    var from := camera.global_position
    var forward := -camera.global_transform.basis.z
    var to := from + forward * 80.0
    var query := PhysicsRayQueryParameters3D.create(from, to, Teams.bullet_mask_for(team))
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        to = hit["position"]
    return (to - origin).normalized()

# ------------------------------------------------------------------------------------------------ actions
func _handle_requests(wish: Vector3) -> void:
    if _want_dodge:
        _want_dodge = false
        _try_dodge(wish)
    if _want_grenade:
        _want_grenade = false
        _try_grenade()
    if _want_reload:
        _want_reload = false
        if weapon != null and weapon.start_reload() and audio != null:
            audio.play_sfx("reload_mag", 1.0, -2.0)
    if _want_swap:
        _want_swap = false
        if weapon != null and weapon.has_secondary():
            weapon.swap()
            if audio != null:
                audio.play_sfx("reload_done", 1.1, -3.0)
    if _want_crush:
        _want_crush = false
        _try_crush()
    if _want_streak >= 0:
        var slot := _want_streak
        _want_streak = -1
        _use_streak(slot)

func _handle_attack() -> void:
    if _storm_time > 0.0:
        return
    var wants := attack_held or Input.is_action_pressed("attack")
    if not wants or _crush_time > 0.0 or _dragon_time > 0.0 or _dodge_time > 0.0:
        if _combat_timer <= 0.0 and aiming:
            set_stance(false)
        return
    _combat_timer = STANCE_SECONDS
    var near: Node3D = null
    if director != null:
        near = director.nearest(global_position, Teams.OPPOSITION, MELEE_ENGAGE)
        if near == null and _combo_window > 0.0:
            near = director.nearest(global_position, Teams.OPPOSITION, MELEE_ENGAGE + 0.7)
    if near != null:
        _try_melee(near)
    else:
        _try_shoot()

func _try_shoot() -> void:
    if weapon == null or weapon.is_reloading():
        return
    if simple_mode and target == null:
        return
    show_weapon(true)
    set_stance(true)
    stats["shots"] = int(stats["shots"]) + 1
    shoot(_aim_direction())

func _after_shot(shot: Dictionary) -> void:
    var kick := float(shot.get("recoil", 0.5))
    _recoil += kick * 0.6
    _shake = maxf(_shake, kick * 0.05)

func _try_melee(victim: Node3D) -> void:
    if _melee_cooldown > 0.0 or _dodge_time > 0.0 or _strike_delay >= 0.0:
        return
    if _combo_window <= 0.0:
        _combo_step = 0
    var step := _combo_step
    var speed := float(style.get("melee_speed", 1.0))
    _melee_cooldown = MELEE_INTERVAL[step] / speed
    _strike_step = step
    _strike_delay = MELEE_HIT_DELAY / speed
    _combo_window = COMBO_WINDOW
    _combo_step = (step + 1) % MELEE_DAMAGE.size()
    var flat := victim.global_position - global_position
    flat.y = 0.0
    var distance := flat.length()
    if distance > 0.05:
        rotation.y = atan2(-flat.x, -flat.z)
        _lunge = flat.normalized() * minf(MELEE_LUNGE[step], maxf(distance - 0.9, 0.0) / 0.12)
    set_stance(false)
    show_weapon(false)
    if rig != null:
        if step == 0:
            rig.play_punch(true)
        elif step == 1:
            rig.play_punch(false)
        else:
            rig.play_kick()
    if audio != null:
        audio.play_sfx("whoosh", randf_range(0.9, 1.1), -6.0)

func _tick_strike(delta: float) -> void:
    if _strike_delay < 0.0:
        return
    _strike_delay -= delta
    if _strike_delay > 0.0:
        return
    _strike_delay = -1.0
    var step := _strike_step
    var damage: float = MELEE_DAMAGE[step] * float(style.get("melee_damage", 1.0))
    var reach: float = MELEE_REACH[step] * float(style.get("reach", 1.0))
    var victims := melee_strike(damage, reach, MELEE_ARC[step], MELEE_KNOCK[step], MELEE_STAGGER[step])
    if victims.is_empty():
        return
    var heavy := step >= 2
    if audio != null:
        audio.play_sfx("kick_hit" if heavy else "punch_light", randf_range(0.95, 1.05), -1.0)
    if fx != null:
        fx.hit_stop(0.09 if step == 3 else (0.06 if heavy else 0.035))
        fx.shake(0.55 if step == 3 else (0.3 if heavy else 0.15))

func _try_dodge(wish: Vector3) -> void:
    if _dodge_cooldown > 0.0 or _dodge_time > 0.0 or _crush_time > 0.0 or _dragon_time > 0.0:
        return
    var direction := wish
    if direction.length() < 0.2:
        direction = -forward_flat()
    direction = direction.normalized()
    _dodge_dir = direction
    _dodge_time = DODGE_TIME
    _dodge_cooldown = DODGE_COOLDOWN
    invulnerable = maxf(invulnerable, DODGE_IFRAMES)
    _perfect_used = false
    _strike_delay = -1.0
    rotation.y = atan2(-direction.x, -direction.z)
    _start_roll_visual()
    if audio != null:
        audio.play_sfx("dodge_roll", randf_range(0.95, 1.05), -2.0)
    dodge_started.emit()

func _start_roll_visual() -> void:
    if visual_root == null:
        return
    if _roll_tween != null and _roll_tween.is_valid():
        _roll_tween.kill()
    _set_roll_angle(0.0)
    _roll_tween = create_tween()
    _roll_tween.tween_method(_set_roll_angle, 0.0, -TAU, DODGE_TIME)
    _roll_tween.tween_callback(_end_roll_visual)

## Rotates the model about its middle (not its feet) so a somersault stays above the ground.
func _set_roll_angle(angle: float) -> void:
    if visual_root == null:
        return
    var centre := body_height * 0.5
    visual_root.rotation.x = angle
    visual_root.position = Vector3(0.0, centre - centre * cos(angle), -centre * sin(angle))

func _end_roll_visual() -> void:
    if visual_root != null:
        visual_root.rotation.x = 0.0
        visual_root.position.y = 0.0

## A hit landed while dodging: that is a PERFECT DODGE, which slows time for a moment and gives crush energy.
func _on_attack_evaded(info: DamageInfo) -> void:
    if _dodge_time <= 0.0 or _perfect_used or info.source_team != Teams.OPPOSITION:
        return
    _perfect_used = true
    stats["perfect_dodges"] = int(stats["perfect_dodges"]) + 1
    crush_meter.add(15.0)
    _dodge_cooldown = minf(_dodge_cooldown, 0.2)
    if settings == null or bool(settings.get_value("bullet_time", true)):
        if fx != null:
            fx.slow_motion(0.35, 1.3)
    announce.emit("PERFECT DODGE!", Color(0.55, 0.95, 1.0))
    if audio != null:
        audio.play_sfx("crush_ready", 1.3, -2.0)

func _try_grenade() -> void:
    if grenades <= 0 or _grenade_cooldown > 0.0 or _dodge_time > 0.0 or _crush_time > 0.0:
        return
    grenades -= 1
    _grenade_cooldown = GRENADE_COOLDOWN
    grenades_changed.emit(grenades)
    var strength := 0.9
    if target != null and is_instance_valid(target):
        strength = clampf(global_position.distance_to(target.global_position) / 12.0, 0.45, 1.15)
    throw_grenade(_aim_flat_direction(), strength)
    if rig != null:
        rig.play_punch(true)
    _combat_timer = STANCE_SECONDS

func add_grenades(count: int) -> void:
    grenades = mini(MAX_GRENADES, grenades + count)
    grenades_changed.emit(grenades)

# ------------------------------------------------------------------------------------------------ crush moves
func _try_crush() -> void:
    if _crush_time > 0.0 or _dodge_time > 0.0 or _dragon_time > 0.0 or _storm_time > 0.0:
        return
    if not crush_meter.spend():
        return
    stats["crushes"] = int(stats["crushes"]) + 1
    crush_triggered.emit(crush_move)
    set_stance(false)
    show_weapon(false)
    _combat_timer = 0.0
    if audio != null:
        audio.play_sfx("crush_" + crush_move, 1.0, 0.0)
    if fx != null:
        fx.shake(0.6)
        fx.ring(global_position + Vector3(0.0, 0.1, 0.0), 2.4, Color(1.0, 0.6, 0.2, 0.9), 0.35)
    if crush_move == "dragon":
        _begin_dragon()
    elif crush_move == "storm":
        _begin_storm()
    else:
        _begin_quake()

func _begin_quake() -> void:
    _crush_time = 0.85
    _crush_delay = 0.48
    invulnerable = maxf(invulnerable, 1.0)
    if rig != null:
        rig.play_slam()
    announce.emit("QUAKE!", Color(1.0, 0.6, 0.2))

func _begin_dragon() -> void:
    var victim: Node3D = null
    if director != null:
        victim = director.nearest(global_position, Teams.OPPOSITION, 18.0)
    var direction := forward_flat()
    var distance := 7.0
    if victim != null:
        var offset := victim.global_position - global_position
        offset.y = 0.0
        distance = maxf(offset.length() - 1.4, 1.0)
        if offset.length() > 0.05:
            direction = offset.normalized()
    _dragon_time = clampf(distance / 30.0, 0.12, 0.45)
    _dragon_velocity = direction * (distance / _dragon_time)
    _crush_time = _dragon_time + 0.5
    invulnerable = maxf(invulnerable, _dragon_time + 0.6)
    rotation.y = atan2(-direction.x, -direction.z)
    if rig != null:
        rig.play_kick()
    announce.emit("DRAGON KICK!", Color(1.0, 0.45, 0.2))

func _begin_storm() -> void:
    _storm_time = STORM_SECONDS
    _storm_fire_rate = weapon.fire_rate_scale
    _storm_infinite = weapon.infinite_ammo
    weapon.fire_rate_scale = _storm_fire_rate * 2.2
    weapon.infinite_ammo = true
    crush_meter.locked = true
    show_weapon(true)
    set_stance(true)
    announce.emit("BULLET STORM!", Color(1.0, 0.85, 0.3))

func _tick_crush(delta: float) -> void:
    _crush_time = maxf(0.0, _crush_time - delta)
    if _crush_delay >= 0.0:
        _crush_delay -= delta
        if _crush_delay <= 0.0:
            _crush_delay = -1.0
            _quake_impact()
    if _dragon_time > 0.0:
        _dragon_time -= delta
        if _dragon_time <= 0.0:
            _dragon_time = 0.0
            _dragon_impact()
    if _storm_time > 0.0:
        _storm_tick(delta)
    # Glow while the meter is full so the player knows CRUSH is ready.
    if crush_meter.is_ready() and rig != null:
        _glow_timer -= delta
        if _glow_timer <= 0.0:
            _glow_timer = 0.12
            rig.flash(0.32 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.008), Color(1.0, 0.62, 0.2))

func _quake_impact() -> void:
    var power := float(style.get("melee_damage", 1.0))
    var hits := Explosion.detonate(director, fx, global_position, QUAKE_RADIUS, 95.0 * power, team, self, 15.0, 1.6, false, DamageInfo.KIND_CRUSH)
    if fx != null:
        fx.ring(global_position + Vector3(0.0, 0.1, 0.0), QUAKE_RADIUS, Color(1.0, 0.55, 0.15, 0.9), 0.6)
        fx.ring(global_position + Vector3(0.0, 0.15, 0.0), QUAKE_RADIUS * 0.55, Color(1.0, 0.92, 0.5, 0.8), 0.45)
        fx.shake(1.3)
        fx.hit_stop(0.1)
    if audio != null:
        audio.play_sfx("crush_slam", 1.0, 1.0)
    heal(12.0)
    if hits > 0:
        announce.emit("CRUSHED %d!" % hits, Color(1.0, 0.8, 0.3))

func _dragon_impact() -> void:
    var power := float(style.get("melee_damage", 1.0))
    _in_crush_strike = true
    melee_strike(170.0 * power, 3.2, 220.0, 16.0, 1.5)
    _in_crush_strike = false
    Explosion.detonate(director, fx, global_position + forward_flat() * 1.2, 4.0, 70.0 * power, team, self, 12.0, 1.0, false, DamageInfo.KIND_CRUSH)
    if fx != null:
        fx.ring(global_position + Vector3(0.0, 0.1, 0.0), 4.0, Color(1.0, 0.5, 0.2, 0.9), 0.45)
        fx.shake(1.0)
        fx.hit_stop(0.09)
    if audio != null:
        audio.play_sfx("crush_slam", 1.15, 0.0)

func _storm_tick(delta: float) -> void:
    _storm_time -= delta
    _combat_timer = STANCE_SECONDS
    if weapon != null and weapon.can_fire():
        var enemy := _random_enemy(42.0)
        if enemy != null:
            var aim := (enemy.chest_position() - muzzle_position()).normalized()
            var flat := enemy.global_position - global_position
            flat.y = 0.0
            if flat.length() > 0.1:
                rotation.y = atan2(-flat.x, -flat.z)
            shoot(aim)
    if _storm_time <= 0.0:
        _storm_time = 0.0
        weapon.fire_rate_scale = _storm_fire_rate
        weapon.infinite_ammo = _storm_infinite
        crush_meter.locked = false

func _random_enemy(max_distance: float) -> Fighter:
    if director == null:
        return null
    var pool: Array = []
    for candidate in director.roster(Teams.OPPOSITION):
        var enemy := candidate as Fighter
        if enemy != null and enemy.global_position.distance_to(global_position) <= max_distance:
            pool.append(enemy)
    if pool.is_empty():
        return null
    return pool[randi() % pool.size()] as Fighter

# ------------------------------------------------------------------------------------------------ killstreaks
func streak_ready_slot(slot: int) -> bool:
    return slot >= 0 and slot < 3 and _streak_is_ready[slot] and not _streak_used[slot]

func streak_used_slot(slot: int) -> bool:
    return slot >= 0 and slot < 3 and _streak_used[slot]

func _check_streaks() -> void:
    for slot in 3:
        if _streak_used[slot] or _streak_is_ready[slot]:
            continue
        if kill_streak >= LoadoutCatalog.streak_kills(streak_ids[slot]):
            _streak_is_ready[slot] = true
            streak_ready.emit(slot, streak_ids[slot])
            announce.emit(str(LoadoutCatalog.streak_data(streak_ids[slot]).get("name", "STREAK")) + " READY", Color(0.6, 0.95, 1.0))
            if audio != null:
                audio.play_sfx("streak_ready", 1.0, -1.0)

func _use_streak(slot: int) -> void:
    if not streak_ready_slot(slot):
        return
    _streak_is_ready[slot] = false
    _streak_used[slot] = true
    streak_triggered.emit(streak_ids[slot])
    if audio != null:
        audio.play_sfx("streak_use", 1.0, -1.0)

# ------------------------------------------------------------------------------------------------ combat callbacks
func _on_damaged(info: DamageInfo, applied: float) -> void:
    stats["damage_taken"] = float(stats["damage_taken"]) + applied
    combo.reset()
    _shake = maxf(_shake, clampf(applied * 0.012, 0.15, 0.7))
    var direction := -info.direction
    if info.source != null and is_instance_valid(info.source):
        direction = info.source.global_position - global_position
    damage_from.emit(direction)
    if settings != null and bool(settings.get_value("vibration", true)):
        Input.vibrate_handheld(40)
    if audio != null:
        audio.play_sfx("hit_flesh", randf_range(0.9, 1.0), -2.0)

func _on_hit_landed(victim: Node3D, info: DamageInfo, applied: float) -> void:
    stats["damage_dealt"] = float(stats["damage_dealt"]) + applied
    if info.kind == DamageInfo.KIND_BULLET:
        stats["hits"] = int(stats["hits"]) + 1
    var killed := not bool(victim.get("alive"))
    var chest := victim.global_position + Vector3(0.0, 1.5, 0.0)
    var enemy := victim as Fighter
    if enemy != null:
        chest = enemy.chest_position() + Vector3(0.0, 0.5, 0.0)
    if not _in_crush_strike and info.kind != DamageInfo.KIND_CRUSH:
        combo.hit(12 if info.kind == DamageInfo.KIND_MELEE else 5)
        var gain := 0.0
        if info.kind == DamageInfo.KIND_MELEE:
            gain = 7.0 * float(style.get("crush_gain", 1.0))
        elif info.kind == DamageInfo.KIND_BULLET:
            gain = float(WeaponCatalog.get_weapon(info.weapon_id).get("crush", 1.0)) * 0.9 * float(style.get("crush_gain", 1.0))
        elif info.kind == DamageInfo.KIND_EXPLOSION:
            gain = 2.5
        crush_meter.add(gain)
    if fx != null and settings != null and bool(settings.get_value("damage_numbers", true)):
        if info.headshot:
            fx.damage_number(chest, applied, "crit")
        elif info.kind != DamageInfo.KIND_BULLET or applied >= 18.0:
            fx.damage_number(chest, applied, "crush" if info.kind == DamageInfo.KIND_CRUSH else "normal")
    hit_confirmed.emit(killed, info.headshot)
    if audio != null and not killed:
        audio.play_sfx("hit_marker", 1.0, -8.0)
    if killed:
        _register_kill(victim, info)

func _register_kill(victim: Node3D, info: DamageInfo) -> void:
    kills += 1
    kill_streak += 1
    if info.kind == DamageInfo.KIND_MELEE:
        stats["melee_kills"] = int(stats["melee_kills"]) + 1
    var worth := 100
    var score_value: Variant = victim.get("score_value")
    if score_value != null:
        worth = int(score_value)
    worth = int(round(float(worth) * combo.multiplier()))
    if info.kind != DamageInfo.KIND_CRUSH:
        crush_meter.add(8.0)
    if info.headshot:
        headshots += 1
        announce.emit("HEADSHOT!", Color(1.0, 0.85, 0.25))
    _multi_kill_count += 1
    _multi_kill_timer = MULTI_KILL_WINDOW
    if _multi_kill_count >= 2:
        announce.emit(MULTI_KILL_TEXT[mini(_multi_kill_count, MULTI_KILL_TEXT.size() - 1)], Color(1.0, 0.55, 0.25))
    kill_scored.emit(victim, worth, info.headshot)
    streak_progress.emit(kill_streak)
    _check_streaks()
    if audio != null:
        audio.play_sfx("hit_kill", 1.0, -3.0)

# ------------------------------------------------------------------------------------------------ downed / respawn
func _play_defeat(_info: DamageInfo) -> void:
    set_stance(false)
    kill_streak = 0
    streak_progress.emit(0)
    for slot in 3:
        _streak_is_ready[slot] = false
        _streak_used[slot] = false
    combo.reset()
    attack_held = false
    mobile_move = Vector2.ZERO
    _storm_time = 0.0
    _crush_time = 0.0
    _dragon_time = 0.0
    _crush_delay = -1.0
    _strike_delay = -1.0
    if weapon != null:
        weapon.fire_rate_scale = 1.0
        weapon.infinite_ammo = false
    crush_meter.locked = false
    if fx != null:
        fx.clear_time_effects()
        fx.poof(global_position + Vector3(0.0, body_height * 0.55, 0.0), Color(0.6, 0.85, 1.0, 1.0))
    if visual_root != null:
        if _roll_tween != null and _roll_tween.is_valid():
            _roll_tween.kill()
        _end_roll_visual()
        var tween := create_tween()
        tween.tween_property(visual_root, "rotation_degrees:x", 88.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(visual_root, "position:y", 0.1, 0.45)
    downed.emit()

func respawn(at: Vector3) -> void:
    alive = true
    health = max_health
    armor = max_armor * 0.6
    collision_layer = Teams.layer_for(team)
    global_position = at
    velocity = Vector3.ZERO
    stunned = 0.0
    invulnerable = 2.5
    _knock = Vector3.ZERO
    if visual_root != null:
        visual_root.rotation = Vector3.ZERO
        visual_root.position = Vector3.ZERO
        visual_root.scale = Vector3.ONE * body_scale
    if weapon != null:
        weapon.setup(str(loadout.get("primary", "viper")), str(loadout.get("secondary", "")), loadout.get("levels", {}))
        equip(weapon.current_id())
    grenades = maxi(grenades, 2)
    grenades_changed.emit(grenades)
    last_damage_msec = Time.get_ticks_msec()
    if director != null:
        director.register(self, team)
    health_changed.emit(health, max_health)
    armor_changed.emit(armor, max_armor)
    reset_camera_behind()
    set_physics_process(true)
    respawned.emit()

# ------------------------------------------------------------------------------------------------ animation + camera
func _animate(delta: float, planar: Vector3) -> void:
    if rig != null:
        var move_speed := Vector2(velocity.x, velocity.z).length()
        if _dodge_time > 0.0:
            move_speed = 0.0
        rig.animate(delta, move_speed, is_on_floor())
    var pitch_radians := deg_to_rad(pitch)
    update_weapon_pose(delta, pitch_radians * 0.6)
    if is_on_floor() and planar.length() > 3.0 and _dodge_time <= 0.0:
        _footstep_timer -= delta
        if _footstep_timer <= 0.0:
            _footstep_timer = 0.36
            if audio != null:
                audio.play_footstep("grass")

func _process(delta: float) -> void:
    if camera_rig == null:
        return
    var real_delta := delta / maxf(Engine.time_scale, 0.05)
    _since_drag += real_delta
    var focus := global_position + Vector3(0.0, CAMERA_HEIGHT, 0.0)
    camera_rig.global_position = camera_rig.global_position.lerp(focus, minf(1.0, real_delta * 16.0))
    _recoil = lerpf(_recoil, 0.0, minf(1.0, real_delta * 9.0))
    camera_rig.rotation = Vector3(deg_to_rad(pitch + _recoil), deg_to_rad(yaw), 0.0)
    _shake = maxf(0.0, _shake - real_delta * 2.2)
    if _shake > 0.001:
        camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.25
        camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.25
    else:
        camera.h_offset = 0.0
        camera.v_offset = 0.0
    var wanted_fov := 68.0
    if _dodge_time > 0.0 or _dragon_time > 0.0:
        wanted_fov = 76.0
    elif _crush_time > 0.0:
        wanted_fov = 72.0
    camera.fov = lerpf(camera.fov, wanted_fov, minf(1.0, real_delta * 7.0))

func get_stats() -> Dictionary:
    var copy := stats.duplicate()
    copy["kills"] = kills
    copy["headshots"] = headshots
    return copy
