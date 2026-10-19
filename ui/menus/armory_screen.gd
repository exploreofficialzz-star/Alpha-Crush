extends VBoxContainer
class_name ArmoryScreen

## Where coins become power: buy and upgrade guns, pick a fighting STYLE, a CRUSH move, three KILLSTREAKS and an outfit.
## Every entry shows the same four states: EQUIPPED / owned (tap to equip), BUY (price), POOR (not enough coins), LOCKED (rank).
signal back_requested
signal data_changed

var progress: PlayerProgress
var audio: AudioManager

var _tab := "guns"
var _list: VBoxContainer
var _coins_chip: PanelContainer
var _tab_row: HBoxContainer

func _ready() -> void:
    add_theme_constant_override("separation", 10)
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 14)
    add_child(top)
    var back := MenuKit.icon_button("home", Color("#4a5a8a"), 64.0)
    back.pressed.connect(func(): back_requested.emit())
    top.add_child(back)
    top.add_child(MenuKit.label("ARMORY", 36, KidUI.GOLD))
    top.add_child(MenuKit.spacer())
    _coins_chip = MenuKit.chip("coin", str(progress.coins))
    top.add_child(_coins_chip)
    _tab_row = HBoxContainer.new()
    _tab_row.add_theme_constant_override("separation", 8)
    add_child(_tab_row)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 10)
    scroll.add_child(_list)
    _rebuild()

func _sfx(sound: String) -> void:
    if audio != null:
        audio.play_sfx(sound)

func _rebuild() -> void:
    var value := _coins_chip.find_child("Value", true, false) as Label
    if value != null:
        value.text = str(progress.coins)
    MenuKit.clear_children(_tab_row)
    var tabs: Array[Array] = [["guns", "GUNS"], ["style", "STYLE"], ["crush", "CRUSH"], ["streaks", "STREAKS"], ["outfit", "OUTFIT"]]
    for entry in tabs:
        var id := str(entry[0])
        var tab := MenuKit.button(str(entry[1]), Color("#ff5a3c") if id == _tab else KidUI.PANEL_LIGHT, Vector2(170, 56), 22)
        tab.pressed.connect(_on_tab.bind(id))
        _tab_row.add_child(tab)
    MenuKit.clear_children(_list)
    if _tab == "guns":
        _build_guns()
    elif _tab == "style":
        _build_simple(PlayerProgress.CATEGORY_STYLES, LoadoutCatalog.STYLE_ORDER, LoadoutCatalog.STYLES, "style")
    elif _tab == "crush":
        _build_simple(PlayerProgress.CATEGORY_CRUSH, LoadoutCatalog.CRUSH_ORDER, LoadoutCatalog.CRUSH_MOVES, "crush")
    elif _tab == "streaks":
        _build_streaks()
    else:
        _build_outfits()

func _on_tab(id: String) -> void:
    _sfx("ui_click")
    _tab = id
    _rebuild()

func _changed() -> void:
    data_changed.emit()
    _rebuild()

# ------------------------------------------------------------------------------------------------ guns
func _stat_row(title: String, fraction: float, color: Color) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var name_label := MenuKit.label(title, 15, Color(0.75, 0.88, 1.0))
    name_label.custom_minimum_size = Vector2(76, 0)
    row.add_child(name_label)
    var meter := MenuKit.bar(color, 10.0, 150.0)
    meter.value = clampf(fraction, 0.0, 1.0)
    meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(meter)
    return row

