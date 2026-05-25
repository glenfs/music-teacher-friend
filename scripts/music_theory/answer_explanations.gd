class_name AnswerExplanations
extends RefCounted

# Pure music-theory "why this answer is correct" lookups used by the in-game
# post-answer teaching panels. Extracted from interval_birds.gd to shrink the
# main monolith — there is zero instance state here, only data.
#
# Naming: each top-level mode (interval / chord / scale-mode / cadence /
# progression) has one `*_reason(...)` static. The chord lookup needs a
# pre-resolved family id (e.g. "maj7" / "dom7") so the caller passes a
# Callable that maps a user-facing quality name to a canonical id; this keeps
# the caller's existing _chord_family_id_from_name() the single source of
# truth for that mapping.


static func interval_reason(interval_id: String) -> String:
	var reasons := {
		"P1": "both notes share the exact same pitch — zero distance (unison).",
		"m2": "the notes are only 1 semitone apart — the smallest possible step, hence the tense, rubbing sound.",
		"M2": "the notes are 2 semitones apart — a comfortable whole-step, the most common melodic motion.",
		"m3": "the distance is 3 semitones — the minor 3rd gives chords their 'sad' or darker quality.",
		"M3": "the distance is 4 semitones — the major 3rd gives chords their bright, happy quality.",
		"P4": "the notes are 5 semitones apart — one of the 'perfect' intervals, stable in melody but can suspend in harmony.",
		"TT": "the notes are exactly 6 semitones apart — the tritone splits the octave in half and was historically forbidden for its harshness.",
		"P5": "the notes are 7 semitones apart — the strongest and most resonant interval after the octave, the basis of power chords.",
		"m6": "the notes are 8 semitones apart — the inversion of a major 3rd; wider, slightly darker.",
		"M6": "the notes are 9 semitones apart — the inversion of a minor 3rd; wide and warm.",
		"m7": "the notes are 10 semitones apart — the inversion of a major 2nd; adds the blue note to dominant 7th chords.",
		"M7": "the notes are 11 semitones apart — just one semitone below the octave, creating strong upward tension.",
		"P8": "the notes are 12 semitones apart — same note name, one octave higher; perfectly consonant and stable."
	}
	return str(reasons.get(interval_id, "the distance between the two notes matches this interval's semitone count."))


static func chord_reason(quality_name: String, family_id_callable: Callable) -> String:
	var family: String = str(family_id_callable.call(quality_name)) if family_id_callable.is_valid() else quality_name.to_lower()
	var reasons := {
		"major": "it contains a major 3rd (4 semitones) above the root, giving it its bright, settled sound.",
		"minor": "it contains a minor 3rd (3 semitones) above the root — one semitone flatter than major — giving it a darker, sadder colour.",
		"maj7": "it adds a major 7th (11 semitones above root) to a major triad, creating that dreamy, lush, shimmering top note.",
		"min7": "it adds a minor 7th (10 semitones above root) to a minor triad, creating a soulful, relaxed, jazzy colour.",
		"dom7": "it adds a minor 7th to a major triad — the tension between the bright major body and the lowered 7th creates a strong pull to resolve.",
		"dim": "both the 3rd and the 5th are lowered (diminished), creating a symmetrically tense, compressed sound.",
		"dim7": "all four notes are spaced exactly 3 semitones apart, creating a perfectly symmetric, very tense sound.",
		"aug": "the 5th is raised by one semitone, making it an augmented 5th — the chord floats and refuses to settle.",
		"sus2": "the 3rd is replaced by the 2nd scale degree — removing the major/minor quality and creating an open, ambiguous sound.",
		"sus4": "the 3rd is replaced by the 4th scale degree — the 4th creates suspension that typically resolves down to the 3rd.",
		"power": "only the root and perfect 5th are used — no 3rd means no major or minor quality, just raw, open, neutral power.",
		"halfdim": "it combines a diminished triad (minor 3rd + flat 5th) with a minor 7th — less tense than fully diminished but darker than minor 7th.",
		"mmaj7": "it stacks a minor triad with a major 7th — the clash between the dark minor 3rd and the bright major 7th creates an edgy, cinematic tension.",
		"aug7": "it combines an augmented triad (raised 5th) with a minor 7th — floating and bluesy, with a strong urge to resolve.",
		"augmaj7": "it combines an augmented triad with a major 7th — the raised 5th gives it a floating quality while the major 7th adds ethereal lushness.",
		"7sus4": "it replaces the 3rd of a dominant 7th with the 4th — combining suspended tension with dominant pull.",
		"maj6": "it adds the major 6th (9 semitones) to a major triad — warm and jazzy without the dreaminess of a 7th.",
		"min6": "it adds the major 6th to a minor triad — the bright 6th against the dark minor body creates a bittersweet quality.",
		"69": "it stacks both the 6th and the 9th on a major triad — five notes that create a full, shimmery, open jazz sound.",
		"dom9": "it extends a dominant 7th with the 9th — five notes of funky, colourful brightness that want to resolve.",
		"maj9": "it extends a major 7th with the 9th — creating an extra-dreamy, lush, modern jazz texture.",
		"min9": "it extends a minor 7th with the 9th — the added 9th opens up the dark minor sound into something smooth and spacious.",
		"add9": "it adds just the 9th to a major triad (no 7th) — a clean, bright sparkle without the complexity of extended harmony.",
	}
	return str(reasons.get(family, "the stacked intervals match this chord family's unique pattern."))


