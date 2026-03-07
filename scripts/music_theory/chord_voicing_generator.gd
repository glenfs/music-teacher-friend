## Generates piano-realistic grand-staff chord voicings for Sight Reading Chords.
## Splits chord tones across treble and bass staves with spacing constraints.
extends RefCounted

# --- Pitch ranges (MIDI-style: C4 = 60) ---
# Bass staff: C2 (36) to E4 (64)
# Treble staff: A3 (57) to C6 (84)
# Overlap zone: A3 (57) to E4 (64)
const BASS_RANGE_LOW := 36   # C2
const BASS_RANGE_HIGH := 64  # E4
const TREBLE_RANGE_LOW := 57 # A3
const TREBLE_RANGE_HIGH := 84 # C6
const MIDDLE_C_MIDI := 60    # C4 - staff split threshold

# Max span from lowest to highest note (in semitones, ~3 octaves)
const MAX_VOICING_SPAN := 36
# Minimum interval between two bass notes below C3 (avoid mud)
const MIN_LOW_BASS_INTERVAL := 5  # a perfect 4th

# Letter-to-base-pitch-class mapping
const LETTER_PC := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const NOTE_LETTERS := ["C", "D", "E", "F", "G", "A", "B"]

# Chord interval definitions (semitones from root)
const CHORD_INTERVALS := {
	"Major": [0, 4, 7],
	"Minor": [0, 3, 7],
	"Diminished": [0, 3, 6],
	"Augmented": [0, 4, 8],
	"Sus2": [0, 2, 7],
	"Sus4": [0, 5, 7],
	"Power": [0, 7],
	"Maj7": [0, 4, 7, 11],
	"Dom7": [0, 4, 7, 10],
	"Min7": [0, 3, 7, 10],
	"Dim7": [0, 3, 6, 9],
	"Half-dim": [0, 3, 6, 10],
	"mMaj7": [0, 3, 7, 11],
	"Aug7": [0, 4, 8, 10],
	"AugMaj7": [0, 4, 8, 11],
	"7sus4": [0, 5, 7, 10],
	"Maj6": [0, 4, 7, 9],
	"Min6": [0, 3, 7, 9],
	"6-9": [0, 4, 7, 9, 14],
	"Dom9": [0, 4, 7, 10, 14],
	"Maj9": [0, 4, 7, 11, 14],
	"Min9": [0, 3, 7, 10, 14],
	"Add9": [0, 4, 7, 14],
}

# Diatonic degree offsets from root for each chord tone.
# Fixes ambiguous interval-to-degree mapping (e.g. tritone = dim5 not aug4).
const CHORD_DEGREES := {
	"Major": [0, 2, 4],
	"Minor": [0, 2, 4],
	"Diminished": [0, 2, 4],
	"Augmented": [0, 2, 4],
	"Sus2": [0, 1, 4],
	"Sus4": [0, 3, 4],
	"Power": [0, 4],
	"Maj7": [0, 2, 4, 6],
	"Dom7": [0, 2, 4, 6],
	"Min7": [0, 2, 4, 6],
	"Dim7": [0, 2, 4, 6],
	"Half-dim": [0, 2, 4, 6],
	"mMaj7": [0, 2, 4, 6],
	"Aug7": [0, 2, 4, 6],
	"AugMaj7": [0, 2, 4, 6],
	"7sus4": [0, 3, 4, 6],
	"Maj6": [0, 2, 4, 5],
	"Min6": [0, 2, 4, 5],
	"6-9": [0, 2, 4, 5, 8],
	"Dom9": [0, 2, 4, 6, 8],
	"Maj9": [0, 2, 4, 6, 8],
	"Min9": [0, 2, 4, 6, 8],
	"Add9": [0, 2, 4, 8],
}

# Treble step sequence: step 0 = F5, step 1 = E5, step 2 = D5 ...
# Bass step sequence: step 0 = A3, step 1 = G3, step 2 = F3 ...
# We use note-to-step mapping for each clef.

# Treble staff: step 0 is top line = F5 (MIDI 77), step 8 is bottom line = E4 (MIDI 64)
# Each step = one diatonic step down. Ledger lines extend above (negative) and below (>8).
# Bass staff: step 0 is top line = A3 (MIDI 57), step 8 is bottom line = B2 (MIDI 47)

const TREBLE_STEP_NOTES := {
	# step: [letter, octave]  — step 0 = top line F5, step 8 = bottom line E4
	-4: ["C", 6], -3: ["B", 5], -2: ["A", 5], -1: ["G", 5],
	0: ["F", 5], 1: ["E", 5], 2: ["D", 5], 3: ["C", 5],
	4: ["B", 4], 5: ["A", 4], 6: ["G", 4], 7: ["F", 4],
	8: ["E", 4], 9: ["D", 4], 10: ["C", 4], 11: ["B", 3], 12: ["A", 3],
}

