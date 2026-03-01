extends Panel

const RHYTHM_NOTEHEAD_SHIMMER_ENABLED := true

const KIND_FALLBACK := "fallback"
const KIND_WHOLE_NOTE := "whole_note"
const KIND_HALF_NOTE := "half_note"
const KIND_QUARTER_NOTE := "quarter_note"
const KIND_EIGHTH_NOTE := "eighth_note"
const KIND_SIXTEENTH_NOTE := "sixteenth_note"
const KIND_DOTTED_QUARTER_NOTE := "dotted_quarter_note"
const KIND_DOTTED_HALF_NOTE := "dotted_half_note"
const KIND_TRIPLET_EIGHTH_NOTE := "triplet_eighth_note"
const KIND_TRIPLET_QUARTER_NOTE := "triplet_quarter_note"
const KIND_WHOLE_REST := "whole_rest"
const KIND_HALF_REST := "half_rest"
const KIND_QUARTER_REST := "quarter_rest"
const KIND_EIGHTH_REST := "eighth_rest"
const KIND_SIXTEENTH_REST := "sixteenth_rest"
const KIND_DOTTED_QUARTER_REST := "dotted_quarter_rest"
const KIND_DOTTED_HALF_REST := "dotted_half_rest"
const RHYTHM_DARK_GREEN := Color(0.16, 0.34, 0.78, 0.98) # quarter/eighth/sixteenth notehead blue
const RHYTHM_FLUOR_GREEN := Color(0.86, 1.00, 0.14, 0.98) # borders/stems/flags

var _event_type := "hit"
var _duration_beats := 1.0
var _glyph_kind := KIND_FALLBACK
var _fallback_width := 34.0
var _flash_alpha := 0.0
var _flash_color := Color(1, 1, 1, 0)
var _miss_mark := false
var _feedback_tween: Tween = null
var _stem_light_color := Color(0.96, 0.96, 0.98, 0.98)
var _visual_scale := 2.35
var _beam_left := false
var _beam_right := false
var _beam_left_len := 12.5
var _beam_right_len := 12.5
var _triplet := false
var _triplet_token := ""
var _triplet_group_len := 0
var _triplet_group_pos := -1
var _triplet_show_number := false
var _triplet_span_left_len := 0.0
var _triplet_span_right_len := 0.0
var _neon_outline_color := Color(0.83, 1.00, 0.22, 0.98)
var _notehead_panel: Panel
var _notehead_inner_panel: Panel
var _notehead_visible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)
	_ensure_notehead_nodes()


func configure(evt: Dictionary) -> void:
	_event_type = str(evt.get("type", "hit"))
	_duration_beats = float(evt.get("duration_beats", 1.0))
	_triplet = bool(evt.get("triplet", false))
	_triplet_token = str(evt.get("triplet_token", ""))
	_glyph_kind = _map_glyph_kind(_event_type, _duration_beats)
	_beam_left = bool(evt.get("beam_left", false))
	_beam_right = bool(evt.get("beam_right", false))
	_beam_left_len = float(evt.get("beam_left_len", 12.5))
	_beam_right_len = float(evt.get("beam_right_len", 12.5))
	_triplet_group_len = int(evt.get("triplet_group_len", 0))
	_triplet_group_pos = int(evt.get("triplet_group_pos", -1))
	_triplet_show_number = bool(evt.get("triplet_show_number", false))
	_triplet_span_left_len = float(evt.get("triplet_span_left_len", 0.0))
	_triplet_span_right_len = float(evt.get("triplet_span_right_len", 0.0))
	_fallback_width = clampf(20.0 + (_duration_beats * 22.0), 24.0, 92.0)
	custom_minimum_size = Vector2(64, 88) * _visual_scale
	size = custom_minimum_size
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	_miss_mark = false
	_flash_alpha = 0.0
	_randomize_stem_light_color()
	_configure_notehead_visual()
	queue_redraw()


func place_on_staff(anchor_x: float, staff_line_y: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		size = custom_minimum_size
	var anchor := _anchor_offset()
	# Snap to half-pixel positions to reduce shimmer/jagged edges during scroll.
	var px := anchor_x - anchor.x
	var py := staff_line_y - anchor.y
	position = Vector2(roundf(px * 2.0) / 2.0, roundf(py * 2.0) / 2.0)
	_layout_notehead_nodes()


func play_feedback(result: String) -> void:
	match result:
		"Perfect":
			_flash_color = Color(0.72, 1.0, 0.20, 0.85)
		"Good":
			_flash_color = Color(0.42, 0.92, 1.0, 0.85)
		"OK":
			_flash_color = Color(1.0, 0.84, 0.25, 0.85)
		_:
			_flash_color = Color(1.0, 0.42, 0.42, 0.85)
	_flash_alpha = 1.0
	_miss_mark = result == "Miss"
	if _feedback_tween != null and is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	scale = Vector2.ONE
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.07)
	_feedback_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.10)
	_feedback_tween.parallel().tween_method(_set_flash_alpha, 1.0, 0.0, 0.18)


