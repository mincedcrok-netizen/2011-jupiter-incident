class_name ShipDoor
extends Interactable
## A sliding bulkhead door between rooms. The player focuses it (it is an Interactable) and
## presses Interact: unlocked doors open/close, locked ones refuse with feedback. Locks are
## story flags (`door_unlocked:<door_id>`), so terminals, dialogue and events can release
## them through the normal narrative systems, and saves keep them. `sealed` doors never open
## in this slice. Open/closed state itself is not saved (documented limitation).
##
## Place on the plane shared by two RoomShells; local +X is the door's width direction.

signal state_changed(is_open: bool)

@export var door_id: StringName = &""
@export var destination_label: String = ""
@export var locked_by_default: bool = false
@export var sealed: bool = false
@export var lock_reason: String = "The door is locked."
@export var opening_size: Vector2 = Vector2(2.4, 2.7)
@export var slide_seconds: float = 0.45

var is_open: bool = false
var _leaf: MeshInstance3D
var _status: MeshInstance3D
var _status_mat: StandardMaterial3D
var _blocker_shape: CollisionShape3D
var _sensor: Area3D
var _tween: Tween
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	if door_id == &"":
		GameManager.report_error("ship_door", "%s has no door_id" % name)
	if interaction_id == &"":
		interaction_id = StringName("door_%s" % door_id)
	super._ready()
	var w := opening_size.x
	var h := opening_size.y
	# Focus/raycast volume (INTERACTABLE layer; stays enabled so an open door can be closed).
	var focus := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(w, h, 0.5)
	focus.shape = fs
	focus.position = Vector3(0, h / 2.0, 0)
	add_child(focus)
	# Physical blocker (WORLD layer) that really stops the player while closed.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PhysicsLayers.WORLD
	blocker.collision_mask = 0
	_blocker_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, 0.3)
	_blocker_shape.shape = bs
	_blocker_shape.position = Vector3(0, h / 2.0, 0)
	blocker.add_child(_blocker_shape)
	add_child(blocker)
	# Moving leaf; slides up into the lintel (hidden inside the wall mass above the opening).
	_leaf = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(w, h + 0.1, 0.2)
	_leaf.mesh = lm
	_leaf.material_override = ShipMaterials.named(&"metal_light")
	_leaf.position = Vector3(0, (h + 0.1) / 2.0, 0)
	add_child(_leaf)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(w * 0.8, 0.12, 0.21)
	stripe.mesh = sm
	stripe.material_override = ShipMaterials.hazard()
	stripe.position = Vector3(0, 0.3, 0)
	_leaf.add_child(stripe)
	# Status light on the frame: red = locked, green = unlocked.
	_status = MeshInstance3D.new()
	var lgm := BoxMesh.new()
	lgm.size = Vector3(0.14, 0.14, 0.06)
	_status.mesh = lgm
	_status_mat = StandardMaterial3D.new()
	_status_mat.emission_enabled = true
	_status.material_override = _status_mat
	_status.position = Vector3(w / 2.0 + 0.2, 1.5, 0.28)
	add_child(_status)
	# Sensor so a door never closes on the player.
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = PhysicsLayers.PLAYER
	var ss := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(w, h, 1.4)
	ss.shape = sb
	ss.position = Vector3(0, h / 2.0, 0)
	_sensor.add_child(ss)
	add_child(_sensor)
	_audio = AudioStreamPlayer3D.new()
	_audio.max_distance = 25.0
	_audio.unit_size = 6.0
	_audio.bus = ShipAudio.bus_name(&"SFX")
	_audio.position = Vector3(0, h / 2.0, 0)
	add_child(_audio)
	EventBus.subscribe(Events.FLAG_CHANGED, _on_flag_changed)
	_refresh()


func is_locked() -> bool:
	return sealed or (locked_by_default and not GameState.is_flag_true(unlock_flag()))


func unlock_flag() -> StringName:
	return StringName("door_unlocked:%s" % door_id)


func is_doorway_occupied() -> bool:
	return _sensor != null and _sensor.has_overlapping_bodies()


## Opens or closes the door. Returns false when refused (locked, or the doorway is occupied).
func set_open(open: bool, animate: bool = true) -> bool:
	if open == is_open:
		return true
	if open and is_locked():
		return false
	if not open and is_doorway_occupied():
		return false
	is_open = open
	_blocker_shape.set_deferred("disabled", open)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target_y := (opening_size.y + 0.1) / 2.0 + (opening_size.y + 0.1 if open else 0.0)
	if animate:
		_tween = create_tween()
		_tween.tween_property(_leaf, "position:y", target_y, slide_seconds).set_trans(Tween.TRANS_SINE)
	else:
		_leaf.position.y = target_y
	_play(&"door_open" if open else &"door_close")
	_refresh()
	state_changed.emit(open)
	return true


func _on_interacted(_actor: Actor) -> void:
	if is_locked():
		_play(&"door_denied")
		var why := lock_reason if lock_reason != "" else "The door is locked."
		EventBus.publish(Events.NOTIFICATION, {"text": why})
		return
	if not set_open(not is_open) and is_open:
		EventBus.publish(Events.NOTIFICATION, {"text": "The doorway is blocked."})


func _refresh() -> void:
	if is_open:
		prompt_text = "Close door"
	elif is_locked():
		prompt_text = "Locked: %s" % destination_label if destination_label != "" else "Locked"
	else:
		prompt_text = "Open: %s" % destination_label if destination_label != "" else "Open door"
	if _status_mat != null:
		var c := Color(1.0, 0.15, 0.1) if is_locked() else (Color(1.0, 0.7, 0.2) if is_open else Color(0.2, 1.0, 0.4))
		_status_mat.albedo_color = c.darkened(0.5)
		_status_mat.emission = c


func _on_flag_changed(p: Dictionary) -> void:
	if p.get("key") == String(unlock_flag()) and is_inside_tree():
		_refresh()


func _play(sound: StringName) -> void:
	var s := ShipAudio.one_shot(sound)
	if s != null and _audio != null:
		_audio.stream = s
		_audio.play()
