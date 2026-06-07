class_name BuildChordQuizPanel
extends PanelContainer

# Guided Practice — fullscreen guided-mode quiz screen, separate from
# Chord Explorer. Five exercise modes, four difficulty levels, escalating
# hint system, and "missing/extra notes" feedback for the Build mode.
#
# Modes:
#   1. Build a Chord     — student picks notes on keyboard/MIDI to form
#                          the named chord. Feedback: "Add Eb." / "F
#                          doesn't belong in Cm."
#   2. Identify Quality  — app plays a chord, student picks the quality.
#   3. Compare Sounds    — A then B, student picks B's quality.
#   4. Chord Function    — "Build the V chord in C major" — student picks
#                          notes for the diatonic chord at that scale
#                          degree.
#   5. Progression       — "Build I-IV-V-I in C" — student builds 3-4
#                          chords in sequence; the chord at each step
#                          locks in when correct.
#
# Difficulty levels:
#   Beginner      — major + minor triads, root position, C/G/F/D/A
#   Early Piano   — + diminished triads, I/IV/V/vi
#   Intermediate  — + 7th chords, inversions, ii-V-I, minor keys
#   Advanced      — + extensions, altered, borrowed, modal mixture
#
# Hint escalation:
#   1. "This chord has N notes."
#   2. "Starts on G."
#   3. "Use root + M3 + P5."
#   4. "The notes are G, B, D."
#
# Parent (interval_birds.gd) injects audio callables + routes MIDI
# events here when the panel is visible.


# --- Signals ---
signal closed
signal presented
signal chord_quiz_completed(score: int, total: int, report: Dictionary)


# --- Constants ---
const KEYBOARD_LOW := 48   # C3
const KEYBOARD_HIGH := 84  # C6
const WHITE_W := 34.0
const WHITE_H := 150.0
const BLACK_W := 22.0
const BLACK_H := 94.0
const QUESTIONS_PER_ROUND := 10
const CHOICES_COUNT := 4

const MENU_TITLE_TEXT := Color(0.9176, 0.9529, 1.0, 1.0)
const MENU_PRIMARY_ACCENT := Color(0.9098, 0.6275, 0.1255, 1.0)
const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT  := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Quality → semitone intervals from root.
const QUALITY_INTERVALS: Dictionary = {
	"Major":    [0, 4, 7],
	"Minor":    [0, 3, 7],
	"Dim":      [0, 3, 6],
	"Aug":      [0, 4, 8],
	"Sus2":     [0, 2, 7],
	"Sus4":     [0, 5, 7],
	"Maj7":     [0, 4, 7, 11],
	"Dom7":     [0, 4, 7, 10],
	"Min7":     [0, 3, 7, 10],
	"Dim7":     [0, 3, 6, 9],
	"Half-dim": [0, 3, 6, 10],
	"mMaj7":    [0, 3, 7, 11],
	"Maj6":     [0, 4, 7, 9],
	"Min6":     [0, 3, 7, 9],
	"Add9":     [0, 4, 7, 14],
}

const QUALITY_PRETTY: Dictionary = {
	"Major": "major", "Minor": "minor", "Dim": "diminished", "Aug": "augmented",
	"Sus2": "sus2", "Sus4": "sus4",
	"Maj7": "Maj7", "Dom7": "Dom7", "Min7": "Min7",
	"Dim7": "Dim7", "Half-dim": "Half-dim", "mMaj7": "mMaj7",
	"Maj6": "Maj6", "Min6": "Min6", "Add9": "Add9",
}

# Compare-Sounds A/B pairs with distractors.
const COMPARE_PAIRS: Array[Dictionary] = [
	{"a": "Major",    "b": "Minor",    "distractors": ["Dim", "Sus4", "Sus2"]},
	{"a": "Major",    "b": "Aug",      "distractors": ["Minor", "Sus2", "Sus4"]},
	{"a": "Major",    "b": "Maj7",     "distractors": ["Dom7", "Min7", "Add9"]},
	{"a": "Major",    "b": "Dom7",     "distractors": ["Maj7", "Min7", "Maj6"]},
	{"a": "Maj7",     "b": "Dom7",     "distractors": ["Min7", "mMaj7", "Half-dim"]},
	{"a": "Dom7",     "b": "Min7",     "distractors": ["Maj7", "Half-dim", "mMaj7"]},
	{"a": "Dim",      "b": "Half-dim", "distractors": ["Dim7", "Minor", "Min7"]},
	{"a": "Major",    "b": "Sus4",     "distractors": ["Sus2", "Minor", "Aug"]},
]

# Diatonic scale + chord-quality patterns used for Chord Function +
# Progression Builder modes. Scale degrees 0-6 → (semitone offset, quality).
const MAJOR_SCALE: Array = [0, 2, 4, 5, 7, 9, 11]
const MINOR_SCALE: Array = [0, 2, 3, 5, 7, 8, 10]
const MAJOR_DIATONIC: Array = [
	{"quality": "Major", "roman": "I"},
	{"quality": "Minor", "roman": "ii"},
	{"quality": "Minor", "roman": "iii"},
	{"quality": "Major", "roman": "IV"},
	{"quality": "Major", "roman": "V"},
	{"quality": "Minor", "roman": "vi"},
	{"quality": "Dim",   "roman": "vii°"},
]
const MINOR_DIATONIC: Array = [
	{"quality": "Minor", "roman": "i"},
	{"quality": "Dim",   "roman": "ii°"},
	{"quality": "Major", "roman": "III"},
	{"quality": "Minor", "roman": "iv"},
	{"quality": "Minor", "roman": "v"},
	{"quality": "Major", "roman": "VI"},
	{"quality": "Major", "roman": "VII"},
]

# Progression templates by difficulty — Roman-numeral sequences the
# Progression Builder rotates through.
const PROGRESSIONS_BY_DIFFICULTY: Dictionary = {
	0: [  # Beginner
		{"label": "I-IV-V-I",   "degrees": [0, 3, 4, 0]},
		{"label": "I-V-vi-IV",  "degrees": [0, 4, 5, 3]},
		{"label": "I-vi-IV-V",  "degrees": [0, 5, 3, 4]},
	],
	1: [  # Early Piano
		{"label": "I-IV-V-I",   "degrees": [0, 3, 4, 0]},
		{"label": "I-V-vi-IV",  "degrees": [0, 4, 5, 3]},
		{"label": "vi-IV-I-V",  "degrees": [5, 3, 0, 4]},
		{"label": "I-vi-ii-V",  "degrees": [0, 5, 1, 4]},
	],
	2: [  # Intermediate
		{"label": "ii-V-I",     "degrees": [1, 4, 0]},
		{"label": "I-vi-ii-V",  "degrees": [0, 5, 1, 4]},
		{"label": "iii-vi-ii-V","degrees": [2, 5, 1, 4]},
		{"label": "I-IV-iii-vi","degrees": [0, 3, 2, 5]},
	],
	3: [  # Advanced
		{"label": "ii-V-I",     "degrees": [1, 4, 0]},
		{"label": "iii-VI-ii-V","degrees": [2, 5, 1, 4]},
		{"label": "I-V-vi-iii-IV-I-IV-V", "degrees": [0, 4, 5, 2, 3, 0, 3, 4]},
	],
}

