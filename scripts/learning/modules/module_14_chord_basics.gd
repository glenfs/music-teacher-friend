extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"Chord Basics!",
			"Time to learn about chords — the backbone of harmony! A chord is what happens when you play several notes at the same time. Once you understand chords, you'll hear the 'mood' behind every song.",
			"Chords are groups of notes played together to create harmony."
		),

		# Step 2: What is a chord?
		LMD.create_explanation_step(
			"What Is a Chord?",
			"A chord is three or more notes played at the same time. When you press several piano keys together, that's a chord! Each chord has its own special sound — some feel happy, some feel sad, and some feel tense.",
			"Chord = 3+ notes sounding together",
			"The most basic chords use three notes and are called triads (tri = three)."
		),

		# Step 3: Building blocks — intervals
		LMD.create_explanation_step(
			"Chords Are Built from Intervals",
			"Remember intervals? Chords are built by stacking them! A triad uses a root note, then adds a 3rd above it, and a 5th above the root. The type of 3rd and 5th you use changes the whole mood of the chord.",
			"Triad = Root + 3rd + 5th",
			"The root is the 'home base' note that gives the chord its name."
		),

		# Step 4: Major triad
		LMD.create_explanation_step(
			"The Major Triad",
			"A major triad uses a root, a major 3rd (4 semitones up), and a perfect 5th (7 semitones up). It sounds happy and bright — like the opening of 'Happy Birthday' or a sunny day! C major is C, E, and G.",
			"Major = Root + Major 3rd + Perfect 5th",
			"Example: C-E-G. The major 3rd (C to E) is what gives it that bright, happy sound."
		),

		# Step 5: Visual — major 3rd (C to E)
		LMD.create_visual_step(
			"The Major 3rd in a Major Chord",
			"Here's the first building block of a C major chord: C up to E. That's a major 3rd — four semitones. This wide, bright gap is what makes major chords sound cheerful!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 8, "label": "Major 3rd (C to E)"}
		),

		# Step 6: Visual — perfect 5th (C to G)
		LMD.create_visual_step(
			"The Perfect 5th in a Major Chord",
			"Now add the second interval: C up to G. That's a perfect 5th — seven semitones. Together with the major 3rd, these three notes (C-E-G) make a complete major chord!",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 6, "label": "Perfect 5th (C to G)"}
		),

		# Step 7: Minor triad
		LMD.create_explanation_step(
			"The Minor Triad",
			"A minor triad uses a root, a minor 3rd (3 semitones up), and a perfect 5th (7 semitones up). It sounds sad or dark — like a rainy day or a lullaby. C minor is C, Eb, and G. The only difference from major is that the 3rd is one semitone lower!",
			"Minor = Root + Minor 3rd + Perfect 5th",
			"Example: C-Eb-G. Just lowering the 3rd by one semitone changes happy to sad!"
		),

		# Step 8: Visual — minor 3rd (C to Eb)
		LMD.create_visual_step(
			"The Minor 3rd in a Minor Chord",
			"Here's the key difference: C up to Eb is a minor 3rd — only three semitones instead of four. That one semitone less makes the whole chord sound darker and more melancholy.",
			"interval_on_staff",
			{"clef": "treble", "note1_step": 10, "note2_step": 8, "label": "Minor 3rd (C to Eb)", "note2_accidental": "flat"}
		),

		# Step 9: Major vs minor
		LMD.create_explanation_step(
			"Major vs Minor — One Note Changes Everything",
			"The amazing thing about major and minor chords is that only ONE note is different! In C major you play C-E-G. In C minor you play C-Eb-G. That single semitone drop on the 3rd flips the mood completely. Major = bright and happy. Minor = dark and sad.",
			"Major 3rd → Happy  |  Minor 3rd → Sad",
			"Tip: If a chord sounds like a celebration, it's probably major. If it sounds wistful or emotional, it's probably minor."
		),

		# Step 10: Diminished triad
		LMD.create_explanation_step(
			"The Diminished Triad",
			"The diminished triad takes things further — both the 3rd AND the 5th are lowered. It uses a root, a minor 3rd (3 semitones), and a diminished 5th (6 semitones). It sounds tense and unstable, like something spooky or suspenseful. C diminished is C, Eb, and Gb.",
			"Diminished = Root + Minor 3rd + Diminished 5th",
			"Example: C-Eb-Gb. The shrunk 5th creates an uneasy, 'leaning' sound that wants to resolve."
		),

		# Step 11: Comparing all three
		LMD.create_explanation_step(
			"Three Triads Compared",
			"Let's line them all up! Major (C-E-G) sounds happy. Minor (C-Eb-G) sounds sad. Diminished (C-Eb-Gb) sounds tense. Notice the pattern: each one lowers one more note. Major is the brightest, diminished is the darkest.",
			"Major → Minor → Diminished (bright to dark)",
			"Major: 4+3 semitones. Minor: 3+4 semitones. Diminished: 3+3 semitones."
		),

		# Step 12: How to hear the difference
		LMD.create_explanation_step(
			"Hearing the Difference",
			"Here's a trick for telling chords apart by ear. Ask yourself: does it sound happy and settled? That's major. Does it sound sad but stable? That's minor. Does it sound tense, like it needs to go somewhere? That's diminished. With practice, you'll recognize them instantly!",
			"Happy = Major  |  Sad = Minor  |  Tense = Diminished",
			"Try the Chord Ear Training mode to practice hearing these differences!"
		),

		# Step 13: Recap
		LMD.create_recap_step(
			"Chord Basics Review!",
			"Awesome work! Here's what we covered about chords:",
			[
				{"label": "Chord", "detail": "Three or more notes played together — the foundation of harmony."},
				{"label": "Triad", "detail": "A three-note chord built from a root, 3rd, and 5th."},
				{"label": "Major Triad", "detail": "Root + major 3rd + perfect 5th — sounds happy and bright. (C-E-G)"},
				{"label": "Minor Triad", "detail": "Root + minor 3rd + perfect 5th — sounds sad and dark. (C-Eb-G)"},
				{"label": "Diminished Triad", "detail": "Root + minor 3rd + diminished 5th — sounds tense. (C-Eb-Gb)"},
				{"label": "Key Difference", "detail": "Major vs minor differs by just one semitone on the 3rd!"},
			]
		),

		# Step 14: Quiz — what is a chord?
		LMD.create_quiz_step(
			"What is a chord?",
			["A single note held for a long time", "Two notes played one after another", "Three or more notes played at the same time", "A type of rhythm pattern"],
			2,
			"That's right! A chord is three or more notes sounding together. Great memory!",
			"Not quite — remember, a chord needs multiple notes ringing at the same time. Try again!"
		),

		# Step 15: Quiz — major triad formula
		LMD.create_quiz_step(
			"A major triad is built from...?",
			["Root + minor 3rd + perfect 5th", "Root + major 3rd + perfect 5th", "Root + major 3rd + diminished 5th", "Root + perfect 4th + perfect 5th"],
			1,
			"Spot on! Major = root + major 3rd + perfect 5th. That major 3rd is what makes it bright!",
			"Think about which interval gives the major chord its 'happy' sound. Try again!"
		),

		# Step 16: Quiz — which notes in C minor?
		LMD.create_quiz_step(
			"Which notes make up C minor?",
			["C - E - G", "C - Eb - Gb", "C - Eb - G", "C - E - Gb"],
			2,
			"Well done! C minor is C-Eb-G. The minor 3rd (Eb) makes it sound sad, but the 5th stays perfect.",
			"Remember: minor lowers the 3rd but keeps the 5th the same as major. Try again!"
		),

		# Step 17: Quiz — happy or sad?
		LMD.create_quiz_step(
			"A chord that sounds happy and bright is most likely...?",
			["Diminished", "Minor", "Major", "It's impossible to tell"],
			2,
			"Great ear! Happy and bright = major. You're getting the hang of this!",
			"Think about our mood associations: happy goes with which chord type? Try again!"
		),

		# Step 18: Quiz — diminished triad
		LMD.create_quiz_step(
			"What makes a diminished triad sound tense?",
			["It uses a major 3rd", "Both the 3rd and 5th are lowered", "It has four notes", "The root is sharped"],
			1,
			"Exactly! The diminished triad lowers both the 3rd and the 5th, creating that uneasy tension.",
			"Think about what makes diminished different from minor — what extra note gets lowered? Try again!"
		),

		# Step 19: Drag symbol — match major to its sound
		LMD.create_drag_symbol_step(
			"Match the chord type to its sound! Which one sounds happy and bright, like the start of 'Happy Birthday'?",
			"Major",
			["Tense, unstable sound", "Happy, bright sound", "Sad, dark sound", "No particular mood"],
			1,
			"Perfect match! Major chords have that unmistakable happy, bright quality.",
			"Think about the mood we associated with major chords throughout the lesson. Try again!"
		),

		# Step 20: Quiz — difference between major and minor
		LMD.create_quiz_step(
			"How does C major (C-E-G) differ from C minor (C-Eb-G)?",
			["The root changes", "The 5th is lowered by a semitone", "The 3rd is lowered by a semitone", "All three notes are different"],
			2,
			"Nailed it! The only difference is the 3rd — E becomes Eb, one semitone lower. That's all it takes to flip happy to sad!",
			"Compare the two chords note by note: C-E-G vs C-Eb-G. Which note changed? Try again!"
		),
	]

	# ── Keyboard Quiz: Find chord tones ──
	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "E4", 8, "E4", "",
		"That's E — the major 3rd of a C major chord! C-E-G.",
		"Find the 3rd of C major — the note E. It's two white keys above C."
	))

	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "Eb4", 8, "Eb4", "flat",
		"You found Eb — the minor 3rd of C minor! C-Eb-G.",
		"Find Eb — it's the black key just below E. This makes C minor!"
	))

	# ── Listening Quiz ──
	steps.append(LMD.create_listening_quiz_step(
		"Hear the Chords!",
		"Listen to these chords and identify whether they sound major, minor, or diminished!",
		[
			{"note_ids": ["C4", "E4", "G4"], "label": "Major", "choices": ["Major", "Minor", "Diminished"], "correct_index": 0},
			{"note_ids": ["C4", "Eb4", "G4"], "label": "Minor", "choices": ["Major", "Minor", "Diminished"], "correct_index": 1},
			{"note_ids": ["C4", "Eb4", "Gb4"], "label": "Diminished", "choices": ["Major", "Minor", "Diminished"], "correct_index": 2},
			{"note_ids": ["D4", "F#4", "A4"], "label": "Major", "choices": ["Major", "Minor", "Diminished"], "correct_index": 0},
			{"note_ids": ["D4", "F4", "A4"], "label": "Minor", "choices": ["Major", "Minor", "Diminished"], "correct_index": 1},
		]
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Chord Practice",
		"Let's review everything about chords! Answer as many as you can!",
		LMD.chord_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You're a chord builder! You know the three main chord types and how they sound!",
		[
			{"label": "Major Triad", "detail": "Bright and happy — C, E, G"},
			{"label": "Minor Triad", "detail": "Sad and dark — C, Eb, G"},
			{"label": "Diminished Triad", "detail": "Tense and unstable — C, Eb, Gb"},
			{"label": "The 3rd", "detail": "Major vs minor = one semitone difference on the 3rd"},
		]
	))

	return LMD.create_module(
		"chord_basics",
		"Chord Basics",
		"Learn major, minor, and diminished triads",
		"",
		steps,
		10,
		"Chord Builder"
	)
