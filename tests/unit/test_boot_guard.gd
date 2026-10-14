extends RefCounted
class_name TestBootGuard

## A start-up that never finished must put the next launch into safe mode, a clean one must clear it,
## and a resting point (waiting on the character select screen) must never count as a crash.
static func _write_state(stage_name: String, done: bool, crash_count: int) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("boot", "stage", stage_name)
    cfg.set_value("boot", "finished", done)
    cfg.set_value("boot", "crashes", crash_count)
    cfg.save(BootGuard.STATE_FILE)

static func run() -> bool:
    _write_state("world_build", false, 0)
    BootGuard.begin()
    var detects_crash := BootGuard.safe_mode and BootGuard.failed_stage == "world_build" and BootGuard.crashes == 1
    BootGuard.finish()
    BootGuard.begin()
    var clears_after_clean_boot := not BootGuard.safe_mode and BootGuard.failed_stage == ""
    BootGuard.rest("character_select")
    BootGuard.begin()
    var rest_is_not_a_crash := not BootGuard.safe_mode
    _write_state("services", false, 1)
    BootGuard.begin()
    var repeated := BootGuard.safe_mode and BootGuard.crashes == 2
    BootGuard.finish()
    return detects_crash and clears_after_clean_boot and rest_is_not_a_crash and repeated and BootGuard.is_finished()
