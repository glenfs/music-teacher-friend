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
	var dotted_quarter_value_bar := [
		_rhythm_note("dotted_quarter"),
		_rhythm_note("eighth"),
		_rhythm_note("half"),
	]
	var dotted_quarter_pair_bar := [
		_rhythm_note("dotted_quarter"),
		_rhythm_note("eighth"),
		_rhythm_note("dotted_quarter"),
		_rhythm_note("eighth"),
	]
	var eighth_rest_pattern := [
		_rhythm_note("quarter"),
		{"kind": "eighth", "beats": 0.5, "rest": true, "rest_kind": "eighth_rest"},
		_rhythm_note("eighth"),
		_rhythm_note("quarter"),
		_rhythm_note("quarter"),
	]
	var sixteenth_rest_visual_bar := [
		_rhythm_note("quarter"),
		{"kind": "sixteenth", "beats": 0.25, "rest": true, "rest_kind": "sixteenth_rest"},
		_rhythm_note("sixteenth"),
		_rhythm_note("eighth"),
		_rhythm_note("quarter"),
		_rhythm_note("quarter"),
	]
	var sixteenth_rest_tap_pattern := [
		_rhythm_note("quarter"),
		{"kind": "sixteenth", "beats": 0.25, "rest": true, "rest_kind": "sixteenth_rest"},
		_rhythm_note("sixteenth"),
		_rhythm_note("eighth"),
		_rhythm_note("half"),
	]
	var syncopated_bar := [
		{"kind": "eighth", "beats": 0.5, "rest": true, "rest_kind": "eighth_rest"},
		_rhythm_note("eighth"),
		_rhythm_note("dotted_quarter"),
		_rhythm_note("eighth"),
		_rhythm_note("quarter"),
	]
	var final_challenge_pattern := [
		_rhythm_note("quarter"),
		{"kind": "eighth", "beats": 0.5, "rest": true, "rest_kind": "eighth_rest"},
		_rhythm_note("eighth"),
		_rhythm_note("dotted_quarter"),
		_rhythm_note("eighth"),
	]

	var dotted_quarter_visual := _staff_visual(
		[dotted_quarter_value_bar],
		4, 4,
		"A dotted quarter lasts 1.5 beats: hold through beat 1 and into the and of 2.",
		"A dot adds half the note's value. Quarter note (1) + half of 1 = 1.5 beats.",
		true, 72
	)
	var dotted_quarter_pair_visual := _merge(_staff_visual(
		[dotted_quarter_pair_bar],
		4, 4,
		"Long-short, long-short. Each dotted quarter plus eighth fills 2 beats.",
		"Dotted quarter (1.5) + eighth (0.5) = 2 beats, so two pairs fill a 4/4 bar.",
		true, 68
	), {"playable": true})
	var eighth_rest_visual := _staff_visual(
		[eighth_rest_pattern],
		4, 4,
		"The beat keeps moving during the rest. Stay silent for half a beat, then come back in.",
		"Quarter (1) + eighth rest (0.5) + eighth (0.5) + quarter (1) + quarter (1) = 4 beats.",
		true, 72
	)
	var sixteenth_rest_visual := _staff_visual(
		[sixteenth_rest_visual_bar],
		4, 4,
		"A sixteenth rest is only a quarter of a beat, so the next note feels late and punchy.",
		"Quarter (1) + sixteenth rest (0.25) + sixteenth (0.25) + eighth (0.5) + quarter (1) + quarter (1) = 4 beats.",
		true, 72
	)
	var syncopated_visual := _merge(_staff_visual(
		[syncopated_bar],
		4, 4,
		"Notice the off-beat start after the rest, then the dotted quarter stretches across the pulse.",
		"Eighth rest (0.5) + eighth (0.5) + dotted quarter (1.5) + eighth (0.5) + quarter (1) = exactly 4 beats.",
		true, 70
	), {"playable": true})

	var mixed_bar_choice_visuals := [
		_choice_staff_visual([
			_rhythm_note("quarter"),
			{"kind": "eighth", "beats": 0.5, "rest": true, "rest_kind": "eighth_rest"},
			_rhythm_note("eighth"),
			_rhythm_note("dotted_quarter"),
			_rhythm_note("eighth"),
		]),
		_choice_staff_visual([
			_rhythm_note("quarter"),
			{"kind": "eighth", "beats": 0.5, "rest": true, "rest_kind": "eighth_rest"},
			_rhythm_note("eighth"),
			_rhythm_note("quarter"),
			_rhythm_note("eighth"),
		]),
		_choice_staff_visual([
			{"kind": "eighth", "beats": 0.5, "rest": true, "rest_kind": "eighth_rest"},
			_rhythm_note("eighth"),
			_rhythm_note("dotted_quarter"),
			_rhythm_note("quarter"),
		]),
		_choice_staff_visual([
			_rhythm_note("quarter"),
			{"kind": "sixteenth", "beats": 0.25, "rest": true, "rest_kind": "sixteenth_rest"},
			_rhythm_note("sixteenth"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
		]),
	]

	var steps: Array = []

	steps.append(LMD.create_intro_step(
		"Dotted Rhythms & Rests",
		"Now we move past plain sixteenths into dotted quarter patterns, eighth and sixteenth rests, and real 4/4 syncopation.",
		"These rhythms still fit the bar exactly, even when the accents shift."
	))

	steps.append(LMD.create_visual_step(
		"The Dotted Quarter Note",
		"A dotted quarter lasts 1.5 beats, so it stretches past the next beat line.",
		"rhythm_value",
		{
			"value": "dotted_quarter",
			"beats": 1.5,
			"bars": dotted_quarter_visual["bars"],
			"prompt": dotted_quarter_visual["prompt"],
			"caption": dotted_quarter_visual["caption"],
			"bpm": dotted_quarter_visual["bpm"],
		}
	))

	steps.append(LMD.create_visual_step(
		"Dotted Quarter + Eighth",
		"This is the classic pair: a long note for 1.5 beats, then a short note for 0.5 beats.",
		"rhythm_staff_example",
		dotted_quarter_pair_visual
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along - Dotted Quarter + Eighth",
		"Hold the long note for 1.5 beats, then tap the short note right on time.",
		[1.5, 0.5, 1.5, 0.5],
		62,
		4
	))

	steps.append(_quiz_with_reference(
		"How many beats does a dotted quarter note get?",
		["1 beat", "1.5 beats", "2 beats", "3 beats"],
		1,
		"Correct. A dotted quarter lasts 1.5 beats.",
		"The dot adds half the quarter note's value, not a whole extra beat.",
		dotted_quarter_visual
	))

	steps.append(LMD.create_explanation_step(
		"Rests Still Count",
		"Rests are silent beats, not empty space. You still keep counting while you wait.",
		"Eighth rests last half a beat. Sixteenth rests last a quarter of a beat.",
		"Silence can make a rhythm feel more alive and syncopated."
	))

	steps.append(LMD.create_visual_step(
		"Eighth Rest in Context",
		"Stay silent for half a beat, then re-enter cleanly on the next eighth note.",
		"rhythm_staff_example",
		eighth_rest_visual
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along - Eighth Rest Pattern",
		"Tap the notes, stay silent on the rest, and keep the beat moving the whole time.",
		eighth_rest_pattern.duplicate(true),
		68,
		4
	))

	steps.append(LMD.create_visual_step(
		"Sixteenth Rest in Context",
		"A sixteenth rest creates a tiny delayed entrance. The note comes in just after the beat starts.",
		"rhythm_staff_example",
		sixteenth_rest_visual
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along - Sixteenth Rest Pattern",
		"Leave a tiny gap for the sixteenth rest, then land the next note right away.",
		sixteenth_rest_tap_pattern.duplicate(true),
		68,
		4
	))

	steps.append(LMD.create_visual_step(
		"A Syncopated 4/4 Bar",
		"This kind of off-beat entrance shows up in real music all the time. It still totals exactly 4 beats.",
		"rhythm_staff_example",
		syncopated_visual
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Final Tap Challenge",
		"Quarter note, silent half-beat, quick eighth, long dotted quarter, final eighth.",
		final_challenge_pattern.duplicate(true),
		70,
		4
	))

	steps.append(LMD.create_recap_step(
		"Syncopation Recap",
		"These are the key ideas before the practice round.",
		[
			{"label": "Dotted quarter", "detail": "1.5 beats. A dot adds half the note's value."},
			{"label": "Dotted quarter + eighth", "detail": "Together they make 2 beats."},
			{"label": "Eighth rest", "detail": "0.5 beat of silence."},
			{"label": "Sixteenth rest", "detail": "0.25 beat of silence."},
			{"label": "Syncopation", "detail": "Notes and rests can shift accents while still filling 4/4 exactly."},
		]
	))

	steps.append(LMD.create_practice_round_step(
		"Dotted Rhythms & Rests Practice",
		"Count carefully and make sure every bar really adds up.",
		_build_practice_pool(
			dotted_quarter_visual,
			dotted_quarter_pair_visual,
			eighth_rest_visual,
			sixteenth_rest_visual,
			mixed_bar_choice_visuals
		),
		8,
		"theory"
	))

	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You can now read dotted quarter rhythms, short rests, and valid syncopated bars in 4/4.",
		[
			{"label": "Read the math", "detail": "Every note and rest value must add up exactly."},
			{"label": "Hear the groove", "detail": "Silence can create just as much rhythm as sound."},
			{"label": "Count through syncopation", "detail": "Keep the pulse steady even when notes land off the beat."},
		]
	))

	return LMD.create_module(
		"rhythm_syncopation",
		"Dotted Rhythms & Rests",
		"Dotted quarter notes, short rests, and syncopated 4/4 rhythm patterns",
		"",
		steps,
		12,
		"Rhythm Master"
	)


