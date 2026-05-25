extends Control
class_name StaffRenderer

# Reusable music-staff rendering Control.
#
# Phase 2 features (Session 2-3 work):
#   - Multi-staff (grand staff) layout with brace + connecting bar lines
#   - Event-based note rendering: groups simultaneous notes into chord clusters
#   - Gould seconds-offset rule for adjacent noteheads in chords
#   - Beam algorithm for grouped eighths/sixteenths (slope follows pitch contour)
#   - Optical (variable-width) note spacing approximating Gould's recommendations
#   - Per-event accidental stacking with collision avoidance
#   - SMuFL glyphs throughout (clefs, noteheads, accidentals, time-sig digits, rests)
#   - Highlight cursor for playback (one event glows accent gold)
#   - cluster_mode flag for chord-explorer-style "no rhythm, just stacked noteheads"
#
# Score input format (built via score_model.gd):
#   { staves: [ {clef, measures: [ {notes: [ {midi, duration_beats, beat_offset, rest, voice} ]} ]} ],
#     key_fifths, key_is_minor, time_sig_num, time_sig_den, tempo_bpm, highlight_index }

const SMuFLFont = preload("res://scripts/score_engine/smufl_font.gd")

# --- Public config ---
var score: Dictionary = {}
var line_color: Color = Color(0.13, 0.16, 0.22, 1.0)
var note_color: Color = Color(0.13, 0.16, 0.22, 1.0)
var highlight_color: Color = Color(0.95, 0.65, 0.16, 1.0)
var ledger_color: Color = Color(0.30, 0.34, 0.42, 0.85)
var staff_space: float = 11.0
var paper_color: Color = Color(0.99, 0.98, 0.95, 1.0)
var draw_paper: bool = false
# When true, rhythm is ignored — every notehead is drawn as a whole note with no stems/flags/beams.
# Chord Explorer uses this to display played chords as stacked notation without rhythmic interpretation.
var cluster_mode: bool = false
# Vertical gap between staves in a grand staff, measured in staff spaces.
var inter_staff_gap_spaces: float = 4.5
# Multi-system layout fallback when adaptive wrapping is off.
var bars_per_system: int = 4
# Adaptive wrapping packs each line by screen width and rhythmic density.
var auto_bars_per_system: bool = true
# Minimum comfortable bar width (in pixels) when computing adaptive bars-per-line.
# Smaller → more bars per line (denser). Larger → fewer bars per line (more spacious).
var min_bar_width_px: float = 140.0
# Cap on adaptive bars-per-line so very wide monitors don't end up with 20 bars
# of tiny eighth-notes per line.
var max_bars_per_system: int = 6
var target_events_per_system: int = 18
# Vertical gap between successive systems, in staff spaces.
var system_vertical_gap_spaces: float = 6.0
# Extra page margin for ledger notes, fingerings, and 8va markings.
var page_top_margin_spaces: float = 8.0
var page_bottom_margin_spaces: float = 5.0
var sight_feedback_colors: Dictionary = {
	0: Color(0.36, 0.82, 0.46, 1.0),
	1: Color(0.95, 0.84, 0.30, 1.0),
	2: Color(0.95, 0.60, 0.22, 1.0),
	3: Color(0.95, 0.30, 0.32, 1.0),
	4: Color(0.42, 0.72, 0.95, 1.0),
}
var pitch_curve_color: Color = Color(0.18, 0.82, 1.0, 0.78)
var pitch_curve_draw_under_staff: bool = true

