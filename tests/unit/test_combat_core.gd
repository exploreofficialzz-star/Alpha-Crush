extends RefCounted
class_name TestCombatCore

static func run() -> bool:
    var ok := true
    ok = TestSupport.expect(Teams.hostile_of(Teams.ALPHA) == Teams.OPPOSITION and Teams.hostile_of(Teams.OPPOSITION) == Teams.ALPHA, "hostile_of swaps sides") and ok
    var alpha_bullets := Teams.bullet_mask_for(Teams.ALPHA)
    ok = TestSupport.expect((alpha_bullets & Teams.LAYER_OPPOSITION) != 0 and (alpha_bullets & Teams.LAYER_ALPHA) == 0 and (alpha_bullets & Teams.LAYER_WORLD) != 0, "ALPHA bullets hit the opposition and the world, not allies") and ok
    var enemy_bullets := Teams.bullet_mask_for(Teams.OPPOSITION)
    ok = TestSupport.expect((enemy_bullets & Teams.LAYER_ALPHA) != 0 and (enemy_bullets & Teams.LAYER_OPPOSITION) == 0, "enemy bullets hit ALPHA only") and ok
    ok = TestSupport.expect(Teams.layer_for(Teams.ALPHA) != Teams.layer_for(Teams.OPPOSITION), "teams use different physics layers") and ok

    var info := DamageInfo.make(12.0, DamageInfo.KIND_MELEE, null, Teams.ALPHA, Vector3.ONE, Vector3.FORWARD)
    ok = TestSupport.expect(TestSupport.approx(info.amount, 12.0) and info.kind == DamageInfo.KIND_MELEE and info.source_team == Teams.ALPHA and not info.is_ranged(), "DamageInfo.make copies its arguments") and ok
    ok = TestSupport.expect(DamageInfo.make(1.0, DamageInfo.KIND_EXPLOSION, null, 0, Vector3.ZERO, Vector3.ZERO).is_ranged(), "explosions count as ranged") and ok

    var combo := ComboTracker.new()
    ok = TestSupport.expect(combo.rank() == "D" and combo.count == 0, "combo starts at rank D") and ok
    var first := combo.hit(10)
    ok = TestSupport.expect(first == 10 and combo.count == 1, "first hit scores base points") and ok
    for i in 3:
        combo.hit()
    ok = TestSupport.expect(combo.rank() == "C" and TestSupport.approx(combo.multiplier(), 1.15), "4 hits reach rank C") and ok
    for i in 5:
        combo.hit()
    ok = TestSupport.expect(combo.rank() == "B" and combo.best == 9, "9 hits reach rank B") and ok
    ok = TestSupport.expect(combo.time_fraction() > 0.9, "a fresh hit refills the combo timer") and ok
    combo.tick(ComboTracker.TIMEOUT + 0.1)
    ok = TestSupport.expect(combo.count == 0 and combo.rank() == "D" and combo.best == 9, "the chain breaks after the timeout but the best is kept") and ok

    var meter := CrushMeter.new()
    meter.add(60.0)
    ok = TestSupport.expect(not meter.is_ready() and not meter.spend(), "a part-full crush meter cannot be spent") and ok
    meter.add(60.0)
    ok = TestSupport.expect(meter.is_ready() and TestSupport.approx(meter.value, 100.0), "the meter caps at 100") and ok
    ok = TestSupport.expect(meter.spend() and TestSupport.approx(meter.value, 0.0), "spending empties the meter") and ok
    meter.locked = true
    meter.add(50.0)
    ok = TestSupport.expect(TestSupport.approx(meter.value, 0.0), "a locked meter does not fill") and ok

    var forward := Vector3(0.0, 0.0, -1.0)
    var straight := AimAssist.score(Vector3.ZERO, forward, Vector3(0.0, 0.0, -10.0), 50.0, 60.0)
    var side := AimAssist.score(Vector3.ZERO, forward, Vector3(5.0, 0.0, -10.0), 50.0, 60.0)
    var behind := AimAssist.score(Vector3.ZERO, forward, Vector3(0.0, 0.0, 10.0), 50.0, 60.0)
    var far := AimAssist.score(Vector3.ZERO, forward, Vector3(0.0, 0.0, -80.0), 50.0, 60.0)
    ok = TestSupport.expect(straight > side and side > 0.0 and behind < 0.0 and far < 0.0, "aim assist prefers what is ahead and ignores what is behind or too far") and ok
    var edge := Vector3(sin(deg_to_rad(36.0)) * 10.0, 0.0, -cos(deg_to_rad(36.0)) * 10.0)
    ok = TestSupport.expect(AimAssist.score(Vector3.ZERO, forward, edge, 50.0, 60.0, false) < 0.0 and AimAssist.score(Vector3.ZERO, forward, edge, 50.0, 60.0, true) > 0.0, "a locked target survives slightly outside the cone") and ok

    var root := TestSupport.tree_root()
    var near_enemy := Node3D.new()
    near_enemy.position = Vector3(0.0, 0.0, -10.0)
    var side_enemy := Node3D.new()
    side_enemy.position = Vector3(6.0, 0.0, -10.0)
    root.add_child(near_enemy)
    root.add_child(side_enemy)
    var picked := AimAssist.pick(Vector3.ZERO, forward, [side_enemy, near_enemy], 50.0, 60.0, null)
    ok = TestSupport.expect(picked == near_enemy, "pick chooses the enemy closest to the crosshair") and ok
    var held := AimAssist.pick(Vector3.ZERO, forward, [side_enemy, near_enemy], 50.0, 60.0, side_enemy)
    ok = TestSupport.expect(held != null, "pick returns a target when one is locked") and ok
    root.remove_child(near_enemy)
    root.remove_child(side_enemy)
    near_enemy.free()
    side_enemy.free()
    return ok
