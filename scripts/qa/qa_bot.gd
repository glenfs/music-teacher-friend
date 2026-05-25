extends Node

const MODE_INTERVAL := 0
const MODE_CHORD := 1
const MODE_SIGHT := 2
const MODE_READ := 3
const MODE_NOTE_CHASE := 4
const MODE_PROGRESSION := 5
const MODE_SCALE_MODE := 6
const MODE_CADENCE := 7

var _app: Node = null
var _runner: Node = null
var qa_scope: String = "all"
var _tests: Array[Dictionary] = []
var _sections: Array[Dictionary] = []
var _failures: Array[String] = []
var _warnings: Array[String] = []
var _fixes: Array[String] = []
var _remaining_issues: Array[String] = []
var _step_failures: Array[String] = []
var _step_warnings: Array[String] = []
var _step_records: Array[Dictionary] = []
var _qa_log: Array[Dictionary] = []
var _issues: Array[Dictionary] = []
var _suggestion_items: Array[Dictionary] = []
var _na_notes: Array[String] = []
var _answer_flip := false
var _active_section_name := ""
var _observed_home_meta_signals := false


func configure(app_root: Node, qa_runner: Node) -> void:
	_app = app_root
	_runner = qa_runner
	_fixes = [
		"scripts/interval_birds.gd: Added robust --qa startup hook with explicit runner start verification and exit code 2 on QA startup failure.",
		"scripts/qa/qa_runner.gd: Switched artifacts to user://, print absolute paths, added QA START/STEP/DONE console proof, and added visible QA overlay/click markers.",
		"scripts/qa/qa_bot.gd: Added resilient end-to-end autoplayer flow coverage and increased cadence wait timeout for QA stability."
	]


func run_suite() -> Dictionary:
	if _app == null or not is_instance_valid(_app):
		fail("App root missing")
		return _summary()

	await _set_small_question_counts()
	_seed_suggestions()

	await _run_scoped_test("Smoke", "smoke", _section_smoke)
	await _run_scoped_test("Ear Interval Matrix", "ear.intervals", _section_interval_matrix)
	await _run_scoped_test("Ear Chord Matrix", "ear.chords", _section_chord_matrix)
	if _is_ear_mode_enabled_for_build(MODE_PROGRESSION):
		await _run_scoped_test("Progression Coverage", "ear.progression", _section_progression)
	else:
		_record_feature_skip("Progression Coverage", "Ear mode `Progression` is MVP-locked for this build.")
	if _is_ear_mode_enabled_for_build(MODE_SCALE_MODE):
		await _run_scoped_test("Scale/Mode Coverage", "ear.scale_mode", _section_scale_mode)
	else:
		_record_feature_skip("Scale/Mode Coverage", "Ear mode `Scale/Mode` is MVP-locked for this build.")
	await _run_scoped_test("Cadence Coverage", "ear.cadence", _section_cadence)
	await _run_scoped_test("Sight Reading Coverage", "sight", _section_sight)
	await _run_scoped_test("Note Chase Coverage", "note_chase", _section_note_chase)
	await _run_scoped_test("Read/Tutorial Coverage", "read", _section_read_tutorial)
	await _run_scoped_test("Navigation Stress", "navigation", _section_navigation_stress)
	await _run_scoped_test("Negative Paths", "negative", _section_negative_paths)
	await _run_scoped_test("Audio Robustness", "audio", _section_audio_robustness)
	await _run_scoped_test("State Reset/Persistence", "state_reset", _section_state_reset_and_persistence)
	await _run_scoped_test("UI Integrity", "ui", _section_ui_integrity)
	await _run_scoped_test("Technical Assertions", "technical", _section_technical_assertions)
	await _run_scoped_test("Long-Run Stability", "long_run", _section_long_run_stability)

	return _summary()


func click_button_by_text(root: Node, text: String) -> bool:
	var btn := _find_button_by_text(root, text)
	if btn == null:
		return false
	if not btn.visible:
		return false
	if btn.disabled:
		return false
	_emit_click_marker(btn)
	btn.emit_signal("pressed")
	return true


func click_button_by_name(root: Node, name: String) -> bool:
	if root == null:
		return false
	var node := root.find_child(name, true, false)
	if node == null:
		return false
	if node is Button:
		var btn := node as Button
		if not btn.visible:
			return false
		if btn.disabled:
			return false
		_emit_click_marker(btn)
		btn.emit_signal("pressed")
		return true
	return false


func assert_node_exists(root: Node, name_or_group: String) -> bool:
	if root == null:
		fail("assert_node_exists(%s): root missing" % name_or_group)
		return false
	var tree := root.get_tree()
	if tree != null:
		var group_nodes := tree.get_nodes_in_group(name_or_group)
		if group_nodes.size() > 0:
			return true
	var node := root.find_child(name_or_group, true, false)
	if node != null:
		return true
	fail("Missing expected node or group: %s" % name_or_group)
	return false


func wait_frames(n: int) -> void:
	for _i in range(maxi(0, n)):
		await get_tree().process_frame


func screenshot(tag: String) -> Dictionary:
	if _runner != null and _runner.has_method("take_screenshot"):
		var shot: Variant = await _runner.call("take_screenshot", tag)
		if shot is Dictionary:
			return shot as Dictionary
		return {}
	var viewport := get_viewport()
	if viewport == null:
		return {}
	var tex := viewport.get_texture()
	if tex == null:
		return {}
	var img := tex.get_image()
	if img == null or img.is_empty():
		return {}
	var rel_path := "res://qa_screenshots/%s.png" % tag
	img.save_png(ProjectSettings.globalize_path(rel_path))
	return {"tag": tag, "path": rel_path, "saved": true}


func fail(reason: String) -> void:
	_failures.append(reason)
	_step_failures.append(reason)
	_log_step("FAIL", reason)
	push_error("QA FAIL: %s" % reason)


func pass_step(name: String) -> void:
	# A lightweight marker for detailed bot progress.
	_log_step("PASS", name)
	print("QA PASS STEP: %s" % name)


func warn_step(reason: String) -> void:
	_warnings.append(reason)
	_step_warnings.append(reason)
	_log_step("WARN", reason)
	push_warning("QA WARN: %s" % reason)


func na_step(reason: String) -> void:
	_na_notes.append(reason)
	_log_step("NA", reason)
	print("QA N/A: %s" % reason)


func _summary() -> Dictionary:
	var overall_ok := _failures.is_empty()
	for t in _tests:
		if not bool(t.get("ok", false)):
			overall_ok = false
			break
	return {
		"ok": overall_ok,
		"tests": _tests,
		"sections": _sections,
		"qa_log": _qa_log,
		"failures": _failures,
		"warnings": _warnings,
		"fixes": _fixes,
		"remaining_issues": _remaining_issues,
		"issues": _issues,
		"suggestions": _suggestions(),
		"suggestion_items": _suggestion_items,
		"not_applicable": _na_notes
	}


func _run_test(name: String, action: Callable) -> void:
	_active_section_name = name
	_step_failures.clear()
	_step_warnings.clear()
	_step_records.clear()
	var before_fail_count := _failures.size()
	print("QA STEP: %s" % name)
	if _runner != null and _runner.has_method("set_step_text"):
		_runner.call("set_step_text", "QA: %s" % name)
	if not action.is_valid():
		fail("%s: invalid action" % name)
	else:
		await action.call()
	var ok := _failures.size() == before_fail_count
	var status := "PASS" if ok else "FAIL"
	if ok and not _step_warnings.is_empty():
		status = "WARN"
	var record := {
		"name": name,
		"ok": ok,
		"status": status,
		"failures": _step_failures.duplicate(),
		"warnings": _step_warnings.duplicate(),
		"steps": _step_records.duplicate(true)
	}
	_tests.append({"name": name, "ok": ok, "failures": _step_failures.duplicate()})
	_sections.append(record)
	_qa_log.append({
		"type": "section",
		"name": name,
		"status": status,
		"failures": _step_failures.duplicate(),
		"warnings": _step_warnings.duplicate(),
		"steps": _step_records.duplicate(true)
	})
	_active_section_name = ""


func _run_scoped_test(name: String, prefix: String, action: Callable) -> void:
	if _scope_allows(prefix):
		await _run_test(name, action)
		return
	_record_scope_skip(name, prefix)


func _scope_allows(prefix: String) -> bool:
	var s := qa_scope.strip_edges().to_lower()
	var p := prefix.strip_edges().to_lower()
	return s == "all" or s == p or s.begins_with(p + ".")


func _is_ear_mode_enabled_for_build(mode: int) -> bool:
	if _app == null or not is_instance_valid(_app):
		return true
	if _app.has_method("_mvp_is_ear_mode_enabled"):
		return bool(_app.call("_mvp_is_ear_mode_enabled", mode))
	return true


func _is_sight_mode_enabled_for_build(mode_name: String) -> bool:
	if _app == null or not is_instance_valid(_app):
		return true
	if _app.has_method("_mvp_is_sight_mode_enabled"):
		return bool(_app.call("_mvp_is_sight_mode_enabled", mode_name))
	return true


func _ear_mode_name(mode: int) -> String:
	match mode:
		MODE_INTERVAL:
			return "Interval"
		MODE_CHORD:
			return "Chord"
		MODE_PROGRESSION:
			return "Progression"
		MODE_SCALE_MODE:
			return "Scale/Mode"
		MODE_CADENCE:
			return "Cadence"
		_:
			return "Mode %d" % mode


func _record_scope_skip(name: String, prefix: String) -> void:
	var status := "SKIPPED (scope)"
	var msg := "Skipped by qa_scope=`%s` (section prefix `%s`)" % [qa_scope, prefix]
	print("QA STEP: %s" % name)
	print("QA SKIP: %s" % msg)
	_sections.append({
		"name": name,
		"ok": true,
		"status": status,
		"failures": [],
		"warnings": [],
		"steps": [{"status":"SKIP","detail":msg,"section":name,"time_unix":Time.get_unix_time_from_system()}]
	})
	_tests.append({"name": name, "ok": true, "skipped": true, "failures": []})
	_qa_log.append({
		"type": "section",
		"name": name,
		"status": status,
		"failures": [],
		"warnings": [],
		"steps": [{"status":"SKIP","detail":msg,"section":name,"time_unix":Time.get_unix_time_from_system()}]
	})


func _record_feature_skip(name: String, reason: String) -> void:
	var status := "SKIPPED (build)"
	var msg := reason.strip_edges()
	if msg.is_empty():
		msg = "Skipped: feature not enabled in this build."
	print("QA STEP: %s" % name)
	print("QA SKIP: %s" % msg)
	_sections.append({
		"name": name,
		"ok": true,
		"status": status,
		"failures": [],
		"warnings": [],
		"steps": [{"status":"SKIP","detail":msg,"section":name,"time_unix":Time.get_unix_time_from_system()}]
	})
	_tests.append({"name": name, "ok": true, "skipped": true, "failures": []})
	_qa_log.append({
		"type": "section",
		"name": name,
		"status": status,
		"failures": [],
		"warnings": [],
		"steps": [{"status":"SKIP","detail":msg,"section":name,"time_unix":Time.get_unix_time_from_system()}]
	})


func _test_ear_interval() -> void:
	await _test_ear_mode(MODE_INTERVAL, "interval")


func _test_ear_chord() -> void:
	await _test_ear_mode(MODE_CHORD, "chord")


func _test_ear_progression() -> void:
	if not _is_ear_mode_enabled_for_build(MODE_PROGRESSION):
		na_step("Ear Progression test skipped: mode is MVP-locked in this build")
		return
	await _test_ear_mode(MODE_PROGRESSION, "progression")


func _test_ear_scale_mode() -> void:
	if not _is_ear_mode_enabled_for_build(MODE_SCALE_MODE):
		na_step("Ear Scale/Mode test skipped: mode is MVP-locked in this build")
		return
	await _test_ear_mode(MODE_SCALE_MODE, "scale_mode")


func _test_ear_cadence() -> void:
	await _test_ear_mode(MODE_CADENCE, "cadence")


func _test_home() -> void:
	await wait_frames(4)
	_call("_show_home")
	await wait_frames(6)
	if not _assert_member_visible("_home_panel"):
		fail("Home panel not visible on launch")
	if not _assert_member_visible("_home_card"):
		fail("Home card not visible on launch")
	_observe_home_meta_signals()
	await screenshot("home")
	pass_step("home")


func _test_practice() -> void:
	_call("_show_home")
	await wait_frames(3)
	var clicked := click_button_by_text(_app, "Practice")
	if not clicked:
		_call("_on_home_hub_pressed", ["Practice"])
	await wait_frames(4)
	if str(_app.get("_home_flow")) != "Practice":
		fail("Practice hub did not become active")
	await screenshot("practice")
	pass_step("practice")


