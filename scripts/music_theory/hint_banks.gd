class_name HintBanks
extends RefCounted

# Pure hint-line lookups for the in-game chicken-hint system.
# Extracted from interval_birds.gd to shrink the monolith — these are just
# data tables, no instance state. Each *_bank() returns the per-id Array of
# hint strings; the caller stays responsible for the dynamic per-question
# context (root note, semitones, etc.) and for the "clear hint" prefix.
#
# Fallbacks are intentionally generic enough to be useful even when the user
# is on a new chord/scale/progression we haven't curated yet.


# ─── Intervals ─────────────────────────────────────────────────────────────
static func interval_bank(interval_id: String) -> Array:
	var bank := {
		"P1": [
			"Unison: both notes are the exact same pitch.",
			"No jump at all — the two tones blend into one.",
			"You hear no movement, just a single solid sound.",
			"If it sounds like nothing changed, it's Unison.",
			"Memory hook: hum one note, then hear the same note again."
		],
		"m2": [
			"Song: the Jaws two-note motif — da-dum.",
			"The smallest possible step: 1 semitone (one piano key apart).",
			"Sounds tense and scratchy — notes rub against each other.",
			"Often used in horror and suspense music for a reason!",
			"Imagine two keys right next to each other on a piano."
		],
		"M2": [
			"Song: the opening of Happy Birthday ('Hap-py').",
			"A comfortable small step: 2 semitones apart.",
			"Sounds smooth and natural — very common in melodies.",
			"This is the distance between adjacent white keys in C major.",
			"Gentle forward motion — less tense than the m2."
		],
		"m3": [
			"Song: 'Greensleeves' — the opening drop has a minor 3rd feel.",
			"Also: 'Smoke on the Water' riff, 'Iron Man' main riff.",
			"3 semitones apart — a moody, slightly dark jump.",
			"The minor 3rd is the interval that makes minor chords minor.",
			"Think of it as a leap that has a touch of sadness."
		],
		"M3": [
			"Song: 'When the Saints Go Marching In' — opening leap.",
			"Also: 'Oh What a Beautiful Morning' opening.",
			"4 semitones apart — bright and hopeful.",
			"The major 3rd is what makes major chords sound happy.",
			"One semitone wider than the minor 3rd — much brighter feel."
		],
		"P4": [
			"Song: 'Here Comes the Bride' — the opening leap.",
			"Also: 'Amazing Grace' and 'Auld Lang Syne' opening.",
			"5 semitones apart — a strong, noble jump.",
			"In ancient music, the perfect 4th was one of the 'perfect' intervals.",
			"Wider than a 3rd, it sounds bold but not aggressive."
		],
		"TT": [
			"Song: 'Maria' from West Side Story opens with a tritone.",
			"Also: The Simpsons theme opening leap.",
			"6 semitones — exactly halfway through the octave.",
			"Medieval musicians called it 'Diabolus in Musica' (Devil in Music).",
			"It sounds restless and unstable — strongly wants to move somewhere."
		],
		"P5": [
			"Song: 'Twinkle Twinkle' — 'Twin-kle Twin-kle' jump.",
			"Also: Star Wars opening fanfare, 'Can't Help Falling in Love'.",
			"7 semitones — the second strongest interval after the octave.",
			"Perfect 5ths are the foundation of power chords in rock.",
			"Open and ringing — feels strong and settled but not quite 'home'."
		],
		"m6": [
			"Song: 'The Entertainer' by Scott Joplin has a minor 6th flavour.",
			"Also: 'Go Down Moses' — the opening leap.",
			"8 semitones — a wide, emotionally charged jump.",
			"It's the inversion of a major 3rd (flip it and you get M3).",
			"Darker and more dramatic than the major 6th."
		],
		"M6": [
			"Song: 'My Bonnie Lies Over the Ocean' opening — large bright leap.",
			"Also: 'Nobody Knows the Trouble I've Seen' opening.",
			"9 semitones — wide but warm and singable.",
			"It's the inversion of a minor 3rd (flip it and you get m3).",
			"Brighter and more open-feeling than the minor 6th."
		],
		"m7": [
			"Song: 'Somewhere' from West Side Story — 'There's a place for us'.",
			"Also: the opening riff of 'Fly Me to the Moon' uses a minor 7th.",
			"10 semitones — very wide, just one step below the octave.",
			"The minor 7th adds the 'blue' note in dominant 7th chords.",
			"Sounds wide and slightly unresolved — yearning for the octave."
		],
		"M7": [
			"Song: 'Take On Me' by A-Ha — the leap in the chorus.",
			"Also: 'Over the Rainbow' has a major 7th in its inner melody.",
			"11 semitones — one tiny step below the octave.",
			"Creates the dreamy tension in major 7th chords (Cmaj7).",
			"Very bright and tense — powerfully wants to resolve up to the octave."
		],
		"P8": [
			"Song: 'Somewhere Over the Rainbow' — the very first leap ('Some-where').",
			"Also: 'Singin' in the Rain' opening leap.",
			"12 semitones — same note name, one octave higher.",
			"The octave is perfectly consonant — it sounds like 'home stretched up'.",
			"The biggest jump in the standard 12 intervals."
		]
	}
	return bank.get(interval_id, [
		"Listen for the size of the jump.",
		"Use the Replay button.",
		"Compare it to the octave — is it half? Less?",
		"Use the bottom note as your anchor.",
		"Then match the jump size to a label."
	])


