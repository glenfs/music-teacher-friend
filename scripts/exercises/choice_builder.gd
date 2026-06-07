class_name ChoiceBuilder
extends RefCounted

# Pure multiple-choice distractor builders for ear training / theory rounds.
# All inputs are passed in as params — no instance state required.
#
# The caller (interval_birds.gd) keeps:
#   - the live RNG instance (for reproducible runs we share it across rounds)
#   - the user-chosen choice_count from settings
#   - INTERVAL_DATA / PROGRESSION_DEFS / Distractors at top of file
# and just forwards them in.


const DistractorsScript = preload("res://scripts/training/distractors.gd")


# Chords commonly confused with a given chord (used to pick a "hardest"
# distractor first so the round has at least one tough wrong answer).
const SIMILAR_CHORDS := {
	"Major":       ["Maj7", "Dom7", "Sus4", "Power"],
	"Minor":       ["Min7", "Dim", "mMaj7", "Sus2"],
	"Dom7":        ["Maj7", "Major", "Min7", "7sus4"],
	"Maj7":        ["Dom7", "Major", "Maj6", "AugMaj7"],
	"Min7":        ["Minor", "Dom7", "Half-dim", "mMaj7"],
	"Dim":  ["Minor", "Half-dim", "Dim7"],
	"Aug":   ["Major", "AugMaj7", "Aug7"],
	"Sus2":        ["Minor", "Sus4", "Add9"],
	"Sus4":        ["Major", "Sus2", "7sus4"],
	"Dim7":        ["Dim", "Half-dim", "Min7"],
	"Half-dim":    ["Min7", "Dim7", "Dim"],
	"mMaj7":       ["Minor", "Min7", "Maj7"],
	"Aug7":        ["Dom7", "Aug", "AugMaj7"],
	"AugMaj7":     ["Maj7", "Aug", "Aug7"],
	"7sus4":       ["Dom7", "Sus4", "Maj7"],
	"Maj6":        ["Major", "Maj7", "Min6"],
	"Min6":        ["Minor", "Maj6", "Min7"],
	"6/9":         ["Maj6", "Add9", "Maj9"],
	"Dom9":        ["Dom7", "Maj9", "Min9"],
	"Maj9":        ["Maj7", "Dom9", "Add9"],
	"Min9":        ["Min7", "Dom9", "Maj9"],
	"Add9":        ["Major", "Maj9", "Sus2"],
	"Power":       ["Major", "Sus4", "Minor"],
}


static func similar_chord_names(chord_name: String) -> Array:
	return SIMILAR_CHORDS.get(chord_name, [])


# Build interval choices: correct + closest-by-semitone distractors. `pool`
# must come from the player's active interval selection; `interval_data` is
# the caller's INTERVAL_DATA const (passed so this module stays standalone).
static func interval_choices(correct_id: String, pool: Array[String], choice_count: int, interval_data: Dictionary) -> Array[String]:
	var correct_st: int = int(interval_data.get(correct_id, {"semitones": [0]})["semitones"][0])
	var distractors: Array[String] = []
	for id in pool:
		var iid := str(id)
		if iid != correct_id:
			distractors.append(iid)
	distractors.sort_custom(func(a: String, b: String) -> bool:
		var a_st: int = int(interval_data.get(a, {"semitones": [0]})["semitones"][0])
		var b_st: int = int(interval_data.get(b, {"semitones": [0]})["semitones"][0])
		return abs(a_st - correct_st) < abs(b_st - correct_st)
	)
	var choices: Array[String] = [correct_id]
	var pick_count := mini(maxi(1, choice_count - 1), distractors.size())
	for di in range(pick_count):
		choices.append(distractors[di])
	choices.shuffle()
	return choices


# Build chord choices: correct + 1 confusable + random fill from the player's pool.
static func chord_choices(correct_name: String, pool: Array[String], choice_count: int) -> Array[String]:
	var choices: Array[String] = [correct_name]
	var similar := similar_chord_names(correct_name)
	for s in similar:
		var sv := str(s)
		if pool.has(sv) and sv != correct_name and not choices.has(sv):
			choices.append(sv)
			break
	var distractors: Array[String] = []
	for chord_name in pool:
		var n: String = str(chord_name)
		if n != correct_name and not choices.has(n):
			distractors.append(n)
	distractors.shuffle()
	var max_distractors: int = maxi(0, mini(choice_count - choices.size(), distractors.size()))
	for di in range(max_distractors):
		choices.append(distractors[di])
	choices.shuffle()
	return choices


