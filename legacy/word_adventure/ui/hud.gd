extends CanvasLayer
class_name AlphaCrushHUD

## Picture-first, thumb-first HUD for small children on phones.
##   right thumb : floating move stick (zone = right ~46% of the screen, lower 70%)
##   left thumb  : big action button (its picture changes with what is in reach) + jump
##   anywhere else: swipe to look around
##   top         : coins / gems / level chips, the goal bubble (a picture of what you are
##                 building plus its letter slots), a lightbulb hint, bag / map / settings
## All touches go through TouchRouter so holding the stick never stops a button from working.
const EDGE := 18.0
const GOAL_MAX_WIDTH := 520.0
const IDLE_HINT_SECONDS := 20.0

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
var audio: AudioManager
var opportunities: OpportunityManager
var map_view: MapView
var camera_drag: CameraDrag
var joystick: AlphaCrushVirtualJoystick

var root: Control
var router: TouchRouter
var director: GuideDirector
var guide: GuideOverlay
var coach: TutorialCoach
var act_button: KidTouchButton
var jump_button: KidTouchButton
var hint_button: KidTouchButton
var bag_button: KidTouchButton
var map_button: KidTouchButton
var menu_button: KidTouchButton
var hub: HubPanel
var settings_panel: SettingsPanel
var map_panel: PanelContainer
var parent_gate: ParentGate
var backdrop: ColorRect
var inventory_panel: PanelContainer
var daily_panel: PanelContainer
var crafting_panel: PanelContainer
var map_dirty := true

var _portrait: TextureRect
var _chips: Dictionary = {}
var _chip_values: Dictionary = {}
var _goal_panel: PanelContainer
var _goal_picture: TextureRect
var _goal_slots: HBoxContainer
var _goal_word := "?unset"
var _slot_nodes: Array[PanelContainer] = []
var _slot_state: Array[bool] = []
var _toast: PanelContainer
var _toast_icon: TextureRect
var _toast_label: Label
var _toast_time := 0.0
var _context_caption: Label
var _context_text := ""
var _context_kind := ""
var _context_extra := ""
var _objective_title := ""
var _refresh_timer := 0.0
var _idle_time := 0.0
var _last_player_position := Vector3.ZERO
var _last_text_scale := -1.0
var _last_contrast := false

func _ready() -> void:
    layer = 20
    root = Control.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_controls()
    _build_status()
    _build_goal()
    _build_toast()
    _build_panels()
    _wire()
    get_viewport().size_changed.connect(_layout)
    _on_settings_changed()
    _layout()
    _refresh_all()
    if _should_coach():
        coach.begin.call_deferred()

# ---------------------------------------------------------------- building

func _make_button(icon_name: String, color: Color, radius: float, on_release: bool) -> KidTouchButton:
    var button := KidTouchButton.new()
    button.setup(icon_name, color, radius)
    button.trigger_on_release = on_release
    root.add_child(button)
    return button

func _build_controls() -> void:
    router = TouchRouter.new()
    router.name = "TouchRouter"
    add_child(router)
    camera_drag = CameraDrag.new()
    camera_drag.name = "LookZone"
    root.add_child(camera_drag)
    camera_drag.setup(player)
    joystick = AlphaCrushVirtualJoystick.new()
    joystick.name = "MoveStick"
    root.add_child(joystick)
    joystick.input_changed.connect(_on_joystick)
    director = GuideDirector.new()
    director.setup(player, world, inventory, opportunities)
    guide = GuideOverlay.new()
    guide.name = "Guide"
    guide.player = player
    guide.director = director
    root.add_child(guide)
    act_button = _make_button("hand", KidUI.ORANGE, 78.0, false)
    act_button.name = "ActButton"
    act_button.pressed.connect(_on_act)
    jump_button = _make_button("jump", KidUI.BLUE, 54.0, false)
    jump_button.name = "JumpButton"
    jump_button.pressed.connect(_on_jump)
    hint_button = _make_button("bulb", Color("#f2a900"), 42.0, true)
    hint_button.name = "HintButton"
    hint_button.pressed.connect(_on_hint)
    bag_button = _make_button("bag", KidUI.PURPLE, 38.0, true)
    bag_button.name = "BagButton"
    bag_button.pressed.connect(func(): _open_hub("bag"))
    map_button = _make_button("map", Color("#1e9e8f"), 38.0, true)
    map_button.name = "MapButton"
    map_button.pressed.connect(_toggle_map)
    menu_button = _make_button("gear", Color("#5b6b9a"), 38.0, true)
    menu_button.name = "MenuButton"
    menu_button.pressed.connect(_toggle_settings)
    coach = TutorialCoach.new()
    coach.name = "Coach"
    coach.player = player
    coach.world = world
    coach.word_system = word_system
    coach.joystick = joystick
    coach.act_button = act_button
    coach.guide = guide
    root.add_child(coach)
    coach.finished.connect(_on_coach_finished)
    # Highest priority first; the look zone is the catch-all underneath everything.
    router.targets.assign([act_button, jump_button, hint_button, bag_button, map_button, menu_button, joystick, camera_drag])

