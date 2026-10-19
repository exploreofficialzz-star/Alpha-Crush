extends SceneTree

const SUITE_AD_SERVICE = preload("res://tests/unit/test_ad_service.gd")
const SUITE_OBJECT_POOL = preload("res://tests/unit/test_object_pool.gd")
const SUITE_WEATHER_MANAGER = preload("res://tests/unit/test_weather_manager.gd")
const SUITE_VISUALS = preload("res://tests/unit/test_visuals.gd")
const SUITE_CONSENT_MANAGER = preload("res://tests/unit/test_consent_manager.gd")
const SUITE_SAVE_MIGRATION = preload("res://tests/unit/test_save_migration.gd")
const SUITE_SAVE_SYSTEM = preload("res://tests/unit/test_save_system.gd")
const SUITE_SETTINGS_MANAGER = preload("res://tests/unit/test_settings_manager.gd")
const SUITE_PURCHASE_SERVICE = preload("res://tests/unit/test_purchase_service.gd")
const SUITE_WORLD_CLOCK = preload("res://tests/unit/test_world_clock.gd")
const SUITE_DEVICE_PROFILE = preload("res://tests/unit/test_device_profile.gd")
const SUITE_QUALITY_MANAGER = preload("res://tests/unit/test_quality_manager.gd")
const SUITE_KID_UI = preload("res://tests/unit/test_kid_ui.gd")
const SUITE_TOUCH_CONTROLS = preload("res://tests/unit/test_touch_controls.gd")
const SUITE_AVATAR_RIG = preload("res://tests/unit/test_avatar_rig.gd")
const SUITE_BOOT_GUARD = preload("res://tests/unit/test_boot_guard.gd")
const SUITE_COMBAT_CORE = preload("res://tests/unit/test_combat_core.gd")
const SUITE_WEAPONS = preload("res://tests/unit/test_weapons.gd")
const SUITE_LOADOUTS = preload("res://tests/unit/test_loadouts.gd")
const SUITE_OPERATIONS = preload("res://tests/unit/test_operations.gd")
const SUITE_PLAYER_PROGRESS = preload("res://tests/unit/test_player_progress.gd")
const SUITE_HUD_LAYOUT = preload("res://tests/unit/test_hud_layout.gd")
const SUITE_ARENA = preload("res://tests/unit/test_arena.gd")
const SUITE_BATTLE_NODES = preload("res://tests/unit/test_battle_nodes.gd")
const SUITE_UI_AND_ASSETS = preload("res://tests/unit/test_ui_and_assets.gd")
const SUITE_SEED_DETERMINISM = preload("res://tests/integration/test_seed_determinism.gd")

func _initialize() -> void:
    call_deferred("_run_suites")

func _run_suites() -> void:
    var suites := [
        ["ad_service", SUITE_AD_SERVICE.run()],
        ["object_pool", SUITE_OBJECT_POOL.run()],
        ["weather_manager", SUITE_WEATHER_MANAGER.run()],
        ["visuals", SUITE_VISUALS.run()],
        ["consent_manager", SUITE_CONSENT_MANAGER.run()],
        ["save_migration", SUITE_SAVE_MIGRATION.run()],
        ["save_system", SUITE_SAVE_SYSTEM.run()],
        ["settings_manager", SUITE_SETTINGS_MANAGER.run()],
        ["purchase_service", SUITE_PURCHASE_SERVICE.run()],
        ["world_clock", SUITE_WORLD_CLOCK.run()],
        ["device_profile", SUITE_DEVICE_PROFILE.run()],
        ["quality_manager", SUITE_QUALITY_MANAGER.run()],
        ["kid_ui", SUITE_KID_UI.run()],
        ["touch_controls", SUITE_TOUCH_CONTROLS.run()],
        ["avatar_rig", SUITE_AVATAR_RIG.run()],
        ["boot_guard", SUITE_BOOT_GUARD.run()],
        ["combat_core", SUITE_COMBAT_CORE.run()],
        ["weapons", SUITE_WEAPONS.run()],
        ["loadouts", SUITE_LOADOUTS.run()],
        ["operations", SUITE_OPERATIONS.run()],
        ["player_progress", SUITE_PLAYER_PROGRESS.run()],
        ["hud_layout", SUITE_HUD_LAYOUT.run()],
        ["arena", SUITE_ARENA.run()],
        ["battle_nodes", SUITE_BATTLE_NODES.run()],
        ["ui_and_assets", SUITE_UI_AND_ASSETS.run()],
        ["seed_determinism", SUITE_SEED_DETERMINISM.run()]
    ]
    var failed := 0
    for result in suites:
        var passed := bool(result[1])
        print("%s %s" % ["PASS" if passed else "FAIL", str(result[0])])
        if not passed:
            failed += 1
    print("TESTS: %d total, %d passed, %d failed" % [suites.size(), suites.size() - failed, failed])
    quit(1 if failed > 0 else 0)
