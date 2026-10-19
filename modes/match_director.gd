extends Node
class_name MatchDirector

## Runs one battle from the countdown to the result screen. It owns the rules of the four modes:
##   crush       first to crush N opponents (they keep arriving from their bases)
##   siege       survive W waves, each bigger than the last
##   domination  hold the flags; first side to the target score wins
##   commander   defeat the boss; reinforcements are called at 60% and 25% of his health
## It spawns the opposition and the squad-mates, drops loot, runs killstreaks, tracks lives and produces the result Dictionary.
## Timers are plain counters in _process (no awaits), so nothing can resume after the scene was freed.
signal match_started
signal objective_changed(text: String, current: int, target: int)
signal wave_started(number: int, total: int)
signal announcement(text: String, color: Color)
signal kill_feed(text: String)
signal boss_spawned(boss: Node3D)
signal match_ended(result: Dictionary)
signal lives_changed(lives: int)
signal countdown_changed(value: int)
signal score_changed(alpha: float, opposition: float, target: float)
signal zones_changed

const COUNTDOWN_SECONDS := 3
const PLAYER_RESPAWN_SECONDS := 3.0
const ALLY_RESPAWN_SECONDS := 8.0
const SUPPLY_INTERVAL := 22.0
const MAX_FIELD_SUPPLIES := 5
const ALLY_NAMES: Array[String] = ["BRAVO", "CHARLIE", "DELTA"]
const GOLD := Color(1.0, 0.85, 0.3)
const CYAN := Color(0.6, 0.95, 1.0)
const RED := Color(1.0, 0.4, 0.35)
const GREEN := Color(0.5, 1.0, 0.6)

var config: Dictionary = {}
var world: BattleWorld
var player: PlayerFighter
var director: CombatDirector
var fx: CombatFX
var audio: AudioManager
var quality: QualityManager

var mode := "crush"
var difficulty := 1.0
var lives := 3
var running := false
var finished := false
var elapsed := 0.0
var crushed := 0
var target_value := 20
var wave := 0
var wave_total := 1
var zones: Array[CaptureZone] = []
var alpha_score := 0.0
var opposition_score := 0.0
var xp_earned := 0
var coins_earned := 0
var deaths := 0
var boss: EnemyFighter = null
var enemy_faction_name := "OPPOSITION"

var _factions: Array[String] = ["jackals"]
var _queue: Array[String] = []
var _spawn_timer := 1.0
var _active_limit := 6
var _rng := RandomNumberGenerator.new()
var _countdown := 0.0
var _last_count := -1
var _between_waves := false
var _wave_pause := 0.0
var _allies: Dictionary = {}
var _ally_respawns: Array[Dictionary] = []
var _player_respawn := -1.0
var _end_delay := -1.0
var _end_won := false
var _supply_timer: float = SUPPLY_INTERVAL
var _supplies_on_field := 0
var _score_timer := 0.0
var _objective_timer := 0.0
var _last_objective := -1

# ------------------------------------------------------------------------------------------------ rules helpers (pure, unit-tested)
static func compute_stars(won: bool, lives_lost: int, best_combo: int) -> int:
    if not won:
        return 0
    var stars := 1
    if lives_lost <= 1:
        stars += 1
    if lives_lost == 0 and best_combo >= 9:
        stars += 1
    return stars

static func wave_size(number: int, p_difficulty: float) -> int:
    return 5 + number * 2 + int(p_difficulty * 2.0)

static func kill_xp(score_value: int) -> int:
    return int(round(float(score_value) * 0.35))

# ------------------------------------------------------------------------------------------------ setup
func setup(p_config: Dictionary, p_world: BattleWorld, p_player: PlayerFighter, p_director: CombatDirector, p_fx: CombatFX, p_audio: AudioManager, p_quality: QualityManager) -> void:
    config = p_config
    world = p_world
    player = p_player
    director = p_director
    fx = p_fx
    audio = p_audio
    quality = p_quality
    mode = str(config.get("mode", "crush"))
    difficulty = float(config.get("difficulty", 1.0))
    lives = int(config.get("lives", 3))
    target_value = int(config.get("target", 20))
    _factions.clear()
    for id in config.get("factions", ["jackals"]):
        _factions.append(str(id))
    if _factions.is_empty():
        _factions.append("jackals")
    enemy_faction_name = EnemyCatalog.faction_name(_factions[0])
    _active_limit = int(config.get("max_active", 6))
    if quality != null:
        if quality.quality == "lowest":
            _active_limit = mini(_active_limit, 5)
        elif quality.quality == "low":
            _active_limit = mini(_active_limit, 6)
    _rng.seed = int(config.get("seed", 1))
    director.set_aggression(clampf(difficulty, 1.0, 4.0))
    world.crate_broken.connect(_on_crate_broken)
    player.downed.connect(_on_player_downed)
    player.streak_triggered.connect(_on_streak_triggered)

