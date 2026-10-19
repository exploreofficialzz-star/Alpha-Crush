extends Node3D
class_name AlphaCrushMain

## Alpha Crush: application root.
##   boot   : splash -> services -> save restore -> first-time hero pick -> main menu
##   battle : arena + hero + opposition + HUD are built for one match, then freed again when it ends
## Heavy work is split over frames and every step is written to BootGuard first, so a phone that dies mid-load restarts in
## safe mode (lowest graphics) instead of crashing the same way twice.
const MIN_SPLASH_SECONDS := 1.6
const SAVE_DELAY := 1.2

var save_system: SaveSystem
var settings: SettingsManager
var progress: PlayerProgress
var quality: QualityManager
var adaptive: AdaptiveQuality
var profiler: AlphaPerformanceProfiler
var audio: AudioManager
var analytics: AnalyticsService
var ads: AdService
var consent: ConsentManager
var purchases: PurchaseService
var security: SecurityService
var clock: WorldClock
var weather: WeatherManager
var splash: SplashScreen
var menu: MainMenu
var settings_overlay: SettingsOverlay
var loading_layer: CanvasLayer
var loading_label: Label

var battle_root: Node3D
var world: BattleWorld
var player: PlayerFighter
var director: CombatDirector
var fx: CombatFX
var match_director: MatchDirector
var hud: BattleHUD
var atmosphere: Atmosphere
var result_screen: ResultScreen

var _boot_started_msec := 0
var _in_battle := false
var _config: Dictionary = {}
var _last_result: Dictionary = {}
var _save_timer: Timer
var _loading_time := 0.0

# ------------------------------------------------------------------------------------------------ boot
func _ready() -> void:
    BootGuard.begin()
    _boot_started_msec = Time.get_ticks_msec()
    # The Android back button must never close the game; menus and the HUD decide what it does.
    get_tree().quit_on_go_back = false
    InputActions.ensure()
    splash = SplashScreen.new()
    splash.name = "Splash"
    add_child(splash)
    # Two frames so the splash is really on screen before any heavy work blocks the main thread.
    await get_tree().process_frame
    await get_tree().process_frame
    splash.set_progress(0.1)
    BootGuard.stage("services")
    _create_services()
    BootGuard.stage("save_restore")
    _restore_save()
    _detect_device_quality()
    if BootGuard.safe_mode:
        settings.set_value("quality", "low")
    _apply_runtime_settings()
    splash.set_progress(0.4)
    await _choose_character_if_new()
    await get_tree().process_frame
    BootGuard.stage("menu")
    _create_loading_layer()
    _create_menu()
    splash.set_progress(0.9)
    await get_tree().process_frame
    adaptive = AdaptiveQuality.new()
    adaptive.name = "AdaptiveQuality"
    adaptive.setup(quality, settings)
    add_child(adaptive)
    analytics.track("game_start", {"version": GameConfig.VERSION_NAME, "tier": str(settings.get_value("quality", "medium"))})
    audio.play_music("menu")
    await _finish_splash()
    BootGuard.finish()
    if not save_system.last_recovery_message.is_empty():
        menu.show_notice(save_system.last_recovery_message)
    elif BootGuard.failed_stage != "":
        menu.show_notice("The game restarted with lighter graphics to keep running smoothly")

func _create_services() -> void:
    save_system = SaveSystem.new()
    save_system.name = "SaveSystem"
    add_child(save_system)
    settings = SettingsManager.new()
    settings.name = "Settings"
    add_child(settings)
    progress = PlayerProgress.new()
    progress.name = "Progress"
    add_child(progress)
    quality = QualityManager.new()
    quality.name = "QualityManager"
    add_child(quality)
    quality.apply("medium")
    weather = WeatherManager.new()
    weather.name = "Weather"
    add_child(weather)
    weather.set_process(false)
    clock = WorldClock.new()
    clock.name = "WorldClock"
    add_child(clock)
    clock.set_process(false)
    analytics = AnalyticsService.new()
    analytics.name = "Analytics"
    add_child(analytics)
    security = SecurityService.new()
    security.name = "Security"
    add_child(security)
    profiler = AlphaPerformanceProfiler.new()
    profiler.name = "Profiler"
    add_child(profiler)
    consent = ConsentManager.new()
    consent.name = "ConsentManager"
    add_child(consent)
    ads = AdService.new()
    ads.name = "Ads"
    add_child(ads)
    ads.initialize()
    ads.configure_consent(consent)
    purchases = PurchaseService.new()
    purchases.name = "Purchases"
    add_child(purchases)
    purchases.initialize()
    audio = AudioManager.new()
    audio.name = "Audio"
    add_child(audio)
    _save_timer = Timer.new()
    _save_timer.name = "SaveTimer"
    _save_timer.one_shot = true
    _save_timer.wait_time = SAVE_DELAY
    add_child(_save_timer)
    _save_timer.timeout.connect(_save)
    progress.changed.connect(_schedule_save)
    settings.changed.connect(_on_settings_changed)
    consent.changed.connect(_on_consent_changed)
    purchases.purchase_completed.connect(_on_purchase_completed)
    purchases.purchase_failed.connect(_on_purchase_failed)
    ads.ad_failed.connect(_on_ad_failed)
    ads.reward_granted.connect(_on_rewarded_ad_reward)

