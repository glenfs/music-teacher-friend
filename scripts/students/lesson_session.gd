extends RefCounted
class_name LessonSession

# Manages "Start Lesson → End Lesson" sessions for the Teacher Edition.
# A LessonSession captures every practice round between the bookends, attaches
# them to a single student, and persists to that student's lesson_sessions.json
# file. The teacher can review past sessions in the dashboard and the End-of-
# Lesson dialog auto-suggests creating a Lesson Log entry from the session.
#
# Storage layout:
#   user://students/<student_id>/lesson_sessions.json
#
# File schema (versioned for future migrations):
#   {
#     "schema_version": 1,
#     "sessions": [
#       {
#         "id": "uuid_or_timestamp_string",
#         "student_id": "...",
#         "started_at": "2026-05-17 14:30",
#         "ended_at":   "2026-05-17 15:15",
#         "duration_sec": 2700,
#         "activities": [
#           {"mode": "sight_notes", "sub_mode": "Notes", "key_pc": 0,
#            "key_is_minor": false, "started_at": "...", "ended_at": "...",
#            "score": 12, "total": 15, "duration_sec": 240}
#         ],
#         "notes": ""
#       }
#     ]
#   }

const CURRENT_SCHEMA_VERSION: int = 1

# In-memory state of the CURRENT session (the one being recorded). When empty
# dict, no session is active.
var _current: Dictionary = {}
# Per-activity scratch — populated on start, finalised on end. We track only
# one active activity at a time (rounds happen sequentially).
var _current_activity: Dictionary = {}


func is_session_active() -> bool:
	return not _current.is_empty()


func get_active_student_id() -> String:
	return str(_current.get("student_id", ""))


func get_started_at_unix() -> int:
	return int(_current.get("_started_at_unix", 0))


func get_elapsed_seconds() -> int:
	if _current.is_empty():
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	return now - int(_current.get("_started_at_unix", now))


func get_current_activity_count() -> int:
	if _current.is_empty():
		return 0
	return int((_current.get("activities", []) as Array).size())


# Begin a new lesson session. Returns true if started, false if one is already active.
func start_session(student_id: String) -> bool:
	if is_session_active():
		return false
	if student_id == "":
		return false
	var now_unix: int = int(Time.get_unix_time_from_system())
	_current = {
		"id": "sess_%d" % now_unix,
		"student_id": student_id,
		"_started_at_unix": now_unix,
		"started_at": _format_iso(now_unix),
		"activities": [],
		"notes": "",
	}
	_current_activity = {}
	return true


# Begin recording one activity inside the current session. Safe no-op when no
# session is active. Closes any previous activity automatically (so we always
# have at most one open at a time).
func begin_activity(mode_name: String, sub_mode: String = "", key_pc: int = -1, key_is_minor: bool = false) -> void:
	if not is_session_active():
		return
	if not _current_activity.is_empty():
		end_activity(0, 0)
	var now_unix: int = int(Time.get_unix_time_from_system())
	_current_activity = {
		"mode": mode_name,
		"sub_mode": sub_mode,
		"key_pc": key_pc,
		"key_is_minor": key_is_minor,
		"_started_at_unix": now_unix,
		"started_at": _format_iso(now_unix),
	}


# Finalise the current activity with score + total and append to the session.
# Safe no-op when no activity is open.
func end_activity(score: int, total: int) -> void:
	if _current_activity.is_empty():
		return
	if not is_session_active():
		_current_activity = {}
		return
	var now_unix: int = int(Time.get_unix_time_from_system())
	_current_activity["ended_at"] = _format_iso(now_unix)
	_current_activity["duration_sec"] = now_unix - int(_current_activity.get("_started_at_unix", now_unix))
	_current_activity.erase("_started_at_unix")
	_current_activity["score"] = score
	_current_activity["total"] = total
	(_current.get("activities", []) as Array).append(_current_activity.duplicate(true))
	_current_activity = {}