func begin() -> void:
    lives_changed.emit(lives)
    var ally_count := int(config.get("allies", 2))
    for i in ally_count:
        _spawn_ally(i, ally_count)
    if mode == "siege":
        wave_total = target_value
    elif mode == "domination":
        _setup_domination()
    elif mode == "commander":
        _setup_commander()
    _countdown = float(COUNTDOWN_SECONDS) + 0.5
    announcement.emit("GET READY", CYAN)
    _emit_objective(true)

func _setup_domination() -> void:
    var names: Array[String] = ["A", "B", "C"]
    for i in mini(3, world.capture_points.size()):
        var zone := CaptureZone.new()
        zone.name = "Zone_" + names[i]
        world.add_child(zone)
        zone.global_position = world.capture_points[i]
        zone.setup(names[i])
        zone.set_initial_owner(Teams.OPPOSITION if i != 1 else -1)
        zone.ownership_changed.connect(_on_zone_changed)
        zones.append(zone)
        var defenders := 2 if i != 1 else 1
        for d in defenders:
            _spawn_defender(zone)
    zones_changed.emit()

func _spawn_defender(zone: CaptureZone) -> void:
    var type_id := EnemyCatalog.pick_type(_factions[_rng.randi() % _factions.size()], _rng.randf(), difficulty >= 1.5)
    var spot := world.random_point_near(zone.global_position, 1.5, 5.0)
    var enemy := spawn_enemy(type_id, _factions[0], spot)
    enemy.hold_point = zone.global_position
    enemy.has_hold_point = true
    enemy.hunt_player = false

func _setup_commander() -> void:
    boss = spawn_enemy("commander", _factions[0], world.boss_spawn)
    boss_spawned.emit(boss)
    var guards := 4
    for i in guards:
        var type_id := EnemyCatalog.pick_type(_factions[0], _rng.randf(), difficulty >= 1.5)
        spawn_enemy(type_id, _factions[0], world.random_point_near(world.boss_spawn, 5.0, 9.0))

# ------------------------------------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
    if finished or director == null:
        return
    if _end_delay >= 0.0:
        _end_delay -= delta
        if _end_delay <= 0.0:
            _end_delay = -1.0
            _end(_end_won)
        return
    if not running:
        _tick_countdown(delta)
        return
    elapsed += delta
    _tick_respawns(delta)
    _tick_spawner(delta)
    if mode == "siege":
        _tick_siege(delta)
    elif mode == "domination":
        _tick_domination(delta)
    _tick_supplies(delta)
    _objective_timer -= delta
    if _objective_timer <= 0.0:
        _objective_timer = 0.4
        _emit_objective(false)

func _tick_countdown(delta: float) -> void:
    _countdown -= delta
    var whole := int(ceil(_countdown))
    if whole != _last_count and whole >= 1 and whole <= COUNTDOWN_SECONDS:
        _last_count = whole
        countdown_changed.emit(whole)
        if audio != null:
            audio.play_sfx("countdown_tick", 1.0, -3.0)
    if _countdown <= 0.0:
        running = true
        _spawn_timer = 0.5
        if mode == "siege":
            _start_wave(1)
        announcement.emit("FIGHT!", GOLD)
        countdown_changed.emit(0)
        if audio != null:
            audio.play_sfx("wave_start", 1.0, -1.0)
        match_started.emit()

func _tick_respawns(delta: float) -> void:
    if _player_respawn >= 0.0:
        _player_respawn -= delta
        if _player_respawn <= 0.0:
            _player_respawn = -1.0
            if not player.alive:
                player.respawn(world.alpha_spawn)
                announcement.emit("BACK IN THE FIGHT", GREEN)
    var index := _ally_respawns.size() - 1
    while index >= 0:
        var entry: Dictionary = _ally_respawns[index]
        entry["left"] = float(entry["left"]) - delta
        if float(entry["left"]) <= 0.0:
            _spawn_ally(int(entry["index"]), int(entry["total"]))
            _ally_respawns.remove_at(index)
        index -= 1

