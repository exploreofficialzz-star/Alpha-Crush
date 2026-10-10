extends Node3D
class_name AlphaCrushMain

var player: AlphaCrushPlayer
var world: AlphaCrushWorld
var word_system: WordSystem
var inventory: Inventory
var hud: AlphaCrushHUD
var save_system: SaveSystem
var world_state: WorldState
var discovery: DiscoveryManager
var economy: EconomyManager
var progression: ProgressionManager
var achievements: AchievementManager
var chunk_streamer: ChunkStreamer
var weather: WeatherManager
var quality: QualityManager
var analytics: AnalyticsService
var network: NetworkService
var ads: AdService
var consent: ConsentManager
var purchases: PurchaseService
var audio: AudioManager
var vfx: VFXManager
var daily: DailyManager
var live_events: LiveEventManager
var settings: SettingsManager
var clock: WorldClock
var crafting: CraftingManager
var marketplace: MarketplaceManager
var market_orders: MarketOrderBoard
var postgame: PostgameManager
var map_manager: MapManager
var hints: HintManager
var security: SecurityService
var multiplayer_session: MultiplayerSession
var profiler: AlphaPerformanceProfiler
var profile: PlayerProfileManager
var opportunities: OpportunityManager
var campaign: CampaignManager
var world_authority: WorldAuthority
var autosave: Timer
var world_environment: Environment
var sun_light: DirectionalLight3D
var atmosphere: Atmosphere
var splash: SplashScreen
var adaptive: AdaptiveQuality

## The game's own splash stays up at least this long so the logo is always seen, even on fast phones.
const MIN_SPLASH_SECONDS := 1.6
var _boot_started_msec := 0

func _ready() -> void:
    _boot_started_msec = Time.get_ticks_msec()
    # The Android back button must never close the game under a child's thumb; the HUD handles it.
    get_tree().quit_on_go_back = false
    _setup_input()
    _setup_environment()
    splash = SplashScreen.new()
    splash.name = "Splash"
    add_child(splash)
    # Two frames so the splash is really on screen before any heavy work blocks the main thread.
    await get_tree().process_frame
    await get_tree().process_frame
    splash.set_progress(0.1)
    _create_services()
    _restore_save()
    _detect_device_quality()
    _apply_runtime_settings()
    splash.set_progress(0.2)
    await _choose_character_if_new()
    await get_tree().process_frame
    splash.set_progress(0.35)
    _create_player()
    _create_atmosphere()
    splash.set_progress(0.5)
    await get_tree().process_frame
    _create_world()
    _create_hud()
    _apply_runtime_settings()
    _connect_systems()
    splash.set_progress(0.65)
    # Add the world only after its signals are connected, so its first discovery
    # and tutorial objective are not emitted into the void during _ready().
    add_child(world)
    _restore_world_after_load()
    splash.set_progress(0.85)
    await _wait_for_ground()
    player.set_physics_process(true)
    adaptive = AdaptiveQuality.new()
    adaptive.name = "AdaptiveQuality"
    adaptive.setup(quality, settings)
    add_child(adaptive)
    autosave = Timer.new()
    autosave.wait_time = 30.0
    autosave.autostart = true
    add_child(autosave)
    autosave.timeout.connect(_save)
    analytics.track("game_start", {"version": GameConfig.VERSION_NAME, "tier": str(settings.get_value("quality", "medium"))})
    audio.play_music("village")
    await _finish_splash()
    if not save_system.last_recovery_message.is_empty():
        hud.show_message(save_system.last_recovery_message)
    else:
        hud.show_message("Welcome to Alpha Crush — WORDS CHANGE THE WORLD")

## First launch only: pick a graphics tier from the phone's RAM / CPU / GPU. AdaptiveQuality
## then corrects the guess from the frame rate it actually sees.
func _detect_device_quality() -> void:
    if bool(settings.get_value("quality_detected", false)):
        return
    settings.set_value("quality", DeviceProfile.detect())
    settings.set_value("quality_detected", true)

## "Who is playing?" - shown once, before the heavy world build, so the child can start tapping
## straight away. The choice becomes the avatar_female setting.
func _choose_character_if_new() -> void:
    if bool(settings.get_value("character_chosen", false)):
        return
    var select := CharacterSelect.new()
    select.name = "CharacterSelect"
    select.audio = audio
    splash.visible = false
    add_child(select)
    var gender: String = await select.chosen
    settings.set_value("avatar_female", gender == "female")
    settings.set_value("character_chosen", true)
    splash.visible = true

