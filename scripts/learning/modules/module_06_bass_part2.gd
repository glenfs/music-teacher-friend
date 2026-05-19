extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")

# Bass: step 0=A3(top), 1=G3, 2=F3, 3=E3, 4=D3, 5=C3, 6=B2, 7=A2, 8=G2(bottom)
# Lines (even steps): A3(0), F3(2), D3(4), B2(6), G2(8) — "Good Boys Do Fine Always" bottom-up
# Spaces (odd steps): G3(1), E3(3), C3(5), A2(7) — "All Cows Eat Grass" bottom-up


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# 1 — Intro
	steps.append(LMD.create_intro_step(
		"The Full Bass Staff!",
		"Let's learn ALL the bass staff notes!",
		"Bass Notes — Part 2"
	))

	# 2 — Visual: staff lines
	steps.append(LMD.create_visual_step(
		"The Five Lines",
		"The bass staff also has 5 lines!",
		"staff_lines_intro",
		{"clef": "bass"}
	))

	# 3 — Visual: staff spaces
	steps.append(LMD.create_visual_step(
		"The Four Spaces",
		"And 4 spaces between the lines!",
		"staff_spaces_intro",
		{"clef": "bass"}
	))

	# 4 — Explanation: line notes
	steps.append(LMD.create_explanation_step(
		"Line Notes: G B D F A",
		"The notes on the five bass lines, from bottom to top, are G, B, D, F, and A.",
		"G  B  D  F  A",
		"Good Boys Do Fine Always — a handy way to remember the bass line notes!"
	))

	# 5 — Visual: notes on lines
	steps.append(LMD.create_visual_step(
		"Line Notes on the Staff",
		"Here are the bass line notes. Each one sits directly on a line.",
		"notes_on_lines",
		{"clef": "bass", "notes": ["G", "B", "D", "F", "A"]}
	))

	# 6 — Explanation: space notes
	steps.append(LMD.create_explanation_step(
		"Space Notes: A C E G",
		"The notes in the four bass spaces, from bottom to top, are A, C, E, and G.",
		"A  C  E  G",
		"All Cows Eat Grass — a fun way to remember the bass space notes!"
	))

	# 7 — Visual: notes in spaces
	steps.append(LMD.create_visual_step(
		"Space Notes on the Staff",
		"Here are the bass space notes. Each one sits between two lines.",
		"notes_in_spaces",
		{"clef": "bass", "notes": ["A", "C", "E", "G"]}
	))

	# 8 — Drag: G on bottom line (step 8, hint)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the bottom line — that's G!",
		"bass", "G", 8, true,
		"Nice! G is on the bottom line.",
		"Look for the hint on the bottom line — that's where G goes!"
	))

	# 9 — Drag: D on middle line (step 4, hint)
	steps.append(LMD.create_drag_note_step(
		"Now find the middle line. That's D!",
		"bass", "D", 4, true,
		"That's right! D sits on the middle line.",
		"The middle line is D — check the hint!"
	))

	# 10 — Drag: F on fourth line (step 2, hint)
	steps.append(LMD.create_drag_note_step(
		"Drag the note to the fourth line — where the bass clef dots are. That's F!",
		"bass", "F", 2, true,
		"Perfect! F is on the fourth line.",
		"The fourth line is F — right between the bass clef dots!"
	))

	# 11 — Drag: A in bottom space (step 7, hint)
	steps.append(LMD.create_drag_note_step(
		"Try a space note! Find the bottom space — that's A.",
		"bass", "A", 7, true,
		"Great! A is in the bottom space.",
		"A is the first letter of All Cows Eat Grass — the bottom space!"
	))

	# 12 — Drag: B on second line (step 6, no hint)
	steps.append(LMD.create_drag_note_step(
		"Where does B go? No hint this time!",
		"bass", "B", 6, false,
		"You nailed it! B is on the second line.",
		"B is the second note in Good Boys Do Fine Always — the second line!"
	))

	# ── Group A: E3 solo ──

	# 13 — Explanation: Three More Notes
	steps.append(LMD.create_explanation_step(
		"Three More Notes!",
		"Now let's learn three more notes going lower: E, D, and C3!",
		"E3,  D3,  C3",
		"We'll learn them one at a time, then combine them."
	))

	# 14 — Visual: E3 (step 3)
	steps.append(LMD.create_visual_step(
		"The Note E3",
		"E sits in the third space from the bottom.",
		"note_on_staff",
		{"clef": "bass", "note_name": "E", "note_step": 3}
	))

	# 15 — Drag: E3 (step 3, hint)
	steps.append(LMD.create_drag_note_step(
		"Place E in the third space!",
		"bass", "E", 3, true,
		"Great! E is in the third space.",
		"E goes in the third space from the bottom — between D and F!"
	))

	# 16 — Note Identify: E3
	steps.append(LMD.create_note_identify_step(
		"bass", "E3", 3, [1, 5],
		"That's E3 — in the third space!",
		"Look for the note in the third space from the bottom — that's E!"
	))

	# ── Group B: D3 + C3 ──

	# 17 — Visual: D3 (step 4)
	steps.append(LMD.create_visual_step(
		"The Note D3",
		"D sits right on the middle line.",
		"note_on_staff",
		{"clef": "bass", "note_name": "D", "note_step": 4}
	))

	# 18 — Visual: C3 (step 5)
	steps.append(LMD.create_visual_step(
		"The Note C3",
		"C3 is in the second space from the bottom — two octaves below Middle C!",
		"note_on_staff",
		{"clef": "bass", "note_name": "C", "note_step": 5}
	))

	# 19 — Drag: D3 (step 4, hint)
	steps.append(LMD.create_drag_note_step(
		"Place D on the middle line!",
		"bass", "D", 4, true,
		"That's right! D sits on the middle line.",
		"D goes on the middle line — the third line from the bottom!"
	))

	# 20 — Drag: C3 (step 5, no hint)
	steps.append(LMD.create_drag_note_step(
		"Now place C3 — no hint this time!",
		"bass", "C", 5, false,
		"Perfect! C3 is in the second space.",
		"C3 goes in the second space from the bottom!"
	))

	# 21 — Note Quiz: D3
	steps.append(LMD.create_note_quiz_step(
		"bass", "D3", 4,
		["A", "B", "C", "D", "E"],
		3,
		"Correct! D3 is right on the middle line.",
		"This note sits on the middle line — the third line from the bottom. That's D!"
	))

	# 22 — Note Quiz: C3
	steps.append(LMD.create_note_quiz_step(
		"bass", "C3", 5,
		["A", "B", "C", "D", "E"],
		2,
		"You got it! C3 is in the second space.",
		"This note is in the second space from the bottom. That's C!"
	))

	# 23 — Listen & Find: D3
	steps.append(LMD.create_listen_find_step(
		"bass", "D3", 4, [3, 5],
		"That's D3! You found it by ear.",
		"Listen carefully — D3 is on the middle line of the bass staff."
	))

	# ── Consolidation ──

	# 24 — Recap
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here's what we covered:",
		[
			{"label": "Line Notes", "detail": "G B D F A — Good Boys Do Fine Always", "clef": "bass"},
			{"label": "Space Notes", "detail": "A C E G — All Cows Eat Grass", "clef": "bass"},
			{"label": "E3", "detail": "In the third space from the bottom", "clef": "bass", "note_step": 3},
			{"label": "D3", "detail": "On the middle line", "clef": "bass", "note_step": 4},
			{"label": "C3", "detail": "In the second space from the bottom", "clef": "bass", "note_step": 5},
		]
	))

	# ── Melody Example ──
	steps.append(LMD.create_melody_example_step(
		"Bass Staff Journey",
		"Hear all the bass notes working together!",
		"bass",
		[
			{"note_id": "C4", "note_step": -2, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 1.0},
			{"note_id": "F3", "note_step": 2, "beats": 1.0},
			{"note_id": "E3", "note_step": 3, "beats": 1.0},
			{"note_id": "D3", "note_step": 4, "beats": 1.0},
			{"note_id": "C3", "note_step": 5, "beats": 2.0},
			{"note_id": "D3", "note_step": 4, "beats": 1.0},
			{"note_id": "F3", "note_step": 2, "beats": 2.0},
		],
		"Bass Staff Journey"
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Name all the bass clef notes! From C4 down to C3.",
		LMD.bass_note_pool_part2(),
		10
	))

	# Cumulative Review — all bass notes C4-C3
	steps.append(LMD.create_cumulative_quiz_step(
		"Bass Review Challenge!",
		"Time to test ALL your bass notes!",
		LMD.bass_note_pool_part2(),
		5
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Excellent! You know all the bass clef notes from C4 down to C3!",
		[
			{"label": "GBDFA", "detail": "Line notes — Good Boys Do Fine Always"},
			{"label": "ACEG", "detail": "Space notes — All Cows Eat Grass"},
			{"label": "E3, D3, C3", "detail": "The lower notes you learned today"},
		]
	))

	return LMD.create_module(
		"bass_part2",
		"Bass Notes — Part 2",
		"Learn GBDFA, ACEG, and notes E3 through C3",
		"",
		steps,
		14,
		"Bass Explorer"
	)
