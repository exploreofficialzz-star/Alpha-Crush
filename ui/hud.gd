extends CanvasLayer
class_name AlphaCrushHUD

var player: AlphaCrushPlayer
var world: AlphaCrushWorld
var word_system: WordSystem
var inventory: Inventory
var crafting: CraftingManager
var progression: ProgressionManager
var daily: DailyManager
var map_manager: MapManager
var hints: HintManager
var settings: SettingsManager
var profiler: AlphaPerformanceProfiler
var profile: PlayerProfileManager
var quality: QualityManager
var multiplayer_session: MultiplayerSession
var consent: ConsentManager
var ads: AdService
var purchases: PurchaseService
var map_view: MapView
var camera_drag: CameraDrag

var status_panel: PanelContainer
var status_label: Label
var objective_label: Label
var message_label: Label
var context_label: Label
var inventory_panel: PanelContainer
var map_panel: PanelContainer
var daily_panel: PanelContainer
var crafting_panel: PanelContainer
var settings_panel: PanelContainer
var map_dirty := true
var message_timer := 0.0
var joystick: VirtualJoystick

func _ready() -> void:
    layer = 20
    _build_hud()

func _build_hud() -> void:
    status_panel = PanelContainer.new()
    status_panel.position = Vector2(16, 16)
    status_panel.size = Vector2(420, 138)
    add_child(status_panel)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 18)
    status_panel.add_child(status_label)

    var title := Label.new()
    title.text = "ALPHA CRUSH"
    title.position = Vector2(930, 18)
    title.add_theme_font_size_override("font_size", 26)
    add_child(title)

    objective_label = Label.new()
    objective_label.position = Vector2(460, 20)
    objective_label.size = Vector2(460, 70)
    objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_label.add_theme_font_size_override("font_size", 18)
    objective_label.text = "EXPLORE"
    add_child(objective_label)

    context_label = Label.new()
    context_label.position = Vector2(450, 555)
    context_label.size = Vector2(380, 50)
    context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    context_label.add_theme_font_size_override("font_size", 20)
    context_label.text = "E  INTERACT"
    add_child(context_label)

    message_label = Label.new()
    message_label.position = Vector2(130, 660)
    message_label.size = Vector2(1020, 40)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 21)
    add_child(message_label)

    _add_button("Inventory", Vector2(16, 168), "inventory")
    _add_button("Map", Vector2(16, 220), "map")
    _add_button("Daily", Vector2(16, 272), "daily")
    _add_button("Craft", Vector2(16, 324), "craft")
    _add_button("Hint", Vector2(16, 376), "hint")
    _add_button("Save", Vector2(16, 428), "save")
    _add_button("Settings", Vector2(16, 476), "settings")

    joystick = preload("res://ui/mobile/virtual_joystick.gd").new()
    joystick.position = Vector2(30, 520)
    joystick.size = Vector2(165, 165)
    add_child(joystick)
    joystick.input_changed.connect(_on_joystick)
    camera_drag = preload("res://ui/mobile/camera_drag.gd").new()
    camera_drag.position = Vector2(820, 500)
    camera_drag.size = Vector2(280, 170)
    add_child(camera_drag)

    _add_button("ACT", Vector2(1110, 530), "interact")
    _add_button("JUMP", Vector2(1110, 585), "jump")
    _add_button("RUN", Vector2(1110, 640), "sprint")
    _add_button("X", Vector2(1140, 16), "close")

    inventory_panel = _make_panel("INVENTORY", Vector2(470, 135), Vector2(350, 440))
    map_panel = _make_panel("MAP", Vector2(830, 135), Vector2(400, 440))
    daily_panel = _make_panel("DAILY", Vector2(830, 135), Vector2(400, 260))
    crafting_panel = _make_panel("WORKSHOP CRAFTING", Vector2(470, 135), Vector2(420, 440))
    settings_panel = _make_panel("SETTINGS, PRIVACY & NETWORK", Vector2(430, 65), Vector2(440, 590))
    var settings_box := settings_panel.get_node_or_null("VBoxContainer") as VBoxContainer
    if settings_box:
        var scroll := ScrollContainer.new()
        scroll.name = "SettingsScroll"
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        var rows := VBoxContainer.new()
        rows.name = "SettingsRows"
        rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(rows)
        settings_box.add_child(scroll)
    inventory_panel.visible = false
    map_panel.visible = false
    daily_panel.visible = false
    crafting_panel.visible = false
    settings_panel.visible = false
    camera_drag.setup(player)
    map_view = preload("res://ui/map/map_view.gd").new()
    map_view.position = Vector2(12, 58)
    map_view.size = Vector2(376, 350)
    map_panel.add_child(map_view)
    map_view.setup(map_manager, player)
    refresh_settings()
    apply_accessibility()

