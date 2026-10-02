extends Node
class_name AlphaPerformanceProfiler

signal sample_ready(fps: float, frame_ms: float, memory_mb: float)

var sample_timer := 0.0
var enabled := true
var low_fps_seconds := 0.0
var last_sample := {}

func _process(delta: float) -> void:
    if not enabled:
        return
    sample_timer += delta
    if Engine.get_frames_per_second() < 30:
        low_fps_seconds += delta
    else:
        low_fps_seconds = maxf(0.0, low_fps_seconds - delta)
    if sample_timer >= 2.0:
        sample_timer = 0.0
        var fps := float(Engine.get_frames_per_second())
        var memory_bytes := float(Performance.get_monitor(Performance.MEMORY_STATIC))
        last_sample = {"fps": fps, "frame_ms": 1000.0 / maxf(fps, 1.0), "memory_mb": memory_bytes / 1048576.0, "low_fps_seconds": low_fps_seconds}
        sample_ready.emit(float(last_sample["fps"]), float(last_sample["frame_ms"]), float(last_sample["memory_mb"]))

func snapshot() -> Dictionary:
    return last_sample.duplicate(true)