func _make_chip(icon_name: String) -> Dictionary:
    var box := PanelContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.custom_minimum_size = Vector2(156, 46)
    var style := KidUI.panel_style(Color(0.04, 0.08, 0.24, 0.74), 24, Color(1, 1, 1, 0.45), 2)
    style.content_margin_top = 3.0
    style.content_margin_bottom = 3.0
    box.add_theme_stylebox_override("panel", style)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 8)
    box.add_child(row)
    row.add_child(KidUI.icon_rect(icon_name, 38.0))
    var label := KidUI.number_label(28)
    label.text = "0"
    row.add_child(label)
    root.add_child(box)
    return {"box": box, "label": label}

func _build_status() -> void:
    _portrait = KidUI.icon_rect("boy", 72.0)
    root.add_child(_portrait)
    _chips = {"coins": _make_chip("coin"), "gems": _make_chip("gem"), "level": _make_chip("star_gold")}

func _build_goal() -> void:
    _goal_panel = PanelContainer.new()
    _goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := KidUI.panel_style(Color(0.04, 0.08, 0.24, 0.78), 34, Color(1, 1, 1, 0.55), 3)
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    _goal_panel.add_theme_stylebox_override("panel", style)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 12)
    _goal_panel.add_child(row)
    _goal_picture = KidUI.icon_rect("explore", 76.0)
    row.add_child(_goal_picture)
    _goal_slots = HBoxContainer.new()
    _goal_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _goal_slots.add_theme_constant_override("separation", 4)
    _goal_slots.alignment = BoxContainer.ALIGNMENT_CENTER
    _goal_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(_goal_slots)
    root.add_child(_goal_panel)
    _context_caption = KidUI.number_label(20, Color(1, 1, 1, 0.9))
    _context_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _context_caption.visible = false
    root.add_child(_context_caption)

func _build_toast() -> void:
    _toast = PanelContainer.new()
    _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast.visible = false
    _toast.add_theme_stylebox_override("panel", KidUI.panel_style(Color(0.04, 0.08, 0.24, 0.88), 30, Color(1, 1, 1, 0.55), 3))
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 12)
    _toast.add_child(row)
    _toast_icon = KidUI.icon_rect("sparkle", 56.0)
    row.add_child(_toast_icon)
    _toast_label = KidUI.number_label(24)
    _toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _toast_label.custom_minimum_size = Vector2(380, 0)
    _toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(_toast_label)
    root.add_child(_toast)