# End the lesson session. Returns the completed session dict so caller can show
# the end-of-lesson dialog / auto-fill a lesson log entry. Empty dict if no
# session was active. Persists immediately to the student's file.
func end_session() -> Dictionary:
	if not is_session_active():
		return {}
	# Close any in-flight activity that wasn't explicitly ended.
	if not _current_activity.is_empty():
		end_activity(0, 0)
	var now_unix: int = int(Time.get_unix_time_from_system())
	_current["ended_at"] = _format_iso(now_unix)
	_current["duration_sec"] = now_unix - int(_current.get("_started_at_unix", now_unix))
	_current.erase("_started_at_unix")
	var sid: String = str(_current.get("student_id", ""))
	var finished: Dictionary = _current.duplicate(true)
	_persist_session(sid, finished)
	_current = {}
	_current_activity = {}
	return finished


# Discard the current session without saving. Used when the teacher closes the
# app or wants to abort the recording.
func abort_session() -> void:
	_current = {}
	_current_activity = {}


# Load past sessions for a student. Returns most-recent-first.
static func load_sessions_for(student_id: String) -> Array:
	if student_id == "":
		return []
	var path := "user://students/%s/lesson_sessions.json" % student_id
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var data: Dictionary = parsed
	var sessions: Array = data.get("sessions", [])
	# Newest first by started_at (string compare on ISO is fine).
	sessions.sort_custom(func(a, b):
		var sa: String = str((a as Dictionary).get("started_at", ""))
		var sb: String = str((b as Dictionary).get("started_at", ""))
		return sa > sb
	)
	return sessions


# Compose a human-readable summary string from a session's activities.
# Used to auto-fill the lesson-log entry created at End-of-Lesson.
static func summarize_activities(session: Dictionary) -> String:
	var activities: Array = session.get("activities", [])
	if activities.is_empty():
		return ""
	# Group by mode label so "Sight Notes ×3 (avg 80%)" reads naturally.
	var groups: Dictionary = {}
	for act_any in activities:
		if typeof(act_any) != TYPE_DICTIONARY:
			continue
		var act: Dictionary = act_any
		var label: String = _activity_label(act)
		var g: Dictionary = groups.get(label, {"count": 0, "score_sum": 0, "total_sum": 0})
		g["count"] = int(g["count"]) + 1
		g["score_sum"] = int(g["score_sum"]) + int(act.get("score", 0))
		g["total_sum"] = int(g["total_sum"]) + int(act.get("total", 0))
		groups[label] = g
	var parts: Array[String] = []
	for label in groups.keys():
		var g: Dictionary = groups[label]
		var count: int = int(g["count"])
		var score_sum: int = int(g["score_sum"])
		var total_sum: int = int(g["total_sum"])
		if total_sum > 0:
			parts.append("%s ×%d (%d/%d)" % [label, count, score_sum, total_sum])
		else:
			parts.append("%s ×%d" % [label, count])
	return "  •  ".join(parts)


static func _activity_label(act: Dictionary) -> String:
	var mode: String = str(act.get("mode", ""))
	var sub: String = str(act.get("sub_mode", ""))
	if not sub.is_empty():
		return "%s %s" % [mode, sub]
	return mode


# --- Internal persistence ---

func _persist_session(student_id: String, finished: Dictionary) -> void:
	if student_id == "":
		return
	# Ensure the per-student folder exists.
	var folder := "user://students/%s" % student_id
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_absolute(folder)
	var path := "%s/lesson_sessions.json" % folder
	var data: Dictionary = {"schema_version": CURRENT_SCHEMA_VERSION, "sessions": []}
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null:
			var txt := rf.get_as_text()
			rf.close()
			var parsed: Variant = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
				if not data.has("sessions"):
					data["sessions"] = []
	(data["sessions"] as Array).append(finished)
	data["schema_version"] = CURRENT_SCHEMA_VERSION
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf == null:
		return
	wf.store_string(JSON.stringify(data, "\t"))
	wf.close()


func _format_iso(unix_seconds: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02d %02d:%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]