func _build_guns() -> void:
    var best_dps := 1.0
    for id in WeaponCatalog.ORDER:
        best_dps = maxf(best_dps, WeaponCatalog.dps(id, WeaponCatalog.MAX_LEVEL))
    for id in WeaponCatalog.ORDER:
        var data := WeaponCatalog.get_weapon(id)
        var level := progress.weapon_level(id)
        var state := progress.offer_state(PlayerProgress.CATEGORY_WEAPONS, id)
        var card := MenuKit.card(Color(0.06, 0.12, 0.3, 0.92), 26)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 14)
        card.add_child(row)
        row.add_child(KidUI.icon_rect(WeaponCatalog.icon_name(id), 84.0))
        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        var equipped := ""
        if str(progress.loadout.get("primary", "")) == id:
            equipped = "   PRIMARY"
        elif str(progress.loadout.get("secondary", "")) == id:
            equipped = "   SECONDARY"
        info.add_child(MenuKit.label("%s   LV %d%s" % [WeaponCatalog.display_name(id), level, equipped], 26, KidUI.GOLD if equipped != "" else Color.WHITE))
        info.add_child(_stat_row("POWER", WeaponCatalog.dps(id, level) / best_dps, Color("#ff5a3c")))
        info.add_child(_stat_row("SPEED", float(data.get("rate", 1.0)) / 13.0, Color("#ffc83d")))
        info.add_child(_stat_row("RANGE", float(data.get("range", 40.0)) / 140.0, Color("#3e8cf0")))
        var actions := VBoxContainer.new()
        actions.add_theme_constant_override("separation", 6)
        row.add_child(actions)
        if state == "owned":
            var primary := MenuKit.button("EQUIP 1", KidUI.GREEN, Vector2(190, 50), 20)
            primary.pressed.connect(_on_equip_weapon.bind(0, id))
            actions.add_child(primary)
            var secondary := MenuKit.button("EQUIP 2", KidUI.BLUE, Vector2(190, 50), 20)
            secondary.pressed.connect(_on_equip_weapon.bind(1, id))
            actions.add_child(secondary)
            if level < WeaponCatalog.MAX_LEVEL:
                var upgrade := MenuKit.button("UPGRADE %d" % WeaponCatalog.upgrade_cost(id, level), KidUI.ORANGE, Vector2(190, 50), 20)
                upgrade.disabled = not progress.can_upgrade(id)
                upgrade.pressed.connect(_on_upgrade_weapon.bind(id))
                actions.add_child(upgrade)
            else:
                actions.add_child(MenuKit.label("MAX LEVEL", 20, KidUI.GOLD))
        else:
            actions.add_child(_offer_button(PlayerProgress.CATEGORY_WEAPONS, id, state))
        _list.add_child(card)

func _on_equip_weapon(slot: int, id: String) -> void:
    _sfx("ui_click")
    progress.equip_weapon(slot, id)
    _changed()

func _on_upgrade_weapon(id: String) -> void:
    if progress.upgrade_weapon(id):
        _sfx("unlock")
    _changed()

# ------------------------------------------------------------------------------------------------ shared offer button
func _offer_button(category: String, id: String, state: String) -> Button:
    var button: Button
    if state == "locked":
        button = MenuKit.button("RANK %d" % progress.required_rank(category, id), Color(0.3, 0.34, 0.46), Vector2(190, 56), 20)
        button.disabled = true
    elif state == "poor":
        button = MenuKit.button("%d COINS" % progress.price_of(category, id), Color(0.45, 0.3, 0.3), Vector2(190, 56), 20)
        button.disabled = true
    else:
        button = MenuKit.button("BUY %d" % progress.price_of(category, id), KidUI.GREEN, Vector2(190, 56), 22)
        button.pressed.connect(_on_buy.bind(category, id))
    return button

func _on_buy(category: String, id: String) -> void:
    if progress.buy(category, id):
        _sfx("unlock")
    _changed()

# ------------------------------------------------------------------------------------------------ styles and crush moves
func _build_simple(category: String, order: Array[String], catalog: Dictionary, loadout_key: String) -> void:
    for id in order:
        var data: Dictionary = catalog[id]
        var state := progress.offer_state(category, id)
        var equipped := str(progress.loadout.get(loadout_key, "")) == id
        var card := MenuKit.card(Color(0.06, 0.12, 0.3, 0.92), 26, KidUI.GOLD if equipped else Color(1, 1, 1, 0.55))
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 14)
        card.add_child(row)
        row.add_child(KidUI.icon_rect(str(data.get("icon", "star")), 84.0))
        var info := VBoxContainer.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info)
        info.add_child(MenuKit.label(str(data.get("name", id.to_upper())) + ("   EQUIPPED" if equipped else ""), 26, KidUI.GOLD if equipped else Color.WHITE))
        var blurb := MenuKit.label(str(data.get("blurb", "")), 17, Color(0.75, 0.88, 1.0))
        blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        info.add_child(blurb)
        if category == PlayerProgress.CATEGORY_STYLES:
            info.add_child(MenuKit.label(_style_summary(data), 16, Color(0.9, 0.95, 1.0)))
        if state == "owned":
            var equip := MenuKit.button("EQUIPPED" if equipped else "EQUIP", Color(0.3, 0.34, 0.46) if equipped else KidUI.GREEN, Vector2(190, 56), 22)
            equip.disabled = equipped
            equip.pressed.connect(_on_equip.bind(category, id))
            row.add_child(equip)
        else:
            row.add_child(_offer_button(category, id, state))
        _list.add_child(card)

