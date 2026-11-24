extends Node
## Registry of all player actors. Gameplay systems (enemy targeting, hazards,
## objectives) query this instead of assuming a single local player.
## Single-player = a registry with one entry. Keys are peer ids.
## Ownership: shared (each peer registers the player actors it knows about).

var _players: Dictionary = {}  # int peer_id -> Node3D


func register(player: Node3D, peer_id: int, actor_id: StringName = &"") -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _players.has(peer_id) and _players[peer_id] != player:
		push_warning("PlayerRegistry: peer %d already has a player registered" % peer_id)
		return false
	_players[peer_id] = player
	if not player.tree_exiting.is_connected(_on_player_exiting.bind(peer_id)):
		player.tree_exiting.connect(_on_player_exiting.bind(peer_id), CONNECT_ONE_SHOT)
	EventBus.publish(Events.PLAYER_REGISTERED, {"peer_id": peer_id, "actor_id": actor_id})
	return true


func unregister(peer_id: int) -> void:
	if _players.erase(peer_id):
		EventBus.publish(Events.PLAYER_UNREGISTERED, {"peer_id": peer_id})


func get_all() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p: Node3D in _players.values():
		if is_instance_valid(p):
			out.append(p)
	return out


func count() -> int:
	return get_all().size()


func get_by_peer(peer_id: int) -> Node3D:
	var p: Node3D = _players.get(peer_id)
	return p if is_instance_valid(p) else null


func get_local() -> Node3D:
	return get_by_peer(Net.local_peer_id())


## Nearest player to a world position, or null if none within max_distance.
func nearest_to(position: Vector3, max_distance: float = INF) -> Node3D:
	var best: Node3D = null
	var best_d2 := max_distance * max_distance if max_distance != INF else INF
	for p in get_all():
		var d2 := p.global_position.distance_squared_to(position)
		if d2 <= best_d2:
			best = p
			best_d2 = d2
	return best


func clear() -> void:
	_players.clear()


func _on_player_exiting(peer_id: int) -> void:
	unregister(peer_id)
