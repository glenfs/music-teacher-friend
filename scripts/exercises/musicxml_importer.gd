class_name MusicXMLImporter
extends RefCounted

# Imports a MusicXML (.musicxml / .xml) or compressed-MusicXML (.mxl) file
# and converts it to the Practice Drills exercise dict format. Pure data
# parser — no Node dependency.
#
# MVP scope (intentionally narrow — the format is huge):
#   • Single part (the first <part> in the score)
#   • Pitch + duration extracted; rests preserved
#   • Time signature, key signature (fifths), tempo, title
#   • Treble or bass clef detected from first <clef>
#   • Multi-voice within a part collapses to the first voice
#   • Chord notes (notes marked <chord/>) are merged into a single
#     beat-position event — represented as the lowest note for now
#   • Triplets, grace notes, ties: NOT yet handled (treated as plain notes)
#
# Output exercise dict matches what _build_exercise_for_staff_mode emits:
#   { title, tempo_bpm, key_pc, key_is_minor, time_sig_num, time_sig_den,
#     staff_mode, notes: [{midi, duration_beats, beat_offset, rest}],
#     total_beats }


const LETTER_PC := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
# Maps <fifths> value → (tonic pitch class, prefer-flats flag) for major keys.
# Minor keys derive the tonic by subtracting 3 semitones from the relative-major tonic.
const FIFTHS_TO_TONIC_MAJOR := {
	0: 0, 1: 7, 2: 2, 3: 9, 4: 4, 5: 11, 6: 6, 7: 1,
	-1: 5, -2: 10, -3: 3, -4: 8, -5: 1, -6: 6, -7: 11,
}


# Entry point. Pass the raw file bytes (XML or zipped MXL); returns the
# exercise dict, or {} with an "error" field set on failure.
static func import_bytes(raw_bytes: PackedByteArray, source_filename: String = "") -> Dictionary:
	if raw_bytes.is_empty():
		return {"error": "Empty file."}
	# Detect compressed (.mxl) by ZIP signature "PK\x03\x04".
	var xml_text: String = ""
	if raw_bytes.size() >= 4 and raw_bytes[0] == 0x50 and raw_bytes[1] == 0x4B and raw_bytes[2] == 0x03 and raw_bytes[3] == 0x04:
		xml_text = _extract_from_mxl(raw_bytes)
		if xml_text == "":
			return {"error": "Could not extract MusicXML from compressed (.mxl) archive."}
	else:
		xml_text = raw_bytes.get_string_from_utf8()
		if xml_text.strip_edges().is_empty():
			# Try latin-1 in case the file uses a non-UTF-8 declaration but the
			# bytes happen to be ASCII-compatible.
			xml_text = raw_bytes.get_string_from_ascii()
	if xml_text.strip_edges().is_empty():
		return {"error": "File appears empty or unreadable."}
	return _parse_xml(xml_text, source_filename)


# Reads the first .xml file out of an MXL ZIP archive. The MXL spec puts a
# META-INF/container.xml that points to the score's rootfile, but in practice
# the score is almost always a single top-level .xml file in the archive;
# we accept either form.
static func _extract_from_mxl(raw_bytes: PackedByteArray) -> String:
	var tmp_path: String = "user://_clefira_musicxml_import.zip"
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return ""
	tmp_file.store_buffer(raw_bytes)
	tmp_file.close()
	var reader := ZIPReader.new()
	if reader.open(tmp_path) != OK:
		return ""
	var files := reader.get_files()
	var container_path := ""
	for f in files:
		if f.to_lower() == "meta-inf/container.xml":
			container_path = f
			break
	var score_path := ""
	if container_path != "":
		var container_bytes := reader.read_file(container_path)
		var container_text := container_bytes.get_string_from_utf8()
		# Cheap regex-ish extract of the first rootfile@full-path.
		var ri := container_text.find("full-path=\"")
		if ri >= 0:
			var start := ri + 11
			var end := container_text.find("\"", start)
			if end > start:
				score_path = container_text.substr(start, end - start)
	if score_path == "":
		# Fall back to first .xml that isn't the container.
		for f in files:
			var lo := f.to_lower()
			if lo.ends_with(".xml") and not lo.begins_with("meta-inf/"):
				score_path = f
				break
	if score_path == "":
		reader.close()
		return ""
	var score_bytes := reader.read_file(score_path)
	reader.close()
	return score_bytes.get_string_from_utf8()


