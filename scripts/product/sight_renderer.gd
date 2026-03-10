class_name SightRenderer
extends RefCounted


func selector_range_for_clef(clef_name: String) -> Dictionary:
	if clef_name == "Bass":
		return {
			"start_note": "C2",
			"end_note": "E4"
		}
	return {
		"start_note": "A3",
		"end_note": "C6"
	}


func default_selected_notes_for_clef(clef_name: String) -> PackedStringArray:
	if clef_name == "Bass":
		return PackedStringArray(["F3", "G3", "A3", "B3", "C4", "D4", "E4"])
	return PackedStringArray(["A3", "B3", "C4", "D4", "E4", "F4", "G4"])


func note_set_for_clef(clef_name: String, selected_notes_by_clef: Dictionary, fallback_notes_by_clef: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if selected_notes_by_clef.has(clef_name):
		var existing: Variant = selected_notes_by_clef[clef_name]
		if existing is PackedStringArray:
			out = existing as PackedStringArray
		elif existing is Array:
			for item in existing:
				out.append(str(item))
	if out.is_empty() and fallback_notes_by_clef.has(clef_name):
		var fallback_any: Variant = fallback_notes_by_clef[clef_name]
		if fallback_any is PackedStringArray:
			out = fallback_any as PackedStringArray
		elif fallback_any is Array:
			for item2 in fallback_any:
				out.append(str(item2))
	return sanitize_note_set_for_clef(clef_name, out)


func sanitize_note_set_for_clef(clef_name: String, notes: Variant) -> PackedStringArray:
	var raw := PackedStringArray()
	if notes is PackedStringArray:
		raw = notes as PackedStringArray
	elif notes is Array:
		for item in notes:
			raw.append(str(item))
	if raw.is_empty():
		raw = default_selected_notes_for_clef(clef_name)
	var range_cfg := selector_range_for_clef(clef_name)
	var start_midi := note_name_to_midi(str(range_cfg.get("start_note", "C4")))
	var end_midi := note_name_to_midi(str(range_cfg.get("end_note", "C5")))
	if start_midi > end_midi:
		var swap := start_midi
		start_midi = end_midi
		end_midi = swap
	var midi_set: Dictionary = {}
	for note_name in raw:
		var midi_note := note_name_to_midi(str(note_name))
		if midi_note < start_midi or midi_note > end_midi:
			continue
		if not is_natural_midi(midi_note):
			continue
		midi_set[midi_note] = true
	var midi_sorted := midi_set.keys()
	midi_sorted.sort()
	if midi_sorted.size() < 3:
		var defaults := default_selected_notes_for_clef(clef_name)
		for default_note in defaults:
			var default_midi := note_name_to_midi(str(default_note))
			if default_midi < start_midi or default_midi > end_midi:
				continue
			if not is_natural_midi(default_midi):
				continue
			midi_set[default_midi] = true
			if midi_set.size() >= 3:
				break
		midi_sorted = midi_set.keys()
		midi_sorted.sort()
	var out := PackedStringArray()
	for midi_note_v in midi_sorted:
		out.append(midi_to_note_name(int(midi_note_v)))
	return out


func derive_range_steps_from_selected_notes(clef_name: String, selected_notes: PackedStringArray, bounds: Vector2i) -> Vector2i:
	var min_step := 999
	var max_step := -999
	for note_name in selected_notes:
		var step := sight_step_for_label_in_clef(str(note_name), clef_name, bounds)
		if step == 999:
			continue
		min_step = mini(min_step, step)
		max_step = maxi(max_step, step)
	if min_step == 999:
		return Vector2i(-4, 12)
	return Vector2i(
		clampi(min_step, bounds.x, bounds.y),
		clampi(max_step, min_step, bounds.y)
	)


func apply_note_selector(
	selector: Node,
	clef_name: String,
	selected_notes_by_clef: Dictionary,
	fallback_notes_by_clef: Dictionary,
	last_clef: String,
	last_start_note: String,
	last_end_note: String,
	selected_color: Color,
	bounds: Vector2i
) -> Dictionary:
	var selected := note_set_for_clef(clef_name, selected_notes_by_clef, fallback_notes_by_clef)
	if selected.is_empty():
		selected = default_selected_notes_for_clef(clef_name)
	var next_selected_notes := selected_notes_by_clef.duplicate(true)
	next_selected_notes[clef_name] = selected
	var range_cfg := selector_range_for_clef(clef_name)
	var start_note := str(range_cfg.get("start_note", "A3"))
	var end_note := str(range_cfg.get("end_note", "C6"))
	var needs_reconfigure := last_clef != clef_name or last_start_note != start_note or last_end_note != end_note
	var selector_config := {
		"start_note": start_note,
		"end_note": end_note,
		"selectable_white_only": true,
		"default_selected_set": selected,
		"min_selected_count": 3,
		"selected_color": selected_color
	}
	if selector != null:
		if needs_reconfigure:
			var animate_clef_switch := last_clef != "" and last_clef != clef_name
			if animate_clef_switch and selector.has_method("transition_to_config"):
				selector.call("transition_to_config", selector_config, selected)
			elif selector.has_method("configure"):
				selector.call("configure", selector_config)
		elif selector.has_method("set_selection"):
			selector.call("set_selection", selected, false)
	var derived := derive_range_steps_from_selected_notes(clef_name, selected, bounds)
	return {
		"selected_notes_by_clef": next_selected_notes,
		"last_clef": clef_name if needs_reconfigure else last_clef,
		"last_start_note": start_note if needs_reconfigure else last_start_note,
		"last_end_note": end_note if needs_reconfigure else last_end_note,
		"range_min_step": derived.x,
		"range_max_step": derived.y
	}


func sight_step_label_for_clef(step: int, clef_name: String) -> String:
	if clef_name == "Bass":
		var bass_labels := ["E4", "D4", "C4", "B3", "A3", "G3", "F3", "E3", "D3", "C3", "B2", "A2", "G2", "F2", "E2", "D2", "C2"]
		var bass_index := clampi(step + 4, 0, bass_labels.size() - 1)
		return bass_labels[bass_index]
	var treble_labels := ["C6", "B5", "A5", "G5", "F5", "E5", "D5", "C5", "B4", "A4", "G4", "F4", "E4", "D4", "C4", "B3", "A3"]
	var treble_index := clampi(step + 4, 0, treble_labels.size() - 1)
	return treble_labels[treble_index]


func sight_step_for_label_in_clef(note_label: String, clef_name: String, bounds: Vector2i) -> int:
	var target: String = note_label.strip_edges()
	for step in range(bounds.x, bounds.y + 1):
		if sight_step_label_for_clef(step, clef_name) == target:
			return step
	return 999


func is_natural_midi(midi_note: int) -> bool:
	var pc := posmod(midi_note, 12)
	return pc == 0 or pc == 2 or pc == 4 or pc == 5 or pc == 7 or pc == 9 or pc == 11


func midi_to_note_name(midi_note: int) -> String:
	var names := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var pc := posmod(midi_note, 12)
	var octave := int(floor(float(midi_note) / 12.0)) - 1
	return "%s%d" % [names[pc], octave]


func note_name_to_midi(note_name: String) -> int:
	var stripped := note_name.strip_edges()
	if stripped.length() < 2:
		return -1
	var pc_map := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var letter := stripped.substr(0, 1).to_upper()
	if not pc_map.has(letter):
		return -1
	var index := 1
	var accidental := 0
	if index < stripped.length():
		var accidental_char := stripped.substr(index, 1)
		if accidental_char == "#":
			accidental = 1
			index += 1
		elif accidental_char == "b" or accidental_char == "B":
			accidental = -1
			index += 1
	if index >= stripped.length():
		return -1
	var octave := int(stripped.substr(index))
	return ((octave + 1) * 12) + int(pc_map[letter]) + accidental


func sight_note_name_with_key_signature(base_name: String, signature_source: Variant, force_natural: bool = false) -> String:
	if base_name.is_empty():
		return base_name
	var letter := base_name.substr(0, 1)
	var octave := base_name.substr(1)
	if force_natural:
		return "%s%s" % [letter, octave]
	var accidental_map: Dictionary = signature_source if typeof(signature_source) == TYPE_DICTIONARY else key_signature_accidental_map(str(signature_source))
	var accidental: int = int(accidental_map.get(letter, 0))
	if accidental > 0:
		return "%s#%s" % [letter, octave]
	if accidental < 0:
		return "%sb%s" % [letter, octave]
	return base_name


func update_sight_range_ui(
	info_label: Label,
	lower_value_label: Label,
	upper_value_label: Label,
	selected_mode: int,
	mode_sight: int,
	sight_mode: String,
	selected_clef: String,
	sight_range_min_step: int,
	sight_range_max_step: int,
	selected_notes: PackedStringArray
) -> void:
	if info_label == null:
		return
	var low_label := sight_step_label_for_clef(sight_range_max_step, selected_clef)
	var high_label := sight_step_label_for_clef(sight_range_min_step, selected_clef)
	info_label.text = "%s to %s | %d notes selected" % [low_label, high_label, selected_notes.size()]
	info_label.visible = selected_mode == mode_sight and sight_mode == "Notes"
	if lower_value_label != null:
		lower_value_label.text = low_label
	if upper_value_label != null:
		upper_value_label.text = high_label


func key_sig_letter_steps(sight_key_signature: String) -> Array:
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	if sight_key_signature == "1#":
		return [["F", sharp_sym]]
	if sight_key_signature == "2#":
		return [["F", sharp_sym], ["C", sharp_sym]]
	if sight_key_signature == "3#":
		return [["F", sharp_sym], ["C", sharp_sym], ["G", sharp_sym]]
	if sight_key_signature == "1b":
		return [["B", flat_sym]]
	if sight_key_signature == "2b":
		return [["B", flat_sym], ["E", flat_sym]]
	if sight_key_signature == "3b":
		return [["B", flat_sym], ["E", flat_sym], ["A", flat_sym]]
	return []


func key_signature_step_for_letter(letter: String, clef_name: String) -> int:
	if clef_name == "Treble":
		match letter:
			"F":
				return 0
			"C":
				return 3
			"G":
				return 1
			"B":
				return 4
			"E":
				return 1
			"A":
				return 7
	if clef_name == "Bass":
		match letter:
			"F":
				return 2
			"C":
				return 5
			"G":
				return 1
			"B":
				return 6
			"E":
				return 3
			"A":
				return 0
	var best_step := 4
	var best_dist := 999999
	for step in range(0, 9):
		if staff_step_name_for_clef(step, clef_name) != letter:
			continue
		var distance: int = absi(step - 4)
		if distance < best_dist:
			best_dist = distance
			best_step = step
	return best_step


func layout_key_signature_labels(
	labels: Array,
	defs: Array,
	selected_mode: int,
	mode_sight: int,
	sight_mode: String,
	selected_clef: String,
	grand_staff_active: bool,
	sight_key_signature: String,
	staff_clef_label: Label,
	sight_accidental_raise_y: float,
	active_staff_step_y: float,
	active_staff_line_gap_y: float,
	staff_center_y_for_step: Callable,
	key_signature_step_for_letter_callable: Callable
) -> void:
	if labels.is_empty() or staff_clef_label == null or not staff_center_y_for_step.is_valid():
		return
	var show_sig := selected_mode == mode_sight and (sight_mode == "Chords" or sight_mode == "Notes")
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	for index in range(labels.size()):
		var label := labels[index] as Label
		if label == null:
			continue
		if not show_sig or index >= defs.size():
			label.visible = false
			continue
		var definition: Array = defs[index]
		var letter := str(definition[0])
		var symbol := str(definition[1])
		var step := key_signature_step_for_letter(letter, selected_clef)
		if key_signature_step_for_letter_callable.is_valid():
			step = int(key_signature_step_for_letter_callable.call(letter, selected_clef))
		var y := float(staff_center_y_for_step.call(step))
		if symbol == sharp_sym:
			y -= 8.0
		elif symbol == flat_sym:
			y -= 18.0
		if sight_mode == "Chords" and grand_staff_active:
			y -= clampf(active_staff_step_y * 0.22, 2.0, 6.0)
		if selected_mode == mode_sight:
			y -= sight_accidental_raise_y
		if selected_clef == "Treble" and index == 2 and (sight_key_signature == "3#" or sight_key_signature == "3b"):
			y -= (active_staff_step_y * 2.0)
		label.text = symbol
		label.visible = true
		var clef_size := staff_clef_label.size
		if clef_size.x <= 1.0:
			clef_size = staff_clef_label.get_combined_minimum_size()
		var base_x := staff_clef_label.position.x + clef_size.x + 18.0
		base_x -= 8.0
		if sight_mode == "Chords" and grand_staff_active:
			base_x += clampf(active_staff_line_gap_y * 0.42, 6.0, 12.0)
		var spacing := 20.0
		if selected_clef == "Bass":
			base_x += 20.0
			spacing = 26.0
		elif symbol == flat_sym:
			base_x += 8.0
		label.position = Vector2(base_x + float(index) * spacing, y - 35.0)


func visual_staff_geometry(
	staff_area: Control,
	selected_mode: int,
	mode_sight: int,
	sight_mode: String,
	staff_left_x: float,
	staff_line_width: float
) -> Dictionary:
	var left := staff_left_x
	var width := staff_line_width
	if staff_area != null and selected_mode == mode_sight:
		if sight_mode == "Continuous" or sight_mode == "Rhythm Flow":
			width = maxf(720.0, staff_area.size.x - 44.0)
			left = 22.0
		else:
			width = minf(staff_line_width, maxf(560.0, staff_area.size.x * 0.56))
			left = clampf((staff_area.size.x - width) * 0.5 + 18.0, 18.0, staff_area.size.x - width - 10.0)
	return {"left": left, "width": width}


func sight_step_to_midi(
	step: int,
	clef_name: String,
	note_name_order: Array,
	accidental: int = 0,
	note_letter_pitch_class_callable: Callable = Callable()
) -> int:
	var anchor_letter := "A" if clef_name == "Bass" else "F"
	var anchor_octave := 3 if clef_name == "Bass" else 5
	var sequence_len: int = note_name_order.size()
	var anchor_index: int = note_name_order.find(anchor_letter)
	if anchor_index < 0 or sequence_len <= 0:
		return -1
	var anchor_diatonic: int = (anchor_octave * sequence_len) + anchor_index
	var note_diatonic: int = anchor_diatonic - step
	var octave: int = int(floor(float(note_diatonic) / float(sequence_len)))
	var letter_index: int = posmod(note_diatonic, sequence_len)
	var letter := str(note_name_order[letter_index])
	var pitch_class := note_letter_pitch_class(letter, accidental)
	if note_letter_pitch_class_callable.is_valid():
		pitch_class = int(note_letter_pitch_class_callable.call(letter, accidental))
	var midi: int = ((octave + 1) * 12) + pitch_class
	if midi < 0 or midi > 127:
		return -1
	return midi


func key_signature_accidental_map(sight_key_signature: String) -> Dictionary:
	var accidental_map := {"C": 0, "D": 0, "E": 0, "F": 0, "G": 0, "A": 0, "B": 0}
	if sight_key_signature == "1#":
		accidental_map["F"] = 1
	elif sight_key_signature == "2#":
		accidental_map["F"] = 1
		accidental_map["C"] = 1
	elif sight_key_signature == "3#":
		accidental_map["F"] = 1
		accidental_map["C"] = 1
		accidental_map["G"] = 1
	elif sight_key_signature == "1b":
		accidental_map["B"] = -1
	elif sight_key_signature == "2b":
		accidental_map["B"] = -1
		accidental_map["E"] = -1
	elif sight_key_signature == "3b":
		accidental_map["B"] = -1
		accidental_map["E"] = -1
		accidental_map["A"] = -1
	return accidental_map


func note_letter_pitch_class(letter: String, accidental: int) -> int:
	var base_map := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	return posmod(int(base_map.get(letter, 0)) + accidental, 12)


func sight_note_name_with_accidental(letter: String, accidental: int, octave: int = -100) -> String:
	var note_name := letter.strip_edges().to_upper()
	if note_name == "":
		note_name = "C"
	if accidental > 0:
		note_name += "#"
	elif accidental < 0:
		note_name += "b"
	if octave > -100:
		note_name += str(octave)
	return note_name


func staff_step_name_for_clef(step_index: int, clef_name: String) -> String:
	var treble_sequence := ["F", "E", "D", "C", "B", "A", "G"]
	var bass_sequence := ["A", "G", "F", "E", "D", "C", "B"]
	var sequence := bass_sequence if clef_name == "Bass" else treble_sequence
	return str(sequence[posmod(step_index, sequence.size())])


func sight_note_hint_lines(
	note_name: String,
	clef_name: String,
	clear_hint: bool,
	current_sight_display_step: int,
	sight_note_profiles: Dictionary,
	note_letter_from_name_callable: Callable
) -> Array[String]:
	var letter := str(note_letter_from_name_callable.call(note_name)) if note_letter_from_name_callable.is_valid() else note_name.substr(0, 1)
	var fallback_profile: Dictionary = sight_note_profiles.get("C", {}) as Dictionary if sight_note_profiles.get("C", {}) is Dictionary else {}
	var profile_any: Variant = sight_note_profiles.get(letter, fallback_profile)
	var profile: Dictionary = profile_any as Dictionary if typeof(profile_any) == TYPE_DICTIONARY else fallback_profile
	var is_line := posmod(current_sight_display_step, 2) == 0
	var lane_txt := "line" if is_line else "space"
	var note_bank := {
		"C": ["Look for middle-C area first.", "C is a common landmark.", "Find C, then move up/down.", "C often anchors reading.", "Say C first, then confirm."],
		"D": ["D is one step from C.", "Find C then move to D.", "D sits close to center often.", "Check line/space around C.", "Use step counting for D."],
		"E": ["E is easy near lower treble line.", "Find nearby D/F and step.", "E is often a chord tone.", "Check if it is line-based here.", "Anchor from C or G."],
		"F": ["F is tied to bass clef marker note.", "In treble, F is first space.", "Use clef clue for F quickly.", "Find E/G and step.", "F is a strong landmark note."],
		"G": ["G is tied to treble clef marker.", "Find treble clef curl line for G.", "G sits as a common anchor.", "Use F/A around it.", "G is often easy to spot."],
		"A": ["A is one step above G.", "Find G then move to A.", "A appears often in melodies.", "Check if line or space here.", "Use neighbor notes to confirm A."],
		"B": ["B sits near C anchor.", "Find C then step to B.", "B can be leading tone feel.", "Check accidental if key has sharps/flats.", "Use A/C around B."]
	}
	var lines: Array = note_bank.get(letter, ["Find nearby anchor.", "Count by steps.", "Check clef.", "Line or space first.", "Confirm letter."])
	var note_extra := [
		"Extra hint: target letter is %s." % letter,
		"Extra hint: read %s clef first." % clef_name,
		"Extra hint: confirm line vs space.",
		"Extra hint: move by one alphabet step at a time.",
		"Extra hint: use nearby landmark notes.",
		"Treble lines (bottom to top): E G B D F.",
		"Treble spaces (bottom to top): F A C E (FACE).",
		"Bass lines (bottom to top): G B D F A.",
		"Bass spaces (bottom to top): A C E G.",
		"Treble first line is E. Start there and count.",
		"Treble second line is G (the G-clef line).",
		"Treble first space is F.",
		"Bass first line is G.",
		"Bass first space is A.",
		"Bass fourth line is F (bass clef dots surround F).",
		"Space-note tip (treble): FACE.",
		"Line-note tip (treble): EGBDF.",
		"Line-note tip (bass): GBDFA.",
		"Space-note tip (bass): ACEG.",
		"Landmark tip: find middle C, then count steps.",
		"Landmark tip: treble G sits on the 2nd line.",
		"Landmark tip: bass F sits on the 4th line."
	]
	var hints: Array[String] = []
	if clear_hint:
		hints.append("Clear: note is %s on a %s." % [letter, lane_txt])
		hints.append("Clear: first check %s clef." % clef_name)
		hints.append("Theory: notes go A-B-C-D-E-F-G.")
		hints.append("Theory: line and space alternate by step.")
		hints.append("Tip: use landmarks like C/F/G.")
	for line in lines:
		hints.append(str(line))
	for line2 in note_extra:
		hints.append(str(line2))
	hints.append("In %s clef, look near %s." % [clef_name, str(profile.get("treble", "") if clef_name == "Treble" else profile.get("bass", ""))])
	if not clear_hint:
		if clef_name == "Treble" and lane_txt == "space":
			hints.append("Treble spaces spell FACE.")
		elif clef_name == "Treble":
			hints.append("Treble lines: E-G-B-D-F.")
		elif clef_name == "Bass" and lane_txt == "space":
			hints.append("Bass spaces: A-C-E-G.")
		else:
			hints.append("Bass lines: G-B-D-F-A.")
	while hints.size() < 20:
		hints.append("Count one staff step at a time.")
	return hints


func sight_chord_hint_lines(chord_name: String, clear_hint: bool, chord_family_id_from_name_callable: Callable) -> Array[String]:
	var clean_name := chord_name.strip_edges()
	var root_token := clean_name.split(" ", false)[0] if not clean_name.is_empty() else "C"
	var quality_part := clean_name
	var split_once := clean_name.split(" ", false, 1)
	if split_once.size() >= 2:
		quality_part = str(split_once[1])
	var family := str(chord_family_id_from_name_callable.call(quality_part)) if chord_family_id_from_name_callable.is_valid() else quality_part.to_lower()
	var bank := {
		"major": ["Start with root note.", "Major stacks look open and stable.", "Find bottom and top note first.", "Major often sounds bright.", "Then check middle note."],
		"minor": ["Start with root note.", "Minor looks similar but sounds darker.", "Bottom note then top note.", "Minor often sounds sadder.", "Check middle note distance."],
		"dim": ["Look for tight stacked look.", "Diminished feels tense.", "Root first, then compressed shape.", "Often used for tension.", "Double-check accidentals."],
		"dim7": ["Very tense stack.", "Symmetric feeling shape.", "Root then count small jumps.", "Used in dramatic moments.", "Check all note spellings."],
		"dom7": ["Dominant 7 often wants to resolve.", "Find major body + flat seventh.", "Listen for blues pull.", "Root first, top color second.", "Check the 7th note carefully."],
		"maj7": ["Major 7 sounds dreamy.", "Find major triad + soft top.", "Root first.", "Check if top feels close/tender.", "Then verify chord name."],
		"min7": ["Minor 7 sounds mellow.", "Find minor triad + extra top.", "Root first.", "Common in jazz/pop.", "Check the 7th note."],
		"sus2": ["No 3rd sound, open feel.", "Third replaced by second.", "Root + 2 + 5 shape.", "Suspended, less major/minor.", "Find open stack."],
		"sus4": ["No 3rd sound, unresolved feel.", "Third replaced by fourth.", "Root + 4 + 5 shape.", "Often wants to resolve.", "Check suspension feel."],
		"aug": ["Raised 5th gives lift.", "Bright but unstable.", "Check if top note is raised.", "Root first, then odd top color.", "Augmented sounds floating."],
		"power": ["Root + fifth only.", "No 3rd major/minor clue.", "Strong rock-style shape.", "Open, direct sound.", "Check if middle is missing."]
	}
	var lines: Array = bank.get(family, ["Root first.", "Read vertical stack.", "Check top note.", "Listen to mood.", "Choose closest family."])
	var chord_extra := [
		"Extra hint: root token is %s." % root_token,
		"Extra hint: this family reads as %s." % family,
		"Extra hint: read bottom note first.",
		"Extra hint: then check top color note.",
		"Extra hint: choose family first, full chord next."
	]
	var hints: Array[String] = []
	if clear_hint:
		hints.append("Clear: root is %s." % root_token)
		hints.append("Clear: chord family is %s." % family)
		hints.append("Theory: chord notes are stacked vertically.")
		hints.append("Theory: 3rd often sets major/minor quality.")
		hints.append("Tip: choose family first, full name next.")
	for line in lines:
		hints.append(str(line))
	for line2 in chord_extra:
		hints.append(str(line2))
	while hints.size() < 20:
		hints.append("Read bottom note first, then build upward.")
	return hints


func sight_note_reason_text(
	note_name: String,
	clef_name: String,
	current_sight_display_step: int,
	note_letter_from_name_callable: Callable
) -> String:
	var letter := str(note_letter_from_name_callable.call(note_name)) if note_letter_from_name_callable.is_valid() else note_name.substr(0, 1)
	var line_space := "line" if posmod(current_sight_display_step, 2) == 0 else "space"
	return "the note head position in %s clef matches %s on a %s." % [clef_name, letter, line_space]


func sight_chord_reason_text(chord_name: String, chord_family_id_from_name_callable: Callable) -> String:
	var clean_name := chord_name.strip_edges()
	var root_token := clean_name.split(" ", false)[0] if not clean_name.is_empty() else "C"
	var quality_part := clean_name
	var split_once := clean_name.split(" ", false, 1)
	if split_once.size() >= 2:
		quality_part = str(split_once[1])
	var family := str(chord_family_id_from_name_callable.call(quality_part)) if chord_family_id_from_name_callable.is_valid() else quality_part.to_lower()
	return "the stacked notes match root %s with %s chord color." % [root_token, family]


func sight_voicing_quality_for_id(chord_id: String) -> String:
	match chord_id:
		"Dim":
			return "Diminished"
		"Aug":
			return "Augmented"
		"6/9":
			return "6-9"
		_:
			return chord_id


func build_sight_chord_candidate(
	root_letter: String,
	root_acc: int,
	chord_id: String,
	sig_map: Dictionary,
	chord_definitions: Dictionary,
	note_name_order: Array
) -> Dictionary:
	var definition_any: Variant = chord_definitions.get(chord_id, null)
	if typeof(definition_any) != TYPE_DICTIONARY:
		return {}
	var definition: Dictionary = definition_any as Dictionary
	var intervals_any: Variant = definition.get("intervals", [])
	var degrees_any: Variant = definition.get("degrees", [])
	if typeof(intervals_any) != TYPE_ARRAY or typeof(degrees_any) != TYPE_ARRAY:
		return {}
	var intervals: Array = intervals_any as Array
	var degrees: Array = degrees_any as Array
	if intervals.size() != degrees.size() or intervals.is_empty():
		return {}
	var root_index := note_name_order.find(root_letter)
	if root_index < 0:
		return {}
	var root_pc := note_letter_pitch_class(root_letter, root_acc)
	var tone_letters: Array[String] = []
	var tone_accidentals: Array[int] = []
	var is_accidental := false
	for i in range(intervals.size()):
		var degree_offset := int(degrees[i])
		var tone_letter := str(note_name_order[posmod(root_index + degree_offset, note_name_order.size())])
		var target_pc := posmod(root_pc + int(intervals[i]), 12)
		var base_pc := note_letter_pitch_class(tone_letter, 0)
		var accidental := target_pc - base_pc
		if accidental > 6:
			accidental -= 12
		elif accidental < -6:
			accidental += 12
		if absi(accidental) > 1:
			return {}
		tone_letters.append(tone_letter)
		tone_accidentals.append(accidental)
		if accidental != int(sig_map.get(tone_letter, 0)):
			is_accidental = true
	var root_name := root_letter
	if root_acc > 0:
		root_name += char(0x266F)
	elif root_acc < 0:
		root_name += char(0x266D)
	var label := str(definition.get("label", chord_id))
	return {
		"id": chord_id,
		"tier": int(definition.get("tier", 1)),
		"quality": chord_id,
		"voicing_quality": sight_voicing_quality_for_id(chord_id),
		"name": "%s %s" % [root_name, label],
		"label": label,
		"root_letter": root_letter,
		"root_accidental": root_acc,
		"tone_letters": tone_letters,
		"tone_accidentals": tone_accidentals,
		"intervals": intervals.duplicate(),
		"is_accidental": is_accidental
	}


func sight_candidate_has_natural_tones(candidate: Dictionary) -> bool:
	var tones_any: Variant = candidate.get("tone_accidentals", [])
	if typeof(tones_any) != TYPE_ARRAY:
		return false
	for accidental in tones_any as Array:
		if int(accidental) != 0:
			return false
	return true


func sight_chord_candidates(
	selected_chord_tier: int,
	include_accidental_variants: bool,
	sight_chord_tier_ids: Dictionary,
	chord_definitions: Dictionary,
	note_name_order: Array,
	sig_map: Dictionary
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var tier_ids_any: Variant = sight_chord_tier_ids.get(selected_chord_tier, sight_chord_tier_ids.get(1, []))
	var tier_ids: Array[String] = []
	if typeof(tier_ids_any) == TYPE_ARRAY:
		for chord_id in tier_ids_any as Array:
			tier_ids.append(str(chord_id))
	var include_tier1_accidentals := selected_chord_tier == 1 and include_accidental_variants
	for root_letter_any in note_name_order:
		var root_letter := str(root_letter_any)
		var root_acc_options: Array[int] = []
		var base_root_acc := int(sig_map.get(root_letter, 0))
		root_acc_options.append(base_root_acc)
		if include_tier1_accidentals:
			if not root_acc_options.has(base_root_acc + 1):
				root_acc_options.append(base_root_acc + 1)
			if not root_acc_options.has(base_root_acc - 1):
				root_acc_options.append(base_root_acc - 1)
		for root_acc in root_acc_options:
			for chord_id in tier_ids:
				var candidate := build_sight_chord_candidate(root_letter, int(root_acc), chord_id, sig_map, chord_definitions, note_name_order)
				if candidate.is_empty():
					continue
				if selected_chord_tier == 1 and not include_tier1_accidentals and not sight_candidate_has_natural_tones(candidate):
					continue
				var candidate_key := "%s|%s" % [str(candidate.get("name", "")), str(candidate.get("id", ""))]
				if seen.has(candidate_key):
					continue
				seen[candidate_key] = true
				out.append(candidate)
	if out.is_empty():
		var fallback := build_sight_chord_candidate("C", 0, "Major", sig_map, chord_definitions, note_name_order)
		if fallback.is_empty():
			fallback = {
				"id": "Major",
				"tier": 1,
				"quality": "Major",
				"voicing_quality": "Major",
				"name": "C Major",
				"label": "Major",
				"root_letter": "C",
				"root_accidental": 0,
				"tone_letters": ["C", "E", "G"],
				"tone_accidentals": [0, 0, 0],
				"intervals": [0, 4, 7],
				"is_accidental": false
			}
		out.append(fallback)
	return out


func sight_required_pc_map(candidate: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var intervals_any: Variant = candidate.get("intervals", [])
	if typeof(intervals_any) != TYPE_ARRAY:
		return out
	for interval in intervals_any as Array:
		out[str(posmod(int(interval), 12))] = true
	return out


func sight_candidate_id_from_name(chord_name: String, candidates: Array) -> String:
	for candidate_any in candidates:
		if typeof(candidate_any) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_any as Dictionary
		if str(candidate.get("name", "")) == chord_name:
			return str(candidate.get("id", ""))
	return ""


func _rotate_tone_letters_for_inversion(base_letters: Array[String], inversion: int) -> Array[String]:
	var out: Array[String] = []
	if base_letters.is_empty():
		return out
	var count := base_letters.size()
	var shift := posmod(inversion, count)
	for i in range(count):
		out.append(base_letters[(i + shift) % count])
	return out


func _collect_descending_step_sequences(step_options: Array, idx: int, current: Array, out: Array, max_gap: int) -> void:
	if idx >= step_options.size():
		out.append(current.duplicate())
		return
	var options_any: Variant = step_options[idx]
	if typeof(options_any) != TYPE_ARRAY:
		return
	var options: Array = options_any as Array
	for step_any in options:
		var step := int(step_any)
		if idx > 0:
			var prev := int(current[idx - 1])
			var gap := prev - step
			if step >= prev:
				continue
			if gap < 1 or gap > max_gap:
				continue
		current.append(step)
		_collect_descending_step_sequences(step_options, idx + 1, current, out, max_gap)
		current.pop_back()


func pick_staff_centers_for_chord(host, tone_letters: Array, inversion: int = 0) -> Array[float]:
	var normalized_letters: Array[String] = []
	for tone in tone_letters:
		var label := str(tone).strip_edges().to_upper()
		if label.is_empty():
			continue
		normalized_letters.append(label.substr(0, 1))
	if normalized_letters.size() < 2:
		return []
	var ordered_letters := _rotate_tone_letters_for_inversion(normalized_letters, inversion)
	var bounds: Vector2i = host._effective_sight_step_bounds()
	var step_options: Array = []
	for letter in ordered_letters:
		var options_for_letter: Array[int] = []
		for step in range(bounds.x, bounds.y + 1):
			if host._staff_step_name_for_clef(step, host._selected_clef) != letter:
				continue
			var center_y := float(host._staff_center_y_for_step(step))
			if center_y < 8.0 or center_y > 304.0:
				continue
			options_for_letter.append(step)
		if options_for_letter.is_empty():
			return []
		options_for_letter.sort()
		options_for_letter.reverse()
		step_options.append(options_for_letter)
	var sequences: Array = []
	_collect_descending_step_sequences(step_options, 0, [], sequences, 3)
	if sequences.is_empty():
		_collect_descending_step_sequences(step_options, 0, [], sequences, 4)
	if sequences.is_empty():
		return []
	sequences.sort_custom(func(a: Array, b: Array) -> bool:
		var low_a := int(a[0])
		var high_a := int(a[a.size() - 1])
		var center_a := (float(low_a) + float(high_a)) * 0.5
		var spread_a := float(low_a - high_a)
		var score_a := absf(center_a - 9.5) + (spread_a * 0.04)
		var low_b := int(b[0])
		var high_b := int(b[b.size() - 1])
		var center_b := (float(low_b) + float(high_b)) * 0.5
		var spread_b := float(low_b - high_b)
		var score_b := absf(center_b - 9.5) + (spread_b * 0.04)
		return score_a < score_b
	)
	var top_bucket := mini(4, sequences.size()) - 1
	var picked: Array = sequences[host._rng.randi_range(0, top_bucket)]
	var centers: Array[float] = []
	for step_value in picked:
		centers.append(host._staff_center_y_for_step(int(step_value)))
	return centers


func pick_staff_centers_for_triad(host, root: String, inversion: int, note_name_order: Array) -> Array[float]:
	var root_index := note_name_order.find(root)
	if root_index < 0:
		root_index = 0
	var third_index := (root_index + 2) % note_name_order.size()
	var fifth_index := (root_index + 4) % note_name_order.size()
	var root_letter := str(note_name_order[root_index])
	var third_letter := str(note_name_order[third_index])
	var fifth_letter := str(note_name_order[fifth_index])
	return pick_staff_centers_for_chord(host, [root_letter, third_letter, fifth_letter], inversion)


func has_sight_chord_available_in_range(host, candidates: Array, note_name_order: Array) -> bool:
	for candidate_any in candidates:
		if typeof(candidate_any) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_any as Dictionary
		var tone_letters_any: Variant = candidate.get("tone_letters", [])
		if typeof(tone_letters_any) != TYPE_ARRAY:
			continue
		var tone_letters: Array = tone_letters_any as Array
		if tone_letters.size() < 2:
			continue
		for inversion in range(tone_letters.size()):
			var centers := pick_staff_centers_for_chord(host, tone_letters, inversion)
			if not centers.is_empty():
				return true
	return false


func closest_step_for_note_name_in_bounds(note_name: String, clef_name: String, bounds: Vector2i, current_sight_display_step: int) -> int:
	var start := clampi(current_sight_display_step, bounds.x, bounds.y)
	var best := start
	var best_dist := 999999
	for step in range(bounds.x, bounds.y + 1):
		if staff_step_name_for_clef(step, clef_name) != note_name:
			continue
		var distance := absi(step - start)
		if distance < best_dist:
			best_dist = distance
			best = step
	return best


func sight_note_snap_x(
	staff_area: Control,
	selected_mode: int,
	mode_sight: int,
	sight_mode: String,
	staff_left_x: float,
	staff_line_width: float,
	staff_note_snap_x: float
) -> float:
	if staff_area == null:
		return staff_note_snap_x
	if selected_mode == mode_sight:
		var geometry := visual_staff_geometry(staff_area, selected_mode, mode_sight, sight_mode, staff_left_x, staff_line_width)
		var left := float(geometry.get("left", staff_left_x))
		var width := float(geometry.get("width", staff_line_width))
		var anchor_ratio := 0.36
		if sight_mode == "Notes" or sight_mode == "Chords":
			anchor_ratio = 0.40
		if sight_mode == "Continuous":
			anchor_ratio = 0.30
		return left + (width * anchor_ratio)
	var usable_width := maxf(260.0, staff_area.size.x - staff_left_x)
	return staff_left_x + (usable_width * 0.26)


func show_sight_note_accidental_for_current_note(host, config: Dictionary) -> void:
	if host._staff_chord_accidental_labels.is_empty():
		return
	var label: Label = host._staff_chord_accidental_labels[0] as Label
	if label == null:
		return
	var mode_sight := int(config.get("mode_sight", 0))
	if host._selected_mode != mode_sight or host._sight_mode != "Notes":
		label.visible = false
		return
	var symbol := String(host._current_sight_note_explicit_accidental).strip_edges()
	if symbol == "":
		label.visible = false
		return
	label.text = symbol
	label.visible = true
	var center_y: float = host._staff_note.position.y + (host._staff_note.size.y * host._staff_note.scale.y * 0.5)
	var note_left: float = host._staff_note.position.x
	var y_adjust := (-4.0 if symbol == char(0x266E) else -1.0) - float(config.get("sight_accidental_raise_y", 0.0))
	var x_offset := float(config.get("sight_accidental_x_offset", 18.0))
	label.position = Vector2(note_left - x_offset, center_y - (label.size.y * 0.5) + y_adjust)


func position_sight_note(host, note_name: String, center_y_override: float = NAN, config: Dictionary = {}) -> void:
	if host._staff_note == null:
		return
	var mode_sight := int(config.get("mode_sight", 0))
	var sight_note_center_offset_y := float(config.get("sight_note_center_offset_y", 0.0))
	var staff_left_x := float(config.get("staff_left_x", 0.0))
	var staff_line_width := float(config.get("staff_line_width", 0.0))
	var staff_note_snap_x_value := float(config.get("staff_note_snap_x", 0.0))
	if host._selected_mode == mode_sight:
		host._pick_random_sight_visual_colors()
		host._apply_sight_note_palette()
	for note_panel in host._staff_chord_notes:
		note_panel.visible = false
	for accidental_label in host._staff_chord_accidental_labels:
		if accidental_label != null:
			accidental_label.visible = false
	if host._selected_mode != mode_sight or host._sight_mode != "Notes":
		host._current_sight_note_explicit_accidental = ""
	var center_y := center_y_override
	if host._selected_mode == mode_sight:
		var bounds: Vector2i = host._effective_sight_step_bounds()
		if is_nan(center_y):
			host._current_sight_display_step = closest_step_for_note_name_in_bounds(note_name, host._selected_clef, bounds, host._current_sight_display_step)
		else:
			host._current_sight_display_step = host._nearest_staff_step_from_center_y(center_y)
		host._current_sight_display_step = clampi(host._current_sight_display_step, bounds.x, bounds.y)
		center_y = host._staff_center_y_for_step(host._current_sight_display_step)
		var base_note: String = host._staff_step_name_for_clef(host._current_sight_display_step, host._selected_clef)
		if host._sight_mode == "Notes":
			var force_natural: bool = host._current_sight_note_explicit_accidental == char(0x266E)
			host._current_sight_note = host._sight_note_name_with_key_signature(base_note, force_natural)
		else:
			host._current_sight_note = base_note
	if host._selected_clef == "Bass":
		if host._staff_clef_label != null:
			host._staff_clef_label.text = char(0x1D122)
		if is_nan(center_y):
			var bass_center_map := {"C": 160.0, "D": 144.0, "E": 128.0, "F": 112.0, "G": 96.0, "A": 80.0, "B": 64.0}
			center_y = float(bass_center_map.get(note_name, 160.0))
	else:
		if host._staff_clef_label != null:
			host._staff_clef_label.text = char(0x1D11E)
		if is_nan(center_y):
			var treble_center_map := {"C": 112.0, "D": 96.0, "E": 80.0, "F": 64.0, "G": 48.0, "A": 32.0, "B": 16.0}
			center_y = float(treble_center_map.get(note_name, 112.0))
		if host._selected_mode != mode_sight:
			center_y += 2.0
	if host._selected_mode == mode_sight:
		var effective_bounds: Vector2i = host._effective_sight_step_bounds()
		host._current_sight_display_step = clampi(host._current_sight_display_step, effective_bounds.x, effective_bounds.y)
		center_y = host._staff_center_y_for_step(host._current_sight_display_step) + sight_note_center_offset_y
		var base_note_2: String = host._staff_step_name_for_clef(host._current_sight_display_step, host._selected_clef)
		if host._sight_mode == "Notes":
			var force_natural_2: bool = host._current_sight_note_explicit_accidental == char(0x266E)
			host._current_sight_note = host._sight_note_name_with_key_signature(base_note_2, force_natural_2)
		else:
			host._current_sight_note = base_note_2
	var top_left_y: float = center_y - (host._staff_note.size.y * 0.5)
	host._staff_note.scale = host._note_scale_for_y(center_y)
	host._staff_note.position = Vector2(
		sight_note_snap_x(host._staff_area, host._selected_mode, mode_sight, host._sight_mode, staff_left_x, staff_line_width, staff_note_snap_x_value),
		top_left_y
	)
	var center_x: float = host._staff_note.position.x + (host._staff_note.size.x * 0.5)
	host._update_staff_ledger_lines(center_y, center_x)
	show_sight_note_accidental_for_current_note(host, config)
	host._start_sight_note_bounce()


func position_sight_chord(host, note_centers: Array, chord_def: Dictionary = {}, config: Dictionary = {}) -> void:
	if host._staff_note == null:
		return
	host._hide_sight_chord_note_chip()
	var mode_sight := int(config.get("mode_sight", 0))
	var sight_chord_note_center_offset_y := float(config.get("sight_chord_note_center_offset_y", 0.0))
	var sight_accidental_raise_y := float(config.get("sight_accidental_raise_y", 0.0))
	var sight_accidental_x_offset := float(config.get("sight_accidental_x_offset", 18.0))
	if host._selected_mode == mode_sight:
		host._pick_random_sight_visual_colors()
		host._apply_sight_note_palette()
	if host._staff_clef_label != null:
		host._staff_clef_label.text = char(0x1D122) if host._selected_clef == "Bass" else char(0x1D11E)
	if note_centers.size() < 2:
		return
	var display_note_centers: Array[float] = []
	var note_steps: Array[int] = []
	var note_x_offsets: Array[float] = []
	for center_any in note_centers:
		var center_y_raw := float(center_any)
		note_steps.append(host._nearest_staff_step_from_center_y(center_y_raw))
		display_note_centers.append(center_y_raw + sight_chord_note_center_offset_y)
		note_x_offsets.append(0.0)
	var sample_center_y: float = host._active_staff_top_y() + (host._active_staff_line_gap_y() * 2.0)
	var note_scale: Vector2 = host._note_scale_for_y(sample_center_y)
	var note_w: float = host._staff_note.size.x * note_scale.x
	var second_interval_shift_ratio: float = float(config.get("sight_chord_second_interval_shift_ratio", 0.62))
	var ci := 0
	while ci < note_steps.size():
		var run: Array[int] = [ci]
		var ri := ci + 1
		while ri < note_steps.size():
			if absi(note_steps[ri] - note_steps[ri - 1]) != 1:
				break
			run.append(ri)
			ri += 1
		if run.size() >= 2:
			run.sort_custom(func(a: int, b: int) -> bool: return note_steps[a] > note_steps[b])
			for pos in range(run.size()):
				if pos % 2 == 1:
					note_x_offsets[run[pos]] = note_w * second_interval_shift_ratio
			ci = ri
		else:
			ci += 1
	var x := sight_note_snap_x(
		host._staff_area,
		host._selected_mode,
		mode_sight,
		host._sight_mode,
		float(config.get("staff_left_x", 0.0)),
		float(config.get("staff_line_width", 0.0)),
		float(config.get("staff_note_snap_x", 0.0))
	)
	var first_top: float = float(display_note_centers[0]) - (host._staff_note.size.y * 0.5)
	host._staff_note.visible = true
	host._staff_note.scale = host._note_scale_for_y(float(display_note_centers[0]))
	host._staff_note.position = Vector2(x + note_x_offsets[0], first_top)
	var ledger_note_centers: Array[float] = [float(display_note_centers[0])]
	var ledger_note_center_xs: Array[float] = [host._staff_note.position.x + (host._staff_note.size.x * host._staff_note.scale.x * 0.5)]
	var extra_note_count := mini(host._staff_chord_notes.size(), maxi(0, display_note_centers.size() - 1))
	for i in range(extra_note_count):
		var note_panel = host._staff_chord_notes[i]
		var center_y := float(display_note_centers[i + 1])
		note_panel.visible = true
		note_panel.scale = host._note_scale_for_y(center_y)
		note_panel.position = Vector2(x + note_x_offsets[i + 1], center_y - (note_panel.size.y * 0.5))
		ledger_note_centers.append(center_y)
		ledger_note_center_xs.append(note_panel.position.x + (note_panel.size.x * note_panel.scale.x * 0.5))
	for i in range(extra_note_count, host._staff_chord_notes.size()):
		var hidden_note = host._staff_chord_notes[i]
		hidden_note.visible = false
	host._update_staff_ledger_lines_for_note_positions(ledger_note_centers, ledger_note_center_xs)
	var tone_accidentals: Array = chord_def.get("display_accidentals", chord_def.get("tone_accidentals", [0, 0, 0]))
	var tone_letters: Array = chord_def.get("display_letters", chord_def.get("tone_letters", ["C", "E", "G"]))
	var sig_map: Dictionary = host._key_signature_accidental_map()
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	var all_note_panels: Array = [host._staff_note]
	for panel in host._staff_chord_notes:
		all_note_panels.append(panel)
	for i in range(all_note_panels.size()):
		var panel = all_note_panels[i]
		if panel == null:
			continue
		panel.set_meta("sight_note_name", "")
		panel.set_meta("sight_note_midi", -1)
		if i < tone_letters.size():
			var letter_name := str(tone_letters[i])
			var accidental_name := int(tone_accidentals[i]) if i < tone_accidentals.size() else 0
			panel.set_meta("sight_note_name", host._sight_note_name_with_accidental(letter_name, accidental_name))
			if i < note_steps.size():
				var step_i := int(note_steps[i])
				panel.set_meta("sight_note_midi", host._sight_step_to_midi(step_i, host._selected_clef, accidental_name))
	for i in range(host._staff_chord_accidental_labels.size()):
		var accidental_label = host._staff_chord_accidental_labels[i]
		if accidental_label == null:
			continue
		if i >= display_note_centers.size() or i >= all_note_panels.size():
			accidental_label.visible = false
			continue
		var accidental_value := int(tone_accidentals[i]) if i < tone_accidentals.size() else 0
		var letter := str(tone_letters[i]) if i < tone_letters.size() else "C"
		var key_acc := int(sig_map.get(letter, 0))
		var needed_acc := accidental_value - key_acc
		if needed_acc == 0:
			accidental_label.visible = false
			continue
		var panel = all_note_panels[i]
		accidental_label.text = sharp_sym if needed_acc > 0 else flat_sym
		accidental_label.visible = true
		var center_y: float = panel.position.y + (panel.size.y * panel.scale.y * 0.5)
		var note_left: float = panel.position.x
		var y_adjust := (-8.0 if needed_acc < 0 else -1.0) - sight_accidental_raise_y
		accidental_label.position = Vector2(note_left - sight_accidental_x_offset, center_y - (accidental_label.size.y * 0.5) + y_adjust)
	host._stop_sight_note_bounce()
	host._start_sight_note_bounce()


func grand_staff_bass_top_y(treble_top_y: float, gap_y: float) -> float:
	var treble_bottom: float = treble_top_y + gap_y * 4.0
	var inter_staff_gap: float = gap_y * 4.0
	return treble_bottom + inter_staff_gap


func grand_staff_bass_display_step(step: int, config: Dictionary = {}) -> int:
	var staff_bottom_line_step: int = int(config.get("staff_bottom_line_step", 8))
	var ledger_step_extra_down: int = int(config.get("grand_staff_bass_ledger_step_extra_down", 0))
	if step == staff_bottom_line_step + 1:
		return staff_bottom_line_step
	if step >= staff_bottom_line_step + 2:
		return step + ledger_step_extra_down
	return step


func grand_staff_bass_center_y_for_step(host, step: int) -> float:
	var gap: float = host._active_staff_line_gap_y()
	var treble_top: float = host._active_staff_top_y()
	var bass_top: float = grand_staff_bass_top_y(treble_top, gap)
	var step_y: float = gap * 0.5
	return bass_top + float(step) * step_y


func layout_grand_staff_bass_key_signature(host, bass_top_y: float, gap_y: float, line_x: float, config: Dictionary = {}) -> void:
	var show_sig: bool = host._selected_mode == int(config.get("mode_sight", 0)) and host._sight_mode == "Chords"
	var defs: Array = key_sig_letter_steps(host._sight_key_signature)
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	var step_y: float = gap_y * 0.5
	var sight_accidental_raise_y: float = float(config.get("sight_accidental_raise_y", 0.0))
	for i in range(host._grand_staff_bass_key_sig_labels.size()):
		var lbl: Label = host._grand_staff_bass_key_sig_labels[i] as Label
		if lbl == null:
			continue
		if not show_sig or i >= defs.size():
			lbl.visible = false
			continue
		var definition: Array = defs[i]
		var letter: String = str(definition[0])
		var symbol: String = str(definition[1])
		var step: int = key_signature_step_for_letter(letter, "Bass")
		var y: float = bass_top_y + float(step) * step_y
		if symbol == sharp_sym:
			y -= 8.0
		elif symbol == flat_sym:
			y -= 18.0
		if host._grand_staff_active:
			y -= clampf(gap_y * 0.20, 2.0, 5.0)
		y -= sight_accidental_raise_y
		lbl.text = symbol
		lbl.visible = true
		var base_x: float = line_x + 68.0
		if host._grand_staff_active:
			base_x += clampf(gap_y * 0.42, 6.0, 12.0)
		var spacing: float = 26.0
		if symbol == flat_sym:
			base_x += 8.0
		lbl.position = Vector2(base_x + float(i) * spacing, y - 35.0)


func layout_grand_staff_bass(host, line_x: float, segment: float, treble_top_y: float, gap_y: float, config: Dictionary = {}) -> void:
	var show_grand: bool = host._selected_mode == int(config.get("mode_sight", 0)) and host._sight_mode == "Chords" and host._grand_staff_active
	var bass_top: float = grand_staff_bass_top_y(treble_top_y, gap_y)
	for i in range(host._grand_staff_bass_lines.size()):
		var bass_line: ColorRect = host._grand_staff_bass_lines[i] as ColorRect
		if bass_line == null:
			continue
		bass_line.visible = show_grand
		bass_line.position = Vector2(line_x, bass_top + float(i) * gap_y)
		bass_line.size.x = segment
	if host._grand_staff_bass_clef_label != null:
		host._grand_staff_bass_clef_label.visible = show_grand
		if show_grand:
			host._grand_staff_bass_clef_label.text = char(0x1D122)
			var bass_span: float = gap_y * 4.0
			var bass_clef_size_factor: float = 1.02
			var font_sz: int = int(round(clampf(bass_span * bass_clef_size_factor, 50.0, 110.0)))
			host._grand_staff_bass_clef_label.add_theme_font_size_override("font_size", font_sz)
			host._grand_staff_bass_clef_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
			host._grand_staff_bass_clef_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.75))
			host._grand_staff_bass_clef_label.add_theme_constant_override("outline_size", 2)
			var clef_x: float = line_x - clampf(gap_y * 0.88, 12.0, 20.0) + float(config.get("grand_staff_clef_right_nudge", 0.0))
			var clef_y: float = bass_top - (gap_y * 0.94) - clampf(gap_y * 0.24, 5.0, 12.0) + (gap_y * float(config.get("grand_staff_clef_down_spaces", 0.0))) - (gap_y * float(config.get("grand_staff_bass_clef_extra_raise_spaces", 0.0)))
			host._grand_staff_bass_clef_label.position = Vector2(clef_x, clef_y)
	if host._grand_staff_brace_label != null:
		host._grand_staff_brace_label.visible = false
	var bass_bottom: float = bass_top + gap_y * 4.0
	if host._grand_staff_left_connector != null:
		host._grand_staff_left_connector.visible = show_grand
		if show_grand:
			host._grand_staff_left_connector.position = Vector2(line_x - 1.0, treble_top_y)
			host._grand_staff_left_connector.size = Vector2(3.0, (bass_bottom - treble_top_y) + 2.0)
	if host._grand_staff_right_connector != null:
		host._grand_staff_right_connector.visible = show_grand
		if show_grand:
			host._grand_staff_right_connector.position = Vector2((line_x + segment) - 2.0, treble_top_y)
			host._grand_staff_right_connector.size = Vector2(3.0, (bass_bottom - treble_top_y) + 2.0)
	if show_grand:
		layout_grand_staff_bass_key_signature(host, bass_top, gap_y, line_x, config)
	else:
		for ks in host._grand_staff_bass_key_sig_labels:
			if ks != null:
				ks.visible = false


func update_grand_staff_ledger_lines(host, all_notes: Array, note_panels: Array, config: Dictionary = {}) -> void:
	host._clear_staff_ledger_lines()
	var gap: float = host._active_staff_line_gap_y()
	var treble_top: float = host._active_staff_top_y()
	var bass_top: float = grand_staff_bass_top_y(treble_top, gap)
	var step_y: float = gap * 0.5
	var staff_bottom_line_step: int = int(config.get("staff_bottom_line_step", 8))
	var staff_top_line_step: int = int(config.get("staff_top_line_step", 0))
	var seen: Dictionary = {}
	for ni in range(all_notes.size()):
		if ni >= note_panels.size():
			continue
		var p: Panel = note_panels[ni] as Panel
		if p == null or not p.visible:
			continue
		if typeof(all_notes[ni]) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = all_notes[ni] as Dictionary
		var staff: String = str(note.get("staff", "treble"))
		var step: int = int(note.get("step", 4))
		if staff == "bass":
			step = grand_staff_bass_display_step(step, config)
		var staff_top_y: float = treble_top if staff == "treble" else bass_top
		var sw: float = p.size.x * p.scale.x
		var sh: float = p.size.y * p.scale.y
		var theta: float = deg_to_rad(p.rotation_degrees)
		var center_x: float = p.position.x + cos(theta) * (sw * 0.5) - sin(theta) * (sh * 0.5)
		if step >= staff_bottom_line_step + 2:
			var top_ledger: int = step if step % 2 == 0 else step - 1
			for s in range(staff_bottom_line_step + 2, top_ledger + 1, 2):
				var y: float = staff_top_y + float(s) * step_y
				var k := "%d:%d" % [int(round(y * 10.0)), int(round(center_x * 10.0))]
				if seen.has(k):
					continue
				seen[k] = true
				host._add_staff_ledger_line(y, center_x)
		elif step <= staff_top_line_step - 2:
			var bottom_ledger: int = step if step % 2 == 0 else step + 1
			var s2 := staff_top_line_step - 2
			while s2 >= bottom_ledger:
				var y2: float = staff_top_y + float(s2) * step_y
				var k2 := "%d:%d" % [int(round(y2 * 10.0)), int(round(center_x * 10.0))]
				if not seen.has(k2):
					seen[k2] = true
					host._add_staff_ledger_line(y2, center_x)
				s2 -= 2


func position_sight_chord_grand_staff(host, voicing: Dictionary, chord_def: Dictionary, config: Dictionary = {}) -> void:
	if host._staff_note == null:
		return
	host._hide_sight_chord_note_chip()
	var mode_sight: int = int(config.get("mode_sight", 0))
	if host._selected_mode == mode_sight:
		host._pick_random_sight_visual_colors()
		host._apply_sight_note_palette()
	if host._staff_clef_label != null:
		host._staff_clef_label.text = char(0x1D11E)
	var all_notes: Array = voicing.get("all_notes", [])
	if all_notes.is_empty():
		return
	var x: float = sight_note_snap_x(
		host._staff_area,
		host._selected_mode,
		mode_sight,
		host._sight_mode,
		float(config.get("staff_left_x", 0.0)),
		float(config.get("staff_line_width", 0.0)),
		float(config.get("staff_note_snap_x", 0.0))
	)
	var note_panels: Array[Panel] = [host._staff_note]
	note_panels.append_array(host._staff_chord_notes)
	for p in note_panels:
		if p != null:
			p.visible = false
			p.set_meta("sight_note_name", "")
			p.set_meta("sight_note_midi", -1)
	for lbl in host._staff_chord_accidental_labels:
		if lbl != null:
			lbl.visible = false
	host._clear_staff_ledger_lines()
	var gap: float = host._active_staff_line_gap_y()
	var treble_top: float = host._active_staff_top_y()
	var bass_top: float = grand_staff_bass_top_y(treble_top, gap)
	var half_gap: float = gap * 0.5
	var display_note_centers: Array[float] = []
	var note_staffs: Array[String] = []
	var note_steps: Array[int] = []
	var note_x_offsets: Array[float] = []
	for ni in range(all_notes.size()):
		if typeof(all_notes[ni]) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = all_notes[ni] as Dictionary
		var staff: String = str(note.get("staff", "treble"))
		var step: int = int(note.get("step", 4))
		var display_step: int = step
		if staff == "bass":
			display_step = grand_staff_bass_display_step(step, config)
		var staff_top_y: float = treble_top if staff == "treble" else bass_top
		var center_y: float = staff_top_y + float(display_step) * half_gap
		display_note_centers.append(center_y)
		note_staffs.append(staff)
		note_steps.append(display_step)
		note_x_offsets.append(0.0)
	var sample_center_y: float = host._active_staff_top_y() + (host._active_staff_line_gap_y() * 2.0)
	var grand_note_scale: Vector2 = host._note_scale_for_y(sample_center_y)
	var note_base_w: float = 40.0
	if host._staff_note != null:
		note_base_w = host._staff_note.size.x
	var note_w: float = note_base_w * grand_note_scale.x
	var second_interval_shift_ratio: float = float(config.get("grand_staff_second_interval_shift_ratio", 0.58))
	var ci := 0
	while ci < all_notes.size():
		var run: Array[int] = [ci]
		var ri := ci + 1
		while ri < all_notes.size():
			if ri >= note_staffs.size() or ri - 1 >= note_staffs.size():
				break
			if note_staffs[ri] != note_staffs[ri - 1]:
				break
			if absi(note_steps[ri] - note_steps[ri - 1]) != 1:
				break
			run.append(ri)
			ri += 1
		if run.size() >= 2:
			run.sort_custom(func(a: int, b: int) -> bool: return note_steps[a] > note_steps[b])
			for pos in range(run.size()):
				if pos % 2 == 1:
					note_x_offsets[run[pos]] = note_w * second_interval_shift_ratio
			ci = ri
		else:
			ci += 1
	for ni in range(all_notes.size()):
		if ni >= note_panels.size() or ni >= display_note_centers.size():
			continue
		var panel: Panel = note_panels[ni] as Panel
		if panel == null or typeof(all_notes[ni]) != TYPE_DICTIONARY:
			continue
		var target_y: float = float(display_note_centers[ni])
		var display_note: Dictionary = all_notes[ni] as Dictionary
		var note_name: String = host._sight_note_name_with_accidental(
			str(display_note.get("letter", "C")),
			int(display_note.get("accidental", 0)),
			int(display_note.get("octave", 4))
		)
		panel.set_meta("sight_note_name", note_name)
		panel.set_meta("sight_note_midi", int(display_note.get("midi", -1)))
		panel.visible = true
		panel.scale = host._note_scale_for_y(target_y)
		var sw: float = panel.size.x * panel.scale.x
		var sh: float = panel.size.y * panel.scale.y
		var theta: float = deg_to_rad(panel.rotation_degrees)
		var rotated_half_y: float = sin(theta) * (sw * 0.5) + cos(theta) * (sh * 0.5)
		panel.position = Vector2(x + note_x_offsets[ni], target_y - rotated_half_y)
	update_grand_staff_ledger_lines(host, all_notes, note_panels, config)
	var sig_map: Dictionary = host._key_signature_accidental_map()
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	var natural_sym := char(0x266E)
	var acc_visible: Array[bool] = []
	acc_visible.resize(all_notes.size())
	acc_visible.fill(false)
	var grand_staff_accidental_x_offset: float = float(config.get("grand_staff_accidental_x_offset", 18.0))
	var sight_accidental_raise_y: float = float(config.get("sight_accidental_raise_y", 0.0))
	for i in range(host._staff_chord_accidental_labels.size()):
		var acc_lbl: Label = host._staff_chord_accidental_labels[i] as Label
		if acc_lbl == null:
			continue
		if i >= all_notes.size() or i >= note_panels.size() or typeof(all_notes[i]) != TYPE_DICTIONARY:
			acc_lbl.visible = false
			continue
		var note: Dictionary = all_notes[i] as Dictionary
		var acc_val: int = int(note.get("accidental", 0))
		var letter: String = str(note.get("letter", "C"))
		var key_acc: int = int(sig_map.get(letter, 0))
		if acc_val == key_acc:
			acc_lbl.visible = false
			continue
		var panel: Panel = note_panels[i] as Panel
		if panel == null:
			acc_lbl.visible = false
			continue
		if acc_val == 0:
			acc_lbl.text = natural_sym
		elif acc_val > 0:
			acc_lbl.text = sharp_sym
		else:
			acc_lbl.text = flat_sym
		acc_lbl.visible = true
		acc_visible[i] = true
		var target_y: float = float(display_note_centers[i])
		var note_left: float = panel.position.x
		var acc_offset_x: float = maxf(grand_staff_accidental_x_offset, panel.size.x * panel.scale.x * 0.40)
		var y_adjust: float = (-8.0 if acc_val < 0 else -1.0) - sight_accidental_raise_y
		acc_lbl.position = Vector2(note_left - acc_offset_x, target_y - (acc_lbl.size.y * 0.5) + y_adjust)
	var acc_stagger_extra: float = maxf(12.0, note_w * 0.45)
	for si in range(1, all_notes.size()):
		if si >= acc_visible.size() or si >= note_staffs.size() or si >= note_steps.size():
			continue
		if not acc_visible[si] or not acc_visible[si - 1]:
			continue
		if note_staffs[si] != note_staffs[si - 1]:
			continue
		if absi(note_steps[si] - note_steps[si - 1]) != 1:
			continue
		var lower_idx: int = si if note_steps[si] > note_steps[si - 1] else si - 1
		if lower_idx < host._staff_chord_accidental_labels.size():
			var lower_lbl: Label = host._staff_chord_accidental_labels[lower_idx] as Label
			if lower_lbl != null and lower_lbl.visible:
				lower_lbl.position.x -= acc_stagger_extra
	host._stop_sight_note_bounce()
	host._start_sight_note_bounce()
