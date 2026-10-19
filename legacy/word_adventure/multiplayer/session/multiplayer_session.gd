extends Node
class_name MultiplayerSession

signal avatar_added(peer_id: int)
signal avatar_removed(peer_id: int)
signal session_message(text: String)

var network: NetworkService
var avatars: Dictionary = {}
var local_player: AlphaCrushPlayer
var transform_timer := 0.0
var transform_interval := 0.05

func configure(network_service: NetworkService, player: AlphaCrushPlayer) -> void:
    network = network_service
    local_player = player
    if network:
        network.player_joined.connect(_on_peer_joined)
        network.player_left.connect(_on_peer_left)
        network.status_changed.connect(_on_network_status_changed)

func host() -> bool:
    if network == null:
        return false
    var result := network.host()
    if result != OK:
        session_message.emit("Unable to host session.")
        return false
    return true

func join(address: String) -> bool:
    if network == null:
        return false
    var result := network.join(address)
    if result != OK:
        session_message.emit("Unable to join session.")
        return false
    # The client is not connected yet; avatar spawn is announced only after
    # NetworkService reports a successful connection.
    return true

func leave() -> void:
    if network:
        network.leave()
    for avatar in avatars.values():
        if is_instance_valid(avatar): avatar.queue_free()
    avatars.clear()

func _process(delta: float) -> void:
    if network == null or not network.online or local_player == null:
        return
    transform_timer += delta
    if transform_timer < transform_interval:
        return
    transform_timer = 0.0
    if multiplayer.is_server():
        _broadcast_local_transform(multiplayer.get_unique_id(), local_player.global_position, local_player.rotation)
    elif multiplayer.get_unique_id() > 0:
        _send_transform.rpc_id(1, local_player.global_position, local_player.rotation)

func _on_network_status_changed(online: bool) -> void:
    if online:
        _announce_avatar()

func _announce_avatar() -> void:
    if multiplayer.is_server():
        _broadcast_spawn.rpc(multiplayer.get_unique_id(), local_player.global_position)
    else:
        _request_spawn.rpc_id(1, local_player.global_position)

@rpc("any_peer", "reliable")
func _request_spawn(position_value: Vector3) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    _broadcast_spawn.rpc(sender, position_value)

@rpc("authority", "call_local", "reliable")
func _broadcast_spawn(peer_id: int, position_value: Vector3) -> void:
    if peer_id == multiplayer.get_unique_id():
        return
    if avatars.has(peer_id):
        return
    var avatar := preload("res://multiplayer/session/multiplayer_avatar.gd").new()
    add_child(avatar)
    avatar.setup(peer_id, position_value)
    avatars[peer_id] = avatar
    avatar_added.emit(peer_id)

@rpc("any_peer", "unreliable_ordered")
func _send_transform(position_value: Vector3, rotation_value: Vector3) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    _broadcast_transform.rpc(sender, position_value, rotation_value)

func _broadcast_local_transform(peer_id: int, position_value: Vector3, rotation_value: Vector3) -> void:
    _broadcast_transform.rpc(peer_id, position_value, rotation_value)

@rpc("authority", "unreliable_ordered")
func _broadcast_transform(peer_id: int, position_value: Vector3, rotation_value: Vector3) -> void:
    if peer_id == multiplayer.get_unique_id():
        return
    if avatars.has(peer_id):
        avatars[peer_id].network_update(position_value, rotation_value)

func _on_peer_joined(_peer_id: int) -> void:
    if not multiplayer.is_server() or local_player == null:
        return
    # Broadcast the host avatar plus all already-connected peers so a late joiner
    # receives a complete lightweight session view. Existing peers ignore duplicates.
    _broadcast_spawn.rpc(multiplayer.get_unique_id(), local_player.global_position)
    for existing_id in avatars.keys():
        var avatar := avatars[existing_id] as MultiplayerAvatar
        if is_instance_valid(avatar):
            _broadcast_spawn.rpc(int(existing_id), avatar.global_position)

func _on_peer_left(peer_id: int) -> void:
    if avatars.has(peer_id):
        var avatar = avatars[peer_id]
        if is_instance_valid(avatar):
            avatar.queue_free()
        avatars.erase(peer_id)
        avatar_removed.emit(peer_id)
