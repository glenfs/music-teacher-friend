class_name PracticeDrillsPanel
extends PanelContainer

# Self-contained Practice Drills modal — full-screen panel with exercise
# generator, on-screen piano, score view, playback, and PDF/image export.
# Owns all its widgets + current-exercise state internally.


signal closed                                        # ← Home pressed
signal presented                                     # panel shown


# --- Constants ---
const KEYBOARD_LOW := 21   # A0
const KEYBOARD_HIGH := 108 # C8
const WHITE_W := 26.0
const WHITE_H := 132.0
const BLACK_W := 17.0
const BLACK_H := 82.0
const EXPORT_PRINT := 1
const EXPORT_SAVE_PDF := 2
const EXPORT_SAVE_IMAGE := 3
const EXPORT_COMPOSER := "Clefira"
const EXPORT_PAGE_W_PX := 1400
const EXPORT_EXPORT_PAGE_H_PX := 1812  # kept names align with old to ease grep
const EXPORT_PAGE_H_PX := 1812
const EXPORT_PAGE_W_PT := 612.0
const EXPORT_PAGE_H_PT := 792.0

const KEY_OPTIONS := [
	["C", 0], ["G", 7], ["D", 2], ["A", 9], ["E", 4], ["B", 11], ["F#", 6],
	["F", 5], ["Bb", 10], ["Eb", 3], ["Ab", 8], ["Db", 1], ["Gb", 6],
]

const MENU_TITLE_TEXT := Color(0.9176, 0.9529, 1.0, 1.0)
const MENU_PRIMARY_ACCENT := Color(0.9098, 0.6275, 0.1255, 1.0)


# --- Module preloads ---
const StaffRendererScript = preload("res://scripts/score_engine/staff_renderer.gd")
const ScoreModelScript = preload("res://scripts/score_engine/score_model.gd")
const TechnicalExerciseGeneratorScript = preload("res://scripts/exercises/technical_exercise_generator.gd")
const ExerciseLibraryScript = preload("res://scripts/exercises/exercise_library.gd")
const CurriculumScript = preload("res://scripts/exercises/curriculum.gd")
const ChordExplorerTheoryScript = preload("res://scripts/music_theory/chord_explorer_theory.gd")
const PianoKeyStylesScript = preload("res://scripts/ui/piano_key_styles.gd")


# --- Injected callables (set in setup()) ---
var _ui_font: Font = null
var _ui_title_font: Font = null
var _rng: RandomNumberGenerator = null
var _play_note_callable: Callable = Callable()         # (midi:int, dur:float) -> Awaitable
var _play_chord_block_callable: Callable = Callable()  # (notes:Array, dur:float) -> Awaitable
var _sample_map_callable: Callable = Callable()        # () -> Dictionary
var _nearest_sample_callable: Callable = Callable()    # (midi:int, map:Dictionary) -> int
var _push_sine_callable: Callable = Callable()         # (freq:float, dur:float) -> void
var _midi_to_freq_callable: Callable = Callable()      # (midi:int) -> float
var _score_font_picker_builder: Callable = Callable()  # (parent:Control) -> void
var _dialog_style_callable: Callable = Callable()      # (dlg:AcceptDialog) -> void
var _weakest_skill_family_callable: Callable = Callable() # () -> String (may be invalid)


# --- State ---
var _current_exercise: Dictionary = {}
var _current_skill_filter: String = "all"
var _current_seed: int = -1
var _playback_active: bool = false
var _playback_token: int = 0
var _playback_index: int = 0
var _note_players: Array[AudioStreamPlayer] = []


# --- Widget references ---
var _type_option: OptionButton = null
var _skill_option: OptionButton = null
var _key_option: OptionButton = null
var _minor_check: CheckButton = null
var _octaves_spin: SpinBox = null
var _level_spin: SpinBox = null
var _staff_option: OptionButton = null
var _tempo_label: Label = null
var _title_label: Label = null
var _status_label: Label = null
var _staff_scroll: ScrollContainer = null
var _staff_area: Control = null
var _keyboard_scroll: ScrollContainer = null
var _keyboard_keys: Dictionary = {}
var _play_button: Button = null
var _stop_button: Button = null
var _generate_button: Button = null
var _overflow_button: Button = null
var _export_menu: PopupMenu = null
var _back_button: Button = null


# --- Public lifecycle ---


func setup(
	ui_font: Font,
	ui_title_font: Font,
	rng: RandomNumberGenerator,
	play_note: Callable,
	play_chord_block: Callable,
	sample_map_fn: Callable,
	nearest_sample_fn: Callable,
	push_sine_fn: Callable,
	midi_to_freq_fn: Callable,
	score_font_picker_builder: Callable,
	dialog_style: Callable,
	weakest_skill_family_fn: Callable
) -> void:
	_ui_font = ui_font
	_ui_title_font = ui_title_font
	_rng = rng
	_play_note_callable = play_note
	_play_chord_block_callable = play_chord_block
	_sample_map_callable = sample_map_fn
	_nearest_sample_callable = nearest_sample_fn
	_push_sine_callable = push_sine_fn
	_midi_to_freq_callable = midi_to_freq_fn
	_score_font_picker_builder = score_font_picker_builder
	_dialog_style_callable = dialog_style
	_weakest_skill_family_callable = weakest_skill_family_fn
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	z_as_relative = false
	z_index = 200
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	add_theme_stylebox_override("panel", bg_style)
	_build_ui()


func present() -> void:
	visible = true
	if _status_label != null:
		_status_label.text = ""
	_refresh_score_renderer()
	presented.emit()


func dismiss() -> void:
	stop_playback(true)
	visible = false


func stop_playback(reset_cursor: bool = true) -> void:
	_playback_active = false
	_playback_token += 1
	_playback_index = -1
	_stop_note_audio()
	_keyboard_clear_highlight()
	if reset_cursor:
		_clear_staff_highlight()


# --- Styling helpers ---


func _stylebox(bg: Color, border: Color, radius: int = 8, border_width: int = 1, shadow_size: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if shadow_size > 0:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0.0, 3.0)
	return sb


func _style_input(ctrl: Control, min_size: Vector2 = Vector2.ZERO) -> void:
	if min_size != Vector2.ZERO:
		ctrl.custom_minimum_size = min_size
	if _ui_title_font != null:
		ctrl.add_theme_font_override("font", _ui_title_font)
	ctrl.add_theme_font_size_override("font_size", 16)
	ctrl.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	ctrl.add_theme_color_override("font_hover_color", MENU_TITLE_TEXT)
	ctrl.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	ctrl.add_theme_color_override("font_focus_color", MENU_TITLE_TEXT)
	var normal := _stylebox(Color(0.09, 0.16, 0.27, 0.92), Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.74), 8, 1, 3)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate()
	(hover as StyleBoxFlat).bg_color = Color(0.11, 0.20, 0.33, 0.96)
	(hover as StyleBoxFlat).border_color = MENU_PRIMARY_ACCENT
	var pressed := normal.duplicate()
	(pressed as StyleBoxFlat).bg_color = Color(0.07, 0.13, 0.23, 0.98)
	var focus := normal.duplicate()
	(focus as StyleBoxFlat).border_width_left = 2
	(focus as StyleBoxFlat).border_width_right = 2
	(focus as StyleBoxFlat).border_width_top = 2
	(focus as StyleBoxFlat).border_width_bottom = 2
	ctrl.add_theme_stylebox_override("normal", normal)
	ctrl.add_theme_stylebox_override("hover", hover)
	ctrl.add_theme_stylebox_override("pressed", pressed)
	ctrl.add_theme_stylebox_override("focus", focus)


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.82))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _add_labeled_control(parent: Control, label_text: String, ctrl: Control, separation: int = 8) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(_make_label(label_text))
	row.add_child(ctrl)
	parent.add_child(row)
	return row


