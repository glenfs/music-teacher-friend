extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro — meet the clefs
		LMD.create_intro_step(
			"Meet the Clefs!",
			"Hi there! I'm going to teach you about clef signs — the symbols at the start of every piece of music. Let's go!",
			"Every piece of music starts with a clef."
		),

		# Step 2: Show treble clef large
		LMD.create_visual_step(
			"The Treble Clef",
			"This is the Treble Clef. It's the most common clef you'll see!",
			"clef_symbol",
			{"clef": "treble"}
		),

		# Step 3: Treble clef on staff
		LMD.create_visual_step(
			"Treble Clef on the Staff",
			"Here's where the Treble Clef sits on the five-line staff. It always goes right at the beginning!",
			"clef_on_staff",
			{"clef": "treble"}
		),

		# Step 4: Explain G clef
		LMD.create_explanation_step(
			"The G Clef",
			"The Treble Clef is also called the G Clef. See how its curl wraps around the second line? That line is the note G!",
			"Treble Clef = G Clef",
			"The curly part of the clef wraps around the G line."
		),

		# Step 5: Intro bass clef
		LMD.create_intro_step(
			"Now for the Bass Clef!",
			"Great job! Now let's learn the other important clef — the Bass Clef. It's used for lower notes.",
			"The Bass Clef handles the low notes."
		),

		# Step 6: Show bass clef large
		LMD.create_visual_step(
			"The Bass Clef",
			"This is the Bass Clef. Notice the two dots on the right side!",
			"clef_symbol",
			{"clef": "bass"}
		),

		# Step 7: Bass clef on staff
		LMD.create_visual_step(
			"Bass Clef on the Staff",
			"Here's the Bass Clef sitting on the staff. It looks different from the Treble Clef!",
			"clef_on_staff",
			{"clef": "bass"}
		),

		# Step 8: Explain F clef
		LMD.create_explanation_step(
			"The F Clef",
			"The Bass Clef is also called the F Clef. Its two dots sit on either side of the fourth line — that line is the note F!",
			"Bass Clef = F Clef",
			"The two dots surround the F line."
		),

		# Step 9: Recap both
		LMD.create_recap_step(
			"Let's Review!",
			"Awesome! Let's put it all together. Here's what we learned:",
			[
				{"label": "Treble Clef", "detail": "Also called the G Clef. Its curl wraps around G.", "clef": "treble"},
				{"label": "Bass Clef", "detail": "Also called the F Clef. Its dots surround F.", "clef": "bass"},
			]
		),

		# Step 10: Quiz — which is G clef?
		LMD.create_quiz_step(
			"Which clef is also called the G Clef?",
			["Treble Clef", "Bass Clef"],
			0,
			"Yes! The Treble Clef is the G Clef because its curl wraps around G!",
			"Hmm, not quite. Remember — the Treble Clef curls around the G line!"
		),

		# Step 11: Quiz — which is F clef?
		LMD.create_quiz_step(
			"Which clef is also called the F Clef?",
			["Treble Clef", "Bass Clef"],
			1,
			"Correct! The Bass Clef is the F Clef because its dots surround F!",
			"Not this time. The Bass Clef's two dots mark the F line!"
		),
	]

	return LMD.create_module(
		"clef_signs",
		"Clef Signs",
		"Learn the Treble and Bass clefs",
		"",
		steps,
		5,
		"Music Basics"
	)
