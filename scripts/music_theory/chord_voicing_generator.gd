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

	# Apply inversion: rotate tones
	var num_tones := tone_pcs.size()
	var effective_inversion := clampi(inversion, 0, num_tones - 1)

	# Grand-staff sight-chords can request 7th-style layout behavior:
	# keep original chord tones without triad/power root-doubling so notehead
	# placement matches the 7th-tier profile across families.
	var should_double_root := (not seventh_style_layout) and (num_tones == 3 or num_tones == 2)

	# Pick a bass root octave
	var bass_root_octave := 3
	if spread:
		bass_root_octave = rng.randi_range(2, 3)

	# Build concrete pitches with octave assignments
	var concrete_notes: Array[Dictionary] = []

	# Assign the bass note (lowest note based on inversion)
	var bass_tone_idx := effective_inversion
	var bass_pc := tone_pcs[bass_tone_idx]
	var bass_iv := tone_intervals[bass_tone_idx]
	var bass_midi := _find_nearest_midi_for_pc(bass_pc, _letter_to_midi(root_letter, root_acc, bass_root_octave) + bass_iv - (12 if bass_iv > 0 and effective_inversion > 0 else 0))
	# Clamp bass to reasonable range
	while bass_midi < BASS_RANGE_LOW:
		bass_midi += 12
	while bass_midi > MIDDLE_C_MIDI:
		bass_midi -= 12
	if bass_midi < BASS_RANGE_LOW:
		bass_midi = BASS_RANGE_LOW

	var bass_degree := tone_degrees[bass_tone_idx]
	var bass_letter_info := _midi_to_letter_in_key(bass_midi, root_letter, root_acc, bass_degree, sig_map)
	concrete_notes.append({
		"midi": bass_midi,
		"letter": bass_letter_info.letter,
		"octave": bass_letter_info.octave,
		"accidental": bass_letter_info.accidental,
		"tone_index": bass_tone_idx,
	})

	# Build remaining tones above the bass
	var remaining_indices: Array[int] = []
	for i in range(num_tones):
		if i != bass_tone_idx:
			remaining_indices.append(i)

	# Sort remaining by interval to keep voicing ordered
	remaining_indices.sort_custom(func(a: int, b: int) -> bool:
		return tone_intervals[a] < tone_intervals[b]
	)

	# Place remaining tones in the treble register (above middle C) for piano-like spread.
	# Target: upper voices in octave 4-5 so they land on the treble staff.
	var treble_root_midi := _letter_to_midi(root_letter, root_acc, 4)  # root in octave 4
	for idx in remaining_indices:
		var iv_offset := tone_intervals[idx] - tone_intervals[bass_tone_idx]
		if iv_offset <= 0:
			iv_offset += 12
		# Start from root in octave 4, offset by the interval
		var note_midi := treble_root_midi + (tone_intervals[idx] - tone_intervals[0])
		# Ensure it's above middle C for treble staff placement
		while note_midi < MIDDLE_C_MIDI:
			note_midi += 12
		# If not spread, keep notes within one octave of each other
		if not spread and note_midi > MIDDLE_C_MIDI + 16:
			note_midi -= 12
			if note_midi < MIDDLE_C_MIDI:
				note_midi += 12
		# Clamp to playable range
		note_midi = clampi(note_midi, BASS_RANGE_LOW, TREBLE_RANGE_HIGH)
		var letter_info := _midi_to_letter_in_key(note_midi, root_letter, root_acc, tone_degrees[idx], sig_map)
		concrete_notes.append({
			"midi": note_midi,
			"letter": letter_info.letter,
			"octave": letter_info.octave,
			"accidental": letter_info.accidental,
			"tone_index": idx,
		})

	# Optionally double the root — place it one octave above the bass note (still in bass/low treble)
	if should_double_root and num_tones >= 2:
		# Always double the actual root pitch class, not the bass inversion note
		# Place near one octave above the bass note for good spacing
		var double_midi := _find_nearest_midi_for_pc(tone_pcs[0], int(concrete_notes[0].midi) + 12)
		# Make sure it's distinct from existing notes
		var dominated := false
		for cn in concrete_notes:
			if int(cn.midi) == double_midi:
				dominated = true
				break
		if not dominated and double_midi >= BASS_RANGE_LOW and double_midi <= TREBLE_RANGE_HIGH:
			var span := maxi(double_midi, _max_midi(concrete_notes)) - mini(double_midi, _min_midi(concrete_notes))
			if span <= MAX_VOICING_SPAN:
				var dbl_info := _midi_to_letter_in_key(double_midi, root_letter, root_acc, 0, sig_map)
				concrete_notes.append({
					"midi": double_midi,
					"letter": dbl_info.letter,
					"octave": dbl_info.octave,
					"accidental": dbl_info.accidental,
					"tone_index": 0,
				})

	# Sort by MIDI pitch (low to high)
	concrete_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.midi) < int(b.midi)
	)

	# Validate span
	if concrete_notes.size() >= 2:
		var span: int = int(concrete_notes[concrete_notes.size() - 1].midi) - int(concrete_notes[0].midi)
		if span > MAX_VOICING_SPAN:
			# Compress: bring highest note down an octave
			concrete_notes[concrete_notes.size() - 1].midi = int(concrete_notes[concrete_notes.size() - 1].midi) - 12
			var fix_tone_idx: int = int(concrete_notes[concrete_notes.size() - 1].tone_index)
			var fix_degree: int = tone_degrees[fix_tone_idx] if fix_tone_idx < tone_degrees.size() else 0
			var fixed := _midi_to_letter_in_key(int(concrete_notes[concrete_notes.size() - 1].midi), root_letter, root_acc, fix_degree, sig_map)
			concrete_notes[concrete_notes.size() - 1].letter = fixed.letter
			concrete_notes[concrete_notes.size() - 1].octave = fixed.octave
			concrete_notes[concrete_notes.size() - 1].accidental = fixed.accidental
			concrete_notes.sort_custom(func(a2: Dictionary, b2: Dictionary) -> bool:
				return int(a2.midi) < int(b2.midi)
			)

	# Validate muddy bass: ensure no two bass notes below C3 (MIDI 48) are closer than MIN_LOW_BASS_INTERVAL
	_fix_muddy_bass(concrete_notes)

	# Split across staves
	var treble_notes: Array[Dictionary] = []
	var bass_notes: Array[Dictionary] = []
	for note in concrete_notes:
		var midi: int = int(note.midi)
		var staff := "bass" if midi < MIDDLE_C_MIDI else "treble"
		# Middle C (60) goes to treble by default, but if it's the only note above bass it can go to bass
		if midi == MIDDLE_C_MIDI:
			staff = "treble"
		note["staff"] = staff
		note["step"] = _midi_to_staff_step(midi, int(note.accidental), str(note.letter), staff)
		if staff == "treble":
			treble_notes.append(note)
		else:
			bass_notes.append(note)

	# Ensure at least one note per staff — if all on one staff, move the extreme note
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
		var result := generate(root, 0, quality, inv, sig_map, rng, spread)
		var treble: Array = result.get("treble_notes", [])
		var bass: Array = result.get("bass_notes", [])
		var all: Array = result.get("all_notes", [])
		if all.size() < 2:
			errors.append("Test %d: %s %s inv %d — fewer than 2 notes" % [_i, root, quality, inv])
			continue
		# Check ranges
		for n in all:
			var midi: int = int(n.midi)
			if midi < BASS_RANGE_LOW or midi > TREBLE_RANGE_HIGH:
				errors.append("Test %d: %s %s — MIDI %d out of range" % [_i, root, quality, midi])
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
		# Check at least one note per staff
		if treble.is_empty() or bass.is_empty():
			errors.append("Test %d: %s %s — missing staff (%d treble, %d bass)" % [_i, root, quality, treble.size(), bass.size()])
	return errors


