class_name RhythmGenerator
extends RefCounted

# New grid supports triplets cleanly: 48 steps/bar (12 per beat).
const STEPS_PER_BAR := 48
const STEP_BEATS := (1.0 / 12.0)

# Legacy saved rhythms used a 16-step grid (16th-note grid). Keep parsing support.
const LEGACY_STEPS_PER_BAR := 16
const LEGACY_STEP_BEATS := 0.25

const TOKEN_TO_STEPS := {
	"4.0": 48, "3.0": 36, "2.0": 24, "1.5": 18, "1.0": 12, "0.5": 6, "0.25": 3,
	"r4.0": 48, "r3.0": 36, "r2.0": 24, "r1.5": 18, "r1.0": 12, "r0.5": 6, "r0.25": 3,
	"t4": 8, "t8": 4
}

const LEGACY_TOKEN_TO_STEPS := {
	"4.0": 16, "3.0": 12, "2.0": 8, "1.5": 6, "1.0": 4, "0.5": 2, "0.25": 1,
	"r4.0": 16, "r3.0": 12, "r2.0": 8, "r1.5": 6, "r1.0": 4, "r0.5": 2, "r0.25": 1
}

var allow_rests := true
var time_signature := "4/4"


func generate_exercise(difficulty_level: int, seed: int = -1) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var level := clampi(difficulty_level, 1, 99)
	var bars: Array[String] = []
	var motifs: Array = []
	var motif_count := rng.randi_range(2, 4)
	for _i in range(motif_count):
		var motif_len := 1 if rng.randf() < 0.72 else 2
		var motif_bars: Array[String] = []
		for _j in range(motif_len):
			motif_bars.append(generate_bar(level, rng))
		motifs.append(motif_bars)
	while bars.size() < 16:
		var motif: Array[String] = motifs[rng.randi_range(0, motifs.size() - 1)]
		for src_bar in motif:
			if bars.size() >= 16:
				break
			var next_bar := str(src_bar)
			if rng.randf() < 0.26:
				next_bar = _vary_bar(next_bar, level, rng)
			if _would_repeat_too_many(bars, next_bar):
				next_bar = generate_bar(level, rng)
			var toks := next_bar.split(" ", false)
			if not validate_bar(toks):
				next_bar = generate_bar(level, rng)
			bars.append(next_bar)
	return bars


func generate_bar(difficulty_level: int, rng: RandomNumberGenerator) -> String:
	var level := clampi(difficulty_level, 1, 99)
	var events := _generate_bar_events(level, rng)
	return _encode_bar(events)


func validate_bar(bar_tokens: Array[String]) -> bool:
	var bar_steps := _steps_per_bar_for_tokens(bar_tokens)
	if bar_steps <= 0:
		return false
	if bar_tokens.is_empty() or bar_tokens[0] == "_":
		return false
	var token_map := _token_map_for_steps(bar_steps)
	var step := 0
	var event_count := 0
	while step < bar_steps:
		var tok := str(bar_tokens[step])
		if tok == "_":
			return false
		if not token_map.has(tok):
			return false
		var dur_steps := int(token_map[tok])
		if dur_steps <= 0 or (step + dur_steps) > bar_steps:
			return false
		event_count += 1
		for i in range(1, dur_steps):
			if str(bar_tokens[step + i]) != "_":
				return false
		step += dur_steps
	return step == bar_steps and event_count >= 1


