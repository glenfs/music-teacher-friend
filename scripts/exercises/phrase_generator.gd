extends RefCounted
class_name PhraseGenerator

# Phrase-coherent motif sequencer for Note Flow / Sight Reading.
# Produces a sequence of 4 bars (4 motifs) that share a tonal center and
# form a coherent melodic arc — antecedent (bars 0-1, opening up) and
# consequent (bars 2-3, return to tonic-area).
#
# A "phrase" is a small named structure picked once per phrase boundary:
#   { "id": "arc_up_down", "motifs": [ [0,2,4], [4,5,7], [7,5,4], [4,2,0] ] }
#
# Motifs are step-offset arrays relative to the phrase root. The caller picks
# a root step inside their staff bounds and adds each offset.

const PHRASES: Array[Dictionary] = [
	{
		"id": "arc_up_down",
		"label": "Arc up-down",
		"bars": [
			[0, 2, 4, 2],   # ascend to mediant, return
			[4, 5, 7, 5],   # leap to dominant, return
			[7, 5, 4, 2],   # descend through mediant
			[4, 2, 0, 0],   # cadence to tonic
		],
	},
	{
		"id": "stepwise_climb",
		"label": "Stepwise climb",
		"bars": [
			[0, 1, 2, 3],
			[4, 3, 2, 1],
			[2, 4, 6, 7],
			[5, 3, 1, 0],
		],
	},
	{
		"id": "triad_arpeggio",
		"label": "Triad arpeggio",
		"bars": [
			[0, 2, 4, 7],   # triad up
			[7, 4, 2, 0],   # triad down
			[0, 4, 7, 4],   # broken triad
			[2, 0, -3, 0],  # leading tone resolution
		],
	},
	{
		"id": "neighbor_tones",
		"label": "Neighbor tones",
		"bars": [
			[0, 1, 0, -1],   # upper/lower neighbor
			[0, 2, 1, 2],    # passing tone
			[4, 3, 4, 5],    # neighbor around dominant
			[4, 2, 1, 0],    # stepwise descent
		],
	},
	{
		"id": "antecedent_consequent",
		"label": "Question and answer",
		"bars": [
			[0, 2, 4, 5],   # rising question
			[5, 4, 2, 4],   # half-cadence feel
			[0, 2, 4, 5],   # repeat question
			[5, 4, 2, 0],   # full resolution
		],
	},
]


# Pick a phrase template at random. Caller stores the returned dict; rotates
# bars across consecutive calls via bar_index (0..3).
static func pick_phrase(rng: RandomNumberGenerator) -> Dictionary:
	return PHRASES[rng.randi_range(0, PHRASES.size() - 1)]


# Resolve a phrase's bar offsets into absolute staff steps, clamped to bounds.
# root_step is the tonic-ish anchor (e.g. middle-of-staff step).
static func bar_steps(phrase: Dictionary, bar_index: int, root_step: int, bounds: Vector2i) -> Array[int]:
	var bars_v: Variant = phrase.get("bars", [])
	if typeof(bars_v) != TYPE_ARRAY:
		return []
	var bars: Array = bars_v as Array
	if bars.is_empty():
		return []
	var idx: int = clampi(bar_index, 0, bars.size() - 1)
	var pattern: Array = bars[idx] as Array
	var out: Array[int] = []
	for off_v in pattern:
		var s: int = clampi(root_step + int(off_v), bounds.x, bounds.y)
		out.append(s)
	return out


# Total bars in a phrase (most are 4).
static func phrase_bar_count(phrase: Dictionary) -> int:
	var bars_v: Variant = phrase.get("bars", [])
	if typeof(bars_v) != TYPE_ARRAY:
		return 0
	return (bars_v as Array).size()
