extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Your First Treble Notes!",
		"Let's learn your first treble notes! We'll start with Middle C, then D, and E.",
		"Treble Notes — Part 1A"
	))

	# ══════════════════════════════════════════════════════════════════════
	# NOTE 1 — C4 (Middle C)
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce C4
	steps.append(LMD.create_visual_step(
		"Meet Middle C!",
		"Middle C is special — it sits on its own extra little line just below the staff. This extra line is called a ledger line. It's like adding a tiny step for notes that don't fit on the five main lines!",
		"note_on_staff",
		{"clef": "treble", "note_name": "C", "note_step": 10}
	))

	# Exercise 1: Drag C4 (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the ledger line below the staff!",
		"treble", "C4", 10, true,
		"That's Middle C! Right on the ledger line.",
		"Middle C sits on its own little ledger line just below the staff."
	))

	# Exercise 2: Identify C4
	steps.append(LMD.create_note_identify_step(
		"treble", "C4", 10, [8, 9],
		"Find Middle C among these notes!",
		"Look for the note on the ledger line below the staff — that's C!"
	))

	# Exercise 3: Quiz C4
	steps.append(LMD.create_note_quiz_step(
		"treble", "C4", 10,
		["A", "B", "C", "D"],
		2,
		"Yes! That's Middle C on its ledger line!",
		"This note sits on the ledger line just below the staff — that's C!"
	))

	# ══════════════════════════════════════════════════════════════════════
	# NOTE 2 — D4
	# ══════════════════════════════════════════════════════════════════════

	# Transition: new note announcement
	steps.append(LMD.create_visual_step(
		"Time for a New Note — D!",
		"D sits in the space just below the bottom line. It's right next to Middle C — just one step higher!",
		"note_on_staff",
		{"clef": "treble", "note_name": "D", "note_step": 9}
	))

	# Exercise 1: Drag D4 (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag D to the space just below the bottom line!",
		"treble", "D4", 9, true,
		"That's D! Right in the space below the staff.",
		"D hangs in the space just below the bottom line."
	))

	# Exercise 2: Quiz D4
	steps.append(LMD.create_note_quiz_step(
		"treble", "D4", 9,
		["C", "D", "E", "F"],
		1,
		"Yes! D is in the space just below the staff.",
		"This note hangs in the space below the bottom line — that's D!"
	))

	# Exercise 3: Identify D4 (distractors: C4 and E4)
	steps.append(LMD.create_note_identify_step(
		"treble", "D4", 9, [10, 8],
		"Find D among these notes!",
		"D is in the space just below the bottom line — between the ledger line and the first line."
	))

	# Exercise 4: Listen & Find D4
	steps.append(LMD.create_listen_find_step(
		"treble", "D4", 9, [10, 8],
		"Great ear! That was D.",
		"Listen again — D is the note between C and E."
	))

	# ══════════════════════════════════════════════════════════════════════
	# NOTE 3 — E4
	# ══════════════════════════════════════════════════════════════════════

	# Transition: new note announcement
	steps.append(LMD.create_visual_step(
		"Time for a New Note — E!",
		"E sits right on the bottom line of the staff. It's the first note that actually sits ON a staff line!",
		"note_on_staff",
		{"clef": "treble", "note_name": "E", "note_step": 8}
	))

	# Exercise 1: Drag E4 (hint on — first time)
	steps.append(LMD.create_drag_note_step(
		"Drag E onto the bottom line of the staff!",
		"treble", "E4", 8, true,
		"Right! E is on the bottom line!",
		"E sits right on the very bottom line of the staff."
	))

	# Exercise 2: Quiz E4
	steps.append(LMD.create_note_quiz_step(
		"treble", "E4", 8,
		["C", "D", "E", "F"],
		2,
		"Right! E is on the bottom line!",
		"This note sits on the very bottom line of the staff — that's E!"
	))

	# Exercise 3: Identify E4 (distractors: C4 and D4)
	steps.append(LMD.create_note_identify_step(
		"treble", "E4", 8, [10, 9],
		"Find E among these notes!",
		"E is on the bottom line of the staff — the first line note you've learned!"
	))

	# Exercise 4: Listen & Find E4
	steps.append(LMD.create_listen_find_step(
		"treble", "E4", 8, [10, 9],
		"Nice! That was E.",
		"Listen again — E is the note that sits on the bottom line."
	))

	# ══════════════════════════════════════════════════════════════════════
	# CONSOLIDATION
	# ══════════════════════════════════════════════════════════════════════

	# Recap: C, D, E
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are your first three treble notes:",
		[
			{"label": "C (Middle C)", "detail": "On its own ledger line below the staff", "clef": "treble", "note_step": 10},
			{"label": "D", "detail": "In the space just below the bottom line", "clef": "treble", "note_step": 9},
			{"label": "E", "detail": "On the bottom line of the staff", "clef": "treble", "note_step": 8},
		]
	))

	# Melody Example: C-D-E mini melody
	steps.append(LMD.create_melody_example_step(
		"Three Note Melody",
		"Listen to a simple melody using the three notes you just learned!",
		"treble",
		[
			{"note_id": "C4", "note_step": 10, "beats": 1.0},
			{"note_id": "D4", "note_step": 9, "beats": 1.0},
			{"note_id": "E4", "note_step": 8, "beats": 2.0},
			{"note_id": "D4", "note_step": 9, "beats": 1.0},
			{"note_id": "C4", "note_step": 10, "beats": 2.0},
		],
		"C-D-E Song"
	))

	# Practice Round — C, D, E only
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's practice these three notes! Name each note as it appears on the staff.",
		LMD.treble_note_pool_part1a(),
		6
	))

	# Cumulative Quiz
	steps.append(LMD.create_cumulative_quiz_step(
		"Note Review",
		"Final review! Name these treble clef notes.",
		LMD.treble_note_pool_part1a(),
		4
	))

	# Final Recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Great work! You've learned three treble notes — Middle C, D, and E!",
		[
			{"label": "C (Middle C)", "detail": "Below the staff on its own ledger line", "clef": "treble", "note_step": 10},
			{"label": "D", "detail": "In the space just below the bottom line", "clef": "treble", "note_step": 9},
			{"label": "E", "detail": "On the bottom line of the staff", "clef": "treble", "note_step": 8},
		]
	))

	return LMD.create_module(
		"treble_part1a",
		"Treble Notes — Part 1A",
		"Learn Middle C, D, and E",
		"",
		steps,
		8,
		"First Notes"
	)