func mark_miss() -> void:
	_miss_mark = true
	play_feedback("Miss")


func _set_flash_alpha(v: float) -> void:
	_flash_alpha = v
	queue_redraw()


func _randomize_stem_light_color() -> void:
	# Fluorescent yellow-green family for stems/beams/outlines/dots.
	var palette: Array[Color] = [
		Color(0.82, 1.00, 0.18, 0.98),
		Color(0.90, 1.00, 0.26, 0.98),
		Color(0.76, 0.98, 0.20, 0.98),
		Color(0.95, 1.00, 0.32, 0.98),
		Color(0.86, 1.00, 0.14, 0.98)
	]
	_stem_light_color = palette[randi() % palette.size()]
	_neon_outline_color = _stem_light_color


func _map_glyph_kind(evt_type: String, dur_beats: float) -> String:
	var is_hit := evt_type == "hit"
	if is_hit and _triplet:
		if _triplet_token == "t8" or is_equal_approx(dur_beats, 1.0 / 3.0):
			return KIND_TRIPLET_EIGHTH_NOTE
		if _triplet_token == "t4" or is_equal_approx(dur_beats, 2.0 / 3.0):
			return KIND_TRIPLET_QUARTER_NOTE
	if is_equal_approx(dur_beats, 4.0):
		return KIND_WHOLE_NOTE if is_hit else KIND_WHOLE_REST
	if is_equal_approx(dur_beats, 2.0):
		return KIND_HALF_NOTE if is_hit else KIND_HALF_REST
	if is_equal_approx(dur_beats, 1.0):
		return KIND_QUARTER_NOTE if is_hit else KIND_QUARTER_REST
	if is_equal_approx(dur_beats, 0.5):
		return KIND_EIGHTH_NOTE if is_hit else KIND_EIGHTH_REST
	if is_equal_approx(dur_beats, 0.25):
		return KIND_SIXTEENTH_NOTE if is_hit else KIND_SIXTEENTH_REST
	if is_equal_approx(dur_beats, 1.5):
		return KIND_DOTTED_QUARTER_NOTE if is_hit else KIND_DOTTED_QUARTER_REST
	if is_equal_approx(dur_beats, 3.0):
		return KIND_DOTTED_HALF_NOTE if is_hit else KIND_DOTTED_HALF_REST
	return KIND_FALLBACK


func _anchor_offset() -> Vector2:
	return Vector2(24.0, 48.0) * _visual_scale


func _line_y() -> float:
	return 48.0


func _note_center() -> Vector2:
	return Vector2(24.0, _line_y())


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_visual_scale, _visual_scale))
	var flash := _flash_color
	flash.a *= _flash_alpha
	if flash.a > 0.01:
		draw_circle(_note_center(), 17.0, flash)
	match _glyph_kind:
		KIND_WHOLE_NOTE:
			_draw_note(false, false, 0, false, Color(0.98, 0.84, 0.22, 0.98), 1.18)
		KIND_HALF_NOTE:
			_draw_note(true, false, 0, false, Color(1.00, 0.96, 0.72, 0.98))
		KIND_QUARTER_NOTE:
			_draw_note(true, true, 0, false, Color(0,0,0,0), 1.0, Color(0.48, 0.28, 0.14, 0.98))
		KIND_EIGHTH_NOTE:
			_draw_note(true, true, 1, false, Color(0,0,0,0), 1.0, Color(0.48, 0.28, 0.14, 0.98))
		KIND_TRIPLET_EIGHTH_NOTE:
			_draw_note(true, true, 1, false, Color(0,0,0,0), 1.0, Color(0.48, 0.28, 0.14, 0.98))
		KIND_SIXTEENTH_NOTE:
			_draw_note(true, true, 2, false, Color(0,0,0,0), 1.0, Color(0.48, 0.28, 0.14, 0.98))
		KIND_TRIPLET_QUARTER_NOTE:
			_draw_note(true, true, 0, false, Color(0,0,0,0), 1.0, Color(0.48, 0.28, 0.14, 0.98))
		KIND_DOTTED_QUARTER_NOTE:
			_draw_note(true, true, 0, true, Color(0,0,0,0), 1.0, Color(0.48, 0.28, 0.14, 0.98))
		KIND_DOTTED_HALF_NOTE:
			_draw_note(true, false, 0, true, Color(1.00, 0.96, 0.72, 0.98))
		KIND_WHOLE_REST:
			_draw_whole_rest()
		KIND_HALF_REST:
			_draw_half_rest()
		KIND_QUARTER_REST:
			_draw_quarter_rest()
		KIND_EIGHTH_REST:
			_draw_eighth_rest()
		KIND_SIXTEENTH_REST:
			_draw_sixteenth_rest()
		KIND_DOTTED_QUARTER_REST:
			_draw_quarter_rest()
			_draw_rest_dot(Vector2(34.0, 48.0))
		KIND_DOTTED_HALF_REST:
			_draw_half_rest()
			_draw_rest_dot(Vector2(38.0, 44.0))
		_:
			_draw_fallback()
	if _miss_mark:
		_draw_miss_x()
	if _triplet_show_number and _triplet and _triplet_token == "t4":
		_draw_triplet_bracket_full()
	if _triplet_show_number:
		_draw_triplet_number()


