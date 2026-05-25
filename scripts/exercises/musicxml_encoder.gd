extends RefCounted
class_name MusicXMLEncoder

# Converts an exercise dict (from TechnicalExerciseGenerator) into a valid
# MusicXML 4.0 partwise score string. The output opens cleanly in MuseScore,
# Finale, Sibelius, Dorico, and Flat.io.

const TechnicalExerciseGeneratorScript = preload("res://scripts/exercises/technical_exercise_generator.gd")

const DIVISIONS_PER_QUARTER := 4  # 4 ticks per quarter note → eighth=2, quarter=4, half=8, whole=16


static func encode(exercise: Dictionary) -> String:
	var sb := PackedStringArray()
	sb.append('<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n')
	sb.append('<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">\n')
	sb.append('<score-partwise version="4.0">\n')
	sb.append('  <work>\n')
	sb.append('    <work-title>%s</work-title>\n' % _xml_escape(str(exercise.get("title", "Practice Exercise"))))
	sb.append('  </work>\n')
	sb.append('  <identification>\n')
	sb.append('    <encoding>\n')
	sb.append('      <software>Clefira Practice Drills</software>\n')
	sb.append('      <encoding-date>%s</encoding-date>\n' % _today_iso())
	sb.append('    </encoding>\n')
	sb.append('  </identification>\n')
	sb.append('  <part-list>\n')
	sb.append('    <score-part id="P1">\n')
	sb.append('      <part-name>Piano</part-name>\n')
	sb.append('    </score-part>\n')
	sb.append('  </part-list>\n')
	sb.append('  <part id="P1">\n')

	var fifths: int = int(exercise.get("fifths", 0))
	var time_num: int = int(exercise.get("time_sig_num", 4))
	var time_den: int = int(exercise.get("time_sig_den", 4))
	var tempo_bpm: int = int(exercise.get("tempo_bpm", 80))
	var hand: String = str(exercise.get("hand", "right"))
	var is_grand_staff: bool = hand == "both" or str(exercise.get("staff_mode", "")) == "grand"
	var clef_sign := "G" if hand == "right" else "F"
	var clef_line := 2 if hand == "right" else 4
	var notes: Array = exercise.get("notes", [])

	# Group notes into measures based on beat_offset (4 beats per measure in 4/4).
	var beats_per_bar: float = float(time_num) * (4.0 / float(time_den))
	var measures: Array = []  # Array[Array[note_dict]]
	for n in notes:
		var beat: float = float(n.get("beat_offset", 0.0))
		var bar_idx: int = int(floor(beat / beats_per_bar))
		while measures.size() <= bar_idx:
			measures.append([])
		measures[bar_idx].append(n)
	if measures.is_empty():
		measures.append([])

	for bar_idx in range(measures.size()):
		var bar_notes: Array = measures[bar_idx]
		sb.append('    <measure number="%d">\n' % (bar_idx + 1))
		if bar_idx == 0:
			sb.append('      <attributes>\n')
			sb.append('        <divisions>%d</divisions>\n' % DIVISIONS_PER_QUARTER)
			sb.append('        <key><fifths>%d</fifths></key>\n' % fifths)
			sb.append('        <time><beats>%d</beats><beat-type>%d</beat-type></time>\n' % [time_num, time_den])
			if is_grand_staff:
				sb.append('        <staves>2</staves>\n')
				sb.append('        <clef number="1"><sign>G</sign><line>2</line></clef>\n')
				sb.append('        <clef number="2"><sign>F</sign><line>4</line></clef>\n')
			else:
				sb.append('        <clef><sign>%s</sign><line>%d</line></clef>\n' % [clef_sign, clef_line])
			sb.append('      </attributes>\n')
			sb.append('      <direction placement="above">\n')
			sb.append('        <direction-type>\n')
			sb.append('          <metronome><beat-unit>quarter</beat-unit><per-minute>%d</per-minute></metronome>\n' % tempo_bpm)
			sb.append('        </direction-type>\n')
			sb.append('        <sound tempo="%d"/>\n' % tempo_bpm)
			sb.append('      </direction>\n')
		if is_grand_staff:
			var measure_ticks: int = int(round(beats_per_bar * float(DIVISIONS_PER_QUARTER)))
			var treble_notes := _notes_for_staff(bar_notes, 1)
			var bass_notes := _notes_for_staff(bar_notes, 2)
			if treble_notes.is_empty():
				treble_notes.append({"midi": -1, "duration_beats": beats_per_bar, "rest": true, "voice": 1, "staff": 1})
			if bass_notes.is_empty():
				bass_notes.append({"midi": -1, "duration_beats": beats_per_bar, "rest": true, "voice": 2, "staff": 2})
			for n in treble_notes:
				sb.append(_encode_note(n, fifths))
			sb.append('      <backup><duration>%d</duration></backup>\n' % measure_ticks)
			for n in bass_notes:
				sb.append(_encode_note(n, fifths))
		else:
			for n in bar_notes:
				sb.append(_encode_note(n, fifths))
		sb.append('    </measure>\n')

	sb.append('  </part>\n')
	sb.append('</score-partwise>\n')
	return "".join(sb)


