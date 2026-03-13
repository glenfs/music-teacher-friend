extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array = [
		LMD.create_intro_step(
			"Time Signatures!",
			"Let's learn about time signatures! They tell you how to count the beats in music.",
			"Time signatures appear at the start of a piece."
		),

		LMD.create_visual_step(
			"What It Looks Like",
			"A time signature is two numbers stacked on top of each other, right after the clef. Here's the most common one!",
			"time_signature",
			{"top": 4, "bottom": 4}
		),

		LMD.create_explanation_step(
			"The Top Number",
			"The top number tells you HOW MANY beats are in each measure. In 4/4, there are 4 beats per measure!",
			"Top Number = How Many Beats",
			"Think of it like clapping: 1, 2, 3, 4!"
		),

		LMD.create_explanation_step(
			"The Bottom Number",
			"The bottom number tells you WHICH NOTE gets one beat. A 4 on the bottom means a quarter note gets one beat.",
			"Bottom Number = Which Note Gets a Beat",
			"4 = quarter note, 8 = eighth note."
		),

		LMD.create_visual_step(
			"4/4 Time",
			"4/4 is the most common time signature. Four beats per measure, and a quarter note gets one beat. Count: 1, 2, 3, 4!",
			"time_signature",
			{"top": 4, "bottom": 4}
		),

		LMD.create_visual_step(
			"3/4 Time",
			"3/4 has three beats per measure. This is the rhythm of a waltz! Count: 1, 2, 3!",
			"time_signature",
			{"top": 3, "bottom": 4}
		),

		LMD.create_visual_step(
			"2/4 Time",
			"2/4 has two beats per measure. It sounds like a march! Count: 1, 2!",
			"time_signature",
			{"top": 2, "bottom": 4}
		),

		# Quiz
		LMD.create_quiz_step(
			"In 4/4 time, how many beats are in each measure?",
			["2", "3", "4"],
			2,
			"Right! 4/4 means 4 beats per measure!",
			"Look at the top number -- that tells you how many beats!"
		),

		LMD.create_quiz_step(
			"In 3/4 time, how many beats per measure?",
			["3", "4", "6"],
			0,
			"Yes! 3/4 is three beats -- like a waltz!",
			"The top number is 3, so there are 3 beats!"
		),

		LMD.create_quiz_step(
			"What does the top number in a time signature tell you?",
			["How many beats per measure", "Which note gets a beat", "How fast to play"],
			0,
			"Correct! The top number = how many beats!",
			"The TOP number tells you how MANY beats."
		),

		LMD.create_quiz_step(
			"Which time signature is used for a waltz?",
			["4/4", "3/4", "2/4"],
			1,
			"That's it! Waltzes use 3/4 time: 1-2-3, 1-2-3!",
			"A waltz has 3 beats per measure. Which one is that?"
		),

		LMD.create_recap_step(
			"Time Signatures Review",
			"Well done! Here's what you learned about time signatures:",
			[
				{"label": "Top Number", "detail": "Tells you how many beats per measure.", "clef": "treble"},
				{"label": "Bottom Number", "detail": "Tells you which note gets one beat (4 = quarter note).", "clef": "treble"},
				{"label": "Common Ones", "detail": "4/4 (four beats), 3/4 (waltz), 2/4 (march).", "clef": "treble"},
			]
		),
	]

	return LMD.create_module(
		"time_signatures",
		"Time Signatures",
		"Learn how rhythm is organized",
		"",
		steps
	)
