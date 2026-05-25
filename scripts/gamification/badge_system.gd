class_name BadgeSystem
extends RefCounted

# Pure mastery-badge evaluation. Data + predicate logic only — persistence,
# UI rendering, and toast display stay in the caller (interval_birds.gd)
# because they touch instance state.
#
# Usage:
#   var newly = BadgeSystem.check_earned(_earned_badges, session_total, ...)
#   for bid in newly:
#       _earned_badges.append(bid)
#       _show_toast(bid)
#       _save()
#
# Adding a new badge:
#   1. Append a dict to DEFS with id/name/desc/icon (icon is a unicode codepoint).
#   2. Add a predicate branch in check_earned().
#   3. Optionally surface a new lifetime counter via a new check_earned param.


const DEFS: Array[Dictionary] = [
	{"id": "first_session",      "name": "First Steps",         "desc": "Complete your first quiz",                                 "icon": 0x2B50},
	{"id": "perfect_session",    "name": "Perfect Run",         "desc": "100% accuracy on a session of 5+ questions",              "icon": 0x1F3C6},
	{"id": "streak_10",          "name": "On Fire",             "desc": "Hit a 10-answer streak",                                  "icon": 0x1F525},
	{"id": "streak_25",          "name": "Legendary Streak",    "desc": "Hit a 25-answer streak",                                  "icon": 0x26A1},
	{"id": "sight_reader_100",   "name": "Sight Reader",        "desc": "100 correct sight-reading answers (lifetime)",            "icon": 0x1F4D6},
	{"id": "chord_whiz_100",     "name": "Chord Whiz",          "desc": "100 correct chord answers (lifetime)",                    "icon": 0x1F3B9},
	{"id": "daily_3",            "name": "Daily Devotee",       "desc": "Complete the daily challenge 3 days",                     "icon": 0x1F4C5},
]


# Returns the subset of badges newly met by the given session/lifetime context.
# Caller is responsible for filtering out already-earned ones (we still do an
# inclusion check here so this stays a pure function — caller passes its
# already_earned list).
static func check_earned(
	already_earned: Array,
	session_total: int,
	session_correct: int,
	session_best_streak: int,
	lifetime_correct_sight: int,
	lifetime_correct_chord: int,
	daily_completed_dates_count: int
) -> Array[String]:
	var out: Array[String] = []
	if not already_earned.has("first_session") and session_total > 0:
		out.append("first_session")
	if not already_earned.has("perfect_session") and session_total >= 5 and session_correct == session_total:
		out.append("perfect_session")
	if not already_earned.has("streak_10") and session_best_streak >= 10:
		out.append("streak_10")
	if not already_earned.has("streak_25") and session_best_streak >= 25:
		out.append("streak_25")
	if not already_earned.has("sight_reader_100") and lifetime_correct_sight >= 100:
		out.append("sight_reader_100")
	if not already_earned.has("chord_whiz_100") and lifetime_correct_chord >= 100:
		out.append("chord_whiz_100")
	if not already_earned.has("daily_3") and daily_completed_dates_count >= 3:
		out.append("daily_3")
	return out


# Lookup a single badge def by id. Returns {} if not found.
static func find_def(badge_id: String) -> Dictionary:
	for d in DEFS:
		if str(d.get("id", "")) == badge_id:
			return d
	return {}
