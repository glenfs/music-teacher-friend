extends Control

const INTERVAL_DATA := {
	"P1": {"label": "P1", "semitones": [0]},
	"m2": {"label": "m2", "semitones": [1]},
	"M2": {"label": "M2", "semitones": [2]},
	"m3": {"label": "m3", "semitones": [3]},
	"M3": {"label": "M3", "semitones": [4]},
	"P4": {"label": "P4", "semitones": [5]},
	"TT": {"label": "TT", "semitones": [6]},
	"P5": {"label": "P5", "semitones": [7]},
	"m6": {"label": "m6", "semitones": [8]},
	"M6": {"label": "M6", "semitones": [9]},
	"m7": {"label": "m7", "semitones": [10]},
	"M7": {"label": "M7", "semitones": [11]},
	"P8": {"label": "P8", "semitones": [12]}
}
const INTERVAL_ORDER := ["P1", "m2", "M2", "m3", "M3", "P4", "TT", "P5", "m6", "M6", "m7", "M7", "P8"]
const DEGREE_INTERVALS := {
	1: ["P1"],
	2: ["M2", "m2"],
	3: ["M3", "m3"],
	4: ["P4"],
	5: ["P5"],
	6: ["M6", "m6"],
	7: ["M7", "m7"],
	8: ["P8"]
}

const NOTE_DURATION := 0.7
const GAP_DURATION := 0.25
const MODE_INTERVAL := 0
const MODE_CHORD := 1
const MODE_SIGHT := 2
const MODE_READ := 3
const MODE_TEACHER := 4
const STAFF_LEFT_X := 56.0
const STAFF_LINE_WIDTH := 360.0
const STAFF_TOP_LINE_Y := 80.0
const STAFF_LINE_GAP_Y := 32.0
const STAFF_STEP_Y := 16.0
const STAFF_NOTE_SNAP_X := 223.0
const STAFF_TOP_LINE_STEP := 0
const STAFF_BOTTOM_LINE_STEP := 8
const CHORD_INTERVALS := {
	"Major": [0, 4, 7],
	"Minor": [0, 3, 7],
	"Maj7": [0, 4, 7, 11],
	"Dom7": [0, 4, 7, 10],
	"Min7": [0, 3, 7, 10],
	"Dim7": [0, 3, 6, 9],
	"Dim": [0, 3, 6],
	"Aug": [0, 4, 8],
	"Sus2": [0, 2, 7],
	"Sus4": [0, 5, 7]
}
const CHORD_GROUP_1 := ["Major", "Minor"]
const CHORD_GROUP_2 := ["Aug", "Dim"]
const CHORD_GROUP_3 := ["Sus2", "Sus4", "Maj7", "Dom7", "Min7", "Dim7"]
const CHORD_GROUP_4 := ["Major", "Minor", "Aug", "Dim", "Sus2", "Sus4", "Maj7", "Dom7", "Min7", "Dim7"]
const SIGHT_TRIADS := [
	{"root": "C", "quality": "Major", "name": "C Major"},
	{"root": "D", "quality": "Minor", "name": "D Minor"},
	{"root": "E", "quality": "Minor", "name": "E Minor"},
	{"root": "F", "quality": "Major", "name": "F Major"},
	{"root": "G", "quality": "Major", "name": "G Major"},
	{"root": "A", "quality": "Minor", "name": "A Minor"},
	{"root": "B", "quality": "Diminished", "name": "B Diminished"}
]
const NOTE_NAME_ORDER := ["C", "D", "E", "F", "G", "A", "B"]
const FARM_BG_PATH := "res://assets/backgrounds/farm_scene.png"
const TREE_LAYERS := []
const BIRD_TEXTURE_PATH := "res://assets/birds/chicken.png"
const TUTORIAL_CHICKEN_PATH := "res://assets/birds/chicken.svg"
const BIRD_TINT := Color(1.0, 1.0, 1.0, 1.0)
const UI_FONT_PATH := "res://assets/fonts/Righteous-Regular.ttf"
const SUCCESS_SFX_PATH := "res://assets/audio/sfx/success.mp3"
const FAIL_SFX_PATH := "res://assets/audio/sfx/fail.mp3"
const TEACHER_DATA_PATH := "user://teacher_data.json"
const TEACHER_EXPORT_DIR := "user://exports"
const TUTORIAL_CUE_CHORDS := [
	[0, 4, 7],
	[0, 3, 7],
	[0, 5, 7],
	[0, 2, 7],
	[0, 4, 8],
	[0, 3, 6],
	[0, 4, 7, 11],
	[0, 4, 7, 10],
	[0, 3, 7, 10]
]
const TUTORIAL_PLACEMENT_SUCCESS_LINES := [
	"Well done!",
	"Great job!",
	"Nice placement!",
	"Perfect spot!",
	"Excellent work!"
]
const TUTORIAL_PLACEMENT_FAIL_LINES := [
	"That was wrong, try again.",
	"Not quite. Try once more.",
	"Close, but not correct. Try again.",
	"Oops, wrong spot. Try again.",
	"Good effort. Try again."
]
const PIANO_SAMPLE_PATHS := {
	57: "res://assets/audio/piano/A3v4.ogg",
	60: "res://assets/audio/piano/C4v4.ogg",
	63: "res://assets/audio/piano/D#4v4.ogg",
	66: "res://assets/audio/piano/F#4v4.ogg",
	69: "res://assets/audio/piano/A4v4.ogg",
	72: "res://assets/audio/piano/C5v4.ogg"
}

var _rng := RandomNumberGenerator.new()
var _audio_player: AudioStreamPlayer
var _audio_stream: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _piano_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _piano_samples: Dictionary = {}
var _chord_players: Array[AudioStreamPlayer] = []
var _success_sfx: AudioStream
var _fail_sfx: AudioStream
var _ui_font: Font

var _home_panel: VBoxContainer
var _game_panel: VBoxContainer
var _home_card: PanelContainer
var _game_card: PanelContainer
var _home_info_label: Label
var _home_hub_row: HBoxContainer
var _home_hub_buttons: Dictionary = {}
var _home_flow := "Practice" # Practice | Learn | Teacher
var _home_mode_label: Label
var _home_mode_buttons_row: HBoxContainer
var _home_q_row: HBoxContainer
var _home_start_button: Button
var _home_teacher_box: VBoxContainer
var _home_teacher_open_button: Button
var _question_spin: SpinBox
var _mode_buttons: Dictionary = {}
var _ear_mode_buttons: Dictionary = {}
var _ear_mode_row: HBoxContainer
var _interval_options_box: VBoxContainer
var _chord_options_box: VBoxContainer
var _sight_options_box: VBoxContainer
var _read_options_box: VBoxContainer
var _clef_buttons: Dictionary = {}
var _selected_clef := "Treble"
var _sight_mode_buttons: Dictionary = {}
var _sight_mode := "Notes" # Notes | Chords | Placement
var _read_module_buttons: Dictionary = {}
var _selected_read_module := 1
var _sight_range_container: VBoxContainer
var _sight_range_info_label: Label
var _sight_range_lower_value_label: Label
var _sight_range_upper_value_label: Label
var _sight_range_min_step := -4
var _sight_range_max_step := 12
var _inversion_toggle: CheckButton
var _adaptive_toggle: CheckButton
var _chord_group_buttons: Dictionary = {}
var _selected_chord_group := 1
var _degree_toggles: Dictionary = {}
var _include_minor_toggle: CheckButton
var _home_material_buttons: Array[Button] = []

var _status_label: Label
var _score_label: Label
var _progress_label: Label
var _meta_label: Label
var _lives_label: Label
var _streak_label: Label
var _xp_label: Label
var _hud_left_box: PanelContainer
var _hud_right_box: PanelContainer
var _hud_center_box: PanelContainer
var _title_label: Label
var _prompt_label: Label
var _sight_container: VBoxContainer
var _sight_top_spacer: Control
var _staff_area: Control
var _staff_note: Panel
var _staff_chord_notes: Array[Panel] = []
var _staff_clef_label: Label
var _staff_lines: Array[ColorRect] = []
var _staff_line_number_labels: Array[Label] = []
var _staff_ledger_lines: Array[ColorRect] = []
var _staff_preview_ledgers: Array[ColorRect] = []
var _placement_target_dots: Array[Panel] = []
var _sight_note_bounce_tween: Tween
var _sky_block: Control
var _result_overlay: ColorRect
var _result_title: Label
var _result_subtitle: Label
var _sky_area: Control
var _bird_sprite: TextureRect
var _food_token: Panel
var _bird_idle_tween: Tween
var _bird_flap_tween: Tween
var _answer_buttons: Array[Button] = []
var _interval_choice_buttons: Array[Button] = []
var _interval_option_map: Dictionary = {}
var _chord_buttons: Dictionary = {}
var _sight_key_buttons: Dictionary = {}
var _sight_chord_choice_buttons: Array[Button] = []
var _replay_button: Button
var _slow_toggle: CheckBox
var _end_button: Button
var _restart_button: Button
var _control_row: HBoxContainer
var _sight_side_controls: VBoxContainer
var _tutorial_panel: VBoxContainer
var _tutorial_button_row: HBoxContainer
var _tutorial_back_button: Button
var _tutorial_end_button_col: VBoxContainer
var _tutorial_end_module2_button: Button
var _tutorial_end_home_button: Button
var _tutorial_end_back_button: Button
var _tutorial_step_label: Label
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _tutorial_continue_button: Button
var _tutorial_module2_button: Button
var _tutorial_home_button: Button
var _tutorial_bubble: PanelContainer
var _tutorial_bubble_label: Label
var _tutorial_bubble_tail: Panel
var _tutorial_chicken: TextureRect
var _teacher_panel: VBoxContainer
var _teacher_students_list: ItemList
var _teacher_name_edit: LineEdit
var _teacher_age_spin: SpinBox
var _teacher_level_edit: LineEdit
var _teacher_book_name_edit: LineEdit
var _teacher_book_part_edit: LineEdit
var _teacher_piece_fields_box: VBoxContainer
var _teacher_tech_fields_box: VBoxContainer
var _teacher_piece_fields: Array[LineEdit] = []
var _teacher_tech_fields: Array[LineEdit] = []
var _teacher_done_piece_edit: LineEdit
var _teacher_done_tech_edit: LineEdit
var _teacher_assignment_task_edit: LineEdit
var _teacher_assignment_due_edit: LineEdit
var _teacher_assignments_list: ItemList
var _teacher_export_csv_button: Button
var _teacher_export_report_button: Button
var _teacher_view_history_button: Button
var _teacher_tabs: TabContainer
var _teacher_selected_student_label: Label
var _teacher_progress_ear_label: Label
var _teacher_progress_sight_label: Label
var _teacher_progress_modules_label: Label
var _teacher_piece_notes: Dictionary = {}
var _teacher_piece_note_dialog: AcceptDialog
var _teacher_piece_note_edit: TextEdit
var _teacher_piece_note_target_field: LineEdit
var _teacher_piece_delete_confirm: ConfirmationDialog
var _teacher_pending_delete_piece_field: LineEdit
var _teacher_filter_option: OptionButton
var _teacher_analytics_label: Label
var _teacher_dashboard_text: RichTextLabel
var _teacher_status_label: Label
var _teacher_history_panel: PanelContainer
var _teacher_history_name_label: Label
var _teacher_history_pieces_list: ItemList
var _teacher_history_tech_list: ItemList
var _teacher_history_stats_text: RichTextLabel

var _current_interval_id := "M2"
var _current_interval_choices: Array[String] = []
var _current_chord_quality := "Major"
var _current_chord_inversion := 0
var _current_chord_notes: Array[int] = []
var _current_available_chord_types: Array[String] = []
var _current_sight_note := "C"
var _current_sight_chord_name := "C Major"
var _current_sight_chord_choices: Array[String] = []
var _current_sight_target_step := 8
var _current_sight_hover_step := 8
var _is_note_dragging := false
var _note_drag_offset_x := 0.0
var _note_drag_offset_y := 0.0
var _placement_note_home_pos := Vector2(2, 110)
var _current_root_midi := 60
var _current_second_midi := 64
var _last_interval_signature := ""
var _last_chord_signature := ""
var _last_sight_signature := ""
var _score := 0
var _question_index := 0
var _total_questions := 10
var _active_intervals: Array[String] = []
var _include_minor_intervals := false
var _selected_mode := MODE_INTERVAL
var _lives := 3
var _streak := 0
var _xp := 0
var _is_prompt_playing := false
var _accepting_answer := false
var _bird_home_global_position := Vector2.ZERO
var _bird_home_ready := false
var _quiz_active := false
var _in_tutorial := false
var _tutorial_step := -1
var _tutorial_exercise_done := false
var _tutorial_expected_step := 10
var _last_tutorial_cue_signature := ""
var _tutorial_run_id := 0
var _interval_stats_asked: Dictionary = {}
var _interval_stats_correct: Dictionary = {}
var _chord_stats_asked: Dictionary = {}
var _chord_stats_correct: Dictionary = {}
var _sight_stats_asked: Dictionary = {}
var _sight_stats_correct: Dictionary = {}
var _teacher_data: Dictionary = {"students": []}
var _teacher_selected_student_id := ""
var _teacher_list_student_ids: Array[String] = []
var _tutorial_module_recorded := false


func _ready() -> void:
	_rng.randomize()
	_build_ui()
	_setup_audio()
	_load_teacher_data()
	_on_mode_selected()
	_show_home()
	call_deferred("_post_layout_init")
	call_deferred("_update_game_card_layout")


func _exit_tree() -> void:
	_stop_bird_idle_anim()
	_stop_bird_flap_anim()
	if _piano_player != null:
		_piano_player.stop()
	for p in _chord_players:
		if p != null:
			p.stop()
	if _sfx_player != null:
		_sfx_player.stop()
	if _audio_player != null:
		_audio_player.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_game_card_layout")
		if _selected_mode == MODE_READ:
			call_deferred("_position_tutorial_title")
			call_deferred("_position_tutorial_button_row")
			call_deferred("_position_tutorial_end_buttons")


func _update_game_card_layout() -> void:
	if _game_card == null:
		return
	var vp := get_viewport_rect().size
	var target_w := maxi(840.0, vp.x - 70.0)
	var target_h := clampf(vp.y * 0.72, 420.0, 560.0)
	_game_card.custom_minimum_size = Vector2(target_w, target_h)


