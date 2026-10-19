extends CanvasLayer
class_name BattleHUD

## Thumb-first combat HUD.
##   right thumb : floating MOVE stick (zone = right ~46% of the screen, lower 70%)
##   left thumb  : big ATTACK button (Smart Stance: kung-fu up close, gun at range) + DODGE, JUMP, CRUSH, GRENADE, RELOAD, SWAP
##   anywhere else: swipe to aim / look around
##   top         : radar, health + armour, lives, objective, boss bar, killstreak buttons, weapon + ammo, pause
## All touches go through TouchRouter, so holding the stick never stops a button from working.
signal quit_requested

const EDGE := 18.0
const FEED_LINES := 4
const FEED_SECONDS := 4.5
const ANNOUNCE_SECONDS := 1.0

var player: PlayerFighter
var director: CombatDirector
var match_director: MatchDirector
var settings: SettingsManager
var audio: AudioManager
var fx: CombatFX
var quality: QualityManager
var consent: ConsentManager
var ads: AdService
var purchases: PurchaseService
var coach_enabled := false

var root: Control
var router: TouchRouter
var camera_drag: CameraDrag
var joystick: AlphaCrushVirtualJoystick
var buttons: Dictionary = {}
var streak_buttons: Array[KidTouchButton] = []
var pause_button: KidTouchButton
var radar: RadarView
var crosshair: CrosshairView
var damage_arrows: DamageArrows
var lock_marker: LockMarker
var crush_ring: CrushRing
var settings_panel: SettingsPanel
var parent_gate: ParentGate
var pause_panel: PanelContainer
var backdrop: ColorRect

var _health_bar: ProgressBar
var _health_fill: StyleBoxFlat
var _armor_bar: ProgressBar
var _health_label: Label
var _lives_box: HBoxContainer
var _objective_panel: PanelContainer
var _objective_title: Label
var _objective_count: Label
var _objective_bar: ProgressBar
var _boss_panel: PanelContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _weapon_panel: PanelContainer
var _weapon_icon: TextureRect
var _weapon_name: Label
var _ammo_label: Label
var _reload_bar: ProgressBar
var _combo_panel: PanelContainer
var _combo_rank: Label
var _combo_count: Label
var _combo_bar: ProgressBar
var _coins_label: Label
var _feed: VBoxContainer
var _announce: Label
var _countdown: Label
var _vignette: TextureRect
var _toast: Label
var _grenade_label: Label
var _streak_labels: Array[Label] = []
var _coach_bubble: PanelContainer
var _coach_label: Label
var _coach_icon: TextureRect
var _announce_queue: Array[Dictionary] = []
var _announce_left := 0.0
var _toast_left := 0.0
var _last_rank := ""
var _last_crush_ready := false
var _coach_step := -1
var _coach_timer := 0.0
var _look_pixels := 0.0
var _boss: Node3D = null
var _zones_cached := false

func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    InputActions.ensure()
    root = Control.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_overlays()
    _build_controls()
    _build_status()
    _build_panels()
    _wire()
    get_viewport().size_changed.connect(_layout)
    _layout()
    _refresh_all()
    if coach_enabled:
        _start_coach.call_deferred()

# ------------------------------------------------------------------------------------------------ building
func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
    var label := KidUI.number_label(size, color)
    label.text = text
    return label

func _panel(fill: Color, radius: int = 22) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", KidUI.panel_style(fill, radius, Color(1, 1, 1, 0.5), 2))
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return panel

func _bar(fill: Color, height: float, width: float) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.value = 1.0
    bar.custom_minimum_size = Vector2(width, height)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var back := StyleBoxFlat.new()
    back.bg_color = Color(0.03, 0.07, 0.2, 0.75)
    back.set_corner_radius_all(int(height * 0.5))
    var front := StyleBoxFlat.new()
    front.bg_color = fill
    front.set_corner_radius_all(int(height * 0.5))
    bar.add_theme_stylebox_override("background", back)
    bar.add_theme_stylebox_override("fill", front)
    return bar

func _make_button(icon_name: String, color: Color, radius: float, on_release: bool) -> KidTouchButton:
    var button := KidTouchButton.new()
    button.setup(icon_name, color, radius)
    button.trigger_on_release = on_release
    root.add_child(button)
    return button

