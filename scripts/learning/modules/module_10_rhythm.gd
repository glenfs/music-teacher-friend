extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		# Step 1: Intro
		LMD.create_intro_step(
			"Let's Learn Rhythm!",
			"Hey! Music isn't just about which notes to play — it's also about WHEN to play them and how LONG to hold them. That's rhythm! Let's dive in!",
			"Rhythm is the heartbeat of music."
		),

		# Step 2: Explain beats
		LMD.create_explanation_step(
			"What Are Beats?",
			"Think of beats like a steady clap — clap, clap, clap, clap. Most music groups these claps into sets of four. That's called 4/4 time!",
			"4/4 Time = 4 beats per bar",
			"Each group of 4 beats is called a bar or measure."
		),

		# Step 3: Whole note visual
		LMD.create_visual_step(
			"The Whole Note",
			"This is a Whole Note. It lasts for 4 whole beats — that's an entire bar all by itself! Hold it nice and long.",
			"rhythm_value",
			{"value": "whole", "beats": 4, "symbol": "𝅝"}
		),

		# Step 4: Half note visual
		LMD.create_visual_step(
			"The Half Note",
			"This is a Half Note. It lasts for 2 beats — exactly half of a whole note. You can fit two of these in one bar!",
			"rhythm_value",
			{"value": "half", "beats": 2, "symbol": "𝅗𝅥"}
		),

		# Step 5: Quarter note visual
		LMD.create_visual_step(
			"The Quarter Note",
			"This is the Quarter Note — the most common note in music! It gets 1 beat. Four quarter notes fill up one bar perfectly.",
			"rhythm_value",
			{"value": "quarter", "beats": 1, "symbol": "♩"}
		),

		# Step 6: Eighth note visual
		LMD.create_visual_step(
			"The Eighth Note",
			"This is an Eighth Note. It's quick — only half a beat! You need eight of these to fill a bar. They often come in pairs with a beam connecting them.",
			"rhythm_value",
			{"value": "eighth", "beats": 0.5, "symbol": "♪"}
		),

		# Step 7: How they relate
		LMD.create_explanation_step(
			"How They Fit Together",
			"Here's a fun pattern: each note is exactly half as long as the one before it. A whole note splits into 2 halves, a half splits into 2 quarters, and a quarter splits into 2 eighths!",
			"Whole → Half → Quarter → Eighth",
			"1 Whole = 2 Halves = 4 Quarters = 8 Eighths"
		),

		# Step 8: Filling a bar
		LMD.create_explanation_step(
			"Filling a Bar",
			"In 4/4 time, every bar must add up to exactly 4 beats. You can mix and match! For example: one half note (2) + two quarter notes (1+1) = 4 beats. Perfect!",
			"Every bar = 4 beats total",
			"Mix different note values as long as they add up to 4."
		),

		# Step 9: Time signature visual
		LMD.create_visual_step(
			"The Time Signature",
			"See those two numbers at the start? That's the time signature! The top number tells you how many beats per bar. The bottom tells you which note gets one beat. In 4/4, there are 4 beats and the quarter note gets 1 beat.",
			"time_signature",
			{"top": 4, "bottom": 4}
		),

		# Step 10: Rests
		LMD.create_explanation_step(
			"Don't Forget Rests!",
			"Sometimes music needs silence too! Rests tell you to be quiet for a certain number of beats. There's a rest for every note value — a whole rest (4 beats of silence), half rest (2 beats), quarter rest (1 beat), and eighth rest (half a beat).",
			"Rests = Musical Silence",
			"Rests last the same number of beats as their matching notes."
		),

		# Step 11: Recap
		LMD.create_recap_step(
			"Rhythm Review!",
			"Great work! Let's review what we learned about rhythm notation:",
			[
				{"label": "Whole Note (𝅝)", "detail": "4 beats — fills an entire bar in 4/4 time."},
				{"label": "Half Note (𝅗𝅥)", "detail": "2 beats — two of them fill a bar."},
				{"label": "Quarter Note (♩)", "detail": "1 beat — four fill a bar. The most common note!"},
				{"label": "Eighth Note (♪)", "detail": "Half a beat — eight fill a bar."},
				{"label": "Rests", "detail": "Silence! Each rest matches a note value."},
			]
		),

		# Step 12: Quiz — quarter note beats
		LMD.create_quiz_step(
			"How many beats does a quarter note get?",
			["Half a beat", "1 beat", "2 beats", "4 beats"],
			1,
			"Nice work! A quarter note gets exactly 1 beat.",
			"Not quite — think about the name. A quarter is one-fourth of a whole (4 beats). Try again!"
		),

		# Step 13: Quiz — whole note beats
		LMD.create_quiz_step(
			"Which note gets 4 beats?",
			["Eighth Note", "Quarter Note", "Half Note", "Whole Note"],
			3,
			"You got it! The whole note lasts 4 beats — a whole bar!",
			"Hmm, not that one. The biggest note value we learned gets 4 beats. Try again!"
		),

		# Step 14: Quiz — half notes in a bar
		LMD.create_quiz_step(
			"How many half notes fill a 4/4 bar?",
			["1", "2", "4", "8"],
			1,
			"Excellent! Two half notes (2 + 2 = 4 beats) fill one bar perfectly.",
			"Almost! A half note is 2 beats, and a bar has 4 beats. How many 2s make 4? Try again!"
		),

		# Step 15: Quiz — eighth note beats
		LMD.create_quiz_step(
			"How many beats does an eighth note get?",
			["Half a beat", "1 beat", "2 beats", "A quarter of a beat"],
			0,
			"That's correct! An eighth note lasts half a beat — nice and quick!",
			"Not quite. An eighth note is half of a quarter note (1 beat). Try again!"
		),

		# Step 16: Quiz — matching values
		LMD.create_quiz_step(
			"How many quarter notes equal one whole note?",
			["2", "3", "4", "8"],
			2,
			"Great job! 4 quarter notes = 1 whole note. You've got rhythm!",
			"Keep trying! A whole note is 4 beats, and each quarter note is 1 beat..."
		),
		# Step 17: Quiz — which combination fills a 4/4 bar? (2 half notes)
		LMD.create_quiz_step(
			"Which combination fills a 4/4 bar?",
			["3 quarter notes", "2 half notes", "1 half note + 1 quarter note", "5 eighth notes"],
			1,
			"That's right! 2 half notes = 2 + 2 = 4 beats. A full bar!",
			"Not quite — remember, a 4/4 bar needs exactly 4 beats total. Try again!"
		),

		# Step 18: Quiz — which combination fills a 4/4 bar? (1 whole note)
		LMD.create_quiz_step(
			"Which of these also fills a 4/4 bar?",
			["1 half note + 1 quarter note", "3 eighth notes", "1 whole note", "2 quarter notes"],
			2,
			"Correct! A whole note = 4 beats — it fills the entire bar by itself!",
			"Hmm, that doesn't add up to 4 beats. Think about how many beats each note is worth!"
		),
	]

	# ── Rhythm Tap Steps ──
	steps.append(LMD.create_rhythm_tap_step(
		"Tap the Beat — Quarter Notes",
		"Tap along with each quarter note beat! Try to stay in time.",
		[1.0, 1.0, 1.0, 1.0],
		90,
		4
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Tap the Beat — Mix It Up",
		"This time there's a half note followed by two quarter notes. Tap when each note starts!",
		[2.0, 1.0, 1.0],
		90,
		4
	))

	steps.append(LMD.create_rhythm_tap_step(
		"Waltz Time — 3/4",
		"Now try 3/4 time! That's 3 beats per bar. Tap a half note then a quarter note — feel the waltz!",
		[2.0, 1.0],
		84,
		3
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Rhythm Practice",
		"Let's drill those rhythm values! How well do you know your note lengths?",
		LMD.rhythm_theory_pool(),
		8,
		"theory"
	))

	# ── Final Recap ──
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"You've got the basics of rhythm down! Every note has a length, and now you know them!",
		[
			{"label": "Whole Note", "detail": "4 beats — fills a whole bar of 4/4"},
			{"label": "Half Note", "detail": "2 beats — two per bar"},
			{"label": "Quarter Note", "detail": "1 beat — four per bar"},
			{"label": "Eighth Note", "detail": "½ beat — eight per bar"},
			{"label": "Rests", "detail": "Silence counts too — each note type has a matching rest"},
		]
	))

	return LMD.create_module(
		"rhythm_notation",
		"Rhythm Notation",
		"Learn whole, half, quarter and eighth notes",
		"",
		steps,
		10,
		"Rhythm Rookie"
	)