# Difficulty selector data: chord pool + key pool + allowed modes per
# difficulty level. _start_round picks from these.
const DIFFICULTIES: Array[Dictionary] = [
	{
		"label": "Beginner",
		"qualities": ["Major", "Minor"],
		"keys": [0, 7, 5, 2, 9],  # C G F D A
		"allow_minor_key": false,
	},
	{
		"label": "Early Piano",
		"qualities": ["Major", "Minor", "Dim"],
		"keys": [0, 7, 5, 2, 9, 4],  # + E
		"allow_minor_key": false,
	},
	{
		"label": "Intermediate",
		"qualities": ["Major", "Minor", "Dim", "Aug", "Sus4", "Maj7", "Dom7", "Min7"],
		"keys": [0, 7, 5, 2, 9, 4, 11, 10, 3, 8],  # + B Bb Eb Ab
		"allow_minor_key": true,
	},
	{
		"label": "Advanced",
		"qualities": ["Major", "Minor", "Dim", "Aug", "Sus4", "Sus2",
			"Maj7", "Dom7", "Min7", "Dim7", "Half-dim", "mMaj7", "Maj6", "Add9"],
		"keys": [0, 7, 2, 9, 4, 11, 6, 5, 10, 3, 8, 1],  # + F# Db
		"allow_minor_key": true,
	},
]


enum Mode { BUILD, IDENTIFY, COMPARE, FUNCTION, PROGRESSION }


# --- Injected dependencies ---
var _ui_font: Font = null
var _ui_title_font: Font = null
var _play_note_callable: Callable = Callable()
var _play_chord_callable: Callable = Callable()


# --- State ---
var _mode: int = Mode.BUILD
var _difficulty: int = 0  # index into DIFFICULTIES
var _question_index: int = 0
var _score: int = 0
var _answered: bool = false
var _summary_shown: bool = false
var _session_attribution_pending: bool = false
var _play_token: int = 0
var _hint_stage: int = 0  # 0-4, advances on each Hint click
var _round_events: Array[Dictionary] = []
var _question_started_msec: int = 0
var _current_attempts: int = 0
var _current_wrong_attempts: int = 0
var _current_hints_used: int = 0

# Current question target
var _target_root_pc: int = 0
var _target_quality: String = "Major"
var _target_notes: Array[int] = []
var _target_key_label: String = "C"
var _target_key_root_pc: int = 0
var _target_key_is_minor: bool = false
var _target_degree: int = 0     # for Function mode
var _target_roman: String = ""  # for Function / Progression

# BUILD-mode selection
var _selected_notes: Dictionary = {}
# True after a wrong submission — _refresh_build_keyboard_highlight uses
# this to paint target notes green + wrong selections red on the keyboard.
# Cleared on next question / clear / new round.
var _show_wrong_feedback: bool = false

# COMPARE
var _compare_a_notes: Array[int] = []
var _compare_b_notes: Array[int] = []

# PROGRESSION
var _progression_steps: Array = []  # array of {degree, roman, quality, root_pc, notes}
var _progression_step_idx: int = 0


# --- Widgets ---
var _back_button: Button = null
var _mode_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _score_label: Label = null
var _prompt_label: Label = null
var _subprompt_label: Label = null  # used by Progression to show chord-step status
var _feedback_label: Label = null
var _next_button: Button = null
var _close_button: Button = null

# BUILD
var _build_root: Control = null
var _build_keyboard_keys: Dictionary = {}
var _build_keyboard_frame: Panel = null
var _build_keyboard_root: Control = null
var _build_selected_label: Label = null
var _build_submit_button: Button = null
var _build_clear_button: Button = null
var _build_hint_button: Button = null

# IDENTIFY/COMPARE shared
var _choices_row: HBoxContainer = null
var _play_button: Button = null

# Playback busy
var _playback_busy_until: float = 0.0
var _playback_lock_token: int = 0
var _playback_unlock_timer: Timer = null
var _playback_unlock_timer_token: int = 0
var _playback_buttons: Array[Button] = []


# --- Lifecycle ---


func setup(ui_font: Font, ui_title_font: Font, play_note: Callable, play_chord: Callable) -> void:
	_ui_font = ui_font
	_ui_title_font = ui_title_font
	_play_note_callable = play_note
	_play_chord_callable = play_chord
	# Pin to the viewport corners and zero the offsets so the panel really
	# covers the whole screen — without explicit offsets the panel can end
	# up smaller than viewport when its parent has its own margins.
	set_anchors_preset(PRESET_FULL_RECT, true)  # `keep_offsets=true` shouldn't matter since we set them next
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 1000  # above chord-explorer (780), home-menu cards, everything
	# Solid opaque dark background — without this the home-menu image
	# bleeds through wherever the inner content doesn't reach.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	bg.border_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", bg)
	_build_ui()


func present() -> void:
	# Re-pin offsets on every present in case the parent's layout pass
	# clobbered them between dismiss and re-present.
	set_anchors_preset(PRESET_FULL_RECT, true)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	visible = true
	move_to_front()
	_start_round()
	presented.emit()


func dismiss() -> void:
	visible = false
	_play_token += 1
	_playback_lock_token += 1
	_playback_busy_until = 0.0
	_stop_playback_unlock_timer()
	_set_playback_buttons_disabled(false)


# Parent routes MIDI note-on here when panel is visible AND mode wants
# note input (Build / Function / Progression).
func handle_midi_note_on(pitch: int) -> void:
	if not visible or _answered:
		return
	if _mode != Mode.BUILD and _mode != Mode.FUNCTION and _mode != Mode.PROGRESSION:
		return
	if pitch < KEYBOARD_LOW or pitch > KEYBOARD_HIGH:
		return
	_toggle_build_note(pitch)


# --- UI ---


