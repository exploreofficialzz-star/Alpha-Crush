extends Node
class_name WorldAuthority

signal world_change_committed(object_id: String, state: String)

var authoritative := false
var world_state: WorldState
var allowed_words: Dictionary = {}

func _ready() -> void:
    _load_allowed_words()

func _load_allowed_words() -> void:
    if not allowed_words.is_empty():
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/words/words.json"))
    if parsed is Array:
        for entry in parsed:
            if entry is Dictionary:
                var word_id := str(entry.get("id", "")).to_upper()
                if not word_id.is_empty():
                    allowed_words[word_id] = true

func configure(state: WorldState) -> void:
    world_state = state
    authoritative = NetworkStatus.is_online(self) and multiplayer.is_server()
    _load_allowed_words()

func can_commit_world_change() -> bool:
    # Authority is evaluated dynamically because the multiplayer peer can be
    # installed after this service is constructed.
    return NetworkStatus.is_authority(self)

func _is_valid_word_change(object_id: String, state: String) -> bool:
    if not object_id.begins_with("word_") or state != "COMPLETE":
        return false
    var normalized := object_id.substr(5).to_upper()
    return allowed_words.has(normalized)

func commit(object_id: String, state: String) -> bool:
    if not can_commit_world_change() or world_state == null or not _is_valid_word_change(object_id, state):
        return false
    if world_state.is_complete(object_id):
        return false
    world_state.set_state(object_id, state)
    if NetworkStatus.is_online(self):
        # call_local: the broadcast also runs on this (host) peer and emits the signal there,
        # so emitting again here would apply the world change and its rewards twice.
        _broadcast_world_change.rpc(object_id, state)
    else:
        world_change_committed.emit(object_id, state)
    return true

func request(object_id: String, state: String) -> void:
    if NetworkStatus.is_authority(self):
        commit(object_id, state)
        return
    _request_world_change.rpc_id(1, object_id, state)

@rpc("any_peer", "reliable")
func _request_world_change(object_id: String, state: String) -> void:
    if NetworkStatus.is_online(self) and multiplayer.is_server() and _is_valid_word_change(object_id, state):
        commit(object_id, state)

@rpc("authority", "call_local", "reliable")
func _broadcast_world_change(object_id: String, state: String) -> void:
    if world_state:
        world_state.set_state(object_id, state)
    world_change_committed.emit(object_id, state)