# Parses a MusicXML string into an exercise dict.
static func _parse_xml(xml_text: String, source_filename: String) -> Dictionary:
	var parser := XMLParser.new()
	if parser.open_buffer(xml_text.to_utf8_buffer()) != OK:
		return {"error": "XML parser failed to open the file."}

	# Aggregate state
	var title: String = ""
	var movement_title: String = ""
	var part_name: String = ""
	var tempo_bpm: int = 80
	var time_num: int = 4
	var time_den: int = 4
	var fifths: int = 0
	var mode_minor: bool = false
	var divisions: int = 1     # ticks per quarter
	var staff_mode: String = "treble"
	var clef_seen: bool = false
	var notes_out: Array = []
	var current_part_id: String = ""
	var first_part_id: String = ""
	var inside_first_part: bool = false
	var current_beat_offset: float = 0.0  # in quarter notes (== beats when den=4)
	var pending_chord_first_offset: float = -1.0
	var prev_note_duration_beats: float = 0.0
	var total_beats: float = 0.0

	# Parser cursor + small lookahead for element text.
	while true:
		var err := parser.read()
		if err == ERR_FILE_EOF:
			break
		if err != OK:
			break
		var node_type := parser.get_node_type()
		if node_type != XMLParser.NODE_ELEMENT:
			continue
		var name := parser.get_node_name()
		match name:
			"work-title", "movement-title":
				var t := _read_element_text(parser)
				if name == "work-title":
					title = t
				else:
					movement_title = t
			"part-list":
				# Capture the first <score-part id="...">.
				while true:
					var e2 := parser.read()
					if e2 != OK or parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "part-list":
						break
					if e2 == ERR_FILE_EOF:
						break
					if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "score-part":
						if first_part_id == "":
							first_part_id = parser.get_named_attribute_value_safe("id")
					if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "part-name":
						var pn := _read_element_text(parser)
						if part_name == "":
							part_name = pn
			"part":
				current_part_id = parser.get_named_attribute_value_safe("id")
				inside_first_part = (first_part_id == "" or current_part_id == first_part_id)
				if inside_first_part:
					current_beat_offset = 0.0
			"divisions":
				if inside_first_part:
					var d_str := _read_element_text(parser)
					var d_val := int(d_str)
					if d_val > 0:
						divisions = d_val
			"fifths":
				if inside_first_part:
					var f_str := _read_element_text(parser)
					fifths = int(f_str)
			"mode":
				if inside_first_part:
					var m_str := _read_element_text(parser).to_lower()
					mode_minor = (m_str == "minor")
			"beats":
				if inside_first_part:
					var b_str := _read_element_text(parser)
					var b_val := int(b_str)
					if b_val > 0:
						time_num = b_val
			"beat-type":
				if inside_first_part:
					var bt_str := _read_element_text(parser)
					var bt_val := int(bt_str)
					if bt_val > 0:
						time_den = bt_val
			"sign":
				if inside_first_part and not clef_seen:
					var s_str := _read_element_text(parser).to_upper()
					if s_str == "F":
						staff_mode = "bass"
					elif s_str == "G":
						staff_mode = "treble"
					clef_seen = true
			"sound":
				if inside_first_part:
					var t_str := parser.get_named_attribute_value_safe("tempo")
					if t_str != "":
						var t_val := int(float(t_str))
						if t_val > 0:
							tempo_bpm = t_val
			"note":
				if inside_first_part:
					var note_data := _parse_note(parser, divisions, time_den)
					if not note_data.is_empty():
						# Chord notes share the same beat_offset as the prior note.
						var is_chord: bool = bool(note_data.get("is_chord", false))
						var dur_beats: float = float(note_data.get("duration_beats", 0.0))
						var is_rest: bool = bool(note_data.get("rest", false))
						var midi_v: int = int(note_data.get("midi", -1))
						var event_offset: float = current_beat_offset
						if is_chord:
							# Snap to the previous note's start position.
							event_offset = current_beat_offset - prev_note_duration_beats
							# For chord notes we keep only the lowest MIDI value
							# in the output (MVP — full-chord support comes
							# with multi-voice in Phase 2). Replace the prior
							# entry if this pitch is lower.
							if not is_rest and not notes_out.is_empty():
								var prev: Dictionary = notes_out[-1]
								var prev_midi: int = int(prev.get("midi", 127))
								if midi_v < prev_midi:
									prev["midi"] = midi_v
									notes_out[-1] = prev
							continue
						else:
							notes_out.append({
								"midi": midi_v if not is_rest else -1,
								"duration_beats": dur_beats,
								"beat_offset": event_offset,
								"rest": is_rest,
							})
							prev_note_duration_beats = dur_beats
							current_beat_offset += dur_beats
							total_beats = maxf(total_beats, current_beat_offset)
			_:
				pass

	if notes_out.is_empty():
		return {"error": "No notes found in the file. Is it really a MusicXML score?"}

	var resolved_title: String = movement_title
	if resolved_title == "":
		resolved_title = title
	if resolved_title == "":
		resolved_title = source_filename if source_filename != "" else "Imported score"
	# Convert fifths to tonic pitch class (account for minor mode).
	var tonic_pc: int = int(FIFTHS_TO_TONIC_MAJOR.get(fifths, 0))
	if mode_minor:
		tonic_pc = ((tonic_pc - 3) % 12 + 12) % 12
	# total_beats normalized to the time signature's beat units.
	return {
		"title": resolved_title,
		"tempo_bpm": tempo_bpm,
		"key_pc": tonic_pc,
		"key_is_minor": mode_minor,
		"time_sig_num": time_num,
		"time_sig_den": time_den,
		"staff_mode": staff_mode,
		"notes": notes_out,
		"total_beats": total_beats,
		"source": "musicxml",
	}


