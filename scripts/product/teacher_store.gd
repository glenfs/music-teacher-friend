class_name TeacherStore
extends RefCounted

# Current schema version. Bump when introducing a breaking change to the data
# layout, then add a migration step in _migrate_from_version below.
# The file lives in `user://` which Godot persists across app updates on every
# supported platform — so user data is NOT lost when a new build ships.
const CURRENT_SCHEMA_VERSION: int = 1

var data: Dictionary = {"students": []}


func set_data(value: Dictionary) -> void:
	data = value.duplicate(true)
	_ensure_students_array()


func get_data() -> Dictionary:
	return data.duplicate(true)


func load_from_path(path: String, ensure_student_defaults: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		data = {"students": [], "schema_version": CURRENT_SCHEMA_VERSION}
		return get_data()
	var teacher_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if teacher_file == null:
		# File exists but can't be opened (permission etc.) — DO NOT wipe in-memory data
		# silently. Start empty in memory but don't trigger a save that would overwrite.
		data = {"students": [], "schema_version": CURRENT_SCHEMA_VERSION}
		return get_data()
	var text: String = teacher_file.get_as_text()
	teacher_file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		data = (parsed as Dictionary).duplicate(true)
	else:
		# File exists but is corrupted (failed JSON parse). Back up the bad file
		# so the user can recover manually instead of silently overwriting it.
		_backup_corrupt_file(path, text)
		data = {"students": [], "schema_version": CURRENT_SCHEMA_VERSION}
	# Schema version handling — supports forward-compat: an OLDER app reading a
	# NEWER file will use .get() defaults for unknown fields and still work.
	var loaded_version: int = int(data.get("schema_version", 0))
	if loaded_version < CURRENT_SCHEMA_VERSION:
		_migrate_from_version(loaded_version)
	data["schema_version"] = CURRENT_SCHEMA_VERSION
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
	data["schema_version"] = CURRENT_SCHEMA_VERSION
	# Rotate-and-keep last 3 backups BEFORE overwriting the live file. If a future
	# bug ever produces bad data, the teacher has recoverable history.
	_rotate_backups(path)
	var teacher_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if teacher_file == null:
		return
	teacher_file.store_string(JSON.stringify(data, "\t"))
	teacher_file.close()


# Keep up to BACKUP_KEEP rotating backups of the live file in user://teacher_backups/.
# Skips when the live file doesn't exist yet (first save).
const BACKUP_KEEP: int = 3

func _rotate_backups(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var backup_dir: String = "user://teacher_backups"
	if not DirAccess.dir_exists_absolute(backup_dir):
		DirAccess.make_dir_absolute(backup_dir)
	# Read current live file content; we'll copy it as the new most-recent backup.
	var src: FileAccess = FileAccess.open(path, FileAccess.READ)
	if src == null:
		return
	var live_text: String = src.get_as_text()
	src.close()
	# Shift existing backups: teacher_backup_2 → 3, 1 → 2, then write new 1.
	for i in range(BACKUP_KEEP - 1, 0, -1):
		var older := "%s/teacher_backup_%d.json" % [backup_dir, i + 1]
		var newer := "%s/teacher_backup_%d.json" % [backup_dir, i]
		if FileAccess.file_exists(newer):
			# Remove older to make room, then rename newer → older.
			if FileAccess.file_exists(older):
				DirAccess.remove_absolute(older)
			DirAccess.rename_absolute(newer, older)
	# Write the new most-recent backup
	var fresh_path := "%s/teacher_backup_1.json" % backup_dir
	var fresh: FileAccess = FileAccess.open(fresh_path, FileAccess.WRITE)
	if fresh == null:
		return
	fresh.store_string(live_text)
	fresh.close()


# Migration hook. Add new branches below as the schema evolves. Example:
#   if from_version < 2:
#       _migrate_v1_to_v2()   # e.g., rename "practice_note" → "homework"
# Always preserve existing data — migrations should only enrich/rename, not delete.
func _migrate_from_version(from_version: int) -> void:
	# Version 0 = pre-versioned. No structural change needed; .get() defaults
	# already handle missing fields in existing student/lesson entries.
	if from_version < 1:
		pass


# When we fail to parse an existing file, save the raw bytes alongside as
# `<path>.corrupt.<unix>` so the user has a manual recovery option. Without
# this, a corrupted file would be silently overwritten on the next save.
func _backup_corrupt_file(path: String, text: String) -> void:
	var stamp: int = int(Time.get_unix_time_from_system())
	var backup_path: String = "%s.corrupt.%d" % [path, stamp]
	var backup_file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	if backup_file == null:
		return
	backup_file.store_string(text)
	backup_file.close()
	push_warning("TeacherStore: corrupted teacher_data.json backed up to %s" % backup_path)


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


func record_item_stats(student_id: String, item_stats_asked: Dictionary, item_stats_correct: Dictionary, category: String) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student: Dictionary = _dictionary_from_variant(students[idx])
	var all_item_stats: Dictionary = _dictionary_from_variant(student.get("item_stats", {}))
	var cat_stats: Dictionary = _dictionary_from_variant(all_item_stats.get(category, {}))
	for key in item_stats_asked:
		var k := str(key)
		var entry: Dictionary = _dictionary_from_variant(cat_stats.get(k, {}))
		entry["asked"] = int(entry.get("asked", 0)) + int(item_stats_asked[key])
		entry["correct"] = int(entry.get("correct", 0)) + int(item_stats_correct.get(key, 0))
		cat_stats[k] = entry
	all_item_stats[category] = cat_stats
	student["item_stats"] = all_item_stats
	students[idx] = student
	data["students"] = students
	return {"updated": true, "student_id": student_id}


func get_weak_items(student_id: String, min_asked: int = 3, max_results: int = 6) -> Array[Dictionary]:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return []
	var student: Dictionary = _dictionary_from_variant(students_array()[idx])
	var all_item_stats: Dictionary = _dictionary_from_variant(student.get("item_stats", {}))
	var weak: Array[Dictionary] = []
	for category in all_item_stats:
		var cat_stats: Dictionary = _dictionary_from_variant(all_item_stats[category])
		for item_key in cat_stats:
			var entry: Dictionary = _dictionary_from_variant(cat_stats[item_key])
			var asked := int(entry.get("asked", 0))
			var correct := int(entry.get("correct", 0))
			if asked < min_asked:
				continue
			var accuracy := int(round(float(correct) / float(maxi(1, asked)) * 100.0))
			if accuracy < 70:
				weak.append({"category": str(category), "item": str(item_key), "accuracy": accuracy, "asked": asked})
	weak.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("accuracy", 100)) < int(b.get("accuracy", 100)))
	if weak.size() > max_results:
		weak.resize(max_results)
	return weak