func bar_to_events(bar_tokens: Array[String]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var bar_steps := _steps_per_bar_for_tokens(bar_tokens)
	if bar_steps <= 0 or not validate_bar(bar_tokens):
		return events
	var token_map := _token_map_for_steps(bar_steps)
	var step_beats := _step_beats_for_steps(bar_steps)
	var step := 0
	while step < bar_steps:
		var tok := str(bar_tokens[step])
		var dur_steps := int(token_map[tok])
		var is_rest := tok.begins_with("r")
		var dur_beats := _token_to_beats(tok)
		var is_triplet := (tok == "t8" or tok == "t4")
		events.append({
			"is_rest": is_rest,
			"duration_beats": dur_beats,
			"start_step": step,
			"start_beat": float(step) * step_beats,
			"expected_hit": not is_rest,
			"triplet": is_triplet,
			"triplet_token": tok if is_triplet else ""
		})
		step += dur_steps
	return events


func validate_exercise(exercise_bars: Array[String]) -> bool:
	if exercise_bars.size() != 16:
		return false
	for bar in exercise_bars:
		var toks := str(bar).split(" ", false)
		if not validate_bar(toks):
			return false
	return true


func summarize_exercise(exercise_bars: Array[String]) -> Dictionary:
	var hit_count := 0
	var rest_count := 0
	var valid := true
	for bar in exercise_bars:
		var toks := str(bar).split(" ", false)
		if not validate_bar(toks):
			valid = false
			continue
		for evt in bar_to_events(toks):
			if bool(evt.get("is_rest", false)):
				rest_count += 1
			else:
				hit_count += 1
	return {"valid": valid, "hit_count": hit_count, "rest_count": rest_count}


func self_test_generate_100() -> bool:
	for level in range(1, 13):
		for i in range(100):
			var seed := (level * 10000) + i
			var bars := generate_exercise(level, seed)
			if not validate_exercise(bars):
				push_error("RhythmGenerator self-test failed at level %d seed %d" % [level, seed])
				return false
	return true


func _generate_bar_events(level: int, rng: RandomNumberGenerator) -> Array:
	var events: Array = []
	if level <= 2:
		return _bar_level_1_2(rng)
	if level <= 4:
		return _bar_level_3_4(level, rng)
	if level <= 6:
		return _bar_level_5_6(rng)
	if level <= 8:
		return _bar_level_7_8(level, rng)
	events = _bar_level_9_plus(level, rng)
	if events.size() > _max_events_for_level(level):
		return _bar_level_7_8(mini(level, 8), rng)
	return events


func _bar_level_1_2(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for _i in range(4):
		var rest := allow_rests and rng.randf() < 0.36
		out.append({"dur": 12, "rest": rest})
	return out


func _bar_level_3_4(level: int, rng: RandomNumberGenerator) -> Array:
	# L3: add half notes/rests. L4+: introduce dotted half (minimally/readably).
	if level >= 4 and rng.randf() < 0.28:
		var out_dh: Array = []
		out_dh.append({"dur": 36, "rest": allow_rests and rng.randf() < 0.14}) # dotted half
		if rng.randf() < 0.28:
			out_dh.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.18})
			out_dh.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.18})
		else:
			out_dh.append({"dur": 12, "rest": allow_rests and rng.randf() < 0.24})
		return out_dh
	var roll := rng.randf()
	if roll < 0.40:
		return [
			{"dur": 24, "rest": allow_rests and rng.randf() < 0.30},
			{"dur": 24, "rest": allow_rests and rng.randf() < 0.30}
		]
	if roll < 0.70:
		var first_half_rest := allow_rests and rng.randf() < 0.25
		return [
			{"dur": 24, "rest": first_half_rest},
			{"dur": 12, "rest": allow_rests and rng.randf() < 0.25},
			{"dur": 12, "rest": allow_rests and rng.randf() < 0.25}
		]
	return _bar_level_1_2(rng)


func _bar_level_5_6(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var beat := 0
	while beat < 4:
		var remaining_beats := 4 - beat
		if remaining_beats >= 2 and rng.randf() < 0.18:
			out.append({"dur": 24, "rest": allow_rests and rng.randf() < 0.20})
			beat += 2
			continue
		var mode_roll := rng.randf()
		if mode_roll < 0.36:
			# Beat-aligned eighth pair only.
			out.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.15})
			out.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.15})
		else:
			out.append({"dur": 12, "rest": allow_rests and rng.randf() < 0.28})
		beat += 1
	return out


