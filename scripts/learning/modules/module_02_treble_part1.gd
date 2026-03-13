extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Your First Treble Notes!",
		"Let's learn your first treble notes! We'll start with Middle C and go up to G.",
		"Treble Notes — Part 1"
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP A — C4 solo (1+2+2 pattern: the "1")
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce C4
	steps.append(LMD.create_visual_step(
		"Middle C",
		"Middle C is special — it sits on its own extra little line just below the staff. This extra line is called a ledger line. It's like adding a tiny step for notes that don't fit on the five main lines!",
		"note_on_staff",
		{"clef": "treble", "note_name": "C", "note_step": 10}
	))

	# Drag: place C4 on the staff (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the ledger line below the staff!",
		"treble", "C4", 10, true,
		"That's Middle C! Right on the ledger line.",
		"Middle C sits on its own little ledger line just below the staff."
	))

	# Identify: find C4 among distractors
	steps.append(LMD.create_note_identify_step(
		"treble", "C4", 10, [8, 6],
		"Find Middle C among these notes!",
		"Look for the note on the ledger line below the staff — that's C!"
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP B — D4 + E4 (first pair of the "2+2")
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce D4
	steps.append(LMD.create_visual_step(
		"The Note D",
		"D sits in the space just below the bottom line.",
		"note_on_staff",
		{"clef": "treble", "note_name": "D", "note_step": 9}
	))

	# Visual: introduce E4
	steps.append(LMD.create_visual_step(
		"The Note E",
		"E sits right on the bottom line of the staff.",
		"note_on_staff",
		{"clef": "treble", "note_name": "E", "note_step": 8}
	))

	# Drag: D4 (hint on — first time placing D)
	steps.append(LMD.create_drag_note_step(
		"Drag D to the space just below the bottom line!",
		"treble", "D4", 9, true,
		"That's D! Right in the space below the staff.",
		"D hangs in the space just below the bottom line."
	))

	# Drag: E4 (no hint — progressive difficulty)
	steps.append(LMD.create_drag_note_step(
		"Now place E on the staff!",
		"treble", "E4", 8, false,
		"Right! E is on the bottom line!",
		"E sits right on the very bottom line of the staff."
	))

	# Quiz: name D4
	steps.append(LMD.create_note_quiz_step(
		"treble", "D4", 9,
		["C", "D", "E", "F"],
		1,
		"Yes! D is in the space just below the staff.",
		"This note hangs in the space below the bottom line — that's D!"
	))

	# Quiz: name E4
	steps.append(LMD.create_note_quiz_step(
		"treble", "E4", 8,
		["C", "D", "E", "F"],
		2,
		"Right! E is on the bottom line!",
		"This note sits on the very bottom line of the staff — that's E!"
	))

	# Listen & Find: D4 target, distractors E4 + C4
	steps.append(LMD.create_listen_find_step(
		"treble", "D4", 9, [8, 10],
		"Great ear! That was D.",
		"Listen again — D is the note between C and E."
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP C — F4 + G4 (second pair of the "2+2")
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce F4
	steps.append(LMD.create_visual_step(
		"The Note F",
		"F is in the first space of the staff.",
		"note_on_staff",
		{"clef": "treble", "note_name": "F", "note_step": 7}
	))

	# Visual: introduce G4
	steps.append(LMD.create_visual_step(
		"The Note G",
		"G sits on the second line.",
		"note_on_staff",
		{"clef": "treble", "note_name": "G", "note_step": 6}
	))

	# Drag: F4 (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag F into the first space of the staff!",
		"treble", "F4", 7, true,
		"That's F — right in the first space!",
		"F goes in the first space, just above the bottom line."
	))

	# Drag: G4 (no hint)
	steps.append(LMD.create_drag_note_step(
		"Place G on the staff!",
		"treble", "G4", 6, false,
		"You got it! G is on the second line!",
		"G sits on the second line from the bottom."
	))

	# Quiz: name F4
	steps.append(LMD.create_note_quiz_step(
		"treble", "F4", 7,
		["D", "E", "F", "G"],
		2,
		"That's F — in the first space!",
		"This note is in the first space above the bottom line — that's F!"
	))

	# Quiz: name G4
	steps.append(LMD.create_note_quiz_step(
		"treble", "G4", 6,
		["E", "F", "G", "A"],
		2,
		"You got it! G is on the second line!",
		"This note is on the second line from the bottom — that's G!"
	))

	# Listen & Find: F4 target, distractors G4 + E4
	steps.append(LMD.create_listen_find_step(
		"treble", "F4", 7, [6, 8],
		"Nice! That was F.",
		"Listen again — F is between E and G."
	))

	# ══════════════════════════════════════════════════════════════════════
	# CONSOLIDATION
	# ══════════════════════════════════════════════════════════════════════

	# Recap: all 5 notes
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are your first five treble notes:",
		[
			{"label": "C (Middle C)", "detail": "On its own ledger line below the staff", "clef": "treble"},
			{"label": "D", "detail": "In the space just below the bottom line", "clef": "treble"},
			{"label": "E", "detail": "On the bottom line of the staff", "clef": "treble"},
			{"label": "F", "detail": "In the first space above the bottom line", "clef": "treble"},
			{"label": "G", "detail": "On the second line — where the treble clef curls", "clef": "treble"},
		]
	))

	# Melody Example: C4 up to G4 and back
	steps.append(LMD.create_melody_example_step(
		"Your First Melody!",
		"You can read notes now! Here's a simple melody using the notes you just learned. Listen and follow along!",
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

	# Practice Round
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Time to practice! Name as many notes as you can. They'll appear on the treble staff — you've got this!",
		LMD.treble_note_pool_basic(),
		8
	))

	# Cumulative Quiz
	steps.append(LMD.create_cumulative_quiz_step(
		"Note Review",
		"Final review! Name these treble clef notes.",
		LMD.treble_note_pool_basic(),
		5
	))

	# Final Recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Fantastic! You've learned your first five notes in the treble clef!",
		[
			{"label": "C (Middle C)", "detail": "Below the staff on its own ledger line"},
			{"label": "D", "detail": "In the space just below the bottom line"},
			{"label": "E", "detail": "On the bottom line of the staff"},
			{"label": "F", "detail": "In the first space above the bottom line"},
			{"label": "G", "detail": "On the second line — where the treble clef curls"},
		]
	))

	return LMD.create_module(
		"treble_part1",
		"Treble Notes — Part 1",
		"Learn Middle C, D, E, F, and G",
		"",
		steps,
		12,
		"First Notes"
	)
