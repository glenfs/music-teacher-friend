extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"Minor Scales!",
			"You've learned about major keys — now let's explore the other side of music: minor scales! Minor music sounds darker, sadder, or more mysterious. Let's find out why!",
			"Minor = the 'sad' side of music"
		),

		# Step 2: What is a minor scale?
		LMD.create_explanation_step(
			"What Is a Minor Scale?",
			"A minor scale is a pattern of whole steps and half steps — just like a major scale, but with a different pattern. That different pattern is what makes minor music sound sad, emotional, or mysterious instead of bright and happy.",
			"Minor Scale = Different step pattern = Different mood",
			"The pattern is: Whole, Half, Whole, Whole, Half, Whole, Whole."
		),

		# Step 3: A Natural Minor
		LMD.create_explanation_step(
			"A Natural Minor — The Easiest Minor Scale",
			"The easiest minor scale to learn is A minor! It uses ALL the white keys on the piano, just like C Major — but it starts and ends on A instead of C. Play A-B-C-D-E-F-G-A and you've played A natural minor!",
			"A Natural Minor = All white keys, starting on A",
			"Same notes as C Major, but starting on a different note completely changes the mood."
		),

		# Step 4: Listening comparison — C Major vs A minor
		LMD.create_listening_quiz_step(
			"Major vs Minor: Hear the Difference!",
			"Listen to these two scales. One sounds bright and happy, the other sounds darker. Can you tell which is which?",
			[
				{"note_ids": ["C4", "D4", "E4", "F4", "G4"], "label": "Major", "choices": ["Major scale", "Minor scale"], "correct_index": 0},
				{"note_ids": ["A3", "B3", "C4", "D4", "E4"], "label": "Minor", "choices": ["Major scale", "Minor scale"], "correct_index": 1},
			]
		),

		# Step 5: Relative major and minor
		LMD.create_explanation_step(
			"Relative Major and Minor",
			"Here's something amazing: every major key has a 'relative minor' that uses the exact same notes! C Major and A minor are relatives — same white keys, different starting note. The minor starts 3 half steps below the major.",
			"C Major ↔ A minor (same notes!)",
			"G Major's relative minor is E minor. F Major's relative minor is D minor."
		),

		# Step 6: More relative pairs
		LMD.create_explanation_step(
			"Finding Relative Minor Keys",
			"To find any major key's relative minor, count down 3 half steps (or up to the 6th note of the scale). G Major → E minor. D Major → B minor. F Major → D minor. They always share the same key signature!",
			"Major key → count down 3 half steps → relative minor",
			"E minor has 1 sharp (F#), same as G Major. B minor has 2 sharps, same as D Major."
		),

		# Step 7: The natural minor pattern
		LMD.create_explanation_step(
			"The Natural Minor Step Pattern",
			"The natural minor scale follows this step pattern: Whole-Half-Whole-Whole-Half-Whole-Whole. Compare that to major (W-W-H-W-W-W-H). The half steps fall in different places, and that's what creates the darker sound!",
			"Minor: W-H-W-W-H-W-W",
			"The half step between notes 2-3 (B-C in A minor) is the first clue you're hearing minor."
		),

		# Step 8: Harmonic minor intro
		LMD.create_explanation_step(
			"The Harmonic Minor Scale",
			"There's a special version called the harmonic minor. It raises the 7th note by a half step! In A harmonic minor, G becomes G#. This creates a dramatic, almost exotic sound — you might hear it in classical music or movie soundtracks!",
			"Harmonic Minor = Natural minor + raised 7th",
			"A harmonic minor: A-B-C-D-E-F-G#-A. That G# pulls strongly toward A."
		),

		# Step 9: Why raise the 7th?
		LMD.create_explanation_step(
			"Why Raise the 7th?",
			"In music, the 7th note 'wants' to go up to the 1st note — like a musical magnet. In natural minor, the 7th (G) is a whole step from the 1st (A), which feels weak. Raising it to G# makes it a half step away, creating a strong pull home!",
			"G → A (weak pull)  vs  G# → A (strong pull!)",
			"This strong pull is called a 'leading tone' — it leads your ear home."
		),

		# Step 10: Listen to harmonic minor
		LMD.create_listening_quiz_step(
			"Natural vs Harmonic Minor",
			"Listen carefully! One scale has a raised 7th that creates a dramatic sound. Can you hear the difference?",
			[
				{"note_ids": ["A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4"], "label": "Natural minor", "choices": ["Natural minor", "Harmonic minor"], "correct_index": 0},
				{"note_ids": ["A3", "B3", "C4", "D4", "E4", "F4", "G#4", "A4"], "label": "Harmonic minor", "choices": ["Natural minor", "Harmonic minor"], "correct_index": 1},
			]
		),

		# Step 11: Common minor keys
		LMD.create_explanation_step(
			"Common Minor Keys",
			"Here are some minor keys you'll see often: A minor (no sharps/flats), E minor (1 sharp — F#), D minor (1 flat — Bb), and B minor (2 sharps — F#, C#). Each shares its key signature with its relative major!",
			"A min = 0 | E min = 1# | D min = 1♭ | B min = 2#",
			"The key signature doesn't tell you major or minor — you have to listen for the mood!"
		),

		# Step 12: How to tell major from minor
		LMD.create_explanation_step(
			"Major or Minor? Listen!",
			"Since relative major and minor keys share the same key signature, how do you tell them apart? Listen! If the music sounds bright and settled, it's probably major. If it sounds dark, sad, or mysterious, it's probably minor. Also, minor pieces often end on the minor chord.",
			"Bright/happy → Major  |  Dark/sad → Minor",
			"The first and last chords of a piece usually tell you the key."
		),

		# Step 13: Recap
		LMD.create_recap_step(
			"Minor Scales Review!",
			"Here's everything we covered about minor scales:",
			[
				{"label": "Natural Minor", "detail": "W-H-W-W-H-W-W — the basic minor scale pattern"},
				{"label": "A Minor", "detail": "All white keys starting on A — relative to C Major"},
				{"label": "Relative Keys", "detail": "Major and minor keys that share the same notes and key signature"},
				{"label": "Harmonic Minor", "detail": "Natural minor with a raised 7th — creates a strong pull home"},
				{"label": "Mood", "detail": "Minor sounds sad, dark, or mysterious compared to major"},
			]
		),

		# Step 14: Quiz — what makes minor sound different?
		LMD.create_quiz_step(
			"What makes a minor scale sound different from major?",
			["It uses different notes", "It has a different step pattern", "It's played louder", "It uses only black keys"],
			1,
			"Correct! The different pattern of whole and half steps creates the minor mood!",
			"Think about what we said changes between major and minor — it's all about the step pattern. Try again!"
		),

		# Step 15: Quiz — A minor notes
		LMD.create_quiz_step(
			"A natural minor uses which keys on the piano?",
			["All black keys", "All white keys starting on A", "A mix of black and white", "Only the note A"],
			1,
			"Right! A natural minor uses all white keys, just starting on A instead of C!",
			"Remember: A minor is the 'twin' of C Major — same keys, different start. Try again!"
		),

		# Step 16: Quiz — relative minor of C Major
		LMD.create_quiz_step(
			"What is the relative minor of C Major?",
			["C minor", "E minor", "A minor", "G minor"],
			2,
			"That's right! A minor is the relative minor of C Major — they share all the same notes!",
			"Count down 3 half steps from C, or go to the 6th note of the C Major scale. Try again!"
		),

		# Step 17: Quiz — harmonic minor
		LMD.create_quiz_step(
			"What note changes in A harmonic minor compared to A natural minor?",
			["C becomes C#", "F becomes F#", "G becomes G#", "E becomes Eb"],
			2,
			"Correct! The 7th note G is raised to G# in harmonic minor!",
			"Harmonic minor raises the 7th note. In A minor, the 7th note is G. Try again!"
		),

		# Step 18: Quiz — relative minor of G Major
		LMD.create_quiz_step(
			"What is the relative minor of G Major?",
			["A minor", "B minor", "D minor", "E minor"],
			3,
			"Yes! E minor is the relative minor of G Major — both have one sharp (F#)!",
			"Count down 3 half steps from G, or find the 6th note of G Major. Try again!"
		),

		# Step 19: Quiz — mood
		LMD.create_quiz_step(
			"A piece that sounds dark and emotional is probably in a...?",
			["Major key", "Minor key", "No key at all", "Chromatic key"],
			1,
			"Right! Dark and emotional music is usually in a minor key!",
			"Remember our mood associations: bright = major, dark = ... Try again!"
		),
	]

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Minor Scales Practice",
		"Let's review everything about minor scales! How well do you know them?",
		LMD.minor_scale_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've mastered minor scales! Now you understand both sides of music — major AND minor!",
		[
			{"label": "Natural Minor", "detail": "W-H-W-W-H-W-W — the dark, emotional scale"},
			{"label": "Relative Keys", "detail": "C Major ↔ A minor, G Major ↔ E minor"},
			{"label": "Harmonic Minor", "detail": "Raised 7th creates a dramatic leading tone"},
			{"label": "Mood Test", "detail": "Bright = Major, Dark = Minor"},
		]
	))

	return LMD.create_module(
		"minor_scales",
		"Minor Scales",
		"Learn natural minor, relative keys, and harmonic minor",
		"",
		steps,
		10,
		"Minor Scale Master"
	)