func _draw_note(with_stem: bool, filled: bool, flag_count: int = 0, dotted: bool = false, open_fill_color: Color = Color(0, 0, 0, 0), head_scale: float = 1.0, filled_head_color: Color = Color(0.98, 0.62, 0.23, 0.98)) -> void:
	var center := _note_center()
	var outline := _neon_outline_color
	var shadow := Color(0.08, 0.18, 0.02, 0.55)
	var pts_shadow := _ellipse_points(center + Vector2(1.6, 1.8), 9.0 * head_scale, 6.0 * head_scale, 16, -0.30)
	var pts := _ellipse_points(center, 9.0 * head_scale, 6.0 * head_scale, 16, -0.30)
	if not _notehead_visible:
		draw_colored_polygon(pts_shadow, shadow)
		if filled:
			draw_colored_polygon(pts, filled_head_color)
			var shine_pts := _ellipse_points(center + Vector2(-1.4, -1.8), 4.8 * head_scale, 2.6 * head_scale, 14, -0.30)
			draw_colored_polygon(shine_pts, Color(1.0, 0.92, 0.75, 0.30))
			_draw_closed_polyline(pts, outline, 2.2)
		else:
			if open_fill_color.a > 0.01:
				draw_colored_polygon(pts, open_fill_color)
				var inner_pts := _ellipse_points(center + Vector2(-1.2, -1.2), 4.8 * head_scale, 2.8 * head_scale, 14, -0.30)
				draw_colored_polygon(inner_pts, Color(1.0, 1.0, 0.90, 0.22))
			_draw_closed_polyline(pts, outline, 2.4)
	if with_stem:
		var stem_x := center.x + 8.0
		var stem_top := center.y - 30.0
		_draw_stem_line(Vector2(stem_x, center.y + 0.5), Vector2(stem_x, stem_top), _stem_light_color, 2.4)
		var wants_triplet_beam := _triplet and (_beam_left or _beam_right)
		if flag_count > 0 or wants_triplet_beam:
			if _beam_left or _beam_right:
				var beam_count := maxi(1, flag_count)
				var use_triplet_bracket := _triplet and _triplet_token == "t4"
				if use_triplet_bracket:
					_draw_triplet_bracket_segment(stem_x, stem_top, _beam_left, _beam_right)
				else:
					for fi in range(flag_count):
						_draw_beam_connector(stem_x, stem_top + (fi * 7.0), _beam_left, _beam_right, outline)
					if beam_count == 1 and flag_count == 0:
						_draw_beam_connector(stem_x, stem_top, _beam_left, _beam_right, outline)
			else:
				if flag_count == 1:
					_draw_single_flag_line(stem_x, stem_top, outline)
				elif flag_count == 2:
					_draw_double_joined_flags(stem_x, stem_top, outline)
				else:
					for fi in range(flag_count):
						_draw_single_flag_line(stem_x, stem_top + (fi * 8.0), outline)
	if dotted:
		var dot_pos := center + Vector2(15.0, -1.0)
		draw_circle(dot_pos + Vector2(0.9, 0.9), 2.4, shadow)
		draw_circle(dot_pos, 2.4, _stem_light_color)
		draw_circle(dot_pos + Vector2(-0.6, -0.5), 0.8, Color(1, 1, 0.9, 0.45))


func _draw_single_flag_line(stem_x: float, y0: float, outline: Color) -> void:
	# Use a thick curved stroke for visibility (same color as stem).
	_draw_flag_curve(PackedVector2Array([
		Vector2(stem_x, y0 + 0.6),
		Vector2(stem_x + 4.2, y0 + 2.2),
		Vector2(stem_x + 8.2, y0 + 5.4),
		Vector2(stem_x + 8.4, y0 + 10.8),
		Vector2(stem_x + 6.6, y0 + 16.8),
		Vector2(stem_x + 4.6, y0 + 22.6)
	]), _stem_light_color, 2.8)


func _draw_double_joined_flags(stem_x: float, y0: float, outline: Color) -> void:
	# Sixteenth-note standalone style: two visible curved flags, same color as stem.
	_draw_flag_curve(PackedVector2Array([
		Vector2(stem_x, y0 + 0.6),
		Vector2(stem_x + 4.3, y0 + 2.2),
		Vector2(stem_x + 8.3, y0 + 5.5),
		Vector2(stem_x + 8.1, y0 + 10.6),
		Vector2(stem_x + 6.4, y0 + 16.0),
		Vector2(stem_x + 4.6, y0 + 20.8)
	]), _stem_light_color, 2.7)
	var lower_y := y0 + 8.0
	_draw_flag_curve(PackedVector2Array([
		Vector2(stem_x + 0.2, lower_y + 0.8),
		Vector2(stem_x + 4.2, lower_y + 2.3),
		Vector2(stem_x + 8.0, lower_y + 5.5),
		Vector2(stem_x + 7.9, lower_y + 10.2),
		Vector2(stem_x + 6.3, lower_y + 15.1),
		Vector2(stem_x + 4.7, lower_y + 19.3)
	]), _stem_light_color, 2.5)


