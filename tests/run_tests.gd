extends SceneTree

const SUITE_ACHIEVEMENT_MANAGER = preload("res://tests/unit/test_achievement_manager.gd")
const SUITE_AD_SERVICE = preload("res://tests/unit/test_ad_service.gd")
const SUITE_OBJECT_POOL = preload("res://tests/unit/test_object_pool.gd")
const SUITE_WEATHER_MANAGER = preload("res://tests/unit/test_weather_manager.gd")
const SUITE_VISUALS = preload("res://tests/unit/test_visuals.gd")
const SUITE_CAMPAIGN_MANAGER = preload("res://tests/unit/test_campaign_manager.gd")
const SUITE_CRAFTING_MANAGER = preload("res://tests/unit/test_crafting_manager.gd")
const SUITE_CONSENT_MANAGER = preload("res://tests/unit/test_consent_manager.gd")
const SUITE_DAILY_MANAGER = preload("res://tests/unit/test_daily_manager.gd")
const SUITE_ECONOMY = preload("res://tests/unit/test_economy.gd")
const SUITE_HARVEST_NODE = preload("res://tests/unit/test_harvest_node.gd")
const SUITE_INVENTORY = preload("res://tests/unit/test_inventory.gd")
const SUITE_INVENTORY_CAPACITY = preload("res://tests/unit/test_inventory_capacity.gd")
const SUITE_MARKET_ORDER_BOARD = preload("res://tests/unit/test_market_order_board.gd")
const SUITE_POSTGAME_MANAGER = preload("res://tests/unit/test_postgame_manager.gd")
const SUITE_SAVE_MIGRATION = preload("res://tests/unit/test_save_migration.gd")
const SUITE_SAVE_SYSTEM = preload("res://tests/unit/test_save_system.gd")
const SUITE_SETTINGS_MANAGER = preload("res://tests/unit/test_settings_manager.gd")
const SUITE_PURCHASE_SERVICE = preload("res://tests/unit/test_purchase_service.gd")
const SUITE_WORD_SYSTEM = preload("res://tests/unit/test_word_system.gd")
const SUITE_WORLD_AUTHORITY = preload("res://tests/unit/test_world_authority.gd")
const SUITE_WORLD_CLOCK = preload("res://tests/unit/test_world_clock.gd")
const SUITE_WORLD_STATE = preload("res://tests/unit/test_world_state.gd")
const SUITE_DEVICE_PROFILE = preload("res://tests/unit/test_device_profile.gd")
const SUITE_QUALITY_MANAGER = preload("res://tests/unit/test_quality_manager.gd")
const SUITE_KID_UI = preload("res://tests/unit/test_kid_ui.gd")
const SUITE_TOUCH_CONTROLS = preload("res://tests/unit/test_touch_controls.gd")
const SUITE_SEED_DETERMINISM = preload("res://tests/integration/test_seed_determinism.gd")

func _initialize() -> void:
    var suites := [
        ["achievement_manager", SUITE_ACHIEVEMENT_MANAGER.run()],
        ["ad_service", SUITE_AD_SERVICE.run()],
        ["object_pool", SUITE_OBJECT_POOL.run()],
        ["weather_manager", SUITE_WEATHER_MANAGER.run()],
        ["visuals", SUITE_VISUALS.run()],
        ["campaign_manager", SUITE_CAMPAIGN_MANAGER.run()],
        ["crafting_manager", SUITE_CRAFTING_MANAGER.run()],
        ["consent_manager", SUITE_CONSENT_MANAGER.run()],
        ["daily_manager", SUITE_DAILY_MANAGER.run()],
        ["economy", SUITE_ECONOMY.run()],
        ["harvest_node", SUITE_HARVEST_NODE.run()],
        ["inventory", SUITE_INVENTORY.run()],
        ["inventory_capacity", SUITE_INVENTORY_CAPACITY.run()],
        ["market_order_board", SUITE_MARKET_ORDER_BOARD.run()],
        ["postgame_manager", SUITE_POSTGAME_MANAGER.run()],
        ["save_migration", SUITE_SAVE_MIGRATION.run()],
        ["save_system", SUITE_SAVE_SYSTEM.run()],
        ["settings_manager", SUITE_SETTINGS_MANAGER.run()],
        ["purchase_service", SUITE_PURCHASE_SERVICE.run()],
        ["word_system", SUITE_WORD_SYSTEM.run()],
        ["world_authority", SUITE_WORLD_AUTHORITY.run()],
        ["world_clock", SUITE_WORLD_CLOCK.run()],
        ["world_state", SUITE_WORLD_STATE.run()],
        ["device_profile", SUITE_DEVICE_PROFILE.run()],
        ["quality_manager", SUITE_QUALITY_MANAGER.run()],
        ["kid_ui", SUITE_KID_UI.run()],
        ["touch_controls", SUITE_TOUCH_CONTROLS.run()],
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
