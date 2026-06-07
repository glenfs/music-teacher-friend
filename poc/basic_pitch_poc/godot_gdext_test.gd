extends SceneTree

# Headless verification of the PolyphonyDetector GDExtension (Phase C).
# Loads chord WAVs, extracts mono samples, runs native detection, and checks the
# detected pitch classes match the expected chord. No mic, no UI.
#
# Run:
#   godot --headless --path . --script res://poc/basic_pitch_poc/godot_gdext_test.gd

const CASES := [
	{"file": "C_major_(C4).wav", "expect_pcs": [0, 4, 7]},        # C E G
	{"file": "G7_dom7.wav", "expect_pcs": [2, 5, 7, 11]},          # D F G B
	{"file": "single_bass_E2.wav", "expect_pcs": [4]},            # E
]


func _load_wav_mono(path: String) -> Dictionary:
	# Minimal RIFF/WAVE parser: 16-bit PCM, returns mono PackedFloat32Array + rate.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 44:
		return {}
	var channels := 1
	var rate := 44100
	var bits := 16
	var data_off := -1
	var data_len := 0
	var pos := 12  # skip RIFF....WAVE
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
	var n_frames := data_len / frame
	for i in range(n_frames):
		var base := data_off + i * frame
		var acc := 0.0
		for c in range(channels):
			var v := bytes.decode_s16(base + c * 2)
			acc += float(v) / 32768.0
		out.append(acc / float(channels))
	return {"samples": out, "rate": rate}


func _initialize() -> void:
	if not ClassDB.class_exists("PolyphonyDetector"):
		print("GDEXT_RESULT FAIL (PolyphonyDetector class not registered)")
		quit(1)
		return

	var det = ClassDB.instantiate("PolyphonyDetector")
	var model_path := ProjectSettings.globalize_path("res://addons/polyphony/nmp.onnx")
	var ok: bool = det.load_model(model_path)
	print("model loaded: ", ok, " (", model_path, ")")
	if not ok:
		print("GDEXT_RESULT FAIL (model load)")
		quit(1)
		return

	var all_pass := true
	for case in CASES:
		var wav_path := ProjectSettings.globalize_path(
			"res://poc/basic_pitch_poc/chords/" + str(case["file"]))
		var dec := _load_wav_mono(wav_path)
		if dec.is_empty():
			print("%s -> ERROR: could not parse wav" % case["file"])
			all_pass = false
			continue
		var r: Dictionary = det.detect_samples(dec["samples"], int(dec["rate"]))
		if r.has("error"):
			print("%s -> ERROR: %s" % [case["file"], r["error"]])
			all_pass = false
			continue
		var got := {}
		for pc in r.get("pitch_classes", []):
			got[int(pc)] = true
		var match_ok := true
		for pc in case["expect_pcs"]:
			if not got.has(int(pc)):
				match_ok = false
		if got.size() != case["expect_pcs"].size():
			match_ok = false
		all_pass = all_pass and match_ok
		print("%s -> notes=%s pcs=%s expect=%s %s (infer %.0fms, %d win)" % [
			case["file"], str(r.get("notes", [])), str(r.get("pitch_classes", [])),
			str(case["expect_pcs"]), "PASS" if match_ok else "FAIL",
			float(r.get("infer_ms", -1.0)), int(r.get("n_windows", -1))])

	print("GDEXT_RESULT ", "PASS" if all_pass else "FAIL")
	quit(0 if all_pass else 1)
