extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"The Grand Staff!",
			"You've learned the treble clef and the bass clef separately — now let's put them TOGETHER! When you join them up, you get something really special called the Grand Staff.",
			"Two staves are better than one!"
		),

		# Step 2: What is the grand staff?
		LMD.create_explanation_step(
			"What Is the Grand Staff?",
			"The Grand Staff is made by stacking a treble clef staff on top of a bass clef staff and connecting them with a big curly bracket called a brace. Together they can show a huge range of notes — from very low to very high!",
			"Grand Staff = Treble + Bass + Brace",
			"A brace on the left connects both staves into one system."
		),

		# Step 3: Grand staff visual
		LMD.create_visual_step(
			"See the Grand Staff",
			"Here it is! The treble clef sits on top and the bass clef sits on the bottom. Notice the brace on the left that ties them together. This is what piano music looks like!",
			"grand_staff_visual",
			{"show_middle_c": false}
		),

		# Step 4: Who uses it?
		LMD.create_explanation_step(
			"Who Uses the Grand Staff?",
			"Piano players use the Grand Staff all the time! Your right hand usually plays the treble clef (the higher notes) and your left hand plays the bass clef (the lower notes). It's like reading two lines at once!",
			"Right hand = Treble, Left hand = Bass",
			"Piano, organ, and harp commonly use the Grand Staff."
		),

		# Step 5: Middle C — the bridge
		LMD.create_visual_step(
			"Meet Middle C!",
			"Middle C is the note right between the two staves. It sits on its own tiny ledger line — a short extra line just for that one note. Middle C is like a bridge connecting the treble and bass worlds!",
			"grand_staff_visual",
			{"show_middle_c": true}
		),

		# Step 6: Explain middle C
		LMD.create_explanation_step(
			"Middle C — The Center of Music",
			"Middle C is special because it can be written in EITHER clef! On the treble staff it's just below the bottom line (on a ledger line). On the bass staff it's just above the top line (also on a ledger line). Same note, two ways to write it!",
			"Middle C = Ledger line between both staves",
			"It's the note right in the middle of a piano keyboard too."
		),

		# Step 7: Notes across both staves
		LMD.create_visual_step(
			"Notes on the Grand Staff",
			"Look — notes can appear on either staff! Higher notes go on the treble staff, lower notes go on the bass staff. Together, the Grand Staff covers a huge range of music.",
			"grand_staff_visual",
			{"show_middle_c": true, "show_notes": ["C4", "E4", "G3"]}
		),

		# Step 8: Reading both at once
		LMD.create_explanation_step(
			"Reading Both Staves",
			"When you read piano music, your eyes learn to look at both staves at the same time. Don't worry — it takes practice! Start by reading each hand separately, then slowly put them together.",
			"Practice each hand, then combine",
			"Even professional pianists started by reading one staff at a time."
		),

		# Step 9: Drag Middle C on treble staff
		LMD.create_drag_note_step(
			"Place Middle C on the treble staff — it goes on the ledger line below!",
			"treble", "C4", 10, true,
			"Perfect! Middle C sits on its own ledger line below the treble staff.",
			"Middle C goes on the small ledger line just below the bottom of the treble staff."
		),

		# Step 10: Drag Middle C on bass staff
		LMD.create_drag_note_step(
			"Now place Middle C on the bass staff — it goes above!",
			"bass", "C4", -2, true,
			"Right! Middle C on its ledger line above the bass staff.",
			"In bass clef, Middle C sits on the ledger line just above the top of the staff."
		),

		# Step 11: Recap
		LMD.create_recap_step(
			"Grand Staff Review!",
			"Fantastic! Here's what we learned about the Grand Staff:",
			[
				{"label": "Grand Staff", "detail": "Treble staff + Bass staff connected by a brace."},
				{"label": "Treble (top)", "detail": "Higher notes — usually played by the right hand."},
				{"label": "Bass (bottom)", "detail": "Lower notes — usually played by the left hand."},
				{"label": "Middle C", "detail": "Sits on a ledger line between both staves."},
			]
		),

		# Step 10: Quiz — what connects the staves?
		LMD.create_quiz_step(
			"What connects the two staves in a Grand Staff?",
			["A clef", "A brace", "A bar line", "A rest"],
			1,
			"Excellent! A brace connects the treble and bass staves together.",
			"Not quite — it's the big curly bracket on the left side. Try again!"
		),

		# Step 11: Quiz — which hand reads treble?
		LMD.create_quiz_step(
			"Which hand typically reads the treble clef?",
			["Left hand", "Right hand", "Both hands", "Neither hand"],
			1,
			"That's right! The right hand usually plays the treble clef — the higher notes.",
			"Hmm, think about which hand plays the higher notes on a piano. Try again!"
		),

		# Step 12: Quiz — where is middle C?
		LMD.create_quiz_step(
			"Where does Middle C sit on the Grand Staff?",
			["On the top line of the treble staff", "On a ledger line between both staves", "On the bottom line of the bass staff", "It doesn't appear on the Grand Staff"],
			1,
			"Well done! Middle C sits on its own ledger line right between the two staves.",
			"Close, but not quite. Middle C has its own special spot between the staves. Try again!"
		),

		# Step 13: Quiz — what instrument uses grand staff?
		LMD.create_quiz_step(
			"Which instrument commonly uses the Grand Staff?",
			["Trumpet", "Violin", "Piano", "Flute"],
			2,
			"Great job! Piano music is written on the Grand Staff because pianists play both high and low notes. You're a Grand Staff Guide!",
			"Think about which instrument needs BOTH treble and bass clef at the same time. Try again!"
		),
	]

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Grand Staff Practice",
		"Let's review the grand staff! Show me what you've learned!",
		LMD.grand_staff_theory_pool(),
		4,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've learned how the grand staff works! Pianists use it every day!",
		[
			{"label": "Grand Staff", "detail": "Treble + bass clef joined by a brace"},
			{"label": "Middle C", "detail": "The bridge between the two staves"},
			{"label": "Right Hand", "detail": "Usually plays the treble (top) staff"},
			{"label": "Left Hand", "detail": "Usually plays the bass (bottom) staff"},
		]
	))

	return LMD.create_module(
		"grand_staff",
		"Grand Staff",
		"Learn how treble and bass clefs work together",
		"",
		steps,
		6,
		"Grand Staff Guide"
	)
