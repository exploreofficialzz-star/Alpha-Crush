extends Node
class_name PlayerProgress

## Everything that persists about the player's career: rank and XP, coins, owned guns / styles / crush moves / streaks /
## outfits, weapon upgrade levels, the chosen loadout, stars earned per operation and lifetime statistics.
## It is a plain data service: SaveSystem stores `snapshot()` and hands it back through `restore()`.
signal changed
signal rank_up(new_rank: int)

const MAX_RANK := 40
const RANK_TITLES: Array[String] = ["RECRUIT", "PRIVATE", "CORPORAL", "SERGEANT", "LIEUTENANT", "CAPTAIN", "MAJOR", "COLONEL", "GENERAL", "ALPHA LEGEND"]
const CATEGORY_STYLES := "styles"
const CATEGORY_CRUSH := "crush"
const CATEGORY_STREAKS := "streaks"
const CATEGORY_OUTFITS := "outfits"
const CATEGORY_WEAPONS := "weapons"

var xp := 0
var rank := 1
var coins := 0
var gems := 0
var owned: Dictionary = {}
var weapon_levels: Dictionary = {}
var loadout: Dictionary = {}
var stars: Dictionary = {}
var stats: Dictionary = {}

func _init() -> void:
    restore(default_state())

static func default_state() -> Dictionary:
    return {
        "xp": 0, "rank": 1, "coins": GameConfig.STARTING_COINS, "gems": 0,
        "owned": {"weapons": ["viper"], "styles": ["tiger"], "crush": ["quake"], "streaks": ["supply"], "outfits": ["alpha"]},
        "weapon_levels": {},
        "loadout": {"primary": "viper", "secondary": "", "style": "tiger", "crush": "quake", "streaks": ["supply", "airstrike", "drone"], "outfit": "alpha"},
        "stars": {},
        "stats": {"kills": 0, "matches": 0, "wins": 0, "headshots": 0, "crushes": 0, "melee_kills": 0, "perfect_dodges": 0, "best_combo": 0, "coins_earned": 0}
    }

# ------------------------------------------------------------------------------------------------ rank maths
## Total XP needed to REACH `target_rank` (rank 1 needs none).
static func xp_for_rank(target_rank: int) -> int:
    if target_rank <= 1:
        return 0
    return int(120.0 * pow(float(target_rank - 1), 1.55))

static func rank_for_xp(total_xp: int) -> int:
    var found := 1
    for candidate in range(2, MAX_RANK + 1):
        if total_xp >= xp_for_rank(candidate):
            found = candidate
        else:
            break
    return found

static func rank_title(for_rank: int) -> String:
    var tier := mini((maxi(for_rank, 1) - 1) >> 2, RANK_TITLES.size() - 1)
    return RANK_TITLES[tier]

## 0..1 progress through the current rank (drives the XP bar).
func rank_fraction() -> float:
    if rank >= MAX_RANK:
        return 1.0
    var floor_xp := xp_for_rank(rank)
    var ceil_xp := xp_for_rank(rank + 1)
    return clampf(float(xp - floor_xp) / maxf(float(ceil_xp - floor_xp), 1.0), 0.0, 1.0)

func add_xp(amount: int) -> void:
    if amount <= 0:
        return
    xp += amount
    var before := rank
    rank = rank_for_xp(xp)
    if rank > before:
        rank_up.emit(rank)
    changed.emit()

# ------------------------------------------------------------------------------------------------ money
func add_coins(amount: int) -> void:
    if amount <= 0:
        return
    coins += amount
    stats["coins_earned"] = int(stats.get("coins_earned", 0)) + amount
    changed.emit()

func spend_coins(amount: int) -> bool:
    if amount < 0 or coins < amount:
        return false
    coins -= amount
    changed.emit()
    return true

# ------------------------------------------------------------------------------------------------ ownership
func owns(category: String, id: String) -> bool:
    var list: Array = owned.get(category, [])
    return list.has(id)

func _grant(category: String, id: String) -> void:
    var list: Array = owned.get(category, [])
    if not list.has(id):
        list.append(id)
    owned[category] = list

func _catalog_for(category: String) -> Dictionary:
    if category == CATEGORY_STYLES:
        return LoadoutCatalog.STYLES
    if category == CATEGORY_CRUSH:
        return LoadoutCatalog.CRUSH_MOVES
    if category == CATEGORY_STREAKS:
        return LoadoutCatalog.STREAKS
    if category == CATEGORY_OUTFITS:
        return LoadoutCatalog.OUTFITS
    return WeaponCatalog.WEAPONS

