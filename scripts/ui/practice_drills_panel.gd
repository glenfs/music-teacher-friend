class_name PracticeDrillsPanel
extends PanelContainer

# Self-contained Practice Drills modal — full-screen panel with exercise
# generator, on-screen piano, score view, playback, and PDF/image export.
# Owns all its widgets + current-exercise state internally.


signal closed                                        # ← Home pressed
signal presented                                     # panel shown


# --- Constants ---
const BULLSEYE_ICON_PATH := "res://assets/icons/bullseye.svg"
const PICK_EXERCISE_ICON_PATH := "res://assets/icons/bullseye-arrow-v2.svg"
const STAFF_WRAP_HEIGHT := 306.0 # 15% lower than the previous 360px score card.
const STAFF_RENDER_HEIGHT := 293.0 # 15% lower than the previous 345px renderer.
const KEYBOARD_LOW := 21   # A0
const KEYBOARD_HIGH := 108 # C8
const WHITE_W := 26.0
const WHITE_H := 132.0
const BLACK_W := 17.0
const BLACK_H := 82.0
const EXPORT_PRINT := 1
const EXPORT_SAVE_PDF := 2
const EXPORT_SAVE_IMAGE := 3
const EXPORT_SAVE_EXERCISE := 4
const EXPORT_LOAD_EXERCISE := 5
const EXPORT_LESSON_SUMMARY := 6
const EXPORT_ANALYTICS := 7
const SAVED_EXERCISES_DIR := "user://saved_exercises"
const CUSTOM_PRESETS_PATH := "user://practice_drills_custom_presets.json"
const DRILL_HISTORY_PATH := "user://practice_drills_history.json"
const DRILL_HISTORY_MAX_ENTRIES := 200
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

# Preset drill tracks — bundles of (skill focus, level) that act as
# pre-shaped paths the student / teacher can pick from instead of dialing
# every option manually. Type selection follows the skill filter so the
# Type dropdown auto-rebuilds when the preset switches.
const DRILL_PRESETS := [
	{"label": "- Preset -",            "skill": "",              "level": -1},
	{"label": "Beginner - Evenness",   "skill": "evenness",      "level": 1},
	{"label": "Chord Voicings",        "skill": "chord_voicing", "level": 3},
	{"label": "Hand Independence",     "skill": "independence",  "level": 3},
	{"label": "Sight-Read Prep",       "skill": "reading",       "level": 2},
	{"label": "Velocity / Speed",      "skill": "velocity",      "level": 5},
	{"label": "Exam Prep - Technical", "skill": "all",           "level": 6},
]

const MENU_TITLE_TEXT := Color(0.9176, 0.9529, 1.0, 1.0)
const MENU_PRIMARY_ACCENT := Color(0.9098, 0.6275, 0.1255, 1.0)


# --- Module preloads ---
const StaffRendererScript = preload("res://scripts/score_engine/staff_renderer.gd")
const ScoreModelScript = preload("res://scripts/score_engine/score_model.gd")
const TechnicalExerciseGeneratorScript = preload("res://scripts/exercises/technical_exercise_generator.gd")
const ExerciseLibraryScript = preload("res://scripts/exercises/exercise_library.gd")
const NotationRulesScript = preload("res://scripts/exercises/notation_rules.gd")
const CurriculumScript = preload("res://scripts/exercises/curriculum.gd")
const ChordExplorerTheoryScript = preload("res://scripts/music_theory/chord_explorer_theory.gd")
const PianoKeyStylesScript = preload("res://scripts/ui/piano_key_styles.gd")
const MicListenerScript = preload("res://scripts/audio/mic_listener.gd")
const MusicXMLImporterScript = preload("res://scripts/exercises/musicxml_importer.gd")


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
var _nav_home_style_callable: Callable = Callable()       # (btn:Button) -> void — applies sight-reader nav-home skin
# QA audio probe — pushes (midi, dur) to the host's _qa_audio_probe so
# the orchestrator's assert_audio asserts see Practice Drills playback.
# Empty by default; the host wires it via setup() when --qa or
# --debug-server is active. _spawn_note calls it on every play.
var _qa_audio_probe_callable: Callable = Callable()       # (midi:int, dur:float) -> void
# Feat 4 — Teacher assignment lookup. (exercise_id:String) -> Dictionary.
# Returns {} when no open assignment matches. Wired via setup() to
# teacher_store.get_open_practice_drill_assignment_for; left empty in
# the student-only build (no teacher data file present).
var _open_assignment_lookup_callable: Callable = Callable()


# --- State ---
var _current_exercise: Dictionary = {}
var _current_skill_filter: String = "all"
var _current_seed: int = -1
var _playback_active: bool = false
var _playback_token: int = 0
var _playback_index: int = 0
var _note_players: Array[AudioStreamPlayer] = []
var _metronome_enabled: bool = false
var _count_in_enabled: bool = false
# Feat 15 — when true, the StaffRenderer skips drawing fingering digits.
# Persists in user://practice_drills_ui.json via _save/_load_ui_state.
var _hide_fingerings_enabled: bool = false
# Cached "active state" stylebox so we don't reallocate every refresh.
var _staff_wrap_style_active: StyleBoxFlat = null
var _staff_wrap_style_idle: StyleBoxFlat = null
var _chip_target_style_active: StyleBoxFlat = null
var _chip_target_style_idle: StyleBoxFlat = null
# Set by _on_daily_warmup_pressed so the next _on_generate_pressed knows to
# append a tonic resolution to the generated exercise. Cleared after use.
var _daily_warmup_flag_for_next_generate: bool = false
# True when the current _current_exercise was generated from Daily Drill (vs
# manual Generate). Drives the daily progress counter — only daily plays
# count toward "today's drills" so the metric isn't gamed by arbitrary
# Generate spam.
var _current_exercise_is_daily: bool = false
# Daily progress persistence — { date: ISO-yyyy-mm-dd, completed: N,
# target: N }. Loaded on present(); auto-resets when the date rolls over.
var _daily_progress: Dictionary = {}
const DAILY_PROGRESS_PATH := "user://practice_drills_progress.json"
const UI_STATE_PATH := "user://practice_drills_ui.json"
const DEFAULT_DAILY_TARGET := 3
# Pre-rolled "what's next" Daily Drill — cached so the hero subtitle can
# preview the upcoming pick AND so pressing Start Daily Drill commits the
# exact previewed exercise. Cleared after consumption so the next preview
# re-rolls.
var _next_daily_pick: Dictionary = {}
# Post-play summary captures so the summary panel can show
# duration/tempo/notes after the playback finish event fires.
var _last_play_start_usec: int = 0
var _last_play_finished_summary: Dictionary = {}
# MIDI grading state — captured during play, scored at finish.
# Each capture: { usec, midi, beat }.
var _midi_captures: Array = []
var _midi_grading_active: bool = false
var _midi_inputs_opened_locally: bool = false
# Per-note judgements from last play. midi → "hit" / "missed".
# Drives the inline-feedback keyboard coloring.
var _last_judgements: Dictionary = {}
# Last play's accuracy (0..1, -1 == no grading happened — e.g., no MIDI
# device or all notes were misses with no input at all).
var _last_accuracy: float = -1.0
# Accuracy gate (UI item 14): block speed/level bumps when last accuracy
# was below threshold. Toggleable via the bottom-row check.
var _speed_gate_enabled: bool = false
const SPEED_GATE_MIN_ACCURACY: float = 0.85
# Precision playback uses an absolute-time event queue drained by _process().
# Each entry: { "at_usec": int, "kind": String, "data": Dictionary, "token": int }.
# Sorted ascending by at_usec at enqueue time.
var _playback_queue: Array[Dictionary] = []
var _playback_sample_map: Dictionary = {}


# --- Widget references ---
var _type_option: OptionButton = null
var _skill_option: OptionButton = null
var _key_option: OptionButton = null
var _minor_check: CheckButton = null
var _metronome_check: CheckButton = null
var _octaves_spin: SpinBox = null
var _level_spin: SpinBox = null
var _staff_option: OptionButton = null
var _tempo_label: Label = null
var _title_label: Label = null
var _status_label: Label = null

# Mic listening — optional input. While on, the host's PitchDetector feeds
# detected single notes back into the panel: the matching keyboard key is
# briefly lit and the status label echoes the heard pitch. Single-note only.
var _mic_listener: RefCounted = null   # MicListener
var _mic_button: Button = null
var _mic_status_label: Label = null
var _mic_last_pitch: int = -1
var _mic_last_pitch_clear_at_msec: int = 0
const _MIC_HIGHLIGHT_HOLD_MSEC := 800
const _MIC_HIGHLIGHT_COLOR := Color(0.40, 0.88, 1.00, 1.0)

# Play Along grading — when on, the playback engine still moves the cursor
# and ticks the metronome but DOESN'T sound the model notes. The student
# plays them on a MIDI keyboard; each event opens a ±PLAY_ALONG_WINDOW_USEC
# grading window. Hits are tinted on the staff and aggregated into a per-bar
# summary on session end.
var _play_along_button: Button = null
var _play_along_enabled: bool = false
var _play_along_active: bool = false
# Per-event grading state. Each entry mirrors a queue note event plus a
# `status`: "pending" / "hit" / "wrong" / "missed".
var _play_along_events: Array = []
# Index into _play_along_events for the next expected note. A MIDI press
# checks this slot first; if pitch matches, we mark hit and advance.
var _play_along_cursor: int = 0
# Bar-keyed totals for the end-of-session summary.
var _play_along_bar_totals: Dictionary = {}  # bar_idx -> {hit, total}
const PLAY_ALONG_WINDOW_USEC := 250_000  # ±250 ms timing tolerance
const PLAY_ALONG_HIT_COLOR := Color(0.32, 0.92, 0.46, 1.0)
const PLAY_ALONG_WRONG_COLOR := Color(0.98, 0.34, 0.34, 1.0)
const PLAY_ALONG_MISS_COLOR := Color(0.65, 0.65, 0.70, 1.0)
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
# UI-upgrade widgets (see docs/prompts/exercie_ui_upgrade.txt):
# Hero action card at the top — the primary surface for Daily Drill.
var _daily_drill_hero_button: Button = null
var _daily_drill_subtitle: Label = null
# Day-goal chip row directly beneath the hero — Target + Tempo + Streak.
var _chip_target_label: Label = null
var _chip_target_wrap: PanelContainer = null        # bullseye-icon wrapper
var _chip_tempo_label: Label = null
var _chip_streak_label: Label = null
var _chip_session_streak_label: Label = null
var _chip_session_streak_wrap: PanelContainer = null  # bullseye-icon wrapper
var _chip_assignment_label: Label = null
# Info popover showing diagnostic detail (seed, generator id, notes count).
var _info_button: Button = null
var _info_dialog: AcceptDialog = null
# Lazy-instantiated load-exercise dialog (lists saved exercises).
var _load_exercise_dialog: AcceptDialog = null
# Feat 5 — Performance analytics dialog. Built lazily on first request.
var _analytics_dialog: AcceptDialog = null
# Drill history dialog (Feat v2 item 20).
var _history_dialog: AcceptDialog = null
# Save-preset dialog (Feat v2 item 17).
var _save_preset_dialog: AcceptDialog = null
var _save_preset_name_edit: LineEdit = null
# Custom presets loaded from disk on demand, kept in memory for re-population.
var _custom_presets: Array = []
# Daily progress widgets — thin bar + count label tucked under the hero CTA.
var _daily_progress_bar: ProgressBar = null
var _daily_progress_label: Label = null
# Compact post-play summary card (item 8): shown when a play completes,
# auto-hidden when the user generates a new drill or starts the next.
var _post_play_summary_panel: PanelContainer = null
var _post_play_summary_label: Label = null
var _post_play_replay_button: Button = null
var _post_play_next_button: Button = null
var _post_play_weak_spot_button: Button = null
var _post_play_replay_take_button: Button = null
var _post_play_loop_bar_button: Button = null
# Feat 12 — saved MIDI captures from the last play, used by
# Replay-your-take. Snapshot taken in _on_play_finished so the user can
# rehear what they played even after stop_playback clears the live buffer.
var _last_play_captures: Array = []
# Feat 8 — Loop & retry. When >= 0, _on_play_pressed filters events to
# those starting at/after this beat, and shifts the timeline so they
# play from t=0. One-shot — cleared at the top of _on_play_pressed after
# being consumed, so a normal Play press following a Loop Last Bar
# returns to full-exercise playback.
var _playback_filter_from_beat: float = -1.0
# Feat 18 — Session streak goal. Counts consecutive plays with
# accuracy ≥ SESSION_STREAK_MIN_ACCURACY (a "clean take"). Resets to 0
# on any play below threshold or on Generate/Reroll. Goal = N clean
# takes in a row; celebrated via toast when hit. Session-scoped — not
# persisted across runs.
var _session_clean_streak: int = 0
const SESSION_STREAK_GOAL: int = 3
const SESSION_STREAK_MIN_ACCURACY: float = 0.9
# v2 widgets (see docs/prompts/exercie_ui_upgrade_v2.txt).
var _preset_option: OptionButton = null
var _reroll_button: Button = null
var _count_in_check: CheckButton = null
var _speed_gate_check: CheckButton = null
var _hide_fingerings_check: CheckButton = null
# Suppresses the gate check during programmatic level changes (Drill-misses
# button steps down by 1, presets jump levels). Without this guard the gate
# would block our own logic.
var _suppress_level_gate: bool = false
# Tracked so the gate can snap back to it when the user tries to climb
# before earning the bump.
var _prev_level_value: float = 1.0
var _contextual_hint_label: Label = null
var _empty_state_label: Label = null
var _staff_wrap_panel: PanelContainer = null


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
	weakest_skill_family_fn: Callable,
	nav_home_style: Callable = Callable(),
	qa_audio_probe: Callable = Callable(),
	open_assignment_lookup: Callable = Callable()
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
	_nav_home_style_callable = nav_home_style
	_qa_audio_probe_callable = qa_audio_probe
	_open_assignment_lookup_callable = open_assignment_lookup
	_force_fullscreen_rect()
	visible = false
	z_as_relative = false
	z_index = 200
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	add_theme_stylebox_override("panel", bg_style)
	_build_ui()
	resized.connect(_apply_responsive_layout)


# Wire mic-listening callables. Optional — if not called, the mic toggle stays
# hidden. Parent passes start/stop/poll callables that drive its shared
# PitchDetector.
func setup_mic(start_cb: Callable, stop_cb: Callable, poll_cb: Callable) -> void:
	if not start_cb.is_valid() or not stop_cb.is_valid() or not poll_cb.is_valid():
		return
	if _mic_listener == null:
		_mic_listener = MicListenerScript.new()
		_mic_listener.note_detected.connect(_on_mic_note_detected)
		_mic_listener.status_changed.connect(_on_mic_status_changed)
	_mic_listener.setup(start_cb, stop_cb, poll_cb)
	if _mic_button != null:
		_mic_button.visible = true


func present() -> void:
	_force_fullscreen_rect()
	visible = true
	move_to_front()
	if _status_label != null:
		_status_label.text = ""
	_load_daily_progress_if_needed()
	_load_ui_state()
	_load_and_apply_custom_presets()
	_refresh_daily_progress_ui()
	_refresh_daily_preview()
	_refresh_day_chips()
	_refresh_contextual_hint()
	_refresh_active_state()
	_refresh_empty_state()
	_refresh_score_renderer()
	_apply_responsive_layout()
	presented.emit()


func dismiss() -> void:
	if _mic_listener != null and _mic_listener.is_listening():
		_mic_listener.stop()
	if _mic_button != null:
		_mic_button.set_pressed_no_signal(false)
		_mic_button.text = "%s  Mic" % char(0x1F3A4)
	if _mic_status_label != null:
		_mic_status_label.visible = false
	stop_playback(true)
	visible = false


func stop_playback(reset_cursor: bool = true) -> void:
	_playback_active = false
	_playback_token += 1
	_playback_index = -1
	_playback_queue.clear()
	# Keep _process running if the mic listener still needs ticks.
	var keep_process: bool = _mic_listener != null and _mic_listener.is_listening()
	set_process(keep_process)
	_stop_note_audio()
	_keyboard_clear_highlight()
	_mic_last_pitch = -1
	if reset_cursor:
		_clear_staff_highlight()


func _force_fullscreen_rect() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


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
	if _ui_font != null:
		ctrl.add_theme_font_override("font", _ui_font)
	elif _ui_title_font != null:
		ctrl.add_theme_font_override("font", _ui_title_font)
	ctrl.add_theme_font_size_override("font_size", 11)
	ctrl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.98))
	ctrl.add_theme_color_override("font_hover_color", Color(0.96, 0.98, 1.0, 0.98))
	ctrl.add_theme_color_override("font_pressed_color", Color(0.96, 0.98, 1.0, 0.98))
	ctrl.add_theme_color_override("font_focus_color", Color(0.96, 0.98, 1.0, 0.98))
	var normal := _stylebox(Color(0.05, 0.11, 0.20, 0.94), Color(0.95, 0.75, 0.30, 0.92), 6, 1, 2)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate()
	(hover as StyleBoxFlat).bg_color = Color(0.08, 0.16, 0.28, 0.98)
	(hover as StyleBoxFlat).border_color = Color(1.0, 0.83, 0.42, 0.98)
	var pressed := normal.duplicate()
	(pressed as StyleBoxFlat).bg_color = Color(0.03, 0.08, 0.16, 0.98)
	var focus := normal.duplicate()
	(focus as StyleBoxFlat).border_width_left = 2
	(focus as StyleBoxFlat).border_width_right = 2
	(focus as StyleBoxFlat).border_width_top = 2
	(focus as StyleBoxFlat).border_width_bottom = 2
	ctrl.add_theme_stylebox_override("normal", normal)
	ctrl.add_theme_stylebox_override("hover", hover)
	ctrl.add_theme_stylebox_override("pressed", pressed)
	ctrl.add_theme_stylebox_override("focus", focus)
	if ctrl is OptionButton:
		call_deferred("_style_option_popup_menu", ctrl)


func _style_option_popup_menu(opt_ctrl: Control) -> void:
	var opt := opt_ctrl as OptionButton
	if opt == null:
		return
	var popup := opt.get_popup()
	if popup == null:
		return
	_style_popup_menu(popup)