func _build_overlays() -> void:
    _vignette = TextureRect.new()
    _vignette.name = "Vignette"
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    gradient.colors = PackedColorArray([Color(0.9, 0.05, 0.05, 0.0), Color(0.9, 0.05, 0.05, 0.0), Color(0.9, 0.05, 0.05, 0.75)])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    texture.width = 256
    texture.height = 256
    _vignette.texture = texture
    _vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
    _vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _vignette.stretch_mode = TextureRect.STRETCH_SCALE
    _vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _vignette.modulate.a = 0.0
    root.add_child(_vignette)
    damage_arrows = DamageArrows.new()
    damage_arrows.name = "DamageArrows"
    damage_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(damage_arrows)
    crosshair = CrosshairView.new()
    crosshair.name = "Crosshair"
    crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(crosshair)
    lock_marker = LockMarker.new()
    lock_marker.name = "LockMarker"
    lock_marker.visible = false
    root.add_child(lock_marker)

func _build_controls() -> void:
    router = TouchRouter.new()
    router.name = "TouchRouter"
    add_child(router)
    camera_drag = CameraDrag.new()
    camera_drag.name = "LookZone"
    root.add_child(camera_drag)
    camera_drag.setup(player)
    camera_drag.dragged.connect(_on_look_drag)
    joystick = AlphaCrushVirtualJoystick.new()
    joystick.name = "MoveStick"
    root.add_child(joystick)
    joystick.input_changed.connect(_on_joystick)
    var specs := {
        "attack": ["attack", Color("#ff5a3c")],
        "dodge": ["dodge", KidUI.BLUE],
        "jump": ["jump", KidUI.PURPLE],
        "crush": ["crush", Color("#ff9a1c")],
        "grenade": ["grenade", Color("#3f8f4a")],
        "reload": ["reload", Color("#4a5a8a")],
        "swap": ["swap", Color("#4a5a8a")]
    }
    var placed := HudLayout.buttons(Vector2(1280, 720), Vector4.ZERO, false)
    for id in specs.keys():
        var spec: Array = specs[id]
        var button := _make_button(str(spec[0]), spec[1], float(placed[id]["radius"]), false)
        button.name = str(id).capitalize() + "Button"
        buttons[id] = button
    crush_ring = CrushRing.new()
    crush_ring.name = "CrushRing"
    crush_ring.inner_radius = float(placed["crush"]["radius"])
    root.add_child(crush_ring)
    root.move_child(crush_ring, buttons["crush"].get_index())
    buttons["attack"].pressed.connect(_on_attack_down)
    buttons["attack"].released.connect(_on_attack_up)
    buttons["dodge"].pressed.connect(_on_dodge)
    buttons["jump"].pressed.connect(_on_jump)
    buttons["crush"].pressed.connect(_on_crush)
    buttons["grenade"].pressed.connect(_on_grenade)
    buttons["reload"].pressed.connect(_on_reload)
    buttons["swap"].pressed.connect(_on_swap)
    _grenade_label = _label("x2", 22)
    _grenade_label.size = Vector2(50, 28)
    buttons["grenade"].add_child(_grenade_label)
    for slot in 3:
        var streak := _make_button("supply", Color("#2bb7c9"), HudLayout.STREAK_RADIUS, false)
        streak.name = "Streak%d" % (slot + 1)
        streak.dimmed = true
        streak.pressed.connect(_on_streak.bind(slot))
        streak_buttons.append(streak)
        var caption := _label("0/3", 18)
        caption.size = Vector2(70, 24)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        streak.add_child(caption)
        _streak_labels.append(caption)
    pause_button = _make_button("pause", Color("#243a78"), 36.0, true)
    pause_button.name = "PauseButton"
    pause_button.pressed.connect(open_pause)
    var order: Array[TouchTarget] = []
    for id in ["attack", "crush", "dodge", "jump", "grenade", "reload", "swap"]:
        order.append(buttons[id])
    for streak in streak_buttons:
        order.append(streak)
    order.append(pause_button)
    order.append(joystick)
    order.append(camera_drag)
    router.targets.assign(order)