# --- Internal helpers ---

static func _letter_to_midi(letter: String, accidental: int, octave: int) -> int:
	var pc: int = LETTER_PC.get(letter, 0) + accidental
	return (octave + 1) * 12 + pc


static func _find_nearest_midi_for_pc(pc: int, target_midi: int) -> int:
	var base := (target_midi / 12) * 12 + posmod(pc, 12)
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
	# Try adjacent letter names to find a simpler spelling (|acc| <= 1)
	var letter_idx := NOTE_LETTERS.find(letter)
	var best_letter := letter
	var best_octave := octave
	var best_acc := acc
	for offset in [1, -1]:
		var try_idx := posmod(letter_idx + offset, 7)
		var try_letter: String = NOTE_LETTERS[try_idx]
		var try_pc: int = int(LETTER_PC.get(try_letter, 0))
		var try_acc: int = posmod(midi, 12) - try_pc
		if try_acc > 6:
			try_acc -= 12
		elif try_acc < -6:
			try_acc += 12
		if absi(try_acc) < absi(best_acc):
			var try_octave: int = (midi / 12) - 1
			var recheck: int = (try_octave + 1) * 12 + try_pc + try_acc
			if recheck != midi:
				if recheck > midi:
					try_octave -= 1
				else:
					try_octave += 1
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
