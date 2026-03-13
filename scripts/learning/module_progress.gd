extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")
const LRQ = preload("res://scripts/learning/learning_review_queue.gd")
const SAVE_PATH := "user://learning_progress.json"

var _data: Dictionary = {}
var _review_queue: RefCounted  # LRQ instance


func _init() -> void:
	_review_queue = LRQ.new()
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = {}
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_data = {}
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_data = parsed
	else:
		_data = {}
	# Restore review queue
	var rq_data: Variant = _data.get("_review_queue", {})
	if rq_data is Dictionary:
		_review_queue.from_dict(rq_data as Dictionary)


func save_progress() -> void:
	_data["_review_queue"] = _review_queue.to_dict()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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

func record_quiz_result(module_id: String, concept_id: String, correct: bool, first_try: bool) -> void:
	_ensure_module(module_id)
	var m: Dictionary = _data[module_id]
	m["quiz_count"] = int(m.get("quiz_count", 0)) + 1
	if correct:
		m["quiz_correct"] = int(m.get("quiz_correct", 0)) + 1
	if first_try and correct:
		m["first_try_correct"] = int(m.get("first_try_correct", 0)) + 1

	# Track per-concept
	_review_queue.record_result(concept_id, correct, first_try)


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
