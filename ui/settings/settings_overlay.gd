extends CanvasLayer
class_name SettingsOverlay

## The settings screen as a full-screen overlay for the MAIN MENU (in a battle the HUD hosts its own copy inside the pause
## menu). Sensitive switches stay behind the grown-up gate exactly as in the SettingsPanel.
signal closed
signal layout_changed
signal save_requested
signal message(text: String)

var panel: SettingsPanel
var gate: ParentGate
var _backdrop: ColorRect

func setup(p_settings: SettingsManager, p_consent: ConsentManager, p_ads: AdService, p_purchases: PurchaseService) -> void:
    layer = 60
    process_mode = Node.PROCESS_MODE_ALWAYS
    _backdrop = ColorRect.new()
    _backdrop.color = Color(0.02, 0.04, 0.12, 0.78)
    _backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    _backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_backdrop)
    panel = SettingsPanel.new()
    panel.name = "SettingsPanel"
    add_child(panel)
    panel.setup(p_settings, p_consent, p_ads, p_purchases)
    panel.close_requested.connect(close)
    panel.message.connect(func(text: String): message.emit(text))
    panel.layout_changed.connect(func(): layout_changed.emit())
    panel.save_requested.connect(func(): save_requested.emit())
    panel.parent_gate_requested.connect(_on_gate_requested)
    gate = ParentGate.new()
    gate.name = "ParentGate"
    add_child(gate)
    gate.passed.connect(panel.unlock_parent_area)
    visible = false

func is_open() -> bool:
    return visible

func open() -> void:
    var size := get_viewport().get_visible_rect().size
    var panel_size := Vector2(minf(size.x - 80.0, 940.0), minf(size.y - 60.0, 610.0))
    panel.custom_minimum_size = panel_size
    panel.size = panel_size
    panel.position = (size - panel_size) * 0.5
    panel.lock_parent_area()
    panel.refresh()
    visible = true
    panel.visible = true

func close() -> void:
    visible = false
    gate.visible = false
    closed.emit()

func _on_gate_requested() -> void:
    gate.open()