func _restore_save() -> void:
    var data: Dictionary = save_system.data
    if data.has("progress"):
        progress.restore(data["progress"])
    if data.has("settings"):
        settings.restore(data["settings"])
        quality.apply(str(settings.get_value("quality", "medium")))
    if data.has("consent"):
        consent.restore(data["consent"])
    if data.has("purchases"):
        var purchase_data: Variant = data["purchases"]
        if purchase_data is Dictionary:
            var saved_entitlements: Variant = purchase_data.get("entitlements", {})
            if saved_entitlements is Dictionary:
                purchases.entitlements = saved_entitlements.duplicate(true)
        ads.remove_ads = purchases.has_entitlement("remove_ads")

## First launch only: pick a graphics tier from the phone's RAM / CPU / GPU. AdaptiveQuality then corrects the guess from the
## frame rate it actually sees.
func _detect_device_quality() -> void:
    if bool(settings.get_value("quality_detected", false)):
        return
    settings.set_value("quality", DeviceProfile.detect())
    settings.set_value("quality_detected", true)

## "Who is playing?" is shown once. The choice becomes the avatar_female setting.
func _choose_character_if_new() -> void:
    if bool(settings.get_value("character_chosen", false)):
        return
    var select := CharacterSelect.new()
    select.name = "CharacterSelect"
    select.audio = audio
    splash.visible = false
    BootGuard.rest("character_select")
    add_child(select)
    var gender: String = await select.chosen
    BootGuard.stage("character_chosen")
    settings.set_value("avatar_female", gender == "female")
    settings.set_value("character_chosen", true)
    splash.visible = true

func _finish_splash() -> void:
    var elapsed := float(Time.get_ticks_msec() - _boot_started_msec) / 1000.0
    if elapsed < MIN_SPLASH_SECONDS:
        await get_tree().create_timer(MIN_SPLASH_SECONDS - elapsed).timeout
    if is_instance_valid(splash):
        await splash.finish()
    splash = null

func _create_menu() -> void:
    menu = MainMenu.new()
    menu.name = "MainMenu"
    menu.progress = progress
    menu.settings = settings
    menu.audio = audio
    add_child(menu)
    menu.play_operation.connect(_on_play_operation)
    menu.play_quick.connect(_on_play_quick)
    menu.settings_requested.connect(_on_menu_settings)
    menu.data_changed.connect(_schedule_save)
    settings_overlay = SettingsOverlay.new()
    settings_overlay.name = "SettingsOverlay"
    add_child(settings_overlay)
    settings_overlay.setup(settings, consent, ads, purchases)
    settings_overlay.closed.connect(_on_settings_closed)
    settings_overlay.save_requested.connect(_schedule_save)

func _create_loading_layer() -> void:
    loading_layer = CanvasLayer.new()
    loading_layer.name = "Loading"
    loading_layer.layer = 90
    loading_layer.visible = false
    add_child(loading_layer)
    var backdrop := ColorRect.new()
    backdrop.color = KidUI.NAVY
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    loading_layer.add_child(backdrop)
    loading_label = KidUI.number_label(54, KidUI.GOLD)
    loading_label.text = "LOADING"
    loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    loading_layer.add_child(loading_label)

func _process(delta: float) -> void:
    if loading_layer != null and loading_layer.visible:
        _loading_time += delta
        loading_label.text = "%s%s" % [str(_loading_title), ".".repeat(int(_loading_time * 3.0) % 4)]

var _loading_title := "LOADING"

func _show_loading(title: String) -> void:
    _loading_title = title
    _loading_time = 0.0
    loading_label.text = title
    loading_layer.visible = true

func _hide_loading() -> void:
    loading_layer.visible = false

# ------------------------------------------------------------------------------------------------ menu callbacks
func _on_play_operation(index: int) -> void:
    _start_battle(OperationCatalog.operation(index))

func _on_play_quick(config: Dictionary) -> void:
    _start_battle(config)

func _on_menu_settings() -> void:
    settings_overlay.open()

func _on_settings_closed() -> void:
    menu.show_home()
    _schedule_save()