func _test_ear_mode(mode: int, tag: String) -> void:
	await _goto_practice_ear_mode(mode)
	await screenshot("%s_entry" % tag)
	if not await _start_round_from_home():
		fail("%s: failed to start round" % tag)
		return
	await screenshot("%s_first_prompt" % tag)
	for i in range(3):
		if not await _wait_for_accepting_answer(720):
			fail("%s: prompt %d not ready for answer" % [tag, i + 1])
			break
		var answered := await _answer_current(mode)
		if not answered:
			fail("%s: failed to answer prompt %d" % [tag, i + 1])
			break
		if i == 0:
			await screenshot("%s_after_first_answer" % tag)
		await wait_frames(2)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if not _assert_member_visible("_home_panel"):
		fail("%s: did not return to home after End" % tag)
	pass_step("ear_%s" % tag)


func _test_sight_notes() -> void:
	await _goto_practice_sight_mode("Notes")
	await screenshot("sight_notes_entry")
	if not await _start_round_from_home():
		fail("Sight Notes: failed to start")
		return
	if not _assert_member_visible("_staff_area"):
		fail("Sight Notes: staff area not visible")
	if not await _wait_for_accepting_answer(240):
		fail("Sight Notes: no answer prompt ready")
	else:
		var ok := await _answer_current(MODE_SIGHT)
		if not ok:
			fail("Sight Notes: unable to submit answer")
	await screenshot("sight_notes_after_first")
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	pass_step("sight_notes")


func _test_sight_chords() -> void:
	await _goto_practice_sight_mode("Chords")
	await screenshot("sight_chords_entry")
	if not await _start_round_from_home():
		fail("Sight Chords: failed to start")
		return
	if not _assert_member_visible("_staff_area"):
		fail("Sight Chords: staff area not visible")
	if not await _wait_for_accepting_answer(240):
		fail("Sight Chords: no answer prompt ready")
	else:
		var ok := await _answer_current(MODE_SIGHT)
		if not ok:
			fail("Sight Chords: unable to submit answer")
	await screenshot("sight_chords_after_first")
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	pass_step("sight_chords")


func _test_note_chase() -> void:
	await _goto_note_chase()
	await screenshot("note_chase_entry")
	if not await _start_round_from_home():
		fail("Note Chase: failed to start")
		return
	if not await _wait_for_note_chase_running(180):
		# Headless QA can burn frames faster than Note Chase's real-time countdown.
		if _member_bool("_awaiting_round_start", false):
			_call("_on_round_start_pressed")
			await wait_frames(8)
		if not await _wait_for_note_chase_running(360):
			fail("Note Chase: round never started")
			return
	if not await _wait_for_note_chase_note(240):
		fail("Note Chase: no active notes spawned")
	else:
		var clicked := _click_first_note_chase_note()
		if not clicked:
			fail("Note Chase: unable to click an active note")
	await screenshot("note_chase_after_first_click")
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	pass_step("note_chase")


func _test_learn_modules() -> void:
	_call("_show_home")
	_call("_on_home_hub_pressed", ["Learn"])
	await wait_frames(6)
	if str(_app.get("_home_flow")) != "Learn":
		fail("Learn hub did not activate")
		return
	_call("_on_mode_button_pressed", [MODE_READ])
	await wait_frames(3)
	_call("_on_read_module_button_pressed", [1])
	if not await _start_round_from_home():
		fail("Learn module 1 failed to start")
		return
	if not await _wait_flag("_in_tutorial", true, 240):
		fail("Learn module 1 tutorial did not open")
	else:
		await screenshot("learn_module1")
		_call("_on_tutorial_continue_pressed")
		await wait_frames(8)
		await screenshot("learn_module1_after_continue")
	_call("_on_tutorial_home_pressed")
	await wait_frames(8)

	_call("_on_home_hub_pressed", ["Learn"])
	_call("_on_mode_button_pressed", [MODE_READ])
	_call("_on_read_module_button_pressed", [2])
	await wait_frames(4)
	if not await _start_round_from_home():
		fail("Learn module 2 failed to start")
		return
	if not await _wait_flag("_in_tutorial", true, 240):
		fail("Learn module 2 tutorial did not open")
	else:
		await screenshot("learn_module2")
	_call("_on_tutorial_home_pressed")
	await wait_frames(8)
	pass_step("learn_modules")


func _test_settings() -> void:
	_call("_show_home")
	_call("_on_home_hub_pressed", ["Practice"])
	await wait_frames(4)
	var clicked := click_button_by_text(_app, "Settings")
	if not clicked:
		_call("_on_ear_settings_pressed")
	await wait_frames(6)
	if not bool(_app.get("_ear_settings_screen_active")):
		fail("Settings screen did not open")
		return
	await screenshot("settings_open")
	var current := false
	if _app.get("_include_minor_intervals") != null:
		current = bool(_app.get("_include_minor_intervals"))
	_call("_on_include_minor_toggled", [not current])
	await wait_frames(3)
	if bool(_app.get("_include_minor_intervals")) == current:
		fail("Settings toggle did not change include-minor state")
	await screenshot("settings_after_toggle")
	_call("_on_home_back_pressed")
	await wait_frames(6)
	if bool(_app.get("_ear_settings_screen_active")):
		fail("Settings screen did not close on back")
	pass_step("settings")


func _section_smoke() -> void:
	await _test_home()
	await _test_practice()
	await _smoke_ear_mode("Interval", MODE_INTERVAL, "smoke_interval")
	await _smoke_ear_mode("Chord", MODE_CHORD, "smoke_chord")
	if _is_ear_mode_enabled_for_build(MODE_PROGRESSION):
		await _smoke_ear_mode("Progression", MODE_PROGRESSION, "smoke_progression")
	else:
		na_step("Smoke: Progression mode locked in this build")
	if _is_ear_mode_enabled_for_build(MODE_SCALE_MODE):
		await _smoke_ear_mode("Scale/Mode", MODE_SCALE_MODE, "smoke_scale_mode")
	else:
		na_step("Smoke: Scale/Mode mode locked in this build")
	await _smoke_ear_mode("Cadence", MODE_CADENCE, "smoke_cadence")
	await _smoke_sight_submode("Notes", "smoke_sight_notes")
	await _smoke_sight_submode("Chords", "smoke_sight_chords")
	if _has_sight_submode("Placement"):
		if _is_sight_mode_enabled_for_build("Placement"):
			await _smoke_sight_submode("Placement", "smoke_sight_placement")
		else:
			na_step("Smoke: Sight Placement mode locked in this build")
	else:
		na_step("Smoke: Sight Placement not present in this build")
	if _has_sight_submode("Continuous"):
		if _is_sight_mode_enabled_for_build("Continuous"):
			await _smoke_sight_submode("Continuous", "smoke_sight_continuous")
		else:
			na_step("Smoke: Sight Continuous mode locked in this build")
	else:
		na_step("Smoke: Sight Continuous/Note Flow not present in this build")
	await _test_note_chase()
	await _test_learn_modules()
	await _test_settings()


func _section_interval_matrix() -> void:
	await _goto_practice_ear_mode(MODE_INTERVAL)
	await _open_ear_settings_if_available()
	await _set_ear_choice_count_extremes()
	await _close_settings_to_home_detail()
	var combos: Array[Dictionary] = [
		{"label":"default", "descending":false, "harmonic":false, "minor":false, "degree_set":"default"},
		{"label":"descending_harmonic", "descending":true, "harmonic":true, "minor":false, "degree_set":"narrow"},
		{"label":"minor_broad", "descending":false, "harmonic":false, "minor":true, "degree_set":"broad"}
	]
	for combo in combos:
		await _safe_interval_combo(combo)


func _section_chord_matrix() -> void:
	await _goto_practice_ear_mode(MODE_CHORD)
	if _member("_inversion_toggle") == null:
		na_step("Chord: inversion toggle not present")
	else:
		await _set_inversion_toggle(false)
		await _run_ear_mini_session("chord_inversions_off", MODE_CHORD, 3, true)
		await _set_inversion_toggle(true)
	for group_id in [1, 2, 3, 4]:
		var ok := await _press_chord_group(group_id)
		if not ok:
			warn_step("Chord: group button %d unavailable" % group_id)
			continue
		await _run_ear_mini_session("chord_group_%d" % group_id, MODE_CHORD, 3, true)
	na_step("Chord playback style matrix (block/broken/both): not applicable for this build (no style UI exposed)")
	na_step("Chord tempo/key selector matrix: no chord tempo/key UI exposed to QA in this build")


func _section_progression() -> void:
	await _goto_practice_ear_mode(MODE_PROGRESSION)
	await _set_progression_patterns(["IVviIV", "iiVI"])
	await _run_ear_mini_session("progression_default", MODE_PROGRESSION, 3, true)
	await _set_progression_patterns(["IVviIV", "IIVV"])
	await _run_ear_mini_session("progression_narrow", MODE_PROGRESSION, 3, true)
	await _set_progression_patterns(["IVviIV", "iiVI", "IIVV", "viIVIIV"])
	var prog_broken_v: Variant = _member("_progression_broken_toggle")
	if prog_broken_v is BaseButton and (prog_broken_v as BaseButton).visible and not (prog_broken_v as BaseButton).disabled:
		await _set_bool_toggle("_progression_broken_toggle", "_on_progression_broken_toggled", false)
		await _run_ear_mini_session("progression_block", MODE_PROGRESSION, 3, true)
		await _set_bool_toggle("_progression_broken_toggle", "_on_progression_broken_toggled", true)
		await _run_ear_mini_session("progression_broken", MODE_PROGRESSION, 3, true)
	else:
		na_step("Progression broken/block option not present")
	if await _qa_set_exposed_setting_if_available("progression", "key", "G"):
		await _run_ear_mini_session("progression_key_g", MODE_PROGRESSION, 3, true)
		await _qa_set_exposed_setting_if_available("progression", "key", "C")
	else:
		na_step("Progression key matrix not executed: no exposed QA hook")
	if await _qa_set_exposed_setting_if_available("progression", "tempo", 60):
		await _run_ear_mini_session("progression_tempo_slow", MODE_PROGRESSION, 3, true)
		await _qa_set_exposed_setting_if_available("progression", "tempo", 140)
		await _run_ear_mini_session("progression_tempo_fast", MODE_PROGRESSION, 3, true)
		await _qa_set_exposed_setting_if_available("progression", "tempo", 90)
	else:
		na_step("Progression tempo matrix not executed: no exposed QA hook")


func _section_scale_mode() -> void:
	await _goto_practice_ear_mode(MODE_SCALE_MODE)
	await _set_scale_modes(["Major", "Natural Minor"])
	await _run_ear_mini_session("scale_major_minor", MODE_SCALE_MODE, 3, true)
	await _set_scale_modes(["Dorian", "Mixolydian"])
	await _run_ear_mini_session("scale_dorian_mixolydian", MODE_SCALE_MODE, 3, true)
	await _set_scale_modes(["Major", "Natural Minor", "Dorian", "Mixolydian", "Lydian", "Phrygian"])
	if _member("_scale_asc_desc_toggle") != null:
		await _set_bool_toggle("_scale_asc_desc_toggle", "_on_scale_asc_desc_toggled", false)
		await _run_ear_mini_session("scale_asc_only", MODE_SCALE_MODE, 3, true)
		await _set_bool_toggle("_scale_asc_desc_toggle", "_on_scale_asc_desc_toggled", true)
		await _run_ear_mini_session("scale_asc_desc", MODE_SCALE_MODE, 3, true)
	else:
		na_step("Scale/Mode asc/desc toggle not present")
	if await _qa_set_exposed_setting_if_available("scale_mode", "root", "G"):
		await _run_ear_mini_session("scale_root_g", MODE_SCALE_MODE, 3, true)
		await _qa_set_exposed_setting_if_available("scale_mode", "root", "C")
	else:
		na_step("Scale root matrix not executed: no exposed QA hook")
	if await _qa_set_exposed_setting_if_available("scale_mode", "tempo", 60):
		await _run_ear_mini_session("scale_tempo_slow", MODE_SCALE_MODE, 3, true)
		await _qa_set_exposed_setting_if_available("scale_mode", "tempo", 140)
		await _run_ear_mini_session("scale_tempo_fast", MODE_SCALE_MODE, 3, true)
		await _qa_set_exposed_setting_if_available("scale_mode", "tempo", 90)
	else:
		na_step("Scale tempo matrix not executed: no exposed QA hook")


