extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Your First Bass Notes!",
		"Now let's learn your first bass notes! We'll start from Middle C and go down.",
		"Bass Notes — Part 1A"
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP A — C4 solo
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
	# GROUP B — B3 + A3
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

	# Listen & Find: A3 target, distractors B3 + C4
	steps.append(LMD.create_listen_find_step(
		"bass", "A3", 0, [-1, -2],
		"Great ear! That was A.",
		"Listen again — A is the note on the top line of the staff."
	))

	# ══════════════════════════════════════════════════════════════════════
	# CONSOLIDATION
	# ══════════════════════════════════════════════════════════════════════

	# Recap: C, B, A
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are your first three bass notes:",
		[
			{"label": "C (Middle C)", "detail": "On its own ledger line above the staff", "clef": "bass"},
			{"label": "B", "detail": "In the space just above the top line", "clef": "bass"},
			{"label": "A", "detail": "On the top line of the staff", "clef": "bass"},
		]
	))

	# Melody Example: C4 down to A3 and back
	steps.append(LMD.create_melody_example_step(
		"Three Bass Notes",
		"Listen to your first three bass notes going down and back up!",
		"bass",
		[
			{"note_id": "C4", "note_step": -2, "beats": 1.0},
			{"note_id": "B3", "note_step": -1, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 2.0},
			{"note_id": "B3", "note_step": -1, "beats": 1.0},
			{"note_id": "C4", "note_step": -2, "beats": 2.0},
		],
		"C-B-A Melody"
	))

	# Practice Round — only C, B, A
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's practice these three bass notes! Name each note as it appears.",
		LMD.bass_note_pool_part1a(),
		6
	))

	# Cumulative Quiz
	steps.append(LMD.create_cumulative_quiz_step(
		"Note Review",
		"Final review! Name these bass clef notes.",
		LMD.bass_note_pool_part1a(),
		4
	))

	# Final Recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Great work! You've learned three bass clef notes — Middle C, B, and A!",
		[
			{"label": "C (Middle C)", "detail": "On a ledger line above the bass staff"},
			{"label": "B", "detail": "In the space just above the top line"},
			{"label": "A", "detail": "On the top line of the staff"},
		]
	))

	return LMD.create_module(
		"bass_part1a",
		"Bass Notes — Part 1A",
		"Learn Middle C, B, and A in bass clef",
		"",
		steps,
		7,
		"Bass Starter"
	)