func _build_panels() -> void:
    backdrop = ColorRect.new()
    backdrop.color = Color(0.02, 0.04, 0.12, 0.62)
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    backdrop.visible = false
    backdrop.gui_input.connect(_on_backdrop_input)
    root.add_child(backdrop)
    hub = HubPanel.new()
    hub.name = "Hub"
    root.add_child(hub)
    hub.setup(inventory, crafting, daily)
    hub.message.connect(show_message)
    hub.close_requested.connect(_close_all)
    inventory_panel = hub.inventory_page
    daily_panel = hub.daily_page
    crafting_panel = hub.crafting_page
    map_panel = PanelContainer.new()
    map_panel.name = "MapPanel"
    map_panel.visible = false
    map_panel.add_theme_stylebox_override("panel", KidUI.panel_style(KidUI.PANEL, 40, Color(1, 1, 1, 0.85), 5))
    var map_column := VBoxContainer.new()
    map_column.add_theme_constant_override("separation", 12)
    map_panel.add_child(map_column)
    var map_header := HBoxContainer.new()
    map_header.add_child(KidUI.icon_rect("map", 72.0))
    var map_spacer := Control.new()
    map_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_header.add_child(map_spacer)
    var map_close := Button.new()
    map_close.custom_minimum_size = Vector2(84, 84)
    map_close.focus_mode = Control.FOCUS_NONE
    var close_style := KidUI.panel_style(KidUI.RED, 42, Color.WHITE, 4)
    for state in ["normal", "hover", "pressed", "focus"]:
        map_close.add_theme_stylebox_override(state, close_style)
    map_close.icon = KidUI.icon("close")
    map_close.expand_icon = true
    map_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_close.pressed.connect(_close_all)
    map_header.add_child(map_close)
    map_column.add_child(map_header)
    var map_body := Control.new()
    map_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_column.add_child(map_body)
    map_view = MapView.new()
    map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
    map_body.add_child(map_view)
    map_view.setup(map_manager, player)
    root.add_child(map_panel)
    settings_panel = SettingsPanel.new()
    settings_panel.name = "SettingsPanel"
    root.add_child(settings_panel)
    settings_panel.setup(settings, consent, ads, purchases, multiplayer_session)
    settings_panel.message.connect(show_message)
    settings_panel.close_requested.connect(_close_all)
    settings_panel.parent_gate_requested.connect(_ask_parent)
    settings_panel.replay_tutorial_requested.connect(_replay_tutorial)
    settings_panel.save_requested.connect(_save_now)
    settings_panel.layout_changed.connect(_layout)
    parent_gate = ParentGate.new()
    parent_gate.name = "ParentGate"
    root.add_child(parent_gate)
    parent_gate.passed.connect(_on_parent_passed)
    parent_gate.dismissed.connect(_update_modal)

func _wire() -> void:
    if settings != null:
        settings.changed.connect(_on_settings_changed)
    if world != null:
        world.context_kind_changed.connect(set_context_kind)
    if word_system != null:
        word_system.word_completed.connect(_on_word_completed)
        word_system.letter_collected.connect(_on_letter_collected)

# ---------------------------------------------------------------- layout

func _place(button: KidTouchButton, center: Vector2) -> void:
    button.position = center - button.size * 0.5

