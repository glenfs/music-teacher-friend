class_name ChordExplorerPanel
extends PanelContainer

# Self-contained Chord Explorer modal — a fullscreen panel where the user plays
# notes (MIDI or on-screen keyboard) and sees the resulting chord identified
# on a grand staff with name, Roman numeral, inversion, and interval breakdown.
#
# The panel owns all its widgets and recent-notes state internally. It talks to
# the parent (interval_birds.gd) via signals + injected callables, so it can be
# instantiated, presented, dismissed, and freed without the parent reaching
# into its guts.


# --- Signals ---
signal closed                                       # user clicked "← Home" (parent should show home, stop MIDI listening)
signal presented                                    # panel just became visible (parent should open MIDI inputs, hide MIDI viz)
signal chord_cleared                                # user clicked Clear (parent should clear MIDI viz lights)
signal note_pressed_via_keyboard(pitch: int)        # user tapped an on-screen key (parent should light MIDI viz)


# --- Constants ---
const ARPEGGIO_WINDOW_SEC := 1.5
const CLICK_WINDOW_SEC := 12.0
const KEYBOARD_LOW := 36   # C2
const KEYBOARD_HIGH := 84  # C6
const WHITE_W := 40.0
const WHITE_H := 196.0
const BLACK_W := 26.0
const BLACK_H := 124.0

const CHORD_FN_ROOT      := Color(1.00, 0.78, 0.22, 1.0)  # gold
const CHORD_FN_THIRD     := Color(0.36, 0.78, 1.00, 1.0)  # cyan
const CHORD_FN_FIFTH     := Color(0.40, 0.92, 0.55, 1.0)  # green
const CHORD_FN_SEVENTH   := Color(0.95, 0.50, 0.85, 1.0)  # magenta
const CHORD_FN_EXTENSION := Color(0.78, 0.74, 1.00, 1.0)  # lavender
const CHORD_FN_OTHER     := Color(0.86, 0.86, 0.94, 1.0)  # silver

const MENU_TITLE_TEXT := Color(0.9176, 0.9529, 1.0, 1.0)
const MENU_PRIMARY_ACCENT := Color(0.9098, 0.6275, 0.1255, 1.0)

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

const KEY_OPTIONS := [
	["C", 0], ["G", 7], ["D", 2], ["A", 9], ["E", 4], ["B", 11], ["F#", 6],
	["F", 5], ["Bb", 10], ["Eb", 3], ["Ab", 8], ["Db", 1], ["Gb", 6],
]


# --- Module preloads ---
const StaffRendererScript = preload("res://scripts/score_engine/staff_renderer.gd")
const ScoreModelScript = preload("res://scripts/score_engine/score_model.gd")
const ChordRecognizerScript = preload("res://scripts/music_theory/chord_recognizer.gd")
const ChordExplorerTheoryScript = preload("res://scripts/music_theory/chord_explorer_theory.gd")
const PianoKeyStylesScript = preload("res://scripts/ui/piano_key_styles.gd")


# --- Injected dependencies (set via setup()) ---
var _ui_font: Font = null
var _ui_title_font: Font = null
var _play_note_callable: Callable = Callable()           # (pitch:int, dur:float) -> void
var _sample_map_callable: Callable = Callable()          # () -> Dictionary
var _nearest_sample_callable: Callable = Callable()      # (pitch:int, map:Dictionary) -> int
var _score_font_picker_builder: Callable = Callable()    # (parent:Control) -> void (optional)


# --- Internal state ---
var _key_pc: int = 0
var _key_is_minor: bool = false
var _recent_notes: Dictionary = {}        # pitch (int) -> last note-on time (float)
var _window_expires_at: float = -1.0
var _last_info: Dictionary = {}


# --- Widget references ---
var _chord_name_label: Label = null
var _full_name_label: Label = null
var _intervals_label: Label = null
var _roman_label: Label = null
var _diatonic_label: Label = null
var _inversion_label: Label = null
var _staff_area: Control = null
var _key_option: OptionButton = null
var _minor_check: CheckButton = null
var _back_button: Button = null
var _clear_button: Button = null
var _play_button: Button = null
var _window_bar: ProgressBar = null
var _keyboard_keys: Dictionary = {}       # pitch -> Button


# --- Public lifecycle ---