func _make_panel(title: String, pos: Vector2, size: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.position = pos
    panel.size = size
    add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)
    var label := Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", 22)
    box.add_child(label)
    var body := Label.new()
    body.name = "Body"
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(body)
    return panel

func _add_button(text_value: String, pos: Vector2, kind: String) -> void:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = Vector2(125, 44)
    button.add_theme_font_size_override("font_size", 16)
    button.pressed.connect(func(): _button_action(kind))
    add_child(button)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return
    if event.is_action_pressed("inventory"):
        _button_action("inventory")
    elif event.is_action_pressed("map"):
        _button_action("map")
    elif event.is_action_pressed("hint"):
        _button_action("hint")
    elif event.is_action_pressed("menu"):
        # ESC closes whatever is open, otherwise it opens the settings panel.
        var any_open := inventory_panel.visible or map_panel.visible or daily_panel.visible or crafting_panel.visible or settings_panel.visible
        _button_action("close" if any_open else "settings")
    else:
        return
    get_viewport().set_input_as_handled()

func _on_joystick(value: Vector2) -> void:
    if player and player.has_method("set_mobile_move"):
        player.set_mobile_move(value)

func _button_action(kind: String) -> void:
    match kind:
        "interact":
            if player: player.interact()
        "jump":
            if player and player.is_on_floor(): player.velocity.y = player.jump_velocity
        "sprint":
            if player: player.set_mobile_sprint(not player.mobile_sprint)
        "save":
            var root := get_parent()
            if root and root.has_method("_save"):
                root._save()
                show_message("Progress saved")
        "inventory":
            inventory_panel.visible = not inventory_panel.visible
            map_panel.visible = false
            daily_panel.visible = false
            crafting_panel.visible = false
            settings_panel.visible = false
            refresh_inventory()
        "map":
            map_panel.visible = not map_panel.visible
            inventory_panel.visible = false
            daily_panel.visible = false
            crafting_panel.visible = false
            settings_panel.visible = false
            refresh_map()
        "daily":
            daily_panel.visible = not daily_panel.visible
            inventory_panel.visible = false
            map_panel.visible = false
            crafting_panel.visible = false
            settings_panel.visible = false
            refresh_daily()
        "craft":
            open_crafting()
        "hint":
            if hints: hints.request_hint()
        "settings":
            settings_panel.visible = not settings_panel.visible
            inventory_panel.visible = false
            map_panel.visible = false
            daily_panel.visible = false
            crafting_panel.visible = false
            refresh_settings()
        "close":
            inventory_panel.visible = false
            map_panel.visible = false
            daily_panel.visible = false
            crafting_panel.visible = false
            settings_panel.visible = false

func open_crafting() -> void:
    inventory_panel.visible = false
    map_panel.visible = false
    daily_panel.visible = false
    crafting_panel.visible = true
    settings_panel.visible = false
    refresh_crafting()

