class_name FunctionalEarPanel
extends PanelContainer

# Functional ear training — students identify the ROLE of a chord within a key
# (I, ii, iii, IV, V, vi, vii° in major; i, ii°, III, iv, V, VI, vii° in minor),
# not the quality in isolation. Recognizing "this is the V chord in F major" is
# the skill musicians actually need.
#
# Each round:
#   1. Play a key-establishing progression (varied; skippable after it's set).
#   2. Play a test chord drawn from the active diatonic functions.
#   3. Show the Roman-numeral buttons for the active level; user picks.
#   4. Score, advance. On a miss, hear your pick vs the correct chord + why.
#
# Supports Major/Minor keys, three difficulty levels (scaffolding), and an
# optional diatonic-7th-chord tier. Self-contained — owns its widgets + session
# state. Reuses the host's chord playback callable for the actual sound.


signal closed                       # ← Home pressed


# --- Constants ---
const ROUND_LENGTH := 10
const CADENCE_CHORD_DUR_SEC := 0.55
const CADENCE_GAP_SEC := 0.08
const TEST_CHORD_DELAY_SEC := 0.30
const TEST_CHORD_DUR_SEC := 1.20
const COMPARE_GAP_SEC := 0.22

# Key options. Pitch-class encoding matches the host's existing tables.
const KEY_CHOICES := [
	["C", 0],   ["G", 7],   ["D", 2],   ["A", 9],   ["E", 4],
	["F", 5],   ["Bb", 10], ["Eb", 3],
]

# Diatonic functions per mode. Minor uses harmonic-minor harmony so the V is a
# MAJOR dominant (raised leading tone) and vii° is the diminished leading-tone
# chord — the functions students actually need to hear.
# Each entry: { roman, semis (above tonic), triad, seventh, quality, tendency, song }
const DEGREES := {
	"major": [
		{"roman": "I",    "semis": 0,  "triad": [0, 4, 7], "seventh": [0, 4, 7, 11], "quality": "major",       "tendency": "home base — stable and at rest", "song": "the chord every song comes to rest on"},
		{"roman": "ii",   "semis": 2,  "triad": [0, 3, 7], "seventh": [0, 3, 7, 10], "quality": "minor",       "tendency": "a gentle pre-dominant that leans toward V", "song": "the 'ii' in a ii–V–I"},
		{"roman": "iii",  "semis": 4,  "triad": [0, 3, 7], "seventh": [0, 3, 7, 10], "quality": "minor",       "tendency": "a soft in-between colour, often passing", "song": "the wistful iii in 'I-iii-IV-V'"},
		{"roman": "IV",   "semis": 5,  "triad": [0, 4, 7], "seventh": [0, 4, 7, 11], "quality": "major",       "tendency": "the 'away' chord — returns home or pushes to V", "song": "the IV in the 'Amen' (IV–I)"},
		{"roman": "V",    "semis": 7,  "triad": [0, 4, 7], "seventh": [0, 4, 7, 10], "quality": "major",       "tendency": "the dominant — pulls strongly home to I", "song": "the chord right before the end of Happy Birthday"},
		{"roman": "vi",   "semis": 9,  "triad": [0, 3, 7], "seventh": [0, 3, 7, 10], "quality": "minor",       "tendency": "the relative-minor 'deceptive' landing", "song": "the surprise vi in a deceptive cadence"},
		{"roman": "vii°", "semis": 11, "triad": [0, 3, 6], "seventh": [0, 3, 6, 10], "quality": "diminished",  "tendency": "tense leading-tone chord — resolves up to I", "song": "the unstable chord that begs to resolve"},
	],
	"minor": [
		{"roman": "i",    "semis": 0,  "triad": [0, 3, 7], "seventh": [0, 3, 7, 10], "quality": "minor",       "tendency": "home base in minor — stable but dark", "song": "the resting chord of a minor-key song"},
		{"roman": "ii°",  "semis": 2,  "triad": [0, 3, 6], "seventh": [0, 3, 6, 10], "quality": "diminished",  "tendency": "a tense pre-dominant that leans toward V", "song": "the 'iiø' in a minor ii–V–i"},
		{"roman": "III",  "semis": 3,  "triad": [0, 4, 7], "seventh": [0, 4, 7, 11], "quality": "major",       "tendency": "the bright relative-major colour", "song": "the relative major hiding inside the minor key"},
		{"roman": "iv",   "semis": 5,  "triad": [0, 3, 7], "seventh": [0, 3, 7, 10], "quality": "minor",       "tendency": "the minor 'away' chord", "song": "the iv in a minor plagal (iv–i)"},
		{"roman": "V",    "semis": 7,  "triad": [0, 4, 7], "seventh": [0, 4, 7, 10], "quality": "major",       "tendency": "the major dominant (raised leading tone) — pulls home to i", "song": "the major V that lights up a minor key"},
		{"roman": "VI",   "semis": 8,  "triad": [0, 4, 7], "seventh": [0, 4, 7, 11], "quality": "major",       "tendency": "the ♭VI — the deceptive landing in minor", "song": "the bright surprise in a minor deceptive cadence"},
		{"roman": "vii°", "semis": 11, "triad": [0, 3, 6], "seventh": [0, 3, 6, 9],  "quality": "diminished",  "tendency": "leading-tone diminished — resolves up to i", "song": "the most unstable chord, begging for i"},
	],
}