## Keeps the hero frozen (and the splash up) until the ground under them has collision, so a slow
## phone never drops the player through a world that has not finished building.
func _wait_for_ground() -> void:
    for _attempt in 90:
        var space := get_world_3d().direct_space_state
        var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 20, 0), player.global_position + Vector3(0, -40, 0), 1)
        if not space.intersect_ray(query).is_empty():
            return
        await get_tree().physics_frame

func _finish_splash() -> void:
    var elapsed := float(Time.get_ticks_msec() - _boot_started_msec) / 1000.0
    if elapsed < MIN_SPLASH_SECONDS:
        await get_tree().create_timer(MIN_SPLASH_SECONDS - elapsed).timeout
    if is_instance_valid(splash):
        await splash.finish()
    splash = null

func _create_services() -> void:
    save_system = preload("res://core/services/save_system.gd").new()
    save_system.name = "SaveSystem"
    add_child(save_system)

    world_state = preload("res://world/world_state/world_state.gd").new()
    world_state.name = "WorldState"
    add_child(world_state)

    inventory = preload("res://gameplay/inventory.gd").new()
    inventory.name = "Inventory"
    inventory.capacity = GameConfig.MAX_INVENTORY_SLOTS
    add_child(inventory)
    inventory.add_item("coins", GameConfig.STARTING_COINS)

    word_system = preload("res://words/word_system.gd").new()
    word_system.name = "WordSystem"
    add_child(word_system)
    word_system.world = world_state

    discovery = preload("res://gameplay/discovery/discovery_manager.gd").new()
    discovery.name = "DiscoveryManager"
    add_child(discovery)

    progression = preload("res://gameplay/progression/progression_manager.gd").new()
    progression.name = "Progression"
    add_child(progression)

    achievements = preload("res://gameplay/achievements/achievement_manager.gd").new()
    achievements.name = "Achievements"
    achievements.inventory = inventory
    add_child(achievements)

    live_events = preload("res://gameplay/live_events/live_event_manager.gd").new()
    live_events.name = "LiveEvents"
    add_child(live_events)

    economy = preload("res://economy/currencies/economy_manager.gd").new()
    economy.name = "Economy"
    economy.inventory = inventory
    add_child(economy)
    economy.set_live_events(live_events)

    marketplace = preload("res://gameplay/marketplace/marketplace_manager.gd").new()
    marketplace.name = "Marketplace"
    add_child(marketplace)
    marketplace.economy = economy

    market_orders = preload("res://gameplay/marketplace/order_board.gd").new()
    market_orders.name = "MarketOrderBoard"
    add_child(market_orders)
    market_orders.setup(marketplace, inventory, economy, live_events)

    postgame = preload("res://gameplay/campaign/postgame_manager.gd").new()
    postgame.name = "PostgameManager"
    add_child(postgame)

    crafting = preload("res://gameplay/crafting/crafting_manager.gd").new()
    crafting.name = "Crafting"
    crafting.inventory = inventory
    add_child(crafting)

    daily = preload("res://gameplay/daily/daily_manager.gd").new()
    daily.name = "Daily"
    add_child(daily)

    map_manager = preload("res://gameplay/map/map_manager.gd").new()
    map_manager.name = "MapManager"
    add_child(map_manager)

    hints = preload("res://gameplay/hints/hint_manager.gd").new()
    hints.name = "HintManager"
    add_child(hints)

    weather = preload("res://world/weather/weather_manager.gd").new()
    weather.name = "Weather"
    add_child(weather)

    clock = preload("res://world/time/world_clock.gd").new()
    clock.name = "WorldClock"
    add_child(clock)

    quality = preload("res://mobile/quality_manager.gd").new()
    quality.name = "QualityManager"
    add_child(quality)
    quality.apply("medium")

    settings = preload("res://ui/settings/settings_manager.gd").new()
    settings.name = "Settings"
    add_child(settings)

    analytics = preload("res://analytics/analytics_service.gd").new()
    analytics.name = "Analytics"
    add_child(analytics)

    network = preload("res://multiplayer/networking/network_service.gd").new()
    network.name = "Network"
    add_child(network)

    multiplayer_session = preload("res://multiplayer/session/multiplayer_session.gd").new()
    multiplayer_session.name = "MultiplayerSession"
    add_child(multiplayer_session)

    security = preload("res://security/security_service.gd").new()
    security.name = "Security"
    add_child(security)

    profiler = preload("res://performance/profiler.gd").new()
    profiler.name = "Profiler"
    add_child(profiler)

    profile = preload("res://player/profile/profile_manager.gd").new()
    profile.name = "PlayerProfile"
    add_child(profile)

    opportunities = preload("res://gameplay/opportunities/opportunity_manager.gd").new()
    opportunities.name = "OpportunityManager"
    add_child(opportunities)

    campaign = preload("res://gameplay/campaign/campaign_manager.gd").new()
    campaign.name = "CampaignManager"
    add_child(campaign)

    world_authority = preload("res://multiplayer/authority/world_authority.gd").new()
    world_authority.name = "WorldAuthority"
    world_authority.world_state = world_state
    add_child(world_authority)
    world_authority.configure(world_state)

    consent = preload("res://ads/consent/consent_manager.gd").new()
    consent.name = "ConsentManager"
    add_child(consent)

    ads = preload("res://ads/admob/ad_service.gd").new()
    ads.name = "Ads"
    add_child(ads)
    ads.initialize()
    ads.configure_consent(consent)

    purchases = preload("res://economy/purchases/purchase_service.gd").new()
    purchases.name = "Purchases"
    add_child(purchases)
    purchases.initialize()

    audio = preload("res://audio/audio_manager.gd").new()
    audio.name = "Audio"
    add_child(audio)

    vfx = preload("res://vfx/vfx_manager.gd").new()
    vfx.name = "VFX"
    add_child(vfx)