func _build_ui() -> void:
	_build_background()

	var root := MarginContainer.new()
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)

	var main_col := VBoxContainer.new()
	main_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_theme_constant_override("separation", 14)
	root.add_child(main_col)

	var brand_label := Label.new()
	brand_label.text = "© Adagio Labs"
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	brand_label.add_theme_font_size_override("font_size", 16)
	main_col.add_child(brand_label)

	_title_label = Label.new()
	_title_label.text = "Adagio Music Trainer"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 52)
	main_col.add_child(_title_label)

	_home_card = PanelContainer.new()
	_home_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_card.custom_minimum_size = Vector2(0, 280)
	main_col.add_child(_home_card)

	_home_panel = VBoxContainer.new()
	_home_panel.add_theme_constant_override("separation", 10)
	_home_card.add_child(_home_panel)

	var home_title := Label.new()
	home_title.text = "Training Setup"
	home_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_title.add_theme_font_size_override("font_size", 24)
	_home_panel.add_child(home_title)

	_home_hub_row = HBoxContainer.new()
	_home_hub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_hub_row.add_theme_constant_override("separation", 10)
	_home_panel.add_child(_home_hub_row)

	for hub_name in ["Practice", "Learn", "Teacher Dashboard"]:
		var hub_btn := Button.new()
		hub_btn.text = hub_name
		hub_btn.custom_minimum_size = Vector2(190, 40)
		hub_btn.pressed.connect(_on_home_hub_pressed.bind(hub_name))
		_home_hub_row.add_child(hub_btn)
		_home_hub_buttons[hub_name] = hub_btn
		_home_material_buttons.append(hub_btn)

	_home_q_row = HBoxContainer.new()
	_home_q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_panel.add_child(_home_q_row)

	_home_mode_label = Label.new()
	_home_mode_label.text = "Training Mode:"
	_home_q_row.add_child(_home_mode_label)

	_home_mode_buttons_row = HBoxContainer.new()
	_home_mode_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_mode_buttons_row.add_theme_constant_override("separation", 8)
	_home_panel.add_child(_home_mode_buttons_row)

	var ear_mode_btn := Button.new()
	ear_mode_btn.text = "Ear Training"
	ear_mode_btn.custom_minimum_size = Vector2(150, 36)
	ear_mode_btn.pressed.connect(_on_mode_button_pressed.bind(MODE_INTERVAL))
	_home_mode_buttons_row.add_child(ear_mode_btn)
	_mode_buttons["Ear"] = ear_mode_btn
	_home_material_buttons.append(ear_mode_btn)

	var sight_mode_btn := Button.new()
	sight_mode_btn.text = "Sight Reader"
	sight_mode_btn.custom_minimum_size = Vector2(140, 36)
	sight_mode_btn.pressed.connect(_on_mode_button_pressed.bind(MODE_SIGHT))
	_home_mode_buttons_row.add_child(sight_mode_btn)
	_mode_buttons["Sight"] = sight_mode_btn
	_home_material_buttons.append(sight_mode_btn)

	var read_mode_btn := Button.new()
	read_mode_btn.text = "Read Notation"
	read_mode_btn.custom_minimum_size = Vector2(150, 36)
	read_mode_btn.pressed.connect(_on_mode_button_pressed.bind(MODE_READ))
	_home_mode_buttons_row.add_child(read_mode_btn)
	_mode_buttons["Read"] = read_mode_btn
	_home_material_buttons.append(read_mode_btn)

	_ear_mode_row = HBoxContainer.new()
	_ear_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ear_mode_row.add_theme_constant_override("separation", 8)
	_home_panel.add_child(_ear_mode_row)

	var ear_interval_btn := Button.new()
	ear_interval_btn.text = "Interval"
	ear_interval_btn.custom_minimum_size = Vector2(120, 34)
	ear_interval_btn.pressed.connect(_on_ear_mode_button_pressed.bind(MODE_INTERVAL))
	_ear_mode_row.add_child(ear_interval_btn)
	_ear_mode_buttons[MODE_INTERVAL] = ear_interval_btn
	_home_material_buttons.append(ear_interval_btn)

	var ear_chord_btn := Button.new()
	ear_chord_btn.text = "Chord"
	ear_chord_btn.custom_minimum_size = Vector2(120, 34)
	ear_chord_btn.pressed.connect(_on_ear_mode_button_pressed.bind(MODE_CHORD))
	_ear_mode_row.add_child(ear_chord_btn)
	_ear_mode_buttons[MODE_CHORD] = ear_chord_btn
	_home_material_buttons.append(ear_chord_btn)

	var q_label := Label.new()
	q_label.text = "Number of Questions:"
	_home_q_row.add_child(q_label)

	_question_spin = SpinBox.new()
	_question_spin.min_value = 1
	_question_spin.max_value = 100
	_question_spin.step = 1
	_question_spin.value = 10
	_question_spin.custom_minimum_size = Vector2(90, 32)
	_home_q_row.add_child(_question_spin)

	_home_teacher_box = VBoxContainer.new()
	_home_teacher_box.add_theme_constant_override("separation", 8)
	_home_panel.add_child(_home_teacher_box)
	var teacher_title := Label.new()
	teacher_title.text = "Teacher Dashboard"
	teacher_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_teacher_box.add_child(teacher_title)
	var teacher_desc := Label.new()
	teacher_desc.text = "Create and manage students, books, pieces, and technical progress."
	teacher_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teacher_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_teacher_box.add_child(teacher_desc)
	_home_teacher_open_button = Button.new()
	_home_teacher_open_button.text = "Open Teacher Dashboard"
	_home_teacher_open_button.custom_minimum_size = Vector2(260, 46)
	_home_teacher_open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_home_teacher_open_button.pressed.connect(_on_teacher_open_pressed)
	_home_teacher_box.add_child(_home_teacher_open_button)
	_home_material_buttons.append(_home_teacher_open_button)

	_interval_options_box = VBoxContainer.new()
	_interval_options_box.add_theme_constant_override("separation", 6)
	_home_panel.add_child(_interval_options_box)

	var intervals_label := Label.new()
	intervals_label.text = "Interval Options"
	intervals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interval_options_box.add_child(intervals_label)

	var interval_row := HBoxContainer.new()
	interval_row.alignment = BoxContainer.ALIGNMENT_CENTER
	interval_row.add_theme_constant_override("separation", 10)
	_interval_options_box.add_child(interval_row)

	var degree_label := Label.new()
	degree_label.text = "Scale Degrees:"
	interval_row.add_child(degree_label)

	for degree in range(1, 9):
		var degree_btn := Button.new()
		degree_btn.text = str(degree)
		degree_btn.toggle_mode = true
		degree_btn.button_pressed = true
		degree_btn.custom_minimum_size = Vector2(48, 34)
		degree_btn.toggled.connect(_on_degree_toggled.bind(degree))
		interval_row.add_child(degree_btn)
		_degree_toggles[degree] = degree_btn
		_home_material_buttons.append(degree_btn)

	_include_minor_toggle = CheckButton.new()
	_include_minor_toggle.text = "Include Minor"
	_include_minor_toggle.button_pressed = false
	_include_minor_toggle.toggled.connect(_on_include_minor_toggled)
	interval_row.add_child(_include_minor_toggle)

	_chord_options_box = VBoxContainer.new()
	_chord_options_box.add_theme_constant_override("separation", 6)
	_home_panel.add_child(_chord_options_box)

	var chord_options_title := Label.new()
	chord_options_title.text = "Chord Options"
	chord_options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chord_options_box.add_child(chord_options_title)

	_inversion_toggle = CheckButton.new()
	_inversion_toggle.text = "Inversions"
	_inversion_toggle.button_pressed = true
	_inversion_toggle.tooltip_text = "Root, 1st, and 2nd inversion"
	_chord_options_box.add_child(_inversion_toggle)

	_adaptive_toggle = CheckButton.new()
	_adaptive_toggle.text = "Adaptive in All"
	_adaptive_toggle.button_pressed = true
	_adaptive_toggle.disabled = true
	_adaptive_toggle.tooltip_text = "All mode auto-progresses by streak"
	_chord_options_box.add_child(_adaptive_toggle)

	var group_label := Label.new()
	group_label.text = "Chord Group"
	group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chord_options_box.add_child(group_label)

	var group_row := HBoxContainer.new()
	group_row.alignment = BoxContainer.ALIGNMENT_CENTER
	group_row.add_theme_constant_override("separation", 8)
	_chord_options_box.add_child(group_row)

	var group_defs := {
		1: "Maj/Min",
		2: "Aug/Dim",
		3: "Sus & 7th",
		4: "All"
	}
	for group_id in [1, 2, 3, 4]:
		var g_btn := Button.new()
		g_btn.text = str(group_defs[group_id])
		g_btn.custom_minimum_size = Vector2(116, 34)
		g_btn.pressed.connect(_on_chord_group_button_pressed.bind(group_id))
		group_row.add_child(g_btn)
		_chord_group_buttons[group_id] = g_btn
		_home_material_buttons.append(g_btn)

	_sight_options_box = VBoxContainer.new()
	_sight_options_box.add_theme_constant_override("separation", 6)
	_home_panel.add_child(_sight_options_box)

	var sight_options_title := Label.new()
	sight_options_title.text = "Sight Reader Options"
	sight_options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_options_box.add_child(sight_options_title)

	var sight_mode_row := HBoxContainer.new()
	sight_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_mode_row.add_theme_constant_override("separation", 8)
	_sight_options_box.add_child(sight_mode_row)

	var sight_notes_btn := Button.new()
	sight_notes_btn.text = "Notes"
	sight_notes_btn.custom_minimum_size = Vector2(110, 34)
	sight_notes_btn.pressed.connect(_on_sight_mode_button_pressed.bind("Notes"))
	sight_mode_row.add_child(sight_notes_btn)
	_sight_mode_buttons["Notes"] = sight_notes_btn
	_home_material_buttons.append(sight_notes_btn)

	var sight_chords_btn := Button.new()
	sight_chords_btn.text = "Chords"
	sight_chords_btn.custom_minimum_size = Vector2(110, 34)
	sight_chords_btn.pressed.connect(_on_sight_mode_button_pressed.bind("Chords"))
	sight_mode_row.add_child(sight_chords_btn)
	_sight_mode_buttons["Chords"] = sight_chords_btn
	_home_material_buttons.append(sight_chords_btn)

	var clef_row := HBoxContainer.new()
	clef_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clef_row.add_theme_constant_override("separation", 8)
	_sight_options_box.add_child(clef_row)

	var treble_btn := Button.new()
	treble_btn.text = "Treble Clef"
	treble_btn.custom_minimum_size = Vector2(130, 34)
	treble_btn.pressed.connect(_on_clef_button_pressed.bind("Treble"))
	clef_row.add_child(treble_btn)
	_clef_buttons["Treble"] = treble_btn
	_home_material_buttons.append(treble_btn)

	var bass_btn := Button.new()
	bass_btn.text = "Bass Clef"
	bass_btn.custom_minimum_size = Vector2(130, 34)
	bass_btn.pressed.connect(_on_clef_button_pressed.bind("Bass"))
	clef_row.add_child(bass_btn)
	_clef_buttons["Bass"] = bass_btn
	_home_material_buttons.append(bass_btn)

	_sight_range_container = VBoxContainer.new()
	_sight_range_container.add_theme_constant_override("separation", 4)
	_sight_options_box.add_child(_sight_range_container)

	var range_title := Label.new()
	range_title.text = "Range"
	range_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_container.add_child(range_title)

	_sight_range_info_label = Label.new()
	_sight_range_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_container.add_child(_sight_range_info_label)

	var range_row := HBoxContainer.new()
	range_row.alignment = BoxContainer.ALIGNMENT_CENTER
	range_row.add_theme_constant_override("separation", 8)
	_sight_range_container.add_child(range_row)

	var lower_minus := Button.new()
	lower_minus.text = "-"
	lower_minus.custom_minimum_size = Vector2(36, 30)
	lower_minus.pressed.connect(_on_sight_range_adjust.bind(1, false))
	range_row.add_child(lower_minus)
	_home_material_buttons.append(lower_minus)

	_sight_range_lower_value_label = Label.new()
	_sight_range_lower_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_lower_value_label.custom_minimum_size = Vector2(54, 0)
	range_row.add_child(_sight_range_lower_value_label)

	var lower_plus := Button.new()
	lower_plus.text = "+"
	lower_plus.custom_minimum_size = Vector2(36, 30)
	lower_plus.pressed.connect(_on_sight_range_adjust.bind(-1, false))
	range_row.add_child(lower_plus)
	_home_material_buttons.append(lower_plus)

	var to_label := Label.new()
	to_label.text = "to"
	to_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	to_label.custom_minimum_size = Vector2(26, 0)
	range_row.add_child(to_label)

	var upper_minus := Button.new()
	upper_minus.text = "-"
	upper_minus.custom_minimum_size = Vector2(36, 30)
	upper_minus.pressed.connect(_on_sight_range_adjust.bind(1, true))
	range_row.add_child(upper_minus)
	_home_material_buttons.append(upper_minus)

	_sight_range_upper_value_label = Label.new()
	_sight_range_upper_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_upper_value_label.custom_minimum_size = Vector2(54, 0)
	range_row.add_child(_sight_range_upper_value_label)

	var upper_plus := Button.new()
	upper_plus.text = "+"
	upper_plus.custom_minimum_size = Vector2(36, 30)
	upper_plus.pressed.connect(_on_sight_range_adjust.bind(-1, true))
	range_row.add_child(upper_plus)
	_home_material_buttons.append(upper_plus)

	_read_options_box = VBoxContainer.new()
	_read_options_box.add_theme_constant_override("separation", 6)
	_home_panel.add_child(_read_options_box)

	var read_title := Label.new()
	read_title.text = "Read Notation Modules"
	read_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_read_options_box.add_child(read_title)

	var read_row := HBoxContainer.new()
	read_row.alignment = BoxContainer.ALIGNMENT_CENTER
	read_row.add_theme_constant_override("separation", 8)
	_read_options_box.add_child(read_row)

	var m1_btn := Button.new()
	m1_btn.text = "Module 1"
	m1_btn.custom_minimum_size = Vector2(120, 34)
	m1_btn.pressed.connect(_on_read_module_button_pressed.bind(1))
	read_row.add_child(m1_btn)
	_read_module_buttons[1] = m1_btn
	_home_material_buttons.append(m1_btn)

	var m2_btn := Button.new()
	m2_btn.text = "Module 2"
	m2_btn.custom_minimum_size = Vector2(120, 34)
	m2_btn.pressed.connect(_on_read_module_button_pressed.bind(2))
	read_row.add_child(m2_btn)
	_read_module_buttons[2] = m2_btn
	_home_material_buttons.append(m2_btn)

	_home_start_button = Button.new()
	_home_start_button.text = "Start Training"
	_home_start_button.custom_minimum_size = Vector2(220, 56)
	_home_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_home_start_button.pressed.connect(_on_start_quiz_pressed)
	_home_panel.add_child(_home_start_button)
	_home_material_buttons.append(_home_start_button)

	_home_info_label = Label.new()
	_home_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_info_label.modulate = Color(1.0, 0.9, 0.7)
	_home_panel.add_child(_home_info_label)

	_game_card = PanelContainer.new()
	_game_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_child(_game_card)

	_game_panel = VBoxContainer.new()
	_game_panel.add_theme_constant_override("separation", 10)
	_game_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_card.add_child(_game_panel)

	var hud_row := HBoxContainer.new()
	hud_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_row.add_theme_constant_override("separation", 12)
	_game_panel.add_child(hud_row)

	_hud_left_box = PanelContainer.new()
	_hud_left_box.custom_minimum_size = Vector2(186, 50)
	hud_row.add_child(_hud_left_box)

	var hud_left_v := VBoxContainer.new()
	hud_left_v.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_left_box.add_child(hud_left_v)
	_lives_label = Label.new()
	_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lives_label.add_theme_font_size_override("font_size", 20)
	hud_left_v.add_child(_lives_label)

	_hud_center_box = PanelContainer.new()
	_hud_center_box.custom_minimum_size = Vector2(360, 74)
	hud_row.add_child(_hud_center_box)

	var hud_center_v := VBoxContainer.new()
	hud_center_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_center_v.add_theme_constant_override("separation", 2)
	_hud_center_box.add_child(hud_center_v)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 20)
	hud_center_v.add_child(_score_label)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 16)
	hud_center_v.add_child(_progress_label)

	_hud_right_box = PanelContainer.new()
	_hud_right_box.custom_minimum_size = Vector2(212, 74)
	hud_row.add_child(_hud_right_box)

	var hud_right_v := VBoxContainer.new()
	hud_right_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_right_v.add_theme_constant_override("separation", 2)
	_hud_right_box.add_child(hud_right_v)
	_streak_label = Label.new()
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.add_theme_font_size_override("font_size", 18)
	hud_right_v.add_child(_streak_label)
	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 18)
	hud_right_v.add_child(_xp_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 20)
	_game_panel.add_child(_status_label)

	_control_row = HBoxContainer.new()
	_control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_control_row.add_theme_constant_override("separation", 12)
	_game_panel.add_child(_control_row)

	_replay_button = Button.new()
	_replay_button.text = "Replay"
	_replay_button.custom_minimum_size = Vector2(130, 44)
	_replay_button.pressed.connect(_on_replay_pressed)
	_control_row.add_child(_replay_button)

	_slow_toggle = CheckBox.new()
	_slow_toggle.text = "Slow Mode"
	_slow_toggle.button_pressed = false
	_control_row.add_child(_slow_toggle)

	_sight_container = VBoxContainer.new()
	_sight_container.add_theme_constant_override("separation", 0)
	_sight_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sight_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_sight_container.visible = false
	_game_panel.add_child(_sight_container)

	_sight_top_spacer = Control.new()
	_sight_top_spacer.custom_minimum_size = Vector2(0, 0)
	_sight_container.add_child(_sight_top_spacer)

	var sight_staff_row := HBoxContainer.new()
	sight_staff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_staff_row.add_theme_constant_override("separation", 18)
	_sight_container.add_child(sight_staff_row)

	_staff_area = Control.new()
	_staff_area.custom_minimum_size = Vector2(500, 320)
	_staff_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_staff_area.gui_input.connect(_on_staff_area_gui_input)
	sight_staff_row.add_child(_staff_area)

	_sight_side_controls = VBoxContainer.new()
	_sight_side_controls.add_theme_constant_override("separation", 16)
	_sight_side_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_staff_row.add_child(_sight_side_controls)

	_staff_clef_label = Label.new()
	_staff_clef_label.text = "𝄞"
	_staff_clef_label.position = Vector2(16, STAFF_TOP_LINE_Y - 36)
	_staff_clef_label.add_theme_font_size_override("font_size", 132)
	_staff_clef_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_staff_area.add_child(_staff_clef_label)

	for i in 5:
		var line := ColorRect.new()
		line.color = Color(1.0, 1.0, 1.0, 0.95)
		line.custom_minimum_size = Vector2(STAFF_LINE_WIDTH, 2)
		line.position = Vector2(STAFF_LEFT_X, STAFF_TOP_LINE_Y + (i * STAFF_LINE_GAP_Y))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(line)
		_staff_lines.append(line)

		var n_lbl := Label.new()
		n_lbl.text = str(5 - i)
		n_lbl.position = Vector2(STAFF_LEFT_X + STAFF_LINE_WIDTH + 10, line.position.y - 10)
		n_lbl.add_theme_font_size_override("font_size", 16)
		n_lbl.visible = false
		n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(n_lbl)
		_staff_line_number_labels.append(n_lbl)

	_staff_note = Panel.new()
	_staff_note.size = Vector2(26, 18)
	_staff_note.rotation_degrees = -15.0
	_staff_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_staff_note.gui_input.connect(_on_staff_note_gui_input)
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	note_style.corner_radius_top_left = 40
	note_style.corner_radius_top_right = 40
	note_style.corner_radius_bottom_left = 40
	note_style.corner_radius_bottom_right = 40
	_staff_note.add_theme_stylebox_override("panel", note_style)
	_staff_area.add_child(_staff_note)

	for i in range(6):
		var pl := ColorRect.new()
		pl.color = Color(0.95, 0.8, 0.35, 0.95)
		pl.size = Vector2(42, 2)
		pl.visible = false
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(pl)
		_staff_preview_ledgers.append(pl)

	for i in range(16):
		var d := Panel.new()
		d.size = Vector2(4, 4)
		d.visible = false
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(0.72, 1.0, 0.20, 1.0)
		ds.corner_radius_top_left = 3
		ds.corner_radius_top_right = 3
		ds.corner_radius_bottom_left = 3
		ds.corner_radius_bottom_right = 3
		d.add_theme_stylebox_override("panel", ds)
		_staff_area.add_child(d)
		_placement_target_dots.append(d)

	for i in 2:
		var extra_note := Panel.new()
		extra_note.size = _staff_note.size
		extra_note.rotation_degrees = _staff_note.rotation_degrees
		extra_note.visible = false
		extra_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		extra_note.add_theme_stylebox_override("panel", note_style.duplicate())
		_staff_area.add_child(extra_note)
		_staff_chord_notes.append(extra_note)

	var keyboard_spacer := Control.new()
	keyboard_spacer.custom_minimum_size = Vector2(0, 0)
	_sight_container.add_child(keyboard_spacer)

	var keyboard_row := HBoxContainer.new()
	keyboard_row.alignment = BoxContainer.ALIGNMENT_CENTER
	keyboard_row.add_theme_constant_override("separation", 2)
	_sight_container.add_child(keyboard_row)

	for note_name in ["C", "D", "E", "F", "G", "A", "B"]:
		var k_btn := Button.new()
		k_btn.text = note_name
		k_btn.custom_minimum_size = Vector2(64, 38)
		k_btn.pressed.connect(_on_sight_key_chosen.bind(note_name))
		keyboard_row.add_child(k_btn)
		_answer_buttons.append(k_btn)
		_sight_key_buttons[note_name] = k_btn
		_style_key_button(k_btn)

	var sight_chord_row := HBoxContainer.new()
	sight_chord_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_chord_row.add_theme_constant_override("separation", 8)
	_sight_container.add_child(sight_chord_row)
	for i in 3:
		var sc_btn := Button.new()
		sc_btn.text = "?"
		sc_btn.custom_minimum_size = Vector2(170, 44)
		sc_btn.pressed.connect(_on_sight_chord_choice_index.bind(i))
		sight_chord_row.add_child(sc_btn)
		_answer_buttons.append(sc_btn)
		_sight_chord_choice_buttons.append(sc_btn)

	_teacher_panel = VBoxContainer.new()
	_teacher_panel.visible = false
	_teacher_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_teacher_panel.add_theme_constant_override("separation", 10)
	_game_panel.add_child(_teacher_panel)

	var teacher_panel_title := Label.new()
	teacher_panel_title.text = "Teacher Dashboard"
	teacher_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teacher_panel_title.add_theme_font_size_override("font_size", 30)
	_teacher_panel.add_child(teacher_panel_title)

	var teacher_layout := HBoxContainer.new()
	teacher_layout.add_theme_constant_override("separation", 12)
	_teacher_panel.add_child(teacher_layout)

	var teacher_left := VBoxContainer.new()
	teacher_left.custom_minimum_size = Vector2(300, 0)
	teacher_left.add_theme_constant_override("separation", 8)
	teacher_layout.add_child(teacher_left)

	var student_list_title := Label.new()
	student_list_title.text = "Students"
	teacher_left.add_child(student_list_title)

	_teacher_filter_option = OptionButton.new()
	_teacher_filter_option.add_item("All Students", 0)
	_teacher_filter_option.add_item("Ear < 70%", 1)
	_teacher_filter_option.add_item("Sight < 70%", 2)
	_teacher_filter_option.add_item("Modules < 3", 3)
	_teacher_filter_option.item_selected.connect(_on_teacher_filter_changed)
	teacher_left.add_child(_teacher_filter_option)

	_teacher_analytics_label = Label.new()
	_teacher_analytics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teacher_left.add_child(_teacher_analytics_label)

	_teacher_students_list = ItemList.new()
	_teacher_students_list.custom_minimum_size = Vector2(300, 260)
	_teacher_students_list.allow_reselect = true
	_teacher_students_list.item_selected.connect(_on_teacher_student_selected)
	teacher_left.add_child(_teacher_students_list)

	var list_btn_row := HBoxContainer.new()
	list_btn_row.add_theme_constant_override("separation", 8)
	teacher_left.add_child(list_btn_row)
	var new_student_btn := Button.new()
	new_student_btn.text = "New Student"
	new_student_btn.pressed.connect(_on_teacher_new_student_pressed)
	list_btn_row.add_child(new_student_btn)
	var delete_student_btn := Button.new()
	delete_student_btn.text = "Delete Student"
	delete_student_btn.pressed.connect(_on_teacher_delete_student_pressed)
	list_btn_row.add_child(delete_student_btn)

	var teacher_right_scroll := ScrollContainer.new()
	teacher_right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teacher_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teacher_layout.add_child(teacher_right_scroll)

	var teacher_right := VBoxContainer.new()
	teacher_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teacher_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teacher_right.add_theme_constant_override("separation", 8)
	teacher_right_scroll.add_child(teacher_right)

	_teacher_selected_student_label = Label.new()
	_teacher_selected_student_label.text = "Selected Student: none"
	_teacher_selected_student_label.add_theme_font_size_override("font_size", 18)
	teacher_right.add_child(_teacher_selected_student_label)

	_teacher_status_label = Label.new()
	teacher_right.add_child(_teacher_status_label)

	_teacher_tabs = TabContainer.new()
	_teacher_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_teacher_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teacher_right.add_child(_teacher_tabs)

	var students_tab := VBoxContainer.new()
	students_tab.name = "Students"
	students_tab.add_theme_constant_override("separation", 8)
	_teacher_tabs.add_child(students_tab)

	var form_title := Label.new()
	form_title.text = "Student Profile"
	students_tab.add_child(form_title)

	var name_age_row := HBoxContainer.new()
	name_age_row.add_theme_constant_override("separation", 8)
	students_tab.add_child(name_age_row)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_age_row.add_child(name_box)
	var name_lbl := Label.new()
	name_lbl.text = "Student Name"
	name_box.add_child(name_lbl)
	_teacher_name_edit = LineEdit.new()
	_teacher_name_edit.placeholder_text = "Enter full name"
	name_box.add_child(_teacher_name_edit)

	var age_box := VBoxContainer.new()
	age_box.custom_minimum_size = Vector2(140, 0)
	name_age_row.add_child(age_box)
	var age_lbl := Label.new()
	age_lbl.text = "Age"
	age_box.add_child(age_lbl)
	_teacher_age_spin = SpinBox.new()
	_teacher_age_spin.min_value = 3
	_teacher_age_spin.max_value = 100
	_teacher_age_spin.step = 1
	_teacher_age_spin.value = 10
	age_box.add_child(_teacher_age_spin)

	_teacher_level_edit = null

	var book_part_row := HBoxContainer.new()
	book_part_row.add_theme_constant_override("separation", 8)
	students_tab.add_child(book_part_row)

	var book_box := VBoxContainer.new()
	book_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_part_row.add_child(book_box)
	var book_lbl := Label.new()
	book_lbl.text = "Active Method Book"
	book_box.add_child(book_lbl)
	_teacher_book_name_edit = LineEdit.new()
	_teacher_book_name_edit.custom_minimum_size = Vector2(320, 0)
	_teacher_book_name_edit.placeholder_text = "Book title"
	book_box.add_child(_teacher_book_name_edit)

	var part_box := VBoxContainer.new()
	part_box.custom_minimum_size = Vector2(170, 0)
	book_part_row.add_child(part_box)
	var part_lbl := Label.new()
	part_lbl.text = "Book Part / Unit"
	part_box.add_child(part_lbl)
	_teacher_book_part_edit = LineEdit.new()
	_teacher_book_part_edit.placeholder_text = "Part/Unit"
	part_box.add_child(_teacher_book_part_edit)

	var student_btn_row := HBoxContainer.new()
	student_btn_row.add_theme_constant_override("separation", 8)
	students_tab.add_child(student_btn_row)
	var save_student_btn := Button.new()
	save_student_btn.text = "Save Student"
	save_student_btn.pressed.connect(_on_teacher_save_student_pressed)
	student_btn_row.add_child(save_student_btn)
	var clear_form_btn := Button.new()
	clear_form_btn.text = "Clear"
	clear_form_btn.pressed.connect(_on_teacher_new_student_pressed)
	student_btn_row.add_child(clear_form_btn)

	var repertoire_tab := VBoxContainer.new()
	repertoire_tab.name = "Repertoire"
	repertoire_tab.add_theme_constant_override("separation", 8)
	_teacher_tabs.add_child(repertoire_tab)

	var pieces_header := HBoxContainer.new()
	pieces_header.add_theme_constant_override("separation", 8)
	repertoire_tab.add_child(pieces_header)
	var pieces_lbl := Label.new()
	pieces_lbl.text = "Active Repertoire Pieces"
	pieces_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pieces_header.add_child(pieces_lbl)
	var add_piece_btn := Button.new()
	add_piece_btn.text = "+"
	add_piece_btn.custom_minimum_size = Vector2(42, 32)
	add_piece_btn.pressed.connect(_on_teacher_add_piece_row_pressed)
	pieces_header.add_child(add_piece_btn)

	_teacher_piece_fields_box = VBoxContainer.new()
	_teacher_piece_fields_box.add_theme_constant_override("separation", 6)
	repertoire_tab.add_child(_teacher_piece_fields_box)
	_teacher_rebuild_piece_fields([])

	var rep_save_row := HBoxContainer.new()
	rep_save_row.add_theme_constant_override("separation", 8)
	repertoire_tab.add_child(rep_save_row)
	var rep_save_btn := Button.new()
	rep_save_btn.text = "Save Repertoire"
	rep_save_btn.pressed.connect(_on_teacher_save_student_pressed)
	rep_save_row.add_child(rep_save_btn)
	var rep_book_done_btn := Button.new()
	rep_book_done_btn.text = "Book Done"
	rep_book_done_btn.pressed.connect(_on_teacher_mark_book_done_pressed)
	rep_save_row.add_child(rep_book_done_btn)

	var assignments_tab := VBoxContainer.new()
	assignments_tab.name = "Assignments"
	assignments_tab.add_theme_constant_override("separation", 8)
	_teacher_tabs.add_child(assignments_tab)

	var assignment_title := Label.new()
	assignment_title.text = "Assignments (Next Week)"
	assignments_tab.add_child(assignment_title)

	var assignment_row := HBoxContainer.new()
	assignment_row.add_theme_constant_override("separation", 8)
	assignments_tab.add_child(assignment_row)
	_teacher_assignment_task_edit = LineEdit.new()
	_teacher_assignment_task_edit.placeholder_text = "Task"
	_teacher_assignment_task_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assignment_row.add_child(_teacher_assignment_task_edit)
	_teacher_assignment_due_edit = LineEdit.new()
	_teacher_assignment_due_edit.placeholder_text = "Due YYYY-MM-DD"
	_teacher_assignment_due_edit.custom_minimum_size = Vector2(140, 0)
	assignment_row.add_child(_teacher_assignment_due_edit)
	var add_assignment_btn := Button.new()
	add_assignment_btn.text = "Add"
	add_assignment_btn.pressed.connect(_on_teacher_add_assignment_pressed)
	assignment_row.add_child(add_assignment_btn)

	_teacher_assignments_list = ItemList.new()
	_teacher_assignments_list.custom_minimum_size = Vector2(0, 120)
	_teacher_assignments_list.allow_reselect = true
	assignments_tab.add_child(_teacher_assignments_list)

	var assignment_btn_row := HBoxContainer.new()
	assignment_btn_row.add_theme_constant_override("separation", 8)
	assignments_tab.add_child(assignment_btn_row)
	var assignment_done_btn := Button.new()
	assignment_done_btn.text = "Mark Done"
	assignment_done_btn.pressed.connect(_on_teacher_mark_assignment_done_pressed)
	assignment_btn_row.add_child(assignment_done_btn)
	var assignment_remove_btn := Button.new()
	assignment_remove_btn.text = "Remove"
	assignment_remove_btn.pressed.connect(_on_teacher_remove_assignment_pressed)
	assignment_btn_row.add_child(assignment_remove_btn)

	var assignments_save_row := HBoxContainer.new()
	assignments_save_row.add_theme_constant_override("separation", 8)
	assignments_tab.add_child(assignments_save_row)
	var assignments_save_btn := Button.new()
	assignments_save_btn.text = "Save Assignments"
	assignments_save_btn.pressed.connect(_on_teacher_save_student_pressed)
	assignments_save_row.add_child(assignments_save_btn)

	var progress_tab := VBoxContainer.new()
	progress_tab.name = "Progress"
	progress_tab.add_theme_constant_override("separation", 8)
	_teacher_tabs.add_child(progress_tab)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	progress_tab.add_child(cards_row)
	_teacher_progress_ear_label = Label.new()
	_teacher_progress_ear_label.text = "Ear: 0%"
	_teacher_progress_ear_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_child(_teacher_progress_ear_label)
	_teacher_progress_sight_label = Label.new()
	_teacher_progress_sight_label.text = "Sight: 0%"
	_teacher_progress_sight_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_child(_teacher_progress_sight_label)
	_teacher_progress_modules_label = Label.new()
	_teacher_progress_modules_label.text = "Modules: 0"
	_teacher_progress_modules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_child(_teacher_progress_modules_label)

	var progress_title := Label.new()
	progress_title.text = "Student Progress Details"
	progress_tab.add_child(progress_title)

	_teacher_dashboard_text = RichTextLabel.new()
	_teacher_dashboard_text.custom_minimum_size = Vector2(0, 260)
	_teacher_dashboard_text.fit_content = false
	_teacher_dashboard_text.scroll_active = true
	progress_tab.add_child(_teacher_dashboard_text)

	var export_row := HBoxContainer.new()
	export_row.add_theme_constant_override("separation", 8)
	progress_tab.add_child(export_row)
	_teacher_export_csv_button = Button.new()
	_teacher_export_csv_button.text = "Export CSV"
	_teacher_export_csv_button.pressed.connect(_on_teacher_export_csv_pressed)
	export_row.add_child(_teacher_export_csv_button)
	_teacher_export_report_button = Button.new()
	_teacher_export_report_button.text = "Export Parent Report"
	_teacher_export_report_button.pressed.connect(_on_teacher_export_report_pressed)
	export_row.add_child(_teacher_export_report_button)

	_teacher_piece_note_dialog = AcceptDialog.new()
	_teacher_piece_note_dialog.title = "Lesson Notes"
	_teacher_piece_note_dialog.ok_button_text = "Save Notes"
	_teacher_piece_note_dialog.confirmed.connect(_on_teacher_piece_notes_save_confirmed)
	_teacher_panel.add_child(_teacher_piece_note_dialog)
	var note_wrap := MarginContainer.new()
	note_wrap.add_theme_constant_override("margin_left", 12)
	note_wrap.add_theme_constant_override("margin_top", 12)
	note_wrap.add_theme_constant_override("margin_right", 12)
	note_wrap.add_theme_constant_override("margin_bottom", 12)
	_teacher_piece_note_dialog.add_child(note_wrap)
	_teacher_piece_note_edit = TextEdit.new()
	_teacher_piece_note_edit.custom_minimum_size = Vector2(420, 180)
	note_wrap.add_child(_teacher_piece_note_edit)

	_teacher_piece_delete_confirm = ConfirmationDialog.new()
	_teacher_piece_delete_confirm.title = "Delete Repertoire Entry"
	_teacher_piece_delete_confirm.dialog_text = "Delete this piece entry?"
	_teacher_piece_delete_confirm.confirmed.connect(_on_teacher_piece_delete_confirmed)
	_teacher_panel.add_child(_teacher_piece_delete_confirm)

	_sky_block = Control.new()
	_sky_block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sky_block.custom_minimum_size = Vector2(0, 78)
	_game_panel.add_child(_sky_block)

	_sky_area = Control.new()
	_sky_area.set_anchors_preset(PRESET_FULL_RECT)
	_sky_block.add_child(_sky_area)

	_bird_sprite = TextureRect.new()
	_bird_sprite.texture = _load_texture(BIRD_TEXTURE_PATH)
	_bird_sprite.custom_minimum_size = Vector2(180, 96)
	_bird_sprite.size = Vector2(180, 96)
	_bird_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bird_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bird_sprite.flip_h = true
	_bird_sprite.modulate = BIRD_TINT
	_bird_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bird_sprite.position = Vector2(24, 110)
	_bird_sprite.pivot_offset = _bird_sprite.custom_minimum_size * 0.5
	_sky_area.add_child(_bird_sprite)

	_tutorial_bubble = PanelContainer.new()
	_tutorial_bubble.visible = false
	_tutorial_bubble.position = Vector2(118, 14)
	_tutorial_bubble.custom_minimum_size = Vector2(470, 104)
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	bubble_style.border_color = Color(0.02, 0.02, 0.02, 0.97)
	bubble_style.border_width_left = 4
	bubble_style.border_width_top = 4
	bubble_style.border_width_right = 4
	bubble_style.border_width_bottom = 4
	bubble_style.corner_radius_top_left = 32
	bubble_style.corner_radius_top_right = 26
	bubble_style.corner_radius_bottom_left = 28
	bubble_style.corner_radius_bottom_right = 30
	bubble_style.shadow_color = Color(0, 0, 0, 0.23)
	bubble_style.shadow_size = 5
	_tutorial_bubble.add_theme_stylebox_override("panel", bubble_style)
	_sky_area.add_child(_tutorial_bubble)

	_tutorial_bubble_tail = Panel.new()
	_tutorial_bubble_tail.visible = false
	_tutorial_bubble_tail.size = Vector2(44, 30)
	_tutorial_bubble_tail.position = Vector2(156, 86)
	_tutorial_bubble_tail.rotation_degrees = -28.0
	var bubble_tail_style := StyleBoxFlat.new()
	bubble_tail_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	bubble_tail_style.border_color = Color(0.02, 0.02, 0.02, 0.97)
	bubble_tail_style.border_width_left = 4
	bubble_tail_style.border_width_top = 4
	bubble_tail_style.border_width_right = 4
	bubble_tail_style.border_width_bottom = 4
	bubble_tail_style.corner_radius_top_left = 8
	bubble_tail_style.corner_radius_top_right = 8
	bubble_tail_style.corner_radius_bottom_left = 16
	bubble_tail_style.corner_radius_bottom_right = 6
	_tutorial_bubble_tail.add_theme_stylebox_override("panel", bubble_tail_style)
	_sky_area.add_child(_tutorial_bubble_tail)

	_tutorial_bubble_label = Label.new()
	_tutorial_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tutorial_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_bubble_label.add_theme_font_size_override("font_size", 16)
	_tutorial_bubble_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 1.0))
	_tutorial_bubble_label.position = Vector2(20, 14)
	_tutorial_bubble_label.size = Vector2(430, 74)
	_tutorial_bubble.add_child(_tutorial_bubble_label)

	_tutorial_chicken = TextureRect.new()
	_tutorial_chicken.texture = _load_texture(TUTORIAL_CHICKEN_PATH)
	_tutorial_chicken.visible = false
	_tutorial_chicken.custom_minimum_size = Vector2(118, 118)
	_tutorial_chicken.size = Vector2(118, 118)
	_tutorial_chicken.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tutorial_chicken.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tutorial_chicken.modulate = Color(1.0, 0.90, 0.72, 1.0)
	_tutorial_chicken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_chicken.position = Vector2(18, 28)
	_tutorial_chicken.z_as_relative = false
	_tutorial_chicken.z_index = 220
	_sky_area.add_child(_tutorial_chicken)

	_food_token = Panel.new()
	_food_token.visible = false
	_food_token.size = Vector2(20, 20)
	_food_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_food_token.z_as_relative = false
	_food_token.z_index = 95
	var food_style := StyleBoxFlat.new()
	food_style.bg_color = Color(0.98, 0.84, 0.28, 1.0)
	food_style.corner_radius_top_left = 12
	food_style.corner_radius_top_right = 12
	food_style.corner_radius_bottom_left = 12
	food_style.corner_radius_bottom_right = 12
	food_style.border_color = Color(0.55, 0.40, 0.08, 0.9)
	food_style.border_width_left = 2
	food_style.border_width_top = 2
	food_style.border_width_right = 2
	food_style.border_width_bottom = 2
	_food_token.add_theme_stylebox_override("panel", food_style)
	add_child(_food_token)

	_prompt_label = Label.new()
	_prompt_label.text = "Choose the interval number:"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_game_panel.add_child(_prompt_label)

	_tutorial_panel = VBoxContainer.new()
	_tutorial_panel.add_theme_constant_override("separation", 8)
	_tutorial_panel.top_level = true
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_panel.visible = false
	_tutorial_panel.z_as_relative = false
	_tutorial_panel.z_index = 250
	_game_panel.add_child(_tutorial_panel)

	_tutorial_button_row = HBoxContainer.new()
	_tutorial_button_row.top_level = true
	_tutorial_button_row.alignment = BoxContainer.ALIGNMENT_END
	_tutorial_button_row.add_theme_constant_override("separation", 10)
	_tutorial_button_row.visible = false
	_tutorial_button_row.z_as_relative = false
	_tutorial_button_row.z_index = 260
	add_child(_tutorial_button_row)

	_tutorial_continue_button = Button.new()
	_tutorial_continue_button.text = "Continue"
	_tutorial_continue_button.custom_minimum_size = Vector2(130, 42)
	_tutorial_continue_button.pressed.connect(_on_tutorial_continue_pressed)
	_tutorial_button_row.add_child(_tutorial_continue_button)

	_tutorial_back_button = Button.new()
	_tutorial_back_button.text = "Back"
	_tutorial_back_button.custom_minimum_size = Vector2(110, 42)
	_tutorial_back_button.visible = false
	_tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	_tutorial_button_row.add_child(_tutorial_back_button)

	_tutorial_module2_button = Button.new()
	_tutorial_module2_button.text = "Go to Module 2"
	_tutorial_module2_button.custom_minimum_size = Vector2(160, 42)
	_tutorial_module2_button.visible = false
	_tutorial_module2_button.pressed.connect(_on_tutorial_module2_pressed)
	_tutorial_button_row.add_child(_tutorial_module2_button)

	_tutorial_home_button = Button.new()
	_tutorial_home_button.text = "Read Notation Home"
	_tutorial_home_button.custom_minimum_size = Vector2(180, 42)
	_tutorial_home_button.visible = false
	_tutorial_home_button.pressed.connect(_on_tutorial_home_pressed)
	_tutorial_button_row.add_child(_tutorial_home_button)

	_tutorial_end_button_col = VBoxContainer.new()
	_tutorial_end_button_col.top_level = true
	_tutorial_end_button_col.add_theme_constant_override("separation", 10)
	_tutorial_end_button_col.visible = false
	_tutorial_end_button_col.z_as_relative = false
	_tutorial_end_button_col.z_index = 260
	add_child(_tutorial_end_button_col)

	_tutorial_end_module2_button = Button.new()
	_tutorial_end_module2_button.text = "Go to Module 2"
	_tutorial_end_module2_button.custom_minimum_size = Vector2(180, 42)
	_tutorial_end_module2_button.visible = false
	_tutorial_end_module2_button.pressed.connect(_on_tutorial_module2_pressed)
	_tutorial_end_button_col.add_child(_tutorial_end_module2_button)

	_tutorial_end_home_button = Button.new()
	_tutorial_end_home_button.text = "Read Notation Home"
	_tutorial_end_home_button.custom_minimum_size = Vector2(180, 42)
	_tutorial_end_home_button.visible = false
	_tutorial_end_home_button.pressed.connect(_on_tutorial_home_pressed)
	_tutorial_end_button_col.add_child(_tutorial_end_home_button)

	_tutorial_end_back_button = Button.new()
	_tutorial_end_back_button.text = "Back"
	_tutorial_end_back_button.custom_minimum_size = Vector2(180, 42)
	_tutorial_end_back_button.visible = false
	_tutorial_end_back_button.pressed.connect(_on_tutorial_back_pressed)
	_tutorial_end_button_col.add_child(_tutorial_end_back_button)

	_tutorial_step_label = Label.new()
	_tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_step_label.add_theme_font_size_override("font_size", 16)
	_tutorial_step_label.modulate = Color(0.96, 0.90, 0.66, 1.0)
	_tutorial_panel.add_child(_tutorial_step_label)

	_tutorial_title_label = Label.new()
	_tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_title_label.add_theme_font_size_override("font_size", 28)
	_tutorial_panel.add_child(_tutorial_title_label)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.add_theme_font_size_override("font_size", 18)
	_tutorial_body_label.visible = false
	_tutorial_panel.add_child(_tutorial_body_label)

	var nests := HBoxContainer.new()
	nests.alignment = BoxContainer.ALIGNMENT_CENTER
	nests.add_theme_constant_override("separation", 12)
	_game_panel.add_child(nests)

	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(116, 64)
		btn.text = "?"
		btn.pressed.connect(_on_interval_choice_index.bind(i))
		nests.add_child(btn)
		_answer_buttons.append(btn)
		_interval_choice_buttons.append(btn)

	var chord_grid := GridContainer.new()
	chord_grid.columns = 5
	chord_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chord_grid.add_theme_constant_override("h_separation", 8)
	chord_grid.add_theme_constant_override("v_separation", 8)
	_game_panel.add_child(chord_grid)

	for chord_name in CHORD_INTERVALS.keys():
		var c_btn := Button.new()
		c_btn.text = chord_name
		c_btn.custom_minimum_size = Vector2(120, 56)
		c_btn.pressed.connect(_on_chord_chosen.bind(chord_name))
		chord_grid.add_child(c_btn)
		_answer_buttons.append(c_btn)
		_chord_buttons[chord_name] = c_btn


	_end_button = Button.new()
	_end_button.text = "Go Back"
	_end_button.custom_minimum_size = Vector2(130, 44)
	_end_button.anchor_left = 1.0
	_end_button.anchor_right = 1.0
	_end_button.anchor_top = 0.0
	_end_button.anchor_bottom = 0.0
	_end_button.offset_left = -154
	_end_button.offset_right = -24
	_end_button.offset_top = 24
	_end_button.offset_bottom = 68
	_end_button.pressed.connect(_on_end_quiz_pressed)
	add_child(_end_button)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.custom_minimum_size = Vector2(130, 44)
	_restart_button.anchor_left = 1.0
	_restart_button.anchor_right = 1.0
	_restart_button.anchor_top = 0.0
	_restart_button.anchor_bottom = 0.0
	_restart_button.offset_left = -298
	_restart_button.offset_right = -168
	_restart_button.offset_top = 24
	_restart_button.offset_bottom = 68
	_restart_button.pressed.connect(_on_restart_quiz_pressed)
	add_child(_restart_button)

	_apply_pro_style()
	if _ui_font != null:
		_end_button.add_theme_font_override("font", _ui_font)
		_restart_button.add_theme_font_override("font", _ui_font)
	_end_button.add_theme_font_size_override("font_size", 17)
	_end_button.add_theme_color_override("font_color", Color(0.20, 0.14, 0.06))
	_style_button(_end_button)
	_restart_button.add_theme_font_size_override("font_size", 17)
	_restart_button.add_theme_color_override("font_color", Color(0.20, 0.14, 0.06))
	_style_button(_restart_button)
	_on_mode_selected()
	_refresh_degree_buttons()
	_refresh_chord_group_buttons()
	_refresh_sight_mode_buttons()
	_refresh_read_module_buttons()
	_update_sight_range_ui()

	_result_overlay = ColorRect.new()
	_result_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_result_overlay.color = Color(0.0, 0.0, 0.0, 0.42)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.z_as_relative = false
	_result_overlay.z_index = 20
	add_child(_result_overlay)

	var result_center := CenterContainer.new()
	result_center.set_anchors_preset(PRESET_FULL_RECT)
	result_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.add_child(result_center)

	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 10)
	result_center.add_child(result_box)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 64)
	result_box.add_child(_result_title)

	_result_subtitle = Label.new()
	_result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_subtitle.add_theme_font_size_override("font_size", 20)
	_result_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_box.add_child(_result_subtitle)

	if _ui_font != null:
		_result_title.add_theme_font_override("font", _ui_font)
		_result_subtitle.add_theme_font_override("font", _ui_font)
	_result_box_hide()
	_end_button.z_as_relative = false
	_end_button.z_index = 100
	_restart_button.z_as_relative = false
	_restart_button.z_index = 100
	_end_button.move_to_front()
	_restart_button.move_to_front()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _load_texture(FARM_BG_PATH)
	add_child(bg)

	var tint := ColorRect.new()
	tint.set_anchors_preset(PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0.08, 0.12, 0.08, 0.26)
	add_child(tint)

	var grass_tint := ColorRect.new()
	grass_tint.anchor_top = 0.62
	grass_tint.anchor_right = 1.0
	grass_tint.anchor_bottom = 1.0
	grass_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grass_tint.color = Color(0.83, 0.78, 0.50, 0.24)
	add_child(grass_tint)

	for i in TREE_LAYERS.size():
		var tree := TextureRect.new()
		tree.anchor_top = 1.0
		tree.anchor_bottom = 1.0
		tree.anchor_right = 1.0
		tree.offset_top = -330 + (i * 8)
		tree.offset_bottom = -10 + (i * 6)
		tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tree.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tree.texture = _load_texture(TREE_LAYERS[i])
		tree.modulate = Color(1, 1, 1, 0.55 + (i * 0.1))
		add_child(tree)


