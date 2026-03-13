extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"Intro to Intervals!",
			"Ready to learn something really cool? An interval is the distance between two notes. Once you understand intervals, you'll start hearing music in a whole new way!",
			"Intervals are the building blocks of melody and harmony."
		),

		# Step 2: What is an interval?
		LMD.create_explanation_step(
			"What Is an Interval?",
			"When you play one note and then another, the 'jump' between them has a name — that's the interval. A small jump sounds close together. A big jump sounds far apart. Every melody is just a series of intervals!",
			"Interval = Distance between two notes",
			"We name intervals by counting the letter names from the first note to the second."
		),

		# Step 3: The step (2nd)
		LMD.create_explanation_step(
			"Steps — The 2nd",
			"The smallest interval we'll learn is a step, also called a 2nd. It's two notes right next to each other, like C to D. Think of walking up a staircase one step at a time — that's what a 2nd sounds like!",
			"Step (2nd) = Notes right next to each other",
			"Example: C to D, or E to F."
		),

		# Step 4: Visual — step on staff
		LMD.create_visual_step(
			"A Step on the Staff",
			"See how close these two notes are? One sits on a line and the next is in the space right above it (or the other way around). That's a step — a 2nd!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 9, "label": "Step (2nd)", "show_keyboard": true}
		),

		# Step 5: The skip (3rd)
		LMD.create_explanation_step(
			"Skips — The 3rd",
			"A skip is a little bigger — it jumps over one letter name. C to E is a 3rd because it goes C, skip D, land on E. Skips sound smooth and are used everywhere in music!",
			"Skip (3rd) = Jump over one letter",
			"Example: C to E, or D to F."
		),

		# Step 6: Visual — skip on staff
		LMD.create_visual_step(
			"A Skip on the Staff",
			"Notice how there's a gap between these notes? If one note is on a line, a 3rd takes you to the very next line. If one is in a space, a 3rd goes to the next space. That's a skip!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 8, "label": "Skip (3rd)", "show_keyboard": true}
		),

		# Step 7: The 4th
		LMD.create_explanation_step(
			"The 4th",
			"A 4th is a bigger jump — count up four letter names. C to F is a 4th (C-D-E-F). The opening notes of 'Here Comes the Bride' are a perfect 4th! It sounds strong and open.",
			"4th = Count four letters up",
			"Example: C to F. Think of 'Here Comes the Bride.'"
		),

		# Step 8: The 5th
		LMD.create_explanation_step(
			"The 5th",
			"A 5th jumps even further — five letter names. C to G is a 5th (C-D-E-F-G). The Star Wars theme starts with a 5th! Fifths sound powerful and grand.",
			"5th = Count five letters up",
			"Example: C to G. Think of the Star Wars opening."
		),

		# Step 9: Visual — 4th on staff
		LMD.create_visual_step(
			"A 4th on the Staff",
			"See the wider gap? C up to F — that's four letter names. The further apart notes are on the staff, the bigger the interval sounds!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 7, "label": "4th", "show_keyboard": true}
		),

		# Step 10: Visual — 5th on staff
		LMD.create_visual_step(
			"A 5th on the Staff",
			"Now look at this jump — C up to G. That's five letter names apart. On the staff you can really see the distance growing!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 6, "label": "5th", "show_keyboard": true}
		),

		# Step 11: Bigger = wider sound
		LMD.create_explanation_step(
			"Bigger Number = Bigger Sound",
			"Here's the simple rule: the larger the interval number, the bigger the jump in pitch. A 2nd is a tiny step, a 3rd is a small skip, a 4th is a solid jump, and a 5th is a big leap. Your ears can learn to tell them apart!",
			"2nd < 3rd < 4th < 5th",
			"You can practice hearing these in Ear Training mode!"
		),

		# Step 12: Recap
		LMD.create_recap_step(
			"Interval Review!",
			"Brilliant! Here's what we learned about intervals:",
			[
				{"label": "Interval", "detail": "The distance between two notes, named by counting letters."},
				{"label": "2nd (Step)", "detail": "Notes right next to each other — C to D."},
				{"label": "3rd (Skip)", "detail": "Jump over one letter — C to E."},
				{"label": "4th", "detail": "Four letters apart — C to F."},
				{"label": "5th", "detail": "Five letters apart — C to G."},
			]
		),

		# Step 13: Quiz — what is an interval?
		LMD.create_quiz_step(
			"What is an interval?",
			["A type of note", "The distance between two notes", "A musical instrument", "A kind of rest"],
			1,
			"That's right! An interval is the distance between two notes. Nice work!",
			"Not quite — think about what we measure between two notes. Try again!"
		),

		# Step 14: Quiz — C to D
		LMD.create_quiz_step(
			"C to D is called a...?",
			["3rd (Skip)", "2nd (Step)", "4th", "5th"],
			1,
			"Well done! C to D is a 2nd — they're right next to each other.",
			"Hmm, count the letter names: C, D. How many is that? Try again!"
		),

		# Step 15: Quiz — C to E
		LMD.create_quiz_step(
			"C to E is called a...?",
			["2nd (Step)", "4th", "3rd (Skip)", "5th"],
			2,
			"Excellent! C to E is a 3rd — it skips right over D.",
			"Almost! Count: C, D, E — that's three letters. What's that interval called? Try again!"
		),

		# Step 16: Quiz — bigger interval
		LMD.create_quiz_step(
			"Which interval is bigger — a 2nd or a 5th?",
			["A 2nd", "They're the same", "A 5th", "It depends on the note"],
			2,
			"Great job! A 5th is a much bigger jump than a 2nd. You're an Interval Explorer!",
			"Remember: bigger number = bigger jump in sound. Try again!"
		),

		# Step 17: Quiz — identify the 4th
		LMD.create_quiz_step(
			"C to F is called a...?",
			["2nd", "3rd", "4th", "5th"],
			2,
			"Awesome! C-D-E-F — four letters, a 4th. You nailed it!",
			"Count the letters from C to F: C, D, E, F. How many is that? Try again!"
		),
	]

	# ── Keyboard Quiz: Find interval notes ──
	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "D4", 9, "D4", "",
		"That's D! One step above C — a 2nd!",
		"Find D — the note one step above middle C."
	))

	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "E4", 8, "E4", "",
		"You found E! That's a 3rd above C!",
		"Find E — count up from C: C, D, E. That's a 3rd!"
	))

	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "G4", 6, "G4", "",
		"Right! G is a 5th above C — the Star Wars interval!",
		"Find G — count up from C: C, D, E, F, G. That's a 5th!"
	))

	# ── Listening Quiz ──
	steps.append(LMD.create_listening_quiz_step(
		"Hear the Intervals!",
		"Listen to these intervals and try to identify them by ear!",
		[
			{"note_ids": ["C4", "D4"], "label": "2nd", "choices": ["2nd (step)", "3rd (skip)", "5th"], "correct_index": 0},
			{"note_ids": ["C4", "E4"], "label": "3rd", "choices": ["2nd", "3rd (skip)", "4th"], "correct_index": 1},
			{"note_ids": ["C4", "F4"], "label": "4th", "choices": ["3rd", "4th", "5th"], "correct_index": 1},
			{"note_ids": ["C4", "G4"], "label": "5th", "choices": ["3rd", "4th", "5th"], "correct_index": 2},
		]
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Interval Practice",
		"Let's see how well you know your intervals! Answer as many as you can!",
		LMD.interval_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've learned about intervals — the building blocks of melody and harmony!",
		[
			{"label": "2nd (Step)", "detail": "Adjacent notes — C to D"},
			{"label": "3rd (Skip)", "detail": "Skip one note — C to E"},
			{"label": "4th", "detail": "C to F — 'Here Comes the Bride'"},
			{"label": "5th", "detail": "C to G — the Star Wars opening"},
		]
	))

	return LMD.create_module(
		"intervals_intro",
		"Intro to Intervals",
		"Learn steps, skips, and the distance between notes",
		"",
		steps,
		11,
		"Interval Explorer"
	)