const BASS_STEP_NOTES := {
	# step: [letter, octave]  — step 0 = top line A3, step 8 = bottom line B2
	-4: ["E", 4], -3: ["D", 4], -2: ["C", 4], -1: ["B", 3],
	0: ["A", 3], 1: ["G", 3], 2: ["F", 3], 3: ["E", 3],
	4: ["D", 3], 5: ["C", 3], 6: ["B", 2], 7: ["A", 2],
	8: ["G", 2], 9: ["F", 2], 10: ["E", 2], 11: ["D", 2], 12: ["C", 2],
}


## Generate a grand-staff voicing for the given chord.
## Returns: { treble_notes: Array[Dict], bass_notes: Array[Dict], all_notes: Array[Dict] }
## Each note dict: { letter: String, octave: int, accidental: int, midi: int, staff: String, step: int }
##
## Piano voicing rules (comfortable playing):
##   Left hand (bass staff): 1-2 notes. Usually bass tone + optional guide/5th.
##   Right hand (treble staff): 2-4 notes in close position.
##   Avoid dense low-register clusters below C3 (MIDI 48).
##   Keep per-hand spans reachable for average players.
const MAX_HAND_SPAN := 10             # 2-note hand stretch: minor 7th
const MAX_THREE_NOTE_SPAN := 10       # 3+ notes in one hand: keep within major 6th/minor 7th
const MAX_ADJACENT_GAP := 7           # practical adjacent-note spacing cap in one hand
const MAX_JAZZ_POP_GLOBAL_SPAN := 26  # two-hand spread cap for grand-staff sight chords
const MAX_JAZZ_POP_LH_NOTES := 2
const MAX_JAZZ_POP_RH_NOTES := 4

