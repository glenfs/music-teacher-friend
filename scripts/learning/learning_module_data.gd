extends RefCounted

# Step types supported by the lesson player
const STEP_INTRO := 0
const STEP_EXPLANATION := 1
const STEP_VISUAL := 2
const STEP_RECAP := 3
const STEP_QUIZ := 4
const STEP_DRAG_NOTE := 5
const STEP_DRAG_SYMBOL := 6
const STEP_NOTE_QUIZ := 7
const STEP_CUMULATIVE_QUIZ := 8
const STEP_PRACTICE_ROUND := 9
const STEP_LISTENING_QUIZ := 10
const STEP_MELODY_EXAMPLE := 11
const STEP_RHYTHM_TAP := 12
const STEP_NOTE_IDENTIFY := 13
const STEP_LISTEN_FIND := 14
const STEP_KEYBOARD_QUIZ := 15

# Module states for map pins
const STATE_LOCKED := 0
const STATE_UNLOCKED := 1
const STATE_COMPLETED := 2


static func create_step(type: int, data: Dictionary) -> Dictionary:
	data["type"] = type
	return data


static func create_intro_step(title: String, chicken_text: String, subtitle: String = "") -> Dictionary:
	return create_step(STEP_INTRO, {
		"title": title,
		"chicken_text": chicken_text,
		"subtitle": subtitle,
	})


static func create_explanation_step(title: String, chicken_text: String, highlight_text: String = "", detail_text: String = "") -> Dictionary:
	return create_step(STEP_EXPLANATION, {
		"title": title,
		"chicken_text": chicken_text,
		"highlight_text": highlight_text,
		"detail_text": detail_text,
	})


static func create_visual_step(title: String, chicken_text: String, visual_type: String, visual_data: Dictionary = {}) -> Dictionary:
	return create_step(STEP_VISUAL, {
		"title": title,
		"chicken_text": chicken_text,
		"visual_type": visual_type,
		"visual_data": visual_data,
	})


static func create_recap_step(title: String, chicken_text: String, items: Array) -> Dictionary:
	return create_step(STEP_RECAP, {
		"title": title,
		"chicken_text": chicken_text,
		"items": items,
	})


static func create_quiz_step(question: String, choices: Array, correct_index: int, chicken_correct: String = "That's right!", chicken_wrong: String = "Not quite — try again!") -> Dictionary:
	return create_step(STEP_QUIZ, {
		"question": question,
		"choices": choices,
		"correct_index": correct_index,
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	})


static func create_drag_note_step(chicken_text: String, clef: String, target_note: String, target_step: int, show_hint: bool = true, chicken_correct: String = "That's the right spot!", chicken_wrong: String = "Not quite -- try again!") -> Dictionary:
	return create_step(STEP_DRAG_NOTE, {
		"chicken_text": chicken_text,
		"clef": clef,
		"target_note": target_note,
		"target_step": target_step,
		"show_hint": show_hint,
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	})


static func create_drag_symbol_step(chicken_text: String, symbol: String, choices: Array, correct_index: int, chicken_correct: String = "You got it!", chicken_wrong: String = "Not that one -- try again!") -> Dictionary:
	return create_step(STEP_DRAG_SYMBOL, {
		"chicken_text": chicken_text,
		"symbol": symbol,
		"choices": choices,
		"correct_index": correct_index,
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	})


static func create_note_quiz_step(clef: String, note_name: String, note_step: int, choices: Array, correct_index: int, chicken_correct: String = "That's right!", chicken_wrong: String = "Not quite — try again!") -> Dictionary:
	return create_step(STEP_NOTE_QUIZ, {
		"chicken_text": "What note is this?",
		"clef": clef,
		"note_name": note_name,
		"note_step": note_step,
		"choices": choices,
		"correct_index": correct_index,
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	})


static func create_cumulative_quiz_step(title: String, chicken_text: String, pool: Array, count: int = 5) -> Dictionary:
	# pool: Array of {clef, note_name, note_step, note_id}
	# count: how many random quizzes to draw from pool
	return create_step(STEP_CUMULATIVE_QUIZ, {
		"title": title,
		"chicken_text": chicken_text,
		"pool": pool,
		"count": count,
	})


static func create_practice_round_step(title: String, chicken_text: String, pool: Array, target_correct: int = 10, pool_type: String = "note") -> Dictionary:
	# pool_type: "note" (staff-based), "theory" (text-based MCQ)
	# For "note" pools: Array of {clef, note_name, note_step, note_id}
	# For "theory" pools: Array of {question, choices: Array, correct_index: int, concept_id: String}
	return create_step(STEP_PRACTICE_ROUND, {
		"title": title,
		"chicken_text": chicken_text,
		"pool": pool,
		"target_correct": target_correct,
		"pool_type": pool_type,
	})


static func create_listening_quiz_step(title: String, chicken_text: String, items: Array) -> Dictionary:
	# items: Array of {note_ids: Array[String], label: String, choices: Array[String], correct_index: int}
	# For intervals: note_ids = ["C4", "E4"], label = "Major 3rd"
	# For chords: note_ids = ["C4", "E4", "G4"], label = "Major"
	return create_step(STEP_LISTENING_QUIZ, {
		"title": title,
		"chicken_text": chicken_text,
		"items": items,
	})