func _layout() -> void:
    if root == null:
        return
    var vs := get_viewport().get_visible_rect().size
    var m := KidUI.safe_margins(get_viewport())
    var left_handed := settings != null and bool(settings.get_value("left_handed", false))
    camera_drag.position = Vector2.ZERO
    camera_drag.size = vs
    var zone_top := vs.y * 0.30
    var zone_width := maxf(260.0, vs.x * 0.46) - (m.x if left_handed else m.z)
    joystick.mirrored = left_handed
    joystick.size = Vector2(zone_width, vs.y - zone_top - m.w)
    joystick.position = Vector2(m.x if left_handed else vs.x - m.z - zone_width, zone_top)
    joystick.queue_redraw()
    var act_center := Vector2((vs.x - m.z - 150.0) if left_handed else (m.x + 150.0), vs.y - m.w - 142.0)
    _place(act_button, act_center)
    var inward := -1.0 if left_handed else 1.0
    _place(jump_button, act_center + Vector2(inward * 182.0, 30.0))
    _context_caption.size = Vector2(300, 30)
    _context_caption.position = Vector2(act_center.x - 150.0, act_center.y - 78.0 - 44.0)
    var left := m.x + EDGE
    var top := m.y + 12.0
    _portrait.position = Vector2(left, top)
    _portrait.size = Vector2(72, 72)
    var index := 0
    for key in ["coins", "gems", "level"]:
        var chip: PanelContainer = _chips[key]["box"]
        chip.position = Vector2(left + 84.0, top - 4.0 + float(index) * 50.0)
        index += 1
    var menu_center := Vector2(vs.x - m.z - EDGE - 52.0, top + 52.0)
    _place(menu_button, menu_center)
    _place(map_button, menu_center - Vector2(108.0, 0.0))
    _place(bag_button, menu_center - Vector2(216.0, 0.0))
    var free_left := left + 84.0 + 156.0 + 16.0
    var free_right := menu_center.x - 216.0 - 52.0 - 16.0
    var free_width := maxf(240.0, free_right - free_left)
    var group_width := minf(GOAL_MAX_WIDTH + 12.0 + 112.0, free_width)
    var goal_width := maxf(200.0, group_width - 124.0)
    var group_x := free_left + (free_width - group_width) * 0.5
    _goal_panel.custom_minimum_size = Vector2(goal_width, 92.0)
    _goal_panel.size = Vector2(goal_width, 92.0)
    _goal_panel.position = Vector2(group_x, top + 2.0)
    _place(hint_button, Vector2(group_x + goal_width + 12.0 + 56.0, top + 48.0))
    var panel_size := Vector2(minf(vs.x - (m.x + m.z) - 2.0 * EDGE - 40.0, 940.0), minf(vs.y - m.y - m.w - 40.0, 610.0))
    for panel in [hub, settings_panel, map_panel]:
        var control := panel as Control
        control.custom_minimum_size = panel_size
        control.size = panel_size
        control.position = (vs - panel_size) * 0.5
    _layout_toast.call_deferred()

func _layout_toast() -> void:
    if _toast == null:
        return
    var vs := get_viewport().get_visible_rect().size
    _toast.reset_size()
    _toast.pivot_offset = _toast.size * 0.5
    _toast.position = Vector2((vs.x - _toast.size.x) * 0.5, _goal_panel.position.y + _goal_panel.size.y + 14.0)

# ---------------------------------------------------------------- input callbacks

func _on_joystick(value: Vector2) -> void:
    if player and player.has_method("set_mobile_move"):
        player.set_mobile_move(value)
    _idle_time = 0.0

func _on_act() -> void:
    _idle_time = 0.0
    if player:
        player.interact()

func _on_jump() -> void:
    _idle_time = 0.0
    if player:
        player.request_jump()

func _on_hint() -> void:
    _idle_time = 0.0
    hint_button.attention = false
    _sfx("hint")
    if guide != null:
        guide.show_boost(8.0)
    if hints:
        hints.request_hint()

func _sfx(sound: String) -> void:
    if audio != null:
        audio.play_sfx(sound)

func _on_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
        _close_all()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return
    if event.is_action_pressed("inventory"):
        _open_hub("bag")
    elif event.is_action_pressed("map"):
        _toggle_map()
    elif event.is_action_pressed("hint"):
        _on_hint()
    elif event.is_action_pressed("menu"):
        if not handle_back():
            _toggle_settings()
    else:
        return
    get_viewport().set_input_as_handled()

## Android back button / ESC: closes whatever is open, otherwise opens settings. Never quits.
func handle_back() -> bool:
    if _any_panel_open():
        _close_all()
        return true
    _toggle_settings()
    return true

# ---------------------------------------------------------------- panels

func _any_panel_open() -> bool:
    return hub.visible or map_panel.visible or settings_panel.visible or parent_gate.visible

func _update_modal() -> void:
    var open := _any_panel_open()
    backdrop.visible = open
    router.enabled = not open
    if open:
        _idle_time = 0.0

func _hide_panels() -> void:
    hub.visible = false
    map_panel.visible = false
    settings_panel.visible = false
    settings_panel.lock_parent_area()
    parent_gate.visible = false

func _close_all() -> void:
    _hide_panels()
    _update_modal()

func _open_hub(tab: String) -> void:
    var was_open := hub.visible and hub.current_tab == tab
    _hide_panels()
    if not was_open:
        hub.show_tab(tab)
        hub.visible = true
        apply_accessibility()
        _sfx("ui_open")
    _update_modal()

