class_name EndOfLessonDialog
extends RefCounted

# One-shot end-of-lesson modal. Builds a fullscreen overlay + center card
# with hero stats, activity list, and 3 actions (Skip / Send Parent Summary /
# Save Lesson Note). Click-outside dismisses.
#
# Stateless — the caller invokes EndOfLessonDialog.present(...) and the
# dialog manages its own lifetime (queue_free on dismiss).


# Show the modal. `host` is the parent Control the overlay is added to.
# Action callbacks:
#   on_parent_summary: () -> void
#   on_save: (entry: Dictionary) -> void  (caller builds the lesson-log save)
# `style_primary_btn` / `style_secondary_btn` are applied to the action buttons
# (passed in so the dialog matches the host's button styling without coupling).
static func present(
	host: Node,
	finished: Dictionary,
	student_display_name: String,
	on_parent_summary: Callable,
	on_save: Callable,
	style_primary_btn: Callable,
	style_secondary_btn: Callable
) -> void:
	if finished.is_empty():
		return

	var activities: Array = finished.get("activities", [])
	var duration_sec: int = int(finished.get("duration_sec", 0))
	var mm: int = duration_sec / 60
	var ss: int = duration_sec % 60
	var total_q: int = 0
	var total_c: int = 0
	for act_any in activities:
		if typeof(act_any) != TYPE_DICTIONARY:
			continue
		total_q += int((act_any as Dictionary).get("total", 0))
		total_c += int((act_any as Dictionary).get("score", 0))
	var avg_acc: int = -1
	if total_q > 0:
		avg_acc = int(round(float(total_c) / float(total_q) * 100.0))

	var summary_line: String = LessonSessionScript.summarize_activities(finished)
	var auto_summary: String = ""
	if activities.is_empty():
		auto_summary = "Lesson session %d:%02d — no rounds recorded." % [mm, ss]
	else:
		auto_summary = "Lesson session %d:%02d  •  %d activit%s\n%s" % [
			mm, ss, activities.size(), "y" if activities.size() == 1 else "ies", summary_line
		]
	var session_date: String = str(finished.get("started_at", "")).substr(0, 10)
	if session_date == "":
		session_date = Time.get_date_string_from_system()
	var entry := {
		"date": session_date,
		"summary": auto_summary,
		"practice_note": "",
		"next_focus": "",
		"auto_from_session": true,
		"session_id": str(finished.get("id", "")),
	}

	# --- Modal scaffolding ---
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_as_relative = false
	overlay.z_index = 700
	host.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(580, 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.14, 0.20, 0.98)
	card_sb.border_color = Color(0.475, 0.82, 0.80, 0.92)
	card_sb.border_width_left = 1
	card_sb.border_width_top = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 3
	card_sb.corner_radius_top_left = 18
	card_sb.corner_radius_top_right = 18
	card_sb.corner_radius_bottom_left = 18
	card_sb.corner_radius_bottom_right = 18
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	card_sb.shadow_size = 18
	card_sb.shadow_offset = Vector2(0, 6)
	card_sb.content_margin_left = 28
	card_sb.content_margin_right = 28
	card_sb.content_margin_top = 22
	card_sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	card.add_child(body)

	# --- Header ---
	var headline_text: String = "Lesson Complete"
	if avg_acc >= 90:
		headline_text = "%s  Outstanding lesson" % char(0x2728)
	elif avg_acc >= 75:
		headline_text = "%s  Strong lesson" % char(0x2B50)
	elif avg_acc >= 60:
		headline_text = "%s  Steady progress" % char(0x1F4AA)
	elif avg_acc >= 0:
		headline_text = "%s  Lesson wrapped" % char(0x1F3B5)
	var headline := Label.new()
	headline.text = headline_text
	headline.add_theme_font_size_override("font_size", 24)
	headline.add_theme_color_override("font_color", Color(0.62, 0.95, 0.88, 1.0))
	body.add_child(headline)

	var student_line := Label.new()
	student_line.text = "%s  ·  %d:%02d" % [student_display_name, mm, ss]
	student_line.add_theme_font_size_override("font_size", 14)
	student_line.add_theme_color_override("font_color", Color(0.78, 0.85, 0.94, 0.78))
	body.add_child(student_line)

	# --- Hero stats ---
	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats_row.add_theme_constant_override("separation", 10)
	body.add_child(stats_row)
	stats_row.add_child(_build_stat_chip("Time", "%d:%02d" % [mm, ss], Color(0.62, 0.86, 0.96, 1.0)))
	stats_row.add_child(_build_stat_chip("Rounds", str(activities.size()), Color(0.86, 0.78, 0.96, 1.0)))
	if total_q > 0:
		var acc_color: Color = Color(0.55, 0.92, 0.68, 1.0) if avg_acc >= 75 else (Color(0.96, 0.80, 0.42, 1.0) if avg_acc >= 60 else Color(0.92, 0.55, 0.50, 1.0))
		stats_row.add_child(_build_stat_chip("Accuracy", "%d%%" % avg_acc, acc_color))
		stats_row.add_child(_build_stat_chip("Correct", "%d / %d" % [total_c, total_q], Color(0.85, 0.92, 0.96, 1.0)))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(1.0, 1.0, 1.0, 0.08)
	body.add_child(divider)

	# --- Activity list ---
	if activities.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No rounds were recorded in this session."
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.add_theme_color_override("font_color", Color(0.78, 0.85, 0.94, 0.72))
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(none_lbl)
	else:
		var act_header := Label.new()
		act_header.text = "What you worked on"
		act_header.add_theme_font_size_override("font_size", 13)
		act_header.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 0.86))
		body.add_child(act_header)
		var act_box := VBoxContainer.new()
		act_box.add_theme_constant_override("separation", 4)
		body.add_child(act_box)
		var shown: int = mini(activities.size(), 6)
		for i in range(shown):
			var act_any: Variant = activities[i]
			if typeof(act_any) != TYPE_DICTIONARY:
				continue
			act_box.add_child(_build_activity_row(act_any as Dictionary))
		if activities.size() > shown:
			var more_lbl := Label.new()
			more_lbl.text = "…and %d more" % (activities.size() - shown)
			more_lbl.add_theme_font_size_override("font_size", 12)
			more_lbl.add_theme_color_override("font_color", Color(0.78, 0.85, 0.94, 0.62))
			act_box.add_child(more_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	body.add_child(spacer)

	# --- Action buttons ---
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(96, 42)
	skip_btn.flat = true
	skip_btn.add_theme_color_override("font_color", Color(0.78, 0.85, 0.94, 0.78))
	skip_btn.add_theme_font_size_override("font_size", 14)
	actions.add_child(skip_btn)

	var parent_btn := Button.new()
	parent_btn.text = "%s  Send Parent Summary" % char(0x1F4E7)
	parent_btn.custom_minimum_size = Vector2(220, 42)
	parent_btn.add_theme_font_size_override("font_size", 14)
	if style_secondary_btn.is_valid():
		style_secondary_btn.call(parent_btn)
	actions.add_child(parent_btn)

	var save_btn := Button.new()
	save_btn.text = "%s  Save Lesson Note" % char(0x2713)
	save_btn.custom_minimum_size = Vector2(200, 42)
	save_btn.add_theme_font_size_override("font_size", 15)
	if style_primary_btn.is_valid():
		style_primary_btn.call(save_btn)
	actions.add_child(save_btn)

	# --- Wiring ---
	var close_modal := func() -> void:
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()

	skip_btn.pressed.connect(func() -> void:
		close_modal.call()
	)
	parent_btn.pressed.connect(func() -> void:
		if on_parent_summary.is_valid():
			on_parent_summary.call()
		# Keep modal open so teacher can still save the lesson note after the summary save.
	)
	save_btn.pressed.connect(func() -> void:
		if on_save.is_valid():
			on_save.call(entry)
		close_modal.call()
	)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var click_pos: Vector2 = (event as InputEventMouseButton).position
			if not card.get_global_rect().has_point(click_pos):
				close_modal.call()
	)

	# --- Bounce-in animation ---
	card.scale = Vector2(0.82, 0.82)
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.pivot_offset = card.custom_minimum_size * 0.5
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Pill chip used in the hero stats row.
static func _build_stat_chip(label_text: String, value_text: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var chip_sb := StyleBoxFlat.new()
	var bg: Color = Color(accent.r, accent.g, accent.b, 0.14)
	chip_sb.bg_color = bg
	chip_sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	chip_sb.border_width_left = 1
	chip_sb.border_width_top = 1
	chip_sb.border_width_right = 1
	chip_sb.border_width_bottom = 1
	chip_sb.corner_radius_top_left = 8
	chip_sb.corner_radius_top_right = 8
	chip_sb.corner_radius_bottom_left = 8
	chip_sb.corner_radius_bottom_right = 8
	chip_sb.content_margin_left = 12
	chip_sb.content_margin_right = 12
	chip_sb.content_margin_top = 6
	chip_sb.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", chip_sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	chip.add_child(v)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.85))
	v.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 17)
	val.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98, 1.0))
	v.add_child(val)
	return chip


