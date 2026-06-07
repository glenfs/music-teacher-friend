class_name DebugServer
extends Node

# Tiny HTTP/JSON debug API for the AI-orchestrated QA pipeline. Spun up
# only when --debug-server is passed on the command line (kept off in
# normal builds). Lets an external Python driver (qa_orchestrator.py)
# poke at the running game: switch modes, generate drills, inject MIDI,
# pull state snapshots, capture logs.
#
# Implementation notes:
#   • Uses TCPServer + manual HTTP parsing (no third-party deps). Enough
#     for localhost JSON traffic; we don't terminate TLS or speak HTTP/2.
#   • Bound to 127.0.0.1 only — never exposed off-host.
#   • The interesting work happens on the IntervalBirds main scene; this
#     module just routes requests to its existing handlers + state vars.
#   • Endpoints intentionally mirror the qa_bot.gd primitives so a test
#     written against one can be replayed against the other.
#
# Endpoints (all JSON):
#   GET  /health                 → { ok: true, build, mode, midi_active }
#   GET  /state                  → snapshot of common state vars
#   GET  /logs?since=ts          → recent log lines + structured events
#   POST /mode { name }          → switch top-level mode (Interval, Chord, ...)
#   POST /drill/start { type, key, level, octaves, hand, tempo, seed? }
#   POST /drill/stop
#   POST /drill/play             → trigger the current drill's playback
#   POST /midi/inject { pitch, velocity?, hold_ms? }
#   POST /audio/probe            → drain the audio-probe buffer
#   POST /assert { member, op, value }   → assert flag/var; { passed, observed }
#   POST /screenshot { tag }
#   POST /quit                   → graceful exit


const DEFAULT_PORT := 8765
const DEFAULT_HOST := "127.0.0.1"
const LOG_CAP := 1024
const MAX_REQUEST_BYTES := 64 * 1024
const ACCEPT_PER_FRAME := 4


var _server := TCPServer.new()
var _listening := false
var _port: int = DEFAULT_PORT
var _app: Node = null
var _log_buffer: Array = []  # ring buffer { unix, level, text }
var _next_log_seq: int = 0
var _active_clients: Array = []  # StreamPeerTCP awaiting read/write
var _logger_callable: Callable = Callable()


func setup(app: Node, port: int = DEFAULT_PORT) -> void:
	_app = app
	_port = port
	_logger_callable = Callable(self, "log_event")
	# Capture push_error / push_warning messages so the orchestrator can
	# see them in the /logs feed — Godot doesn't auto-route those to us.
	set_process(false)


func start() -> bool:
	var err := _server.listen(_port, DEFAULT_HOST)
	if err != OK:
		push_error("[DebugServer] listen() failed on %s:%d (err=%d)" % [DEFAULT_HOST, _port, err])
		return false
	_listening = true
	set_process(true)
	log_event("INFO", "DebugServer listening on http://%s:%d" % [DEFAULT_HOST, _port])
	print("[DebugServer] listening on http://%s:%d" % [DEFAULT_HOST, _port])
	return true


func stop() -> void:
	for client_any in _active_clients:
		var client: StreamPeerTCP = client_any
		if client != null and is_instance_valid(client):
			client.disconnect_from_host()
	_active_clients.clear()
	if _listening:
		_server.stop()
		_listening = false
	set_process(false)


func _process(_delta: float) -> void:
	if not _listening:
		return
	# Accept up to ACCEPT_PER_FRAME new connections per frame so a flood
	# can't stall the game loop.
	var accepted := 0
	while _server.is_connection_available() and accepted < ACCEPT_PER_FRAME:
		var client := _server.take_connection()
		if client != null:
			_active_clients.append(client)
		accepted += 1
	# Service in-flight clients. Each connection serves a single request
	# (no keep-alive) for simplicity.
	var still_open: Array = []
	for client_any in _active_clients:
		var client: StreamPeerTCP = client_any
		if client == null or not is_instance_valid(client):
			continue
		client.poll()
		var status := client.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED and status != StreamPeerTCP.STATUS_CONNECTING:
			continue
		if client.get_available_bytes() <= 0:
			still_open.append(client)
			continue
		_service_client(client)
	_active_clients = still_open


func _service_client(client: StreamPeerTCP) -> void:
	var buf := PackedByteArray()
	var loop_guard := 0
	while client.get_available_bytes() > 0 and buf.size() < MAX_REQUEST_BYTES:
		var chunk_size: int = mini(client.get_available_bytes(), 4096)
		var chunk_pair: Array = client.get_data(chunk_size)
		if chunk_pair[0] != OK:
			break
		buf.append_array(chunk_pair[1])
		loop_guard += 1
		if loop_guard > 16:
			break
	if buf.is_empty():
		client.disconnect_from_host()
		return
	var raw := buf.get_string_from_utf8()
	var parsed := _parse_http_request(raw)
	var response := _dispatch(parsed)
	_write_http_response(client, response)
	client.disconnect_from_host()