# ─── Chord families ────────────────────────────────────────────────────────
static func chord_bank(family_id: String) -> Array:
	var bank := {
		"major": [
			"Bright, stable, and at home — the most common chord in Western music.",
			"Song color: 'Let It Be', 'Hey Jude', most folk/pop songs use major.",
			"Made of three notes: root, major 3rd (4 semitones up), perfect 5th (7 semitones up).",
			"Listen for the open, sunny feeling — not tense, not dark.",
			"Ask: does it sound settled and bright? → Major."
		],
		"minor": [
			"Darker, softer, more emotional than major.",
			"Song color: 'Stairway to Heaven' intro, 'Losing My Religion', minor ballads.",
			"Made of root, minor 3rd (3 semitones up), perfect 5th — one note flattened vs major.",
			"Listen for the warmth but with a shadow — sadder or more serious than major.",
			"Ask: does it feel like a major chord but slightly darker? → Minor."
		],
		"maj7": [
			"Dreamy, lush, and soft — jazz and pop ballads love this chord.",
			"Song color: 'Misty', the opening of 'Something' by The Beatles.",
			"A major triad with an added major 7th just below the octave.",
			"Listen for the shimmery, floating top note that adds gentle sweetness.",
			"Ask: does it sound like major but with a soft, dreamy extra layer? → Maj7."
		],
		"min7": [
			"Soulful and mellow — the chord of smooth jazz and R&B grooves.",
			"Song color: 'What's Going On' by Marvin Gaye, neo-soul grooves.",
			"A minor triad with a minor 7th added on top.",
			"Less harsh than a dominant 7 — relaxed and soft even in the higher note.",
			"Ask: does it feel dark + smooth + a little jazzy? → min7."
		],
		"dom7": [
			"Tense and bluesy — it strongly wants to resolve to the next chord.",
			"Song color: the 12-bar blues, 'Johnny B. Goode', 'Pride and Joy'.",
			"A major triad with a flattened 7th — the 7th note sounds slightly low.",
			"Hear the tension in the top layer: bright major body, slightly rough 7th.",
			"Ask: does it sound like a major chord that wants to move somewhere? → Dom7."
		],
		"dim": [
			"Tense, unstable, and spooky — a chord that wants to resolve urgently.",
			"Song color: classic horror and suspense, dramatic film scores.",
			"Two stacked minor 3rds (root, 3 semitones up, 3 more up = 6 semitones total).",
			"The 5th is lowered (diminished), making the chord sound compressed and tight.",
			"Ask: does it feel tense, hollow, and slightly creepy? → Diminished."
		],
		"dim7": [
			"Fully diminished — four equally-spaced notes create an eerie symmetry.",
			"Song color: dramatic scene transitions, thriller music, Bach's Passions.",
			"Each note is a minor 3rd apart all the way up — mathematically symmetric.",
			"Very tense and dramatic; often used to heighten emotional suspense.",
			"Ask: is it even more tense and dramatic than a diminished triad? → Dim7."
		],
		"aug": [
			"Raised and floating — the 5th note is pushed up one semitone.",
			"Song color: 'Oh! You Pretty Things' by Bowie, impressionist piano music.",
			"A major triad with the top note raised — two major 3rds stacked.",
			"Unstable and cinematic — sounds like it's hovering, not landing.",
			"Ask: does it sound like a bright chord that never quite settles? → Augmented."
		],
		"sus2": [
			"Open and ambiguous — the middle note (3rd) is replaced by the 2nd.",
			"Song color: 'Pinball Wizard' by The Who, U2-style anthems.",
			"No major or minor 3rd means you can't tell if it's happy or sad.",
			"The 2nd note gives an open, spacious quality — often in pop intros.",
			"Ask: does it feel open and neutral, neither bright nor dark? → Sus2."
		],
		"sus4": [
			"Suspended and unresolved — the 3rd is replaced by the 4th.",
			"Song color: 'Crazy' by Seal, 'Space Oddity' by Bowie has sus4 moments.",
			"Feels like it's leaning forward, wanting to resolve down to a major/minor.",
			"The 4th note creates tension that typically resolves by lowering to the 3rd.",
			"Ask: does it sound like it's on hold, waiting to resolve? → Sus4."
		],
		"power": [
			"Root and fifth only — no 3rd, so no major or minor quality.",
			"The sound of electric guitars in rock and metal music.",
			"Song color: 'Smells Like Teen Spirit', 'Back in Black', power pop riffs.",
			"Sounds strong and neutral — neither happy nor sad, just raw and direct.",
			"Ask: does it sound like raw power with no emotional color either way? → Power."
		],
		"halfdim": [
			"Minor with a flattened 5th plus a minor 7th — tense but not fully diminished.",
			"Song color: the 'ii' chord in minor-key jazz — 'Autumn Leaves', 'Blue Bossa'.",
			"Also called m7b5 — it's halfway between minor 7th and fully diminished.",
			"Less dramatic than dim7 but more tense than min7 — a shadowy, restless sound.",
			"Ask: does it feel like a dark minor 7th with extra tension in the 5th? → Half-dim."
		],
		"mmaj7": [
			"A minor triad with a major 7th — dark body with a sharp, bright top note.",
			"Song color: the 'James Bond chord' — dramatic, mysterious, cinematic.",
			"The clash between the minor 3rd and major 7th creates an edgy, sophisticated tension.",
			"Used in film scores for suspense and in jazz for passing harmonies.",
			"Ask: does it sound minor but with a surprisingly bright, cutting top note? → mMaj7."
		],
		"aug7": [
			"An augmented triad with a minor 7th — floating and bluesy.",
			"Song color: altered dominants in jazz, bluesy turnarounds.",
			"The raised 5th plus the lowered 7th create a restless, unresolved tension.",
			"Wants to resolve even more strongly than a regular dominant 7th.",
			"Ask: does it sound like a bright chord that's both floating AND bluesy? → Aug7."
		],
		"augmaj7": [
			"An augmented triad with a major 7th — mysterious and shimmering.",
			"Song color: film scores, impressionist music, dream sequences.",
			"The raised 5th gives it the floating augmented quality; the major 7th adds lushness.",
			"Rare but very distinctive — sounds otherworldly and ethereal.",
			"Ask: does it feel augmented (floating) but with a dreamy, lush top note? → AugMaj7."
		],
		"7sus4": [
			"A dominant 7th chord with the 3rd replaced by the 4th — suspended and bluesy.",
			"Song color: 'Pinball Wizard' intro, gospel/R&B vamps, funk turnarounds.",
			"Combines the tension of sus4 (wanting to resolve the 4th) with dominant 7th pull.",
			"Very common in pop and gospel — often resolves to a regular dominant 7th.",
			"Ask: does it feel suspended AND bluesy at the same time? → 7sus4."
		],
		"maj6": [
			"A major triad with an added 6th — warm, jazzy, and settled.",
			"Song color: swing era jazz, bossa nova endings, 'The Girl from Ipanema'.",
			"Brighter and more grounded than Maj7 — the 6th adds warmth without dreaminess.",
			"Often used as a final chord in jazz standards instead of Maj7.",
			"Ask: does it sound like a warm, settled major chord with a jazzy glow? → Maj6."
		],
		"min6": [
			"A minor triad with an added major 6th — dark but with a glimmer of brightness.",
			"Song color: film noir, tango, 'Summertime' by Gershwin.",
			"The minor 3rd gives darkness; the major 6th adds an unexpected brightness.",
			"Creates a bittersweet, sophisticated quality — common in jazz and Latin music.",
			"Ask: does it sound minor but with an unexpectedly warm, bright upper note? → Min6."
		],
		"69": [
			"A major triad with both a 6th and a 9th — open, bright, and lush.",
			"Song color: classic jazz endings, Wes Montgomery, bossa nova closers.",
			"Five notes that create a very full, shimmery, open sound.",
			"The 6th and 9th together give it a spacious, modern jazz quality.",
			"Ask: does it sound like a rich, full major chord with extra shimmer? → 6/9."
		],
		"dom9": [
			"A dominant 7th with an added 9th — funky, rich, and colorful.",
			"Song color: Stevie Wonder, Nile Rodgers funk, Earth Wind & Fire.",
			"The 9th on top of the dominant 7th creates a bright, funky extension.",
			"Very recognizable in funk, soul, and R&B — five notes of groove.",
			"Ask: does it sound like a funky, colorful dominant 7th with extra brightness? → Dom9."
		],
		"maj9": [
			"A major 7th with an added 9th — dreamy, lush, and modern.",
			"Song color: neo-soul, smooth jazz ballads, Erykah Badu.",
			"Combines the dreaminess of Maj7 with the open quality of the 9th.",
			"Feels like floating on a cloud — very gentle and sophisticated.",
			"Ask: does it sound even dreamier and lusher than a regular Maj7? → Maj9."
		],
		"min9": [
			"A minor 7th with an added 9th — smooth, mellow, and soulful.",
			"Song color: lo-fi beats, R&B ballads, D'Angelo, smooth jazz.",
			"The minor body stays dark; the 9th adds an open, airy quality on top.",
			"Creates a spacious, relaxed mood — less tense than min7 alone.",
			"Ask: does it feel like a relaxed, spacious minor 7th? → Min9."
		],
		"add9": [
			"A major triad with just the 9th added — no 7th, so it's bright and open.",
			"Song color: 'Every Breath You Take' by The Police, pop/worship ballads.",
			"Simpler than a 9th chord — only four notes, giving it a clean sparkle.",
			"The 9th adds color without the tension of a 7th — very pop-friendly.",
			"Ask: does it sound like a bright major chord with a little extra sparkle? → Add9."
		]
	}
	return bank.get(family_id, [
		"Listen for the chord's emotional mood first.",
		"Is it bright (major) or dark (minor)?",
		"Is there extra tension in the top notes?",
		"Replay and hum the lowest note as an anchor.",
		"Choose the family that matches the overall colour."
	])


