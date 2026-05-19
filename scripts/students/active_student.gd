extends RefCounted
class_name ActiveStudent

# Owns the "who is currently using the app" state and routes per-student data
# operations to the correct on-disk location.
#
# Storage layout (Phase 1):
#   user://students/<student_id>/module_progress.json
#   user://students/<student_id>/ear_session_history.json   (future phases)
#   user://students/<student_id>/...
#
# Reserved student IDs:
#   "teacher"       — auto-created default user for the teacher to demo/test on
#   "practice_mode" — no-attribution sandbox account (anything done here is
#                     intentionally not recorded against any real student)
#
# Migration:
#   First-time launch with this system detects legacy `user://progress_data.json`
#   and moves it into `students/teacher/module_progress.json` so existing single-
#   user data is preserved.

const STUDENTS_ROOT := "user://students"
const RESERVED_ID_TEACHER := "teacher"
const RESERVED_ID_PRACTICE := "practice_mode"
const RESERVED_TEACHER_NAME := "Teacher (demo)"
const RESERVED_PRACTICE_NAME := "Practice Mode (no attribution)"

# Legacy single-user paths that should migrate to the teacher demo account.
const LEGACY_PROGRESS_PATH := "user://progress_data.json"
const LEGACY_LEARNING_PROGRESS_PATH := "user://learning_progress.json"

var _active_student_id: String = ""


func get_active_id() -> String:
	return _active_student_id


func set_active_id(student_id: String) -> void:
	_active_student_id = student_id


func is_practice_mode() -> bool:
	return _active_student_id == RESERVED_ID_PRACTICE


func is_teacher_demo() -> bool:
	return _active_student_id == RESERVED_ID_TEACHER


func has_active_student() -> bool:
	return _active_student_id != ""


# Returns the per-student data folder for the active student. Auto-creates it.
# Returns empty string if no active student is set (caller should handle that case).
func active_student_folder() -> String:
	if _active_student_id == "":
		return ""
	return _ensure_student_folder(_active_student_id)


func student_folder(student_id: String) -> String:
	if student_id == "":
		return ""
	return _ensure_student_folder(student_id)


# Resolves the module-progress file path for the active student.
# For Practice Mode, returns an ephemeral path so changes don't pollute real data.
func active_module_progress_path() -> String:
	if _active_student_id == "":
		return ""
	if _active_student_id == RESERVED_ID_PRACTICE:
		# Practice mode uses a dedicated folder; data here is intentionally
		# discardable. We keep the file rather than using a tmp dir so the
		# teacher can recover it if they realized they meant to attribute.
		return "%s/%s/module_progress.json" % [STUDENTS_ROOT, RESERVED_ID_PRACTICE]
	return "%s/%s/module_progress.json" % [STUDENTS_ROOT, _active_student_id]


# Path to the LearningProgress (module_progress.gd) save file for the active student.
# Distinct from active_module_progress_path which is the lifetime-stats file.
func active_learning_progress_path() -> String:
	if _active_student_id == "":
		return ""
	return "%s/%s/learning_progress.json" % [STUDENTS_ROOT, _active_student_id]


func learning_progress_path_for(student_id: String) -> String:
	if student_id == "":
		return ""
	return "%s/%s/learning_progress.json" % [STUDENTS_ROOT, student_id]


# Run-once migration: copy legacy single-user data files into the teacher demo
# folder. Each file is migrated independently — safe to call multiple times,
# no-op once the destination exists. Doesn't delete legacy files (safety net).
func migrate_legacy_if_needed() -> Dictionary:
	var report := {"migrated_progress": false, "migrated_learning": false, "details": []}
	_ensure_root_dir()
	_ensure_student_folder(RESERVED_ID_TEACHER)
	_ensure_student_folder(RESERVED_ID_PRACTICE)
	# Lifetime-stats progress file
	var teacher_progress_path := "%s/%s/module_progress.json" % [STUDENTS_ROOT, RESERVED_ID_TEACHER]
	if _copy_if_missing(LEGACY_PROGRESS_PATH, teacher_progress_path):
		report["migrated_progress"] = true
		report["details"].append("progress_data.json → teacher/module_progress.json")
	# Learning module progress file
	var teacher_learning_path := "%s/%s/learning_progress.json" % [STUDENTS_ROOT, RESERVED_ID_TEACHER]
	if _copy_if_missing(LEGACY_LEARNING_PROGRESS_PATH, teacher_learning_path):
		report["migrated_learning"] = true
		report["details"].append("learning_progress.json → teacher/learning_progress.json")
	return report


# Returns true if a copy was performed; false if dst exists or src missing.
func _copy_if_missing(src_path: String, dst_path: String) -> bool:
	if FileAccess.file_exists(dst_path):
		return false
	if not FileAccess.file_exists(src_path):
		return false
	var src := FileAccess.open(src_path, FileAccess.READ)
	if src == null:
		return false
	var txt := src.get_as_text()
	src.close()
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(txt)
	dst.close()
	return true


# --- Internal helpers ---

func _ensure_root_dir() -> void:
	if not DirAccess.dir_exists_absolute(STUDENTS_ROOT):
		DirAccess.make_dir_absolute(STUDENTS_ROOT)


func _ensure_student_folder(student_id: String) -> String:
	_ensure_root_dir()
	var path := "%s/%s" % [STUDENTS_ROOT, student_id]
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
	return path