# Difficulty levels — which degree indices (into the 7-entry list) are in play.
const LEVELS := [
	{"name": "Beginner",     "idx": [0, 3, 4]},                 # tonic, IV, V — the pillars
	{"name": "Intermediate", "idx": [0, 1, 3, 4, 5]},           # + ii, vi
	{"name": "Advanced",     "idx": [0, 1, 2, 3, 4, 5, 6]},     # all seven
]

# Key-establishing progressions (degree indices). One is chosen per question so
# students internalize the tonic rather than memorizing one cadence.
const PRELUDES := [
	[0, 3, 4, 0],       # I-IV-V-I
	[1, 4, 0],          # ii-V-I
	[0, 5, 3, 4, 0],    # I-vi-IV-V-I
]

const MENU_TITLE_TEXT := Color(0.9176, 0.9529, 1.0, 1.0)
const MENU_PRIMARY_ACCENT := Color(0.9098, 0.6275, 0.1255, 1.0)
const BTN_ACCENT_CORRECT := Color(0.40, 0.92, 0.55, 1.0)
const BTN_ACCENT_WRONG := Color(0.96, 0.38, 0.42, 1.0)
const BTN_ACCENT_NEUTRAL := Color(0.42, 0.78, 0.86, 1.0)


# --- Injected callables ---
var _ui_font: Font = null
var _ui_title_font: Font = null
var _play_chord_callable: Callable = Callable()   # (notes:Array[int], dur:float) -> Awaitable
var _nav_home_style_callable: Callable = Callable()
var _play_correct_sfx_callable: Callable = Callable()
var _play_wrong_sfx_callable: Callable = Callable()


const PROGRESS_PATH := "user://functional_ear_progress.json"
const MASTERY_STREAK := 5
const MASTERY_ACCURACY := 0.85

# --- Settings state ---
var _mode: String = "major"          # "major" | "minor"
var _level: int = 0                  # index into LEVELS
var _use_sevenths: bool = false
var _use_inversions: bool = false
var _skip_prelude: bool = false      # after the key is established, skip the full prelude

# Adaptive practice: weights questions toward the functions the student misses,
# tracks per-function accuracy/streaks, and persists across sessions.
var _review: ReviewQueue = ReviewQueue.new()
var _current_inversion: int = 0      # inversion of the active test chord

# Progression dictation: hear a 3–4 chord sequence, enter the whole Roman string.
var _dictation: bool = false
var _correct_seq: Array[int] = []    # degree indices of the played progression
var _answer_seq: Array[int] = []     # what the student has entered so far

# Candidate dictation progressions (degree indices). Filtered to the active level.
const DICTATION_PROGRESSIONS := {
	"major": [[0, 4, 0], [1, 4, 0], [0, 3, 4, 0], [0, 5, 3, 4], [0, 4, 5, 3], [0, 3, 0, 4]],
	"minor": [[0, 4, 0], [1, 4, 0], [0, 3, 4, 0], [0, 5, 3, 4], [0, 2, 4, 0]],
}


# --- Round state ---
var _key_pc: int = 0
var _key_label: String = "C"
var _question_index: int = 0
var _score: int = 0
var _correct_idx: int = -1           # degree index (0..6) of the current test chord
var _busy_until_msec: int = 0
var _session_token: int = 0
var _key_established: bool = false    # true once a prelude has played this round
var _awaiting_next: bool = false


# --- Widget refs ---
var _back_button: Button = null
var _key_option: OptionButton = null
var _mode_button: Button = null
var _level_option: OptionButton = null
var _sevenths_check: CheckButton = null
var _inversions_check: CheckButton = null
var _dictation_check: CheckButton = null
var _skip_prelude_check: CheckButton = null
var _mastery_label: Label = null
var _sequence_label: Label = null
var _undo_button: Button = null
var _start_button: Button = null
var _replay_button: Button = null
var _next_button: Button = null
var _status_label: Label = null
var _progress_label: Label = null
var _score_label: Label = null
var _answer_row: GridContainer = null
var _answer_buttons: Array[Button] = []   # one per degree index 0..6


# --- Public lifecycle ---


func setup(
	ui_font: Font,
	ui_title_font: Font,
	play_chord: Callable,
	nav_home_style: Callable = Callable(),
	play_correct_sfx: Callable = Callable(),
	play_wrong_sfx: Callable = Callable()
) -> void:
	_ui_font = ui_font
	_ui_title_font = ui_title_font
	_play_chord_callable = play_chord
	_nav_home_style_callable = nav_home_style
	_play_correct_sfx_callable = play_correct_sfx
	_play_wrong_sfx_callable = play_wrong_sfx
	visible = false
	z_as_relative = false
	z_index = 200
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	add_theme_stylebox_override("panel", bg)
	_build_ui()
	resized.connect(_apply_responsive_layout)


func present() -> void:
	visible = true
	move_to_front()
	_apply_responsive_layout()
	_load_progress()
	_soft_reset()
	_update_mastery_label()
	if _status_label != null:
		_status_label.text = "Pick a key, mode and level, then tap Start. You'll hear a short progression to set the key, then a test chord — identify its role."


func dismiss() -> void:
	_session_token += 1
	visible = false


# --- UI build ---