static func generate(root_letter: String, root_acc: int, quality: String, inversion: int, sig_map: Dictionary, rng: RandomNumberGenerator, spread: bool = true, seventh_style_layout: bool = false) -> Dictionary:
	var intervals: Array = CHORD_INTERVALS.get(quality, [0, 4, 7])
	var degrees: Array = CHORD_DEGREES.get(quality, [0, 2, 4])
	var root_midi := _letter_to_midi(root_letter, root_acc, 4)

	# Build abstract chord tones (pitch classes + intervals + diatonic degrees)
	var tone_pcs: Array[int] = []
	var tone_intervals: Array[int] = []
	var tone_degrees: Array[int] = []
	for i_tone in range(intervals.size()):
		var iv: int = int(intervals[i_tone])
		tone_pcs.append(posmod(int(root_midi) + iv, 12))
		tone_intervals.append(iv)
		tone_degrees.append(int(degrees[i_tone]) if i_tone < degrees.size() else 0)

	var num_tones := tone_pcs.size()
	var effective_inversion := clampi(inversion, 0, num_tones - 1)

	# --- Pick bass octave ---
	var bass_octave := 3
	if spread:
		bass_octave = rng.randi_range(2, 3)

	# --- Determine left-hand (bass staff) voicing ---
	# The bass note is the inversion bass tone placed in the low register.
	var bass_tone_idx := effective_inversion
	var bass_iv := tone_intervals[bass_tone_idx]
	var bass_midi := _find_nearest_midi_for_pc(tone_pcs[bass_tone_idx],
		_letter_to_midi(root_letter, root_acc, bass_octave) + bass_iv - (12 if bass_iv > 0 and effective_inversion > 0 else 0))
	while bass_midi < BASS_RANGE_LOW:
		bass_midi += 12
	while bass_midi > MIDDLE_C_MIDI:
		bass_midi -= 12
	bass_midi = clampi(bass_midi, BASS_RANGE_LOW, MIDDLE_C_MIDI - 1)

	# LH profile:
	#   - dyads/triads: bass + optional companion
	#   - 7th/6th/9th families: bass + optional guide tone
	#   - in grand-staff sight mode: cap LH to two notes
	var lh_tone_indices: Array[int] = [bass_tone_idx]
	var lh_extra_candidates: Array[int] = []
	for ti in range(num_tones):
		if ti != bass_tone_idx:
			lh_extra_candidates.append(ti)

	if num_tones == 2:
		if not lh_extra_candidates.is_empty():
			var dyad_idx := _pick_lh_companion_index(bass_tone_idx, tone_intervals, quality, lh_extra_candidates, false)
			if dyad_idx >= 0:
				lh_tone_indices.append(dyad_idx)
	elif num_tones == 3:
		var triad_add_prob := 0.70 if seventh_style_layout else 0.55
		if rng.randf() < triad_add_prob and not lh_extra_candidates.is_empty():
			var triad_idx := _pick_lh_companion_index(bass_tone_idx, tone_intervals, quality, lh_extra_candidates, false)
			if triad_idx >= 0:
				lh_tone_indices.append(triad_idx)
	else:
		# 7ths, 6ths, extensions (4+ tones)
		var dense_add_prob := 0.75 if seventh_style_layout else 0.45
		if rng.randf() < dense_add_prob and not lh_extra_candidates.is_empty():
			var guide_idx := _pick_lh_companion_index(bass_tone_idx, tone_intervals, quality, lh_extra_candidates, true)
			if guide_idx >= 0:
				lh_tone_indices.append(guide_idx)

	if seventh_style_layout and lh_tone_indices.size() > MAX_JAZZ_POP_LH_NOTES:
		lh_tone_indices.resize(MAX_JAZZ_POP_LH_NOTES)

	# --- Build LH concrete notes ---
	var concrete_notes: Array[Dictionary] = []
	# Sort LH tones by interval for ascending pitch order
	lh_tone_indices.sort_custom(func(a: int, b: int) -> bool:
		return tone_intervals[a] < tone_intervals[b])

	# Determine max span based on how many LH notes we're placing
	var lh_span_limit: int = MAX_HAND_SPAN if lh_tone_indices.size() <= 2 else MAX_THREE_NOTE_SPAN
	if seventh_style_layout:
		lh_span_limit = MAX_HAND_SPAN

	for li in range(lh_tone_indices.size()):
		var ti: int = lh_tone_indices[li]
		var note_midi: int
		if li == 0:
			note_midi = bass_midi
		else:
			# Place above the bass note, within LH reach
			note_midi = _find_nearest_midi_for_pc(tone_pcs[ti], bass_midi + (tone_intervals[ti] - tone_intervals[bass_tone_idx]))
			if note_midi <= bass_midi:
				note_midi += 12
			# Ensure within LH span limit
			while note_midi - bass_midi > lh_span_limit:
				note_midi -= 12
			# Keep in bass staff range
			while note_midi < BASS_RANGE_LOW:
				note_midi += 12
			# If still exceeds span after range correction, skip this note
			if note_midi - bass_midi > lh_span_limit:
				continue
			note_midi = clampi(note_midi, BASS_RANGE_LOW, BASS_RANGE_HIGH)
		var deg: int = tone_degrees[ti] if ti < tone_degrees.size() else 0
		var info := _midi_to_letter_in_key(note_midi, root_letter, root_acc, deg, sig_map)
		concrete_notes.append({
			"midi": note_midi,
			"letter": info.letter,
			"octave": info.octave,
			"accidental": info.accidental,
			"tone_index": ti,
		})

	# Final LH validation: check adjacent gaps and drop offending notes
	if concrete_notes.size() >= 3:
		concrete_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.midi) < int(b.midi))
		# Check from top down — drop any note that creates too wide a gap
		var validated: Array[Dictionary] = [concrete_notes[0]]
		for vi in range(1, concrete_notes.size()):
			var gap: int = int(concrete_notes[vi].midi) - int(validated[validated.size() - 1].midi)
			if gap <= MAX_ADJACENT_GAP:
				validated.append(concrete_notes[vi])
			# else: skip this note — gap too wide for adjacent fingers
		concrete_notes = validated

	# --- Build RH concrete notes (close voicing within one octave) ---
	# Pack all chord tones into a single octave above middle C.
	# Max 4 RH notes to keep it playable.
	var rh_base_midi := _letter_to_midi(root_letter, root_acc, 4)
	while rh_base_midi < MIDDLE_C_MIDI:
		rh_base_midi += 12
	# For variety, sometimes start an octave higher (keeps things in mid-treble)
	var rh_octave_jump_prob := 0.22 if seventh_style_layout else 0.35
	if rh_base_midi < 65 and rng.randf() < rh_octave_jump_prob:
		rh_base_midi += 12

	var rh_source_indices: Array[int] = []
	for ti in range(num_tones):
		rh_source_indices.append(ti)
	if seventh_style_layout:
		rh_source_indices.sort_custom(func(a: int, b: int) -> bool:
			var ia := _tone_importance_for_quality(int(tone_intervals[a]), quality)
			var ib := _tone_importance_for_quality(int(tone_intervals[b]), quality)
			if ia == ib:
				return int(tone_intervals[a]) < int(tone_intervals[b])
			return ia > ib
		)
		var has_root_lh := false
		for lti in lh_tone_indices:
			if posmod(int(tone_intervals[lti]), 12) == 0:
				has_root_lh = true
				break
		var selected: Array[int] = []
		for src_idx in rh_source_indices:
			if selected.size() >= MAX_JAZZ_POP_RH_NOTES:
				break
			if src_idx == bass_tone_idx and has_root_lh and num_tones >= 4 and selected.size() > 0:
				continue
			selected.append(src_idx)
		if selected.is_empty():
			selected.append(0)
		if not has_root_lh:
			var has_root_selected := false
			for sti in selected:
				if posmod(int(tone_intervals[sti]), 12) == 0:
					has_root_selected = true
					break
			if not has_root_selected:
				for ti2 in range(num_tones):
					if posmod(int(tone_intervals[ti2]), 12) == 0:
						if selected.size() < MAX_JAZZ_POP_RH_NOTES:
							selected.append(ti2)
						elif selected.size() > 0:
							selected[selected.size() - 1] = ti2
						break
		rh_source_indices = selected

	var rh_built: Array[int] = []
	var rh_midi_to_tone_index: Dictionary = {}
	for ti in rh_source_indices:
		var target_midi: int = rh_base_midi + tone_intervals[ti]
		# Wrap into the octave starting at rh_base_midi (close voicing)
		while target_midi >= rh_base_midi + 12:
			target_midi -= 12
		while target_midi < rh_base_midi:
			target_midi += 12
		# Dedup within RH
		if target_midi not in rh_built:
			rh_built.append(target_midi)
			rh_midi_to_tone_index[str(target_midi)] = ti
	rh_built.sort()

	# Cap RH note count
	var rh_note_cap := MAX_JAZZ_POP_RH_NOTES if seventh_style_layout else 4
	while rh_built.size() > rh_note_cap:
		rh_built.pop_back()

	# Final span check — use tighter limit for 3+ notes
	if rh_built.size() >= 2:
		var rh_span_limit: int = MAX_HAND_SPAN if rh_built.size() <= 2 else MAX_THREE_NOTE_SPAN
		while rh_built.size() > 2 and rh_built[rh_built.size() - 1] - rh_built[0] > rh_span_limit:
			rh_built.pop_back()
		# 2-note fallback check
		if rh_built.size() == 2 and rh_built[1] - rh_built[0] > MAX_HAND_SPAN:
			rh_built.pop_back()

	# Clamp to treble range
	for ri in range(rh_built.size()):
		rh_built[ri] = clampi(rh_built[ri], MIDDLE_C_MIDI, TREBLE_RANGE_HIGH)

	# Add RH notes to concrete_notes.
	# In playable profile, if a RH pitch collides with LH, try shifting RH up an octave.
	for midi in rh_built:
		var midi_val: int = int(midi)
		var is_dup := false
		for cn in concrete_notes:
			if int(cn.midi) == midi_val:
				is_dup = true
				break
		if is_dup and seventh_style_layout:
			var shifted := midi_val + 12
			while shifted <= TREBLE_RANGE_HIGH:
				var collides := false
				for cn2 in concrete_notes:
					if int(cn2.midi) == shifted:
						collides = true
						break
				if not collides:
					midi_val = shifted
					is_dup = false
					break
				shifted += 12
		if is_dup:
			continue
		# Find matching tone index for correct letter naming
		var pc := posmod(midi_val, 12)
		var best_ti := int(rh_midi_to_tone_index.get(str(midi), -1))
		if best_ti < 0:
			for ti in range(num_tones):
				if tone_pcs[ti] == pc:
					best_ti = ti
					break
		if best_ti < 0:
			best_ti = 0
		var deg: int = tone_degrees[best_ti] if best_ti < tone_degrees.size() else 0
		var info := _midi_to_letter_in_key(midi_val, root_letter, root_acc, deg, sig_map)
		concrete_notes.append({
			"midi": midi_val,
			"letter": info.letter,
			"octave": info.octave,
			"accidental": info.accidental,
			"tone_index": best_ti,
		})

	# Enforce adjacent-gap constraint within each hand
	_fix_adjacent_gaps(concrete_notes, MIDDLE_C_MIDI, root_letter, root_acc, sig_map)

	# Sort by MIDI pitch (low to high)
	concrete_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.midi) < int(b.midi)
	)
	if seventh_style_layout:
		_compress_voicing_span_for_playability(concrete_notes, MAX_JAZZ_POP_GLOBAL_SPAN, root_letter, root_acc, tone_degrees, sig_map)

	# Validate muddy bass
	_fix_muddy_bass(concrete_notes)
	_sanitize_to_chord_tones(concrete_notes, tone_pcs, tone_degrees, root_letter, root_acc, sig_map)

	# Split across staves
	var treble_notes: Array[Dictionary] = []
	var bass_notes: Array[Dictionary] = []
	for note in concrete_notes:
		var midi: int = int(note.midi)
		var staff := "bass" if midi < MIDDLE_C_MIDI else "treble"
		if midi == MIDDLE_C_MIDI:
			staff = "treble"
		note["staff"] = staff
		note["step"] = _midi_to_staff_step(midi, int(note.accidental), str(note.letter), staff)
		if staff == "treble":
			treble_notes.append(note)
		else:
			bass_notes.append(note)

	# Ensure at least one note per staff
	if treble_notes.is_empty() and bass_notes.size() >= 2:
		var moved: Dictionary = bass_notes.pop_back()
		moved["staff"] = "treble"
		moved["step"] = _midi_to_staff_step(int(moved.midi), int(moved.accidental), str(moved.letter), "treble")
		treble_notes.append(moved)
	elif bass_notes.is_empty() and treble_notes.size() >= 2:
		var moved: Dictionary = treble_notes.pop_front()
		moved["staff"] = "bass"
		moved["step"] = _midi_to_staff_step(int(moved.midi), int(moved.accidental), str(moved.letter), "bass")
		bass_notes.append(moved)

	var all_notes: Array[Dictionary] = []
	all_notes.append_array(bass_notes)
	all_notes.append_array(treble_notes)

	return {
		"treble_notes": treble_notes,
		"bass_notes": bass_notes,
		"all_notes": all_notes,
	}


