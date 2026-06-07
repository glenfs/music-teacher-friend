class_name FingeringRules

# Centralized fingering tables for Practice Drills technical exercises.
#
# Sources used to normalize the tables:
# - pianoscales.org major/minor scale fingering pages
# - Baylor Piano Basics scale and arpeggio chapters
#
# The key point is that multi-octave scales are not a literal repeat of the
# one-octave fingering. The octave crossing changes the leading finger of the
# next segment, so we keep explicit first-octave and bridge patterns. The
# returned sequence includes both ascent and mirrored descent so the renderer
# can label every pitched note.

# Keyed by FIFTHS (-6..+6), matching _SCALE_PROFILES_MINOR. Previously this table
# was keyed by pitch class while scale_fingerings() looked it up by fifths, so the
# flat keys (F=-1, Bb=-2, Eb=-3, Ab=-4, Db=-5, Gb=-6) all missed and fell back to
# the generic C-major fingering — wrong, and visible above the noteheads.
const _SCALE_PROFILES_MAJOR := {
	0:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # C
	1:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # G
	2:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # D
	3:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # A
	4:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # E
	5:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [4, 3, 2, 1, 4, 3, 2, 1], "bridge": [3, 2, 1, 4, 3, 2, 1]}}, # B
	6:  {"rh": {"first": [2, 3, 4, 1, 2, 3, 1, 2], "bridge": [3, 4, 1, 2, 3, 1, 2]}, "lh": {"first": [4, 3, 2, 1, 3, 2, 1, 4], "bridge": [3, 2, 1, 3, 2, 1, 4]}}, # F#/Gb
	-1: {"rh": {"first": [1, 2, 3, 4, 1, 2, 3, 4], "bridge": [1, 2, 3, 4, 1, 2, 3]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # F
	-2: {"rh": {"first": [2, 1, 2, 3, 1, 2, 3, 4], "bridge": [2, 1, 2, 3, 1, 2, 3]}, "lh": {"first": [3, 2, 1, 4, 3, 2, 1, 3], "bridge": [2, 1, 4, 3, 2, 1, 3]}}, # Bb
	-3: {"rh": {"first": [3, 1, 2, 3, 4, 1, 2, 3], "bridge": [1, 2, 3, 4, 1, 2, 3]}, "lh": {"first": [3, 2, 1, 4, 3, 2, 1, 3], "bridge": [2, 1, 4, 3, 2, 1, 3]}}, # Eb
	-4: {"rh": {"first": [3, 4, 1, 2, 3, 1, 2, 3], "bridge": [4, 1, 2, 3, 1, 2, 3]}, "lh": {"first": [3, 2, 1, 4, 3, 2, 1, 3], "bridge": [2, 1, 4, 3, 2, 1, 3]}}, # Ab
	-5: {"rh": {"first": [2, 3, 1, 2, 3, 4, 1, 2], "bridge": [3, 1, 2, 3, 4, 1, 2]}, "lh": {"first": [3, 2, 1, 4, 3, 2, 1, 3], "bridge": [2, 1, 4, 3, 2, 1, 3]}}, # Db
	-6: {"rh": {"first": [2, 3, 4, 1, 2, 3, 1, 2], "bridge": [3, 4, 1, 2, 3, 1, 2]}, "lh": {"first": [4, 3, 2, 1, 3, 2, 1, 4], "bridge": [3, 2, 1, 3, 2, 1, 4]}}, # Gb
}

const _SCALE_PROFILES_MINOR := {
	0:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # A minor
	1:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # E minor
	2:  {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [4, 3, 2, 1, 4, 3, 2, 1], "bridge": [3, 2, 1, 4, 3, 2, 1]}}, # B minor
	3:  {"rh": {"first": [2, 3, 1, 2, 3, 1, 2, 3], "bridge": [3, 1, 2, 3, 1, 2, 3]}, "lh": {"first": [4, 3, 2, 1, 3, 2, 1, 4], "bridge": [3, 2, 1, 3, 2, 1, 4]}}, # F# / Gb minor
	4:  {"rh": {"first": [3, 4, 1, 2, 3, 1, 2, 3], "bridge": [4, 1, 2, 3, 1, 2, 3]}, "lh": {"first": [3, 2, 1, 4, 3, 2, 1, 3], "bridge": [2, 1, 4, 3, 2, 1, 3]}}, # C# / Db minor
	5:  {"rh": {"first": [3, 4, 1, 2, 3, 1, 2, 3], "bridge": [4, 1, 2, 3, 1, 2, 3]}, "lh": {"first": [3, 2, 1, 3, 2, 1, 4, 3], "bridge": [2, 1, 3, 2, 1, 4, 3]}}, # G# / Ab minor
	6:  {"rh": {"first": [3, 1, 2, 3, 4, 1, 2, 3], "bridge": [1, 2, 3, 4, 1, 2, 3]}, "lh": {"first": [2, 1, 4, 3, 2, 1, 3, 2], "bridge": [1, 4, 3, 2, 1, 3, 2]}}, # D# / Eb minor
	-1: {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # D minor
	-2: {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # G minor
	-3: {"rh": {"first": [1, 2, 3, 1, 2, 3, 4, 5], "bridge": [2, 3, 1, 2, 3, 4, 5]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # C minor
	-4: {"rh": {"first": [1, 2, 3, 4, 1, 2, 3, 4], "bridge": [1, 2, 3, 4, 1, 2, 3]}, "lh": {"first": [5, 4, 3, 2, 1, 3, 2, 1], "bridge": [4, 3, 2, 1, 3, 2, 1]}}, # F minor
	-5: {"rh": {"first": [2, 1, 2, 3, 1, 2, 3, 4], "bridge": [2, 1, 2, 3, 1, 2, 3]}, "lh": {"first": [2, 1, 3, 2, 1, 4, 3, 2], "bridge": [1, 3, 2, 1, 4, 3, 2]}}, # Bb minor
	-6: {"rh": {"first": [3, 1, 2, 3, 4, 1, 2, 3], "bridge": [1, 2, 3, 4, 1, 2, 3]}, "lh": {"first": [2, 1, 4, 3, 2, 1, 3, 2], "bridge": [1, 4, 3, 2, 1, 3, 2]}}, # Eb minor
}


static func scale_fingerings(fifths: int, key_is_minor: bool, octaves: int, hand: String) -> Array:
	if octaves <= 0:
		return []
	var profile := _scale_profile(fifths, key_is_minor, hand)
	if profile.is_empty():
		return _fallback_scale_fingerings(octaves, hand)
	var first: Array = profile.get("first", [])
	var bridge: Array = profile.get("bridge", [])
	if first.is_empty() or bridge.is_empty():
		return _fallback_scale_fingerings(octaves, hand)
	var asc: Array = first.duplicate()
	for _o in range(maxi(0, octaves - 1)):
		asc.append_array(bridge)
	var out: Array = asc.duplicate()
	if not asc.is_empty():
		var desc := asc.duplicate()
		desc.pop_back()
		desc.reverse()
		out.append_array(desc)
	return out


static func arpeggio_fingerings(octaves: int, hand: String) -> Array:
	var result: Array = []
	if octaves <= 0:
		return result
	if hand == "left":
		result.append_array([5, 3, 2, 1])
		for _o in range(maxi(0, octaves - 1)):
			result.append_array([3, 2, 1])
	else:
		result.append_array([1, 2, 3, 1])
		for _o in range(maxi(0, octaves - 1)):
			result.append_array([2, 3, 1])
	var out: Array = result.duplicate()
	if not result.is_empty():
		var desc := result.duplicate()
		desc.pop_back()
		desc.reverse()
		out.append_array(desc)
	return out


static func five_finger_fingerings(hand: String) -> Array:
	if hand == "left":
		return [5, 4, 3, 2, 1, 2, 3, 4, 5]
	return [1, 2, 3, 4, 5, 4, 3, 2, 1]


static func scale_profile(fifths: int, key_is_minor: bool, hand: String) -> Dictionary:
	return _scale_profile(fifths, key_is_minor, hand)


static func _scale_profile(fifths: int, key_is_minor: bool, hand: String) -> Dictionary:
	var bank: Dictionary = _SCALE_PROFILES_MINOR if key_is_minor else _SCALE_PROFILES_MAJOR
	var profile: Dictionary = bank.get(fifths, {})
	if profile.is_empty():
		return {}
	var hand_key := "lh" if hand == "left" else "rh"
	var entry: Dictionary = profile.get(hand_key, {})
	if entry.is_empty():
		return {}
	return {
		"first": entry.get("first", []),
		"bridge": entry.get("bridge", []),
	}


# --- Centralized fingering writer (CONTRACT) ---
#
# Every exercise composer that emits per-note fingerings MUST go through
# this helper instead of writing the `fingering` field directly. The
# helper applies the universal LH mirror (1↔5, 2↔4, 3↔3) so a pattern
# encoded as a RIGHT-hand thumb-to-pinky sequence is automatically
# transformed for the left hand.
#
# WHY: piano left hand is geometrically mirrored from the right — pinky
# (5) sits on the LOWEST note, thumb (1) on the HIGHEST. A pattern like
# [1, 2, 3, 4, 5] (RH ascending C-D-E-F-G with thumb on C) becomes
# nonsense on LH (thumb on the bottom note is wrong); the LH equivalent
# is [5, 4, 3, 2, 1]. The 6-f mirror does exactly that.
#
# Bidirectional patterns like [1, 2, 3, 4, 5, 4, 3, 2, 1] correctly
# round-trip: mirrored = [5, 4, 3, 2, 1, 2, 3, 4, 5].
#
# Calling this helper with hand="right" is a no-op transform but still
# the right entry point so future cross-cutting rules (e.g., 4th-finger
# avoidance under chromatic passages) land in one place.
static func apply_fingering_pattern(notes: Array, pattern: Array, hand: String = "right") -> void:
	if pattern.is_empty() or notes.is_empty():
		return
	var mirror_lh: bool = hand == "left"
	var p_len: int = pattern.size()
	var p_idx: int = 0
	for note_any in notes:
		var note: Dictionary = note_any
		if int(note.get("midi", -1)) < 0 or bool(note.get("rest", false)):
			continue
		var f: int = int(pattern[p_idx % p_len])
		if mirror_lh and f >= 1 and f <= 5:
			f = 6 - f
		note["fingering"] = f
		p_idx += 1


static func _fallback_scale_fingerings(octaves: int, hand: String) -> Array:
	var result: Array = []
	if octaves <= 0:
		return result
	var first: Array
	var bridge: Array
	if hand == "left":
		first = [5, 4, 3, 2, 1, 3, 2, 1]
		bridge = [4, 3, 2, 1, 3, 2, 1]
	else:
		first = [1, 2, 3, 1, 2, 3, 4, 5]
		bridge = [2, 3, 1, 2, 3, 4, 5]
	result.append_array(first)
	for _o in range(maxi(0, octaves - 1)):
		result.append_array(bridge)
	var out: Array = result.duplicate()
	if not result.is_empty():
		var desc := result.duplicate()
		desc.pop_back()
		desc.reverse()
		out.append_array(desc)
	return out
