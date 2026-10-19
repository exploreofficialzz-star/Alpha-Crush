extends CanvasLayer
class_name ResultScreen

## Shown when a battle ends: win or loss banner, the star rating, a stats board, XP and coins counting up, and any rank-up
## with the things it unlocks. Four exits: NEXT (campaign), RETRY, MENU and an optional "x2 coins" rewarded-ad button.
signal next_requested
signal retry_requested
signal menu_requested
signal double_coins_requested

var audio: AudioManager

var _card: PanelContainer
var _double_button: Button

static func format_time(seconds: float) -> String:
    var total := maxi(int(seconds), 0)
    return "%d:%02d" % [int(float(total) / 60.0), total % 60]

## What a new rank opens up, as short labels (used for the rank-up banner and unit-tested).
static func unlocks_at_rank(rank: int) -> Array[String]:
    var found: Array[String] = []
    for id in WeaponCatalog.ORDER:
        if WeaponCatalog.unlock_rank(id) == rank:
            found.append(WeaponCatalog.display_name(id))
    var groups: Array[Dictionary] = [LoadoutCatalog.STYLES, LoadoutCatalog.CRUSH_MOVES, LoadoutCatalog.STREAKS, LoadoutCatalog.OUTFITS]
    for group in groups:
        for id in group.keys():
            if int(group[id].get("unlock_rank", 1)) == rank and rank > 1:
                found.append(str(group[id].get("name", str(id).to_upper())))
    return found

func _ready() -> void:
    layer = 40
    process_mode = Node.PROCESS_MODE_ALWAYS

func show_result(result: Dictionary, rank_before: int, rank_after: int, has_next: bool, can_double: bool) -> void:
    var root := Control.new()
    root.name = "Root"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    var dim := ColorRect.new()
    dim.color = Color(0.02, 0.04, 0.12, 0.82)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(dim)
    var won := bool(result.get("won", false))
    _card = MenuKit.card(KidUI.PANEL, 36, Color(1, 1, 1, 0.85))
    _card.custom_minimum_size = Vector2(900, 0)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    _card.add_child(column)
    var title := MenuKit.label("MISSION COMPLETE" if won else "MISSION FAILED", 54, KidUI.GREEN if won else KidUI.RED)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var subtitle := MenuKit.label("%s   %s" % [str(result.get("title", "BATTLE")), OperationCatalog.mode_name(str(result.get("mode", "crush")))], 22, Color(0.75, 0.88, 1.0))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)
    var stars := MenuKit.stars(int(result.get("stars", 0)), 64.0)
    stars.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(stars)
    _pop_stars(stars)
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 26)
    grid.add_theme_constant_override("v_separation", 4)
    column.add_child(grid)
    var rows: Array[Array] = [
        ["CRUSHED", str(int(result.get("crushed", 0)))],
        ["HEADSHOTS", str(int(result.get("headshots", 0)))],
        ["BEST COMBO", str(int(result.get("best_combo", 0)))],
        ["STYLE POINTS", str(int(result.get("style_points", 0)))],
        ["TIME", format_time(float(result.get("time", 0.0)))],
        ["ACCURACY", "%d%%" % int(float(result.get("accuracy", 0.0)) * 100.0)],
        ["CRUSH MOVES", str(int(result.get("crushes", 0)))],
        ["PERFECT DODGES", str(int(result.get("perfect_dodges", 0)))]
    ]
    for entry in rows:
        grid.add_child(MenuKit.label(str(entry[0]), 18, Color(0.75, 0.88, 1.0)))
        var value := MenuKit.label(str(entry[1]), 22)
        value.custom_minimum_size = Vector2(110, 0)
        grid.add_child(value)
    var rewards := HBoxContainer.new()
    rewards.alignment = BoxContainer.ALIGNMENT_CENTER
    rewards.add_theme_constant_override("separation", 20)
    column.add_child(rewards)
    var xp_chip := MenuKit.chip("bolt", "+0 XP", KidUI.BLUE)
    var coin_chip := MenuKit.chip("coin", "+0", KidUI.GOLD)
    rewards.add_child(xp_chip)
    rewards.add_child(coin_chip)
    _count_up(xp_chip, int(result.get("xp", 0)), " XP")
    _count_up(coin_chip, int(result.get("coins", 0)), "")
    if rank_after > rank_before:
        var unlocks := unlocks_at_rank(rank_after)
        var text := "RANK UP!   RANK %d   %s" % [rank_after, PlayerProgress.rank_title(rank_after)]
        if not unlocks.is_empty():
            text += "\nNEW: " + ", ".join(unlocks)
        var banner := MenuKit.label(text, 24, KidUI.GOLD)
        banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        column.add_child(banner)
    var buttons := HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 14)
    column.add_child(buttons)
    if won and has_next:
        var next_button := MenuKit.button("NEXT", KidUI.GREEN, Vector2(200, 70), 28)
        next_button.pressed.connect(func(): next_requested.emit())
        buttons.add_child(next_button)
    var retry := MenuKit.button("RETRY", KidUI.ORANGE, Vector2(200, 70), 28)
    retry.pressed.connect(func(): retry_requested.emit())
    buttons.add_child(retry)
    var menu := MenuKit.button("MENU", Color("#4a5a8a"), Vector2(200, 70), 28)
    menu.pressed.connect(func(): menu_requested.emit())
    buttons.add_child(menu)
    if can_double and int(result.get("coins", 0)) > 0:
        _double_button = MenuKit.button("x2 COINS", KidUI.PURPLE, Vector2(220, 70), 26)
        _double_button.pressed.connect(_on_double_pressed)
        buttons.add_child(_double_button)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_card)
    root.add_child(center)
    _card.pivot_offset = _card.size * 0.5
    _card.scale = Vector2(0.85, 0.85)
    _card.modulate.a = 0.0
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_card, "modulate:a", 1.0, 0.25)

func _pop_stars(row: HBoxContainer) -> void:
    var index := 0
    for child in row.get_children():
        var star := child as Control
        if star == null:
            continue
        star.pivot_offset = star.custom_minimum_size * 0.5
        star.scale = Vector2.ZERO
        var tween := create_tween()
        tween.tween_interval(0.35 + 0.25 * float(index))
        tween.tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        index += 1

func _count_up(chip: PanelContainer, amount: int, suffix: String) -> void:
    var value := chip.find_child("Value", true, false) as Label
    if value == null:
        return
    var tween := create_tween()
    tween.tween_method(func(current: float): value.text = "+%d%s" % [int(current), suffix], 0.0, float(amount), 1.1).set_delay(0.5)

func _on_double_pressed() -> void:
    if _double_button != null:
        _double_button.disabled = true
    double_coins_requested.emit()

## Called by main once the rewarded ad has paid out.
func mark_doubled() -> void:
    if _double_button != null:
        _double_button.text = "DOUBLED!"
        _double_button.disabled = true