# --- UI construction ---


func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	root_margin.add_child(root_vbox)

	# Top bar
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	root_vbox.add_child(top_bar)
	_back_button = Button.new()
	_back_button.text = "← Home"
	_back_button.custom_minimum_size = Vector2(152, 52)
	if _ui_title_font != null:
		_back_button.add_theme_font_override("font", _ui_title_font)
	_back_button.add_theme_font_size_override("font_size", 20)
	_style_input(_back_button, Vector2(152, 52))
	_back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_button)

	var heading := Label.new()
	heading.text = "Practice Drills"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _ui_title_font != null:
		heading.add_theme_font_override("font", _ui_title_font)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98, 0.94))
	top_bar.add_child(heading)

	var right_reserve := Control.new()
	right_reserve.custom_minimum_size = Vector2(284, 1)
	top_bar.add_child(right_reserve)

	_tempo_label = Label.new()
	_tempo_label.text = "♩ = 60"
	_tempo_label.visible = false
	if _ui_font != null:
		_tempo_label.add_theme_font_override("font", _ui_font)
	_tempo_label.add_theme_font_size_override("font_size", 16)
	_tempo_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.96, 0.92))
	_tempo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_reserve.add_child(_tempo_label)

	# Controls panel
	var controls_panel := PanelContainer.new()
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls_style := _stylebox(Color(0.055, 0.105, 0.18, 0.34), Color(0.36, 0.62, 0.72, 0.10), 8, 1, 0)
	controls_style.content_margin_left = 0
	controls_style.content_margin_right = 0
	controls_style.content_margin_top = 4
	controls_style.content_margin_bottom = 4
	controls_panel.add_theme_stylebox_override("panel", controls_style)
	root_vbox.add_child(controls_panel)

	var controls_margin := MarginContainer.new()
	controls_margin.add_theme_constant_override("margin_left", 4)
	controls_margin.add_theme_constant_override("margin_right", 4)
	controls_margin.add_theme_constant_override("margin_top", 2)
	controls_margin.add_theme_constant_override("margin_bottom", 2)
	controls_panel.add_child(controls_margin)

	var controls_vbox := VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 10)
	controls_margin.add_child(controls_vbox)

	var controls_top := HBoxContainer.new()
	controls_top.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_top.add_theme_constant_override("separation", 16)
	controls_vbox.add_child(controls_top)

	var font_group := HBoxContainer.new()
	font_group.alignment = BoxContainer.ALIGNMENT_CENTER
	font_group.add_theme_constant_override("separation", 10)
	controls_top.add_child(font_group)
	if _score_font_picker_builder.is_valid():
		_score_font_picker_builder.call(font_group)
		# Find the just-added OptionButton and style it
		for child in font_group.get_children():
			if child is OptionButton:
				_style_input(child, Vector2(390, 42))

	_skill_option = OptionButton.new()
	for pair in ExerciseLibraryScript.skill_options():
		var idx: int = _skill_option.item_count
		_skill_option.add_item("Focus: %s" % str(pair[1]), idx)
		_skill_option.set_item_metadata(idx, str(pair[0]))
	_skill_option.selected = 0
	_style_input(_skill_option, Vector2(350, 42))
	_skill_option.item_selected.connect(_on_skill_changed)
	controls_top.add_child(_skill_option)

	_type_option = OptionButton.new()
	_style_input(_type_option, Vector2(320, 42))
	_type_option.item_selected.connect(func(_idx: int) -> void:
		stop_playback(true)
	)
	controls_top.add_child(_type_option)
	_refresh_type_dropdown()

	var controls_bottom := HBoxContainer.new()
	controls_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_bottom.add_theme_constant_override("separation", 16)
	controls_vbox.add_child(controls_bottom)

	_key_option = OptionButton.new()
	for opt in KEY_OPTIONS:
		_key_option.add_item(str(opt[0]))
	_key_option.selected = 0
	_style_input(_key_option, Vector2(126, 42))
	_key_option.item_selected.connect(func(_idx: int) -> void:
		stop_playback(true)
	)
	controls_bottom.add_child(_key_option)

	_minor_check = CheckButton.new()
	_minor_check.text = "Minor"
	if _ui_font != null:
		_minor_check.add_theme_font_override("font", _ui_font)
	_minor_check.add_theme_font_size_override("font_size", 16)
	_minor_check.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_minor_check.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_minor_check.custom_minimum_size = Vector2(112, 42)
	_minor_check.toggled.connect(func(_pressed: bool) -> void:
		stop_playback(true)
	)
	controls_bottom.add_child(_minor_check)

	_staff_option = OptionButton.new()
	_staff_option.add_item("Grand", 0)
	_staff_option.add_item("Treble", 1)
	_staff_option.add_item("Bass", 2)
	_staff_option.selected = 0
	_style_input(_staff_option, Vector2(144, 42))
	_staff_option.item_selected.connect(func(_idx: int) -> void:
		if _current_exercise.is_empty():
			_refresh_score_renderer()
		else:
			_on_generate_pressed()
	)
	_add_labeled_control(controls_bottom, "Staff:", _staff_option)

	_octaves_spin = SpinBox.new()
	_octaves_spin.min_value = 1
	_octaves_spin.max_value = 3
	_octaves_spin.step = 1
	_octaves_spin.value = 1
	_style_input(_octaves_spin, Vector2(92, 42))
	_octaves_spin.value_changed.connect(func(_v: float) -> void:
		stop_playback(true)
	)
	_add_labeled_control(controls_bottom, "Octaves:", _octaves_spin)

	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 10
	_level_spin.step = 1
	_level_spin.value = 1
	_style_input(_level_spin, Vector2(92, 42))
	_level_spin.value_changed.connect(func(_v: float) -> void:
		stop_playback(true)
	)
	_add_labeled_control(controls_bottom, "Level:", _level_spin)

	_generate_button = _build_action_button(controls_bottom, "Generate", MENU_PRIMARY_ACCENT, _on_generate_pressed)
	_generate_button.custom_minimum_size = Vector2(184, 46)
	_overflow_button = _build_overflow_button(controls_bottom)

	_title_label = Label.new()
	_title_label.text = "Pick options and press Generate to build a practice exercise."
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font != null:
		_title_label.add_theme_font_override("font", _ui_font)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.72, 0.79, 0.90, 0.88))
	root_vbox.add_child(_title_label)

	# Staff card
	var staff_wrap := PanelContainer.new()
	staff_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	staff_wrap.custom_minimum_size = Vector2(0, 250)
	var staff_style := StyleBoxFlat.new()
	staff_style.bg_color = Color(0.99, 0.98, 0.95, 1.0)
	staff_style.corner_radius_top_left = 8
	staff_style.corner_radius_top_right = 8
	staff_style.corner_radius_bottom_left = 8
	staff_style.corner_radius_bottom_right = 8
	staff_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	staff_style.shadow_size = 10
	staff_style.shadow_offset = Vector2(0, 4)
	staff_wrap.add_theme_stylebox_override("panel", staff_style)
	root_vbox.add_child(staff_wrap)

	_staff_scroll = ScrollContainer.new()
	_staff_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staff_scroll.follow_focus = false
	staff_wrap.add_child(_staff_scroll)

	_staff_area = StaffRendererScript.new()
	_staff_area.custom_minimum_size = Vector2(1200, 240)
	_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_staff_area.set("draw_paper", true)
	_staff_area.set("auto_bars_per_system", false)
	_staff_area.set("bars_per_system", 0)
	_staff_area.set("page_top_margin_spaces", 5.5)
	_staff_area.set("page_bottom_margin_spaces", 3.0)
	_staff_scroll.add_child(_staff_area)

	_build_keyboard(root_vbox)

	# Bottom action row
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 18)
	root_vbox.add_child(bottom_row)

	_play_button = _build_action_button(bottom_row, "♪ Play", Color(0.45, 0.92, 0.62, 1.0), _on_play_pressed)
	_stop_button = _build_action_button(bottom_row, "■ Stop", Color(0.92, 0.46, 0.42, 1.0), _on_stop_pressed)
	_build_action_button(bottom_row, "Daily Warmup", Color(0.96, 0.78, 0.42, 1.0), _on_daily_warmup_pressed)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font != null:
		_status_label.add_theme_font_override("font", _ui_font)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 0.78))
	root_vbox.add_child(_status_label)


