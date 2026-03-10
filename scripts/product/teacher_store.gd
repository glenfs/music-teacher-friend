class_name TeacherStore
extends RefCounted

var data: Dictionary = {"students": []}


func set_data(value: Dictionary) -> void:
	data = value.duplicate(true)
	_ensure_students_array()


func get_data() -> Dictionary:
	return data.duplicate(true)


func load_from_path(path: String, ensure_student_defaults: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		data = {"students": []}
		return get_data()
	var teacher_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if teacher_file == null:
		data = {"students": []}
		return get_data()
	var text: String = teacher_file.get_as_text()
	teacher_file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		data = (parsed as Dictionary).duplicate(true)
	else:
		data = {"students": []}
	_ensure_students_array()
	var students: Array = data["students"]
	for i in range(students.size()):
		var student_any: Variant = students[i]
		var student: Dictionary = {}
		if typeof(student_any) == TYPE_DICTIONARY:
			student = (student_any as Dictionary).duplicate(true)
		if ensure_student_defaults.is_valid():
			var ensured_any: Variant = ensure_student_defaults.call(student)
			if typeof(ensured_any) == TYPE_DICTIONARY:
				student = (ensured_any as Dictionary).duplicate(true)
		students[i] = student
	data["students"] = students
	return get_data()


func save_to_path(path: String) -> void:
	_ensure_students_array()
	var teacher_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if teacher_file == null:
		return
	teacher_file.store_string(JSON.stringify(data, "\t"))
	teacher_file.close()


func students_array() -> Array:
	_ensure_students_array()
	return data["students"]


func find_index_by_id(student_id: String) -> int:
	if student_id == "":
		return -1
	var students: Array = students_array()
	for i in range(students.size()):
		var student_any: Variant = students[i]
		if typeof(student_any) != TYPE_DICTIONARY:
			continue
		var student: Dictionary = student_any as Dictionary
		if str(student.get("id", "")) == student_id:
			return i
	return -1


func get_active_student_id(selected_student_id: String) -> String:
	if selected_student_id != "":
		return selected_student_id
	return str(data.get("active_student_id", ""))


func save_student(student: Dictionary, selected_student_id: String = "") -> Dictionary:
	var next_student: Dictionary = student.duplicate(true)
	var sid: String = selected_student_id.strip_edges()
	if sid == "":
		sid = str(next_student.get("id", "")).strip_edges()
	if sid == "":
		return {"saved": false}
	next_student["id"] = sid
	var students: Array = students_array().duplicate(true)
	var idx: int = find_index_by_id(sid)
	var created: bool = idx < 0
	if created:
		students.append(next_student)
	else:
		students[idx] = next_student
	data["students"] = students
	return {
		"saved": true,
		"created": created,
		"student_id": sid,
		"student": next_student
	}


func delete_student(student_id: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"deleted": false}
	var students: Array = students_array().duplicate(true)
	students.remove_at(idx)
	data["students"] = students
	var cleared_active := false
	if str(data.get("active_student_id", "")) == student_id:
		data["active_student_id"] = ""
		cleared_active = true
	return {
		"deleted": true,
		"student_id": student_id,
		"active_student_cleared": cleared_active
	}


func set_active_student_id(student_id: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	data["active_student_id"] = student_id
	var student_any: Variant = students_array()[idx]
	var student: Dictionary = {}
	if typeof(student_any) == TYPE_DICTIONARY:
		student = (student_any as Dictionary).duplicate(true)
	return {
		"updated": true,
		"student_id": student_id,
		"student": student
	}


func apply_metric_update(
	student: Dictionary,
	mode: int,
	accuracy_pct: int,
	mode_interval: int,
	mode_chord: int,
	mode_sight: int,
	last_session_value: String
) -> Dictionary:
	var metrics: Dictionary = _dictionary_from_variant(student.get("metrics", {}))
	var ear_sessions: int = int(metrics.get("ear_sessions", 0))
	var sight_sessions: int = int(metrics.get("sight_sessions", 0))
	var ear_accuracy: int = int(metrics.get("ear_accuracy", 0))
	var sight_accuracy: int = int(metrics.get("sight_accuracy", 0))
	if mode == mode_interval or mode == mode_chord:
		ear_accuracy = int(round((float(ear_accuracy * ear_sessions) + float(accuracy_pct)) / float(ear_sessions + 1)))
		ear_sessions += 1
	elif mode == mode_sight:
		sight_accuracy = int(round((float(sight_accuracy * sight_sessions) + float(accuracy_pct)) / float(sight_sessions + 1)))
		sight_sessions += 1
	metrics["ear_sessions"] = ear_sessions
	metrics["sight_sessions"] = sight_sessions
	metrics["ear_accuracy"] = ear_accuracy
	metrics["sight_accuracy"] = sight_accuracy
	metrics["last_session"] = last_session_value
	student["metrics"] = metrics
	return _sync_training_stats(student)


func record_session_metrics(
	selected_student_id: String,
	mode: int,
	correct_count: int,
	asked_count: int,
	mode_interval: int,
	mode_chord: int,
	mode_sight: int,
	last_session_value: String,
	session_history_date: String,
	mode_label_for_mode: Callable
) -> Dictionary:
	var sid: String = get_active_student_id(selected_student_id)
	if sid == "":
		return {"updated": false}
	var idx: int = find_index_by_id(sid)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	if idx >= students.size():
		return {"updated": false}
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var accuracy: int = int(round((float(correct_count) / float(max(1, asked_count))) * 100.0))
	student = apply_metric_update(
		student,
		mode,
		accuracy,
		mode_interval,
		mode_chord,
		mode_sight,
		last_session_value
	)
	var sessions: Array = _array_from_variant(student.get("session_history", []))
	var mode_label: String = str(mode_label_for_mode.call(mode)) if mode_label_for_mode.is_valid() else str(mode)
	sessions.append({
		"date": session_history_date,
		"mode": mode_label,
		"correct": correct_count,
		"asked": asked_count,
		"accuracy": accuracy
	})
	while sessions.size() > 200:
		sessions.remove_at(0)
	student["session_history"] = sessions
	student = _sync_training_stats(student)
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": sid,
		"student": student,
		"accuracy": accuracy
	}


func move_piece_to_history(student_id: String, removed_title: String, current_pieces: Array) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var history: Array = _array_from_variant(student.get("piece_history", []))
	history.append(removed_title)
	student["piece_history"] = history
	student["current_pieces"] = current_pieces.duplicate(true)
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student
	}


