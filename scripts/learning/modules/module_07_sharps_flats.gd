extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# 1 — Intro
	steps.append(LMD.create_intro_step(
		"Sharps & Flats",
		"Time to learn about sharps and flats! These symbols change how a note sounds.",
		"Accidentals"
	))

	# 2 — Visual: Sharp symbol
	steps.append(LMD.create_visual_step(
		"The Sharp Sign",
		"This is a sharp sign. It looks like a hashtag!",
		"symbol_large",
		{"symbol": "#", "label": "Sharp", "color": "gold"}
	))

	# 3 — Explanation: Sharp
	steps.append(LMD.create_explanation_step(
		"What Does Sharp Do?",
		"A sharp raises a note by one half step. That's the smallest step in music!",
		"Sharp = UP",
		"F sharp is one tiny step higher than F."
	))

	# 3b — Keyboard: See the half step F → F#
	steps.append(LMD.create_visual_step(
		"See It on the Piano!",
		"Watch and listen — F moves UP one half step to F#!",
		"keyboard_half_step",
		{"note_natural": "F4", "note_altered": "F#4", "direction": "up"}
	))

	# 4 — Visual: Flat symbol
	steps.append(LMD.create_visual_step(
		"The Flat Sign",
		"This is a flat sign. It looks like a lowercase b!",
		"symbol_large",
		{"symbol": "b", "label": "Flat", "color": "blue"}
	))

	# 5 — Explanation: Flat
	steps.append(LMD.create_explanation_step(
		"What Does Flat Do?",
		"A flat lowers a note by one half step. Think of it like stepping one tiny stair down!",
		"Flat = DOWN",
		"B flat is one tiny step lower than B."
	))

	# 5b — Keyboard: See the half step B → Bb
	steps.append(LMD.create_visual_step(
		"See It on the Piano!",
		"Watch and listen — B moves DOWN one half step to Bb!",
		"keyboard_half_step",
		{"note_natural": "B4", "note_altered": "Bb4", "direction": "down"}
	))

	# 6 — Explanation: Compare
	steps.append(LMD.create_explanation_step(
		"Sharp vs Flat",
		"Sharp goes UP, flat goes DOWN. They're opposites!",
		"Sharp = UP    Flat = DOWN",
		"A sharp raises the pitch. A flat lowers it. Simple as that!"
	))

	# 6b — Keyboard: Enharmonic F#/Gb
	steps.append(LMD.create_visual_step(
		"Two Names, One Key!",
		"Here's something cool — F# and Gb are the SAME key on the piano! They just have different names.",
		"keyboard_enharmonic",
		{"note_id": "F#4", "name1": "F#", "name2": "Gb"}
	))

	# 7 — Drag symbol: match sharp to its meaning
	steps.append(LMD.create_drag_symbol_step(
		"Drag the sharp symbol to what it does!",
		"\u266f",
		["Raises a note", "Lowers a note", "Cancels an accidental"],
		0,
		"Correct! A sharp raises the note by a half step!",
		"Not quite — the sharp raises a note UP!"
	))

	# 8 — Visual: Natural symbol
	steps.append(LMD.create_visual_step(
		"The Natural Sign",
		"This is a natural sign. It cancels any sharp or flat, returning the note to its original pitch!",
		"symbol_large",
		{"symbol": "\u266e", "label": "Natural", "color": "green"}
	))

	# 9 — Explanation: Natural
	steps.append(LMD.create_explanation_step(
		"What Does Natural Do?",
		"If a note has been made sharp or flat (by an accidental or key signature), the natural sign cancels it. The note goes back to its normal, unaltered pitch.",
		"Natural = Cancel",
		"Think of it as an 'undo button' for sharps and flats!"
	))

	# 9b — Keyboard: Natural reset animation F → F# → F♮
	steps.append(LMD.create_visual_step(
		"See the Natural in Action!",
		"Watch — the natural sign brings the note back to its original pitch!",
		"keyboard_natural_reset",
		{"note_natural": "F4", "note_altered": "F#4"}
	))

	# 10 — Quiz: Natural
	steps.append(LMD.create_quiz_step(
		"What does a natural sign (\u266e) do?",
		["Raises a note", "Lowers a note", "Cancels a sharp or flat"],
		2,
		"Exactly! The natural sign cancels any sharp or flat, returning the note to normal.",
		"Not quite — the natural sign undoes sharps and flats. It's like an undo button!"
	))

	# 11 — Recap
	steps.append(LMD.create_recap_step(
		"Let's Review!",
		"Here's what you learned about accidentals:",
		[
			{"label": "Sharp  #", "detail": "Raises a note by one half step (go UP)", "clef": "treble"},
			{"label": "Flat  b", "detail": "Lowers a note by one half step (go DOWN)", "clef": "bass"},
			{"label": "Natural  \u266e", "detail": "Cancels a sharp or flat (returns note to normal)", "clef": "treble"},
		]
	))

	# Quiz: raises
	steps.append(LMD.create_quiz_step(
		"Which symbol RAISES a note?",
		["Sharp #", "Flat b"],
		0,
		"Yes! A sharp raises the note up!",
		"Remember: sharp = UP, like climbing stairs!"
	))

	# Quiz: lowers
	steps.append(LMD.create_quiz_step(
		"Which symbol LOWERS a note?",
		["Sharp #", "Flat b"],
		1,
		"Correct! A flat lowers the note down!",
		"Flat = DOWN, like stepping down!"
	))

	# Quiz: F#
	steps.append(LMD.create_quiz_step(
		"If you see F#, what happened to the F?",
		["Up a half step", "Down a half step", "Nothing changed"],
		0,
		"Right! F# is one half step higher than F!",
		"The # symbol means sharp — it raises the note!"
	))

	# Quiz: Bb
	steps.append(LMD.create_quiz_step(
		"If you see Bb, what happened to the B?",
		["Up", "Down", "Same"],
		1,
		"Yes! Bb is one half step lower than B!",
		"The b symbol means flat — it lowers the note!"
	))

	# Explanation: accidental notes
	steps.append(LMD.create_explanation_step(
		"Reading Accidental Notes",
		"Now let's practice reading notes with sharps and flats on the staff!",
		"See It on the Staff",
		"When you see a # or b next to a note, it changes that note's pitch."
	))

	# Visual: F# on staff (treble step 7, with sharp)
	steps.append(LMD.create_visual_step(
		"F Sharp on the Staff",
		"Here's F# — notice the sharp sign next to the note F!",
		"note_on_staff",
		{"clef": "treble", "note_name": "F#", "note_step": 7, "accidental": "sharp"}
	))

	# Visual: Bb on staff (treble step 4, with flat)
	steps.append(LMD.create_visual_step(
		"B Flat on the Staff",
		"Here's Bb — the flat sign lowers B by one half step!",
		"note_on_staff",
		{"clef": "treble", "note_name": "Bb", "note_step": 4, "accidental": "flat"}
	))

	# Audio comparison: F vs F#
	steps.append(LMD.create_visual_step(
		"Hear the Difference!",
		"Listen to F and then F#. The sharp raises it just a tiny bit — can you hear it?",
		"note_audio_compare",
		{"note1_id": "F4", "note2_id": "F#4", "label1": "F", "label2": "F#"}
	))

	# Audio comparison: B vs Bb
	steps.append(LMD.create_visual_step(
		"Hear the Difference!",
		"Now listen to B and then Bb. The flat lowers it just a tiny bit — hear that subtle change?",
		"note_audio_compare",
		{"note1_id": "B4", "note2_id": "Bb4", "label1": "B", "label2": "Bb"}
	))

	# Quiz: F# identification
	steps.append(LMD.create_quiz_step(
		"You see a note on the F line with a # sign. What note is it?",
		["F", "F#", "G"],
		1,
		"That's right! The sharp raises F to F#!",
		"The # sign means sharp — it raises the note. F with # = F#!"
	))

	# Quiz: Bb identification
	steps.append(LMD.create_quiz_step(
		"You see a note on the B line with a b sign. What note is it?",
		["A", "B", "Bb"],
		2,
		"Correct! The flat lowers B to Bb!",
		"The b sign means flat — it lowers the note. B with b = Bb!"
	))

	# Quiz: C# concept
	steps.append(LMD.create_quiz_step(
		"If C has a sharp sign, the note becomes...?",
		["Cb", "C#", "D"],
		1,
		"Nice! C# is one half step above C.",
		"A sharp raises a note by one half step. C + # = C#!"
	))

	# Quiz: Eb concept
	steps.append(LMD.create_quiz_step(
		"If E has a flat sign, the note becomes...?",
		["Eb", "E#", "D"],
		0,
		"Well done! Eb is one half step below E.",
		"A flat lowers a note by one half step. E + b = Eb!"
	))

	# Keyboard Quiz: Find F# on the keyboard
	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "F#4", 7, "F#4", "sharp",
		"You found F#! It's the black key right above F.",
		"That's not F# — look for the black key just above F!"
	))

	# Keyboard Quiz: Find Bb on the keyboard
	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "Bb4", 4, "Bb4", "flat",
		"You found Bb! It's the black key right below B.",
		"That's not Bb — look for the black key just below B!"
	))

	# Keyboard Quiz: Find C# on the keyboard
	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "C#4", 10, "C#4", "sharp",
		"You found C#! It's the black key right above middle C.",
		"That's not C# — look for the black key just above C!"
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's drill those accidentals! Answer questions about sharps, flats, and naturals.",
		LMD.accidental_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You're an accidental ace! Sharps, flats, and naturals are no problem for you!",
		[
			{"label": "Sharp  \u266f", "detail": "Raises a note by one half step"},
			{"label": "Flat  \u266d", "detail": "Lowers a note by one half step"},
			{"label": "Natural  \u266e", "detail": "Cancels a sharp or flat"},
			{"label": "F# and Bb", "detail": "Two of the most common accidentals"},
		]
	))

	return LMD.create_module(
		"sharps_flats",
		"Sharps & Flats",
		"Learn sharps, flats, naturals, and accidental notes",
		"",
		steps,
		12,
		"Accidental Ace"
	)
