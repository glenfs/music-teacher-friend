extends RefCounted
class_name SingingEvaluator

# Pure evaluator for sight-singing. Compares a target MIDI against a detected
# pitch + cents-off and returns one of five accuracy bands plus a colour /
# label / score that the UI can present consistently.
#
# Match is octave-agnostic (pitch-class equality) — the singer's own octave
# is fine, what matters is whether the pitch class lines up.

# Band integer constants. Using ints over enums so the values pass cleanly
# through Dictionary returns without enum-class scoping awkwardness.
const BAND_CORRECT := 0
const BAND_CLOSE   := 1
const BAND_PITCHY  := 2
const BAND_WRONG   := 3
const BAND_UNCERTAIN := 4

# Cents-off thresholds. Anything inside the band's window scores in that band.
const CORRECT_CENTS := 20.0   # ±20¢ → Excellent
const CLOSE_CENTS   := 50.0   # ±50¢ → Close
const PITCHY_CENTS  := 100.0  # ±100¢ but right pitch class → Pitchy (orange)
# Wrong pitch class → Wrong note regardless of cents.


# Evaluates one note. Returns:
#   {
#     "band":     BAND_* int,
#     "pc_match": bool,
#     "cents_off": float (signed; positive = sharp),
#   }
static func evaluate(target_midi: int, detected_midi: int, cents_off: float) -> Dictionary:
	var target_pc: int = posmod(target_midi, 12)
	var detected_pc: int = posmod(detected_midi, 12)
	if target_pc != detected_pc:
		return {"band": BAND_WRONG, "pc_match": false, "cents_off": cents_off}
	var abs_cents: float = absf(cents_off)
	var band: int
	if abs_cents <= CORRECT_CENTS:
		band = BAND_CORRECT
	elif abs_cents <= CLOSE_CENTS:
		band = BAND_CLOSE
	else:
		band = BAND_PITCHY
	return {"band": band, "pc_match": true, "cents_off": cents_off}


# Display colour for a band. Used by the staff renderer to tint completed notes.
static func band_color(band: int) -> Color:
	match band:
		BAND_CORRECT: return Color(0.36, 0.82, 0.46, 1.0)  # green
		BAND_CLOSE:   return Color(0.95, 0.84, 0.30, 1.0)  # yellow
		BAND_PITCHY:  return Color(0.95, 0.60, 0.22, 1.0)  # orange
		BAND_WRONG:   return Color(0.95, 0.30, 0.32, 1.0)  # red
		BAND_UNCERTAIN: return Color(0.42, 0.72, 0.95, 1.0) # blue
	return Color(0.70, 0.70, 0.70, 1.0)


# Per-note score contribution. Cumulative average across notes gives the
# session percentage.
static func band_score(band: int) -> int:
	match band:
		BAND_CORRECT: return 100
		BAND_CLOSE:   return 70
		BAND_PITCHY:  return 50
		BAND_WRONG:   return 0
		BAND_UNCERTAIN: return 60
	return 0


# Human-friendly label for end-of-session feedback.
static func band_label(band: int) -> String:
	match band:
		BAND_CORRECT: return "Excellent"
		BAND_CLOSE:   return "Close"
		BAND_PITCHY:  return "Pitchy"
		BAND_WRONG:   return "Wrong note"
		BAND_UNCERTAIN: return "Uncertain"
	return "?"
