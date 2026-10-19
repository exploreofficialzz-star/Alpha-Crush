extends Control
class_name TutorialCoach

## First-minute coaching with no words: a pointing hand shows the thumb where to drag, the guide
## arrow leads to the first letter gem, then the big action button pulses with a tapping hand.
## It never blocks input, repeats whenever the child goes idle, and ends the moment the first
## gem is collected.
signal finished

enum Step { OFF, MOVE, COLLECT, ACT, DONE }

const HAND_SIZE := 150.0
const FINGERTIP := Vector2(0.25, 0.12)
const MOVE_GOAL_METERS := 6.0
const REACH_DISTANCE := 3.2

var player: AlphaCrushPlayer
var world: AlphaCrushWorld
var word_system: WordSystem
var joystick: AlphaCrushVirtualJoystick
var act_button: KidTouchButton
var guide: GuideOverlay
var step := Step.OFF
var _hand: TextureRect
var _tween: Tween
var _time := 0.0
var _ripple_at := Vector2.ZERO
var _moved := 0.0
var _last_flat := Vector2.ZERO
var _collected_at_start := 0
var _carried_at_start := 0
var _quiet := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _hand = TextureRect.new()
    _hand.texture = KidUI.icon("pointer")
    _hand.custom_minimum_size = Vector2(HAND_SIZE, HAND_SIZE)
    _hand.size = Vector2(HAND_SIZE, HAND_SIZE)
    _hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hand.visible = false
    add_child(_hand)
    set_process(false)

func is_running() -> bool:
    return step != Step.OFF and step != Step.DONE

## True while the hand is tapping the big action button (the HUD keeps that button pulsing).
func is_pointing_at_action() -> bool:
    return step == Step.ACT

func begin() -> void:
    if player == null or joystick == null or act_button == null:
        return
    _collected_at_start = word_system.total_collected() if word_system != null else 0
    _carried_at_start = player.carried_letters.size()
    _moved = 0.0
    _last_flat = Vector2(player.global_position.x, player.global_position.z)
    set_process(true)
    _enter(Step.MOVE)

func stop() -> void:
    _enter(Step.OFF)
    set_process(false)

func _enter(next: Step) -> void:
    step = next
    _quiet = 0.0
    joystick.attention = next == Step.MOVE
    act_button.attention = next == Step.ACT
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _hand.visible = false
    match next:
        Step.MOVE:
            _play_drag_demo()
        Step.COLLECT:
            if guide != null:
                guide.show_boost(6.0)
        Step.ACT:
            _play_tap_demo()
        Step.DONE:
            joystick.attention = false
            act_button.attention = false
            finished.emit()
            set_process(false)

func _tip_to_position(tip: Vector2) -> Vector2:
    return tip - Vector2(HAND_SIZE, HAND_SIZE) * FINGERTIP

func _play_drag_demo() -> void:
    var rest := joystick.rest_canvas_position()
    var a := _tip_to_position(rest)
    var up := _tip_to_position(rest + Vector2(0, -78))
    var side := _tip_to_position(rest + Vector2(-70, -40))
    _hand.position = a
    _hand.modulate.a = 0.0
    _hand.visible = true
    _tween = create_tween().set_loops()
    _tween.tween_property(_hand, "modulate:a", 1.0, 0.25)
    _tween.tween_property(_hand, "position", up, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_property(_hand, "position", side, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_property(_hand, "position", a, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_property(_hand, "modulate:a", 0.0, 0.2)
    _tween.tween_interval(0.35)

func _play_tap_demo() -> void:
    var tip := act_button.canvas_center() + Vector2(0, 8)
    var resting := _tip_to_position(tip + Vector2(26, 52))
    var tapping := _tip_to_position(tip)
    _hand.position = resting
    _hand.modulate.a = 1.0
    _hand.visible = true
    _tween = create_tween().set_loops()
    _tween.tween_property(_hand, "position", tapping, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_interval(0.18)
    _tween.tween_property(_hand, "position", resting, 0.32).set_trans(Tween.TRANS_SINE)
    _tween.tween_interval(0.35)

func _nearest_letter_distance() -> float:
    var best := INF
    for candidate in world.letters:
        if is_instance_valid(candidate) and not candidate.carried and candidate.is_inside_tree():
            best = minf(best, player.global_position.distance_to(candidate.global_position))
    return best

func _process(delta: float) -> void:
    if step == Step.OFF or step == Step.DONE or player == null:
        return
    _time += delta
    var flat := Vector2(player.global_position.x, player.global_position.z)
    _moved += flat.distance_to(_last_flat)
    _last_flat = flat
    _quiet += delta
    var collected_now := word_system.total_collected() if word_system != null else 0
    var picked_up := collected_now > _collected_at_start or player.carried_letters.size() > _carried_at_start
    match step:
        Step.MOVE:
            if _moved >= MOVE_GOAL_METERS:
                _enter(Step.COLLECT)
            elif picked_up:
                _enter(Step.DONE)
        Step.COLLECT:
            if picked_up:
                _enter(Step.DONE)
            elif _nearest_letter_distance() <= REACH_DISTANCE:
                _enter(Step.ACT)
            elif _quiet > 9.0:
                _quiet = 0.0
                if guide != null:
                    guide.show_boost(5.0)
        Step.ACT:
            if picked_up:
                _enter(Step.DONE)
            elif _nearest_letter_distance() > REACH_DISTANCE * 2.0:
                _enter(Step.COLLECT)
    queue_redraw()

func _draw() -> void:
    if step != Step.ACT or not _hand.visible:
        return
    var center := act_button.canvas_center()
    var phase := fmod(_time * 1.6, 1.0)
    draw_arc(center, act_button.radius + 14.0 + phase * 30.0, 0.0, TAU, 48, Color(1, 1, 1, 0.7 * (1.0 - phase)), 5.0, true)
