class_name LessonSummaryHtml
extends RefCounted

# Pure renderer for a printable / shareable end-of-lesson HTML page that
# the teacher can hand to a parent. No instance state — the caller passes
# the finished-session dict + student record + app version label.


# Returns a self-contained HTML document string. `student_record` is optional;
# when present it adds the recent-trend chart, weak-items list, open-assignments
# list, and next-lesson-focus paragraph.
static func render(
	student_name: String,
	finished: Dictionary,
	student_record: Dictionary,
	app_version_label: String
) -> String:
	var activities: Array = finished.get("activities", [])
	var duration_sec: int = int(finished.get("duration_sec", 0))
	var mm: int = duration_sec / 60
	var ss: int = duration_sec % 60
	var started_at: String = str(finished.get("started_at", ""))
	var total_questions: int = 0
	var total_correct: int = 0
	for act_any in activities:
		if typeof(act_any) != TYPE_DICTIONARY:
			continue
		total_questions += int((act_any as Dictionary).get("total", 0))
		total_correct += int((act_any as Dictionary).get("score", 0))
	var avg_acc: int = -1
	if total_questions > 0:
		avg_acc = int(round(float(total_correct) / float(total_questions) * 100.0))
	var headline: String = ""
	if avg_acc >= 90:
		headline = "Outstanding focus this lesson — keep it up!"
	elif avg_acc >= 75:
		headline = "Solid progress today — building real fluency."
	elif avg_acc >= 60:
		headline = "Steady work this lesson — practising the right things."
	elif avg_acc >= 0:
		headline = "Stretching into harder material — practice will pay off this week."
	else:
		headline = "Lesson recorded — see notes below for the plan."

	var lines: Array[String] = []
	lines.append("<!DOCTYPE html>")
	lines.append("<html lang=\"en\"><head><meta charset=\"utf-8\">")
	lines.append("<title>Clefira Lesson Summary — %s</title>" % _esc(student_name))
	lines.append("<style>")
	lines.append("body{font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#1d2733;margin:32px;line-height:1.5;max-width:780px;}")
	lines.append("h1{font-size:26px;margin:0 0 4px;color:#1d3a5c;}")
	lines.append("h2{font-size:16px;margin:26px 0 8px;color:#1d3a5c;border-bottom:1px solid #cfd9e6;padding-bottom:4px;}")
	lines.append(".headline{font-size:16px;color:#1f6649;background:#e8f6ef;padding:10px 14px;border-left:4px solid #1f6649;border-radius:4px;margin:14px 0 18px;}")
	lines.append(".meta{color:#566778;font-size:13px;margin-bottom:18px;}")
	lines.append(".pill{display:inline-block;background:#eaf3ff;color:#1a4e8a;border-radius:999px;padding:3px 10px;font-size:12px;margin:0 6px 4px 0;}")
	lines.append(".pill.warn{background:#fff4dc;color:#8a5b16;}")
	lines.append(".pill.ok{background:#e1f5e8;color:#1f6649;}")
	lines.append("table{border-collapse:collapse;width:100%;margin-top:6px;}")
	lines.append("th,td{text-align:left;border-bottom:1px solid #e4ebf3;padding:6px 8px;font-size:13px;}")
	lines.append("th{background:#f4f7fb;color:#3d5775;font-weight:600;}")
	lines.append("ul.plain{list-style:none;padding-left:0;margin:6px 0;}")
	lines.append("ul.plain li{padding:5px 0;border-bottom:1px dashed #e4ebf3;}")
	lines.append(".trend{display:flex;gap:4px;align-items:flex-end;height:40px;margin:8px 0;}")
	lines.append(".trend .bar{width:18px;border-radius:3px 3px 0 0;}")
	lines.append(".trend .ok{background:#5dbf8a;} .trend .mid{background:#f0a868;} .trend .low{background:#d5635b;}")
	lines.append("footer{margin-top:32px;color:#8896a8;font-size:11px;text-align:center;}")
	lines.append("@media print{body{margin:18mm;max-width:none;} h1{font-size:20px;} h2{font-size:14px;}}")
	lines.append("</style></head><body>")
	lines.append("<h1>Clefira Lesson Summary</h1>")
	lines.append("<div class=\"meta\">")
	lines.append("<span class=\"pill\">Student: %s</span>" % _esc(student_name))
	lines.append("<span class=\"pill\">Date: %s</span>" % _esc(started_at))
	lines.append("<span class=\"pill\">Duration: %d:%02d</span>" % [mm, ss])
	lines.append("<span class=\"pill\">Rounds: %d</span>" % activities.size())
	if avg_acc >= 0:
		var acc_cls := "ok" if avg_acc >= 75 else ("warn" if avg_acc < 60 else "")
		lines.append("<span class=\"pill %s\">Avg accuracy: %d%%</span>" % [acc_cls, avg_acc])
	lines.append("</div>")
	lines.append("<div class=\"headline\">%s</div>" % _esc(headline))

	lines.append("<h2>What we worked on</h2>")
	if activities.is_empty():
		lines.append("<p>No rounds were recorded during this session.</p>")
	else:
		lines.append("<table><thead><tr><th>#</th><th>Activity</th><th>Score</th><th>Duration</th></tr></thead><tbody>")
		for i in range(activities.size()):
			var act_any: Variant = activities[i]
			if typeof(act_any) != TYPE_DICTIONARY:
				continue
			var act: Dictionary = act_any
			var mode: String = str(act.get("mode", ""))
			var sub: String = str(act.get("sub_mode", ""))
			var label: String = mode + (("  " + sub) if sub != "" else "")
			var score: int = int(act.get("score", 0))
			var total: int = int(act.get("total", 0))
			var dsec: int = int(act.get("duration_sec", 0))
			var dmm: int = dsec / 60
			var dss: int = dsec % 60
			var score_text: String = "%d / %d" % [score, total] if total > 0 else "—"
			lines.append("<tr><td>%d</td><td>%s</td><td>%s</td><td>%d:%02d</td></tr>" % [
				i + 1, _esc(label), _esc(score_text), dmm, dss
			])
		lines.append("</tbody></table>")

	if not student_record.is_empty():
		var history: Array = student_record.get("session_history", [])
		if not history.is_empty():
			var trend_start: int = maxi(0, history.size() - 10)
			lines.append("<h2>Recent practice trend</h2>")
			lines.append("<p style=\"color:#566778;font-size:12px;margin:0;\">Accuracy over the last %d sessions.</p>" % (history.size() - trend_start))
			lines.append("<div class=\"trend\">")
			for ti in range(trend_start, history.size()):
				var t_entry_any: Variant = history[ti]
				if typeof(t_entry_any) != TYPE_DICTIONARY:
					continue
				var t_acc_v = (t_entry_any as Dictionary).get("accuracy", -1)
				var t_acc: int = int(t_acc_v) if t_acc_v != null else -1
				var cls: String = "low"
				if t_acc >= 80:
					cls = "ok"
				elif t_acc >= 60:
					cls = "mid"
				var h_pct: int = maxi(10, t_acc)
				lines.append("<div class=\"bar %s\" style=\"height:%d%%;\" title=\"%d%%\"></div>" % [cls, h_pct, t_acc])
			lines.append("</div>")

		var item_stats_any = student_record.get("item_stats", {})
		var weak_rows: Array = []
		if typeof(item_stats_any) == TYPE_DICTIONARY:
			var item_stats: Dictionary = item_stats_any
			for category in item_stats:
				var cat_any = item_stats[category]
				if typeof(cat_any) != TYPE_DICTIONARY:
					continue
				var cat: Dictionary = cat_any
				for item_key in cat:
					var e_any = cat[item_key]
					if typeof(e_any) != TYPE_DICTIONARY:
						continue
					var asked: int = int((e_any as Dictionary).get("asked", 0))
					if asked < 3:
						continue
					var correct: int = int((e_any as Dictionary).get("correct", 0))
					var acc: int = int(round(float(correct) / float(asked) * 100.0))
					if acc < 70:
						weak_rows.append({"cat": str(category), "item": str(item_key), "acc": acc})
		weak_rows.sort_custom(func(a, b): return int(a.acc) < int(b.acc))
		if not weak_rows.is_empty():
			lines.append("<h2>Focus areas this week</h2>")
			lines.append("<ul class=\"plain\">")
			for wi in range(mini(weak_rows.size(), 3)):
				var w: Dictionary = weak_rows[wi]
				lines.append("<li><strong>%s</strong> (%s) — currently %d%% accurate. Try 5 minutes of focused practice.</li>" % [
					_esc(str(w.item)), _esc(str(w.cat).capitalize()), int(w.acc)
				])
			lines.append("</ul>")

		var assignments: Array = student_record.get("assignments", [])
		var open_assignments: Array = []
		for a_any in assignments:
			if typeof(a_any) != TYPE_DICTIONARY:
				continue
			if not bool((a_any as Dictionary).get("done", false)):
				open_assignments.append(a_any)
		if not open_assignments.is_empty():
			lines.append("<h2>Home practice plan</h2>")
			lines.append("<ul class=\"plain\">")
			for a_any in open_assignments:
				var a: Dictionary = a_any
				var task: String = str(a.get("task", ""))
				var due: String = str(a.get("due", ""))
				var due_suffix: String = ("  (due " + due + ")") if due != "" else ""
				lines.append("<li>%s<span style=\"color:#8a5b16;\">%s</span></li>" % [_esc(task), _esc(due_suffix)])
			lines.append("</ul>")

		var next_focus: String = str(student_record.get("next_lesson_focus", "")).strip_edges()
		if next_focus != "":
			lines.append("<h2>Plan for next lesson</h2>")
			lines.append("<p>%s</p>" % _esc(next_focus))

	var notes: String = str(finished.get("notes", "")).strip_edges()
	if not notes.is_empty():
		lines.append("<h2>Teacher notes</h2>")
		lines.append("<p>%s</p>" % _esc(notes))

	lines.append("<footer>Generated by Clefira %s — %s</footer>" % [
		app_version_label, _esc(Time.get_datetime_string_from_system())
	])
	lines.append("</body></html>")
	return "\n".join(lines)


static func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")
