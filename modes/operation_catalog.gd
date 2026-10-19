extends RefCounted
class_name OperationCatalog

## The campaign: 26 operations named with the NATO phonetic alphabet, ALPHA to ZULU. Every operation is generated from its
## index (no hand-written table to keep in sync), so the order, difficulty curve and map rotation are always consistent.
## A, B, C ... rotate Team Crush / Last Stand / Domination; every fifth operation (E, J, O, T, Y) and the finale (Z) is a
## Commander hunt against a boss.
const CALLSIGNS: Array[String] = [
    "ALPHA", "BRAVO", "CHARLIE", "DELTA", "ECHO", "FOXTROT", "GOLF", "HOTEL", "INDIA", "JULIET", "KILO", "LIMA", "MIKE",
    "NOVEMBER", "OSCAR", "PAPA", "QUEBEC", "ROMEO", "SIERRA", "TANGO", "UNIFORM", "VICTOR", "WHISKEY", "X-RAY", "YANKEE", "ZULU"
]
const MODE_ORDER: Array[String] = ["crush", "siege", "domination", "commander"]
const MODE_NAMES := {"crush": "TEAM CRUSH", "siege": "LAST STAND", "domination": "DOMINATION", "commander": "COMMANDER HUNT"}
const MODE_BLURBS := {
    "crush": "CRUSH THE OPPOSITION BEFORE THEY CRUSH YOU",
    "siege": "SURVIVE EVERY WAVE",
    "domination": "CAPTURE AND HOLD THE FLAGS",
    "commander": "DEFEAT THE COMMANDER AND HIS GUARDS"
}
const MODE_ICONS := {"crush": "crush", "siege": "shield", "domination": "flag", "commander": "crown"}
const DOMINATION_TARGET := 200
const MAX_LIVES := 3

static func count() -> int:
    return CALLSIGNS.size()

static func mode_for(index: int) -> String:
    if index >= count() - 1 or (index + 1) % 5 == 0:
        return "commander"
    var cycle: Array[String] = ["crush", "siege", "domination"]
    return cycle[index % 3]

static func mode_name(mode: String) -> String:
    return str(MODE_NAMES.get(mode, "BATTLE"))

static func difficulty_for(index: int) -> float:
    return 1.0 + float(clampi(index, 0, count() - 1)) * 0.09

static func target_for(mode: String, index: int) -> int:
    if mode == "crush":
        return mini(18 + 2 * index, 60)
    if mode == "siege":
        return mini(4 + int(float(index) / 4.0), 10)
    if mode == "domination":
        return DOMINATION_TARGET
    return 1

static func operation(index: int) -> Dictionary:
    var i := clampi(index, 0, count() - 1)
    var mode := mode_for(i)
    var difficulty := difficulty_for(i)
    var arena_id := ArenaCatalog.ORDER[i % ArenaCatalog.ORDER.size()]
    var first_faction := EnemyCatalog.FACTION_ORDER[i % EnemyCatalog.FACTION_ORDER.size()]
    var second_faction := EnemyCatalog.FACTION_ORDER[(int(float(i) / 3.0) + 1) % EnemyCatalog.FACTION_ORDER.size()]
    var factions: Array[String] = [first_faction]
    if second_faction != first_faction and i >= 3:
        factions.append(second_faction)
    return {
        "index": i,
        "letter": char(65 + i),
        "callsign": CALLSIGNS[i],
        "title": "OPERATION " + CALLSIGNS[i],
        "mode": mode,
        "arena": arena_id,
        "factions": factions,
        "difficulty": difficulty,
        "lives": MAX_LIVES,
        "allies": 2,
        "target": target_for(mode, i),
        "max_active": clampi(4 + int(difficulty * 1.2), 4, 10),
        "reward_xp": 180 + 45 * i,
        "reward_coins": 120 + 30 * i,
        "boss": mode == "commander",
        "seed": 1000 + i * 77
    }

## A free-play match (Quick Battle): the same dictionary shape as an operation, built from the player's choices.
static func quick_battle(mode: String, arena_id: String, difficulty_step: int, faction_id: String) -> Dictionary:
    var level := clampi(difficulty_step, 0, 3)
    var difficulty := 1.0 + float(level) * 0.8
    var index := level * 6
    var factions: Array[String] = [faction_id if EnemyCatalog.FACTIONS.has(faction_id) else "jackals"]
    return {
        "index": -1,
        "letter": "Q",
        "callsign": "QUICK",
        "title": "QUICK BATTLE",
        "mode": mode,
        "arena": arena_id if ArenaCatalog.is_valid(arena_id) else ArenaCatalog.ORDER[0],
        "factions": factions,
        "difficulty": difficulty,
        "lives": MAX_LIVES,
        "allies": 2,
        "target": target_for(mode, index),
        "max_active": clampi(4 + int(difficulty * 1.2), 4, 10),
        "reward_xp": 120 + 40 * level,
        "reward_coins": 80 + 25 * level,
        "boss": mode == "commander",
        "seed": randi() % 100000
    }