func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	root_margin.add_child(root_v)

	# Top bar: back, brand, title, key picker
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root_v.add_child(top)

	_back_button = Button.new()
	_back_button.tooltip_text = "Back to home"
	_back_button.pressed.connect(_on_back_pressed)
	if _nav_home_style_callable.is_valid():
		_nav_home_style_callable.call(_back_button)
	else:
		_back_button.text = char(0x2302)
		_back_button.custom_minimum_size = Vector2(46, 46)
		_back_button.add_theme_font_size_override("font_size", 22)
	top.add_child(_back_button)

	var brand_box := HBoxContainer.new()
	brand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_box.add_theme_constant_override("separation", 8)
	top.add_child(brand_box)
	var brand_logo := TextureRect.new()
	var brand_tex: Texture2D = load("res://assets/logos/clefira-logo.svg") as Texture2D
	if brand_tex == null:
		brand_tex = load("res://assets/branding/clefira-splash-mark-transparent-512.png") as Texture2D
	if brand_tex != null:
		brand_logo.texture = brand_tex
	brand_logo.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	brand_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_logo.custom_minimum_size = Vector2(28, 28)
	brand_logo.tooltip_text = "Clefira"
	brand_box.add_child(brand_logo)
	var brand_text := Label.new()
	brand_text.text = "Clefira"
	if _ui_title_font != null:
		brand_text.add_theme_font_override("font", _ui_title_font)
	brand_text.add_theme_font_size_override("font_size", 18)
	brand_text.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	brand_box.add_child(brand_text)

	var title := Label.new()
	title.text = "Functional Ear Training"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _ui_title_font != null:
		title.add_theme_font_override("font", _ui_title_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98, 0.94))
	top.add_child(title)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 8)
	top.add_child(key_row)
	var key_lbl := Label.new()
	key_lbl.text = "Key:"
	key_lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96, 0.92))
	if _ui_font != null:
		key_lbl.add_theme_font_override("font", _ui_font)
	key_row.add_child(key_lbl)
	_key_option = OptionButton.new()
	_key_option.custom_minimum_size = Vector2(80, 36)
	for opt in KEY_CHOICES:
		_key_option.add_item(str(opt[0]))
	_key_option.selected = 0
	_key_option.item_selected.connect(_on_key_changed)
	_style_option_button(_key_option)
	key_row.add_child(_key_option)

	# Settings row: mode, level, 7ths, skip-prelude.
	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 16)
	root_v.add_child(settings_row)

	_mode_button = Button.new()
	_mode_button.toggle_mode = true
	_mode_button.text = "Major"
	_mode_button.custom_minimum_size = Vector2(110, 34)
	_mode_button.tooltip_text = "Switch between Major and Minor key harmony."
	_mode_button.toggled.connect(_on_mode_toggled)
	_style_panel_button(_mode_button, MENU_PRIMARY_ACCENT)
	settings_row.add_child(_mode_button)

	var level_lbl := Label.new()
	level_lbl.text = "Level:"
	level_lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96, 0.92))
	settings_row.add_child(level_lbl)
	_level_option = OptionButton.new()
	_level_option.custom_minimum_size = Vector2(140, 34)
	for lv in LEVELS:
		_level_option.add_item(str(lv["name"]))
	_level_option.selected = 0
	_level_option.tooltip_text = "Beginner = I/i, IV/iv, V.  Intermediate adds ii & vi.  Advanced = all seven."
	_level_option.item_selected.connect(_on_level_changed)
	_style_option_button(_level_option)
	settings_row.add_child(_level_option)

	_sevenths_check = CheckButton.new()
	_sevenths_check.text = "7th chords"
	_sevenths_check.tooltip_text = "Use diatonic 7th chords (Imaj7, ii7, V7 …) as the test chord."
	_sevenths_check.toggled.connect(_on_sevenths_toggled)
	settings_row.add_child(_sevenths_check)

	_inversions_check = CheckButton.new()
	_inversions_check.text = "Inversions"
	_inversions_check.tooltip_text = "Play the test chord in a random inversion — recognize the FUNCTION, not a fixed shape."
	_inversions_check.toggled.connect(_on_inversions_toggled)
	settings_row.add_child(_inversions_check)

	_dictation_check = CheckButton.new()
	_dictation_check.text = "Dictation"
	_dictation_check.tooltip_text = "Progression dictation: hear a 3–4 chord sequence and enter the whole Roman-numeral string, in order."
	_dictation_check.toggled.connect(_on_dictation_toggled)
	settings_row.add_child(_dictation_check)

	_skip_prelude_check = CheckButton.new()
	_skip_prelude_check.text = "Quick prelude"
	_skip_prelude_check.tooltip_text = "After the key is established, play only a brief tonic instead of the full progression."
	_skip_prelude_check.toggled.connect(_on_skip_prelude_toggled)
	settings_row.add_child(_skip_prelude_check)

	# Status + progress
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 0.96))
	if _ui_font != null:
		_status_label.add_theme_font_override("font", _ui_font)
	root_v.add_child(_status_label)

	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 24)
	root_v.add_child(meta_row)
	_progress_label = Label.new()
	_progress_label.text = "Q —"
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	meta_row.add_child(_progress_label)
	_score_label = Label.new()
	_score_label.text = "Score 0"
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.96, 1.0))
	meta_row.add_child(_score_label)
	_mastery_label = Label.new()
	_mastery_label.text = ""
	_mastery_label.add_theme_font_size_override("font_size", 14)
	_mastery_label.add_theme_color_override("font_color", Color(0.62, 0.95, 0.74, 0.96))
	meta_row.add_child(_mastery_label)

	# Dictation: the building "Your answer: V – I – _" sequence.
	_sequence_label = Label.new()
	_sequence_label.text = ""
	_sequence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sequence_label.add_theme_font_size_override("font_size", 18)
	_sequence_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.56, 0.98))
	if _ui_title_font != null:
		_sequence_label.add_theme_font_override("font", _ui_title_font)
	root_v.add_child(_sequence_label)

	# Start / Replay / Next row
	var control_row := HBoxContainer.new()
	control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	control_row.add_theme_constant_override("separation", 14)
	root_v.add_child(control_row)
	_start_button = Button.new()
	_start_button.text = "%s  Start" % char(0x25B6)
	_start_button.custom_minimum_size = Vector2(150, 46)
	_start_button.pressed.connect(_on_start_pressed)
	_style_panel_button(_start_button, MENU_PRIMARY_ACCENT)
	control_row.add_child(_start_button)
	_replay_button = Button.new()
	_replay_button.text = "%s  Replay" % char(0x21BB)
	_replay_button.custom_minimum_size = Vector2(150, 46)
	_replay_button.disabled = true
	_replay_button.pressed.connect(_on_replay_pressed)
	_style_panel_button(_replay_button, Color(0.46, 0.74, 0.92, 1.0))
	control_row.add_child(_replay_button)
	_next_button = Button.new()
	_next_button.text = "Next  %s" % char(0x2192)
	_next_button.custom_minimum_size = Vector2(150, 46)
	_next_button.visible = false
	_next_button.pressed.connect(_on_next_pressed)
	_style_panel_button(_next_button, MENU_PRIMARY_ACCENT)
	control_row.add_child(_next_button)
	# Undo the last entered chord (dictation only).
	_undo_button = Button.new()
	_undo_button.text = "%s  Undo" % char(0x232B)
	_undo_button.custom_minimum_size = Vector2(120, 46)
	_undo_button.visible = false
	_undo_button.pressed.connect(_on_undo_pressed)
	_style_panel_button(_undo_button, Color(0.92, 0.62, 0.46, 1.0))
	control_row.add_child(_undo_button)

	var answer_top_spacer := Control.new()
	answer_top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	answer_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_v.add_child(answer_top_spacer)

	# Answer grid: one button per degree index; visibility set per mode/level.
	_answer_row = GridContainer.new()
	_answer_row.columns = 7
	_answer_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_answer_row.add_theme_constant_override("h_separation", 10)
	_answer_row.add_theme_constant_override("v_separation", 8)
	root_v.add_child(_answer_row)
	for i in range(7):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 56)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)
		_style_panel_button(btn, BTN_ACCENT_NEUTRAL)
		btn.disabled = true
		var captured_i := i
		btn.pressed.connect(func(): _on_answer_pressed(captured_i))
		_answer_row.add_child(btn)
		_answer_buttons.append(btn)

	var answer_bottom_spacer := Control.new()
	answer_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	answer_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_v.add_child(answer_bottom_spacer)

	_refresh_answer_buttons()