func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 20)
	root_margin.add_theme_constant_override("margin_right", 20)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(root_margin)
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 7)
	root_margin.add_child(root_vbox)

	# Top bar: home + title + difficulty
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	root_vbox.add_child(top_bar)
	_back_button = Button.new()
	_back_button.text = char(0x2190)  # left-arrow — consistent "back" affordance
	_back_button.tooltip_text = "Back to Chord Explorer"
	_back_button.custom_minimum_size = Vector2(46, 46)
	_back_button.add_theme_font_size_override("font_size", 24)
	_apply_nav_icon_style(_back_button)
	_back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_button)
	# Clefira brand mark — same logo+wordmark box used by Chord Explorer, Practice
	# Drills and Functional Ear so every panel header reads as one product.
	var brand_box := HBoxContainer.new()
	brand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_box.add_theme_constant_override("separation", 8)
	top_bar.add_child(brand_box)
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
	title.text = "%s  Guided Practice" % char(0x1F3AF)  # bullseye
	if _ui_title_font != null:
		title.add_theme_font_override("font", _ui_title_font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)
	# Difficulty selector
	var diff_label := Label.new()
	diff_label.text = "Level:"
	diff_label.add_theme_font_size_override("font_size", 13)
	diff_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.82))
	top_bar.add_child(diff_label)
	var diff_opt := OptionButton.new()
	diff_opt.custom_minimum_size = Vector2(150, 38)
	diff_opt.add_theme_font_size_override("font_size", 13)
	for i in DIFFICULTIES.size():
		diff_opt.add_item(str(DIFFICULTIES[i]["label"]))
	diff_opt.selected = 0
	diff_opt.tooltip_text = "Pool of chords + keys grows with each level."
	diff_opt.item_selected.connect(_on_difficulty_selected)
	top_bar.add_child(diff_opt)

	# Mode pill row
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 6)
	root_vbox.add_child(mode_row)
	_make_mode_button(mode_row, Mode.BUILD,       "Build")
	_make_mode_button(mode_row, Mode.IDENTIFY,    "Identify")
	_make_mode_button(mode_row, Mode.COMPARE,     "Compare")
	_make_mode_button(mode_row, Mode.FUNCTION,    "Function")
	_make_mode_button(mode_row, Mode.PROGRESSION, "Progression")

	# Score line
	_score_label = Label.new()
	_score_label.text = ""
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.92))
	root_vbox.add_child(_score_label)

	# Prompt + sub-prompt
	_prompt_label = Label.new()
	_prompt_label.text = ""
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	root_vbox.add_child(_prompt_label)
	_subprompt_label = Label.new()
	_subprompt_label.text = ""
	_subprompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subprompt_label.add_theme_font_size_override("font_size", 15)
	_subprompt_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.85))
	_subprompt_label.visible = false
	root_vbox.add_child(_subprompt_label)

	# Build container (used by BUILD / FUNCTION / PROGRESSION)
	_build_root = _build_build_mode_ui()
	root_vbox.add_child(_build_root)

	# IDENTIFY/COMPARE: play button + multiple choice row
	_play_button = Button.new()
	_play_button.text = "%s  Play" % char(0x266A)
	_play_button.custom_minimum_size = Vector2(180, 44)
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_button.add_theme_font_size_override("font_size", 15)
	_play_button.pressed.connect(_on_play_pressed)
	root_vbox.add_child(_play_button)
	_playback_buttons.append(_play_button)
	_choices_row = HBoxContainer.new()
	_choices_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_choices_row)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 15)
	_feedback_label.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	root_vbox.add_child(_feedback_label)

	# Actions
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	root_vbox.add_child(actions)
	_next_button = Button.new()
	_next_button.text = "Next %s" % char(0x2192)
	_next_button.custom_minimum_size = Vector2(140, 38)
	_next_button.add_theme_font_size_override("font_size", 14)
	_next_button.disabled = true
	_next_button.pressed.connect(_on_advance_pressed)
	actions.add_child(_next_button)
	_close_button = Button.new()
	_close_button.text = "Back"
	_close_button.custom_minimum_size = Vector2(120, 38)
	_close_button.add_theme_font_size_override("font_size", 14)
	_close_button.pressed.connect(_on_back_pressed)
	actions.add_child(_close_button)

	_refresh_mode_styles()


func _build_build_mode_ui() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_build_selected_label = Label.new()
	_build_selected_label.text = "Currently selected: (none)"
	_build_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_selected_label.add_theme_font_size_override("font_size", 13)
	_build_selected_label.add_theme_color_override("font_color", Color(0.65, 0.92, 0.78, 0.92))
	col.add_child(_build_selected_label)
	var kb_wrap := HBoxContainer.new()
	kb_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	kb_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(kb_wrap)
	_build_keyboard_frame = Panel.new()
	_build_keyboard_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.10, 0.08, 0.07, 0.98)
	frame_style.border_color = Color(0.30, 0.20, 0.14, 1.0)
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.corner_radius_top_left = 12
	frame_style.corner_radius_top_right = 12
	frame_style.corner_radius_bottom_left = 12
	frame_style.corner_radius_bottom_right = 12
	frame_style.shadow_color = Color(0, 0, 0, 0.55)
	frame_style.shadow_size = 8
	_build_keyboard_frame.add_theme_stylebox_override("panel", frame_style)
	kb_wrap.add_child(_build_keyboard_frame)
	_build_keyboard_root = Control.new()
	_build_keyboard_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_keyboard_frame.add_child(_build_keyboard_root)
	_build_keyboard_widgets()
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	col.add_child(btn_row)
	_build_submit_button = Button.new()
	_build_submit_button.text = "Check"
	_build_submit_button.custom_minimum_size = Vector2(132, 36)
	_build_submit_button.add_theme_font_size_override("font_size", 14)
	_build_submit_button.pressed.connect(_on_build_submit)
	btn_row.add_child(_build_submit_button)
	_playback_buttons.append(_build_submit_button)
	_build_clear_button = Button.new()
	_build_clear_button.text = "Clear"
	_build_clear_button.custom_minimum_size = Vector2(112, 36)
	_build_clear_button.add_theme_font_size_override("font_size", 14)
	_build_clear_button.pressed.connect(_on_build_clear)
	btn_row.add_child(_build_clear_button)
	_build_hint_button = Button.new()
	_build_hint_button.text = "Hint %s" % char(0x1F4A1)
	_build_hint_button.custom_minimum_size = Vector2(112, 36)
	_build_hint_button.add_theme_font_size_override("font_size", 14)
	_build_hint_button.tooltip_text = "Each click reveals one more clue (4 stages: count → start note → intervals → exact notes)."
	_build_hint_button.pressed.connect(_on_build_hint)
	btn_row.add_child(_build_hint_button)
	return col


func _build_keyboard_widgets() -> void:
	var num_whites: int = 0
	for p in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if not _is_black(p):
			num_whites += 1
	var keys_w: float = num_whites * WHITE_W
	var pad: float = 10.0
	_build_keyboard_frame.custom_minimum_size = Vector2(keys_w + pad * 2, WHITE_H + pad * 2)
	_build_keyboard_root.position = Vector2(pad, pad)
	_build_keyboard_root.size = Vector2(keys_w, WHITE_H)
	var white_x: float = 0.0
	var white_positions: Dictionary = {}
	for pitch in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if _is_black(pitch):
			continue
		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = Vector2(white_x, 0)
		btn.size = Vector2(WHITE_W, WHITE_H)
		_apply_white_key_style(btn, KeyState.NORMAL)
		var captured := pitch
		btn.pressed.connect(func(): _toggle_build_note(captured))
		_build_keyboard_root.add_child(btn)
		_build_keyboard_keys[pitch] = btn
		var pc := ((pitch % 12) + 12) % 12
		var letter_for_pc := {0: "C", 2: "D", 4: "E", 5: "F", 7: "G", 9: "A", 11: "B"}
		var letter: String = String(letter_for_pc.get(pc, ""))
		if not letter.is_empty():
			var lbl := Label.new()
			if pc == 0:
				lbl.text = "C%d" % int(pitch / 12 - 1)
			else:
				lbl.text = letter
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.12, 0.20, 0.40, 0.95))
			lbl.position = Vector2(4, WHITE_H - 24)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lbl)
		white_positions[pitch] = white_x
		white_x += WHITE_W
	for pitch in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if not _is_black(pitch):
			continue
		var prev_white := pitch - 1
		if not white_positions.has(prev_white):
			continue
		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 1
		var bx: float = float(white_positions[prev_white]) + WHITE_W - BLACK_W * 0.5
		btn.position = Vector2(bx, 0)
		btn.size = Vector2(BLACK_W, BLACK_H)
		_apply_black_key_style(btn, KeyState.NORMAL)
		var captured := pitch
		btn.pressed.connect(func(): _toggle_build_note(captured))
		_build_keyboard_root.add_child(btn)
		_build_keyboard_keys[pitch] = btn


