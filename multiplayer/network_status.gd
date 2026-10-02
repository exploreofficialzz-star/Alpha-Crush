extends RefCounted
class_name NetworkStatus

## Single place that answers "am I playing online right now?".
##
## `node.multiplayer` is null for any node that is outside the scene tree (unit tests,
## tools, nodes not yet added), and since Godot 4.2 an idle tree owns an
## OfflineMultiplayerPeer, so `has_multiplayer_peer()` alone is not a reliable test.

static func is_online(node: Node) -> bool:
    if node == null or not node.is_inside_tree():
        return false
    var api: MultiplayerAPI = node.multiplayer
    if api == null or not api.has_multiplayer_peer():
        return false
    var peer: MultiplayerPeer = api.multiplayer_peer
    if peer == null or peer is OfflineMultiplayerPeer:
        return false
    return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## True when this instance owns the authoritative world: always offline, host when online.
static func is_authority(node: Node) -> bool:
    if not is_online(node):
        return true
    return node.multiplayer.is_server()