func _create_player() -> void:
    player = preload("res://player/player.gd").new()
    player.name = "Player"
    player.settings = settings
    # Main sits at the origin, so local == global here. global_position cannot be written
    # before the node is inside the tree (the engine logs an error and the write is lost).
    player.position = Vector3(0, 1.2, 10)
    var saved_player: Dictionary = save_system.data.get("player", {})
    var saved_position: Variant = saved_player.get("position", [])
    if saved_position is Array and saved_position.size() >= 3:
        var restored := Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
        # Saves written while the old terrain had no top-side collision may hold a position
        # far below the world; spawn those players at the village instead of in freefall.
        if restored.y > -5.0 and restored.length() < 100000.0:
            player.position = restored
    add_child(player)
    player.set_physics_process(false)
    if player.has_method("apply_profile"):
        player.apply_profile(profile)

func _create_world() -> void:
    world = preload("res://world/world.gd").new()
    world.name = "World"
    world.word_system = word_system
    world.inventory = inventory
    world.world_state = world_state
    world.discovery = discovery
    world.economy = economy
    world.progression = progression
    world.world_authority = world_authority
    world.campaign = campaign
    world.market_orders = market_orders
    world.postgame = postgame
    world.configure(daily, live_events, map_manager)
    world.restore_word_progress(save_system.data.get("word_progress", {}))
    world.restore_harvest_state(save_system.data.get("harvest_state", {}))

    chunk_streamer = preload("res://world/generation/chunk_streamer.gd").new()
    chunk_streamer.name = "ChunkStreamer"
    world.add_child(chunk_streamer)
    chunk_streamer.setup(player, GameConfig.WORLD_SEED, map_manager, quality)

    hints.world = world
    hints.word_system = word_system
    word_system.world = world
    word_system.assembly_ready.connect(_on_assembly_ready)
    word_system.word_completed.connect(_on_word_completed)
    player.interaction_source = world
    multiplayer_session.configure(network, player)

func _create_hud() -> void:
    hud = preload("res://ui/hud.gd").new()
    hud.name = "HUD"
    hud.player = player
    hud.world = world
    hud.word_system = word_system
    hud.inventory = inventory
    hud.crafting = crafting
    hud.progression = progression
    hud.daily = daily
    hud.map_manager = map_manager
    hud.hints = hints
    hud.settings = settings
    hud.profiler = profiler
    hud.profile = profile
    hud.quality = quality
    hud.multiplayer_session = multiplayer_session
    hud.consent = consent
    hud.ads = ads
    hud.purchases = purchases
    hud.audio = audio
    hud.opportunities = opportunities
    add_child(hud)

