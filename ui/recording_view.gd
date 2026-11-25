class_name RecordingView
extends Control
## Recording player: timed transcript with play/pause. Plays the audio file too if the
## recording names one that exists; otherwise it is transcript-only (never an error).

var player: RecordingPlayer = null
var _title: Label
var _meta: Label
var _status: Label
var _transcript: Label
var _progress: Label
var _play_button: Button
var _audio: AudioStreamPlayer
var _rec_blink: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := RetroStyle.centered_panel(Vector2(0.6, 0.7))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = RetroStyle.label("", 22, RetroStyle.ACCENT)
	_meta = RetroStyle.label("", 13, RetroStyle.DIM)
	_status = RetroStyle.label("", 13, RetroStyle.WARN)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_transcript = RetroStyle.label("", 17)
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_transcript)
	_progress = RetroStyle.label("", 14, RetroStyle.DIM)
	var row := HBoxContainer.new()
	_play_button = RetroStyle.button("Pause")
	_play_button.pressed.connect(toggle_play)
	var close := RetroStyle.button("Close  [Esc]")
	close.pressed.connect(close_view)
	row.add_child(_play_button)
	row.add_child(close)
	for n in [_title, _meta, _status, scroll, _progress, row]:
		box.add_child(n)
	panel.add_child(RetroStyle.scanlines())
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


func is_open() -> bool:
	return visible


func title_text() -> String:
	return _title.text


func transcript_text() -> String:
	return _transcript.text


func status_text() -> String:
	return _status.text


func open_recording(id: StringName) -> bool:
	var rec := NarrativeDatabase.get_recording(id)
	if rec == null or not NarrativeState.is_recording_unlocked(id):
		return false
	close_view()
	player = RecordingPlayer.new(rec)
	_title.text = "● %s" % rec.title
	var kinds := {"cassette": "AUDIO CASSETTE", "dashcam": "DASHCAM FOOTAGE", "black_box": "BLACK-BOX TRANSCRIPT"}
	var parts: Array[String] = [kinds.get(rec.kind, rec.kind)]
	if rec.in_world_date != "":
		parts.append(rec.in_world_date)
	_meta.text = "  |  ".join(parts)
	_status.text = ""
	_audio.stream = null
	if rec.audio != "":
		var stream := load(rec.audio) as AudioStream if ResourceLoader.exists(rec.audio) else null
		if stream != null:
			_audio.stream = stream
		else:
			_status.text = "[audio unavailable: transcript only]"
	GameManager.push_modal("recording")
	visible = true
	player.play()
	if _audio.stream != null:
		_audio.play()
	_refresh()
	return true


func toggle_play() -> void:
	if player == null:
		return
	if player.state == RecordingPlayer.State.PLAYING:
		player.pause()
		_audio.stream_paused = true
	else:
		player.play()
		_audio.stream_paused = false
		if _audio.stream != null and not _audio.playing:
			_audio.play()
	_refresh()


func close_view() -> void:
	if not visible:
		return
	_audio.stop()
	player = null
	visible = false
	GameManager.pop_modal("recording")


func _process(delta: float) -> void:
	if not visible or player == null:
		return
	player.advance(delta)
	_rec_blink += delta
	_title.modulate.a = 1.0 if int(_rec_blink * 2.0) % 2 == 0 else 0.6
	_refresh()


func _refresh() -> void:
	if player == null:
		return
	var lines: Array[String] = []
	for seg: Dictionary in player.revealed_segments():
		var who: String = seg["speaker"]
		lines.append(("%s: %s" % [RetroStyle.character_name(who), seg["text"]]) if who != "" else seg["text"])
	_transcript.text = "\n\n".join(lines)
	_progress.text = "%s / %s" % [RetroStyle.mmss(player.elapsed), RetroStyle.mmss(player.recording.total_seconds())]
	match player.state:
		RecordingPlayer.State.PLAYING: _play_button.text = "Pause"
		RecordingPlayer.State.FINISHED: _play_button.text = "Replay"
		_: _play_button.text = "Play"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.PAUSE):
		close_view()
		get_viewport().set_input_as_handled()
