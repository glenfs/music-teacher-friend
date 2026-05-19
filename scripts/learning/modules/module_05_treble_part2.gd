extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")

# Treble: step 0=F5(top), 1=E5, 2=D5, 3=C5, 4=B4(middle), 5=A4, 6=G4, 7=F4, 8=E4(bottom)
# Lines (even steps): E4(8), G4(6), B4(4), D5(2), F5(0) — "Every Good Boy Does Fine"
# Spaces (odd steps): F4(7), A4(5), C5(3), E5(1) — "FACE"


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# 1 — Intro
	steps.append(LMD.create_intro_step(
		"The Full Treble Staff!",
		"Time to learn ALL the treble staff notes! Let's start with how lines and spaces work.",
		"Treble Notes — Part 2"
	))

	# 2 — Visual: staff lines
	steps.append(LMD.create_visual_step(
		"The Five Lines",
		"The staff has 5 lines. Watch them appear!",
		"staff_lines_intro",
		{"clef": "treble"}
	))

	# 3 — Visual: staff spaces
	steps.append(LMD.create_visual_step(
		"The Four Spaces",
		"Between those 5 lines, there are 4 spaces!",
		"staff_spaces_intro",
		{"clef": "treble"}
	))

	# 4 — Explanation: line notes
	steps.append(LMD.create_explanation_step(
		"Line Notes: E G B D F",
		"The notes on the five lines, from bottom to top, are E, G, B, D, and F.",
		"E  G  B  D  F",
		"Every Good Boy Does Fine — a classic way to remember the treble line notes!"
	))

	# 5 — Visual: notes on lines
	steps.append(LMD.create_visual_step(
		"Line Notes on the Staff",
		"Here are the line notes on the staff. Each one sits directly on a line.",
		"notes_on_lines",
		{"clef": "treble", "notes": ["E", "G", "B", "D", "F"]}
	))

	# 6 — Explanation: space notes
	steps.append(LMD.create_explanation_step(
		"Space Notes: F A C E",
		"The notes in the four spaces, from bottom to top, spell a word: FACE!",
		"F  A  C  E",
		"The spaces spell FACE — easy to remember!"
	))

	# 7 — Visual: notes in spaces
	steps.append(LMD.create_visual_step(
		"Space Notes on the Staff",
		"Here are the space notes. Each one sits between two lines.",
		"notes_in_spaces",
		{"clef": "treble", "notes": ["F", "A", "C", "E"]}
	))

	# 8 — Drag: E on bottom line (step 8, hint)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the bottom line — that's E!",
		"treble", "E", 8, true,
		"Nice! E is on the bottom line.",
		"Look for the hint on the bottom line — that's where E goes!"
	))

	# 9 — Drag: B on middle line (step 4, hint)
	steps.append(LMD.create_drag_note_step(
		"Now find the middle line. That's B!",
		"treble", "B", 4, true,
		"That's right! B sits on the middle line.",
		"The middle line is B — check the hint!"
	))

	# 10 — Drag: F on top line (step 0, hint)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the top line — that's F!",
		"treble", "F", 0, true,
		"Perfect! F is on the very top line.",
		"The top line is F — look for the hint up there!"
	))

	# 11 — Drag: A in second space (step 5, hint)
	steps.append(LMD.create_drag_note_step(
		"Try a space note! Find the second space from the bottom — that's A.",
		"treble", "A", 5, true,
		"Great! A is in the second space.",
		"A is the second letter of FACE — second space from the bottom!"
	))

	# 12 — Drag: D on fourth line (step 2, no hint)
	steps.append(LMD.create_drag_note_step(
		"Where does D go? No hint this time!",
		"treble", "D", 2, false,
		"You nailed it! D is on the fourth line.",
		"D is the fourth note in Every Good Boy Does Fine — the fourth line!"
	))

	# ── Group A: A4 solo ──

	# 13 — Explanation: Three More Notes
	steps.append(LMD.create_explanation_step(
		"Three More Notes!",
		"Now let's add three new notes above G: A, B, and C5!",
		"A4,  B4,  C5",
		"We'll learn them one at a time, then combine them."
	))

	# 14 — Visual: A4 (step 5)
	steps.append(LMD.create_visual_step(
		"The Note A4",
		"A sits in the second space — between G and B.",
		"note_on_staff",
		{"clef": "treble", "note_name": "A", "note_step": 5}
	))

	# 15 — Drag: A4 (step 5, hint)
	steps.append(LMD.create_drag_note_step(
		"Place A in the second space!",
		"treble", "A", 5, true,
		"Great! A is in the second space.",
		"A goes in the second space from the bottom — between G and B!"
	))

	# 16 — Note Identify: A4
	steps.append(LMD.create_note_identify_step(
		"treble", "A4", 5, [3, 7],
		"That's A4 — in the second space!",
		"Look for the note in the second space from the bottom — that's A!"
	))

	# ── Group B: B4 + C5 ──

	# 17 — Visual: B4 (step 4)
	steps.append(LMD.create_visual_step(
		"The Note B4",
		"B sits right on the middle line of the staff.",
		"note_on_staff",
		{"clef": "treble", "note_name": "B", "note_step": 4}
	))

	# 18 — Visual: C5 (step 3)
	steps.append(LMD.create_visual_step(
		"The Note C5",
		"C5 is in the third space — one octave above Middle C!",
		"note_on_staff",
		{"clef": "treble", "note_name": "C", "note_step": 3}
	))

	# 19 — Drag: B4 (step 4, hint)
	steps.append(LMD.create_drag_note_step(
		"Place B on the middle line!",
		"treble", "B", 4, true,
		"That's right! B sits on the middle line.",
		"B goes on the middle line — the third line from the bottom!"
	))

	# 20 — Drag: C5 (step 3, no hint)
	steps.append(LMD.create_drag_note_step(
		"Now place C5 — no hint this time!",
		"treble", "C", 3, false,
		"Perfect! C5 is in the third space.",
		"C5 goes in the third space — just above B on the middle line!"
	))

	# 21 — Note Quiz: B4
	steps.append(LMD.create_note_quiz_step(
		"treble", "B4", 4,
		["A", "B", "C", "D", "E"],
		1,
		"Correct! B4 is right on the middle line.",
		"This note sits on the middle line — the third line from the bottom. That's B!"
	))

	# 22 — Note Quiz: C5
	steps.append(LMD.create_note_quiz_step(
		"treble", "C5", 3,
		["A", "B", "C", "D", "E"],
		2,
		"You got it! C5 is in the third space.",
		"This note is in the third space — just above B on the middle line. That's C!"
	))

	# 23 — Listen & Find: B4
	steps.append(LMD.create_listen_find_step(
		"treble", "B4", 4, [3, 5],
		"That's B4! You found it by ear.",
		"Listen carefully — B4 is on the middle line of the staff."
	))

	# ── Consolidation ──

	# 24 — Recap
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here's what we covered:",
		[
			{"label": "Line Notes", "detail": "E G B D F — Every Good Boy Does Fine", "clef": "treble"},
			{"label": "Space Notes", "detail": "F A C E — the spaces spell FACE", "clef": "treble"},
			{"label": "A4", "detail": "Second space from the bottom", "clef": "treble", "note_step": 5},
			{"label": "B4", "detail": "On the middle line", "clef": "treble", "note_step": 4},
			{"label": "C5", "detail": "In the third space", "clef": "treble", "note_step": 3},
		]
	))

	# ── Melody Example ──
	steps.append(LMD.create_melody_example_step(
		"Play a Melody!",
		"Here's a melody that uses all the treble notes you know! Follow along on the staff.",
		"treble",
		[
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "G4", "note_step": 6, "beats": 1.0},
			{"note_id": "A4", "note_step": 5, "beats": 1.0},
			{"note_id": "G4", "note_step": 6, "beats": 2.0},
			{"note_id": "F4", "note_step": 7, "beats": 1.0},
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "D4", "note_step": 9, "beats": 1.0},
			{"note_id": "C4", "note_step": 10, "beats": 2.0},
		],
		"Treble Explorer Tune"
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Name all the treble notes! This covers everything from C4 up to C5.",
		LMD.treble_note_pool_part2(),
		10
	))

	# Cumulative Review — all treble notes C4-C5
	steps.append(LMD.create_cumulative_quiz_step(
		"Treble Review Challenge!",
		"Let's see how well you know ALL your treble notes so far!",
		LMD.treble_note_pool_part2(),
		5
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Amazing! You know all the notes on the treble staff from C4 to C5!",
		[
			{"label": "EGBDF", "detail": "Line notes — Every Good Boy Does Fine"},
			{"label": "FACE", "detail": "Space notes — F, A, C, E"},
			{"label": "A4, B4, C5", "detail": "The upper notes you learned today"},
		]
	))

	return LMD.create_module(
		"treble_part2",
		"Treble Notes — Part 2",
		"Learn EGBDF, FACE, and notes A4 through C5",
		"",
		steps,
		14,
		"Treble Explorer"
	)