# --- Settings handlers ---


func _on_key_changed(idx: int) -> void:
	if idx < 0 or idx >= KEY_CHOICES.size():
		return
	_key_pc = int(KEY_CHOICES[idx][1])
	_key_label = str(KEY_CHOICES[idx][0])
	_soft_reset()
	if _status_label != null:
		_status_label.text = "Key set to %s %s. Tap Start." % [_key_label, _mode]


func _on_mode_toggled(pressed: bool) -> void:
	_mode = "minor" if pressed else "major"
	if _mode_button != null:
		_mode_button.text = "Minor" if pressed else "Major"
	_refresh_answer_buttons()
	_soft_reset()
	if _status_label != null:
		_status_label.text = "%s %s selected. Tap Start." % [_key_label, _mode]


func _on_level_changed(idx: int) -> void:
	_level = clampi(idx, 0, LEVELS.size() - 1)
	_refresh_answer_buttons()
	_soft_reset()
	if _status_label != null:
		_status_label.text = "%s level. Tap Start." % str(LEVELS[_level]["name"])


func _on_sevenths_toggled(pressed: bool) -> void:
	_use_sevenths = pressed
	_soft_reset()
	if _status_label != null:
		_status_label.text = ("7th chords on. " if pressed else "Triads. ") + "Tap Start."


func _on_inversions_toggled(pressed: bool) -> void:
	_use_inversions = pressed
	_soft_reset()
	if _status_label != null:
		_status_label.text = ("Inversions on. " if pressed else "Root position. ") + "Tap Start."


func _on_skip_prelude_toggled(pressed: bool) -> void:
	_skip_prelude = pressed


# --- Round handlers ---


func _on_back_pressed() -> void:
	dismiss()
	closed.emit()


func _on_start_pressed() -> void:
	_session_token += 1
	_question_index = 0
	_score = 0
	_key_established = false
	_refresh_progress()
	_next_question()


func _on_replay_pressed() -> void:
	if _dictation:
		if not _correct_seq.is_empty():
			_replay_dictation_chords()
		return
	if _correct_idx < 0:
		return
	_play_test_chord_only()


