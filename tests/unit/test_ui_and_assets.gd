extends RefCounted
class_name TestUiAndAssets

static func _icon_ok(icon_name: String) -> bool:
    return FileAccess.file_exists("%s%s.png" % [KidUI.ICON_DIR, icon_name])

static func run() -> bool:
    var ok := true
    # Every icon the battle HUD and menus ask for must be a real picture.
    var needed: Array[String] = [
        "attack", "dodge", "jump", "crush", "grenade", "reload", "swap", "pause", "heart", "shield", "flag", "crown", "supply", "rocket",
        "drone", "ammo", "trophy", "bolt", "target", "hand", "gear", "home", "coin", "star", "star_gold", "boy", "girl", "play", "lock", "check", "close"
    ]
    for id in OperationCatalog.MODE_ICONS.values():
        needed.append(str(id))
    for id in WeaponCatalog.ORDER:
        needed.append(WeaponCatalog.icon_name(id))
    for icon_name in needed:
        ok = TestSupport.expect(_icon_ok(icon_name), "icon %s exists" % icon_name) and ok
    # Every sound the game plays must exist on disk.
    for id in AudioManager.SFX_IDS:
        ok = TestSupport.expect(FileAccess.file_exists("res://audio/sfx/%s.wav" % id), "sound %s exists" % id) and ok
    for path in AudioManager.MUSIC.values():
        ok = TestSupport.expect(FileAccess.file_exists(str(path)), "music %s exists" % str(path)) and ok
    for path in AudioManager.AMBIENCE.values():
        ok = TestSupport.expect(FileAccess.file_exists(str(path)), "ambience %s exists" % str(path)) and ok

    ok = TestSupport.expect(ResultScreen.format_time(75.0) == "1:15" and ResultScreen.format_time(5.0) == "0:05" and ResultScreen.format_time(-3.0) == "0:00", "result screen formats time") and ok
    ok = TestSupport.expect(ResultScreen.unlocks_at_rank(2).has("HORNET") and ResultScreen.unlocks_at_rank(15).has("COMET"), "rank-ups announce new guns") and ok
    ok = TestSupport.expect(ResultScreen.unlocks_at_rank(3).has("CRANE") and ResultScreen.unlocks_at_rank(3).has("AIR STRIKE"), "rank-ups announce styles and streaks") and ok

    InputActions.ensure()
    InputActions.ensure()
    for action in InputActions.ACTIONS.keys():
        ok = TestSupport.expect(InputMap.has_action(str(action)), "input action %s is registered" % str(action)) and ok
    return ok
