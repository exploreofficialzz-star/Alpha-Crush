extends PanelContainer
class_name SettingsPanel

## Two layers. The top layer is for the child: big picture switches for music, sounds, buzzing
## and the hero (boy / girl). Everything else (graphics, left-handed layout, multiplayer, ads
## privacy, store) sits behind the parental gate, because it can spend money or touch the network.
signal message(text: String)
signal close_requested
signal parent_gate_requested
signal replay_tutorial_requested
signal save_requested
signal layout_changed

var settings: SettingsManager
var consent: ConsentManager
var ads: AdService
var purchases: PurchaseService
var multiplayer_session: MultiplayerSession
var unlocked := false
var _content: VBoxContainer

func setup(local_settings: SettingsManager, local_consent: ConsentManager, local_ads: AdService, local_purchases: PurchaseService, local_session: MultiplayerSession) -> void:
    settings = local_settings
    consent = local_consent
    ads = local_ads
    purchases = local_purchases
    multiplayer_session = local_session
    visible = false
    add_theme_stylebox_override("panel", KidUI.panel_style(KidUI.PANEL, 40, Color(1, 1, 1, 0.85), 5))
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    add_child(column)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    column.add_child(header)
    header.add_child(KidUI.icon_rect("gear", 72.0))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    var close := _round_button("close", KidUI.RED, 84.0)
    close.pressed.connect(func(): close_requested.emit())
    header.add_child(close)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 16)
    scroll.add_child(_content)

func _round_button(icon_name: String, color: Color, side: float) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(side, side)
    button.focus_mode = Control.FOCUS_NONE
    var normal := KidUI.panel_style(color, int(side / 2.0), Color.WHITE, 4)
    normal.content_margin_left = 8.0
    normal.content_margin_right = 8.0
    normal.content_margin_top = 8.0
    normal.content_margin_bottom = 8.0
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("focus", normal)
    var pressed_style := normal.duplicate() as StyleBoxFlat
    pressed_style.bg_color = color.darkened(0.25)
    button.add_theme_stylebox_override("pressed", pressed_style)
    button.icon = KidUI.icon(icon_name)
    button.expand_icon = true
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return button

func lock_parent_area() -> void:
    unlocked = false

func unlock_parent_area() -> void:
    unlocked = true
    refresh()

func refresh() -> void:
    if settings == null or _content == null:
        return
    for child in _content.get_children():
        _content.remove_child(child)
        child.queue_free()
    _build_kid_layer()
    if unlocked:
        _build_parent_layer()
    else:
        var lock := _round_button("lock", Color("#5b6b9a"), 96.0)
        lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        lock.pressed.connect(func(): parent_gate_requested.emit())
        _content.add_child(lock)

func _switch(on_icon: String, off_icon: String, key: String, fallback: bool) -> Button:
    var state := bool(settings.get_value(key, fallback))
    var button := _round_button(on_icon if state else off_icon, KidUI.GREEN if state else Color("#6b7699"), 118.0)
    button.pressed.connect(func():
        var next := not bool(settings.get_value(key, fallback))
        settings.set_value(key, next)
        refresh()
    )
    return button

func _build_kid_layer() -> void:
    var switches := HBoxContainer.new()
    switches.alignment = BoxContainer.ALIGNMENT_CENTER
    switches.add_theme_constant_override("separation", 22)
    switches.add_child(_switch("music", "music_off", "music", true))
    switches.add_child(_switch("sound", "sound_off", "sfx", true))
    switches.add_child(_switch("vibrate", "vibrate_off", "vibration", true))
    _content.add_child(switches)
    var heroes := HBoxContainer.new()
    heroes.alignment = BoxContainer.ALIGNMENT_CENTER
    heroes.add_theme_constant_override("separation", 26)
    var is_female := bool(settings.get_value("avatar_female", false))
    for option in [{"icon": "boy", "female": false}, {"icon": "girl", "female": true}]:
        var chosen := is_female == bool(option["female"])
        var hero := Button.new()
        hero.custom_minimum_size = Vector2(138, 138)
        hero.focus_mode = Control.FOCUS_NONE
        var style := KidUI.panel_style(Color("#2a4aa8") if chosen else Color(1, 1, 1, 0.1), 34, KidUI.GOLD if chosen else Color(1, 1, 1, 0.35), 8 if chosen else 3)
        for state in ["normal", "hover", "pressed", "focus"]:
            hero.add_theme_stylebox_override(state, style)
        hero.icon = KidUI.icon(str(option["icon"]))
        hero.expand_icon = true
        hero.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var wants_female := bool(option["female"])
        hero.pressed.connect(func():
            settings.set_value("avatar_female", wants_female)
            refresh()
        )
        heroes.add_child(hero)
    _content.add_child(heroes)

func _text(value: String, size: int = 22) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return label

func _check_row(title: String, key: String, fallback: bool) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_child(_text(title))
    var toggle := CheckButton.new()
    toggle.button_pressed = bool(settings.get_value(key, fallback))
    toggle.custom_minimum_size = Vector2(90, 48)
    toggle.toggled.connect(func(value: bool):
        settings.set_value(key, value)
        if key == "left_handed":
            layout_changed.emit()
    )
    row.add_child(toggle)
    return row