func _apply_pro_style() -> void:
	_ui_font = ResourceLoader.load(UI_FONT_PATH) as Font
	if _ui_font == null:
		return

	_title_label.add_theme_font_override("font", _ui_font)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.86))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)

	_style_card(_home_card, Color(0.10, 0.14, 0.11, 0.74))
	_style_card(_game_card, Color(0.10, 0.14, 0.11, 0.70))
	_style_hud_box(_hud_left_box)
	_style_hud_box(_hud_right_box)
	_style_hud_box(_hud_center_box)
	_style_controls_recursive(self)
	for btn in _home_material_buttons:
		_style_material_button(btn)
	if _tutorial_bubble_label != null:
		_tutorial_bubble_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 1.0))
		_tutorial_bubble_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))


func _style_card(card: PanelContainer, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_color = Color(0.92, 0.84, 0.58, 0.45)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.content_margin_left = 20
	sb.content_margin_top = 16
	sb.content_margin_right = 20
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)


func _style_controls_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			label.add_theme_font_override("font", _ui_font)
			label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
		elif child is CheckButton:
			var sw := child as CheckButton
			sw.add_theme_font_override("font", _ui_font)
			sw.add_theme_font_size_override("font_size", 17)
			sw.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
		elif child is Button:
			var btn := child as Button
			btn.add_theme_font_override("font", _ui_font)
			btn.add_theme_font_size_override("font_size", 19)
			btn.add_theme_color_override("font_color", Color(0.20, 0.14, 0.06))
			btn.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.04))
			btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
			_style_button(btn)
		elif child is CheckBox:
			var cb := child as CheckBox
			cb.add_theme_font_override("font", _ui_font)
			cb.add_theme_font_size_override("font_size", 18)
			cb.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
		elif child is SpinBox:
			var spin := child as SpinBox
			spin.add_theme_font_override("font", _ui_font)
			spin.add_theme_font_size_override("font_size", 18)
		_style_controls_recursive(child)


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.84, 0.74, 0.42, 0.92)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_color = Color(0.27, 0.20, 0.08, 0.65)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.93, 0.82, 0.46, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.73, 0.61, 0.33, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)


func _style_material_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.84, 0.74, 0.42, 0.96)
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 5
	normal.border_color = Color(0.30, 0.23, 0.10, 0.68)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.93, 0.82, 0.46, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.73, 0.61, 0.33, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(0.20, 0.14, 0.06))
	btn.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.04))
	btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	btn.add_theme_font_size_override("font_size", 16)


func _set_home_selection_state(btn: Button, selected: bool) -> void:
	btn.disabled = false
	var normal := btn.get_theme_stylebox("normal")
	if normal is StyleBoxFlat:
		var sb := normal as StyleBoxFlat
		if selected:
			sb.bg_color = Color(0.76, 0.63, 0.33, 1.0)
			sb.border_color = Color(1.0, 0.98, 0.90, 1.0)
			sb.border_width_left = 4
			sb.border_width_top = 4
			sb.border_width_right = 4
			sb.border_width_bottom = 4
		else:
			sb.bg_color = Color(0.84, 0.74, 0.42, 0.96)
			sb.border_color = Color(0.30, 0.23, 0.10, 0.68)
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
	var hover := btn.get_theme_stylebox("hover")
	if hover is StyleBoxFlat:
		var hb := hover as StyleBoxFlat
		if selected:
			hb.bg_color = Color(0.82, 0.69, 0.39, 1.0)
			hb.border_color = Color(1.0, 0.98, 0.90, 1.0)
			hb.border_width_left = 4
			hb.border_width_top = 4
			hb.border_width_right = 4
			hb.border_width_bottom = 4
		else:
			hb.bg_color = Color(0.93, 0.82, 0.46, 1.0)
			hb.border_color = Color(0.30, 0.23, 0.10, 0.68)
			hb.border_width_left = 2
			hb.border_width_top = 2
			hb.border_width_right = 2
			hb.border_width_bottom = 2
	var pressed := btn.get_theme_stylebox("pressed")
	if pressed is StyleBoxFlat:
		var pb := pressed as StyleBoxFlat
		if selected:
			pb.bg_color = Color(0.72, 0.58, 0.30, 1.0)
			pb.border_color = Color(1.0, 0.98, 0.90, 1.0)
			pb.border_width_left = 4
			pb.border_width_top = 4
			pb.border_width_right = 4
			pb.border_width_bottom = 4
		else:
			pb.bg_color = Color(0.73, 0.61, 0.33, 1.0)
			pb.border_color = Color(0.30, 0.23, 0.10, 0.68)
			pb.border_width_left = 2
			pb.border_width_top = 2
			pb.border_width_right = 2
			pb.border_width_bottom = 2
	btn.modulate = Color(1, 1, 1, 1)


func _interval_display_name(interval_id: String) -> String:
	match interval_id:
		"P1":
			return "Unison"
		"m2":
			return "Minor 2nd"
		"M2":
			return "Major 2nd"
		"m3":
			return "Minor 3rd"
		"M3":
			return "Major 3rd"
		"P4":
			return "Perfect 4th"
		"TT":
			return "Tritone"
		"P5":
			return "Perfect 5th"
		"m6":
			return "Minor 6th"
		"M6":
			return "Major 6th"
		"m7":
			return "Minor 7th"
		"M7":
			return "Major 7th"
		"P8":
			return "Octave"
		_:
			return interval_id


func _style_hud_box(box: PanelContainer) -> void:
	if box == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.07, 0.78)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_color = Color(0.95, 0.86, 0.62, 0.40)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", sb)


func _result_box_show(title_text: String, subtitle_text: String) -> void:
	_result_title.text = title_text
	_result_subtitle.text = subtitle_text
	_result_overlay.visible = true


func _result_box_hide() -> void:
	if _result_overlay != null:
		_result_overlay.visible = false


func _post_layout_init() -> void:
	if _bird_sprite != null:
		_bird_home_global_position = global_position + Vector2(40, 185)
		_bird_home_ready = true
	_reset_bird_position()
	_start_bird_idle_anim()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		var tex := ResourceLoader.load(path) as Texture2D
		if tex != null:
			return tex
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null


func _setup_audio() -> void:
	_piano_player = AudioStreamPlayer.new()
	add_child(_piano_player)
	_load_piano_samples()
	for i in 5:
		var chord_player := AudioStreamPlayer.new()
		add_child(chord_player)
		_chord_players.append(chord_player)

	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_success_sfx = _load_audio_stream(SUCCESS_SFX_PATH)
	_fail_sfx = _load_audio_stream(FAIL_SFX_PATH)

	_audio_stream = AudioStreamGenerator.new()
	_audio_stream.mix_rate = 44100
	_audio_stream.buffer_length = 0.45

	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _audio_stream
	add_child(_audio_player)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback()


func _load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path, "AudioStream"):
		return ResourceLoader.load(path) as AudioStream

	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null

	if path.to_lower().ends_with(".mp3"):
		var bytes := FileAccess.get_file_as_bytes(abs_path)
		if bytes.size() > 0:
			var stream := AudioStreamMP3.new()
			stream.data = bytes
			return stream

	return null


func _on_mode_selected() -> void:
	var is_ear := _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD
	var practice_flow := _home_flow == "Practice"
	var learn_flow := _home_flow == "Learn"
	var teacher_flow := _home_flow == "Teacher Dashboard"

	if _home_q_row != null:
		_home_q_row.visible = practice_flow
	if _home_mode_label != null:
		_home_mode_label.visible = practice_flow
	if _home_mode_buttons_row != null:
		_home_mode_buttons_row.visible = practice_flow
	if _home_teacher_box != null:
		_home_teacher_box.visible = teacher_flow

	_ear_mode_row.visible = practice_flow and is_ear
	_interval_options_box.visible = practice_flow and is_ear and _selected_mode == MODE_INTERVAL
	_chord_options_box.visible = practice_flow and is_ear and _selected_mode == MODE_CHORD
	_sight_options_box.visible = practice_flow and _selected_mode == MODE_SIGHT
	_read_options_box.visible = learn_flow and _selected_mode == MODE_READ

	if _home_start_button != null:
		if practice_flow:
			_home_start_button.text = "Start Training"
			_home_start_button.visible = true
		elif learn_flow:
			_home_start_button.text = "Start Module"
			_home_start_button.visible = true
		else:
			_home_start_button.visible = false

	_refresh_mode_buttons()
	_refresh_ear_mode_buttons()
	_refresh_clef_buttons()
	_refresh_chord_group_buttons()
	_refresh_sight_mode_buttons()
	_refresh_read_module_buttons()
	_refresh_home_hub_buttons()


func _on_mode_button_pressed(mode: int) -> void:
	if mode == MODE_TEACHER:
		_home_flow = "Teacher Dashboard"
		_selected_mode = MODE_TEACHER
		_on_mode_selected()
		return
	if mode == MODE_SIGHT:
		_selected_mode = MODE_SIGHT
	elif mode == MODE_READ:
		_selected_mode = MODE_READ
	else:
		if _selected_mode != MODE_INTERVAL and _selected_mode != MODE_CHORD:
			_selected_mode = MODE_INTERVAL
	if _home_flow == "Teacher Dashboard":
		_home_flow = "Practice"
	_on_mode_selected()


func _on_home_hub_pressed(hub_name: String) -> void:
	_home_flow = hub_name
	if hub_name == "Practice":
		if _selected_mode != MODE_INTERVAL and _selected_mode != MODE_CHORD and _selected_mode != MODE_SIGHT:
			_selected_mode = MODE_INTERVAL
	elif hub_name == "Learn":
		_selected_mode = MODE_READ
	else:
		_selected_mode = MODE_TEACHER
	_on_mode_selected()


func _refresh_home_hub_buttons() -> void:
	for key in _home_hub_buttons.keys():
		var btn: Button = _home_hub_buttons[key]
		_set_home_selection_state(btn, str(key) == _home_flow)


func _on_ear_mode_button_pressed(mode: int) -> void:
	if mode != MODE_INTERVAL and mode != MODE_CHORD:
		return
	_selected_mode = mode
	_on_mode_selected()


func _on_read_module_button_pressed(module_id: int) -> void:
	_selected_read_module = clampi(module_id, 1, 2)
	_refresh_read_module_buttons()


func _on_degree_toggled(enabled: bool, degree: int) -> void:
	if not enabled and _count_selected_degrees() == 0:
		var btn: Button = _degree_toggles.get(degree, null)
		if btn != null:
			btn.button_pressed = true
			return
	_refresh_degree_buttons()


func _on_include_minor_toggled(enabled: bool) -> void:
	_include_minor_intervals = enabled


func _on_clef_button_pressed(clef_name: String) -> void:
	_selected_clef = clef_name
	var bounds := _get_sight_step_bounds()
	_sight_range_min_step = clampi(_sight_range_min_step, bounds.x, bounds.y)
	_sight_range_max_step = clampi(_sight_range_max_step, _sight_range_min_step, bounds.y)
	_refresh_clef_buttons()
	_update_sight_range_ui()


func _on_sight_mode_button_pressed(mode_name: String) -> void:
	_sight_mode = mode_name
	_refresh_sight_mode_buttons()


func _on_sight_range_adjust(delta: int, adjust_upper: bool) -> void:
	var bounds := _get_sight_step_bounds()
	if adjust_upper:
		# Upper note is represented by min step index.
		_sight_range_min_step = clampi(_sight_range_min_step + delta, bounds.x, _sight_range_max_step)
	else:
		# Lower note is represented by max step index.
		_sight_range_max_step = clampi(_sight_range_max_step + delta, _sight_range_min_step, bounds.y)
	_update_sight_range_ui()


func _on_chord_group_button_pressed(group_id: int) -> void:
	_selected_chord_group = clampi(group_id, 1, 4)
	_refresh_chord_group_buttons()


func _on_teacher_open_pressed() -> void:
	_selected_mode = MODE_TEACHER
	_home_flow = "Teacher Dashboard"
	_on_mode_selected()
	_show_game()
	_set_answer_buttons_enabled(false)
	_quiz_active = false
	_accepting_answer = false
	_result_box_hide()
	if _teacher_tabs != null:
		_teacher_tabs.current_tab = 0
	_refresh_teacher_students_list()
	_teacher_update_dashboard_empty()
	_teacher_refresh_selected_student_label()
	_teacher_status_label.text = "Use Go Back to return Home."


func _load_teacher_data() -> void:
	if not FileAccess.file_exists(TEACHER_DATA_PATH):
		_teacher_data = {"students": []}
		return
	var f := FileAccess.open(TEACHER_DATA_PATH, FileAccess.READ)
	if f == null:
		_teacher_data = {"students": []}
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		_teacher_data = parsed
	else:
		_teacher_data = {"students": []}
	if not _teacher_data.has("students") or typeof(_teacher_data["students"]) != TYPE_ARRAY:
		_teacher_data["students"] = []
	var students: Array = _teacher_data["students"]
	for i in students.size():
		var s: Dictionary = students[i]
		students[i] = _teacher_ensure_student_defaults(s)
	_teacher_data["students"] = students