# Call once after add_child(), before present(). Builds the UI tree.
func setup(
	ui_font: Font,
	ui_title_font: Font,
	play_note: Callable,
	sample_map_fn: Callable,
	nearest_sample_fn: Callable,
	score_font_picker_builder: Callable
) -> void:
	_ui_font = ui_font
	_ui_title_font = ui_title_font
	_play_note_callable = play_note
	_sample_map_callable = sample_map_fn
	_nearest_sample_callable = nearest_sample_fn
	_score_font_picker_builder = score_font_picker_builder
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	z_as_relative = false
	z_index = 200
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	add_theme_stylebox_override("panel", panel_style)
	_build_ui()


# Show the panel and reset note-tracking state.
func present() -> void:
	_recent_notes.clear()
	_window_expires_at = -1.0
	visible = true
	_refresh_display()
	presented.emit()


# Hide + clear state. Does not free the panel — parent can present() again.
func dismiss() -> void:
	_recent_notes.clear()
	_window_expires_at = -1.0
	visible = false


# Called every frame by parent _process while panel is visible. Updates the
# arpeggio-window progress bar visual.
func tick(_delta: float) -> void:
	if not visible or _window_bar == null:
		return
	if _recent_notes.is_empty():
		_window_bar.modulate.a = 0.0
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var remaining := _window_expires_at - now
	if remaining <= 0.0:
		_window_bar.value = 0.0
		_window_bar.modulate.a = 0.55
		return
	var progress := clampf(remaining / ARPEGGIO_WINDOW_SEC, 0.0, 1.0)
	_window_bar.value = progress
	_window_bar.modulate.a = lerpf(0.55, 1.0, progress)


# Parent forwards MIDI / keyboard note-on events here.
# click_source=true uses the longer CLICK_WINDOW_SEC so users can build chords slowly.
func handle_note_on(pitch: int, click_source: bool = false) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var window_sec := CLICK_WINDOW_SEC if click_source else ARPEGGIO_WINDOW_SEC
	# Previous chord's window expired? Wipe before adding the new note.
	if _window_expires_at > 0.0 and now > _window_expires_at and not _recent_notes.is_empty():
		_recent_notes.clear()
		chord_cleared.emit()
	_recent_notes[pitch] = now
	_window_expires_at = now + window_sec
	if _play_note_callable.is_valid():
		_play_note_callable.call(pitch, 0.45)
	_refresh_display()


# Arpeggio mode is accumulate-only — release events are ignored.
func handle_note_off(_pitch: int) -> void:
	pass


