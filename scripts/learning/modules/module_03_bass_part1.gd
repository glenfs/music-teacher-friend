extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Your First Bass Notes!",
		"Now let's learn your first bass notes! We'll start from Middle C and go down.",
		"Bass Notes — Part 1"
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP A — C4 solo (1+2+2 pattern: the "1")
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce C4
	steps.append(LMD.create_visual_step(
		"Middle C",
		"Middle C sits on its own extra little line just above the bass staff. This extra line is called a ledger line — a small extension when notes need to go beyond the five main lines!",
		"note_on_staff",
		{"clef": "bass", "note_name": "C", "note_step": -2}
	))

	# Drag: place C4 on the staff (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the ledger line above the staff!",
		"bass", "C4", -2, true,
		"That's Middle C! Right on the ledger line above the staff.",
		"Middle C sits on its own little ledger line just above the bass staff."
	))

	# Identify: find C4 among distractors
	steps.append(LMD.create_note_identify_step(
		"bass", "C4", -2, [0, 2],
		"Find Middle C among these notes!",
		"Look for the note on the ledger line above the staff — that's C!"
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP B — B3 + A3 (first pair of the "2+2")
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce B3
	steps.append(LMD.create_visual_step(
		"The Note B",
		"B is just below Middle C, in the space above the top line.",
		"note_on_staff",
		{"clef": "bass", "note_name": "B", "note_step": -1}
	))

	# Visual: introduce A3
	steps.append(LMD.create_visual_step(
		"The Note A",
		"A sits right on the top line of the bass staff!",
		"note_on_staff",
		{"clef": "bass", "note_name": "A", "note_step": 0}
	))

	# Drag: B3 (hint on — first time placing B)
	steps.append(LMD.create_drag_note_step(
		"Drag B to the space above the top line!",
		"bass", "B3", -1, true,
		"That's B! Right in the space above the staff.",
		"B floats in the space just above the top line."
	))

	# Drag: A3 (no hint — progressive difficulty)
	steps.append(LMD.create_drag_note_step(
		"Now place A on the staff!",
		"bass", "A3", 0, false,
		"Right! A is on the top line!",
		"A sits right on the very top line of the bass staff."
	))

	# Quiz: name B3
	steps.append(LMD.create_note_quiz_step(
		"bass", "B3", -1,
		["A", "B", "C", "D"],
		1,
		"Yes! B is in the space above the top line.",
		"This note floats in the space just above the staff — that's B!"
	))

	# Quiz: name A3
	steps.append(LMD.create_note_quiz_step(
		"bass", "A3", 0,
		["F", "G", "A", "B"],
		2,
		"Right! A is on the top line!",
		"This note sits on the very top line of the bass staff — that's A!"
	))

	# Listen & Find: A3 target, distractors B3 + F3
	steps.append(LMD.create_listen_find_step(
		"bass", "A3", 0, [-1, 2],
		"Great ear! That was A.",
		"Listen again — A is the note on the top line of the staff."
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP C — G3 + F3 (second pair of the "2+2")
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce G3
	steps.append(LMD.create_visual_step(
		"The Note G",
		"G is in the top space.",
		"note_on_staff",
		{"clef": "bass", "note_name": "G", "note_step": 1}
	))

	# Visual: introduce F3
	steps.append(LMD.create_visual_step(
		"The Note F",
		"F sits on the fourth line — where the bass clef dots are!",
		"note_on_staff",
		{"clef": "bass", "note_name": "F", "note_step": 2}
	))

	# Drag: G3 (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag G into the top space of the staff!",
		"bass", "G3", 1, true,
		"That's G — right in the top space!",
		"G goes in the top space, just below the top line."
	))

	# Drag: F3 (no hint)
	steps.append(LMD.create_drag_note_step(
		"Place F on the staff!",
		"bass", "F3", 2, false,
		"You got it! F is on the fourth line!",
		"F sits on the fourth line — between the bass clef dots."
	))

	# Quiz: name G3
	steps.append(LMD.create_note_quiz_step(
		"bass", "G3", 1,
		["E", "F", "G", "A"],
		2,
		"That's G — in the top space!",
		"This note is in the top space below the top line — that's G!"
	))

	# Quiz: name F3
	steps.append(LMD.create_note_quiz_step(
		"bass", "F3", 2,
		["D", "E", "F", "G"],
		2,
		"You got it! F is on the fourth line!",
		"This note is on the fourth line where the bass clef dots sit — that's F!"
	))

	# Listen & Find: F3 target, distractors G3 + A3
	steps.append(LMD.create_listen_find_step(
		"bass", "F3", 2, [1, 0],
		"Nice! That was F.",
		"Listen again — F is on the fourth line, between the bass clef dots."
	))

	# ══════════════════════════════════════════════════════════════════════
	# CONSOLIDATION
	# ══════════════════════════════════════════════════════════════════════

	# Recap: all 5 notes
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are your first five bass notes:",
		[
			{"label": "C (Middle C)", "detail": "On its own ledger line above the staff", "clef": "bass"},
			{"label": "B", "detail": "In the space just above the top line", "clef": "bass"},
			{"label": "A", "detail": "On the top line of the staff", "clef": "bass"},
			{"label": "G", "detail": "In the top space, just below the A line", "clef": "bass"},
			{"label": "F", "detail": "On the fourth line — where the bass clef dots are", "clef": "bass"},
		]
	))

	# Melody Example: C4 down to F3 and back
	steps.append(LMD.create_melody_example_step(
		"Simple Bass Scale",
		"These are the notes you just learned — listen as they go down and back up!",
		"bass",
		[
			{"note_id": "C4", "note_step": -2, "beats": 1.0},
			{"note_id": "B3", "note_step": -1, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 1.0},
			{"note_id": "G3", "note_step": 1, "beats": 1.0},
			{"note_id": "F3", "note_step": 2, "beats": 2.0},
			{"note_id": "G3", "note_step": 1, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 1.0},
			{"note_id": "C4", "note_step": -2, "beats": 2.0},
		],
		"Simple Bass Scale"
	))

	# Practice Round
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's practice those bass clef notes! Name each note as it appears on the staff.",
		LMD.bass_note_pool_basic(),
		8
	))

	# Cumulative Quiz
	steps.append(LMD.create_cumulative_quiz_step(
		"Note Review",
		"Final review! Name these bass clef notes.",
		LMD.bass_note_pool_basic(),
		5
	))

	# Final Recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Great work! You've learned five bass clef notes!",
		[
			{"label": "C (Middle C)", "detail": "On a ledger line above the bass staff"},
			{"label": "B", "detail": "In the space just above the top line"},
			{"label": "A", "detail": "On the top line of the staff"},
			{"label": "G", "detail": "In the top space, just below the A line"},
			{"label": "F", "detail": "On the fourth line — where the bass clef dots are!"},
		]
	))

	return LMD.create_module(
		"bass_part1",
		"Bass Notes — Part 1",
		"Learn Middle C, B, A, G, and F",
		"",
		steps,
		12,
		"Bass Beginner"
	)