# Key state for keyboard styling:
#   NORMAL   — unselected, unhighlighted
#   SELECTED — student has it in their answer (blue)
#   TARGET   — wrong-answer feedback: this note is in the correct chord
#              (green) regardless of whether they picked it
#   WRONG    — wrong-answer feedback: they picked this but it isn't in
#              the correct chord (red)
enum KeyState { NORMAL, SELECTED, TARGET, WRONG }


func _apply_white_key_style(btn: Button, state: int) -> void:
	var sb := StyleBoxFlat.new()
	match state:
		KeyState.TARGET:
			sb.bg_color = Color(0.50, 0.92, 0.55, 1.0)  # green — "should have played"
		KeyState.WRONG:
			sb.bg_color = Color(0.96, 0.50, 0.42, 1.0)  # red — "shouldn't have played"
		KeyState.SELECTED:
			sb.bg_color = Color(0.55, 0.88, 1.0, 1.0)   # blue — currently selected
		_:
			sb.bg_color = Color(0.95, 0.94, 0.88, 1.0)  # cream
	sb.border_color = Color(0.62, 0.60, 0.58, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb.duplicate())
	btn.add_theme_stylebox_override("pressed", sb.duplicate())


func _apply_black_key_style(btn: Button, state: int) -> void:
	var sb := StyleBoxFlat.new()
	match state:
		KeyState.TARGET:
			sb.bg_color = Color(0.32, 0.78, 0.40, 1.0)  # green
		KeyState.WRONG:
			sb.bg_color = Color(0.82, 0.30, 0.26, 1.0)  # red
		KeyState.SELECTED:
			sb.bg_color = Color(0.36, 0.78, 1.00, 1.0)  # blue
		_:
			sb.bg_color = Color(0.10, 0.10, 0.12, 1.0)  # black
	sb.border_color = Color(0.02, 0.02, 0.04, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 3
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb.duplicate())
	btn.add_theme_stylebox_override("pressed", sb.duplicate())


func _is_black(pitch: int) -> bool:
	var pc := ((pitch % 12) + 12) % 12
	return pc in [1, 3, 6, 8, 10]


# --- Mode pills ---


func _make_mode_button(parent: Control, mode: int, label: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(124, 34)
	btn.add_theme_font_size_override("font_size", 13)
	btn.tooltip_text = _mode_tooltip(mode)
	btn.pressed.connect(func(): _select_mode(mode))
	parent.add_child(btn)
	_mode_buttons[mode] = btn


func _mode_tooltip(mode: int) -> String:
	match mode:
		Mode.BUILD:
			return "Build the named chord on the keyboard."
		Mode.IDENTIFY:
			return "Listen to a chord and identify its quality."
		Mode.COMPARE:
			return "Hear A then B and name what chord B became."
		Mode.FUNCTION:
			return "Build a Roman-numeral chord inside a key."
		Mode.PROGRESSION:
			return "Build each chord in a progression sequence."
		_:
			return ""


func _select_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	_refresh_mode_styles()
	_start_round()


func _refresh_mode_styles() -> void:
	for key in _mode_buttons.keys():
		var btn: Button = _mode_buttons[key] as Button
		if btn == null:
			continue
		var active: bool = (int(key) == _mode)
		var sb := StyleBoxFlat.new()
		var accent := MENU_PRIMARY_ACCENT if active else Color(0.36, 0.78, 1.00, 1.0)
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.20 if active else 0.08)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.92 if active else 0.50)
		sb.border_width_left = 2 if active else 1
		sb.border_width_right = 2 if active else 1
		sb.border_width_top = 2 if active else 1
		sb.border_width_bottom = 2 if active else 1
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


# --- Round lifecycle ---


func _on_difficulty_selected(idx: int) -> void:
	_difficulty = clampi(idx, 0, DIFFICULTIES.size() - 1)
	_start_round()


func _start_round() -> void:
	_question_index = 0
	_score = 0
	_summary_shown = false
	_session_attribution_pending = true
	_round_events.clear()
	_play_token += 1
	_playback_lock_token += 1
	_playback_busy_until = 0.0
	_set_playback_buttons_disabled(false)
	_clear_choice_buttons()
	_feedback_label.text = ""
	_next_button.disabled = true
	_next_button.text = "Next %s" % char(0x2192)
	_apply_mode_visibility()
	_next_question()


func _apply_mode_visibility() -> void:
	var uses_keyboard: bool = (_mode == Mode.BUILD or _mode == Mode.FUNCTION or _mode == Mode.PROGRESSION)
	_build_root.visible = uses_keyboard
	_play_button.visible = (_mode == Mode.IDENTIFY or _mode == Mode.COMPARE)
	_choices_row.visible = (_mode == Mode.IDENTIFY or _mode == Mode.COMPARE)
	_subprompt_label.visible = (_mode == Mode.PROGRESSION)


func _next_question() -> void:
	if _question_index >= QUESTIONS_PER_ROUND:
		_show_round_summary()
		return
	_question_index += 1
	_answered = false
	_hint_stage = 0
	_current_attempts = 0
	_current_wrong_attempts = 0
	_current_hints_used = 0
	_question_started_msec = Time.get_ticks_msec()
	_show_wrong_feedback = false
	_feedback_label.text = ""
	_next_button.disabled = true
	_play_token += 1
	_clear_choice_buttons()
	_selected_notes.clear()
	_refresh_build_keyboard_highlight()
	_update_score_label()
	match _mode:
		Mode.IDENTIFY:
			_question_identify_quality()
		Mode.COMPARE:
			_question_compare_sounds()
		Mode.FUNCTION:
			_question_chord_function()
		Mode.PROGRESSION:
			_question_progression()
		_:
			_question_build_chord()


func _update_score_label() -> void:
	_score_label.text = "Question %d of %d   Score: %d" % [_question_index, QUESTIONS_PER_ROUND, _score]


# --- Question generators ---


# Build a Chord
func _question_build_chord() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var diff: Dictionary = DIFFICULTIES[_difficulty]
	var qualities: Array = diff["qualities"]
	var keys: Array = diff["keys"]
	_target_quality = str(qualities[rng.randi_range(0, qualities.size() - 1)])
	_target_root_pc = int(keys[rng.randi_range(0, keys.size() - 1)])
	_target_key_label = _spell_root(_target_root_pc, _target_root_pc in [1, 3, 8, 10])
	_target_key_root_pc = _target_root_pc
	_target_key_is_minor = false
	_set_target_notes(_target_root_pc, _target_quality)
	_prompt_label.text = "Build %s%s." % [_target_key_label, _quality_suffix(_target_quality)]
	_update_build_selected_label()