static func _build_practice_pool(dotted_quarter_visual: Dictionary, dotted_quarter_pair_visual: Dictionary, eighth_rest_visual: Dictionary, sixteenth_rest_visual: Dictionary, mixed_bar_choice_visuals: Array) -> Array:
	return [
		_practice_question(
			"rhythm:dotted_quarter_beats",
			"How many beats does a dotted quarter note get?",
			["1 beat", "1.5 beats", "2 beats", "3 beats"],
			1,
			dotted_quarter_visual
		),
		_practice_question(
			"rhythm:dot_on_quarter",
			"What does a dot do to a quarter note?",
			["It doubles it to 2 beats", "It adds half its value, making 1.5 beats", "It cuts it to half a beat", "It turns it into a rest"],
			1,
			dotted_quarter_visual
		),
		_practice_question(
			"rhythm:dotted_pair_total",
			"How many beats do a dotted quarter and an eighth note make together?",
			["1 beat", "1.5 beats", "2 beats", "4 beats"],
			2,
			dotted_quarter_pair_visual
		),
		_practice_question(
			"rhythm:eighth_rest_duration",
			"How long does an eighth rest last?",
			["A quarter beat", "Half a beat", "1 beat", "2 beats"],
			1,
			eighth_rest_visual
		),
		_practice_question(
			"rhythm:eighth_rest_reentry",
			"In the example bar, when does the sound return after the eighth rest?",
			["On beat 1", "On the and of 2", "On beat 3", "On beat 4"],
			1,
			eighth_rest_visual
		),
		_practice_question(
			"rhythm:sixteenth_rest_duration",
			"How long does a sixteenth rest last?",
			["A quarter beat", "Half a beat", "1 beat", "1.5 beats"],
			0,
			sixteenth_rest_visual
		),
		_practice_question(
			"rhythm:rests_keep_counting",
			"What should you do during a rest?",
			["Stop counting until the next note", "Keep counting silently", "Speed up to catch the next note", "Treat it like a fermata"],
			1
		),
		_practice_question(
			"rhythm:mixed_bar_total",
			"Which bar below adds up to exactly 4 beats?",
			[
				"Quarter + eighth rest + eighth + dotted quarter + eighth",
				"Quarter + eighth rest + eighth + quarter + eighth",
				"Eighth rest + eighth + dotted quarter + quarter",
				"Quarter + sixteenth rest + sixteenth + quarter + quarter",
			],
			0,
			{},
			mixed_bar_choice_visuals
		),
	]
