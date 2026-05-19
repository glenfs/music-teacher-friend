extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Two More Treble Notes!",
		"You already know C, D, and E — now let's add F and G to complete your first five treble notes!",
		"Treble Notes — Part 1B"
	))

	# ══════════════════════════════════════════════════════════════════════
	# NOTE 1 — F4
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce F4
	steps.append(LMD.create_visual_step(
		"Meet the Note F!",
		"F is in the first space of the staff — just above the bottom line where E sits.",
		"note_on_staff",
		{"clef": "treble", "note_name": "F", "note_step": 7}
	))

	# Exercise 1: Drag F4 (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag F into the first space of the staff!",
		"treble", "F4", 7, true,
		"That's F — right in the first space!",
		"F goes in the first space, just above the bottom line."
	))

	# Exercise 2: Quiz F4
	steps.append(LMD.create_note_quiz_step(
		"treble", "F4", 7,
		["D", "E", "F", "G"],
		2,
		"That's F — in the first space!",
		"This note is in the first space above the bottom line — that's F!"
	))

	# Exercise 3: Identify F4 (distractors: E4 and G4)
	steps.append(LMD.create_note_identify_step(
		"treble", "F4", 7, [8, 6],
		"Find F among these notes!",
		"F is in the first space — between E on the bottom line and G on the second line."
	))

	# Exercise 4: Listen & Find F4
	steps.append(LMD.create_listen_find_step(
		"treble", "F4", 7, [8, 6],
		"Nice! That was F.",
		"Listen again — F is between E and G."
	))

	# ══════════════════════════════════════════════════════════════════════
	# NOTE 2 — G4
	# ══════════════════════════════════════════════════════════════════════

	# Transition: new note announcement
	steps.append(LMD.create_visual_step(
		"Time for a New Note — G!",
		"G sits on the second line of the staff. Fun fact: the treble clef is sometimes called the 'G clef' because it curls right around this line!",
		"note_on_staff",
		{"clef": "treble", "note_name": "G", "note_step": 6}
	))

	# Exercise 1: Drag G4 (hint on — first time)
	steps.append(LMD.create_drag_note_step(
		"Drag G onto the second line of the staff!",
		"treble", "G4", 6, true,
		"You got it! G is on the second line!",
		"G sits on the second line — where the treble clef curls."
	))

	# Exercise 2: Quiz G4
	steps.append(LMD.create_note_quiz_step(
		"treble", "G4", 6,
		["E", "F", "G", "A"],
		2,
		"You got it! G is on the second line!",
		"This note is on the second line from the bottom — that's G!"
	))

	# Exercise 3: Identify G4 (distractors: F4 and E4)
	steps.append(LMD.create_note_identify_step(
		"treble", "G4", 6, [7, 8],
		"Find G among these notes!",
		"G is on the second line — where the treble clef curls around."
	))

	# Exercise 4: Listen & Find G4
	steps.append(LMD.create_listen_find_step(
		"treble", "G4", 6, [7, 8],
		"Great ear! That was G.",
		"Listen again — G is the note on the second line."
	))

	# ══════════════════════════════════════════════════════════════════════
	# CONSOLIDATION (includes Part 1A notes!)
	# ══════════════════════════════════════════════════════════════════════

	# Recap: all 5 notes
	steps.append(LMD.create_recap_step(
		"All Five Notes!",
		"Here are all five treble notes you've learned so far:",
		[
			{"label": "C (Middle C)", "detail": "On its own ledger line below the staff", "clef": "treble", "note_step": 10},
			{"label": "D", "detail": "In the space just below the bottom line", "clef": "treble", "note_step": 9},
			{"label": "E", "detail": "On the bottom line of the staff", "clef": "treble", "note_step": 8},
			{"label": "F", "detail": "In the first space above the bottom line", "clef": "treble", "note_step": 7},
			{"label": "G", "detail": "On the second line — where the treble clef curls", "clef": "treble", "note_step": 6},
		]
	))

	# Melody Example: C4 up to G4 and back (all 5 notes)
	steps.append(LMD.create_melody_example_step(
		"Your First Scale!",
		"You can read five notes now! Here's a melody using all of them. Listen and follow along!",
		"treble",
		[
			{"note_id": "C4", "note_step": 10, "beats": 1.0},
			{"note_id": "D4", "note_step": 9, "beats": 1.0},
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "F4", "note_step": 7, "beats": 1.0},
			{"note_id": "G4", "note_step": 6, "beats": 2.0},
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "C4", "note_step": 10, "beats": 2.0},
		],
		"Simple Scale Song"
	))

	# Practice Round — all 5 notes (C, D, E from Part 1A + F, G)
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Time to practice all five notes! They'll appear on the treble staff — you've got this!",
		LMD.treble_note_pool_basic(),
		8
	))

	# Cumulative Quiz — all 5 notes
	steps.append(LMD.create_cumulative_quiz_step(
		"Note Review",
		"Final review! Name these treble clef notes — including C, D, and E from Part 1A.",
		LMD.treble_note_pool_basic(),
		8
	))

	# Final Recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Fantastic! You now know all five of your first treble notes — C, D, E, F, and G!",
		[
			{"label": "C (Middle C)", "detail": "Below the staff on its own ledger line", "clef": "treble", "note_step": 10},
			{"label": "D", "detail": "In the space just below the bottom line", "clef": "treble", "note_step": 9},
			{"label": "E", "detail": "On the bottom line of the staff", "clef": "treble", "note_step": 8},
			{"label": "F", "detail": "In the first space above the bottom line", "clef": "treble", "note_step": 7},
			{"label": "G", "detail": "On the second line — where the treble clef curls", "clef": "treble", "note_step": 6},
		]
	))

	return LMD.create_module(
		"treble_part1b",
		"Treble Notes — Part 1B",
		"Learn F and G, plus review C, D, E",
		"",
		steps,
		8,
		"Five Notes"
	)