static func _pick_lh_companion_index(bass_tone_idx: int, tone_intervals: Array[int], quality: String, candidates: Array[int], prefer_guides: bool) -> int:
	var q := quality.to_lower()
	var best_idx := -1
	var best_score := -9999.0
	var bass_iv := int(tone_intervals[bass_tone_idx])
	for ci in candidates:
		var iv_raw := int(tone_intervals[ci])
		var iv := posmod(iv_raw, 12)
		var score := float(_tone_importance_for_quality(iv_raw, quality))
		if prefer_guides:
			if iv == 3 or iv == 4 or iv == 10 or iv == 11:
				score += 24.0
			elif iv == 2 or iv == 5 or iv == 9:
				score += 14.0
			elif iv == 7:
				score += 6.0
		else:
			if iv == 7 or iv == 6 or iv == 8:
				score += 44.0
			elif iv == 3 or iv == 4:
				score += 6.0
		if q.find("sus") >= 0 and (iv == 2 or iv == 5):
			score += 16.0
		if (q.find("dim") >= 0 or q.find("aug") >= 0) and (iv == 6 or iv == 8):
			score += 12.0
		score -= absf(float(iv_raw - bass_iv)) * 0.45
		if score > best_score:
			best_score = score
			best_idx = int(ci)
	return best_idx


