extends RefCounted
class_name TestOperations

static func run() -> bool:
    var ok := true
    ok = TestSupport.expect(OperationCatalog.count() == 26, "26 operations, ALPHA to ZULU") and ok
    var last_difficulty := 0.0
    for i in OperationCatalog.count():
        var op := OperationCatalog.operation(i)
        ok = TestSupport.expect(str(op["letter"]) == char(65 + i) and str(op["callsign"]) == OperationCatalog.CALLSIGNS[i], "operation %d letter and callsign" % i) and ok
        ok = TestSupport.expect(float(op["difficulty"]) > last_difficulty, "difficulty rises with every operation") and ok
        last_difficulty = float(op["difficulty"])
        ok = TestSupport.expect(ArenaCatalog.is_valid(str(op["arena"])), "operation %d has a real arena" % i) and ok
        var factions: Array = op["factions"]
        ok = TestSupport.expect(not factions.is_empty(), "operation %d has an enemy side" % i) and ok
        for faction in factions:
            ok = TestSupport.expect(EnemyCatalog.FACTIONS.has(str(faction)), "operation %d faction exists" % i) and ok
        ok = TestSupport.expect(OperationCatalog.MODE_ORDER.has(str(op["mode"])), "operation %d mode" % i) and ok
        ok = TestSupport.expect(bool(op["boss"]) == (str(op["mode"]) == "commander"), "boss flag matches the mode") and ok
        ok = TestSupport.expect(int(op["target"]) >= 1 and int(op["max_active"]) >= 4 and int(op["max_active"]) <= 10, "operation %d targets" % i) and ok
        ok = TestSupport.expect(str(OperationCatalog.operation(i)) == str(op), "operation %d is deterministic" % i) and ok
    ok = TestSupport.expect(TestSupport.approx(OperationCatalog.difficulty_for(0), 1.0) and TestSupport.approx(OperationCatalog.difficulty_for(25), 3.25), "difficulty runs 1.00 to 3.25") and ok
    for boss_index in [4, 9, 14, 19, 24, 25]:
        ok = TestSupport.expect(OperationCatalog.mode_for(boss_index) == "commander", "operation %d is a commander hunt" % boss_index) and ok
    ok = TestSupport.expect(OperationCatalog.mode_for(0) == "crush" and OperationCatalog.mode_for(1) == "siege" and OperationCatalog.mode_for(2) == "domination", "the first three modes rotate") and ok
    ok = TestSupport.expect(OperationCatalog.target_for("domination", 3) == OperationCatalog.DOMINATION_TARGET and OperationCatalog.target_for("crush", 40) == 60, "targets are capped") and ok

    var quick := OperationCatalog.quick_battle("siege", "dustline", 2, "bulls")
    ok = TestSupport.expect(int(quick["index"]) == -1 and str(quick["arena"]) == "dustline" and str(quick["mode"]) == "siege" and quick["factions"] == ["bulls"], "quick battle carries the chosen options") and ok
    var bad_quick := OperationCatalog.quick_battle("crush", "nowhere", 99, "nobody")
    ok = TestSupport.expect(ArenaCatalog.is_valid(str(bad_quick["arena"])) and EnemyCatalog.FACTIONS.has(str(bad_quick["factions"][0])) and TestSupport.approx(float(bad_quick["difficulty"]), 3.4), "quick battle sanitises bad input") and ok

    ok = TestSupport.expect(MatchDirector.compute_stars(false, 0, 99) == 0, "no stars for a loss") and ok
    ok = TestSupport.expect(MatchDirector.compute_stars(true, 0, 12) == 3 and MatchDirector.compute_stars(true, 0, 5) == 2 and MatchDirector.compute_stars(true, 1, 50) == 2 and MatchDirector.compute_stars(true, 2, 50) == 1, "star rules") and ok
    ok = TestSupport.expect(MatchDirector.wave_size(1, 1.0) == 9 and MatchDirector.wave_size(5, 2.0) == 19, "wave sizes grow") and ok
    ok = TestSupport.expect(MatchDirector.kill_xp(100) == 35, "kill XP") and ok

    ok = TestSupport.expect(ArenaCatalog.ORDER.size() == ArenaCatalog.ARENAS.size(), "every arena is in the rotation") and ok
    for arena_id in ArenaCatalog.ORDER:
        var arena := ArenaCatalog.arena(arena_id)
        ok = TestSupport.expect(str(arena["region"]) != "" and float(arena["time"]) > 0.0 and float(arena["time"]) < 1.0, "%s region and time" % arena_id) and ok
        ok = TestSupport.expect(["clear", "cloudy", "rain"].has(str(arena["weather"])), "%s weather is one the sky supports" % arena_id) and ok
        ok = TestSupport.expect(Vegetation.region_material(str(arena["region"])) != null, "%s ground material builds" % arena_id) and ok
        for i in 100:
            var kind := ArenaCatalog.pick_cluster(arena_id, float(i) / 100.0)
            ok = TestSupport.expect(float(arena["cluster_mix"].get(kind, 0)) > 0.0, "%s never picks a cover kind with zero weight" % arena_id) and ok
    return ok