func _save_teacher_data() -> void:
	if not _teacher_data.has("students") or typeof(_teacher_data["students"]) != TYPE_ARRAY:
		_teacher_data["students"] = []
	var txt := JSON.stringify(_teacher_data, "\t")
	var f := FileAccess.open(TEACHER_DATA_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(txt)
	f.close()


func _teacher_students_array() -> Array:
	if not _teacher_data.has("students") or typeof(_teacher_data["students"]) != TYPE_ARRAY:
		_teacher_data["students"] = []
	return _teacher_data["students"]


func _teacher_parse_csv(text: String) -> Array[String]:
	var out: Array[String] = []
	for p in text.split(","):
		var v := p.strip_edges()
		if v != "":
			out.append(v)
	return out


func _teacher_csv(arr: Array) -> String:
	var out: Array[String] = []
	for item in arr:
		out.append(str(item))
	return ", ".join(out)


func _teacher_collect_field_values(fields: Array[LineEdit]) -> Array[String]:
	var out: Array[String] = []
	for field in fields:
		if field == null:
			continue
		var value := field.text.strip_edges()
		if value != "":
			out.append(value)
	return out


func _teacher_make_item_field(placeholder: String, value: String = "") -> LineEdit:
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder
	edit.text = value
	return edit


func _teacher_piece_entries_from_value_array(values: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for v in values:
		if typeof(v) == TYPE_DICTIONARY:
			var d: Dictionary = v
			var title := str(d.get("title", "")).strip_edges()
			if title == "":
				title = str(d.get("name", "")).strip_edges()
			if title == "":
				continue
			entries.append({
				"title": title,
				"notes": str(d.get("notes", ""))
			})
		else:
			var s := str(v).strip_edges()
			if s != "":
				entries.append({
					"title": s,
					"notes": ""
				})
	return entries


func _teacher_collect_piece_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for field in _teacher_piece_fields:
		if field == null:
			continue
		var title := field.text.strip_edges()
		if title == "":
			continue
		var note := str(_teacher_piece_notes.get(str(field.get_instance_id()), ""))
		entries.append({"title": title, "notes": note})
	return entries


func _teacher_piece_titles(values: Array) -> Array[String]:
	var out: Array[String] = []
	var entries := _teacher_piece_entries_from_value_array(values)
	for e in entries:
		out.append(str(e.get("title", "")))
	return out


func _teacher_refresh_piece_row_numbers() -> void:
	if _teacher_piece_fields_box == null:
		return
	var idx := 1
	for row_node in _teacher_piece_fields_box.get_children():
		if row_node is HBoxContainer:
			var row := row_node as HBoxContainer
			if row.get_child_count() > 0 and row.get_child(0) is Label:
				var number_label := row.get_child(0) as Label
				number_label.text = "%d." % idx
			idx += 1


func _teacher_add_piece_row(value: String = "", notes: String = "") -> void:
	if _teacher_piece_fields_box == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_teacher_piece_fields_box.add_child(row)
	var number_label := Label.new()
	number_label.text = "1."
	number_label.custom_minimum_size = Vector2(26, 0)
	row.add_child(number_label)
	var field := _teacher_make_item_field("Piece title", value)
	row.add_child(field)
	var notes_btn := Button.new()
	notes_btn.text = "Lesson Notes"
	notes_btn.custom_minimum_size = Vector2(120, 30)
	notes_btn.pressed.connect(_on_teacher_piece_notes_pressed.bind(field))
	row.add_child(notes_btn)
	var remove_btn := Button.new()
	remove_btn.text = "-"
	remove_btn.custom_minimum_size = Vector2(38, 30)
	remove_btn.pressed.connect(_on_teacher_request_remove_piece_row_pressed.bind(field))
	row.add_child(remove_btn)
	_teacher_piece_fields.append(field)
	_teacher_piece_notes[str(field.get_instance_id())] = notes
	_teacher_refresh_piece_row_numbers()


func _teacher_rebuild_piece_fields(values: Array) -> void:
	_teacher_piece_fields.clear()
	_teacher_piece_notes.clear()
	if _teacher_piece_fields_box == null:
		return
	for child in _teacher_piece_fields_box.get_children():
		child.queue_free()
	var entries := _teacher_piece_entries_from_value_array(values)
	if entries.is_empty():
		_teacher_add_piece_row("", "")
		return
	for item in entries:
		_teacher_add_piece_row(str(item.get("title", "")), str(item.get("notes", "")))


func _teacher_now_string() -> String:
	return Time.get_datetime_string_from_system()


func _teacher_date_string() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0))]


func _teacher_mode_label(mode: int) -> String:
	match mode:
		MODE_INTERVAL:
			return "Ear - Intervals"
		MODE_CHORD:
			return "Ear - Chords"
		MODE_SIGHT:
			return "Sight Reading"
		MODE_READ:
			return "Read Notation"
		_:
			return "Unknown"


func _teacher_csv_escape(value: String) -> String:
	var v := value.replace("\"", "\"\"")
	return "\"%s\"" % v


func _teacher_get_selected_assignment_index() -> int:
	if _teacher_assignments_list == null:
		return -1
	var selected: PackedInt32Array = _teacher_assignments_list.get_selected_items()
	if selected.is_empty():
		return -1
	return int(selected[0])


func _teacher_refresh_assignments_list(student: Dictionary) -> void:
	if _teacher_assignments_list == null:
		return
	_teacher_assignments_list.clear()
	var assignments: Array = student.get("assignments", [])
	for item in assignments:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = item
		var task := str(a.get("task", "")).strip_edges()
		var due := str(a.get("due", "")).strip_edges()
		var done := bool(a.get("done", false))
		var prefix := "[Done] " if done else "[Open] "
		var due_text := " (Due %s)" % due if due != "" else ""
		_teacher_assignments_list.add_item("%s%s%s" % [prefix, task, due_text])


func _teacher_refresh_selected_student_label() -> void:
	if _teacher_selected_student_label == null:
		return
	if _teacher_selected_student_id == "":
		_teacher_selected_student_label.text = "Selected Student: none"
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_selected_student_label.text = "Selected Student: none"
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	_teacher_selected_student_label.text = "Selected Student: %s" % [
		str(s.get("name", "Unnamed")),
	]


func _teacher_new_student_template() -> Dictionary:
	return {
		"id": "s_%d_%d" % [Time.get_unix_time_from_system(), _rng.randi_range(1000, 9999)],
		"name": "",
		"age": 10,
		"level": "",
		"current_book": {"name": "", "part": ""},
		"current_pieces": [],
		"current_technical": [],
		"book_history": [],
		"piece_history": [],
		"tech_history": [],
		"session_history": [],
		"assignments": [],
		"metrics": {
			"ear_accuracy": 0,
			"sight_accuracy": 0,
			"modules_completed": 0
		},
		"training_stats": {
			"ear_accuracy": 0,
			"sight_accuracy": 0,
			"modules_completed": 0,
			"ear_sessions": 0,
			"sight_sessions": 0,
			"last_session": ""
		}
	}


func _teacher_find_index_by_id(student_id: String) -> int:
	var students: Array = _teacher_students_array()
	for i in students.size():
		var s: Dictionary = students[i]
		if str(s.get("id", "")) == student_id:
			return i
	return -1


func _teacher_collect_form_into(student: Dictionary) -> Dictionary:
	student["name"] = _teacher_name_edit.text.strip_edges()
	student["age"] = int(_teacher_age_spin.value)
	if _teacher_level_edit != null:
		student["level"] = _teacher_level_edit.text.strip_edges()
	var cb: Dictionary = student.get("current_book", {})
	cb["name"] = _teacher_book_name_edit.text.strip_edges()
	cb["part"] = _teacher_book_part_edit.text.strip_edges()
	student["current_book"] = cb
	student["current_pieces"] = _teacher_collect_piece_entries()
	student["current_technical"] = []
	return _teacher_ensure_student_defaults(student)


func _teacher_ensure_student_defaults(student: Dictionary) -> Dictionary:
	if not student.has("book_history"):
		student["book_history"] = []
	if not student.has("piece_history"):
		student["piece_history"] = []
	if not student.has("tech_history"):
		student["tech_history"] = []
	if not student.has("session_history"):
		student["session_history"] = []
	if not student.has("assignments"):
		student["assignments"] = []
	if not student.has("current_book") or typeof(student["current_book"]) != TYPE_DICTIONARY:
		student["current_book"] = {"name": "", "part": ""}
	if not student.has("current_pieces") or typeof(student["current_pieces"]) != TYPE_ARRAY:
		student["current_pieces"] = []
	if not student.has("current_technical") or typeof(student["current_technical"]) != TYPE_ARRAY:
		student["current_technical"] = []
	if typeof(student["book_history"]) != TYPE_ARRAY:
		student["book_history"] = []
	if typeof(student["piece_history"]) != TYPE_ARRAY:
		student["piece_history"] = []
	if typeof(student["tech_history"]) != TYPE_ARRAY:
		student["tech_history"] = []
	if typeof(student["session_history"]) != TYPE_ARRAY:
		student["session_history"] = []
	if typeof(student["assignments"]) != TYPE_ARRAY:
		student["assignments"] = []
	if not student.has("metrics"):
		student["metrics"] = {"ear_accuracy": 0, "sight_accuracy": 0, "modules_completed": 0}
	if not student.has("training_stats") or typeof(student["training_stats"]) != TYPE_DICTIONARY:
		student["training_stats"] = {}
	var metrics: Dictionary = student["metrics"]
	if not metrics.has("ear_accuracy"):
		metrics["ear_accuracy"] = 0
	if not metrics.has("sight_accuracy"):
		metrics["sight_accuracy"] = 0
	if not metrics.has("modules_completed"):
		metrics["modules_completed"] = 0
	if not metrics.has("ear_sessions"):
		metrics["ear_sessions"] = 0
	if not metrics.has("sight_sessions"):
		metrics["sight_sessions"] = 0
	student["metrics"] = metrics
	var stats: Dictionary = student["training_stats"]
	if not stats.has("ear_accuracy"):
		stats["ear_accuracy"] = int(metrics.get("ear_accuracy", 0))
	if not stats.has("sight_accuracy"):
		stats["sight_accuracy"] = int(metrics.get("sight_accuracy", 0))
	if not stats.has("modules_completed"):
		stats["modules_completed"] = int(metrics.get("modules_completed", 0))
	if not stats.has("ear_sessions"):
		stats["ear_sessions"] = int(metrics.get("ear_sessions", 0))
	if not stats.has("sight_sessions"):
		stats["sight_sessions"] = int(metrics.get("sight_sessions", 0))
	if not stats.has("last_session"):
		stats["last_session"] = str(metrics.get("last_session", ""))
	student["training_stats"] = stats
	return student


func _teacher_clear_form() -> void:
	_teacher_selected_student_id = ""
	_teacher_name_edit.text = ""
	_teacher_age_spin.value = 10
	if _teacher_level_edit != null:
		_teacher_level_edit.text = ""
	_teacher_book_name_edit.text = ""
	_teacher_book_part_edit.text = ""
	_teacher_rebuild_piece_fields([])
	if _teacher_done_piece_edit != null:
		_teacher_done_piece_edit.text = ""
	if _teacher_done_tech_edit != null:
		_teacher_done_tech_edit.text = ""
	if _teacher_assignment_task_edit != null:
		_teacher_assignment_task_edit.text = ""
	if _teacher_assignment_due_edit != null:
		_teacher_assignment_due_edit.text = ""
	if _teacher_assignments_list != null:
		_teacher_assignments_list.clear()


func _teacher_fill_form(student: Dictionary) -> void:
	_teacher_name_edit.text = str(student.get("name", ""))
	_teacher_age_spin.value = int(student.get("age", 10))
	if _teacher_level_edit != null:
		_teacher_level_edit.text = str(student.get("level", ""))
	var cb: Dictionary = student.get("current_book", {})
	_teacher_book_name_edit.text = str(cb.get("name", ""))
	_teacher_book_part_edit.text = str(cb.get("part", ""))
	_teacher_rebuild_piece_fields(student.get("current_pieces", []))
	if _teacher_assignment_task_edit != null:
		_teacher_assignment_task_edit.text = ""
	if _teacher_assignment_due_edit != null:
		_teacher_assignment_due_edit.text = ""
	_teacher_refresh_assignments_list(student)


func _teacher_update_dashboard_empty() -> void:
	if _teacher_dashboard_text != null:
		_teacher_dashboard_text.text = "[center]Select a student to view dashboard.[/center]"
	if _teacher_progress_ear_label != null:
		_teacher_progress_ear_label.text = "Ear: 0%"
	if _teacher_progress_sight_label != null:
		_teacher_progress_sight_label.text = "Sight: 0%"
	if _teacher_progress_modules_label != null:
		_teacher_progress_modules_label.text = "Modules: 0"


func _teacher_update_dashboard(student: Dictionary) -> void:
	if _teacher_dashboard_text == null:
		return
	var cb: Dictionary = student.get("current_book", {})
	var metrics: Dictionary = student.get("metrics", {})
	var stats: Dictionary = student.get("training_stats", {})
	if _teacher_progress_ear_label != null:
		_teacher_progress_ear_label.text = "Ear: %s%%" % str(stats.get("ear_accuracy", metrics.get("ear_accuracy", 0)))
	if _teacher_progress_sight_label != null:
		_teacher_progress_sight_label.text = "Sight: %s%%" % str(stats.get("sight_accuracy", metrics.get("sight_accuracy", 0)))
	if _teacher_progress_modules_label != null:
		_teacher_progress_modules_label.text = "Modules: %s" % str(stats.get("modules_completed", metrics.get("modules_completed", 0)))
	var txt := ""
	txt += "[b]Name:[/b] %s\n" % str(student.get("name", ""))
	txt += "[b]Age:[/b] %d\n" % int(student.get("age", 0))
	txt += "\n"
	txt += "[b]Active Method Book:[/b] %s (Part %s)\n" % [str(cb.get("name", "")), str(cb.get("part", ""))]
	txt += "[b]Active Repertoire Pieces:[/b] %s\n\n" % _teacher_csv(_teacher_piece_titles(student.get("current_pieces", [])))
	txt += "[b]Completed Books:[/b] %s\n" % _teacher_csv(student.get("book_history", []))
	txt += "[b]Completed Pieces:[/b] %s\n" % _teacher_csv(student.get("piece_history", []))
	txt += "\n"
	var assignments: Array = student.get("assignments", [])
	var open_assignments: Array[String] = []
	for item in assignments:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = item
		if bool(a.get("done", false)):
			continue
		var task := str(a.get("task", "")).strip_edges()
		if task == "":
			continue
		var due := str(a.get("due", "")).strip_edges()
		open_assignments.append("%s%s" % [task, (" (Due %s)" % due) if due != "" else ""])
	txt += "[b]Open Assignments:[/b] %s\n\n" % _teacher_csv(open_assignments)
	txt += "[b]Ear Accuracy:[/b] %s%%\n" % str(metrics.get("ear_accuracy", 0))
	txt += "[b]Sight Accuracy:[/b] %s%%\n" % str(metrics.get("sight_accuracy", 0))
	txt += "[b]Modules Completed:[/b] %s\n" % str(metrics.get("modules_completed", 0))
	var sessions: Array = student.get("session_history", [])
	txt += "[b]Recent Sessions:[/b]\n"
	var shown := 0
	for i in range(sessions.size() - 1, -1, -1):
		if shown >= 6:
			break
		if typeof(sessions[i]) != TYPE_DICTIONARY:
			continue
		var sess: Dictionary = sessions[i]
		txt += "- %s | %s | %s/%s (%s%%)\n" % [
			str(sess.get("date", "")),
			str(sess.get("mode", "")),
			str(sess.get("correct", 0)),
			str(sess.get("asked", 0)),
			str(sess.get("accuracy", 0))
		]
		shown += 1
	if shown == 0:
		txt += "- No sessions yet.\n"
	_teacher_dashboard_text.text = txt


func _teacher_update_training_stats_from_metrics(student: Dictionary) -> Dictionary:
	var metrics: Dictionary = student.get("metrics", {})
	var stats: Dictionary = student.get("training_stats", {})
	stats["ear_accuracy"] = int(metrics.get("ear_accuracy", 0))
	stats["sight_accuracy"] = int(metrics.get("sight_accuracy", 0))
	stats["modules_completed"] = int(metrics.get("modules_completed", 0))
	stats["ear_sessions"] = int(metrics.get("ear_sessions", 0))
	stats["sight_sessions"] = int(metrics.get("sight_sessions", 0))
	stats["last_session"] = str(metrics.get("last_session", ""))
	student["training_stats"] = stats
	return student


func _on_teacher_add_piece_row_pressed() -> void:
	_teacher_add_piece_row("", "")


func _on_teacher_piece_notes_pressed(field: LineEdit) -> void:
	if field == null:
		return
	_teacher_piece_note_target_field = field
	var key := str(field.get_instance_id())
	_teacher_piece_note_edit.text = str(_teacher_piece_notes.get(key, ""))
	_teacher_piece_note_dialog.popup_centered()


func _on_teacher_piece_notes_save_confirmed() -> void:
	if _teacher_piece_note_target_field == null:
		return
	var key := str(_teacher_piece_note_target_field.get_instance_id())
	_teacher_piece_notes[key] = _teacher_piece_note_edit.text
	_teacher_status_label.text = "Piece notes saved."


func _on_teacher_request_remove_piece_row_pressed(field: LineEdit) -> void:
	if field == null:
		return
	_teacher_pending_delete_piece_field = field
	_teacher_piece_delete_confirm.popup_centered()


func _on_teacher_piece_delete_confirmed() -> void:
	var field := _teacher_pending_delete_piece_field
	_teacher_pending_delete_piece_field = null
	if field == null:
		return
	var removed := field.text.strip_edges()
	var row := field.get_parent()
	if row != null:
		row.queue_free()
	var idx_field := _teacher_piece_fields.find(field)
	if idx_field >= 0:
		_teacher_piece_fields.remove_at(idx_field)
	_teacher_piece_notes.erase(str(field.get_instance_id()))
	if _teacher_piece_fields.is_empty():
		_teacher_add_piece_row("", "")
	_teacher_refresh_piece_row_numbers()
	if removed == "":
		_teacher_status_label.text = "Repertoire entry deleted."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_status_label.text = "Repertoire entry deleted."
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var hist: Array = s.get("piece_history", [])
	hist.append(removed)
	s["piece_history"] = hist
	s["current_pieces"] = _teacher_collect_piece_entries()
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Moved piece to completed history."


func _on_teacher_add_tech_row_pressed() -> void:
	return


func _on_teacher_remove_tech_row_pressed(_field: LineEdit) -> void:
	return


func _refresh_teacher_students_list() -> void:
	if _teacher_students_list == null:
		return
	_teacher_students_list.clear()
	_teacher_list_student_ids.clear()
	var students: Array = _teacher_students_array()
	for s in students:
		var sd: Dictionary = s
		if not _teacher_student_matches_filter(sd):
			continue
		var label := str(sd.get("name", "Unnamed"))
		_teacher_students_list.add_item(label)
		_teacher_list_student_ids.append(str(sd.get("id", "")))
	_teacher_update_analytics()


func _on_teacher_new_student_pressed() -> void:
	_teacher_clear_form()
	_teacher_update_dashboard_empty()
	_teacher_refresh_selected_student_label()
	_teacher_status_label.text = "New student form ready."


func _on_teacher_delete_student_pressed() -> void:
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_status_label.text = "Student not found."
		return
	var students: Array = _teacher_students_array()
	students.remove_at(idx)
	_teacher_data["students"] = students
	if str(_teacher_data.get("active_student_id", "")) == _teacher_selected_student_id:
		_teacher_data["active_student_id"] = ""
	_save_teacher_data()
	_teacher_clear_form()
	_refresh_teacher_students_list()
	_teacher_update_dashboard_empty()
	_teacher_refresh_selected_student_label()
	_teacher_status_label.text = "Student deleted."


func _on_teacher_save_student_pressed() -> void:
	var nm := _teacher_name_edit.text.strip_edges()
	if nm == "":
		_teacher_status_label.text = "Name is required."
		return
	var students: Array = _teacher_students_array()
	if _teacher_selected_student_id == "":
		var s := _teacher_new_student_template()
		s = _teacher_collect_form_into(s)
		students.append(s)
		_teacher_selected_student_id = str(s.get("id", ""))
		_teacher_status_label.text = "Student created."
	else:
		var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
		if idx >= 0:
			var existing: Dictionary = students[idx]
			existing = _teacher_collect_form_into(existing)
			students[idx] = existing
			_teacher_status_label.text = "Student updated."
		else:
			var fallback := _teacher_new_student_template()
			fallback = _teacher_collect_form_into(fallback)
			students.append(fallback)
			_teacher_selected_student_id = str(fallback.get("id", ""))
			_teacher_status_label.text = "Student created."
	_teacher_data["students"] = students
	_save_teacher_data()
	_refresh_teacher_students_list()
	_teacher_refresh_selected_student_label()
	var sel_idx := -1
	for i in _teacher_list_student_ids.size():
		if _teacher_list_student_ids[i] == _teacher_selected_student_id:
			sel_idx = i
			break
	if sel_idx >= 0:
		_teacher_students_list.select(sel_idx)
		_on_teacher_student_selected(sel_idx)


func _on_teacher_student_selected(index: int) -> void:
	if index < 0 or index >= _teacher_list_student_ids.size():
		return
	var student_id := _teacher_list_student_ids[index]
	var real_idx := _teacher_find_index_by_id(student_id)
	if real_idx < 0:
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[real_idx]
	_teacher_selected_student_id = str(s.get("id", ""))
	_teacher_data["active_student_id"] = _teacher_selected_student_id
	_save_teacher_data()
	_teacher_fill_form(s)
	_teacher_update_dashboard(s)
	_teacher_refresh_selected_student_label()
	_teacher_status_label.text = "Loaded student."


func _on_teacher_filter_changed(_idx: int) -> void:
	_refresh_teacher_students_list()


func _teacher_get_filter_id() -> int:
	if _teacher_filter_option == null:
		return 0
	return _teacher_filter_option.get_selected_id()


func _teacher_student_matches_filter(student: Dictionary) -> bool:
	var filter_id := _teacher_get_filter_id()
	var metrics: Dictionary = student.get("metrics", {})
	var ear := int(metrics.get("ear_accuracy", 0))
	var sight := int(metrics.get("sight_accuracy", 0))
	var modules := int(metrics.get("modules_completed", 0))
	match filter_id:
		1:
			return ear < 70
		2:
			return sight < 70
		3:
			return modules < 3
		_:
			return true


func _teacher_update_analytics() -> void:
	if _teacher_analytics_label == null:
		return
	var students: Array = _teacher_students_array()
	if students.is_empty():
		_teacher_analytics_label.text = "No students yet."
		return
	var ear_sum := 0
	var sight_sum := 0
	var modules_sum := 0
	var low_ear := 0
	var low_sight := 0
	for s in students:
		var sd: Dictionary = s
		var m: Dictionary = sd.get("metrics", {})
		var ear := int(m.get("ear_accuracy", 0))
		var sight := int(m.get("sight_accuracy", 0))
		var mods := int(m.get("modules_completed", 0))
		ear_sum += ear
		sight_sum += sight
		modules_sum += mods
		if ear < 70:
			low_ear += 1
		if sight < 70:
			low_sight += 1
	var n: int = max(1, students.size())
	_teacher_analytics_label.text = "Students: %d | Avg Ear: %d%% | Avg Sight: %d%% | Avg Modules: %.1f | Ear<70: %d | Sight<70: %d" % [
		students.size(),
		int(round(float(ear_sum) / float(n))),
		int(round(float(sight_sum) / float(n))),
		float(modules_sum) / float(n),
		low_ear,
		low_sight
	]


func _teacher_get_active_student_id() -> String:
	if _teacher_selected_student_id != "":
		return _teacher_selected_student_id
	return str(_teacher_data.get("active_student_id", ""))


func _teacher_apply_metric_update(student: Dictionary, mode: int, accuracy_pct: int) -> Dictionary:
	var metrics: Dictionary = student.get("metrics", {})
	var ear_sessions := int(metrics.get("ear_sessions", 0))
	var sight_sessions := int(metrics.get("sight_sessions", 0))
	var ear_accuracy := int(metrics.get("ear_accuracy", 0))
	var sight_accuracy := int(metrics.get("sight_accuracy", 0))
	if mode == MODE_INTERVAL or mode == MODE_CHORD:
		ear_accuracy = int(round((float(ear_accuracy * ear_sessions) + float(accuracy_pct)) / float(ear_sessions + 1)))
		ear_sessions += 1
	elif mode == MODE_SIGHT:
		sight_accuracy = int(round((float(sight_accuracy * sight_sessions) + float(accuracy_pct)) / float(sight_sessions + 1)))
		sight_sessions += 1
	metrics["ear_sessions"] = ear_sessions
	metrics["sight_sessions"] = sight_sessions
	metrics["ear_accuracy"] = ear_accuracy
	metrics["sight_accuracy"] = sight_accuracy
	metrics["last_session"] = Time.get_datetime_string_from_system()
	student["metrics"] = metrics
	student = _teacher_update_training_stats_from_metrics(student)
	return student


func _teacher_record_session_metrics(mode: int, correct_count: int, asked_count: int) -> void:
	var sid := _teacher_get_active_student_id()
	if sid == "":
		return
	var idx := _teacher_find_index_by_id(sid)
	if idx < 0:
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var acc := int(round((float(correct_count) / float(max(1, asked_count))) * 100.0))
	s = _teacher_apply_metric_update(s, mode, acc)
	var sessions: Array = s.get("session_history", [])
	sessions.append({
		"date": _teacher_now_string(),
		"mode": _teacher_mode_label(mode),
		"correct": correct_count,
		"asked": asked_count,
		"accuracy": acc
	})
	while sessions.size() > 200:
		sessions.remove_at(0)
	s["session_history"] = sessions
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	if _teacher_selected_student_id == sid:
		_teacher_update_dashboard(s)
	_refresh_teacher_students_list()


func _teacher_mark_module_completed() -> void:
	var sid := _teacher_get_active_student_id()
	if sid == "":
		return
	var idx := _teacher_find_index_by_id(sid)
	if idx < 0:
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var metrics: Dictionary = s.get("metrics", {})
	metrics["modules_completed"] = int(metrics.get("modules_completed", 0)) + 1
	metrics["last_session"] = Time.get_datetime_string_from_system()
	s["metrics"] = metrics
	s = _teacher_update_training_stats_from_metrics(s)
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	if _teacher_selected_student_id == sid:
		_teacher_update_dashboard(s)
	_refresh_teacher_students_list()


