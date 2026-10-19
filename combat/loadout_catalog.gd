extends RefCounted
class_name LoadoutCatalog

## Everything the Armory lets a player pick besides guns: fighting STYLE (stat bonuses), CRUSH move, KILLSTREAK rewards and
## outfit colours. Plain data, so the menu, the match and the tests all read the same numbers.
const STYLE_ORDER: Array[String] = ["tiger", "crane", "hawk", "turtle"]
const CRUSH_ORDER: Array[String] = ["quake", "dragon", "storm"]
const STREAK_ORDER: Array[String] = ["supply", "airstrike", "drone"]
const OUTFIT_ORDER: Array[String] = ["alpha", "ember", "jade", "violet", "shadow", "gold"]

const STYLES := {
    "tiger": {"name": "TIGER", "icon": "style_tiger", "unlock_rank": 1, "price": 0, "blurb": "HEAVY KUNG-FU HITS",
        "melee_damage": 1.25, "melee_speed": 0.95, "reach": 1.0, "crush_gain": 1.0, "gun_damage": 0.95, "reload": 1.0, "armor": 0.0, "health": 1.0, "speed": 1.0},
    "crane": {"name": "CRANE", "icon": "style_crane", "unlock_rank": 3, "price": 500, "blurb": "FAST KICKS, LONG REACH",
        "melee_damage": 1.0, "melee_speed": 1.3, "reach": 1.2, "crush_gain": 1.1, "gun_damage": 0.95, "reload": 1.0, "armor": 0.0, "health": 1.0, "speed": 1.08},
    "hawk": {"name": "HAWK", "icon": "style_hawk", "unlock_rank": 6, "price": 900, "blurb": "GUN MASTER",
        "melee_damage": 0.85, "melee_speed": 1.0, "reach": 1.0, "crush_gain": 0.9, "gun_damage": 1.2, "reload": 0.8, "armor": 0.0, "health": 1.0, "speed": 1.0},
    "turtle": {"name": "TURTLE", "icon": "style_turtle", "unlock_rank": 9, "price": 1300, "blurb": "TOUGH AS NAILS",
        "melee_damage": 1.0, "melee_speed": 1.0, "reach": 1.0, "crush_gain": 1.0, "gun_damage": 1.0, "reload": 1.0, "armor": 40.0, "health": 1.2, "speed": 0.94}
}

const CRUSH_MOVES := {
    "quake": {"name": "QUAKE", "icon": "crush_quake", "unlock_rank": 1, "price": 0, "blurb": "SLAM THE GROUND AND FLOOR EVERYONE NEARBY"},
    "dragon": {"name": "DRAGON KICK", "icon": "crush_dragon", "unlock_rank": 5, "price": 600, "blurb": "DASH AND KICK THE NEAREST ENEMY"},
    "storm": {"name": "BULLET STORM", "icon": "crush_storm", "unlock_rank": 8, "price": 1000, "blurb": "ENDLESS AMMO AND AUTO-AIM FOR 4 SECONDS"}
}

const STREAKS := {
    "supply": {"name": "SUPPLY DROP", "icon": "supply", "kills": 3, "unlock_rank": 1, "price": 0, "blurb": "AMMO, HEALTH AND ARMOUR FALL FROM THE SKY"},
    "airstrike": {"name": "AIR STRIKE", "icon": "rocket", "kills": 5, "unlock_rank": 3, "price": 500, "blurb": "BOMBS RAIN ON THE BIGGEST ENEMY GROUP"},
    "drone": {"name": "GUARDIAN DRONE", "icon": "drone", "kills": 7, "unlock_rank": 7, "price": 900, "blurb": "A DRONE SHOOTS ENEMIES FOR YOU"}
}

const OUTFITS := {
    "alpha": {"name": "ALPHA BLUE", "shirt": Color(0.16, 0.42, 0.82), "pants": Color(0.14, 0.18, 0.28), "leather": Color(0.96, 0.72, 0.16), "unlock_rank": 1, "price": 0},
    "ember": {"name": "EMBER", "shirt": Color(0.88, 0.38, 0.14), "pants": Color(0.22, 0.17, 0.15), "leather": Color(0.98, 0.84, 0.30), "unlock_rank": 2, "price": 250},
    "jade": {"name": "JADE", "shirt": Color(0.14, 0.62, 0.45), "pants": Color(0.12, 0.22, 0.20), "leather": Color(0.88, 0.95, 0.60), "unlock_rank": 4, "price": 400},
    "violet": {"name": "VIOLET", "shirt": Color(0.56, 0.30, 0.86), "pants": Color(0.18, 0.14, 0.30), "leather": Color(0.98, 0.58, 0.80), "unlock_rank": 6, "price": 600},
    "shadow": {"name": "SHADOW", "shirt": Color(0.16, 0.17, 0.20), "pants": Color(0.10, 0.10, 0.12), "leather": Color(0.85, 0.20, 0.22), "unlock_rank": 8, "price": 800},
    "gold": {"name": "GOLD", "shirt": Color(0.92, 0.74, 0.18), "pants": Color(0.30, 0.22, 0.12), "leather": Color(0.20, 0.20, 0.24), "unlock_rank": 12, "price": 1500}
}

static func style_data(id: String) -> Dictionary:
    return STYLES.get(id, STYLES["tiger"])

static func crush_data(id: String) -> Dictionary:
    return CRUSH_MOVES.get(id, CRUSH_MOVES["quake"])

static func streak_data(id: String) -> Dictionary:
    return STREAKS.get(id, STREAKS["supply"])

static func outfit_data(id: String) -> Dictionary:
    return OUTFITS.get(id, OUTFITS["alpha"])

static func streak_kills(id: String) -> int:
    return int(streak_data(id).get("kills", 3))

## Builds an AvatarRig outfit dictionary (skin / hair come from the gender defaults; colours from the chosen outfit).
static func rig_outfit(outfit_id: String, p_gender: String, role_seed: int) -> Dictionary:
    var base := AvatarRig.outfit_for("default", role_seed, p_gender)
    var data := outfit_data(outfit_id)
    base["shirt"] = data.get("shirt", base["shirt"])
    base["pants"] = data.get("pants", base["pants"])
    base["leather"] = data.get("leather", base["leather"])
    base["pack"] = false
    base["hat"] = ""
    return base

## Which of a category's entries a player of `rank` may use (price 0 entries are always owned; others must be bought).
static func available_at_rank(catalog: Dictionary, order: Array[String], rank: int) -> Array[String]:
    var out: Array[String] = []
    for id in order:
        if int(catalog[id].get("unlock_rank", 1)) <= rank:
            out.append(id)
    return out