func _draw_beam_connector(stem_x: float, y0: float, beam_left: bool, beam_right: bool, outline: Color) -> void:
	var beam_len_r := maxf(4.0, _beam_right_len)
	# Draw only the right connector so each consecutive segment is rendered once.
	# This avoids the doubled/blocky look and reads as one smooth beamed line.
	if not beam_right:
		return
	var a := Vector2(stem_x, y0 + 1.2)
	var b := Vector2(stem_x + beam_len_r, y0 + 1.2)
	_draw_mat_line(a, b, _stem_light_color, 2.7)


func _draw_triplet_bracket_segment(stem_x: float, y0: float, beam_left: bool, beam_right: bool) -> void:
	# Quarter-note triplets read better with a bracket + "3" than a solid beam.
	if not beam_right:
		return
	var x0 := stem_x
	var x1 := stem_x + maxf(4.0, _beam_right_len)
	var y := y0 - 1.0
	_draw_mat_line(Vector2(x0, y), Vector2(x1, y), _stem_light_color, 1.8)
	# Small bracket cap on the right end.
	_draw_mat_line(Vector2(x1, y), Vector2(x1, y + 5.0), _stem_light_color, 1.6)
	# Small bracket cap on the run start (only once).
	if not beam_left:
		_draw_mat_line(Vector2(x0, y), Vector2(x0, y + 5.0), _stem_light_color, 1.6)


func _draw_triplet_number() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var font_size := 14
	var stem_x := _note_center().x + 8.0
	var stem_top := _note_center().y - 30.0
	var x := stem_x - 2.0
	if (_triplet_span_left_len + _triplet_span_right_len) > 0.01:
		x = stem_x + ((_triplet_span_right_len - _triplet_span_left_len) * 0.5)
	elif _beam_right:
		x += clampf(_beam_right_len * 0.5, 4.0, 22.0)
	elif _beam_left:
		x -= clampf(_beam_left_len * 0.5, 4.0, 22.0)
	var y := stem_top - (15.0 if _triplet_token == "t4" else 6.0)
	var txt := "3"
	var txt_size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(x - (txt_size.x * 0.5), y)
	# Small contrast plate for readability over backgrounds/staff.
	var pad := Vector2(3.0, 2.0)
	var rect := Rect2(pos - Vector2(0.0, txt_size.y) - pad, txt_size + (pad * 2.0))
	draw_rect(rect, Color(0.12, 0.10, 0.04, 0.65), true)
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.98, 0.96, 0.88, 0.98))


func _draw_triplet_bracket_full() -> void:
	# Quarter-note triplet grouping bracket (detached from stems).
	var stem_x := _note_center().x + 8.0
	var stem_top := _note_center().y - 30.0
	var left_len := maxf(0.0, _triplet_span_left_len)
	var right_len := maxf(0.0, _triplet_span_right_len)
	if (left_len + right_len) <= 0.01:
		return
	var x0 := stem_x - left_len
	var x1 := stem_x + right_len
	var y := stem_top - 9.0
	_draw_mat_line(Vector2(x0, y), Vector2(x1, y), _stem_light_color, 1.8)
	_draw_mat_line(Vector2(x0, y), Vector2(x0, y + 4.5), _stem_light_color, 1.4)
	_draw_mat_line(Vector2(x1, y), Vector2(x1, y + 4.5), _stem_light_color, 1.4)


func _draw_whole_rest() -> void:
	var line_y := _line_y()
	var r := Rect2(Vector2(16.0, line_y + 1.0), Vector2(18.0, 6.0))
	_draw_mat_rect(r, _rest_fill(), _neon_outline_color)


func _draw_half_rest() -> void:
	var line_y := _line_y()
	var r := Rect2(Vector2(16.0, line_y - 7.0), Vector2(18.0, 6.0))
	_draw_mat_rect(r, _rest_fill(), _neon_outline_color)


func _draw_quarter_rest() -> void:
	var c := _rest_fill()
	var x := 28.0
	var line_y := _line_y()
	# Place quarter rest higher on staff: starts near top space and ends near first space.
	var y0 := line_y - 24.0
	_draw_mat_line(Vector2(x - 3, y0), Vector2(x + 3, y0 + 8), c, 2.8)
	_draw_mat_line(Vector2(x + 3, y0 + 8), Vector2(x - 1, y0 + 16), c, 2.8)
	_draw_mat_line(Vector2(x - 1, y0 + 16), Vector2(x + 5, y0 + 24), c, 2.8)
	_draw_mat_line(Vector2(x + 5, y0 + 24), Vector2(x + 0, y0 + 34), c, 2.8)
	_draw_mat_dot(Vector2(x + 2, y0 + 30), c, 2.2)