static func _tone_importance_for_quality(interval_semitones: int, quality: String) -> int:
	var iv := posmod(interval_semitones, 12)
	var q := quality.to_lower()
	match iv:
		0:
			return 88
		3, 4:
			return 100
		10, 11:
			return 98
		2, 9:
			return 92
		5:
			return 98 if q.find("sus") >= 0 else 74
		6, 8:
			if q.find("dim") >= 0 or q.find("aug") >= 0:
				return 96
			return 76
		7:
			if q.find("power") >= 0:
				return 100
			return 72
		_:
			return 70


static func _compress_voicing_span_for_playability(notes: Array[Dictionary], max_span: int, root_letter: String, root_acc: int, tone_degrees: Array[int], sig_map: Dictionary) -> void:
	if notes.size() < 2:
		return
	for _attempt in range(10):
		notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.midi) < int(b.midi))
		var lo := int(notes[0].midi)
		var hi := int(notes[notes.size() - 1].midi)
		if hi - lo <= max_span:
			break
		var moved := false
		if hi - 12 >= MIDDLE_C_MIDI:
			var top := notes[notes.size() - 1]
			top.midi = hi - 12
			var top_ti := int(top.get("tone_index", 0))
			var top_deg := int(tone_degrees[top_ti]) if top_ti >= 0 and top_ti < tone_degrees.size() else 0
			var top_info := _midi_to_letter_in_key(int(top.midi), root_letter, root_acc, top_deg, sig_map)
			top.letter = top_info.letter
			top.octave = top_info.octave
			top.accidental = top_info.accidental
			notes[notes.size() - 1] = top
			moved = true
		elif lo + 12 < MIDDLE_C_MIDI:
			var bottom := notes[0]
			bottom.midi = lo + 12
			var b_ti := int(bottom.get("tone_index", 0))
			var b_deg := int(tone_degrees[b_ti]) if b_ti >= 0 and b_ti < tone_degrees.size() else 0
			var b_info := _midi_to_letter_in_key(int(bottom.midi), root_letter, root_acc, b_deg, sig_map)
			bottom.letter = b_info.letter
			bottom.octave = b_info.octave
			bottom.accidental = b_info.accidental
			notes[0] = bottom
			moved = true
		if not moved:
			break