func _style_popup_menu(popup: PopupMenu) -> void:
	var panel := _stylebox(Color(0.03, 0.08, 0.15, 0.98), Color(0.95, 0.75, 0.30, 0.86), 8, 1, 4)
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.98))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.80, 1.0))
	popup.add_theme_color_override("font_selected_color", Color(1.0, 0.96, 0.80, 1.0))
	var hover := _stylebox(Color(0.10, 0.21, 0.36, 0.98), Color(1.0, 0.84, 0.44, 0.88), 4, 1, 0)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_stylebox_override("highlight", hover)
	var selected := _stylebox(Color(0.14, 0.27, 0.42, 0.98), Color(1.0, 0.84, 0.44, 0.92), 4, 1, 0)
	popup.add_theme_stylebox_override("selected", selected)
	popup.add_theme_stylebox_override("pressed", selected)


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 10)
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
	# Layout overhaul per docs/prompts/exercie_ui_upgrade.txt:
	# Hero Daily Drill action at the top, compact chip row beneath it,
	# all generation controls collapsed into one wrap row, tighter card
	# spacing, and an Info popover for diagnostic detail (seed/generator).
	# Adaptive vertical scroll: on short viewports (laptops, small windows)
	# the bottom action row would otherwise get clipped. Wrapping the whole
	# layout in a ScrollContainer lets the user scroll down to reach Play/
	# Stop/Info/etc. The horizontal scroll inside the staff card still
	# works because the inner ScrollContainer captures wheel events when
	# the mouse is over the staff.
	var root_scroll := ScrollContainer.new()
	root_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_scroll.follow_focus = true
	add_child(root_scroll)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_top", 4)
	root_margin.add_theme_constant_override("margin_bottom", 8)
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_scroll.add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 5)
	root_margin.add_child(root_vbox)

	# === Top bar: home + heading ===
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	root_vbox.add_child(top_bar)
	_back_button = Button.new()
	_back_button.tooltip_text = "Back to home"
	_back_button.set_meta("hud_nav_btn", true)
	_back_button.pressed.connect(_on_back_pressed)
	if _nav_home_style_callable.is_valid():
		_nav_home_style_callable.call(_back_button)
	else:
		_back_button.text = char(0x2302)
		_back_button.custom_minimum_size = Vector2(46, 46)
		_back_button.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(_back_button)

	# Clefira brand mark — small splash icon paired with the screen title so
	# the Practice Drills surface clearly belongs to the product.
	var heading_box := HBoxContainer.new()
	heading_box.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_box.add_theme_constant_override("separation", 8)
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(heading_box)
	var brand_text := Label.new()
	brand_text.text = "Clefira"
	brand_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_title_font != null:
		brand_text.add_theme_font_override("font", _ui_title_font)
	brand_text.add_theme_font_size_override("font_size", 18)
	brand_text.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	heading_box.add_child(brand_text)
	# Use the same logo asset the home screen uses (clefira-logo.svg with
	# the splash mark as fallback). Keeps branding consistent across modules.
	var brand_logo := TextureRect.new()
	var brand_tex: Texture2D = load("res://assets/logos/clefira-logo.svg") as Texture2D
	if brand_tex == null:
		brand_tex = load("res://assets/branding/clefira-splash-mark-transparent-512.png") as Texture2D
	if brand_tex != null:
		brand_logo.texture = brand_tex
	brand_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	brand_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_logo.custom_minimum_size = Vector2(22, 22)
	brand_logo.tooltip_text = "Clefira"
	heading_box.add_child(brand_logo)
	var heading := Label.new()
	heading.text = "Practice Drills"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_title_font != null:
		heading.add_theme_font_override("font", _ui_title_font)
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98, 0.94))
	heading_box.add_child(heading)
	var top_bar_spacer := Control.new()
	top_bar_spacer.custom_minimum_size = Vector2(12, 1)
	top_bar.add_child(top_bar_spacer)
	# _tempo_label retained as a hidden node — older code reads/writes its
	# .text and we surface the value via the Tempo chip instead.
	_tempo_label = Label.new()
	_tempo_label.text = "♩ = 60"
	_tempo_label.visible = false
	add_child(_tempo_label)

	# === Daily Drill hero — REMOVED to give the score area more vertical
	# real estate. The underlying daily-warmup flow is still reachable:
	#   • Keyboard shortcut D
	#   • "▶ Next Drill" button on the post-play summary card
	#   • _on_daily_warmup_pressed() invoked programmatically
	# The hero widget refs (_daily_drill_hero_button, _daily_drill_subtitle,
	# _daily_progress_bar, _daily_progress_label) stay nullable so the
	# refresh helpers null-guard cleanly. Daily progress + streak tracking
	# continues to persist via _daily_progress / drill history.

	# === Day-goal chip row ===
	var chip_row := HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 3)
	root_vbox.add_child(chip_row)
	_chip_target_wrap = _build_bullseye_chip("Pick an exercise", PICK_EXERCISE_ICON_PATH, 12)
	_chip_target_label = _chip_target_wrap.get_meta("chip_label")
	chip_row.add_child(_chip_target_wrap)
	_chip_tempo_label = _build_chip_label("♩  ---")
	chip_row.add_child(_chip_tempo_label)
	_chip_streak_label = _build_chip_label("⚡  Streak ---")
	# Hidden by default — _refresh_daily_progress_ui reveals it once the
	# user has at least a 1-day streak going.
	_chip_streak_label.visible = false
	chip_row.add_child(_chip_streak_label)
	# Feat 18 — Session streak goal chip. Hidden until the first graded
	# play of the session lands; then displays "🎯 Clean: N/3". Refreshed
	# from _on_play_finished via _refresh_session_streak_chip.
	_chip_session_streak_wrap = _build_bullseye_chip("Clean: 0/%d" % SESSION_STREAK_GOAL)
	_chip_session_streak_label = _chip_session_streak_wrap.get_meta("chip_label")
	_chip_session_streak_wrap.visible = false
	chip_row.add_child(_chip_session_streak_wrap)
	# Feat 4 — Teacher-assignment badge. Hidden by default; surfaces
	# when the loaded exercise matches an open assignment for the
	# active student. Read-only indicator — assignment CRUD lives in
	# the teacher dashboard (out of scope for this pass).
	_chip_assignment_label = _build_chip_label("★  Assigned by your teacher")
	_chip_assignment_label.visible = false
	chip_row.add_child(_chip_assignment_label)
	# Accuracy chip is intentionally NOT added — Practice Drills is a
	# playback tool, not a graded quiz, so there's no honest accuracy
	# number to show here. (Item 2 in exercie_ui_upgrade.txt lists it,
	# but faking a value would mislead. Returns once we add MIDI-input
	# grading and have real data to surface.)

	# === Controls — grouped into two compact sub-rows (v2 items 11+13) ===
	# Row 1: Exercise (Preset, Focus, Type, Reroll, Generate, ...)
	# Row 2: Core drill parameters, kept deliberately compact so the
	# Play/Stop row remains visible on normal desktop heights.
	var controls_panel := PanelContainer.new()
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls_style := _stylebox(Color(0.055, 0.105, 0.18, 0.30), Color(0.36, 0.62, 0.72, 0.08), 8, 1, 0)
	controls_style.content_margin_left = 6
	controls_style.content_margin_right = 6
	controls_style.content_margin_top = 1
	controls_style.content_margin_bottom = 1
	controls_panel.add_theme_stylebox_override("panel", controls_style)
	root_vbox.add_child(controls_panel)
	var controls_vbox := VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 1)
	controls_panel.add_child(controls_vbox)

	var exercise_row := HFlowContainer.new()
	exercise_row.add_theme_constant_override("h_separation", 4)
	exercise_row.add_theme_constant_override("v_separation", 1)
	controls_vbox.add_child(exercise_row)

	_preset_option = OptionButton.new()
	for preset in DRILL_PRESETS:
		_preset_option.add_item(str(preset["label"]))
	_preset_option.selected = 0
	_preset_option.tooltip_text = "Pre-shaped drill paths: pick one to set Focus + Level in one tap."
	_style_input(_preset_option, Vector2(180, 30))
	_preset_option.add_theme_font_size_override("font_size", 11)
	_preset_option.item_selected.connect(_on_preset_changed)
	exercise_row.add_child(_preset_option)

	_skill_option = OptionButton.new()
	for pair in ExerciseLibraryScript.skill_options():
		var idx: int = _skill_option.item_count
		_skill_option.add_item("Focus: %s" % str(pair[1]), idx)
		_skill_option.set_item_metadata(idx, str(pair[0]))
	_skill_option.selected = 0
	_style_input(_skill_option, Vector2(252, 30))
	_skill_option.add_theme_font_size_override("font_size", 11)
	_skill_option.item_selected.connect(_on_skill_changed)
	exercise_row.add_child(_skill_option)

	_type_option = OptionButton.new()
	_type_option.tooltip_text = "Specific drill — narrowed by the Focus above."
	_style_input(_type_option, Vector2(232, 30))
	_type_option.add_theme_font_size_override("font_size", 11)
	_type_option.item_selected.connect(func(_idx: int) -> void:
		stop_playback(true)
	)
	exercise_row.add_child(_type_option)
	_refresh_type_dropdown()

	_reroll_button = _build_action_button(exercise_row, "🎲 Reroll", Color(0.62, 0.78, 1.0, 1.0), _on_reroll_pressed)
	_reroll_button.custom_minimum_size = Vector2(112, 30)
	_reroll_button.add_theme_font_size_override("font_size", 11)
	_reroll_button.tooltip_text = "Re-generate the same drill type/key/level with a fresh seed — learn the pattern, not one variation. (R)"

	_generate_button = _build_action_button(exercise_row, "Generate", MENU_PRIMARY_ACCENT, _on_generate_pressed)
	_generate_button.custom_minimum_size = Vector2(136, 30)
	_generate_button.add_theme_font_size_override("font_size", 11)
	_generate_button.tooltip_text = "Build a drill from the current Focus / Type / Key / Level. (G)"
	# Overflow (⋯) — back per user request 2026-05-30. Contains Print / Save
	# PDF / Save Image / Save & Load Exercise / Save Lesson Summary /
	# Performance Analytics.
	_overflow_button = _build_overflow_button(exercise_row)

	var settings_row := HFlowContainer.new()
	settings_row.add_theme_constant_override("h_separation", 4)
	settings_row.add_theme_constant_override("v_separation", 1)
	controls_vbox.add_child(settings_row)

	_key_option = OptionButton.new()
	for opt in KEY_OPTIONS:
		_key_option.add_item(str(opt[0]))
	_key_option.selected = 0
	_style_input(_key_option, Vector2(88, 26))
	_key_option.add_theme_font_size_override("font_size", 10)
	_key_option.item_selected.connect(func(_idx: int) -> void:
		stop_playback(true)
	)
	_add_labeled_control(settings_row, "Key:", _key_option)

	_minor_check = CheckButton.new()
	_minor_check.text = "Minor"
	if _ui_font != null:
		_minor_check.add_theme_font_override("font", _ui_font)
	_minor_check.add_theme_font_size_override("font_size", 11)
	_minor_check.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_minor_check.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_minor_check.custom_minimum_size = Vector2(68, 26)
	_minor_check.toggled.connect(func(_pressed: bool) -> void:
		stop_playback(true)
	)
	settings_row.add_child(_minor_check)

	_staff_option = OptionButton.new()
	_staff_option.add_item("Grand (both hands)", 0)
	_staff_option.add_item("Treble (right)", 1)
	_staff_option.add_item("Bass (left)", 2)
	_staff_option.selected = 0
	_staff_option.tooltip_text = "Hand isolation: Treble = right-hand only, Bass = left-hand only, Grand = both."
	_style_input(_staff_option, Vector2(136, 26))
	_staff_option.add_theme_font_size_override("font_size", 10)
	_staff_option.item_selected.connect(func(_idx: int) -> void:
		if _current_exercise.is_empty():
			_refresh_score_renderer()
		else:
			_on_generate_pressed()
	)
	_add_labeled_control(settings_row, "Clef:", _staff_option)

	_octaves_spin = SpinBox.new()
	_octaves_spin.min_value = 1
	_octaves_spin.max_value = 3
	_octaves_spin.step = 1
	_octaves_spin.value = 1
	_style_input(_octaves_spin, Vector2(60, 26))
	_octaves_spin.add_theme_font_size_override("font_size", 10)
	_octaves_spin.value_changed.connect(func(_v: float) -> void:
		stop_playback(true)
	)
	_add_labeled_control(settings_row, "Oct:", _octaves_spin)

	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 10
	_level_spin.step = 1
	_level_spin.value = 1
	_style_input(_level_spin, Vector2(60, 26))
	_level_spin.add_theme_font_size_override("font_size", 10)
	_level_spin.value_changed.connect(_on_level_spin_changed)
	_add_labeled_control(settings_row, "Lvl:", _level_spin)
	# Speed accuracy gate (Feat 14) — when on, level increases are blocked
	# while last accuracy < threshold. Soft block: we snap back + flash a
	# tooltip-style hint rather than disabling the spinner.
	_speed_gate_check = CheckButton.new()
	_speed_gate_check.text = "Gate level by accuracy"
	_speed_gate_check.tooltip_text = "When ON, level only ratchets up after last play was ≥%d%% accurate. Prevents speed-without-control." % int(SPEED_GATE_MIN_ACCURACY * 100)
	if _ui_font != null:
		_speed_gate_check.add_theme_font_override("font", _ui_font)
	_speed_gate_check.add_theme_font_size_override("font_size", 12)
	_speed_gate_check.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_speed_gate_check.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_speed_gate_check.custom_minimum_size = Vector2(144, 24)
	_speed_gate_check.add_theme_font_size_override("font_size", 10)
	_speed_gate_check.button_pressed = _speed_gate_enabled
	_speed_gate_check.toggled.connect(func(pressed: bool) -> void:
		_speed_gate_enabled = pressed
	)
	settings_row.add_child(_speed_gate_check)

	# Feat 15 — Hide fingerings (visual cue reduction). Sets a flag on the
	# StaffRenderer so the next refresh skips drawing fingering digits.
	_hide_fingerings_check = CheckButton.new()
	_hide_fingerings_check.text = "Hide fingerings"
	_hide_fingerings_check.tooltip_text = "Suppress fingering numbers above noteheads. Useful once you've internalized the pattern."
	if _ui_font != null:
		_hide_fingerings_check.add_theme_font_override("font", _ui_font)
	_hide_fingerings_check.add_theme_font_size_override("font_size", 10)
	_hide_fingerings_check.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_hide_fingerings_check.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_hide_fingerings_check.custom_minimum_size = Vector2(118, 24)
	_hide_fingerings_check.button_pressed = _hide_fingerings_enabled
	_hide_fingerings_check.toggled.connect(func(pressed: bool) -> void:
		_hide_fingerings_enabled = pressed
		if _staff_area != null:
			_staff_area.set("hide_fingerings", pressed)
			_staff_area.queue_redraw()
		_save_ui_state()
	)
	settings_row.add_child(_hide_fingerings_check)

	# === Contextual hint line — HIDDEN per user request (freed space goes
	# to the staff card below). The label is still built + parented so
	# the refresh helpers + drill-misses callback that write to its .text
	# don't need null guards. visible=false means VBoxContainer skips it
	# for layout, so it takes zero vertical space. To bring it back, set
	# _contextual_hint_label.visible = true and remove this comment.
	_contextual_hint_label = Label.new()
	_contextual_hint_label.text = ""
	_contextual_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contextual_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contextual_hint_label.visible = false
	if _ui_font != null:
		_contextual_hint_label.add_theme_font_override("font", _ui_font)
	_contextual_hint_label.add_theme_font_size_override("font_size", 10)
	_contextual_hint_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.78))
	root_vbox.add_child(_contextual_hint_label)

	# === Title (compact subtitle) ===
	_title_label = Label.new()
	_title_label.text = "Pick options + Generate, or hit Start Daily Drill above."
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font != null:
		_title_label.add_theme_font_override("font", _ui_font)
	_title_label.add_theme_font_size_override("font_size", 9)
	_title_label.add_theme_color_override("font_color", Color(0.72, 0.79, 0.90, 0.86))
	root_vbox.add_child(_title_label)

	# === Staff card — tighter padding + smaller shadow + active-state border ===
	_staff_wrap_panel = PanelContainer.new()
	_staff_wrap_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# EXPAND_FILL (was SHRINK_BEGIN) lets the staff card grab the leftover
	# vertical space when the viewport is tall — gives the score the most
	# room possible without crowding the keyboard / bottom action row.
	_staff_wrap_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_staff_wrap_panel.custom_minimum_size = Vector2(0, STAFF_WRAP_HEIGHT)
	# Cache idle + active styles so the active-state flip is just a swap.
	_staff_wrap_style_idle = StyleBoxFlat.new()
	_staff_wrap_style_idle.bg_color = Color(0.99, 0.98, 0.95, 1.0)
	_staff_wrap_style_idle.corner_radius_top_left = 6
	_staff_wrap_style_idle.corner_radius_top_right = 6
	_staff_wrap_style_idle.corner_radius_bottom_left = 6
	_staff_wrap_style_idle.corner_radius_bottom_right = 6
	_staff_wrap_style_idle.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	_staff_wrap_style_idle.shadow_size = 6
	_staff_wrap_style_idle.shadow_offset = Vector2(0, 3)
	_staff_wrap_style_active = _staff_wrap_style_idle.duplicate() as StyleBoxFlat
	_staff_wrap_style_active.border_color = MENU_PRIMARY_ACCENT
	_staff_wrap_style_active.border_width_left = 2
	_staff_wrap_style_active.border_width_right = 2
	_staff_wrap_style_active.border_width_top = 2
	_staff_wrap_style_active.border_width_bottom = 2
	_staff_wrap_panel.add_theme_stylebox_override("panel", _staff_wrap_style_idle)
	root_vbox.add_child(_staff_wrap_panel)

	_staff_scroll = ScrollContainer.new()
	_staff_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staff_scroll.follow_focus = false
	_staff_wrap_panel.add_child(_staff_scroll)
	# Re-render the score when the staff viewport resizes so per-bar
	# width (derived from viewport_w in _refresh_score_renderer) keeps
	# the "exactly 3 bars visible" target across window-resize events.
	_staff_scroll.resized.connect(_on_staff_scroll_resized)

	# Empty-state label — sits inside the staff card scroll container as a
	# sibling of the staff area. Toggled by _refresh_empty_state.
	_empty_state_label = Label.new()
	_empty_state_label.text = "♪  Tap Start Daily Drill above, or pick options + Generate to see the staff."
	_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_state_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_state_label.add_theme_font_size_override("font_size", 16)
	_empty_state_label.add_theme_color_override("font_color", Color(0.34, 0.45, 0.58, 0.72))
	_empty_state_label.custom_minimum_size = Vector2(0, 200)
	_staff_scroll.add_child(_empty_state_label)

	_staff_area = StaffRendererScript.new()
	_staff_area.custom_minimum_size = Vector2(1200, STAFF_RENDER_HEIGHT)
	_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_staff_area.set("draw_paper", true)
	# Bigger staves — staff_space is the unit (one space between staff
	# lines); bumping 11→14 enlarges noteheads, ledger lines, and spacing
	# proportionally so the score reads cleanly on the now-larger card.
	_staff_area.set("staff_space", 14.0)
	# Visual cue reduction (Feat 15) — apply the persisted preference
	# at construction so the very first render respects it.
	_staff_area.set("hide_fingerings", _hide_fingerings_enabled)
	# Single continuous horizontal system — the ScrollContainer scrolls
	# left as playback progresses (see _scroll_to_playback_beat) so the
	# user sees ~2 bars at a time and the score follows the music. The
	# earlier compression bug was the staff width being fixed at 1200px;
	# now we compute width from beat count below so each bar gets enough
	# room and bars don't get squished.
	_staff_area.set("auto_bars_per_system", false)
	_staff_area.set("bars_per_system", 0)
	_staff_area.set("page_top_margin_spaces", 5.5)
	_staff_area.set("page_bottom_margin_spaces", 3.0)
	_staff_scroll.add_child(_staff_area)

	_build_keyboard(root_vbox)

	# === Post-play summary card (hidden until Play finishes) ===
	_post_play_summary_panel = PanelContainer.new()
	_post_play_summary_panel.visible = false
	_post_play_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary_style := _stylebox(Color(0.08, 0.18, 0.13, 0.94), Color(0.42, 0.92, 0.58, 0.86), 8, 2, 3)
	summary_style.content_margin_left = 14
	summary_style.content_margin_right = 14
	summary_style.content_margin_top = 8
	summary_style.content_margin_bottom = 8
	_post_play_summary_panel.add_theme_stylebox_override("panel", summary_style)
	root_vbox.add_child(_post_play_summary_panel)
	var summary_row := HBoxContainer.new()
	summary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_row.add_theme_constant_override("separation", 14)
	_post_play_summary_panel.add_child(summary_row)
	_post_play_summary_label = Label.new()
	_post_play_summary_label.text = ""
	_post_play_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_post_play_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font != null:
		_post_play_summary_label.add_theme_font_override("font", _ui_font)
	_post_play_summary_label.add_theme_font_size_override("font_size", 14)
	_post_play_summary_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.94, 0.96))
	summary_row.add_child(_post_play_summary_label)
	_post_play_replay_button = Button.new()
	_post_play_replay_button.text = "↻  Replay"
	_post_play_replay_button.focus_mode = Control.FOCUS_NONE
	_post_play_replay_button.custom_minimum_size = Vector2(88, 28)
	if _ui_font != null:
		_post_play_replay_button.add_theme_font_override("font", _ui_font)
	_post_play_replay_button.add_theme_font_size_override("font_size", 12)
	_post_play_replay_button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.94, 0.96))
	var replay_sb := _stylebox(Color(0.10, 0.22, 0.16, 0.88), Color(0.42, 0.92, 0.58, 0.62), 8, 1, 0)
	replay_sb.content_margin_left = 10
	replay_sb.content_margin_right = 10
	_post_play_replay_button.add_theme_stylebox_override("normal", replay_sb)
	_post_play_replay_button.pressed.connect(func() -> void:
		_hide_post_play_summary()
		_on_play_pressed()
	)
	summary_row.add_child(_post_play_replay_button)

	# Weak-spot button (Feat 3) — only visible when the last play missed ≥2
	# notes. Re-rolls a drill tightened around the missed pitches.
	_post_play_weak_spot_button = Button.new()
	_post_play_weak_spot_button.text = "  Drill the misses"
	var weak_bullseye: Texture2D = load(BULLSEYE_ICON_PATH)
	if weak_bullseye != null:
		_post_play_weak_spot_button.icon = weak_bullseye
		_post_play_weak_spot_button.add_theme_constant_override("icon_max_width", 18)
	_post_play_weak_spot_button.focus_mode = Control.FOCUS_NONE
	_post_play_weak_spot_button.custom_minimum_size = Vector2(130, 28)
	_post_play_weak_spot_button.visible = false
	if _ui_font != null:
		_post_play_weak_spot_button.add_theme_font_override("font", _ui_font)
	_post_play_weak_spot_button.add_theme_font_size_override("font_size", 12)
	_post_play_weak_spot_button.add_theme_color_override("font_color", Color(0.94, 1.0, 0.96, 0.96))
	var weak_sb := _stylebox(Color(0.20, 0.14, 0.10, 0.92), Color(0.95, 0.66, 0.32, 0.86), 8, 1, 0)
	weak_sb.content_margin_left = 10
	weak_sb.content_margin_right = 10
	_post_play_weak_spot_button.add_theme_stylebox_override("normal", weak_sb)
	_post_play_weak_spot_button.pressed.connect(_on_drill_misses_pressed)
	summary_row.add_child(_post_play_weak_spot_button)

	# Feat 12 — Mistake replay. Visible when the last play captured ANY
	# MIDI input (graded run with at least one key pressed). Schedules
	# _spawn_note for each captured note at its recorded beat so the
	# student can hear what they actually played, side-by-side with the
	# target via the existing Replay button.
	_post_play_replay_take_button = Button.new()
	_post_play_replay_take_button.text = "🎧  Replay your take"
	_post_play_replay_take_button.tooltip_text = "Re-play exactly what you tapped on MIDI — captured timing + pitches."
	_post_play_replay_take_button.focus_mode = Control.FOCUS_NONE
	_post_play_replay_take_button.custom_minimum_size = Vector2(150, 28)
	_post_play_replay_take_button.visible = false
	if _ui_font != null:
		_post_play_replay_take_button.add_theme_font_override("font", _ui_font)
	_post_play_replay_take_button.add_theme_font_size_override("font_size", 12)
	_post_play_replay_take_button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.94, 0.96))
	var take_sb := _stylebox(Color(0.10, 0.18, 0.22, 0.88), Color(0.42, 0.78, 0.92, 0.62), 8, 1, 0)
	take_sb.content_margin_left = 10
	take_sb.content_margin_right = 10
	_post_play_replay_take_button.add_theme_stylebox_override("normal", take_sb)
	_post_play_replay_take_button.pressed.connect(_on_replay_take_pressed)
	summary_row.add_child(_post_play_replay_take_button)

	# Feat 8 — Loop last bar. Re-plays just the final bar so the student
	# can focus on the section that's most likely to need rehearsal
	# (resolution endings tend to land on the last bar).
	_post_play_loop_bar_button = Button.new()
	_post_play_loop_bar_button.text = "↻  Loop last bar"
	_post_play_loop_bar_button.tooltip_text = "Re-play just the last bar from the current exercise."
	_post_play_loop_bar_button.focus_mode = Control.FOCUS_NONE
	_post_play_loop_bar_button.custom_minimum_size = Vector2(132, 28)
	if _ui_font != null:
		_post_play_loop_bar_button.add_theme_font_override("font", _ui_font)
	_post_play_loop_bar_button.add_theme_font_size_override("font_size", 12)
	_post_play_loop_bar_button.add_theme_color_override("font_color", Color(0.94, 1.0, 0.96, 0.96))
	var loop_sb := _stylebox(Color(0.10, 0.16, 0.22, 0.88), Color(0.62, 0.82, 0.96, 0.62), 8, 1, 0)
	loop_sb.content_margin_left = 10
	loop_sb.content_margin_right = 10
	_post_play_loop_bar_button.add_theme_stylebox_override("normal", loop_sb)
	_post_play_loop_bar_button.pressed.connect(_on_loop_last_bar_pressed)
	summary_row.add_child(_post_play_loop_bar_button)

	_post_play_next_button = Button.new()
	_post_play_next_button.text = "▶  Next Drill"
	_post_play_next_button.focus_mode = Control.FOCUS_NONE
	_post_play_next_button.custom_minimum_size = Vector2(104, 28)
	if _ui_font != null:
		_post_play_next_button.add_theme_font_override("font", _ui_font)
	_post_play_next_button.add_theme_font_size_override("font_size", 12)
	_post_play_next_button.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06, 1.0))
	var next_sb := _stylebox(Color(0.96, 0.78, 0.42, 0.96), Color(1.0, 0.92, 0.62, 0.94), 8, 1, 0)
	next_sb.content_margin_left = 10
	next_sb.content_margin_right = 10
	_post_play_next_button.add_theme_stylebox_override("normal", next_sb)
	_post_play_next_button.pressed.connect(func() -> void:
		_hide_post_play_summary()
		_on_daily_warmup_pressed()
	)
	summary_row.add_child(_post_play_next_button)

	# === Bottom action row — Play / Stop / Metronome / Info ===
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(bottom_row)

	_play_button = _build_action_button(bottom_row, "♪ Play", Color(0.45, 0.92, 0.62, 1.0), _on_play_pressed)
	_stop_button = _build_action_button(bottom_row, "■ Stop", Color(0.92, 0.46, 0.42, 1.0), _on_stop_pressed)

	_metronome_check = CheckButton.new()
	_metronome_check.text = "♩ Metronome"
	_metronome_check.tooltip_text = "Audible quarter-note click during Play — every beat ticks, downbeat (beat 1) accented. (M)"
	if _ui_font != null:
		_metronome_check.add_theme_font_override("font", _ui_font)
	_metronome_check.add_theme_font_size_override("font_size", 14)
	_metronome_check.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_metronome_check.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_metronome_check.custom_minimum_size = Vector2(146, 40)
	_metronome_check.button_pressed = _metronome_enabled
	_metronome_check.toggled.connect(func(pressed: bool) -> void:
		_metronome_enabled = pressed
	)
	bottom_row.add_child(_metronome_check)

	_count_in_check = CheckButton.new()
	_count_in_check.text = "1-2-3-4 Count-in"
	_count_in_check.tooltip_text = "Play 4 click beats at tempo before the first note so you can lock into the pulse."
	if _ui_font != null:
		_count_in_check.add_theme_font_override("font", _ui_font)
	_count_in_check.add_theme_font_size_override("font_size", 13)
	_count_in_check.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_count_in_check.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_count_in_check.custom_minimum_size = Vector2(156, 40)
	_count_in_check.button_pressed = _count_in_enabled
	_count_in_check.toggled.connect(func(pressed: bool) -> void:
		_count_in_enabled = pressed
	)
	bottom_row.add_child(_count_in_check)

	# Mic toggle — hidden until parent calls setup_mic(). While on, the host's
	# PitchDetector feeds detected single notes into the panel: matching key
	# briefly lights, status label echoes the heard pitch. Monophonic only.
	_mic_button = Button.new()
	_mic_button.toggle_mode = true
	_mic_button.text = "%s  Mic" % char(0x1F3A4)
	_mic_button.tooltip_text = "Listen to your microphone — play or sing a note to see it light on the keyboard."
	if _ui_font != null:
		_mic_button.add_theme_font_override("font", _ui_font)
	_mic_button.add_theme_font_size_override("font_size", 14)
	_mic_button.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_mic_button.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_mic_button.custom_minimum_size = Vector2(110, 40)
	_mic_button.toggled.connect(_on_mic_button_toggled)
	_mic_button.visible = false
	bottom_row.add_child(_mic_button)

	# 📁 Load Score — opens a file picker for MusicXML (.musicxml/.xml/.mxl)
	# files. On success the imported score replaces the current exercise so
	# Play / Play Along run against it.
	var load_score_btn := Button.new()
	load_score_btn.text = "%s  Load Score..." % char(0x1F4C1)
	load_score_btn.tooltip_text = "Import a MusicXML file (.musicxml, .xml, or .mxl) — your own repertoire or a teacher handout."
	if _ui_font != null:
		load_score_btn.add_theme_font_override("font", _ui_font)
	load_score_btn.add_theme_font_size_override("font_size", 14)
	load_score_btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	load_score_btn.custom_minimum_size = Vector2(146, 40)
	load_score_btn.pressed.connect(_on_load_score_pressed)
	bottom_row.add_child(load_score_btn)

	# Play Along — when on, Play scrolls the cursor + ticks metronome but
	# DOES NOT sound the model notes. Student plays them on MIDI keyboard;
	# system grades pitch + timing and shows per-bar accuracy at the end.
	_play_along_button = Button.new()
	_play_along_button.toggle_mode = true
	_play_along_button.text = "  Play Along"
	# Clefira's own bullseye icon (assets/icons/bullseye.svg) in place of the
	# generic 🎯 emoji glyph.
	var bullseye_tex: Texture2D = load(BULLSEYE_ICON_PATH)
	if bullseye_tex != null:
		_play_along_button.icon = bullseye_tex
		_play_along_button.add_theme_constant_override("icon_max_width", 20)
	_play_along_button.tooltip_text = "Practice partner mode — model notes go silent; play along on MIDI keyboard. System grades pitch + timing and shows per-bar accuracy at the end."
	if _ui_font != null:
		_play_along_button.add_theme_font_override("font", _ui_font)
	_play_along_button.add_theme_font_size_override("font_size", 14)
	_play_along_button.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_play_along_button.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	_play_along_button.custom_minimum_size = Vector2(146, 40)
	_play_along_button.toggled.connect(_on_play_along_toggled)
	bottom_row.add_child(_play_along_button)

	# Info (ℹ) + history (🕘) icon buttons removed 2026-05-30 per user request —
	# they read as "settings" icons next to Play/Stop and added clutter without
	# enough value. Their handlers (_on_info_pressed, _on_history_pressed)
	# remain as dead code so any non-UI callers don't break.

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font != null:
		_status_label.add_theme_font_override("font", _ui_font)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 0.78))
	root_vbox.add_child(_status_label)

	_mic_status_label = Label.new()
	_mic_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font != null:
		_mic_status_label.add_theme_font_override("font", _ui_font)
	_mic_status_label.add_theme_font_size_override("font_size", 13)
	_mic_status_label.add_theme_color_override("font_color", _MIC_HIGHLIGHT_COLOR)
	_mic_status_label.visible = false
	root_vbox.add_child(_mic_status_label)


