extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")
const Module01 = preload("res://scripts/learning/modules/module_01_clef_barlines_time.gd")
const Module02 = preload("res://scripts/learning/modules/module_02_treble_part1.gd")
const Module03a = preload("res://scripts/learning/modules/module_03a_bass_part1a.gd")
const Module03b = preload("res://scripts/learning/modules/module_03b_bass_part1b.gd")
const Module05 = preload("res://scripts/learning/modules/module_05_treble_part2.gd")
const Module06 = preload("res://scripts/learning/modules/module_06_bass_part2.gd")
const Module04 = preload("res://scripts/learning/modules/module_04_ledger_lines.gd")
const Module07 = preload("res://scripts/learning/modules/module_07_sharps_flats.gd")
const Module08 = preload("res://scripts/learning/modules/module_08_treble_part3.gd")
const Module09 = preload("res://scripts/learning/modules/module_09_bass_part3.gd")
const Module10 = preload("res://scripts/learning/modules/module_10_rhythm.gd")
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
# 2. Treble Notes Part 1 — C4-G4
# 3. Bass Notes Part 1A — C4, B3, A3
# 4. Bass Notes Part 1B — G3, F3
# 5. Rhythm Notation — moved early so students learn rhythm near note basics
# 6. Treble Notes Part 2 — EGBDF, FACE, A4-C5
# 7. Bass Notes Part 2 — GBDFA, ACEG, E3-C3
# 8. Ledger Lines — after staff mastery
# 9. Sharps & Flats — enhanced with practice
# 10. Treble Notes Part 3 — D5-G5
# 11. Bass Notes Part 3 — B2-F2
# 12. Key Signatures
# 13. Minor Scales — builds on key signatures
# 14. Grand Staff
# 15. Intro to Intervals
# 16. Interval Quality — builds on intervals intro
# 17. Chord Basics
# 18. Capstone — The Final Challenge

static func get_all_modules() -> Array:
	return [
		Module01.get_module_data(),
		Module02.get_module_data(),
		Module03a.get_module_data(),
		Module03b.get_module_data(),
		Module10.get_module_data(),
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


static func resolve_states(progress: RefCounted) -> Array:
	var modules := get_all_modules()
	var result: Array = []
	for i in modules.size():
		var m: Dictionary = modules[i]
		var mid: String = m["id"]
		var state: int
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
			if progress.is_completed(prev_id):
				state = LMD.STATE_UNLOCKED
				progress.set_module_unlocked(mid)
			else:
				state = LMD.STATE_LOCKED
		result.append({"module": m, "state": state})
	return result