# ------------------------------------------------------------------------------------------------ battle lifecycle
func _start_battle(config: Dictionary) -> void:
    if _in_battle:
        return
    _in_battle = true
    _config = config
    menu.visible = false
    _show_loading("LOADING " + str(config.get("title", "BATTLE")))
    await get_tree().process_frame
    await get_tree().process_frame
    BootGuard.stage("battle_" + str(config.get("arena", "arena")))
    audio.stop_music()
    battle_root = Node3D.new()
    battle_root.name = "Battle"
    add_child(battle_root)
    director = CombatDirector.new()
    director.name = "CombatDirector"
    battle_root.add_child(director)
    fx = CombatFX.new()
    fx.name = "CombatFX"
    battle_root.add_child(fx)
    fx.setup(quality)
    world = BattleWorld.new()
    world.name = "BattleWorld"
    battle_root.add_child(world)
    await world.build(str(config.get("arena", "farmstead")), int(config.get("seed", 1)), quality, director, fx, audio)
    BootGuard.stage("battle_actors")
    _set_time_and_weather(ArenaCatalog.arena(str(config.get("arena", "farmstead"))))
    _create_player()
    atmosphere = Atmosphere.new()
    atmosphere.name = "Atmosphere"
    atmosphere.setup(player, clock, weather, quality)
    atmosphere.audio = audio
    battle_root.add_child(atmosphere)
    await get_tree().process_frame
    match_director = MatchDirector.new()
    match_director.name = "MatchDirector"
    battle_root.add_child(match_director)
    match_director.setup(config, world, player, director, fx, audio, quality)
    match_director.match_ended.connect(_on_match_ended)
    hud = BattleHUD.new()
    hud.name = "BattleHUD"
    hud.player = player
    hud.director = director
    hud.match_director = match_director
    hud.settings = settings
    hud.audio = audio
    hud.fx = fx
    hud.quality = quality
    hud.consent = consent
    hud.ads = ads
    hud.purchases = purchases
    hud.coach_enabled = not bool(settings.get_value("tutorial_done", false))
    hud.quit_requested.connect(_on_quit_to_menu)
    add_child(hud)
    await _wait_for_ground()
    player.set_physics_process(true)
    match_director.begin()
    audio.play_music("boss" if bool(config.get("boss", false)) else "battle")
    if adaptive != null:
        adaptive.reset_window(8.0)
    analytics.track("battle_start", {"mode": str(config.get("mode", "")), "arena": str(config.get("arena", "")), "op": int(config.get("index", -1))})
    await get_tree().process_frame
    _hide_loading()
    BootGuard.finish()

func _create_player() -> void:
    var gender := "female" if bool(settings.get_value("avatar_female", false)) else "male"
    var loadout := progress.loadout_for_match()
    var outfit := LoadoutCatalog.rig_outfit(str(loadout.get("outfit", "alpha")), gender, 7 if gender == "male" else 12)
    player = PlayerFighter.new()
    player.name = "Player"
    battle_root.add_child(player)
    player.build(gender, outfit, loadout, settings)
    player.global_position = world.alpha_spawn
    player.join_battle(director, fx, audio)
    player.reset_camera_behind()
    player.set_physics_process(false)

## Keeps the hero frozen until the ground under them has collision, so a slow phone never drops them through the map.
func _wait_for_ground() -> void:
    for attempt in 90:
        var space := get_world_3d().direct_space_state
        var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0.0, 20.0, 0.0), player.global_position + Vector3(0.0, -40.0, 0.0), Teams.LAYER_WORLD)
        if not space.intersect_ray(query).is_empty():
            return
        await get_tree().physics_frame

func _set_time_and_weather(arena: Dictionary) -> void:
    clock.elapsed = float(arena.get("time", 0.4)) * WorldClock.CYCLE_SECONDS
    clock.set_process(false)
    weather.set_weather(str(arena.get("weather", "clear")))
    weather.set_process(false)

func _on_match_ended(result: Dictionary) -> void:
    _last_result = result
    var before := progress.rank
    progress.apply_result(result)
    var after := progress.rank
    _save()
    analytics.track("battle_end", {"won": bool(result.get("won", false)), "stars": int(result.get("stars", 0)), "mode": str(result.get("mode", "")), "time": int(result.get("time", 0.0))})
    var index := int(result.get("operation", -1))
    var has_next := index >= 0 and index + 1 < OperationCatalog.count()
    var can_double := ads != null and ads.sdk_available and not GameConfig.CHILD_DIRECTED
    result_screen = ResultScreen.new()
    result_screen.name = "ResultScreen"
    result_screen.audio = audio
    add_child(result_screen)
    result_screen.next_requested.connect(_on_result_next)
    result_screen.retry_requested.connect(_on_result_retry)
    result_screen.menu_requested.connect(_on_quit_to_menu)
    result_screen.double_coins_requested.connect(_on_double_requested)
    result_screen.show_result(result, before, after, has_next, can_double)
    audio.play_music("menu")

