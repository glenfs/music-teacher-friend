extends Node

var _app: Node = null
var _bot: Node = null
var _step_counter := 0
var _screenshots: Array[Dictionary] = []
var _screenshot_skipped := false
var _started_at_unix := 0.0
var _result: Dictionary = {}
var qa_observations: Dictionary = {}
var _qa_scope := "all"
var _overlay_layer: CanvasLayer = null
var _overlay_root: Control = null
var _overlay_title: Label = null
var _overlay_step: Label = null
var _overlay_mode: Label = null
var _click_markers: Array[Control] = []

const QA_REPORT_PATH := "user://qa_report.md"
const QA_LOG_PATH := "user://qa_run_log.json"
const QA_ISSUES_PATH := "user://qa_issues.md"
const QA_SUGGESTIONS_PATH := "user://qa_suggestions.md"
const QA_SHOTS_DIR := "user://qa_screenshots"


func setup(app_root: Node) -> void:
	_app = app_root
	call_deferred("_run")


func _run() -> void:
	_started_at_unix = Time.get_unix_time_from_system()
	qa_observations = {}
	_qa_scope = _parse_qa_scope()
	_ensure_dir(QA_SHOTS_DIR)
	_build_overlay()
	print("QA START")
	print("QA_SCOPE=%s" % _qa_scope)
	print("QA REPORT PATH: %s" % ProjectSettings.globalize_path(QA_REPORT_PATH))
	print("QA LOG PATH: %s" % ProjectSettings.globalize_path(QA_LOG_PATH))
	print("QA SCREENSHOTS DIR: %s" % ProjectSettings.globalize_path(QA_SHOTS_DIR))
	print("QA ISSUES PATH: %s" % ProjectSettings.globalize_path(QA_ISSUES_PATH))
	print("QA SUGGESTIONS PATH: %s" % ProjectSettings.globalize_path(QA_SUGGESTIONS_PATH))
	_write_json(QA_LOG_PATH, {
		"qa_started": true,
		"started_at_unix": _started_at_unix,
		"report_path": ProjectSettings.globalize_path(QA_REPORT_PATH),
		"log_path": ProjectSettings.globalize_path(QA_LOG_PATH),
		"screenshots_dir": ProjectSettings.globalize_path(QA_SHOTS_DIR),
		"issues_path": ProjectSettings.globalize_path(QA_ISSUES_PATH),
		"suggestions_path": ProjectSettings.globalize_path(QA_SUGGESTIONS_PATH)
		,
		"qa_scope": _qa_scope
	})

	for _i in range(12):
		await get_tree().process_frame

	var ok := false
	var summary: Dictionary = {}
	var bot_script: Variant = load("res://scripts/qa/qa_bot.gd")
	if bot_script == null or not (bot_script is GDScript):
		summary = {"ok": false, "error": "Failed to load qa_bot.gd"}
	elif not (bot_script as GDScript).can_instantiate():
		summary = {"ok": false, "error": "qa_bot.gd cannot instantiate"}
	else:
		_bot = (bot_script as GDScript).new()
		if _bot == null:
			summary = {"ok": false, "error": "Failed to instantiate qa_bot.gd"}
		else:
			add_child(_bot)
			_bot.set("qa_scope", _qa_scope)
			if _bot.has_method("configure"):
				_bot.call("configure", _app, self)
			if _bot.has_method("run_suite"):
				summary = await _bot.call("run_suite")
				ok = bool(summary.get("ok", false))
			else:
				summary = {"ok": false, "error": "QABot missing run_suite()"}

	_result = {
		"ok": ok,
		"godot_version": str(Engine.get_version_info().get("string", "")),
		"platform": OS.get_name(),
		"display_driver": DisplayServer.get_name(),
		"started_at_unix": _started_at_unix,
		"finished_at_unix": Time.get_unix_time_from_system(),
		"screenshots": _screenshots,
		"screenshot_skipped": _screenshot_skipped,
		"qa_scope": _qa_scope,
		"summary": summary,
		"qa_observations": qa_observations.duplicate(true),
		"qa_done": true
	}
	_write_json(QA_LOG_PATH, _result)
	_write_report(_result)
	_write_issues(_result)
	_write_suggestions(_result)
	print("QA DONE %s" % ("PASS" if ok else "FAIL"))
	print("QA_SCOPE=%s" % _qa_scope)
	print("QA REPORT PATH: %s" % ProjectSettings.globalize_path(QA_REPORT_PATH))
	print("QA LOG PATH: %s" % ProjectSettings.globalize_path(QA_LOG_PATH))
	print("QA SCREENSHOTS DIR: %s" % ProjectSettings.globalize_path(QA_SHOTS_DIR))
	print("QA ISSUES PATH: %s" % ProjectSettings.globalize_path(QA_ISSUES_PATH))
	print("QA SUGGESTIONS PATH: %s" % ProjectSettings.globalize_path(QA_SUGGESTIONS_PATH))
	await _cleanup_before_quit()
	get_tree().quit(0 if ok else 1)