# Identify Quality
func _question_identify_quality() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var diff: Dictionary = DIFFICULTIES[_difficulty]
	var qualities: Array = diff["qualities"]
	_target_quality = str(qualities[rng.randi_range(0, qualities.size() - 1)])
	_target_root_pc = rng.randi_range(0, 11)
	_target_key_label = _spell_root(_target_root_pc, _target_root_pc in [1, 3, 8, 10])
	_set_target_notes(_target_root_pc, _target_quality)
	# Choice pool drawn from same difficulty's qualities.
	var pool: Array = qualities.duplicate()
	pool.erase(_target_quality)
	pool.shuffle()
	var choices: Array[String] = [_target_quality]
	for i in mini(CHOICES_COUNT - 1, pool.size()):
		choices.append(str(pool[i]))
	choices.shuffle()
	_render_choice_buttons(choices)
	_prompt_label.text = "Listen, then pick the chord quality."
	_play_button.text = "%s  Play chord" % char(0x266A)
	_play_button.disabled = false
	_play_identify_target()


# Compare Sounds
func _question_compare_sounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Filter compare pairs to qualities the difficulty allows.
	var diff: Dictionary = DIFFICULTIES[_difficulty]
	var allowed: Array = diff["qualities"]
	var pairs: Array = []
	for p in COMPARE_PAIRS:
		var qa: String = str(p["a"])
		var qb: String = str(p["b"])
		if allowed.has(qa) and allowed.has(qb):
			pairs.append(p)
	if pairs.is_empty():
		pairs = COMPARE_PAIRS
	var pair: Dictionary = pairs[rng.randi_range(0, pairs.size() - 1)]
	var qa: String = str(pair["a"])
	var qb: String = str(pair["b"])
	_target_quality = qb
	_target_root_pc = rng.randi_range(0, 11)
	_target_key_label = _spell_root(_target_root_pc, _target_root_pc in [1, 3, 8, 10])
	var base: int = 60 + _target_root_pc
	if base >= 72:
		base -= 12
	_compare_a_notes.clear()
	_compare_b_notes.clear()
	for iv in (QUALITY_INTERVALS.get(qa, [0, 4, 7]) as Array):
		_compare_a_notes.append(base + int(iv))
	for iv in (QUALITY_INTERVALS.get(qb, [0, 3, 7]) as Array):
		_compare_b_notes.append(base + int(iv))
	var distractors: Array = (pair.get("distractors", []) as Array).duplicate()
	distractors.erase(qb)
	distractors.shuffle()
	var choices: Array[String] = [qb]
	for i in mini(CHOICES_COUNT - 1, distractors.size()):
		choices.append(str(distractors[i]))
	choices.shuffle()
	_render_choice_buttons(choices)
	_prompt_label.text = "Listen: %s → ? — what did chord B change to?" % qa
	_play_button.text = "%s  Play A → B" % char(0x266A)
	_play_button.disabled = false
	_play_compare_sequence()


# Chord Function — "Build the V chord in C major."
func _question_chord_function() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var diff: Dictionary = DIFFICULTIES[_difficulty]
	var keys: Array = diff["keys"]
	var allow_minor: bool = bool(diff["allow_minor_key"])
	_target_key_root_pc = int(keys[rng.randi_range(0, keys.size() - 1)])
	_target_key_is_minor = allow_minor and rng.randf() < 0.35
	_target_key_label = _spell_root(_target_key_root_pc, _target_key_root_pc in [1, 3, 8, 10])
	# Pick a degree appropriate for difficulty:
	# Beginner = I, IV, V; Early = + vi, ii; later levels = anything.
	var degree_pool: Array = []
	match _difficulty:
		0: degree_pool = [0, 3, 4]
		1: degree_pool = [0, 3, 4, 5, 1]
		_:
			degree_pool = [0, 1, 2, 3, 4, 5, 6]
	_target_degree = int(degree_pool[rng.randi_range(0, degree_pool.size() - 1)])
	var scale: Array = MINOR_SCALE if _target_key_is_minor else MAJOR_SCALE
	var defs: Array = MINOR_DIATONIC if _target_key_is_minor else MAJOR_DIATONIC
	_target_root_pc = ((_target_key_root_pc + int(scale[_target_degree])) % 12 + 12) % 12
	_target_quality = str(defs[_target_degree]["quality"])
	_target_roman = str(defs[_target_degree]["roman"])
	_set_target_notes(_target_root_pc, _target_quality)
	var key_mode_word: String = "%s minor" % _target_key_label if _target_key_is_minor else "%s major" % _target_key_label
	_prompt_label.text = "Build the %s chord in %s." % [_target_roman, key_mode_word]
	_update_build_selected_label()


# Progression Builder — multi-step build, each step is a chord in a sequence.
func _question_progression() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var diff: Dictionary = DIFFICULTIES[_difficulty]
	var keys: Array = diff["keys"]
	_target_key_root_pc = int(keys[rng.randi_range(0, keys.size() - 1)])
	_target_key_is_minor = false  # progressions kept major-only for now
	_target_key_label = _spell_root(_target_key_root_pc, _target_key_root_pc in [1, 3, 8, 10])
	var progressions: Array = PROGRESSIONS_BY_DIFFICULTY.get(_difficulty, PROGRESSIONS_BY_DIFFICULTY[0])
	var prog: Dictionary = progressions[rng.randi_range(0, progressions.size() - 1)]
	var degrees: Array = prog["degrees"]
	var prog_label: String = str(prog["label"])
	_progression_steps.clear()
	_progression_step_idx = 0
	var scale: Array = MAJOR_SCALE
	var defs: Array = MAJOR_DIATONIC
	for d in degrees:
		var deg: int = int(d)
		var root_pc: int = ((_target_key_root_pc + int(scale[deg])) % 12 + 12) % 12
		var quality: String = str(defs[deg]["quality"])
		var roman: String = str(defs[deg]["roman"])
		var base: int = 60 + root_pc
		if base >= 72:
			base -= 12
		var intervals: Array = QUALITY_INTERVALS.get(quality, [0, 4, 7])
		var notes: Array[int] = []
		for iv in intervals:
			notes.append(base + int(iv))
		_progression_steps.append({
			"degree": deg, "roman": roman, "quality": quality,
			"root_pc": root_pc, "notes": notes,
		})
	# Seed the first step as the current target.
	_apply_progression_step_to_target(0)
	_prompt_label.text = "Build %s in %s major — one chord at a time." % [prog_label, _target_key_label]
	_refresh_progression_subprompt()
	_update_build_selected_label()


func _apply_progression_step_to_target(idx: int) -> void:
	if idx < 0 or idx >= _progression_steps.size():
		return
	var step: Dictionary = _progression_steps[idx]
	_target_root_pc = int(step["root_pc"])
	_target_quality = str(step["quality"])
	_target_roman = str(step["roman"])
	_target_notes = (step["notes"] as Array).duplicate()


func _refresh_progression_subprompt() -> void:
	if _subprompt_label == null:
		return
	var parts: Array[String] = []
	for i in _progression_steps.size():
		var step: Dictionary = _progression_steps[i]
		var chord_label: String = "%s%s" % [
			_spell_root(int(step["root_pc"]), _target_key_label.contains("b")),
			_quality_suffix(str(step["quality"])),
		]
		var roman_label: String = str(step["roman"])
		var marker: String = ""
		if i < _progression_step_idx:
			marker = "%s" % char(0x2713)  # checkmark
		elif i == _progression_step_idx:
			marker = ">"
		else:
			marker = " "
		parts.append("%s %s/%s" % [marker, chord_label, roman_label])
	_subprompt_label.text = "  ".join(parts)


# --- Note input ---


