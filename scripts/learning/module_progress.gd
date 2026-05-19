extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")
const LRQ = preload("res://scripts/learning/learning_review_queue.gd")
const SAVE_PATH := "user://learning_progress.json"  # default / legacy single-user path

var _data: Dictionary = {}
var _review_queue: RefCounted  # LRQ instance
# Per-student data routing: when ActiveStudent is set, this instance is told to
# read/write from a different path (e.g., user://students/sarah_a1b2/learning_progress.json).
# Until then, defaults to SAVE_PATH (matches legacy behaviour).
var _save_path: String = SAVE_PATH


func _init() -> void:
	_review_queue = LRQ.new()
	load_progress()


func get_save_path() -> String:
	return _save_path


# Switch this instance to read/write from a different file. Saves the CURRENT
# data to the OLD path first (so an in-flight session isn't lost), then loads
# the NEW path. Used by the per-student routing system when active student changes.
func set_save_path_and_reload(path: String) -> void:
	if path == _save_path:
		return
	# Persist any in-memory changes to the outgoing path before swapping.
	save_progress()
	_save_path = path
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(_save_path):
		_data = {}
		# Also reset review queue so an empty file = fresh state, not leftover items.
		_review_queue = LRQ.new()
		return
	var f := FileAccess.open(_save_path, FileAccess.READ)
	if f == null:
		_data = {}
		_review_queue = LRQ.new()
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_data = parsed
	else:
		_data = {}
	# Restore review queue (always start fresh first so we don't merge across students).
	_review_queue = LRQ.new()
	var rq_data: Variant = _data.get("_review_queue", {})
	if rq_data is Dictionary:
		_review_queue.from_dict(rq_data as Dictionary)


func save_progress() -> void:
	_data["_review_queue"] = _review_queue.to_dict()
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()


func get_module_state(module_id: String) -> int:
	if _data.has(module_id):
		var entry: Dictionary = _data[module_id]
		if entry.get("completed", false):
			return LMD.STATE_COMPLETED
		return LMD.STATE_UNLOCKED
	return LMD.STATE_LOCKED


func set_module_unlocked(module_id: String) -> void:
	if not _data.has(module_id):
		_data[module_id] = {"completed": false, "last_step": 0}
	save_progress()


func set_module_completed(module_id: String) -> void:
	if not _data.has(module_id):
		_data[module_id] = {}
	_data[module_id]["completed"] = true
	save_progress()


func get_last_step(module_id: String) -> int:
	if _data.has(module_id):
		return int(_data[module_id].get("last_step", 0))
	return 0


func set_last_step(module_id: String, step: int) -> void:
	if not _data.has(module_id):
		_data[module_id] = {"completed": false}
	_data[module_id]["last_step"] = step
	save_progress()


func is_completed(module_id: String) -> bool:
	return get_module_state(module_id) == LMD.STATE_COMPLETED


# ─── Analytics & Stars ────────────────────────────────────────────

func record_quiz_result(module_id: String, concept_id: String, correct: bool, first_try: bool, response_ms: float = -1.0, confidence: String = "", skill_family: String = "") -> void:
	_ensure_module(module_id)
	var m: Dictionary = _data[module_id]
	m["quiz_count"] = int(m.get("quiz_count", 0)) + 1
	if correct:
		m["quiz_correct"] = int(m.get("quiz_correct", 0)) + 1
	if first_try and correct:
		m["first_try_correct"] = int(m.get("first_try_correct", 0)) + 1
	if response_ms > 0.0:
		var total_answers: int = int(m.get("quiz_count", 0))
		var prev_avg: float = float(m.get("avg_response_ms", 0.0))
		if total_answers <= 1:
			m["avg_response_ms"] = response_ms
		else:
			m["avg_response_ms"] = ((prev_avg * float(total_answers - 1)) + response_ms) / float(total_answers)
		m["last_response_ms"] = response_ms

	var family: String = skill_family.strip_edges()
	if family != "":
		var family_stats: Dictionary = m.get("skill_family_stats", {})
		var entry: Dictionary = family_stats.get(family, {
			"attempts": 0,
			"correct": 0,
			"first_try": 0,
			"avg_response_ms": 0.0,
		})
		entry["attempts"] = int(entry.get("attempts", 0)) + 1
		if correct:
			entry["correct"] = int(entry.get("correct", 0)) + 1
		if first_try and correct:
			entry["first_try"] = int(entry.get("first_try", 0)) + 1
		if response_ms > 0.0:
			var family_attempts: int = int(entry.get("attempts", 0))
			var family_prev_avg: float = float(entry.get("avg_response_ms", 0.0))
			if family_attempts <= 1:
				entry["avg_response_ms"] = response_ms
			else:
				entry["avg_response_ms"] = ((family_prev_avg * float(family_attempts - 1)) + response_ms) / float(family_attempts)
		family_stats[family] = entry
		m["skill_family_stats"] = family_stats

	var day_key: String = Time.get_date_string_from_system()
	var daily_activity: Dictionary = _data.get("_daily_activity", {})
	daily_activity[day_key] = int(daily_activity.get(day_key, 0)) + 1
	_data["_daily_activity"] = daily_activity

	# Track per-concept
	_review_queue.record_result(concept_id, correct, first_try, response_ms, confidence, family)
	save_progress()


