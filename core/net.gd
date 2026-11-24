extends Node
## Network-authority shim. Gameplay code asks THIS autoload "am I the authority?"
## instead of touching the multiplayer API, so single-player and co-op share one
## code path. In single-player the local machine is the authority (peer 1).
## Real networking arrives in Phase 7; nothing here opens a socket.


func is_networked() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)


func is_authority() -> bool:
	if not is_networked():
		return true
	return multiplayer.is_server()


func local_peer_id() -> int:
	if not is_networked():
		return 1
	return multiplayer.get_unique_id()
