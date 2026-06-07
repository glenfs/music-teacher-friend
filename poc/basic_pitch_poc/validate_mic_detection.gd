extends SceneTree

# Validate the live YIN mic-detection pipeline (HPF → noise gate → YIN →
# polyphony guard → stability) WITHOUT a microphone, by injecting real piano
# note audio. Runs each note clean and with added noise (to mimic a phone/tablet
# built-in mic) and reports what was detected and, on failure, WHY.
#
# Run: godot --headless --path . --script res://poc/basic_pitch_poc/validate_mic_detection.gd

const PitchDetectorScript = preload("res://scripts/audio/pitch_detector.gd")
const HOP := 512
const SR := 44100
const LO := 48   # C3
const HI := 84   # C6


func _name(midi: int) -> String:
	var n := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return "%s%d" % [n[midi % 12], midi / 12 - 1]


func _load_wav_mono(path: String) -> PackedFloat32Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedFloat32Array()
	var b := f.get_buffer(f.get_length()); f.close()
	var ch := 1; var off := -1; var ln := 0; var pos := 12
	while pos + 8 <= b.size():
		var cid := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := b.decode_u32(pos + 4)
		if cid == "fmt ":
			ch = b.decode_u16(pos + 10)
		elif cid == "data":
			off = pos + 8; ln = sz; break
		pos += 8 + sz + (sz & 1)
	var out := PackedFloat32Array()
	if off < 0:
		return out
	var fr := 2 * ch
	for i in range(ln / fr):
		out.append(float(b.decode_s16(off + i * fr)) / 32768.0)
	return out


# Run a note's samples through the detector; return {midi: detected_mode, reasons: {..}}
# gain scales the signal (simulate low mic input); compress>0 applies tanh
# soft-compression (simulate Android AGC flattening dynamics).
var _gate_rms := -1.0
var _gate_mult := -1.0


func _run(samples: PackedFloat32Array, noise: float, gain := 1.0, compress := 0.0) -> Dictionary:
	var det = PitchDetectorScript.new()
	det.begin_test_mode(float(SR))
	det.set_reject_polyphony(true)   # match the Sight-Notes mic path
	det.set_soft_pitch_mode(false)
	if _gate_rms > 0.0:
		det.set_gate_sensitivity(_gate_rms, _gate_mult)
	var counts := {}      # detected midi -> frames
	var reasons := {}     # reason -> frames
	var i := 0
	var n := samples.size()
	while i < n:
		var end: int = mini(i + HOP, n)
		var chunk := PackedFloat32Array()
		for k in range(i, end):
			var s: float = samples[k] * gain
			if compress > 0.0:
				s = tanh(s * compress) / compress   # AGC-like dynamic flattening
			if noise > 0.0:
				s += randf_range(-noise, noise)
			chunk.append(s)
		det.feed_test_samples(chunk)
		var r: Dictionary = det.poll()
		if r.get("detected", false):
			var m := int(r["midi"])
			counts[m] = int(counts.get(m, 0)) + 1
		else:
			var rn := str(r.get("reason", "?"))
			reasons[rn] = int(reasons.get(rn, 0)) + 1
		i = end
	# pick the most-detected midi
	var best := -1; var best_c := 0
	for m in counts:
		if int(counts[m]) > best_c:
			best_c = int(counts[m]); best = int(m)
	return {"midi": best, "frames": best_c, "reasons": reasons, "diag": det.get_diag_summary()}


func _pass(noise: float, label: String, gain := 1.0, compress := 0.0) -> Array:
	print("\n===== %s (noise=%.3f gain=%.2f comp=%.0f) =====" % [label, noise, gain, compress])
	var ok := 0; var total := 0; var fails: Array[String] = []
	for midi in range(LO, HI + 1):
		var wav := ProjectSettings.globalize_path("res://poc/basic_pitch_poc/notes/note_%d.wav" % midi)
		var samples := _load_wav_mono(wav)
		if samples.is_empty():
			continue
		total += 1
		var res := _run(samples, noise, gain, compress)
		var got: int = res["midi"]
		var correct := got == midi
		if correct:
			ok += 1
		else:
			# top failure reason
			var rs: Dictionary = res["reasons"]
			var top := "?"; var tc := 0
			for k in rs:
				if int(rs[k]) > tc:
					tc = int(rs[k]); top = str(k)
			var got_s := _name(got) if got >= 0 else "(none)"
			fails.append("%s→%s [%s]" % [_name(midi), got_s, top])
	print("  detected %d/%d (%.0f%%)" % [ok, total, 100.0 * ok / maxi(1, total)])
	if not fails.is_empty():
		print("  misses: " + ", ".join(fails))
	return [ok, total]


# Feed pure noise (no note) and count how many notes get falsely "detected".
func _false_positive_test(noise: float, label: String) -> int:
	var det = PitchDetectorScript.new()
	det.begin_test_mode(float(SR))
	det.set_reject_polyphony(true)
	det.set_soft_pitch_mode(false)
	if _gate_rms > 0.0:
		det.set_gate_sensitivity(_gate_rms, _gate_mult)
	var false_frames := 0
	for _i in range(400):
		var chunk := PackedFloat32Array()
		for _k in range(HOP):
			chunk.append(randf_range(-noise, noise))
		det.feed_test_samples(chunk)
		if det.poll().get("detected", false):
			false_frames += 1
	print("  %s: %d false-detect frames / 400 (noise=%.3f)" % [label, false_frames, noise])
	return false_frames


func _initialize() -> void:
	print("######## DEFAULT GATE (0.0025 / 4.0) ########")
	_pass(0.0, "CLEAN notes")
	var q0 := _pass(0.01, "QUIET / low gain", 0.06)
	var vq0 := _pass(0.008, "VERY QUIET", 0.025)

	print("\n######## CANDIDATE GATE (0.0010 / 2.5 ≈ 8 dB) ########")
	_gate_rms = 0.0010
	_gate_mult = 2.5
	var cclean := _pass(0.0, "CLEAN notes")
	var cheavy := _pass(0.04, "HEAVIER noise")
	var cq := _pass(0.01, "QUIET / low gain", 0.06)
	var cvq := _pass(0.008, "VERY QUIET", 0.025)
	var cagc := _pass(0.03, "AGC-compressed", 0.5, 8.0)
	print("\n--- false-positive checks (candidate gate) ---")
	var fp_quiet := _false_positive_test(0.006, "quiet room noise")
	var fp_loud := _false_positive_test(0.02, "louder room noise")

	print("\nVALIDATE_RESULT default[quiet=%d/%d vquiet=%d/%d] candidate[clean=%d/%d heavy=%d/%d quiet=%d/%d vquiet=%d/%d agc=%d/%d] falsepos[quiet=%d loud=%d]" % [
		q0[0], q0[1], vq0[0], vq0[1],
		cclean[0], cclean[1], cheavy[0], cheavy[1], cq[0], cq[1], cvq[0], cvq[1], cagc[0], cagc[1],
		fp_quiet, fp_loud])
	quit(0)
