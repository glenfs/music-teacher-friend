extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in extra:
		result[key] = extra[key]
	return result


static func _rhythm_note(kind: String, beats: float = -1.0) -> Dictionary:
	if beats <= 0.0:
		match kind:
			"whole":
				beats = 4.0
			"half":
				beats = 2.0
			"dotted_half":
				beats = 3.0
			"quarter":
				beats = 1.0
			"dotted_quarter":
				beats = 1.5
			"eighth":
				beats = 0.5
			"sixteenth":
				beats = 0.25
			_:
				beats = 1.0
	return {"kind": kind, "beats": beats}


static func _staff_visual(bars: Array, top: int = 4, bottom: int = 4, prompt: String = "", caption: String = "", show_counts: bool = true, bpm: int = 84, beam_groups: Array = []) -> Dictionary:
	var visual := {
		"top": top,
		"bottom": bottom,
		"bars": bars,
		"prompt": prompt,
		"caption": caption,
		"show_counts": show_counts,
		"show_time_signature": true,
		"bpm": bpm,
	}
	if not beam_groups.is_empty():
		visual["beam_groups"] = beam_groups
	return visual


static func _choice_staff_visual(bar: Array, beam_groups: Array = []) -> Dictionary:
	var visual := _staff_visual([bar], 4, 4, "", "", false, 84, beam_groups)
	visual["clef"] = "none"
	visual["show_time_signature"] = false
	visual["width"] = 210.0
	visual["staff_height"] = 112.0
	return visual


static func _quiz_with_reference(question: String, choices: Array, correct_index: int, chicken_correct: String, chicken_wrong: String, reference_visual: Dictionary = {}, choice_visuals: Array = []) -> Dictionary:
	var step := LMD.create_quiz_step(question, choices, correct_index, chicken_correct, chicken_wrong)
	if not reference_visual.is_empty():
		step["reference_visual_type"] = "rhythm_staff_example"
		step["reference_visual_data"] = reference_visual
	if not choice_visuals.is_empty():
		step["choice_visual_type"] = "rhythm_staff_example"
		step["choice_visuals"] = choice_visuals
	return step


static func _practice_question(concept_id: String, question: String, choices: Array, correct_index: int, reference_visual: Dictionary = {}, choice_visuals: Array = []) -> Dictionary:
	var item := {
		"question": question,
		"choices": choices,
		"correct_index": correct_index,
		"concept_id": concept_id,
		"test_out_family": "rhythm",
	}
	if not reference_visual.is_empty():
		item["reference_visual_type"] = "rhythm_staff_example"
		item["reference_visual_data"] = reference_visual
	if not choice_visuals.is_empty():
		item["choice_visual_type"] = "rhythm_staff_example"
		item["choice_visuals"] = choice_visuals
	return item