func add_lesson_log_entry(student_id: String, entry: Dictionary) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student: Dictionary = _dictionary_from_variant(students[idx])
	var log: Array = _array_from_variant(student.get("lesson_log", []))
	log.insert(0, entry)
	student["lesson_log"] = log
	students[idx] = student
	data["students"] = students
	return {"updated": true, "student_id": student_id, "student": student}


# Replace an existing lesson-log entry at a given index. Used by the inline-edit
# UI so teachers can refine a log as the class progresses without creating a new row.
# Preserves any unknown fields on the existing entry (forward-compat for future
# additions like attachments, mood, skill tags).
func update_lesson_log_entry(student_id: String, entry_idx: int, entry: Dictionary) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student: Dictionary = _dictionary_from_variant(students[idx])
	var log: Array = _array_from_variant(student.get("lesson_log", []))
	if entry_idx < 0 or entry_idx >= log.size():
		return {"updated": false}
	# Merge: keep existing keys, overwrite ones from the new entry. This protects
	# any future-added fields that the current UI doesn't know about.
	var existing: Dictionary = _dictionary_from_variant(log[entry_idx])
	for k in entry.keys():
		existing[k] = entry[k]
	log[entry_idx] = existing
	student["lesson_log"] = log
	students[idx] = student
	data["students"] = students
	return {"updated": true, "student_id": student_id, "student": student, "entry": existing}


# Delete a lesson-log entry. Useful safety operation alongside edit.
func delete_lesson_log_entry(student_id: String, entry_idx: int) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student: Dictionary = _dictionary_from_variant(students[idx])
	var log: Array = _array_from_variant(student.get("lesson_log", []))
	if entry_idx < 0 or entry_idx >= log.size():
		return {"updated": false}
	log.remove_at(entry_idx)
	student["lesson_log"] = log
	students[idx] = student
	data["students"] = students
	return {"updated": true, "student_id": student_id, "student": student}