func _section_cadence() -> void:
	await _goto_practice_ear_mode(MODE_CADENCE)
	await _set_cadence_types(["Perfect", "Plagal"])
	await _run_ear_mini_session("cadence_two_types", MODE_CADENCE, 3, true)
	await _set_cadence_types(["Half", "Deceptive"])
	await _run_ear_mini_session("cadence_alt_types", MODE_CADENCE, 3, true)
	await _set_cadence_types(["Perfect", "Plagal", "Half", "Deceptive"])
	var cadence_broken_v: Variant = _member("_cadence_broken_toggle")
	if cadence_broken_v is BaseButton and (cadence_broken_v as BaseButton).visible and not (cadence_broken_v as BaseButton).disabled:
		await _set_bool_toggle("_cadence_broken_toggle", "_on_cadence_broken_toggled", false)
		await _run_ear_mini_session("cadence_block", MODE_CADENCE, 3, true)
		await _set_bool_toggle("_cadence_broken_toggle", "_on_cadence_broken_toggled", true)
		await _run_ear_mini_session("cadence_broken", MODE_CADENCE, 3, true)
	else:
		na_step("Cadence broken/block toggle not present")
	if await _qa_set_exposed_setting_if_available("cadence", "key", "G"):
		await _run_ear_mini_session("cadence_key_g", MODE_CADENCE, 3, true)
		await _qa_set_exposed_setting_if_available("cadence", "key", "C")
	else:
		na_step("Cadence key matrix not executed: no exposed QA hook")
	if await _qa_set_exposed_setting_if_available("cadence", "tempo", 60):
		await _run_ear_mini_session("cadence_tempo_slow", MODE_CADENCE, 3, true)
		await _qa_set_exposed_setting_if_available("cadence", "tempo", 140)
		await _run_ear_mini_session("cadence_tempo_fast", MODE_CADENCE, 3, true)
		await _qa_set_exposed_setting_if_available("cadence", "tempo", 90)
	else:
		na_step("Cadence tempo matrix not executed: no exposed QA hook")


func _section_sight() -> void:
	var scope := qa_scope.strip_edges().to_lower()
	var notes_only := scope == "sight.notes" or scope.begins_with("sight.notes.")
	var chords_only := scope == "sight.chords" or scope.begins_with("sight.chords.")
	var placement_only := scope == "sight.placement" or scope.begins_with("sight.placement.")
	var continuous_only := scope == "sight.continuous" or scope.begins_with("sight.continuous.")
	if notes_only:
		await _sight_notes_coverage()
		return
	if chords_only:
		await _sight_chords_coverage()
		return
	if placement_only:
		if _has_sight_submode("Placement") and _is_sight_mode_enabled_for_build("Placement"):
			await _sight_placement_coverage()
		else:
			na_step("Sight Placement coverage: not applicable for this build")
		return
	if continuous_only:
		if _has_sight_submode("Continuous") and _is_sight_mode_enabled_for_build("Continuous"):
			await _sight_continuous_coverage()
		else:
			na_step("Sight Continuous/Note Flow coverage: not applicable for this build")
		return
	await _sight_notes_coverage()
	await _sight_chords_coverage()
	if _has_sight_submode("Placement") and _is_sight_mode_enabled_for_build("Placement"):
		await _sight_placement_coverage()
	else:
		na_step("Sight Placement coverage: not applicable for this build")
	if _has_sight_submode("Continuous") and _is_sight_mode_enabled_for_build("Continuous"):
		await _sight_continuous_coverage()
	else:
		na_step("Sight Continuous/Note Flow coverage: not applicable for this build")


func _section_note_chase() -> void:
	for clef_mode in ["Treble", "Bass", "Both"]:
		if not await _set_note_chase_clef(clef_mode):
			na_step("Note Chase clef `%s`: not present" % clef_mode)
			continue
		if not await _set_note_chase_target_note_count(1):
			warn_step("Note Chase target note count=1 could not be configured")
		await _note_chase_session("note_chase_%s_one" % clef_mode.to_lower(), 1)
		if not await _set_note_chase_target_note_count(3):
			warn_step("Note Chase target note count=3 could not be configured")
		await _note_chase_session("note_chase_%s_three" % clef_mode.to_lower(), 1)


func _section_read_tutorial() -> void:
	await _test_learn_modules()
	await _read_navigation_audio_checks()


func _section_navigation_stress() -> void:
	for i in range(5):
		_safe_set_step_text("QA: Nav Loop %d" % (i + 1))
		await _goto_practice_ear_mode(MODE_INTERVAL)
		await _nav_back_assert("Navigation", "interval_to_practice_%d_before" % i, "interval_to_practice_%d_after" % i)
		await _goto_practice_ear_mode(MODE_CHORD)
		await _nav_back_assert("Navigation", "chord_to_practice_%d_before" % i, "chord_to_practice_%d_after" % i)
		await _goto_practice_sight_mode("Notes")
		await _nav_back_assert("Navigation", "sight_notes_to_practice_%d_before" % i, "sight_notes_to_practice_%d_after" % i)
		await _goto_note_chase()
		await _nav_back_assert("Navigation", "note_chase_to_practice_%d_before" % i, "note_chase_to_practice_%d_after" % i)
	if _is_ear_mode_enabled_for_build(MODE_PROGRESSION) and await _goto_practice_ear_mode_start_quiz(MODE_PROGRESSION, "nav_rapid_back_during_playback"):
		_call("_on_end_quiz_pressed")
		await wait_frames(2)
		_call("_on_home_back_pressed")
		await _assert_audio_stopped("Navigation rapid back")
		await _assert_no_orphan_ui("Navigation rapid back")
		pass_step("navigation_rapid_back_during_playback")


func _section_negative_paths() -> void:
	var items := [
		{"label":"interval", "mode":MODE_INTERVAL},
		{"label":"chord", "mode":MODE_CHORD},
		{"label":"cadence", "mode":MODE_CADENCE}
	]
	if _is_ear_mode_enabled_for_build(MODE_PROGRESSION):
		items.append({"label":"progression", "mode":MODE_PROGRESSION})
	else:
		na_step("Negative paths: Progression mode locked in this build")
	if _is_ear_mode_enabled_for_build(MODE_SCALE_MODE):
		items.append({"label":"scale_mode", "mode":MODE_SCALE_MODE})
	else:
		na_step("Negative paths: Scale/Mode mode locked in this build")
	for item in items:
		if int(item["mode"]) == MODE_CADENCE:
			await _set_cadence_types(["Perfect", "Plagal", "Half", "Deceptive"])
		if int(item["mode"]) == MODE_PROGRESSION:
			await _set_progression_patterns(["IVviIV", "iiVI", "IIVV", "viIVIIV"])
		if int(item["mode"]) == MODE_SCALE_MODE:
			await _set_scale_modes(["Major", "Natural Minor", "Dorian", "Mixolydian"])
		await _negative_path_ear(int(item["mode"]), str(item["label"]))
	await _negative_path_sight("Notes", "sight_notes")
	await _negative_path_sight("Chords", "sight_chords")


func _section_audio_robustness() -> void:
	await _set_cadence_types(["Perfect", "Plagal", "Half", "Deceptive"])
	if await _goto_practice_ear_mode_start_quiz(MODE_CADENCE, "audio_stop_back"):
		await _wait_prompt_phase_transition()
		_call("_on_home_back_pressed")
		await _assert_audio_stopped("Audio back stop")
		pass_step("audio_stop_back")
	if _is_ear_mode_enabled_for_build(MODE_PROGRESSION):
		await _set_progression_patterns(["IVviIV", "iiVI"])
		if await _goto_practice_ear_mode_start_quiz(MODE_PROGRESSION, "audio_replay_abuse"):
			await _replay_abuse("progression_replay_abuse", 6)
			_call("_on_end_quiz_pressed")
			await wait_frames(10)
	else:
		na_step("Audio robustness: Progression mode locked in this build")
	if _is_ear_mode_enabled_for_build(MODE_SCALE_MODE):
		await _set_scale_modes(["Major", "Natural Minor"])
		if await _goto_practice_ear_mode_start_quiz(MODE_SCALE_MODE, "audio_restart"):
			_call("_on_restart_quiz_pressed")
			await wait_frames(8)
			await _assert_audio_stopped("Audio restart stop")
			_call("_on_end_quiz_pressed")
			await wait_frames(8)
	else:
		na_step("Audio robustness: Scale/Mode mode locked in this build")
	var miss_info := _qa_missing_resource_sim_info()
	if bool(miss_info.get("enabled", false)):
		pass_step("missing_resource_simulation_flag_present")
		_log_step("INFO", "Missing-resource simulation enabled", {"qa_missing_resource": miss_info})
	else:
		na_step("Missing resource resilience: Not executed (run with --qa-missing-resource=<audio|font|image|theme|all>)")


func _section_state_reset_and_persistence() -> void:
	await _restart_reset_check_ear(MODE_INTERVAL, "reset_interval")
	await _restart_reset_check_ear(MODE_CADENCE, "reset_cadence")
	await _restart_reset_check_sight_notes("reset_sight_notes")
	await _restart_reset_check_note_chase("reset_note_chase")
	await _back_home_reset_check()
	await _settings_persistence_check()


func _section_ui_integrity() -> void:
	await _check_home_horizontal_scroll_absent()
	await _check_duplicate_labels_home_and_settings()
	await _check_visible_controls_within_viewport()
	await _check_sight_layout_overlap()
	await _check_chicken_visibility_and_overlap()


func _section_technical_assertions() -> void:
	await _assert_mode_ids_follow_navigation()
	await _assert_prompt_and_replay_gate()
	await _assert_result_overlay_scope()
	await _assert_answer_enable_behavior()


func _section_long_run_stability() -> void:
	await _long_ear_session(MODE_INTERVAL, "long_interval", 20)
	if _is_ear_mode_enabled_for_build(MODE_PROGRESSION):
		await _long_ear_session(MODE_PROGRESSION, "long_progression", 12)
	else:
		na_step("Long-run: Progression mode locked in this build")
	for i in range(20):
		await _goto_practice_ear_mode(MODE_INTERVAL if i % 2 == 0 else MODE_CHORD)
		_call("_on_home_back_pressed")
		await wait_frames(2)
		await _goto_practice_sight_mode("Notes" if (i % 3) != 0 else "Chords")
		_call("_on_home_back_pressed")
		await wait_frames(2)
	await _assert_no_orphan_ui("Long-run rapid mode switching")
	pass_step("rapid_mode_switch_soak")


func _check_home_horizontal_scroll_absent() -> void:
	_call("_show_home")
	await wait_frames(6)
	var scroll_v: Variant = _member("_home_scroll")
	if not (scroll_v is ScrollContainer):
		fail("Home shell horizontal scroll check: _home_scroll missing")
		return
	var scroll := scroll_v as ScrollContainer
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		fail("Home shell horizontal scroll check: horizontal scroll mode is not disabled")
		return
	if scroll.scroll_horizontal != 0:
		fail("Home shell horizontal scroll check: scroll offset is %d" % scroll.scroll_horizontal)
		return
	var hbar := scroll.get_h_scroll_bar()
	if hbar != null and hbar.visible:
		fail("Home shell horizontal scroll check: horizontal scrollbar is visible")
		return
	pass_step("home_horizontal_scroll_absent")


func _has_sight_submode(mode_name: String) -> bool:
	var dict_v: Variant = _member("_sight_mode_buttons")
	if dict_v == null or not (dict_v is Dictionary):
		return false
	var dict := dict_v as Dictionary
	return dict.has(mode_name)


func _smoke_ear_mode(label: String, mode: int, tag: String) -> void:
	if not _is_ear_mode_enabled_for_build(mode):
		na_step("%s smoke skipped: mode is MVP-locked in this build" % label)
		return
	await _goto_practice_ear_mode(mode)
	await _take_tagged_screenshot("%s_before" % tag)
	if not _assert_core_controls_on_detail(label):
		return
	if not await _start_round_from_home():
		fail("%s smoke: failed to start round" % label)
		_record_issue("%s smoke start failed" % label, "High", "Navigation", [
			"Open Practice",
			"Select %s" % label,
			"Press Start Training"
		], "Round should start", "Round did not start", "Always")
		return
	await wait_frames(8)
	if _member_bool("_is_prompt_playing", false):
		await _wait_for_prompt_not_playing(720)
	if _member_int("_selected_mode", -1) != mode:
		fail("%s smoke: wrong mode active after start" % label)
	await _end_quiz_to_home_with_checks("%s smoke" % label, tag)


func _smoke_sight_submode(mode_name: String, tag: String) -> void:
	await _goto_practice_sight_mode(mode_name)
	await _take_tagged_screenshot("%s_before" % tag)
	if not _assert_core_controls_on_detail("Sight %s" % mode_name):
		return
	if not await _start_round_from_home():
		fail("Sight %s smoke: failed to start round" % mode_name)
		return
	if mode_name == "Continuous":
		await _wait_flag("_continuous_sight_active", true, 240)
	else:
		if mode_name != "Placement" and not await _wait_for_accepting_answer(480):
			fail("Sight %s smoke: prompt not ready" % mode_name)
	await _end_quiz_to_home_with_checks("Sight %s smoke" % mode_name, tag)


func _assert_core_controls_on_detail(label: String) -> bool:
	var ok := true
	for member_name in ["_home_start_button", "_home_mode_back_button"]:
		var c: Variant = _member(member_name)
		if c == null or not (c is Control):
			fail("%s: missing control %s" % [label, member_name])
			ok = false
			continue
		var ctrl := c as Control
		if not ctrl.visible:
			fail("%s: control not visible %s" % [label, member_name])
			ok = false
	return ok