static func _sanitize_to_chord_tones(notes: Array[Dictionary], tone_pcs: Array[int], tone_degrees: Array[int], root_letter: String, root_acc: int, sig_map: Dictionary) -> void:
	if notes.is_empty() or tone_pcs.is_empty():
		return
	for i in range(notes.size()):
		var n := notes[i]
		var midi := int(n.get("midi", 60))
		var pc := posmod(midi, 12)
		var has_pc := false
		for tpc in tone_pcs:
			if int(tpc) == pc:
				has_pc = true
				break
		if has_pc:
			continue
		var best_ti := 0
		var best_shift := 0
		var best_dist := 99
		for ti in range(tone_pcs.size()):
			var target_pc := int(tone_pcs[ti])
			var up: int = posmod(target_pc - pc, 12)
			var down: int = up - 12
			var shift: int = down if absi(down) <= absi(up) else up
			var dist: int = absi(shift)
			if dist < best_dist:
				best_dist = dist
				best_ti = ti
				best_shift = shift
		var corrected := midi + best_shift
		while corrected < BASS_RANGE_LOW:
			corrected += 12
		while corrected > TREBLE_RANGE_HIGH:
			corrected -= 12
		var degree := int(tone_degrees[best_ti]) if best_ti >= 0 and best_ti < tone_degrees.size() else 0
		var info := _midi_to_letter_in_key(corrected, root_letter, root_acc, degree, sig_map)
		n["midi"] = corrected
		n["letter"] = info.letter
		n["octave"] = info.octave
		n["accidental"] = info.accidental
		n["tone_index"] = best_ti
		notes[i] = n


## Run 500 random voicings and validate constraints. Returns array of error strings (empty = pass).
static func self_test_500(rng: RandomNumberGenerator) -> Array[String]:
	var errors: Array[String] = []
	var qualities := CHORD_INTERVALS.keys()
	var letters := ["C", "D", "E", "F", "G", "A", "B"]
	var sig_map := {}  # C major (no accidentals)
	for _i in range(500):
		var root := str(letters[rng.randi_range(0, 6)])
		var quality := str(qualities[rng.randi_range(0, qualities.size() - 1)])
		var max_inv: int = CHORD_INTERVALS[quality].size() - 1
		var inv := rng.randi_range(0, max_inv)
		var spread := rng.randf() > 0.3
		var use_playable_profile := rng.randf() > 0.5
		var result := generate(root, 0, quality, inv, sig_map, rng, spread, use_playable_profile)
		var treble: Array = result.get("treble_notes", [])
		var bass: Array = result.get("bass_notes", [])
		var all: Array = result.get("all_notes", [])
		var root_pc := posmod(_letter_to_midi(root, 0, 4), 12)
		var required_pcs: Dictionary = {}
		for iv in CHORD_INTERVALS[quality]:
			required_pcs[str(posmod(root_pc + int(iv), 12))] = true
		if all.size() < 2:
			errors.append("Test %d: %s %s inv %d — fewer than 2 notes" % [_i, root, quality, inv])
			continue
		# Check ranges
		for n in all:
			var midi: int = int(n.midi)
			if midi < BASS_RANGE_LOW or midi > TREBLE_RANGE_HIGH:
				errors.append("Test %d: %s %s — MIDI %d out of range" % [_i, root, quality, midi])
			var pc := posmod(midi, 12)
			if not required_pcs.has(str(pc)):
				errors.append("Test %d: %s %s — non-chord tone MIDI %d (pc %d)" % [_i, root, quality, midi, pc])
		# Check staff assignment
		for n in treble:
			if int(n.midi) < TREBLE_RANGE_LOW - 3:
				errors.append("Test %d: treble note MIDI %d below treble range" % [_i, int(n.midi)])
		for n in bass:
			if int(n.midi) > BASS_RANGE_HIGH + 3:
				errors.append("Test %d: bass note MIDI %d above bass range" % [_i, int(n.midi)])
		# Check span
		var span: int = int(all[all.size() - 1].midi) - int(all[0].midi)
		if span > MAX_VOICING_SPAN + 2:
			errors.append("Test %d: span %d exceeds max %d" % [_i, span, MAX_VOICING_SPAN])
		if use_playable_profile and span > MAX_JAZZ_POP_GLOBAL_SPAN + 2:
			errors.append("Test %d: playable profile span %d exceeds target %d" % [_i, span, MAX_JAZZ_POP_GLOBAL_SPAN])
		# Check at least one note per staff
		if treble.is_empty() or bass.is_empty():
			errors.append("Test %d: %s %s — missing staff (%d treble, %d bass)" % [_i, root, quality, treble.size(), bass.size()])
		# Check per-hand span and adjacent gaps
		for hand_label in ["bass", "treble"]:
			var hand_notes: Array[int] = []
			for n in all:
				if str(n.staff) == hand_label:
					hand_notes.append(int(n.midi))
			if use_playable_profile:
				if hand_label == "bass" and hand_notes.size() > MAX_JAZZ_POP_LH_NOTES:
					errors.append("Test %d: playable profile has %d LH notes (> %d)" % [_i, hand_notes.size(), MAX_JAZZ_POP_LH_NOTES])
				if hand_label == "treble" and hand_notes.size() > MAX_JAZZ_POP_RH_NOTES:
					errors.append("Test %d: playable profile has %d RH notes (> %d)" % [_i, hand_notes.size(), MAX_JAZZ_POP_RH_NOTES])
			if hand_notes.size() >= 2:
				hand_notes.sort()
				var h_span: int = hand_notes[hand_notes.size() - 1] - hand_notes[0]
				var span_limit: int = MAX_HAND_SPAN if hand_notes.size() <= 2 else MAX_THREE_NOTE_SPAN
				if h_span > span_limit + 1:
					errors.append("Test %d: %s %s — %s hand span %d > %d (%d notes)" % [_i, root, quality, hand_label, h_span, span_limit, hand_notes.size()])
				for hi in range(hand_notes.size() - 1):
					var adj_gap: int = hand_notes[hi + 1] - hand_notes[hi]
					if adj_gap > MAX_ADJACENT_GAP + 1:
						errors.append("Test %d: %s %s — %s adjacent gap %d > %d" % [_i, root, quality, hand_label, adj_gap, MAX_ADJACENT_GAP])
	return errors