# ------------------------------------------------------------------------------------------------ spawning
func _pick_type(allow_heavy: bool = false) -> String:
    var faction := _factions[_rng.randi() % _factions.size()]
    return EnemyCatalog.pick_type(faction, _rng.randf(), allow_heavy or difficulty >= 1.6)

func _tick_spawner(delta: float) -> void:
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return
    _spawn_timer = _rng.randf_range(0.8, 1.5)
    if mode == "siege" and _between_waves:
        return
    var alive := director.count(Teams.OPPOSITION)
    var limit := _active_limit
    if mode == "commander":
        limit = mini(_active_limit, 5)
    if alive >= limit:
        return
    if mode == "crush":
        if crushed + alive + _queue.size() < target_value:
            _queue.append(_pick_type())
    elif mode == "domination" or mode == "commander":
        if _queue.size() < 2:
            _queue.append(_pick_type())
    if _queue.is_empty():
        return
    var type_id: String = _queue.pop_front()
    var faction := _factions[_rng.randi() % _factions.size()]
    spawn_enemy(type_id, faction, world.pick_enemy_spawn(player.global_position, 26.0))

func spawn_enemy(type_id: String, faction_id: String, at: Vector3) -> EnemyFighter:
    var enemy := EnemyFighter.new()
    enemy.build(type_id, faction_id, Teams.OPPOSITION, difficulty, _rng.randi())
    enemy.join_battle(director, fx, audio)
    world.add_child(enemy)
    enemy.global_position = at
    var toward := player.global_position - at
    enemy.rotation.y = atan2(-toward.x, -toward.z)
    enemy.died.connect(_on_enemy_died.bind(enemy))
    if enemy.is_boss:
        enemy.summon_requested.connect(_on_boss_summon)
    return enemy

func _spawn_ally(index: int, total: int) -> void:
    var type_id := "ally_rifle" if index % 2 == 0 else "ally_smg"
    var ally := EnemyFighter.new()
    ally.build(type_id, "jackals", Teams.ALPHA, 1.0, _rng.randi())
    ally.ally_index = index
    ally.ally_count = total
    ally.display_name = ALLY_NAMES[index % ALLY_NAMES.size()]
    ally.join_battle(director, fx, audio)
    world.add_child(ally)
    var spawns := world.alpha_ally_spawns
    ally.global_position = spawns[index % spawns.size()]
    var tag := Label3D.new()
    tag.text = ally.display_name
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.no_depth_test = true
    tag.shaded = false
    tag.font_size = 44
    tag.pixel_size = 0.006
    tag.outline_size = 8
    tag.modulate = Color(0.45, 0.95, 0.95)
    tag.outline_modulate = Color(0.05, 0.1, 0.2)
    tag.position = Vector3(0.0, ally.body_height + 0.45, 0.0)
    ally.add_child(tag)
    ally.died.connect(_on_ally_died.bind(index, total))
    _allies[index] = ally

# ------------------------------------------------------------------------------------------------ modes
func _start_wave(number: int) -> void:
    wave = number
    _between_waves = false
    _queue.clear()
    var count := wave_size(number, difficulty)
    for i in count:
        _queue.append(_pick_type(number >= 3))
    if number % 3 == 0 or number == wave_total:
        _queue.append("heavy")
    wave_started.emit(number, wave_total)
    announcement.emit("WAVE %d" % number, GOLD)
    if audio != null:
        audio.play_sfx("wave_start", 1.0, -1.0)

func _tick_siege(delta: float) -> void:
    if _between_waves:
        _wave_pause -= delta
        if _wave_pause <= 0.0:
            _start_wave(wave + 1)
        return
    if _queue.is_empty() and director.count(Teams.OPPOSITION) == 0:
        announcement.emit("WAVE CLEARED", GREEN)
        if wave >= wave_total:
            _finish_later(true)
            return
        _between_waves = true
        _wave_pause = 6.0
        _drop_pause_supplies()