static func progression_reason(progression_label: String) -> String:
	# Short "why" for the common chord progressions used in MODE_PROGRESSION.
	# Falls back to a generic explanation when the label isn't in the table.
	var n := progression_label.to_lower()
	if n == "i-iv-v" or n == "i-iv-v-i":
		return "the classic three-chord pop/rock motion — tonic, subdominant, dominant, all major triads in a major key."
	if n == "i-v-vi-iv":
		return "the 'four-chord' pop song progression — a major triad, then dominant, then the relative minor, then subdominant."
	if n == "vi-iv-i-v":
		return "a rotated pop progression starting on the relative minor — emotional opening that resolves home."
	if n == "ii-v-i":
		return "the foundational jazz cadence — minor 7th, dominant 7th, major 7th — strong harmonic pull to home."
	if n == "i-vi-iv-v":
		return "the doo-wop progression — gentle drop to the relative minor, then subdominant, then dominant."
	if n == "i-v-vi-iii-iv-i-iv-v":
		return "Pachelbel's Canon progression — long descending bass motion through the entire key."
	if n.find("blues") >= 0 or n == "i-iv-i-v-iv-i":
		return "the 12-bar blues skeleton — tonic, subdominant, dominant — all dominant 7th sounds in blues."
	return "the chord motion matches this progression's harmonic pattern."


static func scale_mode_reason(mode_name: String) -> String:
	var reasons := {
		"Major": "it uses a bright major pattern with a natural 3rd and natural 7th.",
		"Natural Minor": "it uses a minor 3rd with a softer, darker minor pattern.",
		"Dorian": "it sounds minor but keeps a brighter natural 6th.",
		"Mixolydian": "it sounds major but has a lowered 7th color.",
		"Lydian": "it sounds major with a raised 4th that feels bright and floaty.",
		"Phrygian": "it sounds minor with a very close lowered 2nd."
	}
	return str(reasons.get(mode_name, "the step pattern matches this mode."))


static func cadence_reason(cadence_label: String) -> String:
	var n := cadence_label.to_lower()
	if n.find("perfect") >= 0:
		return "it resolves strongly from dominant to tonic (V-I)."
	if n.find("plagal") >= 0:
		return "it resolves with the church-like IV-I sound."
	if n.find("half") >= 0:
		return "it stops on V, so it sounds unfinished."
	if n.find("deceptive") >= 0:
		return "it starts like a strong resolution but turns to vi instead of I."
	return "the ending chord motion matches this cadence type."