static func create_melody_example_step(title: String, chicken_text: String, clef: String, notes: Array, melody_name: String = "") -> Dictionary:
	# notes: Array of {note_id: String, note_step: int, beats: float}
	return create_step(STEP_MELODY_EXAMPLE, {
		"title": title,
		"chicken_text": chicken_text,
		"clef": clef,
		"notes": notes,
		"melody_name": melody_name,
	})


static func create_rhythm_tap_step(title: String, chicken_text: String, pattern: Array, bpm: int = 100, time_sig_top: int = 4, extra: Dictionary = {}) -> Dictionary:
	var data := {
		"title": title,
		"chicken_text": chicken_text,
		"pattern": pattern,  # Array of floats or Dictionaries with beats/rest metadata
		"bpm": bpm,
		"time_sig_top": time_sig_top,
	}
	for key in extra:
		data[key] = extra[key]
	return create_step(STEP_RHYTHM_TAP, data)


static func create_note_identify_step(clef: String, target_note_id: String, target_step: int, distractor_steps: Array, chicken_correct: String = "", chicken_wrong: String = "") -> Dictionary:
	return {
		"type": STEP_NOTE_IDENTIFY,
		"clef": clef,
		"target_note_id": target_note_id,
		"target_step": target_step,
		"distractor_steps": distractor_steps,  # Array of int — 2 other note_step values
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	}


static func create_listen_find_step(clef: String, target_note_id: String, target_step: int, distractor_steps: Array, chicken_correct: String = "", chicken_wrong: String = "") -> Dictionary:
	return {
		"type": STEP_LISTEN_FIND,
		"clef": clef,
		"target_note_id": target_note_id,
		"target_step": target_step,
		"distractor_steps": distractor_steps,
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	}


static func create_keyboard_quiz_step(clef: String, note_id_on_staff: String, note_step: int, target_note_id: String, accidental: String = "", chicken_correct: String = "", chicken_wrong: String = "") -> Dictionary:
	return {
		"type": STEP_KEYBOARD_QUIZ,
		"clef": clef,
		"note_id_on_staff": note_id_on_staff,
		"note_step": note_step,
		"target_note_id": target_note_id,
		"accidental": accidental,
		"chicken_correct": chicken_correct,
		"chicken_wrong": chicken_wrong,
	}


static func create_module(id: String, title: String, description: String, icon: String, steps: Array, est_minutes: int = 0, badge_name: String = "") -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"icon": icon,
		"steps": steps,
		"est_minutes": est_minutes,
		"badge_name": badge_name,
	}


# ─── Note ID Helpers ──────────────────────────────────────────────

static func step_to_note_id(clef: String, note_step: int) -> String:
	var note_names := ["C", "D", "E", "F", "G", "A", "B"]
	var diatonic_pos: int
	if clef == "treble":
		diatonic_pos = 5 * 7 + 3 - note_step  # F5 = diatonic 38
	else:
		diatonic_pos = 3 * 7 + 5 - note_step  # A3 = diatonic 26
	var note_idx: int = diatonic_pos % 7
	var octave: int = diatonic_pos / 7
	if diatonic_pos < 0:
		note_idx = ((diatonic_pos % 7) + 7) % 7
		octave = (diatonic_pos - 6) / 7
	return note_names[note_idx] + str(octave)


static func note_id_to_midi(note_id: String) -> int:
	if note_id.is_empty():
		return -1
	var base_semitones := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var letter: String = note_id[0].to_upper()
	if not base_semitones.has(letter):
		return -1
	var offset := 1
	var accidental := 0
	if note_id.length() > 2:
		if note_id[1] == "#":
			accidental = 1
			offset = 2
		elif note_id[1] == "b":
			accidental = -1
			offset = 2
	var octave: int = int(note_id.substr(offset))
	return (octave + 1) * 12 + base_semitones[letter] + accidental


# Pool builder helpers for cumulative quizzes
static func treble_note_pool_part1a() -> Array:
	# C4-E4 from module 02a
	return [
		{"clef": "treble", "note_name": "C", "note_step": 10, "note_id": "C4"},
		{"clef": "treble", "note_name": "D", "note_step": 9, "note_id": "D4"},
		{"clef": "treble", "note_name": "E", "note_step": 8, "note_id": "E4"},
	]

static func treble_note_pool_basic() -> Array:
	# C4-G4 from module 02
	return [
		{"clef": "treble", "note_name": "C", "note_step": 10, "note_id": "C4"},
		{"clef": "treble", "note_name": "D", "note_step": 9, "note_id": "D4"},
		{"clef": "treble", "note_name": "E", "note_step": 8, "note_id": "E4"},
		{"clef": "treble", "note_name": "F", "note_step": 7, "note_id": "F4"},
		{"clef": "treble", "note_name": "G", "note_step": 6, "note_id": "G4"},
	]

static func treble_note_pool_part2() -> Array:
	# A4-C5 from module 05
	return treble_note_pool_basic() + [
		{"clef": "treble", "note_name": "A", "note_step": 5, "note_id": "A4"},
		{"clef": "treble", "note_name": "B", "note_step": 4, "note_id": "B4"},
		{"clef": "treble", "note_name": "C", "note_step": 3, "note_id": "C5"},
	]

