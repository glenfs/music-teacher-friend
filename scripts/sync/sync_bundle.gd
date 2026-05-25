extends RefCounted
class_name SyncBundle

# Snapshot collector and applier for Tier A cloud sync.
#
# Bundle layout (the payload that lives in sync_snapshots.payload_json):
#   {
#     "schema_version": 1,
#     "bundled_at":     ISO-8601 timestamp string,
#     "files":          { "<path>": <json-decoded-content> },
#   }
#
# The map key is the user:// path of the source file; the value is the parsed
# JSON contents (one level deeper than the raw file text, so the server stores
# structured data — useful for future queries). On restore we re-serialize each
# value back to JSON and write it to the named path.

const SyncConfigScript = preload("res://scripts/sync/sync_config.gd")
const SCHEMA_VERSION := 1


# Folder where local pre-restore backups are kept. Rolling — last
# BACKUPS_KEEP files are retained; older ones are pruned on each new snapshot.
const BACKUPS_DIR := "user://sync_backups"
const BACKUPS_KEEP := 5


# Snapshots the current local state to a timestamped file under user://sync_backups/
# BEFORE a cloud restore overwrites it. Returns the absolute path of the backup
# file on success, or empty string on failure. Caller decides whether a failure
# blocks the restore — typically it should so we don't lose data silently.
static func snapshot_local_to_backup(reason: String = "pre_restore") -> String:
	var bundle: Dictionary = collect()
	if not DirAccess.dir_exists_absolute(BACKUPS_DIR):
		DirAccess.make_dir_recursive_absolute(BACKUPS_DIR)
	var stamp: int = int(Time.get_unix_time_from_system())
	var path: String = "%s/%s_%d.json" % [BACKUPS_DIR, reason, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(bundle, "\t"))
	f.close()
	_prune_old_backups()
	return path


# Keep only the most recent BACKUPS_KEEP files. Lex-sort matches chrono-sort
# because every file ends in "_<unix>.json".
static func _prune_old_backups() -> void:
	var dir := DirAccess.open(BACKUPS_DIR)
	if dir == null:
		return
	var entries: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and entry.ends_with(".json"):
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	entries.sort()
	while entries.size() > BACKUPS_KEEP:
		var oldest: String = entries[0]
		entries.remove_at(0)
		DirAccess.remove_absolute("%s/%s" % [BACKUPS_DIR, oldest])


# Walks every sync-target file under user:// and packs them into one dict.
# Missing files are simply skipped — the bundle reflects whatever state the
# device currently has, which is the right semantics for a backup.
static func collect() -> Dictionary:
	var files: Dictionary = {}
	# Shared single-file targets at the user:// root.
	for path in [
		SyncConfigScript.TEACHER_DATA_PATH,
		SyncConfigScript.EAR_SETTINGS_PATH,
		SyncConfigScript.PROGRESS_DATA_PATH,
		SyncConfigScript.LEARNING_PROGRESS_PATH,
	]:
		var parsed: Variant = _read_json(path)
		if parsed != null:
			files[path] = parsed
	# Per-student folder: students/<id>/*.json
	_collect_students(files)
	return {
		"schema_version": SCHEMA_VERSION,
		"bundled_at": Time.get_datetime_string_from_system(true, true),  # UTC ISO-8601
		"files": files,
	}


# Writes every file in the bundle back to disk, replacing whatever was there.
# Returns { ok: bool, written: int, errors: Array[String] }. Skips entries with
# unknown / unsafe paths (anything not under user://).
static func apply(bundle: Dictionary) -> Dictionary:
	var written: int = 0
	var errors: Array[String] = []
	if typeof(bundle) != TYPE_DICTIONARY:
		errors.append("bundle is not a dictionary")
		return {"ok": false, "written": 0, "errors": errors}
	var schema: int = int(bundle.get("schema_version", 0))
	if schema != SCHEMA_VERSION:
		errors.append("unknown schema_version %d (expected %d)" % [schema, SCHEMA_VERSION])
		return {"ok": false, "written": 0, "errors": errors}
	var files_v: Variant = bundle.get("files", {})
	if typeof(files_v) != TYPE_DICTIONARY:
		errors.append("bundle has no 'files' map")
		return {"ok": false, "written": 0, "errors": errors}
	var files: Dictionary = files_v
	for path_v in files.keys():
		var path: String = str(path_v)
		if not path.begins_with("user://"):
			errors.append("refusing to write outside user:// (%s)" % path)
			continue
		var parent: String = path.get_base_dir()
		if not parent.is_empty() and parent != "user://":
			DirAccess.make_dir_recursive_absolute(parent)
		var contents: Variant = files[path]
		var serialized: String = JSON.stringify(contents, "\t")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			errors.append("could not open for write: %s" % path)
			continue
		f.store_string(serialized)
		f.close()
		written += 1
	return {"ok": errors.is_empty(), "written": written, "errors": errors}


# Auto-derives a short, human-friendly label for this device. Used so the user
# can tell on the "list snapshots" view which device wrote which snapshot.
static func default_device_label() -> String:
	var os_name: String = OS.get_name()
	var host: String = OS.get_environment("COMPUTERNAME")
	if host.is_empty():
		host = OS.get_environment("HOSTNAME")
	if host.is_empty():
		host = "unnamed"
	return "%s — %s" % [os_name, host]


# --- Internal ---

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	# null is a valid parse result for empty / invalid; we only include valid JSON values.
	if parsed == null and not text.strip_edges().is_empty():
		return null
	return parsed


# Walks user://students/<id>/ and adds every .json file under each student id.
static func _collect_students(files: Dictionary) -> void:
	var root: String = SyncConfigScript.STUDENTS_ROOT
	if not DirAccess.dir_exists_absolute(root):
		return
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var student_root: String = root + "/" + entry
			if DirAccess.dir_exists_absolute(student_root):
				_collect_student_dir(student_root, files)
		entry = dir.get_next()
	dir.list_dir_end()


static func _collect_student_dir(student_root: String, files: Dictionary) -> void:
	var dir := DirAccess.open(student_root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var path: String = student_root + "/" + entry
			if entry.ends_with(".json") and FileAccess.file_exists(path):
				var parsed: Variant = _read_json(path)
				if parsed != null:
					files[path] = parsed
		entry = dir.get_next()
	dir.list_dir_end()