func _tick_domination(delta: float) -> void:
    for zone in zones:
        var alpha_count := _count_in_zone(zone, Teams.ALPHA)
        var opposition_count := _count_in_zone(zone, Teams.OPPOSITION)
        zone.update_zone(delta, alpha_count, opposition_count)
        if zone.owner_team == Teams.ALPHA:
            alpha_score += delta
        elif zone.owner_team == Teams.OPPOSITION:
            opposition_score += delta
    opposition_score += 0.4 * delta
    _score_timer -= delta
    if _score_timer <= 0.0:
        _score_timer = 0.25
        score_changed.emit(alpha_score, opposition_score, float(target_value))
    if alpha_score >= float(target_value):
        _finish_later(true)
    elif opposition_score >= float(target_value):
        _finish_later(false)

func _count_in_zone(zone: CaptureZone, team: int) -> int:
    var total := 0
    for candidate in director.roster(team):
        var fighter := candidate as Node3D
        if fighter != null and zone.contains(fighter.global_position):
            total += 1
    return total

func _on_zone_changed(zone: CaptureZone, new_owner: int) -> void:
    if new_owner == Teams.ALPHA:
        announcement.emit("FLAG %s CAPTURED" % zone.zone_name, GREEN)
    else:
        announcement.emit("FLAG %s LOST" % zone.zone_name, RED)
    if audio != null:
        audio.play_sfx("capture_done", 1.0, -2.0)
    if fx != null:
        fx.ring(zone.global_position + Vector3(0.0, 0.2, 0.0), zone.radius * 1.3, zone.owner_color(), 0.7)
    zones_changed.emit()

func _on_boss_summon(count: int) -> void:
    if boss == null or not is_instance_valid(boss) or not boss.alive:
        return
    announcement.emit("REINFORCEMENTS!", RED)
    for i in count:
        var spot := world.random_point_near(boss.global_position, 6.0, 10.0)
        spawn_enemy(_pick_type(true), _factions[0], spot)

func _finish_later(won: bool) -> void:
    if _end_delay >= 0.0 or finished:
        return
    _end_won = won
    _end_delay = 1.4 if won else 1.0

# ------------------------------------------------------------------------------------------------ events
func _on_enemy_died(info: DamageInfo, enemy: EnemyFighter) -> void:
    crushed += 1
    xp_earned += kill_xp(enemy.score_value)
    _drop_loot(enemy.global_position, enemy.coin_value)
    var who := "ALPHA"
    if info.source != null and is_instance_valid(info.source):
        var killer := info.source as Fighter
        if killer != null:
            who = killer.display_name
    kill_feed.emit("%s CRUSHED %s" % [who, enemy.display_name])
    if finished:
        return
    if mode == "crush" and crushed >= target_value:
        _finish_later(true)
    elif mode == "commander" and enemy == boss:
        announcement.emit("COMMANDER DOWN!", GOLD)
        _finish_later(true)

func _on_ally_died(_info: DamageInfo, index: int, total: int) -> void:
    kill_feed.emit("%s IS DOWN" % ALLY_NAMES[index % ALLY_NAMES.size()])
    _allies.erase(index)
    _ally_respawns.append({"index": index, "total": total, "left": ALLY_RESPAWN_SECONDS})

func _on_player_downed() -> void:
    if finished:
        return
    deaths += 1
    lives -= 1
    lives_changed.emit(lives)
    if mode == "domination":
        opposition_score += 6.0
    if lives <= 0:
        announcement.emit("MISSION FAILED", RED)
        _finish_later(false)
        return
    announcement.emit("DOWN! BACK IN 3...", RED)
    _player_respawn = PLAYER_RESPAWN_SECONDS

# ------------------------------------------------------------------------------------------------ loot and supplies
func _drop(kind: String, amount: int, at: Vector3, is_supply: bool = false) -> void:
    var pickup := Pickup.create(kind, amount)
    world.add_child(pickup)
    pickup.global_position = at + Vector3(0.0, 0.2, 0.0)
    pickup.player = player
    pickup.collected.connect(_on_pickup_collected)
    if is_supply:
        _supplies_on_field += 1
        pickup.tree_exited.connect(_on_supply_gone)

func _on_supply_gone() -> void:
    _supplies_on_field = maxi(0, _supplies_on_field - 1)