static func treble_note_pool_full() -> Array:
	# D5-G5 from module 08
	return treble_note_pool_part2() + [
		{"clef": "treble", "note_name": "D", "note_step": 2, "note_id": "D5"},
		{"clef": "treble", "note_name": "E", "note_step": 1, "note_id": "E5"},
		{"clef": "treble", "note_name": "F", "note_step": 0, "note_id": "F5"},
		{"clef": "treble", "note_name": "G", "note_step": -1, "note_id": "G5"},
	]

static func bass_note_pool_part1a() -> Array:
	# C4, B3, A3 from module 03a
	return [
		{"clef": "bass", "note_name": "C", "note_step": -2, "note_id": "C4"},
		{"clef": "bass", "note_name": "B", "note_step": -1, "note_id": "B3"},
		{"clef": "bass", "note_name": "A", "note_step": 0, "note_id": "A3"},
	]

static func bass_note_pool_basic() -> Array:
	# C4-F3 from module 03a + 03b
	return bass_note_pool_part1a() + [
		{"clef": "bass", "note_name": "G", "note_step": 1, "note_id": "G3"},
		{"clef": "bass", "note_name": "F", "note_step": 2, "note_id": "F3"},
	]

static func bass_note_pool_part2() -> Array:
	# E3-C3 from module 06
	return bass_note_pool_basic() + [
		{"clef": "bass", "note_name": "E", "note_step": 3, "note_id": "E3"},
		{"clef": "bass", "note_name": "D", "note_step": 4, "note_id": "D3"},
		{"clef": "bass", "note_name": "C", "note_step": 5, "note_id": "C3"},
	]

static func bass_note_pool_full() -> Array:
	# B2-F2 from module 09
	return bass_note_pool_part2() + [
		{"clef": "bass", "note_name": "B", "note_step": 6, "note_id": "B2"},
		{"clef": "bass", "note_name": "A", "note_step": 7, "note_id": "A2"},
		{"clef": "bass", "note_name": "G", "note_step": 8, "note_id": "G2"},
		{"clef": "bass", "note_name": "F", "note_step": 9, "note_id": "F2"},
	]


# ─── Theory Concept Pools (for practice rounds & cumulative quizzes) ──

static func clef_theory_pool() -> Array:
	return [
		{"question": "Which clef is also called the G Clef?", "choices": ["Treble Clef", "Bass Clef", "Alto Clef"], "correct_index": 0, "concept_id": "theory:g_clef"},
		{"question": "Which clef is also called the F Clef?", "choices": ["Treble Clef", "Bass Clef", "Alto Clef"], "correct_index": 1, "concept_id": "theory:f_clef"},
		{"question": "The treble clef is used for which notes?", "choices": ["Higher notes", "Lower notes", "All notes"], "correct_index": 0, "concept_id": "theory:treble_range"},
		{"question": "The bass clef is used for which notes?", "choices": ["Higher notes", "Lower notes", "All notes"], "correct_index": 1, "concept_id": "theory:bass_range"},
		{"question": "What do bar lines do?", "choices": ["Divide music into measures", "Make music louder", "Change the key"], "correct_index": 0, "concept_id": "theory:bar_lines"},
		{"question": "How many beats in a bar of 4/4 time?", "choices": ["2", "3", "4"], "correct_index": 2, "concept_id": "theory:4_4_time"},
		{"question": "How many beats in a bar of 3/4 time?", "choices": ["2", "3", "4"], "correct_index": 1, "concept_id": "theory:3_4_time"},
		{"question": "What does the top number in a time signature mean?", "choices": ["Beats per measure", "How fast to play", "How many measures"], "correct_index": 0, "concept_id": "theory:time_sig_top"},
		{"question": "What does the bottom number in a time signature mean?", "choices": ["Which note gets one beat", "How many beats", "How many bars"], "correct_index": 0, "concept_id": "theory:time_sig_bottom"},
		{"question": "The treble clef curls around which line?", "choices": ["The bottom line", "The second line (G)", "The top line"], "correct_index": 1, "concept_id": "theory:treble_curl"},
		{"question": "The bass clef dots surround which line?", "choices": ["The bottom line", "The middle line", "The fourth line (F)"], "correct_index": 2, "concept_id": "theory:bass_dots"},
		{"question": "What is another name for a bar?", "choices": ["A measure", "A phrase", "A line"], "correct_index": 0, "concept_id": "theory:bar_measure"},
		{"question": "A double bar line at the end of a piece means...?", "choices": ["Play louder", "The piece is over", "Repeat from the start"], "correct_index": 1, "concept_id": "theory:double_bar"},
		{"question": "In 3/4 time, how many quarter notes fill a bar?", "choices": ["2", "3", "4"], "correct_index": 1, "concept_id": "theory:3_4_quarters"},
		{"question": "Which staff would a flute player read?", "choices": ["Treble", "Bass", "Both"], "correct_index": 0, "concept_id": "theory:flute_staff"},
		{"question": "Which staff would a cello player read?", "choices": ["Treble", "Bass", "Both"], "correct_index": 1, "concept_id": "theory:cello_staff"},
	]

