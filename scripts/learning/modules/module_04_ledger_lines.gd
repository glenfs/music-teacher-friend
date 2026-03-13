extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")

# Treble ledger: step 10=C4(Middle C), 11=B3, 12=A3
# Bass ledger: step -2=C4(Middle C), -3=D4, -4=E4


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# 1 — Intro
	steps.append(LMD.create_intro_step(
		"Beyond the Staff!",
		"Sometimes notes go above or below the staff. That's where ledger lines help!",
		"Ledger Lines"
	))

	# 2 — Explanation
	steps.append(LMD.create_explanation_step(
		"What Are Ledger Lines?",
		"Ledger lines are small extra lines we add when notes go beyond the staff. Think of them as tiny extensions!",
		"Extra Lines for Extra Notes",
		"Each ledger line works just like a regular staff line — notes sit on them or in the spaces between them."
	))

	# 3 — Visual: Middle C in treble (step 10)
	steps.append(LMD.create_visual_step(
		"Middle C — Treble",
		"You already know Middle C — it uses one ledger line below the treble staff.",
		"note_on_staff",
		{"clef": "treble", "note_name": "C", "note_step": 10}
	))

	# 4 — Visual: B3 in treble (step 11)
	steps.append(LMD.create_visual_step(
		"B3 Below the Staff",
		"B3 sits just below Middle C's ledger line, in the space.",
		"note_on_staff",
		{"clef": "treble", "note_name": "B", "note_step": 11}
	))

	# 5 — Visual: A3 in treble (step 12)
	steps.append(LMD.create_visual_step(
		"A3 — Two Ledger Lines",
		"A3 needs TWO ledger lines below the staff!",
		"note_on_staff",
		{"clef": "treble", "note_name": "A", "note_step": 12}
	))

	# 6 — Visual: Middle C in bass (step -2)
	steps.append(LMD.create_visual_step(
		"Middle C — Bass",
		"In bass clef, Middle C uses a ledger line above the staff.",
		"note_on_staff",
		{"clef": "bass", "note_name": "C", "note_step": -2}
	))

	# 7 — Visual: D4 in bass (step -3)
	steps.append(LMD.create_visual_step(
		"D4 Above the Staff",
		"D4 sits just above Middle C's ledger line.",
		"note_on_staff",
		{"clef": "bass", "note_name": "D", "note_step": -3}
	))

	# 8 — Visual: E4 in bass (step -4)
	steps.append(LMD.create_visual_step(
		"E4 — Two Ledger Lines",
		"E4 needs TWO ledger lines above the bass staff!",
		"note_on_staff",
		{"clef": "bass", "note_name": "E", "note_step": -4}
	))

	# 9 — Drag: B3 in treble (step 11, hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag B3 just below Middle C's ledger line!",
		"treble", "B3", 11, true,
		"Nice! B3 is in the space below Middle C.",
		"B3 sits in the space just below Middle C's ledger line."
	))

	# 10 — Drag: D4 in bass (step -3, hint on)
	steps.append(LMD.create_drag_note_step(
		"Now drag D4 above Middle C on the bass staff!",
		"bass", "D4", -3, true,
		"Perfect! D4 is just above Middle C in bass clef.",
		"D4 sits in the space just above Middle C's ledger line."
	))

	# 11 — Drag: A3 in treble (step 12, no hint)
	steps.append(LMD.create_drag_note_step(
		"Place A3 on the treble staff — no hint!",
		"treble", "A3", 12, false,
		"You got it! A3 on the second ledger line below.",
		"A3 needs two ledger lines below the treble staff."
	))

	# 12 — Drag: E4 in bass (step -4, no hint)
	steps.append(LMD.create_drag_note_step(
		"Place E4 on the bass staff — no hint!",
		"bass", "E4", -4, false,
		"Right! E4 on the second ledger line above.",
		"E4 needs two ledger lines above the bass staff."
	))

	# 13 — Recap
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here are the ledger line notes we learned:",
		[
			{"label": "B3 (Treble)", "detail": "Space below Middle C's ledger line", "clef": "treble"},
			{"label": "A3 (Treble)", "detail": "On a second ledger line below the staff", "clef": "treble"},
			{"label": "D4 (Bass)", "detail": "Space above Middle C's ledger line", "clef": "bass"},
			{"label": "E4 (Bass)", "detail": "On a second ledger line above the staff", "clef": "bass"},
		]
	))

	# 10 — Note quiz: B3 treble (step 11)
	steps.append(LMD.create_note_quiz_step(
		"treble", "B3", 11,
		["A", "B", "C", "D", "E"],
		1,
		"That's B3! It sits in the space below Middle C.",
		"This note is just below Middle C's ledger line — that's B!"
	))

	# 11 — Note quiz: A3 treble (step 12)
	steps.append(LMD.create_note_quiz_step(
		"treble", "A3", 12,
		["F", "G", "A", "B", "C"],
		2,
		"Correct! A3 is on the second ledger line below the staff.",
		"Count down from Middle C: C, B, A. This note needs two ledger lines — that's A!"
	))

	# 12 — Note quiz: D4 bass (step -3)
	steps.append(LMD.create_note_quiz_step(
		"bass", "D4", -3,
		["B", "C", "D", "E", "F"],
		2,
		"Yes! D4 is just above Middle C in bass clef.",
		"This note sits in the space above Middle C's ledger line — that's D!"
	))

	# 13 — Note quiz: E4 bass (step -4)
	steps.append(LMD.create_note_quiz_step(
		"bass", "E4", -4,
		["C", "D", "E", "F", "G"],
		2,
		"You got it! E4 is on the second ledger line above the bass staff.",
		"Count up from Middle C: C, D, E. This note needs two ledger lines — that's E!"
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's practice ledger line notes! These notes sit above or below the staff.",
		LMD.ledger_line_pool(),
		6
	))

	# ── Cumulative Quiz ──
	steps.append(LMD.create_cumulative_quiz_step(
		"Ledger Line Review",
		"Final review — name these ledger line notes!",
		LMD.ledger_line_pool(),
		4
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've mastered ledger lines! Notes can go beyond the staff now!",
		[
			{"label": "Ledger Lines", "detail": "Short extra lines above or below the staff for higher/lower notes"},
			{"label": "Middle C (Treble)", "detail": "One ledger line below the treble staff"},
			{"label": "B3, A3 (Treble)", "detail": "Ledger notes below the treble staff"},
			{"label": "D4, E4 (Bass)", "detail": "Ledger notes above the bass staff"},
		]
	))

	return LMD.create_module(
		"ledger_lines",
		"Ledger Lines",
		"Learn notes above and below the staff",
		"",
		steps,
		7,
		"Ledger Line Learner"
	)