func _build_action_button(parent: Control, text: String, accent: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	var min_w := 210 if text.length() > 12 else 176
	btn.custom_minimum_size = Vector2(min_w, 44)
	btn.focus_mode = Control.FOCUS_NONE
	if _ui_font != null:
		btn.add_theme_font_override("font", _ui_font)
	elif _ui_title_font != null:
		btn.add_theme_font_override("font", _ui_title_font)
	btn.add_theme_font_size_override("font_size", 12)
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
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
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
	# Restyled to match the OptionButton / dropdown look (dark blue bg +
	# golden border, same height as the other controls in the row) so the
	# cluster reads as one cohesive control band.
	var btn := Button.new()
	btn.text = "⋯"
	btn.tooltip_text = "Export / Save / Load"
	btn.focus_mode = Control.FOCUS_NONE
	_style_input(btn, Vector2(34, 30))
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.98))

	_export_menu = PopupMenu.new()
	_export_menu.add_item("Print", EXPORT_PRINT)
	_export_menu.add_item("Save PDF", EXPORT_SAVE_PDF)
	_export_menu.add_item("Save Image", EXPORT_SAVE_IMAGE)
	_export_menu.add_separator()
	_export_menu.add_item("Save Exercise (replay later)", EXPORT_SAVE_EXERCISE)
	_export_menu.add_item("Load Exercise...", EXPORT_LOAD_EXERCISE)
	_export_menu.add_separator()
	_export_menu.add_item("Save Lesson Summary (Markdown)", EXPORT_LESSON_SUMMARY)
	_export_menu.add_item("📊  Performance Analytics", EXPORT_ANALYTICS)
	if _ui_font != null:
		_export_menu.add_theme_font_override("font", _ui_font)
	_export_menu.add_theme_font_size_override("font_size", 16)
	_style_popup_menu(_export_menu)
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
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		btn.text = ""
		# Mark as a piano-key button so it's filtered out of any global
		# UI-click-sfx wiring (current code doesn't have one, but this
		# documents intent for future code). Piano-key taps already play
		# the note sample — no extra UI click needed.
		btn.set_meta("no_click_sfx", true)
		btn.set_meta("piano_key", true)
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
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		btn.text = ""
		btn.z_index = 1
		# See white-key block — same no-click-sfx / piano-key tagging.
		btn.set_meta("no_click_sfx", true)
		btn.set_meta("piano_key", true)
		var captured_pitch_b := pitch
		btn.pressed.connect(func(): _on_keyboard_key_pressed(captured_pitch_b))
		PianoKeyStylesScript.apply_black_style(btn, Color.WHITE)
		btn.add_theme_font_size_override("font_size", 18)
		keys_root.add_child(btn)
		_keyboard_keys[pitch] = btn


func _on_keyboard_key_pressed(pitch: int) -> void:
	# Route through the host's _play_note callable so the keyboard taps
	# use the single shared _piano_player (no per-tap AudioStreamPlayer
	# allocation, no add_child churn, no audio-mixer initialisation pop).
	# Same path the Chord Explorer keyboard uses. Falls back to _spawn_note
	# only if the callable isn't wired (defensive — setup() always wires it).
	if _play_note_callable.is_valid():
		_play_note_callable.call(int(pitch), 0.45)
		return
	var sample_map: Dictionary = _sample_map_callable.call() if _sample_map_callable.is_valid() else {}
	_spawn_note(int(pitch), 0.42, sample_map)


func _keyboard_highlight_color(note_info: Dictionary) -> Color:
	var staff_num := int(note_info.get("staff", 1))
	if staff_num == 2:
		return Color(0.95, 0.72, 0.30, 1.0)
	return Color(0.40, 0.76, 0.86, 1.0)


func _on_mic_button_toggled(pressed: bool) -> void:
	if _mic_listener == null:
		return
	if pressed:
		var ok: bool = _mic_listener.start()
		if not ok:
			_mic_button.set_pressed_no_signal(false)
			return
		_mic_status_label.visible = true
		_mic_button.text = "%s  Mic on" % char(0x1F3A4)
		set_process(true)
	else:
		_mic_listener.stop()
		_mic_status_label.visible = false
		_mic_button.text = "%s  Mic" % char(0x1F3A4)
		if _mic_last_pitch >= 0:
			_keyboard_clear_highlight()
			_mic_last_pitch = -1
		# Only stop _process if playback isn't also using it.
		if not _playback_active:
			set_process(false)


func _on_mic_note_detected(midi: int, _note_name: String, _full_name: String, _cents_off: float) -> void:
	# Light the matching key (cyan), echo "Heard: …" via status_changed.
	if _mic_last_pitch >= 0 and _mic_last_pitch != midi:
		_keyboard_clear_highlight()
	_mic_last_pitch = midi
	_mic_last_pitch_clear_at_msec = Time.get_ticks_msec() + _MIC_HIGHLIGHT_HOLD_MSEC
	if _keyboard_keys.has(midi):
		var btn: Button = _keyboard_keys[midi] as Button
		if btn != null:
			if PianoKeyStylesScript.is_black_key(midi):
				PianoKeyStylesScript.apply_black_style(btn, _MIC_HIGHLIGHT_COLOR)
			else:
				PianoKeyStylesScript.apply_white_style(btn, _MIC_HIGHLIGHT_COLOR)
			# Scroll keyboard so the heard note is visible.
			_keyboard_scroll_to_midis([midi])


func _on_mic_status_changed(text: String, listening: bool) -> void:
	if _mic_status_label == null:
		return
	_mic_status_label.text = text
	_mic_status_label.visible = listening or not text.is_empty()


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
	_next_daily_pick = {}
	_refresh_daily_preview()


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
	_current_exercise_is_daily = _daily_warmup_flag_for_next_generate
	_daily_warmup_flag_for_next_generate = false
	_append_tonic_resolution_to_current_exercise()
	_hide_post_play_summary()
	if _title_label != null:
		_title_label.text = _plain_dash_text(str(_current_exercise.get("title", "")))
	if _tempo_label != null:
		_tempo_label.text = "♩ = %d" % int(_current_exercise.get("tempo_bpm", 60))
	if _status_label != null:
		var playable_notes := 0
		for note_any in _current_exercise.get("notes", []):
			var note: Dictionary = note_any
			if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
				playable_notes += 1
		# Short status — diagnostic detail lives behind the Info button.
		_status_label.text = "%d notes ready. Press Play to hear." % playable_notes
	_refresh_day_chips()
	_refresh_contextual_hint()
	_refresh_active_state()
	_refresh_empty_state()
	_refresh_score_renderer()