static func rhythm_theory_pool() -> Array:
	return [
		{"question": "How many beats does a whole note get?", "choices": ["1", "2", "4"], "correct_index": 2, "concept_id": "theory:whole_note"},
		{"question": "How many beats does a half note get?", "choices": ["1", "2", "4"], "correct_index": 1, "concept_id": "theory:half_note"},
		{"question": "How many beats does a quarter note get?", "choices": ["0.5", "1", "2"], "correct_index": 1, "concept_id": "theory:quarter_note"},
		{"question": "How many beats does an eighth note get?", "choices": ["0.5", "1", "2"], "correct_index": 0, "concept_id": "theory:eighth_note"},
		{"question": "How many quarter notes fill a bar of 4/4?", "choices": ["2", "4", "8"], "correct_index": 1, "concept_id": "theory:quarters_in_bar"},
		{"question": "How many half notes fill a bar of 4/4?", "choices": ["1", "2", "4"], "correct_index": 1, "concept_id": "theory:halves_in_bar"},
		{"question": "Which note gets 4 beats in 4/4 time?", "choices": ["Quarter note", "Half note", "Whole note"], "correct_index": 2, "concept_id": "theory:which_4_beats"},
		{"question": "How many eighth notes equal one quarter note?", "choices": ["1", "2", "4"], "correct_index": 1, "concept_id": "theory:eighths_per_quarter"},
		{"question": "Which rest lasts as long as a quarter note?", "choices": ["Quarter rest", "Half rest", "Whole rest"], "correct_index": 0, "concept_id": "theory:quarter_rest"},
		{"question": "How many whole notes fill a bar of 4/4?", "choices": ["1", "2", "4"], "correct_index": 0, "concept_id": "theory:wholes_in_bar"},
		{"question": "What does a dot after a note do?", "choices": ["Adds half its value", "Doubles its value", "Makes it louder"], "correct_index": 0, "concept_id": "theory:dotted_note"},
		{"question": "A dotted half note lasts how many beats?", "choices": ["2", "3", "4"], "correct_index": 1, "concept_id": "theory:dotted_half"},
		{"question": "How many eighth notes fill a bar of 4/4?", "choices": ["4", "6", "8"], "correct_index": 2, "concept_id": "theory:eighths_in_bar"},
		{"question": "1 half note + 2 quarter notes = how many beats?", "choices": ["3", "4", "5"], "correct_index": 1, "concept_id": "theory:mix_halves_quarters"},
		{"question": "Which note is twice as long as a quarter note?", "choices": ["Eighth note", "Half note", "Whole note"], "correct_index": 1, "concept_id": "theory:double_quarter"},
		{"question": "In 3/4 time, which combination fills one bar?", "choices": ["3 quarter notes", "4 quarter notes", "2 half notes"], "correct_index": 0, "concept_id": "theory:3_4_fill"},
	]

static func accidental_theory_pool() -> Array:
	return [
		{"question": "What does a sharp sign do?", "choices": ["Raises a note", "Lowers a note", "Cancels an accidental"], "correct_index": 0, "concept_id": "theory:sharp_meaning"},
		{"question": "What does a flat sign do?", "choices": ["Raises a note", "Lowers a note", "Cancels an accidental"], "correct_index": 1, "concept_id": "theory:flat_meaning"},
		{"question": "What does a natural sign do?", "choices": ["Raises a note", "Lowers a note", "Cancels a sharp or flat"], "correct_index": 2, "concept_id": "theory:natural_meaning"},
		{"question": "If you see F#, what happened to F?", "choices": ["Up a half step", "Down a half step", "Nothing"], "correct_index": 0, "concept_id": "theory:f_sharp"},
		{"question": "If you see Bb, what happened to B?", "choices": ["Up a half step", "Down a half step", "Nothing"], "correct_index": 1, "concept_id": "theory:b_flat"},
		{"question": "C with a sharp sign becomes...?", "choices": ["Cb", "C#", "D"], "correct_index": 1, "concept_id": "theory:c_sharp"},
		{"question": "E with a flat sign becomes...?", "choices": ["Eb", "E#", "D"], "correct_index": 0, "concept_id": "theory:e_flat"},
		{"question": "A sharp raises a note by how much?", "choices": ["A whole step", "A half step", "Two half steps"], "correct_index": 1, "concept_id": "theory:sharp_amount"},
		{"question": "A flat lowers a note by how much?", "choices": ["A whole step", "A half step", "Two half steps"], "correct_index": 1, "concept_id": "theory:flat_amount"},
		{"question": "If a note has a sharp, then a natural sign appears, the note is...?", "choices": ["Still sharp", "Back to normal", "Now flat"], "correct_index": 1, "concept_id": "theory:natural_cancels"},
		{"question": "An accidental lasts for how long?", "choices": ["The whole piece", "The rest of the bar", "Just that one note"], "correct_index": 1, "concept_id": "theory:accidental_duration"},
		{"question": "F# and Gb sound the same. This is called...?", "choices": ["Unison", "Enharmonic", "Harmonic"], "correct_index": 1, "concept_id": "theory:enharmonic"},
		{"question": "How many half steps between C and C#?", "choices": ["0", "1", "2"], "correct_index": 1, "concept_id": "theory:c_csharp_distance"},
		{"question": "G with a flat sign becomes...?", "choices": ["G#", "Gb", "F#"], "correct_index": 1, "concept_id": "theory:g_flat"},
		{"question": "Which symbol cancels a flat?", "choices": ["Sharp (#)", "Natural (♮)", "Double flat"], "correct_index": 1, "concept_id": "theory:cancel_flat"},
	]

