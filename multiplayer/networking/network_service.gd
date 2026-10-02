extends Node
class_name NetworkService

signal status_changed(online: bool)
signal player_joined(peer_id: int)
signal player_left(peer_id: int)

var online := false
var hosting := false
var peer: ENetMultiplayerPeer

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port: int = 24560, max_players: int = 8) -> int:
    peer = ENetMultiplayerPeer.new()
    var error := peer.create_server(port, max_players)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = peer
    hosting = true
    online = true
    status_changed.emit(true)
    return OK

func join(address: String, port: int = 24560) -> int:
    peer = ENetMultiplayerPeer.new()
    var error := peer.create_client(address, port)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = peer
    hosting = false
    return OK

func leave() -> void:
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
    online = false
    hosting = false
    status_changed.emit(false)

func _on_connected() -> void:
    online = true
    status_changed.emit(true)

func _on_connection_failed() -> void:
    online = false
    status_changed.emit(false)

func _on_server_disconnected() -> void:
    online = false
    status_changed.emit(false)

func _on_peer_connected(peer_id: int) -> void:
    player_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
    player_left.emit(peer_id)
