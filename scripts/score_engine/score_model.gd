extends RefCounted
class_name ScoreModel

# Canonical Score data structures used by StaffRenderer.
#
# A Score is a Dictionary with the shape:
#   {
#     "title": String,
#     "key_fifths": int (-7..7),       # MusicXML-style key signature: positive = sharps, negative = flats
#     "key_is_minor": bool,            # affects accidental display preferences
#     "time_sig_num": int,
#     "time_sig_den": int,
#     "tempo_bpm": int,
#     "staves": Array[Staff],
#   }
#
# A Staff is:
#   {
#     "clef": String                   # "treble" | "bass" | "alto" | "tenor"
#     "measures": Array[Measure],
#   }
#
# A Measure is:
#   {
#     "notes": Array[Note],            # in time order; can be chord groups via "voice"
#   }
#
# A Note is:
#   {
#     "midi": int (-1 for rest),
#     "duration_beats": float,         # in quarter-note units
#     "beat_offset": float,            # offset from start of the score (computed by builder)
#     "rest": bool,
#     "voice": int,                    # 1, 2, ... (default 1 — single voice)
#   }
#
# The "highlight_index" field on the Score (top-level) tells the renderer which
# global note index to highlight (e.g., during playback). -1 means no highlight.

static func new_score(title: String = "") -> Dictionary:
	return {
		"title": title,
		"key_fifths": 0,
		"key_is_minor": false,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"tempo_bpm": 80,
		"staves": [],
		"highlight_index": -1,
		"highlight_beat": -1.0,
	}


static func new_staff(clef: String = "treble") -> Dictionary:
	return {
		"clef": clef,
		"measures": [],
	}


static func new_measure() -> Dictionary:
	return {
		"notes": [],
	}


static func new_note(midi: int, duration_beats: float, beat_offset: float = 0.0, voice: int = 1) -> Dictionary:
	return {
		"midi": int(midi),
		"duration_beats": float(duration_beats),
		"beat_offset": float(beat_offset),
		"rest": int(midi) < 0,
		"voice": int(voice),
	}


static func new_rest(duration_beats: float, beat_offset: float = 0.0, voice: int = 1) -> Dictionary:
	var n := new_note(-1, duration_beats, beat_offset, voice)
	n["rest"] = true
	return n


# Convert a flat list of notes into a Score with measures grouped by time signature.
# Useful for migrating the existing exercise-dict format into the canonical Score model.
static func from_flat_notes(
	flat_notes: Array,
	clef: String = "treble",
	time_sig_num: int = 4,
	time_sig_den: int = 4,
	key_fifths: int = 0,
	key_is_minor: bool = false,
	tempo_bpm: int = 80,
	title: String = ""
) -> Dictionary:
	var score := new_score(title)
	score["key_fifths"] = key_fifths
	score["key_is_minor"] = key_is_minor
	score["time_sig_num"] = time_sig_num
	score["time_sig_den"] = time_sig_den
	score["tempo_bpm"] = tempo_bpm
	var staff := new_staff(clef)
	var beats_per_bar: float = float(time_sig_num) * (4.0 / float(time_sig_den))
	# Group notes into measures by beat_offset.
	var measures: Array = []
	for n in flat_notes:
		var beat: float = float(n.get("beat_offset", 0.0))
		var bar_idx: int = int(floor(beat / beats_per_bar))
		while measures.size() <= bar_idx:
			measures.append(new_measure())
		var note_dict: Dictionary = {
			"midi": int(n.get("midi", -1)),
			"duration_beats": float(n.get("duration_beats", 0.5)),
			"beat_offset": float(n.get("beat_offset", 0.0)),
			"rest": bool(n.get("rest", false)) or int(n.get("midi", -1)) < 0,
			"voice": int(n.get("voice", 1)),
			"fingering": int(n.get("fingering", 0)),
		}
		(measures[bar_idx]["notes"] as Array).append(note_dict)
	if measures.is_empty():
		measures.append(new_measure())
	staff["measures"] = measures
	score["staves"].append(staff)
	return score