func set_module_stars(module_id: String, stars: int) -> void:
	_ensure_module(module_id)
	var prev: int = int(_data[module_id].get("stars", 0))
	_data[module_id]["stars"] = maxi(prev, stars)
	save_progress()


func get_module_stars(module_id: String) -> int:
	if _data.has(module_id):
		return int(_data[module_id].get("stars", 0))
	return 0


func add_study_time(module_id: String, seconds: float) -> void:
	_ensure_module(module_id)
	_data[module_id]["study_time"] = float(_data[module_id].get("study_time", 0.0)) + seconds
	_data["_total_study_time"] = float(_data.get("_total_study_time", 0.0)) + seconds
	save_progress()


func get_module_study_time(module_id: String) -> float:
	if _data.has(module_id):
		return float(_data[module_id].get("study_time", 0.0))
	return 0.0


func get_total_study_time() -> float:
	return float(_data.get("_total_study_time", 0.0))


func get_module_accuracy(module_id: String) -> float:
	if not _data.has(module_id):
		return 0.0
	var m: Dictionary = _data[module_id]
	var total: int = int(m.get("quiz_count", 0))
	if total == 0:
		return 0.0
	return float(m.get("quiz_correct", 0)) / float(total)


func get_completed_count() -> int:
	var count := 0
	for key in _data:
		if key.begins_with("_"):
			continue
		if _data[key] is Dictionary and _data[key].get("completed", false):
			count += 1
	return count


func get_total_quizzes_correct() -> int:
	var total := 0
	for key in _data:
		if key.begins_with("_"):
			continue
		if _data[key] is Dictionary:
			total += int(_data[key].get("quiz_correct", 0))
	return total


func record_confidence(concept_id: String, confidence: String) -> void:
	if concept_id.is_empty():
		return
	_review_queue.record_confidence(concept_id, confidence)
	save_progress()


func get_concept_strength(concept_id: String) -> int:
	return _review_queue.get_concept_strength(concept_id)


func get_concept_accuracy(concept_id: String) -> float:
	return _review_queue.get_accuracy(concept_id)


func meets_concept_mastery(concept_id: String, min_strength: int = LRQ.STRENGTH_LEARNING, min_accuracy: float = 0.65) -> bool:
	if concept_id.is_empty():
		return false
	var strength: int = get_concept_strength(concept_id)
	if strength < min_strength:
		return false
	return get_concept_accuracy(concept_id) >= min_accuracy


func get_concept_gate_progress(concepts: Array[String], min_strength: int = LRQ.STRENGTH_LEARNING, min_accuracy: float = 0.65) -> Dictionary:
	var unique: Array[String] = []
	var seen: Dictionary = {}
	for concept_id in concepts:
		if concept_id.is_empty() or seen.has(concept_id):
			continue
		seen[concept_id] = true
		unique.append(concept_id)
	var matched := 0
	var missing: Array[String] = []
	for concept_id in unique:
		if meets_concept_mastery(concept_id, min_strength, min_accuracy):
			matched += 1
		else:
			missing.append(concept_id)
	var ratio: float = 1.0 if unique.is_empty() else float(matched) / float(unique.size())
	return {
		"required": unique.size(),
		"matched": matched,
		"ratio": ratio,
		"missing": missing,
	}


