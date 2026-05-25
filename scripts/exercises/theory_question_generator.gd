class_name TheoryQuestionGenerator
extends RefCounted

# Pure question generators for the three theory ear-training modes
# (Progression, Scale/Mode, Cadence). Each `build_*` produces the payload
# dict the caller applies to its UI state.
#
# All inputs are passed in — no instance state. The caller owns the live
# RNG, the active review queue, the selection arrays, the data dicts
# (PROGRESSION_DEFS / SCALE_MODE_DEFS / CADENCE_DEFS), and the CHORD_INTERVALS
# table used for diatonic triad construction.


const ChoiceBuilderScript = preload("res://scripts/exercises/choice_builder.gd")


# Returns the user's selected progression ids, filtered through PROGRESSION_DEFS
# membership. Falls back to ["IVviIV", "iiVI"] when the selection is empty.
static func selected_progression_ids(progression_selected: Array, progression_defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for pid in progression_selected:
		var key := str(pid)
		if progression_defs.has(key) and not out.has(key):
			out.append(key)
	if out.is_empty():
		out = ["IVviIV", "iiVI"]
	return out


static func selected_scale_mode_ids(scale_selected_modes: Array, scale_mode_defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for mode_name in scale_selected_modes:
		var key := str(mode_name)
		if scale_mode_defs.has(key) and not out.has(key):
			out.append(key)
	if out.is_empty():
		out = ["Major", "Natural Minor", "Dorian", "Mixolydian"]
	return out


static func selected_cadence_ids(cadence_selected: Array, cadence_defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for cadence_name in cadence_selected:
		var key := str(cadence_name)
		if cadence_defs.has(key) and not out.has(key):
			out.append(key)
	if out.is_empty():
		out = ["Perfect", "Plagal", "Half", "Deceptive"]
	return out


# Narrows the cadence selection to whichever ids appear in the focus-misses
# pool. Returns the full selection if no focus-misses match.
static func selected_cadence_ids_for_current_round(cadence_selected: Array, cadence_defs: Dictionary, focus_missed_ids: Array) -> Array[String]:
	var selected := selected_cadence_ids(cadence_selected, cadence_defs)
	if focus_missed_ids.is_empty():
		return selected
	var focused: Array[String] = []
	for miss_any in focus_missed_ids:
		var miss := str(miss_any)
		for key_any in cadence_defs.keys():
			var key := str(key_any)
			var def: Dictionary = cadence_defs.get(key, {})
			var label := str(def.get("label", key))
			if miss != key and miss != label:
				continue
			if not focused.has(key):
				focused.append(key)
	if focused.is_empty():
		return selected
	return focused


# Build the triad notes for a given diatonic step (0..6) over a given root.
# Uses the major-scale step pattern + I-ii-iii-IV-V-vi-vii° quality template.
static func diatonic_triad_notes(step_index: int, root_midi: int, chord_intervals: Dictionary) -> Array[int]:
	var degree_steps := [0, 2, 4, 5, 7, 9, 11]
	var triad_qualities := ["Major", "Minor", "Minor", "Major", "Major", "Minor", "Dim"]
	var idx := clampi(step_index, 0, 6)
	var triad_root := root_midi + int(degree_steps[idx])
	var quality := str(triad_qualities[idx])
	var intervals: Array[int] = []
	for iv in chord_intervals.get(quality, [0, 4, 7]):
		intervals.append(int(iv))
	var notes: Array[int] = []
	for iv in intervals:
		notes.append(triad_root + int(iv))
	return notes


# Progression question. Returns the payload dict the caller applies via
# _apply_theory_question_payload.
static func build_progression_payload(
	progression_selected: Array,
	progression_defs: Dictionary,
	chord_intervals: Dictionary,
	review_queue: RefCounted,
	rng: RandomNumberGenerator
) -> Dictionary:
	var progression_ids := selected_progression_ids(progression_selected, progression_defs)
	var picked_id := str(review_queue.pick_next(progression_ids)) if review_queue != null else ""
	if picked_id == "":
		picked_id = progression_ids[rng.randi_range(0, progression_ids.size() - 1)]
	var prog_def: Dictionary = progression_defs.get(picked_id, progression_defs["IVviIV"])
	var correct_label := str(prog_def.get("label", picked_id))
	var progression_notes: Array = []
	var steps: Array = prog_def.get("steps", [3, 5, 3])
	for step in steps:
		progression_notes.append(diatonic_triad_notes(int(step), 48, chord_intervals))
	var progression_choices := ChoiceBuilderScript.progression_label_choices(picked_id, progression_ids, progression_defs, rng)
	return {
		"id": "progression:%s" % picked_id,
		"item_id": picked_id,
		"prompt": "Choose the progression:",
		"correct": correct_label,
		"choices": progression_choices,
		"progression_notes": progression_notes,
	}


# Scale / mode question. SCALE_MODE_DEFS maps mode name → semitone offsets
# from the tonic (always C4 = 60 for now).
static func build_scale_mode_payload(
	scale_selected_modes: Array,
	scale_mode_defs: Dictionary,
	review_queue: RefCounted,
	rng: RandomNumberGenerator
) -> Dictionary:
	var selected_modes := selected_scale_mode_ids(scale_selected_modes, scale_mode_defs)
	var picked_mode := str(review_queue.pick_next(selected_modes)) if review_queue != null else ""
	if picked_mode == "":
		picked_mode = selected_modes[rng.randi_range(0, selected_modes.size() - 1)]
	var scale_notes: Array[int] = []
	var scale_steps: Array = scale_mode_defs.get(picked_mode, scale_mode_defs["Major"])
	for step in scale_steps:
		scale_notes.append(60 + int(step))
	return {
		"id": "scale:%s" % picked_mode,
		"item_id": picked_mode,
		"prompt": "Choose the scale/mode:",
		"correct": picked_mode,
		"choices": ChoiceBuilderScript.text_choices(picked_mode, selected_modes, 4),
		"scale_notes": scale_notes,
	}


# Cadence question. Picks a fresh key root each call so players hear the
# pattern in different keys; the chosen root is returned in `play_root` so the
# caller can stash it for the playback step.
static func build_cadence_payload(
	cadence_selected: Array,
	cadence_defs: Dictionary,
	chord_intervals: Dictionary,
	cadence_key_roots: Array,
	focus_missed_ids: Array,
	review_queue: RefCounted,
	rng: RandomNumberGenerator
) -> Dictionary:
	var selected_cadences := selected_cadence_ids_for_current_round(cadence_selected, cadence_defs, focus_missed_ids)
	var cadence_id := str(review_queue.pick_next(selected_cadences)) if review_queue != null else ""
	if cadence_id == "":
		cadence_id = selected_cadences[rng.randi_range(0, selected_cadences.size() - 1)]
	var cadence_def: Dictionary = cadence_defs.get(cadence_id, cadence_defs["Perfect"])
	var correct_cadence := str(cadence_def.get("label", cadence_id))
	var play_root: int = int(cadence_key_roots[rng.randi_range(0, cadence_key_roots.size() - 1)])
	var cadence_notes: Array = []
	var cadence_steps: Array = cadence_def.get("steps", [4, 0])
	for step in cadence_steps:
		cadence_notes.append(diatonic_triad_notes(int(step), play_root, chord_intervals))
	var cadence_labels: Array[String] = []
	for key in selected_cadences:
		cadence_labels.append(str(cadence_defs[key]["label"]))
	return {
		"id": "cadence:%s" % cadence_id,
		"item_id": cadence_id,
		"prompt": "Choose the cadence:",
		"correct": correct_cadence,
		"choices": ChoiceBuilderScript.text_choices(correct_cadence, cadence_labels, 4),
		"cadence_notes": cadence_notes,
		"play_root": play_root,
	}