func _connect_systems() -> void:
    settings.changed.connect(_apply_runtime_settings)
    consent.changed.connect(func(personalized: bool):
        analytics.track("ad_consent", {"personalized": personalized})
        _save()
    )
    world.discovery_message.connect(hud.show_message)
    world.objective_changed.connect(hud.set_objective)
    world.context_changed.connect(hud.set_context)
    world.crafting_requested.connect(hud.open_crafting)
    discovery.discovered_new.connect(_on_discovery)
    achievements.unlocked.connect(func(_id: String, title: String, reward: Dictionary):
        hud.show_message("ACHIEVEMENT UNLOCKED: %s  +%s" % [title, str(reward)])
        analytics.track("achievement_unlocked", {"title": title})
    )
    weather.changed.connect(func(w: String):
        _apply_world_ambience()
        hud.show_message("Weather: %s" % w.capitalize())
    )
    clock.period_changed.connect(func(_period: String): _apply_world_ambience())
    inventory.changed.connect(func():
        hud.refresh_inventory()
        if hud.crafting_panel and hud.crafting_panel.visible:
            hud.refresh_crafting()
    )
    save_system.recovery.connect(hud.show_message)
    word_system.letter_collected.connect(func(letter: String):
        analytics.track("letter_collected", {"letter": letter})
        audio.play_sfx("pickup")
    )
    word_system.word_started.connect(func(word: String): analytics.track("word_started", {"word": word}))
    daily.completed_reward.connect(_on_daily_reward)
    hints.hint_ready.connect(hud.show_message)
    crafting.crafted.connect(func(id: String, output: String):
        analytics.track("craft", {"recipe": id, "output": output})
        achievements.record("craft")
        hud.show_message("Crafted %s" % output)
    )
    economy.sold.connect(func(_item_id: String, _amount: int, _payout: int):
        achievements.record("sale")
        audio.play_sfx("market")
    )
    market_orders.order_fulfilled.connect(func(_id: String, payout: int):
        achievements.record("sale")
        audio.play_sfx("market")
        analytics.track("market_order_fulfilled", {"payout": payout})
    )
    world.resource_harvested.connect(func(_item_id: String, amount: int):
        achievements.record("harvest", amount)
        audio.play_sfx("harvest")
    )
    map_manager.map_changed.connect(func(): hud.set_map_dirty())
    purchases.purchase_completed.connect(_on_purchase_completed)
    purchases.purchase_failed.connect(func(product_id: String, reason: String):
        hud.show_message("Purchase unavailable: %s (%s)" % [product_id, reason])
    )
    ads.ad_failed.connect(func(kind: String, reason: String):
        hud.show_message("Ad unavailable: %s (%s)" % [kind, reason])
    )
    ads.reward_granted.connect(_on_rewarded_ad_reward)
    network.status_changed.connect(func(online: bool): hud.show_message("Multiplayer: %s" % ("Connected" if online else "Offline")))
    multiplayer_session.session_message.connect(hud.show_message)
    world_authority.world_change_committed.connect(_on_authoritative_world_change)
    campaign.chapter_completed.connect(_on_campaign_chapter_completed)
    campaign.finale_unlocked.connect(func(): hud.show_message("THE FINAL WORD IS WAITING — gather the village at the Community Hall."))
    campaign.finale_completed.connect(func(): hud.show_message("ALPHA CRUSH COMPLETE — the world is yours to keep exploring."))
    postgame.challenge_completed.connect(_on_postgame_challenge_completed)
    profiler.sample_ready.connect(func(fps: float, frame_ms: float, memory_mb: float): analytics.track("performance_sample", {"fps": fps, "frame_ms": frame_ms, "memory_mb": memory_mb}))

func _on_discovery(id: String, title: String) -> void:
    hud.show_message("DISCOVERED  •  %s" % title)
    audio.play_sfx("discovery")
    daily.progress("daily_discover")
    achievements.record("discovery")
    if id in ["riverlands", "caves", "starter_village", "orchard_garden"]:
        achievements.record("region_discovered", 1, id)
    analytics.track("discovery", {"id": id})

func _on_purchase_completed(product_id: String) -> void:
    match product_id:
        "remove_ads":
            ads.remove_ads = true
            purchases.entitlements[product_id] = true
            hud.show_message("Ads removed for this account.")
        "coin_pack_small":
            economy.add_coins(100)
            hud.show_message("Coin pack added.")
        "coin_pack_large":
            economy.add_coins(550)
            hud.show_message("Large coin pack added.")
    analytics.track("purchase", {"product": product_id})
    _save()

