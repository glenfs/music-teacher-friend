extends SceneTree

# Headless verification of the Godot -> ONNX-sidecar -> note-events path.
# Run:
#   godot --headless --path . --script res://poc/basic_pitch_poc/godot_grader_test.gd
#
# Grades pre-built chord WAVs (created by run_poc.py) from inside Godot and
# checks the detected pitch classes match the expected chord. No mic, no UI.

const PolyphonyGraderScript = preload("res://scripts/audio/polyphony_grader.gd")

const CASES := [
	{"file": "C_major_(C4).wav", "expect": [60, 64, 67]},
	{"file": "G7_dom7.wav", "expect": [55, 59, 62, 65]},
	{"file": "single_bass_E2.wav", "expect": [40]},
]


func _initialize() -> void:
	var grader = PolyphonyGraderScript.new()
	print("GRADER available: ", grader.is_available())

	var all_pass := true
	for case in CASES:
		var wav: String = ProjectSettings.globalize_path(
			"res://poc/basic_pitch_poc/chords/" + str(case["file"]))
		var r: Dictionary = grader.grade_against(wav, case["expect"])
		var ok: bool = bool(r.get("ok", false)) and bool(r.get("pitch_class_match", false))
		all_pass = all_pass and ok
		if r.get("ok", false):
			print("%s -> notes=%s pcs=%s match=%s (infer %sms) %s" % [
				case["file"], str(r.get("notes", [])), str(r.get("pitch_classes", [])),
				str(r.get("pitch_class_match", false)), str(r.get("infer_ms", -1)),
				"PASS" if ok else "FAIL"])
		else:
			print("%s -> ERROR: %s %s" % [case["file"], str(r.get("error", "?")),
				str(r.get("raw", ""))])

	print("GRADER_RESULT ", "PASS" if all_pass else "FAIL")
	quit(0 if all_pass else 1)