# Reads the next CHARACTERS node and returns its stripped text, then
# advances past the closing element. Designed for leaf-text elements like
# <divisions>4</divisions>.
static func _read_element_text(parser: XMLParser) -> String:
	var text: String = ""
	while true:
		var e := parser.read()
		if e != OK:
			break
		var t := parser.get_node_type()
		if t == XMLParser.NODE_TEXT:
			text += parser.get_node_data()
		elif t == XMLParser.NODE_ELEMENT_END:
			break
	return text.strip_edges()


# Parses a single <note>...</note> block. Returns a partial dict:
#   { midi, duration_beats, rest, is_chord }
# Caller assembles the final note_out entry.
static func _parse_note(parser: XMLParser, divisions: int, time_den: int) -> Dictionary:
	var step: String = ""
	var alter: int = 0
	var octave: int = 4
	var duration: int = 0
	var rest: bool = false
	var is_chord: bool = false
	var has_pitch: bool = false
	while true:
		var e := parser.read()
		if e != OK:
			break
		var t := parser.get_node_type()
		if t == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "note":
			break
		if t != XMLParser.NODE_ELEMENT:
			continue
		var en := parser.get_node_name()
		match en:
			"chord":
				is_chord = true
			"rest":
				rest = true
			"step":
				step = _read_element_text(parser)
				has_pitch = true
			"alter":
				var a_str := _read_element_text(parser)
				alter = int(float(a_str))
			"octave":
				octave = int(_read_element_text(parser))
			"duration":
				duration = int(_read_element_text(parser))
			_:
				pass
	# Convert duration to beats. <duration> is in divisions (per quarter).
	# A beat in the time signature is a (4 / time_den) of a whole note, so
	# 1 beat = (4 / time_den) quarter notes = (4 / time_den) * divisions ticks.
	# duration_in_beats = duration_ticks / divisions * (time_den / 4)
	var dur_beats: float = 0.0
	if divisions > 0 and duration > 0:
		dur_beats = (float(duration) / float(divisions)) * (float(time_den) / 4.0)
	# Convert pitch to MIDI.
	var midi_val: int = -1
	if has_pitch and not rest:
		var pc: int = int(LETTER_PC.get(step.to_upper(), 0)) + alter
		# MusicXML <octave> uses scientific pitch (C4 = middle C, MIDI 60).
		midi_val = (octave + 1) * 12 + pc
		if midi_val < 0 or midi_val > 127:
			midi_val = -1
	return {
		"midi": midi_val,
		"duration_beats": dur_beats,
		"rest": rest,
		"is_chord": is_chord,
	}