# --- UI construction ---


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 22)
	root_margin.add_theme_constant_override("margin_right", 22)
	root_margin.add_theme_constant_override("margin_top", 22)
	root_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(root_margin)
	root_margin.add_child(root_vbox)

	# Top bar: Back | Title | Key selector
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(top_bar)

	_back_button = Button.new()
	_back_button.text = "← Home"
	_back_button.custom_minimum_size = Vector2(120, 42)
	if _ui_title_font != null:
		_back_button.add_theme_font_override("font", _ui_title_font)
	_back_button.add_theme_font_size_override("font_size", 16)
	_back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_button)

	var title_label := Label.new()
	title_label.text = "Chord Explorer"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _ui_title_font != null:
		title_label.add_theme_font_override("font", _ui_title_font)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	top_bar.add_child(title_label)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 8)
	top_bar.add_child(key_row)

	var key_label := Label.new()
	key_label.text = "Key:"
	if _ui_font != null:
		key_label.add_theme_font_override("font", _ui_font)
	key_label.add_theme_font_size_override("font_size", 16)
	key_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96, 0.92))
	key_row.add_child(key_label)

	_key_option = OptionButton.new()
	_key_option.custom_minimum_size = Vector2(96, 38)
	for opt in KEY_OPTIONS:
		_key_option.add_item(str(opt[0]))
	_key_option.selected = 0
	_key_option.item_selected.connect(_on_key_changed)
	key_row.add_child(_key_option)

	_minor_check = CheckButton.new()
	_minor_check.text = "Minor"
	_minor_check.toggled.connect(_on_minor_toggled)
	key_row.add_child(_minor_check)

	if _score_font_picker_builder.is_valid():
		_score_font_picker_builder.call(key_row)

	var chord_body_scroll := ScrollContainer.new()
	chord_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chord_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chord_body_scroll.follow_focus = false
	root_vbox.add_child(chord_body_scroll)

	var chord_body := VBoxContainer.new()
	chord_body.add_theme_constant_override("separation", 18)
	chord_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chord_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chord_body_scroll.add_child(chord_body)

	# Staff area (centered)
	var staff_wrap := PanelContainer.new()
	staff_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var staff_wrap_style := StyleBoxFlat.new()
	staff_wrap_style.bg_color = Color(0.99, 0.98, 0.95, 0.96)
	staff_wrap_style.corner_radius_top_left = 14
	staff_wrap_style.corner_radius_top_right = 14
	staff_wrap_style.corner_radius_bottom_left = 14
	staff_wrap_style.corner_radius_bottom_right = 14
	staff_wrap_style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	staff_wrap_style.shadow_size = 8
	staff_wrap.add_theme_stylebox_override("panel", staff_wrap_style)
	chord_body.add_child(staff_wrap)

	_staff_area = StaffRendererScript.new()
	_staff_area.custom_minimum_size = Vector2(720, 240)
	_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staff_area.set("draw_paper", true)
	_staff_area.set("cluster_mode", true)
	_staff_area.set("inter_staff_gap_spaces", 5.0)
	staff_wrap.add_child(_staff_area)

	# Chord display
	var name_wrap := HBoxContainer.new()
	name_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	name_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chord_body.add_child(name_wrap)
	var name_panel := PanelContainer.new()
	name_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_panel.custom_minimum_size = Vector2(560, 0)
	var name_panel_style := StyleBoxFlat.new()
	name_panel_style.bg_color = Color(0.10, 0.16, 0.26, 0.96)
	name_panel_style.border_color = MENU_PRIMARY_ACCENT
	name_panel_style.border_width_left = 2
	name_panel_style.border_width_right = 2
	name_panel_style.border_width_top = 2
	name_panel_style.border_width_bottom = 2
	name_panel_style.corner_radius_top_left = 12
	name_panel_style.corner_radius_top_right = 12
	name_panel_style.corner_radius_bottom_left = 12
	name_panel_style.corner_radius_bottom_right = 12
	name_panel.add_theme_stylebox_override("panel", name_panel_style)
	name_wrap.add_child(name_panel)

	var name_inner := VBoxContainer.new()
	name_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	name_inner.add_theme_constant_override("separation", 4)
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 18)
	name_margin.add_theme_constant_override("margin_right", 18)
	name_margin.add_theme_constant_override("margin_top", 14)
	name_margin.add_theme_constant_override("margin_bottom", 14)
	name_panel.add_child(name_margin)
	name_margin.add_child(name_inner)

	_window_bar = ProgressBar.new()
	_window_bar.show_percentage = false
	_window_bar.min_value = 0.0
	_window_bar.max_value = 1.0
	_window_bar.value = 0.0
	_window_bar.custom_minimum_size = Vector2(180, 4)
	_window_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_window_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1.0, 1.0, 1.0, 0.10)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = MENU_PRIMARY_ACCENT
	bar_fg.corner_radius_top_left = 2
	bar_fg.corner_radius_top_right = 2
	bar_fg.corner_radius_bottom_left = 2
	bar_fg.corner_radius_bottom_right = 2
	_window_bar.add_theme_stylebox_override("background", bar_bg)
	_window_bar.add_theme_stylebox_override("fill", bar_fg)
	name_inner.add_child(_window_bar)

	var name_head := HBoxContainer.new()
	name_head.alignment = BoxContainer.ALIGNMENT_CENTER
	name_head.add_theme_constant_override("separation", 16)
	name_inner.add_child(name_head)

	_chord_name_label = Label.new()
	_chord_name_label.text = "Play a chord..."
	_chord_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chord_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chord_name_label.clip_text = true
	if _ui_title_font != null:
		_chord_name_label.add_theme_font_override("font", _ui_title_font)
	_chord_name_label.add_theme_font_size_override("font_size", 44)
	_chord_name_label.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	name_head.add_child(_chord_name_label)

	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 12)
	info_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	name_head.add_child(info_row)

	_roman_label = _build_chip(info_row, "—", Color(0.62, 0.86, 0.96, 1.0))
	_inversion_label = _build_chip(info_row, "", Color(0.96, 0.78, 0.42, 1.0))
	_diatonic_label = _build_chip(info_row, "", Color(0.45, 0.92, 0.62, 1.0))
	_intervals_label = _build_chip(info_row, "", Color(0.84, 0.84, 0.92, 1.0))

	_full_name_label = Label.new()
	_full_name_label.text = ""
	_full_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font != null:
		_full_name_label.add_theme_font_override("font", _ui_font)
	_full_name_label.add_theme_font_size_override("font_size", 18)
	_full_name_label.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	name_inner.add_child(_full_name_label)

	_build_keyboard(chord_body)


