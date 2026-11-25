class_name RecordingPlayer
extends RefCounted
## Time-based playback of a recording's transcript segments. Drive it with advance(delta)
## (a view calls it every frame; tests call it directly). Reaching the end marks the
## recording as played in NarrativeState. Audio, if any, is the view's job.

enum State { STOPPED, PLAYING, PAUSED, FINISHED }

var recording: RecordingEntry
var state: State = State.STOPPED
var elapsed: float = 0.0


func _init(rec: RecordingEntry) -> void:
	recording = rec


func play() -> void:
	if state == State.FINISHED:
		elapsed = 0.0  # replay from the start
	if state != State.PLAYING:
		state = State.PLAYING


func pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED


func stop() -> void:
	state = State.STOPPED
	elapsed = 0.0


func advance(delta: float) -> void:
	if state != State.PLAYING or delta <= 0.0:
		return
	elapsed += delta
	if elapsed >= recording.total_seconds():
		elapsed = recording.total_seconds()
		state = State.FINISHED
		NarrativeState.mark_recording_played(recording.id)


## Index of the segment being "spoken" now (the last one once finished).
func current_index() -> int:
	var t := 0.0
	for i in recording.segments.size():
		t += recording.segment_seconds(i)
		if elapsed < t:
			return i
	return recording.segments.size() - 1


## Segments revealed so far, including the current one (nothing before play() has run).
func revealed_segments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == State.STOPPED and elapsed == 0.0:
		return out
	for i in current_index() + 1:
		out.append(recording.segments[i])
	return out
