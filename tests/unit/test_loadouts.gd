extends RefCounted
class_name TestLoadouts

static func _icon_ok(icon_name: String) -> bool:
    return FileAccess.file_exists("%s%s.png" % [KidUI.ICON_DIR, icon_name])

static func run() -> bool:
    var ok := true
    var groups: Array[Dictionary] = [
        {"order": LoadoutCatalog.STYLE_ORDER, "data": LoadoutCatalog.STYLES},
        {"order": LoadoutCatalog.CRUSH_ORDER, "data": LoadoutCatalog.CRUSH_MOVES},
        {"order": LoadoutCatalog.STREAK_ORDER, "data": LoadoutCatalog.STREAKS},
        {"order": LoadoutCatalog.OUTFIT_ORDER, "data": LoadoutCatalog.OUTFITS}
    ]
    for group in groups:
        var order: Array = group["order"]
        var data: Dictionary = group["data"]
        ok = TestSupport.expect(order.size() == data.size(), "order and data agree") and ok
        ok = TestSupport.expect(int(data[order[0]].get("price", 1)) == 0 and int(data[order[0]].get("unlock_rank", 9)) == 1, "the first entry is free at rank 1") and ok
        for id in order:
            var entry: Dictionary = data[id]
            ok = TestSupport.expect(int(entry.get("price", -1)) >= 0 and int(entry.get("unlock_rank", 0)) >= 1, "%s has a price and rank" % id) and ok
            if entry.has("icon"):
                ok = TestSupport.expect(_icon_ok(str(entry["icon"])), "%s icon exists" % id) and ok
    for id in LoadoutCatalog.STREAK_ORDER:
        ok = TestSupport.expect(LoadoutCatalog.streak_kills(id) >= 1, "%s needs kills" % id) and ok
    ok = TestSupport.expect(LoadoutCatalog.style_data("missing").get("name", "") == "TIGER", "unknown styles fall back to TIGER") and ok

    var outfit := LoadoutCatalog.rig_outfit("ember", "male", 3)
    ok = TestSupport.expect(outfit["shirt"] == LoadoutCatalog.OUTFITS["ember"]["shirt"] and outfit["pack"] == false and str(outfit["hat"]) == "", "rig outfits use the chosen colours without a backpack") and ok

    for id in EnemyCatalog.TYPES.keys():
        var data: Dictionary = EnemyCatalog.TYPES[id]
        var role := str(data.get("role", ""))
        ok = TestSupport.expect(role == "gunner" or role == "melee", "%s has a role" % id) and ok
        ok = TestSupport.expect(float(data.get("hp", 0.0)) > 0.0 and float(data.get("speed", 0.0)) > 0.0, "%s has health and speed" % id) and ok
        if role == "gunner":
            ok = TestSupport.expect(WeaponCatalog.is_valid(str(data.get("weapon", ""))), "%s carries a real gun" % id) and ok
            ok = TestSupport.expect(float(data.get("band_min", 0.0)) < float(data.get("band_max", 0.0)), "%s has a distance band" % id) and ok
        else:
            ok = TestSupport.expect(float(data.get("reach", 0.0)) > 0.0 and float(data.get("windup", 0.0)) > 0.0, "%s has reach and a telegraph" % id) and ok
    ok = TestSupport.expect(EnemyCatalog.is_boss("commander") and not EnemyCatalog.is_boss("grunt"), "only the commander is a boss") and ok
    for faction in EnemyCatalog.FACTION_ORDER:
        var mix: Dictionary = EnemyCatalog.faction_data(faction)["mix"]
        for type_id in mix.keys():
            ok = TestSupport.expect(EnemyCatalog.TYPES.has(type_id), "%s mix lists a real type" % faction) and ok
    ok = TestSupport.expect(EnemyCatalog.pick_type("jackals", 0.0) == "grunt", "roll 0 picks the first type") and ok
    var heavy_free := true
    var saw_heavy := false
    for i in 100:
        var roll := float(i) / 100.0
        if EnemyCatalog.pick_type("bulls", roll, false) == "heavy":
            heavy_free = false
        if EnemyCatalog.pick_type("bulls", roll, true) == "heavy":
            saw_heavy = true
    ok = TestSupport.expect(heavy_free and saw_heavy, "heavies appear only when allowed") and ok
    var enemy_outfit := EnemyCatalog.outfit_for("fists", "ninja", 5, "male", false)
    ok = TestSupport.expect(enemy_outfit["shirt"] == EnemyCatalog.FACTIONS["fists"]["shirt"], "factions tint their clothes") and ok
    return ok
