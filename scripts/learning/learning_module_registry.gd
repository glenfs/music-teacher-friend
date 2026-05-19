extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")
const Module01 = preload("res://scripts/learning/modules/module_01_clef_barlines_time.gd")
const Module02a = preload("res://scripts/learning/modules/module_02a_treble_part1a.gd")
const Module02b = preload("res://scripts/learning/modules/module_02b_treble_part1b.gd")
const Module03a = preload("res://scripts/learning/modules/module_03a_bass_part1a.gd")
const Module03b = preload("res://scripts/learning/modules/module_03b_bass_part1b.gd")
const Module05 = preload("res://scripts/learning/modules/module_05_treble_part2.gd")
const Module06 = preload("res://scripts/learning/modules/module_06_bass_part2.gd")
const Module04 = preload("res://scripts/learning/modules/module_04_ledger_lines.gd")
const Module07 = preload("res://scripts/learning/modules/module_07_sharps_flats.gd")
const Module08 = preload("res://scripts/learning/modules/module_08_treble_part3.gd")
const Module09 = preload("res://scripts/learning/modules/module_09_bass_part3.gd")
const Module10a = preload("res://scripts/learning/modules/module_10a_rhythm_basics.gd")
const Module10b = preload("res://scripts/learning/modules/module_10b_rhythm_eighths.gd")
const Module10c = preload("res://scripts/learning/modules/module_10c_rhythm_sixteenths.gd")
const Module10d = preload("res://scripts/learning/modules/module_10d_rhythm_syncopation.gd")
const Module11 = preload("res://scripts/learning/modules/module_11_key_signatures.gd")
const Module12 = preload("res://scripts/learning/modules/module_12_grand_staff.gd")
const Module13 = preload("res://scripts/learning/modules/module_13_intervals_intro.gd")
const Module14 = preload("res://scripts/learning/modules/module_14_chord_basics.gd")
const Module15 = preload("res://scripts/learning/modules/module_15_capstone.gd")
const Module16 = preload("res://scripts/learning/modules/module_16_minor_scales.gd")
const Module17 = preload("res://scripts/learning/modules/module_17_interval_quality.gd")
const ModuleProgressScript = preload("res://scripts/learning/module_progress.gd")


# Resequenced order (rhythm moved earlier per curriculum review):
# 1. Clefs, Bar Lines & Time — fundamentals
# 2. Treble Notes Part 1A — C4, D4, E4
# 3. Treble Notes Part 1B — F4, G4
# 4. Bass Notes Part 1A — C4, B3, A3
# 5. Bass Notes Part 1B — G3, F3
# 6. Rhythm Basics — quarter, half, whole notes + rests
# 7. Rhythm: Eighth Notes & Dots — eighths, dotted half, mixed values
# 8. Rhythm: Sixteenths — pure subdivision and clean 4/4 bar math
# 9. Rhythm: Dotted Rhythms & Rests — syncopation and short rests
# 10. Treble Notes Part 2 — EGBDF, FACE, A4-C5
# 11. Bass Notes Part 2 — GBDFA, ACEG, E3-C3
# 12. Ledger Lines — after staff mastery
# 13. Sharps & Flats — enhanced with practice
# 14. Treble Notes Part 3 — D5-G5
# 15. Bass Notes Part 3 — B2-F2
# 16. Key Signatures
# 17. Minor Scales — builds on key signatures
# 18. Grand Staff
# 19. Intro to Intervals
# 20. Interval Quality — builds on intervals intro
# 21. Chord Basics
# 22. Capstone — The Final Challenge

static func get_all_modules() -> Array:
	return [
		Module01.get_module_data(),
		Module02a.get_module_data(),
		Module02b.get_module_data(),
		Module03a.get_module_data(),
		Module03b.get_module_data(),
		Module10a.get_module_data(),
		Module10b.get_module_data(),
		Module10c.get_module_data(),
		Module10d.get_module_data(),
		Module05.get_module_data(),
		Module06.get_module_data(),
		Module04.get_module_data(),
		Module07.get_module_data(),
		Module08.get_module_data(),
		Module09.get_module_data(),
		Module11.get_module_data(),
		Module16.get_module_data(),
		Module12.get_module_data(),
		Module13.get_module_data(),
		Module17.get_module_data(),
		Module14.get_module_data(),
		Module15.get_module_data(),
	]


static func get_module_by_id(id: String) -> Dictionary:
	for m in get_all_modules():
		if m["id"] == id:
			return m
	return {}


static func _build_listening_concept_id(item: Dictionary) -> String:
	var joined_ids := ""
	for note_id in item.get("note_ids", []):
		if joined_ids != "":
			joined_ids += "_"
		joined_ids += str(note_id)
	return "listening:%s:%s" % [str(item.get("label", "item")), joined_ids]


static func _build_keyboard_concept_id(step: Dictionary) -> String:
	return "keyboard:%s" % str(step.get("target_note_id", ""))


static func _get_rhythm_pattern_token(pattern_item: Variant) -> String:
	if pattern_item is Dictionary:
		var item: Dictionary = pattern_item
		var beats: float = float(item.get("beats", 1.0))
		if bool(item.get("rest", false)):
			return "rest_%s" % String.num(beats, 2)
		var kind: String = str(item.get("kind", "quarter"))
		return "%s_%s" % [kind, String.num(beats, 2)]
	return String.num(float(pattern_item), 2)


static func _build_rhythm_concept_id(step: Dictionary) -> String:
	var pattern_text := ""
	for beat in step.get("pattern", []):
		if pattern_text != "":
			pattern_text += "-"
		pattern_text += _get_rhythm_pattern_token(beat)
	return "rhythm:%s:%s" % [str(step.get("title", "pattern")), pattern_text]