func _build_chip(parent: Control, initial_text: String, accent: Color) -> Label:
	var chip_panel := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	chip_style.border_color = Color(accent.r, accent.g, accent.b, 0.65)
	chip_style.border_width_left = 1
	chip_style.border_width_right = 1
	chip_style.border_width_top = 1
	chip_style.border_width_bottom = 1
	chip_style.corner_radius_top_left = 8
	chip_style.corner_radius_top_right = 8
	chip_style.corner_radius_bottom_left = 8
	chip_style.corner_radius_bottom_right = 8
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 10
	chip_style.content_margin_top = 4
	chip_style.content_margin_bottom = 4
	chip_panel.add_theme_stylebox_override("panel", chip_style)
	parent.add_child(chip_panel)
	var lbl := Label.new()
	lbl.text = initial_text
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", accent)
	chip_panel.add_child(lbl)
	chip_panel.set_meta("chip_label", lbl)
	chip_panel.visible = not initial_text.is_empty()
	return lbl


func _build_keyboard(parent_vbox: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	parent_vbox.add_child(hbox)

	var num_octaves := 4
	var num_whites := num_octaves * 7
	var keys_w := num_whites * WHITE_W
	var keys_h := WHITE_H
	var frame_pad := 12.0
	var frame_w := keys_w + frame_pad * 2.0
	var frame_h := keys_h + frame_pad * 2.0 + 8.0

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.custom_minimum_size = Vector2(frame_w, frame_h)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.10, 0.08, 0.07, 0.98)
	frame_style.border_color = Color(0.30, 0.20, 0.14, 1.0)
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left = 14
	frame_style.corner_radius_top_right = 14
	frame_style.corner_radius_bottom_left = 14
	frame_style.corner_radius_bottom_right = 14
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	frame_style.shadow_size = 10
	frame_style.shadow_offset = Vector2(0, 6)
	frame.add_theme_stylebox_override("panel", frame_style)
	hbox.add_child(frame)

	var felt := Panel.new()
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var felt_style := StyleBoxFlat.new()
	felt_style.bg_color = Color(0.55, 0.10, 0.12, 1.0)
	felt.add_theme_stylebox_override("panel", felt_style)
	felt.position = Vector2(frame_pad, frame_pad)
	felt.size = Vector2(keys_w, 6)
	frame.add_child(felt)

	var keys_root := Control.new()
	keys_root.mouse_filter = Control.MOUSE_FILTER_PASS
	keys_root.position = Vector2(frame_pad, frame_pad + 8)
	keys_root.size = Vector2(keys_w, keys_h)
	frame.add_child(keys_root)

	# White keys first
	var white_x := 0.0
	var white_positions: Dictionary = {}
	for pitch in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if PianoKeyStylesScript.is_black_key(pitch):
			continue
		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.position = Vector2(white_x, 0)
		btn.size = Vector2(WHITE_W, WHITE_H)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ""
		var captured_pitch := pitch
		btn.pressed.connect(func(): _on_key_pressed(captured_pitch))
		PianoKeyStylesScript.apply_white_style(btn, Color.WHITE)
		keys_root.add_child(btn)
		_keyboard_keys[pitch] = btn
		white_positions[pitch] = white_x
		var pc := ((pitch % 12) + 12) % 12
		if pc == 0:
			var lbl := Label.new()
			lbl.text = "C%d" % int(pitch / 12 - 1)
			lbl.add_theme_font_size_override("font_size", 13)
			if _ui_font != null:
				lbl.add_theme_font_override("font", _ui_font)
			lbl.add_theme_color_override("font_color", Color(0.32, 0.34, 0.40, 0.92))
			lbl.position = Vector2(4, WHITE_H - 24)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lbl)
		white_x += WHITE_W

	# Black keys on top
	for pitch in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if not PianoKeyStylesScript.is_black_key(pitch):
			continue
		var prev_white := pitch - 1
		if not white_positions.has(prev_white):
			continue
		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var bx: float = float(white_positions[prev_white]) + WHITE_W - BLACK_W * 0.5
		btn.position = Vector2(bx, 0)
		btn.size = Vector2(BLACK_W, BLACK_H)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ""
		btn.z_index = 1
		var captured_pitch_b := pitch
		btn.pressed.connect(func(): _on_key_pressed(captured_pitch_b))
		PianoKeyStylesScript.apply_black_style(btn, Color.WHITE)
		keys_root.add_child(btn)
		_keyboard_keys[pitch] = btn

	# Side controls (Clear / Play)
	var side_col := VBoxContainer.new()
	side_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	side_col.add_theme_constant_override("separation", 12)
	side_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(side_col)

	_clear_button = _build_side_button(side_col, "Clear", Color(0.92, 0.46, 0.42, 1.0), _on_clear_pressed)
	_play_button = _build_side_button(side_col, "♪ Play", MENU_PRIMARY_ACCENT, _on_play_pressed)


