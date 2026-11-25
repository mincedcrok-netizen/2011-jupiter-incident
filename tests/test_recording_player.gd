extends NarrativeTestCase


func _player(id: StringName = &"test_recording_cassette") -> RecordingPlayer:
	NarrativeState.unlock_recording(id)
	return RecordingPlayer.new(NarrativeDatabase.get_recording(id))


func test_playback_reveals_segments_over_time_and_marks_played() -> void:
	var played := capture(Events.RECORDING_PLAYED)
	var p := _player()
	eq(p.revealed_segments().size(), 0, "nothing shown before play")
	p.play()
	p.advance(0.1)
	eq(p.revealed_segments().size(), 1, "first segment shown immediately")
	p.advance(1.5)
	eq(p.revealed_segments().size(), 1, "still the first segment at 1.6s")
	p.advance(0.5)
	eq(p.revealed_segments().size(), 2, "second segment at 2.1s")
	ok(not NarrativeState.was_recording_played(&"test_recording_cassette"), "not played until it ends")
	p.advance(10.0)
	eq(p.state, RecordingPlayer.State.FINISHED, "finished")
	ok(NarrativeState.was_recording_played(&"test_recording_cassette"), "finishing marks it played")
	eq(played.size(), 1, "played event once")
	eq(p.elapsed, 4.0, "elapsed clamps to the total")


func test_pause_stop_and_replay() -> void:
	var p := _player()
	p.play()
	p.advance(1.0)
	p.pause()
	p.advance(5.0)
	eq(p.elapsed, 1.0, "time does not advance while paused")
	p.play()
	p.advance(1.0)
	eq(p.elapsed, 2.0, "resumes from where it paused")
	p.stop()
	eq(p.elapsed, 0.0, "stop rewinds")
	eq(p.state, RecordingPlayer.State.STOPPED, "stopped")
	p.play()
	p.advance(99.0)
	p.play()
	eq(p.elapsed, 0.0, "playing a finished recording starts over")


func test_bad_deltas_are_ignored() -> void:
	var p := _player()
	p.play()
	p.advance(-3.0)
	p.advance(0.0)
	eq(p.elapsed, 0.0, "negative/zero deltas ignored")
	p.stop()
	p.advance(1.0)
	eq(p.elapsed, 0.0, "advance does nothing unless playing")
