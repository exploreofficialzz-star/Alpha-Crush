extends CanvasLayer
class_name MainMenu

## The front door: rank card, CAMPAIGN (26 operations, ALPHA to ZULU), QUICK BATTLE, ARMORY and SETTINGS.
## Sub-screens are plain Controls swapped inside one holder; the Android back button walks back to the home screen.
signal play_operation(index: int)
signal play_quick(config: Dictionary)
signal settings_requested
signal data_changed

const TILE_COLUMNS := 7

var progress: PlayerProgress
var settings: SettingsManager
var audio: AudioManager

var root: Control
var holder: Control
var _screen := "home"
var _selected_operation := 0
var _quick := {"mode": "crush", "arena": "farmstead", "difficulty": 1, "faction": "jackals"}
var _armory: ArmoryScreen
var _notice: Label

func _ready() -> void:
    layer = 30
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var background := ColorRect.new()
    background.color = KidUI.NAVY
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(background)
    var glow := TextureRect.new()
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    gradient.colors = PackedColorArray([Color(0.22, 0.32, 0.72, 0.55), Color(0.04, 0.07, 0.19, 0.0)])
    var gradient_texture := GradientTexture2D.new()
    gradient_texture.gradient = gradient
    gradient_texture.fill = GradientTexture2D.FILL_RADIAL
    gradient_texture.fill_from = Vector2(0.3, 0.35)
    gradient_texture.fill_to = Vector2(1.0, 0.35)
    gradient_texture.width = 256
    gradient_texture.height = 256
    glow.texture = gradient_texture
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(glow)
    holder = Control.new()
    holder.name = "Holder"
    holder.set_anchors_preset(Control.PRESET_FULL_RECT)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(holder)
    _notice = MenuKit.label("", 22)
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _notice.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _notice.offset_top = -86.0
    _notice.offset_bottom = -20.0
    _notice.offset_left = 60.0
    _notice.offset_right = -60.0
    _notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _notice.visible = false
    root.add_child(_notice)
    _selected_operation = progress.next_operation() if progress != null else 0
    show_home()

func _margin(child: Control) -> MarginContainer:
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    var m := KidUI.safe_margins(get_viewport())
    margin.add_theme_constant_override("margin_left", int(m.x) + 28)
    margin.add_theme_constant_override("margin_right", int(m.z) + 28)
    margin.add_theme_constant_override("margin_top", int(m.y) + 20)
    margin.add_theme_constant_override("margin_bottom", int(m.w) + 20)
    margin.add_child(child)
    return margin

func _sfx(sound: String) -> void:
    if audio != null:
        audio.play_sfx(sound)

func _begin_screen(name_value: String) -> void:
    _screen = name_value
    MenuKit.clear_children(holder)

## Android back / ESC. Returns true when the menu handled it (it never quits the app from here).
func handle_back() -> bool:
    if _screen != "home":
        _sfx("ui_back")
        show_home()
    return true

# ------------------------------------------------------------------------------------------------ home
func show_home() -> void:
    _begin_screen("home")
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 14)
    holder.add_child(_margin(page))
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 14)
    page.add_child(top)
    var hero_icon := "girl" if settings != null and bool(settings.get_value("avatar_female", false)) else "boy"
    top.add_child(KidUI.icon_rect(hero_icon, 84.0))
    var rank_box := VBoxContainer.new()
    top.add_child(rank_box)
    rank_box.add_child(MenuKit.label("RANK %d  %s" % [progress.rank, PlayerProgress.rank_title(progress.rank)], 26, KidUI.GOLD))
    var xp_bar := MenuKit.bar(KidUI.BLUE, 14.0, 300.0)
    xp_bar.value = progress.rank_fraction()
    rank_box.add_child(xp_bar)
    top.add_child(MenuKit.spacer())
    top.add_child(MenuKit.chip("coin", str(progress.coins)))
    top.add_child(MenuKit.chip("star_gold", str(progress.total_stars())))
    var gear := MenuKit.icon_button("gear", Color("#4a5a8a"), 64.0)
    gear.pressed.connect(_on_settings_pressed)
    top.add_child(gear)
    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 30)
    page.add_child(body)
    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_box.alignment = BoxContainer.ALIGNMENT_CENTER
    body.add_child(title_box)
    var title := MenuKit.label("ALPHA", 118, KidUI.GOLD)
    title_box.add_child(title)
    var title_two := MenuKit.label("CRUSH", 118, Color("#ff5a3c"))
    title_box.add_child(title_two)
    title_box.add_child(MenuKit.label("CRUSH THE OPPOSITION", 26, Color(0.75, 0.88, 1.0)))
    var buttons := VBoxContainer.new()
    buttons.add_theme_constant_override("separation", 14)
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.custom_minimum_size = Vector2(420, 0)
    body.add_child(buttons)
    var next_index := progress.next_operation()
    var campaign := MenuKit.button("CAMPAIGN  -  %s" % OperationCatalog.CALLSIGNS[next_index], Color("#ff5a3c"), Vector2(420, 92), 32)
    campaign.pressed.connect(_on_campaign_pressed)
    buttons.add_child(campaign)
    var quick := MenuKit.button("QUICK BATTLE", KidUI.BLUE, Vector2(420, 78), 30)
    quick.pressed.connect(show_quick)
    buttons.add_child(quick)
    var armory := MenuKit.button("ARMORY", KidUI.PURPLE, Vector2(420, 78), 30)
    armory.pressed.connect(show_armory)
    buttons.add_child(armory)
    var footer := MenuKit.label("KILLS %d    WINS %d    BEST COMBO %d" % [int(progress.stats.get("kills", 0)), int(progress.stats.get("wins", 0)), int(progress.stats.get("best_combo", 0))], 20, Color(0.75, 0.88, 1.0))
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page.add_child(footer)

