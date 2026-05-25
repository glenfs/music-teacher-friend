extends Control
class_name SightSingingStaff

# Self-contained staff display for Sight Singing. Draws a single treble-clef
# stave with the supplied melody as a horizontal sequence of whole notes,
# a moving cursor over the current note, and per-note colour tinting once a
# note has been evaluated. Custom _draw() keeps it independent from the
# main StaffRenderer (which is heavier and expects a full score dict).
#
# Public API:
#   set_melody(midis: Array[int], key_pc: int, key_is_minor: bool)
#   set_cursor_index(index: int)        — -1 = no cursor / session done
#   set_note_band(index: int, band: int) — color the note's notehead
#   reset()

const SingingEvaluatorScript = preload("res://scripts/sight_singing/singing_evaluator.gd")

const STAFF_LEFT_MARGIN := 80.0
const STAFF_RIGHT_MARGIN := 32.0
const STAFF_TOP_LINE_Y := 80.0
const STAFF_LINE_GAP := 18.0
const STAFF_LINE_COLOR := Color(0.18, 0.22, 0.28, 1.0)
const STAFF_LINE_WIDTH := 1.6
const CLEF_COLOR := Color(0.10, 0.14, 0.20, 1.0)
const NOTEHEAD_RADIUS_X := 12.0
const NOTEHEAD_RADIUS_Y := 9.5
const NOTEHEAD_BORDER_COLOR := Color(0.10, 0.14, 0.20, 1.0)
const NOTEHEAD_DEFAULT_FILL := Color(0.98, 0.97, 0.94, 1.0)
const CURSOR_COLOR := Color(0.28, 0.62, 0.96, 0.85)
const CURSOR_PAD := 6.0
const LEDGER_LINE_HALF_WIDTH := 16.0

# Treble clef G4 sits on the second line from the bottom. That line's Y is
# STAFF_TOP_LINE_Y + 3 * STAFF_LINE_GAP. We anchor MIDI→Y math around it.
const TREBLE_REFERENCE_MIDI := 67  # G4

var _melody_midis: Array[int] = []
var _key_pc: int = 0
var _key_is_minor: bool = false
var _cursor_index: int = -1
var _note_bands: Dictionary = {}     # int → SingingEvaluator BAND_*
var _accidentals: Array[int] = []    # per-note accidental (-1=flat,0=none,1=sharp)


func _ready() -> void:
	custom_minimum_size = Vector2(760, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_melody(midis: Array, key_pc: int, key_is_minor: bool) -> void:
	_melody_midis.clear()
	for m in midis:
		_melody_midis.append(int(m))
	_key_pc = key_pc
	_key_is_minor = key_is_minor
	_cursor_index = 0 if not _melody_midis.is_empty() else -1
	_note_bands.clear()
	_recompute_accidentals()
	queue_redraw()


func set_cursor_index(index: int) -> void:
	_cursor_index = index
	queue_redraw()


func set_note_band(index: int, band: int) -> void:
	_note_bands[index] = band
	queue_redraw()


func reset() -> void:
	_melody_midis.clear()
	_cursor_index = -1
	_note_bands.clear()
	_accidentals.clear()
	queue_redraw()


# --- Internal ---

# Treble-clef key-sig context: which letters are sharp / flat by default. We
# only need this so we don't draw an accidental for a note already implied
# by the key signature. v1 supports the seven natural-anchored keys we use.
func _key_letters_with_accidental() -> Dictionary:
	# Returns { letter: alter (-1 flat / +1 sharp) }.
	# For v1 we infer from major key tonic; minor mode shares the same key sig
	# as its relative major, so derivation by tonic works for the common keys.
	var fifths: int = _major_fifths_for_pc(_key_pc) if not _key_is_minor else _minor_fifths_for_pc(_key_pc)
	var sharp_order := ["F", "C", "G", "D", "A", "E", "B"]
	var flat_order := ["B", "E", "A", "D", "G", "C", "F"]
	var out: Dictionary = {}
	if fifths > 0:
		for i in range(mini(fifths, 7)):
			out[sharp_order[i]] = 1
	elif fifths < 0:
		for i in range(mini(-fifths, 7)):
			out[flat_order[i]] = -1
	return out


static func _major_fifths_for_pc(pc: int) -> int:
	var sharp_keys := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6}
	var flat_keys := {5: -1, 10: -2, 3: -3, 8: -4, 1: -5, 6: -6}
	if sharp_keys.has(pc):
		return int(sharp_keys[pc])
	if flat_keys.has(pc):
		return int(flat_keys[pc])
	return 0


