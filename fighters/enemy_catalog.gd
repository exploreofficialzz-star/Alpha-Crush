extends RefCounted
class_name EnemyCatalog

## Who the player fights (and who fights beside them). Plain data: the AI in EnemyFighter reads these numbers.
## role "gunner" shoots from a preferred distance band; role "melee" rushes in and trades blows (one telegraphed swing at a
## time, limited by attack tokens). Damage numbers are scaled DOWN versus the player's guns on purpose: enemies are many.
const TYPES := {
    "grunt": {"name": "GRUNT", "role": "gunner", "hp": 60.0, "armor": 0.0, "speed": 3.5, "weapon": "falcon", "damage": 0.26, "rate": 0.55,
        "burst": 3, "pause": 1.4, "accuracy": 3.2, "sight": 48.0, "band_min": 9.0, "band_max": 22.0, "reaction": 0.7, "score": 100, "coins": 6, "scale": 1.0},
    "rusher": {"name": "RUSHER", "role": "melee", "hp": 55.0, "armor": 0.0, "speed": 5.6, "melee_damage": 9.0, "reach": 1.8, "windup": 0.5, "cooldown": 1.5,
        "sight": 40.0, "reaction": 0.4, "score": 110, "coins": 6, "scale": 1.0},
    "shotgunner": {"name": "BLASTER", "role": "gunner", "hp": 80.0, "armor": 0.0, "speed": 3.9, "weapon": "boomer", "damage": 0.32, "rate": 0.8,
        "burst": 1, "pause": 1.6, "accuracy": 1.5, "sight": 36.0, "band_min": 3.0, "band_max": 11.0, "reaction": 0.6, "score": 140, "coins": 8, "scale": 1.0},
    "sniper": {"name": "SNIPER", "role": "gunner", "hp": 45.0, "armor": 0.0, "speed": 2.8, "weapon": "eagle", "damage": 0.24, "rate": 1.0,
        "burst": 1, "pause": 3.0, "accuracy": 0.6, "sight": 62.0, "band_min": 24.0, "band_max": 46.0, "reaction": 1.2, "aim_time": 1.3, "score": 180, "coins": 10, "scale": 1.0},
    "heavy": {"name": "HEAVY", "role": "gunner", "hp": 220.0, "armor": 80.0, "speed": 2.6, "weapon": "bison", "damage": 0.20, "rate": 0.8,
        "burst": 9, "pause": 1.6, "accuracy": 3.8, "sight": 46.0, "band_min": 8.0, "band_max": 20.0, "reaction": 0.9, "score": 320, "coins": 18, "scale": 1.12,
        "stagger_resist": 0.75, "knock_resist": 0.6},
    "grenadier": {"name": "BOMBER", "role": "gunner", "hp": 70.0, "armor": 0.0, "speed": 3.6, "weapon": "hornet", "damage": 0.24, "rate": 0.6,
        "burst": 4, "pause": 1.6, "accuracy": 4.0, "sight": 44.0, "band_min": 8.0, "band_max": 20.0, "reaction": 0.7, "score": 200, "coins": 10, "scale": 1.0,
        "special": "grenade", "special_cooldown": 6.5},
    "ninja": {"name": "NINJA", "role": "melee", "hp": 85.0, "armor": 0.0, "speed": 6.2, "melee_damage": 12.0, "reach": 2.0, "windup": 0.4, "cooldown": 1.2,
        "sight": 46.0, "reaction": 0.3, "score": 220, "coins": 12, "scale": 1.0, "special": "dash", "special_cooldown": 7.0},
    "commander": {"name": "COMMANDER", "role": "gunner", "hp": 900.0, "armor": 150.0, "speed": 3.3, "weapon": "falcon", "damage": 0.30, "rate": 0.7,
        "burst": 6, "pause": 1.2, "accuracy": 2.2, "sight": 70.0, "band_min": 7.0, "band_max": 18.0, "reaction": 0.5, "score": 1500, "coins": 120, "scale": 1.25,
        "special": "slam", "special_cooldown": 7.0, "stagger_resist": 0.9, "knock_resist": 0.85, "boss": true},
    "ally_rifle": {"name": "ALLY", "role": "gunner", "hp": 160.0, "armor": 0.0, "speed": 4.2, "weapon": "falcon", "damage": 0.40, "rate": 0.7,
        "burst": 4, "pause": 1.0, "accuracy": 2.5, "sight": 55.0, "band_min": 8.0, "band_max": 24.0, "reaction": 0.3, "score": 0, "coins": 0, "scale": 1.0},
    "ally_smg": {"name": "ALLY", "role": "gunner", "hp": 160.0, "armor": 0.0, "speed": 4.6, "weapon": "hornet", "damage": 0.45, "rate": 0.7,
        "burst": 6, "pause": 0.9, "accuracy": 3.0, "sight": 45.0, "band_min": 5.0, "band_max": 16.0, "reaction": 0.3, "score": 0, "coins": 0, "scale": 1.0}
}

