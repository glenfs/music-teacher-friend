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
	var sixteenth_bar := _staff_visual(
		[[
			_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
			_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
			_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
			_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
		]],
		4, 4,
		"Count: 1-e-and-a  2-e-and-a  3-e-and-a  4-e-and-a.",
		"Four sixteenth notes fit inside one beat. They are usually beamed in groups of 4.",
		true, 60,
		[[[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15]]]
	)
	var quarter_equals_sixteenths := {
		"left_item": {"kind": "quarter", "beats": 1.0},
		"right_items": [
			{"kind": "sixteenth", "beats": 0.25},
			{"kind": "sixteenth", "beats": 0.25},
			{"kind": "sixteenth", "beats": 0.25},
			{"kind": "sixteenth", "beats": 0.25},
		],
		"beam_group": [0, 1, 2, 3],
		"left_label": "1 beat",
		"right_label": "4 x 1/4 beat",
		"caption": "One quarter note equals four sixteenth notes.",
		"detail": "One steady beat can be split into four very quick taps.",
	}
	var mixed_sixteenths_quarters := _merge(_staff_visual(
		[[
			_rhythm_note("quarter"),
			_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
		]],
		4, 4,
		"Hear the steady beat, then the quick burst of four sixteenths.",
		"Quarter (1) + four sixteenths (1) + quarter (1) + quarter (1) = 4 beats.",
		true, 60,
		[[[1, 2, 3, 4]]]
	), {"playable": true})
	var beam_groups_for_half_beat := [[[1, 2, 3, 4]]]
	var mixed_bar_choice_visuals := [
		_choice_staff_visual(
			[
				_rhythm_note("quarter"),
				_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
				_rhythm_note("half"),
			],
			beam_groups_for_half_beat
		),
		_choice_staff_visual(
			[
				_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
				_rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"), _rhythm_note("sixteenth"),
				_rhythm_note("quarter"),
			],
			[[[0, 1, 2, 3], [4, 5, 6, 7]]]
		),
		_choice_staff_visual(
			[
				_rhythm_note("half"),
				_rhythm_note("quarter"),
				_rhythm_note("sixteenth"),
			],
			[]
		),
		_choice_staff_visual(
			[
				_rhythm_note("quarter"),
				_rhythm_note("quarter"),
				_rhythm_note("quarter"),
				_rhythm_note("quarter"),
				_rhythm_note("sixteenth"),
			],
			[]
		),
	]

	var steps: Array = []

	steps.append(LMD.create_intro_step(
		"Sixteenth Notes",
		"Now each beat splits into four equal parts. Sixteenth notes move fast, but the pulse stays steady.",
		"This module focuses on clean subdivision, not extra dotted rhythms or rests."
	))

	steps.append(LMD.create_visual_step(
		"The Sixteenth Note",
		"A sixteenth note lasts one quarter of a beat. Four of them fit inside one beat.",
		"rhythm_value",
		{
			"value": "sixteenth",
			"beats": 0.25,
			"bars": sixteenth_bar["bars"],
			"beam_groups": sixteenth_bar["beam_groups"],
			"prompt": sixteenth_bar["prompt"],
			"caption": sixteenth_bar["caption"],
			"bpm": sixteenth_bar["bpm"],
		}
	))

	steps.append(LMD.create_visual_step(
		"Quarter = Four Sixteenths",
		"One beat can be divided into four equal slices.",
		"rhythm_equivalence",
		quarter_equals_sixteenths
	))

	steps.append(LMD.create_visual_step(
		"Counting Sixteenths",
		"Count 1-e-and-a, 2-e-and-a. Four syllables per beat keeps the spacing even.",
		"rhythm_staff_example",
		sixteenth_bar
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along - Sixteenth Notes",
		"Tap four quick notes per beat. Keep the pulse steady under the fast notes.",
		[0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25],
		50,
		4
	))

	steps.append(_quiz_with_reference(
		"How many sixteenth notes fit inside one quarter note?",
		["2", "3", "4", "8"],
		2,
		"Right. Four sixteenth notes equal one quarter note.",
		"A single beat is divided into four equal parts here.",
		sixteenth_bar
	))

	steps.append(_quiz_with_reference(
		"How do we count sixteenth notes?",
		["1-2-3-4", "1-and, 2-and", "1-e-and-a, 2-e-and-a", "1-a, 2-a"],
		2,
		"Correct. Sixteenths use four syllables per beat: 1-e-and-a.",
		"Two syllables are not enough for four equal notes.",
		sixteenth_bar
	))

	steps.append(LMD.create_visual_step(
		"Mixing Quarters and Sixteenths",
		"Real rhythm reading means keeping the same beat while the note values change.",
		"rhythm_staff_example",
		mixed_sixteenths_quarters
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along - Quarters + Sixteenths",
		"Steady beat, quick burst, steady beat, steady beat.",
		[1.0, 0.25, 0.25, 0.25, 0.25, 1.0, 1.0],
		54,
		4
	))

	steps.append(_quiz_with_reference(
		"How many beats does one sixteenth note get?",
		["Half a beat", "1 beat", "A quarter of a beat", "2 beats"],
		2,
		"Correct. A sixteenth note lasts one quarter of a beat.",
		"It is shorter than an eighth note and much shorter than a quarter note.",
		sixteenth_bar
	))

	steps.append(_quiz_with_reference(
		"Which bar below adds up to exactly 4 beats?",
		["Quarter + four 16ths + half", "Eight 16ths + quarter", "Half + quarter + 16th", "Four quarters + 16th"],
		0,
		"Correct. 1 + 1 + 2 = 4 beats.",
		"Check every note value carefully. The bar must total exactly 4.",
		{},
		mixed_bar_choice_visuals
	))

	steps.append(LMD.create_recap_step(
		"Sixteenth Notes Recap",
		"These are the ideas to keep before the practice round.",
		[
			{"label": "Sixteenth note", "detail": "1/4 beat. Four fit inside one beat."},
			{"label": "Counting", "detail": "1-e-and-a keeps the spacing even."},
			{"label": "Subdivision", "detail": "The beat stays steady even when notes move faster."},
			{"label": "Bar math", "detail": "Every bar still has to add up exactly."},
		]
	))

	steps.append(LMD.create_practice_round_step(
		"Sixteenth Notes Practice",
		"Answer from the staff. Count carefully and watch the bar total.",
		_build_practice_pool(sixteenth_bar, mixed_sixteenths_quarters, mixed_bar_choice_visuals),
		8,
		"theory"
	))

	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You can now read and count sixteenth notes inside clear 4/4 patterns.",
		[
			{"label": "Read the beat", "detail": "A sixteenth note is one quarter of a beat."},
			{"label": "Count the burst", "detail": "Use 1-e-and-a for four even subdivisions."},
			{"label": "Trust the math", "detail": "Every bar must still add up exactly."},
		]
	))

	return LMD.create_module(
		"rhythm_sixteenths",
		"Sixteenth Notes",
		"Sixteenth note subdivision and clean 4/4 rhythm reading",
		"",
		steps,
		10,
		"Subdivision Scout"
	)