func _style_summary(data: Dictionary) -> String:
    var parts: Array[String] = []
    var pairs: Array[Array] = [["melee_damage", "KUNG-FU"], ["gun_damage", "GUNS"], ["melee_speed", "SPEED"], ["armor", "ARMOUR"], ["health", "HEALTH"]]
    for pair in pairs:
        var value := float(data.get(str(pair[0]), 1.0))
        if str(pair[0]) == "armor":
            if value > 0.0:
                parts.append("+%d ARMOUR" % int(value))
        elif absf(value - 1.0) > 0.01:
            parts.append("%s %s%d%%" % [str(pair[1]), "+" if value > 1.0 else "-", int(round(absf(value - 1.0) * 100.0))])
    return "   ".join(parts)

func _on_equip(category: String, id: String) -> void:
    _sfx("ui_click")
    progress.equip(category, id)
    _changed()

# ------------------------------------------------------------------------------------------------ killstreaks
func _build_streaks() -> void:
    var hint := MenuKit.label("PICK WHAT EACH STREAK SLOT DOES. SLOT 1 UNLOCKS FIRST IN A BATTLE.", 18, Color(0.75, 0.88, 1.0))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _list.add_child(hint)
    var current: Array = progress.loadout.get("streaks", ["supply", "airstrike", "drone"])
    for slot in 3:
        var card := MenuKit.card(Color(0.06, 0.12, 0.3, 0.92), 26)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        card.add_child(row)
        row.add_child(MenuKit.label("SLOT %d" % (slot + 1), 24, KidUI.GOLD))
        for id in LoadoutCatalog.STREAK_ORDER:
            var data := LoadoutCatalog.streak_data(id)
            var state := progress.offer_state(PlayerProgress.CATEGORY_STREAKS, id)
            var chosen := str(current[slot]) == id
            var label := "%s (%d KILLS)" % [str(data.get("name", id)), int(data.get("kills", 3))]
            if state == "owned":
                var pick := MenuKit.button(label, KidUI.GREEN if chosen else KidUI.PANEL_LIGHT, Vector2(250, 64), 18)
                pick.icon = KidUI.icon(str(data.get("icon", "supply")))
                pick.expand_icon = true
                pick.pressed.connect(_on_streak_slot.bind(slot, id))
                row.add_child(pick)
            else:
                row.add_child(_offer_button(PlayerProgress.CATEGORY_STREAKS, id, state))
        _list.add_child(card)

func _on_streak_slot(slot: int, id: String) -> void:
    _sfx("ui_click")
    progress.set_streak(slot, id)
    _changed()

# ------------------------------------------------------------------------------------------------ outfits
func _build_outfits() -> void:
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 12)
    _list.add_child(grid)
    for id in LoadoutCatalog.OUTFIT_ORDER:
        var data := LoadoutCatalog.outfit_data(id)
        var state := progress.offer_state(PlayerProgress.CATEGORY_OUTFITS, id)
        var equipped := str(progress.loadout.get("outfit", "alpha")) == id
        var card := MenuKit.card(Color(0.06, 0.12, 0.3, 0.92), 26, KidUI.GOLD if equipped else Color(1, 1, 1, 0.55))
        card.custom_minimum_size = Vector2(360, 0)
        var column := VBoxContainer.new()
        column.add_theme_constant_override("separation", 6)
        card.add_child(column)
        var swatches := HBoxContainer.new()
        swatches.add_theme_constant_override("separation", 6)
        for key in ["shirt", "pants", "leather"]:
            var swatch := ColorRect.new()
            swatch.color = data.get(key, Color.WHITE)
            swatch.custom_minimum_size = Vector2(70, 46)
            swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
            swatches.add_child(swatch)
        column.add_child(swatches)
        column.add_child(MenuKit.label(str(data.get("name", id.to_upper())) + ("  EQUIPPED" if equipped else ""), 22, KidUI.GOLD if equipped else Color.WHITE))
        if state == "owned":
            var equip := MenuKit.button("EQUIPPED" if equipped else "WEAR", Color(0.3, 0.34, 0.46) if equipped else KidUI.GREEN, Vector2(0, 50), 20)
            equip.disabled = equipped
            equip.pressed.connect(_on_equip.bind(PlayerProgress.CATEGORY_OUTFITS, id))
            column.add_child(equip)
        else:
            column.add_child(_offer_button(PlayerProgress.CATEGORY_OUTFITS, id, state))
        grid.add_child(card)