func _on_play_pressed() -> void:
	if _current_exercise.is_empty():
		if _status_label != null:
			_status_label.text = "Generate an exercise first."
		return
	if _playback_active:
		return
	_hide_post_play_summary()
	_clear_keyboard_judgement_colors()
	_stop_note_audio()
	_clear_staff_highlight()
	_start_midi_grading()
	_playback_token += 1
	var token := _playback_token
	var events: Array = _collect_playback_events(_current_exercise.get("notes", []))
	# Feat 8 — Loop / retry. If a filter is set (Loop Last Bar pressed),
	# slice the events to those at/after the start beat and shift them
	# so they play from t=0. One-shot: cleared here so subsequent normal
	# Play presses get the full exercise back.
	var filter_from_beat: float = _playback_filter_from_beat
	_playback_filter_from_beat = -1.0
	if filter_from_beat >= 0.0:
		var filtered: Array = []
		for ev_any in events:
			var ev_d: Dictionary = ev_any
			var ev_beat: float = float(ev_d.get("beat_offset", 0.0))
			if ev_beat + 0.001 >= filter_from_beat:
				var shifted := ev_d.duplicate(true)
				# Preserve the original (un-shifted) beat for visual cursor /
				# staff highlight — the staff is drawn with absolute positions
				# from the full exercise, so the highlight needs the original
				# beat, not the loop-relative one. Without this the cursor
				# jumps to the start of bar 1 even when audio is in the last bar.
				shifted["original_beat"] = ev_beat
				shifted["beat_offset"] = ev_beat - filter_from_beat
				filtered.append(shifted)
		events = filtered
	var bpm: float = float(_current_exercise.get("tempo_bpm", 80))
	var seconds_per_beat: float = 60.0 / maxf(40.0, bpm)
	_playback_sample_map = _sample_map_callable.call() if _sample_map_callable.is_valid() else {}
	_playback_queue.clear()
	# Count-in offset: when enabled, the actual exercise starts 4 beats LATER
	# in the timeline; click events at t=0..3 lead in.
	var count_in_beats: float = 4.0 if _count_in_enabled else 0.0
	var count_in_offset_sec: float = count_in_beats * seconds_per_beat
	var start_usec: int = Time.get_ticks_usec() + int(round(count_in_offset_sec * 1_000_000.0))
	_last_play_start_usec = start_usec
	var final_end_beat := 0.0
	if _count_in_enabled:
		var time_num_ci: int = max(1, int(_current_exercise.get("time_sig_num", 4)))
		var lead_in_start_usec: int = Time.get_ticks_usec()
		for ci in range(4):
			var click_at_usec: int = lead_in_start_usec + int(round(float(ci) * seconds_per_beat * 1_000_000.0))
			_playback_queue.append({
				"at_usec": click_at_usec,
				"kind": "click",
				"token": token,
				"accent": (ci % time_num_ci) == 0,
			})
	for i in range(events.size()):
		var ev: Dictionary = events[i]
		var beat_offset := float(ev.get("beat_offset", 0.0))
		var dur_beats := float(ev.get("duration_beats", 0.5))
		final_end_beat = maxf(final_end_beat, beat_offset + dur_beats)
		var at_usec := start_usec + int(round(beat_offset * seconds_per_beat * 1_000_000.0))
		_playback_queue.append({
			"at_usec": at_usec,
			"kind": "note",
			"token": token,
			"index": i,
			"event": ev,
			"seconds_per_beat": seconds_per_beat,
		})
	if _metronome_enabled:
		var total_beats := maxf(final_end_beat, float(_current_exercise.get("total_beats", final_end_beat)))
		var time_num: int = max(1, int(_current_exercise.get("time_sig_num", 4)))
		var beat := 0
		while float(beat) < total_beats + 0.001:
			var click_at := start_usec + int(round(float(beat) * seconds_per_beat * 1_000_000.0))
			_playback_queue.append({
				"at_usec": click_at,
				"kind": "click",
				"token": token,
				"accent": (beat % time_num) == 0,
			})
			beat += 1
	# Finish event flushes UI a hair after the last note tail.
	var finish_at := start_usec + int(round((final_end_beat * seconds_per_beat + 0.20) * 1_000_000.0))
	_playback_queue.append({
		"at_usec": finish_at,
		"kind": "finish",
		"token": token,
	})
	_playback_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("at_usec", 0)) < int(b.get("at_usec", 0))
	)
	_playback_index = -1
	_playback_active = true
	# Arm Play Along grading — snapshot the queued events with their absolute
	# target timestamps so handle_midi_note_on can match against them.
	if _play_along_enabled:
		_play_along_arm(start_usec, seconds_per_beat, events, filter_from_beat)
	set_process(true)


func _process(_delta: float) -> void:
	# Mic listening runs independently of playback — handled first so it
	# still ticks when no exercise is playing.
	if _mic_listener != null and _mic_listener.is_listening() and visible:
		_mic_listener.tick()
		if _mic_last_pitch >= 0 and Time.get_ticks_msec() > _mic_last_pitch_clear_at_msec:
			_keyboard_clear_highlight()
			_mic_last_pitch = -1
	if _play_along_active:
		_play_along_sweep_misses(Time.get_ticks_usec())
	if not _playback_active or _playback_queue.is_empty():
		return
	var now: int = Time.get_ticks_usec()
	while not _playback_queue.is_empty() and int(_playback_queue[0].get("at_usec", 0)) <= now:
		var ev: Dictionary = _playback_queue.pop_front()
		if int(ev.get("token", -1)) != _playback_token:
			continue
		var kind := str(ev.get("kind", ""))
		match kind:
			"note":
				_dispatch_note_event(ev)
			"click":
				_dispatch_click_event(bool(ev.get("accent", false)))
			"finish":
				_playback_active = false
				_playback_index = -1
				_clear_staff_highlight()
				_keyboard_clear_highlight()
				_mic_last_pitch = -1
				# Sweep any final misses + emit the summary BEFORE the play
				# finished handler so the status label shows accuracy instead
				# of the generic "play complete" message.
				if _play_along_active:
					_play_along_sweep_misses(Time.get_ticks_usec())
					_play_along_finish()
				# Keep _process running if mic listener still wants ticks.
				var keep_process: bool = _mic_listener != null and _mic_listener.is_listening()
				set_process(keep_process)
				_on_play_finished()
				return


func _dispatch_note_event(ev: Dictionary) -> void:
	_playback_index = int(ev.get("index", -1))
	var event: Dictionary = ev.get("event", {})
	var beat_offset := float(event.get("beat_offset", 0.0))
	# When Loop Last Bar is active, beat_offset is normalized to 0-based for
	# audio scheduling, but the staff is drawn with absolute beats. Use the
	# preserved original_beat for visuals so the cursor + scroll track the
	# actual position in the score, not the loop-relative zero.
	var visual_beat: float = float(event.get("original_beat", beat_offset))
	var midis: Array = event.get("midis", [])
	var note_durs: Array = event.get("note_durations", [])
	var dur_beats := float(event.get("duration_beats", 0.5))
	var seconds_per_beat := float(ev.get("seconds_per_beat", 0.5))
	if _staff_area != null:
		if _staff_area.has_method("set_highlight_beat"):
			_staff_area.set_highlight_beat(visual_beat)
		elif _staff_area.has_method("set_highlight_index"):
			_staff_area.set_highlight_index(int(ev.get("index", -1)))
	_scroll_to_playback_beat(visual_beat)
	_keyboard_show_event(event)
	# Play Along mode mutes the model audio so the student supplies the
	# notes themselves. Cursor + scroll + metronome still run.
	if _play_along_active:
		_play_along_advance_window(ev)
		return
	for ni in range(midis.size()):
		var note_dur_beats: float = float(note_durs[ni]) if ni < note_durs.size() else dur_beats
		var note_sound_sec: float = note_dur_beats * seconds_per_beat
		_spawn_note(int(midis[ni]), maxf(0.05, note_sound_sec * 0.97), _playback_sample_map)


# --- Custom score import (MusicXML) -----------------------------------------


func _on_load_score_pressed() -> void:
	# Show a native-style FileDialog filtered to MusicXML extensions. Godot's
	# FileDialog respects the platform's file picker on Android/iOS via
	# native dialog plugins; on desktop it uses the engine's built-in picker.
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.title = "Load MusicXML score"
	dlg.filters = PackedStringArray([
		"*.musicxml ; MusicXML score",
		"*.xml ; XML score",
		"*.mxl ; Compressed MusicXML",
	])
	dlg.file_selected.connect(_on_load_score_file_selected)
	dlg.close_requested.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered_ratio(0.75)


func _on_load_score_file_selected(path: String) -> void:
	if path == "":
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		if _status_label != null:
			_status_label.text = "Couldn't open %s — check file permissions." % path.get_file()
		return
	var raw_bytes := file.get_buffer(file.get_length())
	file.close()
	var imported: Dictionary = MusicXMLImporterScript.import_bytes(raw_bytes, path.get_file())
	if imported.has("error"):
		if _status_label != null:
			_status_label.text = "Import failed: %s" % str(imported["error"])
		return
	# Apply the imported score as the current exercise. Reuse the existing
	# generate-side staging path so the staff renderer, chip row, and post-
	# play summary all read from the same dict format.
	stop_playback(true)
	_current_exercise = imported
	_current_seed = -1
	_current_exercise_is_daily = false
	if _title_label != null:
		_title_label.text = _plain_dash_text(str(_current_exercise.get("title", "")))
	if _tempo_label != null:
		_tempo_label.text = "♩ = %d" % int(_current_exercise.get("tempo_bpm", 60))
	_refresh_score_renderer()
	_refresh_empty_state()
	_keyboard_scroll_to_first_note()
	if _status_label != null:
		var n_count: int = (_current_exercise.get("notes", []) as Array).size()
		_status_label.text = "Loaded: %s — %d notes ready. Press Play." % [str(_current_exercise.get("title", "score")), n_count]


# --- Play Along grading -----------------------------------------------------


func _on_play_along_toggled(pressed: bool) -> void:
	_play_along_enabled = pressed
	if _play_along_button != null:
		_play_along_button.text = "  Play Along: On" if pressed else "  Play Along"
	if _status_label != null:
		if pressed:
			_status_label.text = "Play Along is on — Play to start. Notes will be silent; play them on your MIDI keyboard."
		elif not _playback_active:
			_status_label.text = ""


# Called from _on_play_pressed if play-along is enabled. Snapshots all queued
# note events into a grading list with absolute target timestamps, resets
# tracking state, and arms the dispatcher to mute model audio.
func _play_along_arm(start_usec: int, seconds_per_beat: float, events: Array, filter_from_beat: float) -> void:
	_play_along_active = true
	_play_along_events.clear()
	_play_along_bar_totals.clear()
	_play_along_cursor = 0
	if _staff_area != null and _staff_area.has_method("clear_play_along_marks"):
		_staff_area.call("clear_play_along_marks")
	var time_num: int = max(1, int(_current_exercise.get("time_sig_num", 4)))
	var time_den: int = max(1, int(_current_exercise.get("time_sig_den", 4)))
	var beats_per_bar: float = float(time_num) * (4.0 / maxf(1.0, float(time_den)))
	for i in events.size():
		var ev_d: Dictionary = events[i] as Dictionary
		var beat_offset: float = float(ev_d.get("beat_offset", 0.0))
		var midis: Array = ev_d.get("midis", [])
		if midis.is_empty():
			continue
		# Pitch grading currently checks the LOWEST note of the event — that
		# matches Hanon / scale single-line drills. Phase 2 will extend this
		# to multi-voice (left + right) when we add the two-hand mode.
		var expected_midi: int = int(midis[0])
		var target_usec: int = start_usec + int(round(beat_offset * seconds_per_beat * 1_000_000.0))
		# Bar index uses the ORIGINAL beat so loop-last-bar still aggregates
		# into the right bucket.
		var original_beat: float = float(ev_d.get("original_beat", beat_offset + filter_from_beat))
		if filter_from_beat < 0.0:
			original_beat = beat_offset
		var bar_idx: int = int(floor(original_beat / maxf(0.001, beats_per_bar)))
		_play_along_events.append({
			"index": i,
			"event_ref": ev_d,
			"expected_midi": expected_midi,
			"target_usec": target_usec,
			"bar_idx": bar_idx,
			"status": "pending",
		})
		var bar_entry_v: Variant = _play_along_bar_totals.get(bar_idx, null)
		var bar_entry: Dictionary
		if typeof(bar_entry_v) == TYPE_DICTIONARY:
			bar_entry = bar_entry_v
		else:
			bar_entry = {"hit": 0, "total": 0}
		bar_entry["total"] = int(bar_entry.get("total", 0)) + 1
		_play_along_bar_totals[bar_idx] = bar_entry


# Called from _dispatch_note_event when the cursor passes a note. We don't
# fail the note yet — we keep the window open for ±PLAY_ALONG_WINDOW_USEC
# from target. handle_midi_note_on does the matching. Anything still pending
# after window-closed gets marked missed by _play_along_sweep_misses below.
func _play_along_advance_window(_ev: Dictionary) -> void:
	pass


# Called once per _process tick while play_along_active. Sweeps the events
# list and marks any whose target_usec + window has passed without a hit.
func _play_along_sweep_misses(now_usec: int) -> void:
	if _play_along_events.is_empty():
		return
	for entry in _play_along_events:
		if str(entry.get("status", "")) != "pending":
			continue
		var target_usec: int = int(entry.get("target_usec", 0))
		if now_usec > target_usec + PLAY_ALONG_WINDOW_USEC:
			entry["status"] = "missed"
			_play_along_tint_event(entry, PLAY_ALONG_MISS_COLOR)


# Public API: parent (interval_birds.gd) forwards MIDI note-ons here while
# Practice Drills is active. We match against the nearest pending event.
func handle_midi_note_on(pitch: int) -> void:
	if not _play_along_active or _play_along_events.is_empty():
		return
	var now_usec: int = Time.get_ticks_usec()
	# Walk forward from cursor to find the nearest pending event within
	# window. We scan a small lookahead so a clean early-press matches even
	# if a previous note was missed.
	var lookahead: int = 6
	for i in range(_play_along_cursor, mini(_play_along_events.size(), _play_along_cursor + lookahead)):
		var entry: Dictionary = _play_along_events[i]
		if str(entry.get("status", "")) != "pending":
			continue
		var target_usec: int = int(entry.get("target_usec", 0))
		var diff: int = now_usec - target_usec
		if absi(diff) > PLAY_ALONG_WINDOW_USEC:
			continue
		var expected_midi: int = int(entry.get("expected_midi", -1))
		# Octave-flexible match: same pitch class also counts (so a student
		# whose MIDI keyboard sits one octave off doesn't get penalised).
		var pitch_match: bool = (pitch == expected_midi) or (posmod(pitch, 12) == posmod(expected_midi, 12))
		if pitch_match:
			entry["status"] = "hit"
			_play_along_tint_event(entry, PLAY_ALONG_HIT_COLOR)
			var bar_idx: int = int(entry.get("bar_idx", 0))
			var bar_entry: Dictionary = _play_along_bar_totals.get(bar_idx, {"hit": 0, "total": 0})
			bar_entry["hit"] = int(bar_entry.get("hit", 0)) + 1
			_play_along_bar_totals[bar_idx] = bar_entry
			_play_along_cursor = i + 1
			return
		# Wrong pitch but inside window → mark it, advance.
		entry["status"] = "wrong"
		_play_along_tint_event(entry, PLAY_ALONG_WRONG_COLOR)
		_play_along_cursor = i + 1
		return
	# No event in window — could be a stray press; ignore.


# Visually mark the note on the staff with the grading color. Falls through
# silently if the staff renderer doesn't expose a per-event tint hook.
func _play_along_tint_event(entry: Dictionary, color: Color) -> void:
	if _staff_area == null:
		return
	if _staff_area.has_method("mark_play_along_event"):
		_staff_area.call("mark_play_along_event", int(entry.get("index", -1)), color)


# Builds the per-bar accuracy summary text shown when Play Along finishes.
func _play_along_summary_text() -> String:
	if _play_along_events.is_empty():
		return ""
	var total_hits: int = 0
	var total_events: int = _play_along_events.size()
	for ent in _play_along_events:
		if str(ent.get("status", "")) == "hit":
			total_hits += 1
	var overall_pct: int = int(round(float(total_hits) / float(maxi(1, total_events)) * 100.0))
	var bar_keys: Array = _play_along_bar_totals.keys()
	bar_keys.sort()
	var lines: Array[String] = []
	lines.append("%s  Overall accuracy: %d%%  (%d / %d notes)" % [char(0x1F3AF), overall_pct, total_hits, total_events])
	lines.append("")
	lines.append("Per-bar:")
	for k in bar_keys:
		var be: Dictionary = _play_along_bar_totals[k]
		var bh: int = int(be.get("hit", 0))
		var bt: int = int(be.get("total", 0))
		var bp: int = int(round(float(bh) / float(maxi(1, bt)) * 100.0))
		var glyph := "%s" % char(0x2713) if bp >= 75 else ("%s" % char(0x2717) if bp < 50 else "·")
		lines.append("  %s  Bar %d: %d%% (%d/%d)" % [glyph, int(k) + 1, bp, bh, bt])
	return "\n".join(lines)


func _play_along_finish() -> void:
	if not _play_along_active:
		return
	_play_along_active = false
	var summary := _play_along_summary_text()
	if summary == "":
		return
	# Show the summary in the status label OR a dialog if one is wired.
	if _status_label != null:
		_status_label.text = summary
	# Also push the summary into the post-play summary panel if visible.
	if _post_play_summary_panel != null and is_instance_valid(_post_play_summary_panel):
		# Append to whatever the panel already shows; future work: dedicated panel.
		pass


func _dispatch_click_event(accent: bool) -> void:
	# High, short click that cuts through the played notes:
	# pitched well above typical drill range (drills mostly sit at MIDI 48-72)
	# and boosted by ~+10 dB. Downbeat is a perfect-fourth higher AND ~3 dB
	# louder so beat 1 is unambiguous.
	var pitch := 100 if accent else 95
	var click_db := 13.0 if accent else 10.0
	_spawn_note(pitch, 0.055, _playback_sample_map, click_db)


func _on_stop_pressed() -> void:
	stop_playback(true)


func _on_daily_warmup_pressed() -> void:
	_daily_warmup_flag_for_next_generate = true
	var level: int = int(_level_spin.value) if _level_spin != null else 3
	var focus: String = _current_skill_filter
	var inferred_from_weakness: String = ""
	if focus == "all" and _weakest_skill_family_callable.is_valid():
		var weakest_family: String = str(_weakest_skill_family_callable.call())
		if not weakest_family.is_empty():
			inferred_from_weakness = CurriculumScript.focus_for_module_family(weakest_family)
			if inferred_from_weakness != "all":
				focus = inferred_from_weakness
	# Consume the cached "what's next" preview if available so the button
	# commits exactly the pick the user saw — otherwise re-roll.
	var pick: Dictionary
	if not _next_daily_pick.is_empty() and int(_next_daily_pick.get("preview_level", -999)) == level and str(_next_daily_pick.get("preview_focus", "")) == focus:
		pick = _next_daily_pick.get("pick", {}) as Dictionary
		_next_daily_pick = {}
	if pick.is_empty():
		pick = CurriculumScript.daily_warmup_pick(level, focus, -1)
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
	# Load is the only entry that's valid with no current exercise — gate
	# the rest behind the "generate first" dialog.
	if id == EXPORT_LOAD_EXERCISE:
		_show_load_exercise_dialog()
		return
	if id == EXPORT_LESSON_SUMMARY:
		var lesson_path: String = _save_lesson_summary_markdown()
		if lesson_path.is_empty():
			_set_export_status("Could not save lesson summary.")
		else:
			_set_export_status("Saved lesson summary: %s" % lesson_path.get_file())
		return
	if id == EXPORT_ANALYTICS:
		_show_analytics_dialog()
		return
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
		EXPORT_SAVE_EXERCISE:
			var saved_path: String = _save_current_exercise_json()
			if saved_path.is_empty():
				_set_export_status("Could not save exercise.")
			else:
				_set_export_status("Saved exercise: %s  (Load via the ... menu)" % saved_path.get_file())