func _on_teacher_mark_book_done_pressed() -> void:
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var cb: Dictionary = s.get("current_book", {})
	var book_name := str(cb.get("name", "")).strip_edges()
	var book_part := str(cb.get("part", "")).strip_edges()
	if book_name == "":
		_teacher_status_label.text = "No current book to mark done."
		return
	var hist: Array = s.get("book_history", [])
	hist.append("%s%s" % [book_name, (" (Part %s)" % book_part) if book_part != "" else ""])
	s["book_history"] = hist
	s["current_book"] = {"name": "", "part": ""}
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_fill_form(s)
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Book marked done."
	_refresh_teacher_students_list()


func _on_teacher_mark_piece_done_pressed() -> void:
	if _teacher_done_piece_edit == null:
		return
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var current: Array[Dictionary] = _teacher_piece_entries_from_value_array(s.get("current_pieces", []))
	var target := _teacher_done_piece_edit.text.strip_edges()
	if target == "" and not current.is_empty():
		target = str(current[0].get("title", ""))
	if target == "":
		_teacher_status_label.text = "No piece to mark done."
		return
	var updated: Array[Dictionary] = []
	for p in current:
		var ps := str(p.get("title", ""))
		if ps != target:
			updated.append(p)
	var hist: Array = s.get("piece_history", [])
	hist.append(target)
	s["piece_history"] = hist
	s["current_pieces"] = updated
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_done_piece_edit.text = ""
	_teacher_fill_form(s)
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Piece marked done."
	_refresh_teacher_students_list()


func _on_teacher_mark_tech_done_pressed() -> void:
	if _teacher_done_tech_edit == null:
		return
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var current: Array = s.get("current_technical", [])
	var target := _teacher_done_tech_edit.text.strip_edges()
	if target == "" and not current.is_empty():
		target = str(current[0])
	if target == "":
		_teacher_status_label.text = "No technical drill to mark done."
		return
	var updated: Array[String] = []
	for t in current:
		var ts := str(t)
		if ts != target:
			updated.append(ts)
	var hist: Array = s.get("tech_history", [])
	hist.append(target)
	s["tech_history"] = hist
	s["current_technical"] = updated
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_done_tech_edit.text = ""
	_teacher_fill_form(s)
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Technical drill marked done."
	_refresh_teacher_students_list()


func _on_teacher_add_assignment_pressed() -> void:
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var task := _teacher_assignment_task_edit.text.strip_edges()
	if task == "":
		_teacher_status_label.text = "Assignment task is required."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_status_label.text = "Student not found."
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var assignments: Array = s.get("assignments", [])
	assignments.append({
		"task": task,
		"due": _teacher_assignment_due_edit.text.strip_edges(),
		"done": false,
		"created_at": _teacher_now_string(),
		"done_at": ""
	})
	s["assignments"] = assignments
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_assignment_task_edit.text = ""
	_teacher_assignment_due_edit.text = ""
	_teacher_refresh_assignments_list(s)
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Assignment added."


func _on_teacher_mark_assignment_done_pressed() -> void:
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_status_label.text = "Student not found."
		return
	var assignment_idx := _teacher_get_selected_assignment_index()
	if assignment_idx < 0:
		_teacher_status_label.text = "Select an assignment in the list."
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var assignments: Array = s.get("assignments", [])
	if assignment_idx >= assignments.size():
		_teacher_status_label.text = "Assignment selection out of range."
		return
	var a: Dictionary = assignments[assignment_idx]
	a["done"] = true
	a["done_at"] = _teacher_now_string()
	assignments[assignment_idx] = a
	s["assignments"] = assignments
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_refresh_assignments_list(s)
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Assignment marked done."


func _on_teacher_remove_assignment_pressed() -> void:
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_status_label.text = "Student not found."
		return
	var assignment_idx := _teacher_get_selected_assignment_index()
	if assignment_idx < 0:
		_teacher_status_label.text = "Select an assignment in the list."
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var assignments: Array = s.get("assignments", [])
	if assignment_idx >= assignments.size():
		_teacher_status_label.text = "Assignment selection out of range."
		return
	assignments.remove_at(assignment_idx)
	s["assignments"] = assignments
	students[idx] = s
	_teacher_data["students"] = students
	_save_teacher_data()
	_teacher_refresh_assignments_list(s)
	_teacher_update_dashboard(s)
	_teacher_status_label.text = "Assignment removed."


func _teacher_ensure_export_dir() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if not dir.dir_exists("exports"):
		var err := dir.make_dir("exports")
		if err != OK and err != ERR_ALREADY_EXISTS:
			return false
	return true


func _teacher_export_file_stamp() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	var t: Dictionary = Time.get_time_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(d.get("year", 0)),
		int(d.get("month", 0)),
		int(d.get("day", 0)),
		int(t.get("hour", 0)),
		int(t.get("minute", 0)),
		int(t.get("second", 0))
	]


func _on_teacher_export_csv_pressed() -> void:
	if not _teacher_ensure_export_dir():
		_teacher_status_label.text = "Could not create export folder."
		return
	var students: Array = _teacher_students_array()
	var lines: Array[String] = []
	lines.append("student_id,name,age,current_book,current_part,current_pieces,ear_accuracy,sight_accuracy,modules_completed,last_session")
	for item in students:
		var s: Dictionary = item
		var cb: Dictionary = s.get("current_book", {})
		var m: Dictionary = s.get("metrics", {})
		lines.append(",".join([
			_teacher_csv_escape(str(s.get("id", ""))),
			_teacher_csv_escape(str(s.get("name", ""))),
			str(int(s.get("age", 0))),
			_teacher_csv_escape(str(cb.get("name", ""))),
			_teacher_csv_escape(str(cb.get("part", ""))),
			_teacher_csv_escape(_teacher_csv(_teacher_piece_titles(s.get("current_pieces", [])))),
			str(int(m.get("ear_accuracy", 0))),
			str(int(m.get("sight_accuracy", 0))),
			str(int(m.get("modules_completed", 0))),
			_teacher_csv_escape(str(m.get("last_session", "")))
		]))
	var path := "%s/teacher_students_%s.csv" % [TEACHER_EXPORT_DIR, _teacher_export_file_stamp()]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_teacher_status_label.text = "Failed to write CSV export."
		return
	f.store_string("\n".join(lines))
	f.close()
	_teacher_status_label.text = "CSV exported to: %s" % path


func _on_teacher_export_report_pressed() -> void:
	if _teacher_selected_student_id == "":
		_teacher_status_label.text = "Select a student first."
		return
	if not _teacher_ensure_export_dir():
		_teacher_status_label.text = "Could not create export folder."
		return
	var idx := _teacher_find_index_by_id(_teacher_selected_student_id)
	if idx < 0:
		_teacher_status_label.text = "Student not found."
		return
	var students: Array = _teacher_students_array()
	var s: Dictionary = students[idx]
	var cb: Dictionary = s.get("current_book", {})
	var m: Dictionary = s.get("metrics", {})
	var report_lines: Array[String] = []
	report_lines.append("Adagio Labs - Parent Report")
	report_lines.append("Generated: %s" % _teacher_now_string())
	report_lines.append("")
	report_lines.append("Student: %s" % str(s.get("name", "")))
	report_lines.append("Age: %d" % int(s.get("age", 0)))
	report_lines.append("")
	report_lines.append("Current Focus")
	report_lines.append("- Book: %s (Part %s)" % [str(cb.get("name", "")), str(cb.get("part", ""))])
	report_lines.append("- Repertoire: %s" % _teacher_csv(_teacher_piece_titles(s.get("current_pieces", []))))
	report_lines.append("")
	report_lines.append("Training Performance")
	report_lines.append("- Ear accuracy: %s%%" % str(m.get("ear_accuracy", 0)))
	report_lines.append("- Sight accuracy: %s%%" % str(m.get("sight_accuracy", 0)))
	report_lines.append("- Read modules completed: %s" % str(m.get("modules_completed", 0)))
	report_lines.append("")
	report_lines.append("Open Assignments")
	var assignments: Array = s.get("assignments", [])
	var open_count := 0
	for item in assignments:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = item
		if bool(a.get("done", false)):
			continue
		var due := str(a.get("due", "")).strip_edges()
		report_lines.append("- %s%s" % [str(a.get("task", "")), (" (Due %s)" % due) if due != "" else ""])
		open_count += 1
	if open_count == 0:
		report_lines.append("- None")
	report_lines.append("")
	report_lines.append("Recent Sessions")
	var sessions: Array = s.get("session_history", [])
	var shown := 0
	for i in range(sessions.size() - 1, -1, -1):
		if shown >= 10:
			break
		if typeof(sessions[i]) != TYPE_DICTIONARY:
			continue
		var sess: Dictionary = sessions[i]
		report_lines.append("- %s | %s | %s/%s (%s%%)" % [
			str(sess.get("date", "")),
			str(sess.get("mode", "")),
			str(sess.get("correct", 0)),
			str(sess.get("asked", 0)),
			str(sess.get("accuracy", 0))
		])
		shown += 1
	if shown == 0:
		report_lines.append("- No sessions yet")
	var safe_name := str(s.get("name", "student")).strip_edges().replace(" ", "_")
	if safe_name == "":
		safe_name = "student"
	var path := "%s/parent_report_%s_%s.txt" % [TEACHER_EXPORT_DIR, safe_name, _teacher_export_file_stamp()]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_teacher_status_label.text = "Failed to write parent report."
		return
	f.store_string("\n".join(report_lines))
	f.close()
	_teacher_status_label.text = "Parent report exported to: %s" % path


func _refresh_mode_buttons() -> void:
	var is_ear := _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD
	if _mode_buttons.has("Ear"):
		_set_home_selection_state(_mode_buttons["Ear"], is_ear)
	if _mode_buttons.has("Sight"):
		_set_home_selection_state(_mode_buttons["Sight"], _selected_mode == MODE_SIGHT)
	if _mode_buttons.has("Read"):
		_set_home_selection_state(_mode_buttons["Read"], _selected_mode == MODE_READ)
		_mode_buttons["Read"].visible = false


func _refresh_ear_mode_buttons() -> void:
	for key in _ear_mode_buttons.keys():
		var btn: Button = _ear_mode_buttons[key]
		_set_home_selection_state(btn, int(key) == _selected_mode)


func _refresh_read_module_buttons() -> void:
	for key in _read_module_buttons.keys():
		var btn: Button = _read_module_buttons[key]
		_set_home_selection_state(btn, int(key) == _selected_read_module)


func _refresh_clef_buttons() -> void:
	for clef_name in _clef_buttons.keys():
		var btn: Button = _clef_buttons[clef_name]
		_set_home_selection_state(btn, clef_name == _selected_clef)


func _refresh_sight_mode_buttons() -> void:
	for key in _sight_mode_buttons.keys():
		var btn: Button = _sight_mode_buttons[key]
		_set_home_selection_state(btn, str(key) == _sight_mode)
	if _sight_range_container != null:
		_sight_range_container.visible = _sight_mode == "Notes"


func _get_sight_step_bounds() -> Vector2i:
	return Vector2i(-4, 12)


func _effective_sight_step_bounds() -> Vector2i:
	var bounds := _get_sight_step_bounds()
	if _in_tutorial:
		return bounds
	if _sight_mode != "Notes":
		return bounds
	return Vector2i(_sight_range_min_step, _sight_range_max_step)


func _sight_step_label(step: int) -> String:
	if _selected_clef == "Bass":
		# step -4 .. 12
		var bass_labels := ["E4", "D4", "C4", "B3", "A3", "G3", "F3", "E3", "D3", "C3", "B2", "A2", "G2", "F2", "E2", "D2", "C2"]
		var idx := clampi(step + 4, 0, bass_labels.size() - 1)
		return bass_labels[idx]
	# step -4 .. 12
	var treble_labels := ["C6", "B5", "A5", "G5", "F5", "E5", "D5", "C5", "B4", "A4", "G4", "F4", "E4", "D4", "C4", "B3", "A3"]
	var t_idx := clampi(step + 4, 0, treble_labels.size() - 1)
	return treble_labels[t_idx]


func _update_sight_range_ui() -> void:
	if _sight_range_info_label == null:
		return
	var low_label := _sight_step_label(_sight_range_max_step)
	var high_label := _sight_step_label(_sight_range_min_step)
	_sight_range_info_label.text = ""
	if _sight_range_lower_value_label != null:
		_sight_range_lower_value_label.text = low_label
	if _sight_range_upper_value_label != null:
		_sight_range_upper_value_label.text = high_label


func _refresh_degree_buttons() -> void:
	for degree_key in _degree_toggles.keys():
		var btn: Button = _degree_toggles[degree_key]
		_set_home_selection_state(btn, btn.button_pressed)


func _refresh_chord_group_buttons() -> void:
	for group_key in _chord_group_buttons.keys():
		var btn: Button = _chord_group_buttons[group_key]
		_set_home_selection_state(btn, int(group_key) == _selected_chord_group)


func _count_selected_degrees() -> int:
	var count := 0
	for degree_key in _degree_toggles.keys():
		var btn: Button = _degree_toggles[degree_key]
		if btn.button_pressed:
			count += 1
	return count


func _get_selected_degrees() -> Array[int]:
	var selected: Array[int] = []
	for degree in range(1, 9):
		var btn: Button = _degree_toggles.get(degree, null)
		if btn != null and btn.button_pressed:
			selected.append(degree)
	if selected.is_empty():
		selected.append(1)
	return selected


func _current_note_duration() -> float:
	return NOTE_DURATION * (1.6 if _slow_toggle != null and _slow_toggle.button_pressed else 1.0)


func _current_gap_duration() -> float:
	return GAP_DURATION * (1.7 if _slow_toggle != null and _slow_toggle.button_pressed else 1.0)


func _current_post_answer_delay() -> float:
	return 1.25 if _slow_toggle != null and _slow_toggle.button_pressed else 0.85


func _refresh_meta_ui() -> void:
	if _lives_label != null:
		_lives_label.text = "Chicken Life: %d" % _lives
	if _streak_label != null:
		_streak_label.text = "Streak: %d" % _streak
	if _xp_label != null:
		_xp_label.text = "XP: %d" % _xp


func _init_session_stats() -> void:
	_interval_stats_asked.clear()
	_interval_stats_correct.clear()
	_chord_stats_asked.clear()
	_chord_stats_correct.clear()
	_sight_stats_asked.clear()
	_sight_stats_correct.clear()
	if _selected_mode == MODE_INTERVAL:
		for interval in _active_intervals:
			_interval_stats_asked[interval] = 0
			_interval_stats_correct[interval] = 0
	else:
		if _selected_mode == MODE_CHORD:
			var keys: Array = CHORD_INTERVALS.keys()
			keys.sort()
			for key in keys:
				_chord_stats_asked[key] = 0
				_chord_stats_correct[key] = 0
		else:
			if _sight_mode == "Chords":
				for triad in SIGHT_TRIADS:
					var chord_name := str(triad["name"])
					_sight_stats_asked[chord_name] = 0
					_sight_stats_correct[chord_name] = 0
			else:
				for n in ["C", "D", "E", "F", "G", "A", "B"]:
					_sight_stats_asked[n] = 0
					_sight_stats_correct[n] = 0


func _get_available_chord_types() -> Array[String]:
	match _selected_chord_group:
		1:
			return _copy_chord_group(CHORD_GROUP_1)
		2:
			return _copy_chord_group(CHORD_GROUP_2)
		3:
			return _copy_chord_group(CHORD_GROUP_3)
		4:
			# "All" mode is adaptive by design.
			if _streak >= 6:
				return _copy_chord_group(CHORD_GROUP_4)
			if _streak >= 3:
				return _merge_chord_groups([CHORD_GROUP_1, CHORD_GROUP_2])
			return _copy_chord_group(CHORD_GROUP_1)
		_:
			return _copy_chord_group(CHORD_GROUP_1)


func _copy_chord_group(source: Array) -> Array[String]:
	var out: Array[String] = []
	for item in source:
		out.append(str(item))
	return out


func _merge_chord_groups(groups: Array) -> Array[String]:
	var out: Array[String] = []
	for group in groups:
		for item in group:
			var chord_name := str(item)
			if not out.has(chord_name):
				out.append(chord_name)
	return out


func _record_question_asked() -> void:
	if _selected_mode == MODE_INTERVAL:
		_interval_stats_asked[_current_interval_id] = int(_interval_stats_asked.get(_current_interval_id, 0)) + 1
	elif _selected_mode == MODE_CHORD:
		_chord_stats_asked[_current_chord_quality] = int(_chord_stats_asked.get(_current_chord_quality, 0)) + 1
	else:
		var key := _current_sight_chord_name if _sight_mode == "Chords" else _current_sight_note
		_sight_stats_asked[key] = int(_sight_stats_asked.get(key, 0)) + 1


func _record_question_correct() -> void:
	if _selected_mode == MODE_INTERVAL:
		_interval_stats_correct[_current_interval_id] = int(_interval_stats_correct.get(_current_interval_id, 0)) + 1
	elif _selected_mode == MODE_CHORD:
		_chord_stats_correct[_current_chord_quality] = int(_chord_stats_correct.get(_current_chord_quality, 0)) + 1
	else:
		var key := _current_sight_chord_name if _sight_mode == "Chords" else _current_sight_note
		_sight_stats_correct[key] = int(_sight_stats_correct.get(key, 0)) + 1


func _session_performance_summary() -> String:
	var parts: Array[String] = []
	if _selected_mode == MODE_INTERVAL:
		var keys: Array = _interval_stats_asked.keys()
		keys.sort()
		for key in keys:
			var asked := int(_interval_stats_asked[key])
			if asked <= 0:
				continue
			var correct := int(_interval_stats_correct.get(key, 0))
			var acc := int(round((float(correct) / float(asked)) * 100.0))
			parts.append("%s:%d%%" % [_interval_display_name(str(key)), acc])
	elif _selected_mode == MODE_CHORD:
		var ckeys: Array = _chord_stats_asked.keys()
		ckeys.sort()
		for key in ckeys:
			var asked_c := int(_chord_stats_asked[key])
			if asked_c <= 0:
				continue
			var correct_c := int(_chord_stats_correct.get(key, 0))
			var acc_c := int(round((float(correct_c) / float(asked_c)) * 100.0))
			parts.append("%s:%d%%" % [str(key), acc_c])
	else:
		var nkeys: Array = _sight_stats_asked.keys()
		nkeys.sort()
		for key in nkeys:
			var asked_n := int(_sight_stats_asked[key])
			if asked_n <= 0:
				continue
			var correct_n := int(_sight_stats_correct.get(key, 0))
			var acc_n := int(round((float(correct_n) / float(asked_n)) * 100.0))
			parts.append("%s:%d%%" % [str(key), acc_n])
	return "Performance: " + (" | ".join(parts) if not parts.is_empty() else "N/A")


func _on_start_quiz_pressed() -> void:
	if _selected_mode == MODE_TEACHER:
		_on_teacher_open_pressed()
		return
	if _selected_mode == MODE_READ:
		_home_info_label.text = ""
		_show_game()
		await _start_read_module()
		return

	if _selected_mode == MODE_INTERVAL:
		_active_intervals = _build_interval_pool_for_settings()
		if _active_intervals.size() < 3:
			_home_info_label.text = "Need at least 3 interval options."
			return
	else:
		_active_intervals = []

	_home_info_label.text = ""
	_total_questions = int(_question_spin.value)
	_apply_answer_mode()
	_score = 0
	_question_index = 0
	_lives = 3
	_streak = 0
	_xp = 0
	_last_interval_signature = ""
	_last_chord_signature = ""
	_last_sight_signature = ""
	_quiz_active = true
	_accepting_answer = false
	_init_session_stats()
	_refresh_meta_ui()
	_result_box_hide()
	_show_game()
	await _begin_next_question()


func _on_end_quiz_pressed() -> void:
	_in_tutorial = false
	_quiz_active = false
	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_status_label.text = "Back to home."
	_result_box_hide()
	_show_home()


func _on_restart_quiz_pressed() -> void:
	if _is_prompt_playing:
		return
	if _selected_mode == MODE_READ:
		await _start_read_module()
		return
	_quiz_active = false
	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_status_label.text = "Restarting..."
	_score = 0
	_question_index = 0
	_lives = 3
	_streak = 0
	_xp = 0
	_last_interval_signature = ""
	_last_chord_signature = ""
	_last_sight_signature = ""
	_init_session_stats()
	_refresh_meta_ui()
	_result_box_hide()
	_quiz_active = true
	await _begin_next_question()


func _build_interval_pool_for_settings() -> Array[String]:
	var selected_degrees := _get_selected_degrees()
	var pool: Array[String] = []
	for d in selected_degrees:
		var options: Array = DEGREE_INTERVALS.get(d, [])
		for id in options:
			var iid := str(id)
			if iid.begins_with("m") and not _include_minor_intervals:
				continue
			if not pool.has(iid):
				pool.append(iid)
	if pool.is_empty():
		for d in selected_degrees:
			var fallback_options: Array = DEGREE_INTERVALS.get(d, [])
			for id in fallback_options:
				var fallback_id := str(id)
				if not pool.has(fallback_id):
					pool.append(fallback_id)
	return pool


func _build_interval_choices(correct_id: String, pool: Array[String]) -> Array[String]:
	var distractors: Array[String] = []
	for id in pool:
		var iid := str(id)
		if iid != correct_id:
			distractors.append(iid)
	distractors.shuffle()
	var choices: Array[String] = [correct_id]
	choices.append_array(distractors.slice(0, 2))
	choices.shuffle()
	return choices


func _apply_answer_mode() -> void:
	if _selected_mode == MODE_INTERVAL:
		_prompt_label.text = "Choose the interval:"
	elif _selected_mode == MODE_CHORD:
		_prompt_label.text = "Choose the chord type:"
	elif _selected_mode == MODE_READ:
		_prompt_label.text = ""
	elif _selected_mode == MODE_TEACHER:
		_prompt_label.text = ""
	else:
		if _sight_mode == "Chords":
			_prompt_label.text = "Choose the chord name:"
		elif _sight_mode == "Placement":
			_prompt_label.text = "Drag note to the correct line/space:"
		else:
			_prompt_label.text = "Click the matching key:"

	if _selected_mode == MODE_SIGHT or _selected_mode == MODE_READ:
		_replay_button.visible = false
		_slow_toggle.visible = false
		_sight_side_controls.visible = false
		_control_row.visible = false
		_prompt_label.visible = _selected_mode == MODE_SIGHT and _sight_mode == "Placement"
		_status_label.visible = false
		_game_panel.add_theme_constant_override("separation", 2)
		_staff_note.mouse_filter = Control.MOUSE_FILTER_STOP if (_selected_mode == MODE_SIGHT and _sight_mode == "Placement") or _in_tutorial else Control.MOUSE_FILTER_IGNORE
	else:
		if _replay_button.get_parent() != _control_row:
			if _replay_button.get_parent() != null:
				_replay_button.get_parent().remove_child(_replay_button)
			_control_row.add_child(_replay_button)
		if _slow_toggle.get_parent() != _control_row:
			if _slow_toggle.get_parent() != null:
				_slow_toggle.get_parent().remove_child(_slow_toggle)
			_control_row.add_child(_slow_toggle)
		_replay_button.visible = true
		_slow_toggle.visible = true
		_sight_side_controls.visible = true
		_control_row.visible = true
		_prompt_label.visible = true
		_status_label.visible = true
		_game_panel.add_theme_constant_override("separation", 10)
	if _selected_mode != MODE_READ and _tutorial_bubble != null:
		_tutorial_bubble.visible = false
	if _selected_mode != MODE_READ and _tutorial_bubble_tail != null:
		_tutorial_bubble_tail.visible = false
	if _tutorial_button_row != null and _selected_mode != MODE_READ:
		_tutorial_button_row.visible = false
	if _tutorial_end_button_col != null and _selected_mode != MODE_READ:
		_tutorial_end_button_col.visible = false

	for btn in _interval_choice_buttons:
		var is_active := _selected_mode == MODE_INTERVAL
		btn.visible = is_active
		btn.disabled = not is_active

	for chord_name in CHORD_INTERVALS.keys():
		if _chord_buttons.has(chord_name):
			var chord_btn: Button = _chord_buttons[chord_name]
			var show := _selected_mode == MODE_CHORD and _current_available_chord_types.has(chord_name)
			chord_btn.visible = show
			chord_btn.disabled = not show

	for note_name in _sight_key_buttons.keys():
		var k_btn: Button = _sight_key_buttons[note_name]
		var show_key := _selected_mode == MODE_SIGHT and _sight_mode == "Notes"
		k_btn.visible = show_key
		k_btn.disabled = not show_key
		k_btn.modulate = Color(1, 1, 1, 1)

	for i in _sight_chord_choice_buttons.size():
		var sc_btn: Button = _sight_chord_choice_buttons[i]
		var show_chord_choice := _selected_mode == MODE_SIGHT and _sight_mode == "Chords"
		sc_btn.visible = show_chord_choice
		sc_btn.disabled = not show_chord_choice
		sc_btn.modulate = Color(1, 1, 1, 1)

	_sight_container.visible = _selected_mode == MODE_SIGHT or _selected_mode == MODE_READ
	if _teacher_panel != null:
		_teacher_panel.visible = _selected_mode == MODE_TEACHER
	if _sky_block != null:
		if _selected_mode == MODE_READ:
			_sky_block.custom_minimum_size = Vector2(0, 118)
		elif _selected_mode == MODE_SIGHT:
			_sky_block.custom_minimum_size = Vector2(0, 16)
		elif _selected_mode == MODE_TEACHER:
			_sky_block.custom_minimum_size = Vector2(0, 0)
		else:
			_sky_block.custom_minimum_size = Vector2(0, 140)
	if _staff_area != null:
		if _selected_mode == MODE_READ:
			_staff_area.custom_minimum_size = Vector2(470, 246)
		else:
			_staff_area.custom_minimum_size = Vector2(500, 320)
	if _sight_top_spacer != null:
		if _selected_mode == MODE_READ:
			_sight_top_spacer.custom_minimum_size = Vector2(0, 78)
		else:
			_sight_top_spacer.custom_minimum_size = Vector2(0, 0)
	if _bird_sprite != null:
		_bird_sprite.visible = _selected_mode != MODE_READ
	if _tutorial_chicken != null:
		_tutorial_chicken.visible = _selected_mode == MODE_READ
		if _selected_mode == MODE_READ:
			_tutorial_chicken.move_to_front()
	if _tutorial_bubble != null and _selected_mode == MODE_READ:
		_tutorial_bubble.move_to_front()
	if _tutorial_bubble_tail != null and _selected_mode == MODE_READ:
		_tutorial_bubble_tail.move_to_front()
	if _staff_clef_label != null:
		_staff_clef_label.text = "𝄢" if _selected_clef == "Bass" else "𝄞"
	if _selected_mode == MODE_SIGHT or _selected_mode == MODE_READ:
		_start_sight_note_bounce()
	else:
		_stop_sight_note_bounce()
	if _selected_mode == MODE_READ:
		call_deferred("_position_tutorial_button_row")
		call_deferred("_position_tutorial_title")
		call_deferred("_position_tutorial_end_buttons")
	if _selected_mode == MODE_TEACHER:
		_replay_button.visible = false
		_slow_toggle.visible = false
		_sight_side_controls.visible = false
		_control_row.visible = false
		_prompt_label.visible = false
		_status_label.visible = false