func _build_status() -> void:
    radar = RadarView.new()
    radar.name = "Radar"
    radar.size = Vector2(124, 124)
    radar.player = player
    radar.director = director
    root.add_child(radar)
    _health_label = _label("100", 24)
    root.add_child(_health_label)
    _health_bar = _bar(Color("#3ec46d"), 22.0, 250.0)
    _health_fill = _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
    root.add_child(_health_bar)
    _armor_bar = _bar(Color("#4aa8ff"), 12.0, 250.0)
    root.add_child(_armor_bar)
    _lives_box = HBoxContainer.new()
    _lives_box.add_theme_constant_override("separation", 6)
    _lives_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_lives_box)
    _objective_panel = _panel(Color(0.04, 0.09, 0.24, 0.78))
    var objective_column := VBoxContainer.new()
    objective_column.add_theme_constant_override("separation", 2)
    objective_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _objective_panel.add_child(objective_column)
    _objective_title = _label("GET READY", 17, Color(0.75, 0.88, 1.0))
    _objective_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_column.add_child(_objective_title)
    _objective_count = _label("", 30, KidUI.GOLD)
    _objective_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_column.add_child(_objective_count)
    _objective_bar = _bar(KidUI.GOLD, 8.0, 320.0)
    objective_column.add_child(_objective_bar)
    root.add_child(_objective_panel)
    _boss_panel = _panel(Color(0.2, 0.03, 0.05, 0.85))
    var boss_column := VBoxContainer.new()
    boss_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _boss_panel.add_child(boss_column)
    _boss_name = _label("COMMANDER", 18, Color(1.0, 0.85, 0.4))
    _boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_column.add_child(_boss_name)
    _boss_bar = _bar(Color("#e84640"), 16.0, 400.0)
    boss_column.add_child(_boss_bar)
    _boss_panel.visible = false
    root.add_child(_boss_panel)
    _weapon_panel = _panel(Color(0.04, 0.09, 0.24, 0.78))
    var weapon_row := HBoxContainer.new()
    weapon_row.add_theme_constant_override("separation", 10)
    weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weapon_panel.add_child(weapon_row)
    _weapon_icon = KidUI.icon_rect("wpn_pistol", 60.0)
    weapon_row.add_child(_weapon_icon)
    var weapon_column := VBoxContainer.new()
    weapon_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weapon_row.add_child(weapon_column)
    _weapon_name = _label("VIPER", 16, Color(0.75, 0.88, 1.0))
    weapon_column.add_child(_weapon_name)
    _ammo_label = _label("12 / 96", 30)
    weapon_column.add_child(_ammo_label)
    _reload_bar = _bar(KidUI.ORANGE, 6.0, 120.0)
    _reload_bar.visible = false
    weapon_column.add_child(_reload_bar)
    root.add_child(_weapon_panel)
    _combo_panel = _panel(Color(0.2, 0.08, 0.02, 0.78), 18)
    var combo_row := HBoxContainer.new()
    combo_row.add_theme_constant_override("separation", 8)
    combo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _combo_panel.add_child(combo_row)
    _combo_rank = _label("D", 44, KidUI.GOLD)
    combo_row.add_child(_combo_rank)
    var combo_column := VBoxContainer.new()
    combo_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    combo_row.add_child(combo_column)
    _combo_count = _label("x0 COMBO", 17)
    combo_column.add_child(_combo_count)
    _combo_bar = _bar(KidUI.ORANGE, 8.0, 110.0)
    combo_column.add_child(_combo_bar)
    _combo_panel.visible = false
    root.add_child(_combo_panel)
    _coins_label = _label("0", 24, KidUI.GOLD)
    root.add_child(_coins_label)
    _feed = VBoxContainer.new()
    _feed.add_theme_constant_override("separation", 2)
    _feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_feed)
    _announce = _label("", 58, KidUI.GOLD)
    _announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _announce.visible = false
    root.add_child(_announce)
    _countdown = _label("", 170, Color.WHITE)
    _countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _countdown.visible = false
    root.add_child(_countdown)
    _toast = _label("", 22)
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.visible = false
    root.add_child(_toast)
    _coach_bubble = _panel(Color(0.98, 0.96, 0.85, 0.96), 24)
    var coach_row := HBoxContainer.new()
    coach_row.add_theme_constant_override("separation", 10)
    coach_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _coach_bubble.add_child(coach_row)
    _coach_icon = KidUI.icon_rect("hand", 54.0)
    coach_row.add_child(_coach_icon)
    _coach_label = Label.new()
    _coach_label.add_theme_font_size_override("font_size", 26)
    _coach_label.add_theme_color_override("font_color", KidUI.INK)
    _coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    coach_row.add_child(_coach_label)
    _coach_bubble.visible = false
    root.add_child(_coach_bubble)