func _on_undo_pressed() -> void:
	if not _dictation or _awaiting_next or _answer_seq.is_empty():
		return
	_answer_seq.remove_at(_answer_seq.size() - 1)
	_update_sequence_label()


func _on_dictation_toggled(pressed: bool) -> void:
	_dictation = pressed
	if _undo_button != null:
		_undo_button.visible = pressed
	_soft_reset()
	if _status_label != null:
		_status_label.text = ("Progression dictation: hear a sequence, then tap the Roman numerals in order. " if pressed else "Single-chord mode. ") + "Tap Start."


func _on_next_pressed() -> void:
	_advance_after_answer()


func _on_answer_pressed(idx: int) -> void:
	if _dictation:
		_on_dictation_answer(idx)
		return
	if _correct_idx < 0:
		return
	if Time.get_ticks_msec() < _busy_until_msec:
		return
	if not _is_index_active(idx):
		return
	_set_answer_row_enabled(false)
	var is_correct: bool = (idx == _correct_idx)
	var defs: Array = _current_degrees()
	var picked_label: String = str(defs[idx]["roman"])
	var correct_def: Dictionary = defs[_correct_idx]
	var correct_label: String = str(correct_def["roman"])
	var key_name := "%s %s" % [_key_label, _mode]
	if is_correct:
		_score += 1
		_answer_buttons[idx].add_theme_color_override("font_color", BTN_ACCENT_CORRECT)
		_status_label.text = "%s  Correct! %s is the %s chord in %s — %s." % [
			char(0x2713), correct_label, str(correct_def["quality"]), key_name, str(correct_def["tendency"])
		]
		if _play_correct_sfx_callable.is_valid():
			_play_correct_sfx_callable.call()
	else:
		_answer_buttons[idx].add_theme_color_override("font_color", BTN_ACCENT_WRONG)
		_answer_buttons[_correct_idx].add_theme_color_override("font_color", BTN_ACCENT_CORRECT)
		# Deeper teaching: name it, explain its tendency, give a memory hook.
		_status_label.text = "%s  That was %s (%s) in %s — %s.\nYou picked %s. Listen: your pick, then the real %s.  (%s)" % [
			char(0x2717), correct_label, str(correct_def["quality"]), key_name, str(correct_def["tendency"]),
			picked_label, correct_label, str(correct_def["song"])
		]
		if _play_wrong_sfx_callable.is_valid():
			_play_wrong_sfx_callable.call()
	# Adaptive bookkeeping + persistent per-function mastery.
	_review.record_result(_item_id(_correct_idx), is_correct)
	_save_progress()
	_refresh_progress()
	_update_mastery_label()
	_busy_until_msec = Time.get_ticks_msec() + 1400
	if is_correct:
		var my_token := _session_token
		get_tree().create_timer(1.6).timeout.connect(func():
			if my_token != _session_token or not is_inside_tree() or not visible:
				return
			_advance_after_answer()
		)
	else:
		# Wrong — play your-pick vs the correct chord so the difference is audible,
		# then wait for Next.
		_awaiting_next = true
		_play_compare_picked_correct(idx, _correct_idx)
		if _replay_button != null:
			_replay_button.disabled = false
		if _next_button != null:
			_next_button.visible = true
			_next_button.disabled = false
			_next_button.grab_focus()


# Shared advance — used by the correct-answer timer and the Next button.
func _advance_after_answer() -> void:
	_awaiting_next = false
	if _next_button != null:
		_next_button.visible = false
	if _question_index >= ROUND_LENGTH:
		_finish_round()
	else:
		_next_question()


# --- Round driving ---


func _next_question() -> void:
	_awaiting_next = false
	if _next_button != null:
		_next_button.visible = false
	_question_index += 1
	_refresh_progress()
	if _dictation:
		_start_dictation_question()
		return
	# Adaptive: ReviewQueue weights toward missed/under-practiced functions.
	_correct_idx = _pick_next_degree_idx()
	_current_inversion = 0
	if _use_inversions:
		var size := int((_current_degrees()[_correct_idx]["seventh"] if _use_sevenths else _current_degrees()[_correct_idx]["triad"]).size())
		_current_inversion = randi() % maxi(1, size)
	for b in _answer_buttons:
		b.remove_theme_color_override("font_color")
		b.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_set_answer_row_enabled(false)
	_status_label.text = "Listen to the key, then the test chord…"
	_play_prelude_then_test()


# Plays a key-establishing progression. Returns false if the round was
# invalidated (settings changed / panel closed) mid-play.
func _play_prelude(my_token: int) -> bool:
	var base_root_midi: int = 60 + (_key_pc % 12)
	var defs: Array = _current_degrees()
	var prelude: Array
	if _skip_prelude and _key_established:
		prelude = [0]
	else:
		prelude = PRELUDES[randi() % PRELUDES.size()]
	for step_idx in prelude:
		var d: Dictionary = defs[int(step_idx)]
		var chord: Array[int] = _build_chord_notes(base_root_midi + int(d["semis"]), d["triad"])
		await _play_chord_callable.call(chord, CADENCE_CHORD_DUR_SEC)
		if my_token != _session_token:
			return false
		await get_tree().create_timer(CADENCE_GAP_SEC).timeout
		if my_token != _session_token:
			return false
	_key_established = true
	return true


