class_name ChordToneSpelling
extends RefCounted

# Spells each chord tone using stack-of-thirds music notation rules instead
# of naive pitch-class → letter lookup. Pure data, no Node dependency.
#
# Why this exists:
#   The chord recognizer / panel previously used `NOTE_NAMES_SHARP[pc]` or
#   `NOTE_NAMES_FLAT[pc]` to spell every chord tone, which gives C Dom7's
#   b7 as "A#" (key uses sharps) — musically wrong. The 7th of a chord must
#   use the 7th letter from the root (B), with whatever accidental brings
#   it to the right pitch (Bb, not A#).
#
# Rules (from standard Western music notation):
#   • Triads stack in 3rds: 1, 3, 5 → root_letter, root+2 letters, root+4
#   • 7th chords add the 7th: root_letter + 6 letters
#   • Extensions (9, 11, 13) use the next odd diatonic step: 1, 3, 5, 7, 9, 11, 13
#   • The accidental is whatever brings the natural letter pitch to the
#     intended chord-tone pitch class. C Dom7's 7th letter is B (natural pc
#     11); the chord wants pc 10 → accidental = -1 → spell as "Bb".
#   • For dim7 ([0,3,6,9]) the top tone is a diminished 7th, not a 6th. It
#     uses the 7th letter with a double-flat (e.g. C-dim7's top note is Bbb).
#   • Sus2 / Sus4: the 2 or 4 substitutes for the 3rd in the letter stack.
#
# Usage:
#   var tones := ChordToneSpelling.spell_chord_tones("C", 0, [0, 4, 7, 10], "7")
#   # tones == [{letter:"C", accidental:0}, {letter:"E", accidental:0},
#   #          {letter:"G", accidental:0}, {letter:"B", accidental:-1}]
#
# spell_pc(letter, accidental, uses_flats=false) returns "Bb" / "F#" etc.


const NOTE_LETTERS := ["C", "D", "E", "F", "G", "A", "B"]
const LETTER_PC := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


# Per-quality slot assignment: which scale degree (1..13) each interval slot
# occupies. The chord's `quality` string follows the chord recognizer's
# `quality_short` vocabulary. Intervals are matched to slots positionally
# (sorted ascending) — order in the value array MUST match the natural
# sort order of CHORD_TEMPLATES intervals.
#
# Each entry is the intended chord-degree label per interval position:
#   triad → [1, 3, 5]
#   7th   → [1, 3, 5, 7]
#   etc.
const _QUALITY_DEGREES := {
	# Triads
	"Major":    [1, 3, 5],
	"Minor":    [1, 3, 5],
	"dim":      [1, 3, 5],
	"aug":      [1, 3, 5],
	"sus2":     [1, 2, 5],
	"sus4":     [1, 4, 5],
	# 7ths — top tone is the 7th letter (or a 6 in case of m7/Maj7/Dom7? no:
	# m7/Maj7/Dom7 all use the 7 letter). dim7 also uses the 7 letter (bb7).
	"7":        [1, 3, 5, 7],
	"maj7":     [1, 3, 5, 7],
	"m7":       [1, 3, 5, 7],
	"dim7":     [1, 3, 5, 7],
	"m7b5":     [1, 3, 5, 7],
	"mMaj7":    [1, 3, 5, 7],
	"aug7":     [1, 3, 5, 7],
	"augMaj7":  [1, 3, 5, 7],
	"7sus4":    [1, 4, 5, 7],
	# 6ths — the 6 tone is the 6 letter (root+5 letters).
	"6":        [1, 3, 5, 6],
	"m6":       [1, 3, 5, 6],
	# Add9 — no 7, just root + triad + 9. Intervals sort: [0, 2(or 14), 4, 7]
	# When the 9 is in raw form (semitone 2) it still occupies the 9 slot.
	"add9":     [1, 3, 5, 9],
	"madd9":    [1, 3, 5, 9],
	# 6/9
	"6/9":      [1, 3, 5, 6, 9],
	# 9ths — root + triad + 7 + 9
	"9":        [1, 3, 5, 7, 9],
	"maj9":     [1, 3, 5, 7, 9],
	"m9":       [1, 3, 5, 7, 9],
	# Alt dominants
	"7b5":      [1, 3, 5, 7],
	"7b9":      [1, 3, 5, 7, 9],
	"7#9":      [1, 3, 5, 7, 9],
	"7b13":     [1, 3, 5, 7, 13],
	"9sus4":    [1, 4, 5, 7, 9],
	# 11ths / 13ths
	"11":       [1, 3, 5, 7, 9, 11],
	"m11":      [1, 3, 5, 7, 9, 11],
	"maj11":    [1, 3, 5, 7, 9, 11],
	"13":       [1, 3, 5, 7, 9, 13],
	"maj7#11":  [1, 3, 5, 7, 9, 11],
	# Power chord
	"5":        [1, 5],
	# Quartal / clusters — best-effort, fall through to algorithmic spelling.
	"sus4(no5)": [1, 4],
}

