extends Node
class_name WeaponController

## Ammunition, fire-rate, bloom and reload for one fighter's two weapon slots. It never touches the physics world: it only
## answers "may I fire now?" and hands back what a shot is made of, so the same logic serves the player, squad-mates and
## enemies (and can be unit-tested without a scene).
signal fired(weapon_id: String)
signal reload_started(weapon_id: String, seconds: float)
signal reload_finished(weapon_id: String)
signal ammo_changed(in_mag: int, reserve: int)
signal weapon_changed(weapon_id: String)
signal dry_fire

var slots: Array[String] = ["viper", ""]
var active := 0
var levels: Dictionary = {}
## Enemies never run out of spare rounds (they still reload, which gives the player a window).
var infinite_reserve := false
## Crush "Bullet Storm": nothing is consumed while it lasts.
var infinite_ammo := false
var fire_rate_scale := 1.0
var damage_scale := 1.0
var reload_scale := 1.0

var _mags: Dictionary = {}
var _reserves: Dictionary = {}
var _cooldown := 0.0
var _reload_left := 0.0
var _reload_total := 0.0
var _bloom := 0.0

func setup(primary: String, secondary: String, p_levels: Dictionary = {}) -> void:
    levels = p_levels.duplicate()
    slots.clear()
    slots.append(primary if WeaponCatalog.is_valid(primary) else "")
    slots.append(secondary if WeaponCatalog.is_valid(secondary) else "")
    if slots[0] == "" and slots[1] != "":
        slots[0] = slots[1]
        slots[1] = ""
    active = 0
    _mags.clear()
    _reserves.clear()
    _cooldown = 0.0
    _reload_left = 0.0
    _bloom = 0.0
    for id in slots:
        if id != "":
            _mags[id] = mag_size(id)
            _reserves[id] = int(WeaponCatalog.get_weapon(id).get("reserve", 0))
    weapon_changed.emit(current_id())
    _emit_ammo()

func current_id() -> String:
    if active < 0 or active >= slots.size():
        return ""
    return slots[active]

func spec() -> Dictionary:
    return WeaponCatalog.get_weapon(current_id())

func level_of(id: String) -> int:
    return clampi(int(levels.get(id, 0)), 0, WeaponCatalog.MAX_LEVEL)

func mag_size(id: String) -> int:
    return WeaponCatalog.mag_at_level(id, level_of(id))

func mag_ammo() -> int:
    return int(_mags.get(current_id(), 0))

func reserve_ammo() -> int:
    return int(_reserves.get(current_id(), 0))

func is_reloading() -> bool:
    return _reload_left > 0.0

## 0 when idle, then 0..1 while a reload is in progress (drives the HUD ring).
func reload_fraction() -> float:
    if _reload_left <= 0.0 or _reload_total <= 0.0:
        return 0.0
    return clampf(1.0 - _reload_left / _reload_total, 0.0, 1.0)

func current_spread() -> float:
    return float(spec().get("spread", 1.0)) + _bloom

func has_secondary() -> bool:
    return slots.size() > 1 and slots[1] != ""

func can_fire() -> bool:
    return current_id() != "" and _reload_left <= 0.0 and _cooldown <= 0.0 and (mag_ammo() > 0 or infinite_ammo)

func is_empty() -> bool:
    return mag_ammo() <= 0 and not infinite_ammo and (reserve_ammo() <= 0 and not infinite_reserve)

## Returns an empty Dictionary when the weapon cannot fire right now; otherwise everything the shooter needs for one shot.
func try_fire() -> Dictionary:
    var id := current_id()
    if id == "" or _reload_left > 0.0 or _cooldown > 0.0:
        return {}
    var data := WeaponCatalog.get_weapon(id)
    if data.is_empty():
        return {}
    var in_mag := int(_mags.get(id, 0))
    if in_mag <= 0 and not infinite_ammo:
        dry_fire.emit()
        _cooldown = 0.3
        start_reload()
        return {}
    if not infinite_ammo:
        _mags[id] = in_mag - 1
    _cooldown = 1.0 / maxf(float(data.get("rate", 1.0)) * fire_rate_scale, 0.1)
    var spread := current_spread()
    _bloom = minf(float(data.get("bloom_max", 3.0)), _bloom + float(data.get("bloom", 0.5)))
    var shot := {
        "id": id,
        "pellets": int(data.get("pellets", 1)),
        "damage": WeaponCatalog.damage_at_level(id, level_of(id)) * damage_scale,
        "spread": spread,
        "range": float(data.get("range", 40.0)),
        "knockback": float(data.get("knockback", 1.0)),
        "recoil": float(data.get("recoil", 0.5)),
        "projectile": str(data.get("projectile", "")),
        "blast": float(data.get("blast", 0.0)),
        "projectile_speed": float(data.get("projectile_speed", 30.0)),
        "tracer": data.get("tracer", Color.WHITE),
        "sfx": str(data.get("sfx", "")),
        "crush": float(data.get("crush", 1.0))
    }
    fired.emit(id)
    _emit_ammo()
    if int(_mags.get(id, 0)) <= 0 and not infinite_ammo:
        start_reload()
    return shot

func start_reload() -> bool:
    var id := current_id()
    if id == "" or _reload_left > 0.0:
        return false
    var data := WeaponCatalog.get_weapon(id)
    if data.is_empty():
        return false
    if int(_mags.get(id, 0)) >= mag_size(id):
        return false
    if int(_reserves.get(id, 0)) <= 0 and not infinite_reserve:
        return false
    _reload_total = float(data.get("reload", 1.5)) * reload_scale
    _reload_left = maxf(_reload_total, 0.05)
    reload_started.emit(id, _reload_total)
    return true

func cancel_reload() -> void:
    _reload_left = 0.0

func swap() -> void:
    if not has_secondary():
        return
    cancel_reload()
    active = 1 - active
    _cooldown = 0.25
    _bloom = 0.0
    weapon_changed.emit(current_id())
    _emit_ammo()

## Ammo crate: adds `fraction` of each weapon's full reserve (1.0 = completely restocked) and tops up the magazines.
func refill(fraction: float) -> void:
    for id in slots:
        if id == "":
            continue
        var cap := int(WeaponCatalog.get_weapon(id).get("reserve", 0))
        var add := int(ceil(float(cap) * clampf(fraction, 0.0, 1.0)))
        _reserves[id] = mini(cap, int(_reserves.get(id, 0)) + add)
    _emit_ammo()

func tick(delta: float) -> void:
    if _cooldown > 0.0:
        _cooldown = maxf(0.0, _cooldown - delta)
    if _bloom > 0.0:
        _bloom = maxf(0.0, _bloom - delta * 5.0)
    if _reload_left > 0.0:
        _reload_left -= delta
        if _reload_left <= 0.0:
            _reload_left = 0.0
            _finish_reload()

func _process(delta: float) -> void:
    tick(delta)

func _finish_reload() -> void:
    var id := current_id()
    if id == "":
        return
    var room := mag_size(id) - int(_mags.get(id, 0))
    var spare := int(_reserves.get(id, 0))
    var moved := room if infinite_reserve else mini(room, spare)
    _mags[id] = int(_mags.get(id, 0)) + moved
    if not infinite_reserve:
        _reserves[id] = spare - moved
    reload_finished.emit(id)
    _emit_ammo()

func _emit_ammo() -> void:
    ammo_changed.emit(mag_ammo(), reserve_ammo())
