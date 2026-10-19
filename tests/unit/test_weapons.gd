extends RefCounted
class_name TestWeapons

const REQUIRED := ["name", "kind", "icon", "damage", "rate", "mag", "reserve", "reload", "spread", "range", "pellets", "sfx", "unlock_rank", "price", "model", "tracer"]

static func run() -> bool:
    var ok := true
    ok = TestSupport.expect(WeaponCatalog.ORDER.size() == WeaponCatalog.WEAPONS.size(), "ORDER lists every weapon") and ok
    var last_rank := 0
    for id in WeaponCatalog.ORDER:
        var data := WeaponCatalog.get_weapon(id)
        for key in REQUIRED:
            ok = TestSupport.expect(data.has(key), "%s has %s" % [id, key]) and ok
        ok = TestSupport.expect(float(data.get("damage", 0.0)) > 0.0 and float(data.get("rate", 0.0)) > 0.0 and int(data.get("mag", 0)) > 0, "%s has positive stats" % id) and ok
        ok = TestSupport.expect(FileAccess.file_exists("%s%s.png" % [KidUI.ICON_DIR, WeaponCatalog.icon_name(id)]), "%s icon exists" % id) and ok
        ok = TestSupport.expect(FileAccess.file_exists("res://audio/sfx/%s.wav" % str(data.get("sfx", ""))), "%s sound exists" % id) and ok
        ok = TestSupport.expect(AudioManager.SFX_IDS.has(str(data.get("sfx", ""))), "%s sound is registered" % id) and ok
        ok = TestSupport.expect(WeaponCatalog.unlock_rank(id) >= last_rank, "%s unlocks no earlier than the previous gun" % id) and ok
        last_rank = WeaponCatalog.unlock_rank(id)
        ok = TestSupport.expect(WeaponCatalog.dps(id, WeaponCatalog.MAX_LEVEL) > WeaponCatalog.dps(id, 0), "%s upgrades add power" % id) and ok
        ok = TestSupport.expect(WeaponCatalog.upgrade_cost(id, 0) == WeaponCatalog.UPGRADE_BASE_COST * WeaponCatalog.tier(id) and WeaponCatalog.upgrade_cost(id, WeaponCatalog.MAX_LEVEL) == 0, "%s upgrade costs" % id) and ok
        var model := WeaponModel.build(id)
        var parts := 0
        for child in model.get_children():
            if child is MeshInstance3D:
                parts += 1
        ok = TestSupport.expect(model.get_node_or_null("Muzzle") != null and parts >= 2, "%s model has a muzzle and parts" % id) and ok
        model.free()
    ok = TestSupport.expect(WeaponCatalog.price("viper") == 0 and WeaponCatalog.unlock_rank("viper") == 1, "the VIPER is free at rank 1") and ok
    ok = TestSupport.expect(TestSupport.approx(WeaponCatalog.range_multiplier("viper", 0.0), 1.0) and TestSupport.approx(WeaponCatalog.range_multiplier("viper", 500.0), WeaponCatalog.FALLOFF_FLOOR), "damage falls off with distance") and ok
    ok = TestSupport.expect(WeaponCatalog.range_multiplier("boomer", 10.0) < 1.0 and WeaponCatalog.range_multiplier("boomer", 4.0) == 1.0, "the shotgun fades fast") and ok
    ok = TestSupport.expect(WeaponCatalog.ids_for_rank(1) == ["viper"] and WeaponCatalog.ids_for_rank(40).size() == WeaponCatalog.ORDER.size(), "guns open up with rank") and ok
    ok = TestSupport.expect(not WeaponCatalog.is_valid("nope") and WeaponCatalog.get_weapon("nope").is_empty(), "unknown guns are rejected") and ok

    var controller := WeaponController.new()
    controller.setup("viper", "hornet", {})
    ok = TestSupport.expect(controller.current_id() == "viper" and controller.mag_ammo() == 12 and controller.reserve_ammo() == 96 and controller.has_secondary(), "controller starts loaded") and ok
    var shot := controller.try_fire()
    ok = TestSupport.expect(not shot.is_empty() and controller.mag_ammo() == 11 and int(shot["pellets"]) == 1 and TestSupport.approx(float(shot["damage"]), 24.0), "a shot uses a round and reports its damage") and ok
    ok = TestSupport.expect(controller.try_fire().is_empty(), "fire rate limits the next shot") and ok
    controller.tick(1.0)
    ok = TestSupport.expect(controller.can_fire(), "the weapon is ready again after the cooldown") and ok
    controller.start_reload()
    ok = TestSupport.expect(controller.is_reloading() and controller.try_fire().is_empty(), "no firing while reloading") and ok
    controller.tick(5.0)
    ok = TestSupport.expect(not controller.is_reloading() and controller.mag_ammo() == 12 and controller.reserve_ammo() == 95, "a reload tops up the magazine from the reserve") and ok
    controller.swap()
    ok = TestSupport.expect(controller.current_id() == "hornet" and controller.mag_ammo() == 32, "swap switches to the secondary") and ok
    controller.refill(1.0)
    ok = TestSupport.expect(controller.reserve_ammo() == int(WeaponCatalog.get_weapon("hornet")["reserve"]), "ammo crates refill the reserve") and ok
    controller.infinite_ammo = true
    controller.tick(1.0)
    var before := controller.mag_ammo()
    controller.try_fire()
    ok = TestSupport.expect(controller.mag_ammo() == before, "infinite ammo consumes nothing") and ok
    controller.free()

    var upgraded := WeaponController.new()
    upgraded.setup("viper", "", {"viper": 5})
    ok = TestSupport.expect(upgraded.mag_size("viper") == 18 and TestSupport.approx(float(upgraded.try_fire()["damage"]), 24.0 * 1.4), "level 5 adds 40% damage and 50% magazine") and ok
    upgraded.free()

    var enemy := WeaponController.new()
    enemy.infinite_reserve = true
    enemy.damage_scale = 0.25
    enemy.setup("falcon", "", {})
    for i in 30:
        enemy.tick(1.0)
        enemy.try_fire()
    enemy.tick(10.0)
    ok = TestSupport.expect(enemy.mag_ammo() == 30, "enemies reload without ever running out of spare rounds") and ok
    enemy.free()
    return ok
