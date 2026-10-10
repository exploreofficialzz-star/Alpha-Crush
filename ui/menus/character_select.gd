extends CanvasLayer
class_name CharacterSelect

## "Who is playing?" Two big cards, a boy and a girl, each showing the real 3D hero turning on
## the spot. Tap a card (the hero waves), then tap the big green play button. No reading needed.
signal chosen(gender: String)

const OPTIONS: Array[Dictionary] = [
    {"gender": "male", "portrait": "boy", "label": "BOY", "tint": Color("#3e8cf0"), "seed": 7},
    {"gender": "female", "portrait": "girl", "label": "GIRL", "tint": Color("#ff78aa"), "seed": 12}
]

var audio: Node
var _root: Control
var _cards: Array[Button] = []
var _rigs: Array[AvatarRig] = []
var _play: Button
var _play_icon: TextureRect
var _hand: TextureRect
var _selected := -1
var _time := 0.0
var _confirmed := false

func _ready() -> void:
    layer = 95
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_root)
    _root.add_child(_make_backdrop())
    for i in OPTIONS.size():
        var card := _make_card(i)
        _cards.append(card)
        _root.add_child(card)
    _play = _make_play_button()
    _root.add_child(_play)
    _hand = KidUI.icon_rect("pointer", 120.0)
    _hand.size = Vector2(120, 120)
    _root.add_child(_hand)
    get_viewport().size_changed.connect(_layout)
    _layout()
    _set_play_enabled(false)

func _make_backdrop() -> Control:
    var holder := Control.new()
    holder.set_anchors_preset(Control.PRESET_FULL_RECT)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg := ColorRect.new()
    bg.color = KidUI.NAVY
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(bg)
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color(0.20, 0.34, 0.74, 0.95), Color(KidUI.NAVY.r, KidUI.NAVY.g, KidUI.NAVY.b, 0.0)])
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.4)
    texture.fill_to = Vector2(1.0, 0.4)
    texture.width = 256
    texture.height = 256
    var glow := TextureRect.new()
    glow.texture = texture
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(glow)
    return holder

func _card_style(tint: Color, selected: bool) -> StyleBoxFlat:
    var fill := tint.darkened(0.55) if selected else Color("#16295f")
    var style := KidUI.panel_style(fill, 40, KidUI.GOLD if selected else Color(1, 1, 1, 0.45), 12 if selected else 5)
    style.shadow_color = Color(0, 0, 0, 0.4)
    style.shadow_size = 16 if selected else 8
    style.shadow_offset = Vector2(0, 8)
    return style

func _make_card(index: int) -> Button:
    var option: Dictionary = OPTIONS[index]
    var card := Button.new()
    card.focus_mode = Control.FOCUS_NONE
    card.flat = false
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        card.add_theme_stylebox_override(state, _card_style(option["tint"], false))
    card.pressed.connect(_on_card_pressed.bind(index))
    card.add_child(_make_preview(str(option["gender"]), int(option["seed"])))
    var badge := KidUI.icon_rect(str(option["portrait"]), 70.0)
    badge.name = "Badge"
    card.add_child(badge)
    var label := KidUI.number_label(36)
    label.name = "Name"
    label.text = str(option["label"])
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    card.add_child(label)
    return card