# ─── Scale modes ───────────────────────────────────────────────────────────
static func scale_mode_bank(mode_name: String) -> Array:
	var bank := {
		"Major": [
			"Bright, confident, and settled — the most common scale in Western music.",
			"Song color: 'Happy Birthday', 'Twinkle Twinkle', most pop melodies.",
			"The 3rd note is natural (major), and the 7th is a half-step below the octave.",
			"Solfège: Do Re Mi Fa Sol La Ti Do — this is the Major scale.",
			"Key question: does it sound sunny and settled with a strong leading-tone pull home?"
		],
		"Natural Minor": [
			"Darker, more emotional than major — the 3rd is lowered by a semitone.",
			"Song color: 'Greensleeves', 'Stairway to Heaven', most rock ballads.",
			"The 3rd AND 6th AND 7th are all lowered compared to major.",
			"It sounds darker but still settled — no raised 7th to create strong upward pull.",
			"Key question: does it feel like major's emotional, darker sibling?"
		],
		"Dorian": [
			"Minor-sounding, but with one brighter note — the 6th is raised.",
			"Song color: 'Scarborough Fair', 'So What' by Miles Davis, 'Oye Como Va'.",
			"Think of it as Natural Minor with the 6th note raised by a semitone.",
			"The raised 6th gives it a jazzy, folky, or Spanish brightness in the middle.",
			"Key question: does it sound like minor, but not quite as dark or settled?"
		],
		"Mixolydian": [
			"Major-sounding, but with a lowered 7th — less 'leading-tone' pull.",
			"Song color: 'Sweet Home Alabama', 'Norwegian Wood', most blues-rock.",
			"Think of it as Major with the 7th note flattened by a semitone.",
			"The flattened 7th gives it a bluesy, rock, or folk looseness at the top.",
			"Key question: does it sound like major, but the ending feels less 'final'?"
		],
		"Lydian": [
			"Bright and dreamy — the 4th note is raised by a semitone.",
			"Song color: 'Flying' by The Beatles, film scores by John Williams.",
			"Think of it as Major with the 4th note sharpened — sounds more open and floating.",
			"The raised 4th sits in the middle of the scale and sounds bright and ethereal.",
			"Key question: does it feel like major, but even more open and floaty?"
		],
		"Phrygian": [
			"Dark and dramatic — the 2nd note is lowered to create immediate tension.",
			"Song color: flamenco music, 'White Zombie' riffs, Spanish guitar.",
			"Think of it as Natural Minor with the 2nd note flattened by a semitone.",
			"The half-step between root and 2nd creates an intense, exotic-sounding color.",
			"Key question: does it feel dark and tense right from the very first step up?"
		]
	}
	return bank.get(mode_name, [
		"Listen for mode colour notes.",
		"Compare to major/minor first.",
		"Focus on the 3rd (major vs minor), then the 7th.",
		"Notice the ending pull.",
		"One altered note is the key to identifying most modes."
	])


