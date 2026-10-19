extends RefCounted
class_name TestPlayerProgress

static func run() -> bool:
    var ok := true
    var progress := PlayerProgress.new()
    ok = TestSupport.expect(progress.rank == 1 and progress.coins == GameConfig.STARTING_COINS and progress.owns("weapons", "viper"), "a new career starts at rank 1 with a VIPER") and ok
    ok = TestSupport.expect(PlayerProgress.xp_for_rank(1) == 0, "rank 1 needs no XP") and ok
    var previous := 0
    for r in range(2, PlayerProgress.MAX_RANK + 1):
        var needed := PlayerProgress.xp_for_rank(r)
        ok = TestSupport.expect(needed > previous, "rank %d needs more XP than rank %d" % [r, r - 1]) and ok
        ok = TestSupport.expect(PlayerProgress.rank_for_xp(needed) == r and PlayerProgress.rank_for_xp(needed - 1) == r - 1, "rank_for_xp is the inverse of xp_for_rank at %d" % r) and ok
        previous = needed
    ok = TestSupport.expect(PlayerProgress.rank_title(1) == "RECRUIT" and PlayerProgress.rank_title(PlayerProgress.MAX_RANK) == "ALPHA LEGEND", "rank titles") and ok

    var ranks: Array[int] = []
    progress.rank_up.connect(func(value: int): ranks.append(value))
    progress.add_xp(PlayerProgress.xp_for_rank(3))
    ok = TestSupport.expect(progress.rank == 3 and ranks == [3], "gaining XP raises the rank and announces it") and ok
    ok = TestSupport.expect(progress.rank_fraction() >= 0.0 and progress.rank_fraction() < 1.0, "rank progress is a fraction") and ok

    ok = TestSupport.expect(progress.offer_state("weapons", "comet") == "locked", "rank gates the launcher") and ok
    ok = TestSupport.expect(progress.offer_state("weapons", "hornet") == "poor" and not progress.buy("weapons", "hornet"), "cannot buy without coins") and ok
    progress.add_coins(300)
    ok = TestSupport.expect(progress.offer_state("weapons", "hornet") == "buy", "hornet is affordable") and ok
    var before := progress.coins
    ok = TestSupport.expect(progress.buy("weapons", "hornet") and progress.coins == before - 400 and progress.owns("weapons", "hornet"), "buying spends coins and grants the gun") and ok
    ok = TestSupport.expect(not progress.buy("weapons", "hornet") and progress.offer_state("weapons", "hornet") == "owned", "cannot buy twice") and ok
    ok = TestSupport.expect(not progress.spend_coins(10 ** 9), "cannot overspend") and ok

    ok = TestSupport.expect(progress.equip_weapon(1, "hornet") and str(progress.loadout["secondary"]) == "hornet", "equip as secondary") and ok
    ok = TestSupport.expect(progress.equip_weapon(0, "hornet") and str(progress.loadout["primary"]) == "hornet" and str(progress.loadout["secondary"]) == "viper", "equipping the other slot's gun swaps them") and ok
    ok = TestSupport.expect(not progress.equip_weapon(0, "comet"), "cannot equip a gun you do not own") and ok

    progress.add_coins(5000)
    var coins_before := progress.coins
    ok = TestSupport.expect(progress.upgrade_weapon("viper") and progress.weapon_level("viper") == 1 and progress.coins == coins_before - WeaponCatalog.upgrade_cost("viper", 0), "upgrade costs coins and adds a level") and ok
    for i in 10:
        progress.upgrade_weapon("viper")
    ok = TestSupport.expect(progress.weapon_level("viper") == WeaponCatalog.MAX_LEVEL and not progress.can_upgrade("viper"), "upgrades stop at the maximum level") and ok

    progress._grant("streaks", "airstrike")
    ok = TestSupport.expect(progress.set_streak(1, "airstrike") and progress.loadout["streaks"][1] == "airstrike", "streak slot assignment") and ok
    ok = TestSupport.expect(progress.set_streak(0, "airstrike") and progress.loadout["streaks"][0] == "airstrike" and progress.loadout["streaks"][1] == "supply", "moving a streak swaps slots") and ok
    ok = TestSupport.expect(not progress.set_streak(2, "drone"), "cannot slot a streak you do not own") and ok

    ok = TestSupport.expect(progress.is_operation_unlocked(0) and not progress.is_operation_unlocked(1) and progress.next_operation() == 0, "only operation ALPHA is open at first") and ok
    var coins_now := progress.coins
    progress.apply_result({"won": false, "operation": 0, "stars": 0, "xp": 10, "coins": 5, "kills": 3})
    ok = TestSupport.expect(progress.best_stars(0) == 0 and not progress.is_operation_unlocked(1) and progress.coins == coins_now + 5, "a loss pays a little but unlocks nothing") and ok
    progress.apply_result({"won": true, "operation": 0, "stars": 2, "xp": 100, "coins": 50, "kills": 20, "headshots": 4, "best_combo": 12})
    ok = TestSupport.expect(progress.best_stars(0) == 2 and progress.is_operation_unlocked(1) and progress.next_operation() == 1, "a win records stars and opens the next operation") and ok
    progress.apply_result({"won": true, "operation": 0, "stars": 1, "xp": 0, "coins": 0})
    ok = TestSupport.expect(progress.best_stars(0) == 2 and int(progress.stats["matches"]) == 3 and int(progress.stats["wins"]) == 2 and int(progress.stats["best_combo"]) == 12, "stars never go down and stats accumulate") and ok

    var text := JSON.stringify(progress.snapshot())
    var parsed: Variant = JSON.parse_string(text)
    var restored := PlayerProgress.new()
    restored.restore(parsed)
    ok = TestSupport.expect(restored.xp == progress.xp and restored.coins == progress.coins and restored.rank == progress.rank and restored.owns("weapons", "hornet") and restored.weapon_level("viper") == WeaponCatalog.MAX_LEVEL and restored.best_stars(0) == 2, "a JSON round-trip keeps the whole career") and ok
    ok = TestSupport.expect(str(restored.loadout["primary"]) == str(progress.loadout["primary"]) and restored.loadout["streaks"] == progress.loadout["streaks"], "the loadout survives a round-trip") and ok

    var tampered := PlayerProgress.new()
    tampered.restore({"xp": 5, "loadout": {"primary": "comet", "secondary": "comet", "style": "turtle", "crush": "storm", "outfit": "gold", "streaks": ["drone", "x", "airstrike"]}, "owned": {}})
    ok = TestSupport.expect(str(tampered.loadout["primary"]) == "viper" and str(tampered.loadout["secondary"]) == "" and str(tampered.loadout["style"]) == "tiger" and str(tampered.loadout["crush"]) == "quake" and str(tampered.loadout["outfit"]) == "alpha", "a tampered save cannot equip what is not owned") and ok
    ok = TestSupport.expect(tampered.loadout["streaks"] == ["supply", "supply", "supply"], "unowned streaks fall back to the supply drop") and ok
    for node in [progress, restored, tampered]:
        node.free()
    return ok
