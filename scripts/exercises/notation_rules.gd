class_name NotationRules

# Shared notation post-processing used by Practice Drills and QA:
# - terminal tonic resolution
# - terminal duration shaping

static func apply_tonic_resolution_inplace(staff_notes: Array, key_pc: int, key_is_minor: bool, beats_per_bar: float, staff: int, voice: int) -> void:
	_remove_terminal_rests_after_last_playable(staff_notes)
	var last_idx := -1
	for i in range(staff_notes.size() - 1, -1, -1):
		var n: Dictionary = staff_notes[i]
		if int(n.get("midi", -1)) >= 0 and not bool(n.get("rest", false)):
			last_idx = i
			break
	if last_idx < 0:
		return
	var last: Dictionary = staff_notes[last_idx]
	var last_midi: int = int(last["midi"])
	var last_start: float = float(last.get("beat_offset", 0.0))
	var last_dur: float = float(last.get("duration_beats", 0.0))
	var last_end: float = last_start + last_dur
	var tonic_pc: int = ((key_pc % 12) + 12) % 12
	var third_pc: int = (tonic_pc + (3 if key_is_minor else 4)) % 12
	var fifth_pc: int = (tonic_pc + 7) % 12
	var last_pc: int = ((last_midi % 12) + 12) % 12
	var is_triad_tone: bool = (last_pc == tonic_pc or last_pc == third_pc or last_pc == fifth_pc)
	if is_triad_tone:
		complete_bars_inplace(staff_notes, beats_per_bar, staff, voice)
		return
	var current_bar_end: float = ceil(last_end / beats_per_bar) * beats_per_bar
	if current_bar_end - last_end < 0.001:
		var new_bar_start: float = current_bar_end
		staff_notes.append(make_tonic_note(key_pc, last_midi, new_bar_start, beats_per_bar, staff, voice))
	else:
		var remaining: float = current_bar_end - last_end
		staff_notes.append(make_tonic_note(key_pc, last_midi, last_end, remaining, staff, voice))
	complete_bars_inplace(staff_notes, beats_per_bar, staff, voice)


static func complete_bars_inplace(staff_notes: Array, beats_per_bar: float, staff: int, voice: int) -> void:
	if staff_notes.is_empty() or beats_per_bar <= 0.0:
		return
	_remove_terminal_rests_after_last_playable(staff_notes)
	var last_start := -1.0
	for note_any in staff_notes:
		var note: Dictionary = note_any
		if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
			last_start = maxf(last_start, float(note.get("beat_offset", 0.0)))
	if last_start < 0.0:
		return
	var last_end := last_start
	for note_any in staff_notes:
		var note: Dictionary = note_any
		if absf(float(note.get("beat_offset", 0.0)) - last_start) <= 0.001 and int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
			last_end = maxf(last_end, last_start + float(note.get("duration_beats", 0.0)))
	# Round the existing final event end up to its meter boundary. Subtracting
	# epsilon keeps an event that already lands on a bar line unchanged.
	var final_bar_end: float = ceil((last_end - 0.001) / beats_per_bar) * beats_per_bar
	if final_bar_end <= last_start + 0.001:
		final_bar_end = last_start + beats_per_bar
	for note_any in staff_notes:
		var note: Dictionary = note_any
		if absf(float(note.get("beat_offset", 0.0)) - last_start) <= 0.001 and int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
			note["duration_beats"] = final_bar_end - last_start
	_fill_internal_gaps_with_rests_inplace(staff_notes, final_bar_end, beats_per_bar, staff, voice)


static func _fill_internal_gaps_with_rests_inplace(staff_notes: Array, final_bar_end: float, beats_per_bar: float, staff: int, voice: int) -> void:
	var sorted_notes := staff_notes.duplicate()
	sorted_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("beat_offset", 0.0)) < float(b.get("beat_offset", 0.0))
	)
	var cursor := 0.0
	var gap_rests: Array = []
	for note_any in sorted_notes:
		var note: Dictionary = note_any
		var note_start := float(note.get("beat_offset", 0.0))
		if note_start > cursor + 0.001:
			_append_gap_rests(gap_rests, cursor, note_start, beats_per_bar, staff, voice)
		cursor = maxf(cursor, note_start + float(note.get("duration_beats", 0.0)))
	if cursor < final_bar_end - 0.001:
		_append_gap_rests(gap_rests, cursor, final_bar_end, beats_per_bar, staff, voice)
	staff_notes.append_array(gap_rests)
	staff_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_offset := float(a.get("beat_offset", 0.0))
		var b_offset := float(b.get("beat_offset", 0.0))
		if absf(a_offset - b_offset) > 0.001:
			return a_offset < b_offset
		return int(a.get("midi", -1)) < int(b.get("midi", -1))
	)


static func _append_gap_rests(out_rests: Array, gap_start: float, gap_end: float, beats_per_bar: float, staff: int, voice: int) -> void:
	var beat: float = gap_start
	while beat < gap_end - 0.001:
		var bar_end: float = (floor((beat + 0.001) / beats_per_bar) + 1.0) * beats_per_bar
		var remaining: float = minf(gap_end, bar_end) - beat
		var duration: float = _largest_rest_duration_for_remaining(remaining)
		out_rests.append({
			"midi": -1,
			"beat_offset": beat,
			"duration_beats": duration,
			"rest": true,
			"staff": staff,
			"voice": voice,
		})
		beat += duration


static func _largest_rest_duration_for_remaining(remaining: float) -> float:
	for duration: float in [4.0, 2.0, 1.0, 0.5, 0.25]:
		if duration <= remaining + 0.001:
			return duration
	return remaining


static func make_tonic_note(key_pc: int, reference_midi: int, beat_offset: float, duration_beats: float, staff: int, voice: int) -> Dictionary:
	var pc := ((key_pc % 12) + 12) % 12
	var ref_pc := ((reference_midi % 12) + 12) % 12
	var down_steps := ((ref_pc - pc) + 12) % 12
	var tonic_below := reference_midi - down_steps
	var tonic_above := tonic_below + 12
	var pick_above := (reference_midi - tonic_below) > (tonic_above - reference_midi)
	var tonic_midi: int = tonic_above if pick_above else tonic_below
	return {
		"midi": tonic_midi,
		"beat_offset": beat_offset,
		"duration_beats": duration_beats,
		"staff": staff,
		"voice": voice,
		"fingering": 0,
	}


static func _remove_terminal_rests_after_last_playable(staff_notes: Array) -> void:
	var last_playable_idx := -1
	for i in range(staff_notes.size() - 1, -1, -1):
		var n: Dictionary = staff_notes[i]
		if int(n.get("midi", -1)) >= 0 and not bool(n.get("rest", false)):
			last_playable_idx = i
			break
	if last_playable_idx < 0:
		return
	for i in range(staff_notes.size() - 1, last_playable_idx, -1):
		var n: Dictionary = staff_notes[i]
		if int(n.get("midi", -1)) < 0 or bool(n.get("rest", false)):
			staff_notes.remove_at(i)