func _parse_http_request(raw: String) -> Dictionary:
	var result: Dictionary = {"method": "", "path": "", "query": {}, "body": {}, "raw_body": ""}
	var split_idx := raw.find("\r\n\r\n")
	var head := raw if split_idx < 0 else raw.substr(0, split_idx)
	var body := "" if split_idx < 0 else raw.substr(split_idx + 4)
	var lines := head.split("\r\n", false)
	if lines.is_empty():
		return result
	var request_line: PackedStringArray = lines[0].split(" ", false)
	if request_line.size() >= 2:
		result["method"] = request_line[0]
		var raw_path: String = request_line[1]
		var qpos := raw_path.find("?")
		if qpos >= 0:
			result["path"] = raw_path.substr(0, qpos)
			result["query"] = _parse_query(raw_path.substr(qpos + 1))
		else:
			result["path"] = raw_path
	result["raw_body"] = body
	if not body.is_empty():
		var json_parsed: Variant = JSON.parse_string(body)
		if json_parsed is Dictionary:
			result["body"] = json_parsed as Dictionary
	return result


func _parse_query(qs: String) -> Dictionary:
	var out: Dictionary = {}
	for pair_any in qs.split("&", false):
		var pair: String = pair_any
		var eq := pair.find("=")
		if eq < 0:
			out[pair] = ""
		else:
			out[pair.substr(0, eq)] = pair.substr(eq + 1).uri_decode()
	return out


func _dispatch(req: Dictionary) -> Dictionary:
	var method: String = str(req.get("method", ""))
	var path: String = str(req.get("path", ""))
	var body: Dictionary = req.get("body", {}) as Dictionary
	var query: Dictionary = req.get("query", {}) as Dictionary
	# Route table — each branch returns {status, body}.
	match path:
		"/health":
			var health: Dictionary = {}
			health["ok"] = true
			health["build"] = _build_string()
			health["mode"] = _member_int("_selected_mode", -1)
			# Use the bool-safe accessors — bool(null) raises "Nonexistent
			# 'bool' constructor" in GDScript 4 when the member doesn't
			# exist on the app (e.g. early bootstrap before vars are set).
			health["midi_active"] = _member_bool("_midi_grading_active", false)
			health["qa_enabled"] = _member_bool("_qa_enabled", false)
			return _ok(health)
		"/state":
			return _ok(_snapshot_state())
		"/logs":
			var since: int = int(str(query.get("since", "0")))
			return _ok({"logs": _logs_since(since), "next": _next_log_seq})
		"/mode":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_mode_switch(body)
		"/drill/start":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_drill_start(body)
		"/drill/stop":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_drill_stop()
		"/drill/play":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_drill_play()
		"/midi/inject":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_midi_inject(body)
		"/audio/probe":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_audio_probe()
		"/assert":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_assert(body)
		"/screenshot":
			if method != "POST": return _err(405, "method not allowed")
			return _handle_screenshot(body)
		"/quit":
			if method != "POST": return _err(405, "method not allowed")
			call_deferred("_graceful_quit")
			return _ok({"quitting": true})
	return _err(404, "no route for %s %s" % [method, path])


# --- Handlers ---


func _handle_mode_switch(body: Dictionary) -> Dictionary:
	# Accept either { name: "Interval" } (friendly) or { mode: 0 } (int).
	# Maps friendly name → mode constant, then routes through
	# _on_mode_button_pressed(int) which is the actual app handler. The
	# previous _on_mode_selected() path takes no args — wrong signature.
	var name: String = str(body.get("name", "")).strip_edges()
	var mode_int: int = -1
	if body.has("mode"):
		mode_int = int(body.get("mode", -1))
	elif not name.is_empty():
		mode_int = _mode_int_for_name(name)
	if mode_int < 0:
		return _err(400, "mode required (name=\"Interval\" or mode=0)")
	if _app == null or not _app.has_method("_on_mode_button_pressed"):
		return _err(500, "_on_mode_button_pressed not found on app root")
	_app.call("_on_mode_button_pressed", mode_int)
	log_event("INFO", "mode switched to %d (%s)" % [mode_int, name])
	return _ok({"mode": mode_int, "name": name})