func _build_action_button(parent: Control, text: String, accent: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	var min_w := 210 if text.length() > 12 else 176
	btn.custom_minimum_size = Vector2(min_w, 50)
	btn.focus_mode = Control.FOCUS_NONE
	if _ui_title_font != null:
		btn.add_theme_font_override("font", _ui_title_font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.78, 1.0))
	btn.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.16, 0.27, 0.94)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	(hover as StyleBoxFlat).bg_color = Color(0.12, 0.21, 0.35, 0.98)
	(hover as StyleBoxFlat).border_color = accent
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate()
	(pressed_sb as StyleBoxFlat).bg_color = Color(0.07, 0.13, 0.23, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _build_overflow_button(parent: Control) -> Button:
	var btn := Button.new()
	btn.text = "..."
	btn.tooltip_text = "Export"
	btn.custom_minimum_size = Vector2(54, 46)
	btn.focus_mode = Control.FOCUS_NONE
	if _ui_title_font != null:
		btn.add_theme_font_override("font", _ui_title_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.78, 1.0))
	btn.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	var sb := _stylebox(Color(0.09, 0.16, 0.27, 0.94), Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.82), 8, 2, 5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	(hover as StyleBoxFlat).bg_color = Color(0.12, 0.21, 0.35, 0.98)
	(hover as StyleBoxFlat).border_color = MENU_PRIMARY_ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate()
	(pressed_sb as StyleBoxFlat).bg_color = Color(0.07, 0.13, 0.23, 0.98)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	_export_menu = PopupMenu.new()
	_export_menu.add_item("Print", EXPORT_PRINT)
	_export_menu.add_item("Save PDF", EXPORT_SAVE_PDF)
	_export_menu.add_item("Save Image", EXPORT_SAVE_IMAGE)
	if _ui_font != null:
		_export_menu.add_theme_font_override("font", _ui_font)
	_export_menu.add_theme_font_size_override("font_size", 16)
	_export_menu.id_pressed.connect(_on_export_menu_id_pressed)
	btn.add_child(_export_menu)
	btn.pressed.connect(func() -> void:
		_show_export_menu(btn)
	)
	parent.add_child(btn)
	return btn


func _show_export_menu(anchor: Control) -> void:
	if _export_menu == null or anchor == null:
		return
	var anchor_pos := anchor.get_screen_position()
	var menu_w := 168
	_export_menu.position = Vector2i(
		int(anchor_pos.x + anchor.size.x - float(menu_w)),
		int(anchor_pos.y + anchor.size.y + 6.0)
	)
	_export_menu.popup()


# --- Keyboard ---


func _keyboard_white_count() -> int:
	var count := 0
	for pitch in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if not PianoKeyStylesScript.is_black_key(pitch):
			count += 1
	return count


func _build_keyboard(parent_vbox: VBoxContainer) -> void:
	var keyboard_wrap := PanelContainer.new()
	keyboard_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keyboard_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keyboard_wrap.custom_minimum_size = Vector2(0, 172)
	var wrap_style := _stylebox(Color(0.045, 0.085, 0.145, 0.76), Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.30), 8, 1, 4)
	wrap_style.content_margin_left = 10
	wrap_style.content_margin_right = 10
	wrap_style.content_margin_top = 8
	wrap_style.content_margin_bottom = 8
	keyboard_wrap.add_theme_stylebox_override("panel", wrap_style)
	parent_vbox.add_child(keyboard_wrap)

	_keyboard_scroll = ScrollContainer.new()
	_keyboard_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keyboard_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_keyboard_scroll.custom_minimum_size = Vector2(0, 156)
	_keyboard_scroll.follow_focus = false
	keyboard_wrap.add_child(_keyboard_scroll)

	var white_count := _keyboard_white_count()
	var keys_w := float(white_count) * WHITE_W
	var keys_h := WHITE_H
	var frame_pad := 10.0
	var frame_w := keys_w + frame_pad * 2.0
	var frame_h := keys_h + frame_pad * 2.0 + 8.0

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.custom_minimum_size = Vector2(frame_w, frame_h)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.075, 0.067, 0.060, 1.0)
	frame_style.border_color = Color(0.24, 0.18, 0.13, 1.0)
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left = 8
	frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_left = 8
	frame_style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", frame_style)
	_keyboard_scroll.add_child(frame)

	var felt := Panel.new()
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var felt_style := StyleBoxFlat.new()
	felt_style.bg_color = Color(0.48, 0.08, 0.10, 1.0)
	felt.add_theme_stylebox_override("panel", felt_style)
	felt.position = Vector2(frame_pad, frame_pad)
	felt.size = Vector2(keys_w, 5)
	frame.add_child(felt)

	var keys_root := Control.new()
	keys_root.mouse_filter = Control.MOUSE_FILTER_PASS
	keys_root.position = Vector2(frame_pad, frame_pad + 7)
	keys_root.size = Vector2(keys_w, keys_h)
	frame.add_child(keys_root)

	_keyboard_keys.clear()
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
		btn.pressed.connect(func(): _on_keyboard_key_pressed(captured_pitch))
		PianoKeyStylesScript.apply_white_style(btn, Color.WHITE)
		btn.add_theme_font_size_override("font_size", 22)
		keys_root.add_child(btn)
		_keyboard_keys[pitch] = btn
		white_positions[pitch] = white_x
		var pc := ((pitch % 12) + 12) % 12
		if pc == 0:
			var lbl := Label.new()
			lbl.text = "C%d" % int(pitch / 12 - 1)
			lbl.add_theme_font_size_override("font_size", 11)
			if _ui_font != null:
				lbl.add_theme_font_override("font", _ui_font)
			lbl.add_theme_color_override("font_color", Color(0.32, 0.34, 0.40, 0.88))
			lbl.position = Vector2(4, WHITE_H - 22)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lbl)
		white_x += WHITE_W

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
		btn.pressed.connect(func(): _on_keyboard_key_pressed(captured_pitch_b))
		PianoKeyStylesScript.apply_black_style(btn, Color.WHITE)
		btn.add_theme_font_size_override("font_size", 18)
		keys_root.add_child(btn)
		_keyboard_keys[pitch] = btn