func _cleanup_before_quit() -> void:
	if _bot != null and is_instance_valid(_bot):
		_bot.queue_free()
	_bot = null
	for marker in _click_markers:
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	_click_markers.clear()
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	_overlay_layer = null
	_overlay_root = null
	_overlay_title = null
	_overlay_step = null
	_overlay_mode = null
	for _i in range(4):
		await get_tree().process_frame


func _parse_qa_scope() -> String:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for src in [user_args, args]:
		for i in range(src.size()):
			var s := str(src[i])
			if s == "--qa-scope" and i + 1 < src.size():
				var v := str(src[i + 1]).strip_edges()
				return v if v != "" else "all"
			if s.begins_with("--qa-scope="):
				var veq := s.trim_prefix("--qa-scope=").strip_edges()
				return veq if veq != "" else "all"
	return "all"


func note_observation(key: String) -> void:
	var k := key.strip_edges()
	if k == "":
		return
	qa_observations[k] = true


func generate_pro_suggestions() -> Array[String]:
	var out: Array[String] = []
	if bool(qa_observations.get("questions_repeat_often", false)):
		out.append("Add stronger repetition control/spaced sampling in short sessions so recently shown items are less likely to repeat back-to-back.")
	if bool(qa_observations.get("wrong_answers_no_explanation", false)):
		out.append("Add concise post-answer explanations for wrong responses (why correct answer is right and what distinguishes the chosen distractor).")
	if bool(qa_observations.get("no_daily_or_session_goal_visible", false)):
		out.append("Add a visible daily/session goal indicator (questions, accuracy, or streak target) on home or pre-round screens to improve retention and focus.")
	if bool(qa_observations.get("no_skill_weakness_tracking_visible", false)):
		out.append("Add a visible strengths/weaknesses summary by topic (intervals, chords, key signatures, clefs) so practice can target weak areas.")
	return out


func _process(_delta: float) -> void:
	if _overlay_mode == null or _app == null or not is_instance_valid(_app):
		return
	if _app.has_method("qa_mode_identifier"):
		_overlay_mode.text = "MODE: %s" % str(_app.call("qa_mode_identifier"))
	else:
		_overlay_mode.text = "MODE: n/a"


func take_screenshot(tag: String) -> Dictionary:
	_step_counter += 1
	var safe_tag := _sanitize_tag(tag)
	var rel_path := "%s/%02d_%s.png" % [QA_SHOTS_DIR, _step_counter, safe_tag]
	var abs_path := ProjectSettings.globalize_path(rel_path)
	var item := {
		"tag": tag,
		"path": rel_path,
		"saved": false,
		"reason": ""
	}

	if DisplayServer.get_name() == "headless":
		item["reason"] = "headless display driver"
		_screenshot_skipped = true
		_screenshots.append(item)
		return item

	if _app == null or not is_instance_valid(_app):
		item["reason"] = "app root missing"
		_screenshot_skipped = true
		_screenshots.append(item)
		return item

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var viewport := _app.get_viewport()
	if viewport == null:
		item["reason"] = "viewport missing"
		_screenshot_skipped = true
		_screenshots.append(item)
		return item
	var tex := viewport.get_texture()
	if tex == null:
		item["reason"] = "viewport texture missing"
		_screenshot_skipped = true
		_screenshots.append(item)
		return item
	var img := tex.get_image()
	if img == null or img.is_empty():
		item["reason"] = "viewport image empty"
		_screenshot_skipped = true
		_screenshots.append(item)
		return item

	_ensure_dir(QA_SHOTS_DIR)
	var err := img.save_png(abs_path)
	if err != OK:
		item["reason"] = "save_png error %s" % str(err)
		_screenshot_skipped = true
	else:
		item["saved"] = true
		item["reason"] = ""
	_screenshots.append(item)
	return item