func _build_side_button(parent: Control, text: String, accent: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(96, 56)
	btn.focus_mode = Control.FOCUS_NONE
	if _ui_title_font != null:
		btn.add_theme_font_override("font", _ui_title_font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.10, 0.12, 0.16, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.07, 0.10, 1.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.92)
	sb.border_color = Color(accent.r * 0.65, accent.g * 0.65, accent.b * 0.65, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	(hover as StyleBoxFlat).bg_color = (sb.bg_color as Color).lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate()
	(pressed_sb as StyleBoxFlat).bg_color = (sb.bg_color as Color).darkened(0.10)
	(pressed_sb as StyleBoxFlat).shadow_size = 1
	(pressed_sb as StyleBoxFlat).shadow_offset = Vector2(0, 1)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


# --- Event handlers ---


func _on_back_pressed() -> void:
	dismiss()
	closed.emit()


func _on_clear_pressed() -> void:
	_recent_notes.clear()
	_window_expires_at = -1.0
	chord_cleared.emit()
	_refresh_display()


func _on_play_pressed() -> void:
	if _recent_notes.is_empty():
		return
	if not _sample_map_callable.is_valid() or not _nearest_sample_callable.is_valid():
		return
	var sample_map: Dictionary = _sample_map_callable.call()
	if sample_map.is_empty():
		return
	var pitches := _active_pitches()
	if _play_button != null:
		_play_button.modulate = Color(0.78, 0.78, 0.78, 1.0)
	for i in range(pitches.size()):
		_play_note_soft(int(pitches[i]), sample_map)
		if i < pitches.size() - 1:
			await get_tree().create_timer(0.025).timeout
	await get_tree().create_timer(0.25).timeout
	if _play_button != null:
		_play_button.modulate = Color.WHITE


func _on_key_changed(idx: int) -> void:
	if idx < 0 or idx >= KEY_OPTIONS.size():
		return
	_key_pc = int(KEY_OPTIONS[idx][1])
	_refresh_display()


func _on_minor_toggled(pressed: bool) -> void:
	_key_is_minor = pressed
	_refresh_display()


func _on_key_pressed(pitch: int) -> void:
	if not visible:
		return
	# Already in the chord? Toggle OFF.
	if _recent_notes.has(int(pitch)):
		_recent_notes.erase(int(pitch))
		_refresh_display()
		return
	# Click-source note-on uses the longer window so users can build chords slowly.
	note_pressed_via_keyboard.emit(int(pitch))
	handle_note_on(int(pitch), true)


# --- Audio ---


func _play_note_soft(pitch: int, sample_map: Dictionary) -> void:
	var nearest: int = int(_nearest_sample_callable.call(pitch, sample_map))
	if not sample_map.has(nearest):
		return
	var stream: AudioStream = sample_map[nearest]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pow(2.0, float(pitch - nearest) / 12.0)
	player.volume_db = -12.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# --- Display refresh ---


func _active_pitches() -> Array[int]:
	var arr: Array[int] = []
	for k in _recent_notes.keys():
		arr.append(int(k))
	arr.sort()
	return arr


func _refresh_display() -> void:
	if _staff_area == null or _chord_name_label == null:
		return
	var pitches: Array[int] = _active_pitches()
	_push_notes_to_renderer(pitches)
	if pitches.is_empty():
		_chord_name_label.text = "Play a chord..."
		_chord_name_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.96, 0.62))
		_full_name_label.text = ""
		_set_chip(_roman_label, "")
		_set_chip(_inversion_label, "")
		_set_chip(_diatonic_label, "")
		_set_chip(_intervals_label, "")
		if _window_bar != null:
			_window_bar.modulate.a = 0.0
		_last_info = {}
		_refresh_keyboard_lighting()
		return
	var info: Dictionary = ChordRecognizerScript.recognize(pitches, _key_pc, _key_is_minor)
	_last_info = info
	_refresh_keyboard_lighting()
	_chord_name_label.text = str(info.get("short_name", ""))
	_chord_name_label.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	_full_name_label.text = str(info.get("full_name", ""))
	var roman := str(info.get("roman", ""))
	_set_chip(_roman_label, roman if not roman.is_empty() else "")
	var inv := str(info.get("inversion_label", ""))
	_set_chip(_inversion_label, inv if not inv.is_empty() else "")
	var quality := str(info.get("quality", ""))
	if quality != "" and quality != "single" and quality != "interval" and quality != "cluster":
		var dia: bool = bool(info.get("is_diatonic", false))
		_set_chip(_diatonic_label, "In key" if dia else "Borrowed")
	else:
		_set_chip(_diatonic_label, "")
	var intervals: Array = info.get("intervals_from_root", [])
	if intervals.size() >= 2:
		var iv_strs: Array[String] = []
		for iv in intervals:
			iv_strs.append("%d" % int(iv))
		_set_chip(_intervals_label, "[%s]" % " ".join(iv_strs))
	else:
		_set_chip(_intervals_label, "")