func get_due_review_count(max_count: int = 32) -> int:
	return _review_queue.get_review_items(max_count).size()


func get_daily_activity_window(days: int = 7) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var daily_activity: Dictionary = _data.get("_daily_activity", {})
	var now_unix: int = Time.get_unix_time_from_system()
	for offset in range(days - 1, -1, -1):
		var target_unix: int = now_unix - (offset * 86400)
		var d: Dictionary = Time.get_date_dict_from_unix_time(target_unix)
		var date_key := "%04d-%02d-%02d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0))]
		result.append({
			"date": date_key,
			"count": int(daily_activity.get(date_key, 0)),
			"label": str(d.get("weekday", "")),
		})
	return result


func get_aggregated_skill_family_stats() -> Dictionary:
	var aggregated: Dictionary = {}
	for key in _data:
		if key.begins_with("_"):
			continue
		if not (_data[key] is Dictionary):
			continue
		var module_data: Dictionary = _data[key]
		var family_stats: Dictionary = module_data.get("skill_family_stats", {})
		for family in family_stats.keys():
			var entry: Dictionary = family_stats[family]
			var agg: Dictionary = aggregated.get(family, {
				"attempts": 0,
				"correct": 0,
				"first_try": 0,
			})
			agg["attempts"] = int(agg.get("attempts", 0)) + int(entry.get("attempts", 0))
			agg["correct"] = int(agg.get("correct", 0)) + int(entry.get("correct", 0))
			agg["first_try"] = int(agg.get("first_try", 0)) + int(entry.get("first_try", 0))
			aggregated[family] = agg
	return aggregated


func get_weakest_skill_family() -> String:
	var aggregated: Dictionary = get_aggregated_skill_family_stats()
	var weakest := ""
	var weakest_score := 2.0
	for family in aggregated.keys():
		var entry: Dictionary = aggregated[family]
		var attempts: int = int(entry.get("attempts", 0))
		if attempts <= 0:
			continue
		var accuracy: float = float(entry.get("correct", 0)) / float(attempts)
		if accuracy < weakest_score:
			weakest_score = accuracy
			weakest = str(family)
	return weakest


func get_recommended_practice() -> Dictionary:
	var weakest: String = get_weakest_skill_family()
	match weakest:
		"note":
			return {"title": "Next best practice", "summary": "Spend 3 minutes in Sight Reading to strengthen note recognition."}
		"listening":
			return {"title": "Next best practice", "summary": "Spend 3 minutes in Ear Training to sharpen interval and chord listening."}
		"keyboard":
			return {"title": "Next best practice", "summary": "Spend 3 minutes matching staff notes to the keyboard."}
		"rhythm":
			return {"title": "Next best practice", "summary": "Spend 3 minutes in Rhythm Flow to tighten pulse and timing."}
		"theory":
			return {"title": "Next best practice", "summary": "Do a short theory review and then retake one learning quiz."}
		_:
			return {"title": "Next best practice", "summary": "Continue the next unlocked lesson to keep momentum."}


func set_placement_result(score_percent: int, skill_correct: Dictionary, skill_totals: Dictionary) -> void:
	_data["_placement_result"] = {
		"score_percent": score_percent,
		"skill_correct": skill_correct.duplicate(true),
		"skill_totals": skill_totals.duplicate(true),
		"taken_at_unix": Time.get_unix_time_from_system(),
	}
	save_progress()


func has_placement_result() -> bool:
	return _data.has("_placement_result")


func get_placement_result() -> Dictionary:
	var placement: Variant = _data.get("_placement_result", {})
	if placement is Dictionary:
		return (placement as Dictionary).duplicate(true)
	return {}


func get_review_queue() -> RefCounted:
	return _review_queue


func get_pace_setting() -> String:
	return str(_data.get("_pace_setting", "normal"))


func set_pace_setting(pace: String) -> void:
	_data["_pace_setting"] = pace
	save_progress()


func _ensure_module(module_id: String) -> void:
	if not _data.has(module_id):
		_data[module_id] = {"completed": false}