func refresh_settings() -> void:
    if settings_panel == null or settings == null:
        return
    var box := settings_panel.get_node_or_null("VBoxContainer/SettingsScroll/SettingsRows") as VBoxContainer
    if box == null:
        return
    _clear_rows(box, "Setting_")
    var help := settings_panel.get_node_or_null("VBoxContainer/Body") as Label
    if help:
        help.text = "Choose comfortable controls and visual settings. Changes save with your progress."
    var quality_row := HBoxContainer.new()
    quality_row.name = "Setting_Quality"
    var quality_label := Label.new()
    quality_label.text = "Graphics quality"
    quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quality_row.add_child(quality_label)
    var quality_picker := OptionButton.new()
    var quality_values := ["low", "medium", "high", "ultra"]
    for quality_name in quality_values:
        quality_picker.add_item(quality_name.capitalize())
    var current_quality := str(settings.get_value("quality", "medium"))
    quality_picker.select(maxi(0, quality_values.find(current_quality)))
    quality_picker.item_selected.connect(func(index: int):
        settings.set_value("quality", quality_values[index])
    )
    quality_row.add_child(quality_picker)
    box.add_child(quality_row)
    _add_setting_toggle(box, "Music", "music", true)
    _add_setting_toggle(box, "Sound effects", "sfx", true)
    _add_setting_toggle(box, "Vibration", "vibration", true)
    _add_setting_toggle(box, "High contrast", "high_contrast", false)
    _add_setting_slider(box, "Text size", "text_scale", 0.8, 1.5, 0.1, 1.0)
    _add_setting_slider(box, "Camera sensitivity", "camera_sensitivity", 0.5, 2.0, 0.1, 1.0)
    var address_row := HBoxContainer.new()
    address_row.name = "Setting_NetworkAddress"
    var address_label := Label.new()
    address_label.text = "LAN host address"
    address_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    address_row.add_child(address_label)
    var address_input := LineEdit.new()
    address_input.name = "NetworkAddress"
    address_input.placeholder_text = "192.168.1.20"
    address_input.text = "127.0.0.1"
    address_input.custom_minimum_size = Vector2(150, 28)
    address_row.add_child(address_input)
    box.add_child(address_row)
    var network_row := HBoxContainer.new()
    network_row.name = "Setting_NetworkButtons"
    var host_button := Button.new()
    host_button.text = "Host"
    host_button.pressed.connect(func():
        if multiplayer_session and multiplayer_session.host():
            show_message("Session hosted on UDP 24560. Share your LAN address with friends.")
        else:
            show_message("Could not host a session.")
    )
    network_row.add_child(host_button)
    var join_button := Button.new()
    join_button.text = "Join"
    join_button.pressed.connect(func():
        if multiplayer_session and multiplayer_session.join(address_input.text.strip_edges()):
            show_message("Connecting to %s…" % address_input.text.strip_edges())
        else:
            show_message("Could not start a connection.")
    )
    network_row.add_child(join_button)
    var leave_button := Button.new()
    leave_button.text = "Leave"
    leave_button.pressed.connect(func():
        if multiplayer_session:
            multiplayer_session.leave()
        show_message("Left multiplayer session.")
    )
    network_row.add_child(leave_button)
    box.add_child(network_row)
    var consent_status := Label.new()
    consent_status.name = "Setting_ConsentStatus"
    if consent == null or not consent.consent_collected:
        consent_status.text = "Ad privacy: not chosen (personalization off)"
    else:
        consent_status.text = "Ad privacy: %s" % ("personalized" if consent.personalized_ads else "non-personalized")
    box.add_child(consent_status)
    var consent_row := HBoxContainer.new()
    consent_row.name = "Setting_ConsentButtons"
    var allow_ads := Button.new()
    allow_ads.text = "Allow personalized ads"
    allow_ads.pressed.connect(func():
        if consent:
            consent.set_consent(true)
            show_message("Personalized ads consent saved.")
            refresh_settings()
    )
    consent_row.add_child(allow_ads)
    var decline_ads := Button.new()
    decline_ads.text = "Non-personalized ads"
    decline_ads.pressed.connect(func():
        if consent:
            consent.set_consent(false)
            show_message("Non-personalized ads preference saved.")
            refresh_settings()
    )
    consent_row.add_child(decline_ads)
    box.add_child(consent_row)
    var store_title := Label.new()
    store_title.name = "Setting_StoreTitle"
    store_title.text = "STORE & REWARDED ADS"
    store_title.add_theme_font_size_override("font_size", 18)
    box.add_child(store_title)
    var store_row := HBoxContainer.new()
    store_row.name = "Setting_StoreButtons"
    var remove_ads_button := Button.new()
    remove_ads_button.text = "Remove ads"
    remove_ads_button.pressed.connect(func():
        if purchases:
            purchases.purchase("remove_ads")
    )
    store_row.add_child(remove_ads_button)
    var small_pack_button := Button.new()
    small_pack_button.text = "100 coins"
    small_pack_button.pressed.connect(func():
        if purchases:
            purchases.purchase("coin_pack_small")
    )
    store_row.add_child(small_pack_button)
    var large_pack_button := Button.new()
    large_pack_button.text = "550 coins"
    large_pack_button.pressed.connect(func():
        if purchases:
            purchases.purchase("coin_pack_large")
    )
    store_row.add_child(large_pack_button)
    var restore_button := Button.new()
    restore_button.text = "Restore"
    restore_button.pressed.connect(func():
        if purchases:
            var requested := purchases.restore()
            if requested:
                show_message("Purchase restore requested.")
    )
    store_row.add_child(restore_button)
    box.add_child(store_row)
    var rewarded_button := Button.new()
    rewarded_button.name = "Setting_RewardedAd"
    rewarded_button.text = "Watch ad for 50 coins"
    rewarded_button.pressed.connect(func():
        if ads:
            ads.show_rewarded("coins")
    )
    box.add_child(rewarded_button)
    apply_accessibility()