# Generic text-choice builder for scale/cadence/etc. Uses the Distractors module's
# similarity heuristic to pick the hardest wrong answers.
static func text_choices(correct_name: String, pool: Array[String], count: int = 4) -> Array[String]:
	var candidates: Array[String] = []
	for item in pool:
		var n := str(item)
		if not candidates.has(n):
			candidates.append(n)
	var picks := maxi(1, mini(count - 1, maxi(0, candidates.size() - 1)))
	var distractors: Array[String] = DistractorsScript.pick_similar(correct_name, candidates, picks)
	if distractors.size() < picks:
		var fallback: Array[String] = []
		for n in candidates:
			if n != correct_name and not distractors.has(n):
				fallback.append(n)
		fallback.shuffle()
		for n in fallback:
			distractors.append(n)
			if distractors.size() >= picks:
				break
	var choices: Array[String] = [correct_name]
	for di in range(mini(picks, distractors.size())):
		choices.append(distractors[di])
	choices.shuffle()
	return choices


# Progression-label distractors. Ranks candidates by structural similarity to
# the correct progression: same length first, then matching first/last chord,
# then count of shared scale degrees. RNG passed in for the small tiebreaker
# jitter so the round stays reproducible vs. the caller's seeded run.
static func progression_label_choices(
	correct_progression_id: String,
	progression_ids: Array[String],
	progression_defs: Dictionary,
	rng: RandomNumberGenerator
) -> Array[String]:
	var correct_def: Dictionary = progression_defs.get(correct_progression_id, {})
	var correct_label := str(correct_def.get("label", correct_progression_id))
	var correct_steps: Array = correct_def.get("steps", [])
	var target_len := correct_steps.size()
	var same_len_pool: Array[String] = []
	var other_pool: Array[String] = []
	var label_to_steps: Dictionary = {}
	for pid_any in progression_ids:
		var pid := str(pid_any)
		if pid == correct_progression_id:
			continue
		var pdef: Dictionary = progression_defs.get(pid, {})
		var label := str(pdef.get("label", pid))
		if label == "":
			continue
		var steps: Array = pdef.get("steps", [])
		label_to_steps[label] = steps.duplicate()
		if steps.size() == target_len:
			same_len_pool.append(label)
		else:
			other_pool.append(label)
	var count := 3 if progression_ids.size() >= 3 else maxi(2, progression_ids.size())
	var distractor_count := maxi(1, count - 1)
	var distractors: Array[String] = []
	var mixed_pool: Array[String] = []
	for item_same in same_len_pool:
		if not mixed_pool.has(item_same):
			mixed_pool.append(item_same)
	for item_other in other_pool:
		if not mixed_pool.has(item_other):
			mixed_pool.append(item_other)
	var ranked_pool: Array[Dictionary] = []
	for label_any in mixed_pool:
		var label := str(label_any)
		var steps_any: Array = label_to_steps.get(label, [])
		var score := 0
		if steps_any.size() == target_len:
			score += 20
		if not correct_steps.is_empty() and not steps_any.is_empty():
			if int(steps_any[0]) == int(correct_steps[0]):
				score += 12
			if int(steps_any[steps_any.size() - 1]) == int(correct_steps[correct_steps.size() - 1]):
				score += 12
		var overlap := 0
		for step in steps_any:
			if correct_steps.has(step):
				overlap += 1
		score += overlap * 4
		score += rng.randi_range(0, 2)
		ranked_pool.append({"label": label, "score": score})
	ranked_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	for item_ranked in ranked_pool:
		var picked := str(item_ranked.get("label", ""))
		if picked == "" or picked == correct_label or distractors.has(picked):
			continue
		distractors.append(picked)
		if distractors.size() >= distractor_count:
			break
	if distractors.size() < distractor_count:
		var more := DistractorsScript.pick_similar(correct_label, mixed_pool, distractor_count)
		for item2 in more:
			if item2 != correct_label and not distractors.has(item2):
				distractors.append(item2)
			if distractors.size() >= distractor_count:
				break
	var choices: Array[String] = [correct_label]
	for di in range(mini(distractor_count, distractors.size())):
		choices.append(distractors[di])
	choices.shuffle()
	return choices