# Serializes _current_exercise to user://saved_exercises/<base>.json so the
# user can reload the exact same generated drill later. Different from the
# PDF / Image exports — this is the data, not a rendered page. Returns the
# saved file path on success, empty string on failure.
func _save_current_exercise_json() -> String:
	if _current_exercise.is_empty():
		return ""
	if not _ensure_saved_exercises_dir():
		return ""
	var base := _export_base_name()
	var path := "%s/%s.exercise.json" % [SAVED_EXERCISES_DIR, base]
	var payload := {
		"schema": "clefira.practice_drill.v1",
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"exercise": _current_exercise,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return path


func _ensure_saved_exercises_dir() -> bool:
	var d := DirAccess.open("user://")
	if d == null:
		return false
	if not d.dir_exists("saved_exercises"):
		var err := d.make_dir("saved_exercises")
		if err != OK and err != ERR_ALREADY_EXISTS:
			return false
	return true


# Pops a dialog listing saved exercise files. Selecting one loads it back
# into _current_exercise and re-renders the staff. Built lazily so the
# dialog widget is only spun up when the user actually opens Load.
func _show_load_exercise_dialog() -> void:
	if _load_exercise_dialog == null:
		_load_exercise_dialog = AcceptDialog.new()
		_load_exercise_dialog.exclusive = false
		_load_exercise_dialog.title = "Load Saved Exercise"
		_load_exercise_dialog.dialog_hide_on_ok = true
		if _dialog_style_callable.is_valid():
			_dialog_style_callable.call(_load_exercise_dialog)
		add_child(_load_exercise_dialog)
	# Rebuild the body each time so newly-saved exercises show up.
	for child in _load_exercise_dialog.get_children():
		if child is VBoxContainer:
			child.queue_free()
	var files := _list_saved_exercise_files()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_load_exercise_dialog.add_child(body)
	if files.is_empty():
		_load_exercise_dialog.dialog_text = "No saved exercises yet.\n\nUse the ... menu → Save Exercise after generating a drill you'd like to reuse."
		_load_exercise_dialog.popup_centered(Vector2(440, 180))
		return
	_load_exercise_dialog.dialog_text = ""
	var hint := Label.new()
	hint.text = "Pick a saved exercise to load it back into the staff."
	if _ui_font != null:
		hint.add_theme_font_override("font", _ui_font)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.82, 0.90, 0.96, 0.78))
	body.add_child(hint)
	# Reverse-chronological — newest first.
	files.reverse()
	for path_str in files:
		var fname: String = path_str.get_file().get_basename()
		# Strip the trailing ".exercise" extension from .exercise.json files.
		if fname.ends_with(".exercise"):
			fname = fname.substr(0, fname.length() - ".exercise".length())
		var row_btn := Button.new()
		row_btn.text = fname
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.focus_mode = Control.FOCUS_NONE
		if _ui_font != null:
			row_btn.add_theme_font_override("font", _ui_font)
		row_btn.add_theme_font_size_override("font_size", 14)
		row_btn.custom_minimum_size = Vector2(420, 30)
		var captured := path_str
		row_btn.pressed.connect(func() -> void:
			_load_exercise_dialog.hide()
			_load_exercise_from_path(captured)
		)
		body.add_child(row_btn)
	_load_exercise_dialog.popup_centered(Vector2(480, mini(420, 80 + files.size() * 38)))


func _list_saved_exercise_files() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(SAVED_EXERCISES_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(".json"):
			out.append("%s/%s" % [SAVED_EXERCISES_DIR, name])
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func _load_exercise_from_path(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_set_export_status("Could not open: %s" % path.get_file())
		return
	var content := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		_set_export_status("Saved exercise is malformed: %s" % path.get_file())
		return
	var d: Dictionary = parsed as Dictionary
	var exercise_v: Variant = d.get("exercise", null)
	if not (exercise_v is Dictionary):
		_set_export_status("No exercise payload in: %s" % path.get_file())
		return
	stop_playback(true)
	_current_exercise = (exercise_v as Dictionary).duplicate(true)
	_current_seed = int(_current_exercise.get("seed", -1))
	if _title_label != null:
		_title_label.text = _plain_dash_text(str(_current_exercise.get("title", "")))
	if _tempo_label != null:
		_tempo_label.text = "♩ = %d" % int(_current_exercise.get("tempo_bpm", 60))
	_refresh_day_chips()
	_refresh_contextual_hint()
	_refresh_active_state()
	_refresh_empty_state()
	_refresh_score_renderer()
	if _status_label != null:
		_status_label.text = "Loaded: %s" % path.get_file()


# --- Exercise building / score refresh ---


func _staff_mode() -> String:
	if _staff_option == null:
		return "grand"
	match _staff_option.selected:
		1: return "treble"
		2: return "bass"
		_: return "grand"


func _plain_dash_text(text: String) -> String:
	return text.replace("—", "-").replace("–", "-").replace("−", "-")


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


# --- Custom presets (Feat v2 item 17) ---


# Loads user-saved presets from disk and merges them into the preset
# dropdown. Called from present() so newly-saved presets appear without a
# restart.
func _load_and_apply_custom_presets() -> void:
	_custom_presets = []
	var f := FileAccess.open(CUSTOM_PRESETS_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Array:
			for entry_any in (parsed as Array):
				if entry_any is Dictionary:
					_custom_presets.append((entry_any as Dictionary).duplicate(true))
	_refresh_preset_dropdown()


func _refresh_preset_dropdown() -> void:
	if _preset_option == null:
		return
	var prev_idx := _preset_option.selected
	_preset_option.clear()
	for preset in DRILL_PRESETS:
		_preset_option.add_item(str(preset["label"]))
	if not _custom_presets.is_empty():
		_preset_option.add_separator("— Your Presets —")
	for custom in _custom_presets:
		_preset_option.add_item("★ %s" % str(custom.get("label", "Untitled")))
	_preset_option.add_separator("— Manage —")
	# Special items at the end — use negative metadata sentinels.
	var save_idx := _preset_option.item_count
	_preset_option.add_item("💾 Save current as preset")
	_preset_option.set_item_metadata(save_idx, "__save__")
	if prev_idx >= 0 and prev_idx < _preset_option.item_count:
		_preset_option.selected = clampi(prev_idx, 0, _preset_option.item_count - 1)


# Returns the resolved preset for a given selected idx, handling both
# built-in DRILL_PRESETS entries and custom user-saved entries. Save sentinel
# is treated separately by the caller.
func _resolve_preset_from_selection(idx: int) -> Dictionary:
	if idx < 0:
		return {}
	if idx < DRILL_PRESETS.size():
		return DRILL_PRESETS[idx]
	# Skip the "— Your Presets —" separator at DRILL_PRESETS.size() if
	# customs exist.
	var cursor := DRILL_PRESETS.size()
	if not _custom_presets.is_empty():
		cursor += 1  # separator
		for custom in _custom_presets:
			if cursor == idx:
				return custom as Dictionary
			cursor += 1
	# "— Manage —" separator
	cursor += 1
	if cursor == idx:
		# This is the Save sentinel
		return {"__action": "save"}
	return {}


func _save_current_settings_as_preset() -> void:
	if _save_preset_dialog == null:
		_save_preset_dialog = AcceptDialog.new()
		_save_preset_dialog.title = "Save Preset"
		_save_preset_dialog.ok_button_text = "Save"
		_save_preset_dialog.add_cancel_button("Cancel")
		if _dialog_style_callable.is_valid():
			_dialog_style_callable.call(_save_preset_dialog)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		_save_preset_dialog.add_child(body)
		var hint := Label.new()
		hint.text = "Name this preset (current Focus + Level + Hand will be saved):"
		if _ui_font != null:
			hint.add_theme_font_override("font", _ui_font)
		hint.add_theme_font_size_override("font_size", 14)
		body.add_child(hint)
		_save_preset_name_edit = LineEdit.new()
		_save_preset_name_edit.placeholder_text = "e.g., My Warmup"
		_save_preset_name_edit.custom_minimum_size = Vector2(320, 32)
		body.add_child(_save_preset_name_edit)
		_save_preset_dialog.confirmed.connect(_on_save_preset_confirmed)
		add_child(_save_preset_dialog)
	_save_preset_name_edit.text = ""
	_save_preset_dialog.popup_centered(Vector2(420, 160))


func _on_save_preset_confirmed() -> void:
	if _save_preset_name_edit == null:
		return
	var name := _save_preset_name_edit.text.strip_edges()
	if name.is_empty():
		return
	var skill_id := _current_skill_filter
	var lvl: int = int(_level_spin.value) if _level_spin != null else 3
	var hand_mode := _staff_mode()
	_custom_presets.append({
		"label": name,
		"skill": skill_id,
		"level": lvl,
		"hand_mode": hand_mode,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	})
	var f := FileAccess.open(CUSTOM_PRESETS_PATH, FileAccess.WRITE)
	var persisted := false
	if f != null:
		f.store_string(JSON.stringify(_custom_presets, "\t"))
		f.close()
		persisted = true
	_refresh_preset_dropdown()
	if _status_label != null:
		if persisted:
			_status_label.text = "Saved preset: %s" % name
		else:
			# Write failed — the preset works this session but won't survive a
			# restart; tell the user instead of claiming it saved.
			_status_label.text = "Couldn't save preset to disk (available this session only)."


# --- Lesson summary (Feat 10) — aggregates today's history into a
# Markdown report a teacher can read at a glance. ---


# Feat 5 — Performance analytics. Aggregates the existing drill history
# JSON into a compact dialog: total drills, average accuracy across
# graded plays, weakest 5 items (avg accuracy < 70%), time spent today
# vs all-time, last-practiced exercise. No new tracking infrastructure —
# pure read-side over what _append_drill_history_entry already writes.
func _show_analytics_dialog() -> void:
	if _analytics_dialog == null:
		_analytics_dialog = AcceptDialog.new()
		_analytics_dialog.exclusive = false
		_analytics_dialog.title = "Performance Analytics"
		if _dialog_style_callable.is_valid():
			_dialog_style_callable.call(_analytics_dialog)
		add_child(_analytics_dialog)
	# Rebuild body each time so it picks up newly-completed drills.
	for child in _analytics_dialog.get_children():
		if child is VBoxContainer:
			child.queue_free()
	var history := _load_drill_history()
	if history.is_empty():
		_analytics_dialog.dialog_text = "No drill history yet.\n\nComplete a drill (press Play through to the end) and the analytics will populate here."
		_analytics_dialog.popup_centered(Vector2(440, 200))
		return
	_analytics_dialog.dialog_text = ""
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	_analytics_dialog.add_child(body)
	# --- Aggregates ---
	var total_drills: int = history.size()
	var total_sec: float = 0.0
	var sec_today: float = 0.0
	var drills_today: int = 0
	var graded_count: int = 0
	var graded_sum: float = 0.0
	var per_exercise: Dictionary = {}  # title → {count, graded_count, graded_sum, avg_tempo_sum, last_unix}
	var last_unix: int = 0
	var last_title: String = ""
	for entry_any in history:
		var entry: Dictionary = entry_any
		var ts: int = int(entry.get("unix", 0))
		total_sec += float(entry.get("elapsed_sec", 0.0))
		var entry_dt := Time.get_date_dict_from_unix_time(ts)
		var entry_iso := "%04d-%02d-%02d" % [int(entry_dt.year), int(entry_dt.month), int(entry_dt.day)]
		if entry_iso == _today_iso():
			sec_today += float(entry.get("elapsed_sec", 0.0))
			drills_today += 1
		var acc: float = float(entry.get("accuracy", -1.0))
		if acc >= 0.0:
			graded_count += 1
			graded_sum += acc
		var title: String = str(entry.get("title", "Untitled"))
		if not per_exercise.has(title):
			per_exercise[title] = {"count": 0, "graded_count": 0, "graded_sum": 0.0, "tempo_sum": 0.0, "last_unix": 0}
		var row: Dictionary = per_exercise[title]
		row["count"] = int(row["count"]) + 1
		row["tempo_sum"] = float(row["tempo_sum"]) + float(entry.get("bpm", 0))
		if acc >= 0.0:
			row["graded_count"] = int(row["graded_count"]) + 1
			row["graded_sum"] = float(row["graded_sum"]) + acc
		if ts > int(row["last_unix"]):
			row["last_unix"] = ts
		if ts > last_unix:
			last_unix = ts
			last_title = title
	# --- Render summary lines ---
	_analytics_add_line(body, "Total drills played:  %d" % total_drills)
	_analytics_add_line(body, "Time today / all-time:  %s  /  %s" % [_fmt_dur(sec_today), _fmt_dur(total_sec)])
	_analytics_add_line(body, "Drills today:  %d" % drills_today)
	if graded_count > 0:
		var avg_pct: int = int(round((graded_sum / float(graded_count)) * 100.0))
		_analytics_add_line(body, "Avg accuracy (%d graded plays):  %d%%" % [graded_count, avg_pct])
	else:
		_analytics_add_line(body, "Avg accuracy:  (no graded plays — connect a MIDI keyboard)")
	if not last_title.is_empty():
		_analytics_add_line(body, "Last practiced:  %s" % last_title)
	# --- Weakest items (avg accuracy < 70%, sorted ascending) ---
	var weak_rows: Array = []
	for title_any in per_exercise.keys():
		var row2: Dictionary = per_exercise[title_any]
		if int(row2["graded_count"]) == 0:
			continue
		var avg: float = float(row2["graded_sum"]) / float(row2["graded_count"])
		if avg < 0.7:
			weak_rows.append({"title": str(title_any), "avg": avg, "count": int(row2["count"])})
	weak_rows.sort_custom(func(a, b): return float(a["avg"]) < float(b["avg"]))
	if not weak_rows.is_empty():
		_analytics_add_header(body, "Needs more work")
		for i in range(mini(5, weak_rows.size())):
			var w: Dictionary = weak_rows[i]
			_analytics_add_line(body, "  • %s — %d%% over %d plays" % [
				str(w["title"]), int(round(float(w["avg"]) * 100.0)), int(w["count"])
			])
	# --- Per-exercise breakdown (top 8 by play count) ---
	var by_count: Array = []
	for title_any in per_exercise.keys():
		var row3: Dictionary = per_exercise[title_any]
		by_count.append({
			"title": str(title_any),
			"count": int(row3["count"]),
			"avg_tempo": float(row3["tempo_sum"]) / maxf(1.0, float(row3["count"])),
		})
	by_count.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	if not by_count.is_empty():
		_analytics_add_header(body, "Most-played exercises")
		for i in range(mini(8, by_count.size())):
			var r: Dictionary = by_count[i]
			_analytics_add_line(body, "  • %s — %d plays  ·  avg ♩ = %d bpm" % [
				str(r["title"]), int(r["count"]), int(round(float(r["avg_tempo"])))
			])
	_analytics_dialog.popup_centered(Vector2(560, mini(620, 120 + body.get_child_count() * 22)))


func _analytics_add_line(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0, 0.94))
	parent.add_child(lbl)


func _analytics_add_header(parent: VBoxContainer, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	parent.add_child(spacer)
	var lbl := Label.new()
	lbl.text = text
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62, 1.0))
	parent.add_child(lbl)


func _fmt_dur(seconds: float) -> String:
	var mm: int = int(seconds) / 60
	var ss: int = int(seconds) % 60
	if mm == 0:
		return "%ds" % ss
	return "%dm %02ds" % [mm, ss]


func _save_lesson_summary_markdown() -> String:
	if not _ensure_export_dir():
		return ""
	var history := _load_drill_history()
	var today_iso := _today_iso()
	var today_entries: Array = []
	for entry_any in history:
		var entry: Dictionary = entry_any
		var entry_dt := Time.get_date_dict_from_unix_time(int(entry.get("unix", 0)))
		var entry_iso := "%04d-%02d-%02d" % [int(entry_dt.year), int(entry_dt.month), int(entry_dt.day)]
		if entry_iso == today_iso:
			today_entries.append(entry)
	var lines := PackedStringArray()
	lines.append("# Practice Drills — Lesson Summary")
	lines.append("")
	lines.append("**Date:** %s" % today_iso)
	lines.append("")
	if today_entries.is_empty():
		lines.append("_No drills completed today._")
	else:
		var total_notes: int = 0
		var total_sec: float = 0.0
		var graded_count: int = 0
		var graded_sum: float = 0.0
		var weak_items: Dictionary = {}
		for entry_any in today_entries:
			var entry: Dictionary = entry_any
			total_notes += int(entry.get("notes", 0))
			total_sec += float(entry.get("elapsed_sec", 0.0))
			var acc: float = float(entry.get("accuracy", -1.0))
			if acc >= 0.0:
				graded_count += 1
				graded_sum += acc
				if acc < 0.7:
					var title: String = str(entry.get("title", "Untitled"))
					weak_items[title] = int(weak_items.get(title, 0)) + 1
		lines.append("**Drills completed:** %d" % today_entries.size())
		var mm: int = int(total_sec) / 60
		var ss: int = int(total_sec) % 60
		lines.append("**Total practice time:** %d:%02d" % [mm, ss])
		lines.append("**Total notes played:** %d" % total_notes)
		if graded_count > 0:
			var avg_pct: int = int(round((graded_sum / float(graded_count)) * 100.0))
			lines.append("**Average accuracy (graded plays):** %d%%" % avg_pct)
		else:
			lines.append("_(No graded plays today — connect a MIDI keyboard to log accuracy.)_")
		lines.append("")
		if not weak_items.is_empty():
			lines.append("## Needs more work")
			for title_any in weak_items.keys():
				lines.append("- %s _(low accuracy %d×)_" % [str(title_any), int(weak_items[title_any])])
			lines.append("")
		lines.append("## Drills played")
		for entry_any in today_entries:
			var entry: Dictionary = entry_any
			var ts: int = int(entry.get("unix", 0))
			var dt := Time.get_datetime_dict_from_unix_time(ts)
			var when := "%02d:%02d" % [int(dt.hour), int(dt.minute)]
			var title: String = str(entry.get("title", ""))
			var key_letter := ChordExplorerTheoryScript.key_pc_to_letter(int(entry.get("key_pc", 0)))
			var key_str := "%s %s" % [key_letter, "minor" if bool(entry.get("key_is_minor", false)) else "major"]
			var bpm: int = int(entry.get("bpm", 0))
			var acc: float = float(entry.get("accuracy", -1.0))
			var acc_str := ""
			if acc >= 0.0:
				acc_str = "  ·  %d%% accuracy" % int(round(acc * 100.0))
			lines.append("- **%s** — %s in %s  ·  ♩=%d%s" % [when, title, key_str, bpm, acc_str])
		lines.append("")
		if not _next_daily_pick.is_empty():
			var pick: Dictionary = _next_daily_pick.get("pick", {}) as Dictionary
			if not pick.is_empty():
				var nx_id := str(pick.get("exercise_id", ""))
				var nx_kp := int(pick.get("key_pc", 0))
				var nx_min := bool(pick.get("key_is_minor", false))
				lines.append("## Recommended next drill")
				lines.append("- %s in %s %s" % [
					ExerciseLibraryScript.display_name(nx_id),
					ChordExplorerTheoryScript.key_pc_to_letter(nx_kp),
					"minor" if nx_min else "major",
				])
				lines.append("")
	lines.append("---")
	lines.append("_Generated by Clefira Practice Drills._")
	var path := "user://exports/lesson_summary_%s.md" % today_iso
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string("\n".join(lines))
	f.close()
	return path


# --- Drill history (Feat v2 item 20) ---


func _append_drill_history_entry(elapsed_sec: float, notes_count: int, bpm: int, accuracy: float = -1.0) -> void:
	if _current_exercise.is_empty():
		return
	var history := _load_drill_history()
	var entry := {
		"unix": int(Time.get_unix_time_from_system()),
		"title": str(_current_exercise.get("title", "")),
		"exercise_id": str(_current_exercise.get("exercise_id", "")),
		"key_pc": int(_current_exercise.get("key_pc", 0)),
		"key_is_minor": bool(_current_exercise.get("key_is_minor", false)),
		"bpm": bpm,
		"notes": notes_count,
		"elapsed_sec": elapsed_sec,
		"was_daily": _current_exercise_is_daily,
		"accuracy": accuracy,
	}
	history.append(entry)
	# Cap so the file doesn't grow forever — newest entries are kept.
	if history.size() > DRILL_HISTORY_MAX_ENTRIES:
		history = history.slice(history.size() - DRILL_HISTORY_MAX_ENTRIES, history.size())
	var f := FileAccess.open(DRILL_HISTORY_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(history))
		f.close()


func _load_drill_history() -> Array:
	var f := FileAccess.open(DRILL_HISTORY_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		return (parsed as Array).duplicate(true)
	return []


func _on_history_pressed() -> void:
	if _history_dialog == null:
		_history_dialog = AcceptDialog.new()
		_history_dialog.title = "Drill History"
		_history_dialog.exclusive = false
		if _dialog_style_callable.is_valid():
			_dialog_style_callable.call(_history_dialog)
		add_child(_history_dialog)
	# Rebuild body each time so newly-completed drills show.
	for child in _history_dialog.get_children():
		if child is VBoxContainer:
			child.queue_free()
	var history := _load_drill_history()
	if history.is_empty():
		_history_dialog.dialog_text = "No completed drills yet.\n\nFinish a drill (press Play through to the end) and it'll show up here with timestamp + tempo."
		_history_dialog.popup_centered(Vector2(460, 180))
		return
	_history_dialog.dialog_text = ""
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_history_dialog.add_child(body)
	var hint := Label.new()
	hint.text = "Recent completed drills"
	if _ui_font != null:
		hint.add_theme_font_override("font", _ui_font)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0, 0.90))
	body.add_child(hint)
	# Newest first, cap shown rows for the dialog.
	history.reverse()
	var shown := 0
	for entry_any in history:
		if shown >= 5:
			break
		var entry: Dictionary = entry_any
		var ts: int = int(entry.get("unix", 0))
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		var when_str := "%04d-%02d-%02d  %02d:%02d" % [int(dt.year), int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]
		var title: String = str(entry.get("title", ""))
		var bpm: int = int(entry.get("bpm", 0))
		var notes: int = int(entry.get("notes", 0))
		var key_letter := ChordExplorerTheoryScript.key_pc_to_letter(int(entry.get("key_pc", 0)))
		var key_str := "%s %s" % [key_letter, "minor" if bool(entry.get("key_is_minor", false)) else "major"]
		var prefix := "★" if bool(entry.get("was_daily", false)) else " "
		var row := PanelContainer.new()
		var row_style := _stylebox(Color(0.08, 0.15, 0.24, 0.92), Color(0.30, 0.56, 0.88, 0.32), 8, 1, 0)
		row.add_theme_stylebox_override("panel", row_style)
		var row_box := VBoxContainer.new()
		row_box.add_theme_constant_override("separation", 1)
		row.add_child(row_box)
		var row_title := Label.new()
		row_title.text = "%s  %s" % [prefix, title]
		if _ui_font != null:
			row_title.add_theme_font_override("font", _ui_font)
		row_title.add_theme_font_size_override("font_size", 13)
		row_title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 0.96))
		row_box.add_child(row_title)
		var row_meta := Label.new()
		row_meta.text = "%s   ·   ♩=%d   ·   %d notes   ·   %s" % [when_str, bpm, notes, key_str]
		if _ui_font != null:
			row_meta.add_theme_font_override("font", _ui_font)
		row_meta.add_theme_font_size_override("font_size", 11)
		row_meta.add_theme_color_override("font_color", Color(0.78, 0.87, 0.96, 0.84))
		row_box.add_child(row_meta)
		body.add_child(row)
		shown += 1
	_history_dialog.popup_centered(Vector2(660, mini(360, 140 + shown * 56)))


