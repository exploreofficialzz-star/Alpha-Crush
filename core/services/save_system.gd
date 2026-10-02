extends Node
class_name SaveSystem

const SAVE_PATH := "user://alpha_crush_save.json"
const BACKUP_PATH := "user://alpha_crush_save.backup.json"
const TEMP_PATH := "user://alpha_crush_save.tmp.json"
const SAVE_VERSION := 13

signal saved
signal loaded
signal recovery(message: String)

var data: Dictionary = {}
var last_recovery_message := ""

func _ready() -> void:
    load_game()

func default_data() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "world_seed": GameConfig.WORLD_SEED,
        "player": {"position": [0.0, 1.2, 10.0], "customization": {"style": "default"}},
        "progression": {"level": 1, "xp": 0},
        "achievements": {"progress": {}, "claimed": {}},
        "inventory": {"coins": GameConfig.STARTING_COINS, "gems": 0},
        "inventory_capacity": GameConfig.MAX_INVENTORY_SLOTS,
        "harvest_state": {},
        "consent": {"consent_collected": false, "personalized_ads": false},
        "purchases": {"entitlements": {}},
        "world_state": {},
        "discoveries": [],
        "map": [],
        "upgrades": {},
        "daily": {},
        "events": {},
        "world_clock": {"elapsed": 0.0, "period": "morning"},
        "weather": {"weather": "clear", "timer": 0.0},
        "settings": {"quality": "medium", "music": true, "sfx": true, "vibration": true, "text_scale": 1.0, "high_contrast": false, "camera_sensitivity": 1.0},
        "profile": {"display_name": "Explorer", "avatar_style": "default", "outfit": "field_jacket", "backpack": "starter_pack", "emotes": ["wave", "celebrate"]},
        "opportunities": {},
        "campaign": {"current_index": 0, "completed": {}, "finale_ready": false, "finale_done": false, "postgame_unlocked": false},
        "market_orders": {"active_order": {}, "sequence": 0},
        "postgame": {"completed": {}, "active_id": "", "cycle": 0},
        "word_system": {"active_word": "", "collected": {}, "completed": {}, "history": []},
        "word_progress": {},
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
    if version < 2:
        if not out.has("progression"): out["progression"] = {"level": 1, "xp": 0}
    if version < 3:
        if not out.has("discoveries"): out["discoveries"] = []
        if not out.has("upgrades"): out["upgrades"] = {}
    if version < 4:
        if not out.has("map"): out["map"] = []
        if not out.has("daily"): out["daily"] = {}
    if version < 5:
        if not out.has("events"): out["events"] = {}
        if not out.has("settings"): out["settings"] = default_data()["settings"]
    if version < 6:
        if not out.has("session"): out["session"] = {"last_save": 0, "clean_shutdown": false}
        if not out.has("profile"): out["profile"] = default_data()["profile"]
        if not out.has("opportunities"): out["opportunities"] = {}
    if version < 7:
        if not out.has("world_clock"): out["world_clock"] = {"elapsed": 0.0, "period": "morning"}
        if not out.has("weather"): out["weather"] = {"weather": "clear", "timer": 0.0}
    if version < 8:
        if not out.has("achievements"): out["achievements"] = {"progress": {}, "claimed": {}}
    if version < 9:
        if not out.has("inventory_capacity"):
            out["inventory_capacity"] = GameConfig.MAX_INVENTORY_SLOTS
    if version < 10:
        if not out.has("harvest_state"):
            out["harvest_state"] = {}
    if version < 11:
        if not out.has("campaign"):
            out["campaign"] = default_data()["campaign"]
    if version < 12:
        if not out.has("market_orders"):
            out["market_orders"] = default_data()["market_orders"]
    if version < 13:
        if not out.has("postgame"):
            out["postgame"] = default_data()["postgame"]
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