func _play_prelude_then_test() -> void:
	var my_token := _session_token
	if not _play_chord_callable.is_valid():
		return
	if not await _play_prelude(my_token):
		return
	await get_tree().create_timer(TEST_CHORD_DELAY_SEC).timeout
	if my_token != _session_token:
		return
	_play_test_chord_only()


func _play_test_chord_only() -> void:
	if _correct_idx < 0 or not _play_chord_callable.is_valid():
		return
	var notes: Array[int] = _test_chord_notes(_correct_idx, _current_inversion)
	_play_chord_callable.call(notes, TEST_CHORD_DUR_SEC)
	get_tree().create_timer(0.25).timeout.connect(func():
		if visible and not _awaiting_next:
			_set_answer_row_enabled(true)
			if _status_label != null:
				_status_label.text = "What role is that chord in %s %s?" % [_key_label, _mode]
	)


# --- Progression dictation ---


func _start_dictation_question() -> void:
	_correct_seq = _pick_dictation_progression()
	_answer_seq = []
	_correct_idx = _correct_seq[0] if not _correct_seq.is_empty() else 0   # keep guards happy
	for b in _answer_buttons:
		b.remove_theme_color_override("font_color")
		b.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_set_answer_row_enabled(false)
	_update_sequence_label()
	_status_label.text = "Listen to the key, then a %d-chord progression…" % _correct_seq.size()
	_play_dictation_sequence()


func _play_dictation_sequence() -> void:
	var my_token := _session_token
	if not _play_chord_callable.is_valid():
		return
	if not await _play_prelude(my_token):
		return
	await get_tree().create_timer(TEST_CHORD_DELAY_SEC).timeout
	if my_token != _session_token:
		return
	for deg in _correct_seq:
		await _play_chord_callable.call(_test_chord_notes(int(deg), 0), CADENCE_CHORD_DUR_SEC + 0.18)
		if my_token != _session_token:
			return
		await get_tree().create_timer(0.12).timeout
		if my_token != _session_token:
			return
	if visible and not _awaiting_next:
		_set_answer_row_enabled(true)
		_status_label.text = "Enter the progression (%d chords): tap each Roman numeral in order." % _correct_seq.size()


# Replays just the progression chords (no prelude) — for review.
func _replay_dictation_chords() -> void:
	var my_token := _session_token
	if not _play_chord_callable.is_valid():
		return
	for deg in _correct_seq:
		await _play_chord_callable.call(_test_chord_notes(int(deg), 0), CADENCE_CHORD_DUR_SEC + 0.18)
		if my_token != _session_token:
			return
		await get_tree().create_timer(0.12).timeout
		if my_token != _session_token:
			return


func _on_dictation_answer(idx: int) -> void:
	if _correct_seq.is_empty() or _awaiting_next:
		return
	if Time.get_ticks_msec() < _busy_until_msec:
		return
	if not _is_index_active(idx):
		return
	if _answer_seq.size() >= _correct_seq.size():
		return
	_answer_seq.append(idx)
	_update_sequence_label()
	# Echo the entered chord so the student hears their choice.
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(_test_chord_notes(idx, 0), 0.5)
	if _answer_seq.size() == _correct_seq.size():
		_grade_dictation()


func _grade_dictation() -> void:
	_set_answer_row_enabled(false)
	var all_correct := true
	for i in range(_correct_seq.size()):
		var c := int(_correct_seq[i])
		var a := int(_answer_seq[i]) if i < _answer_seq.size() else -1
		var ok := (a == c)
		if not ok:
			all_correct = false
		_review.record_result(_item_id(c), ok)
	_save_progress()
	_update_mastery_label()
	if all_correct:
		_score += 1
		if _play_correct_sfx_callable.is_valid():
			_play_correct_sfx_callable.call()
		_status_label.text = "%s  Correct! The progression was  %s." % [char(0x2713), _seq_roman_string(_correct_seq)]
	else:
		if _play_wrong_sfx_callable.is_valid():
			_play_wrong_sfx_callable.call()
		_status_label.text = "%s  The progression was  %s.\nYou entered  %s.  Replay to hear it again, then Next." % [
			char(0x2717), _seq_roman_string(_correct_seq), _seq_roman_string(_answer_seq)
		]
	_refresh_progress()
	_busy_until_msec = Time.get_ticks_msec() + 1400
	if all_correct:
		var my_token := _session_token
		get_tree().create_timer(1.6).timeout.connect(func():
			if my_token != _session_token or not is_inside_tree() or not visible:
				return
			_advance_after_answer()
		)
	else:
		_awaiting_next = true
		if _replay_button != null:
			_replay_button.disabled = false
		if _next_button != null:
			_next_button.visible = true
			_next_button.disabled = false
			_next_button.grab_focus()


func _pick_dictation_progression() -> Array[int]:
	var active: Array = _active_indices()
	var pool: Array = []
	for prog in DICTATION_PROGRESSIONS[_mode]:
		var ok := true
		for d in prog:
			if not active.has(int(d)):
				ok = false
				break
		if ok:
			pool.append(prog)
	var chosen: Array = pool[randi() % pool.size()] if not pool.is_empty() else [0, 4, 0]
	var out: Array[int] = []
	for d in chosen:
		out.append(int(d))
	return out