static func key_sig_theory_pool() -> Array:
	return [
		{"question": "What does a key signature do?", "choices": ["Sets which notes are sharp or flat", "Sets the tempo", "Sets the volume"], "correct_index": 0, "concept_id": "theory:key_sig_purpose"},
		{"question": "How many sharps in G Major?", "choices": ["0", "1", "2"], "correct_index": 1, "concept_id": "theory:g_major_sharps"},
		{"question": "Which note is sharp in G Major?", "choices": ["C", "F", "G"], "correct_index": 1, "concept_id": "theory:g_major_which"},
		{"question": "How many flats in F Major?", "choices": ["0", "1", "2"], "correct_index": 1, "concept_id": "theory:f_major_flats"},
		{"question": "Which note is flat in F Major?", "choices": ["E", "B", "A"], "correct_index": 1, "concept_id": "theory:f_major_which"},
		{"question": "C Major has how many sharps or flats?", "choices": ["0", "1", "2"], "correct_index": 0, "concept_id": "theory:c_major_accidentals"},
		{"question": "Can a key signature have both sharps AND flats?", "choices": ["Yes", "No", "Sometimes"], "correct_index": 1, "concept_id": "theory:no_mixing"},
		{"question": "If you see one sharp at the start, the key is likely...?", "choices": ["C Major", "G Major", "F Major"], "correct_index": 1, "concept_id": "theory:one_sharp_key"},
		{"question": "In G Major, which note is always sharp?", "choices": ["C", "F", "G"], "correct_index": 1, "concept_id": "theory:g_major_sharp_note"},
		{"question": "F Major has one flat. Which note is it?", "choices": ["E", "B", "A"], "correct_index": 1, "concept_id": "theory:f_major_flat_note"},
		{"question": "What key has no sharps or flats?", "choices": ["G Major", "F Major", "C Major"], "correct_index": 2, "concept_id": "theory:no_accidentals_key"},
		{"question": "In F Major, is B natural or flat?", "choices": ["Natural", "Flat", "Sharp"], "correct_index": 1, "concept_id": "theory:f_major_b_status"},
		{"question": "Which key signature has F#?", "choices": ["C Major", "F Major", "G Major"], "correct_index": 2, "concept_id": "theory:which_key_fsharp"},
		{"question": "How many sharps does D Major have?", "choices": ["1", "2", "3"], "correct_index": 1, "concept_id": "theory:d_major_sharps"},
		{"question": "Which notes are sharp in D Major?", "choices": ["F# only", "F# and C#", "F#, C#, G#"], "correct_index": 1, "concept_id": "theory:d_major_which"},
		{"question": "How many sharps does A Major have?", "choices": ["1", "2", "3"], "correct_index": 2, "concept_id": "theory:a_major_sharps"},
		{"question": "Which notes are sharp in A Major?", "choices": ["F# and C#", "F#, C#, G#", "F#, C#, G#, D#"], "correct_index": 1, "concept_id": "theory:a_major_which"},
		{"question": "How many flats does B♭ Major have?", "choices": ["1", "2", "3"], "correct_index": 1, "concept_id": "theory:bb_major_flats"},
		{"question": "Which notes are flat in B♭ Major?", "choices": ["B♭ only", "B♭ and E♭", "B♭, E♭, A♭"], "correct_index": 1, "concept_id": "theory:bb_major_which"},
		{"question": "How many flats does E♭ Major have?", "choices": ["1", "2", "3"], "correct_index": 2, "concept_id": "theory:eb_major_flats"},
		{"question": "If you see 2 sharps at the start, the key is likely...?", "choices": ["G Major", "D Major", "A Major"], "correct_index": 1, "concept_id": "theory:two_sharp_key"},
		{"question": "If you see 2 flats at the start, the key is likely...?", "choices": ["F Major", "B♭ Major", "E♭ Major"], "correct_index": 1, "concept_id": "theory:two_flat_key"},
		{"question": "Sharps always arrive in what order?", "choices": ["F, C, G, D, A, E, B", "B, E, A, D, G, C, F", "C, D, E, F, G, A, B"], "correct_index": 0, "concept_id": "theory:sharp_order"},
		{"question": "Flats always arrive in what order?", "choices": ["F, C, G, D, A, E, B", "B, E, A, D, G, C, F", "A, B, C, D, E, F, G"], "correct_index": 1, "concept_id": "theory:flat_order"},
		{"question": "In A Major, is G natural or sharp?", "choices": ["Natural", "Sharp", "Flat"], "correct_index": 1, "concept_id": "theory:a_major_g_status"},
	]