func required_rank(category: String, id: String) -> int:
    return int(_catalog_for(category).get(id, {}).get("unlock_rank", 1))

func price_of(category: String, id: String) -> int:
    return int(_catalog_for(category).get(id, {}).get("price", 0))

## "owned", "buy" (affordable and unlocked), "poor" (unlocked, not enough coins) or "locked" (rank too low).
func offer_state(category: String, id: String) -> String:
    if owns(category, id):
        return "owned"
    if rank < required_rank(category, id):
        return "locked"
    if coins < price_of(category, id):
        return "poor"
    return "buy"

func buy(category: String, id: String) -> bool:
    if offer_state(category, id) != "buy":
        return false
    if not spend_coins(price_of(category, id)):
        return false
    _grant(category, id)
    changed.emit()
    return true

# ------------------------------------------------------------------------------------------------ weapons and loadout
func weapon_level(id: String) -> int:
    return clampi(int(weapon_levels.get(id, 0)), 0, WeaponCatalog.MAX_LEVEL)

func can_upgrade(id: String) -> bool:
    return owns(CATEGORY_WEAPONS, id) and weapon_level(id) < WeaponCatalog.MAX_LEVEL and coins >= WeaponCatalog.upgrade_cost(id, weapon_level(id))

func upgrade_weapon(id: String) -> bool:
    if not can_upgrade(id):
        return false
    var level := weapon_level(id)
    if not spend_coins(WeaponCatalog.upgrade_cost(id, level)):
        return false
    weapon_levels[id] = level + 1
    changed.emit()
    return true

## slot 0 = primary, 1 = secondary. Equipping a gun that is already in the other slot swaps the two.
func equip_weapon(slot: int, id: String) -> bool:
    if id != "" and not owns(CATEGORY_WEAPONS, id):
        return false
    var primary := str(loadout.get("primary", "viper"))
    var secondary := str(loadout.get("secondary", ""))
    if slot == 0:
        if id == "":
            return false
        if id == secondary:
            secondary = primary
        primary = id
    else:
        if id == primary:
            primary = secondary if secondary != "" else primary
        secondary = id
    loadout["primary"] = primary
    loadout["secondary"] = secondary
    changed.emit()
    return true

func equip(category: String, id: String) -> bool:
    if not owns(category, id):
        return false
    if category == CATEGORY_STYLES:
        loadout["style"] = id
    elif category == CATEGORY_CRUSH:
        loadout["crush"] = id
    elif category == CATEGORY_OUTFITS:
        loadout["outfit"] = id
    else:
        return false
    changed.emit()
    return true

## Streak slots (0..2): put an owned streak into a slot; the streak that was there swaps places if it moved.
func set_streak(slot: int, id: String) -> bool:
    if slot < 0 or slot > 2 or not owns(CATEGORY_STREAKS, id):
        return false
    var current: Array = loadout.get("streaks", ["supply", "airstrike", "drone"])
    while current.size() < 3:
        current.append("supply")
    var previous := str(current[slot])
    var other := current.find(id)
    current[slot] = id
    if other >= 0 and other != slot:
        current[other] = previous
    loadout["streaks"] = current
    changed.emit()
    return true

## The dictionary PlayerFighter.build() expects.
func loadout_for_match() -> Dictionary:
    var result := loadout.duplicate(true)
    result["levels"] = weapon_levels.duplicate()
    return result

# ------------------------------------------------------------------------------------------------ campaign and statistics
func best_stars(operation_index: int) -> int:
    return clampi(int(stars.get(str(operation_index), 0)), 0, 3)

func total_stars() -> int:
    var sum := 0
    for key in stars.keys():
        sum += clampi(int(stars[key]), 0, 3)
    return sum

## Operation 0 is always open; every other one opens when the previous operation has been completed at least once.
func is_operation_unlocked(operation_index: int) -> bool:
    return operation_index <= 0 or best_stars(operation_index - 1) >= 1

func next_operation() -> int:
    for i in OperationCatalog.count():
        if best_stars(i) < 1:
            return i
    return OperationCatalog.count() - 1