func _set_target_notes(root_pc: int, quality: String) -> void:
	var intervals: Array = QUALITY_INTERVALS.get(quality, [0, 4, 7])
	var base: int = 60 + root_pc
	if base >= 72:
		base -= 12
	_target_notes.clear()
	for iv in intervals:
		_target_notes.append(base + int(iv))


func _toggle_build_note(pitch: int) -> void:
	if _answered:
		return
	var uses_keyboard: bool = (_mode == Mode.BUILD or _mode == Mode.FUNCTION or _mode == Mode.PROGRESSION)
	if not uses_keyboard:
		return
	_show_wrong_feedback = false
	if _selected_notes.has(pitch):
		_selected_notes.erase(pitch)
	else:
		_selected_notes[pitch] = true
		if _play_note_callable.is_valid():
			_play_note_callable.call(pitch, 0.5)
	_refresh_build_keyboard_highlight()
	_update_build_selected_label()


func _refresh_build_keyboard_highlight() -> void:
	# Pre-compute pitch-class sets so per-key state resolution is O(1).
	# Wrong-answer feedback: target PCs glow green; student's wrong PCs
	# glow red; correct selections (in both sets) win green so the
	# correct answer is what the eye lands on.
	var target_pcs: Dictionary = {}
	if _show_wrong_feedback:
		for n in _target_notes:
			target_pcs[((int(n) % 12) + 12) % 12] = true
	var selected_pcs: Dictionary = {}
	if _show_wrong_feedback:
		for p in _selected_notes.keys():
			selected_pcs[((int(p) % 12) + 12) % 12] = true
	for pitch_key in _build_keyboard_keys.keys():
		var pitch := int(pitch_key)
		var btn: Button = _build_keyboard_keys[pitch_key] as Button
		if btn == null:
			continue
		var state: int = KeyState.NORMAL
		if _show_wrong_feedback:
			var pc := ((pitch % 12) + 12) % 12
			if target_pcs.has(pc):
				state = KeyState.TARGET
			elif selected_pcs.has(pc):
				state = KeyState.WRONG
		elif _selected_notes.has(pitch):
			state = KeyState.SELECTED
		if _is_black(pitch):
			_apply_black_key_style(btn, state)
		else:
			_apply_white_key_style(btn, state)


func _update_build_selected_label() -> void:
	if _build_selected_label == null:
		return
	if _selected_notes.is_empty():
		_build_selected_label.text = "Currently selected: (none)"
		return
	var sorted_pitches: Array[int] = []
	for pitch in _selected_notes.keys():
		sorted_pitches.append(int(pitch))
	sorted_pitches.sort()
	var parts: Array[String] = []
	for p in sorted_pitches:
		parts.append(_midi_to_name(p))
	_build_selected_label.text = "Currently selected: %s" % "  ".join(parts)


# Build mode submission — handles BUILD / FUNCTION / PROGRESSION modes
# with detailed "missing / extra" feedback per the doc.
func _on_build_submit() -> void:
	var uses_keyboard: bool = (_mode == Mode.BUILD or _mode == Mode.FUNCTION or _mode == Mode.PROGRESSION)
	if not uses_keyboard or _answered:
		return
	if _selected_notes.size() < 2:
		_feedback_label.text = "Pick at least 2 notes before checking."
		_feedback_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.42, 1.0))
		return
	_current_attempts += 1
	# Compute PC sets.
	var selected_pcs: Dictionary = {}
	for pitch in _selected_notes.keys():
		selected_pcs[((int(pitch) % 12) + 12) % 12] = true
	var target_pcs: Dictionary = {}
	for note in _target_notes:
		target_pcs[((int(note) % 12) + 12) % 12] = true
	var missing: Array[String] = []
	var extra: Array[String] = []
	for pc in target_pcs.keys():
		if not selected_pcs.has(pc):
			missing.append(_pc_to_name(int(pc)))
	for pc in selected_pcs.keys():
		if not target_pcs.has(pc):
			extra.append(_pc_to_name(int(pc)))
	var correct: bool = missing.is_empty() and extra.is_empty()
	# PROGRESSION mode advances per-chord — not a single submit.
	if _mode == Mode.PROGRESSION and correct:
		_progression_step_idx += 1
		_refresh_progression_subprompt()
		# Play the just-completed chord for reinforcement.
		if _play_chord_callable.is_valid():
			_play_chord_callable.call(_target_notes, 1.0)
		if _progression_step_idx >= _progression_steps.size():
			# Progression complete — count as one correct question.
			_answered = true
			_score += 1
			_record_question_result(true, "progression_complete", missing, extra)
			var prog_done: String = "%s  Progression complete!" % char(0x2713)
			_feedback_label.text = prog_done
			_feedback_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.62, 1.0))
			_update_score_label()
			_next_button.disabled = false
			if _question_index >= QUESTIONS_PER_ROUND:
				_next_button.text = "See result %s" % char(0x2192)
		else:
			# Advance to next chord in the progression, keep round open.
			_apply_progression_step_to_target(_progression_step_idx)
			_selected_notes.clear()
			_refresh_build_keyboard_highlight()
			_update_build_selected_label()
			var step: Dictionary = _progression_steps[_progression_step_idx]
			_feedback_label.text = "%s  Next: %s chord (%s)." % [
				char(0x2192),
				str(step["roman"]),
				"%s%s" % [_spell_root(int(step["root_pc"]), _target_key_label.contains("b")), _quality_suffix(str(step["quality"]))],
			]
			_feedback_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 0.92))
		return
	if _mode == Mode.PROGRESSION and not correct:
		_current_wrong_attempts += 1
		_show_wrong_feedback = true
		_refresh_build_keyboard_highlight()
		_feedback_label.text = "%s  %s Try this step again." % [char(0x2717), _build_missing_extra_message(selected_pcs, missing, extra)]
		_feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45, 1.0))
		return
	# BUILD / FUNCTION (or PROGRESSION incorrect) — render feedback.
	if correct:
		_answered = true
		_score += 1
		_record_question_result(true, _format_selected_notes(), missing, extra)
		_feedback_label.text = "%s  Yes. %s = %s." % [
			char(0x2713),
			_target_chord_label(),
			_format_target_notes(),
		]
		_feedback_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.62, 1.0))
		if _play_chord_callable.is_valid():
			_play_chord_callable.call(_target_notes, 1.4)
	else:
		_current_wrong_attempts += 1
		_feedback_label.text = "%s  %s Try again." % [char(0x2717), _build_missing_extra_message(selected_pcs, missing, extra)]
		_feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45, 1.0))
		# Paint the keyboard: target notes green, the user's wrong picks
		# red. Visual feedback complements the text message so the student
		# can see what they should have played at a glance.
		_show_wrong_feedback = true
		_refresh_build_keyboard_highlight()
		if _play_chord_callable.is_valid():
			_play_chord_callable.call(_target_notes, 1.4)
		return
	_update_score_label()
	_next_button.disabled = false
	if _question_index >= QUESTIONS_PER_ROUND:
		_next_button.text = "See result %s" % char(0x2192)


func _on_build_clear() -> void:
	if _answered:
		return
	_selected_notes.clear()
	_show_wrong_feedback = false
	_refresh_build_keyboard_highlight()
	_update_build_selected_label()