func mark_module_completed(selected_student_id: String, last_session_value: String) -> Dictionary:
	var sid: String = get_active_student_id(selected_student_id)
	if sid == "":
		return {"updated": false}
	var idx: int = find_index_by_id(sid)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var metrics: Dictionary = _dictionary_from_variant(student.get("metrics", {}))
	metrics["modules_completed"] = int(metrics.get("modules_completed", 0)) + 1
	metrics["last_session"] = last_session_value
	student["metrics"] = metrics
	student = _sync_training_stats(student)
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": sid,
		"student": student
	}


func mark_book_done(student_id: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var current_book: Dictionary = _dictionary_from_variant(student.get("current_book", {}))
	var book_name := str(current_book.get("name", "")).strip_edges()
	var book_part := str(current_book.get("part", "")).strip_edges()
	if book_name == "":
		return {"updated": false, "reason": "no_current_book"}
	var history: Array = _array_from_variant(student.get("book_history", []))
	history.append("%s%s" % [book_name, (" (Part %s)" % book_part) if book_part != "" else ""])
	student["book_history"] = history
	student["current_book"] = {"name": "", "part": ""}
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student
	}


func mark_piece_done(student_id: String, target_title: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var current: Array[Dictionary] = _piece_entries_from_value_array(_array_from_variant(student.get("current_pieces", [])))
	var target := target_title.strip_edges()
	if target == "" and not current.is_empty():
		target = str(current[0].get("title", ""))
	if target == "":
		return {"updated": false, "reason": "no_current_piece"}
	var updated: Array[Dictionary] = []
	for piece in current:
		if str(piece.get("title", "")) != target:
			updated.append(piece)
	var history: Array = _array_from_variant(student.get("piece_history", []))
	history.append(target)
	student["piece_history"] = history
	student["current_pieces"] = updated
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student,
		"target": target
	}