func update_piece(student_id: String, piece_idx: int, piece: Dictionary) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student: Dictionary = _dictionary_from_variant(students[idx])
	var pieces: Array = _array_from_variant(student.get("current_pieces", []))
	if piece_idx < 0 or piece_idx >= pieces.size():
		return {"updated": false}
	pieces[piece_idx] = piece
	student["current_pieces"] = pieces
	students[idx] = student
	data["students"] = students
	return {"updated": true, "student_id": student_id, "student": student}


func add_piece(student_id: String, piece: Dictionary) -> Dictionary:
	var idx: int = find_index_by_id(student_id)
	if idx < 0:
		return {"updated": false}
	var students: Array = students_array().duplicate(true)
	var student: Dictionary = _dictionary_from_variant(students[idx])
	var pieces: Array = _array_from_variant(student.get("current_pieces", []))
	pieces.append(piece)
	student["current_pieces"] = pieces
	students[idx] = student
	data["students"] = students
	return {"updated": true, "student_id": student_id, "student": student}


func ensure_piece_defaults(piece: Variant) -> Dictionary:
	var p: Dictionary = {}
	if typeof(piece) == TYPE_DICTIONARY:
		p = (piece as Dictionary).duplicate(true)
	elif typeof(piece) == TYPE_STRING:
		p = {"title": str(piece)}
	var defaults := {
		"title": "", "composer": "", "source_book": "",
		"status": "working", "date_assigned": "", "date_completed": "",
		"target_bpm": 0, "current_bpm": 0,
		"memory_status": "reading", "focus_bars": "",
		"notes": "", "last_reviewed": "",
		"ratings": {"notes": 0, "rhythm": 0, "technique": 0, "musicality": 0, "memory": 0}
	}
	for key in defaults:
		if not p.has(key):
			p[key] = defaults[key]
	if typeof(p.get("ratings")) != TYPE_DICTIONARY:
		p["ratings"] = defaults["ratings"]
	return p


func ensure_tech_defaults(item: Variant) -> Dictionary:
	var t: Dictionary = {}
	if typeof(item) == TYPE_DICTIONARY:
		t = (item as Dictionary).duplicate(true)
	elif typeof(item) == TYPE_STRING:
		t = {"title": str(item)}
	var defaults := {
		"title": "", "category": "scale", "key_or_root": "",
		"quality_or_mode": "", "hands": "HT",
		"motion": "parallel", "status": "not_started",
		"target_bpm": 0, "current_bpm": 0,
		"notes": "", "last_checked": ""
	}
	for key in defaults:
		if not t.has(key):
			t[key] = defaults[key]
	return t


func ensure_student_defaults(student: Dictionary) -> Dictionary:
	var s := student.duplicate(true)
	var str_defaults := {
		"id": "", "name": "", "level": "", "instrument": "Piano",
		"lesson_day": "", "parent_name": "", "parent_contact": "",
		"next_lesson_focus": ""
	}
	for key in str_defaults:
		if not s.has(key):
			s[key] = str_defaults[key]
	if not s.has("age"):
		s["age"] = 0
	if not s.has("lesson_duration_min"):
		s["lesson_duration_min"] = 30
	var dict_defaults := {"current_book": {"name": "", "part": ""}, "metrics": {}, "training_stats": {}}
	for key in dict_defaults:
		if not s.has(key) or typeof(s[key]) != TYPE_DICTIONARY:
			s[key] = dict_defaults[key]
	var arr_defaults := ["current_pieces", "repertoire_history", "current_technical",
		"tech_history", "lesson_log", "assignments", "session_history",
		"book_history", "piece_history", "teacher_flags"]
	for key in arr_defaults:
		if not s.has(key) or typeof(s[key]) != TYPE_ARRAY:
			s[key] = []
	# Migrate pieces to rich format
	var pieces: Array = s["current_pieces"]
	for i in pieces.size():
		pieces[i] = ensure_piece_defaults(pieces[i])
	s["current_pieces"] = pieces
	# Migrate tech items to dict format
	var tech: Array = s["current_technical"]
	for i in tech.size():
		tech[i] = ensure_tech_defaults(tech[i])
	s["current_technical"] = tech
	return s


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