# Friendly-name → mode constant lookup. Mirrors the MODE_* constants in
# interval_birds.gd. Returns -1 for unknown names.
func _mode_int_for_name(name: String) -> int:
	match name.to_lower():
		"interval", "intervals":         return 0
		"chord", "chords":               return 1
		"sight", "sight reading":        return 2
		"read", "rhythm flow":           return 3
		"note chase", "note_chase":      return 4
		"progression", "progressions":   return 5
		"scale", "scale mode", "mode":   return 6
		"cadence", "cadences":           return 7
		_: return -1


func _handle_drill_start(body: Dictionary) -> Dictionary:
	# Practice Drills entry — we drive _on_generate_pressed after seeding
	# the relevant input vars. Falls back to direct generation via
	# TechnicalExerciseGenerator if Practice Drills panel isn't loaded.
	var drill_type: String = str(body.get("type", "scale"))
	var key_pc: int = int(body.get("key_pc", body.get("key", 0)))
	var key_minor: bool = bool(body.get("key_is_minor", body.get("minor", false)))
	var level: int = int(body.get("level", 3))
	var octaves: int = int(body.get("octaves", 1))
	var hand: String = str(body.get("hand", "right"))
	var seed: int = int(body.get("seed", -1))
	var gen_path: String = "res://scripts/exercises/technical_exercise_generator.gd"
	if not ResourceLoader.exists(gen_path):
		return _err(500, "exercise generator script missing")
	var Generator = load(gen_path)
	var ex: Dictionary = Generator.generate(drill_type, key_pc, key_minor, level, hand, octaves, -1, seed)
	if ex.is_empty():
		return _err(400, "generator returned empty (unknown type=%s)" % drill_type)
	# If the Practice Drills panel is open, hand the generated exercise
	# to it so the rest of the UI (chips, contextual hint, score
	# renderer) refreshes. Otherwise just return the generated dict so
	# the orchestrator can inspect it directly.
	var panel = _practice_drills_panel()
	if panel != null and panel.has_method("set"):
		panel.set("_current_exercise", ex)
		if panel.has_method("_refresh_score_renderer"):
			panel.call("_refresh_score_renderer")
		if panel.has_method("_refresh_day_chips"):
			panel.call("_refresh_day_chips")
		log_event("INFO", "drill started: %s (level=%d, hand=%s, seed=%d)" % [drill_type, level, hand, seed])
	return _ok({
		"exercise_id": drill_type,
		"title": str(ex.get("title", "")),
		"note_count": (ex.get("notes", []) as Array).size(),
		"total_beats": float(ex.get("total_beats", 0.0)),
		"seed": int(ex.get("seed", seed)),
	})


func _handle_drill_stop() -> Dictionary:
	var panel = _practice_drills_panel()
	if panel != null and panel.has_method("stop_playback"):
		panel.call("stop_playback", true)
		return _ok({"stopped": true})
	return _err(404, "practice drills panel not active")


func _handle_drill_play() -> Dictionary:
	var panel = _practice_drills_panel()
	if panel != null and panel.has_method("_on_play_pressed"):
		panel.call("_on_play_pressed")
		return _ok({"playing": true})
	return _err(404, "practice drills panel not active")


func _handle_midi_inject(body: Dictionary) -> Dictionary:
	var pitch: int = int(body.get("pitch", -1))
	var velocity: int = int(body.get("velocity", 96))
	var hold_ms: int = int(body.get("hold_ms", 0))
	if pitch < 0 or pitch > 127:
		return _err(400, "pitch out of MIDI range")
	var on_event := InputEventMIDI.new()
	on_event.message = MIDI_MESSAGE_NOTE_ON
	on_event.pitch = pitch
	on_event.velocity = velocity
	Input.parse_input_event(on_event)
	# Headless mode doesn't reliably route InputEventMIDI through
	# Input.parse_input_event to listening _input handlers, so the QA
	# pipeline would never see the capture. Mirror the panel's _input
	# logic directly here when grading is active — the same end state
	# either way (push to _midi_captures), just bypassing the OS input
	# dispatcher that's not wired in headless.
	_midi_inject_direct_to_panel(pitch)
	# Schedule the note-off via a one-shot timer so the dispatcher stays
	# synchronous (no `await`) — coroutines would force every endpoint
	# call site to also await.
	if hold_ms > 0:
		var timer := get_tree().create_timer(float(hold_ms) / 1000.0)
		timer.timeout.connect(func() -> void:
			var off_event := InputEventMIDI.new()
			off_event.message = MIDI_MESSAGE_NOTE_OFF
			off_event.pitch = pitch
			off_event.velocity = 0
			Input.parse_input_event(off_event)
		)
	log_event("INFO", "midi inject pitch=%d vel=%d hold=%dms" % [pitch, velocity, hold_ms])
	return _ok({"pitch": pitch, "velocity": velocity})