static func _extract_concepts_from_step(step: Dictionary) -> Array[String]:
	var concepts: Array[String] = []
	if step.has("concept_id"):
		concepts.append(str(step.get("concept_id", "")))
	var stype: int = int(step.get("type", -1))
	match stype:
		LMD.STEP_QUIZ:
			var question: String = str(step.get("question", ""))
			if question != "":
				concepts.append("quiz:%s" % question.left(40))
		LMD.STEP_NOTE_QUIZ:
			var clef: String = str(step.get("clef", ""))
			var note_step: int = int(step.get("note_step", 0))
			var note_name: String = str(step.get("note_name", ""))
			var note_id := note_name if note_name.length() >= 2 and note_name[-1].is_valid_int() else LMD.step_to_note_id(clef, note_step)
			if clef != "" and note_id != "":
				concepts.append("%s:%s" % [clef, note_id])
		LMD.STEP_CUMULATIVE_QUIZ, LMD.STEP_PRACTICE_ROUND:
			var pool_type: String = str(step.get("pool_type", "note"))
			for pool_item_variant in step.get("pool", []):
				if not (pool_item_variant is Dictionary):
					continue
				var pool_item: Dictionary = pool_item_variant
				if pool_type == "theory":
					var pool_concept: String = str(pool_item.get("concept_id", ""))
					if pool_concept != "":
						concepts.append(pool_concept)
				else:
					var pool_clef: String = str(pool_item.get("clef", ""))
					var pool_note_id: String = str(pool_item.get("note_id", ""))
					if pool_clef != "" and pool_note_id != "":
						concepts.append("%s:%s" % [pool_clef, pool_note_id])
		LMD.STEP_LISTENING_QUIZ:
			for item_variant in step.get("items", []):
				if not (item_variant is Dictionary):
					continue
				var item: Dictionary = item_variant
				var item_concept: String = str(item.get("concept_id", ""))
				if item_concept == "":
					item_concept = _build_listening_concept_id(item)
				if item_concept != "":
					concepts.append(item_concept)
		LMD.STEP_KEYBOARD_QUIZ:
			concepts.append(_build_keyboard_concept_id(step))
		LMD.STEP_RHYTHM_TAP:
			concepts.append(_build_rhythm_concept_id(step))
		LMD.STEP_NOTE_IDENTIFY, LMD.STEP_LISTEN_FIND:
			var target_clef: String = str(step.get("clef", ""))
			var target_note_id: String = str(step.get("target_note_id", ""))
			if target_clef != "" and target_note_id != "":
				concepts.append("%s:%s" % [target_clef, target_note_id])
	return concepts


static func _extract_gate_concepts(module_data: Dictionary) -> Array[String]:
	var unique: Array[String] = []
	var seen: Dictionary = {}
	for step in module_data.get("steps", []):
		for concept_id in _extract_concepts_from_step(step):
			if concept_id.is_empty() or seen.has(concept_id):
				continue
			seen[concept_id] = true
			unique.append(concept_id)
			if unique.size() >= 6:
				return unique
	return unique


static func _get_unlock_gate(modules: Array, index: int) -> Dictionary:
	if index <= 0 or index >= modules.size():
		return {}
	var module_data: Dictionary = modules[index]
	var explicit_rules: Dictionary = module_data.get("unlock_rules", {})
	if not explicit_rules.is_empty():
		return explicit_rules
	var previous_module: Dictionary = modules[index - 1]
	var concepts: Array[String] = _extract_gate_concepts(previous_module)
	return {
		"required_concepts": concepts,
		"min_strength": 2,
		"min_accuracy": 0.65,
		"min_ratio": 0.6,
		"source_title": str(previous_module.get("title", "the previous lesson")),
	}


static func _build_lock_reason(gate: Dictionary, progress_info: Dictionary) -> String:
	var source_title: String = str(gate.get("source_title", "the previous lesson"))
	var missing: Array[String] = progress_info.get("missing", [])
	if missing.is_empty():
		return "Build a little more mastery in %s to unlock this." % source_title
	var need_count: int = mini(2, missing.size())
	return "Master %d more concept%s from %s to unlock this." % [need_count, "s" if need_count != 1 else "", source_title]


static func resolve_states(progress: RefCounted) -> Array:
	var modules := get_all_modules()
	var result: Array = []
	for i in modules.size():
		var m: Dictionary = modules[i]
		var mid: String = m["id"]
		var state: int
		var lock_reason := ""
		var saved_state: int = progress.get_module_state(mid)
		if saved_state == LMD.STATE_COMPLETED:
			state = LMD.STATE_COMPLETED
		elif i == 0:
			state = LMD.STATE_UNLOCKED
			progress.set_module_unlocked(mid)
		elif saved_state == LMD.STATE_UNLOCKED:
			state = LMD.STATE_UNLOCKED
		else:
			var prev_id: String = modules[i - 1]["id"]
			var gate: Dictionary = _get_unlock_gate(modules, i)
			var gate_concepts: Array[String] = gate.get("required_concepts", [])
			var gate_progress: Dictionary = progress.get_concept_gate_progress(
				gate_concepts,
				int(gate.get("min_strength", 2)),
				float(gate.get("min_accuracy", 0.65))
			)
			var meets_gate: bool = gate_concepts.is_empty() or float(gate_progress.get("ratio", 0.0)) >= float(gate.get("min_ratio", 0.6))
			if progress.is_completed(prev_id) or meets_gate:
				state = LMD.STATE_UNLOCKED
				progress.set_module_unlocked(mid)
			else:
				state = LMD.STATE_LOCKED
				lock_reason = _build_lock_reason(gate, gate_progress)
		result.append({"module": m, "state": state, "lock_reason": lock_reason})
	return result
