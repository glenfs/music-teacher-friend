extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── Hands-on staff exploration (action before theory) ──

	# 1 — Intro: jump right in
	steps.append(LMD.create_intro_step(
		"Touch the Staff!",
		"Before we learn any rules, let's explore! Music is written on five lines. Try dragging the note onto the staff!",
		"Explore the 5 Lines & 4 Spaces"
	))

	# 2 — Drag to 1st line (bottom, step 8)
	steps.append(LMD.create_drag_note_step(
		"See those 5 lines? The bottom one is the 1st line. Drag the note there!",
		"none",
		"1st Line",
		8,
		true,
		"Nice! That's the 1st line — the very bottom one!",
		"Not quite — the 1st line is at the bottom. Try the lowest line!"
	))

	# 3 — Drag to 2nd space (step 5)
	steps.append(LMD.create_drag_note_step(
		"The gaps between lines are called spaces. Drag the note to the 2nd space!",
		"none",
		"2nd Space",
		5,
		true,
		"You got it! Spaces sit between the lines!",
		"Almost! The 2nd space is between the 2nd and 3rd lines. Look for the gap!"
	))

	# 4 — Drag to 3rd line (middle, step 4)
	steps.append(LMD.create_drag_note_step(
		"Now find the middle line — that's the 3rd line. Drag the note there!",
		"none",
		"3rd Line",
		4,
		true,
		"Perfect! The 3rd line is right in the middle of the staff!",
		"Not quite — count from the bottom: 1, 2, 3. The middle line!"
	))

	# 5 — Drag to 4th space (step 1) — no hint
	steps.append(LMD.create_drag_note_step(
		"Getting the hang of it! Now try the 4th space — near the top. No hint this time!",
		"none",
		"4th Space",
		1,
		false,
		"Excellent! You found the 4th space — the highest gap on the staff!",
		"Close! The 4th space is between the 4th and 5th lines — near the top!"
	))

	# 6 — Drag to 5th line (top, step 0) — no hint
	steps.append(LMD.create_drag_note_step(
		"Last one! Drag the note to the very top line — the 5th line!",
		"none",
		"5th Line",
		0,
		false,
		"You nailed it! Now you know your way around the staff!",
		"Almost! The 5th line is at the very top!"
	))

	# 7 — Bridge: connect the experience to theory
	steps.append(LMD.create_explanation_step(
		"Lines & Spaces",
		"You just explored the musical staff! Every note in music sits on a line or in a space. Now let's learn the symbols that tell musicians which notes go where!",
		"5 Lines  ·  4 Spaces",
		"Lines are numbered 1–5 from bottom to top. Spaces are numbered 1–4 the same way. Each position is a different note!"
	))

	# ── Theory begins ──

	# 8 — Visual: treble clef symbol
	steps.append(LMD.create_visual_step(
		"The Treble Clef",
		"This curly symbol is the treble clef. You'll see it at the start of most melodies!",
		"clef_symbol",
		{"clef": "treble"}
	))

	# 3 — Visual: treble clef on staff
	steps.append(LMD.create_visual_step(
		"Treble Clef on the Staff",
		"Here's how the treble clef looks sitting on the five-line staff.",
		"clef_on_staff",
		{"clef": "treble"}
	))

	# 4 — Explanation: Treble = G Clef
	steps.append(LMD.create_explanation_step(
		"The G Clef",
		"The treble clef is also called the G Clef because its curl wraps around the 2nd staff line — that's where the note G lives!",
		"G Clef = Treble Clef",
		"The curl tells musicians exactly where G is on the staff. Every other note is measured from there!"
	))

	# 5 — Visual: bass clef symbol
	steps.append(LMD.create_visual_step(
		"The Bass Clef",
		"This is the bass clef. It marks the lower notes — think left hand on a piano!",
		"clef_symbol",
		{"clef": "bass"}
	))

	# 6 — Visual: bass clef on staff
	steps.append(LMD.create_visual_step(
		"Bass Clef on the Staff",
		"Here's the bass clef on the staff. Notice the two dots!",
		"clef_on_staff",
		{"clef": "bass"}
	))

	# 7 — Explanation: Bass = F Clef
	steps.append(LMD.create_explanation_step(
		"The F Clef",
		"The bass clef is also called the F Clef because its two dots sit on either side of the 4th line — that's where the note F lives!",
		"F Clef = Bass Clef",
		"Those two dots pinpoint the note F on the staff. All bass notes are measured from that line!"
	))

	# — Clef recap
	steps.append(LMD.create_recap_step(
		"Clef Review",
		"Nice work! Let's make sure you remember the two clefs:",
		[
			{"label": "Treble Clef  𝄞", "detail": "The G Clef — its curl wraps around the 2nd line (G)", "clef": "treble"},
			{"label": "Bass Clef  𝄢", "detail": "The F Clef — its dots sit around the 4th line (F)", "clef": "bass"},
		]
	))

	# — Quiz: G Clef
	steps.append(LMD.create_quiz_step(
		"Which clef is also called the G Clef?",
		["Treble Clef", "Bass Clef"],
		0,
		"Yes! The treble clef curls around the 2nd line — the G line!",
		"Not quite — the G Clef is the treble clef. Its curl wraps around the 2nd line."
	))

	# — Quiz: F Clef
	steps.append(LMD.create_quiz_step(
		"Which clef is also called the F Clef?",
		["Treble Clef", "Bass Clef"],
		1,
		"Correct! The bass clef dots mark the 4th line — the F line!",
		"Not quite — the F Clef is the bass clef. Its dots surround the 4th line."
	))

	# — Quiz: Treble clef for high or low?
	steps.append(LMD.create_quiz_step(
		"The treble clef is used for which notes?",
		["Higher notes", "Lower notes"],
		0,
		"Right! Treble = higher notes, like melodies and right hand on piano!",
		"Not quite — the treble clef is for higher notes. The bass clef handles the lower ones."
	))

	# — Transition intro: Bar Lines
	steps.append(LMD.create_intro_step(
		"Bar Lines",
		"Now let's look at how music stays organized. Bar lines are the lines that group music into neat, countable sections!",
		"The lines that keep music in order."
	))

	# 9 — Visual: bar lines (3 bars)
	steps.append(LMD.create_visual_step(
		"Bar Lines on the Staff",
		"See those vertical lines? Those are bar lines! They divide the staff into sections called measures. Each measure holds a set number of beats.",
		"bar_lines",
		{"clef": "treble", "bars": 3}
	))

	# 10 — Explanation: measures/bars
	steps.append(LMD.create_explanation_step(
		"Measures",
		"The space between two bar lines is called a measure (or bar). It keeps music organized!",
		"Bar Lines = Dividers",
		"Without bar lines, music would be one endless stream of notes. Bars help you keep your place."
	))

	# 11 — Transition intro: Time Signatures
	steps.append(LMD.create_intro_step(
		"Time Signatures",
		"Now that you know about measures, let's learn how we count the beats inside them. Time signatures tell you exactly how many beats each measure gets!",
		"The numbers that set the rhythm."
	))

	# 12 — Visual: 4/4 time signature
	steps.append(LMD.create_visual_step(
		"4/4 Time",
		"4/4 means 4 beats in every measure. Count along: 1, 2, 3, 4!",
		"time_signature",
		{"top": 4, "bottom": 4}
	))

	# — Visual: 3/4 time signature
	steps.append(LMD.create_visual_step(
		"3/4 Time",
		"3/4 means 3 beats in every measure. Like a waltz: 1, 2, 3!",
		"time_signature",
		{"top": 3, "bottom": 4}
	))

	# — Bar Lines & Time Signatures recap
	steps.append(LMD.create_recap_step(
		"Bar Lines & Time Review",
		"Let's make sure you've got bar lines and time signatures down:",
		[
			{"label": "Bar Lines", "detail": "Vertical lines that divide music into measures"},
			{"label": "Measures", "detail": "The space between two bar lines — each holds a set number of beats"},
			{"label": "4/4 Time", "detail": "4 beats per measure — the most common time signature"},
			{"label": "3/4 Time", "detail": "3 beats per measure — the waltz feel"},
		]
	))

	# — Quiz: What do bar lines do?
	steps.append(LMD.create_quiz_step(
		"What do bar lines do?",
		["Divide music into measures", "Make music louder", "Change the key"],
		0,
		"Yes! Bar lines split music into neat, countable measures!",
		"Not quite — bar lines divide music into measures."
	))

	# — Quiz: How many beats in 4/4?
	steps.append(LMD.create_quiz_step(
		"How many beats in a bar of 4/4 time?",
		["2", "3", "4"],
		2,
		"Right! 4/4 means 4 beats in every bar!",
		"The top number tells you how many beats. 4/4 = 4 beats!"
	))

	# — Quiz: How many beats in 3/4?
	steps.append(LMD.create_quiz_step(
		"How many beats in a bar of 3/4 time?",
		["2", "3", "4"],
		1,
		"You got it! 3/4 has 3 beats — perfect for a waltz!",
		"The top number is the beat count. 3/4 means 3 beats per bar!"
	))

	# — Quiz: What does the top number mean?
	steps.append(LMD.create_quiz_step(
		"In a time signature, what does the top number tell you?",
		["How many beats per measure", "How fast to play", "How many measures"],
		0,
		"Exactly! The top number is the number of beats in each measure!",
		"Not quite — the top number tells you how many beats are in each measure."
	))

	# — Final section: Drag symbol + full recap
	steps.append(LMD.create_drag_symbol_step(
		"Drag the symbol to the correct clef name!",
		"𝄞",
		["Treble Clef", "Bass Clef", "Alto Clef"],
		0,
		"That's right! 𝄞 is the treble clef!",
		"Not that one — look at the curly shape. That's the treble clef!"
	))

	# ── Practice Round ──
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's see how much you remember! Answer these questions about clefs, bar lines, and time signatures.",
		LMD.clef_theory_pool(),
		8,
		"theory"
	))

	# — Full module recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Amazing work! Here's everything you learned in this lesson:",
		[
			{"label": "The Staff", "detail": "5 lines and 4 spaces — every note lives on one of these"},
			{"label": "Treble Clef  𝄞", "detail": "The G Clef — curls around the 2nd line (G)", "clef": "treble"},
			{"label": "Bass Clef  𝄢", "detail": "The F Clef — dots around the 4th line (F)", "clef": "bass"},
			{"label": "Bar Lines", "detail": "Vertical lines that divide music into measures"},
			{"label": "Time Signatures", "detail": "4/4 = 4 beats, 3/4 = 3 beats per measure"},
		]
	))

	return LMD.create_module(
		"clef_barlines_time",
		"Clefs, Bar Lines & Time",
		"Learn the basics of reading music",
		"",
		steps,
		10,
		"Music Reader"
	)