# Scale-degree label → "natural-letter offset from root" (steps in the
# diatonic series). 1 → 0 (root letter), 3 → 2 letters above root, etc.
# Compound extensions (9, 11, 13) wrap to the simple degree's letter
# position because the 9 IS the 2 in a different octave, structurally
# spelled as the 2 letter.
const _DEGREE_TO_LETTER_OFFSET := {
	1: 0,
	2: 1, 9: 1,
	3: 2,
	4: 3, 11: 3,
	5: 4,
	6: 5, 13: 5,
	7: 6,
}


# Public entry: spell each chord tone given its chord context.
# Returns Array of Dictionaries { letter, accidental }. Order matches the
# input intervals (after sorting ascending to align with the quality's
# slot order — caller may want to re-sort by stack-of-thirds).
static func spell_chord_tones(root_letter: String, root_acc: int, intervals: Array, quality: String) -> Array:
	if intervals.is_empty():
		return []
	# Sort intervals ascending so they match the quality's slot order.
	# (CHORD_TEMPLATES keys are already sorted ascending intervals.)
	var sorted_intervals: Array = []
	for iv in intervals:
		sorted_intervals.append(int(iv))
	sorted_intervals.sort()
	var root_idx: int = NOTE_LETTERS.find(root_letter)
	if root_idx < 0:
		root_idx = 0
	var root_pc_natural: int = int(LETTER_PC.get(root_letter, 0))
	var root_pc: int = ((root_pc_natural + root_acc) % 12 + 12) % 12
	var degrees: Array = _QUALITY_DEGREES.get(quality, [])
	# Assign each interval to a chord-DEGREE slot. Mapping the sorted intervals to
	# the degree list POSITIONALLY breaks when an extension (9/11/13) is voiced in
	# a low octave — e.g. a #9 played as Eb right beside the 3rd: the sorted set
	# [0,3,4,7,10] would put the #9 in the 3rd's slot and cascade into double/triple
	# accidentals. So when the slot count matches, choose the assignment that
	# MINIMIZES total accidentals (greedy min-cost matching). For ordinary voicings
	# this is identical to the positional mapping.
	var degree_for_index: Array = []
	degree_for_index.resize(sorted_intervals.size())
	for k in degree_for_index.size():
		degree_for_index[k] = -999   # sentinel: use the structural fallback offset
	if not degrees.is_empty() and degrees.size() == sorted_intervals.size():
		degree_for_index = _match_intervals_to_degrees(sorted_intervals, degrees, root_pc, root_idx)
	elif not degrees.is_empty():
		for k in sorted_intervals.size():
			if k < degrees.size():
				degree_for_index[k] = int(degrees[k])
	var out: Array = []
	for i in sorted_intervals.size():
		var iv: int = sorted_intervals[i]
		var iv_mod: int = ((iv % 12) + 12) % 12
		var target_pc: int = ((root_pc + iv) % 12 + 12) % 12
		var letter_offset: int
		var deg: int = int(degree_for_index[i])
		if deg != -999:
			letter_offset = int(_DEGREE_TO_LETTER_OFFSET.get(deg, 0))
		else:
			# Unknown quality OR more intervals than the table covers —
			# fall back to a structural guess from the interval class.
			letter_offset = _fallback_letter_offset(iv_mod, sorted_intervals)
		var letter_idx: int = (root_idx + letter_offset) % 7
		var letter: String = NOTE_LETTERS[letter_idx]
		var natural_pc: int = int(LETTER_PC.get(letter, 0))
		var accidental: int = ((target_pc - natural_pc) % 12 + 12) % 12
		if accidental > 6:
			accidental -= 12
		out.append({"letter": letter, "accidental": accidental})
	return out


