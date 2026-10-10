extends PanelContainer
class_name HubPanel

## One big panel with three picture tabs: the bag (item tiles), today's stars (daily goals as
## filled pips) and the workshop (recipes shown as ingredient icons -> result icon).
signal message(text: String)
signal close_requested

const TABS: Array[Dictionary] = [
    {"id": "bag", "icon": "bag", "color": Color("#7a5cff")},
    {"id": "daily", "icon": "star", "color": Color("#f2a900")},
    {"id": "craft", "icon": "hammer", "color": Color("#ff8a1c")}
]

var inventory: Inventory
var crafting: CraftingManager
var daily: DailyManager
var inventory_page: PanelContainer
var daily_page: PanelContainer
var crafting_page: PanelContainer
var current_tab := "bag"
var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _bag_grid: GridContainer
var _bag_bar: ProgressBar
var _bag_empty: Control
var _daily_rows: VBoxContainer
var _craft_rows: VBoxContainer

func setup(local_inventory: Inventory, local_crafting: CraftingManager, local_daily: DailyManager) -> void:
    inventory = local_inventory
    crafting = local_crafting
    daily = local_daily
    visible = false
    add_theme_stylebox_override("panel", KidUI.panel_style(KidUI.PANEL, 40, Color(1, 1, 1, 0.85), 5))
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    add_child(column)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    column.add_child(header)
    for tab in TABS:
        var button := _round_button(str(tab["icon"]), tab["color"], 84.0)
        button.pressed.connect(show_tab.bind(str(tab["id"])))
        header.add_child(button)
        _tab_buttons[str(tab["id"])] = button
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    var close := _round_button("close", KidUI.RED, 84.0)
    close.pressed.connect(func(): close_requested.emit())
    header.add_child(close)
    var body := Control.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(body)
    inventory_page = _make_page(body)
    daily_page = _make_page(body)
    crafting_page = _make_page(body)
    _pages = {"bag": inventory_page, "daily": daily_page, "craft": crafting_page}
    _build_bag()
    _build_daily()
    _build_craft()
    show_tab("bag")

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
    var disabled_style := normal.duplicate() as StyleBoxFlat
    disabled_style.bg_color = Color("#4b5a86")
    button.add_theme_stylebox_override("disabled", disabled_style)
    button.icon = KidUI.icon(icon_name)
    button.expand_icon = true
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return button

func _make_page(parent: Control) -> PanelContainer:
    var page := PanelContainer.new()
    page.set_anchors_preset(Control.PRESET_FULL_RECT)
    page.add_theme_stylebox_override("panel", KidUI.panel_style(Color(0.04, 0.08, 0.24, 0.6), 28))
    page.visible = false
    parent.add_child(page)
    return page

func show_tab(tab_id: String) -> void:
    current_tab = tab_id
    for id in _pages.keys():
        (_pages[id] as Control).visible = id == tab_id
    for id in _tab_buttons.keys():
        var button := _tab_buttons[id] as Button
        button.modulate = Color.WHITE if id == tab_id else Color(0.72, 0.74, 0.85, 1.0)
    refresh_all()

func refresh_all() -> void:
    match current_tab:
        "bag":
            refresh_inventory()
        "daily":
            refresh_daily()
        "craft":
            refresh_crafting()

func _build_bag() -> void:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    inventory_page.add_child(column)
    _bag_bar = ProgressBar.new()
    _bag_bar.show_percentage = false
    _bag_bar.custom_minimum_size = Vector2(0, 22)
    var fill := KidUI.panel_style(KidUI.GREEN, 11)
    var back := KidUI.panel_style(Color(1, 1, 1, 0.14), 11)
    _bag_bar.add_theme_stylebox_override("fill", fill)
    _bag_bar.add_theme_stylebox_override("background", back)
    column.add_child(_bag_bar)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var stack := Control.new()
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.add_child(stack)
    _bag_grid = GridContainer.new()
    _bag_grid.columns = 5
    _bag_grid.add_theme_constant_override("h_separation", 12)
    _bag_grid.add_theme_constant_override("v_separation", 12)
    stack.add_child(_bag_grid)
    _bag_empty = KidUI.icon_rect("bag", 160.0)
    _bag_empty.modulate = Color(1, 1, 1, 0.3)
    column.add_child(_bag_empty)
    _bag_empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _tile(icon_name: String, amount: int) -> PanelContainer:
    var tile := PanelContainer.new()
    tile.custom_minimum_size = Vector2(120, 128)
    tile.add_theme_stylebox_override("panel", KidUI.panel_style(Color(1, 1, 1, 0.12), 24, Color(1, 1, 1, 0.35), 3))
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 0)
    tile.add_child(column)
    var picture := KidUI.icon_rect(icon_name, 72.0)
    picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    column.add_child(picture)
    var count := KidUI.number_label(28, KidUI.GOLD)
    count.text = "×%d" % amount
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(count)
    return tile