func _on_keyboard_key_pressed(pitch: int) -> void:
	var sample_map: Dictionary = _sample_map_callable.call() if _sample_map_callable.is_valid() else {}
	_spawn_note(int(pitch), 0.42, sample_map)


func _keyboard_highlight_color(note_info: Dictionary) -> Color:
	var staff_num := int(note_info.get("staff", 1))
	if staff_num == 2:
		return Color(0.96, 0.78, 0.26, 1.0)
	return Color(0.33, 0.86, 0.92, 1.0)


func _keyboard_clear_highlight() -> void:
	for pitch_key in _keyboard_keys.keys():
		var pitch := int(pitch_key)
		var btn: Button = _keyboard_keys[pitch_key] as Button
		if btn == null:
			continue
		btn.text = ""
		if PianoKeyStylesScript.is_black_key(pitch):
			PianoKeyStylesScript.apply_black_style(btn, Color.WHITE)
			btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.70, 1.0))
		else:
			PianoKeyStylesScript.apply_white_style(btn, Color.WHITE)
			btn.add_theme_color_override("font_color", Color(0.10, 0.13, 0.18, 1.0))


func _keyboard_scroll_to_midis(midis: Array) -> void:
	if _keyboard_scroll == null or midis.is_empty():
		return
	var min_x := INF
	var max_x := -INF
	for midi_any in midis:
		var midi := int(midi_any)
		if not _keyboard_keys.has(midi):
			continue
		var btn: Button = _keyboard_keys[midi] as Button
		if btn == null:
			continue
		min_x = minf(min_x, btn.position.x)
		max_x = maxf(max_x, btn.position.x + btn.size.x)
	if min_x == INF:
		return
	var center_x := (min_x + max_x) * 0.5
	var content_w := max_x
	if _keyboard_scroll.get_child_count() > 0:
		var keyboard_frame := _keyboard_scroll.get_child(0) as Control
		if keyboard_frame != null:
			content_w = maxf(keyboard_frame.custom_minimum_size.x, keyboard_frame.size.x)
	var viewport_w := maxf(1.0, _keyboard_scroll.size.x)
	var max_scroll := maxf(0.0, content_w - viewport_w)
	var target_x := int(clampf(center_x - viewport_w * 0.5, 0.0, max_scroll))
	if abs(_keyboard_scroll.scroll_horizontal - target_x) > 2:
		_keyboard_scroll.scroll_horizontal = target_x


func _keyboard_scroll_to_first_note() -> void:
	if _current_exercise.is_empty():
		return
	var notes: Array = _current_exercise.get("notes", [])
	var first_beat := INF
	var midis: Array = []
	for note_any in notes:
		var note: Dictionary = note_any
		var midi := int(note.get("midi", -1))
		if midi < 0 or bool(note.get("rest", false)):
			continue
		var beat := float(note.get("beat_offset", 0.0))
		if beat < first_beat - 0.001:
			first_beat = beat
			midis = [midi]
		elif absf(beat - first_beat) <= 0.001:
			midis.append(midi)
	_keyboard_scroll_to_midis(midis)


func _keyboard_show_event(event: Dictionary) -> void:
	_keyboard_clear_highlight()
	var note_infos: Array = event.get("note_infos", [])
	var active_midis: Array = []
	for info_any in note_infos:
		var info: Dictionary = info_any
		var midi := int(info.get("midi", -1))
		if not _keyboard_keys.has(midi):
			continue
		active_midis.append(midi)
		var btn: Button = _keyboard_keys[midi] as Button
		if btn == null:
			continue
		var color := _keyboard_highlight_color(info)
		var fingering := int(info.get("fingering", 0))
		btn.text = str(fingering) if fingering > 0 else ""
		if PianoKeyStylesScript.is_black_key(midi):
			PianoKeyStylesScript.apply_black_style(btn, color)
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
		else:
			PianoKeyStylesScript.apply_white_style(btn, color)
			btn.add_theme_color_override("font_color", Color(0.07, 0.10, 0.16, 1.0))
	_keyboard_scroll_to_midis(active_midis)


# --- Event handlers ---


func _on_back_pressed() -> void:
	dismiss()
	closed.emit()


func _on_skill_changed(idx: int) -> void:
	if _skill_option == null:
		return
	stop_playback(true)
	if idx < 0 or idx >= _skill_option.item_count:
		return
	var meta = _skill_option.get_item_metadata(idx)
	if meta == null:
		return
	_current_skill_filter = str(meta)
	_refresh_type_dropdown()


func _on_generate_pressed() -> void:
	if _type_option == null:
		return
	stop_playback(true)
	var type_idx := _type_option.selected
	var type_str := "scale"
	if type_idx >= 0 and type_idx < _type_option.item_count:
		var meta = _type_option.get_item_metadata(type_idx)
		if meta != null:
			type_str = str(meta)
	var key_idx := _key_option.selected
	var key_pc := int(KEY_OPTIONS[key_idx][1])
	var key_minor := _minor_check.button_pressed
	var staff_mode := _staff_mode()
	var octaves := int(_octaves_spin.value)
	var level := int(_level_spin.value)
	_current_seed = _rng.randi() if _rng != null else int(Time.get_ticks_msec()) & 0x7fffffff
	_current_exercise = _build_exercise_for_staff_mode(type_str, key_pc, key_minor, level, octaves, staff_mode, _current_seed)
	if _title_label != null:
		_title_label.text = str(_current_exercise.get("title", ""))
	if _tempo_label != null:
		_tempo_label.text = "♩ = %d" % int(_current_exercise.get("tempo_bpm", 60))
	if _status_label != null:
		var playable_notes := 0
		for note_any in _current_exercise.get("notes", []):
			var note: Dictionary = note_any
			if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
				playable_notes += 1
		var roll_seed: int = int(_current_exercise.get("seed", _current_seed))
		var roll_gen: String = str(_current_exercise.get("generator_id", ""))
		if not roll_gen.is_empty():
			_status_label.text = "%d notes ready. Press Play to hear.  ·  roll %s · seed %d" % [playable_notes, roll_gen, roll_seed]
		else:
			_status_label.text = "%d notes ready. Press Play to hear.  ·  seed %d" % [playable_notes, roll_seed]
	_refresh_score_renderer()