func _show_home() -> void:
	_in_tutorial = false
	_home_card.visible = true
	_home_panel.visible = true
	_game_card.visible = false
	_game_panel.visible = false
	_end_button.visible = false
	_restart_button.visible = false
	_hud_left_box.visible = false
	_hud_right_box.visible = false
	_hud_center_box.visible = false
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	if _teacher_panel != null:
		_teacher_panel.visible = false
	if _tutorial_bubble != null:
		_tutorial_bubble.visible = false
	if _tutorial_bubble_tail != null:
		_tutorial_bubble_tail.visible = false
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	if _tutorial_button_row != null:
		_tutorial_button_row.visible = false
	if _tutorial_end_button_col != null:
		_tutorial_end_button_col.visible = false
	if _tutorial_chicken != null:
		_tutorial_chicken.visible = false
	_result_box_hide()


func _show_game() -> void:
	_home_card.visible = false
	_home_panel.visible = false
	_game_card.visible = true
	_game_panel.visible = true
	_end_button.visible = true
	_restart_button.visible = true
	_hud_left_box.visible = true
	_hud_right_box.visible = true
	_hud_center_box.visible = true
	if _selected_mode == MODE_READ:
		_hud_left_box.visible = false
		_hud_right_box.visible = false
		_hud_center_box.visible = false
	if _selected_mode == MODE_TEACHER:
		_restart_button.visible = false
		_hud_left_box.visible = false
		_hud_right_box.visible = false
		_hud_center_box.visible = false
		_prompt_label.visible = false
		_control_row.visible = false
		_sight_container.visible = false
		if _teacher_panel != null:
			_teacher_panel.visible = true
			_refresh_teacher_students_list()
	if _tutorial_button_row != null:
		_tutorial_button_row.visible = _selected_mode == MODE_READ
		if _selected_mode == MODE_READ:
			call_deferred("_position_tutorial_button_row")
	if _tutorial_end_button_col != null:
		_tutorial_end_button_col.visible = false
	if _tutorial_panel != null and _selected_mode == MODE_READ:
		call_deferred("_position_tutorial_title")
		call_deferred("_position_tutorial_end_buttons")
	_end_button.move_to_front()
	_restart_button.move_to_front()


func _start_read_module() -> void:
	_in_tutorial = true
	_tutorial_run_id += 1
	_tutorial_module_recorded = false
	_quiz_active = true
	_accepting_answer = false
	_replay_button.disabled = true
	_restart_button.disabled = false
	_score = 0
	_question_index = 0
	_lives = 3
	_streak = 0
	_xp = 0
	_refresh_meta_ui()
	_apply_answer_mode()
	_set_answer_buttons_enabled(false)
	_hide_preview_ledger()
	_hide_target_dotted_oval()
	_set_staff_highlight_none()
	_clear_staff_ledger_lines()
	_result_box_hide()
	if _selected_read_module == 2:
		_tutorial_step = 10
	else:
		_tutorial_step = 0
	await _show_tutorial_step()


func _on_tutorial_continue_pressed() -> void:
	if not _in_tutorial:
		return
	if (_tutorial_step == 6 or _tutorial_step == 8) and not _tutorial_exercise_done:
		return
	_tutorial_run_id += 1
	_interrupt_tutorial_audio()
	_tutorial_continue_button.visible = false
	_tutorial_back_button.visible = false
	if _tutorial_button_row != null:
		call_deferred("_position_tutorial_button_row")
	_tutorial_step += 1
	await _show_tutorial_step()


func _on_tutorial_back_pressed() -> void:
	if not _in_tutorial:
		return
	if _tutorial_step <= 0:
		return
	_tutorial_run_id += 1
	_interrupt_tutorial_audio()
	_tutorial_continue_button.visible = false
	_tutorial_back_button.visible = false
	if _tutorial_button_row != null:
		call_deferred("_position_tutorial_button_row")
	_tutorial_step = maxi(0, _tutorial_step - 1)
	await _show_tutorial_step()


func _on_tutorial_module2_pressed() -> void:
	_selected_read_module = 2
	_refresh_read_module_buttons()
	_tutorial_run_id += 1
	_interrupt_tutorial_audio()
	_tutorial_step = 10
	await _show_tutorial_step()


func _on_tutorial_home_pressed() -> void:
	_in_tutorial = false
	_tutorial_run_id += 1
	_interrupt_tutorial_audio()
	_show_home()


func _interrupt_tutorial_audio() -> void:
	if _piano_player != null:
		_piano_player.stop()
	if _sfx_player != null:
		_sfx_player.stop()
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.play()
		_playback = _audio_player.get_stream_playback()


func _position_tutorial_button_row() -> void:
	if _tutorial_button_row == null or _staff_area == null:
		return
	if not _tutorial_button_row.visible:
		return
	_tutorial_button_row.reset_size()
	var top_line_global_y := _staff_area.global_position.y + STAFF_TOP_LINE_Y
	var row_size := _tutorial_button_row.size
	if row_size.x <= 1.0:
		row_size = _tutorial_button_row.get_combined_minimum_size()
	var left := get_viewport_rect().size.x - row_size.x - 28.0
	var y := top_line_global_y - (row_size.y * 0.5)
	_tutorial_button_row.global_position = Vector2(left, y)


func _position_tutorial_end_buttons() -> void:
	if _tutorial_end_button_col == null or _staff_area == null:
		return
	if not _tutorial_end_button_col.visible:
		return
	_tutorial_end_button_col.reset_size()
	var top_line_global_y := _staff_area.global_position.y + STAFF_TOP_LINE_Y
	var col_size := _tutorial_end_button_col.size
	if col_size.x <= 1.0:
		col_size = _tutorial_end_button_col.get_combined_minimum_size()
	var left := get_viewport_rect().size.x - col_size.x - 28.0
	var y := top_line_global_y
	_tutorial_end_button_col.global_position = Vector2(left, y)


func _position_tutorial_title() -> void:
	if _tutorial_panel == null or _game_card == null:
		return
	if not _tutorial_panel.visible:
		return
	_tutorial_panel.reset_size()
	var title_size := _tutorial_panel.size
	if title_size.x <= 1.0:
		title_size = _tutorial_panel.get_combined_minimum_size()
	var left := _game_card.global_position.x + (_game_card.size.x - title_size.x) * 0.5
	var y := _game_card.global_position.y + 16.0
	_tutorial_panel.global_position = Vector2(left, y)


func _set_tutorial_character_layout(step: int) -> void:
	if _tutorial_chicken != null:
		_tutorial_chicken.position = Vector2(18, 28)
	if _tutorial_bubble != null:
		_tutorial_bubble.position = Vector2(118, 14)
	if _tutorial_bubble_tail != null:
		_tutorial_bubble_tail.position = Vector2(156, 86)
	if step == 0:
		if _tutorial_chicken != null:
			_tutorial_chicken.position = Vector2(18, 54)
		if _tutorial_bubble != null:
			_tutorial_bubble.position = Vector2(118, 38)
		if _tutorial_bubble_tail != null:
			_tutorial_bubble_tail.position = Vector2(156, 112)
	if step == 1:
		if _tutorial_chicken != null:
			_tutorial_chicken.position = Vector2(18, 46)
		if _tutorial_bubble != null:
			_tutorial_bubble.position = Vector2(118, 34)
		if _tutorial_bubble_tail != null:
			_tutorial_bubble_tail.position = Vector2(156, 106)


func _tutorial_random_line(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return str(lines[_rng.randi_range(0, lines.size() - 1)])


func _set_tutorial_chicken_line(text: String) -> void:
	_tutorial_body_label.text = text
	if _tutorial_bubble_label != null and _tutorial_bubble.visible:
		_tutorial_bubble_label.text = text


func _show_tutorial_step() -> void:
	if _tutorial_panel == null:
		return
	var run_id := _tutorial_run_id
	_stop_sight_note_bounce()
	_tutorial_panel.visible = true
	_tutorial_body_label.visible = false
	_tutorial_continue_button.visible = true
	_tutorial_continue_button.disabled = false
	_tutorial_back_button.visible = _tutorial_step > 0
	_tutorial_back_button.disabled = false
	_tutorial_module2_button.visible = false
	_tutorial_home_button.visible = false
	if _tutorial_button_row != null:
		_tutorial_button_row.visible = true
		call_deferred("_position_tutorial_button_row")
	if _tutorial_end_button_col != null:
		_tutorial_end_button_col.visible = false
	if _tutorial_end_module2_button != null:
		_tutorial_end_module2_button.visible = false
	if _tutorial_end_home_button != null:
		_tutorial_end_home_button.visible = false
	if _tutorial_end_back_button != null:
		_tutorial_end_back_button.visible = false
	call_deferred("_position_tutorial_title")
	_tutorial_exercise_done = false
	_accepting_answer = false
	_staff_area.visible = true
	var convo_step := _tutorial_step
	_prompt_label.visible = false
	_status_label.visible = false
	_replay_button.visible = false
	_slow_toggle.visible = false
	_control_row.visible = false

	for btn in _sight_chord_choice_buttons:
		btn.visible = false
		btn.disabled = true
	for note_name in _sight_key_buttons.keys():
		var kb: Button = _sight_key_buttons[note_name]
		kb.visible = false
		kb.disabled = true

	for n in _staff_chord_notes:
		n.visible = false
	_ensure_staff_base_lines_visible()
	_set_staff_highlight_none()
	_hide_preview_ledger()
	_hide_target_dotted_oval()
	_clear_staff_ledger_lines()
	_staff_note.modulate = Color(1, 1, 1, 1)
	_staff_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_tutorial_character_layout(_tutorial_step)
	if _tutorial_bubble != null:
		_tutorial_bubble.visible = false
	if _tutorial_bubble_tail != null:
		_tutorial_bubble_tail.visible = false
	if _tutorial_chicken != null:
		_tutorial_chicken.visible = true
		_tutorial_chicken.move_to_front()
	for ln in _staff_line_number_labels:
		ln.visible = false

	match _tutorial_step:
		0:
			_tutorial_title_label.text = "Module 1: Staff Story"
			_tutorial_body_label.text = "Welcome. You will learn staff lines, clefs, and Middle C in both clefs."
			_staff_area.visible = false
			await _play_tutorial_page_cue(run_id)
		1:
			_tutorial_title_label.text = "Staff Lines"
			_tutorial_body_label.text = "These are the 5 staff lines. We will number them from bottom to top."
			await _play_tutorial_page_cue(run_id)
		2:
			_tutorial_title_label.text = "Staff Numbering"
			_tutorial_body_label.text = "Watch the numbering: line 1 is bottom, line 5 is top."
			await _animate_staff_lines_intro(run_id)
			if run_id != _tutorial_run_id:
				return
			await _play_tutorial_page_cue(run_id)
		3:
			_tutorial_title_label.text = "Treble Clef"
			_tutorial_body_label.text = "Treble clef is used for higher notes."
			_selected_clef = "Treble"
			_refresh_clef_buttons()
			_position_sight_note("G", STAFF_TOP_LINE_Y + 4.0 * STAFF_STEP_Y)
			await _blink_clef_highlight(4, 1.5, run_id)
			if run_id != _tutorial_run_id:
				return
			await _play_tutorial_page_cue(run_id)
		4:
			_tutorial_title_label.text = "Bass Clef"
			_tutorial_body_label.text = "Bass clef is used for lower notes."
			_selected_clef = "Bass"
			_refresh_clef_buttons()
			_position_sight_note("C", STAFF_TOP_LINE_Y + 5.0 * STAFF_STEP_Y)
			await _blink_clef_highlight(4, 1.5, run_id)
			if run_id != _tutorial_run_id:
				return
			await _play_tutorial_page_cue(run_id)
		5:
			_tutorial_title_label.text = "Middle C in Treble"
			_tutorial_body_label.text = "Middle C (C4) sits below the treble staff with a ledger line."
			_selected_clef = "Treble"
			_refresh_clef_buttons()
			_position_sight_note("C", STAFF_TOP_LINE_Y + 10.0 * STAFF_STEP_Y)
			await _play_tutorial_page_cue(run_id)
		6:
			_tutorial_title_label.text = "Exercise: Place Middle C (Treble)"
			_tutorial_body_label.text = "Drag the note from the side and place it on Middle C (C4)."
			_selected_clef = "Treble"
			_refresh_clef_buttons()
			_tutorial_expected_step = 10
			_tutorial_exercise_done = false
			_tutorial_continue_button.disabled = true
			_staff_note.mouse_filter = Control.MOUSE_FILTER_STOP
			_accepting_answer = true
			_reset_placement_note_to_side()
			await _play_tutorial_page_cue(run_id)
		7:
			_tutorial_title_label.text = "Middle C in Bass"
			_tutorial_body_label.text = "Middle C (C4) sits above the bass staff with a ledger line."
			_selected_clef = "Bass"
			_refresh_clef_buttons()
			_position_sight_note("C", STAFF_TOP_LINE_Y - 2.0 * STAFF_STEP_Y)
			await _play_tutorial_page_cue(run_id)
		8:
			_tutorial_title_label.text = "Exercise: Place Middle C (Bass)"
			_tutorial_body_label.text = "Now place Middle C (C4) in bass clef."
			_selected_clef = "Bass"
			_refresh_clef_buttons()
			_tutorial_expected_step = -2
			_tutorial_exercise_done = false
			_tutorial_continue_button.disabled = true
			_staff_note.mouse_filter = Control.MOUSE_FILTER_STOP
			_accepting_answer = true
			_reset_placement_note_to_side()
			await _play_tutorial_page_cue(run_id)
		9:
			_tutorial_title_label.text = "Module 1 Complete"
			_tutorial_body_label.text = "Great work. You learned staff lines, both clefs, and Middle C placement."
			if not _tutorial_module_recorded:
				_teacher_mark_module_completed()
				_tutorial_module_recorded = true
			_tutorial_continue_button.visible = false
			_tutorial_back_button.visible = false
			if _tutorial_button_row != null:
				_tutorial_button_row.visible = false
			if _tutorial_end_button_col != null:
				_tutorial_end_button_col.visible = true
				call_deferred("_position_tutorial_end_buttons")
			if _tutorial_end_module2_button != null:
				_tutorial_end_module2_button.visible = true
			if _tutorial_end_home_button != null:
				_tutorial_end_home_button.visible = true
			if _tutorial_end_back_button != null:
				_tutorial_end_back_button.visible = true
			_position_sight_note("E", STAFF_TOP_LINE_Y + 4.0 * STAFF_STEP_Y)
			await _play_tutorial_page_cue(run_id)
		10:
			_tutorial_title_label.text = "Module 2: More Treble Notes"
			_tutorial_body_label.text = "Coming soon. This module will introduce more treble clef notes."
			_tutorial_continue_button.visible = false
			_tutorial_back_button.visible = false
			if _tutorial_button_row != null:
				_tutorial_button_row.visible = false
			if _tutorial_end_button_col != null:
				_tutorial_end_button_col.visible = true
				call_deferred("_position_tutorial_end_buttons")
			if _tutorial_end_module2_button != null:
				_tutorial_end_module2_button.visible = false
			if _tutorial_end_home_button != null:
				_tutorial_end_home_button.visible = true
			if _tutorial_end_back_button != null:
				_tutorial_end_back_button.visible = true
			_selected_clef = "Treble"
			_refresh_clef_buttons()
			_position_sight_note("G", STAFF_TOP_LINE_Y + 4.0 * STAFF_STEP_Y)
			await _play_tutorial_page_cue(run_id)
		_:
			_tutorial_step = 9
			await _show_tutorial_step()

	if run_id != _tutorial_run_id:
		return

	if _tutorial_step_label != null:
		var shown_step := _tutorial_step + 1
		_tutorial_step_label.text = "Module 1  |  Step %d / 11" % shown_step
		if _tutorial_step == 10:
			_tutorial_step_label.text = "Module 2 Preview"

	await get_tree().create_timer(1.0).timeout
	if not _in_tutorial or _tutorial_step != convo_step:
		return
	if run_id != _tutorial_run_id:
		return
	if _tutorial_bubble != null:
		_tutorial_bubble.visible = true
	if _tutorial_bubble_label != null:
		_tutorial_bubble_label.text = _tutorial_body_label.text
	await _play_tutorial_hmm(run_id)


func _animate_staff_lines_intro(run_id: int = -1) -> void:
	await get_tree().create_timer(2.0).timeout
	if run_id != -1 and run_id != _tutorial_run_id:
		return
	for i in _staff_lines.size():
		var line := _staff_lines[i]
		var lbl := _staff_line_number_labels[i]
		line.modulate = Color(1, 1, 1, 0.0)
		lbl.modulate = Color(1, 1, 1, 0.0)
		lbl.visible = true
		line.color = Color(1.0, 1.0, 1.0, 0.95)
		lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))

	var reveal_order: Array[int] = [4, 3, 2, 1, 0]
	var line_notes: Array[int] = [60, 62, 64, 65, 67]
	for order_idx in reveal_order.size():
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		var idx := reveal_order[order_idx]
		var line := _staff_lines[idx]
		var lbl := _staff_line_number_labels[idx]
		line.color = Color(0.72, 1.0, 0.20, 1.0)
		lbl.add_theme_color_override("font_color", Color(0.72, 1.0, 0.20, 1.0))
		var tw := create_tween()
		tw.tween_property(line, "modulate:a", 1.0, 0.72)
		tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.72)
		await tw.finished
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		await _play_note(line_notes[order_idx], 0.18)
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		await get_tree().create_timer(0.34).timeout
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		line.color = Color(1.0, 1.0, 1.0, 0.95)
		lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
		await get_tree().create_timer(0.26).timeout
		if run_id != -1 and run_id != _tutorial_run_id:
			return


func _blink_clef_highlight(times: int = 4, total_seconds: float = 1.4, run_id: int = -1) -> void:
	if _staff_clef_label == null:
		return
	var base := Color(1.0, 1.0, 1.0, 1.0)
	var hi := Color(0.72, 1.0, 0.20, 1.0)
	var blink_count := maxi(1, times)
	var phase := total_seconds / float(blink_count * 2)
	for i in range(blink_count):
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		_staff_clef_label.modulate = hi
		await get_tree().create_timer(phase).timeout
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		_staff_clef_label.modulate = base
		await get_tree().create_timer(phase).timeout
		if run_id != -1 and run_id != _tutorial_run_id:
			return
	_staff_clef_label.modulate = base


func _play_tutorial_page_cue(run_id: int = -1) -> void:
	var chord_pick: Array = []
	var root_options: Array[int] = [55, 57, 59, 60, 62, 64]
	for attempt in range(10):
		var candidate: Array = TUTORIAL_CUE_CHORDS[_rng.randi_range(0, TUTORIAL_CUE_CHORDS.size() - 1)]
		var root: int = root_options[_rng.randi_range(0, root_options.size() - 1)]
		var sig_parts: Array[String] = []
		for v in candidate:
			sig_parts.append(str(v))
		var signature := "%d:%s" % [root, ",".join(sig_parts)]
		if signature != _last_tutorial_cue_signature or attempt == 9:
			_last_tutorial_cue_signature = signature
			chord_pick = candidate.duplicate()
			chord_pick.sort()
			for i in chord_pick.size():
				chord_pick[i] = root + int(chord_pick[i])
			break
	if chord_pick.is_empty():
		chord_pick = [60, 64, 67]

	var note_len := 0.12
	for i in chord_pick.size():
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		await _play_note(int(chord_pick[i]), note_len)
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		await _push_silence(0.02)
		if run_id != -1 and run_id != _tutorial_run_id:
			return
	if chord_pick.size() >= 3:
		await _play_note(int(chord_pick[1]), 0.08)
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		await _push_silence(0.02)
		if run_id != -1 and run_id != _tutorial_run_id:
			return
		await _play_note(int(chord_pick[2]), 0.1)


func _play_tutorial_hmm(run_id: int = -1) -> void:
	if run_id != -1 and run_id != _tutorial_run_id:
		return
	await _push_sine(220.0, 0.04)
	if run_id != -1 and run_id != _tutorial_run_id:
		return
	await _push_silence(0.01)
	if run_id != -1 and run_id != _tutorial_run_id:
		return
	await _push_sine(196.0, 0.04)


func _begin_next_question() -> void:
	if not _quiz_active:
		return

	if _question_index >= _total_questions:
		_finish_quiz()
		return

	_question_index += 1
	_score_label.text = "Score: %d / %d" % [_score, _question_index - 1]
	_progress_label.text = "Question %d of %d" % [_question_index, _total_questions]
	_status_label.text = "Listen..."
	_refresh_meta_ui()

	_set_answer_buttons_enabled(false)
	_accepting_answer = false
	_replay_button.disabled = true
	_restart_button.disabled = true
	_reset_bird_position()
	if _selected_mode == MODE_CHORD:
		_current_available_chord_types = _get_available_chord_types()
	elif _selected_mode == MODE_SIGHT:
		_current_available_chord_types = []
	else:
		_current_available_chord_types = []
	_apply_answer_mode()
	_generate_round()
	await _play_new_question_cue()
	_record_question_asked()
	_is_prompt_playing = true
	await _play_current_prompt()
	_is_prompt_playing = false
	if not _quiz_active:
		return

	_status_label.text = "Pick the correct nest."
	_set_answer_buttons_enabled(true)
	_accepting_answer = true
	_replay_button.disabled = false
	_restart_button.disabled = false


func _finish_quiz() -> void:
	_quiz_active = false
	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = false
	_status_label.text = ""
	_progress_label.text = "Final Score: %d / %d | XP: %d" % [_score, _total_questions, _xp]
	_teacher_record_session_metrics(_selected_mode, _score, _total_questions)
	var perf := _session_performance_summary()
	_home_info_label.text = perf
	_result_box_show("Complete", perf)
	var score_pct := (float(_score) / float(maxi(1, _total_questions))) * 100.0
	_play_completion_reaction(score_pct)


func _generate_round() -> void:
	if _selected_mode == MODE_INTERVAL:
		var interval_sig := ""
		for attempt in range(16):
			var selected_degrees := _get_selected_degrees()
			var picked_degree := selected_degrees[_rng.randi_range(0, selected_degrees.size() - 1)]
			var degree_candidates: Array = DEGREE_INTERVALS.get(picked_degree, [])
			if degree_candidates.is_empty():
				degree_candidates = DEGREE_INTERVALS.get(1, ["P1"])
			var correct_pool: Array[String] = []
			for v in degree_candidates:
				var cid := str(v)
				if cid.begins_with("m") and not _include_minor_intervals:
					continue
				correct_pool.append(cid)
			if correct_pool.is_empty():
				for v in degree_candidates:
					correct_pool.append(str(v))
			_current_interval_id = correct_pool[_rng.randi_range(0, correct_pool.size() - 1)]
			var semitone_options: Array = INTERVAL_DATA[_current_interval_id]["semitones"]
			var semitones: int = int(semitone_options[_rng.randi_range(0, semitone_options.size() - 1)])
			_current_root_midi = _rng.randi_range(52, 64)
			_current_second_midi = _current_root_midi + semitones
			interval_sig = "%s:%d:%d" % [_current_interval_id, _current_root_midi, _current_second_midi]
			if interval_sig != _last_interval_signature or attempt == 15:
				break
		_last_interval_signature = interval_sig
		_current_interval_choices = _build_interval_choices(_current_interval_id, _active_intervals)
		_interval_option_map.clear()
		for i in _interval_choice_buttons.size():
			var choice_id := _current_interval_choices[i]
			var btn: Button = _interval_choice_buttons[i]
			btn.text = _interval_display_name(choice_id)
			_interval_option_map[choice_id] = btn
	elif _selected_mode == MODE_CHORD:
		if _current_available_chord_types.is_empty():
			_current_available_chord_types = _get_available_chord_types()
		var chord_sig := ""
		for attempt in range(16):
			_current_chord_quality = _current_available_chord_types[_rng.randi_range(0, _current_available_chord_types.size() - 1)]
			_current_root_midi = _rng.randi_range(50, 60)
			_current_chord_inversion = 0
			if _inversion_toggle != null and _inversion_toggle.button_pressed:
				var max_inversion := mini(2, CHORD_INTERVALS[_current_chord_quality].size() - 1)
				if max_inversion > 0:
					_current_chord_inversion = _rng.randi_range(0, max_inversion)
			_current_chord_notes = _build_chord_notes(_current_root_midi, _current_chord_quality, _current_chord_inversion)
			chord_sig = "%s:%d:%d" % [_current_chord_quality, _current_root_midi, _current_chord_inversion]
			if chord_sig != _last_chord_signature or attempt == 15:
				break
		_last_chord_signature = chord_sig
	else:
		if _sight_mode == "Chords":
			var sight_chord_sig := ""
			for attempt in range(16):
				_generate_sight_chord_round()
				sight_chord_sig = _current_sight_chord_name
				if _staff_note != null:
					sight_chord_sig += ":%d" % int(round(_staff_note.position.y))
				if sight_chord_sig != _last_sight_signature or attempt == 15:
					break
			_last_sight_signature = sight_chord_sig
		elif _sight_mode == "Placement":
			_generate_sight_placement_round()
		else:
			var sight_note_sig := ""
			for attempt in range(16):
				var slot := _pick_sight_note_slot()
				_current_sight_note = str(slot.get("name", "C"))
				var center_y := float(slot.get("center_y", 96.0))
				_position_sight_note(_current_sight_note, center_y)
				sight_note_sig = "%s:%d" % [_current_sight_note, int(round(center_y))]
				if sight_note_sig != _last_sight_signature or attempt == 15:
					break
			_last_sight_signature = sight_note_sig