func _on_settings_pressed() -> void:
    _sfx("ui_click")
    settings_requested.emit()

func _on_campaign_pressed() -> void:
    _sfx("ui_click")
    _selected_operation = progress.next_operation()
    show_operations()

# ------------------------------------------------------------------------------------------------ campaign map
func _back_button() -> Button:
    var back := MenuKit.icon_button("home", Color("#4a5a8a"), 64.0)
    back.pressed.connect(handle_back)
    return back

func show_operations() -> void:
    _begin_screen("operations")
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 12)
    holder.add_child(_margin(page))
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 14)
    page.add_child(top)
    top.add_child(_back_button())
    top.add_child(MenuKit.label("CAMPAIGN   ALPHA TO ZULU", 36, KidUI.GOLD))
    top.add_child(MenuKit.spacer())
    top.add_child(MenuKit.chip("star_gold", "%d / %d" % [progress.total_stars(), OperationCatalog.count() * 3]))
    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 22)
    page.add_child(body)
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = TILE_COLUMNS
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    scroll.add_child(grid)
    for i in OperationCatalog.count():
        grid.add_child(_operation_tile(i))
    var detail := MenuKit.card(Color(0.06, 0.12, 0.3, 0.92), 30)
    detail.custom_minimum_size = Vector2(380, 0)
    detail.name = "Detail"
    body.add_child(detail)
    _fill_operation_detail(detail)

func _operation_tile(index: int) -> Button:
    var unlocked := progress.is_operation_unlocked(index)
    var earned := progress.best_stars(index)
    var color := KidUI.PANEL_LIGHT
    if index == _selected_operation:
        color = Color("#ff5a3c")
    elif earned > 0:
        color = Color("#2f7a4e")
    var tile := MenuKit.button(char(65 + index), color if unlocked else Color(0.25, 0.28, 0.4), Vector2(104, 92), 40)
    tile.disabled = not unlocked
    if unlocked:
        var marks := ""
        for i in earned:
            marks += "*"
        tile.text = "%s\n%s" % [char(65 + index), marks]
    else:
        tile.text = "?"
    tile.pressed.connect(_on_operation_selected.bind(index))
    return tile

func _on_operation_selected(index: int) -> void:
    _sfx("ui_click")
    _selected_operation = index
    show_operations()

func _fill_operation_detail(panel: PanelContainer) -> void:
    var info := OperationCatalog.operation(_selected_operation)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    panel.add_child(column)
    column.add_child(MenuKit.label(str(info["title"]), 30, KidUI.GOLD))
    var mode := str(info["mode"])
    var mode_row := HBoxContainer.new()
    mode_row.add_theme_constant_override("separation", 10)
    mode_row.add_child(KidUI.icon_rect(str(OperationCatalog.MODE_ICONS.get(mode, "crush")), 44.0))
    mode_row.add_child(MenuKit.label(OperationCatalog.mode_name(mode), 24, Color(0.85, 0.93, 1.0)))
    column.add_child(mode_row)
    var blurb := MenuKit.label(str(OperationCatalog.MODE_BLURBS.get(mode, "")), 18, Color(0.75, 0.88, 1.0))
    blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(blurb)
    column.add_child(MenuKit.label("MAP  " + ArenaCatalog.arena_name(str(info["arena"])), 20))
    var factions: Array = info["factions"]
    var names: Array[String] = []
    for id in factions:
        names.append(EnemyCatalog.faction_name(str(id)))
    var enemy_label := MenuKit.label("ENEMY  " + " + ".join(names), 18)
    enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(enemy_label)
    column.add_child(MenuKit.label("THREAT  %d%%" % int(float(info["difficulty"]) * 100.0), 20, Color(1.0, 0.6, 0.45)))
    column.add_child(MenuKit.stars(progress.best_stars(_selected_operation), 34.0))
    var reward := HBoxContainer.new()
    reward.add_theme_constant_override("separation", 8)
    reward.add_child(KidUI.icon_rect("coin", 30.0))
    reward.add_child(MenuKit.label("+%d" % int(info["reward_coins"]), 22, KidUI.GOLD))
    column.add_child(reward)
    column.add_child(MenuKit.spacer(false))
    var play := MenuKit.button("PLAY", Color("#ff5a3c"), Vector2(0, 84), 38)
    play.disabled = not progress.is_operation_unlocked(_selected_operation)
    play.pressed.connect(_on_play_operation.bind(_selected_operation))
    column.add_child(play)

