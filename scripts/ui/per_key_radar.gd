class_name PerKeyRadar
extends Control

# Polar radar chart for per-key sight-reading accuracy. Used by both the
# home overview card and the teacher dashboard. Animates in by scaling
# the filled polygon from 0 to 1 the first time it becomes visible.
#
# Usage:
#   var radar := PerKeyRadar.new()
#   radar.set_data({"C": {"asked": 30, "correct": 27}, ...})
#   parent.add_child(radar)
#
# Data shape: { key_label: { "asked": int, "correct": int } }
# Keys outside KEY_ORDER are ignored. Missing keys render with zero radius.


const KEY_ORDER: Array[String] = ["C", "1#", "2#", "3#", "1b", "2b", "3b"]

const COLOR_GRID := Color(0.42, 0.40, 0.50, 0.55)
const COLOR_GRID_OUTER := Color(0.62, 0.58, 0.72, 0.85)
const COLOR_SPOKE := Color(0.55, 0.50, 0.62, 0.55)
const COLOR_LABEL := Color(0.92, 0.92, 0.96, 0.92)
const COLOR_FILL := Color(0.55, 0.55, 0.92, 0.32)
const COLOR_OUTLINE := Color(0.62, 0.74, 1.00, 0.92)
const COLOR_POINT_GREEN := Color(0.55, 0.92, 0.68, 1.0)
const COLOR_POINT_GOLD := Color(0.96, 0.80, 0.42, 1.0)
const COLOR_POINT_RED := Color(0.92, 0.55, 0.50, 1.0)


var _entries: Array[Dictionary] = []
var _anim_progress: float = 0.0
var _animated_in: bool = false
var _tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(260, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(per_key: Dictionary) -> void:
	_entries.clear()
	for k in KEY_ORDER:
		var raw: Variant = per_key.get(k, null)
		var asked: int = 0
		var correct: int = 0
		if typeof(raw) == TYPE_DICTIONARY:
			asked = int((raw as Dictionary).get("asked", 0))
			correct = int((raw as Dictionary).get("correct", 0))
		_entries.append({
			"label": k,
			"asked": asked,
			"correct": correct,
		})
	queue_redraw()
	_play_intro_animation()


func _play_intro_animation() -> void:
	if _animated_in:
		_anim_progress = 1.0
		queue_redraw()
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_anim_progress = 0.0
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_anim_progress, 0.0, 1.0, 0.65)
	_animated_in = true


func _set_anim_progress(v: float) -> void:
	_anim_progress = v
	queue_redraw()


func _draw() -> void:
	if _entries.is_empty():
		return
	var center: Vector2 = size * 0.5
	var max_radius: float = minf(size.x, size.y) * 0.40
	var n: int = _entries.size()
	# Background grid rings at 25/50/75/100%.
	for ring_pct in [0.25, 0.50, 0.75, 1.0]:
		var r: float = max_radius * float(ring_pct)
		var pts := PackedVector2Array()
		for i in range(n):
			var ang: float = (TAU * float(i) / float(n)) - (PI / 2.0)
			pts.append(center + Vector2(cos(ang), sin(ang)) * r)
		var color: Color = COLOR_GRID_OUTER if ring_pct >= 0.99 else COLOR_GRID
		_draw_polygon_outline(pts, color, 1.4 if ring_pct >= 0.99 else 1.0)
	# Spokes + labels.
	var font := ThemeDB.fallback_font
	var font_size: int = 12
	for i in range(n):
		var ang: float = (TAU * float(i) / float(n)) - (PI / 2.0)
		var spoke_end: Vector2 = center + Vector2(cos(ang), sin(ang)) * max_radius
		draw_line(center, spoke_end, COLOR_SPOKE, 1.0, true)
		if font == null:
			continue
		var entry: Dictionary = _entries[i]
		var label: String = str(entry.get("label", ""))
		var display: String = label.replace("#", char(0x266F)).replace("b", char(0x266D))
		var txt_size: Vector2 = font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var label_pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * (max_radius + 14.0)
		label_pos -= txt_size * 0.5
		label_pos.y += txt_size.y * 0.5
		draw_string(font, label_pos, display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_LABEL)
	# Accuracy polygon (animated).
	var poly_pts := PackedVector2Array()
	var point_colors: Array[Color] = []
	for i in range(n):
		var entry2: Dictionary = _entries[i]
		var asked2: int = int(entry2.get("asked", 0))
		var correct2: int = int(entry2.get("correct", 0))
		var pct: float = 0.0
		if asked2 > 0:
			pct = float(correct2) / float(asked2)
		var radius: float = max_radius * pct * _anim_progress
		var ang2: float = (TAU * float(i) / float(n)) - (PI / 2.0)
		poly_pts.append(center + Vector2(cos(ang2), sin(ang2)) * radius)
		var pt_color: Color = COLOR_POINT_GREEN if pct >= 0.80 else (COLOR_POINT_GOLD if pct >= 0.60 else COLOR_POINT_RED)
		if asked2 == 0:
			pt_color = Color(pt_color.r, pt_color.g, pt_color.b, 0.30)
		point_colors.append(pt_color)
	if poly_pts.size() >= 3:
		draw_colored_polygon(poly_pts, COLOR_FILL)
		_draw_polygon_outline(poly_pts, COLOR_OUTLINE, 2.0)
		for i in range(poly_pts.size()):
			var entry3: Dictionary = _entries[i]
			var asked3: int = int(entry3.get("asked", 0))
			if asked3 == 0:
				continue
			draw_circle(poly_pts[i], 3.4, point_colors[i])


func _draw_polygon_outline(pts: PackedVector2Array, color: Color, width: float) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	for i in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		draw_line(a, b, color, width, true)
