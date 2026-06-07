extends SceneTree

# Headless test of the ChordDetection facade (productization API): loads chord
# WAVs, grades them against the expected chord MIDIs, checks correctness +
# missing/extra reporting. No mic, no UI.
#
# Run: godot --headless --path . --script res://poc/basic_pitch_poc/chord_detection_test.gd

const ChordDetectionScript = preload("res://scripts/audio/chord_detection.gd")

const CASES := [
	{"file": "C_major_(C4).wav", "expect": [60, 64, 67], "want_correct": true},
	{"file": "G7_dom7.wav", "expect": [55, 59, 62, 65], "want_correct": true},
	# Mismatch: grade a C-major take against an A-minor prompt -> should flag missing/extra.
	{"file": "C_major_(C4).wav", "expect": [57, 60, 64], "want_correct": false},
]


func _load_wav_mono(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var channels := 1
	var rate := 44100
	var bits := 16
	var data_off := -1
	var data_len := 0
	var pos := 12
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csz := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if cid == "fmt ":
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif cid == "data":
			data_off = body
			data_len = csz
			break
		pos = body + csz + (csz & 1)
	if data_off < 0 or bits != 16:
		return {}
	var out := PackedFloat32Array()
	var frame := 2 * channels
	for i in range(data_len / frame):
		var base := data_off + i * frame
		var acc := 0.0
		for c in range(channels):
			acc += float(bytes.decode_s16(base + c * 2)) / 32768.0
		out.append(acc / float(channels))
	return {"samples": out, "rate": rate}


func _initialize() -> void:
	var cd = ChordDetectionScript.new()
	print("ChordDetection available: ", cd.is_available())
	if not cd.is_available():
		print("CHORD_DETECT_RESULT FAIL (native detector unavailable)")
		quit(1)
		return

	var all_pass := true
	for case in CASES:
		var wav := ProjectSettings.globalize_path("res://poc/basic_pitch_poc/chords/" + str(case["file"]))
		var dec := _load_wav_mono(wav)
		if dec.is_empty():
			print("%s -> ERROR loading wav" % case["file"]); all_pass = false; continue
		var r: Dictionary = cd.grade(dec["samples"], int(dec["rate"]), case["expect"])
		if not r.get("available", false) or r.has("error"):
			print("%s -> ERROR: %s" % [case["file"], str(r.get("error", "unavailable"))]); all_pass = false; continue
		var ok: bool = (bool(r["correct"]) == bool(case["want_correct"]))
		all_pass = all_pass and ok
		print("%s vs %s -> correct=%s (want %s) missing=%s extra=%s %s" % [
			case["file"], str(case["expect"]), str(r["correct"]), str(case["want_correct"]),
			str(r["missing_pcs"]), str(r["extra_pcs"]), "PASS" if ok else "FAIL"])

	print("CHORD_DETECT_RESULT ", "PASS" if all_pass else "FAIL")
	quit(0 if all_pass else 1)