func _on_play_operation(index: int) -> void:
    _sfx("ui_click")
    play_operation.emit(index)

# ------------------------------------------------------------------------------------------------ quick battle
func show_quick() -> void:
    _begin_screen("quick")
    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 12)
    holder.add_child(_margin(page))
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 14)
    page.add_child(top)
    top.add_child(_back_button())
    top.add_child(MenuKit.label("QUICK BATTLE", 36, KidUI.GOLD))
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 12)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(body)
    body.add_child(MenuKit.label("MODE", 20, Color(0.75, 0.88, 1.0)))
    var mode_row := HBoxContainer.new()
    mode_row.add_theme_constant_override("separation", 10)
    body.add_child(mode_row)
    for mode in OperationCatalog.MODE_ORDER:
        mode_row.add_child(_choice(OperationCatalog.mode_name(mode), "mode", mode, Vector2(250, 64)))
    body.add_child(MenuKit.label("MAP", 20, Color(0.75, 0.88, 1.0)))
    var arena_grid := GridContainer.new()
    arena_grid.columns = 4
    arena_grid.add_theme_constant_override("h_separation", 10)
    arena_grid.add_theme_constant_override("v_separation", 8)
    body.add_child(arena_grid)
    for arena_id in ArenaCatalog.ORDER:
        arena_grid.add_child(_choice(ArenaCatalog.arena_name(arena_id), "arena", arena_id, Vector2(250, 56)))
    body.add_child(MenuKit.label("DIFFICULTY", 20, Color(0.75, 0.88, 1.0)))
    var level_row := HBoxContainer.new()
    level_row.add_theme_constant_override("separation", 10)
    body.add_child(level_row)
    var level_names: Array[String] = ["ROOKIE", "SOLDIER", "VETERAN", "LEGEND"]
    for i in level_names.size():
        level_row.add_child(_choice(level_names[i], "difficulty", i, Vector2(250, 56)))
    body.add_child(MenuKit.label("ENEMY SIDE", 20, Color(0.75, 0.88, 1.0)))
    var side_row := HBoxContainer.new()
    side_row.add_theme_constant_override("separation", 10)
    body.add_child(side_row)
    for faction_id in EnemyCatalog.FACTION_ORDER:
        side_row.add_child(_choice(EnemyCatalog.faction_name(faction_id), "faction", faction_id, Vector2(250, 56)))
    body.add_child(MenuKit.spacer(false))
    var start := MenuKit.button("START BATTLE", Color("#ff5a3c"), Vector2(0, 80), 36)
    start.pressed.connect(_on_quick_start)
    page.add_child(start)

func _choice(text: String, key: String, value: Variant, min_size: Vector2) -> Button:
    var chosen: bool = _quick[key] == value
    var made := MenuKit.button(text, Color("#ff5a3c") if chosen else KidUI.PANEL_LIGHT, min_size, 22)
    made.pressed.connect(_on_quick_choice.bind(key, value))
    return made

func _on_quick_choice(key: String, value: Variant) -> void:
    _sfx("ui_click")
    _quick[key] = value
    show_quick()

func _on_quick_start() -> void:
    _sfx("ui_click")
    play_quick.emit(OperationCatalog.quick_battle(str(_quick["mode"]), str(_quick["arena"]), int(_quick["difficulty"]), str(_quick["faction"])))

# ------------------------------------------------------------------------------------------------ armory
func show_armory() -> void:
    _begin_screen("armory")
    _armory = ArmoryScreen.new()
    _armory.progress = progress
    _armory.audio = audio
    _armory.back_requested.connect(handle_back)
    _armory.data_changed.connect(_on_armory_changed)
    holder.add_child(_margin(_armory))

func _on_armory_changed() -> void:
    data_changed.emit()

## A short message at the bottom of the screen that fades away by itself.
func show_notice(text: String) -> void:
    if _notice == null or text == "":
        return
    _notice.text = text
    _notice.modulate.a = 1.0
    _notice.visible = true
    var tween := create_tween()
    tween.tween_interval(3.0)
    tween.tween_property(_notice, "modulate:a", 0.0, 0.6)
    tween.tween_callback(_hide_notice)

func _hide_notice() -> void:
    if _notice != null:
        _notice.visible = false

## Called by main after a battle so the home screen shows fresh numbers.
func refresh() -> void:
    if _screen == "home":
        show_home()
    elif _screen == "operations":
        show_operations()