# Escalating hint: each click reveals one more clue.
func _on_build_hint() -> void:
	if _answered:
		return
	_hint_stage = mini(_hint_stage + 1, 4)
	_current_hints_used = maxi(_current_hints_used, _hint_stage)
	var hint_text: String = ""
	match _hint_stage:
		1:
			hint_text = "This chord has %d notes." % _target_notes.size()
		2:
			hint_text = "Starts on %s." % _target_key_label
		3:
			hint_text = "Use %s." % _interval_summary(_target_quality)
		4:
			hint_text = "The notes are %s." % _format_target_notes()
		_:
			hint_text = "The notes are %s." % _format_target_notes()
	_feedback_label.text = "%s  Hint %d/4: %s" % [char(0x1F4A1), _hint_stage, hint_text]
	_feedback_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.92))


func _build_missing_extra_message(selected_pcs: Dictionary, missing: Array[String], extra: Array[String]) -> String:
	var msg_parts: Array[String] = []
	if not missing.is_empty():
		var got_pcs: Array[String] = []
		for pc in selected_pcs.keys():
			got_pcs.append(_pc_to_name(int(pc)))
		if got_pcs.is_empty():
			msg_parts.append("Add %s." % ", ".join(missing))
		else:
			msg_parts.append("You have %s. Add %s." % [", ".join(got_pcs), ", ".join(missing)])
	if not extra.is_empty():
		msg_parts.append("%s %s in %s%s." % [
			", ".join(extra),
			"does not belong" if extra.size() == 1 else "do not belong",
			_target_chord_label(),
			"",
		])
	if msg_parts.is_empty():
		return "That is not the target chord."
	return "  ".join(msg_parts)


func _format_selected_notes() -> String:
	if _selected_notes.is_empty():
		return ""
	var sorted_pitches: Array[int] = []
	for pitch in _selected_notes.keys():
		sorted_pitches.append(int(pitch))
	sorted_pitches.sort()
	var parts: Array[String] = []
	for p in sorted_pitches:
		parts.append(_midi_to_name(p))
	return ", ".join(parts)


func _target_chord_label() -> String:
	return "%s%s" % [_spell_root(_target_root_pc, _target_key_label.contains("b")), _quality_suffix(_target_quality)]


func _record_question_result(correct: bool, chosen: String, missing: Array[String], extra: Array[String]) -> void:
	var mode_name := _mode_name(_mode)
	var difficulty_label := str(DIFFICULTIES[_difficulty].get("label", ""))
	var response_ms := maxi(0, Time.get_ticks_msec() - _question_started_msec)
	var event: Dictionary = {
		"question": _question_index,
		"mode": mode_name,
		"difficulty": difficulty_label,
		"correct": correct,
		"assisted": _current_hints_used > 0 or _current_wrong_attempts > 0,
		"attempts": _current_attempts,
		"wrong_attempts": _current_wrong_attempts,
		"hints_used": _current_hints_used,
		"response_ms": response_ms,
		"key": _target_key_label,
		"key_is_minor": _target_key_is_minor,
		"root_pc": _target_root_pc,
		"root": _spell_root(_target_root_pc, _target_key_label.contains("b")),
		"quality": _target_quality,
		"roman": _target_roman,
		"target_notes": _format_target_notes(),
		"chosen": chosen,
		"missing": missing.duplicate(),
		"extra": extra.duplicate(),
	}
	if _mode == Mode.PROGRESSION:
		var steps: Array[Dictionary] = []
		for step_v in _progression_steps:
			if typeof(step_v) == TYPE_DICTIONARY:
				var step: Dictionary = step_v
				steps.append({
					"roman": str(step.get("roman", "")),
					"root_pc": int(step.get("root_pc", 0)),
					"quality": str(step.get("quality", "")),
				})
		event["progression_steps"] = steps
	_round_events.append(event)


func _round_report() -> Dictionary:
	var mode_counts: Dictionary = {}
	var weak_qualities: Dictionary = {}
	var weak_functions: Dictionary = {}
	var weak_keys: Dictionary = {}
	var hints_total := 0
	var assisted_correct := 0
	var unassisted_correct := 0
	for event in _round_events:
		var mode_name := str(event.get("mode", ""))
		mode_counts[mode_name] = int(mode_counts.get(mode_name, 0)) + 1
		hints_total += int(event.get("hints_used", 0))
		if bool(event.get("correct", false)):
			if bool(event.get("assisted", false)):
				assisted_correct += 1
			else:
				unassisted_correct += 1
			continue
		var quality := str(event.get("quality", ""))
		if not quality.is_empty():
			weak_qualities[quality] = int(weak_qualities.get(quality, 0)) + 1
		var roman := str(event.get("roman", ""))
		if not roman.is_empty():
			weak_functions[roman] = int(weak_functions.get(roman, 0)) + 1
		var key_label := str(event.get("key", ""))
		if not key_label.is_empty():
			weak_keys[key_label] = int(weak_keys.get(key_label, 0)) + 1
	return {
		"mode": _mode_name(_mode),
		"difficulty": str(DIFFICULTIES[_difficulty].get("label", "")),
		"events": _round_events.duplicate(true),
		"mode_counts": mode_counts,
		"weak_qualities": weak_qualities,
		"weak_functions": weak_functions,
		"weak_keys": weak_keys,
		"hints_total": hints_total,
		"assisted_correct": assisted_correct,
		"unassisted_correct": unassisted_correct,
	}


func _mode_name(mode: int) -> String:
	match mode:
		Mode.BUILD:
			return "Build a Chord"
		Mode.IDENTIFY:
			return "Identify Quality"
		Mode.COMPARE:
			return "Compare Sounds"
		Mode.FUNCTION:
			return "Chord Function"
		Mode.PROGRESSION:
			return "Progression"
		_:
			return "Unknown"


func _interval_summary(quality: String) -> String:
	# Human-readable interval description for hint level 3.
	match quality:
		"Major":    return "root + major 3rd + perfect 5th"
		"Minor":    return "root + minor 3rd + perfect 5th"
		"Dim":      return "root + minor 3rd + diminished 5th"
		"Aug":      return "root + major 3rd + augmented 5th"
		"Sus2":     return "root + major 2nd + perfect 5th"
		"Sus4":     return "root + perfect 4th + perfect 5th"
		"Maj7":     return "root + major 3rd + perfect 5th + major 7th"
		"Dom7":     return "root + major 3rd + perfect 5th + minor 7th"
		"Min7":     return "root + minor 3rd + perfect 5th + minor 7th"
		"Dim7":     return "root + minor 3rd + diminished 5th + diminished 7th"
		"Half-dim": return "root + minor 3rd + diminished 5th + minor 7th"
		"mMaj7":    return "root + minor 3rd + perfect 5th + major 7th"
		"Maj6":     return "root + major 3rd + perfect 5th + major 6th"
		"Min6":     return "root + minor 3rd + perfect 5th + major 6th"
		"Add9":     return "root + major 3rd + perfect 5th + 9th"
		_:
			return "the chord tones"


# --- Identify / Compare playback ---


func _play_identify_target() -> void:
	if _is_playback_busy():
		return
	_lock_playback(1.5)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(_target_notes, 1.4)


