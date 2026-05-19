extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"Interval Quality!",
			"You already know intervals by number — 2nds, 3rds, 4ths, 5ths. But did you know each interval also has a QUALITY? Major, minor, or perfect — these qualities tell you the exact size and mood of the interval!",
			"Every interval has a number AND a quality."
		),

		# Step 2: Why quality matters
		LMD.create_explanation_step(
			"Why Does Quality Matter?",
			"C to E and C to Eb are both 3rds — but they sound completely different! C to E is a major 3rd (bright, happy). C to Eb is a minor 3rd (dark, sad). The quality tells you which kind of 3rd you're hearing. It's the secret behind major and minor chords!",
			"Same number, different quality = different sound",
			"Quality is measured in semitones (half steps)."
		),

		# Step 3: Perfect intervals
		LMD.create_explanation_step(
			"Perfect Intervals",
			"Some intervals are called 'perfect' — the unison (same note), 4th, 5th, and octave. These intervals sound very stable and clean. They don't come in major or minor versions — they're just perfect! The perfect 5th is the most consonant interval in music.",
			"Perfect intervals: Unison, 4th, 5th, Octave",
			"Perfect 4th = 5 semitones. Perfect 5th = 7 semitones. Octave = 12 semitones."
		),

		# Step 4: Visual — Perfect 4th
		LMD.create_visual_step(
			"The Perfect 4th",
			"C to F is a perfect 4th — 5 semitones. It sounds strong and open, like the start of 'Here Comes the Bride.' Perfect intervals have a pure, stable quality.",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 7, "label": "Perfect 4th (5 semitones)", "show_keyboard": true}
		),

		# Step 5: Visual — Perfect 5th
		LMD.create_visual_step(
			"The Perfect 5th",
			"C to G is a perfect 5th — 7 semitones. It's the backbone of most chords and sounds powerful, like the opening of Star Wars. This is the most important interval in harmony!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 6, "label": "Perfect 5th (7 semitones)", "show_keyboard": true}
		),

		# Step 6: Major and minor intervals
		LMD.create_explanation_step(
			"Major and Minor Intervals",
			"2nds, 3rds, 6ths, and 7ths come in BOTH major and minor versions. The major version is always one semitone bigger than the minor version. Major intervals sound bright and open. Minor intervals sound darker and more intimate.",
			"Major = 1 semitone bigger than minor",
			"Major 2nd = 2 semitones. Minor 2nd = 1 semitone. Major 3rd = 4 semitones. Minor 3rd = 3 semitones."
		),

		# Step 7: Major 3rd vs Minor 3rd
		LMD.create_explanation_step(
			"Major 3rd vs Minor 3rd — The Big One!",
			"This is the most important quality to know! A major 3rd (4 semitones, like C to E) sounds happy and bright. A minor 3rd (3 semitones, like C to Eb) sounds sad and dark. This single interval is what makes chords major or minor!",
			"Major 3rd (4 semitones) = Happy  |  Minor 3rd (3 semitones) = Sad",
			"Every major chord has a major 3rd. Every minor chord has a minor 3rd."
		),

		# Step 8: Visual — Major 3rd
		LMD.create_visual_step(
			"The Major 3rd",
			"C to E is a major 3rd — 4 semitones. This bright interval is the foundation of every major chord. If it sounds like the start of a cheerful song, it's a major 3rd!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 8, "label": "Major 3rd (4 semitones)", "show_keyboard": true}
		),

		# Step 9: Visual — Minor 3rd
		LMD.create_visual_step(
			"The Minor 3rd",
			"C to Eb is a minor 3rd — 3 semitones. This darker interval is the foundation of every minor chord. If it sounds wistful or sad, it's a minor 3rd!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 8, "label": "Minor 3rd (3 semitones)", "note2_accidental": "flat", "show_keyboard": true}
		),

		# Step 10: Major 2nd vs Minor 2nd
		LMD.create_explanation_step(
			"Major 2nd vs Minor 2nd",
			"A major 2nd (2 semitones, like C to D) is a whole step — smooth and melodic. A minor 2nd (1 semitone, like C to C# or E to F) is a half step — tense and crunchy. The minor 2nd creates that 'Jaws theme' feeling!",
			"Major 2nd (whole step) = smooth  |  Minor 2nd (half step) = tense",
			"Jaws: E-F, E-F... that's a minor 2nd (half step) creating suspense!"
		),

		# Step 11: Listening — Major vs Minor 3rd
		LMD.create_listening_quiz_step(
			"Hear the Quality!",
			"Listen to these intervals. Can you tell major from minor?",
			[
				{"note_ids": ["C4", "E4"], "label": "Major 3rd", "choices": ["Major 3rd", "Minor 3rd", "Perfect 5th"], "correct_index": 0},
				{"note_ids": ["C4", "Eb4"], "label": "Minor 3rd", "choices": ["Major 3rd", "Minor 3rd", "Perfect 4th"], "correct_index": 1},
				{"note_ids": ["C4", "D4"], "label": "Major 2nd", "choices": ["Minor 2nd", "Major 2nd", "Major 3rd"], "correct_index": 1},
				{"note_ids": ["E4", "F4"], "label": "Minor 2nd", "choices": ["Minor 2nd", "Major 2nd", "Minor 3rd"], "correct_index": 0},
			]
		),

		# Step 12: Semitone counting
		LMD.create_explanation_step(
			"Counting Semitones",
			"Here's a reliable way to identify any interval: count the semitones (half steps) on a keyboard! Minor 2nd = 1, Major 2nd = 2, Minor 3rd = 3, Major 3rd = 4, Perfect 4th = 5, Perfect 5th = 7, Octave = 12.",
			"Semitone Cheat Sheet",
			"m2=1, M2=2, m3=3, M3=4, P4=5, P5=7, P8=12"
		),

		# Step 13: The tritone
		LMD.create_explanation_step(
			"The Tritone — The Devil's Interval",
			"There's one special interval: the tritone (6 semitones) — exactly halfway through an octave. It sounds very tense and unstable. In the Middle Ages, it was even called 'the devil in music!' It's the sound of suspense and unresolved tension.",
			"Tritone = 6 semitones = Maximum tension",
			"C to F# (or C to Gb) is a tritone. It resolves by moving one step in either direction."
		),

		# Step 14: Quality summary
		LMD.create_recap_step(
			"Interval Quality Review!",
			"Here's the complete picture of interval qualities:",
			[
				{"label": "Perfect", "detail": "Unison, 4th (5), 5th (7), Octave (12) — stable and clean"},
				{"label": "Major 2nd", "detail": "2 semitones — a smooth whole step"},
				{"label": "Minor 2nd", "detail": "1 semitone — a tense half step"},
				{"label": "Major 3rd", "detail": "4 semitones — bright, the heart of major chords"},
				{"label": "Minor 3rd", "detail": "3 semitones — dark, the heart of minor chords"},
				{"label": "Tritone", "detail": "6 semitones — maximum tension!"},
			]
		),

		# Step 15: Quiz — what is a perfect interval?
		LMD.create_quiz_step(
			"Which of these is a perfect interval?",
			["Major 3rd", "Minor 2nd", "Perfect 5th", "Minor 6th"],
			2,
			"Right! The 5th is a perfect interval — along with the unison, 4th, and octave!",
			"Remember: perfect intervals are the unison, 4th, 5th, and octave. Try again!"
		),

		# Step 16: Quiz — major 3rd semitones
		LMD.create_quiz_step(
			"How many semitones in a major 3rd?",
			["2", "3", "4", "5"],
			2,
			"Correct! A major 3rd is 4 semitones — the bright interval that makes major chords happy!",
			"Think: minor 3rd = 3, major 3rd = one more. Try again!"
		),

		# Step 17: Quiz — minor vs major 3rd
		LMD.create_quiz_step(
			"A minor 3rd sounds...?",
			["Bright and happy", "Dark and sad", "Tense and scary", "Neutral"],
			1,
			"That's right! Minor 3rds have that darker, sadder quality compared to major 3rds!",
			"Think about what 'minor' means in music — happy or sad? Try again!"
		),

		# Step 18: Quiz — C to Eb
		LMD.create_quiz_step(
			"C to Eb is what kind of interval?",
			["Major 2nd", "Minor 2nd", "Major 3rd", "Minor 3rd"],
			3,
			"Correct! C to Eb is a minor 3rd — 3 semitones!",
			"Count from C: C#(1), D(2), Eb(3). That's 3 semitones — what quality of 3rd? Try again!"
		),

		# Step 19: Quiz — perfect 4th semitones
		LMD.create_quiz_step(
			"How many semitones in a perfect 4th?",
			["4", "5", "6", "7"],
			1,
			"Right! A perfect 4th = 5 semitones. 'Here Comes the Bride'!",
			"Count from C to F on the keyboard: C#, D, Eb, E, F = 5 semitones. Try again!"
		),

		# Step 20: Quiz — the tritone
		LMD.create_quiz_step(
			"The tritone is called 'the devil's interval' because it sounds...?",
			["Very stable and calm", "Bright and cheerful", "Tense and unstable", "Soft and quiet"],
			2,
			"Yes! The tritone's extreme tension is why it got that spooky nickname!",
			"Think about what 6 semitones (exactly half an octave) sounds like. Try again!"
		),
	]

	# ── Listening Quiz — Quality Identification ──
	steps.append(LMD.create_listening_quiz_step(
		"Ear Training: Interval Quality",
		"Listen to each interval and identify its quality! This is real ear training!",
		[
			{"note_ids": ["C4", "E4"], "label": "Major 3rd", "choices": ["Major 3rd", "Minor 3rd", "Perfect 5th"], "correct_index": 0},
			{"note_ids": ["C4", "Eb4"], "label": "Minor 3rd", "choices": ["Major 3rd", "Minor 3rd", "Perfect 4th"], "correct_index": 1},
			{"note_ids": ["C4", "G4"], "label": "Perfect 5th", "choices": ["Major 3rd", "Perfect 4th", "Perfect 5th"], "correct_index": 2},
			{"note_ids": ["C4", "F4"], "label": "Perfect 4th", "choices": ["Major 3rd", "Perfect 4th", "Perfect 5th"], "correct_index": 1},
			{"note_ids": ["C4", "D4"], "label": "Major 2nd", "choices": ["Minor 2nd", "Major 2nd", "Minor 3rd"], "correct_index": 1},
		]
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Interval Quality Practice",
		"Let's review interval qualities! Can you remember your semitone counts?",
		LMD.interval_quality_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You now understand interval QUALITY — the difference between major, minor, and perfect! This knowledge is the foundation of all harmony!",
		[
			{"label": "Perfect", "detail": "Unison, 4th, 5th, Octave — pure and stable"},
			{"label": "Major/Minor", "detail": "2nds, 3rds, 6ths, 7ths — major is one semitone wider"},
			{"label": "Major 3rd", "detail": "4 semitones — bright, makes major chords"},
			{"label": "Minor 3rd", "detail": "3 semitones — dark, makes minor chords"},
		]
	))

	return LMD.create_module(
		"interval_quality",
		"Interval Quality",
		"Learn major, minor, and perfect interval qualities",
		"",
		steps,
		12,
		"Quality Inspector"
	)