## Applies a finished match (the Dictionary produced by MatchDirector): XP, coins, stars and statistics.
func apply_result(result: Dictionary) -> void:
    var won := bool(result.get("won", false))
    stats["matches"] = int(stats.get("matches", 0)) + 1
    if won:
        stats["wins"] = int(stats.get("wins", 0)) + 1
    stats["kills"] = int(stats.get("kills", 0)) + int(result.get("kills", 0))
    stats["headshots"] = int(stats.get("headshots", 0)) + int(result.get("headshots", 0))
    stats["crushes"] = int(stats.get("crushes", 0)) + int(result.get("crushes", 0))
    stats["melee_kills"] = int(stats.get("melee_kills", 0)) + int(result.get("melee_kills", 0))
    stats["perfect_dodges"] = int(stats.get("perfect_dodges", 0)) + int(result.get("perfect_dodges", 0))
    stats["best_combo"] = maxi(int(stats.get("best_combo", 0)), int(result.get("best_combo", 0)))
    var index := int(result.get("operation", -1))
    if index >= 0 and won:
        stars[str(index)] = maxi(best_stars(index), int(result.get("stars", 1)))
    add_coins(int(result.get("coins", 0)))
    add_xp(int(result.get("xp", 0)))
    changed.emit()

func snapshot() -> Dictionary:
    return {
        "xp": xp, "rank": rank, "coins": coins, "gems": gems,
        "owned": owned.duplicate(true), "weapon_levels": weapon_levels.duplicate(true),
        "loadout": loadout.duplicate(true), "stars": stars.duplicate(true), "stats": stats.duplicate(true)
    }

## Safe against missing keys and the int-becomes-float quirk of JSON.
func restore(value: Dictionary) -> void:
    var defaults := default_state()
    xp = maxi(int(value.get("xp", 0)), 0)
    coins = maxi(int(value.get("coins", defaults["coins"])), 0)
    gems = maxi(int(value.get("gems", 0)), 0)
    rank = rank_for_xp(xp)
    owned = defaults["owned"].duplicate(true)
    var saved_owned: Variant = value.get("owned", {})
    if saved_owned is Dictionary:
        for category in owned.keys():
            var saved_list: Variant = saved_owned.get(category, [])
            if saved_list is Array:
                var merged: Array = owned[category]
                for entry in saved_list:
                    if not merged.has(str(entry)):
                        merged.append(str(entry))
                owned[category] = merged
    weapon_levels.clear()
    var saved_levels: Variant = value.get("weapon_levels", {})
    if saved_levels is Dictionary:
        for id in saved_levels.keys():
            weapon_levels[str(id)] = clampi(int(saved_levels[id]), 0, WeaponCatalog.MAX_LEVEL)
    loadout = defaults["loadout"].duplicate(true)
    var saved_loadout: Variant = value.get("loadout", {})
    if saved_loadout is Dictionary:
        for key in loadout.keys():
            if saved_loadout.has(key):
                loadout[key] = saved_loadout[key]
    _sanitize_loadout()
    stars.clear()
    var saved_stars: Variant = value.get("stars", {})
    if saved_stars is Dictionary:
        for key in saved_stars.keys():
            stars[str(key)] = clampi(int(saved_stars[key]), 0, 3)
    stats = defaults["stats"].duplicate(true)
    var saved_stats: Variant = value.get("stats", {})
    if saved_stats is Dictionary:
        for key in stats.keys():
            stats[key] = int(saved_stats.get(key, stats[key]))
    changed.emit()

## Never lets a corrupt or hand-edited save equip something the player does not own.
func _sanitize_loadout() -> void:
    if not owns(CATEGORY_WEAPONS, str(loadout.get("primary", ""))):
        loadout["primary"] = "viper"
    var secondary := str(loadout.get("secondary", ""))
    if secondary != "" and (not owns(CATEGORY_WEAPONS, secondary) or secondary == str(loadout["primary"])):
        loadout["secondary"] = ""
    if not owns(CATEGORY_STYLES, str(loadout.get("style", ""))):
        loadout["style"] = "tiger"
    if not owns(CATEGORY_CRUSH, str(loadout.get("crush", ""))):
        loadout["crush"] = "quake"
    if not owns(CATEGORY_OUTFITS, str(loadout.get("outfit", ""))):
        loadout["outfit"] = "alpha"
    var streaks: Variant = loadout.get("streaks", [])
    var clean: Array = []
    if streaks is Array:
        for entry in streaks:
            clean.append(str(entry) if owns(CATEGORY_STREAKS, str(entry)) else "supply")
    while clean.size() < 3:
        clean.append("supply")
    loadout["streaks"] = clean.slice(0, 3)