# --- Internal helpers ---

static func _letter_to_midi(letter: String, accidental: int, octave: int) -> int:
	var pc: int = LETTER_PC.get(letter, 0) + accidental
	return (octave + 1) * 12 + pc


static func _find_nearest_midi_for_pc(pc: int, target_midi: int) -> int:
	# Snap to the nearest MIDI with the requested pitch class.
	# Use octave base via modulo instead of float division to avoid semitone drift.
	var octave_base := target_midi - posmod(target_midi, 12)
	var base := octave_base + posmod(pc, 12)
	if base > target_midi + 6:
		base -= 12
	elif base < target_midi - 6:
		base += 12
	return base


static func _midi_to_letter_in_key(midi: int, _root_letter: String, _root_acc: int, degree_offset: int, _sig_map: Dictionary) -> Dictionary:
	# Determine the letter name based on the root + diatonic degree offset
	var root_idx := NOTE_LETTERS.find(_root_letter)
	if root_idx < 0:
		root_idx = 0
	var letter_idx := posmod(root_idx + degree_offset, 7)
	var letter: String = NOTE_LETTERS[letter_idx]
	# Calculate octave and accidental
	var octave: int = (midi / 12) - 1
	var expected_pc: int = int(LETTER_PC.get(letter, 0))
	var actual_pc: int = posmod(midi, 12)
	var acc: int = actual_pc - expected_pc
	if acc > 6:
		acc -= 12
	elif acc < -6:
		acc += 12
	# Verify octave (letter C-B boundary: C starts new octave in MIDI)
	var recomputed_midi: int = (octave + 1) * 12 + expected_pc + acc
	if recomputed_midi != midi:
		# Adjust octave
		if recomputed_midi > midi:
			octave -= 1
		else:
			octave += 1
	# Simplify double-sharps/flats to enharmonic equivalents for readability.
	# E.g. D## → E, Fbb → Eb. Only respell if |acc| >= 2.
	if acc >= 2 or acc <= -2:
		var respelled := _simplify_enharmonic(letter, octave, acc, midi)
		return respelled
	return {"letter": letter, "octave": octave, "accidental": acc}


static func _simplify_enharmonic(letter: String, octave: int, acc: int, midi: int) -> Dictionary:
	# Search all letter spellings and choose the simplest accidental spelling.
	# This avoids misleading names like A# when the pitch is really B natural.
	var preferred_idx := NOTE_LETTERS.find(letter)
	if preferred_idx < 0:
		preferred_idx = 0
	var best_letter: String = letter
	var best_octave: int = octave
	var best_acc: int = acc
	var best_cost: int = 9999
	for li in range(NOTE_LETTERS.size()):
		var try_letter: String = NOTE_LETTERS[li]
		var try_pc: int = int(LETTER_PC.get(try_letter, 0))
		var try_acc: int = posmod(midi, 12) - try_pc
		if try_acc > 6:
			try_acc -= 12
		elif try_acc < -6:
			try_acc += 12
		var try_octave: int = int((midi - try_pc - try_acc) / 12) - 1
		var recheck: int = (try_octave + 1) * 12 + try_pc + try_acc
		if recheck != midi:
			continue
		var cost: int = (absi(try_acc) * 20) + absi(li - preferred_idx)
		if try_acc == 0:
			cost -= 6
		elif absi(try_acc) == 1:
			cost -= 2
		if cost < best_cost:
			best_cost = cost
			best_letter = try_letter
			best_octave = try_octave
			best_acc = try_acc
	return {"letter": best_letter, "octave": best_octave, "accidental": best_acc}