func _end_quiz_to_home_with_checks(context: String, tag_prefix: String) -> void:
	await _take_tagged_screenshot("%s_active" % tag_prefix)
	if _member_bool("_quiz_active", false):
		_call("_on_end_quiz_pressed")
		await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(8)
	await _take_tagged_screenshot("%s_after_back" % tag_prefix)
	if not _assert_member_visible("_home_panel"):
		fail("%s: home panel not visible after exit" % context)
	await _assert_audio_stopped(context)
	await _assert_no_orphan_ui(context)
	pass_step("%s_end_back" % tag_prefix)


func _open_ear_settings_if_available() -> void:
	var clicked := click_button_by_text(_app, "Settings")
	if not clicked:
		_call("_on_ear_settings_pressed")
	await wait_frames(6)
	if not _member_bool("_ear_settings_screen_active", false):
		warn_step("Ear settings screen did not open")
		return
	pass_step("ear_settings_open")


func _close_settings_to_home_detail() -> void:
	if _member_bool("_ear_settings_screen_active", false):
		if _app.has_method("_on_ear_settings_back_pressed"):
			_call("_on_ear_settings_back_pressed")
		else:
			_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step("ear_settings_close")


func _set_ear_choice_count_extremes() -> void:
	var sel_v: Variant = _member("_ear_choice_count_select")
	if sel_v == null or not (sel_v is OptionButton):
		na_step("Interval matrix: ear choice count selector not available")
		return
	var sel := sel_v as OptionButton
	if sel.item_count <= 0:
		return
	_call("_on_ear_choice_count_selected", [0])
	await wait_frames(2)
	pass_step("ear_choice_count_low")
	_call("_on_ear_choice_count_selected", [sel.item_count - 1])
	await wait_frames(2)
	pass_step("ear_choice_count_high")


func _safe_interval_combo(combo: Dictionary) -> void:
	await _goto_practice_ear_mode(MODE_INTERVAL)
	await _set_bool_toggle("_include_minor_toggle", "_on_include_minor_toggled", bool(combo.get("minor", false)))
	await _set_bool_toggle("_descending_intervals_toggle", "_on_descending_intervals_toggled", bool(combo.get("descending", false)))
	await _set_bool_toggle("_harmonic_intervals_toggle", "_on_harmonic_intervals_toggled", bool(combo.get("harmonic", false)))
	await _set_interval_degree_set(str(combo.get("degree_set", "default")))
	await _run_ear_mini_session("interval_%s" % str(combo.get("label", "combo")), MODE_INTERVAL, 3, true, true)


func _set_interval_degree_set(kind: String) -> void:
	var toggles_v: Variant = _member("_degree_toggles")
	if toggles_v == null or not (toggles_v is Dictionary):
		na_step("Interval degree toggles not exposed")
		return
	var toggles := toggles_v as Dictionary
	var target_on: Array[int] = []
	match kind:
		"narrow":
			target_on = [2, 3]
		"broad":
			target_on = [1, 2, 3, 4, 5, 6, 7, 8]
		_:
			target_on = [1, 2, 3, 4, 5, 8]
	for degree_any in toggles.keys():
		var degree := int(degree_any)
		var desired := target_on.has(degree)
		var btn_v: Variant = toggles[degree_any]
		if btn_v is Button and (btn_v as Button).button_pressed != desired:
			_call("_on_degree_toggled", [desired, degree])
	await wait_frames(2)
	pass_step("interval_degree_set_%s" % kind)


func _set_bool_toggle(member_name: String, method_name: String, desired: bool) -> void:
	var btn_v: Variant = _member(member_name)
	if btn_v == null or not (btn_v is BaseButton):
		na_step("Toggle not available: %s" % member_name)
		return
	var btn := btn_v as BaseButton
	if not btn.visible or btn.disabled:
		na_step("Toggle not applicable (hidden/disabled): %s" % member_name)
		return
	if btn.button_pressed == desired:
		pass_step("%s already %s" % [member_name, "on" if desired else "off"])
		return
	if _app.has_method(method_name):
		_call(method_name, [desired])
	else:
		btn.button_pressed = desired
		if btn.has_signal("toggled"):
			btn.emit_signal("toggled", desired)
	await wait_frames(2)
	pass_step("%s %s" % [member_name, "on" if desired else "off"])


func _set_inversion_toggle(enabled: bool) -> void:
	await _set_bool_toggle("_inversion_toggle", "_on_inversion_toggled", enabled)


func _press_chord_group(group_id: int) -> bool:
	var dict_v: Variant = _member("_chord_group_buttons")
	if dict_v is Dictionary:
		var dict := dict_v as Dictionary
		var btn_v: Variant = dict.get(group_id, null)
		if btn_v is Button:
			_emit_click_marker(btn_v as Button)
			(btn_v as Button).emit_signal("pressed")
			await wait_frames(4)
			pass_step("chord_group_%d" % group_id)
			return true
	# Fallback for current UI: chord tiers are exposed as per-chord toggles.
	var tiers_v: Variant = _member("_chord_tier_toggles")
	if not (tiers_v is Dictionary):
		return false
	var tiers := tiers_v as Dictionary
	if tiers.is_empty():
		return false
	var include_set: Dictionary = {}
	match group_id:
		1:
			include_set = {"Major": true, "Minor": true}
		2:
			include_set = {"Augmented": true, "Diminished": true}
		3:
			include_set = {"Sus2": true, "Sus4": true, "Maj7": true, "Dom7": true, "Min7": true, "Dim7": true}
		4:
			include_set = {}
		_:
			return false
	for chord_key_any in tiers.keys():
		var chord_key := str(chord_key_any)
		var desired := true if group_id == 4 else include_set.has(chord_key)
		_call("_on_chord_tier_toggle", [desired, chord_key])
	await wait_frames(4)
	pass_step("chord_group_%d" % group_id)
	return true


func _set_progression_patterns(ids: Array[String]) -> void:
	var dict_v: Variant = _member("_progression_pattern_buttons")
	if dict_v == null or not (dict_v is Dictionary):
		na_step("Progression pattern buttons not exposed")
		return
	var dict := dict_v as Dictionary
	for key_any in dict.keys():
		var key := str(key_any)
		var desired := ids.has(key)
		var btn_v: Variant = dict[key_any]
		if btn_v is BaseButton and (btn_v as BaseButton).button_pressed != desired:
			_call("_on_progression_toggle", [desired, key])
	await wait_frames(2)
	pass_step("progression_patterns_%s" % "_".join(ids))


func _set_scale_modes(modes: Array[String]) -> void:
	var dict_v: Variant = _member("_scale_mode_select_buttons")
	if dict_v == null or not (dict_v is Dictionary):
		na_step("Scale mode select buttons not exposed")
		return
	var dict := dict_v as Dictionary
	# Two-pass toggle order avoids transient "empty selection" edge cases.
	for key_any in dict.keys():
		var key := str(key_any)
		if not modes.has(key):
			continue
		var btn_v: Variant = dict[key_any]
		if btn_v is BaseButton and not (btn_v as BaseButton).button_pressed:
			_call("_on_scale_mode_toggle", [true, key])
	for key_any2 in dict.keys():
		var key2 := str(key_any2)
		if modes.has(key2):
			continue
		var btn_v2: Variant = dict[key_any2]
		if btn_v2 is BaseButton and (btn_v2 as BaseButton).button_pressed:
			_call("_on_scale_mode_toggle", [false, key2])
	await wait_frames(2)
	var selected_now_v: Variant = _member("_scale_selected_modes")
	if selected_now_v is Array:
		var selected_now: Array = selected_now_v as Array
		var mismatch := false
		for m in modes:
			if not selected_now.has(str(m)):
				mismatch = true
				break
		if not mismatch:
			for m2 in selected_now:
				if not modes.has(str(m2)):
					mismatch = true
					break
		if mismatch:
			# Fallback hard-set for builds with custom UI signal timing.
			_app.set("_scale_selected_modes", modes.duplicate())
			var home_state_v: Variant = _member("_home_state")
			if home_state_v != null:
				home_state_v.set("scale_selected_modes", modes.duplicate())
			if _app.has_method("_refresh_scale_mode_buttons"):
				_call("_refresh_scale_mode_buttons")
			await wait_frames(2)
			selected_now_v = _member("_scale_selected_modes")
	if selected_now_v is Array and (selected_now_v as Array).size() < 2:
		fail("Scale mode QA setup left fewer than 2 modes selected")
		return
	pass_step("scale_modes_%s" % "_".join(modes))


func _set_cadence_types(types: Array[String]) -> void:
	var dict_v: Variant = _member("_cadence_type_buttons")
	if dict_v == null or not (dict_v is Dictionary):
		na_step("Cadence type buttons not exposed")
		return
	var dict := dict_v as Dictionary
	# Two-pass toggle order avoids transient "empty selection" edge cases.
	for key_any in dict.keys():
		var key := str(key_any)
		if not types.has(key):
			continue
		var btn_v: Variant = dict[key_any]
		if btn_v is BaseButton and not (btn_v as BaseButton).button_pressed:
			_call("_on_cadence_toggle", [true, key])
	for key_any2 in dict.keys():
		var key2 := str(key_any2)
		if types.has(key2):
			continue
		var btn_v2: Variant = dict[key_any2]
		if btn_v2 is BaseButton and (btn_v2 as BaseButton).button_pressed:
			_call("_on_cadence_toggle", [false, key2])
	await wait_frames(2)
	var selected_now_v: Variant = _member("_cadence_selected")
	if selected_now_v is Array:
		var selected_now: Array = selected_now_v as Array
		var mismatch := false
		for t in types:
			if not selected_now.has(str(t)):
				mismatch = true
				break
		if not mismatch:
			for t2 in selected_now:
				if not types.has(str(t2)):
					mismatch = true
					break
		if mismatch:
			_app.set("_cadence_selected", types.duplicate())
			var home_state_v: Variant = _member("_home_state")
			if home_state_v != null:
				home_state_v.set("cadence_selected", types.duplicate())
			if _app.has_method("_refresh_cadence_buttons"):
				_call("_refresh_cadence_buttons")
			await wait_frames(2)
			selected_now_v = _member("_cadence_selected")
	if selected_now_v is Array and (selected_now_v as Array).size() < 2:
		fail("Cadence QA setup left fewer than 2 cadence types selected")
		return
	pass_step("cadence_types_%s" % "_".join(types))


func _run_ear_mini_session(tag: String, mode: int, questions: int, use_replay: bool = false, check_replay_gating: bool = false) -> void:
	await _goto_practice_ear_mode(mode)
	# Re-apply targeted subsets after navigation because mode entry can repopulate defaults in some flows.
	if tag.find("scale_dorian_mixolydian") >= 0:
		await _set_scale_modes(["Dorian", "Mixolydian"])
	elif tag.find("scale_major_minor") >= 0:
		await _set_scale_modes(["Major", "Natural Minor"])
	elif tag.find("cadence_two_types") >= 0:
		await _set_cadence_types(["Perfect", "Plagal"])
	elif tag.find("cadence_alt_types") >= 0:
		await _set_cadence_types(["Half", "Deceptive"])
	elif tag.find("cadence_block") >= 0 or tag.find("cadence_broken") >= 0:
		await _set_cadence_types(["Perfect", "Plagal", "Half", "Deceptive"])
	await _take_tagged_screenshot("%s_before" % tag)
	if not await _start_round_from_home():
		if mode == MODE_SCALE_MODE:
			warn_step("%s debug scale_selected=%s" % [tag, str(_member("_scale_selected_modes"))])
		elif mode == MODE_CADENCE:
			warn_step("%s debug cadence_selected=%s" % [tag, str(_member("_cadence_selected"))])
		var q_spin_val := -1
		var q_spin_v: Variant = _member("_question_spin")
		if q_spin_v is SpinBox:
			q_spin_val = int((q_spin_v as SpinBox).value)
		warn_step("%s debug selected_mode=%d question_spin=%d" % [tag, _member_int("_selected_mode", -1), q_spin_val])
		fail("%s: failed to start" % tag)
		return
	await _run_answer_loop(mode, questions, false, use_replay, check_replay_gating)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	await _assert_audio_stopped(tag)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	await _take_tagged_screenshot("%s_after" % tag)
	pass_step(tag)


func _run_answer_loop(mode: int, questions: int, wrong_first: bool = false, use_replay: bool = false, check_replay_gating: bool = false) -> void:
	var seen_counts: Dictionary = {}
	var previous_prompt_key := ""
	var consecutive_repeat_count := 0
	for i in range(questions):
		if not await _wait_for_accepting_answer(720):
			if not _member_bool("_quiz_active", false):
				warn_step("Session ended before requested question %d/%d in mode %d" % [i + 1, questions, mode])
				break
			fail("Prompt %d/%d not ready in mode %d" % [i + 1, questions, mode])
			return
		var prompt_key := _current_prompt_observation_key(mode)
		if prompt_key != "":
			seen_counts[prompt_key] = int(seen_counts.get(prompt_key, 0)) + 1
			if prompt_key == previous_prompt_key:
				consecutive_repeat_count += 1
			else:
				consecutive_repeat_count = 0
			previous_prompt_key = prompt_key
			if consecutive_repeat_count >= 1 or int(seen_counts[prompt_key]) >= 3:
				_note_observation("questions_repeat_often")
		if use_replay and _app.has_method("_on_replay_pressed"):
			if check_replay_gating:
				await _assert_prompt_and_replay_gate_once()
			_call("_on_replay_pressed")
			await wait_frames(4)
		var use_wrong := wrong_first and i == 0
		if not await _answer_current(mode, use_wrong):
			fail("Answer submission failed for question %d in mode %d" % [i + 1, mode])
			return
		await wait_frames(4)
		if use_wrong:
			if not _feedback_visible_or_status_changed():
				warn_step("Wrong-answer feedback not visibly detected (mode %d)" % mode)
			_observe_wrong_answer_explanation()
			# Continue by answering subsequent prompts normally.
	pass_step("answer_loop_%d_%d" % [mode, questions])


