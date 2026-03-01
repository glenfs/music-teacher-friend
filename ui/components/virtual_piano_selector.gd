extends Control
class_name VirtualPianoSelector

signal selection_changed(selected_notes: PackedStringArray, selected_midi: PackedInt32Array)
signal selection_rejected(message: String)

const _WHITE_PCS := [0, 2, 4, 5, 7, 9, 11]
const _NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const _NOTE_TO_PC := {
	"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11
}

const _WHITE_KEY_W := 40.0
const _WHITE_KEY_H := 130.0
const _BLACK_KEY_W := 24.0
const _BLACK_KEY_H := 82.0
const _LABEL_H := 20.0
const _WHITE_GAP := 2.0

var start_note := "A3"
var end_note := "C6"
var selectable_white_only := true
var min_selected_count := 3
var selected_color := Color(0.98, 0.82, 0.40, 1.0)

var _start_midi := 57
var _end_midi := 84
var _default_selected_notes := PackedStringArray()
var _selected_midi_set: Dictionary = {}
var _white_buttons: Dictionary = {}
var _white_x_by_midi: Dictionary = {}

@onready var _scroll: ScrollContainer = $Scroll
@onready var _keyboard: Control = $Scroll/Keyboard
@onready var _white_layer: Control = $Scroll/Keyboard/WhiteLayer
@onready var _black_layer: Control = $Scroll/Keyboard/BlackLayer
@onready var _labels_layer: Control = $Scroll/Keyboard/LabelsLayer


func _ready() -> void:
	custom_minimum_size = Vector2(0, _WHITE_KEY_H + _LABEL_H + 6.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _default_selected_notes.is_empty():
		_default_selected_notes = PackedStringArray([start_note, end_note])
	_rebuild_keyboard()


func configure(config: Dictionary) -> void:
	start_note = str(config.get("start_note", start_note))
	end_note = str(config.get("end_note", end_note))
	selectable_white_only = bool(config.get("selectable_white_only", selectable_white_only))
	min_selected_count = maxi(1, int(config.get("min_selected_count", min_selected_count)))
	selected_color = Color(config.get("selected_color", selected_color))
	var defaults_v: Variant = config.get("default_selected_set", _default_selected_notes)
	_default_selected_notes = _to_note_array(defaults_v)
	_rebuild_keyboard()
	set_selection(_default_selected_notes, false)


func set_selection(selected_notes: Variant, emit_now: bool = true) -> void:
	var incoming := _to_note_array(selected_notes)
	var normalized: PackedInt32Array = _sanitize_note_selection(incoming)
	_selected_midi_set.clear()
	for midi_note in normalized:
		_selected_midi_set[int(midi_note)] = true
	_apply_selection_visuals()
	if emit_now:
		emit_signal("selection_changed", get_selected_notes(), get_selected_midi())


func get_selected_notes() -> PackedStringArray:
	var midi_notes := get_selected_midi()
	var out := PackedStringArray()
	for midi_note in midi_notes:
		out.append(_midi_to_note_name(int(midi_note)))
	return out


func get_selected_midi() -> PackedInt32Array:
	var keys := _selected_midi_set.keys()
	keys.sort()
	var out := PackedInt32Array()
	for k in keys:
		out.append(int(k))
	return out


func _rebuild_keyboard() -> void:
	_start_midi = _note_name_to_midi(start_note)
	_end_midi = _note_name_to_midi(end_note)
	if _start_midi > _end_midi:
		var t := _start_midi
		_start_midi = _end_midi
		_end_midi = t
	_clear_children(_white_layer)
	_clear_children(_black_layer)
	_clear_children(_labels_layer)
	_white_buttons.clear()
	_white_x_by_midi.clear()

	var white_midis := PackedInt32Array()
	for midi_note in range(_start_midi, _end_midi + 1):
		if _is_white_midi(midi_note):
			white_midis.append(midi_note)
	var white_count := white_midis.size()
	if white_count == 0:
		return

	var total_w := white_count * _WHITE_KEY_W
	_keyboard.custom_minimum_size = Vector2(total_w, _WHITE_KEY_H + _LABEL_H + 6.0)
	_white_layer.custom_minimum_size = _keyboard.custom_minimum_size
	_black_layer.custom_minimum_size = _keyboard.custom_minimum_size
	_labels_layer.custom_minimum_size = _keyboard.custom_minimum_size

	var idx := 0
	for midi_note in white_midis:
		var x := idx * _WHITE_KEY_W
		_white_x_by_midi[int(midi_note)] = x
		var key_btn := Button.new()
		key_btn.name = "W_%d" % midi_note
		key_btn.toggle_mode = true
		key_btn.focus_mode = Control.FOCUS_ALL
		key_btn.flat = false
		key_btn.clip_text = false
		key_btn.position = Vector2(x, 0.0)
		key_btn.size = Vector2(_WHITE_KEY_W - _WHITE_GAP, _WHITE_KEY_H)
		key_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		key_btn.text = ""
		key_btn.pressed.connect(_on_white_key_pressed.bind(int(midi_note)))
		_white_layer.add_child(key_btn)
		_white_buttons[int(midi_note)] = key_btn
		_add_octave_label_if_needed(int(midi_note), x)
		idx += 1

	for midi_note in range(_start_midi, _end_midi + 1):
		if _is_white_midi(midi_note):
			continue
		var left_white := midi_note - 1
		var right_white := midi_note + 1
		if not _white_x_by_midi.has(left_white) or not _white_x_by_midi.has(right_white):
			continue
		var bx := float(_white_x_by_midi[left_white]) + (_WHITE_KEY_W - (_BLACK_KEY_W * 0.5))
		var black_key := Panel.new()
		black_key.name = "B_%d" % midi_note
		black_key.position = Vector2(bx, 0.0)
		black_key.size = Vector2(_BLACK_KEY_W, _BLACK_KEY_H)
		black_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		black_key.focus_mode = Control.FOCUS_NONE
		var black_sb := StyleBoxFlat.new()
		black_sb.bg_color = Color(0.13, 0.18, 0.28, 0.98)
		black_sb.corner_radius_top_left = 5
		black_sb.corner_radius_top_right = 5
		black_sb.corner_radius_bottom_left = 6
		black_sb.corner_radius_bottom_right = 6
		black_sb.border_width_left = 1
		black_sb.border_width_top = 1
		black_sb.border_width_right = 1
		black_sb.border_width_bottom = 1
		black_sb.border_color = Color(0.03, 0.04, 0.08, 0.96)
		black_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
		black_sb.shadow_size = 2
		black_key.add_theme_stylebox_override("panel", black_sb)
		_black_layer.add_child(black_key)

	var initial := _default_selected_notes if not _default_selected_notes.is_empty() else PackedStringArray([_midi_to_note_name(white_midis[0])])
	set_selection(initial, false)


func _on_white_key_pressed(midi_note: int) -> void:
	var btn := _white_buttons.get(midi_note, null) as Button
	if btn == null:
		return
	var is_selected := _selected_midi_set.has(midi_note)
	if is_selected:
		if _selected_midi_set.size() <= min_selected_count:
			btn.button_pressed = true
			_shake_button(btn)
			emit_signal("selection_rejected", "Select at least %d notes." % min_selected_count)
			return
		_selected_midi_set.erase(midi_note)
	else:
		_selected_midi_set[midi_note] = true
	_apply_selection_visuals()
	emit_signal("selection_changed", get_selected_notes(), get_selected_midi())


func _apply_selection_visuals() -> void:
	for k in _white_buttons.keys():
		var midi_note := int(k)
		var btn := _white_buttons[k] as Button
		if btn == null:
			continue
		var selected := _selected_midi_set.has(midi_note)
		btn.button_pressed = selected
		_apply_white_key_style(btn, selected)


func _apply_white_key_style(btn: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = selected_color if selected else Color(0.98, 0.99, 1.0, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.23, 0.33, 0.48, 0.55)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.08 if selected else 0.04)
	normal.shadow_size = 2 if selected else 1
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = selected_color.lightened(0.05) if selected else Color(1.0, 1.0, 1.0, 1.0)
	hover.shadow_size = 3
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = selected_color.darkened(0.08) if selected else Color(0.95, 0.97, 1.0, 1.0)
	pressed.shadow_size = 1
	btn.add_theme_stylebox_override("pressed", pressed)


func _add_octave_label_if_needed(midi_note: int, x: float) -> void:
	var name := _midi_to_note_name(midi_note)
	var is_c := name.begins_with("C")
	var is_start_or_end := midi_note == _start_midi or midi_note == _end_midi
	if not is_c and not is_start_or_end:
		return
	var lbl := Label.new()
	lbl.text = name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.position = Vector2(x - 6.0, _WHITE_KEY_H + 2.0)
	lbl.size = Vector2(_WHITE_KEY_W + 12.0, _LABEL_H)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0, 0.90))
	_labels_layer.add_child(lbl)