func _write_report(data: Dictionary) -> void:
	var summary: Dictionary = data.get("summary", {})
	var tests: Array = summary.get("tests", [])
	var sections: Array = summary.get("sections", [])
	var failures: Array = summary.get("failures", [])
	var warnings: Array = summary.get("warnings", [])
	var fixes: Array = summary.get("fixes", [])
	var remaining: Array = summary.get("remaining_issues", [])
	var suggestions: Array = summary.get("suggestions", [])
	var issues: Array = summary.get("issues", [])
	var na_items: Array = summary.get("not_applicable", [])
	var pro_suggestions: Array[String] = generate_pro_suggestions()
	var screenshot_lines: Array[String] = []
	for s_any in _screenshots:
		var s: Dictionary = s_any
		if bool(s.get("saved", false)):
			screenshot_lines.append("- `%s` (%s)" % [str(s.get("path", "")), str(s.get("tag", ""))])
		else:
			screenshot_lines.append("- `%s` skipped: %s" % [str(s.get("tag", "")), str(s.get("reason", "unknown"))])

	var test_lines: Array[String] = []
	for t_any in (sections if not sections.is_empty() else tests):
		var t: Dictionary = t_any
		var name := str(t.get("name", "unnamed"))
		var status := str(t.get("status", "PASS" if bool(t.get("ok", false)) else "FAIL"))
		test_lines.append("- `%s`: %s" % [name, status])

	var fail_lines: Array[String] = []
	for f in failures:
		fail_lines.append("- %s" % str(f))
	if fail_lines.is_empty():
		fail_lines.append("- None")

	var warn_lines: Array[String] = []
	for w in warnings:
		warn_lines.append("- %s" % str(w))
	if warn_lines.is_empty():
		warn_lines.append("- None")

	var fix_lines: Array[String] = []
	for fx in fixes:
		fix_lines.append("- %s" % str(fx))
	if fix_lines.is_empty():
		fix_lines.append("- None in runtime harness (project fixes may be applied separately).")

	var remain_lines: Array[String] = []
	for r in remaining:
		remain_lines.append("- %s" % str(r))
	if remain_lines.is_empty():
		remain_lines.append("- None observed in QA automation run.")

	var suggestion_lines: Array[String] = []
	for s in suggestions:
		suggestion_lines.append("- %s" % str(s))
	if suggestion_lines.is_empty():
		suggestion_lines = [
			"- Add streak-based mini rewards tied to theory explanations.",
			"- Add spaced repetition goals by interval/chord family.",
			"- Add short listening drills with tempo ramp.",
			"- Add adaptive hint tiers before revealing answers.",
			"- Add daily challenge sets across ear + sight modes.",
			"- Add end-of-session skill heatmap by topic.",
			"- Add mistake replay queue with focused remediation.",
			"- Add call-and-response rhythm reading mode.",
			"- Add lesson goals tied to grade/level standards.",
			"- Add progress badges for accuracy + consistency."
		]

	var section_order: Array[String] = [
		"Smoke",
		"Ear Interval Matrix",
		"Ear Chord Matrix",
		"Progression Coverage",
		"Scale/Mode Coverage",
		"Cadence Coverage",
		"Sight Reading Coverage",
		"Note Chase Coverage",
		"Read/Tutorial Coverage",
		"Navigation Stress",
		"Negative Paths",
		"Audio Robustness",
		"State Reset/Persistence",
		"Long-Run Stability"
	]
	var section_lookup: Dictionary = {}
	for s_any in sections:
		var s: Dictionary = s_any
		section_lookup[str(s.get("name", ""))] = s

	var report := ""
	report += "# QA Report - Clefira\n\n"
	report += "## Environment\n\n"
	report += "- Platform: `%s`\n" % str(data.get("platform", "unknown"))
	report += "- Godot: `%s`\n" % str(Engine.get_version_info().get("string", "unknown"))
	report += "- Display driver: `%s`\n" % str(data.get("display_driver", "unknown"))
	report += "- QA mode: `--qa`\n\n"
	report += "- QA scope: `%s`\n\n" % str(data.get("qa_scope", "all"))
	report += "## Test Cases Run + Pass/Fail\n\n"
	report += "\n".join(test_lines) + "\n\n"
	for sec_name in section_order:
		report += "## %s\n\n" % sec_name
		if section_lookup.has(sec_name):
			var sec: Dictionary = section_lookup[sec_name]
			report += "- Status: `%s`\n" % str(sec.get("status", "PASS"))
			var sec_failures: Array = sec.get("failures", [])
			var sec_warnings: Array = sec.get("warnings", [])
			var step_count := (sec.get("steps", []) as Array).size()
			report += "- Steps logged: %d\n" % step_count
			report += "- Failures: %d\n" % sec_failures.size()
			report += "- Warnings: %d\n" % sec_warnings.size()
			if sec_failures.size() > 0:
				report += "- Failure details:\n"
				for f_any in sec_failures:
					report += "  - %s\n" % str(f_any)
			if sec_warnings.size() > 0:
				report += "- Warning details:\n"
				for w_any in sec_warnings:
					report += "  - %s\n" % str(w_any)
		else:
			report += "- Not executed\n"
		report += "\n"
	report += "## Screenshots\n\n"
	report += "\n".join(screenshot_lines if not screenshot_lines.is_empty() else ["- None"]) + "\n\n"
	report += "## What Failed Initially\n\n"
	report += "\n".join(fail_lines) + "\n\n"
	report += "## Warnings\n\n"
	report += "\n".join(warn_lines) + "\n\n"
	report += "## Not Applicable (Build-Dependent)\n\n"
	if na_items.is_empty():
		report += "- None\n\n"
	else:
		for na_any in na_items:
			report += "- %s\n" % str(na_any)
		report += "\n"
	report += "## What Was Changed To Fix It\n\n"
	report += "\n".join(fix_lines) + "\n\n"
	report += "## Remaining Known Issues\n\n"
	report += "\n".join(remain_lines) + "\n\n"
	report += "## Issues\n\n"
	if issues.is_empty():
		report += "- None observed during this QA run.\n\n"
	else:
		for issue_any in issues:
			var issue: Dictionary = issue_any
			report += "- `%s` (%s, %s)\n" % [str(issue.get("title", "Issue")), str(issue.get("severity", "Unknown")), str(issue.get("area", "QA"))]
		report += "\n"
	report += "## Suggestions To Make Clefira More Fun + Educational\n\n"
	report += "\n".join(suggestion_lines) + "\n"
	report += "\n## Pro-Level Improvement Suggestions\n\n"
	if pro_suggestions.is_empty():
		report += "- None triggered from observed QA behavior in this run.\n"
	else:
		for p in pro_suggestions:
			report += "- %s\n" % p
	_write_text(QA_REPORT_PATH, report)