static func interval_theory_pool() -> Array:
	return [
		{"question": "What is an interval?", "choices": ["Distance between two notes", "A type of chord", "A rhythm pattern"], "correct_index": 0, "concept_id": "theory:interval_def"},
		{"question": "C to D is what interval?", "choices": ["2nd (step)", "3rd (skip)", "4th"], "correct_index": 0, "concept_id": "theory:c_to_d"},
		{"question": "C to E is what interval?", "choices": ["2nd", "3rd (skip)", "5th"], "correct_index": 1, "concept_id": "theory:c_to_e"},
		{"question": "C to F is what interval?", "choices": ["3rd", "4th", "5th"], "correct_index": 1, "concept_id": "theory:c_to_f"},
		{"question": "C to G is what interval?", "choices": ["3rd", "4th", "5th"], "correct_index": 2, "concept_id": "theory:c_to_g"},
		{"question": "Which interval is bigger: a 2nd or a 5th?", "choices": ["2nd", "5th", "Same size"], "correct_index": 1, "concept_id": "theory:interval_size"},
		{"question": "A step between adjacent notes is called a...?", "choices": ["2nd", "3rd", "4th"], "correct_index": 0, "concept_id": "theory:step_name"},
		{"question": "C to C (same note, one octave up) is what interval?", "choices": ["5th", "7th", "Octave"], "correct_index": 2, "concept_id": "theory:c_to_c_octave"},
		{"question": "A skip between notes (e.g. C to E) is called a...?", "choices": ["2nd", "3rd", "5th"], "correct_index": 1, "concept_id": "theory:skip_name"},
		{"question": "Which interval sounds the most stable and 'open'?", "choices": ["2nd", "3rd", "5th"], "correct_index": 2, "concept_id": "theory:stable_interval"},
		{"question": "How many letter names apart are C and F?", "choices": ["3", "4", "5"], "correct_index": 1, "concept_id": "theory:c_f_distance"},
		{"question": "D to F is what interval?", "choices": ["2nd", "3rd", "4th"], "correct_index": 1, "concept_id": "theory:d_to_f"},
		{"question": "E to A is what interval?", "choices": ["3rd", "4th", "5th"], "correct_index": 1, "concept_id": "theory:e_to_a"},
		{"question": "G to D (going up) is what interval?", "choices": ["4th", "5th", "6th"], "correct_index": 1, "concept_id": "theory:g_to_d"},
		{"question": "Which interval sounds like 'Here Comes the Bride'?", "choices": ["2nd", "3rd", "4th"], "correct_index": 2, "concept_id": "theory:interval_song_4th"},
		{"question": "Which interval sounds like the start of 'Star Wars'?", "choices": ["3rd", "4th", "5th"], "correct_index": 2, "concept_id": "theory:interval_song_5th"},
	]

static func chord_theory_pool() -> Array:
	return [
		{"question": "What is a chord?", "choices": ["3+ notes played together", "A single note", "A rhythm pattern"], "correct_index": 0, "concept_id": "theory:chord_def"},
		{"question": "A major chord sounds...?", "choices": ["Happy and bright", "Sad and dark", "Tense and unstable"], "correct_index": 0, "concept_id": "theory:major_mood"},
		{"question": "A minor chord sounds...?", "choices": ["Happy and bright", "Sad and dark", "Tense and unstable"], "correct_index": 1, "concept_id": "theory:minor_mood"},
		{"question": "What notes make a C Major chord?", "choices": ["C-E-G", "C-Eb-G", "C-Eb-Gb"], "correct_index": 0, "concept_id": "theory:c_major_notes"},
		{"question": "What notes make a C minor chord?", "choices": ["C-E-G", "C-Eb-G", "C-Eb-Gb"], "correct_index": 1, "concept_id": "theory:c_minor_notes"},
		{"question": "Major vs minor differs by how many semitones on the 3rd?", "choices": ["1", "2", "3"], "correct_index": 0, "concept_id": "theory:major_minor_diff"},
		{"question": "A diminished chord sounds...?", "choices": ["Happy", "Sad", "Tense and unstable"], "correct_index": 2, "concept_id": "theory:dim_mood"},
		{"question": "How many notes are in a basic triad?", "choices": ["2", "3", "4"], "correct_index": 1, "concept_id": "theory:triad_count"},
		{"question": "A major chord is built from which intervals?", "choices": ["Major 3rd + Minor 3rd", "Minor 3rd + Major 3rd", "Two Major 3rds"], "correct_index": 0, "concept_id": "theory:major_intervals"},
		{"question": "A minor chord is built from which intervals?", "choices": ["Major 3rd + Minor 3rd", "Minor 3rd + Major 3rd", "Two Minor 3rds"], "correct_index": 1, "concept_id": "theory:minor_intervals"},
		{"question": "What is the bottom note of a chord called?", "choices": ["The root", "The bass", "The tonic"], "correct_index": 0, "concept_id": "theory:chord_root"},
		{"question": "What notes make a G Major chord?", "choices": ["G-B-D", "G-Bb-D", "G-B-D#"], "correct_index": 0, "concept_id": "theory:g_major_chord"},
		{"question": "A diminished chord is built from...?", "choices": ["Two major 3rds", "Two minor 3rds", "Major 3rd + minor 3rd"], "correct_index": 1, "concept_id": "theory:dim_intervals"},
		{"question": "What makes a chord 'minor' instead of 'major'?", "choices": ["Lower the 3rd by a half step", "Raise the 5th", "Add a 7th"], "correct_index": 0, "concept_id": "theory:minor_change"},
		{"question": "The three notes of a triad are called...?", "choices": ["Root, 3rd, 5th", "1st, 2nd, 3rd", "Bass, melody, harmony"], "correct_index": 0, "concept_id": "theory:triad_names"},
		{"question": "D minor chord uses which notes?", "choices": ["D-F-A", "D-F#-A", "D-F-Ab"], "correct_index": 0, "concept_id": "theory:d_minor_notes"},
	]