func _draw_eighth_rest() -> void:
	var c := _rest_fill()
	var x := 24.0
	# Eighth rest like the reference: round bulb on the left, hooked top, then long slanted downstroke.
	_draw_mat_dot(Vector2(x + 0.1, 31.4), c, 2.2)
	_draw_mat_polyline(PackedVector2Array([
		Vector2(x + 1.5, 32.1),
		Vector2(x + 4.5, 30.5),
		Vector2(x + 6.4, 28.5),
		Vector2(x + 6.0, 31.6),
		Vector2(x + 4.9, 36.3),
		Vector2(x + 3.6, 41.1),
		Vector2(x + 2.3, 46.0),
		Vector2(x + 1.2, 50.3)
	]), c, 2.0)


func _draw_sixteenth_rest() -> void:
	var c := _rest_fill()
	var x := 24.0
	# Sixteenth rest should look like the eighth rest + a second middle hook/flag.
	# Reuse the same slanted "7" style backbone.
	_draw_mat_dot(Vector2(x + 0.1, 31.4), c, 2.1)
	_draw_mat_polyline(PackedVector2Array([
		Vector2(x + 1.5, 32.1),
		Vector2(x + 4.5, 30.5),
		Vector2(x + 6.4, 28.5),
		Vector2(x + 6.0, 31.6),
		Vector2(x + 4.9, 36.3),
		Vector2(x + 3.6, 41.1),
		Vector2(x + 2.3, 46.0),
		Vector2(x + 1.2, 50.3)
	]), c, 2.0)
	# Second (middle) hook + bulb, attached to the same slanted stroke.
	_draw_mat_dot(Vector2(x + 1.8, 39.4), c, 1.35)
	_draw_mat_polyline(PackedVector2Array([
		Vector2(x + 2.5, 39.8),
		Vector2(x + 4.6, 38.9),
		Vector2(x + 6.0, 37.6),
		Vector2(x + 5.7, 39.6),
		Vector2(x + 4.9, 41.7),
		Vector2(x + 4.0, 43.1)
	]), c, 1.45)


func _draw_rest_dot(pos: Vector2) -> void:
	_draw_mat_dot(pos, _stem_light_color, 2.2)


func _draw_fallback() -> void:
	var w := _fallback_width
	var r := Rect2(Vector2(24.0 - (w * 0.5), _line_y() - 8.0), Vector2(w, 16.0))
	var fill := Color(0.84, 0.94, 1.0, 0.95) if _event_type == "hit" else Color(0.92, 0.88, 0.74, 0.92)
	var edge := Color(0.12, 0.22, 0.30, 0.85)
	draw_rect(r, fill)
	draw_rect(r, edge, false, 2.0)


func _ensure_notehead_nodes() -> void:
	if _notehead_panel == null or not is_instance_valid(_notehead_panel):
		_notehead_panel = Panel.new()
		_notehead_panel.name = "RhythmNotehead"
		_notehead_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notehead_panel.clip_contents = false
		_notehead_panel.z_index = 240
		var empty := StyleBoxEmpty.new()
		_notehead_panel.add_theme_stylebox_override("panel", empty)
		add_child(_notehead_panel)
	if _notehead_inner_panel == null or not is_instance_valid(_notehead_inner_panel):
		_notehead_inner_panel = Panel.new()
		_notehead_inner_panel.name = "RhythmNoteheadInner"
		_notehead_inner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notehead_inner_panel.clip_contents = false
		_notehead_inner_panel.z_index = 241
		var empty2 := StyleBoxEmpty.new()
		_notehead_inner_panel.add_theme_stylebox_override("panel", empty2)
		add_child(_notehead_inner_panel)


