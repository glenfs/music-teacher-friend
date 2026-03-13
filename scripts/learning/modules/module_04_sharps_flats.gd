extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		LMD.create_intro_step(
			"Sharps & Flats",
			"Time to learn about sharps and flats! These little symbols change how a note sounds.",
			"They're called accidentals."
		),

		# Sharp
		LMD.create_visual_step(
			"The Sharp Sign",
			"This is a sharp sign. It looks like a hashtag! When you see it, the note goes UP a tiny step.",
			"symbol_large",
			{"symbol": "#", "label": "Sharp", "color": "gold"}
		),

		LMD.create_explanation_step(
			"What Does Sharp Do?",
			"A sharp raises a note by one half step. That's the smallest step in music. Think of it like climbing one tiny stair up!",
			"Sharp = Go UP one half step",
			"F sharp is one tiny step higher than F."
		),

		# Flat
		LMD.create_visual_step(
			"The Flat Sign",
			"This is a flat sign. It looks like a lowercase b! When you see it, the note goes DOWN a tiny step.",
			"symbol_large",
			{"symbol": "b", "label": "Flat", "color": "blue"}
		),

		LMD.create_explanation_step(
			"What Does Flat Do?",
			"A flat lowers a note by one half step. Think of it like stepping one tiny stair down!",
			"Flat = Go DOWN one half step",
			"B flat is one tiny step lower than B."
		),

		# Compare
		LMD.create_explanation_step(
			"Sharp vs Flat",
			"So remember: sharp goes UP, flat goes DOWN. They're opposites!",
			"Sharp = UP    Flat = DOWN",
			"A sharp raises the pitch. A flat lowers it."
		),

		# Interactive: identify the symbol
		LMD.create_quiz_step(
			"Which symbol RAISES a note?",
			["Sharp #", "Flat b"],
			0,
			"Yes! A sharp raises the note up!",
			"Remember: sharp = UP, like climbing stairs!"
		),

		LMD.create_quiz_step(
			"Which symbol LOWERS a note?",
			["Sharp #", "Flat b"],
			1,
			"Correct! A flat lowers the note down!",
			"Flat = DOWN, like stepping down!"
		),

		LMD.create_quiz_step(
			"If you see F#, what happened to the F?",
			["It went up a half step", "It went down a half step", "Nothing changed"],
			0,
			"Right! F# is one half step higher than F!",
			"The # symbol means sharp -- it raises the note!"
		),

		LMD.create_quiz_step(
			"If you see Bb, what happened to the B?",
			["It went up", "It went down", "It stayed the same"],
			1,
			"Yes! Bb is one half step lower than B!",
			"The b symbol means flat -- it lowers the note!"
		),

		LMD.create_recap_step(
			"Sharps & Flats Review",
			"You now know the basics of sharps and flats! Here's a summary:",
			[
				{"label": "Sharp  #", "detail": "Raises a note by one half step (go UP).", "clef": "treble"},
				{"label": "Flat  b", "detail": "Lowers a note by one half step (go DOWN).", "clef": "bass"},
			]
		),
	]

	return LMD.create_module(
		"sharps_flats",
		"Sharps & Flats",
		"Learn about accidentals",
		"",
		steps
	)
