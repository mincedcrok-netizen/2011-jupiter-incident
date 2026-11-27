extends ShipTestCase


func _lights(r: RoomShell) -> Array:
	return r.find_children("*", "OmniLight3D", true, false).filter(func(l: Node) -> bool: return l is FlickerLight)


func test_every_area_is_lit_and_the_damaged_areas_use_emergency_lighting() -> void:
	for r in tree.get_nodes_in_group("rooms"):
		ok(_lights(r as RoomShell).size() >= 2, "%s has real light fixtures" % (r as RoomShell).room_id)
	for id in ["corridor", "damaged", "engineering", "bridge"]:
		var modes := []
		for l in _lights(room(id)):
			modes.append((l as FlickerLight).mode)
		ok("pulse" in modes or "strobe" in modes, "%s has emergency lighting (%s)" % [id, str(modes)])
	var trims := {}
	for z in ShipMaterials.ZONES:
		trims[ShipMaterials.ZONES[z]["trim"].to_html()] = true
	eq(trims.size(), ShipMaterials.ZONES.size(), "every zone has its own colour identity")


func test_light_behaviours() -> void:
	for mode in ["steady", "flicker", "pulse", "strobe", "dying"]:
		var lo := 99.0
		var hi := -1.0
		for i in 2000:
			var e := FlickerLight.energy_at(mode, 1.0, i * 0.01, 0.7)
			lo = minf(lo, e)
			hi = maxf(hi, e)
			ok(e >= 0.0 and e <= 1.05, "%s stays within bounds" % mode) if i % 400 == 0 else null
		if mode == "steady":
			ok(is_equal_approx(lo, hi), "steady never changes")
		else:
			ok(hi - lo > 0.3, "%s visibly varies (%.2f..%.2f)" % [mode, lo, hi])
	eq(FlickerLight.energy_at("flicker", 1.0, 3.3, 0.5), FlickerLight.energy_at("flicker", 1.0, 3.3, 0.5), "deterministic")
	eq(FlickerLight.energy_at("nonsense", 2.0, 1.0), 2.0, "unknown mode falls back to steady")


func test_distant_lights_switch_off_to_bound_the_light_count() -> void:
	var l := _lights(room("corridor"))[0] as FlickerLight
	teleport(l.global_position + Vector3(0, -1.5, 3), 0)
	await physics(3)
	l._check = 0.0
	l._process(0.016)
	ok(l.visible, "a nearby light is on")
	teleport(Vector3(0, 0.05, 47), 180)
	await physics(3)
	l._check = 0.0
	l._process(0.016)
	ok(not l.visible, "a light 60 m away is switched off")


func test_every_sound_the_deck_uses_exists_and_loops_correctly() -> void:
	var names := {}
	for e in deck.find_children("*", "AudioStreamPlayer3D", true, false):
		if e is SpatialEmitter:
			names[String((e as SpatialEmitter).sound)] = true
	for n in ["ship_hum", "door_open", "door_close", "door_denied", "pa_chime", "distant_clank_1", "distant_clank_2", "distant_thump"]:
		names[n] = true
	ok(names.size() >= 8, "the deck uses a variety of sounds (%d)" % names.size())
	for n in names:
		ok(ShipAudio.one_shot(StringName(n)) != null, "sound '%s' loads" % n)
	for n in ["ship_hum", "vent_loop", "electrical_crackle", "alarm_loop"]:
		var s := ShipAudio.loop(StringName(n)) as AudioStreamWAV
		ok(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end > 20000, "'%s' is a looping stream (%d samples)" % [n, s.loop_end if s else 0])
	eq(GameManager.recent_errors().size(), 0, "no missing-sound warnings")


func test_a_missing_sound_degrades_quietly_and_reports_once() -> void:
	ok(ShipAudio.one_shot(&"no_such_sound_xyz") == null, "null for a missing file")
	ok(ShipAudio.one_shot(&"no_such_sound_xyz") == null, "still null")
	eq(GameManager.recent_errors().size(), 1, "reported exactly once")
	var e := SpatialEmitter.new()
	e.sound = &"no_such_sound_xyz"
	deck.add_child(e)
	ok(not e.playing, "an emitter with a missing sound simply stays silent")
	e.queue_free()


func test_audio_buses_exist_and_route_to_master() -> void:
	for b in ShipAudio.BUSES:
		var i := AudioServer.get_bus_index(b)
		ok(i != -1, "bus %s exists" % b)
		if i != -1:
			eq(AudioServer.get_bus_send(i), &"Master", "%s routes to Master" % b)
	var n := AudioServer.bus_count
	ShipAudio.ensure_buses()
	eq(AudioServer.bus_count, n, "ensure_buses is idempotent")


func test_ambience_is_running() -> void:
	await physics(10)
	var amb := deck.get_node("Ambience") as ShipAmbience
	ok(amb.is_hum_playing(), "the machinery hum is playing")
	var emitters := deck.find_children("*", "AudioStreamPlayer3D", true, false).filter(func(n: Node) -> bool: return n is SpatialEmitter)
	ok(emitters.size() >= 8, "positional emitters placed around the ship (%d)" % emitters.size())
	for e in emitters:
		ok((e as SpatialEmitter).stream != null and (e as SpatialEmitter).playing, "emitter %s is playing" % e.name)
	var before := amb.distant_noise_count
	ok(amb.trigger_distant_noise(), "a distant noise can be triggered")
	eq(amb.distant_noise_count, before + 1, "and is counted")