func _write_issues(data: Dictionary) -> void:
	var summary: Dictionary = data.get("summary", {})
	var issues: Array = summary.get("issues", [])
	var failures: Array = summary.get("failures", [])
	if not failures.is_empty():
		for f_any in failures:
			var f := str(f_any)
			var exists := false
			for issue_any in issues:
				var issue: Dictionary = issue_any
				if str(issue.get("title", "")) == f:
					exists = true
					break
			if exists:
				continue
			var area := "QA"
			if f.to_lower().contains("cadence"):
				area = "Cadence"
			elif f.to_lower().contains("learn") or f.to_lower().contains("tutorial"):
				area = "Read"
			elif f.to_lower().contains("audio"):
				area = "Audio"
			elif f.to_lower().contains("navigation") or f.to_lower().contains("back"):
				area = "Navigation"
			issues.append({
				"title": f,
				"severity": "High",
				"area": area,
				"repro_steps": ["See qa_report.md and qa_run_log.json section logs for exact sequence."],
				"expected": "QA step should pass",
				"actual": f,
				"frequency": "Intermittent",
				"screenshot_paths": []
			})
	var out := "# QA Issues\n\n"
	if issues.is_empty():
		out += "- No issues recorded in this run.\n"
		_write_text(QA_ISSUES_PATH, out)
		return
	for issue_any in issues:
		var issue: Dictionary = issue_any
		out += "## Title\n%s\n\n" % str(issue.get("title", "Untitled issue"))
		out += "- Severity: %s\n" % str(issue.get("severity", "Medium"))
		out += "- Area: %s\n" % str(issue.get("area", "QA"))
		out += "- Repro steps\n"
		var repro: Array = issue.get("repro_steps", [])
		if repro.is_empty():
			out += "  - None provided\n"
		else:
			for step_any in repro:
				out += "  - %s\n" % str(step_any)
		out += "- Expected\n  - %s\n" % str(issue.get("expected", ""))
		out += "- Actual\n  - %s\n" % str(issue.get("actual", ""))
		out += "- Frequency: %s\n" % str(issue.get("frequency", "Always"))
		out += "- Screenshot path(s) if captured\n"
		var shots: Array = issue.get("screenshot_paths", [])
		if shots.is_empty():
			out += "  - None\n\n"
		else:
			for shot_any in shots:
				out += "  - %s\n" % str(shot_any)
			out += "\n"
	_write_text(QA_ISSUES_PATH, out)


