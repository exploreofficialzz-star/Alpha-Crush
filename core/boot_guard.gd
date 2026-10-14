extends RefCounted
class_name BootGuard

## Crash-loop breaker and breadcrumb log for the start-up sequence.
##
## Why this exists: the game cannot be profiled on every phone, and a script error inside the long start-up
## coroutine (or an out-of-memory kill on a small device) used to look like "the game crashes right after
## I pick boy or girl" with no trace left behind. Now every start-up stage is written to user://boot_log.txt
## and to user://boot_state.cfg *before* it runs. If the next launch finds a boot that never finished, the
## game starts in SAFE MODE (lowest graphics tier, no grass, fewer animals) and tells the player so, instead
## of crashing the same way again. A clean boot clears the flag, so safe mode never sticks.

const STATE_FILE := "user://boot_state.cfg"
const LOG_FILE := "user://boot_log.txt"
const MAX_LOG_BYTES := 30000

static var safe_mode := false
static var crashes := 0
static var failed_stage := ""
static var started_msec := 0
static var _finished := false

## Call once, first thing in the main scene.
static func begin() -> void:
    started_msec = Time.get_ticks_msec()
    _finished = false
    var cfg := ConfigFile.new()
    var previous_finished := true
    var previous_stage := ""
    var previous_crashes := 0
    if cfg.load(STATE_FILE) == OK:
        previous_finished = bool(cfg.get_value("boot", "finished", true))
        previous_stage = str(cfg.get_value("boot", "stage", ""))
        previous_crashes = int(cfg.get_value("boot", "crashes", 0))
    if previous_finished:
        crashes = 0
        failed_stage = ""
    else:
        crashes = previous_crashes + 1
        failed_stage = previous_stage
    safe_mode = crashes >= 1
    _trim_log()
    log_line("---- boot begin  version=%s  safe_mode=%s  previous_failure=%s  crashes=%d" % [str(GameConfig.VERSION_NAME), str(safe_mode), failed_stage if failed_stage != "" else "none", crashes])
    log_line("device: %s | %s | %s | ram=%d MB | os=%s" % [OS.get_name(), OS.get_model_name(), RenderingServer.get_video_adapter_name(), int(OS.get_static_memory_usage() / 1048576), OS.get_version()])
    _save_state("begin", false)

## A step that counts: if the process dies while it runs, the next launch enters safe mode.
static func stage(stage_name: String) -> void:
    log_line("stage %s" % stage_name)
    _save_state(stage_name, false)

## A resting point (waiting for the player to tap): quitting here is NOT a crash.
static func rest(stage_name: String) -> void:
    log_line("rest  %s" % stage_name)
    _save_state(stage_name, true)

## The village is on screen and the player can move.
static func finish() -> void:
    if _finished:
        return
    _finished = true
    log_line("boot finished in %d ms" % (Time.get_ticks_msec() - started_msec))
    crashes = 0
    _save_state("done", true)

static func is_finished() -> bool:
    return _finished

static func log_line(text: String) -> void:
    var f := FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
    if f == null:
        f = FileAccess.open(LOG_FILE, FileAccess.WRITE)
    if f == null:
        return
    f.seek_end()
    f.store_line("[%6d ms] %s" % [Time.get_ticks_msec() - started_msec, text])
    f.close()

static func _save_state(stage_name: String, done: bool) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("boot", "stage", stage_name)
    cfg.set_value("boot", "finished", done)
    cfg.set_value("boot", "crashes", crashes)
    cfg.save(STATE_FILE)

static func _trim_log() -> void:
    if not FileAccess.file_exists(LOG_FILE):
        return
    var f := FileAccess.open(LOG_FILE, FileAccess.READ)
    if f == null:
        return
    var size := f.get_length()
    var text := f.get_as_text()
    f.close()
    if size > MAX_LOG_BYTES:
        var keep := text.substr(text.length() - int(MAX_LOG_BYTES / 2))
        var out := FileAccess.open(LOG_FILE, FileAccess.WRITE)
        if out != null:
            out.store_string(keep)
            out.close()