static func grand_staff_theory_pool() -> Array:
	return [
		{"question": "A grand staff combines which two clefs?", "choices": ["Treble and Bass", "Treble and Alto", "Bass and Tenor"], "correct_index": 0, "concept_id": "theory:grand_staff_clefs"},
		{"question": "Which instrument commonly uses the grand staff?", "choices": ["Guitar", "Piano", "Flute"], "correct_index": 1, "concept_id": "theory:grand_staff_instrument"},
		{"question": "Middle C sits where on the grand staff?", "choices": ["On the treble staff", "Between the two staves", "On the bass staff"], "correct_index": 1, "concept_id": "theory:middle_c_grand"},
		{"question": "The right hand usually plays which staff?", "choices": ["Treble (top)", "Bass (bottom)", "Both equally"], "correct_index": 0, "concept_id": "theory:right_hand_staff"},
		{"question": "The left hand usually plays which staff?", "choices": ["Treble (top)", "Bass (bottom)", "Either one"], "correct_index": 1, "concept_id": "theory:left_hand_staff"},
		{"question": "How many staves does a grand staff have?", "choices": ["1", "2", "3"], "correct_index": 1, "concept_id": "theory:grand_staff_count"},
		{"question": "The two staves of a grand staff are connected by a...?", "choices": ["Bar line and brace", "Double bar", "Repeat sign"], "correct_index": 0, "concept_id": "theory:grand_staff_brace"},
		{"question": "Where does the treble staff sit on a grand staff?", "choices": ["On top", "On bottom", "In the middle"], "correct_index": 0, "concept_id": "theory:treble_position"},
		{"question": "Why is the grand staff useful for piano?", "choices": ["It shows both hands at once", "It makes music louder", "It changes the key"], "correct_index": 0, "concept_id": "theory:grand_staff_why"},
		{"question": "Middle C can be written in which clef?", "choices": ["Only treble", "Only bass", "Either treble or bass"], "correct_index": 2, "concept_id": "theory:middle_c_either"},
		{"question": "Which instrument besides piano uses the grand staff?", "choices": ["Trumpet", "Organ", "Violin"], "correct_index": 1, "concept_id": "theory:organ_grand"},
		{"question": "How many lines total are on a grand staff (both staves)?", "choices": ["5", "10", "11"], "correct_index": 1, "concept_id": "theory:grand_staff_lines"},
		{"question": "On the grand staff, higher notes are on which staff?", "choices": ["The top (treble)", "The bottom (bass)", "Either one"], "correct_index": 0, "concept_id": "theory:higher_notes_staff"},
		{"question": "When learning piano, you should start by reading...?", "choices": ["Both staves at once", "Each hand separately", "Only the treble"], "correct_index": 1, "concept_id": "theory:piano_learning_start"},
	]

static func minor_scale_theory_pool() -> Array:
	return [
		{"question": "What is the step pattern of a natural minor scale?", "choices": ["W-W-H-W-W-W-H", "W-H-W-W-H-W-W", "H-W-W-H-W-W-W"], "correct_index": 1, "concept_id": "theory:minor_step_pattern"},
		{"question": "A natural minor uses all white keys starting on which note?", "choices": ["C", "A", "E"], "correct_index": 1, "concept_id": "theory:a_minor_white_keys"},
		{"question": "What is the relative minor of C Major?", "choices": ["C minor", "A minor", "E minor"], "correct_index": 1, "concept_id": "theory:relative_minor_c"},
		{"question": "What is the relative minor of G Major?", "choices": ["B minor", "D minor", "E minor"], "correct_index": 2, "concept_id": "theory:relative_minor_g"},
		{"question": "What note is raised in A harmonic minor?", "choices": ["F to F#", "G to G#", "E to E#"], "correct_index": 1, "concept_id": "theory:harmonic_minor_raised"},
		{"question": "Why is the 7th raised in harmonic minor?", "choices": ["To make it louder", "To create a leading tone", "To add a flat"], "correct_index": 1, "concept_id": "theory:leading_tone_why"},
		{"question": "Minor music usually sounds...?", "choices": ["Bright and happy", "Dark and sad", "Fast and loud"], "correct_index": 1, "concept_id": "theory:minor_mood"},
		{"question": "How do you find a relative minor from a major key?", "choices": ["Go up 3 half steps", "Go down 3 half steps", "Go up 5 half steps"], "correct_index": 1, "concept_id": "theory:find_relative_minor"},
		{"question": "What is the relative major of A minor?", "choices": ["A Major", "C Major", "G Major"], "correct_index": 1, "concept_id": "theory:relative_major_a"},
		{"question": "E minor has the same key signature as...?", "choices": ["C Major", "G Major", "D Major"], "correct_index": 1, "concept_id": "theory:e_minor_key_sig"},
		{"question": "D minor has the same key signature as...?", "choices": ["G Major", "C Major", "F Major"], "correct_index": 2, "concept_id": "theory:d_minor_key_sig"},
		{"question": "What makes harmonic minor sound 'exotic'?", "choices": ["A big gap between the 6th and 7th notes", "Playing very fast", "Using only black keys"], "correct_index": 0, "concept_id": "theory:harmonic_exotic"},
		{"question": "B minor has how many sharps?", "choices": ["1 (F#)", "2 (F#, C#)", "3 (F#, C#, G#)"], "correct_index": 1, "concept_id": "theory:b_minor_sharps"},
		{"question": "Can a major and minor key share the same key signature?", "choices": ["No, never", "Yes, relative keys do", "Only in bass clef"], "correct_index": 1, "concept_id": "theory:relative_share_key_sig"},
		{"question": "How can you tell if music is major or minor?", "choices": ["Count the notes", "Listen to the mood — bright or dark", "Look at the time signature"], "correct_index": 1, "concept_id": "theory:major_minor_tell"},
	]


