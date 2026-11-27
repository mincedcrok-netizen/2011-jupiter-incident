extends ShipTestCase


func test_deck_loads_with_all_six_areas_and_no_errors() -> void:
	var ids: Array[String] = []
	for r in tree.get_nodes_in_group("rooms"):
		ids.append(String((r as RoomShell).room_id))
	ids.sort()
	eq(ids, ["bridge", "corridor", "damaged", "engineering", "quarters", "storage"], "all required areas exist")
	for r in tree.get_nodes_in_group("rooms"):
		ok((r as RoomShell).built and (r as RoomShell).piece_count > 10 and (r as RoomShell).trim_count > 5, "%s built its hull (%d pieces, %d trim strips merged into one mesh)" % [(r as RoomShell).room_id, (r as RoomShell).piece_count, (r as RoomShell).trim_count])
		ok((r as RoomShell).get_node_or_null("Trim") is MeshInstance3D, "%s merged its trim into a single mesh" % (r as RoomShell).room_id)
	eq(GameManager.recent_errors(), [] as Array[Dictionary], "no errors or warnings reported while loading the deck")


func test_every_scene_reference_resolves() -> void:
	for path in [DECK, "res://scenes/boot.tscn", "res://gameplay/player/player.tscn", "res://ui/hud.tscn"]:
		ok(ResourceLoader.exists(path) and load(path) is PackedScene, "%s loads" % path)
	eq(load("res://scenes/boot.tscn").instantiate().get("first_scene"), DECK, "boot starts on the ship deck")


func test_rooms_do_not_overlap_and_touch_where_doors_are() -> void:
	var rooms := {}
	for r in tree.get_nodes_in_group("rooms"):
		rooms[String((r as RoomShell).room_id)] = r
	var ids := rooms.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: RoomShell = rooms[ids[i]]
			var b: RoomShell = rooms[ids[j]]
			var ra := Rect2(Vector2(a.global_position.x - a.size.x / 2.0, a.global_position.z - a.size.z / 2.0), Vector2(a.size.x, a.size.z))
			var rb := Rect2(Vector2(b.global_position.x - b.size.x / 2.0, b.global_position.z - b.size.z / 2.0), Vector2(b.size.x, b.size.z))
			ok(not ra.grow(-0.01).intersects(rb.grow(-0.01)), "%s and %s do not overlap" % [ids[i], ids[j]])
	# every door sits on the plane shared by two rooms
	for d in deck.get_node("Doors").get_children():
		if not (d is ShipDoor) or d.sealed:
			continue
		var touching := 0
		for r in rooms.values():
			var rs := r as RoomShell
			var p := rs.to_local(d.global_position)
			var on_x := absf(absf(p.x) - rs.size.x / 2.0) < 0.05 and absf(p.z) < rs.size.z / 2.0
			var on_z := absf(absf(p.z) - rs.size.z / 2.0) < 0.05 and absf(p.x) < rs.size.x / 2.0
			if on_x or on_z:
				touching += 1
		eq(touching, 2, "door '%s' joins exactly two rooms" % d.door_id)


func test_room_shell_validation_rejects_bad_openings() -> void:
	var r := RoomShell.new()
	r.room_id = &"t"
	r.size = Vector3(6, 3.4, 6)
	r.openings = [{"side": "north", "offset": 2.9, "width": 2.4, "height": 2.7}]
	ok(not r.validate().is_empty(), "opening that does not fit the wall is rejected")
	r.openings = [{"side": "north", "offset": 0, "width": 2.4, "height": 9.0}]
	ok(not r.validate().is_empty(), "opening taller than the room is rejected")
	r.openings = [{"side": "north", "offset": -1, "width": 2.0, "height": 2.7}, {"side": "north", "offset": 0.5, "width": 2.0, "height": 2.7}]
	ok(not r.validate().is_empty(), "overlapping openings are rejected")
	r.openings = [{"side": "up", "offset": 0, "width": 2.0, "height": 2.7}]
	r.openings = [{"side": "north", "offset": 0, "width": 2.0, "height": 2.7, "kind": "hatch"}]
	ok(not r.validate().is_empty(), "unknown opening kind is rejected")
	r.openings = [{"side": "north", "offset": 0, "width": 2.0, "height": 2.7}]
	eq(r.validate(), [] as Array[String], "a valid layout passes")
	r.room_id = &""
	ok(not r.validate().is_empty(), "missing room id is rejected")
	r.free()


func test_invalid_room_reports_an_error_and_builds_nothing() -> void:
	var r := RoomShell.new()
	r.room_id = &"bad"
	r.size = Vector3(6, 3.4, 6)
	r.openings = [{"side": "north", "offset": 9.0, "width": 2.4, "height": 2.7}]
	tree.root.add_child(r)
	ok(not r.built, "an invalid room does not half-build")
	ok(GameManager.recent_errors().size() >= 1, "the problem is reported")
	r.queue_free()


func test_all_props_and_interactables_have_known_kinds() -> void:
	eq(GameManager.recent_errors().size(), 0, "no unknown prop/interactable kinds were reported")
	var b := ShipProp.new()
	b.kind = "no_such_prop"
	tree.root.add_child(b)
	ok(GameManager.recent_errors().size() == 1, "an unknown prop kind is reported, not fatal")
	b.queue_free()


func test_render_budget() -> void:
	var meshes := deck.find_children("*", "MeshInstance3D", true, false).size()
	var lights := deck.find_children("*", "OmniLight3D", true, false)
	var shadowed := 0
	for l in lights:
		if (l as OmniLight3D).shadow_enabled:
			shadowed += 1
	ok(meshes < 560, "mesh count stays within budget (%d of 560; hull + props + doors)" % meshes)
	ok(shadowed <= 2, "at most two shadow-casting lights (%d)" % shadowed)
	ok(lights.size() < 60, "light count is bounded (%d)" % lights.size())


func test_small_props_have_a_draw_distance_so_long_sightlines_stay_cheap() -> void:
	var limited := 0
	var total := 0
	for n in deck.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g is MeshInstance3D and not (g.get_parent() is RoomShell) and not (g.get_parent() is ShipDoor) and g.get_parent() != deck.get_node("Backdrop"):
			total += 1
			if g.visibility_range_end > 0.0:
				limited += 1
	ok(total > 200, "many prop meshes checked (%d)" % total)
	ok(float(limited) / float(total) > 0.95, "props and labels are distance-culled (%d of %d)" % [limited, total])
