extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")

# Bass staff: step 0=A3(top line), 1=G3, 2=F3, 3=E3, 4=D3(middle), 5=C3, 6=B2, 7=A2, 8=G2(bottom line)
# Lines (even steps): A3(0), F3(2), D3(4), B2(6), G2(8) — "Good Boys Do Fine Always" bottom-up
# Spaces (odd steps): G3(1), E3(3), C3(5), A2(7) — "All Cows Eat Grass" bottom-up


static func get_module_data() -> Dictionary:
	var steps: Array = [
		LMD.create_intro_step(
			"Bass Note Names!",
			"Now let's learn the notes on the bass staff. The bass clef handles the lower notes!",
			"Same idea as treble — just different note names."
		),

		# Lines teaching screen — animated 1-5
		LMD.create_visual_step(
			"5 Lines",
			"The bass staff also has 5 lines! Watch them appear — line 1, 2, 3, 4, 5!",
			"staff_lines_intro",
			{"clef": "bass"}
		),

		# Spaces teaching screen — animated 1-4
		LMD.create_visual_step(
			"4 Spaces",
			"And 4 spaces between the lines! Notes sit ON lines or IN spaces, just like treble.",
			"staff_spaces_intro",
			{"clef": "bass"}
		),

		# Line notes explanation
		LMD.create_explanation_step(
			"Bass Line Notes",
			"The bass line notes from bottom to top are: G  B  D  F  A. Remember: Good Boys Do Fine Always!",
			"G  B  D  F  A",
			"Good Boys Do Fine Always"
		),

		# Line notes visual — noteheads on lines
		LMD.create_visual_step(
			"Line Notes on the Staff",
			"Here are the bass line notes! Each one sits right ON a line.",
			"notes_on_lines",
			{"clef": "bass", "notes": ["G", "B", "D", "F", "A"]}
		),

		# Space notes explanation
		LMD.create_explanation_step(
			"Bass Space Notes",
			"The bass space notes from bottom to top are: A  C  E  G. Remember: All Cows Eat Grass!",
			"A  C  E  G",
			"All Cows Eat Grass"
		),

		# Space notes visual — noteheads in spaces
		LMD.create_visual_step(
			"Space Notes on the Staff",
			"Here are the bass space notes! See how each one sits IN a space, between two lines.",
			"notes_in_spaces",
			{"clef": "bass", "notes": ["A", "C", "E", "G"]}
		),

		# Guided drag practice
		LMD.create_drag_note_step(
			"Drag the note to the bottom line of the bass staff. That's G!",
			"bass", "G", 8, true,
			"Nice! G is the bottom line of the bass staff!",
			"Look for the dotted hint on the bottom line."
		),

		LMD.create_drag_note_step(
			"Find the middle line — that's D!",
			"bass", "D", 4, true,
			"That's right! D is on the middle line!",
			"The middle line is D. Check the hint!"
		),

		LMD.create_drag_note_step(
			"The F line has the clef dots around it. Find F!",
			"bass", "F", 2, true,
			"Perfect! F is where the bass clef dots are!",
			"Remember — the two dots surround the F line."
		),

		LMD.create_drag_note_step(
			"Try a space note. The first space from the bottom is A!",
			"bass", "A", 7, true,
			"Good job! A is in the first space!",
			"The first space is just above the bottom line."
		),

		LMD.create_drag_note_step(
			"Find the E space — third space from the bottom!",
			"bass", "E", 3, true,
			"That's E! Nice work!",
			"E is the third space from the bottom."
		),

		LMD.create_drag_note_step(
			"Place B on the second line from the bottom — no hint this time!",
			"bass", "B", 6, false,
			"Excellent! B is the second line!",
			"B is the second line from the bottom. Try again!"
		),

		LMD.create_quiz_step(
			"The bass space notes spell which phrase?",
			["All Cows Eat Grass", "All Cars Exit Green", "Ants Carry Everything Gently"],
			0,
			"Yes! A-C-E-G: All Cows Eat Grass!",
			"The spaces are A, C, E, G. Think of cows!"
		),

		LMD.create_quiz_step(
			"Which note sits on the line where the bass clef dots are?",
			["D", "F", "A"],
			1,
			"Correct! The bass clef dots mark the F line!",
			"Remember — the Bass Clef is the F Clef!"
		),

		LMD.create_recap_step(
			"Bass Notes Review",
			"Awesome job! Here's what you learned:",
			[
				{"label": "Line Notes", "detail": "G B D F A — Good Boys Do Fine Always", "clef": "bass"},
				{"label": "Space Notes", "detail": "A C E G — All Cows Eat Grass", "clef": "bass"},
			]
		),
	]

	return LMD.create_module(
		"note_names_bass",
		"Note Names (Bass)",
		"Learn the notes on the bass staff",
		"",
		steps
	)
