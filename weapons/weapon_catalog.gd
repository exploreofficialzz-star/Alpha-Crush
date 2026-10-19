extends RefCounted
class_name WeaponCatalog

## Every gun in Alpha Crush, as plain data. Numbers are for upgrade level 0; WeaponController applies the level.
## rate = shots per second, spread/bloom = degrees, range = metres, reload = seconds.
## fall_start..fall_end is the distance band over which damage fades to FALLOFF_FLOOR.
## "projectile" weapons launch a rocket instead of firing a hit-scan ray (blast = explosion radius in metres).
const MAX_LEVEL := 5
const UPGRADE_BASE_COST := 120
const DAMAGE_PER_LEVEL := 0.08
const MAG_PER_LEVEL := 0.10
const FALLOFF_FLOOR := 0.35

const ORDER: Array[String] = ["viper", "hornet", "falcon", "boomer", "eagle", "bison", "comet"]

const WEAPONS := {
    "viper": {
        "name": "VIPER", "kind": "pistol", "icon": "wpn_pistol", "tier": 1,
        "damage": 24.0, "rate": 4.2, "mag": 12, "reserve": 96, "reload": 1.1,
        "spread": 1.1, "bloom": 0.7, "bloom_max": 4.0, "range": 52.0, "fall_start": 28.0, "fall_end": 52.0,
        "pellets": 1, "recoil": 0.7, "knockback": 1.2, "crush": 1.8, "sfx": "gun_pistol",
        "unlock_rank": 1, "price": 0, "tracer": Color(1.0, 0.86, 0.45),
        "model": {"length": 0.24, "height": 0.15, "barrel": 0.10, "stock": 0.0, "mag": 0.07, "scope": false, "color": Color(0.20, 0.21, 0.25), "accent": Color(0.96, 0.62, 0.16)}
    },
    "hornet": {
        "name": "HORNET", "kind": "smg", "icon": "wpn_smg", "tier": 1,
        "damage": 11.0, "rate": 12.0, "mag": 32, "reserve": 192, "reload": 1.5,
        "spread": 2.6, "bloom": 0.5, "bloom_max": 6.0, "range": 40.0, "fall_start": 16.0, "fall_end": 40.0,
        "pellets": 1, "recoil": 0.45, "knockback": 0.6, "crush": 1.1, "sfx": "gun_smg",
        "unlock_rank": 2, "price": 400, "tracer": Color(1.0, 0.80, 0.35),
        "model": {"length": 0.34, "height": 0.17, "barrel": 0.14, "stock": 0.10, "mag": 0.14, "scope": false, "color": Color(0.17, 0.18, 0.21), "accent": Color(0.20, 0.70, 0.95)}
    },
    "falcon": {
        "name": "FALCON", "kind": "rifle", "icon": "wpn_rifle", "tier": 2,
        "damage": 21.0, "rate": 8.0, "mag": 30, "reserve": 180, "reload": 1.9,
        "spread": 1.5, "bloom": 0.55, "bloom_max": 4.5, "range": 75.0, "fall_start": 40.0, "fall_end": 75.0,
        "pellets": 1, "recoil": 0.9, "knockback": 1.0, "crush": 1.4, "sfx": "gun_rifle",
        "unlock_rank": 4, "price": 900, "tracer": Color(1.0, 0.90, 0.55),
        "model": {"length": 0.52, "height": 0.17, "barrel": 0.24, "stock": 0.20, "mag": 0.13, "scope": false, "color": Color(0.16, 0.20, 0.17), "accent": Color(0.95, 0.80, 0.20)}
    },
    "boomer": {
        "name": "BOOMER", "kind": "shotgun", "icon": "wpn_shotgun", "tier": 2,
        "damage": 10.0, "rate": 1.25, "mag": 6, "reserve": 48, "reload": 2.3,
        "spread": 6.5, "bloom": 1.0, "bloom_max": 8.0, "range": 28.0, "fall_start": 6.0, "fall_end": 20.0,
        "pellets": 9, "recoil": 1.8, "knockback": 3.0, "crush": 0.9, "sfx": "gun_shotgun",
        "unlock_rank": 6, "price": 1200, "tracer": Color(1.0, 0.70, 0.30),
        "model": {"length": 0.50, "height": 0.15, "barrel": 0.30, "stock": 0.18, "mag": 0.0, "scope": false, "color": Color(0.30, 0.22, 0.16), "accent": Color(0.85, 0.25, 0.20)}
    },
    "eagle": {
        "name": "EAGLE", "kind": "sniper", "icon": "wpn_sniper", "tier": 3,
        "damage": 120.0, "rate": 0.85, "mag": 5, "reserve": 30, "reload": 2.5,
        "spread": 0.15, "bloom": 1.2, "bloom_max": 3.0, "range": 140.0, "fall_start": 120.0, "fall_end": 140.0,
        "pellets": 1, "recoil": 2.2, "knockback": 4.0, "crush": 6.0, "sfx": "gun_sniper",
        "unlock_rank": 9, "price": 1800, "tracer": Color(0.70, 0.95, 1.0),
        "model": {"length": 0.66, "height": 0.16, "barrel": 0.34, "stock": 0.22, "mag": 0.08, "scope": true, "color": Color(0.14, 0.16, 0.20), "accent": Color(0.55, 0.90, 1.0)}
    },
    "bison": {
        "name": "BISON", "kind": "lmg", "icon": "wpn_lmg", "tier": 3,
        "damage": 16.0, "rate": 10.0, "mag": 75, "reserve": 300, "reload": 3.6,
        "spread": 2.4, "bloom": 0.4, "bloom_max": 6.5, "range": 70.0, "fall_start": 35.0, "fall_end": 70.0,
        "pellets": 1, "recoil": 1.1, "knockback": 1.4, "crush": 1.3, "sfx": "gun_lmg",
        "unlock_rank": 12, "price": 2400, "tracer": Color(1.0, 0.75, 0.30),
        "model": {"length": 0.60, "height": 0.20, "barrel": 0.26, "stock": 0.22, "mag": 0.18, "scope": false, "color": Color(0.22, 0.22, 0.18), "accent": Color(0.90, 0.45, 0.15)}
    },
    "comet": {
        "name": "COMET", "kind": "launcher", "icon": "wpn_launcher", "tier": 4,
        "damage": 150.0, "rate": 0.6, "mag": 1, "reserve": 9, "reload": 2.6,
        "spread": 0.4, "bloom": 0.0, "bloom_max": 0.0, "range": 120.0, "fall_start": 120.0, "fall_end": 121.0,
        "pellets": 1, "recoil": 2.6, "knockback": 0.0, "crush": 7.0, "sfx": "gun_launcher",
        "projectile": "rocket", "blast": 4.6, "projectile_speed": 34.0,
        "unlock_rank": 15, "price": 3200, "tracer": Color(1.0, 0.55, 0.20),
        "model": {"length": 0.90, "height": 0.20, "barrel": 0.10, "stock": 0.0, "mag": 0.0, "scope": false, "color": Color(0.25, 0.30, 0.22), "accent": Color(0.95, 0.30, 0.20)}
    }
}