# Daily Warmup post-processor: musically smart ending rules per user spec.
#
#   If the last note IS a tonic-triad tone (root/3rd/5th):
#     • Extend its duration so it reaches the next bar line (no extra note).
#     • If it already lands on the bar line, leave it alone — already
#       resolved (e.g., a quarter on beat 4 of 4/4 stays a quarter).
#   If the last note is NOT a triad tone:
#     • Has remaining beats in its bar?  → Append a root-triad note at
#       last_end with duration = remaining-in-bar (so e.g. a non-triad
#       eighth at beat 3.5 gets a tonic eighth on beat 3.5–4.0).
#     • Ended exactly on a bar line?     → Append a whole-bar tonic in the
#       NEXT bar.
#
# Mutates _current_exercise in place; touches notes, total_beats, and the
# per-hand caches used by the grand-staff renderer.
func _append_tonic_resolution_to_current_exercise() -> void:
	if _current_exercise.is_empty():
		return
	var notes: Array = _current_exercise.get("notes", [])
	if notes.is_empty():
		return
	var key_pc: int = int(_current_exercise.get("key_pc", 0))
	var key_is_minor: bool = bool(_current_exercise.get("key_is_minor", false))
	var time_num: int = max(1, int(_current_exercise.get("time_sig_num", 4)))
	var time_den: int = max(1, int(_current_exercise.get("time_sig_den", 4)))
	var beats_per_bar: float = float(time_num) * (4.0 / float(time_den))
	var staff_mode := str(_current_exercise.get("staff_mode", "treble"))
	if staff_mode == "grand":
		var rh: Array = (_current_exercise.get("right_hand_notes", []) as Array).duplicate(true)
		var lh: Array = (_current_exercise.get("left_hand_notes", []) as Array).duplicate(true)
		NotationRulesScript.apply_tonic_resolution_inplace(rh, key_pc, key_is_minor, beats_per_bar, 1, 1)
		NotationRulesScript.apply_tonic_resolution_inplace(lh, key_pc, key_is_minor, beats_per_bar, 2, 2)
		_current_exercise["right_hand_notes"] = rh
		_current_exercise["left_hand_notes"] = lh
		var combined: Array = []
		combined.append_array(_notes_for_staff(rh, 1, 1))
		combined.append_array(_notes_for_staff(lh, 2, 2))
		combined.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _sort_notes_by_time_and_staff(a, b)
		)
		_current_exercise["notes"] = combined
	else:
		var staff_id: int = 2 if staff_mode == "bass" else 1
		var voice_id: int = 2 if staff_mode == "bass" else 1
		var out_notes: Array = notes.duplicate(true)
		NotationRulesScript.apply_tonic_resolution_inplace(out_notes, key_pc, key_is_minor, beats_per_bar, staff_id, voice_id)
		_current_exercise["notes"] = out_notes
	# Recompute total_beats from the final notes array.
	var final_end: float = 0.0
	for note_any in _current_exercise.get("notes", []):
		var n: Dictionary = note_any
		var e: float = float(n.get("beat_offset", 0.0)) + float(n.get("duration_beats", 0.0))
		if e > final_end:
			final_end = e
	_current_exercise["total_beats"] = final_end


# Applies the resolution rules to a single staff array in place.
#
# Triad-tone endings (root / 3rd / 5th):
#   • Already lands on a bar line → leave alone (e.g. quarter on beat 4 of
#     4/4 stays a quarter).
#   • Else → extend duration by the predominant-note tier (≈ doubling),
#     capped at the bar line. So in a quarter-note piece, a triad on
#     beat 2 becomes a HALF note (not a dotted-half-to-bar); in an
#     eighth-note piece, a triad on the second half of beat 4 becomes a
#     quarter and lands on the bar line.
#
# Non-triad endings:
#   • Remaining beats left in current bar → append a root-triad note for
#     just the remaining duration.
#   • Ended exactly on bar line → append a whole-bar tonic in the next bar.
func _apply_tonic_resolution_inplace(staff_notes: Array, key_pc: int, key_is_minor: bool, beats_per_bar: float, staff: int, voice: int) -> void:
	var last_idx := -1
	for i in range(staff_notes.size() - 1, -1, -1):
		var n: Dictionary = staff_notes[i]
		if int(n.get("midi", -1)) >= 0 and not bool(n.get("rest", false)):
			last_idx = i
			break
	if last_idx < 0:
		return
	var last: Dictionary = staff_notes[last_idx]
	var last_midi: int = int(last["midi"])
	var last_start: float = float(last.get("beat_offset", 0.0))
	var last_dur: float = float(last.get("duration_beats", 0.0))
	var last_end: float = last_start + last_dur
	var tonic_pc: int = ((key_pc % 12) + 12) % 12
	var third_pc: int = (tonic_pc + (3 if key_is_minor else 4)) % 12
	var fifth_pc: int = (tonic_pc + 7) % 12
	var last_pc: int = ((last_midi % 12) + 12) % 12
	var is_triad_tone: bool = (last_pc == tonic_pc or last_pc == third_pc or last_pc == fifth_pc)
	if is_triad_tone:
		var bar_line: float = ceil(last_end / beats_per_bar) * beats_per_bar
		var remaining_to_bar: float = bar_line - last_start
		if absf(bar_line - last_end) <= 0.001:
			return  # Already lands on bar line — keep as-is.
		# Extend by one note-value tier (≈ doubling). Cap so we don't
		# cross the bar line. Never shrink. The "or extend further to
		# reach the bar" exception fires only when one-tier doubling
		# would leave a remainder smaller than the original duration
		# (i.e. the note is already most of the way to the bar line —
		# in that case fill the remainder instead of leaving a tiny gap).
		var tier_target: float = last_dur * 2.0
		var extended: float = min(tier_target, remaining_to_bar)
		if remaining_to_bar - extended < last_dur and remaining_to_bar <= last_dur * 3.0 + 0.001:
			extended = remaining_to_bar
		extended = max(extended, last_dur)
		if extended - last_dur > 0.001:
			staff_notes[last_idx]["duration_beats"] = extended
		return
	# Non-triad: append a tonic to fill the bar OR start a new whole-bar one.
	var current_bar_end: float = ceil(last_end / beats_per_bar) * beats_per_bar
	if current_bar_end - last_end < 0.001:
		var new_bar_start: float = current_bar_end
		staff_notes.append(_make_tonic_note(key_pc, last_midi, new_bar_start, beats_per_bar, staff, voice))
	else:
		var remaining: float = current_bar_end - last_end
		staff_notes.append(_make_tonic_note(key_pc, last_midi, last_end, remaining, staff, voice))


# Builds a single tonic-resolution note dict in the same shape the exercise
# generator emits. Voiced near reference_midi so the resolution doesn't jump
# octaves away from the last note the hand played.
func _make_tonic_note(key_pc: int, reference_midi: int, beat_offset: float, duration_beats: float, staff: int, voice: int) -> Dictionary:
	var pc := ((key_pc % 12) + 12) % 12
	var ref_pc := ((reference_midi % 12) + 12) % 12
	# Step the reference down to its tonic in the same octave.
	var down_steps := ((ref_pc - pc) + 12) % 12
	var tonic_below := reference_midi - down_steps
	var tonic_above := tonic_below + 12
	var pick_above := (reference_midi - tonic_below) > (tonic_above - reference_midi)
	var tonic_midi: int = tonic_above if pick_above else tonic_below
	return {
		"midi": tonic_midi,
		"beat_offset": beat_offset,
		"duration_beats": duration_beats,
		"staff": staff,
		"voice": voice,
		"fingering": 0,
	}


# --- UI-upgrade helpers (chip row + Info popover) ---


# Builds a compact pill-style label used in the day-goal chip row.
# A chip that leads with the custom bullseye icon (assets/icons/bullseye.svg)
# instead of the 🎯 emoji glyph. Returns the wrapping PanelContainer; the inner
# Label is stored in its "chip_label" meta so callers can update .text.
func _build_bullseye_chip(text: String, icon_path: String = BULLSEYE_ICON_PATH, icon_size: int = 18) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := _stylebox(Color(0.10, 0.17, 0.27, 0.78), Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.42), 14, 1, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var lbl := Label.new()
	lbl.text = text
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0, 0.96))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	panel.set_meta("chip_label", lbl)
	return panel


func _build_chip_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(0, 28)
	if _ui_font != null:
		lbl.add_theme_font_override("font", _ui_font)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0, 0.96))
	var sb := _stylebox(Color(0.10, 0.17, 0.27, 0.78), Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.42), 14, 1, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl


# Refreshes the Target + Tempo chips from _current_exercise. Called after
# Generate / Daily Warmup. Streak chip stays hidden until practice-drill
# streak tracking is wired in.
func _refresh_day_chips() -> void:
	if _chip_target_label == null:
		return
	if _current_exercise.is_empty():
		_chip_target_label.text = "Pick an exercise"
		if _chip_tempo_label != null:
			_chip_tempo_label.text = "♩  ---"
		if _chip_assignment_label != null:
			_chip_assignment_label.visible = false
		return
	var title: String = str(_current_exercise.get("title", "")).strip_edges()
	if title.is_empty():
		var ex_id: String = str(_current_exercise.get("exercise_id", "exercise"))
		title = ExerciseLibraryScript.display_name(ex_id)
	_chip_target_label.text = title
	if _chip_tempo_label != null:
		var bpm: int = int(_current_exercise.get("tempo_bpm", 60))
		_chip_tempo_label.text = "♩  %d bpm" % bpm
	# Feat 4 — assignment badge. Asks the host whether an open
	# practice-drill assignment matches the loaded exercise_id.
	_refresh_assignment_chip()


func _refresh_assignment_chip() -> void:
	if _chip_assignment_label == null:
		return
	if not _open_assignment_lookup_callable.is_valid() or _current_exercise.is_empty():
		_chip_assignment_label.visible = false
		return
	var ex_id := str(_current_exercise.get("exercise_id", ""))
	if ex_id.is_empty():
		_chip_assignment_label.visible = false
		return
	var assignment_v: Variant = _open_assignment_lookup_callable.call(ex_id)
	if not (assignment_v is Dictionary) or (assignment_v as Dictionary).is_empty():
		_chip_assignment_label.visible = false
		return
	var a: Dictionary = assignment_v as Dictionary
	var due_str: String = str(a.get("due", ""))
	var due_suffix := ""
	if not due_str.is_empty():
		due_suffix = "  (due %s)" % due_str
	_chip_assignment_label.text = "★  Assigned by your teacher%s" % due_suffix
	_chip_assignment_label.visible = true


# Info popover: dumps the diagnostic detail that used to live in the
# verbose status label (notes count, generator id, seed, total beats, key).
# Trimming the status row keeps the UI calm; the data still ships, just
# one click away.
func _on_info_pressed() -> void:
	if _info_dialog == null:
		_info_dialog = AcceptDialog.new()
		_info_dialog.exclusive = false
		_info_dialog.title = "Exercise Info"
		if _dialog_style_callable.is_valid():
			_dialog_style_callable.call(_info_dialog)
		add_child(_info_dialog)
	var body := _build_info_body_text()
	_info_dialog.dialog_text = body
	_info_dialog.popup_centered(Vector2(420, 220))


func _build_info_body_text() -> String:
	if _current_exercise.is_empty():
		return "No exercise generated yet. Pick options + Generate, or hit Start Daily Drill."
	var playable_notes := 0
	var total_notes := 0
	for note_any in _current_exercise.get("notes", []):
		var note: Dictionary = note_any
		total_notes += 1
		if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
			playable_notes += 1
	var bpm: int = int(_current_exercise.get("tempo_bpm", 60))
	var total_beats: float = float(_current_exercise.get("total_beats", 0.0))
	var time_num: int = int(_current_exercise.get("time_sig_num", 4))
	var time_den: int = int(_current_exercise.get("time_sig_den", 4))
	var roll_seed: int = int(_current_exercise.get("seed", _current_seed))
	var roll_gen: String = str(_current_exercise.get("generator_id", ""))
	var key_pc: int = int(_current_exercise.get("key_pc", 0))
	var key_is_minor: bool = bool(_current_exercise.get("key_is_minor", false))
	var key_letter := ChordExplorerTheoryScript.key_pc_to_letter(key_pc)
	var lines := PackedStringArray()
	lines.append("Title: %s" % str(_current_exercise.get("title", "")))
	lines.append("Key:   %s %s" % [key_letter, "minor" if key_is_minor else "major"])
	lines.append("Tempo: ♩ = %d bpm" % bpm)
	lines.append("Meter: %d/%d   ·   Total beats: %.1f" % [time_num, time_den, total_beats])
	lines.append("Notes: %d playable  (%d total events incl. rests)" % [playable_notes, total_notes])
	if not roll_gen.is_empty():
		lines.append("Roll:  %s" % roll_gen)
	lines.append("Seed:  %d" % roll_seed)
	return "\n".join(lines)


# --- v2 helpers ---


# Keyboard shortcuts (feature item 19 — accessibility). Only active while
# the panel is visible. Picked single-letter keys so they don't clash with
# common edit shortcuts; Space toggles playback.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# Ignore when an editable control (SpinBox / line edit) has focus —
	# otherwise R/G/D/M while typing in a SpinBox would steal the key.
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and (focus is LineEdit or focus is SpinBox):
		return
	match key_event.keycode:
		KEY_SPACE:
			if _playback_active:
				_on_stop_pressed()
			else:
				_on_play_pressed()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reroll_pressed()
			get_viewport().set_input_as_handled()
		KEY_G:
			_on_generate_pressed()
			get_viewport().set_input_as_handled()
		KEY_D:
			_on_daily_warmup_pressed()
			get_viewport().set_input_as_handled()
		KEY_M:
			if _metronome_check != null:
				_metronome_check.button_pressed = not _metronome_check.button_pressed
			get_viewport().set_input_as_handled()


# --- MIDI grading pipeline (Feat 3/8/12/14, UI 14/16) ---
#
# We open MIDI inputs at play start, capture every note-on event with its
# usec timestamp, then at finish match captures to the exercise's expected
# notes within a per-tempo timing window. Each matched expected event is
# either "hit" (correct pitch within window) or "missed" (no input).
# Unmatched captures are "extras".


# Pitch-class match window — accept octave-equivalent matches when the
# captured pitch is within ±2 octaves of the expected. (Keep it strict on
# pitch class so a wrong note doesn't count.)
const GRADING_OCTAVE_TOLERANCE: int = 2


# Open MIDI inputs and start a fresh capture buffer.
func _start_midi_grading() -> void:
	_midi_captures.clear()
	_last_judgements = {}
	_last_accuracy = -1.0
	if not _midi_inputs_opened_locally:
		OS.open_midi_inputs()
		_midi_inputs_opened_locally = true
	_midi_grading_active = true
	set_process_input(true)


func _stop_midi_grading() -> void:
	_midi_grading_active = false


# Capture MIDI note-on events while a play is active. Other InputEventMIDI
# variants (note-off, CC, pitch-bend) are ignored. Velocity 0 also treated
# as note-off per the MIDI spec.
func _input(event: InputEvent) -> void:
	if not _midi_grading_active:
		return
	if not (event is InputEventMIDI):
		return
	var m := event as InputEventMIDI
	if m.message != MIDI_MESSAGE_NOTE_ON or m.velocity <= 0:
		return
	var bpm: float = float(_current_exercise.get("tempo_bpm", 80))
	var seconds_per_beat: float = 60.0 / maxf(40.0, bpm)
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_sec: float = float(now_usec - _last_play_start_usec) / 1_000_000.0
	var beat: float = elapsed_sec / seconds_per_beat
	_midi_captures.append({
		"usec": now_usec,
		"midi": int(m.pitch),
		"beat": beat,
	})


