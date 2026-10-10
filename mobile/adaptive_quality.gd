extends Node
class_name AdaptiveQuality

## Watches the frame rate the phone actually achieves and steps graphics down when it cannot keep
## up, so a low-end device settles on a smooth tier by itself. Never steps up (no flip-flopping),
## stops after MAX_STEPS, and does nothing when a parent switched "automatic graphics" off.
signal stepped_down(level: String)

const WARMUP_SECONDS := 10.0
const SAMPLE_SECONDS := 1.0
const WINDOW := 6
const COOLDOWN_SECONDS := 12.0
const MAX_STEPS := 3
const SLOW_FRACTION := 0.72

var quality: QualityManager
var settings: SettingsManager
var enabled := true
var steps_taken := 0
var _elapsed := 0.0
var _sample_timer := 0.0
var _cooldown := 0.0
var _samples: Array[float] = []

func setup(quality_manager: QualityManager, settings_manager: SettingsManager) -> void:
    quality = quality_manager
    settings = settings_manager

## True when the recent average is clearly below what the current tier is meant to deliver.
static func should_step_down(samples: Array[float], target_fps: float) -> bool:
    if samples.is_empty() or target_fps <= 0.0:
        return false
    var total := 0.0
    for sample in samples:
        total += sample
    return total / float(samples.size()) < target_fps * SLOW_FRACTION

func reset_window(extra_cooldown: float = 0.0) -> void:
    _samples.clear()
    _sample_timer = 0.0
    _cooldown = maxf(_cooldown, extra_cooldown)

func _notification(what: int) -> void:
    # Returning from the background looks like a long slow frame; do not judge the phone on it.
    if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
        reset_window(5.0)

func _process(delta: float) -> void:
    if not enabled or quality == null or settings == null:
        return
    if not bool(settings.get_value("auto_quality", true)):
        return
    _elapsed += delta
    _cooldown = maxf(0.0, _cooldown - delta)
    if _elapsed < WARMUP_SECONDS:
        return
    _sample_timer += delta
    if _sample_timer < SAMPLE_SECONDS:
        return
    _sample_timer = 0.0
    _samples.append(float(Engine.get_frames_per_second()))
    while _samples.size() > WINDOW:
        _samples.pop_front()
    if _samples.size() < WINDOW or _cooldown > 0.0 or steps_taken >= MAX_STEPS or quality.is_floor():
        return
    var target := float(quality.current().get("fps", 60))
    if should_step_down(_samples, target):
        var next := quality.lower_level()
        steps_taken += 1
        reset_window(COOLDOWN_SECONDS)
        settings.set_value("quality", next)
        stepped_down.emit(next)