func _make_preview(gender: String, seed_value: int) -> SubViewportContainer:
    var container := SubViewportContainer.new()
    container.name = "Preview"
    container.stretch = true
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var viewport := SubViewport.new()
    viewport.own_world_3d = true
    viewport.transparent_bg = true
    viewport.handle_input_locally = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    container.add_child(viewport)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_CLEAR_COLOR
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.86, 0.90, 1.0)
    environment.ambient_light_energy = 0.9
    var world_environment := WorldEnvironment.new()
    world_environment.environment = environment
    viewport.add_child(world_environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = false
    viewport.add_child(sun)
    var camera := Camera3D.new()
    camera.fov = 30.0
    camera.position = Vector3(0.0, 1.0, 4.4)
    camera.current = true
    viewport.add_child(camera)
    var rig := AvatarRig.new()
    rig.name = "PreviewRig"
    viewport.add_child(rig)
    if rig.build(gender, AvatarRig.outfit_for("default", seed_value)):
        rig.rotation_degrees = Vector3(0.0, 160.0, 0.0)  # the model faces -Z; turn it to face the camera
        _rigs.append(rig)
    else:
        viewport.remove_child(rig)
        rig.free()
        _rigs.append(null)
        var fallback := KidUI.icon_rect("boy" if gender == "male" else "girl", 200.0)
        fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
        container.add_child(fallback)
    return container

func _make_play_button() -> Button:
    var button := Button.new()
    button.focus_mode = Control.FOCUS_NONE
    var style := KidUI.panel_style(KidUI.GREEN, 80, Color.WHITE, 8)
    style.shadow_color = Color(0, 0, 0, 0.4)
    style.shadow_size = 12
    style.shadow_offset = Vector2(0, 7)
    for state in ["normal", "hover", "pressed", "focus"]:
        button.add_theme_stylebox_override(state, style)
    var off := KidUI.panel_style(Color("#4b5a86"), 80, Color(1, 1, 1, 0.5), 6)
    button.add_theme_stylebox_override("disabled", off)
    button.pressed.connect(_on_play_pressed)
    _play_icon = KidUI.icon_rect("play", 90.0)
    _play_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    _play_icon.offset_left = 22.0
    _play_icon.offset_top = 22.0
    _play_icon.offset_right = -14.0
    _play_icon.offset_bottom = -22.0
    button.add_child(_play_icon)
    return button

func _layout() -> void:
    var vs := get_viewport().get_visible_rect().size
    var card_size := Vector2(minf(vs.x * 0.30, 380.0), clampf(vs.y * 0.58, 260.0, 440.0))
    var gap := minf(vs.x * 0.05, 70.0)
    var x0 := (vs.x - (card_size.x * 2.0 + gap)) * 0.5
    var y0 := vs.y * 0.06
    for i in _cards.size():
        var card := _cards[i]
        card.position = Vector2(x0 + float(i) * (card_size.x + gap), y0)
        card.size = card_size
        card.pivot_offset = card_size * 0.5
        var preview := card.get_node("Preview") as Control
        preview.position = Vector2(10.0, 10.0)
        preview.size = Vector2(card_size.x - 20.0, card_size.y - 98.0)
        var badge := card.get_node("Badge") as Control
        badge.position = Vector2(18.0, card_size.y - 84.0)
        badge.size = Vector2(70.0, 70.0)
        var label := card.get_node("Name") as Label
        label.position = Vector2(96.0, card_size.y - 84.0)
        label.size = Vector2(card_size.x - 110.0, 70.0)
    var play_side := clampf(vs.y * 0.18, 96.0, 140.0)
    _play.size = Vector2(play_side, play_side)
    _play.pivot_offset = _play.size * 0.5
    _play.position = Vector2((vs.x - play_side) * 0.5, minf(vs.y - play_side - 18.0, y0 + card_size.y + 22.0))

func _set_play_enabled(enabled: bool) -> void:
    _play.disabled = not enabled
    _play_icon.modulate = Color(1, 1, 1, 1.0 if enabled else 0.45)

func _sfx(sound: String) -> void:
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", sound)

func _on_card_pressed(index: int) -> void:
    if _confirmed:
        return
    _selected = index
    _sfx("ui_click")
    KidUI.buzz(20)
    for i in _cards.size():
        var option: Dictionary = OPTIONS[i]
        var is_selected := i == index
        var style := _card_style(option["tint"], is_selected)
        for state in ["normal", "hover", "pressed", "focus", "disabled"]:
            _cards[i].add_theme_stylebox_override(state, style)
        var tween := create_tween().set_parallel(true)
        tween.tween_property(_cards[i], "scale", Vector2(1.06, 1.06) if is_selected else Vector2(0.94, 0.94), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(_cards[i], "modulate", Color.WHITE if is_selected else Color(0.78, 0.8, 0.9, 1.0), 0.2)
    if index < _rigs.size() and _rigs[index] != null:
        _rigs[index].play_reach()
    _set_play_enabled(true)
    _hand.visible = false

func _on_play_pressed() -> void:
    if _selected < 0 or _confirmed:
        return
    _confirmed = true
    _sfx("unlock")
    var option: Dictionary = OPTIONS[_selected]
    chosen.emit(str(option["gender"]))
    var fade := create_tween()
    fade.tween_property(_root, "modulate:a", 0.0, 0.3)
    await fade.finished
    queue_free()

func _process(delta: float) -> void:
    _time += delta
    for rig in _rigs:
        if rig != null and is_instance_valid(rig):
            rig.animate(delta, 0.0, true)
    if _selected < 0 and not _cards.is_empty():
        var card := _cards[0]
        _hand.visible = true
        var tip := card.position + Vector2(card.size.x * 0.5, card.size.y * 0.55)
        _hand.position = tip - Vector2(30.0, 14.0) + Vector2(0.0, sin(_time * 4.0) * 12.0)
    elif _selected >= 0 and not _confirmed:
        var pulse := 1.0 + 0.06 * sin(_time * 6.0)
        _play.scale = Vector2(pulse, pulse)