func _write_suggestions(data: Dictionary) -> void:
	var summary: Dictionary = data.get("summary", {})
	var items: Array = summary.get("suggestion_items", [])
	var strings: Array = summary.get("suggestions", [])
	var out := "# QA Suggestions\n\n"
	if items.is_empty() and strings.is_empty():
		out += "- No suggestions recorded in this run.\n"
		_write_text(QA_SUGGESTIONS_PATH, out)
		return
	if items.is_empty():
		for s_any in strings:
			out += "## Suggestion title\n%s\n\n" % str(s_any)
			out += "- Area: QA\n"
			out += "- Why it helps (quality / UX / testability / performance)\n  - Quality / UX\n"
			out += "- Suggested implementation idea (brief)\n  - Review and prioritize from QA backlog.\n"
			out += "- Priority (P1/P2/P3): P3\n\n"
	else:
		for item_any in items:
			var item: Dictionary = item_any
			out += "## Suggestion title\n%s\n\n" % str(item.get("title", "Untitled suggestion"))
			out += "- Area: %s\n" % str(item.get("area", "QA"))
			out += "- Why it helps (quality / UX / testability / performance)\n  - %s\n" % str(item.get("why", ""))
			out += "- Suggested implementation idea (brief)\n  - %s\n" % str(item.get("idea", ""))
			out += "- Priority (P1/P2/P3): %s\n\n" % str(item.get("priority", "P3"))
	_write_text(QA_SUGGESTIONS_PATH, out)


func _write_json(path: String, data: Variant) -> void:
	var txt := JSON.stringify(data, "\t")
	if txt == "":
		txt = "{\"qa_json_error\":true}"
	_write_text(path, txt)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("QA runner failed to open %s" % path)
		return
	f.store_string(text)
	f.close()


func _ensure_dir(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path)


func set_step_text(step_name: String) -> void:
	if _overlay_step != null:
		_overlay_step.text = "STEP: %s" % step_name


func show_click(global_pos: Vector2) -> void:
	if _overlay_root == null or not is_instance_valid(_overlay_root):
		return
	var dot := ColorRect.new()
	dot.color = Color(1.0, 0.2, 0.2, 0.9)
	dot.size = Vector2(18, 18)
	dot.position = global_pos - Vector2(9, 9)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 4096
	_overlay_root.add_child(dot)
	_click_markers.append(dot)
	var tw := create_tween()
	tw.parallel().tween_property(dot, "scale", Vector2(1.8, 1.8), 0.18)
	tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.35)
	tw.finished.connect(func() -> void:
		if is_instance_valid(dot):
			dot.queue_free()
		_click_markers.erase(dot)
	)


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 127
	add_child(_overlay_layer)

	_overlay_root = Control.new()
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_overlay_root)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.size = Vector2(780, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	_overlay_title = Label.new()
	_overlay_title.text = "QA RUNNING"
	_overlay_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	vb.add_child(_overlay_title)

	_overlay_step = Label.new()
	_overlay_step.text = "STEP: boot"
	_overlay_step.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vb.add_child(_overlay_step)

	_overlay_mode = Label.new()
	_overlay_mode.text = "MODE: boot"
	_overlay_mode.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1.0))
	_overlay_mode.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_overlay_mode)


func _sanitize_tag(tag: String) -> String:
	var out := tag.to_lower()
	for ch in ["/", "\\", " ", ":", ";", ",", ".", "(", ")", "[", "]", "{", "}", "\"", "'"]:
		out = out.replace(ch, "_")
	while out.find("__") >= 0:
		out = out.replace("__", "_")
	out = out.strip_edges()
	if out.is_empty():
		return "shot"
	return out
