extends CanvasLayer
class_name SplashScreen

## The game's own splash / loading screen. The engine's native boot splash (project setting
## application/boot_splash) shows the same art on the same colour, so the hand-over is seamless;
## this layer then covers the world while it is being built and fills five letter tiles
## (A-L-P-H-A) as loading progresses, so waiting is something a child can watch, not read.
const BG_COLOR := Color("#0a1230")
const WORD := "ALPHA"
const ART_PATH := "res://assets/branding/splash_art_512.png"

var _root: Control
var _art: TextureRect
var _title: Label
var _tiles: Array[Panel] = []
var _lit := 0
var _bob: Tween
var _finishing := false

func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_root)
    var bg := ColorRect.new()
    bg.color = BG_COLOR
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(bg)
    var glow := TextureRect.new()
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color(0.16, 0.30, 0.66, 0.9), Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 0.0)])
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    var glow_texture := GradientTexture2D.new()
    glow_texture.gradient = gradient
    glow_texture.fill = GradientTexture2D.FILL_RADIAL
    glow_texture.fill_from = Vector2(0.5, 0.45)
    glow_texture.fill_to = Vector2(1.0, 0.45)
    glow_texture.width = 256
    glow_texture.height = 256
    glow.texture = glow_texture
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    glow.stretch_mode = TextureRect.STRETCH_SCALE
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(glow)
    _art = TextureRect.new()
    _art.texture = load(ART_PATH) as Texture2D
    _art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_art)
    _title = Label.new()
    _title.text = "ALPHA CRUSH"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _title.add_theme_color_override("font_color", Color("#ffd65e"))
    _title.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.12, 1.0))
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_title)
    for i in WORD.length():
        var tile := Panel.new()
        tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tile.add_theme_stylebox_override("panel", _tile_style(false))
        var letter := Label.new()
        letter.text = WORD.substr(i, 1)
        letter.set_anchors_preset(Control.PRESET_FULL_RECT)
        letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
        letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
        letter.name = "Letter"
        tile.add_child(letter)
        _root.add_child(tile)
        _tiles.append(tile)
    get_viewport().size_changed.connect(_layout)
    _layout()
    _intro()

func _tile_style(lit: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = KidUI.GOLD if lit else Color(0.13, 0.20, 0.45, 0.9)
    style.set_corner_radius_all(14)
    style.border_color = Color(1, 1, 1, 0.9 if lit else 0.25)
    style.set_border_width_all(4)
    return style

func _layout() -> void:
    var vs := get_viewport().get_visible_rect().size
    var art_side := clampf(vs.y * 0.50, 200.0, 420.0)
    _art.size = Vector2(art_side, art_side)
    _art.position = Vector2((vs.x - art_side) * 0.5, vs.y * 0.07)
    _art.pivot_offset = _art.size * 0.5
    var title_size := int(clampf(vs.y * 0.085, 34.0, 72.0))
    _title.add_theme_font_size_override("font_size", title_size)
    _title.add_theme_constant_override("outline_size", maxi(6, int(title_size / 7.0)))
    _title.size = Vector2(vs.x, title_size * 1.5)
    _title.position = Vector2(0.0, _art.position.y + art_side + 6.0)
    var tile_side := clampf(vs.y * 0.088, 44.0, 76.0)
    var gap := tile_side * 0.18
    var total := tile_side * _tiles.size() + gap * (_tiles.size() - 1)
    var x := (vs.x - total) * 0.5
    var y := minf(vs.y - tile_side - 36.0, _title.position.y + _title.size.y + 22.0)
    for tile in _tiles:
        tile.position = Vector2(x, y)
        tile.size = Vector2(tile_side, tile_side)
        tile.pivot_offset = tile.size * 0.5
        (tile.get_node("Letter") as Label).add_theme_font_size_override("font_size", int(tile_side * 0.62))
        x += tile_side + gap

func _intro() -> void:
    _art.modulate.a = 0.0
    _art.scale = Vector2(0.85, 0.85)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(_art, "modulate:a", 1.0, 0.45)
    tween.tween_property(_art, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.chain().tween_callback(_start_bob)

func _start_bob() -> void:
    if _finishing:
        return
    _bob = create_tween().set_loops()
    _bob.tween_property(_art, "scale", Vector2(1.035, 1.035), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _bob.tween_property(_art, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 0..1; lights one tile per fifth.
func set_progress(value: float) -> void:
    var target := clampi(floori(clampf(value, 0.0, 1.0) * float(_tiles.size()) + 0.001), 0, _tiles.size())
    while _lit < target:
        _light(_lit)
        _lit += 1

func _light(index: int) -> void:
    var tile := _tiles[index]
    tile.add_theme_stylebox_override("panel", _tile_style(true))
    (tile.get_node("Letter") as Label).add_theme_color_override("font_color", KidUI.INK)
    var pop := create_tween()
    pop.tween_property(tile, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop.tween_property(tile, "scale", Vector2.ONE, 0.16)

## Fills any remaining tiles, then fades away. `await splash.finish()`.
func finish() -> void:
    if _finishing:
        return
    _finishing = true
    if _bob != null and _bob.is_valid():
        _bob.kill()
    set_progress(1.0)
    var fade := create_tween()
    fade.tween_interval(0.25)
    fade.tween_property(_root, "modulate:a", 0.0, 0.4)
    await fade.finished
    queue_free()