func _handle_audio_probe() -> Dictionary:
	var probe_v: Variant = _member("_qa_audio_probe")
	if not (probe_v is Array):
		return _ok({"events": []})
	var events: Array = (probe_v as Array).duplicate()
	# Caller may also want to clear the buffer.
	if _app != null and _app.has_method("_qa_audio_probe_reset"):
		_app.call("_qa_audio_probe_reset")
	return _ok({"events": events})


func _handle_assert(body: Dictionary) -> Dictionary:
	var member: String = str(body.get("member", ""))
	if member.is_empty():
		return _err(400, "member required")
	var op: String = str(body.get("op", "eq"))
	var expected: Variant = body.get("value", null)
	var observed: Variant = _member(member)
	var passed: bool = _compare(observed, op, expected)
	log_event("INFO" if passed else "FAIL", "assert %s %s %s → observed=%s" % [member, op, str(expected), str(observed)])
	return _ok({
		"passed": passed,
		"observed": observed,
		"expected": expected,
		"op": op,
	})


func _handle_screenshot(body: Dictionary) -> Dictionary:
	var tag: String = str(body.get("tag", "shot_%d" % Time.get_ticks_msec()))
	# Skip cleanly in headless mode — there's no rendered viewport image
	# to capture. Return 200 with a `skipped` marker so the orchestrator
	# can keep going (visual checks just become no-ops on CI).
	if DisplayServer.get_name().to_lower() == "headless":
		return _ok({"tag": tag, "skipped": true, "reason": "headless"})
	var viewport := get_viewport()
	if viewport == null:
		return _err(500, "no viewport available")
	var tex := viewport.get_texture()
	if tex == null:
		return _err(500, "viewport texture missing")
	var img := tex.get_image()
	if img == null or img.is_empty():
		# Same fallback: render driver may be loaded but no frame composed
		# yet; treat as a soft skip rather than a hard failure.
		return _ok({"tag": tag, "skipped": true, "reason": "empty viewport image"})
	var dir := "user://debug_screenshots"
	var d := DirAccess.open("user://")
	if d != null and not d.dir_exists("debug_screenshots"):
		d.make_dir("debug_screenshots")
	var path := "%s/%s.png" % [dir, tag]
	var save_err := img.save_png(ProjectSettings.globalize_path(path))
	if save_err != OK:
		return _err(500, "save_png failed (%d)" % save_err)
	return _ok({"tag": tag, "path": ProjectSettings.globalize_path(path)})


# --- State + logging ---


func _snapshot_state() -> Dictionary:
	return {
		"selected_mode":          _member_int("_selected_mode", -1),
		"quiz_active":            _member_bool("_quiz_active", false),
		"is_prompt_playing":      _member_bool("_is_prompt_playing", false),
		"home_flow":              _member_str("_home_flow", ""),
		"question_index":         _member_int("_question_index", 0),
		"total_questions":        _member_int("_total_questions", 0),
		"score":                  _member_int("_score", 0),
		"streak":                 _member_int("_streak", 0),
		"midi_grading_active":    _member_bool("_midi_grading_active", false),
		"midi_captures_count":    _midi_captures_size(),
		"last_play_accuracy":     _member_float("_last_accuracy", -1.0),
		"current_exercise_title": _current_exercise_title(),
		"daily_progress":         _member("_daily_progress"),
		"viewport_size":          [int(get_viewport().get_visible_rect().size.x), int(get_viewport().get_visible_rect().size.y)],
		"unix_ms":                Time.get_ticks_msec(),
	}


func log_event(level: String, text: String) -> void:
	_log_buffer.append({"seq": _next_log_seq, "unix_ms": Time.get_ticks_msec(), "level": level, "text": text})
	_next_log_seq += 1
	if _log_buffer.size() > LOG_CAP:
		_log_buffer.pop_front()


func _logs_since(since_seq: int) -> Array:
	var out: Array = []
	for entry_any in _log_buffer:
		var entry: Dictionary = entry_any
		if int(entry.get("seq", -1)) >= since_seq:
			out.append(entry)
	return out


# --- HTTP helpers ---


func _ok(body: Variant) -> Dictionary:
	return {"status": 200, "body": body}


func _err(code: int, message: String) -> Dictionary:
	return {"status": code, "body": {"error": message}}