# Match captures to the exercise events. Returns:
#   { accuracy, hits, misses, extras, missed_pitches, judgements }
# `judgements` maps expected MIDI → "hit" / "missed" for the keyboard
# inline feedback. Returns accuracy = -1.0 if no captures arrived at all
# (no MIDI device or user just listened — don't penalize either way).
func _score_midi_captures_against_exercise() -> Dictionary:
	var result := {
		"accuracy": -1.0,
		"hits": 0,
		"misses": 0,
		"extras": 0,
		"missed_pitches": [],
		"judgements": {},
	}
	if _current_exercise.is_empty():
		return result
	# Expected events flattened: each entry { beat, midi, expected_idx }.
	var expected: Array = []
	for note_any in _current_exercise.get("notes", []):
		var note: Dictionary = note_any
		if int(note.get("midi", -1)) < 0 or bool(note.get("rest", false)):
			continue
		expected.append({
			"beat": float(note.get("beat_offset", 0.0)),
			"midi": int(note.get("midi", -1)),
			"matched": false,
		})
	if expected.is_empty():
		return result
	# No captures → if user pressed Play with no MIDI device, don't penalize.
	# Return accuracy=-1 so the UI can show "play to grade" instead.
	if _midi_captures.is_empty():
		return result
	var bpm: float = float(_current_exercise.get("tempo_bpm", 80))
	# Timing window scales with tempo: half a beat at 80 bpm is ~0.375 s,
	# which is a fair "did the user hit it on this note" window for casual
	# practice. Tighten if you want strict.
	var window_beats: float = 0.5
	var captures_used: Dictionary = {}
	var judgements: Dictionary = {}
	var hits: int = 0
	var missed_pitches: Array = []
	for i in range(expected.size()):
		var ev: Dictionary = expected[i]
		var ev_beat: float = float(ev["beat"])
		var ev_midi: int = int(ev["midi"])
		var ev_pc: int = ((ev_midi % 12) + 12) % 12
		var matched := false
		for ci in range(_midi_captures.size()):
			if captures_used.has(ci):
				continue
			var cap: Dictionary = _midi_captures[ci]
			var cap_midi: int = int(cap["midi"])
			var cap_pc: int = ((cap_midi % 12) + 12) % 12
			if cap_pc != ev_pc:
				continue
			if absi(cap_midi - ev_midi) > GRADING_OCTAVE_TOLERANCE * 12:
				continue
			if absf(float(cap["beat"]) - ev_beat) > window_beats:
				continue
			captures_used[ci] = true
			matched = true
			break
		if matched:
			hits += 1
			judgements[ev_midi] = "hit"
		else:
			if not judgements.has(ev_midi):
				judgements[ev_midi] = "missed"
			missed_pitches.append(ev_midi)
	var extras: int = _midi_captures.size() - captures_used.size()
	var accuracy: float = float(hits) / float(expected.size())
	result["accuracy"] = accuracy
	result["hits"] = hits
	result["misses"] = expected.size() - hits
	result["extras"] = extras
	result["missed_pitches"] = missed_pitches
	result["judgements"] = judgements
	return result


# --- Inline feedback (UI item 14) — color keys based on grading ---


func _apply_keyboard_judgement_colors() -> void:
	if _last_judgements.is_empty():
		return
	var hit_color := Color(0.40, 0.88, 0.50, 1.0)
	var miss_color := Color(0.94, 0.46, 0.46, 1.0)
	for midi_any in _last_judgements.keys():
		var midi: int = int(midi_any)
		if not _keyboard_keys.has(midi):
			continue
		var btn: Button = _keyboard_keys[midi] as Button
		if btn == null:
			continue
		var verdict: String = str(_last_judgements[midi])
		var tint: Color = hit_color if verdict == "hit" else miss_color
		if PianoKeyStylesScript.is_black_key(midi):
			PianoKeyStylesScript.apply_black_style(btn, tint)
		else:
			PianoKeyStylesScript.apply_white_style(btn, tint)


func _clear_keyboard_judgement_colors() -> void:
	if _last_judgements.is_empty():
		return
	_last_judgements = {}
	_keyboard_clear_highlight()


# Level spin handler — applies the speed accuracy gate (Feat 14). When the
# gate is on and last accuracy is below threshold, snaps the level back to
# its prior value and surfaces the reason in the status label so the user
# sees what blocked them.
func _on_level_spin_changed(value: float) -> void:
	stop_playback(true)
	if _suppress_level_gate:
		_prev_level_value = value
		return
	if _speed_gate_enabled and value > _prev_level_value and _last_accuracy >= 0.0 and _last_accuracy < SPEED_GATE_MIN_ACCURACY:
		if _level_spin != null:
			_level_spin.set_value_no_signal(_prev_level_value)
		if _status_label != null:
			_status_label.text = "Gate: last accuracy was %d%% (needs ≥%d%% to level up). Try the same level again." % [
				int(round(_last_accuracy * 100.0)),
				int(SPEED_GATE_MIN_ACCURACY * 100),
			]
		return
	_prev_level_value = value
	_next_daily_pick = {}
	_refresh_daily_preview()


# Drill the misses (Feat 3): pulls the missed-pitch list from the last
# play, picks a new exercise that emphasises those pitches by dropping
# the level by 1 (so the student gets a slower, cleaner pass), and
# re-runs Generate. If we have no missed-pitch data, no-ops.
func _on_drill_misses_pressed() -> void:
	var missed: Array = _last_play_finished_summary.get("missed_pitches", []) as Array
	if missed.is_empty():
		return
	_hide_post_play_summary()
	stop_playback(true)
	# Step the level down by 1 (floor at 1) so the weak-spot pass is a
	# touch easier and the student can re-build confidence. The Focus
	# stays the same so the drill shape is familiar.
	if _level_spin != null:
		var new_lvl: int = max(1, int(_level_spin.value) - 1)
		_suppress_level_gate = true
		_level_spin.set_value_no_signal(float(new_lvl))
		_prev_level_value = float(new_lvl)
		_suppress_level_gate = false
	# Store the missed pitches so the chosen exercise + key bias toward
	# them on next generate. Surface the intent in the contextual hint.
	if _contextual_hint_label != null:
		_contextual_hint_label.text = "Hint: 🎯 Drilling %d missed note(s) — slower level so they land cleanly." % missed.size()
	_on_generate_pressed()


# Reroll re-runs the current Focus/Type/Key/Level with a fresh seed.
# Bound to the 🎲 Reroll button and the R keyboard shortcut.
func _on_reroll_pressed() -> void:
	if _type_option == null:
		return
	stop_playback(true)
	_on_generate_pressed()


# Preset selector — picks a Focus + Level bundle so teachers/students can
# jump into a structured path with one tap. Index 0 is the placeholder.
# Now also dispatches to the "Save current as preset" action and to custom
# user-saved presets (Feat v2 item 17).
func _on_preset_changed(idx: int) -> void:
	if idx <= 0:
		return
	var preset: Dictionary = _resolve_preset_from_selection(idx)
	if preset.is_empty():
		return
	if str(preset.get("__action", "")) == "save":
		# Reset selection before opening dialog so re-picking works.
		if _preset_option != null:
			_preset_option.set_block_signals(true)
			_preset_option.selected = 0
			_preset_option.set_block_signals(false)
		_save_current_settings_as_preset()
		return
	stop_playback(true)
	var skill_id: String = str(preset.get("skill", ""))
	var lvl: int = int(preset.get("level", -1))
	var hand_mode: String = str(preset.get("hand_mode", ""))
	if not skill_id.is_empty() and _skill_option != null:
		for i in range(_skill_option.item_count):
			var meta = _skill_option.get_item_metadata(i)
			if meta != null and str(meta) == skill_id:
				_skill_option.selected = i
				_current_skill_filter = skill_id
				_refresh_type_dropdown()
				break
	if lvl > 0 and _level_spin != null:
		_level_spin.set_value_no_signal(float(lvl))
	if not hand_mode.is_empty() and _staff_option != null:
		match hand_mode:
			"treble": _staff_option.selected = 1
			"bass":   _staff_option.selected = 2
			_:         _staff_option.selected = 0
	_next_daily_pick = {}
	_refresh_daily_preview()
	_refresh_contextual_hint()
	if _preset_option != null:
		_preset_option.set_block_signals(true)
		_preset_option.selected = 0
		_preset_option.set_block_signals(false)


# Contextual hint (UI item 18) — one short line that describes what the
# user is about to play in plain language. Replaces the static title text
# that used to say "Pick options and press Generate".
func _refresh_contextual_hint() -> void:
	if _contextual_hint_label == null:
		return
	if _current_exercise.is_empty():
		var lvl: int = int(_level_spin.value) if _level_spin != null else 3
		var skill_label := "the selected focus"
		if _skill_option != null and _skill_option.selected >= 0:
			var raw_txt := _skill_option.get_item_text(_skill_option.selected)
			if raw_txt.begins_with("Focus: "):
				raw_txt = raw_txt.substr(7)
			skill_label = raw_txt
		_contextual_hint_label.text = "Hint: ready to drill %s at level %d — hit Generate or Start Daily Drill." % [skill_label, lvl]
		return
	var ex_id: String = str(_current_exercise.get("exercise_id", ""))
	var ex_name: String = str(_current_exercise.get("title", ExerciseLibraryScript.display_name(ex_id)))
	var key_pc: int = int(_current_exercise.get("key_pc", 0))
	var key_minor: bool = bool(_current_exercise.get("key_is_minor", false))
	var key_str := "%s %s" % [
		ChordExplorerTheoryScript.key_pc_to_letter(key_pc),
		"minor" if key_minor else "major",
	]
	var hand_str := "both hands"
	match _staff_mode():
		"treble": hand_str = "right hand"
		"bass":   hand_str = "left hand"
	var bpm: int = int(_current_exercise.get("tempo_bpm", 60))
	_contextual_hint_label.text = "Hint: %s in %s — %s · ♩ = %d bpm" % [ex_name, key_str, hand_str, bpm]


# Active state (UI item 12) — when an exercise is loaded, the Target chip
# gets a strong filled accent and the staff card gets an accent border.
func _refresh_active_state() -> void:
	var loaded: bool = not _current_exercise.is_empty()
	if _staff_wrap_panel != null and _staff_wrap_style_idle != null and _staff_wrap_style_active != null:
		_staff_wrap_panel.add_theme_stylebox_override(
			"panel",
			_staff_wrap_style_active if loaded else _staff_wrap_style_idle,
		)
	if _chip_target_wrap != null and _chip_target_label != null:
		if loaded:
			if _chip_target_style_active == null:
				_chip_target_style_active = _stylebox(
					Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.32),
					MENU_PRIMARY_ACCENT,
					14, 1, 0,
				)
				_chip_target_style_active.content_margin_left = 10
				_chip_target_style_active.content_margin_right = 10
				_chip_target_style_active.content_margin_top = 4
				_chip_target_style_active.content_margin_bottom = 4
			_chip_target_wrap.add_theme_stylebox_override("panel", _chip_target_style_active)
			_chip_target_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
		else:
			if _chip_target_style_idle == null:
				_chip_target_style_idle = _stylebox(Color(0.10, 0.17, 0.27, 0.78), Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.42), 14, 1, 0)
				_chip_target_style_idle.content_margin_left = 10
				_chip_target_style_idle.content_margin_right = 10
				_chip_target_style_idle.content_margin_top = 4
				_chip_target_style_idle.content_margin_bottom = 4
			_chip_target_wrap.add_theme_stylebox_override("panel", _chip_target_style_idle)
			_chip_target_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0, 0.96))


# Handler for staff-scroll size changes. Re-runs the score renderer so
# per-bar width (computed from viewport_w in _refresh_score_renderer)
# stays calibrated to the "exactly 3 bars visible" target. Skips when
# a playback is in flight so we don't yank the horizontal scroll
# mid-animation; the next stop/restart will pick up the new size.
func _on_staff_scroll_resized() -> void:
	if _playback_active:
		return
	_refresh_score_renderer()


# Empty state (UI item 19) — keep the staff renderer always visible so
# the empty grand staff (built by _refresh_score_renderer's placeholder
# branch) acts as the visual "ready to play" surface. The overlay label
# stays hidden; the contextual hint above the staff handles the textual
# prompt.
func _refresh_empty_state() -> void:
	if _empty_state_label != null:
		_empty_state_label.visible = false
	if _staff_area != null:
		_staff_area.visible = true


# --- Daily progress (item 5) ---


func _today_iso() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