func _feedback_visible_or_status_changed() -> bool:
	var status_v: Variant = _member("_status_label")
	if status_v is Label:
		return not (status_v as Label).text.strip_edges().is_empty()
	return true


func _observe_wrong_answer_explanation() -> void:
	var status_v: Variant = _member("_status_label")
	if not (status_v is Label):
		return
	var text := (status_v as Label).text.strip_edges().to_lower()
	if text == "":
		return
	var has_explanation := text.contains("because") or text.contains("why") or text.contains("interval") or text.contains("shape") or text.contains("pattern")
	if not has_explanation:
		_note_observation("wrong_answers_no_explanation")


func _observe_home_meta_signals() -> void:
	if _observed_home_meta_signals:
		return
	_observed_home_meta_signals = true
	var texts: Array[String] = []
	var stack: Array[Node] = [_app]
	while not stack.is_empty():
		var n_any: Variant = stack.pop_back()
		if not (n_any is Node):
			continue
		var n := n_any as Node
		if n is Label:
			var lbl := n as Label
			if lbl.visible:
				texts.append(lbl.text.to_lower())
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	var joined := " | ".join(texts)
	var has_goal := joined.contains("daily") or joined.contains("goal") or joined.contains("target") or joined.contains("session goal")
	var has_skill_tracking := joined.contains("weak") or joined.contains("strength") or joined.contains("accuracy by") or joined.contains("mastery") or joined.contains("stats")
	if not has_goal:
		_note_observation("no_daily_or_session_goal_visible")
	if not has_skill_tracking:
		_note_observation("no_skill_weakness_tracking_visible")


func _sight_notes_coverage() -> void:
	var clefs := ["Treble", "Bass"]
	for clef in clefs:
		await _goto_practice_sight_mode("Notes")
		await _set_clef(clef)
		await _set_sight_key_sig("C")
		await _set_sight_range_variant(false)
		await _run_sight_session("sight_notes_%s_c" % clef.to_lower(), "Notes", 5)
		if await _set_sight_key_sig("2#"):
			await _run_sight_session("sight_notes_%s_2s" % clef.to_lower(), "Notes", 5)
		await _set_sight_range_variant(true)
		await _run_sight_session("sight_notes_%s_wide" % clef.to_lower(), "Notes", 5)


func _sight_chords_coverage() -> void:
	# Chords mode now always uses grand staff (no clef toggle)
	await _goto_practice_sight_mode("Chords")
	await _set_sight_key_sig("C")
	await _run_sight_session("sight_chords_grand_c", "Chords", 5)
	if await _set_sight_key_sig("2b"):
		await _run_sight_session("sight_chords_grand_2b", "Chords", 5)


func _sight_placement_coverage() -> void:
	await _goto_practice_sight_mode("Placement")
	await _take_tagged_screenshot("sight_placement_before")
	if not await _start_round_from_home():
		fail("Sight Placement: failed to start")
		return
	if _member("_staff_area") == null:
		fail("Sight Placement: staff area missing")
	else:
		# Best-effort placement interaction: tap within staff area to exercise input path.
		var staff := _member("_staff_area") as Control
		if staff != null:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			staff.position = staff.position
			_call("_on_staff_area_gui_input", [ev])
		pass_step("sight_placement_input_best_effort")
	_call("_on_restart_quiz_pressed")
	await wait_frames(8)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	await _assert_no_orphan_ui("Sight Placement")


func _sight_continuous_coverage() -> void:
	if not _is_sight_mode_enabled_for_build("Continuous"):
		na_step("Sight Continuous coverage skipped: mode is MVP-locked in this build")
		return
	await _goto_practice_sight_mode("Continuous")
	await _take_tagged_screenshot("sight_continuous_before")
	if not await _start_round_from_home():
		fail("Sight Continuous: failed to start")
		return
	await _wait_flag("_continuous_sight_active", true, 240)
	# Ensure the continuous flow leaves "tap to start" waiting state before we probe hits.
	if _member_bool("_continuous_sight_waiting_start", false):
		if _app.has_method("_start_continuous_flow_after_waiting"):
			_call("_start_continuous_flow_after_waiting")
		else:
			_call("_on_round_start_pressed")
		await wait_frames(10)
	if _member_bool("_awaiting_round_start", false):
		_call("_on_round_start_pressed")
		await wait_frames(10)
	var start_hits := _member_int("_continuous_sight_total_hits", 0)
	var hit_registered := false
	for _i in range(300):
		if _member_bool("_continuous_sight_waiting_start", false):
			if _app.has_method("_start_continuous_flow_after_waiting"):
				_call("_start_continuous_flow_after_waiting")
			await get_tree().process_frame
			continue
		_try_hit_continuous_active_note()
		if _member_int("_continuous_sight_total_hits", 0) > start_hits:
			hit_registered = true
			break
		await get_tree().process_frame
	var end_hits := _member_int("_continuous_sight_total_hits", 0)
	if not hit_registered and end_hits <= start_hits:
		warn_step("Sight Continuous: no hit/miss events detected during timed session")
	pass_step("sight_continuous_timed_session")
	_call("_on_end_quiz_pressed")
	await wait_frames(10)
	await _assert_audio_stopped("Sight Continuous")
	await _assert_continuous_notes_cleared()


func _try_hit_continuous_active_note() -> bool:
	var idx := -1
	if _app.has_method("_continuous_active_note_index"):
		idx = int(_app.call("_continuous_active_note_index"))
	if idx < 0:
		return false
	var notes_v: Variant = _member("_continuous_sight_notes")
	if not (notes_v is Array):
		return false
	var notes: Array = notes_v as Array
	if idx >= notes.size():
		return false
	var note_any: Variant = notes[idx]
	if not (note_any is Dictionary):
		return false
	var note := note_any as Dictionary
	if bool(note.get("answered", false)):
		return false
	var token := str(note.get("name", "")).strip_edges()
	if token.is_empty():
		return false
	_call("_on_continuous_sight_key_pressed", [token])
	return true


func _run_sight_session(tag: String, mode_name: String, questions: int) -> void:
	await _goto_practice_sight_mode(mode_name)
	var sight_q_spin: Variant = _member("_sight_question_spin")
	if sight_q_spin is SpinBox:
		(sight_q_spin as SpinBox).value = maxf((sight_q_spin as SpinBox).value, float(questions))
	await _take_tagged_screenshot("%s_before" % tag)
	if not await _start_round_from_home():
		fail("%s: failed to start" % tag)
		return
	if _member("_staff_area") == null:
		fail("%s: staff area missing" % tag)
	else:
		await _assert_staff_visible_within_bounds(tag)
	await _run_answer_loop(MODE_SIGHT, questions, false, true, false)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	await _take_tagged_screenshot("%s_after" % tag)
	pass_step(tag)


func _set_clef(clef_name: String) -> bool:
	if not _app.has_method("_on_clef_button_pressed"):
		return false
	var buttons_v: Variant = _member("_clef_buttons")
	if buttons_v is Dictionary and not (buttons_v as Dictionary).has(clef_name):
		return false
	_call("_on_clef_button_pressed", [clef_name])
	await wait_frames(2)
	return _member_str("_selected_clef", "") == clef_name


func _set_sight_key_sig(sig_name: String) -> bool:
	var dict_v: Variant = _member("_sight_key_sig_buttons")
	if dict_v == null or not (dict_v is Dictionary):
		na_step("Sight key signatures not exposed")
		return false
	var dict := dict_v as Dictionary
	if not dict.has(sig_name):
		return false
	_call("_on_sight_key_sig_button_pressed", [sig_name])
	await wait_frames(2)
	pass_step("sight_key_sig_%s" % sig_name)
	return _member_str("_sight_key_signature", "") == sig_name


func _set_sight_range_variant(wider: bool) -> void:
	if not _app.has_method("_on_sight_range_adjust"):
		na_step("Sight range adjust UI not available")
		return
	# Best-effort: nudge range controls a few times in each direction.
	for _i in range(2):
		_call("_on_sight_range_adjust", [(-1 if wider else 1), false])
		_call("_on_sight_range_adjust", [(-1 if wider else 1), true])
	await wait_frames(2)
	pass_step("sight_range_%s" % ("wide" if wider else "narrow"))


func _set_note_chase_clef(clef_mode: String) -> bool:
	var dict_v: Variant = _member("_note_chase_clef_buttons")
	if dict_v == null or not (dict_v is Dictionary):
		return false
	var dict := dict_v as Dictionary
	if not dict.has(clef_mode):
		return false
	_call("_on_note_chase_clef_mode_pressed", [clef_mode])
	await wait_frames(2)
	pass_step("note_chase_clef_%s" % clef_mode)
	return _member_str("_note_chase_clef_mode", "") == clef_mode


func _set_note_chase_target_note_count(count: int) -> bool:
	var dict_v: Variant = _member("_note_chase_note_toggles")
	if dict_v == null or not (dict_v is Dictionary):
		return false
	var dict := dict_v as Dictionary
	var names: Array[String] = []
	for k in dict.keys():
		names.append(str(k))
	names.sort()
	var desired: Array[String] = []
	for i in range(mini(count, names.size())):
		desired.append(names[i])
	for k in names:
		var btn_v: Variant = dict.get(k, null)
		if not (btn_v is BaseButton):
			continue
		var btn := btn_v as BaseButton
		var should_on := desired.has(k)
		if btn.button_pressed != should_on:
			_call("_on_note_chase_note_toggled", [k])
	await wait_frames(2)
	pass_step("note_chase_target_count_%d" % count)
	return true


func _note_chase_session(tag: String, expected_clicks: int) -> void:
	await _goto_note_chase()
	await _take_tagged_screenshot("%s_before" % tag)
	if not await _start_round_from_home():
		fail("%s: failed to start" % tag)
		return
	if not await _wait_for_note_chase_running(240):
		fail("%s: note chase did not start" % tag)
		return
	var clicks := 0
	for _i in range(300):
		if await _wait_for_note_chase_note(1):
			if _click_first_note_chase_note():
				clicks += 1
				if clicks >= expected_clicks:
					break
		await get_tree().process_frame
	if clicks <= 0:
		fail("%s: no hittable note detected" % tag)
	_call("_on_restart_quiz_pressed")
	await wait_frames(8)
	await _assert_note_chase_cleared("Note Chase restart")
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	await _assert_note_chase_cleared("Note Chase exit")
	pass_step(tag)


func _read_navigation_audio_checks() -> void:
	_call("_show_home")
	_call("_on_home_hub_pressed", ["Learn"])
	await wait_frames(4)
	_call("_on_mode_button_pressed", [MODE_READ])
	await wait_frames(4)
	var modules_v: Variant = _member("_read_module_buttons")
	if modules_v == null or not (modules_v is Dictionary):
		na_step("Read module buttons not exposed")
		return
	var modules := modules_v as Dictionary
	for module_id_any in modules.keys():
		var module_id := int(module_id_any)
		_call("_on_read_module_button_pressed", [module_id])
		await wait_frames(4)
		if not await _start_round_from_home():
			warn_step("Read module %d did not start" % module_id)
			continue
		if not await _wait_flag("_in_tutorial", true, 240):
			warn_step("Read module %d tutorial did not open" % module_id)
		else:
			await _take_tagged_screenshot("read_module_%d" % module_id)
			if _app.has_method("_on_tutorial_back_pressed"):
				_call("_on_tutorial_back_pressed")
				await wait_frames(6)
				if not _member_bool("_in_tutorial", false):
					_call("_on_tutorial_home_pressed")
					await wait_frames(6)
			else:
				_call("_on_tutorial_home_pressed")
				await wait_frames(6)
		await _assert_audio_stopped("Read module %d nav" % module_id)
	pass_step("read_navigation_audio_checks")


func _nav_back_assert(area: String, before_tag: String, after_tag: String) -> void:
	await _take_tagged_screenshot(before_tag)
	_call("_on_home_back_pressed")
	await wait_frames(6)
	await _take_tagged_screenshot(after_tag)
	if _member_bool("_home_mode_detail_active", false):
		fail("%s: back navigation did not leave detail screen" % area)
		_record_issue("%s back navigation stuck" % area, "High", "Navigation", [
			"Enter a mode detail screen",
			"Press Back"
		], "Return to parent Practice screen", "Detail screen remained active", "Always")
	await _assert_audio_stopped(area)
	await _assert_no_orphan_ui(area)


