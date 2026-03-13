extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")

# Treble staff: step 0=F5(top line), 1=E5, 2=D5, 3=C5, 4=B4(middle), 5=A4, 6=G4, 7=F4, 8=E4(bottom line)
# Lines (even steps): F5(0), D5(2), B4(4), G4(6), E4(8) — "Every Good Boy Does Fine" bottom-up
# Spaces (odd steps): E5(1), C5(3), A4(5), F4(7) — "FACE" bottom-up


static func get_module_data() -> Dictionary:
	var steps: Array = [
		LMD.create_intro_step(
			"Treble Note Names!",
			"Let's learn the names of the notes on the treble staff. Every line and space has its own note!",
			"Each line and space is a different note."
		),

		# Lines teaching screen — animated 1-5
		LMD.create_visual_step(
			"5 Lines",
			"The staff has 5 lines. Watch them appear from the bottom — line 1, 2, 3, 4, 5!",
			"staff_lines_intro",
			{"clef": "treble"}
		),

		# Spaces teaching screen — animated 1-4
		LMD.create_visual_step(
			"4 Spaces",
			"Between those 5 lines, there are 4 spaces! Notes can sit ON lines or IN spaces.",
			"staff_spaces_intro",
			{"clef": "treble"}
		),

		# Line notes explanation
		LMD.create_explanation_step(
			"Line Notes",
			"The line notes from bottom to top are: E  G  B  D  F. A fun way to remember: Every Good Boy Does Fine!",
			"E  G  B  D  F",
			"Every Good Boy Does Fine"
		),

		# Line notes visual — noteheads on lines
		LMD.create_visual_step(
			"Line Notes on the Staff",
			"Here are the line notes! See how each one sits right ON a line.",
			"notes_on_lines",
			{"clef": "treble", "notes": ["E", "G", "B", "D", "F"]}
		),

		# Space notes explanation
		LMD.create_explanation_step(
			"Space Notes",
			"The space notes from bottom to top spell a word: F  A  C  E. That's easy to remember!",
			"F  A  C  E",
			"The spaces spell FACE!"
		),

		# Space notes visual — noteheads in spaces
		LMD.create_visual_step(
			"Space Notes on the Staff",
			"Here are the space notes! See how each one sits IN a space, between two lines.",
			"notes_in_spaces",
			{"clef": "treble", "notes": ["F", "A", "C", "E"]}
		),

		# Guided drag-and-drop: start with easy notes + hints
		LMD.create_drag_note_step(
			"Let's try it! Drag the note to the bottom line. That's E — the first line note!",
			"treble", "E", 8, true,
			"Nice work! That's E on the bottom line!",
			"Almost! Look for the dotted hint on the bottom line."
		),

		LMD.create_drag_note_step(
			"Now drag the note to the middle line. That's B!",
			"treble", "B", 4, true,
			"You got it! B sits right on the middle line!",
			"Not quite — the middle line is B. Check the hint!"
		),

		LMD.create_drag_note_step(
			"Can you find the top line? That's F!",
			"treble", "F", 0, true,
			"Perfect! F is the top line!",
			"Look for the dotted oval at the very top line."
		),

		LMD.create_drag_note_step(
			"Now try a space note. Drag to the first space from the bottom. That's F!",
			"treble", "F", 7, true,
			"That's right! F is in the first space!",
			"Almost! The first space is just above the bottom line."
		),

		LMD.create_drag_note_step(
			"Find the A space — second space from the bottom!",
			"treble", "A", 5, true,
			"Good job! A is in the second space!",
			"Try the second space up from the bottom."
		),

		# Slightly harder: less obvious notes
		LMD.create_drag_note_step(
			"Where does G go? It's on the second line from the bottom.",
			"treble", "G", 6, true,
			"That's G! The clef curls around this line, remember?",
			"G is on the second line — where the clef curls!"
		),

		LMD.create_drag_note_step(
			"Try placing D — the fourth line from the bottom. No hint this time!",
			"treble", "D", 2, false,
			"Excellent! D is on the fourth line!",
			"Not quite. D is the fourth line from the bottom — try again!"
		),

		# Quiz steps
		LMD.create_quiz_step(
			"The space notes from bottom to top spell which word?",
			["FACE", "EDGE", "BEAD"],
			0,
			"Yes! The spaces spell F-A-C-E!",
			"Remember — F, A, C, E spell a word!"
		),

		LMD.create_quiz_step(
			"Which note sits on the middle line of the treble staff?",
			["D", "B", "G"],
			1,
			"Correct! B is right in the middle!",
			"Think of 'Every Good Boy Does Fine' — the middle one is B!"
		),

		LMD.create_recap_step(
			"Treble Notes Review",
			"Great work! Here's what you learned:",
			[
				{"label": "Line Notes", "detail": "E G B D F — Every Good Boy Does Fine", "clef": "treble"},
				{"label": "Space Notes", "detail": "F A C E — the spaces spell FACE!", "clef": "treble"},
			]
		),
	]

	return LMD.create_module(
		"note_names_treble",
		"Note Names (Treble)",
		"Learn the notes on the treble staff",
		"",
		steps
	)