static func get_module_data() -> Dictionary:
	# ── Note value staff visuals ────────────────────────────────────
	var eighth_bar := _staff_visual(
		[[_rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("eighth")]],
		4, 4,
		"Count: 1-and 2-and 3-and 4-and  — two taps per beat.",
		"Two eighth notes fit inside one beat. They are usually beamed in pairs.",
		true, 84,
		[[[0, 1], [2, 3], [4, 5], [6, 7]]]
	)
	var quarter_bar := _staff_visual(
		[[_rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter")]],
		4, 4,
		"Clap along: 1  2  3  4  — one clap per beat.",
		"Quarter notes are the steady pulse. Each one gets 1 beat."
	)
	var quarter_equals_eighths_visual := {
		"left_item": {"kind": "quarter", "beats": 1.0},
		"right_items": [
			{"kind": "eighth", "beats": 0.5},
			{"kind": "eighth", "beats": 0.5},
		],
		"beam_group": [0, 1],
		"left_label": "1 beat",
		"right_label": "1/2 + 1/2 beats",
		"caption": "One quarter note equals two eighth notes.",
		"detail": "One clap becomes two quick taps. Listen to hear the difference.",
	}
	var mixed_quarter_eighths := _merge(_staff_visual(
		[[_rhythm_note("quarter"), _rhythm_note("eighth"), _rhythm_note("eighth"), _rhythm_note("quarter"), _rhythm_note("quarter")]],
		4, 4,
		"Feel the quarter notes march, then the eighths double up on beat 2.",
		"Quarter + two eighths + quarter + quarter = 4 beats.",
		true, 80,
		[[[1, 2]]]
	), {"playable": true})
	var mixed_bars_clap := _merge(_staff_visual(
		[
			[_rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter")],
			[_rhythm_note("half"), _rhythm_note("quarter"), _rhythm_note("quarter")],
		],
		4, 4,
		"Clap each bar yourself first. Then press Hear the Demo to check.",
		"Different note lengths, same 4-beat total."
	), {"playable": true})
	var dotted_half_visual := _staff_visual(
		[[_rhythm_note("dotted_half"), _rhythm_note("quarter")]],
		4, 4,
		"Count: 1-2-3 then tap on 4. The dotted half lasts 3 beats, quarter gets 1.",
		"The dot adds half the note's value. Half note (2) + dot (1) = 3 beats."
	)
	var dotted_half_quarter_mix := _merge(_staff_visual(
		[[_rhythm_note("dotted_half"), _rhythm_note("quarter")]],
		4, 4,
		"Hold through 3 beats, then quarter on beat 4.",
		"Dotted half (3 beats) + quarter (1 beat) = 4 beats total."
	), {"playable": true})
	var mixed_bar_choice_visuals := [
		_choice_staff_visual([
			_rhythm_note("half"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
		]),
		_choice_staff_visual([
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
		]),
		_choice_staff_visual([
			_rhythm_note("half"),
			_rhythm_note("eighth"),
		]),
		_choice_staff_visual(
			[
				_rhythm_note("eighth"),
				_rhythm_note("eighth"),
				_rhythm_note("eighth"),
				_rhythm_note("eighth"),
				_rhythm_note("eighth"),
			],
			[[[0, 1], [2, 3]]]
		),
	]

	# ── Build steps ─────────────────────────────────────────────────
	var steps: Array = []

	# ═══════════════════════════════════════════════════════════════
	# Step 1: Intro
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_intro_step(
		"Eighth Notes & Dots",
		"Now we split beats in half and add dots. You'll count 1-and 2-and and feel how rhythms get more interesting.",
		"Let's double up the speed!"
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 2: The Eighth Note
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Eighth Note",
		"Eighth notes split each beat in half. Count 1-and 2-and 3-and 4-and.",
		"rhythm_value",
		{
			"value": "eighth",
			"beats": 0.5,
			"bars": eighth_bar["bars"],
			"beam_groups": eighth_bar["beam_groups"],
			"prompt": eighth_bar["prompt"],
			"caption": eighth_bar["caption"],
			"bpm": eighth_bar["bpm"],
		}
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 3: Quarter = Two Eighths
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"Quarter = Two Eighths",
		"One beat splits into two halves.",
		"rhythm_equivalence",
		quarter_equals_eighths_visual
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 4: Tap Along — Eighth Notes
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along — Eighth Notes",
		"Tap twice per beat — 8 quick taps!",
		[0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
		66,
		4
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 5: Quiz — Eighth note beats
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"How many beats does an eighth note get?",
		["1 beat", "Half a beat", "2 beats", "A quarter of a beat"],
		1,
		"Right. An eighth note lasts half a beat.",
		"Two eighth notes fit inside one beat.",
		eighth_bar
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 6: Quiz — Eighth note counting
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"How do we count eighth notes?",
		["1, 2, 3, 4", "1-and, 2-and, 3-and, 4-and", "1-2, 3-4", "1, 2"],
		1,
		"Right! Two taps per beat: 1-and, 2-and, 3-and, 4-and.",
		"Eighth notes split each beat in half. How would you count two taps per beat?",
		eighth_bar
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 7: Mixing Quarters and Eighths
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"Mixing Quarters and Eighths",
		"Real music mixes values. Feel the flow between steady beats and quick splits.",
		"rhythm_staff_example",
		mixed_quarter_eighths
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 8: Tap Along — Quarters + Eighths
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along — Quarters + Eighths",
		"Some taps are steady, some are quick doubles.",
		[1.0, 0.5, 0.5, 1.0, 1.0],
		66,
		4
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 9: Two Bars, Same Total
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"Two Bars, Same Total",
		"Different note lengths, same 4-beat total.",
		"rhythm_staff_example",
		mixed_bars_clap
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 10: The Dotted Half Note
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Dotted Half Note",
		"A dot adds half the note's value. Half (2) + dot (1) = 3 beats.",
		"rhythm_value",
		{
			"value": "dotted_half",
			"beats": 3.0,
			"bars": dotted_half_visual["bars"],
			"prompt": dotted_half_visual["prompt"],
			"caption": dotted_half_visual["caption"],
			"bpm": dotted_half_visual["bpm"],
		}
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 11: Tap Along — Dotted Half + Quarter
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along — Dotted Half + Quarter",
		"Hold through 3 beats, then tap on beat 4.",
		[3.0, 1.0],
		66,
		4
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 12: Quiz — Dotted half beats
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"How many beats does a dotted half note take?",
		["2 beats", "2 and a half beats", "3 beats", "4 beats"],
		2,
		"Correct! 2 + 1 = 3 beats.",
		"The dot adds half the value. Half note = 2, plus half of 2...",
		dotted_half_visual
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 13: Quiz — Which bar adds up to 4
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"Which bar below adds up to 4 beats?",
		["Half note + quarter note + quarter note", "3 quarter notes", "1 half note + 1 eighth note", "5 eighth notes"],
		0,
		"Correct! 2 + 1 + 1 = 4 beats.",
		"Count each option. The bar must total exactly 4.",
		{},
		mixed_bar_choice_visuals
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 14: Recap
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_recap_step(
		"Eighth Notes & Dots Recap",
		"Here's what you've learned about faster notes and dots!",
		[
			{"label": "Eighth note", "detail": "1/2 beat each. Two per beat."},
			{"label": "Counting", "detail": "1-and, 2-and, 3-and, 4-and."},
			{"label": "Dotted half note", "detail": "3 beats. Dot adds half the value."},
			{"label": "Mixed values", "detail": "Different note lengths add up to fill the bar."},
		]
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 15: Tap Challenge — Mixed Pattern
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Challenge — Mixed Pattern",
		"Quarter, two eighths, then hold the half. Listen first!",
		[1.0, 0.5, 0.5, 2.0],
		72,
		4
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 16: Practice Round
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_practice_round_step(
		"Eighth Notes & Dots Practice",
		"Answer from the notation on the staff. Count the beats!",
		_build_practice_pool(eighth_bar, dotted_half_visual, quarter_bar, mixed_bar_choice_visuals),
		8,
		"theory"
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 17: Final Recap
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You can now read eighth notes, dotted halves, and mixed rhythm patterns!",
		[
			{"label": "Eighth note", "detail": "1/2 beat"},
			{"label": "Dotted half note", "detail": "3 beats"},
			{"label": "Mixed values", "detail": "All add up to fill the bar"},
		]
	))

	return LMD.create_module(
		"rhythm_eighths",
		"Eighth Notes & Dots",
		"Eighth notes, dotted half notes, and mixing note values",
		"",
		steps,
		10,
		"Rhythm Explorer"
	)


static func _build_practice_pool(eighth_bar: Dictionary, dotted_half_visual: Dictionary, quarter_bar: Dictionary, mixed_bar_choice_visuals: Array) -> Array:
	return [
		_practice_question(
			"rhythm:eighth_beats",
			"How many beats does an eighth note get?",
			["1 beat", "Half a beat", "2 beats", "A quarter of a beat"],
			1,
			eighth_bar
		),
		_practice_question(
			"rhythm:eighth_counting",
			"How do we count eighth notes?",
			["1, 2, 3, 4", "1-and, 2-and, 3-and, 4-and", "1-2, 3-4", "1, 2"],
			1,
			eighth_bar
		),
		_practice_question(
			"rhythm:dotted_half_beats",
			"How many beats does a dotted half note take?",
			["2 beats", "2 and a half beats", "3 beats", "4 beats"],
			2,
			dotted_half_visual
		),
		_practice_question(
			"rhythm:quarters_make_whole",
			"How many quarter notes equal one whole note?",
			["2", "3", "4", "8"],
			2,
			quarter_bar
		),
		_practice_question(
			"rhythm:mixed_bar_total",
			"Which bar below adds up to 4 beats?",
			["Half note + quarter note + quarter note", "3 quarter notes", "1 half note + 1 eighth note", "5 eighth notes"],
			0,
			{},
			mixed_bar_choice_visuals
		),
		_practice_question(
			"rhythm:eighths_per_beat",
			"How many eighth notes fit in one beat?",
			["1", "2", "3", "4"],
			1
		),
		_practice_question(
			"rhythm:eighths_fill_bar",
			"How many eighth notes fill a 4/4 bar?",
			["4", "6", "8", "16"],
			2
		),
		_practice_question(
			"rhythm:dot_effect",
			"What does a dot do to a note's duration?",
			["Doubles the value", "Adds half the value", "Halves the value", "Adds one beat"],
			1
		),
	]