func _configure_notehead_visual() -> void:
	_ensure_notehead_nodes()
	var is_note := _glyph_kind in [KIND_WHOLE_NOTE, KIND_HALF_NOTE, KIND_QUARTER_NOTE, KIND_EIGHTH_NOTE, KIND_SIXTEENTH_NOTE, KIND_DOTTED_QUARTER_NOTE, KIND_DOTTED_HALF_NOTE, KIND_TRIPLET_EIGHTH_NOTE, KIND_TRIPLET_QUARTER_NOTE]
	_notehead_visible = is_note
	_notehead_panel.visible = is_note
	_notehead_inner_panel.visible = false
	if not is_note:
		return
	var head_scale := 1.0
	var base_color := Color(0.42, 0.23, 0.10, 0.98)
	var open_note := false
	var inner_ratio := Vector2(0.54, 0.52)
	var gloss_strength := 0.62
	match _glyph_kind:
		KIND_WHOLE_NOTE:
			head_scale = 1.24
			base_color = Color(0.98, 0.84, 0.22, 0.98)
			open_note = true
			inner_ratio = Vector2(0.61, 0.57)
			gloss_strength = 0.68
		KIND_HALF_NOTE, KIND_DOTTED_HALF_NOTE:
			head_scale = 1.12
			base_color = Color(1.00, 0.96, 0.72, 0.98)
			open_note = true
			inner_ratio = Vector2(0.64, 0.60)
			gloss_strength = 0.62
		KIND_QUARTER_NOTE, KIND_EIGHTH_NOTE, KIND_SIXTEENTH_NOTE, KIND_DOTTED_QUARTER_NOTE, KIND_TRIPLET_EIGHTH_NOTE, KIND_TRIPLET_QUARTER_NOTE:
			head_scale = 1.0
			base_color = RHYTHM_DARK_GREEN
			gloss_strength = 0.34
			_stem_light_color = RHYTHM_FLUOR_GREEN
			_neon_outline_color = RHYTHM_FLUOR_GREEN
		_:
			head_scale = 1.0
			base_color = Color(0.42, 0.23, 0.10, 0.98)
			gloss_strength = 0.38
	var head_size := Vector2(18.0 * head_scale, 12.0 * head_scale) * _visual_scale
	_notehead_panel.size = head_size
	_notehead_panel.custom_minimum_size = head_size
	_apply_notehead_material_local(_notehead_panel, base_color, _neon_outline_color, open_note, gloss_strength)
	_set_open_note_lighting(open_note)
	if open_note:
		_notehead_inner_panel.visible = true
		var inner_size := head_size * inner_ratio
		_notehead_inner_panel.size = inner_size
		_notehead_inner_panel.custom_minimum_size = inner_size
		var inner := StyleBoxFlat.new()
		# Open-note center: light neutral fill so half/whole notes read as open, not brown-filled.
		inner.bg_color = Color(0.98, 0.97, 0.90, 0.94)
		inner.corner_radius_top_left = int(round(inner_size.x * 0.5))
		inner.corner_radius_top_right = int(round(inner_size.x * 0.5))
		inner.corner_radius_bottom_left = int(round(inner_size.x * 0.5))
		inner.corner_radius_bottom_right = int(round(inner_size.x * 0.5))
		inner.border_width_left = 0
		inner.border_width_top = 0
		inner.border_width_right = 0
		inner.border_width_bottom = 0
		_notehead_inner_panel.add_theme_stylebox_override("panel", inner)
		_notehead_inner_panel.modulate = Color(1, 1, 1, 0.95)
	_layout_notehead_nodes()


func _set_open_note_lighting(open_note: bool) -> void:
	if _notehead_panel == null or not is_instance_valid(_notehead_panel):
		return
	var gloss := _notehead_panel.get_node_or_null("MatGloss")
	if gloss != null and gloss is CanvasItem:
		(gloss as CanvasItem).visible = true
		(gloss as CanvasItem).modulate.a = 0.70 if not open_note else 0.35
	var shimmer_a := _notehead_panel.get_node_or_null("MatShimmerA")
	var shimmer_b := _notehead_panel.get_node_or_null("MatShimmerB")
	if open_note:
		if shimmer_a != null and shimmer_a is CanvasItem:
			(shimmer_a as CanvasItem).visible = false
		if shimmer_b != null and shimmer_b is CanvasItem:
			(shimmer_b as CanvasItem).visible = false
		if _notehead_panel.has_meta("note_shimmer_tween"):
			var t_v: Variant = _notehead_panel.get_meta("note_shimmer_tween")
			if t_v is Tween:
				var t := t_v as Tween
				if t != null and is_instance_valid(t):
					t.kill()
			_notehead_panel.set_meta("note_shimmer_tween", null)
	else:
		if shimmer_a != null and shimmer_a is CanvasItem:
			(shimmer_a as CanvasItem).visible = RHYTHM_NOTEHEAD_SHIMMER_ENABLED
		if shimmer_b != null and shimmer_b is CanvasItem:
			(shimmer_b as CanvasItem).visible = RHYTHM_NOTEHEAD_SHIMMER_ENABLED


func _layout_notehead_nodes() -> void:
	if _notehead_panel == null or not is_instance_valid(_notehead_panel):
		return
	if not _notehead_panel.visible:
		return
	var center := _note_center() * _visual_scale
	_notehead_panel.position = center - (_notehead_panel.size * 0.5)
	_notehead_panel.pivot_offset = _notehead_panel.size * 0.5
	_notehead_panel.rotation_degrees = -15.0
	if _notehead_inner_panel != null and is_instance_valid(_notehead_inner_panel) and _notehead_inner_panel.visible:
		_notehead_inner_panel.position = center - (_notehead_inner_panel.size * 0.5) + Vector2(-1.0, -0.5) * _visual_scale
		_notehead_inner_panel.pivot_offset = _notehead_inner_panel.size * 0.5
		_notehead_inner_panel.rotation_degrees = -15.0


func _notehead_lift_color_local(c: Color, amount: float) -> Color:
	return Color(
		clampf(c.r + amount, 0.0, 1.0),
		clampf(c.g + amount, 0.0, 1.0),
		clampf(c.b + amount, 0.0, 1.0),
		c.a
	)