static func _minor_fifths_for_pc(pc: int) -> int:
	var minor_map := {9: 0, 4: 1, 11: 2, 6: 3, 1: 4, 8: 5, 3: 6, 2: -1, 7: -2, 0: -3, 5: -4, 10: -5}
	if minor_map.has(pc):
		return int(minor_map[pc])
	return 0


# Returns ["letter", alter (-1/0/1), octave] for a MIDI under the active key
# signature. Used by both the y-position math and the accidental draw decision.
func _spell_midi(midi: int) -> Array:
	var pc: int = posmod(midi, 12)
	var octave: int = int(floor(midi / 12.0)) - 1
	var prefer_flats: bool = _major_fifths_for_pc(_key_pc) < 0 if not _key_is_minor else _minor_fifths_for_pc(_key_pc) < 0
	# White-key pitch classes have one unambiguous letter.
	match pc:
		0:  return ["C", 0, octave]
		2:  return ["D", 0, octave]
		4:  return ["E", 0, octave]
		5:  return ["F", 0, octave]
		7:  return ["G", 0, octave]
		9:  return ["A", 0, octave]
		11: return ["B", 0, octave]
	# Black keys — key-context aware (matches the StaffRenderer fix from earlier).
	if prefer_flats:
		match pc:
			1:  return ["D", -1, octave]
			3:  return ["E", -1, octave]
			6:  return ["G", -1, octave]
			8:  return ["A", -1, octave]
			10: return ["B", -1, octave]
	match pc:
		1:  return ["C", 1, octave]
		3:  return ["D", 1, octave]
		6:  return ["F", 1, octave]
		8:  return ["G", 1, octave]
		10: return ["A", 1, octave]
	return ["C", 0, octave]


