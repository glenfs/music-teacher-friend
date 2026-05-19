extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Higher Treble Notes!",
		"Let's learn the higher treble notes! These sit near the top of the staff.",
		"Treble Notes — Part 3"
	))

	# ════════════════════════════════════════════════════════════════════
	# 2. Group A — D5 solo (step 2, fourth line)
	# ════════════════════════════════════════════════════════════════════

	# Visual: introduce D5
	steps.append(LMD.create_visual_step(
		"The Note D",
		"D5 sits on the fourth line of the staff.",
		"note_on_staff",
		{"clef": "treble", "note_name": "D", "note_step": 2}
	))

	# Drag: place D5 (hint on — first note)
	steps.append(LMD.create_drag_note_step(
		"Drag D5 onto the fourth line!",
		"treble", "D5", 2, true,
		"Perfect! D5 on the fourth line.",
		"That line is the fourth from the bottom — try D!"
	))

	# Identify: find D5 among distractors
	steps.append(LMD.create_note_identify_step(
		"treble", "D5", 2, [0, 4],
		"That's D5! Great eye!",
		"Look for the note on the fourth line — that's D5."
	))

	# ════════════════════════════════════════════════════════════════════
	# 3. Group B — E5 + F5 pair (steps 1 and 0)
	# ════════════════════════════════════════════════════════════════════

	# Visual: introduce E5
	steps.append(LMD.create_visual_step(
		"The Note E",
		"E5 is in the top space.",
		"note_on_staff",
		{"clef": "treble", "note_name": "E", "note_step": 1}
	))

	# Visual: introduce F5
	steps.append(LMD.create_visual_step(
		"The Note F",
		"F5 sits right on the top line!",
		"note_on_staff",
		{"clef": "treble", "note_name": "F", "note_step": 0}
	))

	# Drag: place E5 (hint on — first of pair)
	steps.append(LMD.create_drag_note_step(
		"Drag E5 into the top space!",
		"treble", "E5", 1, true,
		"Nice! E5 in the top space.",
		"The top space is just below the top line — that's E!"
	))

	# Drag: place F5 (no hint — progressive difficulty)
	steps.append(LMD.create_drag_note_step(
		"Now place F5 on the staff!",
		"treble", "F5", 0, false,
		"Right! F5 on the top line.",
		"F5 sits on the very top line of the staff."
	))

	# Quiz: name E5
	steps.append(LMD.create_note_quiz_step(
		"treble", "E5", 1,
		["A", "B", "C", "D", "E", "F", "G"],
		4,
		"Yes! E5 is in the top space!",
		"This note sits in the top space of the staff — that's E!"
	))

	# Quiz: name F5
	steps.append(LMD.create_note_quiz_step(
		"treble", "F5", 0,
		["A", "B", "C", "D", "E", "F", "G"],
		5,
		"Right! F5 is on the top line!",
		"This note sits on the very top line of the staff — that's F!"
	))

	# Listen & find: E5 by ear
	steps.append(LMD.create_listen_find_step(
		"treble", "E5", 1, [0, 2],
		"You found E5 by ear! Well done!",
		"Listen carefully — E5 is in the top space."
	))

	# ════════════════════════════════════════════════════════════════════
	# 4. Group C — G5 solo (step -1, above staff — hardest)
	# ════════════════════════════════════════════════════════════════════

	# Visual: introduce G5
	steps.append(LMD.create_visual_step(
		"The Note G",
		"G5 floats in the space just above the top line.",
		"note_on_staff",
		{"clef": "treble", "note_name": "G", "note_step": -1}
	))

	# Drag: place G5 (no hint — hardest position)
	steps.append(LMD.create_drag_note_step(
		"Place G5 above the top line!",
		"treble", "G5", -1, false,
		"You got it! G5 floats above the staff.",
		"G5 sits in the space just above the top line."
	))

	# Quiz: name G5
	steps.append(LMD.create_note_quiz_step(
		"treble", "G5", -1,
		["A", "B", "C", "D", "E", "F", "G"],
		6,
		"You got it! G5 floats just above the top line!",
		"This note is just above the top line — that's G!"
	))

	# ════════════════════════════════════════════════════════════════════
	# 5. Consolidation
	# ════════════════════════════════════════════════════════════════════

	# Recap: all four notes
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are the upper treble notes you just learned:",
		[
			{"label": "D5", "detail": "On the fourth line from the bottom", "clef": "treble", "note_step": 2},
			{"label": "E5", "detail": "In the top space of the staff", "clef": "treble", "note_step": 1},
			{"label": "F5", "detail": "On the top line", "clef": "treble", "note_step": 0},
			{"label": "G5", "detail": "Just above the top line", "clef": "treble", "note_step": -1},
		]
	))

	# Melody example — full treble range
	steps.append(LMD.create_melody_example_step(
		"A Complete Melody!",
		"You can read the whole treble staff now! Here's a melody that stretches from low to high.",
		"treble",
		[
			{"note_id": "C4", "note_step": 10, "beats": 1.0},
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "G4", "note_step": 6, "beats": 1.0},
			{"note_id": "C5", "note_step": 3, "beats": 2.0},
			{"note_id": "B4", "note_step": 4, "beats": 0.5},
			{"note_id": "A4", "note_step": 5, "beats": 0.5},
			{"note_id": "G4", "note_step": 6, "beats": 1.0},
			{"note_id": "E5", "note_step": 1, "beats": 1.0},
			{"note_id": "D5", "note_step": 2, "beats": 1.0},
			{"note_id": "C5", "note_step": 3, "beats": 2.0},
		],
		"Treble Staff Adventure"
	))

	# Practice round — full treble range
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Name notes across the entire treble staff — from C4 all the way up to G5!",
		LMD.treble_note_pool_full(),
		10
	))

	# Cumulative quiz — full treble range
	steps.append(LMD.create_cumulative_quiz_step(
		"Full Treble Challenge!",
		"Can you name notes from the FULL treble range?",
		LMD.treble_note_pool_full(),
		5
	))

	# Final recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've mastered the entire treble staff! From Middle C up to G5!",
		[
			{"label": "D5, E5, F5, G5", "detail": "The high treble notes you just learned"},
			{"label": "Full range: C4–G5", "detail": "You can now read 12 notes on the treble staff!"},
		]
	))

	return LMD.create_module(
		"treble_part3",
		"Treble Notes — Part 3",
		"Learn D5, E5, F5, and G5",
		"",
		steps,
		12,
		"Treble Master"
	)