func _slider_row(title: String, key: String, minimum: float, maximum: float, step: float, fallback: float) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_child(_text(title))
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.custom_minimum_size = Vector2(220, 40)
    slider.value = float(settings.get_value(key, fallback))
    slider.value_changed.connect(func(value: float): settings.set_value(key, snappedf(value, step)))
    row.add_child(slider)
    return row

func _section(title: String) -> Label:
    var label := _text(title, 20)
    label.add_theme_color_override("font_color", KidUI.GOLD)
    return label

func _text_button(title: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(0, 58)
    button.add_theme_font_size_override("font_size", 22)
    button.pressed.connect(action)
    return button

func _build_parent_layer() -> void:
    _content.add_child(HSeparator.new())
    _content.add_child(_section("GRAPHICS"))
    var quality_row := HBoxContainer.new()
    quality_row.alignment = BoxContainer.ALIGNMENT_CENTER
    quality_row.add_theme_constant_override("separation", 16)
    var current := str(settings.get_value("quality", "medium"))
    for entry in [{"level": "low", "icon": "bars1"}, {"level": "medium", "icon": "bars2"}, {"level": "high", "icon": "bars3"}]:
        var level := str(entry["level"])
        var selected := current == level or (level == "low" and current == "lowest") or (level == "high" and current == "ultra")
        var pick := _round_button(str(entry["icon"]), KidUI.GREEN if selected else Color("#6b7699"), 92.0)
        pick.pressed.connect(func():
            settings.set_value("quality", level)
            settings.set_value("auto_quality", false)
            refresh()
        )
        quality_row.add_child(pick)
    _content.add_child(quality_row)
    _content.add_child(_check_row("Automatic graphics (lowers detail if the phone struggles)", "auto_quality", true))
    _content.add_child(_section("PLAY"))
    _content.add_child(_check_row("Left-handed layout (move stick on the left)", "left_handed", false))
    _content.add_child(_check_row("Helpful arrows", "guide_arrows", true))
    _content.add_child(_check_row("High contrast", "high_contrast", false))
    _content.add_child(_slider_row("Text size", "text_scale", 0.8, 1.5, 0.1, 1.0))
    _content.add_child(_slider_row("Camera sensitivity", "camera_sensitivity", 0.5, 2.0, 0.1, 1.0))
    _content.add_child(_text_button("Show the how-to-play hand again", func(): replay_tutorial_requested.emit()))
    _content.add_child(_text_button("Save now", func(): save_requested.emit()))
    _content.add_child(_section("PRIVACY & ADS"))
    if GameConfig.CHILD_DIRECTED:
        _content.add_child(_text("This game is made for children. Ads, if any, are never personalized."))
    else:
        var status := "not chosen" if consent == null or not consent.consent_collected else ("personalized" if consent.personalized_ads else "non-personalized")
        _content.add_child(_text("Ad privacy: %s" % status))
        _content.add_child(_text_button("Allow personalized ads", func():
            if consent:
                consent.set_consent(true)
                message.emit("Personalized ads consent saved.")
                refresh()
        ))
    _content.add_child(_text_button("Use non-personalized ads", func():
        if consent:
            consent.set_consent(false)
            message.emit("Non-personalized ads saved.")
            refresh()
    ))
    _content.add_child(_section("STORE"))
    _content.add_child(_text_button("Remove ads", func():
        if purchases:
            purchases.purchase("remove_ads")
    ))
    _content.add_child(_text_button("100 coins", func():
        if purchases:
            purchases.purchase("coin_pack_small")
    ))
    _content.add_child(_text_button("550 coins", func():
        if purchases:
            purchases.purchase("coin_pack_large")
    ))
    _content.add_child(_text_button("Restore purchases", func():
        if purchases and purchases.restore():
            message.emit("Purchase restore requested.")
    ))
    _content.add_child(_text_button("Watch an ad for 50 coins", func():
        if ads:
            ads.show_rewarded("coins")
    ))
    _content.add_child(_section("PLAY WITH FRIENDS ON THE SAME WI-FI"))
    var address := LineEdit.new()
    address.placeholder_text = "192.168.1.20"
    address.text = "127.0.0.1"
    address.custom_minimum_size = Vector2(0, 52)
    _content.add_child(address)
    var network_row := HBoxContainer.new()
    network_row.add_theme_constant_override("separation", 10)
    network_row.add_child(_text_button("Host", func():
        if multiplayer_session and multiplayer_session.host():
            message.emit("Hosting on UDP 24560. Friends join your Wi-Fi address.")
        else:
            message.emit("Could not host a session.")
    ))
    network_row.add_child(_text_button("Join", func():
        if multiplayer_session and multiplayer_session.join(address.text.strip_edges()):
            message.emit("Connecting to %s…" % address.text.strip_edges())
        else:
            message.emit("Could not start a connection.")
    ))
    network_row.add_child(_text_button("Leave", func():
        if multiplayer_session:
            multiplayer_session.leave()
        message.emit("Left multiplayer session.")
    ))
    for child in network_row.get_children():
        (child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_child(network_row)