func _bar_level_7_8(level: int, rng: RandomNumberGenerator) -> Array:
	var roll := rng.randf()
	if roll < 0.38:
		# Dotted half mostly starts on beat 1, then fill beat 4.
		var out: Array = []
		out.append({"dur": 36, "rest": allow_rests and rng.randf() < 0.15})
		if rng.randf() < 0.28:
			out.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.20})
			out.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.20})
		else:
			out.append({"dur": 12, "rest": allow_rests and rng.randf() < 0.25})
		return out
	if level >= 8 and roll < 0.70:
		# Dotted-quarter intro (readable, beat-oriented combinations).
		var choices: Array = [
			[
				{"dur": 18, "rest": allow_rests and rng.randf() < 0.12},
				{"dur": 6, "rest": allow_rests and rng.randf() < 0.16},
				{"dur": 12, "rest": allow_rests and rng.randf() < 0.18},
				{"dur": 12, "rest": allow_rests and rng.randf() < 0.18}
			],
			[
				{"dur": 12, "rest": allow_rests and rng.randf() < 0.18},
				{"dur": 18, "rest": allow_rests and rng.randf() < 0.12},
				{"dur": 6, "rest": allow_rests and rng.randf() < 0.16},
				{"dur": 12, "rest": allow_rests and rng.randf() < 0.18}
			],
			[
				{"dur": 18, "rest": allow_rests and rng.randf() < 0.12},
				{"dur": 18, "rest": allow_rests and rng.randf() < 0.12},
				{"dur": 12, "rest": allow_rests and rng.randf() < 0.20}
			]
		]
		return choices[rng.randi_range(0, choices.size() - 1)]
	return _bar_level_5_6(rng)


func _bar_level_9_plus(level: int, rng: RandomNumberGenerator) -> Array:
	var chunks: Array[Dictionary] = [
		{"kind": "q", "steps": 12},
		{"kind": "h", "steps": 24},
		{"kind": "e_pair", "steps": 12},
		{"kind": "s_run4", "steps": 12},
		{"kind": "s_run8", "steps": 24},
		{"kind": "dhalf_plus_q", "steps": 48}
	]
	if level >= 10:
		chunks.append_array([
			{"kind": "trip8_beat", "steps": 12},    # 3 eighth-triplets in one beat
			{"kind": "trip8_2beats", "steps": 24}   # 6 eighth-triplets
		])
	if level >= 11:
		chunks.append({"kind": "trip4_2beats", "steps": 24}) # 3 quarter-triplets across two beats
	var out: Array = []
	var step := 0
	while step < STEPS_PER_BAR:
		var rem := STEPS_PER_BAR - step
		var beat_aligned := (step % 12) == 0
		var options: Array[Dictionary] = []
		for c in chunks:
			var csteps := int(c["steps"])
			if csteps > rem:
				continue
			var k := str(c["kind"])
			if not beat_aligned and k not in ["q", "e_pair", "s_run4"]:
				continue
			if k == "dhalf_plus_q" and step != 0:
				continue
			if k == "trip4_2beats" and (step % 24) != 0:
				continue
			options.append(c)
		if options.is_empty():
			options.append({"kind": "q", "steps": 12})
		var pick: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		match str(pick["kind"]):
			"h":
				out.append({"dur": 24, "rest": allow_rests and rng.randf() < 0.18})
				step += 24
			"q":
				out.append({"dur": 12, "rest": allow_rests and rng.randf() < 0.20})
				step += 12
			"e_pair":
				out.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.10})
				out.append({"dur": 6, "rest": allow_rests and rng.randf() < 0.10})
				step += 12
			"s_run4":
				for _i in range(4):
					out.append({"dur": 3, "rest": allow_rests and rng.randf() < 0.05})
				step += 12
			"s_run8":
				for _i in range(8):
					out.append({"dur": 3, "rest": allow_rests and rng.randf() < 0.04})
				step += 24
			"dhalf_plus_q":
				out.append({"dur": 36, "rest": allow_rests and rng.randf() < 0.10})
				out.append({"dur": 12, "rest": allow_rests and rng.randf() < 0.20})
				step += 48
			"trip8_beat":
				for _i in range(3):
					out.append({"dur": 4, "rest": false, "triplet": true, "triplet_token": "t8"})
				step += 12
			"trip8_2beats":
				for _i in range(6):
					out.append({"dur": 4, "rest": false, "triplet": true, "triplet_token": "t8"})
				step += 24
			"trip4_2beats":
				for _i in range(3):
					out.append({"dur": 8, "rest": false, "triplet": true, "triplet_token": "t4"})
				step += 24
			_:
				out.append({"dur": 12, "rest": false})
				step += 12
	if out.size() > _max_events_for_level(level):
		return _bar_level_7_8(mini(level, 8), rng)
	return out