func _on_rewarded_ad_reward(kind: String) -> void:
    match kind:
        "coins": economy.add_coins(50)
        "gems": inventory.add_item("gems", 3)
        _:
            hud.show_message("Reward received: %s" % kind)
    analytics.track("rewarded_ad_completed", {"kind": kind})
    _save()

func _on_daily_reward(_objective_id: String, reward: Dictionary) -> void:
    if reward.has("coins"):
        economy.add_coins(int(reward["coins"]))
    if reward.has("gems"):
        inventory.add_item("gems", int(reward["gems"]))
    hud.show_message("Daily reward claimed!")
    analytics.track("daily_reward", reward)

func _restore_save() -> void:
    var data: Dictionary = save_system.data
    if data.has("inventory"):
        inventory.restore(data["inventory"])
    if data.has("world_state"):
        world_state.restore(data["world_state"])
    if data.has("discoveries"):
        discovery.restore(data["discoveries"])
    if data.has("map"):
        map_manager.restore(data["map"])
    if data.has("upgrades"):
        economy.upgrades = data["upgrades"].duplicate(true)
    if data.has("daily"):
        daily.restore(data["daily"])
    if data.has("events"):
        live_events.restore(data["events"])
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
    if data.has("profile"):
        profile.restore(data["profile"])
    if data.has("world_clock"):
        clock.restore(data["world_clock"])
    if data.has("weather"):
        weather.restore(data["weather"])
    if data.has("opportunities"):
        opportunities.restore(data["opportunities"])
    if data.has("progression"):
        progression.restore(data["progression"])
    if data.has("achievements"):
        achievements.restore(data["achievements"])
    if data.has("campaign"):
        campaign.restore(data["campaign"])
    if data.has("market_orders"):
        market_orders.restore(data["market_orders"])
    if data.has("postgame"):
        postgame.restore(data["postgame"])
    if data.has("word_system"):
        word_system.restore(data["word_system"])
    var saved_capacity := int(data.get("inventory_capacity", GameConfig.MAX_INVENTORY_SLOTS))
    inventory.capacity = clampi(saved_capacity, GameConfig.MAX_INVENTORY_SLOTS, GameConfig.MAX_INVENTORY_SLOTS + 48)
    # Legacy saves did not persist capacity; reconstruct the one-time BASKET bonus.
    if not data.has("inventory_capacity") and world_state.is_complete("basket_upgrade"):
        inventory.capacity = GameConfig.MAX_INVENTORY_SLOTS + 12

func _restore_world_after_load() -> void:
    if world and world.has_method("apply_persistent_state"):
        world.apply_persistent_state()
    if world and world.has_method("resume_saved_word") and word_system.has_active_word() and world.current_word_letters.is_empty():
        world.resume_saved_word(word_system.active_word)
    if player and player.has_method("apply_profile"):
        player.apply_profile(profile)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save(what == NOTIFICATION_WM_CLOSE_REQUEST)
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if is_instance_valid(hud):
            hud.handle_back()

func _save(clean_shutdown: bool = false) -> void:
    if not is_instance_valid(save_system) or not is_instance_valid(player):
        return
    save_system.data.player.position = [player.global_position.x, player.global_position.y, player.global_position.z]
    save_system.data.inventory = inventory.snapshot()
    save_system.data.inventory_capacity = inventory.capacity
    save_system.data.world_state = world_state.snapshot()
    save_system.data.discoveries = discovery.snapshot()
    save_system.data.map = map_manager.snapshot()
    save_system.data.upgrades = economy.upgrades.duplicate(true)
    save_system.data.daily = daily.snapshot()
    save_system.data.events = live_events.snapshot()
    save_system.data.world_clock = clock.snapshot()
    save_system.data.weather = weather.snapshot()
    save_system.data.settings = settings.snapshot()
    save_system.data.consent = consent.snapshot()
    save_system.data.purchases = {"entitlements": purchases.entitlements.duplicate(true)}
    save_system.data.progression = {"level": progression.level, "xp": progression.xp}
    save_system.data.achievements = achievements.snapshot()
    save_system.data.word_system = word_system.snapshot()
    save_system.data.word_progress = world.snapshot_word_progress()
    save_system.data.harvest_state = world.snapshot_harvest_state()
    save_system.data.profile = profile.snapshot()
    save_system.data.opportunities = opportunities.snapshot()
    save_system.data.campaign = campaign.snapshot()
    save_system.data.market_orders = market_orders.snapshot()
    save_system.data.postgame = postgame.snapshot()
    save_system.data.session = {
        "last_save": Time.get_unix_time_from_system(),
        "clean_shutdown": clean_shutdown
    }
    save_system.save_game()