func _push_notes_to_renderer(pitches: Array[int]) -> void:
	if _staff_area == null or not _staff_area.has_method("set_score"):
		return
	var flat_notes: Array = []
	for p in pitches:
		flat_notes.append({
			"midi": int(p),
			"duration_beats": 4.0,
			"beat_offset": 0.0,
			"rest": false,
		})
	var fifths: int = ChordExplorerTheoryScript.key_pc_to_fifths(_key_pc, _key_is_minor)
	var score_dict: Dictionary = ScoreModelScript.from_flat_notes_grand_staff(
		flat_notes, 4, 4, fifths, _key_is_minor, 80, "", 60
	)
	_staff_area.set_score(score_dict)


func _set_chip(label: Label, text: String) -> void:
	if label == null:
		return
	var chip_panel := label.get_parent() as PanelContainer
	if text.is_empty():
		if chip_panel != null:
			chip_panel.visible = false
		return
	if chip_panel != null:
		chip_panel.visible = true
	label.text = text


# --- Keyboard lighting ---


func _refresh_keyboard_lighting() -> void:
	if _keyboard_keys.is_empty():
		return
	var held: Dictionary = {}
	for k in _recent_notes.keys():
		held[int(k)] = true
	for pitch_key in _keyboard_keys.keys():
		var pitch := int(pitch_key)
		var btn: Button = _keyboard_keys[pitch_key] as Button
		if btn == null:
			continue
		var is_black := PianoKeyStylesScript.is_black_key(pitch)
		if held.has(pitch):
			var color := _note_color_for_pitch(pitch)
			if is_black:
				PianoKeyStylesScript.apply_black_style(btn, color)
			else:
				PianoKeyStylesScript.apply_white_style(btn, color)
		else:
			if is_black:
				PianoKeyStylesScript.apply_black_style(btn, Color.WHITE)
			else:
				PianoKeyStylesScript.apply_white_style(btn, Color.WHITE)


func _note_color_for_pitch(pitch: int) -> Color:
	if _last_info.is_empty():
		return MENU_PRIMARY_ACCENT
	var root_pc_v = _last_info.get("root_pc", -1)
	if int(root_pc_v) < 0:
		return MENU_PRIMARY_ACCENT
	var pc := ((int(pitch) % 12) + 12) % 12
	var degree := ((pc - int(root_pc_v)) + 12) % 12
	match degree:
		0: return CHORD_FN_ROOT
		3, 4: return CHORD_FN_THIRD
		6, 7, 8: return CHORD_FN_FIFTH
		10, 11: return CHORD_FN_SEVENTH
		2, 5, 9: return CHORD_FN_EXTENSION
		_: return CHORD_FN_OTHER