func _write_http_response(client: StreamPeerTCP, response: Dictionary) -> void:
	var status: int = int(response.get("status", 200))
	var body_str: String = JSON.stringify(response.get("body", {}))
	var body_bytes: PackedByteArray = body_str.to_utf8_buffer()
	var status_text := _status_text(status)
	var headers := "HTTP/1.1 %d %s\r\n" % [status, status_text] \
		+ "Content-Type: application/json; charset=utf-8\r\n" \
		+ "Content-Length: %d\r\n" % body_bytes.size() \
		+ "Access-Control-Allow-Origin: *\r\n" \
		+ "Connection: close\r\n\r\n"
	var head_bytes := headers.to_utf8_buffer()
	client.put_data(head_bytes)
	client.put_data(body_bytes)


func _status_text(code: int) -> String:
	match code:
		200: return "OK"
		400: return "Bad Request"
		404: return "Not Found"
		405: return "Method Not Allowed"
		500: return "Internal Server Error"
		_:   return "OK"


# --- App accessors (mirror qa_bot.gd patterns) ---


func _member(name: String) -> Variant:
	if _app == null:
		return null
	# Support dotted paths so the orchestrator can reach panel state via
	# e.g. "_practice_drills_panel._midi_grading_active". Each segment is
	# a .get() on the result of the previous segment.
	if name.find(".") >= 0:
		var parts := name.split(".", false)
		var obj: Variant = _app
		for part in parts:
			if obj == null:
				return null
			obj = obj.get(part)
		return obj
	return _app.get(name)


func _member_int(name: String, default_val: int) -> int:
	var v: Variant = _member(name)
	return int(v) if v != null else default_val


func _member_bool(name: String, default_val: bool) -> bool:
	var v: Variant = _member(name)
	return bool(v) if v != null else default_val


func _member_str(name: String, default_val: String) -> String:
	var v: Variant = _member(name)
	return str(v) if v != null else default_val


func _member_float(name: String, default_val: float) -> float:
	var v: Variant = _member(name)
	return float(v) if v != null else default_val


func _compare(observed: Variant, op: String, expected: Variant) -> bool:
	match op:
		"eq":   return observed == expected
		"ne":   return observed != expected
		"gt":   return float(observed) > float(expected)
		"gte":  return float(observed) >= float(expected)
		"lt":   return float(observed) < float(expected)
		"lte":  return float(observed) <= float(expected)
		"in":
			if expected is Array:
				return (expected as Array).has(observed)
			return false
		_:      return observed == expected


func _practice_drills_panel() -> Node:
	if _app == null:
		return null
	return _app.get("_practice_drills_panel") as Node


# Headless-mode MIDI capture shim. Replays exactly the logic in the
# panel's _input(): if grading is active, compute the elapsed beat from
# _last_play_start_usec and append to _midi_captures. Skipped when
# grading is off or the panel is unavailable.
func _midi_inject_direct_to_panel(pitch: int) -> void:
	var panel = _practice_drills_panel()
	if panel == null:
		return
	if not bool(panel.get("_midi_grading_active")):
		return
	var captures_v: Variant = panel.get("_midi_captures")
	if not (captures_v is Array):
		return
	var captures: Array = captures_v as Array
	var current_ex_v: Variant = panel.get("_current_exercise")
	var bpm: float = 80.0
	if current_ex_v is Dictionary:
		bpm = float((current_ex_v as Dictionary).get("tempo_bpm", 80))
	var seconds_per_beat: float = 60.0 / maxf(40.0, bpm)
	var now_usec: int = Time.get_ticks_usec()
	var play_start_v: Variant = panel.get("_last_play_start_usec")
	var play_start: int = int(play_start_v) if play_start_v != null else now_usec
	var elapsed_sec: float = float(now_usec - play_start) / 1_000_000.0
	var beat: float = elapsed_sec / seconds_per_beat
	captures.append({
		"usec": now_usec,
		"midi": int(pitch),
		"beat": beat,
	})


func _midi_captures_size() -> int:
	var panel = _practice_drills_panel()
	if panel == null:
		return 0
	var caps_v: Variant = panel.get("_midi_captures")
	return (caps_v as Array).size() if caps_v is Array else 0


func _current_exercise_title() -> String:
	var panel = _practice_drills_panel()
	if panel == null:
		return ""
	var ex_v: Variant = panel.get("_current_exercise")
	if not (ex_v is Dictionary):
		return ""
	return str((ex_v as Dictionary).get("title", ""))


func _build_string() -> String:
	# Best-effort build descriptor. Project name + Godot version.
	return "Clefira/%s on Godot %s" % [
		str(ProjectSettings.get_setting("application/config/name", "unknown")),
		Engine.get_version_info().get("string", ""),
	]


func _graceful_quit() -> void:
	stop()
	get_tree().quit(0)