func _on_play_pressed() -> void:
	if _current_exercise.is_empty():
		if _status_label != null:
			_status_label.text = "Generate an exercise first."
		return
	if _playback_active:
		return
	_stop_note_audio()
	_clear_staff_highlight()
	_playback_active = true
	_playback_token += 1
	var token := _playback_token
	var events: Array = _collect_playback_events(_current_exercise.get("notes", []))
	var bpm: float = float(_current_exercise.get("tempo_bpm", 80))
	var seconds_per_beat: float = 60.0 / maxf(40.0, bpm)
	var sample_map: Dictionary = _sample_map_callable.call() if _sample_map_callable.is_valid() else {}
	for i in range(events.size()):
		if token != _playback_token or not _playback_active:
			break
		_playback_index = i
		var event: Dictionary = events[i]
		var midis: Array = event.get("midis", [])
		var note_durs: Array = event.get("note_durations", [])
		var dur_beats: float = float(event.get("duration_beats", 0.5))
		var wait_beats: float = dur_beats
		if i < events.size() - 1:
			var cur_beat: float = float(event.get("beat_offset", 0.0))
			var next_beat: float = float(events[i + 1].get("beat_offset", 0.0))
			wait_beats = next_beat - cur_beat
		var wait_sec: float = wait_beats * seconds_per_beat
		if _staff_area != null:
			if _staff_area.has_method("set_highlight_beat"):
				_staff_area.set_highlight_beat(float(event.get("beat_offset", 0.0)))
			elif _staff_area.has_method("set_highlight_index"):
				_staff_area.set_highlight_index(i)
		_scroll_to_playback_beat(float(event.get("beat_offset", 0.0)))
		_keyboard_show_event(event)
		for ni in range(midis.size()):
			var note_dur_beats: float = float(note_durs[ni]) if ni < note_durs.size() else dur_beats
			var note_sound_sec: float = note_dur_beats * seconds_per_beat
			_spawn_note(int(midis[ni]), maxf(0.05, note_sound_sec * 0.97), sample_map)
		await get_tree().create_timer(wait_sec).timeout
	if token == _playback_token:
		_playback_active = false
		_playback_index = -1
		_clear_staff_highlight()
		_keyboard_clear_highlight()


func _on_stop_pressed() -> void:
	stop_playback(true)


func _on_daily_warmup_pressed() -> void:
	var level: int = int(_level_spin.value) if _level_spin != null else 3
	var focus: String = _current_skill_filter
	var inferred_from_weakness: String = ""
	if focus == "all" and _weakest_skill_family_callable.is_valid():
		var weakest_family: String = str(_weakest_skill_family_callable.call())
		if not weakest_family.is_empty():
			inferred_from_weakness = CurriculumScript.focus_for_module_family(weakest_family)
			if inferred_from_weakness != "all":
				focus = inferred_from_weakness
	var pick: Dictionary = CurriculumScript.daily_warmup_pick(level, focus, -1)
	var ex_id: String = str(pick.get("exercise_id", "scale"))
	var key_pc: int = int(pick.get("key_pc", 0))
	var key_minor: bool = bool(pick.get("key_is_minor", false))
	var found_idx: int = -1
	for i in range(_type_option.item_count):
		var meta = _type_option.get_item_metadata(i)
		if meta != null and str(meta) == ex_id:
			found_idx = i
			break
	if found_idx < 0:
		_current_skill_filter = "all"
		if _skill_option != null:
			_skill_option.set_block_signals(true)
			_skill_option.selected = 0
			_skill_option.set_block_signals(false)
		_refresh_type_dropdown()
		for i in range(_type_option.item_count):
			var meta2 = _type_option.get_item_metadata(i)
			if meta2 != null and str(meta2) == ex_id:
				found_idx = i
				break
	if found_idx >= 0:
		_type_option.selected = found_idx
	if _key_option != null:
		for i in range(KEY_OPTIONS.size()):
			if int(KEY_OPTIONS[i][1]) == key_pc:
				_key_option.selected = i
				break
	if _minor_check != null:
		_minor_check.button_pressed = key_minor
	if _status_label != null:
		var suffix: String = ""
		if not inferred_from_weakness.is_empty() and inferred_from_weakness != "all":
			suffix = "  ←  auto-focused on your weakest area"
		_status_label.text = "Daily Warmup: %s in %s %s%s" % [
			ExerciseLibraryScript.display_name(ex_id),
			ChordExplorerTheoryScript.key_pc_to_letter(key_pc),
			"minor" if key_minor else "major",
			suffix,
		]
	_on_generate_pressed()


func _on_export_menu_id_pressed(id: int) -> void:
	if not _has_exportable_score():
		_show_generate_first_dialog()
		return
	match id:
		EXPORT_PRINT:
			_set_export_status("Preparing print-ready score PDF...")
			var print_pdf_path: String = await _save_score_pdf()
			if print_pdf_path.is_empty():
				return
			var print_open_err := OS.shell_open(ProjectSettings.globalize_path(print_pdf_path))
			if print_open_err == OK:
				_set_export_status("Print-ready score PDF opened.")
			else:
				_set_export_status("Print-ready score PDF saved: %s" % print_pdf_path.get_file())
		EXPORT_SAVE_PDF:
			_set_export_status("Saving score PDF...")
			var pdf_path: String = await _save_score_pdf()
			if not pdf_path.is_empty():
				_set_export_status("Saved score PDF: %s" % pdf_path.get_file())
		EXPORT_SAVE_IMAGE:
			_set_export_status("Saving score image...")
			var image_path: String = await _save_score_image()
			if not image_path.is_empty():
				_set_export_status("Saved score image: %s" % image_path.get_file())


# --- Exercise building / score refresh ---


func _staff_mode() -> String:
	if _staff_option == null:
		return "grand"
	match _staff_option.selected:
		1: return "treble"
		2: return "bass"
		_: return "grand"


func _hand_for_staff_mode(mode: String) -> String:
	match mode:
		"bass": return "left"
		"treble": return "right"
		_: return "both"


func _notes_for_staff(notes: Array, staff_number: int, voice_number: int) -> Array:
	var out: Array = []
	for note_any in notes:
		var note: Dictionary = note_any
		var copy := note.duplicate(true)
		copy["staff"] = staff_number
		copy["voice"] = voice_number
		out.append(copy)
	return out


func _sort_notes_by_time_and_staff(a: Dictionary, b: Dictionary) -> bool:
	var beat_a := float(a.get("beat_offset", 0.0))
	var beat_b := float(b.get("beat_offset", 0.0))
	if absf(beat_a - beat_b) > 0.001:
		return beat_a < beat_b
	var staff_a := int(a.get("staff", 1))
	var staff_b := int(b.get("staff", 1))
	if staff_a != staff_b:
		return staff_a < staff_b
	return int(a.get("midi", -1)) < int(b.get("midi", -1))