func _update_sequence_label() -> void:
	if _sequence_label == null:
		return
	if not _dictation or _correct_seq.is_empty():
		_sequence_label.text = ""
		return
	var defs: Array = _current_degrees()
	var parts: Array[String] = []
	for i in range(_correct_seq.size()):
		if i < _answer_seq.size():
			parts.append(str(defs[int(_answer_seq[i])]["roman"]))
		else:
			parts.append("_")
	_sequence_label.text = "Your answer:   %s" % "  –  ".join(parts)


func _seq_roman_string(seq: Array) -> String:
	var defs: Array = _current_degrees()
	var parts: Array[String] = []
	for d in seq:
		parts.append(str(defs[int(d)]["roman"]))
	return "  –  ".join(parts)


# Plays the student's (wrong) pick, then the correct chord, so the ear hears the
# contrast that the explanation describes.
func _play_compare_picked_correct(picked_idx: int, correct_idx: int) -> void:
	var my_token := _session_token
	if not _play_chord_callable.is_valid():
		return
	await get_tree().create_timer(0.45).timeout
	if my_token != _session_token or not visible:
		return
	await _play_chord_callable.call(_test_chord_notes(picked_idx), 0.9)
	if my_token != _session_token or not visible:
		return
	await get_tree().create_timer(COMPARE_GAP_SEC).timeout
	if my_token != _session_token or not visible:
		return
	await _play_chord_callable.call(_test_chord_notes(correct_idx), 1.1)


func _finish_round() -> void:
	var pct: int = int(round(float(_score) / float(maxi(1, ROUND_LENGTH)) * 100.0))
	var verdict := "Excellent — keep going!"
	if pct < 50:
		verdict = "Keep practicing — recognizing function takes ear training time."
	elif pct < 75:
		verdict = "Solid. The next round will sharpen the weaker degrees."
	var summary := _progress_summary()
	if summary != "":
		verdict += "\n" + summary
	_status_label.text = "Round complete — %d / %d  (%d%%). %s\nTap Start for another round." % [_score, ROUND_LENGTH, pct, verdict]
	_update_mastery_label()
	_correct_idx = -1
	_correct_seq = []
	_answer_seq = []
	_update_sequence_label()
	_awaiting_next = false
	if _next_button != null:
		_next_button.visible = false
	if _replay_button != null:
		_replay_button.disabled = true


# --- Helpers ---


func _current_degrees() -> Array:
	return DEGREES[_mode]


func _active_indices() -> Array:
	return LEVELS[_level]["idx"]


# Stable per-function id for the review queue / persistence (e.g. "major:V").
func _item_id(degree_idx: int) -> String:
	return "%s:%s" % [_mode, str(_current_degrees()[degree_idx]["roman"])]


# Adaptive selection: ask the ReviewQueue which active function to test next
# (weighted toward misses / under-practiced), then map it back to a degree index.
func _pick_next_degree_idx() -> int:
	var active: Array = _active_indices()
	var candidates: Array[String] = []
	var id_to_idx: Dictionary = {}
	for i in active:
		var id := _item_id(int(i))
		candidates.append(id)
		id_to_idx[id] = int(i)
	var picked := _review.pick_next(candidates)
	if picked == "" or not id_to_idx.has(picked):
		return int(active[randi() % active.size()])
	return int(id_to_idx[picked])


func _save_progress() -> void:
	var data := {
		"misses": _review.misses,
		"attempts": _review.attempts,
		"corrects": _review.corrects,
		"streaks": _review.streaks,
	}
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	_review.misses = d.get("misses", {})
	_review.attempts = d.get("attempts", {})
	_review.corrects = d.get("corrects", {})
	_review.streaks = d.get("streaks", {})


# Per-function accuracy summary over the active functions (needs ≥2 attempts).
func _progress_summary() -> String:
	var defs: Array = _current_degrees()
	var best_roman := ""
	var best_acc := -1.0
	var worst_roman := ""
	var worst_acc := 2.0
	for i in _active_indices():
		var id := _item_id(int(i))
		var att := int(_review.attempts.get(id, 0))
		if att < 2:
			continue
		var acc := float(int(_review.corrects.get(id, 0))) / float(att)
		var roman := str(defs[int(i)]["roman"])
		if acc > best_acc:
			best_acc = acc
			best_roman = roman
		if acc < worst_acc:
			worst_acc = acc
			worst_roman = roman
	if best_roman == "":
		return ""
	var s := "Strongest: %s %d%%" % [best_roman, int(round(best_acc * 100.0))]
	if worst_roman != "" and worst_roman != best_roman:
		s += "   ·   Focus next: %s %d%%" % [worst_roman, int(round(worst_acc * 100.0))]
	return s


# Compact "mastered" indicator: functions with a strong streak AND high accuracy.
func _update_mastery_label() -> void:
	if _mastery_label == null:
		return
	var defs: Array = _current_degrees()
	var mastered: Array[String] = []
	for i in _active_indices():
		var id := _item_id(int(i))
		var att := int(_review.attempts.get(id, 0))
		if att < 3:
			continue
		var acc := float(int(_review.corrects.get(id, 0))) / float(att)
		if int(_review.streaks.get(id, 0)) >= MASTERY_STREAK and acc >= MASTERY_ACCURACY:
			mastered.append(str(defs[int(i)]["roman"]))
	_mastery_label.text = ("%s Mastered: %s" % [char(0x2605), ", ".join(mastered)]) if not mastered.is_empty() else ""


