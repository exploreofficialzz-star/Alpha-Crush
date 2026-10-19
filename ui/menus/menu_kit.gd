extends RefCounted
class_name MenuKit

## Small builders shared by every menu screen so buttons, cards, stars and bars look the same everywhere.
static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
    var made := KidUI.number_label(size, color)
    made.text = text
    return made

static func spacer(expand_horizontal: bool = true) -> Control:
    var node := Control.new()
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if expand_horizontal:
        node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    else:
        node.size_flags_vertical = Control.SIZE_EXPAND_FILL
    return node

static func button(text: String, color: Color, min_size: Vector2 = Vector2(260, 68), font_size: int = 28) -> Button:
    var made := Button.new()
    made.text = text
    made.focus_mode = Control.FOCUS_NONE
    made.custom_minimum_size = min_size
    made.add_theme_font_size_override("font_size", font_size)
    made.add_theme_color_override("font_color", Color.WHITE)
    made.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
    var normal := KidUI.panel_style(color, 28, Color(1, 1, 1, 0.9), 4)
    var pressed := KidUI.panel_style(color.darkened(0.25), 28, Color(1, 1, 1, 0.9), 4)
    var disabled := KidUI.panel_style(Color(0.3, 0.34, 0.46), 28, Color(1, 1, 1, 0.3), 3)
    made.add_theme_stylebox_override("normal", normal)
    made.add_theme_stylebox_override("hover", normal)
    made.add_theme_stylebox_override("focus", normal)
    made.add_theme_stylebox_override("pressed", pressed)
    made.add_theme_stylebox_override("disabled", disabled)
    return made

static func icon_button(icon_name: String, color: Color, side: float) -> Button:
    var made := button("", color, Vector2(side, side), 20)
    made.icon = KidUI.icon(icon_name)
    made.expand_icon = true
    made.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return made

static func card(fill: Color = KidUI.PANEL, radius: int = 26, border: Color = Color(1, 1, 1, 0.55)) -> PanelContainer:
    var made := PanelContainer.new()
    made.add_theme_stylebox_override("panel", KidUI.panel_style(fill, radius, border, 3))
    return made

static func bar(fill: Color, height: float, width: float) -> ProgressBar:
    var made := ProgressBar.new()
    made.show_percentage = false
    made.min_value = 0.0
    made.max_value = 1.0
    made.custom_minimum_size = Vector2(width, height)
    made.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var back := StyleBoxFlat.new()
    back.bg_color = Color(0.03, 0.07, 0.2, 0.8)
    back.set_corner_radius_all(int(height * 0.5))
    var front := StyleBoxFlat.new()
    front.bg_color = fill
    front.set_corner_radius_all(int(height * 0.5))
    made.add_theme_stylebox_override("background", back)
    made.add_theme_stylebox_override("fill", front)
    return made

## Three star icons, `count` of them gold.
static func stars(count: int, side: float = 28.0) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 2)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in 3:
        var star := KidUI.icon_rect("star_gold" if i < count else "star", side)
        if i >= count:
            star.modulate = Color(1, 1, 1, 0.35)
        row.add_child(star)
    return row

static func chip(icon_name: String, text: String, color: Color = KidUI.GOLD) -> PanelContainer:
    var made := card(Color(0.04, 0.09, 0.24, 0.85), 24)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    made.add_child(row)
    row.add_child(KidUI.icon_rect(icon_name, 34.0))
    var value := label(text, 26, color)
    value.name = "Value"
    row.add_child(value)
    return made

static func clear_children(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()