func _build_exercise_for_staff_mode(type_str: String, key_pc: int, key_minor: bool, level: int, octaves: int, mode: String, seed: int = -1) -> Dictionary:
	if mode != "grand":
		var hand := _hand_for_staff_mode(mode)
		var exercise: Dictionary = TechnicalExerciseGeneratorScript.generate(type_str, key_pc, key_minor, level, hand, octaves, -1, seed)
		exercise["staff_mode"] = mode
		exercise["hand"] = hand
		return exercise
	var right: Dictionary = TechnicalExerciseGeneratorScript.generate(type_str, key_pc, key_minor, level, "right", octaves, -1, seed)
	var left: Dictionary = TechnicalExerciseGeneratorScript.generate(type_str, key_pc, key_minor, level, "left", octaves, -1, seed)
	var combined_notes: Array = []
	combined_notes.append_array(_notes_for_staff(right.get("notes", []), 1, 1))
	combined_notes.append_array(_notes_for_staff(left.get("notes", []), 2, 2))
	combined_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_notes_by_time_and_staff(a, b)
	)
	var exercise := right.duplicate(true)
	exercise["hand"] = "both"
	exercise["staff_mode"] = "grand"
	exercise["title"] = "%s (Grand Staff)" % str(right.get("title", "Practice Exercise"))
	exercise["notes"] = combined_notes
	exercise["total_beats"] = maxf(float(right.get("total_beats", 0.0)), float(left.get("total_beats", 0.0)))
	exercise["right_hand_notes"] = right.get("notes", [])
	exercise["left_hand_notes"] = left.get("notes", [])
	return exercise


func _refresh_type_dropdown() -> void:
	if _type_option == null:
		return
	var prev_id: String = ""
	if _type_option.item_count > 0:
		var prev_meta = _type_option.get_item_metadata(_type_option.selected)
		if prev_meta != null:
			prev_id = str(prev_meta)
	_type_option.clear()
	var ids: Array = ExerciseLibraryScript.ids_for_skill(_current_skill_filter)
	if ids.is_empty():
		ids = ExerciseLibraryScript.ids_for_skill("all")
	var restore_idx: int = 0
	for i in range(ids.size()):
		var id: String = ids[i]
		_type_option.add_item(ExerciseLibraryScript.display_name(id), i)
		_type_option.set_item_metadata(i, id)
		if id == prev_id:
			restore_idx = i
	_type_option.selected = restore_idx


func _refresh_score_renderer() -> void:
	if _staff_area == null or not _staff_area.has_method("set_score"):
		return
	var mode := _staff_mode()
	_staff_area.set("auto_bars_per_system", false)
	_staff_area.set("bars_per_system", 0)
	if _current_exercise.is_empty():
		_staff_area.custom_minimum_size = Vector2(1200, 240)
		var placeholder := ScoreModelScript.new_score("")
		placeholder["time_sig_num"] = 4
		placeholder["time_sig_den"] = 4
		if mode == "grand":
			var treble_staff := ScoreModelScript.new_staff("treble")
			(treble_staff["measures"] as Array).append(ScoreModelScript.new_measure())
			var bass_staff := ScoreModelScript.new_staff("bass")
			(bass_staff["measures"] as Array).append(ScoreModelScript.new_measure())
			(placeholder["staves"] as Array).append(treble_staff)
			(placeholder["staves"] as Array).append(bass_staff)
		else:
			var staff := ScoreModelScript.new_staff(mode)
			(staff["measures"] as Array).append(ScoreModelScript.new_measure())
			(placeholder["staves"] as Array).append(staff)
		_staff_area.set_score(placeholder)
		_keyboard_clear_highlight()
		if _keyboard_scroll != null:
			_keyboard_scroll.scroll_horizontal = 0
		call_deferred("_reset_staff_scroll")
		return
	var notes: Array = _current_exercise.get("notes", [])
	var time_num: int = int(_current_exercise.get("time_sig_num", 4))
	var time_den: int = int(_current_exercise.get("time_sig_den", 4))
	var fifths: int = int(_current_exercise.get("fifths", 0))
	var key_is_minor: bool = bool(_current_exercise.get("key_is_minor", false))
	var tempo: int = int(_current_exercise.get("tempo_bpm", 80))
	var title: String = str(_current_exercise.get("title", ""))
	var total_beats: float = float(_current_exercise.get("total_beats", 0.0))
	_staff_area.custom_minimum_size = Vector2(_score_width_for_exercise(notes, time_num, time_den, total_beats), 240)
	var score_dict: Dictionary
	if mode == "grand":
		score_dict = ScoreModelScript.from_flat_notes_grand_staff(notes, time_num, time_den, fifths, key_is_minor, tempo, title, 60)
	else:
		score_dict = ScoreModelScript.from_flat_notes(notes, mode, time_num, time_den, fifths, key_is_minor, tempo, title)
	_staff_area.set_score(score_dict)
	_keyboard_clear_highlight()
	call_deferred("_reset_staff_scroll")
	call_deferred("_keyboard_scroll_to_first_note")


func _score_width_for_exercise(notes: Array, time_num: int, time_den: int, total_beats: float) -> float:
	var beats_per_bar := float(time_num) * (4.0 / maxf(1.0, float(time_den)))
	var measure_count := maxi(1, int(ceil(maxf(beats_per_bar, total_beats) / maxf(0.001, beats_per_bar))))
	var event_beats: Dictionary = {}
	var playable_notes := 0
	for note_any in notes:
		var note: Dictionary = note_any
		var midi := int(note.get("midi", -1))
		if midi < 0 or bool(note.get("rest", false)):
			continue
		playable_notes += 1
		event_beats["%.3f" % float(note.get("beat_offset", 0.0))] = true
	var event_count := maxi(1, event_beats.size())
	var by_measure := 260.0 + float(measure_count) * 185.0
	var by_events := 360.0 + float(event_count) * 58.0 + float(maxi(0, playable_notes - event_count)) * 16.0
	return maxf(1200.0, maxf(by_measure, by_events))


# --- Playback ---


func _sort_notes_by_time(a: Dictionary, b: Dictionary) -> bool:
	var beat_a := float(a.get("beat_offset", 0.0))
	var beat_b := float(b.get("beat_offset", 0.0))
	if absf(beat_a - beat_b) > 0.001:
		return beat_a < beat_b
	return int(a.get("midi", -1)) < int(b.get("midi", -1))


