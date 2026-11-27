extends ShipTestCase

const CELL := 0.5


func test_player_spawns_safely_in_the_corridor_facing_the_bridge() -> void:
	await physics(30)
	ok(player.is_on_floor(), "spawn is on the floor")
	ok(room("corridor").contains_point(player.global_position), "spawn is inside the main corridor")
	ok(player.global_transform.basis.z.z > 0.9, "facing north (toward the bridge)")


func test_walls_hold_the_player_in() -> void:
	teleport(Vector3(0, 0.05, 0), 90)  # facing west, wall at x=-2.1 (no door at z=0)
	await physics(4)
	Input.action_press(InputActions.SPRINT)
	await walk_to(Vector3(-6, 0.05, 0), 0.5, 200)
	Input.action_release(InputActions.SPRINT)
	ok(player.global_position.x > -2.2, "the west wall stopped the player (x=%.2f)" % player.global_position.x)


func test_player_cannot_walk_off_the_end_of_the_ship() -> void:
	open_all_doors()
	teleport(Vector3(0, 0.05, 45), 180)
	await physics(4)
	Input.action_press(InputActions.SPRINT)
	await walk_to(Vector3(0, 0.05, 60), 0.5, 300)
	Input.action_release(InputActions.SPRINT)
	ok(player.global_position.z < 49.6, "the sealed engine core door holds (z=%.2f)" % player.global_position.z)


func test_the_player_really_walks_every_route_through_every_door() -> void:
	var visited := {}
	EventBus.subscribe(Events.AREA_ENTERED, func(p: Dictionary) -> void: visited[p["trigger_id"]] = true)
	GameState.set_flag(&"door_unlocked:section_b", true)
	var route := [
		[Vector3(0, 0.05, -17), "", ""], [Vector3(1.8, 0.05, -25.5), "bridge", "room_bridge"],
		[Vector3(0, 0.05, -17), "", ""], [Vector3(-1.4, 0.05, -8), "", ""], [Vector3(-6, 0.05, -8), "quarters", "room_quarters"],
		[Vector3(-1.4, 0.05, -8), "", ""], [Vector3(1.4, 0.05, 4), "", ""], [Vector3(6, 0.05, 4), "supply", "room_storage"],
		[Vector3(1.4, 0.05, 4), "", ""], [Vector3(0, 0.05, 17.5), "", ""], [Vector3(0, 0.05, 26), "section_b", "room_damaged"],
		[Vector3(0, 0.05, 31.5), "", ""], [Vector3(0, 0.05, 40), "engineering", "room_engineering"],
		[Vector3(0, 0.05, 46.5), "", ""],
	]
	teleport(Vector3(0, 0.05, 13), 0)
	await physics(4)
	for step in route:
		var door_id: String = step[1]
		var target: Vector3 = step[0]
		if door_id != "":
			# open the door we are standing in front of, then continue through it
			var d := door(door_id)
			if not d.is_open:
				d.set_open(true, false)
			await physics(2)
		var reached := await walk_to(target)
		ok(reached, "reached %s (at %s)" % [str(target), str(player.global_position)])
		if not reached:
			break
	for id in ["room_bridge", "room_quarters", "room_storage", "room_damaged", "room_engineering", "room_corridor"]:
		ok(visited.has(id), "%s trigger fired during the walk" % id)


func test_every_room_and_interactable_is_reachable_by_a_walking_capsule() -> void:
	open_all_doors()
	await physics(3)
	var space := (deck as Node3D).get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = PhysicsLayers.WORLD
	var rooms := tree.get_nodes_in_group("rooms")
	var valid := {}  # Vector2i -> free(bool)
	var min_x := -14.0
	var min_z := -36.0
	var nx := int(28.0 / CELL)
	var nz := int(90.0 / CELL)
	for ix in nx:
		for iz in nz:
			var p := Vector3(min_x + (ix + 0.5) * CELL, 0.0, min_z + (iz + 0.5) * CELL)
			if not _in_walkable_volume(p, rooms):
				continue
			q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.0, 0))
			valid[Vector2i(ix, iz)] = space.intersect_shape(q, 1).is_empty()
	var start := _cell_of(Vector3(0, 0, 13), min_x, min_z)
	ok(valid.get(start, false), "the spawn cell is free")
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if valid.get(n, false) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var free_total := 0
	for k in valid:
		if valid[k]:
			free_total += 1
	var fraction := float(seen.size()) / maxf(1.0, float(free_total))
	ok(free_total > 1500, "a real floor area was sampled (%d free cells)" % free_total)
	ok(fraction >= 0.97, "at least 97%% of walkable floor is connected to the spawn (%.1f%%, %d of %d cells)" % [fraction * 100.0, seen.size(), free_total])
	for r: RoomShell in rooms:
		ok(_reachable_near(r.global_position, 3.0, seen, min_x, min_z), "%s: its centre is reachable" % r.room_id)
	var approachable := 0
	for n in deck.find_children("*", "StaticBody3D", true, false):
		if n is Interactable:
			var found := _reachable_near(n.global_position, 2.2, seen, min_x, min_z)
			ok(found, "interactable '%s' has a reachable standing spot within reach" % (n as Interactable).interaction_id)
			approachable += 1 if found else 0
	ok(approachable >= 18, "all interactables checked (%d)" % approachable)
	for t in tree.get_nodes_in_group("nav_target"):
		ok(_reachable_near(t.global_position, 3.5, seen, min_x, min_z), "nav target '%s' is reachable" % (t as NavTarget).target_id)


func _cell_of(p: Vector3, min_x: float, min_z: float) -> Vector2i:
	return Vector2i(int((p.x - min_x) / CELL), int((p.z - min_z) / CELL))


func _reachable_near(p: Vector3, radius: float, seen: Dictionary, min_x: float, min_z: float) -> bool:
	var c := _cell_of(p, min_x, min_z)
	var span := int(radius / CELL)
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var cell := c + Vector2i(dx, dz)
			var world := Vector3(min_x + (cell.x + 0.5) * CELL, 0, min_z + (cell.y + 0.5) * CELL)
			if seen.has(cell) and Vector2(world.x - p.x, world.z - p.z).length() <= radius:
				return true
	return false


## Inside any room interior, or inside a doorway between rooms.
func _in_walkable_volume(p: Vector3, rooms: Array) -> bool:
	for r: RoomShell in rooms:
		if r.contains_point(p + Vector3(0, 0.5, 0)):
			return true
	for d in deck.get_node("Doors").get_children():
		if d is ShipDoor and not d.sealed:
			var l := (d as Node3D).to_local(p)
			if absf(l.x) <= d.opening_size.x / 2.0 and absf(l.z) <= 0.5:
				return true
	return false