func _toggle_map() -> void:
    var was_open := map_panel.visible
    _hide_panels()
    if not was_open:
        map_panel.visible = true
        refresh_map()
        _sfx("ui_open")
    _update_modal()

func _toggle_settings() -> void:
    var was_open := settings_panel.visible
    _hide_panels()
    if not was_open:
        settings_panel.refresh()
        settings_panel.visible = true
        apply_accessibility()
        _sfx("ui_open")
    _update_modal()

func _ask_parent() -> void:
    parent_gate.open()
    _update_modal()

func _on_parent_passed() -> void:
    settings_panel.unlock_parent_area()
    apply_accessibility()
    _update_modal()

func open_crafting() -> void:
    _open_hub("craft")

func refresh_settings() -> void:
    if settings_panel != null and settings_panel.visible:
        settings_panel.refresh()

func _save_now() -> void:
    var host := get_parent()
    if host != null and host.has_method("_save"):
        host.call("_save")
        show_message("Progress saved")

func _replay_tutorial() -> void:
    _close_all()
    if settings != null:
        settings.set_value("tutorial_done", false)
    if coach != null:
        coach.begin()

# ---------------------------------------------------------------- tutorial

func _should_coach() -> bool:
    if settings == null or player == null or world == null or word_system == null:
        return false
    if bool(settings.get_value("tutorial_done", false)):
        return false
    if not word_system.completed_words.is_empty() or word_system.total_collected() > 0:
        settings.set_value("tutorial_done", true)
        return false
    return true

func _on_coach_finished() -> void:
    if settings != null:
        settings.set_value("tutorial_done", true)
    celebrate()
    _sfx("levelup")
    show_message("You got a letter gem!")

# ---------------------------------------------------------------- live updates

func set_objective(title: String, _detail: String) -> void:
    _objective_title = title

func set_context(text_value: String) -> void:
    var text := text_value.strip_edges()
    if text.begins_with("E  "):
        text = text.substr(3)
    elif text.begins_with("E "):
        text = text.substr(2)
    _context_text = text
    _apply_context()

func set_context_kind(kind: String, extra: String = "") -> void:
    _context_kind = kind
    _context_extra = extra
    _apply_context()

func _apply_context() -> void:
    var has_target := not _context_kind.is_empty() and _context_kind != "none"
    if has_target and _context_kind == "pickup" and not _context_extra.is_empty():
        act_button.set_glyph(_context_extra)
    else:
        act_button.set_glyph("")
        act_button.set_icon(KidUI.context_icon_name(_context_kind) if has_target else "hand")
    act_button.dimmed = not has_target
    _context_caption.text = _context_text if has_target else ""
    _context_caption.visible = has_target and not _context_text.is_empty()