func _collect_playback_events(notes: Array) -> Array:
	var sorted_notes := notes.duplicate(true)
	sorted_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_notes_by_time(a, b)
	)
	var fallback_staff := 2 if _staff_mode() == "bass" else 1
	var events: Array = []
	var current: Dictionary = {}
	for note_any in sorted_notes:
		var note: Dictionary = note_any
		var beat := float(note.get("beat_offset", 0.0))
		if current.is_empty() or absf(float(current.get("beat_offset", 0.0)) - beat) > 0.001:
			current = {
				"beat_offset": beat,
				"duration_beats": float(note.get("duration_beats", 0.5)),
				"midis": [],
				"note_durations": [],
				"note_infos": [],
			}
			events.append(current)
		current["duration_beats"] = maxf(float(current.get("duration_beats", 0.5)), float(note.get("duration_beats", 0.5)))
		var midi := int(note.get("midi", -1))
		var is_rest := bool(note.get("rest", false)) or midi < 0
		if not is_rest:
			(current["midis"] as Array).append(midi)
			(current["note_durations"] as Array).append(float(note.get("duration_beats", 0.5)))
			(current["note_infos"] as Array).append({
				"midi": midi,
				"fingering": int(note.get("fingering", 0)),
				"staff": int(note.get("staff", fallback_staff)),
				"voice": int(note.get("voice", 1)),
			})
	return events


func _spawn_note(midi: int, duration_sec: float, sample_map: Dictionary) -> void:
	if midi < 0:
		return
	if sample_map.is_empty():
		if _push_sine_callable.is_valid() and _midi_to_freq_callable.is_valid():
			var freq: float = float(_midi_to_freq_callable.call(midi))
			_push_sine_callable.call(freq, duration_sec)
		return
	var nearest: int = int(_nearest_sample_callable.call(midi, sample_map)) if _nearest_sample_callable.is_valid() else midi
	if not sample_map.has(nearest):
		return
	var stream: AudioStream = sample_map[nearest]
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pow(2.0, float(midi - nearest) / 12.0)
	add_child(player)
	_note_players.append(player)
	player.play()
	var stop_at := get_tree().create_timer(duration_sec)
	stop_at.timeout.connect(func() -> void:
		_note_players.erase(player)
		if is_instance_valid(player):
			player.stop()
			if not player.is_queued_for_deletion():
				player.queue_free()
	)


func _stop_note_audio() -> void:
	for player in _note_players:
		if player != null and is_instance_valid(player):
			player.stop()
			if not player.is_queued_for_deletion():
				player.queue_free()
	_note_players.clear()


func _clear_staff_highlight() -> void:
	if _staff_area == null:
		return
	if _staff_area.has_method("set_highlight_beat"):
		_staff_area.set_highlight_beat(-1.0)
	elif _staff_area.has_method("set_highlight_index"):
		_staff_area.set_highlight_index(-1)


func _reset_staff_scroll() -> void:
	if _staff_scroll == null:
		return
	_staff_scroll.scroll_horizontal = 0
	_staff_scroll.scroll_vertical = 0


func _scroll_to_playback_beat(beat_offset: float) -> void:
	if _staff_scroll == null or _staff_area == null:
		return
	_staff_scroll.scroll_vertical = 0
	var content_w: float = maxf(float(_staff_area.custom_minimum_size.x), _staff_area.size.x)
	var viewport_w: float = maxf(1.0, _staff_scroll.size.x)
	var max_scroll := maxf(0.0, content_w - viewport_w)
	if max_scroll <= 0.0:
		_staff_scroll.scroll_horizontal = 0
		return
	var total_beats := maxf(1.0, float(_current_exercise.get("total_beats", 1.0)))
	var beat_ratio := clampf(maxf(0.0, beat_offset) / total_beats, 0.0, 1.0)
	var target_x := int(clampf(content_w * beat_ratio - viewport_w * 0.35, 0.0, max_scroll))
	if abs(_staff_scroll.scroll_horizontal - target_x) > 2:
		_staff_scroll.scroll_horizontal = target_x


# --- Export ---


func _set_export_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _has_exportable_score() -> bool:
	if _current_exercise.is_empty():
		return false
	var notes: Array = _current_exercise.get("notes", [])
	for note_any in notes:
		var note: Dictionary = note_any
		if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
			return true
	return false


func _show_generate_first_dialog() -> void:
	_set_export_status("Generate an exercise first.")
	var dlg := AcceptDialog.new()
	dlg.title = "Generate first"
	dlg.dialog_text = "Generate a Practice Drills exercise before using Print, Save PDF, or Save Image."
	add_child(dlg)
	dlg.popup_hide.connect(func() -> void:
		if is_instance_valid(dlg):
			dlg.queue_free()
	)
	if _dialog_style_callable.is_valid():
		_dialog_style_callable.call(dlg)
	dlg.popup_centered(Vector2i(500, 180))


func _ensure_export_dir() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if not dir.dir_exists("exports"):
		var err := dir.make_dir("exports")
		if err != OK and err != ERR_ALREADY_EXISTS:
			return false
	return true


func _export_base_name() -> String:
	var raw := str(_current_exercise.get("title", "practice_drill")).to_lower()
	raw = raw.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_-"
	var clean := ""
	for c in raw:
		if allowed.contains(c):
			clean += c
	if clean.is_empty():
		clean = "practice_drill"
	return "%s_%d" % [clean, int(Time.get_unix_time_from_system())]


func _score_dict_for_export() -> Dictionary:
	if _current_exercise.is_empty():
		return {}
	var notes: Array = _current_exercise.get("notes", [])
	var time_num: int = int(_current_exercise.get("time_sig_num", 4))
	var time_den: int = int(_current_exercise.get("time_sig_den", 4))
	var fifths: int = int(_current_exercise.get("fifths", 0))
	var key_is_minor: bool = bool(_current_exercise.get("key_is_minor", false))
	var tempo: int = int(_current_exercise.get("tempo_bpm", 80))
	var title: String = str(_current_exercise.get("title", "Practice Drill"))
	var mode := str(_current_exercise.get("staff_mode", _staff_mode()))
	var score_dict: Dictionary
	if mode == "grand":
		score_dict = ScoreModelScript.from_flat_notes_grand_staff(notes, time_num, time_den, fifths, key_is_minor, tempo, title, 60)
	else:
		score_dict = ScoreModelScript.from_flat_notes(notes, mode, time_num, time_den, fifths, key_is_minor, tempo, title)
	score_dict["highlight_index"] = -1
	score_dict["highlight_beat"] = -1.0
	return score_dict


func _configure_export_renderer(renderer: Control, score_dict: Dictionary, staff_w: float, staff_h: float) -> void:
	renderer.custom_minimum_size = Vector2(staff_w, staff_h)
	renderer.size = Vector2(staff_w, staff_h)
	renderer.set("draw_paper", false)
	renderer.set("auto_bars_per_system", true)
	renderer.set("bars_per_system", 4)
	renderer.set("min_bar_width_px", 210.0)
	renderer.set("max_bars_per_system", 4)
	renderer.set("target_events_per_system", 14)
	renderer.set("page_top_margin_spaces", 4.0)
	renderer.set("page_bottom_margin_spaces", 3.0)
	if renderer.has_method("set_score"):
		renderer.call("set_score", score_dict)