# Greedy minimum-accidental matching of intervals -> degree slots. Returns an
# array (aligned with sorted_intervals) of the degree assigned to each interval.
# Pairing every interval with the degree whose natural letter needs the fewest
# accidentals avoids the positional-mapping cascade for compressed extensions.
static func _match_intervals_to_degrees(sorted_intervals: Array, degrees: Array, root_pc: int, root_idx: int) -> Array:
	var n: int = sorted_intervals.size()
	var result: Array = []
	result.resize(n)
	for k in n:
		result[k] = -999
	var pairs: Array = []
	for i in n:
		var target_pc: int = ((root_pc + int(sorted_intervals[i])) % 12 + 12) % 12
		for j in degrees.size():
			var deg: int = int(degrees[j])
			var off: int = int(_DEGREE_TO_LETTER_OFFSET.get(deg, 0))
			var nat: int = int(LETTER_PC.get(NOTE_LETTERS[(root_idx + off) % 7], 0))
			var acc: int = ((target_pc - nat + 6) % 12 + 12) % 12 - 6
			pairs.append({"i": i, "deg": deg, "cost": absi(acc)})
	pairs.sort_custom(func(a, b): return int(a["cost"]) < int(b["cost"]))
	var used_i: Dictionary = {}
	var used_deg: Dictionary = {}
	for p in pairs:
		var pi: int = int(p["i"])
		var pd: int = int(p["deg"])
		if used_i.has(pi) or used_deg.has(pd):
			continue
		result[pi] = pd
		used_i[pi] = true
		used_deg[pd] = true
	return result


# Public entry: spell a single chord tone given the chord context.
# Useful when caller has the bass-pc and wants its correct letter under
# the current chord's intended structure.
static func spell_chord_bass(root_letter: String, root_acc: int, intervals: Array, quality: String, bass_pc: int) -> String:
	var tones: Array = spell_chord_tones(root_letter, root_acc, intervals, quality)
	if tones.is_empty():
		return ""
	var bass_pc_norm: int = ((bass_pc % 12) + 12) % 12
	var root_pc_natural: int = int(LETTER_PC.get(root_letter, 0))
	var root_pc: int = ((root_pc_natural + root_acc) % 12 + 12) % 12
	# Find which tone has matching pitch class.
	for tone in tones:
		var letter: String = str(tone.get("letter", ""))
		var acc: int = int(tone.get("accidental", 0))
		var natural_pc: int = int(LETTER_PC.get(letter, 0))
		var tone_pc: int = ((natural_pc + acc) % 12 + 12) % 12
		if tone_pc == bass_pc_norm:
			return format_pitch(letter, acc)
	# Bass isn't a chord tone — fall back to generic spelling using the
	# root's preferred enharmonic family.
	var prefer_flats: bool = root_acc < 0
	return format_pitch_pc(bass_pc_norm, prefer_flats)