func mark_tech_done(student_id: String, target_title: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var current: Array = _array_from_variant(student.get("current_technical", []))
	var target := target_title.strip_edges()
	if target == "" and not current.is_empty():
		target = str(current[0])
	if target == "":
		return {"updated": false, "reason": "no_current_technical"}
	var updated: Array[String] = []
	for item in current:
		var technical := str(item)
		if technical != target:
			updated.append(technical)
	var history: Array = _array_from_variant(student.get("tech_history", []))
	history.append(target)
	student["tech_history"] = history
	student["current_technical"] = updated
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student,
		"target": target
	}


func add_assignment(student_id: String, task: String, due: String, created_at: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var assignments: Array = _array_from_variant(student.get("assignments", []))
	assignments.append({
		"task": task,
		"due": due,
		"done": false,
		"created_at": created_at,
		"done_at": ""
	})
	student["assignments"] = assignments
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student
	}


func mark_assignment_done(student_id: String, assignment_idx: int, done_at: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var assignments: Array = _array_from_variant(student.get("assignments", []))
	if assignment_idx < 0 or assignment_idx >= assignments.size():
		return {"updated": false, "reason": "assignment_out_of_range"}
	if typeof(assignments[assignment_idx]) != TYPE_DICTIONARY:
		return {"updated": false, "reason": "assignment_invalid"}
	var assignment: Dictionary = (assignments[assignment_idx] as Dictionary).duplicate(true)
	assignment["done"] = true
	assignment["done_at"] = done_at
	assignments[assignment_idx] = assignment
	student["assignments"] = assignments
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student
	}


func remove_assignment(student_id: String, assignment_idx: int) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student_any: Variant = students[idx]
	if typeof(student_any) != TYPE_DICTIONARY:
		return {"updated": false}
	var student: Dictionary = (student_any as Dictionary).duplicate(true)
	var assignments: Array = _array_from_variant(student.get("assignments", []))
	if assignment_idx < 0 or assignment_idx >= assignments.size():
		return {"updated": false, "reason": "assignment_out_of_range"}
	assignments.remove_at(assignment_idx)
	student["assignments"] = assignments
	students[idx] = student
	data["students"] = students
	return {
		"updated": true,
		"student_id": student_id,
		"student": student
	}


func _ensure_students_array() -> void:
	if not data.has("students") or typeof(data["students"]) != TYPE_ARRAY:
		data["students"] = []


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _array_from_variant(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []


func _piece_entries_from_value_array(values: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var item: Dictionary = value as Dictionary
			var title := str(item.get("title", "")).strip_edges()
			if title == "":
				title = str(item.get("name", "")).strip_edges()
			if title == "":
				continue
			entries.append({
				"title": title,
				"notes": str(item.get("notes", ""))
			})
			continue
		var label := str(value).strip_edges()
		if label == "":
			continue
		entries.append({
			"title": label,
			"notes": ""
		})
	return entries


func _sync_training_stats(student: Dictionary) -> Dictionary:
	var metrics: Dictionary = _dictionary_from_variant(student.get("metrics", {}))
	var stats: Dictionary = _dictionary_from_variant(student.get("training_stats", {}))
	stats["ear_accuracy"] = int(metrics.get("ear_accuracy", 0))
	stats["sight_accuracy"] = int(metrics.get("sight_accuracy", 0))
	stats["modules_completed"] = int(metrics.get("modules_completed", 0))
	stats["ear_sessions"] = int(metrics.get("ear_sessions", 0))
	stats["sight_sessions"] = int(metrics.get("sight_sessions", 0))
	stats["last_session"] = str(metrics.get("last_session", ""))
	student["training_stats"] = stats
	return student