func _on_result_next() -> void:
    var index := int(_last_result.get("operation", -1))
    _end_battle()
    if index >= 0 and index + 1 < OperationCatalog.count():
        _start_battle(OperationCatalog.operation(index + 1))
    else:
        _return_to_menu()

func _on_result_retry() -> void:
    var config := _config
    _end_battle()
    _start_battle(config)

func _on_quit_to_menu() -> void:
    _end_battle()
    _return_to_menu()

func _end_battle() -> void:
    get_tree().paused = false
    Engine.time_scale = 1.0
    if is_instance_valid(result_screen):
        result_screen.queue_free()
        result_screen = null
    if is_instance_valid(hud):
        hud.queue_free()
        hud = null
    if is_instance_valid(battle_root):
        battle_root.queue_free()
        battle_root = null
    world = null
    player = null
    director = null
    fx = null
    match_director = null
    atmosphere = null
    _in_battle = false

func _return_to_menu() -> void:
    menu.visible = true
    menu.refresh()
    audio.play_music("menu")

func _on_double_requested() -> void:
    ads.show_rewarded("double_coins")

# ------------------------------------------------------------------------------------------------ services callbacks
func _on_settings_changed() -> void:
    _apply_runtime_settings()
    _schedule_save()

func _apply_runtime_settings() -> void:
    if settings == null:
        return
    if audio != null:
        audio.enabled = bool(settings.get_value("sfx", true))
        audio.set_music_enabled(bool(settings.get_value("music", true)))
    if quality != null:
        quality.apply(str(settings.get_value("quality", "medium")))
    if is_instance_valid(player):
        player.camera_sensitivity = clampf(float(settings.get_value("camera_sensitivity", 1.0)), 0.4, 2.2)
        player.simple_mode = bool(settings.get_value("simple_mode", true))
        player.aim_assist = clampf(float(settings.get_value("aim_assist", 1.0)), 0.0, 1.0)

func _on_consent_changed(personalized: bool) -> void:
    analytics.track("ad_consent", {"personalized": personalized})
    _schedule_save()

func _on_purchase_completed(product_id: String) -> void:
    var message := ""
    if product_id == "remove_ads":
        ads.remove_ads = true
        purchases.entitlements[product_id] = true
        message = "Ads removed for this account."
    elif product_id == "coin_pack_small":
        progress.add_coins(100)
        message = "Coin pack added."
    elif product_id == "coin_pack_large":
        progress.add_coins(550)
        message = "Large coin pack added."
    analytics.track("purchase", {"product": product_id})
    _toast(message)
    _save()

func _on_purchase_failed(product_id: String, reason: String) -> void:
    _toast("Purchase unavailable: %s (%s)" % [product_id, reason])

func _on_ad_failed(kind: String, reason: String) -> void:
    _toast("Ad unavailable: %s (%s)" % [kind, reason])

func _on_rewarded_ad_reward(kind: String) -> void:
    if kind == "double_coins":
        progress.add_coins(int(_last_result.get("coins", 0)))
        if is_instance_valid(result_screen):
            result_screen.mark_doubled()
    elif kind == "coins":
        progress.add_coins(50)
        _toast("+50 coins")
    elif kind == "gems":
        progress.gems += 3
        progress.changed.emit()
    analytics.track("rewarded_ad_completed", {"kind": kind})
    _save()

func _toast(text: String) -> void:
    if text == "":
        return
    if is_instance_valid(hud):
        hud.show_toast(text)
    elif is_instance_valid(menu):
        menu.show_notice(text)

# ------------------------------------------------------------------------------------------------ saving and system events
func _schedule_save() -> void:
    if is_instance_valid(_save_timer) and _save_timer.is_stopped():
        _save_timer.start()

func _save(clean_shutdown: bool = false) -> void:
    if not is_instance_valid(save_system) or progress == null:
        return
    save_system.data["progress"] = progress.snapshot()
    save_system.data["settings"] = settings.snapshot()
    save_system.data["consent"] = consent.snapshot()
    save_system.data["purchases"] = {"entitlements": purchases.entitlements.duplicate(true)}
    save_system.data["session"] = {"last_save": Time.get_unix_time_from_system(), "clean_shutdown": clean_shutdown}
    save_system.save_game()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save(true)
    elif what == NOTIFICATION_APPLICATION_PAUSED:
        _save(false)
        if is_instance_valid(hud) and is_instance_valid(match_director) and not match_director.finished:
            hud.open_pause()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _handle_back()

func _handle_back() -> void:
    if is_instance_valid(result_screen):
        return
    if is_instance_valid(hud):
        hud.handle_back()
    elif is_instance_valid(settings_overlay) and settings_overlay.is_open():
        settings_overlay.close()
    elif is_instance_valid(menu):
        menu.handle_back()