func show_message(text_value: String) -> void:
    if _toast == null or text_value.strip_edges().is_empty():
        return
    _toast_label.text = text_value
    _toast_icon.texture = KidUI.icon(_icon_for_message(text_value))
    _toast.visible = true
    _toast.modulate.a = 1.0
    _toast_time = 4.5
    _layout_toast()
    _toast.scale = Vector2(0.9, 0.9)
    var pop := create_tween()
    pop.tween_property(_toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _icon_for_message(text: String) -> String:
    var lower := text.to_lower()
    if lower.contains("letter") or lower.contains("gem"):
        return "gem"
    if lower.contains("harvest"):
        return "wheat"
    if lower.contains("achievement") or lower.contains("final word") or lower.contains("complete"):
        return "star_gold"
    if lower.contains("discover") or lower.contains("explore"):
        return "explore"
    if lower.contains("saved") or lower.contains("progress"):
        return "check"
    if lower.contains("crafted"):
        return "hammer"
    if lower.contains("coin") or lower.contains("sold"):
        return "coin"
    if lower.contains("weather") or lower.contains("rain") or lower.contains("sun"):
        return "sun"
    if lower.contains("multiplayer") or lower.contains("session") or lower.contains("hosting"):
        return "people"
    if lower.contains("purchase") or lower.contains("unavailable"):
        return "lock"
    return "sparkle"

func refresh_inventory() -> void:
    if hub != null and hub.visible and hub.current_tab == "bag":
        hub.refresh_inventory()

func refresh_crafting() -> void:
    if hub != null and hub.visible and hub.current_tab == "craft":
        hub.refresh_crafting()

func refresh_map() -> void:
    if map_view != null:
        map_view.queue_redraw()
    map_dirty = false

func refresh_daily() -> void:
    if hub != null and hub.visible and hub.current_tab == "daily":
        hub.refresh_daily()

func set_map_dirty() -> void:
    map_dirty = true

func _refresh_all() -> void:
    _refresh_status()
    _refresh_goal()
    _apply_context()

func _refresh_status() -> void:
    if inventory == null:
        return
    var values := {
        "coins": inventory.count("coins"),
        "gems": inventory.count("gems"),
        "level": progression.level if progression else 1
    }
    for key in values.keys():
        if _chip_values.get(key, -1) != values[key]:
            _chip_values[key] = values[key]
            (_chips[key]["label"] as Label).text = str(values[key])
    var want := "girl" if (settings != null and bool(settings.get_value("avatar_female", false))) else "boy"
    var tex := KidUI.icon(want)
    if _portrait.texture != tex:
        _portrait.texture = tex

func _style_slot(index: int, filled: bool) -> void:
    var slot := _slot_nodes[index]
    var style := KidUI.panel_style(KidUI.GOLD if filled else Color(1, 1, 1, 0.12), 12, Color.WHITE if filled else Color(1, 1, 1, 0.4), 3)
    style.content_margin_left = 2.0
    style.content_margin_right = 2.0
    style.content_margin_top = 2.0
    style.content_margin_bottom = 2.0
    slot.add_theme_stylebox_override("panel", style)
    var letter := slot.get_child(0) as Label
    letter.add_theme_color_override("font_color", KidUI.INK if filled else Color(1, 1, 1, 0.6))
    if filled:
        slot.pivot_offset = slot.size * 0.5
        var pop := create_tween()
        pop.tween_property(slot, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        pop.tween_property(slot, "scale", Vector2.ONE, 0.14)

func _rebuild_goal_slots(word: String) -> void:
    for child in _goal_slots.get_children():
        _goal_slots.remove_child(child)
        child.queue_free()
    _slot_nodes.clear()
    _slot_state.clear()
    _goal_picture.texture = KidUI.icon(KidUI.word_icon(word) if not word.is_empty() else "explore")
    if word.is_empty():
        return
    var count := word.length()
    var slot_width := clampf(floorf(408.0 / float(count)) - 4.0, 34.0, 56.0)
    for i in count:
        var slot := PanelContainer.new()
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.custom_minimum_size = Vector2(slot_width, slot_width * 1.18)
        var letter := KidUI.number_label(int(slot_width * 0.62), Color(1, 1, 1, 0.6))
        letter.text = word.substr(i, 1)
        letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        slot.add_child(letter)
        _goal_slots.add_child(slot)
        _slot_nodes.append(slot)
        _slot_state.append(false)
        _style_slot(i, false)

func _refresh_goal() -> void:
    if word_system == null or _goal_slots == null:
        return
    var word := str(word_system.active_word).to_upper()
    if word != _goal_word:
        _goal_word = word
        _rebuild_goal_slots(word)
    var seen: Dictionary = {}
    for i in _slot_nodes.size():
        var letter := _goal_word.substr(i, 1)
        var occurrence := int(seen.get(letter, 0))
        seen[letter] = occurrence + 1
        var filled := int(word_system.collected.get(letter, 0)) > occurrence
        if filled != _slot_state[i]:
            _slot_state[i] = filled
            _style_slot(i, filled)

func _on_letter_collected(_letter: String) -> void:
    _refresh_goal()
    KidUI.buzz(30)

func _on_word_completed(_word: String) -> void:
    _refresh_goal()
    celebrate()
    KidUI.buzz(70)

func celebrate(origin: Vector2 = Vector2.ZERO) -> void:
    var vs := get_viewport().get_visible_rect().size
    var start := origin if origin != Vector2.ZERO else Vector2(vs.x * 0.5, vs.y * 0.34)
    var palette: Array[Color] = [KidUI.GOLD, KidUI.PINK, KidUI.BLUE, KidUI.GREEN, KidUI.ORANGE, KidUI.PURPLE]
    for i in 34:
        var piece := ColorRect.new()
        piece.color = palette[i % palette.size()]
        piece.size = Vector2(randf_range(10.0, 18.0), randf_range(16.0, 26.0))
        piece.position = start
        piece.pivot_offset = piece.size * 0.5
        piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(piece)
        var angle := randf_range(PI, TAU)
        var burst := start + Vector2(cos(angle), sin(angle)) * randf_range(120.0, 380.0)
        var landing := burst + Vector2(randf_range(-60.0, 60.0), randf_range(200.0, 440.0))
        var tween := create_tween().set_parallel(true)
        tween.tween_property(piece, "position", burst, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(piece, "position", landing, 1.0).set_delay(0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(piece, "rotation", randf_range(-8.0, 8.0), 1.45)
        tween.tween_property(piece, "modulate:a", 0.0, 0.5).set_delay(0.95)
        tween.chain().tween_callback(piece.queue_free)

# ---------------------------------------------------------------- settings + accessibility

func _on_settings_changed() -> void:
    if settings == null:
        return
    KidUI.haptics_enabled = bool(settings.get_value("vibration", true))
    if guide != null:
        guide.enabled = bool(settings.get_value("guide_arrows", true))
    var scale_now := float(settings.get_value("text_scale", 1.0))
    var contrast_now := bool(settings.get_value("high_contrast", false))
    if not is_equal_approx(scale_now, _last_text_scale) or contrast_now != _last_contrast:
        apply_accessibility()
    _layout()
    _refresh_status()

func apply_accessibility() -> void:
    if settings == null or hub == null:
        return
    var text_scale := clampf(float(settings.get_value("text_scale", 1.0)), 0.8, 1.5)
    var contrast := bool(settings.get_value("high_contrast", false))
    _last_text_scale = text_scale
    _last_contrast = contrast
    var frame := KidUI.panel_style(Color.BLACK if contrast else KidUI.PANEL, 40, Color.WHITE if contrast else Color(1, 1, 1, 0.85), 6 if contrast else 5)
    for panel in [hub, settings_panel, map_panel]:
        var control := panel as Control
        control.add_theme_stylebox_override("panel", frame)
        for node in control.find_children("*", "Label", true, false):
            var label := node as Label
            if not label.has_meta("base_font_size"):
                label.set_meta("base_font_size", label.get_theme_font_size("font_size"))
            label.add_theme_font_size_override("font_size", maxi(12, int(round(float(label.get_meta("base_font_size")) * text_scale))))
            if contrast:
                label.add_theme_color_override("font_color", Color.WHITE)

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
    if _toast_time > 0.0:
        _toast_time -= delta
        if _toast_time <= 0.0:
            _toast.visible = false
        elif _toast_time < 0.5:
            _toast.modulate.a = _toast_time / 0.5
    _refresh_timer -= delta
    if _refresh_timer <= 0.0:
        _refresh_timer = 0.2
        _refresh_status()
        _refresh_goal()
        var coaching := coach != null and coach.is_pointing_at_action()
        act_button.attention = coaching or (not _context_kind.is_empty() and _context_kind != "none")
        if map_dirty and map_panel.visible:
            refresh_map()
        if hub.visible and hub.current_tab == "daily":
            hub.refresh_daily()
    _tick_idle(delta)

func _tick_idle(delta: float) -> void:
    if player == null:
        return
    var moved := player.global_position.distance_to(_last_player_position) > 0.05
    _last_player_position = player.global_position
    if moved or router.active_touches() > 0 or _any_panel_open():
        _idle_time = 0.0
        return
    _idle_time += delta
    if _idle_time > IDLE_HINT_SECONDS and not hint_button.attention and not (coach != null and coach.is_running()):
        hint_button.attention = true
        if guide != null:
            guide.show_boost(5.0)