## Opposition "sides". Each has a signature look (clothes tinted in its colours) and a favourite mix of fighters.
const FACTIONS := {
    "jackals": {"name": "IRON JACKALS", "shirt": Color(0.42, 0.43, 0.46), "pants": Color(0.20, 0.21, 0.23), "leather": Color(0.96, 0.52, 0.12),
        "mix": {"grunt": 5, "shotgunner": 2, "sniper": 1, "grenadier": 1, "rusher": 1}},
    "fists": {"name": "SHADOW FISTS", "shirt": Color(0.16, 0.12, 0.24), "pants": Color(0.10, 0.08, 0.14), "leather": Color(0.82, 0.22, 0.62),
        "mix": {"rusher": 4, "ninja": 4, "grunt": 1}},
    "vipers": {"name": "RED VIPERS", "shirt": Color(0.12, 0.38, 0.22), "pants": Color(0.10, 0.18, 0.12), "leather": Color(0.62, 0.95, 0.20),
        "mix": {"grunt": 3, "grenadier": 3, "rusher": 2, "sniper": 1}},
    "bulls": {"name": "STEEL BULLS", "shirt": Color(0.62, 0.14, 0.14), "pants": Color(0.22, 0.10, 0.10), "leather": Color(0.96, 0.80, 0.20),
        "mix": {"heavy": 3, "grunt": 3, "shotgunner": 2, "rusher": 1}}
}
const FACTION_ORDER: Array[String] = ["jackals", "fists", "vipers", "bulls"]

static func type_data(id: String) -> Dictionary:
    return TYPES.get(id, TYPES["grunt"])

static func faction_data(id: String) -> Dictionary:
    return FACTIONS.get(id, FACTIONS["jackals"])

static func faction_name(id: String) -> String:
    return str(faction_data(id).get("name", "OPPOSITION"))

static func is_boss(id: String) -> bool:
    return bool(type_data(id).get("boss", false))

## AvatarRig outfit for a fighter: faction colours for the opposition, Alpha colours for the squad-mates.
static func outfit_for(faction_id: String, type_id: String, role_seed: int, p_gender: String, ally: bool) -> Dictionary:
    var outfit := AvatarRig.outfit_for("default", role_seed, p_gender)
    var palette := LoadoutCatalog.outfit_data("jade") if ally else faction_data(faction_id)
    outfit["shirt"] = palette.get("shirt", outfit["shirt"])
    outfit["pants"] = palette.get("pants", outfit["pants"])
    outfit["leather"] = palette.get("leather", outfit["leather"])
    outfit["pack"] = false
    outfit["hat"] = ""
    if type_id == "commander":
        outfit["shirt"] = Color(0.10, 0.10, 0.12)
        outfit["leather"] = Color(0.98, 0.84, 0.25)
    return outfit

## Picks a fighter type from a faction's weighted mix using a 0..1 roll (deterministic for tests).
static func pick_type(faction_id: String, roll: float, allow_heavy: bool = true) -> String:
    var mix: Dictionary = faction_data(faction_id).get("mix", {})
    var total := 0.0
    for id in mix.keys():
        if not allow_heavy and str(id) == "heavy":
            continue
        total += float(mix[id])
    var cursor := clampf(roll, 0.0, 0.9999) * total
    for id in mix.keys():
        if not allow_heavy and str(id) == "heavy":
            continue
        cursor -= float(mix[id])
        if cursor < 0.0:
            return str(id)
    return "grunt"