func _clear_rows(box: Container, prefix: String) -> void:
    # remove_child() first: queue_free() alone keeps the old node (and its name) alive until the
    # end of the frame, so a rebuilt row with the same name would be silently renamed and leak.
    for child in box.get_children():
        if String(child.name).begins_with(prefix):
            box.remove_child(child)
            child.queue_free()

func _add_setting_toggle(parent: VBoxContainer, title: String, key: String, fallback: bool) -> void:
    var row := HBoxContainer.new()
    row.name = "Setting_%s" % key
    var label := Label.new()
    label.text = title
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    var toggle := CheckButton.new()
    toggle.button_pressed = bool(settings.get_value(key, fallback))
    toggle.toggled.connect(func(value: bool): settings.set_value(key, value))
    row.add_child(toggle)
    parent.add_child(row)

func _add_setting_slider(parent: VBoxContainer, title: String, key: String, minimum: float, maximum: float, step: float, fallback: float) -> void:
    var row := HBoxContainer.new()
    row.name = "Setting_%s" % key
    var label := Label.new()
    label.text = title
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.custom_minimum_size = Vector2(130, 24)
    slider.value = float(settings.get_value(key, fallback))
    slider.value_changed.connect(func(value: float): settings.set_value(key, snappedf(value, step)))
    row.add_child(slider)
    parent.add_child(row)

func apply_accessibility() -> void:
    if settings == null:
        return
    var text_scale := clampf(float(settings.get_value("text_scale", 1.0)), 0.8, 1.5)
    var contrast := bool(settings.get_value("high_contrast", false))
    for node in find_children("*", "Label", true, false):
        var label := node as Label
        if not label.has_meta("alpha_base_font_size"):
            label.set_meta("alpha_base_font_size", label.get_theme_font_size("font_size"))
        var base_size := int(label.get_meta("alpha_base_font_size"))
        label.add_theme_font_size_override("font_size", maxi(12, int(round(base_size * text_scale))))
        label.add_theme_color_override("font_color", Color.WHITE if contrast else Color("#e8eef5"))
    for node in find_children("*", "Button", true, false):
        var button := node as Button
        button.add_theme_color_override("font_color", Color.WHITE if contrast else Color("#e8eef5"))
    for node in find_children("*", "PanelContainer", true, false):
        var panel := node as PanelContainer
        var style := StyleBoxFlat.new()
        style.bg_color = Color("#05080d") if contrast else Color("#172536", 0.94)
        style.border_color = Color.WHITE if contrast else Color("#607f99")
        style.set_border_width_all(2 if contrast else 1)
        style.set_corner_radius_all(8)
        panel.add_theme_stylebox_override("panel", style)

