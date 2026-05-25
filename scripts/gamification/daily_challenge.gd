class_name DailyChallenge
extends RefCounted

# Pure daily-challenge config generator. Same input (today's date string) →
# same output for any user. Caller (interval_birds.gd) owns the persisted
# best-score map keyed by date, the home card rendering, and the start hook
# that selects the mode + key + question count; this module only computes
# the deterministic challenge spec.


# Returns today's date as YYYY-MM-DD (system local time).
static func today_date_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


# Returns the challenge config for the given date string. Keys:
#   date         — input date string (passed through for the caller's score key)
#   mode         — "Notes" or "Chords"
#   key_sig      — one of "C", "1#", "1b", "2#", "2b"
#   questions    — int, fixed at 10
#   label        — human-friendly description for UI display
static func config_for_date(date_str: String) -> Dictionary:
	# Simple integer hash from date — not cryptographic; just used for daily
	# rotation. 31-multiplier-and-mod-prime is a classic stable hash that gives
	# good spread over consecutive ISO dates.
	var h: int = 0
	for c in date_str:
		h = (h * 31 + c.unicode_at(0)) % 1000000007
	var rotation_modes: Array = ["Notes", "Chords", "Notes"]  # 2/3 weighting toward Notes
	var rotation_keys: Array[String] = ["C", "1#", "1b", "2#", "2b"]
	var picked_mode: String = rotation_modes[h % rotation_modes.size()]
	var picked_key: String = rotation_keys[(h / 3) % rotation_keys.size()]
	var question_count: int = 10
	var label: String = "Sight Reading: %s in %s · %d questions" % [picked_mode, picked_key, question_count]
	return {
		"date": date_str,
		"mode": picked_mode,
		"key_sig": picked_key,
		"questions": question_count,
		"label": label,
	}


# Convenience: today's config.
static func config_for_today() -> Dictionary:
	return config_for_date(today_date_str())