func _drop_loot(at: Vector3, coin_amount: int) -> void:
    if coin_amount > 0:
        _drop("coin", coin_amount, at + Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6)))
    var health_chance := 0.35 if player.health_fraction() < 0.5 else 0.12
    var ammo_low := player.weapon != null and player.weapon.reserve_ammo() < 30
    var ammo_chance := 0.45 if ammo_low else 0.16
    var roll := _rng.randf()
    if roll < health_chance:
        _drop("health", 40, at)
    elif roll < health_chance + ammo_chance:
        _drop("ammo", 1, at)
    elif roll < health_chance + ammo_chance + 0.06:
        _drop("armor", 35, at)
    elif roll < health_chance + ammo_chance + 0.12:
        _drop("grenade", 1, at)

func _on_crate_broken(at: Vector3) -> void:
    _drop("coin", 3, at)
    var roll := _rng.randf()
    if roll < 0.5:
        _drop("ammo", 1, at + Vector3(0.5, 0.0, 0.0))
    elif roll < 0.85:
        _drop("health", 35, at + Vector3(-0.5, 0.0, 0.0))
    else:
        _drop("armor", 30, at + Vector3(0.0, 0.0, 0.5))

func _tick_supplies(delta: float) -> void:
    _supply_timer -= delta
    if _supply_timer > 0.0 or _supplies_on_field >= MAX_FIELD_SUPPLIES or world.pickup_points.is_empty():
        return
    _supply_timer = SUPPLY_INTERVAL
    var kinds: Array[String] = ["health", "ammo", "armor", "grenade"]
    var kind := kinds[_rng.randi() % kinds.size()]
    if player.health_fraction() < 0.5:
        kind = "health"
    elif player.weapon != null and player.weapon.reserve_ammo() < 30:
        kind = "ammo"
    var point := world.pickup_points[_rng.randi() % world.pickup_points.size()]
    _drop(kind, 40 if kind == "health" else (35 if kind == "armor" else 1), point, true)

func _drop_pause_supplies() -> void:
    var base := world.alpha_spawn
    _drop("health", 45, base + Vector3(-2.0, 0.0, -6.0), true)
    _drop("ammo", 1, base + Vector3(2.0, 0.0, -6.0), true)
    _drop("armor", 35, base + Vector3(0.0, 0.0, -8.0), true)

func _on_pickup_collected(pickup: Pickup) -> void:
    var above := pickup.global_position + Vector3(0.0, 1.2, 0.0)
    if pickup.kind == "coin":
        coins_earned += pickup.amount
        if audio != null:
            audio.play_sfx("pickup_coin", randf_range(0.95, 1.1), -6.0)
    elif pickup.kind == "health":
        player.heal(float(pickup.amount))
        if fx != null:
            fx.damage_number(above, float(pickup.amount), "heal", "+%d" % pickup.amount)
        if audio != null:
            audio.play_sfx("pickup_health", 1.0, -3.0)
    elif pickup.kind == "ammo":
        if player.weapon != null:
            player.weapon.refill(0.6)
        if fx != null:
            fx.damage_number(above, 0.0, "xp", "AMMO")
        if audio != null:
            audio.play_sfx("pickup_ammo", 1.0, -3.0)
    elif pickup.kind == "armor":
        player.add_armor(float(pickup.amount))
        if fx != null:
            fx.damage_number(above, 0.0, "xp", "ARMOUR")
        if audio != null:
            audio.play_sfx("pickup_ammo", 1.2, -3.0)
    elif pickup.kind == "grenade":
        player.add_grenades(pickup.amount)
        if fx != null:
            fx.damage_number(above, 0.0, "xp", "+GRENADE")
        if audio != null:
            audio.play_sfx("pickup_ammo", 0.8, -3.0)

# ------------------------------------------------------------------------------------------------ killstreaks
func _on_streak_triggered(streak_id: String) -> void:
    announcement.emit(str(LoadoutCatalog.streak_data(streak_id).get("name", "STREAK")), CYAN)
    if streak_id == "airstrike":
        var strike := AirStrike.create(director, fx, audio, player)
        world.add_child(strike)
        strike.start(_best_cluster_centre())
    elif streak_id == "drone":
        var drone := GuardianDrone.create(director, fx, audio, player)
        world.add_child(drone)
        drone.start(player.global_position + Vector3(0.0, 6.0, 0.0))
    else:
        var drop := SupplyDrop.create(fx, audio)
        world.add_child(drop)
        drop.landed.connect(_on_supply_landed)
        drop.start(world.snap(player.global_position + player.forward_flat() * 4.0))