func _play_current_prompt() -> void:
	if _selected_mode == MODE_CHORD:
		await _play_chord(_current_chord_notes, _current_note_duration())
		await _push_silence(0.05)
		return
	if _selected_mode == MODE_SIGHT:
		await get_tree().create_timer(0.05).timeout
		return

	await _play_two_notes_async(_current_root_midi, _current_second_midi)


func _play_two_notes_async(midi_a: int, midi_b: int) -> void:
	var d := _current_note_duration()
	var g := _current_gap_duration()
	await _play_note(midi_a, d)
	await _push_silence(g)
	await _play_note(midi_b, d)
	await _push_silence(0.05)


func _on_replay_pressed() -> void:
	if not _quiz_active or _is_prompt_playing:
		return
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_status_label.text = "Replaying..."
	_is_prompt_playing = true
	await _play_current_prompt()
	_is_prompt_playing = false
	if _quiz_active:
		_status_label.text = "Pick the correct nest."
		_set_answer_buttons_enabled(true)
		_replay_button.disabled = false


func _build_chord_notes(root_midi: int, chord_quality: String, inversion: int) -> Array[int]:
	var raw_intervals: Array = CHORD_INTERVALS[chord_quality]
	var intervals: Array[int] = []
	for v in raw_intervals:
		intervals.append(int(v))
	var inv_count := mini(inversion, intervals.size() - 1)
	for i in inv_count:
		var moved: int = int(intervals.pop_front()) + 12
		intervals.append(moved)
	var notes: Array[int] = []
	for iv in intervals:
		notes.append(root_midi + iv)
	return notes


func _play_chord(notes: Array[int], duration: float) -> void:
	if notes.is_empty():
		return
	if _piano_samples.is_empty() or _chord_players.size() < notes.size():
		for midi_note in notes:
			await _play_note(midi_note, 0.08)
		await _push_silence(0.14)
		await _play_broken_chord(notes, duration)
		return

	for i in notes.size():
		var midi_note := notes[i]
		var nearest := _nearest_sample_midi(midi_note)
		var stream: AudioStream = _piano_samples[nearest]
		var player: AudioStreamPlayer = _chord_players[i]
		player.stop()
		player.stream = stream
		player.pitch_scale = pow(2.0, float(midi_note - nearest) / 12.0)
		player.play()

	await get_tree().create_timer(duration).timeout
	for p in _chord_players:
		p.stop()
	await _push_silence(0.14)
	await _play_broken_chord(notes, duration)


func _play_broken_chord(notes: Array[int], duration: float) -> void:
	if notes.is_empty():
		return
	var step_duration: float = clampf(duration * 0.34, 0.18, 0.34)
	for midi_note in notes:
		await _play_note(midi_note, step_duration)
		await _push_silence(0.03)