func _add_export_label(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, alignment: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = label_size
	lbl.horizontal_alignment = alignment
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	if _ui_title_font != null:
		lbl.add_theme_font_override("font", _ui_title_font)
	elif _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


func _render_score_export_image() -> Image:
	var score_dict := _score_dict_for_export()
	if score_dict.is_empty():
		return null
	var page_w := float(EXPORT_PAGE_W_PX)
	var margin_x := 108.0
	var staff_y := 214.0
	var bottom_margin := 96.0
	var staff_w := page_w - margin_x * 2.0
	var probe_staff_h := 260.0
	var probe: Control = StaffRendererScript.new()
	_configure_export_renderer(probe, score_dict, staff_w, probe_staff_h)
	var staff_h := maxf(probe_staff_h, float(probe.custom_minimum_size.y))
	probe.free()
	var page_h := int(ceil(maxf(float(EXPORT_PAGE_H_PX), staff_y + staff_h + bottom_margin)))

	var viewport := SubViewport.new()
	viewport.size = Vector2i(EXPORT_PAGE_W_PX, page_h)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var page := Control.new()
	page.size = Vector2(float(EXPORT_PAGE_W_PX), float(page_h))
	page.custom_minimum_size = page.size
	viewport.add_child(page)

	var bg := ColorRect.new()
	bg.color = Color(1.0, 1.0, 1.0, 1.0)
	bg.position = Vector2.ZERO
	bg.size = page.size
	page.add_child(bg)

	var title := str(_current_exercise.get("title", "Practice Drill"))
	var tempo := int(_current_exercise.get("tempo_bpm", 80))
	_add_export_label(page, title, Vector2(margin_x, 46.0), Vector2(staff_w, 58.0), 34, HORIZONTAL_ALIGNMENT_CENTER, Color(0.06, 0.08, 0.12, 1.0))
	_add_export_label(page, EXPORT_COMPOSER, Vector2(margin_x + staff_w * 0.5, 112.0), Vector2(staff_w * 0.5, 38.0), 22, HORIZONTAL_ALIGNMENT_RIGHT, Color(0.10, 0.12, 0.16, 1.0))
	_add_export_label(page, "q = %d" % tempo, Vector2(margin_x + 10.0, 168.0), Vector2(260.0, 34.0), 21, HORIZONTAL_ALIGNMENT_LEFT, Color(0.10, 0.12, 0.16, 1.0))

	var renderer: Control = StaffRendererScript.new()
	renderer.position = Vector2(margin_x, staff_y)
	_configure_export_renderer(renderer, score_dict, staff_w, staff_h)
	page.add_child(renderer)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := viewport.get_texture()
	if tex == null:
		viewport.queue_free()
		return null
	var img := tex.get_image()
	viewport.queue_free()
	if img == null or img.is_empty():
		return null
	return img


func _save_score_image(base_name: String = "") -> String:
	if not _ensure_export_dir():
		_set_export_status("Could not create exports folder.")
		return ""
	var base := base_name if not base_name.is_empty() else _export_base_name()
	var path := "user://exports/%s.png" % base
	var image: Image = await _render_score_export_image()
	if image == null or image.is_empty():
		_set_export_status("Could not render score image.")
		return ""
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_set_export_status("Could not save score image.")
		return ""
	return path


func _save_score_pdf() -> String:
	if not _ensure_export_dir():
		_set_export_status("Could not create exports folder.")
		return ""
	var base := _export_base_name()
	var image: Image = await _render_score_export_image()
	if image == null or image.is_empty():
		_set_export_status("Could not render score PDF.")
		return ""
	var pdf_path := "user://exports/%s.pdf" % base
	if not _write_image_pdf(pdf_path, image):
		_set_export_status("Could not save score PDF.")
		return ""
	return pdf_path


# --- PDF writer helpers ---


func _pdf_append_string(out: PackedByteArray, text: String) -> void:
	out.append_array(text.to_utf8_buffer())


func _pdf_add_object(out: PackedByteArray, offsets: Array, object_id: int, body: String) -> void:
	while offsets.size() <= object_id:
		offsets.append(0)
	offsets[object_id] = out.size()
	_pdf_append_string(out, "%d 0 obj\n%s\nendobj\n" % [object_id, body])


func _pdf_add_stream_object(out: PackedByteArray, offsets: Array, object_id: int, dictionary: String, data: PackedByteArray) -> void:
	while offsets.size() <= object_id:
		offsets.append(0)
	offsets[object_id] = out.size()
	_pdf_append_string(out, "%d 0 obj\n%s\nstream\n" % [object_id, dictionary])
	out.append_array(data)
	_pdf_append_string(out, "\nendstream\nendobj\n")


func _pdf_escape_text(value: String) -> String:
	var out := value
	out = out.replace("\\", "\\\\")
	out = out.replace("(", "\\(")
	out = out.replace(")", "\\)")
	out = out.replace("\n", " ")
	out = out.replace("\r", " ")
	return out


func _write_image_pdf(path: String, image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var img: Image = image.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	var img_size: Vector2i = img.get_size()
	var img_data: PackedByteArray = img.get_data()
	if img_size.x <= 0 or img_size.y <= 0 or img_data.is_empty():
		return false
	var scale := minf(EXPORT_PAGE_W_PT / float(img_size.x), EXPORT_PAGE_H_PT / float(img_size.y))
	var draw_w := float(img_size.x) * scale
	var draw_h := float(img_size.y) * scale
	var draw_x := (EXPORT_PAGE_W_PT - draw_w) * 0.5
	var draw_y := EXPORT_PAGE_H_PT - draw_h
	var content := "q\n%.3f 0 0 %.3f %.3f %.3f cm\n/Im0 Do\nQ\n" % [draw_w, draw_h, draw_x, draw_y]

	var pdf := PackedByteArray()
	var offsets: Array = []
	_pdf_append_string(pdf, "%PDF-1.4\n")
	_pdf_add_object(pdf, offsets, 1, "<< /Type /Catalog /Pages 2 0 R >>")
	_pdf_add_object(pdf, offsets, 2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
	_pdf_add_object(pdf, offsets, 3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.3f %.3f] /Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >>" % [EXPORT_PAGE_W_PT, EXPORT_PAGE_H_PT])
	_pdf_add_stream_object(pdf, offsets, 4, "<< /Length %d >>" % content.to_utf8_buffer().size(), content.to_utf8_buffer())
	_pdf_add_stream_object(pdf, offsets, 5, "<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length %d >>" % [img_size.x, img_size.y, img_data.size()], img_data)
	var title := _pdf_escape_text(str(_current_exercise.get("title", "Practice Drill")))
	_pdf_add_object(pdf, offsets, 6, "<< /Title (%s) /Author (%s) /Creator (Clefira) /Producer (Clefira) >>" % [title, EXPORT_COMPOSER])

	var xref_offset := pdf.size()
	_pdf_append_string(pdf, "xref\n0 7\n0000000000 65535 f \n")
	for i in range(1, 7):
		_pdf_append_string(pdf, "%010d 00000 n \n" % int(offsets[i]))
	_pdf_append_string(pdf, "trailer\n<< /Size 7 /Root 1 0 R /Info 6 0 R >>\nstartxref\n%d\n%%EOF\n" % xref_offset)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(pdf)
	f.close()
	return true
