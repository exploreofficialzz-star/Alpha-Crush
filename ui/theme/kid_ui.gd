extends RefCounted
class_name KidUI

## Shared look-and-feel for the picture-first HUD: palette, icon lookup, rounded panel styles and
## small feedback helpers. Everything here is static so any UI script can use it without wiring.

const ICON_DIR := "res://assets/ui/icons/"

const NAVY := Color("#0a1230")
const PANEL := Color("#142457")
const PANEL_LIGHT := Color("#22377e")
const GOLD := Color("#ffc83d")
const GOLD_DARK := Color("#d68c14")
const ORANGE := Color("#ff8a1c")
const GREEN := Color("#3ec46d")
const BLUE := Color("#3e8cf0")
const PURPLE := Color("#7a5cff")
const PINK := Color("#ff78aa")
const RED := Color("#e84640")
const WHITE := Color(1, 1, 1, 1)
const INK := Color("#172554")

static var _icons: Dictionary = {}
static var haptics_enabled := true

static func icon(icon_name: String) -> Texture2D:
    if _icons.has(icon_name):
        return _icons[icon_name] as Texture2D
    var path := "%s%s.png" % [ICON_DIR, icon_name]
    var tex: Texture2D = null
    if ResourceLoader.exists(path):
        tex = load(path) as Texture2D
    _icons[icon_name] = tex
    return tex

static func buzz(milliseconds: int = 18) -> void:
    if haptics_enabled and DisplayServer.is_touchscreen_available():
        Input.vibrate_handheld(milliseconds)

static func panel_style(fill: Color, radius: int = 28, border: Color = Color(1, 1, 1, 0.0), border_width: int = 0) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.set_corner_radius_all(radius)
    if border_width > 0:
        style.border_color = border
        style.set_border_width_all(border_width)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    return style

## A TextureRect showing an icon at a fixed size (keeps aspect, never stretches).
static func icon_rect(icon_name: String, pixels: float) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = icon(icon_name)
    rect.custom_minimum_size = Vector2(pixels, pixels)
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect

## Big, chunky label used for numbers (coins, gems, level).
static func number_label(font_size: int = 28, color: Color = WHITE) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.2, 1.0))
    label.add_theme_constant_override("outline_size", maxi(3, int(font_size / 6)))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

## Rounded-rectangle outline helper for _draw() code.
static func draw_round_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(int(radius))
    canvas.draw_style_box(style, rect)

## Safe-area insets (left, top, right, bottom) in canvas units; zero on devices without cut-outs.
static func safe_margins(viewport: Viewport) -> Vector4:
    var canvas := viewport.get_visible_rect().size
    var window_px := Vector2(DisplayServer.window_get_size())
    if window_px.x <= 0.0 or window_px.y <= 0.0:
        return Vector4.ZERO
    var safe := DisplayServer.get_display_safe_area()
    var screen := Vector2(DisplayServer.screen_get_size())
    if safe.size.x <= 0 or safe.size.y <= 0 or screen.x <= 0.0:
        return Vector4.ZERO
    var kx := canvas.x / window_px.x
    var ky := canvas.y / window_px.y
    var left := clampf(float(safe.position.x) * kx, 0.0, 96.0)
    var top := clampf(float(safe.position.y) * ky, 0.0, 96.0)
    var right := clampf((screen.x - float(safe.end.x)) * kx, 0.0, 96.0)
    var bottom := clampf((screen.y - float(safe.end.y)) * ky, 0.0, 96.0)
    return Vector4(left, top, right, bottom)