func _vary_bar(bar: String, level: int, rng: RandomNumberGenerator) -> String:
	if rng.randf() < 0.55:
		return generate_bar(level, rng)
	var toks := bar.split(" ", false)
	if not validate_bar(toks):
		return generate_bar(level, rng)
	var events := bar_to_events(toks)
	if events.is_empty():
		return generate_bar(level, rng)
	var idx := rng.randi_range(0, events.size() - 1)
	var target := events[idx]
	var dur_beats := float(target.get("duration_beats", 0.0))
	var target_triplet := bool(target.get("triplet", false))
	if target_triplet:
		# Avoid turning triplet notes into rests or vice versa for readability.
		return generate_bar(level, rng)
	if dur_beats <= 0.25 and level < 9:
		return generate_bar(level, rng)
	var is_rest := bool(target.get("is_rest", false))
	if not allow_rests and not is_rest:
		return bar
	var start_step := int(target.get("start_step", 0))
	var tok := str(toks[start_step])
	toks[start_step] = tok.substr(1) if is_rest else ("r" + tok)
	return " ".join(toks)


func _would_repeat_too_many(existing: Array[String], next_bar: String) -> bool:
	if existing.is_empty():
		return false
	var same_run := 0
	for i in range(existing.size() - 1, -1, -1):
		if str(existing[i]) == next_bar:
			same_run += 1
		else:
			break
	return same_run >= 2


func _max_events_for_level(level: int) -> int:
	if level <= 4:
		return 4
	if level <= 8:
		return 6
	return 10


func _encode_bar(events: Array) -> String:
	var tokens: Array[String] = []
	for e in events:
		var dur_steps := int(e.get("dur", 12))
		var is_rest := bool(e.get("rest", false))
		var triplet_token := str(e.get("triplet_token", ""))
		var token := ""
		if not triplet_token.is_empty():
			token = triplet_token
		else:
			var beats_str := _steps_to_beats_token(dur_steps)
			token = ("r" + beats_str) if is_rest else beats_str
		tokens.append(token)
		for _i in range(dur_steps - 1):
			tokens.append("_")
	if tokens.size() != STEPS_PER_BAR:
		tokens.clear()
		for _i in range(4):
			tokens.append("1.0")
			for _j in range(11):
				tokens.append("_")
	return " ".join(tokens)


func _steps_to_beats_token(steps: int) -> String:
	match steps:
		48: return "4.0"
		36: return "3.0"
		24: return "2.0"
		18: return "1.5"
		12: return "1.0"
		6: return "0.5"
		3: return "0.25"
		8: return "t4"
		4: return "t8"
		_: return "1.0"


func _steps_per_bar_for_tokens(bar_tokens: Array[String]) -> int:
	if bar_tokens.size() == STEPS_PER_BAR:
		return STEPS_PER_BAR
	if bar_tokens.size() == LEGACY_STEPS_PER_BAR:
		return LEGACY_STEPS_PER_BAR
	return -1


func _token_map_for_steps(bar_steps: int) -> Dictionary:
	return TOKEN_TO_STEPS if bar_steps == STEPS_PER_BAR else LEGACY_TOKEN_TO_STEPS


func _step_beats_for_steps(bar_steps: int) -> float:
	return STEP_BEATS if bar_steps == STEPS_PER_BAR else LEGACY_STEP_BEATS


func _token_to_beats(tok_in: String) -> float:
	var tok := str(tok_in)
	if tok == "t8":
		return 1.0 / 3.0
	if tok == "t4":
		return 2.0 / 3.0
	var is_rest := tok.begins_with("r")
	var dur_token := tok.substr(1) if is_rest else tok
	return float(dur_token)
