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
	var quarter_bar := _staff_visual(
		[[_rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter")]],
		4, 4,
		"Clap along: 1  2  3  4  — one clap per beat.",
		"Quarter notes are the steady pulse. Each one gets 1 beat."
	)
	var half_bar := _staff_visual(
		[[_rhythm_note("half"), _rhythm_note("half")]],
		4, 4,
		"Count: 1-2  3-4  — hold each note for 2 beats.",
		"Two half notes fill a 4/4 bar."
	)
	var whole_bar := _staff_visual(
		[[_rhythm_note("whole")]],
		4, 4,
		"Clap once and count: 1-2-3-4  — one long hold through all 4 beats.",
		"A whole note lasts for the entire bar."
	)
	var mixed_half_quarters := _merge(_staff_visual(
		[[_rhythm_note("half"), _rhythm_note("quarter"), _rhythm_note("quarter")]],
		4, 4,
		"Clap: hold... tap tap. The half note lasts 2 beats, then two quick quarters.",
		"The half note lasts 2 beats, each quarter note lasts 1 beat. Total: 4."
	), {"playable": true})
	var ladder_visual := _merge(_staff_visual(
		[
			[_rhythm_note("whole")],
			[_rhythm_note("half"), _rhythm_note("half")],
			[_rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter")],
		],
		4, 4,
		"Listen: same 4 beats, different divisions. Press Hear the Demo.",
		"1 whole = 2 halves = 4 quarters.  Each bar totals 4 beats."
	), {"playable": true})
	var rests_bar_visual := _staff_visual(
		[[
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0, "rest": true, "rest_kind": "quarter_rest"},
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0, "rest": true, "rest_kind": "quarter_rest"},
		], [
			{"kind": "half", "beats": 2.0},
			{"kind": "half", "beats": 2.0, "rest": true, "rest_kind": "half_rest"},
		]],
		4, 4,
		"Count: 1 (rest) 3 (rest)  |  1-2 (rest-rest). The beat never stops.",
		"Quarter rest = 1 beat silence.  Half rest = 2 beats silence."
	)
	var time_sig_visual := _staff_visual(
		[[_rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter"), _rhythm_note("quarter")]],
		4, 4,
		"Look at the two numbers before the first note.",
		"Top number = beats per bar.  Bottom number = which note gets one beat."
	)
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
			_rhythm_note("quarter"),
		]),
		_choice_staff_visual([
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
			_rhythm_note("quarter"),
		]),
	]

	# ── Build steps ─────────────────────────────────────────────────
	var steps: Array = []

	# ═══════════════════════════════════════════════════════════════
	# Step 1: Intro
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_intro_step(
		"Rhythm Basics",
		"Rhythm tells us WHEN to play and HOW LONG to hold each note. You'll clap, listen, and tap!",
		"Get ready to move and make some noise!"
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 2: Feel 4 Steady Beats
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"Feel 4 Steady Beats",
		"Most music starts with a steady pulse. Clap along with the metronome -- it will repeat so you can really feel it. Count 1, 2, 3, 4 out loud.",
		"rhythm_staff_example",
		_merge(quarter_bar, {"loop_count": 10})
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 3: The Quarter Note
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Quarter Note",
		"The quarter note gets 1 beat — one clap, one count.",
		"rhythm_value",
		{
			"value": "quarter",
			"beats": 1.0,
			"bars": quarter_bar["bars"],
			"prompt": quarter_bar["prompt"],
			"caption": quarter_bar["caption"],
			"bpm": quarter_bar["bpm"],
		}
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 4: Tap Along — Quarter Notes
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along — Quarter Notes",
		"Tap anywhere on the zone when each note starts!",
		[1.0, 1.0, 1.0, 1.0],
		66,
		4
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 5: Quiz — Quarter note beats
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"How many beats does one quarter note get?",
		["Half a beat", "1 beat", "2 beats", "4 beats"],
		1,
		"Correct! One quarter note = 1 beat.",
		"A quarter note is the basic pulse — check the staff.",
		quarter_bar
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 6: The Half Note
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Half Note",
		"A half note lasts 2 beats — twice as long as a quarter note. Count \"1-2\" while holding it.",
		"rhythm_value",
		{
			"value": "half",
			"beats": 2.0,
			"bars": half_bar["bars"],
			"prompt": half_bar["prompt"],
			"caption": half_bar["caption"],
			"bpm": half_bar["bpm"],
		}
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 7: Mix It: Half + Quarters
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"Mix It: Half + Quarters",
		"Feel the contrast. Hold... tap tap.",
		"rhythm_staff_example",
		mixed_half_quarters
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 8: Tap Along — Half + Quarters
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along — Half + Quarters",
		"Tap when each new note starts.",
		[2.0, 1.0, 1.0],
		72,
		4
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 9: Quiz — Half notes fill bar
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"How many half notes fill one 4/4 bar?",
		["1", "2", "3", "4"],
		1,
		"Exactly. Two half notes add up to 4 beats.",
		"Each half note lasts 2 beats. How many fit in 4?",
		half_bar
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 10: The Whole Note
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Whole Note",
		"A whole note fills the entire bar — 4 beats. Clap once and hold.",
		"rhythm_value",
		{
			"value": "whole",
			"beats": 4.0,
			"bars": whole_bar["bars"],
			"prompt": whole_bar["prompt"],
			"caption": whole_bar["caption"],
			"bpm": whole_bar["bpm"],
		}
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 11: Quiz — Which note lasts 4 beats
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"Which note lasts 4 beats in 4/4 time?",
		["Half note", "Quarter note", "Whole note", "Eighth note"],
		2,
		"Correct! The whole note fills all 4 beats.",
		"Which note fills the entire bar?",
		whole_bar
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 12: The Note Value Ladder
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Note Value Ladder",
		"All bars last 4 beats but divide time differently.",
		"rhythm_staff_example",
		ladder_visual
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 13: Quiz — Quarters make whole
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"How many quarter notes equal one whole note?",
		["2", "3", "4", "8"],
		2,
		"Right! 4 quarter notes fill the same time as 1 whole note.",
		"Look at the ladder — count the quarters in the bottom bar.",
		ladder_visual
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 14: The Time Signature
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"The Time Signature",
		"Top = beats per bar. Bottom = which note gets one beat.",
		"time_signature",
		time_sig_visual
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 15: Quiz — Time signature top number
	# ═══════════════════════════════════════════════════════════════
	steps.append(_quiz_with_reference(
		"In 4/4 time, what does the top number tell you?",
		["How many beats are in the bar", "Which note is sharp", "How loud to play", "Which clef to use"],
		0,
		"Correct! The top number tells you how many beats per bar.",
		"Look at the stacked numbers. The top one is about beats.",
		_merge(time_sig_visual, {"highlight_top": true})
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 16: Explanation — Rests
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_explanation_step(
		"Rests — The Sound of Silence",
		"Silence is just as important as sound. A rest means stop playing but keep counting.",
		"Each rest type lasts the same number of beats as its matching note.",
		"Quarter rest = 1 silent beat.  Half rest = 2 silent beats.  Whole rest = a full bar of silence."
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 17: Visual — Rests in Action
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_visual_step(
		"Rests in Action",
		"Watch the rests. Count beats, notice where silence falls.",
		"rhythm_staff_example",
		rests_bar_visual
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 18: Tap Along — Feel the Rests
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_rhythm_tap_step(
		"Tap Along — Feel the Rests",
		"Tap on beats 1 and 3. Beats 2 and 4 are rests — keep counting but don't tap!",
		[
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0, "rest": true, "rest_kind": "quarter_rest"},
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0, "rest": true, "rest_kind": "quarter_rest"},
		],
		60,
		4,
		{
			"description": "You'll hear the pattern first. Then tap beats 1 and 3, and stay silent on beats 2 and 4.",
		}
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 19: Recap
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_recap_step(
		"Rhythm Basics Recap",
		"Here are all the note values you've learned so far!",
		[
			{"label": "Quarter note", "detail": "1 beat. The steady pulse."},
			{"label": "Half note", "detail": "2 beats. Hold for two counts."},
			{"label": "Whole note", "detail": "4 beats. Fills the whole bar."},
			{"label": "Rests", "detail": "Same durations as notes, but silent. Keep the beat!"},
		]
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 20: Practice Round
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_practice_round_step(
		"Rhythm Basics Practice",
		"Answer from the notation on the staff. Count the beats!",
		_build_practice_pool(quarter_bar, half_bar, whole_bar, time_sig_visual, mixed_bar_choice_visuals),
		6,
		"theory"
	))

	# ═══════════════════════════════════════════════════════════════
	# Step 21: Final Recap
	# ═══════════════════════════════════════════════════════════════
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You can now read quarter, half, and whole notes, and understand rests!",
		[
			{"label": "Quarter note", "detail": "1 beat"},
			{"label": "Half note", "detail": "2 beats"},
			{"label": "Whole note", "detail": "4 beats"},
			{"label": "Rests", "detail": "Silent beats — keep counting!"},
		]
	))

	return LMD.create_module(
		"rhythm_basics",
		"Rhythm Basics",
		"Quarter, half, and whole notes — the building blocks of rhythm",
		"",
		steps,
		8,
		"Rhythm Starter"
	)


static func _build_practice_pool(quarter_bar: Dictionary, half_bar: Dictionary, whole_bar: Dictionary, time_sig_visual: Dictionary, mixed_bar_choice_visuals: Array) -> Array:
	return [
		_practice_question(
			"rhythm:quarter_beats",
			"How many beats does one quarter note get?",
			["Half a beat", "1 beat", "2 beats", "4 beats"],
			1,
			quarter_bar
		),
		_practice_question(
			"rhythm:whole_beats",
			"Which note value lasts 4 beats in 4/4 time?",
			["Half note", "Quarter note", "Whole note", "Eighth note"],
			2,
			whole_bar
		),
		_practice_question(
			"rhythm:half_fill_bar",
			"How many half notes fill one 4/4 bar?",
			["1", "2", "3", "4"],
			1,
			half_bar
		),
		_practice_question(
			"rhythm:quarters_make_whole",
			"How many quarter notes equal one whole note?",
			["2", "3", "4", "8"],
			2,
			quarter_bar
		),
		_practice_question(
			"rhythm:time_signature_top",
			"In 4/4 time, what does the top number tell you?",
			["How many beats are in the bar", "Which clef to use", "How loud to play", "How fast to clap"],
			0,
			time_sig_visual
		),
		_practice_question(
			"rhythm:mixed_bar_total",
			"Which bar below adds up to 4 beats?",
			["Half note + quarter note + quarter note", "3 quarter notes", "1 half note + 1 quarter note", "5 quarter notes"],
			0,
			{},
			mixed_bar_choice_visuals
		),
	]