func refresh_crafting() -> void:
    if crafting_panel == null or crafting == null:
        return
    var box := crafting_panel.get_node_or_null("VBoxContainer") as VBoxContainer
    if box == null:
        return
    _clear_rows(box, "Recipe_")
    var recipe_ids: Array = crafting.recipes.keys()
    recipe_ids.sort()
    for recipe_id in recipe_ids:
        var id := str(recipe_id)
        var row := HBoxContainer.new()
        row.name = "Recipe_%s" % id
        var label := Label.new()
        label.text = crafting.recipe_summary(id)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.add_child(label)
        var craft_button := Button.new()
        craft_button.text = "CRAFT" if crafting.can_craft(id) else "LOCKED"
        craft_button.disabled = not crafting.can_craft(id)
        craft_button.pressed.connect(func():
            if crafting.craft(id):
                show_message("Crafted %s" % id.replace("_", " ").capitalize())
            else:
                show_message("Not enough materials or inventory space")
            refresh_crafting()
        )
        row.add_child(craft_button)
        box.add_child(row)

func set_objective(title: String, detail: String) -> void:
    objective_label.text = "%s\n%s" % [title, detail]

func set_context(text_value: String) -> void:
    if context_label:
        context_label.text = text_value

func show_message(text_value: String) -> void:
    if message_label:
        message_label.text = text_value
        message_timer = 5.0

func refresh_inventory() -> void:
    if inventory_panel == null or not is_instance_valid(inventory_panel):
        return
    var body = inventory_panel.get_node_or_null("VBoxContainer/Body")
    if body == null:
        body = inventory_panel.get_node_or_null("Body")
    if body == null:
        return
    var lines := ["STACKS  %d / %d" % [inventory.used_slots(), inventory.capacity]]
    var keys := inventory.items.keys()
    keys.sort()
    for id in keys:
        lines.append("%s  × %d" % [str(id).replace("_", " ").capitalize(), int(inventory.items[id])])
    body.text = "\n".join(lines)

func refresh_map() -> void:
    if map_panel == null:
        return
    if map_view:
        map_view.queue_redraw()
    map_dirty = false

func refresh_daily() -> void:
    if daily_panel == null:
        return
    var body = daily_panel.get_node_or_null("VBoxContainer/Body")
    if body == null:
        body = daily_panel.get_node_or_null("Body")
    if body == null:
        return
    var lines := []
    for objective in daily.objectives:
        lines.append("• %s  %d/%d" % [str(objective.get("title", "Objective")), int(objective.get("progress", 0)), int(objective.get("target", 1))])
    body.text = "\n".join(lines)

func set_map_dirty() -> void:
    map_dirty = true

func _item_total() -> int:
    var total := 0
    for value in inventory.items.values():
        total += int(value)
    return total

func _process(delta: float) -> void:
    if message_timer > 0.0:
        message_timer -= delta
        if message_timer <= 0.0 and message_label:
            message_label.text = ""
    if not status_label or not word_system or not inventory:
        return
    var coins := inventory.count("coins")
    var gems := inventory.count("gems")
    var level := progression.level if progression else 1
    var objective := word_system.progress_text()
    if objective.is_empty(): objective = "Explore"
    var name_value := str(profile.display_name) if profile else "Explorer"
    status_label.text = "%s\nWORD  %s\nCOINS  %d   GEMS  %d   LEVEL  %d" % [name_value, objective, coins, gems, level]
    if map_dirty and map_panel.visible:
        refresh_map()
    if daily_panel.visible:
        refresh_daily()