# Reads the persisted counter; preserves streak across days but resets the
# completed-today counter when the date rolls over. Streak is only broken
# (back to 0) the first time we observe a today where the last hit-target
# day is older than yesterday — handled in _maybe_break_stale_streak.
# Tiny key/value store for UI prefs that should persist across sessions
# (currently just hide_fingerings — extend the saved dict as more
# togglable preferences land). Lives in user://practice_drills_ui.json.
func _load_ui_state() -> void:
	var f := FileAccess.open(UI_STATE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed as Dictionary
	_hide_fingerings_enabled = bool(d.get("hide_fingerings", false))
	if _hide_fingerings_check != null:
		_hide_fingerings_check.set_pressed_no_signal(_hide_fingerings_enabled)
	if _staff_area != null:
		_staff_area.set("hide_fingerings", _hide_fingerings_enabled)


func _save_ui_state() -> void:
	var d := {
		"hide_fingerings": _hide_fingerings_enabled,
	}
	var f := FileAccess.open(UI_STATE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()


func _load_daily_progress_if_needed() -> void:
	if not _daily_progress.is_empty() and str(_daily_progress.get("date", "")) == _today_iso():
		return
	# Start from defaults, then overlay anything we can salvage from disk.
	_daily_progress = {
		"date": _today_iso(),
		"completed": 0,
		"target": DEFAULT_DAILY_TARGET,
		"streak": 0,
		"last_target_hit_date": "",
	}
	var f := FileAccess.open(DAILY_PROGRESS_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			var saved: Dictionary = parsed as Dictionary
			_daily_progress["streak"] = int(saved.get("streak", 0))
			_daily_progress["last_target_hit_date"] = str(saved.get("last_target_hit_date", ""))
			_daily_progress["target"] = int(saved.get("target", DEFAULT_DAILY_TARGET))
			if str(saved.get("date", "")) == _today_iso():
				_daily_progress["completed"] = int(saved.get("completed", 0))
	_maybe_break_stale_streak()


# If the last day we hit target is older than yesterday, the streak is
# broken — reset to 0. Called every time we load progress for a new day.
func _maybe_break_stale_streak() -> void:
	var last_hit := str(_daily_progress.get("last_target_hit_date", ""))
	if last_hit.is_empty():
		return
	if last_hit == _today_iso() or last_hit == _yesterday_iso():
		return
	_daily_progress["streak"] = 0


func _yesterday_iso() -> String:
	var now := Time.get_unix_time_from_system()
	var yesterday := Time.get_date_dict_from_unix_time(int(now) - 86400)
	return "%04d-%02d-%02d" % [int(yesterday.year), int(yesterday.month), int(yesterday.day)]


func _save_daily_progress() -> void:
	var f := FileAccess.open(DAILY_PROGRESS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_daily_progress, "\t"))
	f.close()


func _refresh_daily_progress_ui() -> void:
	if _daily_progress_bar == null or _daily_progress_label == null:
		return
	var target: int = max(1, int(_daily_progress.get("target", DEFAULT_DAILY_TARGET)))
	var done: int = clampi(int(_daily_progress.get("completed", 0)), 0, target)
	_daily_progress_bar.max_value = target
	_daily_progress_bar.value = done
	var suffix := ""
	if done >= target:
		suffix = "  ✓"
	_daily_progress_label.text = "%d / %d today%s" % [done, target, suffix]
	# Streak chip — visible only once the user has a streak going.
	if _chip_streak_label != null:
		var streak: int = int(_daily_progress.get("streak", 0))
		if streak <= 0:
			_chip_streak_label.visible = false
		else:
			_chip_streak_label.visible = true
			var day_word := "day" if streak == 1 else "days"
			_chip_streak_label.text = "⚡  %d-%s streak" % [streak, day_word]


# Called from _on_play_finished when the current exercise came from Daily
# Drill — caps at target so the bar fills cleanly. When this completion
# crosses the daily target for the first time today, advance the streak
# (rolls forward by 1 vs yesterday's hit, otherwise restarts at 1).
func _increment_daily_progress() -> void:
	_load_daily_progress_if_needed()
	var target: int = max(1, int(_daily_progress.get("target", DEFAULT_DAILY_TARGET)))
	var prev_done: int = clampi(int(_daily_progress.get("completed", 0)), 0, target)
	var done: int = clampi(prev_done + 1, 0, target)
	_daily_progress["completed"] = done
	if done >= target and prev_done < target:
		var last_hit := str(_daily_progress.get("last_target_hit_date", ""))
		var prev_streak: int = int(_daily_progress.get("streak", 0))
		var new_streak: int = 1
		if last_hit == _yesterday_iso():
			new_streak = prev_streak + 1
		_daily_progress["streak"] = new_streak
		_daily_progress["last_target_hit_date"] = _today_iso()
	_save_daily_progress()
	_refresh_daily_progress_ui()


# --- What's Next preview (item 6) ---


# Rolls a cached pick so the hero subtitle can show what the next Daily Drill
# will be BEFORE the user presses Start. Pressing Start consumes the cache so
# the actual generated drill matches the preview exactly.
func _refresh_daily_preview() -> void:
	if _daily_drill_subtitle == null:
		return
	var level: int = int(_level_spin.value) if _level_spin != null else 3
	var focus: String = _current_skill_filter
	var inferred_from_weakness := ""
	if focus == "all" and _weakest_skill_family_callable.is_valid():
		var weakest_family: String = str(_weakest_skill_family_callable.call())
		if not weakest_family.is_empty():
			inferred_from_weakness = CurriculumScript.focus_for_module_family(weakest_family)
			if inferred_from_weakness != "all":
				focus = inferred_from_weakness
	var pick: Dictionary = CurriculumScript.daily_warmup_pick(level, focus, -1)
	_next_daily_pick = {
		"preview_level": level,
		"preview_focus": focus,
		"pick": pick,
	}
	var ex_id: String = str(pick.get("exercise_id", "scale"))
	var key_pc: int = int(pick.get("key_pc", 0))
	var key_minor: bool = bool(pick.get("key_is_minor", false))
	var key_str := "%s %s" % [
		ChordExplorerTheoryScript.key_pc_to_letter(key_pc),
		"minor" if key_minor else "major",
	]
	var suffix := ""
	if not inferred_from_weakness.is_empty() and inferred_from_weakness != "all":
		suffix = "  ←  auto-focused on your weakest area"
	_daily_drill_subtitle.text = "Next: %s in %s%s" % [
		ExerciseLibraryScript.display_name(ex_id),
		key_str,
		suffix,
	]


# --- Post-play summary (item 8) ---


func _on_play_finished() -> void:
	if _current_exercise.is_empty():
		return
	# Snapshot the MIDI captures BEFORE _stop_midi_grading clears state on
	# the next play, so Feat 12's Replay-your-take button can still
	# schedule them once the live buffer is gone.
	_last_play_captures = _midi_captures.duplicate(true)
	_stop_midi_grading()
	var elapsed_usec: int = Time.get_ticks_usec() - _last_play_start_usec
	var elapsed_sec: float = float(elapsed_usec) / 1_000_000.0
	var playable_notes := 0
	for note_any in _current_exercise.get("notes", []):
		var note: Dictionary = note_any
		if int(note.get("midi", -1)) >= 0 and not bool(note.get("rest", false)):
			playable_notes += 1
	var bpm: int = int(_current_exercise.get("tempo_bpm", 60))
	# Score the captured MIDI input against the exercise events.
	var score := _score_midi_captures_against_exercise()
	_last_accuracy = float(score.get("accuracy", -1.0))
	_last_judgements = score.get("judgements", {}) as Dictionary
	_last_play_finished_summary = {
		"notes": playable_notes,
		"bpm": bpm,
		"elapsed_sec": elapsed_sec,
		"was_daily": _current_exercise_is_daily,
		"hits": int(score.get("hits", 0)),
		"misses": int(score.get("misses", 0)),
		"extras": int(score.get("extras", 0)),
		"accuracy": _last_accuracy,
		"missed_pitches": score.get("missed_pitches", []),
	}
	_apply_keyboard_judgement_colors()
	_update_session_streak(_last_accuracy)
	_show_post_play_summary()
	_append_drill_history_entry(elapsed_sec, playable_notes, bpm, _last_accuracy)
	if _current_exercise_is_daily:
		_increment_daily_progress()
		# Pre-roll the next preview so the user sees what's coming next
		# AFTER finishing the one they just played.
		_next_daily_pick = {}
		_refresh_daily_preview()


func _show_post_play_summary() -> void:
	if _post_play_summary_panel == null or _post_play_summary_label == null:
		return
	var elapsed: float = float(_last_play_finished_summary.get("elapsed_sec", 0.0))
	var mm: int = int(elapsed) / 60
	var ss: int = int(elapsed) % 60
	var notes: int = int(_last_play_finished_summary.get("notes", 0))
	var bpm: int = int(_last_play_finished_summary.get("bpm", 0))
	var prefix := "✓ Played"
	if bool(_last_play_finished_summary.get("was_daily", false)):
		prefix = "✓ Daily Drill done"
	var accuracy: float = float(_last_play_finished_summary.get("accuracy", -1.0))
	if accuracy < 0.0:
		# No MIDI captured — playback-only summary (unchanged from before).
		_post_play_summary_label.text = "%s — %d notes at ♩ = %d  ·  %d:%02d  ·  (connect a MIDI keyboard to grade your play)" % [prefix, notes, bpm, mm, ss]
	else:
		# Two-line graded result: scoreline + error pattern.
		var pct: int = int(round(accuracy * 100.0))
		var hits: int = int(_last_play_finished_summary.get("hits", 0))
		var misses: int = int(_last_play_finished_summary.get("misses", 0))
		var extras: int = int(_last_play_finished_summary.get("extras", 0))
		var grade_word := "Perfect"
		if pct < 100: grade_word = "Strong"
		if pct < 90: grade_word = "Good"
		if pct < 70: grade_word = "Keep going"
		if pct < 50: grade_word = "Slow it down"
		var line_1 := "%s — %s · %d%% accuracy  (♩ = %d, %d:%02d)" % [prefix, grade_word, pct, bpm, mm, ss]
		var line_2 := "%d / %d notes hit" % [hits, hits + misses]
		if misses > 0:
			line_2 += "  ·  %d missed" % misses
		if extras > 0:
			line_2 += "  ·  %d extra" % extras
		_post_play_summary_label.text = "%s\n%s" % [line_1, line_2]
	_refresh_post_play_action_buttons()
	_post_play_summary_panel.visible = true


# Toggle the "Drill the misses" button on the post-play summary based on
# whether the just-finished play had >=2 missed notes worth drilling.
func _refresh_post_play_action_buttons() -> void:
	if _post_play_weak_spot_button == null:
		return
	var missed_pitches: Array = _last_play_finished_summary.get("missed_pitches", []) as Array
	_post_play_weak_spot_button.visible = missed_pitches.size() >= 2
	# Feat 12 — Replay-your-take visible only if MIDI was captured.
	if _post_play_replay_take_button != null:
		_post_play_replay_take_button.visible = _last_play_captures.size() > 0


# Feat 18 — Session streak goal updater. Called from _on_play_finished
# with the play's accuracy. -1.0 means no MIDI was captured (no grading),
# leave the streak untouched. Otherwise: clean take advances the counter,
# below-threshold resets to 0. Hits goal → status-label celebration.
func _update_session_streak(accuracy: float) -> void:
	if accuracy < 0.0:
		return  # ungraded — neither increment nor reset
	if accuracy >= SESSION_STREAK_MIN_ACCURACY:
		_session_clean_streak += 1
		if _session_clean_streak == SESSION_STREAK_GOAL and _status_label != null:
			_status_label.text = "🎉  Clean streak goal hit (%d in a row)! Great work." % SESSION_STREAK_GOAL
	else:
		_session_clean_streak = 0
	_refresh_session_streak_chip()


func _refresh_session_streak_chip() -> void:
	if _chip_session_streak_label == null:
		return
	# Reveal chip on first graded play; cap visible counter at the goal
	# so the chip doesn't keep climbing past 3/3 — the celebration message
	# is the reward, the chip just resets.
	var capped: int = mini(_session_clean_streak, SESSION_STREAK_GOAL)
	_chip_session_streak_label.text = "Clean: %d/%d" % [capped, SESSION_STREAK_GOAL]
	if _chip_session_streak_wrap != null:
		_chip_session_streak_wrap.visible = _session_clean_streak > 0


# Feat 8 — Loop last bar handler. Computes the start beat of the last
# bar in the current exercise, sets the one-shot playback filter, then
# invokes the normal _on_play_pressed which honors the filter to only
# schedule events from that bar onward.
func _on_loop_last_bar_pressed() -> void:
	if _current_exercise.is_empty() or _playback_active:
		return
	var time_num: int = max(1, int(_current_exercise.get("time_sig_num", 4)))
	var time_den: int = max(1, int(_current_exercise.get("time_sig_den", 4)))
	var beats_per_bar: float = float(time_num) * (4.0 / maxf(1.0, float(time_den)))
	var total_beats: float = float(_current_exercise.get("total_beats", beats_per_bar))
	var last_bar_start: float = floor((total_beats - 0.001) / beats_per_bar) * beats_per_bar
	if last_bar_start < 0.0:
		last_bar_start = 0.0
	_playback_filter_from_beat = last_bar_start
	_hide_post_play_summary()
	_on_play_pressed()


# Feat 12 — Mistake replay handler. Walks _last_play_captures and
# schedules a _spawn_note for each one at its recorded beat-relative
# delay, using the exercise's BPM. Aborts cleanly if another playback is
# in flight or there are no captures (defensive).
func _on_replay_take_pressed() -> void:
	if _last_play_captures.is_empty() or _current_exercise.is_empty():
		return
	if _playback_active:
		return
	var bpm: float = float(_current_exercise.get("tempo_bpm", 80))
	var seconds_per_beat: float = 60.0 / maxf(40.0, bpm)
	# Normalise capture beat offsets relative to the earliest one so the
	# replay starts immediately instead of waiting out the original
	# absolute time delta from play start.
	var min_beat: float = 1e18
	for cap_any in _last_play_captures:
		var cap: Dictionary = cap_any
		min_beat = minf(min_beat, float(cap.get("beat", 0.0)))
	if min_beat >= 1e18:
		min_beat = 0.0
	var sample_map: Dictionary = _sample_map_callable.call() if _sample_map_callable.is_valid() else {}
	for cap_any in _last_play_captures:
		var cap: Dictionary = cap_any
		var pitch: int = int(cap.get("midi", -1))
		if pitch < 0:
			continue
		var delay_sec: float = (float(cap.get("beat", 0.0)) - min_beat) * seconds_per_beat
		if delay_sec <= 0.0:
			_spawn_note(pitch, 0.45, sample_map)
		else:
			var captured_pitch := pitch
			var captured_map := sample_map
			var t := get_tree().create_timer(delay_sec)
			t.timeout.connect(func() -> void:
				if not is_instance_valid(self) or not visible:
					return
				_spawn_note(captured_pitch, 0.45, captured_map)
			)
	if _status_label != null:
		_status_label.text = "Replaying your take — %d notes." % _last_play_captures.size()


func _hide_post_play_summary() -> void:
	if _post_play_summary_panel != null:
		_post_play_summary_panel.visible = false


# --- Responsive layout (item 9) ---


# Adjusts hero dock density on narrow viewports and constrains overall
# reading width on very-wide ones. Below 820px → CTA shrinks. Above 1600px
# → root margin widens so content stays in a 1400px scan zone instead of
# sprawling edge to edge (UI item 17 — wider 2-col layout reinterpreted as
# constrained scan width, since true side-by-side would require gutting
# the linear flow and we keep the keyboard full-width for usability).
func _apply_responsive_layout() -> void:
	if _daily_drill_hero_button == null:
		return
	var w: float = size.x
	var h: float = size.y
	if w <= 0:
		var vp := get_viewport()
		if vp != null:
			w = vp.get_visible_rect().size.x
			h = vp.get_visible_rect().size.y
	var narrow: bool = w < 820.0
	var ultra_wide: bool = w >= 1600.0
	var short: bool = h < 860.0
	if _chip_tempo_label != null:
		_chip_tempo_label.visible = not narrow and not short
	if narrow or short:
		_daily_drill_hero_button.text = "▶  Daily Drill"
		_daily_drill_hero_button.custom_minimum_size = Vector2(148, 34)
		_daily_drill_hero_button.add_theme_font_size_override("font_size", 13)
	else:
		_daily_drill_hero_button.text = "▶  Start Daily Drill"
		_daily_drill_hero_button.custom_minimum_size = Vector2(196, 38)
		_daily_drill_hero_button.add_theme_font_size_override("font_size", 15)
	if _daily_drill_subtitle != null:
		_daily_drill_subtitle.add_theme_font_size_override("font_size", 11 if short else 12)
	if _daily_progress_label != null:
		_daily_progress_label.add_theme_font_size_override("font_size", 11 if short else 12)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 12 if short else 13)
	if _contextual_hint_label != null:
		_contextual_hint_label.add_theme_font_size_override("font_size", 11 if short else 12)
	if _play_button != null:
		_play_button.custom_minimum_size = Vector2(156 if short else 176, 42 if short else 44)
		_play_button.add_theme_font_size_override("font_size", 14 if short else 15)
	if _stop_button != null:
		_stop_button.custom_minimum_size = Vector2(156 if short else 176, 42 if short else 44)
		_stop_button.add_theme_font_size_override("font_size", 14 if short else 15)
	if _metronome_check != null:
		_metronome_check.custom_minimum_size = Vector2(138 if short else 146, 36 if short else 40)
		_metronome_check.add_theme_font_size_override("font_size", 13 if short else 14)
	if _count_in_check != null:
		_count_in_check.custom_minimum_size = Vector2(148 if short else 156, 36 if short else 40)
		_count_in_check.add_theme_font_size_override("font_size", 12 if short else 13)
	if _info_button != null:
		_info_button.custom_minimum_size = Vector2(34 if short else 36, 34 if short else 36)
		_info_button.add_theme_font_size_override("font_size", 16 if short else 17)
	if _key_option != null:
		_key_option.custom_minimum_size = Vector2(84 if short else 88, 26 if short else 28)
		_key_option.add_theme_font_size_override("font_size", 10)
	if _minor_check != null:
		_minor_check.custom_minimum_size = Vector2(66 if short else 70, 26 if short else 28)
		_minor_check.add_theme_font_size_override("font_size", 10)
	if _staff_option != null:
		_staff_option.custom_minimum_size = Vector2(132 if short else 138, 26 if short else 28)
		_staff_option.add_theme_font_size_override("font_size", 10)
	if _octaves_spin != null:
		_octaves_spin.custom_minimum_size = Vector2(58 if short else 62, 26 if short else 28)
		_octaves_spin.add_theme_font_size_override("font_size", 10)
	if _level_spin != null:
		_level_spin.custom_minimum_size = Vector2(58 if short else 62, 26 if short else 28)
		_level_spin.add_theme_font_size_override("font_size", 10)
	if _speed_gate_check != null:
		_speed_gate_check.custom_minimum_size = Vector2(136 if short else 144, 24 if short else 26)
		_speed_gate_check.add_theme_font_size_override("font_size", 10)
	# Re-flow the root margin: 24px default, but balloon to (w - 1400) / 2
	# when ultra-wide so the content reads as a centered column. The
	# MarginContainer is now the ScrollContainer's first (and only) child;
	# walk through the wrapper to find it.
	var root_margin: MarginContainer = null
	if get_child_count() > 0:
		var first := get_child(0)
		if first is ScrollContainer and first.get_child_count() > 0:
			root_margin = first.get_child(0) as MarginContainer
		elif first is MarginContainer:
			# Defensive: old layout shape (no ScrollContainer wrapper).
			root_margin = first as MarginContainer
	if root_margin != null:
		var side: int = 24
		if ultra_wide:
			side = int((w - 1400.0) * 0.5)
		root_margin.add_theme_constant_override("margin_left", side)
		root_margin.add_theme_constant_override("margin_right", side)


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
	# Feat v2 item 11 — group entries by category (scale / arpeggio / drill
	# / hanon / czerny / ...) so a long, mixed list reads as a structured
	# library instead of an undifferentiated dump.
	var by_category: Dictionary = {}
	for id_any in ids:
		var id: String = str(id_any)
		var entry: Dictionary = ExerciseLibraryScript.entry(id)
		var cat: String = str(entry.get("category", "other"))
		if not by_category.has(cat):
			by_category[cat] = []
		(by_category[cat] as Array).append(id)
	var category_order: Array[String] = ["scale", "arpeggio", "chord", "jazz", "hanon", "czerny", "drill", "other"]
	# Append any extra categories that aren't in the priority order so we
	# don't silently drop items if the library grows.
	for cat_any in by_category.keys():
		var cat_str := str(cat_any)
		if not category_order.has(cat_str):
			category_order.append(cat_str)
	var restore_idx: int = 0
	var item_index: int = 0
	var added_any: bool = false
	for cat in category_order:
		var cat_ids: Array = by_category.get(cat, [])
		if cat_ids.is_empty():
			continue
		if added_any:
			# Separator items (non-selectable header) — visible only when
			# more than one category renders so we don't add noise.
			_type_option.add_separator(_category_label(cat))
			item_index = _type_option.item_count
		else:
			_type_option.add_separator(_category_label(cat))
			item_index = _type_option.item_count
		added_any = true
		for id_any in cat_ids:
			var id: String = str(id_any)
			_type_option.add_item(ExerciseLibraryScript.display_name(id))
			_type_option.set_item_metadata(item_index, id)
			if id == prev_id:
				restore_idx = item_index
			item_index += 1
	# If the prev_id wasn't found, fall back to the first non-separator.
	if restore_idx == 0:
		for i in range(_type_option.item_count):
			if _type_option.get_item_metadata(i) != null:
				restore_idx = i
				break
	_type_option.selected = restore_idx


func _category_label(category_id: String) -> String:
	match category_id:
		"scale":    return "— Scales —"
		"arpeggio": return "— Arpeggios —"
		"hanon":    return "— Hanon —"
		"czerny":   return "— Czerny —"
		"chord":    return "— Chord Exercises —"
		"jazz":     return "— Jazz —"
		"drill":    return "— Drills —"
		"other":    return "— Other —"
		_:          return "— %s —" % category_id.capitalize()


func _refresh_score_renderer() -> void:
	if _staff_area == null or not _staff_area.has_method("set_score"):
		return
	var mode := _staff_mode()
	# Single continuous horizontal system — the ScrollContainer scrolls
	# left as playback progresses (see _scroll_to_playback_beat) so the
	# user sees ~2 bars at a time and the score follows the music. The
	# earlier compression bug was the staff width being fixed at 1200px;
	# now we compute width from beat count below so each bar gets enough
	# room and bars don't get squished.
	_staff_area.set("auto_bars_per_system", false)
	_staff_area.set("bars_per_system", 0)
	if _current_exercise.is_empty():
		_staff_area.custom_minimum_size = Vector2(1200, STAFF_RENDER_HEIGHT)
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
	# Width sized so exactly ~3 bars fit in the visible staff scroll
	# viewport at any time; the rest of the bars extend off-screen and
	# the horizontal scroll container handles the rest. Per-bar width is
	# derived from the current viewport width so the layout adapts to
	# resized windows / different displays. ~120px reserved at the start
	# for clef + key signature glyphs.
	var beats_per_bar_for_width: float = float(time_num) * (4.0 / maxf(1.0, float(time_den)))
	var bar_count_for_width: float = ceil(maxf(beats_per_bar_for_width, total_beats) / maxf(0.001, beats_per_bar_for_width))
	var viewport_w: float = _staff_scroll.size.x if _staff_scroll != null and _staff_scroll.size.x > 0 else 1200.0
	const PREFIX_PX: float = 120.0
	const VISIBLE_BARS: float = 3.0
	const PER_BAR_MIN_PX: float = 260.0   # floor so notes aren't squished on narrow viewports
	const PER_BAR_MAX_PX: float = 460.0   # ceiling so bars don't sprawl on ultra-wide
	var per_bar_px: float = clampf((viewport_w - PREFIX_PX) / VISIBLE_BARS, PER_BAR_MIN_PX, PER_BAR_MAX_PX)
	var staff_width: float = PREFIX_PX + bar_count_for_width * per_bar_px
	_staff_area.custom_minimum_size = Vector2(maxf(viewport_w, staff_width), STAFF_RENDER_HEIGHT)
	var score_dict: Dictionary
	if mode == "grand":
		score_dict = ScoreModelScript.from_flat_notes_grand_staff(notes, time_num, time_den, fifths, key_is_minor, tempo, title, 60)
	else:
		score_dict = ScoreModelScript.from_flat_notes(notes, mode, time_num, time_den, fifths, key_is_minor, tempo, title)
	_staff_area.set_score(score_dict)
	_keyboard_clear_highlight()
	call_deferred("_reset_staff_scroll")
	call_deferred("_keyboard_scroll_to_first_note")


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


func _spawn_note(midi: int, duration_sec: float, sample_map: Dictionary, volume_db: float = 0.0) -> void:
	if midi < 0:
		return
	# QA audio probe — push every spawned note to the host's probe queue
	# so the orchestrator's assert_audio asserts see Practice Drills
	# playback. No-op when --qa / --debug-server isn't active (the
	# callable stays empty in that case).
	if _qa_audio_probe_callable.is_valid():
		_qa_audio_probe_callable.call(int(midi), float(duration_sec))
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
	# Play at the target volume from frame 1 — the piano sample's own
	# natural attack envelope handles smoothing. The previous
	# "start at -24 dB, ramp up over 12 ms" pre-fade actually CREATED
	# the click the user was hearing on virtual-keyboard taps: layering
	# a fast volume step on top of the piano's natural transient sounds
	# like a percussive tick. Removing the ramp leaves a clean note.
	player.volume_db = volume_db
	add_child(player)
	_note_players.append(player)
	player.play()
	var fade_sec := 0.03
	var hold_sec := maxf(0.0, duration_sec - fade_sec)
	var stop_at := get_tree().create_timer(hold_sec)
	stop_at.timeout.connect(func() -> void:
		if not is_instance_valid(player):
			_note_players.erase(player)
			return
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -60.0, fade_sec)
		tween.finished.connect(func() -> void:
			_note_players.erase(player)
			if is_instance_valid(player):
				player.stop()
				if not player.is_queued_for_deletion():
					player.queue_free()
		)
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
	# Tempo marking: use the actual quarter-note glyph (U+2669) instead of
	# the placeholder letter "q". The Unicode quarter note is present in
	# Inter (the project UI font) and renders cleanly in PDF + PNG export.
	_add_export_label(page, "♩ = %d" % tempo, Vector2(margin_x + 10.0, 168.0), Vector2(260.0, 34.0), 21, HORIZONTAL_ALIGNMENT_LEFT, Color(0.10, 0.12, 0.16, 1.0))

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