static func _build_practice_pool(sixteenth_bar: Dictionary, mixed_sixteenths_quarters: Dictionary, mixed_bar_choice_visuals: Array) -> Array:
	return [
		_practice_question(
			"rhythm:sixteenth_beats",
			"How many beats does one sixteenth note get?",
			["Half a beat", "1 beat", "A quarter of a beat", "2 beats"],
			2,
			sixteenth_bar
		),
		_practice_question(
			"rhythm:sixteenth_counting",
			"How do we count sixteenth notes?",
			["1-2-3-4", "1-and, 2-and", "1-e-and-a, 2-e-and-a", "1-a, 2-a"],
			2,
			sixteenth_bar
		),
		_practice_question(
			"rhythm:sixteenths_per_quarter",
			"How many sixteenth notes fit inside one quarter note?",
			["2", "3", "4", "8"],
			2
		),
		_practice_question(
			"rhythm:sixteenths_fill_bar",
			"How many sixteenth notes fill one full 4/4 bar?",
			["4", "8", "16", "32"],
			2,
			sixteenth_bar
		),
		_practice_question(
			"rhythm:quarter_equals_four_sixteenths",
			"What is one quarter note equal to?",
			["2 eighth notes", "4 sixteenth notes", "1 half note", "8 sixteenth notes"],
			1
		),
		_practice_question(
			"rhythm:mixed_sixteenth_pattern",
			"How many beats do the four sixteenths in the middle of the bar add up to?",
			["Half a beat", "1 beat", "2 beats", "4 beats"],
			1,
			mixed_sixteenths_quarters
		),
		_practice_question(
			"rhythm:mixed_bar_sixteenths",
			"Which bar below adds up to exactly 4 beats?",
			["Quarter + four 16ths + half", "Eight 16ths + quarter", "Half + quarter + 16th", "Four quarters + 16th"],
			0,
			{},
			mixed_bar_choice_visuals
		),
	]