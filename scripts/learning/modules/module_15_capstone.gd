extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"The Final Challenge!",
		"You've learned so much — notes, rhythms, key signatures, intervals, and chords! Now it's time to put it ALL together. Are you ready for the Capstone Challenge?",
		"Music Theory Capstone"
	))

	# ══════════════════════════════════════════════════════════════════════
	# SECTION 1 — Mixed Note Reading
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_explanation_step(
		"Section 1: Note Reading",
		"First up — let's see how well you can read notes on both the treble and bass clefs. These will cover the full range you've learned!",
		"Treble + Bass Notes",
		"Every note from C4 all the way up to G5, and from C4 down to F2."
	))

	# Treble quiz — full A-G choices
	steps.append(LMD.create_note_quiz_step(
		"treble", "A4", 5,
		["A", "B", "C", "D", "E", "F", "G"],
		0,
		"That's A4 — in the second space!",
		"Look carefully at which space this note is in. Count up from the bottom!"
	))

	steps.append(LMD.create_note_quiz_step(
		"treble", "F5", 0,
		["A", "B", "C", "D", "E", "F", "G"],
		5,
		"Right! F5 is on the top line!",
		"This note sits on the very top line of the treble staff."
	))

	# Bass quiz — full A-G choices
	steps.append(LMD.create_note_quiz_step(
		"bass", "D3", 4,
		["A", "B", "C", "D", "E", "F", "G"],
		3,
		"Yes! D3 on the middle line of the bass staff!",
		"This note sits right on the middle line — the third line from the bottom."
	))

	steps.append(LMD.create_note_quiz_step(
		"bass", "G2", 8,
		["A", "B", "C", "D", "E", "F", "G"],
		6,
		"Correct! G2 on the very bottom line!",
		"This note sits on the bottom line of the bass staff."
	))

	# ══════════════════════════════════════════════════════════════════════
	# SECTION 2 — Rhythm Tapping
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_explanation_step(
		"Section 2: Rhythm",
		"Now let's test your sense of rhythm! Tap along with the beat patterns.",
		"Feel the Beat!",
		"Listen, watch, and tap!"
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Capstone Rhythm — Steady Quarter Notes",
		"Start simple — four steady quarter notes. Keep it in time!",
		[1.0, 1.0, 1.0, 1.0],
		92,
		4
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Capstone Rhythm — Mixed Pattern",
		"Now a trickier pattern: a half note, a quarter note, and two eighth notes. Watch the bar carefully!",
		[2.0, 1.0, 0.5, 0.5],
		88,
		4
	))

	# ══════════════════════════════════════════════════════════════════════
	# SECTION 3 — Key Signatures
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_explanation_step(
		"Section 3: Key Signatures",
		"Can you identify key signatures? Let's find out!",
		"Name That Key!",
		"Remember: count the sharps or flats!"
	))

	steps.append(LMD.create_quiz_step(
		"A piece starts with 2 sharps (F# and C#). What key is it?",
		["G Major", "D Major", "A Major", "C Major"],
		1,
		"Right! Two sharps means D Major!",
		"Count the sharps: G=1, D=2, A=3. Which has 2? Try again!"
	))

	steps.append(LMD.create_quiz_step(
		"A piece starts with 1 flat (B♭). What key is it?",
		["C Major", "F Major", "B♭ Major", "E♭ Major"],
		1,
		"Correct! One flat means F Major!",
		"Remember: F Major has one flat. B♭ Major has two. Try again!"
	))

	steps.append(LMD.create_quiz_step(
		"You're playing in A Major. What happens to all G notes?",
		["They stay natural", "They're played as G#", "They're played as Gb", "They're skipped"],
		1,
		"Yes! A Major has 3 sharps: F#, C#, and G# — so all G notes become G#!",
		"A Major has three sharps. The order is F, C, G. So G is... Try again!"
	))

	# ══════════════════════════════════════════════════════════════════════
	# SECTION 4 — Intervals & Quality
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_explanation_step(
		"Section 4: Intervals & Quality",
		"Let's test your interval knowledge — number AND quality!",
		"How Far Apart? What Quality?",
		"Remember: count letter names AND semitones."
	))

	steps.append(LMD.create_quiz_step(
		"C to F is what interval?",
		["2nd", "3rd", "Perfect 4th", "Perfect 5th"],
		2,
		"That's right! C-D-E-F = a perfect 4th!",
		"Count the letters: C, D, E, F. How many? Try again!"
	))

	steps.append(LMD.create_quiz_step(
		"C to Eb is what kind of interval?",
		["Major 3rd", "Minor 3rd", "Perfect 4th", "Minor 2nd"],
		1,
		"Correct! C to Eb is a minor 3rd — 3 semitones!",
		"Count semitones: C-C#-D-Eb = 3. That's a minor 3rd. Try again!"
	))

	steps.append(LMD.create_quiz_step(
		"How many semitones in a major 3rd?",
		["3", "4", "5", "7"],
		1,
		"Right! A major 3rd = 4 semitones — the bright interval!",
		"Minor 3rd = 3, major 3rd = one more. Try again!"
	))

	# Listening quiz — identify intervals by ear (with quality)
	steps.append(LMD.create_listening_quiz_step(
		"Capstone Ear Training",
		"Listen carefully and identify each interval — number AND quality!",
		[
			{"note_ids": ["C4", "E4"], "label": "Major 3rd", "choices": ["Major 3rd", "Minor 3rd", "Perfect 5th"], "correct_index": 0},
			{"note_ids": ["C4", "Eb4"], "label": "Minor 3rd", "choices": ["Major 3rd", "Minor 3rd", "Perfect 4th"], "correct_index": 1},
			{"note_ids": ["C4", "G4"], "label": "Perfect 5th", "choices": ["Perfect 4th", "Perfect 5th", "Major 3rd"], "correct_index": 1},
			{"note_ids": ["C4", "F4"], "label": "Perfect 4th", "choices": ["Major 3rd", "Perfect 4th", "Perfect 5th"], "correct_index": 1},
		]
	))

	# ══════════════════════════════════════════════════════════════════════
	# SECTION 5 — Minor Scales & Chords
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_quiz_step(
		"What is the relative minor of G Major?",
		["A minor", "D minor", "E minor", "B minor"],
		2,
		"Yes! E minor — same key signature as G Major (1 sharp)!",
		"Count down 3 half steps from G, or find the 6th note. Try again!"
	))

	steps.append(LMD.create_quiz_step(
		"A major chord sounds...?",
		["Happy and bright", "Sad and dark", "Tense and spooky"],
		0,
		"Right! Major = happy and bright!",
		"Think about how major chords make you feel — is it bright or dark?"
	))

	steps.append(LMD.create_quiz_step(
		"What notes make a C Major chord?",
		["C-E-G", "C-Eb-G", "C-E-G#"],
		0,
		"Correct! C-E-G — the classic major triad!",
		"A major triad = root + major 3rd + perfect 5th. For C, that's C-E-G."
	))

	# ══════════════════════════════════════════════════════════════════════
	# SECTION 6 — Melody Recognition
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_melody_example_step(
		"Your Capstone Melody!",
		"Here's a melody that uses everything you've learned. Listen, follow along, and try singing it back!",
		"treble",
		[
			{"note_id": "C4", "note_step": 10, "beats": 1.0},
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "G4", "note_step": 6, "beats": 1.0},
			{"note_id": "A4", "note_step": 5, "beats": 0.5},
			{"note_id": "G4", "note_step": 6, "beats": 0.5},
			{"note_id": "F4", "note_step": 7, "beats": 1.0},
			{"note_id": "E4", "note_step": 8, "beats": 1.0},
			{"note_id": "D4", "note_step": 9, "beats": 1.0},
			{"note_id": "C4", "note_step": 10, "beats": 2.0},
		],
		"Capstone Melody"
	))

	# ══════════════════════════════════════════════════════════════════════
	# COMPLETION
	# ══════════════════════════════════════════════════════════════════════

	steps.append(LMD.create_recap_step(
		"Congratulations!",
		"You did it! You've completed the entire Music Theory learning path! You can read notes, tap rhythms, identify key signatures, understand major and minor, hear interval qualities, and build chords. That's AMAZING!",
		[
			{"label": "Notes", "detail": "Treble and bass clef — full range!"},
			{"label": "Rhythm", "detail": "Whole, half, quarter, and eighth notes"},
			{"label": "Key Signatures", "detail": "Sharp and flat keys from the circle of fifths"},
			{"label": "Minor Scales", "detail": "Natural minor, relative keys, harmonic minor"},
			{"label": "Interval Quality", "detail": "Major, minor, and perfect intervals by ear"},
			{"label": "Chords", "detail": "Major, minor, and diminished triads"},
			{"label": "You Earned:", "detail": "🏆 Music Theory Graduate!"},
		]
	))

	return LMD.create_module(
		"capstone",
		"The Final Challenge",
		"Put it all together — notes, rhythm, keys, scales, intervals, and chords!",
		"",
		steps,
		15,
		"Music Theory Graduate"
	)
