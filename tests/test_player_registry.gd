extends TestCase

var _nodes: Array[Node3D] = []


func before_each() -> void:
	PlayerRegistry.clear()
	EventBus.clear()


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	PlayerRegistry.clear()


func _make(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	tree.root.add_child(n)
	n.global_position = pos
	_nodes.append(n)
	return n


func test_register_and_lookup() -> void:
	var a := _make(Vector3.ZERO)
	ok(PlayerRegistry.register(a, 1), "registered")
	eq(PlayerRegistry.count(), 1, "count")
	ok(PlayerRegistry.get_local() == a, "peer 1 is local in single-player")


func test_duplicate_peer_rejected() -> void:
	var a := _make(Vector3.ZERO)
	var b := _make(Vector3.ONE)
	PlayerRegistry.register(a, 1)
	ok(not PlayerRegistry.register(b, 1), "second player for same peer rejected")


func test_null_rejected() -> void:
	ok(not PlayerRegistry.register(null, 1), "null rejected")


func test_nearest_to_picks_closest_and_respects_max_distance() -> void:
	var near := _make(Vector3(1, 0, 0))
	var far := _make(Vector3(50, 0, 0))
	PlayerRegistry.register(near, 1)
	PlayerRegistry.register(far, 2)
	ok(PlayerRegistry.nearest_to(Vector3.ZERO) == near, "nearest wins")
	ok(PlayerRegistry.nearest_to(Vector3(100, 0, 0)) == far, "other nearest from the other side")
	ok(PlayerRegistry.nearest_to(Vector3(0, 100, 0), 5.0) == null, "none within range")
	PlayerRegistry.clear()
	ok(PlayerRegistry.nearest_to(Vector3.ZERO) == null, "empty registry -> null")


func test_auto_unregister_when_player_leaves_tree() -> void:
	var a := _make(Vector3.ZERO)
	PlayerRegistry.register(a, 1)
	_nodes.erase(a)
	a.get_parent().remove_child(a)
	eq(PlayerRegistry.count(), 0, "unregistered on tree exit")
	a.free()