func _build_panels() -> void:
    backdrop = ColorRect.new()
    backdrop.name = "Backdrop"
    backdrop.color = Color(0.02, 0.04, 0.12, 0.72)
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    backdrop.visible = false
    root.add_child(backdrop)
    pause_panel = PanelContainer.new()
    pause_panel.name = "PausePanel"
    pause_panel.visible = false
    pause_panel.add_theme_stylebox_override("panel", KidUI.panel_style(KidUI.PANEL, 36, Color(1, 1, 1, 0.8), 5))
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 16)
    pause_panel.add_child(column)
    var title := _label("PAUSED", 46, KidUI.GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    column.add_child(_menu_button("RESUME", KidUI.GREEN, close_pause))
    column.add_child(_menu_button("SETTINGS", KidUI.BLUE, _open_settings))
    column.add_child(_menu_button("QUIT TO MENU", KidUI.RED, _on_quit))
    root.add_child(pause_panel)
    settings_panel = SettingsPanel.new()
    settings_panel.name = "SettingsPanel"
    root.add_child(settings_panel)
    settings_panel.setup(settings, consent, ads, purchases)
    settings_panel.close_requested.connect(_close_settings)
    settings_panel.message.connect(show_toast)
    settings_panel.layout_changed.connect(_layout)
    settings_panel.parent_gate_requested.connect(_on_gate_requested)
    settings_panel.replay_tutorial_requested.connect(_on_replay_tutorial)
    settings_panel.save_requested.connect(_on_save_requested)
    parent_gate = ParentGate.new()
    parent_gate.name = "ParentGate"
    root.add_child(parent_gate)
    parent_gate.passed.connect(_on_gate_passed)
    parent_gate.dismissed.connect(_on_gate_dismissed)

func _menu_button(text: String, color: Color, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(380, 76)
    button.add_theme_font_size_override("font_size", 30)
    var normal := KidUI.panel_style(color, 30, Color.WHITE, 4)
    var pressed := KidUI.panel_style(color.darkened(0.25), 30, Color.WHITE, 4)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("focus", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.pressed.connect(action)
    return button

# ------------------------------------------------------------------------------------------------ wiring
func _wire() -> void:
    if player != null:
        player.health_changed.connect(_on_health)
        player.armor_changed.connect(_on_armor)
        player.grenades_changed.connect(_on_grenades)
        player.hit_confirmed.connect(_on_hit_confirmed)
        player.announce.connect(_on_player_announce)
        player.damage_from.connect(_on_damage_from)
        player.streak_progress.connect(_on_streak_progress)
        player.streak_ready.connect(_on_streak_ready)
        player.downed.connect(_on_player_downed)
        player.respawned.connect(_on_player_respawned)
        player.crush_meter.became_ready.connect(_on_crush_ready)
        if player.weapon != null:
            player.weapon.ammo_changed.connect(_on_ammo)
            player.weapon.weapon_changed.connect(_on_weapon_changed)
            player.weapon.reload_started.connect(_on_reload_started)
            player.weapon.reload_finished.connect(_on_reload_finished)
    if match_director != null:
        match_director.objective_changed.connect(_on_objective)
        match_director.announcement.connect(_on_match_announcement)
        match_director.kill_feed.connect(_on_kill_feed)
        match_director.boss_spawned.connect(_on_boss_spawned)
        match_director.lives_changed.connect(_on_lives)
        match_director.countdown_changed.connect(_on_countdown)
        match_director.zones_changed.connect(_on_zones_changed)
        match_director.match_started.connect(_on_match_started)
        match_director.match_ended.connect(_on_match_ended)
        match_director.wave_started.connect(_on_wave_started)
    if settings != null:
        settings.changed.connect(_on_settings_changed)

func _refresh_all() -> void:
    if player == null:
        return
    _on_health(player.health, player.max_health)
    _on_armor(player.armor, player.max_armor)
    _on_grenades(player.grenades)
    if player.weapon != null:
        _on_weapon_changed(player.weapon.current_id())
        _on_ammo(player.weapon.mag_ammo(), player.weapon.reserve_ammo())
    for slot in 3:
        _update_streak_slot(slot)
    if match_director != null:
        _on_lives(match_director.lives)
    _on_settings_changed()

# ------------------------------------------------------------------------------------------------ layout
func _place(button: KidTouchButton, center: Vector2) -> void:
    button.position = center - button.size * 0.5

func _layout() -> void:
    if root == null:
        return
    var size := get_viewport().get_visible_rect().size
    var margins := KidUI.safe_margins(get_viewport())
    var left_handed := settings != null and bool(settings.get_value("left_handed", false))
    camera_drag.position = Vector2.ZERO
    camera_drag.size = size
    var zone := HudLayout.stick_zone(size, margins, left_handed)
    joystick.mirrored = left_handed
    joystick.position = zone.position
    joystick.size = zone.size
    joystick.queue_redraw()
    var placed := HudLayout.buttons(size, margins, left_handed)
    for id in placed.keys():
        _place(buttons[id], placed[id]["center"])
    var crush_center: Vector2 = placed["crush"]["center"]
    crush_ring.size = Vector2.ONE * (crush_ring.inner_radius + 30.0) * 2.0
    crush_ring.position = crush_center - crush_ring.size * 0.5
    _grenade_label.position = Vector2(buttons["grenade"].size.x * 0.5 + 20.0, buttons["grenade"].size.y * 0.5 + 14.0)
    var streak_spots := HudLayout.streak_centers(size, margins)
    for i in streak_buttons.size():
        _place(streak_buttons[i], streak_spots[i])
        _streak_labels[i].position = Vector2(streak_buttons[i].size.x * 0.5 - 35.0, streak_buttons[i].size.y - 6.0)
    _place(pause_button, HudLayout.pause_center(size, margins))
    var left := margins.x + EDGE
    var top := margins.y + 12.0
    radar.position = Vector2(left, top)
    _health_bar.position = Vector2(left + 44.0, top + 134.0)
    _health_label.position = Vector2(left + 44.0 + 8.0, top + 128.0)
    _health_label.size = Vector2(120, 34)
    _armor_bar.position = Vector2(left + 44.0, top + 162.0)
    _lives_box.position = Vector2(left, top + 180.0)
    _combo_panel.position = Vector2(left, top + 214.0)
    _objective_panel.custom_minimum_size = Vector2(360, 82)
    _objective_panel.size = Vector2(360, 82)
    _objective_panel.position = Vector2((size.x - 360.0) * 0.5, top - 4.0)
    _boss_panel.custom_minimum_size = Vector2(420, 58)
    _boss_panel.size = Vector2(420, 58)
    _boss_panel.position = Vector2((size.x - 420.0) * 0.5, top + 82.0)
    var right := size.x - margins.z - EDGE
    _weapon_panel.position = Vector2(right - 250.0, top + 100.0)
    _weapon_panel.custom_minimum_size = Vector2(250, 86)
    _weapon_panel.size = Vector2(250, 86)
    _coins_label.position = Vector2(right - 220.0, top + 22.0)
    _coins_label.size = Vector2(120, 34)
    _coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _feed.position = Vector2(right - 300.0, top + 196.0)
    _feed.size = Vector2(300, 100)
    _announce.size = Vector2(size.x, 76)
    _announce.position = Vector2(0.0, size.y * 0.24)
    _countdown.size = Vector2(size.x, 200)
    _countdown.position = Vector2(0.0, size.y * 0.22)
    _toast.size = Vector2(size.x, 34)
    _toast.position = Vector2(0.0, size.y - 120.0)
    var panel_size := Vector2(minf(size.x - (margins.x + margins.z) - 2.0 * EDGE - 40.0, 940.0), minf(size.y - margins.y - margins.w - 40.0, 610.0))
    settings_panel.custom_minimum_size = panel_size
    settings_panel.size = panel_size
    settings_panel.position = (size - panel_size) * 0.5
    pause_panel.reset_size()
    pause_panel.position = (size - pause_panel.size) * 0.5

# ------------------------------------------------------------------------------------------------ touch callbacks
func _on_joystick(value: Vector2) -> void:
    if player != null:
        player.set_mobile_move(value)

func _on_look_drag(relative: Vector2) -> void:
    _look_pixels += relative.length()

func _on_attack_down() -> void:
    if player != null:
        player.set_attack_held(true)

func _on_attack_up() -> void:
    if player != null:
        player.set_attack_held(false)

func _on_dodge() -> void:
    if player != null:
        player.request_dodge()
    if _coach_step == 3:
        _advance_coach()

func _on_jump() -> void:
    if player != null:
        player.request_jump()

func _on_crush() -> void:
    if player != null:
        player.request_crush()

func _on_grenade() -> void:
    if player != null:
        player.request_grenade()

func _on_reload() -> void:
    if player != null:
        player.request_reload()

func _on_swap() -> void:
    if player != null:
        player.request_swap()

func _on_streak(slot: int) -> void:
    if player != null:
        player.request_streak(slot)

# ------------------------------------------------------------------------------------------------ game callbacks
func _on_health(current: float, maximum: float) -> void:
    var fraction := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
    _health_bar.value = fraction
    _health_label.text = str(int(ceil(current)))
    if _health_fill != null:
        _health_fill.bg_color = Color("#3ec46d") if fraction > 0.5 else (Color("#ffb020") if fraction > 0.25 else Color("#e84640"))

func _on_armor(current: float, maximum: float) -> void:
    _armor_bar.value = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
    _armor_bar.visible = maximum > 0.0

func _on_grenades(count: int) -> void:
    _grenade_label.text = "x%d" % count
    if buttons.has("grenade"):
        buttons["grenade"].dimmed = count <= 0

func _on_ammo(in_mag: int, reserve: int) -> void:
    _ammo_label.text = "%d / %d" % [in_mag, reserve]
    _ammo_label.add_theme_color_override("font_color", KidUI.RED if in_mag <= 3 else Color.WHITE)

func _on_weapon_changed(weapon_id: String) -> void:
    _weapon_icon.texture = KidUI.icon(WeaponCatalog.icon_name(weapon_id))
    _weapon_name.text = WeaponCatalog.display_name(weapon_id)
    if buttons.has("swap") and player != null and player.weapon != null:
        buttons["swap"].dimmed = not player.weapon.has_secondary()

func _on_reload_started(_weapon_id: String, _seconds: float) -> void:
    _reload_bar.visible = true
    _reload_bar.value = 0.0

func _on_reload_finished(_weapon_id: String) -> void:
    _reload_bar.visible = false

func _on_hit_confirmed(kill: bool, headshot: bool) -> void:
    crosshair.show_hit(kill, headshot)

func _on_player_announce(text: String, color: Color) -> void:
    _queue_announcement(text, color)

func _on_match_announcement(text: String, color: Color) -> void:
    _queue_announcement(text, color)

func _on_damage_from(world_direction: Vector3) -> void:
    if player == null:
        return
    var yaw := deg_to_rad(player.yaw)
    var forward := Vector2(-sin(yaw), -cos(yaw))
    var right := Vector2(-forward.y, forward.x)
    var flat := Vector2(world_direction.x, world_direction.z)
    if flat.length() < 0.01:
        return
    damage_arrows.add_hit(atan2(flat.dot(right), flat.dot(forward)))

func _on_streak_progress(_kills: int) -> void:
    for slot in 3:
        _update_streak_slot(slot)

func _on_streak_ready(slot: int, _streak_id: String) -> void:
    _update_streak_slot(slot)

func _update_streak_slot(slot: int) -> void:
    if player == null or slot >= streak_buttons.size():
        return
    var id := player.streak_ids[slot]
    var data := LoadoutCatalog.streak_data(id)
    var button := streak_buttons[slot]
    button.set_icon(str(data.get("icon", "supply")))
    var need := LoadoutCatalog.streak_kills(id)
    if player.streak_used_slot(slot):
        button.dimmed = true
        button.attention = false
        _streak_labels[slot].text = "USED"
    elif player.streak_ready_slot(slot):
        button.dimmed = false
        button.attention = true
        _streak_labels[slot].text = "READY"
    else:
        button.dimmed = true
        button.attention = false
        _streak_labels[slot].text = "%d/%d" % [mini(player.kill_streak, need), need]

func _on_player_downed() -> void:
    crosshair.visible = false
    lock_marker.visible = false
    for button in buttons.values():
        (button as KidTouchButton).dimmed = true

func _on_player_respawned() -> void:
    crosshair.visible = true
    damage_arrows.clear_all()
    for button in buttons.values():
        (button as KidTouchButton).dimmed = false
    _on_grenades(player.grenades)
    _on_weapon_changed(player.weapon.current_id())
    for slot in 3:
        _update_streak_slot(slot)

func _on_crush_ready() -> void:
    _queue_announcement("CRUSH READY!", Color(1.0, 0.7, 0.2))

func _on_objective(text: String, current: int, target: int) -> void:
    _objective_title.text = text
    if match_director != null and match_director.mode == "siege":
        _objective_count.text = "WAVE %d / %d" % [maxi(current, 1), target]
    elif match_director != null and match_director.mode == "commander":
        _objective_count.text = "BOSS FIGHT"
    else:
        _objective_count.text = "%d / %d" % [current, target]
    _objective_bar.value = clampf(float(current) / maxf(float(target), 1.0), 0.0, 1.0)

func _on_wave_started(_number: int, _total: int) -> void:
    _objective_bar.value = 0.0

func _on_kill_feed(text: String) -> void:
    var line := _label(text, 19, Color(1, 1, 1, 0.95))
    line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    line.set_meta("ttl", FEED_SECONDS)
    _feed.add_child(line)
    while _feed.get_child_count() > FEED_LINES:
        var oldest := _feed.get_child(0)
        _feed.remove_child(oldest)
        oldest.queue_free()

func _on_boss_spawned(boss: Node3D) -> void:
    _boss = boss
    _boss_panel.visible = true
    radar.boss = boss
    var fighter := boss as Fighter
    if fighter != null:
        _boss_name.text = fighter.display_name
        fighter.health_changed.connect(_on_boss_health)
        _on_boss_health(fighter.health, fighter.max_health)

func _on_boss_health(current: float, maximum: float) -> void:
    _boss_bar.value = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
    if current <= 0.0:
        _boss_panel.visible = false

func _on_lives(lives: int) -> void:
    for child in _lives_box.get_children():
        _lives_box.remove_child(child)
        child.queue_free()
    for i in maxi(lives, 0):
        _lives_box.add_child(KidUI.icon_rect("heart", 30.0))

func _on_countdown(value: int) -> void:
    if value <= 0:
        _countdown.visible = false
        return
    _countdown.text = str(value)
    _countdown.visible = true
    _countdown.pivot_offset = _countdown.size * 0.5
    _countdown.scale = Vector2(1.5, 1.5)
    var tween := create_tween()
    tween.tween_property(_countdown, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_zones_changed() -> void:
    if match_director == null:
        return
    radar.zones = match_director.zones

func _on_match_started() -> void:
    _countdown.visible = false

func _on_match_ended(_result: Dictionary) -> void:
    router.enabled = false
    if player != null:
        player.set_attack_held(false)
        player.set_mobile_move(Vector2.ZERO)
    _coach_bubble.visible = false

func _on_settings_changed() -> void:
    if settings == null:
        return
    var scale_value := clampf(float(settings.get_value("text_scale", 1.0)), 0.8, 1.5)
    for label in [_objective_count, _ammo_label]:
        (label as Label).add_theme_font_size_override("font_size", int(30.0 * scale_value))
    _layout()

# ------------------------------------------------------------------------------------------------ announcements, feed, toast
func _queue_announcement(text: String, color: Color) -> void:
    _announce_queue.append({"text": text, "color": color})
    while _announce_queue.size() > 3:
        _announce_queue.pop_front()

func show_toast(text: String) -> void:
    _toast.text = text
    _toast.visible = true
    _toast_left = 2.5

func _tick_announcements(real_delta: float) -> void:
    if _announce_left > 0.0:
        _announce_left -= real_delta
        var fade := clampf(_announce_left / 0.25, 0.0, 1.0)
        _announce.modulate.a = fade if _announce_left < 0.25 else 1.0
        if _announce_left <= 0.0:
            _announce.visible = false
    if _announce_left <= 0.0 and not _announce_queue.is_empty():
        var next: Dictionary = _announce_queue.pop_front()
        _announce.text = str(next["text"])
        _announce.add_theme_color_override("font_color", next["color"])
        _announce.modulate.a = 1.0
        _announce.visible = true
        _announce_left = ANNOUNCE_SECONDS
        _announce.pivot_offset = Vector2(_announce.size.x * 0.5, 38.0)
        _announce.scale = Vector2(1.35, 1.35)
        var tween := create_tween()
        tween.tween_property(_announce, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if _toast_left > 0.0:
        _toast_left -= real_delta
        if _toast_left <= 0.0:
            _toast.visible = false

func _tick_feed(real_delta: float) -> void:
    var index := _feed.get_child_count() - 1
    while index >= 0:
        var line := _feed.get_child(index) as Label
        var ttl := float(line.get_meta("ttl", 0.0)) - real_delta
        line.set_meta("ttl", ttl)
        line.modulate.a = clampf(ttl / 0.6, 0.0, 1.0)
        if ttl <= 0.0:
            _feed.remove_child(line)
            line.queue_free()
        index -= 1

# ------------------------------------------------------------------------------------------------ per-frame updates
func _process(delta: float) -> void:
    var real_delta := delta / maxf(Engine.time_scale, 0.05)
    _tick_announcements(real_delta)
    _tick_feed(real_delta)
    if player == null or not is_instance_valid(player):
        return
    _update_lock_marker()
    _update_meters()
    _update_vignette(real_delta)
    if _coach_step >= 0:
        _tick_coach(real_delta)

func _update_lock_marker() -> void:
    var target := player.target
    var camera := player.camera
    var has_lock := target != null and is_instance_valid(target) and camera != null and player.alive
    crosshair.set_locked(has_lock)
    if not has_lock:
        lock_marker.visible = false
        return
    var enemy := target as Fighter
    var point := enemy.chest_position() if enemy != null else target.global_position
    if camera.is_position_behind(point):
        lock_marker.visible = false
        return
    lock_marker.visible = true
    lock_marker.position = camera.unproject_position(point) - lock_marker.size * 0.5

func _update_meters() -> void:
    var fraction := player.crush_meter.fraction()
    crush_ring.fraction = fraction
    var ready_now := player.crush_meter.is_ready()
    if ready_now != _last_crush_ready:
        _last_crush_ready = ready_now
        buttons["crush"].attention = ready_now
        buttons["crush"].dimmed = not ready_now
    var rank := player.combo.rank()
    _combo_panel.visible = player.combo.count > 0
    if _combo_panel.visible:
        _combo_rank.text = rank
        _combo_count.text = "x%d COMBO" % player.combo.count
        _combo_bar.value = player.combo.time_fraction()
    if player.weapon != null and player.weapon.is_reloading():
        _reload_bar.value = player.weapon.reload_fraction()
    if match_director != null:
        _coins_label.text = str(match_director.coins_earned)

func _update_vignette(real_delta: float) -> void:
    var wanted := 0.0
    if not player.alive:
        wanted = 1.0
    else:
        var fraction := player.health_fraction()
        if fraction < 0.4:
            wanted = (0.4 - fraction) / 0.4 * (0.75 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.008))
    _vignette.modulate.a = lerpf(_vignette.modulate.a, wanted, minf(1.0, real_delta * 6.0))

# ------------------------------------------------------------------------------------------------ pause and settings
func any_panel_open() -> bool:
    return pause_panel.visible or settings_panel.visible or parent_gate.visible

func open_pause() -> void:
    if any_panel_open() or (match_director != null and match_director.finished):
        return
    if fx != null:
        fx.clear_time_effects()
    get_tree().paused = true
    backdrop.visible = true
    pause_panel.visible = true
    router.enabled = false
    pause_panel.reset_size()
    _layout()

func close_pause() -> void:
    pause_panel.visible = false
    settings_panel.visible = false
    parent_gate.visible = false
    backdrop.visible = false
    router.enabled = true
    get_tree().paused = false

func _open_settings() -> void:
    pause_panel.visible = false
    settings_panel.lock_parent_area()
    settings_panel.refresh()
    settings_panel.visible = true

func _close_settings() -> void:
    settings_panel.visible = false
    pause_panel.visible = true
    _layout()

func _on_gate_requested() -> void:
    parent_gate.open()

func _on_gate_passed() -> void:
    settings_panel.unlock_parent_area()

func _on_gate_dismissed() -> void:
    pass

func _on_save_requested() -> void:
    show_toast("Saved.")

func _on_replay_tutorial() -> void:
    if settings != null:
        settings.set_value("tutorial_done", false)
    show_toast("Tips will show again next battle.")

func _on_quit() -> void:
    get_tree().paused = false
    quit_requested.emit()

## Android back button / ESC: pauses, or closes whatever is open. Never quits the app.
func handle_back() -> bool:
    if settings_panel.visible:
        _close_settings()
    elif pause_panel.visible:
        close_pause()
    elif parent_gate.visible:
        parent_gate.visible = false
    else:
        open_pause()
    return true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return
    if event.is_action_pressed("pause"):
        handle_back()
        get_viewport().set_input_as_handled()

# ------------------------------------------------------------------------------------------------ first-battle coach (pictures first)
func _start_coach() -> void:
    _coach_step = -1
    _advance_coach()

func _advance_coach() -> void:
    _clear_coach_highlight()
    _coach_step += 1
    _coach_timer = 0.0
    _look_pixels = 0.0
    if _coach_step > 3:
        _coach_step = -1
        _coach_bubble.visible = false
        if settings != null:
            settings.set_value("tutorial_done", true)
        return
    var texts: Array[String] = ["DRAG HERE TO MOVE", "SWIPE TO LOOK AND AIM", "HOLD TO FIGHT!", "TAP TO ROLL AWAY"]
    var icons: Array[String] = ["jump", "hand", "attack", "dodge"]
    _coach_label.text = texts[_coach_step]
    _coach_icon.texture = KidUI.icon(icons[_coach_step])
    _coach_bubble.visible = true
    if _coach_step == 0:
        joystick.attention = true
    elif _coach_step == 2:
        buttons["attack"].attention = true
    elif _coach_step == 3:
        buttons["dodge"].attention = true
    _place_coach_bubble()

func _clear_coach_highlight() -> void:
    joystick.attention = false
    buttons["attack"].attention = false
    buttons["dodge"].attention = false

func _place_coach_bubble() -> void:
    var size := get_viewport().get_visible_rect().size
    _coach_bubble.reset_size()
    var spot := Vector2(size.x * 0.5 - _coach_bubble.size.x * 0.5, size.y * 0.42)
    if _coach_step == 0:
        spot = Vector2(size.x - _coach_bubble.size.x - 40.0, size.y * 0.52)
    elif _coach_step == 2:
        spot = Vector2(40.0, size.y * 0.52)
    elif _coach_step == 3:
        spot = Vector2(300.0, size.y * 0.58)
    _coach_bubble.position = spot

func _tick_coach(real_delta: float) -> void:
    if match_director != null and not match_director.running:
        return
    _coach_timer += real_delta
    if _coach_step == 0 and joystick.value.length() > 0.4:
        if _coach_timer > 0.8:
            _advance_coach()
    elif _coach_step == 1 and _look_pixels > 250.0:
        _advance_coach()
    elif _coach_step == 2 and player.kills >= 1:
        _advance_coach()
    elif _coach_step == 3 and _coach_timer > 14.0:
        _advance_coach()
    if _coach_step == 0 and joystick.value.length() <= 0.4:
        _coach_timer = 0.0
