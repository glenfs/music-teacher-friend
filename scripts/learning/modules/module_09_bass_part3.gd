extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"Lower Bass Notes!",
		"Let's learn the lower bass notes! These sit near the bottom of the staff.",
		"Bass Notes — Part 3"
	))

	# ════════════════════════════════════════════════════════════════════
	# 2. Group A — B2 solo (step 6, second line)
	# ════════════════════════════════════════════════════════════════════

	# Visual: introduce B2
	steps.append(LMD.create_visual_step(
		"The Note B",
		"B2 sits on the second line from the bottom.",
		"note_on_staff",
		{"clef": "bass", "note_name": "B", "note_step": 6}
	))

	# Drag: place B2 (hint on — first note)
	steps.append(LMD.create_drag_note_step(
		"Drag B2 onto the second line!",
		"bass", "B2", 6, true,
		"Perfect! B2 on the second line.",
		"That line is the second from the bottom — try B!"
	))

	# Identify: find B2 among distractors
	steps.append(LMD.create_note_identify_step(
		"bass", "B2", 6, [4, 8],
		"That's B2! Great eye!",
		"Look for the note on the second line — that's B2."
	))

	# ════════════════════════════════════════════════════════════════════
	# 3. Group B — A2 + G2 pair (steps 7 and 8)
	# ════════════════════════════════════════════════════════════════════

	# Visual: introduce A2
	steps.append(LMD.create_visual_step(
		"The Note A",
		"A2 is in the first space from the bottom.",
		"note_on_staff",
		{"clef": "bass", "note_name": "A", "note_step": 7}
	))

	# Visual: introduce G2
	steps.append(LMD.create_visual_step(
		"The Note G",
		"G2 sits on the very bottom line!",
		"note_on_staff",
		{"clef": "bass", "note_name": "G", "note_step": 8}
	))

	# Drag: place A2 (hint on — first of pair)
	steps.append(LMD.create_drag_note_step(
		"Drag A2 into the first space!",
		"bass", "A2", 7, true,
		"Nice! A2 in the first space.",
		"The first space is just above the bottom line — that's A!"
	))

	# Drag: place G2 (no hint — progressive difficulty)
	steps.append(LMD.create_drag_note_step(
		"Now place G2 on the staff!",
		"bass", "G2", 8, false,
		"Right! G2 on the bottom line.",
		"G2 sits on the very bottom line of the staff."
	))

	# Quiz: name A2
	steps.append(LMD.create_note_quiz_step(
		"bass", "A2", 7,
		["A", "B", "C", "D", "E", "F", "G"],
		0,
		"Yes! A2 is in the first space!",
		"This note sits in the first space from the bottom — that's A!"
	))

	# Quiz: name G2
	steps.append(LMD.create_note_quiz_step(
		"bass", "G2", 8,
		["A", "B", "C", "D", "E", "F", "G"],
		6,
		"Right! G2 is on the bottom line!",
		"This note sits on the very bottom line of the staff — that's G!"
	))

	# Listen & find: G2 by ear
	steps.append(LMD.create_listen_find_step(
		"bass", "G2", 8, [7, 6],
		"You found G2 by ear! Well done!",
		"Listen carefully — G2 is on the bottom line."
	))

	# ════════════════════════════════════════════════════════════════════
	# 4. Group C — F2 solo (step 9, below staff — hardest)
	# ════════════════════════════════════════════════════════════════════

	# Visual: introduce F2
	steps.append(LMD.create_visual_step(
		"The Note F",
		"F2 is on a ledger line below the bass staff.",
		"note_on_staff",
		{"clef": "bass", "note_name": "F", "note_step": 9}
	))

	# Drag: place F2 (no hint — hardest position)
	steps.append(LMD.create_drag_note_step(
		"Place F2 below the staff!",
		"bass", "F2", 9, false,
		"You got it! F2 below the staff.",
		"F2 sits on a ledger line below the bottom line."
	))

	# Quiz: name F2
	steps.append(LMD.create_note_quiz_step(
		"bass", "F2", 9,
		["A", "B", "C", "D", "E", "F", "G"],
		5,
		"You got it! F2 is below the staff!",
		"This note hangs below the bottom line — that's F!"
	))

	# ════════════════════════════════════════════════════════════════════
	# 5. Consolidation
	# ════════════════════════════════════════════════════════════════════

	# Recap: all four notes
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are the lower bass notes you just learned:",
		[
			{"label": "B2", "detail": "On the second line from the bottom", "clef": "bass", "note_step": 6},
			{"label": "A2", "detail": "In the first space from the bottom", "clef": "bass", "note_step": 7},
			{"label": "G2", "detail": "On the bottom line", "clef": "bass", "note_step": 8},
			{"label": "F2", "detail": "Below the staff on a ledger line", "clef": "bass", "note_step": 9},
		]
	))

	# Melody example — full bass range
	steps.append(LMD.create_melody_example_step(
		"Deep Bass Melody",
		"From high to low — the full bass range you've mastered!",
		"bass",
		[
			{"note_id": "C4", "note_step": -2, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 1.0},
			{"note_id": "F3", "note_step": 2, "beats": 1.0},
			{"note_id": "D3", "note_step": 4, "beats": 1.0},
			{"note_id": "B2", "note_step": 6, "beats": 1.0},
			{"note_id": "A2", "note_step": 7, "beats": 1.0},
			{"note_id": "F2", "note_step": 9, "beats": 2.0},
			{"note_id": "C4", "note_step": -2, "beats": 2.0},
		],
		"Deep Bass Melody"
	))

	# Practice round — full bass range
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Name notes across the entire bass staff — from C4 all the way down to F2!",
		LMD.bass_note_pool_full(),
		10
	))

	# Cumulative quiz — full bass range
	steps.append(LMD.create_cumulative_quiz_step(
		"Full Bass Challenge!",
		"Can you name notes from the FULL bass range?",
		LMD.bass_note_pool_full(),
		5
	))

	# Final recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've mastered the entire bass staff! From C4 down to F2!",
		[
			{"label": "B2, A2, G2, F2", "detail": "The deep bass notes you just learned"},
			{"label": "Full range: C4–F2", "detail": "You can now read 12 notes on the bass staff!"},
		]
	))

	return LMD.create_module(
		"bass_part3",
		"Bass Notes — Part 3",
		"Learn B2, A2, G2, and F2",
		"",
		steps,
		12,
		"Bass Master"
	)