# Choose the root spelling (letter + accidental) for a chord rooted on `root_pc`
# that engraves the WHOLE chord most cleanly — fewest accidentals, and never a
# double sharp/flat when an enharmonic root avoids it. This is the fix for the
# "Bb major triad shows as A#–C##–E#" class of bug: a naive key-based root
# spelling can pick A# (because the key prefers sharps), and then every chord
# tone inherits that, producing absurd double accidentals. We instead try every
# plausible root letter and keep the one whose chord-tone spelling is simplest.
# `prefer_flats` only breaks genuine ties (e.g. a flat key context).
static func best_root_spelling(root_pc: int, intervals: Array, quality: String, prefer_flats: bool = false) -> Dictionary:
	var pc := ((int(root_pc) % 12) + 12) % 12
	var candidates: Array = []
	for letter in NOTE_LETTERS:
		var natural_pc: int = int(LETTER_PC[letter])
		# Nearest signed accidental that maps this letter onto pc, in [-6, 5].
		var acc: int = ((pc - natural_pc + 6) % 12 + 12) % 12 - 6
		if absi(acc) <= 2:
			candidates.append({"letter": letter, "acc": acc})
	if candidates.is_empty():
		return _pc_fallback_spelling(pc, prefer_flats)
	var best: Dictionary = {}
	var best_score: float = INF
	for cand in candidates:
		var c: Dictionary = cand
		var tones: Array = spell_chord_tones(str(c.letter), int(c.acc), intervals, quality)
		var score: float = _accidental_penalty(int(c.acc))
		for t in tones:
			score += _accidental_penalty(int((t as Dictionary).get("accidental", 0)))
		# Mild tie-breakers: simpler root letter, then key flat/sharp preference.
		score += 0.10 * float(absi(int(c.acc)))
		if int(c.acc) < 0 and not prefer_flats:
			score += 0.05
		elif int(c.acc) > 0 and prefer_flats:
			score += 0.05
		if score < best_score:
			best_score = score
			best = c
	return best


static func _accidental_penalty(acc: int) -> float:
	var a: int = absi(acc)
	if a >= 2:
		return 10.0 + float(a)   # double accidentals are heavily discouraged
	return float(a)


static func _pc_fallback_spelling(pc: int, prefer_flats: bool) -> Dictionary:
	const SHARP := [["C", 0], ["C", 1], ["D", 0], ["D", 1], ["E", 0], ["F", 0], ["F", 1], ["G", 0], ["G", 1], ["A", 0], ["A", 1], ["B", 0]]
	const FLAT := [["C", 0], ["D", -1], ["D", 0], ["E", -1], ["E", 0], ["F", 0], ["G", -1], ["G", 0], ["A", -1], ["A", 0], ["B", -1], ["B", 0]]
	var tbl: Array = FLAT if prefer_flats else SHARP
	var e: Array = tbl[((pc % 12) + 12) % 12]
	return {"letter": str(e[0]), "acc": int(e[1])}


# Format a (letter, accidental) pair as e.g. "Bb", "F#", "B", "Bbb".
static func format_pitch(letter: String, accidental: int) -> String:
	if accidental == 0:
		return letter
	if accidental == 1:
		return letter + "#"
	if accidental == -1:
		return letter + "b"
	if accidental == 2:
		return letter + "##"
	if accidental == -2:
		return letter + "bb"
	return letter


# Generic fallback when no chord context is available.
static func format_pitch_pc(pc: int, prefer_flats: bool) -> String:
	const SHARP_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	const FLAT_NAMES  := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
	var pc_norm: int = ((pc % 12) + 12) % 12
	return FLAT_NAMES[pc_norm] if prefer_flats else SHARP_NAMES[pc_norm]


# Heuristic letter-offset when the chord quality isn't in the table.
# Looks at the interval class and tries to pick the most-musical slot.
static func _fallback_letter_offset(iv_mod: int, all_intervals: Array) -> int:
	var has_third: bool = false
	var has_seventh: bool = false
	var has_five: bool = false
	for ov in all_intervals:
		var m: int = ((int(ov) % 12) + 12) % 12
		if m == 3 or m == 4:
			has_third = true
		if m == 10 or m == 11:
			has_seventh = true
		if m == 7:
			has_five = true
	match iv_mod:
		0: return 0
		1: return 1 if has_third else 1
		2: return 1
		3, 4: return 2
		5: return 3
		6: return 3 if has_five else 4
		7, 8: return 4
		9:
			if has_seventh:
				return 5  # 13th
			if not has_seventh and _intervals_contain_six(all_intervals):
				return 6  # dim7's bb7
			return 5
		10, 11: return 6
	return 0


static func _intervals_contain_six(intervals: Array) -> bool:
	for ov in intervals:
		var m: int = ((int(ov) % 12) + 12) % 12
		if m == 6:
			return true
	return false