func _on_supply_landed(at: Vector3) -> void:
    _drop("health", 50, at + Vector3(1.6, 0.0, 0.0))
    _drop("ammo", 1, at + Vector3(-1.6, 0.0, 0.0))
    _drop("armor", 40, at + Vector3(0.0, 0.0, 1.6))
    _drop("grenade", 2, at + Vector3(0.0, 0.0, -1.6))

## Centre of the densest group of opposition fighters (falls back to a point ahead of the player).
func _best_cluster_centre() -> Vector3:
    var best := Vector3.INF
    var best_count := 0
    var roster := director.roster(Teams.OPPOSITION)
    for candidate in roster:
        var node := candidate as Node3D
        if node == null:
            continue
        var neighbours := 0
        for other in roster:
            var other_node := other as Node3D
            if other_node != null and other_node.global_position.distance_to(node.global_position) <= 8.0:
                neighbours += 1
        if neighbours > best_count:
            best_count = neighbours
            best = node.global_position
    if not best.is_finite():
        return world.snap(player.global_position + player.forward_flat() * 14.0)
    return world.snap(best)

# ------------------------------------------------------------------------------------------------ objective + end
func _emit_objective(force: bool) -> void:
    var text := "CRUSH " + enemy_faction_name
    var current := crushed
    var goal := target_value
    if mode == "siege":
        text = "SURVIVE THE WAVES"
        current = wave
        goal = wave_total
    elif mode == "domination":
        text = "HOLD THE FLAGS"
        current = int(alpha_score)
        goal = target_value
    elif mode == "commander":
        text = "DEFEAT THE COMMANDER"
        current = 0 if (boss != null and is_instance_valid(boss) and boss.alive) else 1
        goal = 1
    if force or current != _last_objective:
        _last_objective = current
        objective_changed.emit(text, current, goal)

func _end(won: bool) -> void:
    if finished:
        return
    finished = true
    running = false
    if fx != null:
        fx.clear_time_effects()
    var stars := compute_stars(won, deaths, player.combo.best)
    var reward_xp := int(config.get("reward_xp", 150))
    var reward_coins := int(config.get("reward_coins", 100))
    var bonus_xp := int(float(reward_xp) * (0.4 + 0.2 * float(stars))) if won else int(float(reward_xp) * 0.15)
    var bonus_coins := reward_coins if won else int(float(reward_coins) * 0.25)
    var player_stats := player.get_stats()
    var shots := maxi(int(player_stats.get("shots", 0)), 1)
    var result := {
        "won": won,
        "mode": mode,
        "operation": int(config.get("index", -1)),
        "title": str(config.get("title", "BATTLE")),
        "arena": str(config.get("arena", "")),
        "time": elapsed,
        "kills": player.kills,
        "crushed": crushed,
        "headshots": player.headshots,
        "best_combo": player.combo.best,
        "style_points": player.combo.points,
        "deaths": deaths,
        "stars": stars,
        "xp": xp_earned + bonus_xp + int(float(player.combo.points) / 20.0),
        "coins": coins_earned + bonus_coins,
        "crushes": int(player_stats.get("crushes", 0)),
        "melee_kills": int(player_stats.get("melee_kills", 0)),
        "perfect_dodges": int(player_stats.get("perfect_dodges", 0)),
        "damage_dealt": int(float(player_stats.get("damage_dealt", 0.0))),
        "accuracy": clampf(float(int(player_stats.get("hits", 0))) / float(shots), 0.0, 1.0)
    }
    for team in [Teams.ALPHA, Teams.OPPOSITION]:
        for candidate in director.roster(team):
            var node := candidate as Node
            if node != null and node != player:
                node.set_physics_process(false)
    player.attack_held = false
    player.mobile_move = Vector2.ZERO
    player.invulnerable = 999.0
    if won and player.rig != null:
        player.rig.play_cheer()
    if audio != null:
        audio.play_sfx("victory_fanfare" if won else "defeat_sting", 1.0, 0.0)
    match_ended.emit(result)
