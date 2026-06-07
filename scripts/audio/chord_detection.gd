class_name ChordDetection
extends RefCounted

# Thin facade over the native PolyphonyDetector GDExtension (Basic Pitch / ONNX).
# Lets a chord exercise grade what the student actually PLAYED on their piano —
# YIN is monophonic and collapses a chord to one note; this returns every note.
#
# Degrades gracefully: if the extension isn't loaded (lib missing for the
# platform/build), is_available() is false and callers fall back to button input.
#
# Usage:
#   var cd := ChordDetection.new()
#   if cd.is_available():
#       var r := cd.grade(samples, rate, expected_midis)   # r.correct, r.missing_pcs, ...

const MODEL_RES_PATH := "res://addons/polyphony/nmp.onnx"

var _detector = null      # native PolyphonyDetector, or null
var _tried := false


func is_available() -> bool:
	_ensure()
	return _detector != null


func _ensure() -> void:
	if _tried:
		return
	_tried = true
	if not ClassDB.class_exists("PolyphonyDetector"):
		return
	var d: Object = ClassDB.instantiate("PolyphonyDetector")
	if d == null:
		return
	var model := _resolve_model_path()
	if model.is_empty() or not d.call("load_model", model):
		return
	_detector = d


# res:// works on disk in dev; in an exported .pck the model isn't a real file,
# so copy its bytes to user:// once and load from there.
func _resolve_model_path() -> String:
	var abs := ProjectSettings.globalize_path(MODEL_RES_PATH)
	if FileAccess.file_exists(abs):
		return abs
	if not FileAccess.file_exists(MODEL_RES_PATH):
		return ""
	var bytes := FileAccess.get_file_as_bytes(MODEL_RES_PATH)
	if bytes.is_empty():
		return ""
	var tmp := "user://nmp.onnx"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	f.close()
	return ProjectSettings.globalize_path(tmp)


# Returns { available, notes:[midi], pitch_classes:[0..11], infer_ms } or {available:false}.
func detect(samples: PackedFloat32Array, sample_rate: int) -> Dictionary:
	_ensure()
	if _detector == null:
		return {"available": false}
	var r: Dictionary = _detector.call("detect_samples", samples, sample_rate)
	r["available"] = true
	return r


# Grade a captured take against the expected chord (array of MIDI notes).
# Returns { available, correct, missing_pcs, extra_pcs, detected_pcs, notes, infer_ms }.
func grade(samples: PackedFloat32Array, sample_rate: int, expected_midis: Array) -> Dictionary:
	var r := detect(samples, sample_rate)
	if not bool(r.get("available", false)):
		return {"available": false}
	if r.has("error"):
		return {"available": true, "error": r["error"]}

	var detected := {}
	for pc in r.get("pitch_classes", []):
		detected[int(pc)] = true
	var expected := {}
	for m in expected_midis:
		expected[posmod(int(m), 12)] = true

	var missing: Array[int] = []
	for pc in expected.keys():
		if not detected.has(pc):
			missing.append(pc)
	var extra: Array[int] = []
	for pc in detected.keys():
		if not expected.has(pc):
			extra.append(pc)
	missing.sort()
	extra.sort()

	return {
		"available": true,
		"correct": missing.is_empty() and extra.is_empty(),
		"missing_pcs": missing,
		"extra_pcs": extra,
		"detected_pcs": detected.keys(),
		"notes": r.get("notes", []),
		"infer_ms": r.get("infer_ms", -1.0),
	}


# "C", "C#", ... for a pitch class — for building feedback text.
static func pc_name(pc: int) -> String:
	var names := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return names[posmod(pc, 12)]