# Single activity row in the modal: mode label + score badge.
static func _build_activity_row(act: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := Label.new()
	dot.text = "%s" % char(0x2022)
	dot.add_theme_font_size_override("font_size", 14)
	dot.add_theme_color_override("font_color", Color(0.62, 0.95, 0.88, 0.65))
	row.add_child(dot)
	var mode: String = str(act.get("mode", ""))
	var sub: String = str(act.get("sub_mode", ""))
	var label_text: String = mode + (("  " + sub) if sub != "" else "")
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 0.95))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var score: int = int(act.get("score", 0))
	var total: int = int(act.get("total", 0))
	if total > 0:
		var pct: int = int(round(float(score) / float(total) * 100.0))
		var acc_color: Color = Color(0.55, 0.92, 0.68, 1.0) if pct >= 75 else (Color(0.96, 0.80, 0.42, 1.0) if pct >= 60 else Color(0.92, 0.55, 0.50, 1.0))
		var score_lbl := Label.new()
		score_lbl.text = "%d / %d  ·  %d%%" % [score, total, pct]
		score_lbl.add_theme_font_size_override("font_size", 12)
		score_lbl.add_theme_color_override("font_color", acc_color)
		row.add_child(score_lbl)
	var dsec: int = int(act.get("duration_sec", 0))
	if dsec > 0:
		var dmm: int = dsec / 60
		var dss: int = dsec % 60
		var dur_lbl := Label.new()
		dur_lbl.text = "%d:%02d" % [dmm, dss]
		dur_lbl.add_theme_font_size_override("font_size", 11)
		dur_lbl.add_theme_color_override("font_color", Color(0.78, 0.85, 0.94, 0.55))
		row.add_child(dur_lbl)
	return row


const LessonSessionScript = preload("res://scripts/students/lesson_session.gd")
