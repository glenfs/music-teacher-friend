extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"Key Signatures!",
			"Welcome back! You already know about sharps and flats — now let's see how music uses them in a really clever way called a key signature. It saves a LOT of writing!",
			"Key signatures keep sheet music clean and simple."
		),

		# Step 2: What is a key signature?
		LMD.create_explanation_step(
			"What Is a Key Signature?",
			"A key signature is a set of sharps or flats written at the very beginning of a piece, right after the clef. It tells you which notes are ALWAYS sharp or flat throughout the whole piece — so you don't have to write the symbol every single time!",
			"Key Signature = Sharps or Flats at the Start",
			"It applies to every note with that letter name in the entire piece."
		),

		# Step 3: Why they exist
		LMD.create_explanation_step(
			"Why Do We Need Them?",
			"Imagine a piece in G Major where every F is sharp. Without a key signature, you'd have to write a tiny # next to every single F! That would get messy fast. The key signature says 'all F notes are sharp' once, and you're done!",
			"Saves writing # or ♭ on every note",
			"One marking at the start replaces dozens throughout the piece."
		),

		# Step 4: C Major — no sharps or flats
		LMD.create_explanation_step(
			"C Major — The Simple One",
			"Let's start easy! C Major has NO sharps and NO flats. Its key signature is completely empty — just the clef and nothing else. That's why beginners often learn C Major first!",
			"C Major = No sharps, no flats",
			"All the white keys on a piano, from C to C."
		),

		# Step 5: G Major visual
		LMD.create_visual_step(
			"G Major — One Sharp",
			"Here's G Major! It has one sharp: F#. See the sharp symbol on the F line? This means every F in the piece is played as F-sharp, without needing to write it each time.",
			"key_signature_visual",
			{"key": "G", "sharps": ["F"], "flats": []}
		),

		# Step 6: Explain G Major
		LMD.create_explanation_step(
			"Understanding G Major",
			"In the key of G Major, the note F is raised to F-sharp. This one small change gives G Major its bright, happy sound. If you play all the white keys from G to G but change every F to F#, that's the G Major scale!",
			"G Major: F → F#",
			"One sharp makes all the difference in the sound."
		),

		# Step 7: F Major visual
		LMD.create_visual_step(
			"F Major — One Flat",
			"Now let's look at F Major! It has one flat: B-flat. See the flat symbol on the B line? Every B in this piece becomes B-flat.",
			"key_signature_visual",
			{"key": "F", "sharps": [], "flats": ["B"]}
		),

		# Step 8: Explain F Major
		LMD.create_explanation_step(
			"Understanding F Major",
			"In F Major, the note B is lowered to B-flat. This gives F Major a warm, smooth sound. Play all the white keys from F to F but change every B to Bb, and you've got the F Major scale!",
			"F Major: B → B♭",
			"One flat creates a gentler, warmer colour."
		),

		# Step 9: D Major visual
		LMD.create_visual_step(
			"D Major — Two Sharps",
			"D Major has two sharps: F# and C#. See how a second sharp was added? Each new sharp key adds one more sharp!",
			"key_signature_visual",
			{"key": "D", "sharps": ["F", "C"], "flats": []}
		),

		# Step 10: A Major visual
		LMD.create_visual_step(
			"A Major — Three Sharps",
			"A Major has three sharps: F#, C#, and G#. The pattern continues — one more sharp each time!",
			"key_signature_visual",
			{"key": "A", "sharps": ["F", "C", "G"], "flats": []}
		),

		# Step 11: Sharp key pattern
		LMD.create_explanation_step(
			"The Sharp Key Pattern",
			"Notice how sharp keys grow: G has 1 sharp, D has 2, A has 3. Each new key adds one more sharp. The sharps always arrive in the same order: F, C, G, D, A, E, B!",
			"G(1#) → D(2#) → A(3#)",
			"Sharps always appear in order: F, C, G, D, A, E, B."
		),

		# Step 12: Bb Major visual
		LMD.create_visual_step(
			"B♭ Major — Two Flats",
			"B♭ Major has two flats: B♭ and E♭. Just like with sharps, flat keys grow one flat at a time!",
			"key_signature_visual",
			{"key": "Bb", "sharps": [], "flats": ["B", "E"]}
		),

		# Step 13: Eb Major visual
		LMD.create_visual_step(
			"E♭ Major — Three Flats",
			"E♭ Major has three flats: B♭, E♭, and A♭. See the pattern? Each new flat key adds one more flat!",
			"key_signature_visual",
			{"key": "Eb", "sharps": [], "flats": ["B", "E", "A"]}
		),

		# Step 14: Flat key pattern
		LMD.create_explanation_step(
			"The Flat Key Pattern",
			"Flat keys grow the same way! F has 1 flat, B♭ has 2, E♭ has 3. Flats arrive in their own order: B, E, A, D, G, C, F — the exact reverse of the sharp order!",
			"F(1♭) → B♭(2♭) → E♭(3♭)",
			"Flats always appear in order: B, E, A, D, G, C, F."
		),

		# Step 15: Circle of fifths (light intro)
		LMD.create_explanation_step(
			"The Circle of Fifths",
			"Musicians organize all the keys in a circle called the Circle of Fifths. Going clockwise, each key adds one sharp. Going counter-clockwise, each key adds one flat. C Major sits at the top with no sharps or flats!",
			"C → G → D → A  (sharps)\nC → F → B♭ → E♭  (flats)",
			"You don't need to memorize the whole circle yet — just know the pattern exists!"
		),

		# Step 16: Sharps vs flats rule
		LMD.create_explanation_step(
			"Sharps and Flats Don't Mix!",
			"Here's a neat rule: a key signature has EITHER sharps OR flats — never both! Sharp keys and flat keys are like two different families.",
			"Sharps OR Flats — never both",
			"More sharps or flats = more notes changed from the basic C Major scale."
		),

		# Step 17: Recap
		LMD.create_recap_step(
			"Key Signature Review!",
			"Wonderful! Here's everything we covered about key signatures:",
			[
				{"label": "C Major", "detail": "No sharps, no flats — the simplest key."},
				{"label": "G Major", "detail": "1 sharp: F#"},
				{"label": "D Major", "detail": "2 sharps: F#, C#"},
				{"label": "A Major", "detail": "3 sharps: F#, C#, G#"},
				{"label": "F Major", "detail": "1 flat: B♭"},
				{"label": "B♭ Major", "detail": "2 flats: B♭, E♭"},
				{"label": "E♭ Major", "detail": "3 flats: B♭, E♭, A♭"},
				{"label": "Rule", "detail": "A key has sharps OR flats, never both."},
			]
		),

		# Step 18: Quiz — what does a key signature do?
		LMD.create_quiz_step(
			"What does a key signature do?",
			["Shows the tempo", "Tells you which notes are always sharp or flat", "Names the instrument", "Sets the volume"],
			1,
			"Well done! A key signature tells you which notes are sharp or flat for the whole piece.",
			"Not quite — think about what sharps and flats at the beginning tell us. Try again!"
		),

		# Step 19: Quiz — sharps in D Major
		LMD.create_quiz_step(
			"How many sharps does D Major have?",
			["1", "2", "3", "4"],
			1,
			"That's correct! D Major has two sharps — F# and C#.",
			"Hmm, D is one step past G on the circle. G has 1 sharp, so D has... Try again!"
		),

		# Step 20: Quiz — which note is flat in F Major
		LMD.create_quiz_step(
			"Which note is flat in F Major?",
			["E", "F", "A", "B"],
			3,
			"Awesome! B-flat is the one flat in F Major.",
			"Close, but not quite! F Major has one flat — think about which note it changes. Try again!"
		),

		# Step 21: Quiz — identify Eb Major
		LMD.create_quiz_step(
			"If you see 3 flats at the start of a piece, the key is likely...?",
			["F Major", "B♭ Major", "E♭ Major", "A♭ Major"],
			2,
			"Great job! Three flats means E♭ Major!",
			"Count the flats: F=1, B♭=2, E♭=3. Which one has 3? Try again!"
		),

		# Step 22: Quiz — sharps and flats mixing
		LMD.create_quiz_step(
			"Can a key signature have BOTH sharps and flats?",
			["Yes, always", "No, never", "Only in bass clef", "Only for piano"],
			1,
			"Great job! A key signature uses sharps OR flats — never both at the same time.",
			"Almost! Remember the rule we learned about the two 'families.' Try again!"
		),

		# Step 23: Quiz — A Major sharps
		LMD.create_quiz_step(
			"Which notes are sharp in A Major?",
			["F# only", "F# and C#", "F#, C#, and G#", "All notes"],
			2,
			"Correct! A Major has three sharps: F#, C#, and G#.",
			"A Major is 3 steps around the circle. Remember: sharps arrive as F, C, G... Try again!"
		),
	]

	# ── Keyboard Quiz: Find key signature notes ──
	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "F#4", 7, "F#4", "sharp",
		"That's F#! The one sharp in the key of G Major!",
		"Find F# — it's the black key just above F. G Major has this one sharp."
	))

	steps.append(LMD.create_keyboard_quiz_step(
		"treble", "Bb4", 4, "Bb4", "flat",
		"You found Bb! The one flat in the key of F Major!",
		"Find Bb — it's the black key just below B. F Major has this one flat."
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Key Signature Practice",
		"Let's review key signatures! How well do you know your sharps and flats?",
		LMD.key_sig_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You understand key signatures! From C Major all the way to A Major and E♭ Major!",
		[
			{"label": "Sharp Keys", "detail": "G(1#) → D(2#) → A(3#). Sharps arrive: F, C, G..."},
			{"label": "Flat Keys", "detail": "F(1♭) → B♭(2♭) → E♭(3♭). Flats arrive: B, E, A..."},
			{"label": "C Major", "detail": "No sharps, no flats — sits at the top of the circle"},
			{"label": "Rule", "detail": "Sharps OR flats — never both!"},
		]
	))

	return LMD.create_module(
		"key_signatures",
		"Key Signatures",
		"Learn C, G, D, A, F, B♭, and E♭ Major key signatures",
		"",
		steps,
		12,
		"Key Explorer"
	)
