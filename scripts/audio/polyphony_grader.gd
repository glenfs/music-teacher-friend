class_name PolyphonyGrader
extends RefCounted

# Desktop (Windows) polyphonic note grader — step 2 of the ML mic spike.
#
# YIN is monophonic: fed a chord it reports ONE note, so a struck chord can read
# as a "correct" single answer. This grader instead runs Spotify Basic Pitch
# (Apache-2.0) over a recorded take and returns ALL notes that were played, so a
# chord can be graded against the expected pitch classes.
#
# It does NOT embed an ML runtime in Godot. It shells out to a Python sidecar
# (poc/basic_pitch_poc/infer.py) that runs the validated ONNX pipeline and
# returns one JSON line. This is the DESKTOP architecture: it proves the in-app
# take -> polyphonic-grade flow without any native build. The Android path
# replaces the sidecar with native ONNX/TFLite + ported post-processing.
#
# Usage:
#   var grader := PolyphonyGrader.new()
#   var r := grader.grade_against(wav_abs_path, [60, 64, 67])  # expect C major
#   if r.ok and r.pitch_class_match: ...
#
# grade_wav() returns the raw detection dict; grade_against() adds match info.

const MARKER := "BP_RESULT "

# PoC paths — the dev venv + sidecar under res://poc. A shipped desktop build
# would point these at a frozen single-file exe instead (no Python install).
var _python_exe := ""
var _infer_script := ""


func _init() -> void:
	_python_exe = ProjectSettings.globalize_path("res://poc/basic_pitch_poc/.venv/Scripts/python.exe")
	_infer_script = ProjectSettings.globalize_path("res://poc/basic_pitch_poc/infer.py")


func set_paths(python_exe: String, infer_script: String) -> void:
	_python_exe = python_exe
	_infer_script = infer_script


func is_available() -> bool:
	return FileAccess.file_exists(_python_exe) and FileAccess.file_exists(_infer_script)


# Runs the sidecar over an absolute WAV path. Returns:
#   { ok: bool, notes: [midi], pitch_classes: [0..11], all_detected: [midi],
#     load_ms: int, infer_ms: int, exit_code: int, error?: String }
func grade_wav(wav_abs_path: String) -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "sidecar unavailable (python/infer.py missing)"}
	if not FileAccess.file_exists(wav_abs_path):
		return {"ok": false, "error": "wav missing: " + wav_abs_path}

	var output: Array = []
	var code: int = OS.execute(_python_exe, [_infer_script, wav_abs_path], output, false, false)

	# Scan every captured chunk/line for the clean marker line.
	for chunk in output:
		for line in str(chunk).split("\n", false):
			if line.begins_with(MARKER):
				var parsed: Variant = JSON.parse_string(line.substr(MARKER.length()))
				if parsed is Dictionary:
					var d: Dictionary = parsed
					d["exit_code"] = code
					d["ok"] = not d.has("error")
					return d
	return {
		"ok": false,
		"error": "no result marker in sidecar output",
		"exit_code": code,
		"raw": "\n".join(PackedStringArray(output)),
	}


# Convenience: grade a take against an expected chord (array of MIDI notes).
# Adds, on top of grade_wav():
#   detected_pcs, expected_pcs, missing_pcs, extra_pcs, pitch_class_match (exact set match)
func grade_against(wav_abs_path: String, expected_midis: Array) -> Dictionary:
	var r := grade_wav(wav_abs_path)
	if not r.get("ok", false):
		return r
	var detected_pcs := {}
	for m in r.get("pitch_classes", []):
		detected_pcs[int(m)] = true
	var expected_pcs := {}
	for m in expected_midis:
		expected_pcs[int(m) % 12] = true
	var missing: Array = []
	for pc in expected_pcs:
		if not detected_pcs.has(pc):
			missing.append(pc)
	var extra: Array = []
	for pc in detected_pcs:
		if not expected_pcs.has(pc):
			extra.append(pc)
	missing.sort()
	extra.sort()
	r["detected_pcs"] = detected_pcs.keys()
	r["expected_pcs"] = expected_pcs.keys()
	r["missing_pcs"] = missing
	r["extra_pcs"] = extra
	r["pitch_class_match"] = missing.is_empty() and extra.is_empty()
	return r