static func _interval_to_degree(semitones: int) -> int:
	# Map chromatic interval to nearest diatonic degree offset
	var s := posmod(semitones, 12)
	match s:
		0: return 0       # unison
		1: return 1       # minor 2nd
		2: return 1       # major 2nd
		3: return 2       # minor 3rd
		4: return 2       # major 3rd
		5: return 3       # perfect 4th
		6: return 3       # tritone (dim 5th)
		7: return 4       # perfect 5th
		8: return 4       # aug 5th / minor 6th
		9: return 5       # major 6th
		10: return 6      # minor 7th
		11: return 6      # major 7th
	return 0


static func _midi_to_staff_step(midi: int, accidental: int, letter: String, staff: String) -> int:
	# Convert a concrete note to its staff step position.
	var ref_notes: Dictionary = TREBLE_STEP_NOTES if staff == "treble" else BASS_STEP_NOTES
	var base_midi_no_acc := midi - accidental
	for step_val in ref_notes.keys():
		var sn: Array = ref_notes[step_val]
		var sn_letter: String = str(sn[0])
		var sn_octave: int = int(sn[1])
		if sn_letter == letter and sn_octave == (base_midi_no_acc / 12 - 1):
			# Verify the octave matches
			var check_midi := (sn_octave + 1) * 12 + int(LETTER_PC.get(sn_letter, 0))
			if check_midi == base_midi_no_acc:
				return int(step_val)
	# Fallback: compute step from nearest known reference
	# Treble: step 10 = C4 (MIDI 60), Bass: step -2 = C4 (MIDI 60)
	if staff == "treble":
		# Step 10 = C4, each step up (lower number) = one diatonic step up
		var c4_step := 10
		var dist := _diatonic_distance_from_c4(letter, (midi - accidental) / 12 - 1)
		return c4_step - dist
	else:
		# Bass: step -2 = C4, each step up (lower number) = one diatonic step up
		var c4_step := -2
		var dist := _diatonic_distance_from_c4(letter, (midi - accidental) / 12 - 1)
		return c4_step - dist


static func _diatonic_distance_from_c4(letter: String, octave: int) -> int:
	# Returns signed diatonic steps from C4 to the given note
	var letter_idx := NOTE_LETTERS.find(letter)
	if letter_idx < 0:
		letter_idx = 0
	# C4 is letter_idx=0, octave=4
	return (octave - 4) * 7 + letter_idx


static func _max_midi(notes: Array[Dictionary]) -> int:
	var m := -999
	for n in notes:
		if int(n.midi) > m:
			m = int(n.midi)
	return m


static func _min_midi(notes: Array[Dictionary]) -> int:
	var m := 999
	for n in notes:
		if int(n.midi) < m:
			m = int(n.midi)
	return m


static func _fix_adjacent_gaps(notes: Array[Dictionary], split_midi: int, _root_letter: String, _root_acc: int, _sig_map: Dictionary) -> void:
	# For each hand (LH < split_midi, RH >= split_midi), ensure no two
	# consecutive notes exceed MAX_ADJACENT_GAP semitones.
	for is_rh in [false, true]:
		var hand: Array[Dictionary] = []
		for n in notes:
			var in_rh := int(n.midi) >= split_midi
			if in_rh == is_rh:
				hand.append(n)
		if hand.size() < 2:
			continue
		hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.midi) < int(b.midi))
		for i in range(hand.size() - 1):
			var gap: int = int(hand[i + 1].midi) - int(hand[i].midi)
			if gap > MAX_ADJACENT_GAP:
				var new_midi: int = int(hand[i + 1].midi) - 12
				var prev_midi: int = int(hand[i].midi)
				var floor_midi: int = split_midi if is_rh else BASS_RANGE_LOW
				if new_midi > prev_midi and new_midi >= floor_midi:
					hand[i + 1].midi = new_midi
					# Octave shift preserves note spelling; update octave for display correctness.
					hand[i + 1].octave = int(new_midi / 12) - 1


static func _fix_muddy_bass(notes: Array[Dictionary]) -> void:
	# Ensure bass notes below C3 (MIDI 48) have enough spacing
	for i in range(notes.size() - 1):
		var midi_a: int = int(notes[i].midi)
		var midi_b: int = int(notes[i + 1].midi)
		if midi_a < 48 and midi_b < 48:
			if midi_b - midi_a < MIN_LOW_BASS_INTERVAL:
				# Move the higher one up an octave
				notes[i + 1].midi = midi_b + 12
				if int(notes[i + 1].midi) > TREBLE_RANGE_HIGH:
					notes[i + 1].midi = midi_b  # revert if out of range
				else:
					notes[i + 1].octave = int(int(notes[i + 1].midi) / 12) - 1