func _is_index_active(idx: int) -> bool:
	return _active_indices().has(idx)


func _test_chord_notes(degree_idx: int, inversion: int = 0) -> Array[int]:
	var d: Dictionary = _current_degrees()[degree_idx]
	var base_root_midi: int = 60 + (_key_pc % 12) + int(d["semis"])
	var intervals: Array = d["seventh"] if _use_sevenths else d["triad"]
	var notes: Array[int] = _build_chord_notes(base_root_midi, intervals)
	# Invert by moving the lowest `inversion` tones up an octave, then re-sort.
	var inv: int = clampi(inversion, 0, notes.size() - 1)
	for k in range(inv):
		notes[k] += 12
	notes.sort()
	return notes


func _build_chord_notes(root_midi: int, intervals: Array) -> Array[int]:
	var notes: Array[int] = []
	for iv in intervals:
		notes.append(root_midi + int(iv))
	return notes


# Relabels the answer buttons for the active mode and shows only the functions
# allowed by the current level (a Beginner sees just three buttons).
func _refresh_answer_buttons() -> void:
	var defs: Array = _current_degrees()
	var active: Array = _active_indices()
	for i in range(_answer_buttons.size()):
		var btn := _answer_buttons[i]
		if btn == null:
			continue
		var d: Dictionary = defs[i]
		btn.text = str(d["roman"])
		btn.tooltip_text = "%s — the %s chord on degree %d" % [str(d["roman"]), str(d["quality"]), i + 1]
		btn.visible = active.has(i)


func _set_answer_row_enabled(enabled: bool) -> void:
	var active: Array = _active_indices()
	for i in range(_answer_buttons.size()):
		_answer_buttons[i].disabled = not (enabled and active.has(i))
	if _replay_button != null:
		_replay_button.disabled = not enabled


func _soft_reset() -> void:
	# Cancel any in-flight question and return to the "tap Start" state. Called
	# when a setting changes so the active question can't mismatch the new config.
	_session_token += 1
	_correct_idx = -1
	_awaiting_next = false
	_key_established = false
	_correct_seq = []
	_answer_seq = []
	_update_sequence_label()
	if _next_button != null:
		_next_button.visible = false
	if _replay_button != null:
		_replay_button.disabled = true
	for b in _answer_buttons:
		if b != null:
			b.remove_theme_color_override("font_color")
			b.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	_set_answer_row_enabled(false)


func _refresh_progress() -> void:
	if _progress_label != null:
		_progress_label.text = "Q %d / %d" % [maxi(_question_index, 0), ROUND_LENGTH]
	if _score_label != null:
		_score_label.text = "Score %d" % _score


# --- Styling / responsive ---


func _style_panel_button(btn: Button, accent: Color) -> void:
	if btn == null:
		return
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var fill := Color(0.10, 0.17, 0.27, 0.96)
		if state == "hover":
			fill = Color(0.13, 0.21, 0.32, 0.98)
		elif state == "pressed":
			fill = Color(0.08, 0.14, 0.22, 1.0)
		elif state == "disabled":
			fill = Color(0.10, 0.14, 0.20, 0.55)
		sb.bg_color = fill
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.30 if state == "disabled" else 0.85)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 9
		sb.corner_radius_top_right = 9
		sb.corner_radius_bottom_left = 9
		sb.corner_radius_bottom_right = 9
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		btn.add_theme_stylebox_override(state, sb)
	if _ui_font != null:
		btn.add_theme_font_override("font", _ui_font)


func _style_option_button(opt: OptionButton) -> void:
	if opt == null:
		return
	_style_panel_button(opt, MENU_PRIMARY_ACCENT)
	opt.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	opt.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.78, 1.0))
	opt.add_theme_color_override("font_pressed_color", MENU_TITLE_TEXT)
	call_deferred("_style_option_popup", opt)


func _style_option_popup(opt_ctrl: Control) -> void:
	var opt := opt_ctrl as OptionButton
	if opt == null or not is_instance_valid(opt):
		return
	var popup := opt.get_popup()
	if popup == null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.08, 0.15, 0.98)
	panel.border_color = Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.88)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	panel.content_margin_left = 6
	panel.content_margin_right = 6
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.80, 1.0))
	popup.add_theme_color_override("font_selected_color", Color(1.0, 0.96, 0.80, 1.0))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.10, 0.21, 0.36, 0.98)
	hover.border_color = Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.88)
	hover.border_width_left = 1
	hover.border_width_top = 1
	hover.border_width_right = 1
	hover.border_width_bottom = 1
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_stylebox_override("highlight", hover)
	var selected: StyleBoxFlat = hover.duplicate()
	selected.bg_color = Color(0.14, 0.27, 0.42, 0.98)
	popup.add_theme_stylebox_override("selected", selected)
	popup.add_theme_stylebox_override("pressed", selected)


func _apply_responsive_layout() -> void:
	if _answer_row == null:
		return
	var w: float = size.x if size.x > 0 else 1366.0
	var cols := 7
	var btn_w := 96
	var btn_h := 56
	if w < 560.0:
		cols = 4
		btn_w = 74
		btn_h = 50
	elif w < 760.0:
		cols = 7
		btn_w = 82
		btn_h = 52
	_answer_row.columns = cols
	for b in _answer_buttons:
		if b != null:
			b.custom_minimum_size = Vector2(btn_w, btn_h)