# ─── Cadences ──────────────────────────────────────────────────────────────
# The cadence bank is pattern-based — caller passes the already-lowercased
# label which we substring-match. Returns the body lines only (no clear-hint
# prefix or padding; the caller handles those).
static func cadence_bank(cadence_label_lower: String) -> Array:
	var n := cadence_label_lower
	# Order matters: check "half"/"imperfect" and "deceptive"/"interrupted" BEFORE
	# "perfect", because "imperfect" contains the substring "perfect".
	if n.find("half") >= 0 or n.find("imperfect") >= 0:
		return ["Sounds unfinished or paused.", "Ends with a question-mark feeling.", "It stops on V, not home.", "You expect another chord after it.", "Suspended ending, not final."]
	if n.find("deceptive") >= 0 or n.find("interrupted") >= 0:
		return ["Starts like a strong ending, but surprises you.", "Feels like a trick turn.", "V does not go to I here.", "The ending avoids full resolution.", "A 'not yet home' surprise landing."]
	if n.find("plagal") >= 0 or n.find("amen") >= 0:
		return ["Church-like 'Amen' feeling.", "Softer home arrival than perfect cadence.", "IV moves to I.", "Still resolves, but gentler.", "Common hymn-style ending color."]
	if n.find("perfect") >= 0 or n.find("authentic") >= 0:
		return ["Strong 'home' ending.", "Feels complete and settled.", "Classic V to I resolution sound.", "The ending lands firmly.", "Often the strongest cadence in tonal music."]
	return ["Listen to how the last chord feels.", "Does it sound final or open?", "Compare strong vs soft resolution.", "Replay and focus on the last chord.", "Cadence = ending pattern."]