func refresh_inventory() -> void:
    if inventory == null or _bag_grid == null:
        return
    for child in _bag_grid.get_children():
        _bag_grid.remove_child(child)
        child.queue_free()
    var ids: Array = inventory.items.keys()
    ids.sort()
    var shown := 0
    for id in ids:
        var item_id := str(id)
        var amount := int(inventory.items[id])
        if amount <= 0 or item_id == "coins" or item_id == "gems":
            continue
        _bag_grid.add_child(_tile(KidUI.item_icon_name(item_id), amount))
        shown += 1
    _bag_empty.visible = shown == 0
    _bag_bar.max_value = maxf(1.0, float(inventory.capacity))
    _bag_bar.value = float(inventory.used_slots())

func _build_daily() -> void:
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    daily_page.add_child(scroll)
    _daily_rows = VBoxContainer.new()
    _daily_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _daily_rows.add_theme_constant_override("separation", 12)
    scroll.add_child(_daily_rows)

func refresh_daily() -> void:
    if daily == null or _daily_rows == null:
        return
    for child in _daily_rows.get_children():
        _daily_rows.remove_child(child)
        child.queue_free()
    for objective in daily.objectives:
        var target := maxi(1, int(objective.get("target", 1)))
        var progress := clampi(int(objective.get("progress", 0)), 0, target)
        var done := progress >= target
        var row := PanelContainer.new()
        row.add_theme_stylebox_override("panel", KidUI.panel_style(Color(0.2, 0.75, 0.4, 0.28) if done else Color(1, 1, 1, 0.1), 26, Color(1, 1, 1, 0.3), 3))
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 14)
        row.add_child(line)
        var star := KidUI.icon_rect("star_gold", 64.0)
        star.modulate = Color.WHITE if done else Color(1, 1, 1, 0.4)
        line.add_child(star)
        var middle := VBoxContainer.new()
        middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(middle)
        var title := Label.new()
        title.text = str(objective.get("title", "Goal"))
        title.add_theme_font_size_override("font_size", 22)
        title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        middle.add_child(title)
        var pips := HBoxContainer.new()
        pips.add_theme_constant_override("separation", 6)
        for i in mini(target, 8):
            var filled := i < progress if target <= 8 else float(i) / float(mini(target, 8)) < float(progress) / float(target)
            var dot := Panel.new()
            dot.custom_minimum_size = Vector2(26, 26)
            dot.add_theme_stylebox_override("panel", KidUI.panel_style(KidUI.GOLD if filled else Color(1, 1, 1, 0.18), 13, Color.WHITE if filled else Color(1, 1, 1, 0.3), 2))
            pips.add_child(dot)
        middle.add_child(pips)
        var reward: Dictionary = objective.get("reward", {})
        for currency in reward.keys():
            var chip := HBoxContainer.new()
            chip.add_child(KidUI.icon_rect(KidUI.item_icon_name(str(currency)), 40.0))
            var amount := KidUI.number_label(24, KidUI.GOLD)
            amount.text = "+%d" % int(reward[currency])
            chip.add_child(amount)
            line.add_child(chip)
        _daily_rows.add_child(row)

func _build_craft() -> void:
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    crafting_page.add_child(scroll)
    _craft_rows = VBoxContainer.new()
    _craft_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _craft_rows.add_theme_constant_override("separation", 12)
    scroll.add_child(_craft_rows)

func _chip(item_id: String, amount: int, enough: bool) -> Control:
    var chip := VBoxContainer.new()
    chip.add_theme_constant_override("separation", -4)
    var picture := KidUI.icon_rect(KidUI.item_icon_name(item_id), 54.0)
    picture.modulate = Color.WHITE if enough else Color(1, 1, 1, 0.45)
    chip.add_child(picture)
    var count := KidUI.number_label(22, KidUI.GREEN if enough else KidUI.RED)
    count.text = "×%d" % amount
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chip.add_child(count)
    return chip

func refresh_crafting() -> void:
    if crafting == null or _craft_rows == null:
        return
    for child in _craft_rows.get_children():
        _craft_rows.remove_child(child)
        child.queue_free()
    var ids: Array = crafting.recipes.keys()
    ids.sort()
    for recipe_id in ids:
        var id := str(recipe_id)
        var recipe: Dictionary = crafting.recipes[recipe_id]
        var row := PanelContainer.new()
        row.add_theme_stylebox_override("panel", KidUI.panel_style(Color(1, 1, 1, 0.1), 26, Color(1, 1, 1, 0.3), 3))
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 12)
        row.add_child(line)
        var inputs: Dictionary = recipe.get("inputs", {})
        for item in inputs.keys():
            var needed := int(inputs[item])
            line.add_child(_chip(str(item), needed, inventory != null and inventory.has_item(str(item), needed)))
        var arrow := KidUI.icon_rect("play", 44.0)
        arrow.modulate = Color(1, 1, 1, 0.8)
        line.add_child(arrow)
        line.add_child(_chip(str(recipe.get("output", id)), int(recipe.get("amount", 1)), true))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(spacer)
        var can := crafting.can_craft(id)
        var craft := _round_button("hammer" if can else "lock", KidUI.GREEN if can else Color("#4b5a86"), 76.0)
        craft.disabled = not can
        craft.pressed.connect(func():
            if crafting.craft(id):
                message.emit("Crafted %s" % id.replace("_", " ").capitalize())
            else:
                message.emit("Not enough materials or bag space")
            refresh_crafting()
        )
        line.add_child(craft)
        _craft_rows.add_child(row)