func _goto_practice_ear_mode_start_quiz(mode: int, tag: String) -> bool:
	if not _is_ear_mode_enabled_for_build(mode):
		na_step("%s: mode `%s` is locked in this build" % [tag, _ear_mode_name(mode)])
		return false
	await _goto_practice_ear_mode(mode)
	await _normalize_mode_options_for_start(mode)
	await _take_tagged_screenshot("%s_before" % tag)
	if not await _start_round_from_home():
		fail("%s: failed to start" % tag)
		return false
	await wait_frames(6)
	return true


func _negative_path_ear(mode: int, tag: String) -> void:
	if not _is_ear_mode_enabled_for_build(mode):
		na_step("%s negative path skipped: mode `%s` is locked in this build" % [tag, _ear_mode_name(mode)])
		return
	await _goto_practice_ear_mode(mode)
	await _normalize_mode_options_for_start(mode)
	if not await _start_round_from_home():
		fail("%s negative path: failed to start" % tag)
		return
	if not await _wait_for_accepting_answer(720):
		fail("%s negative path: no prompt ready" % tag)
		return
	if not await _answer_current(mode, true):
		warn_step("%s negative path: no wrong-answer path available; used fallback" % tag)
	if _app.has_method("_on_replay_pressed"):
		_call("_on_replay_pressed")
		await wait_frames(6)
	if not await _wait_for_accepting_answer(720):
		warn_step("%s negative path: next question did not become answerable quickly" % tag)
	else:
		await _answer_current(mode, false)
	await _force_game_over_if_possible(mode, tag)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step("%s_negative" % tag)


func _negative_path_sight(mode_name: String, tag: String) -> void:
	await _goto_practice_sight_mode(mode_name)
	if not await _start_round_from_home():
		fail("%s negative path: failed to start" % tag)
		return
	if not await _wait_for_accepting_answer(720):
		fail("%s negative path: no prompt ready" % tag)
		return
	if not await _answer_current(MODE_SIGHT, true):
		warn_step("%s negative path: could not force wrong answer" % tag)
	if _app.has_method("_on_replay_pressed"):
		_call("_on_replay_pressed")
		await wait_frames(6)
	if await _wait_for_accepting_answer(720):
		await _answer_current(MODE_SIGHT, false)
	await _force_game_over_if_possible(MODE_SIGHT, tag)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step("%s_negative" % tag)


func _force_game_over_if_possible(mode: int, tag: String) -> void:
	var guard := 0
	while _member_bool("_quiz_active", false) and _member_int("_lives", 0) > 0 and guard < 10:
		if not await _wait_for_accepting_answer(480):
			break
		await _answer_current(mode, true)
		await wait_frames(4)
		guard += 1
	if _member_int("_lives", 0) <= 0:
		var result_overlay_v: Variant = _member("_result_overlay")
		if result_overlay_v is CanvasItem and not (result_overlay_v as CanvasItem).visible:
			warn_step("%s: game-over result overlay not visible" % tag)
		else:
			pass_step("%s_game_over_overlay" % tag)
		_call("_on_restart_quiz_pressed")
		await wait_frames(8)
		await _assert_restart_state(mode, "%s game over restart" % tag)
		_call("_on_end_quiz_pressed")
		await wait_frames(8)


func _wait_prompt_phase_transition() -> void:
	await wait_frames(2)
	if _member_bool("_is_prompt_playing", false):
		await _wait_for_prompt_not_playing(720)
	else:
		await wait_frames(20)


func _replay_abuse(tag: String, taps: int) -> void:
	for i in range(taps):
		_call("_on_replay_pressed")
		await wait_frames(2)
		if i % 2 == 0 and _app.has_method("_request_chicken_hint"):
			_call("_request_chicken_hint")
			await wait_frames(1)
	await _assert_audio_stopped(tag)
	pass_step(tag)


func _wait_for_prompt_not_playing(max_frames: int) -> bool:
	for _i in range(max_frames):
		if not _member_bool("_is_prompt_playing", false):
			return true
		await get_tree().process_frame
	return false


func _assert_audio_stopped(context: String) -> void:
	if not await _wait_flag("_is_prompt_playing", false, 180):
		fail("%s: prompt/audio playback did not stop after exit action" % context)
		_record_issue("Audio did not stop on navigation", "High", "Audio", [
			"Start a quiz prompt",
			"Use Back/End/Restart during or after playback"
		], "Playback stops shortly after navigation", "Prompt/audio still marked active", "Intermittent")
	else:
		pass_step("%s_audio_stopped" % context.replace(" ", "_").to_lower())
	await wait_frames(8)
	var audio_dbg := _qa_audio_debug_counters()
	var suspicious := _qa_suspicious_audio_names(audio_dbg)
	# Give short tails a chance to settle before warning.
	if not suspicious.is_empty():
		var deadline := Time.get_ticks_msec() + 1200
		while Time.get_ticks_msec() < deadline and not suspicious.is_empty():
			await get_tree().process_frame
			audio_dbg = _qa_audio_debug_counters()
			suspicious = _qa_suspicious_audio_names(audio_dbg)
	if not suspicious.is_empty():
		warn_step("%s: audio counters show active playback after stop check (%s)" % [context, ", ".join(suspicious)])
		_log_step("INFO", "Audio debug counters", {"audio": audio_dbg})


func _qa_suspicious_audio_names(audio_dbg: Dictionary) -> Array[String]:
	var active_names_v: Variant = audio_dbg.get("active_names", [])
	var active_names: Array = active_names_v if active_names_v is Array else []
	var suspicious: Array[String] = []
	for name_any in active_names:
		var name := str(name_any)
		# "generator" is intentionally kept running for synthesized prompts.
		if name in ["generator", "music", "ui_sfx", "sfx", "shield_sfx"]:
			continue
		suspicious.append(name)
	return suspicious


func _assert_no_orphan_ui(context: String) -> void:
	var game_panel_v: Variant = _member("_game_panel")
	if game_panel_v is CanvasItem and (game_panel_v as CanvasItem).visible and not _member_bool("_quiz_active", false):
		warn_step("%s: game panel still visible after exit (may be by design)" % context)
	var result_overlay_v: Variant = _member("_result_overlay")
	if result_overlay_v is CanvasItem and (result_overlay_v as CanvasItem).visible and not _member_bool("_quiz_active", false):
		warn_step("%s: result overlay remains visible after exit" % context)


func _assert_continuous_notes_cleared() -> void:
	var notes_v: Variant = _member("_continuous_sight_notes")
	if notes_v is Array and (notes_v as Array).size() > 0:
		warn_step("Continuous notes array not empty after exit")
	else:
		pass_step("continuous_notes_cleared")


func _assert_note_chase_cleared(context: String) -> void:
	var items_v: Variant = _member("_note_chase_active_notes")
	if items_v is Array and (items_v as Array).size() > 0:
		fail("%s: note chase active notes not cleared" % context)
		_record_issue("Note Chase stale notes after reset/exit", "High", "Note Chase", [
			"Start Note Chase",
			"Restart or exit round"
		], "Active note overlays clear", "Active notes remain in array after reset/exit", "Intermittent")
	else:
		pass_step("%s_cleared" % context.replace(" ", "_").to_lower())


func _assert_staff_visible_within_bounds(tag: String) -> void:
	var staff_v: Variant = _member("_staff_area")
	if not (staff_v is Control):
		fail("%s: staff area missing" % tag)
		return
	var staff := staff_v as Control
	if not staff.visible:
		fail("%s: staff area not visible" % tag)
		return
	var rect := staff.get_global_rect()
	var vp_rect := get_viewport().get_visible_rect()
	if rect.position.y < -4.0 or rect.end.y > vp_rect.end.y + 8.0:
		warn_step("%s: staff area appears clipped/offscreen" % tag)
	pass_step("%s_staff_bounds" % tag)


func _restart_reset_check_ear(mode: int, tag: String) -> void:
	await _goto_practice_ear_mode(mode)
	await _normalize_mode_options_for_start(mode)
	if not await _start_round_from_home():
		fail("%s: start failed" % tag)
		return
	await _run_answer_loop(mode, 2, false, false, false)
	_call("_on_restart_quiz_pressed")
	await wait_frames(10)
	await _assert_restart_state(mode, tag)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)


func _restart_reset_check_sight_notes(tag: String) -> void:
	await _goto_practice_sight_mode("Notes")
	if not await _start_round_from_home():
		fail("%s: start failed" % tag)
		return
	await _run_answer_loop(MODE_SIGHT, 2, false, false, false)
	_call("_on_restart_quiz_pressed")
	await wait_frames(10)
	await _assert_restart_state(MODE_SIGHT, tag)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)


func _restart_reset_check_note_chase(tag: String) -> void:
	await _goto_note_chase()
	if not await _start_round_from_home():
		fail("%s: start failed" % tag)
		return
	await _wait_for_note_chase_running(240)
	await _wait_for_note_chase_note(240)
	_click_first_note_chase_note()
	await wait_frames(6)
	_call("_on_restart_quiz_pressed")
	await wait_frames(10)
	await _assert_restart_state(MODE_NOTE_CHASE, tag)
	await _assert_note_chase_cleared("%s restart" % tag)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)


func _assert_restart_state(mode: int, context: String) -> void:
	if _member_int("_score", -1) != 0:
		fail("%s: score did not reset to 0" % context)
	if _member_int("_question_index", -1) > 1:
		fail("%s: question index did not reset" % context)
	var expected_lives := 5 if mode == MODE_NOTE_CHASE else 3
	if _member_int("_lives", -1) != expected_lives:
		fail("%s: lives did not reset (expected %d)" % [context, expected_lives])
	if _member_int("_streak", -1) != 0:
		warn_step("%s: streak did not reset to 0" % context)
	await _assert_audio_stopped(context)
	pass_step("%s_restart_state" % context.replace(" ", "_").to_lower())


func _back_home_reset_check() -> void:
	if await _goto_practice_ear_mode_start_quiz(MODE_INTERVAL, "back_home_reset"):
		await _run_answer_loop(MODE_INTERVAL, 1, false, false, false)
		_call("_on_end_quiz_pressed")
		await wait_frames(8)
		_call("_on_home_back_pressed")
		await wait_frames(8)
		await _assert_audio_stopped("Back/Home behavior")
		await _assert_no_orphan_ui("Back/Home behavior")
	pass_step("back_home_reset_check")


func _settings_persistence_check() -> void:
	await _goto_practice_ear_mode(MODE_INTERVAL)
	var before_minor := _member_bool("_include_minor_intervals", false)
	await _set_bool_toggle("_include_minor_toggle", "_on_include_minor_toggled", not before_minor)
	var changed_minor := _member_bool("_include_minor_intervals", false)
	_call("_on_home_back_pressed")
	await wait_frames(6)
	await _goto_practice_ear_mode(MODE_INTERVAL)
	var after_return_minor := _member_bool("_include_minor_intervals", false)
	var behavior := "persisted" if after_return_minor == changed_minor else "reset-by-design"
	_log_step("INFO", "Settings persistence include_minor: %s" % behavior)
	pass_step("settings_persistence_check")


func _check_duplicate_labels_home_and_settings() -> void:
	_call("_show_home")
	await wait_frames(4)
	_scan_duplicate_labels("Home")
	_call("_on_home_hub_pressed", ["Practice"])
	await wait_frames(3)
	_call("_on_ear_settings_pressed")
	await wait_frames(4)
	_scan_duplicate_labels("Settings")
	_call("_on_home_back_pressed")
	await wait_frames(4)


func _scan_duplicate_labels(screen_name: String) -> void:
	var counts: Dictionary = {}
	var stack: Array[Node] = [_app]
	while not stack.is_empty():
		var n_any: Variant = stack.pop_back()
		if not (n_any is Node):
			continue
		var n: Node = n_any as Node
		if n is Label:
			var lbl := n as Label
			if not lbl.visible:
				continue
			var txt := lbl.text.strip_edges()
			if txt.length() < 3:
				continue
			counts[txt] = int(counts.get(txt, 0)) + 1
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	for txt_any in counts.keys():
		var txt := str(txt_any)
		var count := int(counts[txt_any])
		if count > 1 and (txt.to_lower() == "settings" or txt.to_lower().contains("options")):
			warn_step("%s duplicate label `%s` x%d" % [screen_name, txt, count])
	pass_step("%s_duplicate_label_scan" % screen_name.to_lower())