# ─── Progressions ──────────────────────────────────────────────────────────
static func progression_bank(progression_label: String) -> Array:
	var bank := {
		"I-IV-V":    ["Classic 3-chord backbone — used in rock, blues, folk.", "I is home, IV is a lift, V is tension pulling back.", "The V chord creates the strongest pull back to I.", "Listen for the steady 'home → away → tension → home' shape.", "Found in hundreds of songs: La Bamba, Twist and Shout."],
		"ii-V-I":    ["The jazz turnaround — ii sets up V which resolves to I.", "Each chord moves down a 5th: it's a chain of tension releases.", "The ii chord gives mild tension; V gives strong tension.", "Listen for that smooth, inevitable pull toward the last chord.", "Common in jazz standards: Autumn Leaves, Misty."],
		"vi-IV-I-V": ["The modern 'pop 4-chord'. Found in countless pop hits.", "Starts on vi, which feels like a softer, more emotional home.", "The IV gives lift, I grounds it, V creates the push back.", "Listen for the minor flavour right at the start (vi chord).", "Used in: Let It Be, With or Without You, Frozen's Let It Go."],
		"I-vi-IV-V": ["The classic 1950s doo-wop/pop progression.", "I sounds home, vi gives bittersweet color, IV lifts, V tensions.", "Common in early rock and roll and Motown songs.", "Listen for the bittersweet vi chord second in the sequence.", "Used in: Stand By Me, Every Breath You Take, Blue Moon."],
		"I-V-IV-V":  ["A rocking progression with V before IV — slightly unexpected.", "The V before IV gives it a stronger, bolder quality than I-IV-V.", "Common in hard rock and stadium rock.", "Listen for the big V chord appearing early in the sequence.", "Found in: many power rock anthems."],
		"ii-IV-I":   ["A soft, gentle resolution. ii and IV both pre-resolve to I.", "Smooth, folky feel — less tension than ii-V-I.", "Listen for the gentle 'approach home' feeling at the end.", "Both ii and IV are subdominant-family chords.", "Softer than a V-I cadence — a subtle, calm landing."],
		"I-IV-vi-V": ["Home, lift, shadow, then tension — a slightly dramatic arc.", "The vi (minor) gives an emotional dip before the final V tension.", "Listen for the darker color on the third chord.", "Common in emotional pop ballads.", "The V at the end makes it want to loop back to I."],
		"I-iii-IV-V":["A bright, ascending-feel progression.", "iii is a 'color chord' between I and IV — adds warmth.", "Listen for the middle chord that sounds slightly richer than I.", "Builds from home toward IV and V in a clear upward arc.", "Used in many major-key pop songs for a hopeful lift."],
		"I-V-vi-IV": ["Another widely used pop rotation of the 4-chord loop.", "Starts with the strong I-V pair, then the emotional vi-IV.", "The vi still gives the minor colour, just later in the loop.", "Listen for the minor-feeling dip after the V chord.", "Used in: Vivaldi's Canon in D progression, many pop songs."]
	}
	return bank.get(progression_label, [
		"Listen for the tonal centre — which chord feels like 'home'?",
		"Count how many chords you hear before it repeats.",
		"Does the progression end settled, open, or tense?",
		"Focus on the first and last chord — they reveal the most.",
		"Try to hear if any chord sounds like a minor chord (darker colour)."
	])
