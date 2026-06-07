class_name ProgressStore
extends RefCounted

var stats: Dictionary = {}


func set_stats(value: Dictionary) -> void:
	stats = value.duplicate(true)


func get_stats() -> Dictionary:
	return stats.duplicate(true)


func load_from_path(path: String) -> Dictionary:
	stats = {}
	if not FileAccess.file_exists(path):
		return get_stats()
	var progress_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if progress_file == null:
		return get_stats()
	var text: String = progress_file.get_as_text()
	progress_file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		stats = (parsed as Dictionary).duplicate(true)
	return get_stats()


func save_to_path(path: String) -> void:
	var progress_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if progress_file == null:
		return
	progress_file.store_string(JSON.stringify(stats, "\t"))
	progress_file.close()


func merge_session(
	selected_mode: int,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	interval_stats_asked: Dictionary,
	interval_stats_correct: Dictionary,
	chord_stats_asked: Dictionary,
	chord_stats_correct: Dictionary
) -> Dictionary:
	var next_stats: Dictionary = stats.duplicate(true)
	var interval_bucket: Dictionary = _ensure_bucket(next_stats, "interval")
	var chord_bucket: Dictionary = _ensure_bucket(next_stats, "chord")
	var pitch_match_bucket: Dictionary = _ensure_bucket(next_stats, "pitch_match")
	var progression_bucket: Dictionary = _ensure_bucket(next_stats, "progression")
	var scale_mode_bucket: Dictionary = _ensure_bucket(next_stats, "scale_mode")
	var cadence_bucket: Dictionary = _ensure_bucket(next_stats, "cadence")
	match selected_mode:
		mode_interval:
			next_stats["sessions_interval"] = int(next_stats.get("sessions_interval", 0)) + 1
			next_stats["interval"] = _merge_mode_stats(interval_bucket, interval_stats_asked, interval_stats_correct)
		mode_chord:
			next_stats["sessions_chord"] = int(next_stats.get("sessions_chord", 0)) + 1
			next_stats["chord"] = _merge_mode_stats(chord_bucket, chord_stats_asked, chord_stats_correct)
		mode_pitch_match:
			next_stats["sessions_pitch_match"] = int(next_stats.get("sessions_pitch_match", 0)) + 1
			next_stats["pitch_match"] = _merge_mode_stats(pitch_match_bucket, chord_stats_asked, chord_stats_correct)
		mode_progression:
			next_stats["sessions_progression"] = int(next_stats.get("sessions_progression", 0)) + 1
			next_stats["progression"] = _merge_mode_stats(progression_bucket, chord_stats_asked, chord_stats_correct)
		mode_scale_mode:
			next_stats["sessions_scale_mode"] = int(next_stats.get("sessions_scale_mode", 0)) + 1
			next_stats["scale_mode"] = _merge_mode_stats(scale_mode_bucket, chord_stats_asked, chord_stats_correct)
		mode_cadence:
			next_stats["sessions_cadence"] = int(next_stats.get("sessions_cadence", 0)) + 1
			next_stats["cadence"] = _merge_mode_stats(cadence_bucket, chord_stats_asked, chord_stats_correct)
	stats = next_stats
	return get_stats()


func progress_home_line(mode: int, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_cadence: int) -> String:
	var sessions_key: String = ""
	var stats_key: String = ""
	match mode:
		mode_interval:
			sessions_key = "sessions_interval"
			stats_key = "interval"
		mode_chord:
			sessions_key = "sessions_chord"
			stats_key = "chord"
		mode_pitch_match:
			sessions_key = "sessions_pitch_match"
			stats_key = "pitch_match"
		mode_cadence:
			var cadence_sessions: int = int(stats.get("sessions_cadence", 0))
			if cadence_sessions < 2:
				return ""
			return "\u266a %d sessions" % cadence_sessions
		_:
			return ""
	var session_count: int = int(stats.get(sessions_key, 0))
	if session_count < 2:
		return ""
	var stats_any: Variant = stats.get(stats_key, {})
	if typeof(stats_any) != TYPE_DICTIONARY:
		return "\u266a %d sessions" % session_count
	var weak: Array[String] = []
	var stats_dict: Dictionary = stats_any as Dictionary
	for key in stats_dict.keys():
		var entry_any: Variant = stats_dict[key]
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var asked: int = int(entry.get("asked", 0))
		if asked < 3:
			continue
		var correct: int = int(entry.get("correct", 0))
		if float(correct) / float(asked) < 0.65:
			weak.append(str(key))
	if weak.is_empty():
		return "\u266a %d sessions  \u2022  All looking strong!" % session_count
	var show: Array[String] = weak.slice(0, 3)
	return "\u266a %d sessions  \u2022  Needs work: %s" % [session_count, ", ".join(show)]


func compute_missed_ids(stats_asked: Dictionary, stats_correct: Dictionary) -> Array[String]:
	var missed: Array[String] = []
	for key in stats_asked.keys():
		var asked := int(stats_asked.get(key, 0))
		if asked <= 0:
			continue
		var correct := int(stats_correct.get(key, 0))
		if correct < asked:
			missed.append(str(key))
	return missed


func update_streak(streak_count: int, streak_last_date: String, just_played: bool) -> Dictionary:
	var today_dict := Time.get_date_dict_from_system()
	var today := "%04d-%02d-%02d" % [int(today_dict["year"]), int(today_dict["month"]), int(today_dict["day"])]
	var new_count := streak_count
	var new_date := streak_last_date
	var changed := false
	if just_played:
		if streak_last_date != today:
			var yesterday_unix := Time.get_unix_time_from_system() - 86400.0
			var yd := Time.get_date_dict_from_unix_time(int(yesterday_unix))
			var yesterday := "%04d-%02d-%02d" % [int(yd["year"]), int(yd["month"]), int(yd["day"])]
			if streak_last_date == yesterday or streak_last_date == "":
				new_count = streak_count + 1
			else:
				new_count = 1
			new_date = today
			changed = true
	else:
		if streak_last_date != "" and streak_last_date != today:
			var yesterday_unix2 := Time.get_unix_time_from_system() - 86400.0
			var yd2 := Time.get_date_dict_from_unix_time(int(yesterday_unix2))
			var yesterday2 := "%04d-%02d-%02d" % [int(yd2["year"]), int(yd2["month"]), int(yd2["day"])]
			if streak_last_date != yesterday2:
				new_count = 0
				new_date = ""
				changed = true
	return {"count": new_count, "date": new_date, "changed": changed}


func _ensure_bucket(target: Dictionary, key: String) -> Dictionary:
	var bucket: Dictionary = {}
	var existing: Variant = target.get(key, {})
	if typeof(existing) == TYPE_DICTIONARY:
		bucket = (existing as Dictionary).duplicate(true)
	target[key] = bucket
	return bucket


func _merge_mode_stats(bucket: Dictionary, asked_counts: Dictionary, correct_counts: Dictionary) -> Dictionary:
	var merged: Dictionary = bucket.duplicate(true)
	for key in asked_counts.keys():
		var entry: Dictionary = {}
		var existing: Variant = merged.get(key, {})
		if typeof(existing) == TYPE_DICTIONARY:
			entry = (existing as Dictionary).duplicate(true)
		entry["asked"] = int(entry.get("asked", 0)) + int(asked_counts.get(key, 0))
		entry["correct"] = int(entry.get("correct", 0)) + int(correct_counts.get(key, 0))
		merged[key] = entry
	return merged