# Build a grand-staff Score (treble + bass) from a flat list of notes, auto-routing each
# note to the appropriate staff based on MIDI pitch (≥60 → treble, <60 → bass).
# Useful for chord display where the player's notes span both clefs.
static func from_flat_notes_grand_staff(
	flat_notes: Array,
	time_sig_num: int = 4,
	time_sig_den: int = 4,
	key_fifths: int = 0,
	key_is_minor: bool = false,
	tempo_bpm: int = 80,
	title: String = "",
	split_midi: int = 60
) -> Dictionary:
	var score := new_score(title)
	score["key_fifths"] = key_fifths
	score["key_is_minor"] = key_is_minor
	score["time_sig_num"] = time_sig_num
	score["time_sig_den"] = time_sig_den
	score["tempo_bpm"] = tempo_bpm
	var treble_notes: Array = []
	var bass_notes: Array = []
	for n in flat_notes:
		var midi: int = int(n.get("midi", -1))
		if int(n.get("staff", 0)) == 1:
			treble_notes.append(n)
		elif int(n.get("staff", 0)) == 2:
			bass_notes.append(n)
		elif midi >= split_midi:
			treble_notes.append(n)
		else:
			bass_notes.append(n)
	# If one staff is empty, add a whole rest so the bar still renders.
	if treble_notes.is_empty():
		treble_notes.append({"midi": -1, "duration_beats": 4.0, "beat_offset": 0.0, "rest": true})
	if bass_notes.is_empty():
		bass_notes.append({"midi": -1, "duration_beats": 4.0, "beat_offset": 0.0, "rest": true})
	var beats_per_bar: float = float(time_sig_num) * (4.0 / float(time_sig_den))
	var treble_staff := _build_staff_from_notes(treble_notes, "treble", beats_per_bar)
	var bass_staff := _build_staff_from_notes(bass_notes, "bass", beats_per_bar)
	_equalize_grand_staff_measures([treble_staff, bass_staff], beats_per_bar)
	score["staves"].append(treble_staff)
	score["staves"].append(bass_staff)
	return score


# Build a grand-staff Score from explicit RH and LH note streams. Useful for two-hand
# exercises (Hanon, Czerny, scales-in-thirds) where each hand has its own pattern.
# Treble clef for RH (top staff), bass clef for LH (bottom staff).
static func from_two_hand_notes(
	rh_notes: Array,
	lh_notes: Array,
	time_sig_num: int = 4,
	time_sig_den: int = 4,
	key_fifths: int = 0,
	key_is_minor: bool = false,
	tempo_bpm: int = 80,
	title: String = ""
) -> Dictionary:
	var score := new_score(title)
	score["key_fifths"] = key_fifths
	score["key_is_minor"] = key_is_minor
	score["time_sig_num"] = time_sig_num
	score["time_sig_den"] = time_sig_den
	score["tempo_bpm"] = tempo_bpm
	var beats_per_bar: float = float(time_sig_num) * (4.0 / float(time_sig_den))
	if rh_notes.is_empty():
		rh_notes = [{"midi": -1, "duration_beats": 4.0, "beat_offset": 0.0, "rest": true}]
	if lh_notes.is_empty():
		lh_notes = [{"midi": -1, "duration_beats": 4.0, "beat_offset": 0.0, "rest": true}]
	var treble_staff := _build_staff_from_notes(rh_notes, "treble", beats_per_bar)
	var bass_staff := _build_staff_from_notes(lh_notes, "bass", beats_per_bar)
	_equalize_grand_staff_measures([treble_staff, bass_staff], beats_per_bar)
	score["staves"].append(treble_staff)
	score["staves"].append(bass_staff)
	return score


static func _equalize_grand_staff_measures(staves: Array, beats_per_bar: float) -> void:
	var max_measures := 0
	for staff_any in staves:
		var staff: Dictionary = staff_any
		max_measures = maxi(max_measures, (staff.get("measures", []) as Array).size())
	for staff_any in staves:
		var staff: Dictionary = staff_any
		var measures: Array = staff.get("measures", [])
		var staff_number := 1 if str(staff.get("clef", "treble")) == "treble" else 2
		while measures.size() < max_measures:
			measures.append(new_measure())
		for measure_idx in range(measures.size()):
			var measure: Dictionary = measures[measure_idx]
			var measure_notes: Array = measure.get("notes", [])
			if measure_notes.is_empty():
				measure_notes.append({
					"midi": -1,
					"duration_beats": beats_per_bar,
					"beat_offset": float(measure_idx) * beats_per_bar,
					"rest": true,
					"voice": staff_number,
					"staff": staff_number,
				})
			measure["notes"] = measure_notes
		staff["measures"] = measures


static func _build_staff_from_notes(notes: Array, clef: String, beats_per_bar: float) -> Dictionary:
	var staff := new_staff(clef)
	var measures: Array = []
	for n in notes:
		var beat: float = float(n.get("beat_offset", 0.0))
		var bar_idx: int = int(floor(beat / beats_per_bar))
		while measures.size() <= bar_idx:
			measures.append(new_measure())
		(measures[bar_idx]["notes"] as Array).append({
			"midi": int(n.get("midi", -1)),
			"duration_beats": float(n.get("duration_beats", 0.5)),
			"beat_offset": float(n.get("beat_offset", 0.0)),
			"rest": bool(n.get("rest", false)) or int(n.get("midi", -1)) < 0,
			"voice": int(n.get("voice", 1)),
			"staff": int(n.get("staff", 1 if clef == "treble" else 2)),
			"fingering": int(n.get("fingering", 0)),
		})
	if measures.is_empty():
		measures.append(new_measure())
	staff["measures"] = measures
	return staff