func _sanitize_note_selection(selected_notes: PackedStringArray) -> PackedInt32Array:
	var allowed_white := PackedInt32Array()
	for midi_note in range(_start_midi, _end_midi + 1):
		if _is_white_midi(midi_note):
			allowed_white.append(midi_note)
	var requested_set: Dictionary = {}
	for note_name in selected_notes:
		var midi_note := _note_name_to_midi(str(note_name))
		if midi_note < _start_midi or midi_note > _end_midi:
			continue
		if selectable_white_only and not _is_white_midi(midi_note):
			continue
		requested_set[midi_note] = true
	var out := PackedInt32Array()
	for midi_note in allowed_white:
		if requested_set.has(midi_note):
			out.append(midi_note)
	if out.size() >= min_selected_count:
		return out
	for midi_note in allowed_white:
		if out.has(midi_note):
			continue
		out.append(midi_note)
		if out.size() >= min_selected_count:
			break
	return out


func _to_note_array(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


func _is_white_midi(midi_note: int) -> bool:
	var pc := posmod(midi_note, 12)
	return _WHITE_PCS.has(pc)


func _midi_to_note_name(midi_note: int) -> String:
	var pc := posmod(midi_note, 12)
	var octave := int(floor(float(midi_note) / 12.0)) - 1
	return "%s%d" % [_NOTE_NAMES_SHARP[pc], octave]


func _note_name_to_midi(note_name: String) -> int:
	var n := note_name.strip_edges()
	if n.length() < 2:
		return -1
	var letter := n.substr(0, 1).to_upper()
	if not _NOTE_TO_PC.has(letter):
		return -1
	var idx := 1
	var accidental := 0
	if idx < n.length():
		var c := n.substr(idx, 1)
		if c == "#":
			accidental = 1
			idx += 1
		elif c == "b" or c == "B":
			accidental = -1
			idx += 1
	if idx >= n.length():
		return -1
	var octave := int(n.substr(idx))
	var pc := int(_NOTE_TO_PC[letter]) + accidental
	return (octave + 1) * 12 + pc


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _shake_button(btn: Button) -> void:
	var orig := btn.position
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "position:x", orig.x - 4.0, 0.04)
	tw.tween_property(btn, "position:x", orig.x + 4.0, 0.04)
	tw.tween_property(btn, "position:x", orig.x - 3.0, 0.03)
	tw.tween_property(btn, "position:x", orig.x, 0.03)