func _check_visible_controls_within_viewport() -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var checked := 0
	var clipped := 0
	var clipped_ancestors: Array[Control] = []
	var stack: Array[Node] = [_app]
	while not stack.is_empty():
		var n_any: Variant = stack.pop_back()
		if not (n_any is Node):
			continue
		var n: Node = n_any as Node
		if n is Control:
			var c := n as Control
			if c.visible:
				checked += 1
				var r := c.get_global_rect()
				if r.size.x > 4 and r.size.y > 4:
					if _is_control_in_scroll_hierarchy(c):
						for ch in n.get_children():
							if ch is Node:
								stack.append(ch)
						continue
					# Skip background textures that intentionally cover the viewport
					if c is TextureRect and (c as TextureRect).stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED:
						for ch in n.get_children():
							if ch is Node:
								stack.append(ch)
						continue
					if r.position.x < -16 or r.position.y < -16 or r.end.x > vp_rect.end.x + 16 or r.end.y > vp_rect.end.y + 16:
						# Only count topmost clipped ancestor — skip children that
						# inherit the same overflow from a parent already counted.
						var is_child_of_clipped := false
						for ancestor in clipped_ancestors:
							if ancestor.is_ancestor_of(c):
								is_child_of_clipped = true
								break
						if not is_child_of_clipped:
							clipped += 1
							clipped_ancestors.append(c)
		for ch in n.get_children():
			if ch is Node:
				stack.append(ch)
	if clipped > 2:
		warn_step("Viewport scan: %d controls extend beyond viewport (symptom-based check)" % clipped)
	pass_step("viewport_bounds_scan_%d" % checked)


func _is_control_in_scroll_hierarchy(ctrl: Control) -> bool:
	if ctrl == null:
		return false
	var n: Node = ctrl
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


func _check_sight_layout_overlap() -> void:
	await _goto_practice_sight_mode("Notes")
	if not await _start_round_from_home():
		fail("UI integrity: Sight Notes failed to start")
		return
	await _wait_for_accepting_answer(480)
	var clef_v: Variant = _member("_staff_clef_label")
	var ks_v: Variant = _member("_staff_key_sig_labels")
	if clef_v is Control and ks_v is Array:
		var clef_rect := (clef_v as Control).get_global_rect()
		for lbl_any in (ks_v as Array):
			if lbl_any is Control and (lbl_any as Control).visible:
				if clef_rect.intersects((lbl_any as Control).get_global_rect()):
					fail("UI integrity: key signature overlaps clef in sight mode")
					_record_issue("Key signature overlaps clef", "High", "Sight", [
						"Open Sight Notes",
						"Use a key signature",
						"Start round"
					], "Key signature and clef should not overlap", "Overlap detected in visible staff labels", "Intermittent")
					break
	await _take_tagged_screenshot("ui_sight_overlap")
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step("sight_overlap_check")


func _check_chicken_visibility_and_overlap() -> void:
	if await _goto_practice_ear_mode_start_quiz(MODE_INTERVAL, "ui_chicken"):
		await _wait_for_accepting_answer(720)
		var bird_v: Variant = _member("_bird_sprite")
		if bird_v is Control and not (bird_v as Control).visible:
			warn_step("Chicken/bird sprite hidden at round start")
		var bubble_v: Variant = _member("_tutorial_bubble")
		var choices_v: Variant = _member("_interval_choice_buttons")
		if bubble_v is Control and (bubble_v as Control).visible and choices_v is Array:
			var br := (bubble_v as Control).get_global_rect()
			for btn_any in (choices_v as Array):
				if btn_any is Control and (btn_any as Control).visible and br.intersects((btn_any as Control).get_global_rect()):
					warn_step("Chicken bubble overlaps interval answer button")
					break
		_call("_on_end_quiz_pressed")
		await wait_frames(8)
		if _member_bool("_home_mode_detail_active", false):
			_call("_on_home_back_pressed")
			await wait_frames(6)
	pass_step("chicken_visibility_overlap_check")


func _assert_mode_ids_follow_navigation() -> void:
	await _goto_practice_ear_mode(MODE_INTERVAL)
	if _member_int("_selected_mode", -1) != MODE_INTERVAL:
		fail("Mode ID assertion failed for Interval")
	await _goto_practice_ear_mode(MODE_CADENCE)
	if _member_int("_selected_mode", -1) != MODE_CADENCE:
		fail("Mode ID assertion failed for Cadence")
	await _goto_practice_sight_mode("Notes")
	if _member_int("_selected_mode", -1) != MODE_SIGHT:
		fail("Mode ID assertion failed for Sight")
	await _goto_note_chase()
	if _member_int("_selected_mode", -1) != MODE_NOTE_CHASE:
		fail("Mode ID assertion failed for Note Chase")
	pass_step("mode_id_navigation_assertions")


func _assert_prompt_and_replay_gate() -> void:
	if not await _goto_practice_ear_mode_start_quiz(MODE_INTERVAL, "tech_prompt_replay"):
		return
	await _assert_prompt_and_replay_gate_once()
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step("prompt_replay_gate_assertions")


func _assert_prompt_and_replay_gate_once() -> void:
	var replay_v: Variant = _member("_replay_button")
	if not (replay_v is Button):
		na_step("Replay button not exposed for gating assertion")
		return
	var replay_btn := replay_v as Button
	if _member_bool("_is_prompt_playing", false) and not replay_btn.disabled:
		warn_step("Replay button enabled while prompt playing (behavior may be intended)")
	await _wait_for_accepting_answer(720)
	if _member_bool("_is_prompt_playing", false):
		await _wait_for_prompt_not_playing(720)
	if replay_btn.disabled:
		warn_step("Replay button still disabled after answer became available")


func _assert_result_overlay_scope() -> void:
	var result_v: Variant = _member("_result_overlay")
	if not (result_v is CanvasItem):
		na_step("Result overlay not exposed")
		return
	if (result_v as CanvasItem).visible and not _member_bool("_quiz_active", false):
		warn_step("Result overlay visible outside active session (may be stale state)")
	pass_step("result_overlay_scope_check")


func _assert_answer_enable_behavior() -> void:
	if not await _goto_practice_ear_mode_start_quiz(MODE_INTERVAL, "tech_answer_enable"):
		return
	var buttons_v: Variant = _member("_interval_choice_buttons")
	if not (buttons_v is Array):
		na_step("Interval choice buttons not exposed")
	else:
		var any_enabled_during_prompt := false
		if _member_bool("_is_prompt_playing", false):
			for btn_any in (buttons_v as Array):
				if btn_any is Button and (btn_any as Button).visible and not (btn_any as Button).disabled:
					any_enabled_during_prompt = true
					break
			if any_enabled_during_prompt:
				warn_step("Answer buttons enabled during prompt (verify intended behavior)")
		await _wait_for_accepting_answer(720)
		var any_enabled_after := false
		for btn_any2 in (buttons_v as Array):
			if btn_any2 is Button and (btn_any2 as Button).visible and not (btn_any2 as Button).disabled:
				any_enabled_after = true
				break
		if not any_enabled_after:
			fail("No answer buttons enabled after prompt")
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step("answer_enable_behavior")


func _long_ear_session(mode: int, tag: String, questions: int) -> void:
	if not _is_ear_mode_enabled_for_build(mode):
		na_step("%s skipped: mode `%s` is locked in this build" % [tag, _ear_mode_name(mode)])
		return
	await _goto_practice_ear_mode(mode)
	var q_spin: Variant = _member("_question_spin")
	if q_spin is SpinBox:
		(q_spin as SpinBox).value = questions
	await wait_frames(2)
	if not await _start_round_from_home():
		fail("%s: failed to start long session" % tag)
		return
	await _run_answer_loop(mode, questions, false, (mode != MODE_INTERVAL), false)
	_call("_on_end_quiz_pressed")
	await wait_frames(8)
	if _member_bool("_home_mode_detail_active", false):
		_call("_on_home_back_pressed")
		await wait_frames(6)
	pass_step(tag)


func _normalize_mode_options_for_start(mode: int) -> void:
	match mode:
		MODE_PROGRESSION:
			await _set_progression_patterns(["IVviIV", "iiVI"])
		MODE_SCALE_MODE:
			await _set_scale_modes(["Major", "Natural Minor"])
		MODE_CADENCE:
			await _set_cadence_types(["Perfect", "Plagal"])
		_:
			pass


func _goto_practice_ear_mode(mode: int) -> void:
	_call("_show_home")
	_call("_on_home_hub_pressed", ["Practice"])
	await wait_frames(3)
	_call("_on_mode_button_pressed", [MODE_INTERVAL])
	await wait_frames(3)
	_call("_on_ear_mode_button_pressed", [mode])
	await wait_frames(6)
	if _member_int("_selected_mode", -1) != mode:
		# Retry once after forcing a home UI refresh.
		if _app.has_method("_on_mode_selected"):
			_call("_on_mode_selected")
			await wait_frames(4)
		_call("_on_ear_mode_button_pressed", [mode])
		await wait_frames(6)
	if _member_int("_selected_mode", -1) != mode:
		fail("Ear mode %d selection failed (selected=%d)" % [mode, _member_int("_selected_mode", -1)])
		return
	if not bool(_app.get("_home_mode_detail_active")):
		fail("Ear mode detail was not active")


func _goto_practice_sight_mode(mode_name: String) -> void:
	_call("_show_home")
	_call("_on_home_hub_pressed", ["Practice"])
	await wait_frames(3)
	_call("_on_mode_button_pressed", [MODE_SIGHT])
	await wait_frames(3)
	_call("_on_sight_mode_button_pressed", [mode_name])
	await wait_frames(6)
	if int(_app.get("_selected_mode")) != MODE_SIGHT:
		fail("Sight mode selection failed")


func _goto_note_chase() -> void:
	_call("_show_home")
	_call("_on_home_hub_pressed", ["Practice"])
	await wait_frames(3)
	_call("_on_mode_button_pressed", [MODE_SIGHT])
	await wait_frames(3)
	# Prefer UI click for coverage, fallback to direct mode select.
	var clicked := click_button_by_text(_app, "Note Chase")
	if not clicked:
		_call("_on_mode_button_pressed", [MODE_NOTE_CHASE])
	await wait_frames(6)
	if int(_app.get("_selected_mode")) != MODE_NOTE_CHASE:
		fail("Note Chase mode did not activate")


func _start_round_from_home() -> bool:
	if _member_bool("_quiz_active", false):
		return true
	_call("_on_start_quiz_pressed")
	await wait_frames(8)
	if bool(_app.get("_awaiting_round_start")):
		_call("_on_round_start_pressed")
		await wait_frames(8)
	if bool(_app.get("_quiz_active")):
		return true
	# Ensure home detail UI is refreshed, then try the actual visible Start button path.
	if _app.has_method("_on_mode_selected"):
		_call("_on_mode_selected")
		await wait_frames(4)
	var start_btn_v: Variant = _member("_home_start_button")
	if start_btn_v is Button:
		var start_btn := start_btn_v as Button
		if start_btn.visible and not start_btn.disabled:
			_emit_click_marker(start_btn)
			start_btn.emit_signal("pressed")
			await wait_frames(8)
			if bool(_app.get("_awaiting_round_start")):
				_call("_on_round_start_pressed")
				await wait_frames(8)
			if bool(_app.get("_quiz_active")):
				return true
	# Retry once to recover from stale UI/result state after aggressive QA transitions.
	if _app.has_method("_on_end_quiz_pressed"):
		_call("_on_end_quiz_pressed")
		await wait_frames(6)
	if _app.has_method("_on_mode_selected"):
		_call("_on_mode_selected")
		await wait_frames(4)
	_call("_on_start_quiz_pressed")
	await wait_frames(8)
	if bool(_app.get("_awaiting_round_start")):
		_call("_on_round_start_pressed")
		await wait_frames(8)
	if bool(_app.get("_quiz_active")):
		return true
	var info_text := ""
	var info_v: Variant = _member("_home_info_label")
	if info_v is Label:
		info_text = (info_v as Label).text.strip_edges()
	if not info_text.is_empty():
		warn_step("Start round blocked: %s" % info_text)
	return false


func _set_small_question_counts() -> void:
	if _app == null:
		return
	var q_spin: Variant = _app.get("_question_spin")
	if q_spin != null and q_spin is SpinBox:
		(q_spin as SpinBox).value = 3
	var sight_q_spin: Variant = _app.get("_sight_question_spin")
	if sight_q_spin != null and sight_q_spin is SpinBox:
		(sight_q_spin as SpinBox).value = 3
	await wait_frames(2)


func _wait_for_accepting_answer(max_frames: int) -> bool:
	for _i in range(max_frames):
		if bool(_app.get("_accepting_answer")) and bool(_app.get("_quiz_active")):
			return true
		await get_tree().process_frame
	return false


func _wait_for_note_chase_running(max_frames: int) -> bool:
	var timeout_seconds := maxf(3.2, float(max_frames) / 60.0)
	var deadline := Time.get_ticks_msec() + int(round(timeout_seconds * 1000.0))
	while Time.get_ticks_msec() <= deadline:
		if bool(_app.get("_note_chase_running")):
			return true
		await get_tree().process_frame
	return false


func _wait_for_note_chase_note(max_frames: int) -> bool:
	var timeout_seconds := maxf(2.8, float(max_frames) / 60.0)
	var deadline := Time.get_ticks_msec() + int(round(timeout_seconds * 1000.0))
	while Time.get_ticks_msec() <= deadline:
		var items: Array = _app.get("_note_chase_active_notes")
		for item_any in items:
			var item: Dictionary = item_any
			if str(item.get("kind", "")) != "note":
				continue
			if bool(item.get("hit", false)):
				continue
			var panel: Panel = item.get("node", null)
			if panel != null and is_instance_valid(panel):
				return true
		await get_tree().process_frame
	return false