# --- Engraving-rule constants ---
const SHARP_ORDER := ["F", "C", "G", "D", "A", "E", "B"]
const FLAT_ORDER := ["B", "E", "A", "D", "G", "C", "F"]
const LETTER_INDEX := {"C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6}
const PC_TO_NATURAL_LETTER := {0: "C", 1: "C", 2: "D", 3: "D", 4: "E", 5: "F", 6: "F", 7: "G", 8: "G", 9: "A", 10: "A", 11: "B"}
# Set by _draw_score on every render; consulted by _pc_to_letter() below so
# black keys are spelled in line with the active key signature. In flat keys
# (e.g., G minor, key_fifths=-2) pc=3 (E♭/D♯) must land on the E line, not the
# D line — otherwise an E♭ from a G-minor scale renders as "D♭" on the staff.
var _active_key_fifths: int = 0
# Optical spacing weights (Gould-ish approximation; relative widths per duration).
const OPTICAL_WIDTH := {
	4.0: 4.5,   # whole
	2.0: 3.0,   # half
	1.5: 2.4,   # dotted quarter
	1.0: 2.0,   # quarter
	0.5: 1.3,   # eighth
	0.25: 0.85, # sixteenth
}
const CLEF_BASELINE_NUDGE_SPACES := -0.48
const KEY_SIGNATURE_BASELINE_NUDGE_SPACES := -0.28
const TIME_SIGNATURE_BASELINE_NUDGE_SPACES := -0.86
const BASS_TO_TREBLE_MIN_MIDI := 67 # G4. Three bass-ledger-line passages read better in treble clef.
const BASS_TO_TREBLE_FORCE_LEDGER_COUNT := 4
const TREBLE_8VA_MIN_MIDI := 84 # C6. Sustained passages above B5 read better with 8va.

# --- Internal layout state (recomputed each draw) ---
var _content_x_start: float = 0.0
var _content_x_end: float = 0.0


func _ready() -> void:
	resized.connect(_on_resized)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SMuFLFont.register_change_listener(Callable(self, "_on_smufl_font_changed"))


func _exit_tree() -> void:
	SMuFLFont.unregister_change_listener(Callable(self, "_on_smufl_font_changed"))


func _on_smufl_font_changed() -> void:
	queue_redraw()


func _on_resized() -> void:
	_update_required_height_for_systems()
	queue_redraw()


func set_score(s: Dictionary) -> void:
	score = s
	_update_required_height_for_systems()
	queue_redraw()


# Dynamically grow custom_minimum_size.y so the renderer reports the right height
# when a multi-system score requires multiple lines. Parent containers (PanelContainer,
# VBox) expand to honor this. We never shrink — only grow — so a score with fewer
# bars later in the session doesn't suddenly squish the panel.
func _update_required_height_for_systems() -> void:
	if score.is_empty():
		return
	var staves: Array = score.get("staves", [])
	if staves.is_empty():
		return
	var measure_count: int = _measure_count_for_staves(staves)
	if measure_count <= 0:
		return
	var staff_count: int = staves.size()
	var staff_h: float = staff_space * 4.0
	var inter_staff: float = staff_space * inter_staff_gap_spaces
	var per_system_h: float = float(staff_count) * staff_h + float(maxi(0, staff_count - 1)) * inter_staff
	var system_gap: float = staff_space * system_vertical_gap_spaces
	var staff_x := 24.0
	var staff_w: float = _layout_width() - staff_x - 28.0
	var system_ranges := _layout_system_ranges(
		staves,
		measure_count,
		staff_w,
		staff_count,
		int(score.get("key_fifths", 0)),
		int(score.get("time_sig_num", 4)),
		int(score.get("time_sig_den", 4))
	)
	var system_count: int = maxi(1, system_ranges.size())
	var top_margin: float = staff_space * page_top_margin_spaces
	var bottom_margin: float = staff_space * page_bottom_margin_spaces
	var systems_h: float = float(system_count) * per_system_h + float(maxi(0, system_count - 1)) * system_gap
	var total_h: float = top_margin + systems_h + bottom_margin
	var target_h := maxf(220.0, total_h)
	if absf(target_h - custom_minimum_size.y) > 1.0:
		custom_minimum_size = Vector2(custom_minimum_size.x, target_h)


func _layout_width() -> float:
	var w := size.x
	if w < 100.0:
		w = custom_minimum_size.x
	if w < 100.0:
		w = 900.0
	return w


func _measure_count_for_staves(staves: Array) -> int:
	var measure_count := 1
	for staff in staves:
		var measures: Array = (staff as Dictionary).get("measures", [])
		if measures.size() > measure_count:
			measure_count = measures.size()
	return measure_count


func _prelude_width(staff_count: int, key_fifths: int, time_num: int, time_den: int, include_time_signature: bool) -> float:
	var brace_w: float = staff_space * 1.4 if staff_count >= 2 else 0.0
	var clef_w: float = staff_space * 2.6
	var key_w: float = float(absi(key_fifths)) * staff_space * 0.95
	var ts_w: float = staff_space * float(maxi(str(time_num).length(), str(time_den).length())) * 1.4
	if include_time_signature:
		return brace_w + 8.0 + clef_w + 8.0 + key_w + 8.0 + ts_w + 14.0
	return brace_w + 8.0 + clef_w + 8.0 + key_w + 14.0


func _measure_layout_stats(staves: Array, measure_idx: int) -> Dictionary:
	var events_by_beat: Dictionary = {}
	for staff_any in staves:
		var staff: Dictionary = staff_any
		var measures: Array = staff.get("measures", [])
		if measure_idx < 0 or measure_idx >= measures.size():
			continue
		var measure: Dictionary = measures[measure_idx]
		var notes_in_bar: Array = measure.get("notes", [])
		for ev_any in _collect_events(notes_in_bar):
			var ev: Dictionary = ev_any
			var notes: Array = ev.get("notes", [])
			var has_note := false
			for note_any in notes:
				var note: Dictionary = note_any
				if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
					has_note = true
					break
			var weight := _optical_width_for(float(ev.get("duration_beats", 0.5)))
			if not has_note:
				weight *= 0.55
			weight += maxf(0.0, float(notes.size() - 1)) * 0.35
			var key := _event_x_key(float(ev.get("beat_offset", 0.0)))
			events_by_beat[key] = maxf(float(events_by_beat.get(key, 0.0)), weight)
	var total_weight := 0.0
	for key in events_by_beat.keys():
		total_weight += float(events_by_beat[key])
	var event_count := events_by_beat.size()
	if event_count <= 0:
		event_count = 1
		total_weight = _optical_width_for(4.0) * 0.65
	return {
		"events": event_count,
		"weight": maxf(1.0, total_weight),
	}


func _measure_raw_width_px(staves: Array, measure_idx: int) -> float:
	var stats := _measure_layout_stats(staves, measure_idx)
	var event_count := int(stats.get("events", 1))
	var weight := float(stats.get("weight", 1.0))
	var base_px := staff_space * 7.0
	var event_px := float(event_count) * staff_space * 1.55
	var weight_px := weight * staff_space * 1.20
	return maxf(min_bar_width_px, base_px + event_px + weight_px)


func _measure_widths_for_range(staves: Array, first_bar: int, last_bar_exclusive: int) -> Array:
	var widths: Array = []
	for bar_idx in range(first_bar, last_bar_exclusive):
		widths.append(_measure_raw_width_px(staves, bar_idx))
	return widths


func _layout_system_ranges(staves: Array, measure_count: int, staff_w: float, staff_count: int, key_fifths: int, time_num: int, time_den: int) -> Array:
	var ranges: Array = []
	var first_bar := 0
	if not auto_bars_per_system:
		var fixed_bars := maxi(1, bars_per_system) if bars_per_system > 0 else measure_count
		while first_bar < measure_count:
			var last_fixed := mini(first_bar + fixed_bars, measure_count)
			ranges.append({"first_bar": first_bar, "last_bar_exclusive": last_fixed})
			first_bar = last_fixed
		return ranges
	while first_bar < measure_count:
		var include_time := ranges.is_empty()
		var available_w := maxf(min_bar_width_px, staff_w - _prelude_width(staff_count, key_fifths, time_num, time_den, include_time))
		var used_w := 0.0
		var used_events := 0
		var last_bar := first_bar
		while last_bar < measure_count:
			var stats := _measure_layout_stats(staves, last_bar)
			var measure_events := int(stats.get("events", 1))
			var measure_w := _measure_raw_width_px(staves, last_bar)
			var bars_on_line := last_bar - first_bar
			var exceeds_width := bars_on_line > 0 and used_w + measure_w > available_w
			var exceeds_events := bars_on_line > 0 and used_events + measure_events > target_events_per_system
			var exceeds_bar_cap := bars_on_line > 0 and bars_on_line >= max_bars_per_system
			if exceeds_width or exceeds_events or exceeds_bar_cap:
				break
			used_w += measure_w
			used_events += measure_events
			last_bar += 1
		if last_bar == first_bar:
			last_bar += 1
		ranges.append({"first_bar": first_bar, "last_bar_exclusive": last_bar})
		first_bar = last_bar
	return ranges


func get_scroll_y_for_beat(beat_offset: float) -> int:
	if score.is_empty():
		return 0
	var staves: Array = score.get("staves", [])
	if staves.is_empty():
		return 0
	var time_num: int = int(score.get("time_sig_num", 4))
	var time_den: int = int(score.get("time_sig_den", 4))
	var beats_per_bar: float = float(time_num) * (4.0 / float(time_den))
	var measure_count := _measure_count_for_staves(staves)
	var target_bar := clampi(int(floor(maxf(0.0, beat_offset) / maxf(0.001, beats_per_bar))), 0, maxi(0, measure_count - 1))
	var staff_count := staves.size()
	var staff_height: float = staff_space * 4.0
	var inter_staff_gap: float = staff_space * inter_staff_gap_spaces
	var per_system_h: float = float(staff_count) * staff_height + float(maxi(0, staff_count - 1)) * inter_staff_gap
	var system_gap: float = staff_space * system_vertical_gap_spaces
	var staff_x := 24.0
	var staff_w: float = _layout_width() - staff_x - 28.0
	var ranges := _layout_system_ranges(staves, measure_count, staff_w, staff_count, int(score.get("key_fifths", 0)), time_num, time_den)
	var top_margin: float = staff_space * page_top_margin_spaces
	var bottom_margin: float = staff_space * page_bottom_margin_spaces
	var systems_h: float = float(ranges.size()) * per_system_h + float(maxi(0, ranges.size() - 1)) * system_gap
	var total_h: float = top_margin + systems_h + bottom_margin
	var first_system_top: float = (size.y - total_h) * 0.5 + top_margin
	if total_h > size.y - 24.0:
		first_system_top = top_margin
	first_system_top = maxf(top_margin, first_system_top)
	for sys_idx in range(ranges.size()):
		var r: Dictionary = ranges[sys_idx]
		if target_bar >= int(r.get("first_bar", 0)) and target_bar < int(r.get("last_bar_exclusive", 0)):
			var system_top := first_system_top + float(sys_idx) * (per_system_h + system_gap)
			return int(maxf(0.0, system_top - staff_space * 3.0))
	return 0


func set_highlight_index(idx: int) -> void:
	if not score.is_empty():
		score["highlight_index"] = idx
		score["highlight_beat"] = -1.0
	queue_redraw()


func set_highlight_beat(beat_offset: float) -> void:
	if not score.is_empty():
		score["highlight_index"] = -1
		score["highlight_beat"] = float(beat_offset)
	queue_redraw()


func set_note_bands(bands: Dictionary) -> void:
	if not score.is_empty():
		score["note_bands"] = bands.duplicate()
	queue_redraw()


func set_pitch_curve_points(points: Array) -> void:
	if not score.is_empty():
		score["pitch_curve"] = points.duplicate(true)
	queue_redraw()


# --- Top-level draw ---

func _draw() -> void:
	if draw_paper:
		draw_rect(Rect2(Vector2.ZERO, size), paper_color, true)
	if score.is_empty():
		_draw_empty_staff()
		return
	var staves: Array = score.get("staves", [])
	if staves.is_empty():
		_draw_empty_staff()
		return
	_draw_score(staves)


func _draw_empty_staff() -> void:
	var top := size.y * 0.45
	var x := 64.0
	var w := size.x - x - 24.0
	for i in range(5):
		var y := top + i * staff_space
		draw_line(Vector2(x, y), Vector2(x + w, y), line_color, 1.5)


func _draw_score(staves: Array) -> void:
	var staff_count: int = staves.size()
	var staff_height: float = staff_space * 4.0
	var inter_staff_gap: float = staff_space * inter_staff_gap_spaces
	var per_system_h: float = float(staff_count) * staff_height + float(maxi(0, staff_count - 1)) * inter_staff_gap
	var system_gap: float = staff_space * system_vertical_gap_spaces
	var key_fifths: int = int(score.get("key_fifths", 0))
	# Capture the active key signature so the per-pitch spelling helpers downstream
	# (_pc_to_letter, _midi_to_staff_y, _midi_letter_index, _accidental_for_pitch)
	# can place black keys on the correct staff line.
	_active_key_fifths = key_fifths
	var time_num: int = int(score.get("time_sig_num", 4))
	var time_den: int = int(score.get("time_sig_den", 4))

	var measure_count: int = _measure_count_for_staves(staves)
	var staff_x: float = 24.0
	var staff_w: float = _layout_width() - staff_x - 28.0
	var system_ranges := _layout_system_ranges(staves, measure_count, staff_w, staff_count, key_fifths, time_num, time_den)
	var system_count: int = maxi(1, system_ranges.size())

	# Vertical positioning: total stack of systems centered (or top-aligned if too tall).
	var top_margin: float = staff_space * page_top_margin_spaces
	var bottom_margin: float = staff_space * page_bottom_margin_spaces
	var systems_h: float = float(system_count) * per_system_h + float(maxi(0, system_count - 1)) * system_gap
	var total_h: float = top_margin + systems_h + bottom_margin
	var first_system_top: float = (size.y - total_h) * 0.5 + top_margin
	if total_h > size.y - 24.0:
		first_system_top = top_margin  # top-align when content exceeds available height
	first_system_top = maxf(top_margin, first_system_top)

	# Per-system prelude widths: clef + key sig always; time signature only on system 0
	# (standard engraving convention).
	var brace_w: float = staff_space * 1.4 if staff_count >= 2 else 0.0
	var clef_w: float = staff_space * 2.6
	var key_w: float = float(absi(key_fifths)) * staff_space * 0.95
	var ts_w: float = staff_space * float(maxi(str(time_num).length(), str(time_den).length())) * 1.4
	var prelude_w_first: float = brace_w + 8.0 + clef_w + 8.0 + key_w + 8.0 + ts_w + 14.0
	var prelude_w_other: float = brace_w + 8.0 + clef_w + 8.0 + key_w + 14.0

	var beats_per_bar: float = float(time_num) * (4.0 / float(time_den))

	# Accumulated global event index across systems — needed so highlight_index
	# tracks correctly during playback (which walks events linearly through the score).
	var per_staff_event_offsets: Array[int] = []
	for i in range(staff_count):
		per_staff_event_offsets.append(0)

	for sys_idx in range(system_count):
		var system_range: Dictionary = system_ranges[sys_idx] if sys_idx < system_ranges.size() else {"first_bar": 0, "last_bar_exclusive": measure_count}
		var first_bar: int = int(system_range.get("first_bar", 0))
		var last_bar_exclusive: int = int(system_range.get("last_bar_exclusive", measure_count))
		var system_top: float = first_system_top + float(sys_idx) * (per_system_h + system_gap)

		var staff_tops: Array[float] = []
		for i in range(staff_count):
			staff_tops.append(system_top + float(i) * (staff_height + inter_staff_gap))

		var prelude_w: float = prelude_w_first if sys_idx == 0 else prelude_w_other
		var content_x_start: float = staff_x + prelude_w
		var content_x_end: float = staff_x + staff_w
		# Stash on instance so other helpers reading _content_x_* still work (last system wins; harmless).
		_content_x_start = content_x_start
		_content_x_end = content_x_end

		var system_bar_count: int = last_bar_exclusive - first_bar
		if system_bar_count <= 0:
			continue
		var notes_w: float = content_x_end - content_x_start
		var raw_widths := _measure_widths_for_range(staves, first_bar, last_bar_exclusive)
		var raw_total := 0.0
		for raw_w_any in raw_widths:
			raw_total += maxf(1.0, float(raw_w_any))
		if raw_total <= 0.0:
			raw_total = float(system_bar_count)
		var bar_x_positions: Array[float] = []
		var cur_bar_x := content_x_start
		bar_x_positions.append(cur_bar_x)
		for raw_w_any in raw_widths:
			var scaled_w := (maxf(1.0, float(raw_w_any)) / raw_total) * notes_w
			cur_bar_x += scaled_w
			bar_x_positions.append(cur_bar_x)

		# Brace (per system) when grand staff
		if staff_count >= 2:
			_draw_grand_staff_brace(staff_x, staff_tops[0], staff_tops[staff_count - 1] + staff_height)

		# Bar lines: through all staves (grand) or per staff (single)
		var is_last_system: bool = sys_idx == system_count - 1
		for b in range(bar_x_positions.size()):
			var bx: float = bar_x_positions[b]
			# Only the very LAST bar of the LAST system gets the final-double-bar.
			var is_final_of_piece: bool = is_last_system and (b == bar_x_positions.size() - 1)
			if staff_count >= 2:
				var top_y: float = staff_tops[0]
				var bot_y: float = staff_tops[staff_count - 1] + staff_height
				if is_final_of_piece:
					draw_line(Vector2(bx - 4.0, top_y), Vector2(bx - 4.0, bot_y), line_color, 1.4)
					draw_line(Vector2(bx, top_y), Vector2(bx, bot_y), line_color, 3.0)
				else:
					draw_line(Vector2(bx, top_y), Vector2(bx, bot_y), line_color, 1.4)
			else:
				for i in range(staff_count):
					var top_y_s: float = staff_tops[i]
					var bot_y_s: float = top_y_s + staff_height
					if is_final_of_piece:
						draw_line(Vector2(bx - 4.0, top_y_s), Vector2(bx - 4.0, bot_y_s), line_color, 1.4)
						draw_line(Vector2(bx, top_y_s), Vector2(bx, bot_y_s), line_color, 3.0)
					else:
						draw_line(Vector2(bx, top_y_s), Vector2(bx, bot_y_s), line_color, 1.4)

		# Build per-system shared event maps (grand-staff RH/LH alignment within the system)
		var system_staves: Array = []
		for st in staves:
			var sliced := (st as Dictionary).duplicate()
			sliced["measures"] = (st["measures"] as Array).slice(first_bar, last_bar_exclusive)
			system_staves.append(sliced)
		var shared_event_x_maps: Array = []
		if staff_count >= 2:
			shared_event_x_maps = _build_shared_event_x_maps(system_staves, system_bar_count, bar_x_positions, beats_per_bar)

		# Per staff: lines, clef, key sig, (time sig on first system only), notes
		for i in range(staff_count):
			var staff: Dictionary = staves[i]
			var top_y_draw: float = staff_tops[i]
			_draw_staff_lines(top_y_draw, staff_x, staff_w)
			var x_after_clef: float = _draw_clef(str(staff.get("clef", "treble")), staff_x + brace_w + 8.0, top_y_draw)
			var x_after_key: float = _draw_key_signature(str(staff.get("clef", "treble")), key_fifths, x_after_clef + 6.0, top_y_draw)
			if sys_idx == 0:
				_draw_time_signature(time_num, time_den, x_after_key + 8.0, top_y_draw)
			var system_staff: Dictionary = system_staves[i]
			# Pass the running event index so highlighting tracks correctly across systems.
			per_staff_event_offsets[i] = _draw_staff_notes_subset(system_staff, top_y_draw, bar_x_positions, 0.0, key_fifths, i, shared_event_x_maps, per_staff_event_offsets[i])

	# Adaptive height: if width-driven system wrapping changed after layout,
	# defer-grow custom_minimum_size so parent layouts give us the room.
	if total_h > custom_minimum_size.y + 1.0:
		call_deferred("_apply_min_height_grow", total_h)


func _apply_min_height_grow(target_h: float) -> void:
	if target_h > custom_minimum_size.y:
		custom_minimum_size = Vector2(custom_minimum_size.x, target_h)


func _draw_staff_lines(top_y: float, staff_x: float, staff_w: float) -> void:
	for i in range(5):
		var y: float = top_y + float(i) * staff_space
		draw_line(Vector2(staff_x, y), Vector2(staff_x + staff_w, y), line_color, 1.6)


# --- Grand staff brace ---

func _draw_grand_staff_brace(x: float, top_y: float, bottom_y: float) -> void:
	# Draw a curved brace using a polyline (more reliable than scaling a font glyph).
	var width: float = staff_space * 1.0
	var center_y: float = (top_y + bottom_y) * 0.5
	var height: float = bottom_y - top_y
	var pts := PackedVector2Array()
	# Sample a curved S-shape brace — two arcs meeting at the center.
	var num_segs := 24
	for i in range(num_segs + 1):
		var t: float = float(i) / float(num_segs)
		var y: float = top_y + t * height
		# Curvature peaks at the top, middle, and bottom; pinches at quarter points.
		var phase: float = t * TAU
		var bulge: float = sin(phase) * 0.45 + sin(phase * 0.5) * 0.35
		var px: float = x + width * (0.4 + bulge * 0.6)
		pts.append(Vector2(px, y))
	# Mirror to the other side and draw filled.
	var mirror := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		mirror.append(Vector2(x + (x - p.x) * 0.0 + (width - (p.x - x)) * 0.0 + (width * 0.65), p.y))
	# Simpler approach: draw as a thick polyline with rounded ends.
	# Use draw_polyline with a wide width so it appears as a brace.
	draw_polyline(pts, line_color, maxf(2.0, staff_space * 0.20), true)
	# Add small caps at top and bottom so the brace looks anchored.
	draw_circle(Vector2(pts[0].x, top_y), staff_space * 0.18, line_color)
	draw_circle(Vector2(pts[pts.size() - 1].x, bottom_y), staff_space * 0.18, line_color)


# --- Clef rendering ---

func _draw_clef(clef: String, x: float, staff_top: float) -> float:
	var font := SMuFLFont.get_font()
	var glyph := SMuFLFont.glyph("gClef" if clef == "treble" else "fClef")
	var glyph_size := int(staff_space * 4.0)
	var baseline_y: float
	if clef == "treble":
		baseline_y = staff_top + 3.5 * staff_space
	else:
		baseline_y = staff_top + 1.5 * staff_space
	baseline_y += CLEF_BASELINE_NUDGE_SPACES * staff_space
	draw_string(font, Vector2(x, baseline_y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, line_color)
	return x + staff_space * 2.6


# --- Key signature rendering ---

func _draw_key_signature(clef: String, fifths: int, x: float, staff_top: float) -> float:
	if fifths == 0:
		return x
	var font := SMuFLFont.get_font()
	var glyph_size := int(staff_space * 4.0)
	var glyph_name := "accidentalSharp" if fifths > 0 else "accidentalFlat"
	var glyph := SMuFLFont.glyph(glyph_name)
	var letters := SHARP_ORDER if fifths > 0 else FLAT_ORDER
	var count := mini(absi(fifths), 7)
	var advance := staff_space * 0.95
	var cur_x := x
	for i in range(count):
		var letter: String = letters[i]
		var y := _key_sig_y_for_letter(letter, clef, fifths > 0, staff_top)
		var baseline_y := y + (staff_space * (0.4 + KEY_SIGNATURE_BASELINE_NUDGE_SPACES))
		draw_string(font, Vector2(cur_x, baseline_y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, line_color)
		cur_x += advance
	return cur_x


func _key_sig_y_for_letter(letter: String, clef: String, is_sharp: bool, staff_top: float) -> float:
	var ref_letter_idx: int = (5 * 7 + 3) if clef == "treble" else (3 * 7 + 5)  # F5 / A3
	var letter_idx_target := _accidental_target_letter_idx(letter, clef, is_sharp)
	var diatonic_steps := ref_letter_idx - letter_idx_target
	return staff_top + float(diatonic_steps) * (staff_space * 0.5)


func _accidental_target_letter_idx(letter: String, clef: String, is_sharp: bool) -> int:
	if clef == "treble":
		if is_sharp:
			match letter:
				"F": return 5 * 7 + 3
				"C": return 5 * 7 + 0
				"G": return 5 * 7 + 4
				"D": return 5 * 7 + 1
				"A": return 4 * 7 + 5
				"E": return 5 * 7 + 2
				"B": return 4 * 7 + 6
		else:
			match letter:
				"B": return 4 * 7 + 6
				"E": return 5 * 7 + 2
				"A": return 4 * 7 + 5
				"D": return 5 * 7 + 1
				"G": return 4 * 7 + 4
				"C": return 5 * 7 + 0
				"F": return 4 * 7 + 3
	else:
		if is_sharp:
			match letter:
				"F": return 3 * 7 + 3
				"C": return 3 * 7 + 0
				"G": return 3 * 7 + 4
				"D": return 3 * 7 + 1
				"A": return 2 * 7 + 5
				"E": return 3 * 7 + 2
				"B": return 2 * 7 + 6
		else:
			match letter:
				"B": return 2 * 7 + 6
				"E": return 3 * 7 + 2
				"A": return 2 * 7 + 5
				"D": return 3 * 7 + 1
				"G": return 2 * 7 + 4
				"C": return 3 * 7 + 0
				"F": return 2 * 7 + 3
	return 4 * 7


# --- Time signature ---

func _draw_time_signature(num: int, den: int, x: float, staff_top: float) -> float:
	var font := SMuFLFont.get_font()
	var glyph_size := int(staff_space * 4.0)
	var num_glyphs := SMuFLFont.time_sig_glyphs(num)
	var den_glyphs := SMuFLFont.time_sig_glyphs(den)
	var time_sig_y_nudge := TIME_SIGNATURE_BASELINE_NUDGE_SPACES * staff_space
	var num_y := staff_top + staff_space * 1.95 + time_sig_y_nudge
	var den_y := staff_top + staff_space * 3.95 + time_sig_y_nudge
	var col_w := staff_space * float(maxi(str(num).length(), str(den).length())) * 1.4
	var num_x := x + (col_w - staff_space * float(str(num).length()) * 1.4) * 0.5
	var den_x := x + (col_w - staff_space * float(str(den).length()) * 1.4) * 0.5
	draw_string(font, Vector2(num_x, num_y), num_glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, line_color)
	draw_string(font, Vector2(den_x, den_y), den_glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, line_color)
	return x + col_w


# --- Note layout: events + clusters ---

func _event_x_key(beat_offset: float) -> String:
	return "%.3f" % beat_offset


func _build_shared_event_x_maps(staves: Array, measure_count: int, bar_x_positions: Array, beats_per_bar: float) -> Array:
	var maps: Array = []
	for m in range(measure_count):
		var events_by_key: Dictionary = {}
		for staff in staves:
			var measures: Array = (staff as Dictionary).get("measures", [])
			if m >= measures.size():
				continue
			var measure: Dictionary = measures[m]
			var notes_in_bar: Array = measure.get("notes", [])
			if notes_in_bar.is_empty():
				continue
			for ev in _collect_events(notes_in_bar):
				var beat := float(ev.get("beat_offset", 0.0))
				var key := _event_x_key(beat)
				var dur := float(ev.get("duration_beats", 0.5))
				if events_by_key.has(key):
					var existing: Dictionary = events_by_key[key]
					existing["duration_beats"] = maxf(float(existing.get("duration_beats", dur)), dur)
				else:
					events_by_key[key] = {
						"beat_offset": beat,
						"duration_beats": dur,
						"notes": [],
						"rest": false,
						"x": 0.0,
					}
		var shared_events: Array = events_by_key.values()
		shared_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("beat_offset", 0.0)) < float(b.get("beat_offset", 0.0))
		)
		if not shared_events.is_empty():
			var bar_w := float(bar_x_positions[m + 1]) - float(bar_x_positions[m]) if m + 1 < bar_x_positions.size() else min_bar_width_px
			_assign_event_x_positions(shared_events, float(bar_x_positions[m]), bar_w, beats_per_bar, m)
		var x_map: Dictionary = {}
		for ev in shared_events:
			x_map[_event_x_key(float(ev.get("beat_offset", 0.0)))] = float(ev.get("x", 0.0))
		maps.append(x_map)
	return maps


# Multi-system-aware variant. `event_idx_start` is the global event index of the
# first event on this system (so highlight tracking remains consistent across the
# whole piece). Returns the global event index that the NEXT system should start with.
func _draw_staff_notes_subset(staff: Dictionary, staff_top: float, bar_x_positions: Array, bar_w: float, key_fifths: int, staff_idx: int, shared_event_x_maps: Array, event_idx_start: int) -> int:
	var clef: String = str(staff.get("clef", "treble"))
	var measures: Array = staff.get("measures", [])
	var time_num: int = int(score.get("time_sig_num", 4))
	var time_den: int = int(score.get("time_sig_den", 4))
	var beats_per_bar: float = float(time_num) * (4.0 / float(time_den))
	var highlight_index: int = int(score.get("highlight_index", -1))
	var highlight_beat: float = float(score.get("highlight_beat", -1.0))

	var global_event_idx: int = event_idx_start
	var display_state := {"clef": clef, "ottava": 0}
	for m in range(measures.size()):
		var measure: Dictionary = measures[m]
		var notes_in_bar: Array = measure.get("notes", [])
		if notes_in_bar.is_empty():
			continue
		var bar_x: float = bar_x_positions[m]
		var bar_w_actual: float = float(bar_x_positions[m + 1]) - bar_x if m + 1 < bar_x_positions.size() else bar_w
		var events: Array = _collect_events(notes_in_bar)
		if shared_event_x_maps.size() > m:
			var shared_map: Dictionary = shared_event_x_maps[m]
			for ev in events:
				var key := _event_x_key(float(ev.get("beat_offset", 0.0)))
				ev["x"] = float(shared_map.get(key, bar_x + bar_w_actual * 0.5))
		else:
			_assign_event_x_positions(events, bar_x, bar_w_actual, beats_per_bar, m)
		_prepare_event_display(events, clef, display_state)
		_draw_ottava_spans(events, staff_top, clef)
		_draw_pitch_curve_subset(events, staff_top, clef, global_event_idx)
		var beam_groups: Array = []
		if not cluster_mode:
			beam_groups = _collect_beam_groups(events)
		for ev_idx in range(events.size()):
			var event: Dictionary = events[ev_idx]
			var event_beat := float(event.get("beat_offset", 0.0))
			var is_highlighted: bool = global_event_idx == highlight_index or (highlight_beat >= 0.0 and absf(event_beat - highlight_beat) <= 0.001)
			_draw_event(event, clef, key_fifths, staff_top, is_highlighted, global_event_idx)
			global_event_idx += 1
		for bg in beam_groups:
			_draw_beam_group(bg, events, clef, staff_top)
	return global_event_idx


func _draw_staff_notes(staff: Dictionary, staff_top: float, bar_x_positions: Array, bar_w: float, key_fifths: int, staff_idx: int, shared_event_x_maps: Array = []) -> void:
	var clef: String = str(staff.get("clef", "treble"))
	var measures: Array = staff.get("measures", [])
	var time_num: int = int(score.get("time_sig_num", 4))
	var time_den: int = int(score.get("time_sig_den", 4))
	var beats_per_bar: float = float(time_num) * (4.0 / float(time_den))
	var highlight_index: int = int(score.get("highlight_index", -1))
	var highlight_beat: float = float(score.get("highlight_beat", -1.0))

	var global_event_idx := 0
	var display_state := {"clef": clef, "ottava": 0}
	for m in range(measures.size()):
		var measure: Dictionary = measures[m]
		var notes_in_bar: Array = measure.get("notes", [])
		if notes_in_bar.is_empty():
			continue
		var bar_x: float = bar_x_positions[m]
		var bar_w_actual: float = float(bar_x_positions[m + 1]) - bar_x if m + 1 < bar_x_positions.size() else bar_w
		# 1) Group notes by beat_offset → events (each event = chord cluster or single note)
		var events: Array = _collect_events(notes_in_bar)
		# 2) Compute X positions for each event using optical spacing
		if shared_event_x_maps.size() > m:
			var shared_map: Dictionary = shared_event_x_maps[m]
			for ev in events:
				var key := _event_x_key(float(ev.get("beat_offset", 0.0)))
				ev["x"] = float(shared_map.get(key, bar_x + bar_w_actual * 0.5))
		else:
			_assign_event_x_positions(events, bar_x, bar_w_actual, beats_per_bar, m)
		_prepare_event_display(events, clef, display_state)
		_draw_ottava_spans(events, staff_top, clef)
		_draw_pitch_curve_subset(events, staff_top, clef, global_event_idx)
		# 3) Identify beam groups (consecutive eighths/sixteenths in the same beat group)
		var beam_groups: Array = []
		if not cluster_mode:
			beam_groups = _collect_beam_groups(events)
		# 4) Draw each event
		for ev_idx in range(events.size()):
			var event: Dictionary = events[ev_idx]
			var event_beat := float(event.get("beat_offset", 0.0))
			var is_highlighted: bool = global_event_idx == highlight_index or (highlight_beat >= 0.0 and absf(event_beat - highlight_beat) <= 0.001)
			_draw_event(event, clef, key_fifths, staff_top, is_highlighted, global_event_idx)
			global_event_idx += 1
		# 5) Draw beams (after events so they layer on top of stem ends)
		for bg in beam_groups:
			_draw_beam_group(bg, events, clef, staff_top)


func _collect_events(notes: Array) -> Array:
	# Group consecutive notes that share the same beat_offset into "events".
	# An event is { beat_offset, duration_beats, notes[], rest }
	var events: Array = []
	var current_event: Dictionary = {}
	for n in notes:
		var beat: float = float(n.get("beat_offset", 0.0))
		var is_rest: bool = bool(n.get("rest", false))
		if current_event.is_empty() or absf(float(current_event["beat_offset"]) - beat) > 0.001:
			# Start a new event
			current_event = {
				"beat_offset": beat,
				"duration_beats": float(n.get("duration_beats", 0.5)),
				"notes": [],
				"rest": is_rest,
				"x": 0.0,  # filled in later
			}
			events.append(current_event)
		(current_event["notes"] as Array).append(n)
		# If any note in the event is a non-rest, the event isn't a rest.
		if not is_rest:
			current_event["rest"] = false
	return events


func _assign_event_x_positions(events: Array, bar_x: float, bar_w: float, beats_per_bar: float, measure_idx: int) -> void:
	# Optical spacing within a bar: width per event ∝ OPTICAL_WIDTH[duration].
	# Sum widths, then scale to fit available bar width with small margins on either side.
	var total_weight: float = 0.0
	for ev in events:
		total_weight += _optical_width_for(float(ev.get("duration_beats", 0.5)))
	if total_weight <= 0.0:
		total_weight = 1.0
	var inset: float = bar_w * 0.08  # leading inset for clef-side breathing room
	var trailing: float = bar_w * 0.06
	var usable: float = bar_w - inset - trailing
	var cur_x: float = bar_x + inset
	for ev in events:
		var w: float = _optical_width_for(float(ev.get("duration_beats", 0.5))) / total_weight * usable
		ev["x"] = cur_x + w * 0.5  # event center sits at midpoint of its slice
		cur_x += w


func _draw_pitch_curve_subset(events: Array, staff_top: float, clef: String, event_idx_start: int) -> void:
	var points: Array = score.get("pitch_curve", [])
	if points.size() < 2 or events.is_empty():
		return
	var filtered_points: Array = []
	var local_points := PackedVector2Array()
	var first_idx := event_idx_start
	var last_idx := event_idx_start + events.size() - 1
	var min_midi := 999
	var max_midi := -999
	for ev_any in events:
		var ev: Dictionary = ev_any
		var notes: Array = ev.get("notes", [])
		for note_any in notes:
			var note: Dictionary = note_any
			if bool(note.get("rest", false)):
				continue
			var note_midi := int(note.get("midi", -1))
			if note_midi >= 0:
				min_midi = mini(min_midi, note_midi)
				max_midi = maxi(max_midi, note_midi)
	for point_any in points:
		var point: Dictionary = point_any
		var event_pos := float(point.get("event_pos", -1.0))
		if event_pos < float(first_idx) - 0.001 or event_pos > float(last_idx) + 0.001:
			continue
		var curve_midi := int(point.get("midi", 60))
		filtered_points.append({"event_pos": event_pos, "midi": curve_midi})
		min_midi = mini(min_midi, curve_midi)
		max_midi = maxi(max_midi, curve_midi)
	if filtered_points.size() < 2:
		return
	if min_midi > max_midi:
		min_midi = 60
		max_midi = 72
	if max_midi - min_midi < 4:
		min_midi -= 2
		max_midi += 2
	var curve_guide_color := pitch_curve_color
	curve_guide_color.a *= 0.28
	var curve_lane_top := staff_top + staff_space * 5.15
	var curve_lane_h := staff_space * 2.15
	if pitch_curve_draw_under_staff:
		draw_line(
			Vector2(float(events[0].get("x", _content_x_start)), curve_lane_top + curve_lane_h * 0.5),
			Vector2(float(events[events.size() - 1].get("x", _content_x_start)), curve_lane_top + curve_lane_h * 0.5),
			curve_guide_color,
			maxf(1.0, staff_space * 0.06),
			true
		)
	for curve_point_any in filtered_points:
		var curve_point: Dictionary = curve_point_any
		var event_pos := float(curve_point.get("event_pos", -1.0))
		var local_pos := clampf(event_pos - float(first_idx), 0.0, float(maxi(0, events.size() - 1)))
		var idx := clampi(int(floor(local_pos)), 0, events.size() - 1)
		var frac := local_pos - float(idx)
		var ev_a: Dictionary = events[idx]
		var ev_b: Dictionary = events[mini(idx + 1, events.size() - 1)]
		var x := lerpf(float(ev_a.get("x", 0.0)), float(ev_b.get("x", 0.0)), frac)
		var y: float
		if pitch_curve_draw_under_staff:
			var normalized := clampf((float(int(curve_point.get("midi", 60)) - min_midi)) / maxf(1.0, float(max_midi - min_midi)), 0.0, 1.0)
			y = curve_lane_top + curve_lane_h - (normalized * curve_lane_h)
		else:
			var display_clef := str(ev_a.get("display_clef", clef))
			var ottava_shift := int(ev_a.get("ottava_shift", 0))
			y = _midi_to_staff_y(int(curve_point.get("midi", 60)) - ottava_shift, display_clef, staff_top)
		local_points.append(Vector2(x, y))
	if local_points.size() >= 2:
		draw_polyline(local_points, pitch_curve_color, maxf(2.0, staff_space * 0.16), true)
	for p in local_points:
		draw_circle(p, maxf(1.6, staff_space * 0.13), pitch_curve_color)


func _optical_width_for(dur_beats: float) -> float:
	# Find the closest known duration weight; fall back to log-based interpolation.
	var keys := [4.0, 2.0, 1.5, 1.0, 0.5, 0.25]
	var best := 1.0
	var best_diff := INF
	for k in keys:
		var d := absf(dur_beats - float(k))
		if d < best_diff:
			best_diff = d
			best = OPTICAL_WIDTH[float(k)]
	return best


func _prepare_event_display(events: Array, staff_clef: String, display_state: Dictionary) -> void:
	if not display_state.has("clef"):
		display_state["clef"] = staff_clef
	if not display_state.has("ottava"):
		display_state["ottava"] = 0
	for event_idx in range(events.size()):
		var event: Dictionary = events[event_idx]
		if bool(event.get("rest", false)):
			event["display_clef"] = str(display_state.get("clef", staff_clef))
			event["ottava_shift"] = int(display_state.get("ottava", 0))
			event["draw_clef_change"] = false
			event["draw_ottava_mark"] = false
			continue
		var active_clef := str(display_state.get("clef", staff_clef))
		var active_ottava := int(display_state.get("ottava", 0))
		var display_clef := _prepared_display_clef_for_event(events, event_idx, staff_clef, active_clef)
		var ottava_shift := _prepared_ottava_shift_for_event(events, event_idx, display_clef, active_ottava)
		event["display_clef"] = display_clef
		event["ottava_shift"] = ottava_shift
		event["draw_clef_change"] = display_clef != active_clef
		event["draw_ottava_mark"] = ottava_shift > 0 and (ottava_shift != active_ottava or display_clef != active_clef)
		display_state["clef"] = display_clef
		display_state["ottava"] = ottava_shift


func _prepared_display_clef_for_event(events: Array, event_idx: int, staff_clef: String, active_clef: String) -> String:
	var event: Dictionary = events[event_idx]
	var display_clef := _display_clef_for_event(event, staff_clef)
	if staff_clef != "bass" or display_clef != "treble":
		return display_clef
	if active_clef == "treble":
		return "treble"
	var bass_burden := _event_ledger_burden(event, "bass", 0)
	var sustained_high := _has_neighbor_event_at_or_above(events, event_idx, BASS_TO_TREBLE_MIN_MIDI)
	if sustained_high or bass_burden >= BASS_TO_TREBLE_FORCE_LEDGER_COUNT:
		return "treble"
	return staff_clef


func _display_clef_for_event(event: Dictionary, staff_clef: String) -> String:
	if staff_clef == "bass" and _event_max_midi(event) >= BASS_TO_TREBLE_MIN_MIDI:
		var bass_burden := _event_ledger_burden(event, "bass", 0)
		var treble_shift := _ottava_shift_for_event(event, "treble")
		var treble_burden := _event_ledger_burden(event, "treble", treble_shift)
		if treble_burden < bass_burden:
			return "treble"
	return staff_clef


func _ottava_shift_for_event(event: Dictionary, display_clef: String) -> int:
	if display_clef == "treble" and _event_max_midi(event) >= TREBLE_8VA_MIN_MIDI:
		return 12
	return 0


func _prepared_ottava_shift_for_event(events: Array, event_idx: int, display_clef: String, active_ottava: int) -> int:
	var event: Dictionary = events[event_idx]
	var base_shift := _ottava_shift_for_event(event, display_clef)
	if base_shift <= 0:
		return 0
	if active_ottava > 0:
		return base_shift
	# Do not octave-shift a single peak note in an otherwise unshifted scale run.
	# That reads like a wrong-note drop. Reserve 8va for sustained high passages.
	return base_shift if _has_neighbor_event_at_or_above(events, event_idx, TREBLE_8VA_MIN_MIDI) else 0


func _has_neighbor_event_at_or_above(events: Array, event_idx: int, midi_threshold: int) -> bool:
	if event_idx > 0:
		var prev_event: Dictionary = events[event_idx - 1]
		if _event_max_midi(prev_event) >= midi_threshold:
			return true
	if event_idx < events.size() - 1:
		var next_event: Dictionary = events[event_idx + 1]
		if _event_max_midi(next_event) >= midi_threshold:
			return true
	return false


func _event_max_midi(event: Dictionary) -> int:
	var max_midi := -1
	var notes: Array = event.get("notes", [])
	for n in notes:
		var note: Dictionary = n
		if bool(note.get("rest", false)):
			continue
		var midi := int(note.get("midi", -1))
		if midi >= 0:
			max_midi = maxi(max_midi, midi)
	return max_midi


func _event_ledger_burden(event: Dictionary, clef: String, ottava_shift: int) -> int:
	var total := 0
	var notes: Array = event.get("notes", [])
	for n in notes:
		var note: Dictionary = n
		if bool(note.get("rest", false)):
			continue
		var midi := int(note.get("midi", -1))
		if midi >= 0:
			total += _ledger_count_for_display_midi(midi - ottava_shift, clef)
	return total


func _ledger_count_for_display_midi(midi: int, clef: String) -> int:
	var note_y := _midi_to_staff_y(midi, clef, 0.0)
	var top_y := 0.0
	var bot_y := staff_space * 4.0
	if note_y < top_y - staff_space * 0.5:
		return int(floor(((top_y - note_y) + 0.01) / staff_space))
	if note_y > bot_y + staff_space * 0.5:
		return int(floor(((note_y - bot_y) + 0.01) / staff_space))
	return 0


# --- Event drawing (single notes + chord clusters) ---

func _draw_event(event: Dictionary, clef: String, key_fifths: int, staff_top: float, highlight: bool, event_index: int = -1) -> void:
	var font := SMuFLFont.get_font()
	var color := _event_color(event_index, highlight)
	var event_x: float = float(event.get("x", 0.0))
	var dur_beats: float = float(event.get("duration_beats", 0.5))
	var is_rest: bool = bool(event.get("rest", false))
	var display_clef := str(event.get("display_clef", clef))
	var ottava_shift := int(event.get("ottava_shift", 0))
	if is_rest:
		var rest_glyph := SMuFLFont.rest_for_duration(dur_beats)
		var rest_y := staff_top + staff_space * 2.0
		draw_string(font, Vector2(event_x - staff_space * 0.5, rest_y + staff_space * 0.3), rest_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(staff_space * 4.0), color)
		return
	var notes: Array = event.get("notes", [])
	if notes.is_empty():
		return
	if bool(event.get("draw_clef_change", false)):
		var clef_x := maxf(_content_x_start + staff_space * 0.15, event_x - staff_space * 2.35)
		_draw_inline_clef_change(display_clef, clef_x, staff_top)
	# Sort notes by pitch ascending — required for cluster column assignment.
	notes.sort_custom(func(a, b): return int(a.get("midi", 0)) < int(b.get("midi", 0)))
	# Compute Y for each note (carry over the fingering field if present)
	var note_layouts: Array = []
	for n in notes:
		var midi: int = int(n.get("midi", -1))
		if midi < 0:
			continue
		var display_midi := midi - ottava_shift
		var note_y := _midi_to_staff_y(display_midi, display_clef, staff_top)
		note_layouts.append({
			"midi": midi,
			"display_midi": display_midi,
			"y": note_y,
			"letter_idx": _midi_letter_index(display_midi),
			"fingering": int(n.get("fingering", 0)),
		})
	if note_layouts.is_empty():
		return
	# Assign cluster columns (Gould seconds-offset rule).
	_assign_cluster_columns(note_layouts)
	# Decide stem direction for the whole cluster.
	var stem_up: bool = _cluster_stem_direction(note_layouts, staff_top)
	# Draw accidentals (with stacking for multiple).
	_draw_event_accidentals(note_layouts, key_fifths, event_x, color)
	# Draw noteheads.
	var head_glyph_dur := dur_beats if not cluster_mode else 4.0
	var head_glyph := SMuFLFont.notehead_for_duration(head_glyph_dur)
	var head_advance := staff_space * 1.18  # one notehead width
	for nl in note_layouts:
		var col_offset: float = float(nl.get("col", 0)) * head_advance
		# In stem-up clusters, "left" column is toward the stem; in stem-down it's the opposite.
		# To keep code simple we always offset to the right of the base x for col=1.
		var head_x: float = event_x - staff_space * 0.6 + col_offset
		var head_y_local: float = float(nl["y"])
		# Ledger lines per note position
		_draw_ledgers(event_x + col_offset, nl["y"], staff_top)
		draw_string(font, Vector2(head_x, head_y_local), head_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(staff_space * 4.0), color)
	# Fingering digits — drawn ABOVE the highest notehead in the cluster (one digit per note).
	# Engraving convention places fingering opposite the stem; for v1 we always place above
	# the cluster, which is readable and avoids stem-direction conditionals.
	_draw_event_fingerings(note_layouts, event_x, head_advance, staff_top, color)
	if cluster_mode:
		return  # No stems/flags for chord-explorer-style display
	var is_beamed := bool(event.get("beamed", false))
	# Stem (single shared stem for the whole cluster). Beamed events draw their
	# stems in _draw_beam_group so loose stems do not protrude past the beam.
	if dur_beats < 4.0 and not is_beamed:
		_draw_cluster_stem(note_layouts, event_x, stem_up, color)
	# Flag for unbeamed eighths/sixteenths (beams handled separately by beam group draw)
	if dur_beats <= 0.5 and not is_beamed:
		_draw_flag_for_event(event_x, note_layouts, stem_up, dur_beats, color)


func _event_color(event_index: int, highlight: bool) -> Color:
	if highlight:
		return highlight_color
	var bands: Dictionary = score.get("note_bands", {})
	if event_index >= 0 and bands.has(event_index):
		var band := int(bands[event_index])
		var feedback_color: Variant = sight_feedback_colors.get(band, note_color)
		return feedback_color if feedback_color is Color else note_color
	return note_color


func _draw_inline_clef_change(clef: String, x: float, staff_top: float) -> void:
	var font := SMuFLFont.get_font()
	var glyph := SMuFLFont.glyph("gClef" if clef == "treble" else "fClef")
	var glyph_size := int(staff_space * 3.0)
	var baseline_y := staff_top + ((3.35 if clef == "treble" else 1.35) + CLEF_BASELINE_NUDGE_SPACES) * staff_space
	var mark_color := line_color
	mark_color.a *= 0.82
	draw_string(font, Vector2(x, baseline_y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, mark_color)


func _draw_ottava_spans(events: Array, staff_top: float, default_clef: String) -> void:
	var span_start := -1
	var span_show_label := false
	for event_idx in range(events.size() + 1):
		var is_shifted := false
		if event_idx < events.size():
			var event: Dictionary = events[event_idx]
			is_shifted = int(event.get("ottava_shift", 0)) > 0 and not bool(event.get("rest", false))
		if is_shifted and span_start < 0:
			span_start = event_idx
			var start_event: Dictionary = events[event_idx]
			span_show_label = bool(start_event.get("draw_ottava_mark", false))
		elif not is_shifted and span_start >= 0:
			_draw_ottava_mark(events, span_start, event_idx - 1, staff_top, default_clef, span_show_label)
			span_start = -1
			span_show_label = false


func _draw_ottava_mark(events: Array, start_idx: int, end_idx: int, staff_top: float, default_clef: String, show_label: bool = true) -> void:
	if start_idx < 0 or end_idx < start_idx or start_idx >= events.size():
		return
	end_idx = mini(end_idx, events.size() - 1)
	var mark_color := line_color
	mark_color.a *= 0.76
	var size_px := int(staff_space * 1.1)
	var start_event: Dictionary = events[start_idx]
	var end_event: Dictionary = events[end_idx]
	var start_x := float(start_event.get("x", 0.0)) - staff_space * 0.85
	var end_x := float(end_event.get("x", 0.0)) + staff_space * 2.15
	if end_x <= start_x:
		end_x = start_x + staff_space * 2.2
	var highest_note_y := INF
	for idx in range(start_idx, end_idx + 1):
		var event: Dictionary = events[idx]
		var display_clef := str(event.get("display_clef", default_clef))
		var ottava_shift := int(event.get("ottava_shift", 0))
		var notes: Array = event.get("notes", [])
		for note_any in notes:
			var note: Dictionary = note_any
			var midi := int(note.get("midi", -1))
			if midi < 0 or bool(note.get("rest", false)):
				continue
			var note_y := _midi_to_staff_y(midi - ottava_shift, display_clef, staff_top)
			highest_note_y = minf(highest_note_y, note_y)
	if highest_note_y == INF:
		highest_note_y = staff_top
	var line_y: float = minf(staff_top - staff_space * 2.85, highest_note_y - staff_space * 2.05)
	var label_x := start_x - staff_space * 0.15
	var label_y := line_y + staff_space * 0.30
	var line_start := start_x
	if show_label:
		draw_string(ThemeDB.fallback_font, Vector2(label_x, label_y), "8va", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, mark_color)
		line_start = label_x + staff_space * 1.75
	draw_line(Vector2(line_start, line_y), Vector2(end_x, line_y), mark_color, maxf(1.0, staff_space * 0.08), true)
	draw_line(Vector2(end_x, line_y), Vector2(end_x, line_y + staff_space * 0.55), mark_color, maxf(1.0, staff_space * 0.08), true)


func _draw_event_fingerings(note_layouts: Array, event_x: float, head_advance: float, staff_top: float, color: Color) -> void:
	# Use the system font (NOT SMuFL) for digits — readable Arabic numerals.
	var fnt := ThemeDB.fallback_font
	var size_px: int = int(staff_space * 1.05)
	# Find the topmost (smallest y) notehead per column so fingering sits above it.
	for nl in note_layouts:
		var fingering: int = int(nl.get("fingering", 0))
		if fingering < 1 or fingering > 5:
			continue
		var col_offset: float = float(nl.get("col", 0)) * head_advance
		var note_y: float = float(nl["y"])
		# Place ~1.4 staff-spaces above the notehead, slightly offset right of head center.
		var pos := Vector2(event_x - staff_space * 0.25 + col_offset, note_y - staff_space * 1.1)
		draw_string(fnt, pos, str(fingering), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _assign_cluster_columns(note_layouts: Array) -> void:
	# Gould rule: notes a 2nd apart can't share the same column on the same side of the stem.
	# Walk pitches ascending; flip column whenever current note is within 1 letter step of previous.
	var prev_letter: int = -999
	var current_col: int = 0
	for nl in note_layouts:
		var li: int = int(nl["letter_idx"])
		if prev_letter == -999:
			current_col = 0
		elif (li - prev_letter) <= 1:
			current_col = 1 - current_col
		else:
			current_col = 0
		nl["col"] = current_col
		prev_letter = li


func _cluster_stem_direction(note_layouts: Array, staff_top: float) -> bool:
	# Conventional rule: average position above middle line → stem down; below → stem up.
	# When tied, stem down.
	var middle_y: float = staff_top + staff_space * 2.0
	var sum_y: float = 0.0
	for nl in note_layouts:
		sum_y += float(nl["y"])
	var avg_y: float = sum_y / float(note_layouts.size())
	return avg_y > middle_y  # below middle → stem up


func _draw_cluster_stem(note_layouts: Array, event_x: float, stem_up: bool, color: Color) -> void:
	# Stem goes from the highest notehead to the lowest, extended by the standard stem length.
	var top_y: float = INF
	var bot_y: float = -INF
	var top_col: int = 0
	var bot_col: int = 0
	for nl in note_layouts:
		var y: float = float(nl["y"])
		if y < top_y:
			top_y = y
			top_col = int(nl.get("col", 0))
		if y > bot_y:
			bot_y = y
			bot_col = int(nl.get("col", 0))
	var head_advance: float = staff_space * 1.18
	var stem_len: float = staff_space * 3.5
	var stem_thickness: float = maxf(1.2, staff_space * 0.10)
	var stem_x: float
	var anchor_y: float
	var far_y: float
	if stem_up:
		stem_x = event_x + (staff_space * 0.55) + (head_advance * float(top_col))
		anchor_y = bot_y
		far_y = top_y - stem_len
	else:
		stem_x = event_x - (staff_space * 0.55) + (head_advance * float(bot_col))
		anchor_y = top_y
		far_y = bot_y + stem_len
	draw_line(Vector2(stem_x, anchor_y), Vector2(stem_x, far_y), color, stem_thickness)


func _draw_flag_for_event(event_x: float, note_layouts: Array, stem_up: bool, dur_beats: float, color: Color) -> void:
	if note_layouts.is_empty():
		return
	var top_y: float = INF
	var bot_y: float = -INF
	for nl in note_layouts:
		var y: float = float(nl["y"])
		if y < top_y: top_y = y
		if y > bot_y: bot_y = y
	var stem_x: float = event_x + (staff_space * 0.55 if stem_up else -staff_space * 0.55)
	var stem_len: float = staff_space * 3.5
	var flag_y: float = (top_y - stem_len) if stem_up else (bot_y + stem_len)
	var glyph_name := "flag8thUp" if stem_up else "flag8thDown"
	if dur_beats <= 0.25:
		glyph_name = "flag16thUp" if stem_up else "flag16thDown"
	var glyph := SMuFLFont.glyph(glyph_name)
	if glyph.is_empty():
		return
	var draw_y: float = flag_y if stem_up else (flag_y + staff_space * 0.6)
	draw_string(SMuFLFont.get_font(), Vector2(stem_x - staff_space * 0.05, draw_y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(staff_space * 4.0), color)


func _draw_event_accidentals(note_layouts: Array, key_fifths: int, event_x: float, color: Color) -> void:
	# Collect accidentals needed (skip those implied by key sig).
	# Stack from rightmost (closest to noteheads) to leftmost to avoid collisions.
	var to_draw: Array = []
	for nl in note_layouts:
		var midi: int = int(nl["midi"])
		var acc_name := _accidental_for_pitch(midi, key_fifths)
		if not acc_name.is_empty():
			to_draw.append({"name": acc_name, "y": float(nl["y"])})
	if to_draw.is_empty():
		return
	# Sort top to bottom (smaller y first); place each one further left than previous.
	to_draw.sort_custom(func(a, b): return float(a["y"]) < float(b["y"]))
	var font := SMuFLFont.get_font()
	var glyph_size := int(staff_space * 4.0)
	var current_x: float = event_x - staff_space * 1.5
	var advance: float = staff_space * 0.95
	# Simple stacking — for now just place them side-by-side; refining collision rules is a later phase.
	for i in range(to_draw.size()):
		var entry: Dictionary = to_draw[i]
		var glyph := SMuFLFont.glyph(str(entry["name"]))
		var x: float = current_x - float(i) * advance * 0.55
		var y: float = float(entry["y"]) + staff_space * 0.4
		draw_string(font, Vector2(x, y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, color)


# --- Beam algorithm ---

func _collect_beam_groups(events: Array) -> Array:
	# A beam group = consecutive non-rest events with duration <= 0.5 within the same beat group.
	# Beat group boundary: integer-beat positions in 4/4 (0, 1, 2, 3).
	var groups: Array = []
	var current: Array = []
	var current_beat_group: int = -1
	var current_display_sig := ""
	for i in range(events.size()):
		var ev: Dictionary = events[i]
		if bool(ev.get("rest", false)):
			if current.size() >= 2:
				groups.append(current.duplicate())
			current.clear()
			current_beat_group = -1
			current_display_sig = ""
			continue
		var dur: float = float(ev.get("duration_beats", 0.5))
		var beat: float = float(ev.get("beat_offset", 0.0))
		if dur > 0.5 + 0.001 or dur <= 0.0:
			if current.size() >= 2:
				groups.append(current.duplicate())
			current.clear()
			current_beat_group = -1
			current_display_sig = ""
			continue
		var bg := int(floor(beat))
		var display_sig := "%s:%d" % [str(ev.get("display_clef", "")), int(ev.get("ottava_shift", 0))]
		if bg != current_beat_group or (not current.is_empty() and display_sig != current_display_sig):
			if current.size() >= 2:
				groups.append(current.duplicate())
			current.clear()
			current_beat_group = bg
			current_display_sig = display_sig
		current.append(i)
		ev["beamed"] = true if current.size() >= 2 else false
	if current.size() >= 2:
		groups.append(current.duplicate())
	# Mark the first event in each finalized group as beamed too (was added before size hit 2).
	for g in groups:
		for idx in g:
			(events[int(idx)] as Dictionary)["beamed"] = true
	return groups


func _draw_beam_group(group: Array, events: Array, clef: String, staff_top: float) -> void:
	if group.size() < 2:
		return
	# Determine the cluster top/bottom Y for each event in the group, plus stem direction.
	# We pick a single stem direction for the whole group (majority vote — or based on average y).
	var sum_y: float = 0.0
	var count: int = 0
	var ev_layouts: Array = []
	for idx in group:
		var ev: Dictionary = events[int(idx)]
		var notes: Array = ev.get("notes", [])
		var display_clef := str(ev.get("display_clef", clef))
		var ottava_shift := int(ev.get("ottava_shift", 0))
		var min_y: float = INF
		var max_y: float = -INF
		for n in notes:
			var midi: int = int(n.get("midi", -1))
			if midi < 0:
				continue
			var y := _midi_to_staff_y(midi - ottava_shift, display_clef, staff_top)
			if y < min_y: min_y = y
			if y > max_y: max_y = y
			sum_y += y
			count += 1
		ev_layouts.append({
			"event": ev,
			"x": float(ev.get("x", 0.0)),
			"min_y": min_y,
			"max_y": max_y,
			"dur": float(ev.get("duration_beats", 0.5)),
		})
	if count == 0:
		return
	var middle_y: float = staff_top + staff_space * 2.0
	var avg_y: float = sum_y / float(count)
	var stem_up: bool = avg_y > middle_y
	# Compute beam endpoints (Y positions at first and last event's stem tip).
	var first_layout: Dictionary = ev_layouts[0]
	var last_layout: Dictionary = ev_layouts[ev_layouts.size() - 1]
	var stem_len: float = staff_space * 3.2
	var first_stem_tip_y: float = (float(first_layout["min_y"]) - stem_len) if stem_up else (float(first_layout["max_y"]) + stem_len)
	var last_stem_tip_y: float = (float(last_layout["min_y"]) - stem_len) if stem_up else (float(last_layout["max_y"]) + stem_len)
	# Limit slope: max ±1 staff space difference between endpoints.
	var max_slope: float = staff_space * 1.0
	var dy := last_stem_tip_y - first_stem_tip_y
	if absf(dy) > max_slope:
		var sign: float = sign(dy)
		last_stem_tip_y = first_stem_tip_y + sign * max_slope
	# Compute the per-event stem X position (consistent with non-beam stem rule).
	var stems_x: Array[float] = []
	var stems_far_y: Array[float] = []
	var beam_thickness: float = maxf(2.5, staff_space * 0.45)
	for i in range(ev_layouts.size()):
		var L: Dictionary = ev_layouts[i]
		var stem_x: float = float(L["x"]) + (staff_space * 0.55 if stem_up else -staff_space * 0.55)
		stems_x.append(stem_x)
		# Linearly interpolate beam Y between first and last stem tips.
		var t: float = (float(i)) / float(maxi(1, ev_layouts.size() - 1))
		var beam_y: float = first_stem_tip_y + t * (last_stem_tip_y - first_stem_tip_y)
		stems_far_y.append(beam_y)
		# Draw the stem line from the notehead anchor to the beam Y.
		var anchor_y: float = (float(L["max_y"]) if stem_up else float(L["min_y"]))
		var beam_edge_y: float = beam_y + (beam_thickness * 0.5 if stem_up else -beam_thickness * 0.5)
		draw_line(Vector2(stem_x, anchor_y), Vector2(stem_x, beam_edge_y), note_color, maxf(1.2, staff_space * 0.10), true)
	# Draw beam line as an antialiased thick stroke. Godot's filled polygons are
	# sharper but visibly jagged at shallow slopes on low-height beams.
	draw_line(
		Vector2(stems_x[0], stems_far_y[0]),
		Vector2(stems_x[stems_x.size() - 1], stems_far_y[stems_far_y.size() - 1]),
		note_color,
		beam_thickness,
		true
	)
	# For sixteenths: draw a second beam slightly inside.
	var any_sixteenth: bool = false
	for L in ev_layouts:
		if float(L["dur"]) <= 0.25 + 0.001:
			any_sixteenth = true
			break
	if any_sixteenth:
		var offset_dir: float = 1.0 if stem_up else -1.0
		var second_beam_offset: float = (beam_thickness + staff_space * 0.22) * offset_dir
		draw_line(
			Vector2(stems_x[0], stems_far_y[0] + second_beam_offset),
			Vector2(stems_x[stems_x.size() - 1], stems_far_y[stems_far_y.size() - 1] + second_beam_offset),
			note_color,
			beam_thickness,
			true
		)


# --- Ledger lines + Y-position math ---

# Returns the natural letter for a pitch class, biased by _active_key_fifths.
# White-key pitch classes are unambiguous (one diatonic letter). Black-key
# pitch classes are spelled flat-of-upper in flat keys (Db, Eb, Gb, Ab, Bb)
# and sharp-of-lower in sharp keys (C#, D#, F#, G#, A#). This mirrors the
# spelling that TechnicalExerciseGenerator.midi_to_step_alter_octave already
# uses for MusicXML export — the staff renderer now agrees with it.
func _pc_to_letter(pc: int) -> String:
	var pc_norm := ((pc % 12) + 12) % 12
	var prefer_flats: bool = _active_key_fifths < 0
	match pc_norm:
		0:  return "C"
		2:  return "D"
		4:  return "E"
		5:  return "F"
		7:  return "G"
		9:  return "A"
		11: return "B"
		1:  return "D" if prefer_flats else "C"   # Db / C#
		3:  return "E" if prefer_flats else "D"   # Eb / D#
		6:  return "G" if prefer_flats else "F"   # Gb / F#
		8:  return "A" if prefer_flats else "G"   # Ab / G#
		10: return "B" if prefer_flats else "A"   # Bb / A#
	return "C"


# Returns an integer offset to add to the natural octave when the spelling
# straddles an octave boundary — e.g., MIDI 60 (pitch class 0) is C4, but in a
# very-flat context the same MIDI may be spelled as B#3 (B-line of octave 3).
# Equivalently, MIDI 71 (pc 11) is B4, but in a very-sharp context the same
# MIDI spells Cb5 (C-line of octave 5). Without this correction, those edge
# spellings render one full staff space off. White-key pitch classes never
# need it; only the boundary-straddling spellings do, and those only apply
# to the rare double-flat / double-sharp cases — included here for safety.
func _octave_shift_for_letter(pc: int, letter: String) -> int:
	if pc == 0 and letter == "B":
		return -1   # Cb of next octave is actually B of previous octave letter-wise
	if pc == 11 and letter == "C":
		return 1
	return 0


func _midi_to_staff_y(midi: int, clef: String, staff_top: float) -> float:
	var pc := ((midi % 12) + 12) % 12
	var octave := int(floor(midi / 12.0)) - 1
	var letter: String = _pc_to_letter(pc)
	var letter_idx := (octave + _octave_shift_for_letter(pc, letter)) * 7 + int(LETTER_INDEX[letter])
	var ref_letter_idx: int = (5 * 7 + 3) if clef == "treble" else (3 * 7 + 5)
	var diatonic_steps := ref_letter_idx - letter_idx
	return staff_top + float(diatonic_steps) * (staff_space * 0.5)


func _midi_letter_index(midi: int) -> int:
	var pc := ((midi % 12) + 12) % 12
	var octave := int(floor(midi / 12.0)) - 1
	var letter: String = _pc_to_letter(pc)
	return (octave + _octave_shift_for_letter(pc, letter)) * 7 + int(LETTER_INDEX[letter])


func _draw_ledgers(note_x: float, note_y: float, staff_top: float) -> void:
	var top_y: float = staff_top
	var bot_y: float = staff_top + staff_space * 4
	var w: float = staff_space * 1.4
	if note_y < top_y - staff_space * 0.5:
		var y: float = top_y - staff_space
		while y >= note_y - 0.01:
			draw_line(Vector2(note_x - w * 0.5, y), Vector2(note_x + w * 0.5, y), ledger_color, 1.4)
			y -= staff_space
	elif note_y > bot_y + staff_space * 0.5:
		var y2: float = bot_y + staff_space
		while y2 <= note_y + 0.01:
			draw_line(Vector2(note_x - w * 0.5, y2), Vector2(note_x + w * 0.5, y2), ledger_color, 1.4)
			y2 += staff_space


func _accidental_for_pitch(midi: int, key_fifths: int) -> String:
	var pc := ((midi % 12) + 12) % 12
	var is_black := pc in [1, 3, 6, 8, 10]
	if not is_black:
		return ""
	var key_letters_with_accidental: Array = []
	if key_fifths > 0:
		for i in range(mini(key_fifths, 7)):
			key_letters_with_accidental.append(SHARP_ORDER[i])
	elif key_fifths < 0:
		for i in range(mini(-key_fifths, 7)):
			key_letters_with_accidental.append(FLAT_ORDER[i])
	# Use the context-aware letter so e.g. pc=3 spells as E in flat keys (and
	# is therefore implied by a -2 key sig in G minor), not as D (which would
	# always force a drawn accidental and turn Eb into "Db" on the staff).
	var letter: String = _pc_to_letter(pc)
	if letter in key_letters_with_accidental:
		return ""
	if key_fifths < 0:
		return "accidentalFlat"
	return "accidentalSharp"
