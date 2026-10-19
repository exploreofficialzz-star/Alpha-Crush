extends Node
class_name SaveSystem

const SAVE_PATH := "user://alpha_crush_save.json"
const BACKUP_PATH := "user://alpha_crush_save.backup.json"
const TEMP_PATH := "user://alpha_crush_save.tmp.json"
const SAVE_VERSION := 14

signal saved
signal loaded
signal recovery(message: String)

var data: Dictionary = {}
var last_recovery_message := ""

func _ready() -> void:
    load_game()

## Keys that only the old word-adventure game used; they are dropped when an old save is migrated.
const OBSOLETE_KEYS: Array[String] = [
    "world_seed", "player", "progression", "achievements", "inventory", "inventory_capacity", "harvest_state", "world_state",
    "discoveries", "map", "upgrades", "daily", "events", "world_clock", "weather", "opportunities", "campaign", "market_orders",
    "postgame", "word_system", "word_progress"
]

func default_data() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "progress": PlayerProgress.default_state(),
        "consent": {"consent_collected": false, "personalized_ads": false},
        "purchases": {"entitlements": {}},
        "settings": {"quality": "medium", "music": true, "sfx": true, "vibration": true, "text_scale": 1.0, "high_contrast": false, "camera_sensitivity": 1.0,
            "simple_mode": true, "aim_assist": 1.0, "bullet_time": true, "damage_numbers": true},
        "profile": {"display_name": "Recruit"},
        "analytics": {"first_open": Time.get_unix_time_from_system()},
        "session": {"last_save": 0, "clean_shutdown": false}
    }

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        data = default_data()
        loaded.emit()
        return data
    var parsed: Variant = _read_json(SAVE_PATH)
    if typeof(parsed) != TYPE_DICTIONARY:
        var backup: Variant = _read_json(BACKUP_PATH)
        if typeof(backup) == TYPE_DICTIONARY:
            data = migrate(backup)
            last_recovery_message = "Recovered your previous Alpha Crush save."
            recovery.emit(last_recovery_message)
        else:
            data = default_data()
            last_recovery_message = "A fresh save was created because the previous save was unreadable."
            recovery.emit(last_recovery_message)
    else:
        data = migrate(parsed)
    loaded.emit()
    return data

func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return null
    return JSON.parse_string(f.get_as_text())

func migrate(old: Dictionary) -> Dictionary:
    var defaults := default_data()
    var out: Dictionary = defaults.duplicate(true)
    for key in old.keys():
        out[key] = old[key]
    for key in defaults.keys():
        var current: Variant = out[key]
        var fallback: Variant = defaults[key]
        if _is_number(current) and _is_number(fallback):
            # JSON has a single number type, so every saved int comes back as a float.
            # Keep the saved value (e.g. the BASKET capacity bonus) and restore the declared type.
            if typeof(fallback) == TYPE_INT:
                out[key] = int(current)
            continue
        if typeof(current) != typeof(fallback):
            if fallback is Dictionary or fallback is Array:
                out[key] = fallback.duplicate(true)
            else:
                out[key] = fallback
    var version := int(old.get("version", 1))
    if version < 14:
        # 2.x word-adventure save: keep the coins as a welcome bonus (capped), start the combat career fresh, drop the old keys.
        var carried := 0
        var old_inventory: Variant = old.get("inventory", {})
        if old_inventory is Dictionary:
            carried = clampi(int(old_inventory.get("coins", 0)), 0, 1500)
        var career: Dictionary = PlayerProgress.default_state()
        career["coins"] = int(career["coins"]) + carried
        out["progress"] = career
        for key in OBSOLETE_KEYS:
            out.erase(key)
        if not out.has("profile") or typeof(out["profile"]) != TYPE_DICTIONARY:
            out["profile"] = default_data()["profile"]
    out["version"] = SAVE_VERSION
    return out

func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func save_game() -> void:
    data["version"] = SAVE_VERSION
    var session: Dictionary = data.get("session", {}).duplicate(true)
    session["last_save"] = Time.get_unix_time_from_system()
    if not session.has("clean_shutdown"):
        session["clean_shutdown"] = false
    data["session"] = session
    var payload := JSON.stringify(data)
    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        recovery.emit("Save failed: could not create the temporary save file.")
        return
    temp.store_string(payload)
    temp.flush()
    temp.close()
    var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
    var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)
    var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):
            var remove_error := DirAccess.remove_absolute(backup_absolute)
            if remove_error != OK:
                recovery.emit("Save failed: could not rotate the previous backup.")
                return
        var backup_error := DirAccess.rename_absolute(save_absolute, backup_absolute)
        if backup_error != OK:
            recovery.emit("Save failed: could not preserve the previous save.")
            return
    var commit_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
    if commit_error != OK:
        if FileAccess.file_exists(BACKUP_PATH) and not FileAccess.file_exists(SAVE_PATH):
            DirAccess.rename_absolute(backup_absolute, save_absolute)
        recovery.emit("Save failed: the new save could not be committed.")
        return
    saved.emit()