func _on_assembly_ready(word: String) -> void:
    if world.has_method("assemble_word"):
        world.assemble_word(word, player.global_position + Vector3(0, 2, -2))

func _on_word_completed(word: String) -> void:
    if campaign:
        campaign.complete_for_word(word)
    world.apply_word_consequence(word)
    # In multiplayer, rewards are granted only after the authority commits the
    # world change. Single-player resolves locally and can reward immediately.
    if not NetworkStatus.is_online(self):
        _grant_word_completion_rewards(word)

func _on_authoritative_world_change(object_id: String, _state: String) -> void:
    if not object_id.begins_with("word_"):
        return
    var word := object_id.substr(5).to_upper()
    var already_applied := world.completed_words.has(word)
    world.apply_word_consequence_from_authority(object_id)
    if not already_applied:
        _grant_word_completion_rewards(word)
    hud.show_message("WORLD STATE SYNCHRONIZED")


func _on_postgame_challenge_completed(_id: String, reward: Dictionary) -> void:
    if reward.has("coins"):
        economy.add_coins(int(reward["coins"]))
    if reward.has("xp"):
        progression.grant(int(reward["xp"]))
    hud.show_message("POSTGAME REWARD • +%s coins • +%s XP" % [str(reward.get("coins", 0)), str(reward.get("xp", 0))])
    analytics.track("postgame_challenge_completed", reward)
    _save()

func _on_campaign_chapter_completed(_id: String, reward: Dictionary) -> void:
    if reward.has("coins"):
        economy.add_coins(int(reward["coins"]))
    if reward.has("xp"):
        progression.grant(int(reward["xp"]))
    hud.show_message("WORLD CHAPTER RESTORED • +%s coins • +%s XP" % [str(reward.get("coins", 0)), str(reward.get("xp", 0))])
    analytics.track("campaign_chapter_completed", reward)
    _save()

func _grant_word_completion_rewards(word: String) -> void:
    progression.grant(50)
    daily.progress("daily_word")
    achievements.record("word_completed")
    vfx.burst(player.global_position + Vector3(0, 1, 0))
    audio.play_sfx("word_complete")
    analytics.track("word_completed", {"word": word})
    hud.show_message("%s changed the world!" % word)
    _save()

func _setup_input() -> void:
    _key_action("move_forward", KEY_W)
    _key_action("move_back", KEY_S)
    _key_action("move_left", KEY_A)
    _key_action("move_right", KEY_D)
    _key_action("interact", KEY_E)
    _key_action("jump", KEY_SPACE)
    _key_action("sprint", KEY_SHIFT)
    _key_action("inventory", KEY_I)
    _key_action("map", KEY_M)
    _key_action("drop", KEY_Q)
    _key_action("hint", KEY_H)
    _key_action("menu", KEY_ESCAPE)

func _key_action(action: String, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for event in InputMap.action_get_events(action):
        if event is InputEventKey and event.physical_keycode == keycode:
            return
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    InputMap.action_add_event(action, event)

func _setup_environment() -> void:
    # Sky, sun, fog and tone-mapping are owned by Atmosphere, which needs the player and clock (see _create_atmosphere).
    pass

func _create_atmosphere() -> void:
    atmosphere = Atmosphere.new()
    atmosphere.name = "Atmosphere"
    atmosphere.setup(player, clock, weather, quality)
    atmosphere.audio = audio
    player.footstep.connect(func(): audio.play_footstep())
    add_child(atmosphere)
    world_environment = atmosphere.environment
    sun_light = atmosphere.sun

func _apply_runtime_settings() -> void:
    if settings == null:
        return
    if audio:
        audio.enabled = bool(settings.get_value("sfx", true))
        audio.set_music_enabled(bool(settings.get_value("music", true)))
    if quality:
        quality.apply(str(settings.get_value("quality", "medium")))
    if player:
        player.camera_sensitivity = clampf(float(settings.get_value("camera_sensitivity", 1.0)), 0.5, 2.0)
        player.set_body_type("female" if bool(settings.get_value("avatar_female", false)) else "male")
    if hud:
        hud.apply_accessibility()

func _apply_world_ambience() -> void:
    # Atmosphere follows the world clock and weather every frame; nothing to switch on period changes anymore.
    if atmosphere != null:
        atmosphere.set_process(true)