func _on_interval_choice_index(choice_idx: int) -> void:
	if _selected_mode != MODE_INTERVAL:
		return
	if not _quiz_active or not _accepting_answer:
		return
	if choice_idx < 0 or choice_idx >= _current_interval_choices.size():
		return
	var choice_id := _current_interval_choices[choice_idx]

	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true
	var is_correct := choice_id == _current_interval_id
	var chosen_btn: Button = _interval_choice_buttons[choice_idx]
	var correct_btn: Button = _get_button_for_interval(_current_interval_id)
	if is_correct:
		_score += 1
		_streak += 1
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		_status_label.text = "Correct! It was %s." % _interval_display_name(_current_interval_id)
		await _blink_answer_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		_streak = 0
		_lives = maxi(0, _lives - 1)
		_xp = maxi(0, _xp - 2)
		_status_label.text = "Not quite. Correct answer: %s." % _interval_display_name(_current_interval_id)
		await _blink_answer_feedback(chosen_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Score: %d / %d" % [_score, _question_index]
	_refresh_meta_ui()

	if is_correct and correct_btn != null:
		await _feed_chicken_at_target(correct_btn)
		await get_tree().create_timer(0.12).timeout
		await _fly_bird_to_start()
	else:
		await _play_hungry_reaction()

	if _lives <= 0:
		_quiz_active = false
		_accepting_answer = false
		await _fly_bird_away_sad()
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = ""
		_progress_label.text = "Final Score: %d / %d | XP: %d" % [_score, _question_index, _xp]
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		_result_box_show("Game Over", "No lives left. Restart or Go Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _on_chord_chosen(choice_quality: String) -> void:
	if _selected_mode != MODE_CHORD:
		return
	if not _quiz_active or not _accepting_answer:
		return

	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true
	var is_correct := choice_quality == _current_chord_quality
	var chosen_btn: Button = _chord_buttons.get(choice_quality, null)
	var correct_btn: Button = _chord_buttons.get(_current_chord_quality, null)
	if is_correct:
		_score += 1
		_streak += 1
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		_status_label.text = "Correct! It was %s." % _current_chord_quality
		await _blink_answer_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		_streak = 0
		_lives = maxi(0, _lives - 1)
		_xp = maxi(0, _xp - 2)
		_status_label.text = "Not quite. Correct answer: %s." % _current_chord_quality
		await _blink_answer_feedback(chosen_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Score: %d / %d" % [_score, _question_index]
	_refresh_meta_ui()

	if is_correct and correct_btn != null:
		await _feed_chicken_at_target(correct_btn)
		await get_tree().create_timer(0.12).timeout
		await _fly_bird_to_start()
	else:
		await _play_hungry_reaction()

	if _lives <= 0:
		_quiz_active = false
		_accepting_answer = false
		await _fly_bird_away_sad()
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = ""
		_progress_label.text = "Final Score: %d / %d | XP: %d" % [_score, _question_index, _xp]
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		_result_box_show("Game Over", "No lives left. Restart or Go Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _on_sight_key_chosen(note_name: String) -> void:
	if _selected_mode != MODE_SIGHT:
		return
	if not _quiz_active or not _accepting_answer:
		return

	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true

	var is_correct := note_name == _current_sight_note
	var correct_btn: Button = _sight_key_buttons[_current_sight_note]
	if is_correct:
		_score += 1
		_streak += 1
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		_status_label.text = "Correct! That note is %s." % _current_sight_note
		await _blink_sight_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		_streak = 0
		_lives = maxi(0, _lives - 1)
		_xp = maxi(0, _xp - 2)
		_status_label.text = "Not quite. Correct note: %s." % _current_sight_note
		var wrong_btn: Button = _sight_key_buttons[note_name]
		await _blink_sight_feedback(wrong_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Score: %d / %d" % [_score, _question_index]
	_refresh_meta_ui()

	if is_correct and correct_btn != null:
		await _feed_chicken_at_target(correct_btn)
		await get_tree().create_timer(0.12).timeout
		await _fly_bird_to_start()
	else:
		await _play_hungry_reaction()

	if _lives <= 0:
		_quiz_active = false
		_accepting_answer = false
		await _fly_bird_away_sad()
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = ""
		_progress_label.text = "Final Score: %d / %d | XP: %d" % [_score, _question_index, _xp]
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		_result_box_show("Game Over", "No lives left. Restart or Go Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _on_sight_chord_choice_index(choice_idx: int) -> void:
	if _selected_mode != MODE_SIGHT or _sight_mode != "Chords":
		return
	if not _quiz_active or not _accepting_answer:
		return
	if choice_idx < 0 or choice_idx >= _current_sight_chord_choices.size():
		return
	var chosen_name := _current_sight_chord_choices[choice_idx]

	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true

	var is_correct := chosen_name == _current_sight_chord_name
	var chosen_btn: Button = _sight_chord_choice_buttons[choice_idx]
	var correct_idx := _current_sight_chord_choices.find(_current_sight_chord_name)
	var correct_btn: Button = null
	if correct_idx >= 0 and correct_idx < _sight_chord_choice_buttons.size():
		correct_btn = _sight_chord_choice_buttons[correct_idx]

	if is_correct:
		_score += 1
		_streak += 1
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		_status_label.text = "Correct! It is %s." % _current_sight_chord_name
		await _blink_answer_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		_streak = 0
		_lives = maxi(0, _lives - 1)
		_xp = maxi(0, _xp - 2)
		_status_label.text = "Not quite. Correct chord: %s." % _current_sight_chord_name
		await _blink_answer_feedback(chosen_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Score: %d / %d" % [_score, _question_index]
	_refresh_meta_ui()

	if is_correct and correct_btn != null:
		await _feed_chicken_at_target(correct_btn)
		await get_tree().create_timer(0.12).timeout
		await _fly_bird_to_start()
	else:
		await _play_hungry_reaction()

	if _lives <= 0:
		_quiz_active = false
		_accepting_answer = false
		await _fly_bird_away_sad()
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = ""
		_progress_label.text = "Final Score: %d / %d | XP: %d" % [_score, _question_index, _xp]
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		_result_box_show("Game Over", "No lives left. Restart or Go Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _set_answer_buttons_enabled(enabled: bool) -> void:
	for btn in _answer_buttons:
		if btn.visible:
			btn.disabled = not enabled


func _place_note_from_local_point(local: Vector2, resolve_drop: bool) -> void:
	if _staff_note == null:
		return
	var cx := clampf(local.x, 6.0, _staff_area.size.x - 6.0)
	var cy := local.y
	var bounds := _effective_sight_step_bounds()
	var min_y := STAFF_TOP_LINE_Y + float(bounds.x) * STAFF_STEP_Y
	var max_y := STAFF_TOP_LINE_Y + float(bounds.y) * STAFF_STEP_Y
	cy = clampf(cy, min_y, max_y)
	_staff_note.scale = _note_scale_for_y(cy)
	_staff_note.position = Vector2(cx - (_staff_note.size.x * 0.5), cy - (_staff_note.size.y * 0.5))
	if _is_in_staff_drop_zone(cx):
		var step := _nearest_staff_step_from_center_y(cy)
		_current_sight_hover_step = step
		_preview_placement_step(step)
		if resolve_drop:
			_snap_note_to_step(step, true)
			await _resolve_sight_placement_drop(step)
	else:
		_set_staff_highlight_none()
		_hide_preview_ledger()
		if resolve_drop:
			_reset_placement_note_to_side()


func _on_staff_area_gui_input(event: InputEvent) -> void:
	if not _is_placement_drag_context_active():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _is_note_dragging:
					_is_note_dragging = true
					_note_drag_offset_x = 0.0
					_note_drag_offset_y = 0.0
				_place_note_from_local_point(mb.position, false)
				accept_event()
			else:
				if _is_note_dragging:
					await _finish_note_drag_drop(mb.position)
					accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _is_note_dragging:
			_is_note_dragging = true
			_note_drag_offset_x = 0.0
			_note_drag_offset_y = 0.0
		_place_note_from_local_point((event as InputEventMouseMotion).position, false)
		accept_event()


func _is_placement_drag_context_active() -> bool:
	if not ((_selected_mode == MODE_SIGHT and _sight_mode == "Placement") or _in_tutorial):
		return false
	if not _in_tutorial and (not _quiz_active or not _accepting_answer):
		return false
	return true


func _update_note_drag_from_mouse() -> void:
	if _staff_area == null or _staff_note == null:
		return
	var local_mouse := _staff_area.get_local_mouse_position()
	var center_x := local_mouse.x - _note_drag_offset_x
	var center_y := local_mouse.y - _note_drag_offset_y
	var bounds := _effective_sight_step_bounds()
	var min_y := STAFF_TOP_LINE_Y + float(bounds.x) * STAFF_STEP_Y
	var max_y := STAFF_TOP_LINE_Y + float(bounds.y) * STAFF_STEP_Y
	center_y = clampf(center_y, min_y, max_y)
	center_x = clampf(center_x, 6.0, _staff_area.size.x - 6.0)
	_staff_note.scale = _note_scale_for_y(center_y)
	_staff_note.position = Vector2(center_x - (_staff_note.size.x * 0.5), center_y - (_staff_note.size.y * 0.5))
	if _is_in_staff_drop_zone(center_x):
		var hover_step := _nearest_staff_step_from_center_y(center_y)
		_current_sight_hover_step = hover_step
		_preview_placement_step(hover_step)
	else:
		_set_staff_highlight_none()
		_hide_preview_ledger()


func _finish_note_drag_drop(drop_local_pos: Vector2 = Vector2(-1, -1)) -> void:
	if _staff_note == null or _staff_area == null:
		_is_note_dragging = false
		return
	if not _is_note_dragging:
		return
	_is_note_dragging = false
	var center_x := _staff_note.position.x + (_staff_note.size.x * 0.5)
	var center_y := _staff_note.position.y + (_staff_note.size.y * 0.5)
	if drop_local_pos.x >= 0.0 and drop_local_pos.y >= 0.0:
		center_x = drop_local_pos.x
		center_y = drop_local_pos.y
		var bounds := _effective_sight_step_bounds()
		var min_y := STAFF_TOP_LINE_Y + float(bounds.x) * STAFF_STEP_Y
		var max_y := STAFF_TOP_LINE_Y + float(bounds.y) * STAFF_STEP_Y
		center_y = clampf(center_y, min_y, max_y)
		center_x = clampf(center_x, 6.0, _staff_area.size.x - 6.0)
		_staff_note.scale = _note_scale_for_y(center_y)
		_staff_note.position = Vector2(center_x - (_staff_note.size.x * 0.5), center_y - (_staff_note.size.y * 0.5))
	if not _is_in_staff_drop_zone(center_x):
		_set_staff_highlight_none()
		_hide_preview_ledger()
		_reset_placement_note_to_side()
	else:
		var step := _nearest_staff_step_from_center_y(center_y)
		_snap_note_to_step(step, _in_tutorial)
		await _resolve_sight_placement_drop(step)


func _input(event: InputEvent) -> void:
	if not _is_note_dragging:
		return
	if not _is_placement_drag_context_active():
		_is_note_dragging = false
		return
	if event is InputEventMouseMotion:
		_update_note_drag_from_mouse()
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			var drop_local := _staff_area.get_local_mouse_position()
			await _finish_note_drag_drop(drop_local)
			accept_event()


func _on_staff_note_gui_input(event: InputEvent) -> void:
	if not _is_placement_drag_context_active():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_note_dragging = true
				_note_drag_offset_x = mb.position.x - (_staff_note.size.x * 0.5)
				_note_drag_offset_y = mb.position.y - (_staff_note.size.y * 0.5)
				accept_event()
			else:
				var drop_local := _staff_area.get_local_mouse_position()
				await _finish_note_drag_drop(drop_local)
				accept_event()
	elif event is InputEventMouseMotion and _is_note_dragging:
		_update_note_drag_from_mouse()
		accept_event()


func _nearest_staff_step_from_center_y(center_y: float) -> int:
	var step := int(round((center_y - STAFF_TOP_LINE_Y) / STAFF_STEP_Y))
	var bounds := _effective_sight_step_bounds()
	return clampi(step, bounds.x, bounds.y)


func _snap_note_to_step(step: int, keep_current_x: bool = false) -> void:
	var center_y := STAFF_TOP_LINE_Y + float(step) * STAFF_STEP_Y
	_staff_note.scale = _note_scale_for_y(center_y)
	var px := STAFF_NOTE_SNAP_X
	if keep_current_x:
		px = _staff_note.position.x
	px = clampf(px, STAFF_LEFT_X, STAFF_LEFT_X + STAFF_LINE_WIDTH - _staff_note.size.x)
	_staff_note.position = Vector2(px, center_y - (_staff_note.size.y * 0.5))


func _is_in_staff_drop_zone(center_x: float) -> bool:
	return center_x >= STAFF_LEFT_X and center_x <= (STAFF_LEFT_X + STAFF_LINE_WIDTH)


func _reset_placement_note_to_side() -> void:
	if _staff_note == null:
		return
	var bounds := _effective_sight_step_bounds()
	var home_center_y := STAFF_TOP_LINE_Y + float(clampi(bounds.y - 2, bounds.x, bounds.y)) * STAFF_STEP_Y
	_staff_note.scale = _note_scale_for_y(home_center_y)
	_staff_note.modulate = Color(1, 1, 1, 1)
	_staff_note.visible = true
	_staff_note.position = Vector2(_placement_note_home_pos.x, home_center_y - (_staff_note.size.y * 0.5))
	_hide_target_dotted_oval()


func _preview_placement_step(step: int) -> void:
	_set_staff_highlight_for_step(step, Color(0.95, 0.80, 0.35, 0.95))
	if _is_staff_ledger_step(step):
		_show_preview_ledger(step, Color(0.95, 0.80, 0.35, 0.95))
	else:
		_hide_preview_ledger()


func _resolve_sight_placement_drop(step: int) -> void:
	if _in_tutorial:
		await _resolve_tutorial_placement_drop(step)
		return
	if not _quiz_active:
		return
	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true

	var is_correct := step == _current_sight_target_step
	var ok_green := Color(0.72, 1.0, 0.20, 1.0)
	var bad_red := Color(1.0, 0.26, 0.26, 1.0)
	if is_correct:
		_score += 1
		_streak += 1
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		_staff_note.modulate = ok_green
		_set_staff_highlight_for_step(step, ok_green)
		if _is_staff_ledger_step(step):
			_show_preview_ledger(step, ok_green)
		var pop := create_tween()
		pop.set_trans(Tween.TRANS_SINE)
		pop.set_ease(Tween.EASE_OUT)
		var s0 := _staff_note.scale
		pop.tween_property(_staff_note, "scale", s0 * 1.08, 0.08)
		pop.tween_property(_staff_note, "scale", s0, 0.10)
		await _play_success_sfx()
	else:
		_streak = 0
		_lives = maxi(0, _lives - 1)
		_xp = maxi(0, _xp - 2)
		_staff_note.modulate = bad_red
		_set_staff_highlight_for_step(step, bad_red)
		if _is_staff_ledger_step(step):
			_show_preview_ledger(step, bad_red)
		await _play_fail_sfx()
		var shake := create_tween()
		var x0 := _staff_note.position.x
		shake.tween_property(_staff_note, "position:x", x0 - 8.0, 0.06)
		shake.tween_property(_staff_note, "position:x", x0 + 8.0, 0.06)
		shake.tween_property(_staff_note, "position:x", x0, 0.06)
		await shake.finished
		await _blink_correct_placement_target(_current_sight_target_step, 4, 2.0)

	_score_label.text = "Score: %d / %d" % [_score, _question_index]
	_refresh_meta_ui()

	if is_correct:
		await _feed_chicken_at_target(_staff_note)
		await get_tree().create_timer(0.12).timeout
		await _fly_bird_to_start()
	else:
		await _play_hungry_reaction()

	_reset_placement_note_to_side()
	_set_staff_highlight_none()
	_hide_preview_ledger()

	if _lives <= 0:
		_quiz_active = false
		_accepting_answer = false
		await _fly_bird_away_sad()
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = ""
		_progress_label.text = "Final Score: %d / %d | XP: %d" % [_score, _question_index, _xp]
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		_result_box_show("Game Over", "No lives left. Restart or Go Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _resolve_tutorial_placement_drop(step: int) -> void:
	var ok_green := Color(0.72, 1.0, 0.20, 1.0)
	var bad_red := Color(1.0, 0.26, 0.26, 1.0)
	var is_correct := step == _tutorial_expected_step
	if is_correct:
		_staff_note.modulate = ok_green
		_set_staff_highlight_for_step(step, ok_green)
		if _is_staff_ledger_step(step):
			_show_preview_ledger(step, ok_green)
		await _play_success_sfx()
		await _feed_chicken_at_target(_staff_note)
		await _fly_bird_to_start()
		_tutorial_exercise_done = true
		_tutorial_continue_button.disabled = false
		_set_tutorial_chicken_line("%s Click Continue." % _tutorial_random_line(TUTORIAL_PLACEMENT_SUCCESS_LINES))
		_hide_target_dotted_oval()
		_set_staff_highlight_none()
		_hide_preview_ledger()
		_reset_placement_note_to_side()
	else:
		_staff_note.modulate = bad_red
		_set_staff_highlight_for_step(step, bad_red)
		if _is_staff_ledger_step(step):
			_show_preview_ledger(step, bad_red)
		await _play_fail_sfx()
		var guide_x := _staff_note.position.x + (_staff_note.size.x * 0.5)
		_show_target_dotted_oval(_tutorial_expected_step, ok_green, guide_x)
		_set_staff_highlight_for_step(_tutorial_expected_step, ok_green)
		if _is_staff_ledger_step(_tutorial_expected_step):
			_show_preview_ledger(_tutorial_expected_step, ok_green)
		_set_tutorial_chicken_line("%s Follow the green guide." % _tutorial_random_line(TUTORIAL_PLACEMENT_FAIL_LINES))


func _is_staff_ledger_step(step: int) -> bool:
	return not _ledger_steps_for_note_step(step).is_empty()


func _set_staff_highlight_none() -> void:
	for i in _staff_lines.size():
		_staff_lines[i].color = Color(1.0, 1.0, 1.0, 0.95)


func _ensure_staff_base_lines_visible() -> void:
	for i in _staff_lines.size():
		var line := _staff_lines[i]
		if line == null:
			continue
		line.visible = true
		line.modulate = Color(1.0, 1.0, 1.0, 1.0)
		line.color = Color(1.0, 1.0, 1.0, 0.95)
	for lbl in _staff_line_number_labels:
		if lbl == null:
			continue
		lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _line_index_for_step(step: int) -> int:
	return int(round(float(step) / 2.0))


func _line_indices_for_space_step(step: int) -> Array[int]:
	var lines: Array[int] = []
	if step < STAFF_TOP_LINE_STEP:
		lines.append(0)
	elif step > STAFF_BOTTOM_LINE_STEP:
		lines.append(4)
	else:
		var a := int(floor(float(step) / 2.0))
		var b := int(ceil(float(step) / 2.0))
		if a >= 0 and a <= 4:
			lines.append(a)
		if b >= 0 and b <= 4 and b != a:
			lines.append(b)
	return lines


func _set_staff_highlight_for_step(step: int, color: Color) -> void:
	_set_staff_highlight_none()
	if step % 2 == 0:
		var li := _line_index_for_step(step)
		if li >= 0 and li < _staff_lines.size():
			_staff_lines[li].color = color
	else:
		var lis := _line_indices_for_space_step(step)
		for li in lis:
			if li >= 0 and li < _staff_lines.size():
				_staff_lines[li].color = color


func _ledger_steps_for_note_step(step: int) -> Array[int]:
	var out: Array[int] = []
	if step >= STAFF_BOTTOM_LINE_STEP + 2:
		var top := step if step % 2 == 0 else step + 1
		for s in range(STAFF_BOTTOM_LINE_STEP + 2, top + 1, 2):
			out.append(s)
	elif step <= STAFF_TOP_LINE_STEP - 2:
		var bottom := step if step % 2 == 0 else step - 1
		var s2 := STAFF_TOP_LINE_STEP - 2
		while s2 >= bottom:
			out.append(s2)
			s2 -= 2
	return out


func _show_preview_ledger(step: int, color: Color) -> void:
	if _staff_preview_ledgers.is_empty():
		return
	_hide_preview_ledger()
	var ledger_steps := _ledger_steps_for_note_step(step)
	for i in range(mini(ledger_steps.size(), _staff_preview_ledgers.size())):
		var y := STAFF_TOP_LINE_Y + float(ledger_steps[i]) * STAFF_STEP_Y
		var pl: ColorRect = _staff_preview_ledgers[i]
		pl.color = color
		pl.position = Vector2(_staff_note.position.x - 8.0, y - 1.0)
		pl.visible = true


func _hide_preview_ledger() -> void:
	for pl in _staff_preview_ledgers:
		if pl != null:
			pl.visible = false


func _show_target_dotted_oval(step: int, color: Color, center_x_override: float = -1.0) -> void:
	if _placement_target_dots.is_empty():
		return
	var center_x := STAFF_NOTE_SNAP_X + (_staff_note.size.x * 0.5)
	if center_x_override >= 0.0:
		center_x = center_x_override
	var center_y := STAFF_TOP_LINE_Y + float(step) * STAFF_STEP_Y
	var rx := 16.0
	var ry := 10.0
	for i in range(_placement_target_dots.size()):
		var dot := _placement_target_dots[i]
		var a := TAU * float(i) / float(_placement_target_dots.size())
		var px := center_x + cos(a) * rx
		var py := center_y + sin(a) * ry
		dot.position = Vector2(px - 2.0, py - 2.0)
		dot.modulate = color
		dot.visible = true


func _hide_target_dotted_oval() -> void:
	for dot in _placement_target_dots:
		if dot != null:
			dot.visible = false


func _blink_correct_placement_target(step: int, times: int, total_seconds: float) -> void:
	var ok_green := Color(0.72, 1.0, 0.20, 1.0)
	var half := maxf(0.04, total_seconds / maxf(1.0, float(times) * 2.0))
	for i in range(times):
		_set_staff_highlight_for_step(step, ok_green)
		_show_target_dotted_oval(step, ok_green)
		if _is_staff_ledger_step(step):
			_show_preview_ledger(step, ok_green)
		await get_tree().create_timer(half).timeout
		_set_staff_highlight_none()
		_hide_preview_ledger()
		_hide_target_dotted_oval()
		await get_tree().create_timer(half).timeout


func _generate_sight_chord_round() -> void:
	var triad: Dictionary = {}
	var centers: Array[float] = []
	var found := false
	for attempt in range(40):
		var t: Dictionary = SIGHT_TRIADS[_rng.randi_range(0, SIGHT_TRIADS.size() - 1)]
		var root_t := str(t.get("root", "C"))
		var quality_t := str(t.get("quality", "Major"))
		var inversion_t := _rng.randi_range(0, 2)
		var c := _pick_staff_centers_for_triad(root_t, quality_t, inversion_t)
		if not c.is_empty():
			triad = t
			centers = c
			found = true
			break
	if not found:
		triad = SIGHT_TRIADS[0]
		var b := _effective_sight_step_bounds()
		centers = [STAFF_TOP_LINE_Y + float(b.y) * STAFF_STEP_Y, STAFF_TOP_LINE_Y + float(maxi(b.x, b.y - 2)) * STAFF_STEP_Y, STAFF_TOP_LINE_Y + float(maxi(b.x, b.y - 4)) * STAFF_STEP_Y]

	_current_sight_chord_name = str(triad.get("name", "C Major"))
	_position_sight_chord(centers)

	var all_names: Array[String] = []
	for t in SIGHT_TRIADS:
		all_names.append(str(t["name"]))
	_current_sight_chord_choices = _build_sight_chord_choices(_current_sight_chord_name, all_names)
	for i in _sight_chord_choice_buttons.size():
		if i >= _current_sight_chord_choices.size():
			continue
		_sight_chord_choice_buttons[i].text = _current_sight_chord_choices[i]


func _generate_sight_placement_round() -> void:
	for n in _staff_chord_notes:
		n.visible = false
	_clear_staff_ledger_lines()
	_hide_preview_ledger()
	_set_staff_highlight_none()
	_stop_sight_note_bounce()
	_is_note_dragging = false

	var bounds := _effective_sight_step_bounds()
	var target_step := _rng.randi_range(bounds.x, bounds.y)
	for attempt in range(12):
		target_step = _rng.randi_range(bounds.x, bounds.y)
		var sig := "P:%d:%s" % [target_step, _selected_clef]
		if sig != _last_sight_signature or attempt == 11:
			_last_sight_signature = sig
			break
	_current_sight_target_step = target_step
	_current_sight_note = _sight_step_label(target_step)
	_prompt_label.text = "Place: %s" % _current_sight_note

	_reset_placement_note_to_side()
	_current_sight_hover_step = bounds.y


func _build_sight_chord_choices(correct_name: String, pool: Array[String]) -> Array[String]:
	var distractors: Array[String] = []
	for n in pool:
		if n != correct_name:
			distractors.append(n)
	distractors.shuffle()
	var choices: Array[String] = [correct_name]
	choices.append_array(distractors.slice(0, 2))
	choices.shuffle()
	return choices


func _staff_step_name_for_clef(step_index: int, clef_name: String) -> String:
	var treble_seq := ["F", "E", "D", "C", "B", "A", "G"]
	var bass_seq := ["A", "G", "F", "E", "D", "C", "B"]
	var seq := bass_seq if clef_name == "Bass" else treble_seq
	return str(seq[posmod(step_index, seq.size())])


func _pick_staff_centers_for_triad(root: String, _quality: String, inversion: int) -> Array[float]:
	var bounds := _effective_sight_step_bounds()
	var root_i := NOTE_NAME_ORDER.find(root)
	if root_i < 0:
		root_i = 0
	var third_i := (root_i + 2) % 7
	var fifth_i := (root_i + 4) % 7
	var tones_low_to_high: Array[String] = []
	if inversion == 0:
		tones_low_to_high = [NOTE_NAME_ORDER[root_i], NOTE_NAME_ORDER[third_i], NOTE_NAME_ORDER[fifth_i]]
	elif inversion == 1:
		tones_low_to_high = [NOTE_NAME_ORDER[third_i], NOTE_NAME_ORDER[fifth_i], NOTE_NAME_ORDER[root_i]]
	else:
		tones_low_to_high = [NOTE_NAME_ORDER[fifth_i], NOTE_NAME_ORDER[root_i], NOTE_NAME_ORDER[third_i]]
	var step_triplets: Array[Array] = []
	for s0 in range(-7, 22):
		if _staff_step_name_for_clef(s0, _selected_clef) != tones_low_to_high[0]:
			continue
		for s1 in range(-7, s0):
			if _staff_step_name_for_clef(s1, _selected_clef) != tones_low_to_high[1]:
				continue
			for s2 in range(-7, s1):
				if _staff_step_name_for_clef(s2, _selected_clef) != tones_low_to_high[2]:
					continue
				var gap_top_mid := s0 - s1
				var gap_mid_low := s1 - s2
				# Keep triad voices in compact position (avoid very wide spacing).
				if gap_top_mid < 1 or gap_mid_low < 1:
					continue
				if gap_top_mid > 3 or gap_mid_low > 3:
					continue
				var c0 := STAFF_TOP_LINE_Y + float(s0) * STAFF_STEP_Y
				var c1 := STAFF_TOP_LINE_Y + float(s1) * STAFF_STEP_Y
				var c2 := STAFF_TOP_LINE_Y + float(s2) * STAFF_STEP_Y
				if s0 < bounds.x or s0 > bounds.y:
					continue
				if s1 < bounds.x or s1 > bounds.y:
					continue
				if s2 < bounds.x or s2 > bounds.y:
					continue
				if c0 < 8.0 or c0 > 304.0:
					continue
				if c1 < 8.0 or c1 > 304.0:
					continue
				if c2 < 8.0 or c2 > 304.0:
					continue
				step_triplets.append([s0, s1, s2])

	if step_triplets.is_empty():
		return [112.0, 96.0, 80.0]

	step_triplets.sort_custom(func(a: Array, b: Array) -> bool:
		var da: float = absf(float(a[0]) - 10.0)
		var db: float = absf(float(b[0]) - 10.0)
		return da < db
	)
	var top_bucket: int = mini(3, step_triplets.size()) - 1
	var picked: Array = step_triplets[_rng.randi_range(0, top_bucket)]
	return [
		STAFF_TOP_LINE_Y + float(picked[0]) * STAFF_STEP_Y,
		STAFF_TOP_LINE_Y + float(picked[1]) * STAFF_STEP_Y,
		STAFF_TOP_LINE_Y + float(picked[2]) * STAFF_STEP_Y
	]


func _has_sight_chord_available_in_range() -> bool:
	for triad in SIGHT_TRIADS:
		var root := str(triad.get("root", "C"))
		var quality := str(triad.get("quality", "Major"))
		for inversion in [0, 1, 2]:
			var centers := _pick_staff_centers_for_triad(root, quality, inversion)
			if not centers.is_empty():
				return true
	return false


func _position_sight_chord(note_centers: Array[float]) -> void:
	if _staff_note == null:
		return
	if _staff_clef_label != null:
		_staff_clef_label.text = "𝄢" if _selected_clef == "Bass" else "𝄞"
	if note_centers.size() < 3:
		return

	var x := STAFF_NOTE_SNAP_X
	var first_top := note_centers[0] - (_staff_note.size.y * 0.5)
	_staff_note.visible = true
	_staff_note.scale = _note_scale_for_y(note_centers[0])
	_staff_note.position = Vector2(x, first_top)

	for i in _staff_chord_notes.size():
		var n: Panel = _staff_chord_notes[i]
		var cy := note_centers[i + 1]
		n.visible = true
		n.scale = _note_scale_for_y(cy)
		n.position = Vector2(x, cy - (n.size.y * 0.5))

	_update_staff_ledger_lines_for_notes(note_centers, x + (_staff_note.size.x * 0.5))
	_stop_sight_note_bounce()
	_start_sight_note_bounce()


func _update_staff_ledger_lines_for_notes(note_centers: Array[float], note_center_x: float) -> void:
	_clear_staff_ledger_lines()
	var needed: Array[float] = []
	for note_center_y in note_centers:
		var step := int(round((note_center_y - STAFF_TOP_LINE_Y) / STAFF_STEP_Y))
		var ledger_steps := _ledger_steps_for_note_step(step)
		for s in ledger_steps:
			var y := STAFF_TOP_LINE_Y + float(s) * STAFF_STEP_Y
			if not needed.has(y):
				needed.append(y)
	needed.sort()
	for yv in needed:
		_add_staff_ledger_line(float(yv), note_center_x)


func _pick_sight_note_slot() -> Dictionary:
	var step := _rng.randi_range(_sight_range_min_step, _sight_range_max_step)
	return {
		"name": _staff_step_name_for_clef(step, _selected_clef),
		"center_y": STAFF_TOP_LINE_Y + float(step) * STAFF_STEP_Y
	}


func _clear_staff_ledger_lines() -> void:
	for line in _staff_ledger_lines:
		if is_instance_valid(line):
			line.queue_free()
	_staff_ledger_lines.clear()


func _add_staff_ledger_line(line_y: float, center_x: float) -> void:
	if _staff_area == null:
		return
	var ledger := ColorRect.new()
	ledger.color = Color(1.0, 1.0, 1.0, 0.95)
	ledger.size = Vector2(36, 2)
	ledger.position = Vector2(center_x - 18.0, line_y - 1.0)
	_staff_area.add_child(ledger)
	_staff_area.move_child(ledger, _staff_area.get_child_count() - 2)
	_staff_ledger_lines.append(ledger)


func _update_staff_ledger_lines(note_center_y: float, note_center_x: float) -> void:
	_update_staff_ledger_lines_for_notes([note_center_y], note_center_x)


func _position_sight_note(note_name: String, center_y_override: float = NAN) -> void:
	if _staff_note == null:
		return
	for n in _staff_chord_notes:
		n.visible = false
	var center_y := center_y_override
	if _selected_clef == "Bass":
		if _staff_clef_label != null:
			_staff_clef_label.text = "𝄢"
		if is_nan(center_y):
			var bass_center_map := {"C": 160.0, "D": 144.0, "E": 128.0, "F": 112.0, "G": 96.0, "A": 80.0, "B": 64.0}
			center_y = float(bass_center_map.get(note_name, 160.0))
	else:
		if _staff_clef_label != null:
			_staff_clef_label.text = "𝄞"
		if is_nan(center_y):
			var treble_center_map := {"C": 112.0, "D": 96.0, "E": 80.0, "F": 64.0, "G": 48.0, "A": 32.0, "B": 16.0}
			center_y = float(treble_center_map.get(note_name, 112.0))
		# Nudge treble notes slightly lower to align with staff lines.
		center_y += 2.0
	var top_left_y := center_y - (_staff_note.size.y * 0.5)
	_staff_note.scale = _note_scale_for_y(center_y)
	_staff_note.position = Vector2(STAFF_NOTE_SNAP_X, top_left_y)
	var center_x := _staff_note.position.x + (_staff_note.size.x * 0.5)
	_update_staff_ledger_lines(center_y, center_x)
	_start_sight_note_bounce()


func _note_scale_for_y(center_y: float) -> Vector2:
	var t := clampf((center_y - (STAFF_TOP_LINE_Y - 64.0)) / 256.0, 0.0, 1.0)
	var s := lerpf(1.0, 1.22, t)
	return Vector2(s, s)


func _start_sight_note_bounce() -> void:
	if _staff_note == null:
		return
	_stop_sight_note_bounce()
	var y0 := _staff_note.position.y
	_sight_note_bounce_tween = create_tween()
	_sight_note_bounce_tween.set_loops()
	_sight_note_bounce_tween.tween_property(_staff_note, "position:y", y0 - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sight_note_bounce_tween.tween_property(_staff_note, "position:y", y0 + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_sight_note_bounce() -> void:
	if _sight_note_bounce_tween != null:
		_sight_note_bounce_tween.kill()
		_sight_note_bounce_tween = null


func _blink_button(btn: Button, color: Color, times: int) -> void:
	var original := btn.modulate
	for i in times:
		btn.modulate = color
		await get_tree().create_timer(0.11).timeout
		btn.modulate = original
		await get_tree().create_timer(0.09).timeout


func _blink_answer_feedback(wrong_btn: Button, correct_btn: Button, times: int) -> void:
	var red := Color(1.0, 0.35, 0.35, 1.0)
	var green := Color(0.35, 1.0, 0.45, 1.0)
	var wrong_original := Color(1, 1, 1, 1)
	var correct_original := Color(1, 1, 1, 1)
	if wrong_btn != null:
		wrong_original = wrong_btn.modulate
	if correct_btn != null:
		correct_original = correct_btn.modulate

	for i in times:
		if wrong_btn != null:
			wrong_btn.modulate = red
		if correct_btn != null:
			correct_btn.modulate = green
		await get_tree().create_timer(0.11).timeout
		if wrong_btn != null:
			wrong_btn.modulate = wrong_original
		if correct_btn != null:
			correct_btn.modulate = correct_original
		await get_tree().create_timer(0.09).timeout


func _create_sight_mark(btn: Button, text: String, color: Color) -> Label:
	if btn == null:
		return null
	var mark := Label.new()
	mark.text = text
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.custom_minimum_size = Vector2(40, 30)
	mark.size = Vector2(40, 30)
	mark.modulate = Color(1, 1, 1, 1)
	mark.add_theme_font_size_override("font_size", 28)
	mark.add_theme_color_override("font_color", color)
	mark.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	mark.add_theme_constant_override("outline_size", 4)
	if _ui_font != null:
		mark.add_theme_font_override("font", _ui_font)
	mark.z_as_relative = false
	mark.z_index = 110
	add_child(mark)
	var center := btn.global_position + (btn.size * 0.5)
	var local_pos := center - global_position
	mark.position = local_pos + Vector2(-20, -btn.size.y * 1.02)
	return mark


func _blink_sight_feedback(wrong_btn: Button, correct_btn: Button, times: int) -> void:
	var red := Color(1.0, 0.35, 0.35, 1.0)
	var green := Color(0.35, 1.0, 0.45, 1.0)
	var wrong_original := Color(1, 1, 1, 1)
	var correct_original := Color(1, 1, 1, 1)
	if wrong_btn != null:
		wrong_original = wrong_btn.modulate
	if correct_btn != null:
		correct_original = correct_btn.modulate

	var wrong_mark: Label = null
	var correct_mark: Label = null
	if wrong_btn != null:
		wrong_mark = _create_sight_mark(wrong_btn, "X", red)
	if correct_btn != null:
		correct_mark = _create_sight_mark(correct_btn, "✓", green)

	for i in times:
		if wrong_btn != null:
			wrong_btn.modulate = red
		if correct_btn != null:
			correct_btn.modulate = green
		await get_tree().create_timer(0.11).timeout
		if wrong_btn != null:
			wrong_btn.modulate = wrong_original
		if correct_btn != null:
			correct_btn.modulate = correct_original
		await get_tree().create_timer(0.09).timeout

	if is_instance_valid(wrong_mark):
		wrong_mark.queue_free()
	if is_instance_valid(correct_mark):
		correct_mark.queue_free()


func _style_key_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.96, 0.96, 0.97, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_color = Color(0.58, 0.58, 0.62, 0.95)
	normal.border_width_left = 2
	normal.border_width_top = 4
	normal.border_width_right = 2
	normal.border_width_bottom = 5
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.98, 0.98, 1.0, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.84, 0.88, 0.95, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)


func _get_button_for_interval(interval_id: String) -> Button:
	if _interval_option_map.has(interval_id):
		return _interval_option_map[interval_id]
	return null


func _reset_bird_position() -> void:
	if _bird_sprite == null:
		return
	if not _bird_home_ready:
		_bird_home_global_position = global_position + Vector2(40, 185)
		_bird_home_ready = true
	_bird_sprite.global_position = _bird_home_global_position
	_bird_sprite.rotation_degrees = 0.0
	_bird_sprite.size = Vector2(180, 96)
	_bird_sprite.modulate = BIRD_TINT
	_bird_sprite.pivot_offset = _bird_sprite.size * 0.5
	_hide_food_token()


func _show_food_at_target(target_button: Control) -> void:
	if _food_token == null or target_button == null:
		return
	_food_token.scale = Vector2.ONE
	_food_token.modulate = Color(1, 1, 1, 1)
	var center := target_button.global_position + (target_button.size * 0.5)
	_food_token.global_position = center + Vector2(-_food_token.size.x * 0.5, -_food_token.size.y * 0.5)
	_food_token.visible = true


func _hide_food_token() -> void:
	if _food_token != null:
		_food_token.visible = false


func _feed_chicken_at_target(target_button: Control) -> void:
	if _bird_sprite == null or target_button == null:
		return
	_show_food_at_target(target_button)
	await _fly_bird_to_nest(target_button)
	if _food_token != null and _food_token.visible:
		var food_tween := create_tween()
		food_tween.set_trans(Tween.TRANS_SINE)
		food_tween.set_ease(Tween.EASE_IN)
		food_tween.tween_property(_food_token, "scale", Vector2(0.22, 0.22), 0.16)
		food_tween.parallel().tween_property(_food_token, "modulate:a", 0.0, 0.16)
		var peck := create_tween()
		peck.set_trans(Tween.TRANS_SINE)
		peck.set_ease(Tween.EASE_IN_OUT)
		peck.tween_property(_bird_sprite, "rotation_degrees", -9.0, 0.08)
		peck.tween_property(_bird_sprite, "rotation_degrees", 0.0, 0.08)
		await food_tween.finished
		_food_token.modulate = Color(1, 1, 1, 1)
	_hide_food_token()


func _play_hungry_reaction() -> void:
	if _bird_sprite == null:
		return
	_hide_food_token()
	_stop_bird_idle_anim()
	_stop_bird_flap_anim()
	var base_pos := _bird_sprite.global_position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bird_sprite, "global_position:y", base_pos.y + 8.0, 0.14)
	tween.parallel().tween_property(_bird_sprite, "rotation_degrees", 10.0, 0.14)
	tween.tween_property(_bird_sprite, "global_position:y", base_pos.y, 0.16)
	tween.parallel().tween_property(_bird_sprite, "rotation_degrees", 0.0, 0.16)
	await tween.finished
	_start_bird_idle_anim()


func _fly_bird_to_nest(target_button: Control) -> void:
	if _bird_sprite == null:
		return
	_stop_bird_idle_anim()
	_start_bird_flap_anim()
	var target_pos := target_button.global_position + (target_button.size * 0.5) - (_bird_sprite.size * 0.5)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_bird_sprite, "global_position", target_pos, 0.6)
	await tween.finished
	_stop_bird_flap_anim()
	_start_bird_idle_anim()


func _fly_bird_to_start() -> void:
	if _bird_sprite == null or not _bird_home_ready:
		return
	_stop_bird_idle_anim()
	_start_bird_flap_anim()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bird_sprite, "global_position", _bird_home_global_position, 0.55)
	await tween.finished
	_stop_bird_flap_anim()
	_start_bird_idle_anim()


func _fly_bird_away_sad() -> void:
	if _bird_sprite == null:
		return
	_hide_food_token()
	_stop_bird_idle_anim()
	_stop_bird_flap_anim()
	_bird_sprite.modulate = Color(0.75, 0.78, 0.9, 0.95)
	var target := _bird_sprite.global_position + Vector2(-260, -120)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_bird_sprite, "rotation_degrees", -25.0, 0.8)
	tween.parallel().tween_property(_bird_sprite, "global_position", target, 0.8)
	await tween.finished


func _play_completion_reaction(score_pct: float) -> void:
	if _bird_sprite == null:
		return
	_stop_bird_idle_anim()
	_stop_bird_flap_anim()
	if score_pct >= 99.999:
		_play_reaction_roll()
		_speak_phrase("Bawk wow!")
	elif score_pct >= 70.0:
		_play_reaction_jump()
		_speak_phrase("Bawk good job!")
	else:
		_play_reaction_walk()
		_speak_phrase("Bawk hmmm...")


func _play_reaction_roll() -> void:
	var y0 := _bird_sprite.position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bird_sprite, "rotation_degrees", 360.0, 0.85)
	tween.parallel().tween_property(_bird_sprite, "position:y", y0 - 28.0, 0.4)
	tween.tween_property(_bird_sprite, "position:y", y0, 0.45)
	tween.finished.connect(func() -> void:
		if _bird_sprite != null:
			_bird_sprite.rotation_degrees = 0.0
		_start_bird_idle_anim()
	)


func _play_reaction_jump() -> void:
	var y0 := _bird_sprite.position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bird_sprite, "position:y", y0 - 34.0, 0.23)
	tween.tween_property(_bird_sprite, "position:y", y0, 0.28)
	tween.finished.connect(func() -> void:
		_start_bird_idle_anim()
	)


func _play_reaction_walk() -> void:
	var x0 := _bird_sprite.global_position.x
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bird_sprite, "global_position:x", x0 - 70.0, 0.35)
	tween.tween_property(_bird_sprite, "global_position:x", x0 + 70.0, 0.35)
	tween.tween_property(_bird_sprite, "global_position:x", x0, 0.35)
	tween.finished.connect(func() -> void:
		_start_bird_idle_anim()
	)


func _speak_phrase(text: String) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var voice_id := ""
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if not voices.is_empty():
			voice_id = str(voices[0])
		# Slightly faster and higher pitch for a playful "chicken-like" voice.
		DisplayServer.tts_speak(text, voice_id, 92, 1.35, 1.15, 0, true)
	else:
		_play_success_sfx()


func _start_bird_idle_anim() -> void:
	if _bird_sprite == null:
		return
	_stop_bird_idle_anim()
	_bird_idle_tween = create_tween()
	_bird_idle_tween.set_loops()
	_bird_idle_tween.tween_property(_bird_sprite, "position:y", _bird_sprite.position.y - 6.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bird_idle_tween.parallel().tween_property(_bird_sprite, "rotation_degrees", -2.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bird_idle_tween.tween_property(_bird_sprite, "position:y", _bird_sprite.position.y + 6.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bird_idle_tween.parallel().tween_property(_bird_sprite, "rotation_degrees", 2.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_bird_idle_anim() -> void:
	if _bird_idle_tween != null:
		_bird_idle_tween.kill()
		_bird_idle_tween = null


func _start_bird_flap_anim() -> void:
	if _bird_sprite == null:
		return
	_stop_bird_flap_anim()
	_bird_flap_tween = create_tween()
	_bird_flap_tween.set_loops()
	_bird_flap_tween.tween_property(_bird_sprite, "scale:y", 0.86, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bird_flap_tween.parallel().tween_property(_bird_sprite, "rotation_degrees", -8.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bird_flap_tween.tween_property(_bird_sprite, "scale:y", 1.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bird_flap_tween.parallel().tween_property(_bird_sprite, "rotation_degrees", 5.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_bird_flap_anim() -> void:
	if _bird_flap_tween != null:
		_bird_flap_tween.kill()
		_bird_flap_tween = null
	if _bird_sprite != null:
		_bird_sprite.scale = Vector2.ONE
		_bird_sprite.rotation_degrees = 0.0


func _midi_to_freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


func _load_piano_samples() -> void:
	_piano_samples.clear()
	for midi_key in PIANO_SAMPLE_PATHS.keys():
		var sample_path: String = PIANO_SAMPLE_PATHS[midi_key]
		if not ResourceLoader.exists(sample_path, "AudioStream"):
			continue
		var stream := ResourceLoader.load(sample_path)
		if stream is AudioStream:
			_piano_samples[midi_key] = stream


func _play_note(midi_note: int, duration: float) -> void:
	if _piano_samples.is_empty():
		await _push_sine(_midi_to_freq(midi_note), duration)
		return

	var nearest: int = _nearest_sample_midi(midi_note)
	var stream: AudioStream = _piano_samples[nearest]
	_piano_player.stop()
	_piano_player.stream = stream
	_piano_player.pitch_scale = pow(2.0, float(midi_note - nearest) / 12.0)
	_piano_player.play()
	await get_tree().create_timer(duration).timeout
	_piano_player.stop()


func _nearest_sample_midi(target_midi: int) -> int:
	var keys: Array = _piano_samples.keys()
	var best: int = int(keys[0])
	var best_dist: int = int(abs(target_midi - best))
	for k in keys:
		var midi: int = int(k)
		var d: int = int(abs(target_midi - midi))
		if d < best_dist:
			best = midi
			best_dist = d
	return best


func _play_success_sfx() -> void:
	if _success_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _success_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.33).timeout
		return
	await _push_sine(1046.5, 0.08)
	await _push_silence(0.03)
	await _push_sine(1318.5, 0.11)


func _play_new_question_cue() -> void:
	if _sfx_player != null:
		await _push_sine(880.0, 0.05)
		await _push_silence(0.015)
		await _push_sine(988.0, 0.06)
		return
	await _push_sine(880.0, 0.05)
	await _push_silence(0.015)
	await _push_sine(988.0, 0.06)


func _play_fail_sfx() -> void:
	if _fail_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _fail_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.34).timeout
		return
	await _push_sine(392.0, 0.09)
	await _push_silence(0.03)
	await _push_sine(293.7, 0.12)


func _push_sine(freq: float, duration: float) -> void:
	var sample_rate := _audio_stream.mix_rate
	var total_frames := int(duration * sample_rate)
	var phase := 0.0
	var increment := TAU * freq / sample_rate
	var remaining := total_frames

	while remaining > 0:
		var available := _playback.get_frames_available()
		if available <= 0:
			await get_tree().process_frame
			continue

		var frames_to_write := mini(remaining, available)
		for i in frames_to_write:
			var sample := sin(phase) * 0.23
			_playback.push_frame(Vector2(sample, sample))
			phase += increment
		remaining -= frames_to_write


func _push_silence(duration: float) -> void:
	var sample_rate := _audio_stream.mix_rate
	var total_frames := int(duration * sample_rate)
	var remaining := total_frames

	while remaining > 0:
		var available := _playback.get_frames_available()
		if available <= 0:
			await get_tree().process_frame
			continue

		var frames_to_write := mini(remaining, available)
		for i in frames_to_write:
			_playback.push_frame(Vector2.ZERO)
		remaining -= frames_to_write


func _ordinal(n: int) -> String:
	match n:
		2:
			return "2nd"
		3:
			return "3rd"
		_:
			return "%dth" % n