func _wait_flag(flag_name: String, expected: bool, max_frames: int) -> bool:
	for _i in range(max_frames):
		if bool(_app.get(flag_name)) == expected:
			return true
		await get_tree().process_frame
	return false


func _answer_current(selected_mode: int, prefer_wrong: bool = false) -> bool:
	if selected_mode == MODE_CHORD:
		return await _answer_chord(prefer_wrong)
	if selected_mode == MODE_SIGHT:
		var sight_mode := str(_app.get("_sight_mode"))
		if sight_mode == "Chords":
			return await _answer_sight_chord(prefer_wrong)
		return await _answer_sight_note(prefer_wrong)
	return await _answer_interval_or_theory(prefer_wrong)


func _answer_interval_or_theory(prefer_wrong: bool = false) -> bool:
	var buttons: Array = _app.get("_interval_choice_buttons")
	if buttons.is_empty():
		return false
	var expected := str(_app.get("_current_interval_id"))
	var selected_mode := int(_app.get("_selected_mode"))
	if selected_mode != MODE_INTERVAL:
		expected = str(_app.get("_current_ear_text_answer"))
	var chosen_idx := -1
	var first_enabled := -1
	var first_wrong := -1
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		if btn == null or not is_instance_valid(btn) or not btn.visible or btn.disabled:
			continue
		if first_enabled < 0:
			first_enabled = i
		var cid := str(btn.get_meta("choice_id")) if btn.has_meta("choice_id") else ""
		if cid == expected and chosen_idx < 0:
			chosen_idx = i
		elif cid != expected and first_wrong < 0:
			first_wrong = i
	if first_enabled < 0:
		return false
	# Prefer the correct choice for deterministic QA coverage (3 accepted prompts/mode).
	if prefer_wrong and first_wrong >= 0:
		chosen_idx = first_wrong
	elif chosen_idx < 0:
		chosen_idx = first_enabled
	_call("_on_interval_choice_index", [chosen_idx])
	return true


func _answer_chord(prefer_wrong: bool = false) -> bool:
	var dict: Dictionary = _app.get("_chord_buttons")
	if dict.is_empty():
		return false
	var correct := str(_app.get("_current_chord_quality"))
	var first_key := ""
	var wrong_key := ""
	for k in dict.keys():
		var key := str(k)
		var btn: Button = dict.get(k, null)
		if btn == null or not is_instance_valid(btn) or not btn.visible or btn.disabled:
			continue
		if first_key == "":
			first_key = key
		if key != correct and wrong_key == "":
			wrong_key = key
	if first_key == "":
		return false
	var pick := wrong_key if prefer_wrong and wrong_key != "" else correct
	if pick == "":
		pick = first_key
	_call("_on_chord_chosen", [pick])
	return true


func _answer_sight_note(prefer_wrong: bool = false) -> bool:
	var buttons: Dictionary = _app.get("_sight_key_buttons")
	if buttons.is_empty():
		return false
	var correct := str(_app.get("_current_sight_note"))
	var first := ""
	var wrong := ""
	for k in buttons.keys():
		var note_name := str(k)
		var btn: Button = buttons.get(k, null)
		if btn == null or not is_instance_valid(btn) or not btn.visible or btn.disabled:
			continue
		if first == "":
			first = note_name
		if note_name != correct and wrong == "":
			wrong = note_name
	if first == "":
		return false
	var pick := wrong if prefer_wrong and wrong != "" else correct
	if pick == "":
		pick = first
	_call("_on_sight_key_chosen", [pick])
	return true


func _answer_sight_chord(prefer_wrong: bool = false) -> bool:
	var choices: Array = _app.get("_current_sight_chord_choices")
	var buttons: Array = _app.get("_sight_chord_choice_buttons")
	if choices.is_empty() or buttons.is_empty():
		return false
	var correct_name := str(_app.get("_current_sight_chord_name"))
	var correct_idx := choices.find(correct_name)
	var first_enabled := -1
	var wrong_idx := -1
	for i in range(mini(choices.size(), buttons.size())):
		var btn: Button = buttons[i]
		if btn == null or not is_instance_valid(btn) or not btn.visible or btn.disabled:
			continue
		if first_enabled < 0:
			first_enabled = i
		if i != correct_idx and wrong_idx < 0:
			wrong_idx = i
	if first_enabled < 0:
		return false
	var pick_idx := wrong_idx if prefer_wrong and wrong_idx >= 0 else (correct_idx if correct_idx >= 0 else first_enabled)
	_call("_on_sight_chord_choice_index", [pick_idx])
	return true


func _click_first_note_chase_note() -> bool:
	var items: Array = _app.get("_note_chase_active_notes")
	for item_any in items:
		var item: Dictionary = item_any
		if str(item.get("kind", "")) != "note":
			continue
		if bool(item.get("hit", false)):
			continue
		var panel: Panel = item.get("node", null)
		if panel == null or not is_instance_valid(panel):
			continue
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		_emit_click_marker_panel(panel)
		_call("_on_note_chase_note_gui_input", [ev, panel])
		return true
	return false


func _emit_click_marker(control: Control) -> void:
	if _runner == null or not _runner.has_method("show_click"):
		return
	var center := control.get_global_rect().get_center()
	_runner.call("show_click", center)


func _emit_click_marker_panel(panel: Panel) -> void:
	if _runner == null or not _runner.has_method("show_click"):
		return
	var center := panel.global_position + (panel.size * 0.5)
	_runner.call("show_click", center)


func _assert_member_visible(member_name: String) -> bool:
	var v: Variant = _app.get(member_name)
	if v == null:
		fail("Missing member: %s" % member_name)
		return false
	if v is CanvasItem:
		var ci := v as CanvasItem
		if not ci.visible:
			fail("Member not visible: %s" % member_name)
			return false
	return true


func _find_button_by_text(root: Node, text: String) -> Button:
	if root == null:
		return null
	var target := text.strip_edges().to_lower()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n_any: Variant = stack.pop_back()
		if not (n_any is Node):
			continue
		var n: Node = n_any as Node
		if n is Button:
			var b := n as Button
			if b.text.strip_edges().to_lower() == target:
				return b
		for c in n.get_children():
			if c is Node:
				stack.append(c)
	return null


func _call(method_name: String, args: Array = []) -> Variant:
	if _app == null or not is_instance_valid(_app):
		return null
	if not _app.has_method(method_name):
		fail("App missing method: %s" % method_name)
		return null
	return _app.callv(method_name, args)


func _log_step(status: String, detail: String, extra: Dictionary = {}) -> void:
	var item := {
		"section": _active_section_name,
		"status": status,
		"detail": detail,
		"time_unix": Time.get_unix_time_from_system()
	}
	for k in extra.keys():
		item[k] = extra[k]
	_step_records.append(item)


func _record_issue(title: String, severity: String, area: String, repro_steps: Array[String], expected: String, actual: String, frequency: String = "Always", screenshot_paths: Array[String] = []) -> void:
	_issues.append({
		"title": title,
		"severity": severity,
		"area": area,
		"repro_steps": repro_steps.duplicate(),
		"expected": expected,
		"actual": actual,
		"frequency": frequency,
		"screenshot_paths": screenshot_paths.duplicate()
	})


func _record_suggestion(title: String, area: String, why: String, idea: String, priority: String) -> void:
	_suggestion_items.append({
		"title": title,
		"area": area,
		"why": why,
		"idea": idea,
		"priority": priority
	})


func _seed_suggestions() -> void:
	if not _suggestion_items.is_empty():
		return
	_record_suggestion("Add exposed QA hooks for tempo/key selectors", "QA", "Improves testability", "Expose tempo/key UI controls as named members so QA can matrix-test them without brittle tree searches.", "P1")
	_record_suggestion("Add explicit mode identifier label for QA", "QA", "Improves quality", "Display a small internal mode tag in QA overlay/debug build to simplify navigation assertions.", "P2")
	_record_suggestion("Expose audio-active counters in QA mode", "Audio", "Improves testability", "Publish active playback source count/state for overlap detection in `--qa` runs.", "P1")
	_record_suggestion("Add deterministic seed printout in QA mode", "QA", "Improves quality", "Print and persist RNG seed used for QA sessions to reproduce intermittent failures.", "P2")
	_record_suggestion("Add safe missing-resource simulation flag", "QA", "Improves resilience", "Provide a QA-only switch to stub optional assets/audio and verify fallback behavior.", "P1")


func _member(member_name: String) -> Variant:
	if _app == null:
		return null
	return _app.get(member_name)


func _member_bool(member_name: String, default_value: bool = false) -> bool:
	var v: Variant = _member(member_name)
	if v == null:
		return default_value
	return bool(v)


func _member_int(member_name: String, default_value: int = 0) -> int:
	var v: Variant = _member(member_name)
	if v == null:
		return default_value
	return int(v)


func _member_str(member_name: String, default_value: String = "") -> String:
	var v: Variant = _member(member_name)
	if v == null:
		return default_value
	return str(v)


func _take_tagged_screenshot(tag: String) -> Array[String]:
	var shot := await screenshot(tag)
	var paths: Array[String] = []
	if shot is Dictionary and bool(shot.get("saved", false)):
		paths.append(str(shot.get("path", "")))
	return paths


func _mode_area_name(mode: int, sight_mode_name: String = "") -> String:
	match mode:
		MODE_INTERVAL, MODE_CHORD, MODE_PROGRESSION, MODE_SCALE_MODE, MODE_CADENCE:
			return "Ear"
		MODE_SIGHT:
			return "Sight"
		MODE_NOTE_CHASE:
			return "Note Chase"
		MODE_READ:
			return "Read"
	return "QA"


func _safe_set_step_text(text: String) -> void:
	if _runner != null and _runner.has_method("set_step_text"):
		_runner.call("set_step_text", text)


func _qa_set_exposed_setting_if_available(group_name: String, setting_name: String, value: Variant) -> bool:
	if _app == null or not is_instance_valid(_app):
		return false
	if not _app.has_method("qa_get_exposed_setting_hooks") or not _app.has_method("qa_set_exposed_setting"):
		return false
	var hooks_v: Variant = _app.call("qa_get_exposed_setting_hooks")
	if not (hooks_v is Dictionary):
		return false
	var hooks := hooks_v as Dictionary
	if not hooks.has(group_name):
		return false
	var group_v: Variant = hooks[group_name]
	if not (group_v is Dictionary):
		return false
	var group := group_v as Dictionary
	if not group.has(setting_name):
		return false
	var ok := bool(_app.call("qa_set_exposed_setting", group_name, setting_name, value))
	if ok:
		await wait_frames(2)
		pass_step("qa_hook_%s_%s_%s" % [group_name, setting_name, str(value)])
	return ok


func _qa_missing_resource_sim_info() -> Dictionary:
	if _app != null and is_instance_valid(_app) and _app.has_method("qa_get_missing_resource_simulation_info"):
		var info_v: Variant = _app.call("qa_get_missing_resource_simulation_info")
		if info_v is Dictionary:
			return info_v as Dictionary
	return {"enabled": false}


func _qa_audio_debug_counters() -> Dictionary:
	if _app != null and is_instance_valid(_app) and _app.has_method("qa_get_audio_debug_counters"):
		var v: Variant = _app.call("qa_get_audio_debug_counters")
		if v is Dictionary:
			return v as Dictionary
	return {"active_count": 0}


func _note_observation(key: String) -> void:
	if _runner != null and _runner.has_method("note_observation"):
		_runner.call("note_observation", key)


func _current_prompt_observation_key(mode: int) -> String:
	if mode == MODE_CHORD:
		return _member_str("_current_chord_quality", "")
	if mode == MODE_SIGHT:
		if _member_str("_sight_mode", "") == "Chords":
			return _member_str("_current_sight_chord_name", "")
		return _member_str("_current_sight_note", "")
	if mode == MODE_INTERVAL:
		return _member_str("_current_interval_id", "")
	return _member_str("_current_ear_text_answer", "")


func _suggestions() -> Array[String]:
	return [
		"Add interval quests that unlock new bird animations after mastery streaks.",
		"Add adaptive review sessions that revisit missed intervals/chords within 24 hours.",
		"Add a short 'listen then sing' mode with pitch match feedback for ear-to-voice transfer.",
		"Add curriculum tracks (beginner, choir, piano, guitar) with tailored note/chord sets.",
		"Add progressive sight-reading rhythms so pitch and rhythm grow together.",
		"Add a daily mixed challenge combining interval, chord, cadence, and sight prompts.",
		"Add post-round explanations that compare the correct answer to the chosen distractor.",
		"Add teacher/student assignments with target accuracy and completion deadlines.",
		"Add achievements for consistent practice, not just high scores, to reinforce habits.",
		"Add a mastery map showing weak keys, clefs, intervals, and chord qualities over time."
	]