static func is_valid(id: String) -> bool:
    return WEAPONS.has(id)

static func get_weapon(id: String) -> Dictionary:
    if WEAPONS.has(id):
        return WEAPONS[id]
    return {}

static func display_name(id: String) -> String:
    return str(get_weapon(id).get("name", id.to_upper()))

static func icon_name(id: String) -> String:
    return str(get_weapon(id).get("icon", "wpn_pistol"))

static func unlock_rank(id: String) -> int:
    return int(get_weapon(id).get("unlock_rank", 1))

static func price(id: String) -> int:
    return int(get_weapon(id).get("price", 0))

static func tier(id: String) -> int:
    return int(get_weapon(id).get("tier", 1))

static func fire_interval(id: String) -> float:
    return 1.0 / maxf(float(get_weapon(id).get("rate", 1.0)), 0.1)

static func damage_at_level(id: String, level: int) -> float:
    var base := float(get_weapon(id).get("damage", 10.0))
    return base * (1.0 + DAMAGE_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL)))

static func mag_at_level(id: String, level: int) -> int:
    var base := int(get_weapon(id).get("mag", 10))
    return maxi(1, int(round(float(base) * (1.0 + MAG_PER_LEVEL * float(clampi(level, 0, MAX_LEVEL))))))

## Sustained damage per second when every shot lands (used by the Armory to compare guns).
static func dps(id: String, level: int = 0) -> float:
    var data := get_weapon(id)
    return damage_at_level(id, level) * float(data.get("rate", 1.0)) * float(data.get("pellets", 1))

## Coins to raise `id` from `level` to `level + 1`; 0 when it is already at the top.
static func upgrade_cost(id: String, level: int) -> int:
    if level >= MAX_LEVEL or not is_valid(id):
        return 0
    return UPGRADE_BASE_COST * (level + 1) * tier(id)

## 1.0 up close, fading to FALLOFF_FLOOR between fall_start and fall_end.
static func range_multiplier(id: String, distance: float) -> float:
    var data := get_weapon(id)
    var start := float(data.get("fall_start", 30.0))
    var finish := float(data.get("fall_end", 60.0))
    if distance <= start:
        return 1.0
    var t := clampf((distance - start) / maxf(finish - start, 0.1), 0.0, 1.0)
    return lerpf(1.0, FALLOFF_FLOOR, t)

static func ids_for_rank(rank: int) -> Array[String]:
    var out: Array[String] = []
    for id in ORDER:
        if unlock_rank(id) <= rank:
            out.append(id)
    return out