const LETTER_INDEX_TABLE := {"C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6}

# Y position for a given MIDI on the treble clef. Each diatonic step = half a
# staff space (STAFF_LINE_GAP / 2). G4 (MIDI 67) sits on the second line from
# the bottom — index 3 from the top (the "G line").
func _y_for_midi(midi: int) -> float:
	var spelling: Array = _spell_midi(midi)
	var letter: String = str(spelling[0])
	var octave: int = int(spelling[2])
	var letter_index: int = int(LETTER_INDEX_TABLE.get(letter, 0))
	# G4 (octave 4, letter index 4) is our reference.
	var letter_idx: int = octave * 7 + letter_index
	var ref_letter_idx: int = 4 * 7 + 4  # G4
	# Each diatonic step DOWN = +1 half-space (lower on screen visually).
	var diatonic_steps_from_g4: int = ref_letter_idx - letter_idx
	# G4 line is the second from bottom: top_line_y + 3*STAFF_LINE_GAP.
	var g4_line_y: float = STAFF_TOP_LINE_Y + 3.0 * STAFF_LINE_GAP
	return g4_line_y + float(diatonic_steps_from_g4) * (STAFF_LINE_GAP * 0.5)


func _recompute_accidentals() -> void:
	_accidentals.clear()
	var key_letters: Dictionary = _key_letters_with_accidental()
	for midi in _melody_midis:
		var spelling: Array = _spell_midi(midi)
		var letter: String = spelling[0]
		var alter: int = int(spelling[1])
		# If the alter matches the key sig already, no accidental needed.
		var key_alter: int = int(key_letters.get(letter, 0))
		if alter == key_alter:
			_accidentals.append(0)
		else:
			_accidentals.append(alter)


func _x_for_index(index: int) -> float:
	if _melody_midis.is_empty():
		return STAFF_LEFT_MARGIN
	var available_w: float = size.x - STAFF_LEFT_MARGIN - STAFF_RIGHT_MARGIN
	var spacing: float = available_w / float(maxi(1, _melody_midis.size()))
	return STAFF_LEFT_MARGIN + spacing * (float(index) + 0.5)


func _draw() -> void:
	# Staff lines
	var right_x: float = size.x - STAFF_RIGHT_MARGIN
	for i in 5:
		var y: float = STAFF_TOP_LINE_Y + float(i) * STAFF_LINE_GAP
		draw_line(Vector2(STAFF_LEFT_MARGIN - 36.0, y), Vector2(right_x, y), STAFF_LINE_COLOR, STAFF_LINE_WIDTH)
	# Treble clef glyph — Unicode treble clef U+1D11E (works in default font fallback).
	var clef_y: float = STAFF_TOP_LINE_Y + 2.0 * STAFF_LINE_GAP + 8.0
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(STAFF_LEFT_MARGIN - 56.0, clef_y + STAFF_LINE_GAP), char(0x1D11E), HORIZONTAL_ALIGNMENT_LEFT, -1, 56, CLEF_COLOR)

	# Cursor on the current note (drawn under notes so it doesn't obscure them).
	if _cursor_index >= 0 and _cursor_index < _melody_midis.size():
		var cx: float = _x_for_index(_cursor_index)
		var cursor_y_top: float = STAFF_TOP_LINE_Y - CURSOR_PAD
		var cursor_h: float = STAFF_LINE_GAP * 4.0 + CURSOR_PAD * 2.0
		var cursor_w: float = NOTEHEAD_RADIUS_X * 2.4 + CURSOR_PAD * 2.0
		draw_rect(Rect2(cx - cursor_w * 0.5, cursor_y_top, cursor_w, cursor_h), CURSOR_COLOR, false, 2.4)

	# Notes
	for i in range(_melody_midis.size()):
		var midi: int = _melody_midis[i]
		var nx: float = _x_for_index(i)
		var ny: float = _y_for_midi(midi)
		# Ledger lines if note sits above/below staff
		var top_staff_y: float = STAFF_TOP_LINE_Y
		var bot_staff_y: float = STAFF_TOP_LINE_Y + 4.0 * STAFF_LINE_GAP
		if ny < top_staff_y - STAFF_LINE_GAP * 0.5:
			var ly: float = top_staff_y - STAFF_LINE_GAP
			while ly >= ny - STAFF_LINE_GAP * 0.5:
				draw_line(Vector2(nx - LEDGER_LINE_HALF_WIDTH, ly), Vector2(nx + LEDGER_LINE_HALF_WIDTH, ly), STAFF_LINE_COLOR, STAFF_LINE_WIDTH)
				ly -= STAFF_LINE_GAP
		elif ny > bot_staff_y + STAFF_LINE_GAP * 0.5:
			var ly2: float = bot_staff_y + STAFF_LINE_GAP
			while ly2 <= ny + STAFF_LINE_GAP * 0.5:
				draw_line(Vector2(nx - LEDGER_LINE_HALF_WIDTH, ly2), Vector2(nx + LEDGER_LINE_HALF_WIDTH, ly2), STAFF_LINE_COLOR, STAFF_LINE_WIDTH)
				ly2 += STAFF_LINE_GAP
		# Accidental glyph (♯/♭) if needed
		if i < _accidentals.size() and _accidentals[i] != 0:
			var acc_glyph: String = "♭" if _accidentals[i] < 0 else "♯"
			draw_string(font, Vector2(nx - NOTEHEAD_RADIUS_X - 14.0, ny + 8.0), acc_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CLEF_COLOR)
		# Notehead fill color: evaluator band tint, default fill if not yet evaluated.
		var fill_color: Color = NOTEHEAD_DEFAULT_FILL
		if _note_bands.has(i):
			fill_color = SingingEvaluatorScript.band_color(int(_note_bands[i]))
		# Draw notehead as a filled ellipse + border. Approximate ellipse via
		# scaled circle using a small polygon. Godot has no built-in ellipse,
		# so we draw two stacked draw_circle calls at different radii and
		# use border draw_arc — but cleaner: build a 24-point polygon.
		_draw_ellipse(Vector2(nx, ny), NOTEHEAD_RADIUS_X, NOTEHEAD_RADIUS_Y, fill_color, NOTEHEAD_BORDER_COLOR)


# Draws an ellipse (filled + outline). Godot has no built-in ellipse, so we
# tessellate one as a 24-point polygon.
func _draw_ellipse(center: Vector2, rx: float, ry: float, fill: Color, border: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var segments := 24
	for i in segments:
		var t: float = float(i) / float(segments) * TAU
		pts.append(Vector2(center.x + cos(t) * rx, center.y + sin(t) * ry))
	draw_colored_polygon(pts, fill)
	# Border — close the loop.
	pts.append(pts[0])
	draw_polyline(pts, border, 1.4, true)
