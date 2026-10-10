extends Control
class_name ParentGate

## A grown-up check in front of settings that can spend money, open the store, change privacy
## choices or touch the network. A pre-reader cannot add 7 + 5, so a simple sum is enough.
signal passed
signal dismissed

var _panel: PanelContainer
var _question: Label
var _buttons: Array[Button] = []
var _answer := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.12, 0.78)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    _panel = PanelContainer.new()
    _panel.add_theme_stylebox_override("panel", KidUI.panel_style(KidUI.PANEL, 36, Color(1, 1, 1, 0.8), 5))
    add_child(_panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    _panel.add_child(column)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 14)
    top.add_child(KidUI.icon_rect("lock", 64.0))
    var caption := Label.new()
    caption.text = "Grown-ups only"
    caption.add_theme_font_size_override("font_size", 30)
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    top.add_child(caption)
    var close := Button.new()
    close.custom_minimum_size = Vector2(72, 72)
    close.focus_mode = Control.FOCUS_NONE
    close.icon = KidUI.icon("close")
    close.expand_icon = true
    close.add_theme_stylebox_override("normal", KidUI.panel_style(KidUI.RED, 36))
    close.add_theme_stylebox_override("pressed", KidUI.panel_style(KidUI.RED.darkened(0.2), 36))
    close.add_theme_stylebox_override("hover", KidUI.panel_style(KidUI.RED, 36))
    close.pressed.connect(_on_close)
    top.add_child(close)
    column.add_child(top)
    _question = KidUI.number_label(56, KidUI.GOLD)
    _question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_question)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(row)
    for i in 4:
        var button := Button.new()
        button.custom_minimum_size = Vector2(128, 104)
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size", 52)
        for state in ["normal", "hover", "focus"]:
            button.add_theme_stylebox_override(state, KidUI.panel_style(KidUI.BLUE, 28, Color.WHITE, 4))
        button.add_theme_stylebox_override("pressed", KidUI.panel_style(KidUI.BLUE.darkened(0.25), 28, Color.WHITE, 4))
        button.pressed.connect(_on_answer.bind(i))
        row.add_child(button)
        _buttons.append(button)
    get_viewport().size_changed.connect(_center)

func open() -> void:
    _new_question()
    visible = true
    _center.call_deferred()

func _center() -> void:
    if _panel == null:
        return
    var vs := get_viewport().get_visible_rect().size
    _panel.reset_size()
    _panel.position = (vs - _panel.size) * 0.5

func _new_question() -> void:
    var a := _rng.randi_range(4, 9)
    var b := _rng.randi_range(3, 9)
    _answer = a + b
    _question.text = "%d + %d = ?" % [a, b]
    var options: Array[int] = [_answer]
    while options.size() < 4:
        var candidate := _answer + _rng.randi_range(-4, 4)
        if candidate > 0 and not options.has(candidate):
            options.append(candidate)
    options.shuffle()
    for i in _buttons.size():
        _buttons[i].text = str(options[i])

func _on_answer(index: int) -> void:
    if int(_buttons[index].text) == _answer:
        visible = false
        passed.emit()
        return
    KidUI.buzz(40)
    var shake := create_tween()
    var home := _panel.position
    shake.tween_property(_panel, "position", home + Vector2(14, 0), 0.05)
    shake.tween_property(_panel, "position", home - Vector2(14, 0), 0.08)
    shake.tween_property(_panel, "position", home, 0.05)
    _new_question()

func _on_close() -> void:
    visible = false
    dismissed.emit()