static func _notes_for_staff(notes: Array, staff_number: int) -> Array:
	var out: Array = []
	for note_any in notes:
		var note: Dictionary = note_any
		var staff: int = int(note.get("staff", 1 if int(note.get("midi", -1)) >= 60 else 2))
		if staff == staff_number:
			out.append(note)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var beat_a := float(a.get("beat_offset", 0.0))
		var beat_b := float(b.get("beat_offset", 0.0))
		if absf(beat_a - beat_b) > 0.001:
			return beat_a < beat_b
		return int(a.get("midi", -1)) < int(b.get("midi", -1))
	)
	return out


static func _encode_note(note: Dictionary, fifths: int) -> String:
	var dur_beats: float = float(note.get("duration_beats", 0.5))
	var ticks: int = int(round(dur_beats * float(DIVISIONS_PER_QUARTER)))
	var type_str: String = _duration_type(dur_beats)
	var is_rest: bool = bool(note.get("rest", false)) or int(note.get("midi", -1)) < 0
	var lines := PackedStringArray()
	lines.append('      <note>\n')
	if is_rest:
		lines.append('        <rest/>\n')
	else:
		var spec: Array = TechnicalExerciseGeneratorScript.midi_to_step_alter_octave(int(note["midi"]), fifths)
		var step: String = str(spec[0])
		var alter: int = int(spec[1])
		var octave: int = int(spec[2])
		lines.append('        <pitch>\n')
		lines.append('          <step>%s</step>\n' % step)
		if alter != 0:
			lines.append('          <alter>%d</alter>\n' % alter)
		lines.append('          <octave>%d</octave>\n' % octave)
		lines.append('        </pitch>\n')
	lines.append('        <duration>%d</duration>\n' % ticks)
	if note.has("voice"):
		lines.append('        <voice>%d</voice>\n' % int(note.get("voice", 1)))
	lines.append('        <type>%s</type>\n' % type_str)
	if note.has("staff"):
		lines.append('        <staff>%d</staff>\n' % int(note.get("staff", 1)))
	lines.append('      </note>\n')
	return "".join(lines)


static func _duration_type(dur_beats: float) -> String:
	# Map duration in quarter-note beats to a MusicXML <type> value.
	if absf(dur_beats - 4.0) < 0.01: return "whole"
	if absf(dur_beats - 2.0) < 0.01: return "half"
	if absf(dur_beats - 1.0) < 0.01: return "quarter"
	if absf(dur_beats - 0.5) < 0.01: return "eighth"
	if absf(dur_beats - 0.25) < 0.01: return "16th"
	return "eighth"  # safe fallback


static func _xml_escape(s: String) -> String:
	var out := s
	out = out.replace("&", "&amp;")
	out = out.replace("<", "&lt;")
	out = out.replace(">", "&gt;")
	out = out.replace('"', "&quot;")
	out = out.replace("'", "&apos;")
	return out


static func _today_iso() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


# Convenience: write the encoded MusicXML to a file. Returns the absolute path
# (in user-fs terms, e.g. "user://exercises/...musicxml") on success, or "" on failure.
static func save_to_file(exercise: Dictionary, filename: String = "") -> String:
	var name := filename
	if name.is_empty():
		var safe_title := str(exercise.get("title", "exercise")).to_lower()
		safe_title = safe_title.replace(" ", "_").replace("—", "-").replace("/", "_")
		# Strip non-alphanumeric/underscore/dash for filesystem safety.
		var clean := ""
		for c in safe_title:
			if c.is_valid_identifier() or c == "-" or c == "_":
				clean += c
		var stamp := str(int(Time.get_unix_time_from_system()))
		name = "%s_%s.musicxml" % [clean, stamp]
	var dir_path := "user://exercises"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)
	var full := "%s/%s" % [dir_path, name]
	var f := FileAccess.open(full, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(encode(exercise))
	f.close()
	return full