func _play_compare_sequence() -> void:
	if _compare_a_notes.is_empty() or _compare_b_notes.is_empty():
		return
	if _is_playback_busy():
		return
	_play_token += 1
	var my_token: int = _play_token
	_lock_playback(3.1)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(_compare_a_notes, 1.3)
	if not await _wait_play_sequence_seconds(1.55, my_token):
		return
	if my_token != _play_token or not is_inside_tree() or not visible:
		return
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(_compare_b_notes, 1.3)


func _wait_play_sequence_seconds(seconds: float, play_token: int) -> bool:
	var deadline := (float(Time.get_ticks_msec()) / 1000.0) + maxf(0.0, seconds)
	while (float(Time.get_ticks_msec()) / 1000.0) < deadline:
		if not is_inside_tree() or not visible:
			return false
		if play_token != _play_token:
			return false
		await get_tree().process_frame
	return true


# --- Multiple-choice handling ---


func _on_play_pressed() -> void:
	match _mode:
		Mode.IDENTIFY:
			_play_identify_target()
		Mode.COMPARE:
			_play_compare_sequence()
		_:
			pass


func _render_choice_buttons(choices: Array) -> void:
	_clear_choice_buttons()
	for choice in choices:
		var btn := Button.new()
		btn.text = str(choice)
		btn.custom_minimum_size = Vector2(126, 42)
		btn.add_theme_font_size_override("font_size", 14)
		var captured := str(choice)
		btn.pressed.connect(func(): _submit_choice(captured))
		_choices_row.add_child(btn)


func _clear_choice_buttons() -> void:
	if _choices_row == null:
		return
	for child in _choices_row.get_children():
		child.queue_free()


func _submit_choice(chosen: String) -> void:
	if _answered:
		return
	_current_attempts += 1
	_answered = true
	var correct: bool = chosen == _target_quality
	if correct:
		_score += 1
		_feedback_label.text = "%s  Correct! That was %s." % [char(0x2713), _target_quality]
		_feedback_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.62, 1.0))
	else:
		_feedback_label.text = "%s  Not quite — that was %s." % [char(0x2717), _target_quality]
		_feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45, 1.0))
		_current_wrong_attempts += 1
	_record_question_result(correct, chosen, [], [])
	for child in _choices_row.get_children():
		if child is Button:
			(child as Button).disabled = true
	_update_score_label()
	_next_button.disabled = false
	if _question_index >= QUESTIONS_PER_ROUND:
		_next_button.text = "See result %s" % char(0x2192)


# --- Advance / summary ---


func _on_advance_pressed() -> void:
	if _summary_shown:
		_next_button.text = "Next %s" % char(0x2192)
		_start_round()
		return
	if _question_index >= QUESTIONS_PER_ROUND and _answered:
		_show_round_summary()
		return
	_next_question()


func _show_round_summary() -> void:
	var pct: int = int(round(float(_score) / float(QUESTIONS_PER_ROUND) * 100.0))
	var stars: String = ""
	if pct >= 90: stars = "%s%s%s" % [char(0x1F3C6), char(0x1F3C6), char(0x1F3C6)]
	elif pct >= 70: stars = "%s%s" % [char(0x2B50), char(0x2B50)]
	elif pct >= 50: stars = "%s" % char(0x2B50)
	else: stars = "%s  Keep practicing!" % char(0x1F4AA)
	_prompt_label.text = "Round complete!  %d / %d  (%d%%)\n%s" % [_score, QUESTIONS_PER_ROUND, pct, stars]
	_subprompt_label.visible = false
	_feedback_label.text = ""
	_score_label.text = ""
	_clear_choice_buttons()
	if _play_button != null:
		_play_button.visible = false
	if _build_root != null:
		_build_root.visible = false
	_next_button.text = "Play again"
	_next_button.disabled = false
	_summary_shown = true
	if _session_attribution_pending:
		_session_attribution_pending = false
		chord_quiz_completed.emit(_score, QUESTIONS_PER_ROUND, _round_report())


# --- Playback busy lock ---


func _is_playback_busy() -> bool:
	return (float(Time.get_ticks_msec()) / 1000.0) < _playback_busy_until


func _lock_playback(duration: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_playback_busy_until = max(_playback_busy_until, now + duration)
	_playback_lock_token += 1
	var my_token: int = _playback_lock_token
	_set_playback_buttons_disabled(true)
	if is_inside_tree():
		_ensure_playback_unlock_timer()
		_playback_unlock_timer_token = my_token
		_playback_unlock_timer.start(maxf(0.01, duration))


func _ensure_playback_unlock_timer() -> void:
	if _playback_unlock_timer != null and is_instance_valid(_playback_unlock_timer):
		return
	_playback_unlock_timer = Timer.new()
	_playback_unlock_timer.one_shot = true
	_playback_unlock_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_playback_unlock_timer.timeout.connect(_on_playback_unlock_timer_timeout)
	add_child(_playback_unlock_timer)


func _stop_playback_unlock_timer() -> void:
	if _playback_unlock_timer != null and is_instance_valid(_playback_unlock_timer):
		_playback_unlock_timer.stop()


func _on_playback_unlock_timer_timeout() -> void:
	_auto_unlock_playback(_playback_unlock_timer_token)


func _auto_unlock_playback(token: int) -> void:
	if token != _playback_lock_token:
		return
	_playback_busy_until = 0.0
	_set_playback_buttons_disabled(false)


func _set_playback_buttons_disabled(disabled: bool) -> void:
	for b in _playback_buttons:
		if is_instance_valid(b):
			b.disabled = disabled


# --- Helpers ---


func _quality_suffix(quality: String) -> String:
	match quality:
		"Major": return ""
		"Minor": return "m"
		_:
			return quality


func _spell_root(pc: int, use_flats: bool) -> String:
	var pc_clamped: int = ((int(pc) % 12) + 12) % 12
	return str(NOTE_NAMES_FLAT[pc_clamped] if use_flats else NOTE_NAMES_SHARP[pc_clamped])


func _pc_to_name(pc: int) -> String:
	return _spell_root(pc, _target_key_label.contains("b"))


func _format_target_notes() -> String:
	var parts: Array[String] = []
	for note in _target_notes:
		parts.append(_midi_to_name(note))
	return ", ".join(parts)


func _midi_to_name(pitch: int) -> String:
	var pc := ((int(pitch) % 12) + 12) % 12
	var octave: int = int(pitch / 12) - 1
	return "%s%d" % [_spell_root(pc, _target_key_label.contains("b")), octave]


# Round-icon nav-button styling that mirrors the sight-reader /
# ear-training header buttons (46x46 round, navy bg, gold border).
# Kept inline so the panel doesn't need a parent-injected styler.
func _apply_nav_icon_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.17, 0.29, 0.86)
	normal.border_color = Color(0.92, 0.78, 0.32, 0.92)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 23
	normal.corner_radius_top_right = 23
	normal.corner_radius_bottom_left = 23
	normal.corner_radius_bottom_right = 23
	normal.shadow_color = Color(0, 0, 0, 0.32)
	normal.shadow_size = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.22, 0.34, 0.96)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.07, 0.13, 0.22, 0.96)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.96, 0.96, 0.99, 1.0))


func _on_back_pressed() -> void:
	dismiss()
	closed.emit()