static func interval_quality_theory_pool() -> Array:
	return [
		{"question": "Which intervals are 'perfect'?", "choices": ["2nds, 3rds, 6ths", "Unison, 4th, 5th, Octave", "All intervals"], "correct_index": 1, "concept_id": "theory:perfect_intervals"},
		{"question": "How many semitones in a major 3rd?", "choices": ["3", "4", "5"], "correct_index": 1, "concept_id": "theory:major_3rd_semitones"},
		{"question": "How many semitones in a minor 3rd?", "choices": ["2", "3", "4"], "correct_index": 1, "concept_id": "theory:minor_3rd_semitones"},
		{"question": "How many semitones in a perfect 5th?", "choices": ["5", "6", "7"], "correct_index": 2, "concept_id": "theory:perfect_5th_semitones"},
		{"question": "How many semitones in a perfect 4th?", "choices": ["4", "5", "6"], "correct_index": 1, "concept_id": "theory:perfect_4th_semitones"},
		{"question": "A major interval is how much bigger than its minor version?", "choices": ["1 semitone", "2 semitones", "3 semitones"], "correct_index": 0, "concept_id": "theory:major_minor_diff"},
		{"question": "A major 3rd sounds...?", "choices": ["Dark and sad", "Bright and happy", "Tense and scary"], "correct_index": 1, "concept_id": "theory:major_3rd_mood"},
		{"question": "A minor 3rd sounds...?", "choices": ["Bright and happy", "Dark and sad", "Tense and scary"], "correct_index": 1, "concept_id": "theory:minor_3rd_mood"},
		{"question": "What is a tritone?", "choices": ["A perfect 4th", "An interval of 6 semitones", "A major 3rd"], "correct_index": 1, "concept_id": "theory:tritone_def"},
		{"question": "How many semitones in a major 2nd?", "choices": ["1", "2", "3"], "correct_index": 1, "concept_id": "theory:major_2nd_semitones"},
		{"question": "How many semitones in a minor 2nd?", "choices": ["1", "2", "3"], "correct_index": 0, "concept_id": "theory:minor_2nd_semitones"},
		{"question": "C to E is what interval?", "choices": ["Minor 3rd", "Major 3rd", "Perfect 4th"], "correct_index": 1, "concept_id": "theory:c_to_e_quality"},
		{"question": "C to Eb is what interval?", "choices": ["Minor 3rd", "Major 3rd", "Minor 2nd"], "correct_index": 0, "concept_id": "theory:c_to_eb_quality"},
		{"question": "The 3rd of a major chord is always a...?", "choices": ["Perfect 3rd", "Major 3rd", "Minor 3rd"], "correct_index": 1, "concept_id": "theory:major_chord_3rd"},
		{"question": "E to F (on a piano) is what interval?", "choices": ["Minor 2nd (half step)", "Major 2nd (whole step)", "Minor 3rd"], "correct_index": 0, "concept_id": "theory:e_to_f_quality"},
	]


static func find_theory_item_by_concept_id(concept_id: String) -> Dictionary:
	# Search all theory pools for a matching concept
	var pools: Array = [
		clef_theory_pool(), rhythm_theory_pool(), accidental_theory_pool(),
		key_sig_theory_pool(), interval_theory_pool(), chord_theory_pool(),
		grand_staff_theory_pool(), minor_scale_theory_pool(),
		interval_quality_theory_pool(),
	]
	for pool in pools:
		for item in pool:
			var item_concept: String = item.get("concept_id", "")
			if item_concept == concept_id:
				return item
	return {}


static func ledger_line_pool() -> Array:
	return [
		{"clef": "treble", "note_name": "C", "note_step": 10, "note_id": "C4"},
		{"clef": "treble", "note_name": "B", "note_step": 11, "note_id": "B3"},
		{"clef": "treble", "note_name": "A", "note_step": 12, "note_id": "A3"},
		{"clef": "bass", "note_name": "C", "note_step": -2, "note_id": "C4"},
		{"clef": "bass", "note_name": "D", "note_step": -3, "note_id": "D4"},
		{"clef": "bass", "note_name": "E", "note_step": -4, "note_id": "E4"},
	]