func test_announcements_chime_and_caption() -> void:
	var notes := capture(Events.NOTIFICATION)
	var a := deck.get_node("Announcer") as ShipAnnouncer
	ok(a.announce(), "announces from its message list")
	ok(notes.size() == 1 and String(notes[0]["text"]).begins_with("[PA] "), "caption shown as '[PA] ...'")
	ok(a._player.stream != null, "with a chime sound assigned")
	var empty := ShipAnnouncer.new()
	ok(not empty.announce(), "no messages -> nothing to say, no crash")
	empty.free()


func test_door_sounds_are_wired() -> void:
	var d := door("bridge")
	d.set_open(true, false)
	ok(d._audio.stream != null and d._audio.playing, "opening plays the door sound")
	door("section_b").try_interact(player)
	ok(door("section_b")._audio.stream == ShipAudio.one_shot(&"door_denied"), "a locked door plays the denied beep")


func test_the_mixer_actually_produces_sound() -> void:
	await physics(5)
	await tree.create_timer(0.6).timeout
	var idx := AudioServer.get_bus_index(&"Ambience")
	var peak := maxf(AudioServer.get_bus_peak_volume_left_db(idx, 0), AudioServer.get_bus_peak_volume_right_db(idx, 0))
	ok(peak > -70.0, "the Ambience bus carries signal (peak %.1f dB)" % peak)


func test_space_backdrop_and_jupiter_are_visible_from_the_bridge_window() -> void:
	var b := deck.get_node("Backdrop") as SpaceBackdrop
	var env := b.world_environment.environment
	ok(env.background_mode == Environment.BG_SKY and env.fog_enabled, "star sky + fog configured")
	ok(b.jupiter.material_override is ShaderMaterial, "Jupiter has its banded shader")
	var eye := Vector3(0, 1.6, -30)
	var dir := b.jupiter.global_position - eye
	var t := (-34.0 - eye.z) / dir.z  # where the sight line crosses the window plane
	var x := eye.x + dir.x * t
	var y := eye.y + dir.y * t
	ok(absf(x) < 4.0 and y > 0.9 and y < 3.6, "from the helm Jupiter is framed by the window (x=%.1f, y=%.1f)" % [x, y])


func test_room_identification_follows_the_player() -> void:
	var loc := deck.find_children("*", "LocationView", true, false)[0] as LocationView
	for pair in [["bridge", "COMMAND BRIDGE"], ["quarters", "CREW QUARTERS"], ["storage", "SUPPLY ROOM"], ["damaged", "SECTION B (DAMAGED)"], ["engineering", "ENGINEERING ACCESS CORRIDOR"], ["corridor", "DECK A: MAIN CORRIDOR"]]:
		var r := room(pair[0])
		teleport(r.global_position + Vector3(0.3, 0.05, 0.3), 0)
		await physics(6)
		eq(loc.location_text(), "LOCATION: %s" % pair[1], "the tag names the %s" % pair[0])
		eq(loc.banner_text(), pair[1], "and a banner announces it")
		ok(loc.banner_alpha() >= 0.0, "banner fades in")


func test_every_doorway_is_labelled() -> void:
	var labelled := 0
	for r in tree.get_nodes_in_group("rooms"):
		for o: Dictionary in (r as RoomShell).openings:
			if o.get("kind", "door") == "door":
				ok(str(o.get("label", "")) != "", "%s: a doorway has a destination sign" % (r as RoomShell).room_id)
				labelled += 1
	ok(labelled >= 10, "all doorways checked (%d)" % labelled)


func test_the_waypoint_guides_without_a_minimap() -> void:
	var wp := deck.find_children("*", "WaypointView", true, false)[0] as WaypointView
	NarrativeState.set_objective("go", "Go to the bridge", "nav_bridge")
	teleport(Vector3(0, 0.05, 13), 0)
	await physics(4)
	wp.update_marker()
	ok(wp.shown and wp.on_screen, "target ahead: marker on screen")
	ok(wp.label_text.contains("COMMAND BRIDGE") and wp.label_text.contains("m"), "labelled with name and distance ('%s')" % wp.label_text)
	ok(absf(wp.marker_position.x - wp.get_viewport_rect().size.x / 2.0) < 120.0, "marker is near the screen centre when facing it")
	teleport(Vector3(0, 0.05, 13), 180)
	await physics(4)
	wp.update_marker()
	ok(wp.shown and not wp.on_screen, "target behind: marker pinned to the screen edge")
	ok(wp.marker_position.y >= wp.get_viewport_rect().size.y - WaypointView.MARGIN - 1.0, "pinned along the bottom")
	teleport(Vector3(0, 0.05, -26.5), 0)
	await physics(4)
	wp.update_marker()
	ok(not wp.shown, "marker hides on arrival")
	teleport(Vector3(0, 0.05, 13), 0)
	await physics(3)
	GameManager.push_modal("test")
	wp.update_marker()
	ok(not wp.shown, "hidden during dialogue/readers")
	GameManager.pop_modal("test")
	NarrativeState.complete_objective("go")
	wp.update_marker()
	ok(not wp.shown, "completed objectives stop guiding")
	NarrativeState.set_objective("ghost", "Nowhere", "nav_does_not_exist")
	wp.update_marker()
	ok(not wp.shown, "an unknown target hides the marker, no crash")