func _ensure_note_layer_local(panel: Panel, node_name: String, z: int) -> Panel:
	var existing := panel.get_node_or_null(NodePath(node_name))
	if existing != null and existing is Panel:
		var existing_panel := existing as Panel
		existing_panel.z_index = z
		return existing_panel
	var layer := Panel.new()
	layer.name = node_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	var empty := StyleBoxEmpty.new()
	layer.add_theme_stylebox_override("panel", empty)
	panel.add_child(layer)
	return layer


func _apply_notehead_shimmer_local(panel: Panel, base_color: Color) -> void:
	if panel == null:
		return
	var shimmer_a := _ensure_note_layer_local(panel, "MatShimmerA", 3)
	var shimmer_b := _ensure_note_layer_local(panel, "MatShimmerB", 3)
	shimmer_a.visible = RHYTHM_NOTEHEAD_SHIMMER_ENABLED
	shimmer_b.visible = RHYTHM_NOTEHEAD_SHIMMER_ENABLED
	var shimmer_key := "%0.3f|%0.3f|%0.3f|%0.3f|%0.1f|%0.1f" % [base_color.r, base_color.g, base_color.b, base_color.a, panel.size.x, panel.size.y]
	var old_tween_variant: Variant = null
	var old_key := ""
	if panel.has_meta("note_shimmer_tween"):
		old_tween_variant = panel.get_meta("note_shimmer_tween")
	if panel.has_meta("note_shimmer_key"):
		old_key = str(panel.get_meta("note_shimmer_key"))
	if RHYTHM_NOTEHEAD_SHIMMER_ENABLED and old_key == shimmer_key and old_tween_variant != null and old_tween_variant is Tween:
		var running_tween := old_tween_variant as Tween
		if running_tween != null and is_instance_valid(running_tween):
			return
	if old_tween_variant != null and old_tween_variant is Tween:
		var old_tween := old_tween_variant as Tween
		if old_tween != null and is_instance_valid(old_tween):
			old_tween.kill()
	panel.set_meta("note_shimmer_tween", null)
	panel.set_meta("note_shimmer_key", shimmer_key)
	if not RHYTHM_NOTEHEAD_SHIMMER_ENABLED:
		return
	var w := panel.size.x
	var h := panel.size.y
	shimmer_a.size = Vector2(w * 0.30, h * 0.86)
	shimmer_a.position = Vector2(w * 0.10, h * 0.06)
	var sa := StyleBoxFlat.new()
	sa.bg_color = _notehead_lift_color_local(base_color, 0.34)
	sa.bg_color.a = 0.12
	var ra := int(round(shimmer_a.size.y * 0.46))
	sa.corner_radius_top_left = ra
	sa.corner_radius_top_right = ra
	sa.corner_radius_bottom_left = ra
	sa.corner_radius_bottom_right = ra
	shimmer_a.add_theme_stylebox_override("panel", sa)
	shimmer_b.size = Vector2(w * 0.18, h * 0.74)
	shimmer_b.position = Vector2(w * 0.56, h * 0.14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _notehead_lift_color_local(base_color, 0.42)
	sb.bg_color.a = 0.07
	var rb := int(round(shimmer_b.size.y * 0.46))
	sb.corner_radius_top_left = rb
	sb.corner_radius_top_right = rb
	sb.corner_radius_bottom_left = rb
	sb.corner_radius_bottom_right = rb
	shimmer_b.add_theme_stylebox_override("panel", sb)
	var loop := create_tween()
	loop.set_loops()
	loop.tween_property(shimmer_a, "modulate:a", 0.55, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(shimmer_b, "modulate:a", 0.40, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(shimmer_a, "position:x", w * 0.20, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(shimmer_b, "position:x", w * 0.46, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(shimmer_a, "modulate:a", 0.22, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(shimmer_b, "modulate:a", 0.12, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(shimmer_a, "position:x", w * 0.10, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(shimmer_b, "position:x", w * 0.56, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	panel.set_meta("note_shimmer_tween", loop)


func _apply_notehead_material_local(panel: Panel, base_color: Color, border_color: Color, open_note: bool = false, gloss_alpha: float = 0.62) -> void:
	if panel == null:
		return
	var rx := int(round(maxf(6.0, panel.size.x * 0.5)))
	var body := StyleBoxFlat.new()
	body.bg_color = base_color
	body.corner_radius_top_left = rx
	body.corner_radius_top_right = rx
	body.corner_radius_bottom_left = rx
	body.corner_radius_bottom_right = rx
	var border_w := 3 if open_note else 2
	body.border_width_left = border_w
	body.border_width_top = border_w
	body.border_width_right = border_w
	body.border_width_bottom = border_w
	body.border_color = border_color
	panel.add_theme_stylebox_override("panel", body)
	var shadow := _ensure_note_layer_local(panel, "MatShadow", -2)
	shadow.size = panel.size + Vector2(8, 6)
	shadow.position = Vector2(-2, 2)
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	shadow_sb.corner_radius_top_left = rx
	shadow_sb.corner_radius_top_right = rx
	shadow_sb.corner_radius_bottom_left = rx
	shadow_sb.corner_radius_bottom_right = rx
	shadow.add_theme_stylebox_override("panel", shadow_sb)
	var gloss := _ensure_note_layer_local(panel, "MatGloss", 2)
	gloss.size = Vector2(panel.size.x * 0.52, panel.size.y * 0.34)
	gloss.position = Vector2(panel.size.x * 0.16, panel.size.y * 0.12)
	var gloss_sb := StyleBoxFlat.new()
	gloss_sb.bg_color = _notehead_lift_color_local(base_color, 0.28)
	gloss_sb.bg_color.a = gloss_alpha
	var gr := int(round(gloss.size.y * 0.9))
	gloss_sb.corner_radius_top_left = gr
	gloss_sb.corner_radius_top_right = gr
	gloss_sb.corner_radius_bottom_left = gr
	gloss_sb.corner_radius_bottom_right = gr
	gloss.add_theme_stylebox_override("panel", gloss_sb)
	_apply_notehead_shimmer_local(panel, base_color)


func _draw_miss_x() -> void:
	var c := Color(1.0, 0.32, 0.32, 0.95)
	var p := _note_center()
	draw_line(p + Vector2(-13, -13), p + Vector2(13, 13), c, 2.4)
	draw_line(p + Vector2(13, -13), p + Vector2(-13, 13), c, 2.4)


func _ellipse_points(center: Vector2, rx: float, ry: float, segments: int, rotation_rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cos_r := cos(rotation_rad)
	var sin_r := sin(rotation_rad)
	for i in range(segments):
		var t := TAU * float(i) / float(maxi(1, segments))
		var ex := cos(t) * rx
		var ey := sin(t) * ry
		var px := (ex * cos_r) - (ey * sin_r)
		var py := (ex * sin_r) + (ey * cos_r)
		pts.append(center + Vector2(px, py))
	return pts


func _draw_closed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		draw_line(a, b, color, width, true)


func _rest_fill() -> Color:
	return Color(0.96, 0.93, 0.80, 0.98)


func _draw_mat_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var shadow := Color(0.04, 0.08, 0.02, 0.48)
	var hi := _notehead_lift_color_local(color, 0.20)
	hi.a = minf(color.a, 0.42)
	draw_line(a + Vector2(0.8, 0.8), b + Vector2(0.8, 0.8), shadow, width + 0.6, true)
	draw_line(a, b, color, width, true)
	draw_line(a + Vector2(-0.15, -0.15), b + Vector2(-0.15, -0.15), hi, maxf(0.9, width * 0.34), true)


func _draw_mat_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var shadow_points := PackedVector2Array()
	for p in points:
		shadow_points.append(p + Vector2(0.8, 0.8))
	draw_polyline(shadow_points, Color(0.04, 0.08, 0.02, 0.48), width + 0.8, true)
	draw_polyline(points, color, width, true)
	draw_polyline(points, _notehead_lift_color_local(color, 0.18), maxf(0.8, width * 0.32), true)


func _draw_mat_beam_polygon(pts: PackedVector2Array, color: Color) -> void:
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(0.8, 0.8))
	draw_colored_polygon(shadow_pts, Color(0.04, 0.08, 0.02, 0.42))
	draw_colored_polygon(pts, color)
	# Top sheen strip (Note Flow-like gloss feel for beams)
	if pts.size() >= 4:
		var top_a := pts[0]
		var top_b := pts[1]
		_draw_mat_line(top_a, top_b, _notehead_lift_color_local(color, 0.12), 0.9)
	_draw_closed_polyline(pts, Color(0.08, 0.12, 0.04, 0.35), 0.5)


func _draw_flag_polygon(pts: PackedVector2Array, color: Color) -> void:
	# Flat-colored flag so it matches the stem color exactly.
	draw_colored_polygon(pts, color)


func _draw_flag_curve(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, width, true)


func _draw_stem_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# Flat stem line so it visually matches flag color exactly.
	draw_line(a, b, color, width, true)


func _draw_mat_rect(r: Rect2, fill: Color, border: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(0.8, 0.8), r.size), Color(0.04, 0.08, 0.02, 0.35))
	draw_rect(r, fill)
	var gloss_r := Rect2(r.position + Vector2(1.0, 0.8), Vector2(maxf(2.0, r.size.x - 2.0), maxf(1.0, r.size.y * 0.45)))
	draw_rect(gloss_r, Color(1.0, 1.0, 0.9, 0.16))
	draw_rect(r, border, false, 1.6)


func _draw_mat_dot(pos: Vector2, color: Color, radius: float) -> void:
	draw_circle(pos + Vector2(0.7, 0.7), radius, Color(0.04, 0.08, 0.02, 0.42))
	draw_circle(pos, radius, color)
	draw_circle(pos + Vector2(-0.5, -0.4), maxf(0.6, radius * 0.36), Color(1.0, 1.0, 0.9, 0.28))
