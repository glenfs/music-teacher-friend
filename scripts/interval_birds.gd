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
	4: ["P4", "TT"],
	5: ["P5"],
	6: ["M6", "m6"],
	7: ["M7", "m7"],
	8: ["P8"]
}
const DEFAULT_INTERVAL_DEGREES := [1, 2, 3, 4, 5, 8]
const CHICKEN_COMBO_TARGET := 5
const HomeMenuTokensScript = preload("res://scripts/ui/home_menu_tokens.gd")
const HomeMenuStateScript = preload("res://scripts/ui/home_menu_state.gd")
const HomeMenuUIScript = preload("res://scripts/ui/home_menu_ui.gd")

const NOTE_DURATION := 0.7
const GAP_DURATION := 0.25
const MODE_INTERVAL := 0
const MODE_CHORD := 1
const MODE_SIGHT := 2
const MODE_READ := 3
const MODE_NOTE_CHASE := 4
const STAFF_LEFT_X := 56.0
const STAFF_LINE_WIDTH := 620.0
const STAFF_TOP_LINE_Y := 104.0
const STAFF_LINE_GAP_Y := 54.0
const STAFF_STEP_Y := 27.0
const STAFF_NOTE_SNAP_X := 223.0
const SIGHT_NOTE_CENTER_OFFSET_Y := 7.0
const NOTEHEAD_SHIMMER_ENABLED := false
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
const CHICKEN_HINT_PROMPT_LINES := [
	"If you need help, tap me.",
	"Click me for a hint.",
	"Need a clue? Tap me.",
	"Stuck? I can nudge you.",
	"I can give a theory clue.",
	"Want a song-based hint?",
	"Tap me for a smarter hint.",
	"Need a clearer clue? Tap again.",
	"Chicken coach ready. Click me.",
	"Need a reading shortcut? Tap me.",
	"I can break this down step-by-step.",
	"Want ear-training help? Click me.",
	"Tap me if this one feels tricky."
]
const INTERVAL_HINT_PROFILES := {
	"P1": {"color": "same-note lock", "pull": "no tension, pure stability", "shape": "zero distance", "song": "Think of matching a drone exactly.", "theory": "Both notes share the same pitch class; resonance feels fused.", "compare": "No gap at all, just alignment."},
	"m2": {"color": "tight tension", "pull": "strong urge to resolve quickly", "shape": "smallest squeeze above root", "song": "Jaws-style bite interval", "theory": "Highly dissonant cluster often used for suspense.", "compare": "Closer than any other distinct step."},
	"M2": {"color": "gentle motion", "pull": "mild forward movement", "shape": "small step but more open than a crunch", "song": "Happy Birthday opening motion", "theory": "Common scalar neighbor; stable in melody flow.", "compare": "A small step that still breathes."},
	"m3": {"color": "dark-warm", "pull": "settled but wistful", "shape": "compact leap", "song": "Greensleeves mood color", "theory": "Defines minor flavor in triads.", "compare": "Wider than steps, still near root."},
	"M3": {"color": "bright-hopeful", "pull": "stable and singing", "shape": "clean expressive leap", "song": "When the Saints opening leap color", "theory": "Defines major flavor in triads.", "compare": "Close cousin to minor flavor but brighter."},
	"P4": {"color": "firm suspended", "pull": "can feel unresolved over bass", "shape": "broad jump without harshness", "song": "Here Comes the Bride opening", "theory": "Consonant in melody, suspension-like in harmony.", "compare": "Broader than a third, not yet octave-close."},
	"TT": {"color": "edgy unstable", "pull": "strong directional tension", "shape": "symmetrical split of octave", "song": "Maria (West Side Story) tritone color", "theory": "Divides octave equally; classic dominant tension core.", "compare": "Sits exactly in the middle of octave space."},
	"P5": {"color": "open powerful", "pull": "stable and ringing", "shape": "wide clean jump", "song": "Twinkle star-span resonance", "theory": "Strong overtone alignment; foundation of power chords.", "compare": "Feels like home support, not crowded."},
	"m6": {"color": "dramatic shadow", "pull": "emotional pull inward", "shape": "large leap with dark tint", "song": "Love Story opening flavor", "theory": "Inversion partner of a bright third.", "compare": "Past midpoint, not yet octave-close."},
	"M6": {"color": "warm expansive", "pull": "lyrical and open", "shape": "large leap with hopeful tone", "song": "My Bonnie Lies Over the Ocean opening", "theory": "Inversion partner of a minor third.", "compare": "Wide interval that still feels singable."},
	"m7": {"color": "near-octave suspense", "pull": "leans strongly to resolve upward", "shape": "very wide with dark edge", "song": "Somewhere (descending color) style", "theory": "Inversion partner of a major second.", "compare": "Almost octave, but still unsettled."},
	"M7": {"color": "sharp near-octave tension", "pull": "intense urge to close to tonic", "shape": "very wide and bright-tense", "song": "Take On Me color in melodic leaps", "theory": "Leading-tone relationship to octave target.", "compare": "One tiny step below octave closure."},
	"P8": {"color": "full resonance", "pull": "complete closure", "shape": "same note class, higher register", "song": "Somewhere Over the Rainbow opening leap", "theory": "Frequency doubles; strongest pitch identity match.", "compare": "Maximum simple span with exact pitch-class match."}
}
const CHORD_HINT_PROFILES := {
	"major": {"mood": "bright and resolved", "stack": "lower gap wider than upper", "function": "often tonic or strong cadence target", "lesson": "Major triad uses a bright third over the root.", "song": "common pop anthem landing color"},
	"minor": {"mood": "darker, reflective", "stack": "lower gap tighter than upper", "function": "often emotive tonic in minor key", "lesson": "Minor triad lowers the third against root.", "song": "ballad verse color"},
	"sus2": {"mood": "open, floating", "stack": "no defining third, airy top", "function": "suspends identity until resolved", "lesson": "Suspended chords remove major/minor identity.", "song": "modern ambient pop intro color"},
	"sus4": {"mood": "leaning unresolved", "stack": "upper tones press to resolve down", "function": "classical suspension pull", "lesson": "The suspended fourth typically resolves to a third.", "song": "anthem pre-chorus tension"},
	"aug": {"mood": "shimmering unstable", "stack": "symmetrical lift at top", "function": "chromatic color and lift", "lesson": "Augmented triad raises the fifth from major shape.", "song": "cinematic transition chord"},
	"dim": {"mood": "tight and tense", "stack": "stacked narrow gaps", "function": "leading-tone tension", "lesson": "Diminished color compresses both upper intervals.", "song": "thriller suspense hit"},
	"dim7": {"mood": "maximum tension wheel", "stack": "equal stacked minor thirds", "function": "modulation pivot and dominant substitute", "lesson": "Fully diminished seventh is symmetric every three semitones.", "song": "classic noir drama cue"},
	"dom7": {"mood": "bluesy push-forward", "stack": "major body plus restless top", "function": "wants to resolve to tonic", "lesson": "Dominant seventh creates tritone drive to resolution.", "song": "blues turnaround signature"},
	"maj7": {"mood": "lush and dreamy", "stack": "stable triad plus close bright top", "function": "color tonic in jazz/pop", "lesson": "Major seventh adds a close leading color above triad.", "song": "jazz ballad pad tone"},
	"min7": {"mood": "soft soulful", "stack": "minor body plus relaxed top", "function": "ii or vi color in progressions", "lesson": "Minor seventh softens minor triad into a smooth sonority.", "song": "neo-soul groove bed"},
	"power": {"mood": "neutral and strong", "stack": "root + open fifth only", "function": "drives rhythm without major/minor bias", "lesson": "Without a third, chord quality stays ambiguous.", "song": "rock riff backbone"}
}
const SIGHT_NOTE_PROFILES := {
	"C": {"anchor": "middle C region", "treble": "just below treble staff", "bass": "just above bass staff", "role": "home pitch for C-major map"},
	"D": {"anchor": "step above C anchor", "treble": "near lower treble zone", "bass": "near upper bass zone", "role": "diatonic passing tone"},
	"E": {"anchor": "line-heavy reference", "treble": "lowest treble line landmark", "bass": "space near top of bass staff", "role": "stable chord tone in C-major"},
	"F": {"anchor": "brace point around clefs", "treble": "first treble space landmark", "bass": "top bass line landmark", "role": "subdominant gravity tone"},
	"G": {"anchor": "clef-related gravity note", "treble": "second treble line landmark", "bass": "top bass space landmark", "role": "dominant pull tone"},
	"A": {"anchor": "singable reference above G", "treble": "second treble space landmark", "bass": "middle bass line landmark", "role": "common melodic high point"},
	"B": {"anchor": "leading color toward C", "treble": "middle treble line landmark", "bass": "middle bass space landmark", "role": "leading tone behavior in C-major"}
}
const FARM_BG_PATH := "res://assets/backgrounds/farm_scene.png"
const TREE_LAYERS := []
const BIRD_TEXTURE_PATH := "res://assets/birds/chicken.png"
const TUTORIAL_CHICKEN_PATH := "res://assets/birds/chicken.svg"
const BIRD_TINT := Color(1.0, 1.0, 1.0, 1.0)
const UI_FONT_PATH := "res://assets/fonts/Inter-Regular.ttf"
const UI_TITLE_FONT_PATH := "res://assets/fonts/Poppins-SemiBold.ttf"
const UI_CLICK_SFX_PATH := "res://assets/audio/sfx/ui-basic-click.wav"
const UI_SIGHT_ANSWER_CLICK_SFX_PATH := "res://assets/audio/sfx/ui-basic-click-2-glass.wav"
const CORRECT_SFX_PATH := "res://assets/audio/sfx/correct.mp3"
const WRONG_CHOICE_SFX_PATH := "res://assets/audio/sfx/wrong-choice.wav"
const FAIL_GAMEOVER_SFX_PATH := "res://assets/audio/sfx/fail.mp3"
const WIN_FANFARE_SFX_PATH := "res://assets/audio/sfx/fanfare-2-rpg.wav"
const MODULE_COMPLETE_SFX_PATH := "res://assets/audio/sfx/module-complete.wav"
const NEW_QUESTION_SFX_PATH := "res://assets/audio/sfx/new_question.wav"
const POWERUP_SFX_PATH := "res://assets/audio/sfx/powerup.wav"
const TRANSITION_WHOOSH_SFX_PATH := "res://assets/audio/sfx/transition-whoosh-sound.wav"
const SHIELD_ACTIVATE_SFX_PATH := "res://assets/audio/sfx/268185__andychristen__wristwatchtic-tac.wav"
const NOTE_CHASE_BGM_PATH := "res://assets/audio/sfx/module-complete.wav"
const NOTE_CHASE_NOTE_COLORS := [
	Color(1.0, 0.47, 0.73, 0.97), # pink
	Color(0.34, 0.58, 0.98, 0.97), # blue
	Color(0.35, 0.95, 0.95, 0.97), # cyan
	Color(0.66, 0.46, 0.96, 0.97), # purple
	Color(0.54, 0.35, 0.92, 0.97), # violet
	Color(0.13, 0.58, 0.25, 0.97), # dark green
	Color(0.96, 0.66, 0.36, 0.97), # warm orange
	Color(1.0, 0.41, 0.41, 0.97), # coral red
	Color(0.41, 0.93, 0.64, 0.97), # mint
	Color(0.98, 0.80, 0.25, 0.97), # amber
	Color(0.31, 0.84, 0.96, 0.97), # sky
	Color(0.92, 0.42, 0.84, 0.97), # magenta
	Color(0.74, 0.90, 0.34, 0.97), # lime
	Color(0.98, 0.52, 0.67, 0.97), # rose
	Color(0.44, 0.82, 0.76, 0.97), # teal mint
	Color(0.86, 0.60, 0.30, 0.97) # bronze
]
const NOTE_CHASE_STAFF_COLORS := [
	Color(1.0, 0.84, 0.40, 0.96),
	Color(0.45, 0.86, 1.0, 0.96),
	Color(1.0, 0.62, 0.78, 0.96),
	Color(0.58, 0.95, 0.66, 0.96),
	Color(0.83, 0.62, 1.0, 0.96),
	Color(1.0, 0.56, 0.38, 0.96),
	Color(0.48, 0.92, 0.78, 0.96),
	Color(0.94, 0.72, 0.34, 0.96),
	Color(0.35, 0.78, 0.98, 0.96),
	Color(0.94, 0.54, 0.88, 0.96),
	Color(0.72, 0.92, 0.35, 0.96),
	Color(0.94, 0.64, 0.46, 0.96)
]
const NOTE_CHASE_THEME_TINTS := [
	Color(0.90, 0.96, 1.0, 1.0),
	Color(1.0, 0.90, 0.96, 1.0),
	Color(0.90, 1.0, 1.0, 1.0),
	Color(0.94, 0.90, 1.0, 1.0),
	Color(0.92, 0.88, 1.0, 1.0),
	Color(0.88, 1.0, 0.90, 1.0),
	Color(1.0, 0.92, 0.84, 1.0),
	Color(0.86, 0.97, 0.93, 1.0),
	Color(0.98, 0.89, 0.83, 1.0),
	Color(0.90, 0.94, 1.0, 1.0),
	Color(0.89, 0.98, 0.92, 1.0),
	Color(0.98, 0.91, 0.90, 1.0),
	Color(0.91, 0.93, 0.99, 1.0)
]
const SIGHT_NOTE_COLORS := [
	Color(1.0, 0.47, 0.73, 0.98),
	Color(0.35, 0.58, 0.98, 0.98),
	Color(0.35, 0.94, 0.94, 0.98),
	Color(0.66, 0.46, 0.96, 0.98),
	Color(0.56, 0.94, 0.66, 0.98),
	Color(0.98, 0.68, 0.32, 0.98),
	Color(0.96, 0.42, 0.42, 0.98),
	Color(0.74, 0.90, 0.34, 0.98),
	Color(0.94, 0.54, 0.88, 0.98),
	Color(0.42, 0.84, 0.76, 0.98)
]
const PIANO_SAMPLED_DIR := "res://assets/audio/piano/sampled"
const TEACHER_DATA_PATH := "user://teacher_data.json"
const EAR_SETTINGS_PATH := "user://ear_settings.json"
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
var _ui_sfx_player: AudioStreamPlayer
var _shield_sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _piano_samples: Dictionary = {}
var _piano_interval_anchor_samples: Dictionary = {}
var _chord_players: Array[AudioStreamPlayer] = []
var _ui_click_sfx: AudioStream
var _ui_sight_answer_click_sfx: AudioStream
var _correct_sfx: AudioStream
var _wrong_choice_sfx: AudioStream
var _fail_gameover_sfx: AudioStream
var _win_fanfare_sfx: AudioStream
var _module_complete_sfx: AudioStream
var _new_question_sfx: AudioStream
var _powerup_sfx: AudioStream
var _transition_whoosh_sfx: AudioStream
var _shield_activate_sfx: AudioStream
var _note_chase_bgm: AudioStream
var _ui_font: Font
var _ui_title_font: Font
var _sight_note_color := Color(1.0, 0.47, 0.73, 0.98)
var _sight_ledger_color := Color(0.35, 0.58, 0.98, 0.98)
var _sight_staff_frame_border_color := Color(0.95, 0.84, 0.42, 0.88)

var _home_panel: VBoxContainer
var _game_panel: VBoxContainer
var _header_card: PanelContainer
var _home_card: PanelContainer
var _game_card: PanelContainer
var _home_info_label: Label
var _home_title_label: Label
var _header_tagline_label: Label
var _home_hub_row: HBoxContainer
var _home_hub_buttons: Dictionary = {}
var _home_section_cards: Dictionary = {}
var _home_option_group_cards: Array[PanelContainer] = []
var _home_flow := "Practice" # Practice | Learn | Teacher
var _home_mode_label: Label
var _home_mode_buttons_row: Control
var _home_q_row: HBoxContainer
var _home_settings_button: Button
var _home_start_button: Button
var _home_mode_back_button: Button
var _ear_settings_button: Button
var _ear_settings_screen: VBoxContainer
var _ear_settings_back_button: Button
var _ear_settings_more_panel: VBoxContainer
var _ear_choice_count_select: OptionButton
var _ear_theme_select: OptionButton
var _ear_settings_header_label: Label
var _sight_settings_header_label: Label
var _ear_choice_label: Label
var _ear_questions_label: Label
var _sight_questions_label: Label
var _question_spin: SpinBox
var _mode_buttons: Dictionary = {}
var _ear_mode_buttons: Dictionary = {}
var _ear_mode_row: HBoxContainer
var _interval_options_box: VBoxContainer
var _chord_options_box: VBoxContainer
var _sight_options_box: VBoxContainer
var _note_chase_options_box: VBoxContainer
var _read_options_box: VBoxContainer
var _clef_buttons: Dictionary = {}
var _selected_clef := "Treble"
var _sight_mode_buttons: Dictionary = {}
var _sight_note_chase_button: Button
var _sight_mode := "Notes" # Notes | Chords | Placement
var _sight_settings_button: Button
var _sight_settings_more_panel: VBoxContainer
var _sight_settings_back_button: Button
var _sight_question_spin: SpinBox
var _sight_key_signature := "C" # C | 2# | 3# | 2b | 3b
var _sight_key_sig_buttons: Dictionary = {}
var _sight_key_sig_row: HBoxContainer
var _sight_accidentals_toggle: CheckButton
var _read_module_buttons: Dictionary = {}
var _selected_read_module := 1
var _sight_range_container: VBoxContainer
var _sight_range_info_label: Label
var _sight_range_lower_value_label: Label
var _sight_range_upper_value_label: Label
var _sight_range_min_step := 6
var _sight_range_max_step := 12
var _inversion_toggle: Button
var _adaptive_toggle: CheckButton
var _chord_group_buttons: Dictionary = {}
var _selected_chord_group := 1
var _degree_toggles: Dictionary = {}
var _include_minor_toggle: Button
var _descending_intervals_toggle: Button
var _harmonic_intervals_toggle: Button
var _note_chase_note_toggles: Dictionary = {}
var _note_chase_clef_buttons: Dictionary = {}
var _note_chase_selected_notes: Array[String] = ["C", "E", "G"]
var _note_chase_clef_mode := "Treble" # Treble | Bass | Both
var _home_material_buttons: Array[Button] = []
var _home_tokens
var _home_state
var _home_menu_ui
var _home_hint_labels: Dictionary = {}
var _home_disabled_reason_label: Label
var _home_sight_mode_row: Control
var _sight_clef_row: Control
var _home_interval_degree_row: Control
var _home_chase_note_row: Control
var _home_chase_clef_row: Control
var _home_mode_detail_active := false
var _sight_settings_screen_active := false
var _continuous_sight_active := false
var _continuous_sight_duration := 30.0
var _continuous_sight_elapsed := 0.0
var _continuous_sight_spawn_timer := 0.0
var _continuous_sight_notes: Array[Dictionary] = []
var _continuous_sight_play_line: ColorRect
var _continuous_sight_bpm := 80
var _continuous_sight_speed := 70.0
var _continuous_sight_base_speed := 70.0
var _continuous_sight_hit_window := 24.0
var _continuous_sight_zone_width := 64.0
var _continuous_sight_total_hits := 0
var _continuous_sight_correct_hits := 0
var _continuous_sight_combo := 0
var _continuous_sight_best_combo := 0
var _continuous_sight_waiting_start := false
var _continuous_sight_perfect_hits := 0
var _continuous_sight_good_hits := 0
var _continuous_sight_miss_hits := 0
var _continuous_sight_reaction_sum := 0.0
var _continuous_sight_reaction_count := 0
var _continuous_sight_level := 1
var _continuous_sight_level_bounds := Vector2i(6, 10)
var _continuous_sight_allow_accidentals := false
var _continuous_testing_no_life_loss := true
var _continuous_spawn_queue: Array[Dictionary] = []
var _continuous_bar_accidentals: Dictionary = {}
var _continuous_bar_note_index := 0
var _continuous_total_spawned_notes := 0
var _continuous_accidental_probability := 0.18
var _continuous_natural_probability := 0.22
var _continuous_last_spawn_step := 9999
var _continuous_spawn_seq := 0
var _continuous_last_spawn_elapsed := 0.0
var _continuous_keyboard_row: HBoxContainer
var _continuous_key_buttons: Array[Button] = []
var _continuous_black_key_buttons: Array[Button] = []
var _continuous_sight_min_gap := 72.0
var _continuous_rest_bar_active := false
var _continuous_rest_bar_timer := 0.0
var _continuous_rest_symbol: ColorRect

var _status_label: Label
var _score_label: Label
var _progress_label: Label
var _meta_label: Label
var _lives_label: Label
var _streak_label: Label
var _xp_label: Label
var _note_chase_target_label: Label
var _note_chase_speed_label: Label
var _note_chase_combo_label: Label
var _note_chase_shield_label: Label
var _note_chase_level_label: Label
var _note_chase_target_box: PanelContainer
var _note_chase_speed_box: PanelContainer
var _note_chase_combo_box: PanelContainer
var _note_chase_shield_box: PanelContainer
var _note_chase_side_panel: PanelContainer
var _note_chase_side_target_box: PanelContainer
var _note_chase_side_speed_box: PanelContainer
var _note_chase_side_combo_box: PanelContainer
var _note_chase_side_shield_box: PanelContainer
var _note_chase_side_target_label: Label
var _note_chase_side_speed_label: Label
var _note_chase_side_combo_label: Label
var _note_chase_side_shield_label: Label
var _note_chase_bottom_row: HBoxContainer
var _note_chase_bottom_spacer: Control
var _note_chase_bottom_target_box: PanelContainer
var _note_chase_bottom_speed_box: PanelContainer
var _note_chase_bottom_combo_box: PanelContainer
var _note_chase_bottom_shield_box: PanelContainer
var _note_chase_bottom_target_label: RichTextLabel
var _note_chase_bottom_speed_label: RichTextLabel
var _note_chase_bottom_combo_label: RichTextLabel
var _note_chase_bottom_shield_label: RichTextLabel
var _hud_left_box: PanelContainer
var _hud_right_box: PanelContainer
var _hud_center_box: PanelContainer
var _title_label: Label
var _prompt_label: Label
var _sight_key_label: Label
var _sight_container: VBoxContainer
var _sight_top_spacer: Control
var _sight_keyboard_row: HBoxContainer
var _staff_area: Control
var _staff_note: Panel
var _staff_chord_notes: Array[Panel] = []
var _staff_chord_accidental_labels: Array[Label] = []
var _staff_clef_label: Label
var _staff_key_sig_labels: Array[Label] = []
var _note_chase_clef_clone: Label
var _note_chase_fail_line: ColorRect
var _note_chase_spawn_line: ColorRect
var _note_chase_overlay: ColorRect
var _note_chase_overlay_label: Label
var _note_chase_staff_frame: Panel
var _staff_lines: Array[ColorRect] = []
var _note_chase_staff_clone_lines: Array[ColorRect] = []
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
var _round_start_button: Button
var _slow_toggle: CheckBox
var _end_button: Button
var _restart_button: Button
var _control_row: HBoxContainer
var _interval_center_top_spacer: Control
var _interval_center_bottom_spacer: Control
var _interval_prompt_top_spacer: Control
var _interval_choices_top_spacer: Control
var _interval_choices_row: HBoxContainer
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
var _tutorial_bubble_dots: Array[Panel] = []
var _tutorial_chicken: TextureRect
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
var _current_chord_choices: Array[String] = []
var _current_sight_note := "C"
var _current_sight_chord_name := "C Major"
var _current_sight_chord_choices: Array[String] = []
var _current_sight_chord_def: Dictionary = {}
var _current_sight_target_step := 8
var _current_sight_display_step := 8
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
var _use_descending_intervals := false
var _use_harmonic_intervals := false
var _selected_mode := MODE_INTERVAL
var _lives := 3
var _streak := 0
var _chicken_combo_charge := 0
var _chicken_combo_shields := 0
var _xp := 0
var _is_prompt_playing := false
var _accepting_answer := false
var _awaiting_round_start := false
var _note_chase_running := false
var _note_chase_staff_scroll_x := 0.0
var _note_chase_spawn_timer := 0.0
var _note_chase_spawn_interval := 1.2
var _note_chase_scroll_speed := 95.0
var _note_chase_base_spawn_interval := 1.2
var _note_chase_base_scroll_speed := 95.0
var _note_chase_speed_stage := 0
var _note_chase_correct_streak := 0
var _note_chase_wrongs := 0
var _note_chase_correct_clicks := 0
var _note_chase_spawned := 0
var _note_chase_elapsed := 0.0
var _note_chase_active_notes: Array[Dictionary] = []
var _note_chase_target_spawn_streak := 0
var _note_chase_fever_active := false
var _note_chase_fever_timer := 0.0
var _note_chase_boss_active := false
var _note_chase_boss_timer := 0.0
var _note_chase_boss_last_stage := -1
var _note_chase_last_theme_stage := -1
var _note_chase_clef_switch_cd := 0.0
var _note_chase_freeze_timer := 0.0
var _note_chase_shield_timer := 0.0
var _note_chase_combo_mult := 1
var _note_chase_last_spawn_note := ""
var _bird_home_global_position := Vector2.ZERO
var _bird_home_ready := false
var _chicken_hint_busy := false
var _chicken_hint_cooldown_until := 0.0
var _chicken_hint_clicks_this_turn := 0
var _chicken_hint_turn_token := 0
var _chicken_last_prompt_line := ""
var _chicken_last_hint_by_topic: Dictionary = {}
var _chicken_used_hints_by_topic: Dictionary = {}
var _chicken_hint_locked_this_turn := false
var _chicken_prompt_ready_at := 0.0
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
var _ear_choice_count := 6
var _ui_theme_id := "golden_harvest"
var _ear_settings_screen_active := false


func _ready() -> void:
	_rng.randomize()
	_home_tokens = HomeMenuTokensScript.new()
	_home_state = HomeMenuStateScript.new()
	_home_menu_ui = HomeMenuUIScript.new()
	_home_menu_ui.setup(_home_tokens)
	_sync_home_state_from_runtime()
	_load_ear_settings()
	_build_ui()
	_setup_audio()
	_on_mode_selected()
	_show_home()
	call_deferred("_post_layout_init")
	call_deferred("_update_game_card_layout")


func _sync_home_state_from_runtime() -> void:
	if _home_state == null:
		return
	_home_state.home_flow = _home_flow
	_home_state.selected_mode = _selected_mode
	_home_state.ear_settings_screen_active = _ear_settings_screen_active
	_home_state.selected_read_module = _selected_read_module
	_home_state.selected_clef = _selected_clef
	_home_state.sight_mode = _sight_mode
	_home_state.sight_key_signature = _sight_key_signature
	_home_state.sight_range_min_step = _sight_range_min_step
	_home_state.sight_range_max_step = _sight_range_max_step
	_home_state.include_minor_intervals = _include_minor_intervals
	_home_state.use_descending_intervals = _use_descending_intervals
	_home_state.use_harmonic_intervals = _use_harmonic_intervals
	_home_state.note_chase_clef_mode = _note_chase_clef_mode
	_home_state.note_chase_selected_notes = _note_chase_selected_notes.duplicate()


func _sync_runtime_from_home_state() -> void:
	if _home_state == null:
		return
	_home_flow = _home_state.home_flow
	_selected_mode = _home_state.selected_mode
	_ear_settings_screen_active = _home_state.ear_settings_screen_active
	_selected_read_module = _home_state.selected_read_module
	_selected_clef = _home_state.selected_clef
	_sight_mode = _home_state.sight_mode
	_sight_key_signature = "C" if _home_state.sight_key_signature == "None" else _home_state.sight_key_signature
	_sight_range_min_step = _home_state.sight_range_min_step
	_sight_range_max_step = _home_state.sight_range_max_step
	_include_minor_intervals = _home_state.include_minor_intervals
	_use_descending_intervals = _home_state.use_descending_intervals
	_use_harmonic_intervals = _home_state.use_harmonic_intervals
	_note_chase_clef_mode = _home_state.note_chase_clef_mode
	_note_chase_selected_notes = _home_state.note_chase_selected_notes.duplicate()


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
	if _ui_sfx_player != null:
		_ui_sfx_player.stop()
	if _shield_sfx_player != null:
		_shield_sfx_player.stop()
	if _audio_player != null:
		_audio_player.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_game_card_layout")
		if _selected_mode == MODE_READ:
			call_deferred("_position_tutorial_title")
			call_deferred("_position_tutorial_button_row")
			call_deferred("_position_tutorial_end_buttons")


func _process(delta: float) -> void:
	_update_note_chase(delta)
	_update_continuous_sight(delta)
	_ensure_bird_visible_in_gameplay()
	_update_chicken_bubble_position()
	if (_selected_mode == MODE_NOTE_CHASE or _selected_mode == MODE_SIGHT) and _game_panel != null and _game_panel.visible:
		if _selected_mode == MODE_SIGHT:
			_set_note_chase_staff_scrolling(false)
		_note_chase_realign_staff_frame()


func _update_game_card_layout() -> void:
	if _game_card == null:
		return
	var vp := get_viewport_rect().size
	var is_large := vp.y >= 720.0 or vp.x >= 1100.0
	var target_w := maxi(980.0, vp.x - 36.0)
	var target_h := clampf(vp.y * (0.80 if is_large else 0.68), 440.0, vp.y - 72.0)
	_game_card.custom_minimum_size = Vector2(target_w, target_h)
	if _home_card != null:
		var home_h := clampf(target_h - 92.0, 360.0, vp.y - 140.0)
		_home_card.custom_minimum_size = Vector2(target_w, home_h)
	_apply_responsive_touch_scaling(vp)
	if _game_panel != null and _game_panel.visible and _selected_mode != MODE_READ:
		var should_snap_now := _awaiting_round_start or (_question_index <= 1 and not _accepting_answer and not _is_prompt_playing)
		_refresh_bird_perch_from_layout(should_snap_now)


func _apply_responsive_touch_scaling(vp: Vector2) -> void:
	var profile: Dictionary = _home_tokens.profile_for_viewport(vp) if _home_tokens != null else {"name": "large_phone", "large_text_scale": 1.0}
	var is_tablet: bool = str(profile.get("name", "large_phone")) == "tablet"
	var large_scale := float(profile.get("large_text_scale", 1.0))
	var viewport_scale := clampf(vp.y / 800.0, 1.0, 1.55)
	large_scale *= viewport_scale
	var btn_h := (72.0 if is_tablet else 44.0) * viewport_scale
	var btn_w_boost := (1.44 if is_tablet else 1.08) * clampf(vp.x / 1200.0, 1.0, 1.20)
	if _home_panel != null:
		_home_panel.add_theme_constant_override("separation", int(roundf((22 if is_tablet else 12) * viewport_scale)))
		for child in _home_panel.get_children():
			if child is Label:
				var lbl := child as Label
				if lbl != null:
					lbl.add_theme_font_size_override("font_size", int(roundf((24 if is_tablet else 18) * large_scale)))
	if _home_mode_buttons_row != null:
		_home_mode_buttons_row.add_theme_constant_override("separation", int(roundf((16 if is_tablet else 10) * viewport_scale)))
	if _home_hub_row != null:
		_home_hub_row.add_theme_constant_override("separation", int(roundf((18 if is_tablet else 12) * viewport_scale)))
	for b in _home_material_buttons:
		if b == null:
			continue
		if not b.has_meta("base_min_size"):
			b.set_meta("base_min_size", b.custom_minimum_size)
		var base_meta: Variant = b.get_meta("base_min_size")
		var base_size: Vector2 = base_meta if base_meta is Vector2 else b.custom_minimum_size
		var base_w := maxf(72.0, base_size.x)
		var new_w: float = roundf(base_w * btn_w_boost)
		var min_h := btn_h
		if b.has_meta("mini_btn"):
			min_h = btn_h * 0.66
			new_w *= 0.82
		elif b.has_meta("compact_btn"):
			min_h = btn_h * 0.78
		b.custom_minimum_size = Vector2(new_w, maxf(base_size.y, min_h))
		b.add_theme_font_size_override("font_size", int(roundf((24 if is_tablet else 17) * large_scale)))
	if _home_mode_back_button != null:
		_home_mode_back_button.custom_minimum_size = Vector2(108, 40) if is_tablet else Vector2(96, 36)
		_home_mode_back_button.add_theme_font_size_override("font_size", int(roundf((18 if is_tablet else 14) * large_scale)))
	var option_btn_font := int(roundf((26 if is_tablet else 20) * large_scale))
	for b in _ear_mode_buttons.values():
		var ear_btn := b as Button
		if ear_btn == null:
			continue
		ear_btn.add_theme_font_size_override("font_size", option_btn_font)
	for b in _sight_mode_buttons.values():
		var sight_btn := b as Button
		if sight_btn == null:
			continue
		sight_btn.add_theme_font_size_override("font_size", option_btn_font)
	if _sight_note_chase_button != null:
		_sight_note_chase_button.add_theme_font_size_override("font_size", option_btn_font)
	for b in _clef_buttons.values():
		var clef_btn := b as Button
		if clef_btn == null:
			continue
		clef_btn.add_theme_font_size_override("font_size", int(roundf((22 if is_tablet else 16) * large_scale)))
	for b in _sight_key_sig_buttons.values():
		var sig_btn := b as Button
		if sig_btn == null:
			continue
		sig_btn.add_theme_font_size_override("font_size", int(roundf((18 if is_tablet else 13) * large_scale)))
	for b in _note_chase_note_toggles.values():
		var note_btn := b as Button
		if note_btn == null:
			continue
		note_btn.add_theme_font_size_override("font_size", int(roundf((17 if is_tablet else 13) * large_scale)))
	for b in _note_chase_clef_buttons.values():
		var chase_clef_btn := b as Button
		if chase_clef_btn == null:
			continue
		chase_clef_btn.add_theme_font_size_override("font_size", int(roundf((21 if is_tablet else 15) * large_scale)))
	for b in _degree_toggles.values():
		var degree_btn := b as Button
		if degree_btn == null:
			continue
		degree_btn.add_theme_font_size_override("font_size", int(roundf((16 if is_tablet else 12) * large_scale)))
	var section_label_font := int(roundf((21 if is_tablet else 16) * large_scale))
	_set_label_font_size_recursive(_interval_options_box, section_label_font)
	_set_label_font_size_recursive(_chord_options_box, section_label_font)
	_set_label_font_size_recursive(_sight_options_box, section_label_font)
	_set_label_font_size_recursive(_note_chase_options_box, section_label_font)
	_set_label_font_size_recursive(_ear_settings_screen, section_label_font)
	if _ear_settings_header_label != null:
		_ear_settings_header_label.add_theme_font_size_override("font_size", int(roundf((25 if is_tablet else 20) * large_scale)))
	if _sight_settings_header_label != null:
		_sight_settings_header_label.add_theme_font_size_override("font_size", int(roundf((25 if is_tablet else 20) * large_scale)))
	var settings_small_label_font := int(roundf((16 if is_tablet else 13) * large_scale))
	if _ear_choice_label != null:
		_ear_choice_label.add_theme_font_size_override("font_size", settings_small_label_font)
	if _ear_questions_label != null:
		_ear_questions_label.add_theme_font_size_override("font_size", settings_small_label_font)
	if _sight_questions_label != null:
		_sight_questions_label.add_theme_font_size_override("font_size", settings_small_label_font)
	if _question_spin != null:
		_question_spin.custom_minimum_size = Vector2(120, 48) if is_tablet else Vector2(90, 32)
		_question_spin.add_theme_font_size_override("font_size", int(roundf((18 if is_tablet else 14) * large_scale)))
	if _ear_choice_count_select != null:
		_ear_choice_count_select.custom_minimum_size = Vector2(96, 42) if is_tablet else Vector2(80, 34)
		_ear_choice_count_select.add_theme_font_size_override("font_size", int(roundf((18 if is_tablet else 14) * large_scale)))
	if _ear_theme_select != null:
		_ear_theme_select.custom_minimum_size = Vector2(240, 42) if is_tablet else Vector2(180, 34)
		_ear_theme_select.add_theme_font_size_override("font_size", int(roundf((18 if is_tablet else 14) * large_scale)))
	if _sight_question_spin != null:
		_sight_question_spin.custom_minimum_size = Vector2(120, 48) if is_tablet else Vector2(90, 32)
		_sight_question_spin.add_theme_font_size_override("font_size", int(roundf((18 if is_tablet else 14) * large_scale)))
	if _inversion_toggle != null:
		_inversion_toggle.custom_minimum_size = Vector2(194, 46) if is_tablet else Vector2(168, 38)
		_inversion_toggle.add_theme_font_size_override("font_size", int(roundf((20 if is_tablet else 16) * large_scale)))
	if _adaptive_toggle != null:
		_adaptive_toggle.custom_minimum_size = Vector2(270, 52) if is_tablet else Vector2(230, 42)
		_adaptive_toggle.add_theme_font_size_override("font_size", int(roundf((20 if is_tablet else 16) * large_scale)))
	if _sight_accidentals_toggle != null:
		_sight_accidentals_toggle.custom_minimum_size = Vector2(260, 52) if is_tablet else Vector2(220, 42)
		_sight_accidentals_toggle.add_theme_font_size_override("font_size", int(roundf((20 if is_tablet else 16) * large_scale)))
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", int(roundf((60 if is_tablet else 52) * large_scale)))
	if _home_title_label != null:
		_home_title_label.add_theme_font_size_override("font_size", int(roundf((28 if is_tablet else 22) * large_scale)))
	if _header_tagline_label != null:
		_header_tagline_label.add_theme_font_size_override("font_size", int(roundf((16 if is_tablet else 13) * large_scale)))
	if _home_start_button != null:
		if not _home_start_button.has_meta("base_min_size"):
			_home_start_button.set_meta("base_min_size", _home_start_button.custom_minimum_size)
		var start_meta: Variant = _home_start_button.get_meta("base_min_size")
		var start_base: Vector2 = start_meta if start_meta is Vector2 else _home_start_button.custom_minimum_size
		_home_start_button.custom_minimum_size = Vector2(maxf(start_base.x, 220 if is_tablet else 170), maxf(start_base.y, btn_h))
		_home_start_button.add_theme_font_size_override("font_size", int(roundf((22 if is_tablet else 17) * large_scale)))
	if _restart_button != null:
		_restart_button.custom_minimum_size = Vector2(168, 58) if is_tablet else Vector2(130, 44)
		_restart_button.add_theme_font_size_override("font_size", int(roundf((20 if is_tablet else 17) * large_scale)))
	if _end_button != null:
		_end_button.custom_minimum_size = Vector2(168, 58) if is_tablet else Vector2(130, 44)
		_end_button.add_theme_font_size_override("font_size", int(roundf((20 if is_tablet else 17) * large_scale)))
	for k in _sight_key_buttons.values():
		var k_btn := k as Button
		if k_btn == null:
			continue
		k_btn.custom_minimum_size = Vector2(148, 84) if is_tablet else Vector2(118, 68)
		k_btn.add_theme_font_size_override("font_size", int(roundf((27 if is_tablet else 22) * large_scale)))
	for cbtn in _sight_chord_choice_buttons:
		if cbtn == null:
			continue
		cbtn.custom_minimum_size = Vector2(246, 84) if is_tablet else Vector2(204, 68)
		cbtn.add_theme_font_size_override("font_size", int(roundf((23 if is_tablet else 19) * large_scale)))
	for kb in _continuous_key_buttons:
		if kb == null:
			continue
		kb.custom_minimum_size = Vector2(90, 178) if is_tablet else Vector2(62, 132)
		kb.add_theme_font_size_override("font_size", int(roundf((20 if is_tablet else 15) * large_scale)))
		_layout_virtual_black_key(kb)
	if _sight_keyboard_row != null:
		_sight_keyboard_row.add_theme_constant_override("separation", 12 if is_tablet else 8)
	if _tutorial_bubble != null:
		_tutorial_bubble.custom_minimum_size = Vector2(710, 170) if is_tablet else Vector2(620, 148)
	if _tutorial_bubble_label != null:
		_tutorial_bubble_label.add_theme_font_size_override("font_size", int(roundf((24 if is_tablet else 22) * large_scale)))
		_tutorial_bubble_label.position = Vector2(26, 18) if is_tablet else Vector2(24, 16)
		_tutorial_bubble_label.size = Vector2(650, 128) if is_tablet else Vector2(568, 114)
	if _tutorial_chicken != null:
		_tutorial_chicken.custom_minimum_size = Vector2(174, 174) if is_tablet else Vector2(152, 152)
		_tutorial_chicken.size = _tutorial_chicken.custom_minimum_size
	_apply_home_layout_profile(profile)


func _apply_home_layout_profile(profile: Dictionary) -> void:
	if _home_menu_ui == null or _home_tokens == null:
		return
	var profile_name := str(profile.get("name", "large_phone"))
	var compact_profile := profile_name == "small_phone"
	_home_mode_buttons_row = _home_menu_ui.ensure_grid_layout(_home_mode_buttons_row, int(profile.get("columns_modes", 2)), _home_tokens.SPACING["grid_h_gap"], _home_tokens.SPACING["grid_v_gap"])
	var interval_cols := _home_interval_degree_row.get_child_count() if _home_interval_degree_row != null else int(profile.get("columns_degrees", 4))
	var chase_note_cols := _home_chase_note_row.get_child_count() if _home_chase_note_row != null else int(profile.get("columns_notes", 4))
	var chase_clef_cols := 2 if compact_profile else (_home_chase_clef_row.get_child_count() if _home_chase_clef_row != null else 4)
	var sight_clef_cols := 1 if compact_profile else 2
	_home_interval_degree_row = _home_menu_ui.ensure_grid_layout(_home_interval_degree_row, max(1, interval_cols), _home_tokens.SPACING["grid_h_gap"], _home_tokens.SPACING["grid_v_gap"])
	_home_chase_note_row = _home_menu_ui.ensure_grid_layout(_home_chase_note_row, max(1, chase_note_cols), _home_tokens.SPACING["grid_h_gap"], _home_tokens.SPACING["grid_v_gap"])
	_home_chase_clef_row = _home_menu_ui.ensure_grid_layout(_home_chase_clef_row, max(1, chase_clef_cols), _home_tokens.SPACING["grid_h_gap"], _home_tokens.SPACING["grid_v_gap"])
	_sight_clef_row = _home_menu_ui.ensure_grid_layout(_sight_clef_row, max(1, sight_clef_cols), _home_tokens.SPACING["grid_h_gap"], _home_tokens.SPACING["grid_v_gap"])


func _set_label_font_size_recursive(node: Node, font_size: int) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Label:
			var lbl := child as Label
			if lbl != null:
				lbl.add_theme_font_size_override("font_size", font_size)
		_set_label_font_size_recursive(child, font_size)


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

	_header_card = PanelContainer.new()
	_header_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_child(_header_card)

	var header_col := VBoxContainer.new()
	header_col.alignment = BoxContainer.ALIGNMENT_CENTER
	header_col.add_theme_constant_override("separation", 4)
	_header_card.add_child(header_col)

	var header_top_row := HBoxContainer.new()
	header_top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_col.add_child(header_top_row)

	var header_left_slot := Control.new()
	header_left_slot.custom_minimum_size = Vector2(144, 0)
	header_top_row.add_child(header_left_slot)

	var header_center_col := VBoxContainer.new()
	header_center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	header_center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_center_col.add_theme_constant_override("separation", 0)
	header_top_row.add_child(header_center_col)

	_title_label = Label.new()
	_title_label.text = "Clefira"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 52)
	header_center_col.add_child(_title_label)

	_header_tagline_label = Label.new()
	_header_tagline_label.text = "Music learning that actually sticks."
	_header_tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_tagline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_tagline_label.add_theme_font_size_override("font_size", 14)
	header_center_col.add_child(_header_tagline_label)

	var header_back_slot := HBoxContainer.new()
	header_back_slot.custom_minimum_size = Vector2(144, 0)
	header_back_slot.alignment = BoxContainer.ALIGNMENT_END
	header_top_row.add_child(header_back_slot)

	_home_mode_back_button = Button.new()
	_home_mode_back_button.text = "Back"
	_home_mode_back_button.custom_minimum_size = Vector2(108, 40)
	_home_mode_back_button.pressed.connect(_on_home_back_pressed)
	header_back_slot.add_child(_home_mode_back_button)
	_home_material_buttons.append(_home_mode_back_button)

	_home_card = PanelContainer.new()
	_home_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_card.custom_minimum_size = Vector2(0, 280)
	main_col.add_child(_home_card)

	_home_panel = VBoxContainer.new()
	_home_panel.add_theme_constant_override("separation", 10)
	_home_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_panel.alignment = BoxContainer.ALIGNMENT_BEGIN
	_home_card.add_child(_home_panel)

	_home_title_label = Label.new()
	_home_title_label.text = "Choose Mode"
	_home_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_title_label.add_theme_font_size_override("font_size", 24)
	_home_panel.add_child(_home_title_label)

	_home_hub_row = HBoxContainer.new()
	_home_hub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_hub_row.add_theme_constant_override("separation", 10)
	_home_panel.add_child(_home_hub_row)

	for hub_name in ["Practice", "Learn"]:
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
	_home_mode_label.text = "Mode:"
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
	sight_mode_btn.text = "Sight Reading"
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
	read_mode_btn.visible = false

	var home_settings_spacer := Control.new()
	home_settings_spacer.custom_minimum_size = Vector2(0, 10)
	_home_panel.add_child(home_settings_spacer)

	_home_settings_button = Button.new()
	_home_settings_button.text = "Settings"
	_home_settings_button.custom_minimum_size = Vector2(108, 30)
	_home_settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_home_settings_button.set_meta("mini_btn", true)
	_home_settings_button.pressed.connect(_on_ear_settings_pressed)
	_home_panel.add_child(_home_settings_button)
	_home_material_buttons.append(_home_settings_button)

	_ear_mode_row = HBoxContainer.new()
	_ear_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ear_mode_row.add_theme_constant_override("separation", 8)
	_home_panel.add_child(_ear_mode_row)

	var ear_interval_btn := Button.new()
	ear_interval_btn.text = "Interval"
	ear_interval_btn.custom_minimum_size = Vector2(136, 44)
	ear_interval_btn.pressed.connect(_on_ear_mode_button_pressed.bind(MODE_INTERVAL))
	_ear_mode_row.add_child(ear_interval_btn)
	_ear_mode_buttons[MODE_INTERVAL] = ear_interval_btn
	_home_material_buttons.append(ear_interval_btn)

	var ear_chord_btn := Button.new()
	ear_chord_btn.text = "Chord"
	ear_chord_btn.custom_minimum_size = Vector2(136, 44)
	ear_chord_btn.pressed.connect(_on_ear_mode_button_pressed.bind(MODE_CHORD))
	_ear_mode_row.add_child(ear_chord_btn)
	_ear_mode_buttons[MODE_CHORD] = ear_chord_btn
	_home_material_buttons.append(ear_chord_btn)

	_ear_settings_screen = VBoxContainer.new()
	_ear_settings_screen.add_theme_constant_override("separation", 10)
	_ear_settings_screen.alignment = BoxContainer.ALIGNMENT_CENTER
	_ear_settings_screen.visible = false
	_home_panel.add_child(_ear_settings_screen)

	_ear_settings_more_panel = VBoxContainer.new()
	_ear_settings_more_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_ear_settings_more_panel.add_theme_constant_override("separation", 8)
	_ear_settings_more_panel.visible = true
	_ear_settings_screen.add_child(_ear_settings_more_panel)

	var theme_row := HBoxContainer.new()
	theme_row.alignment = BoxContainer.ALIGNMENT_CENTER
	theme_row.add_theme_constant_override("separation", 10)
	_ear_settings_more_panel.add_child(theme_row)

	var theme_label := Label.new()
	theme_label.text = "Theme:"
	theme_row.add_child(theme_label)

	_ear_theme_select = OptionButton.new()
	_ear_theme_select.custom_minimum_size = Vector2(220, 42)
	if _home_tokens != null:
		for theme_id in _home_tokens.theme_ids():
			_ear_theme_select.add_item(_home_tokens.theme_label(theme_id))
			_ear_theme_select.set_item_metadata(_ear_theme_select.item_count - 1, theme_id)
	_ear_theme_select.item_selected.connect(_on_theme_selected)
	theme_row.add_child(_ear_theme_select)

	_ear_settings_header_label = Label.new()
	_ear_settings_header_label.text = "Ear Training"
	_ear_settings_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ear_settings_header_label.set_meta("settings_section_header", true)
	_ear_settings_more_panel.add_child(_ear_settings_header_label)

	var ear_choice_row := HBoxContainer.new()
	ear_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ear_choice_row.add_theme_constant_override("separation", 10)
	_ear_settings_more_panel.add_child(ear_choice_row)

	_ear_choice_label = Label.new()
	_ear_choice_label.text = "Number of choices:"
	_ear_choice_label.set_meta("settings_small_label", true)
	ear_choice_row.add_child(_ear_choice_label)

	_ear_choice_count_select = OptionButton.new()
	for c in [2, 3, 4, 5, 6]:
		_ear_choice_count_select.add_item(str(c))
		_ear_choice_count_select.set_item_metadata(_ear_choice_count_select.item_count - 1, c)
	_ear_choice_count_select.custom_minimum_size = Vector2(104, 42)
	_ear_choice_count_select.item_selected.connect(_on_ear_choice_count_selected)
	ear_choice_row.add_child(_ear_choice_count_select)

	var q_row := HBoxContainer.new()
	q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	q_row.add_theme_constant_override("separation", 8)
	_ear_settings_more_panel.add_child(q_row)
	_ear_questions_label = Label.new()
	_ear_questions_label.text = "Number of questions:"
	_ear_questions_label.set_meta("settings_small_label", true)
	q_row.add_child(_ear_questions_label)
	_question_spin = SpinBox.new()
	_question_spin.min_value = 1
	_question_spin.max_value = 100
	_question_spin.step = 1
	_question_spin.value = 10
	_question_spin.custom_minimum_size = Vector2(110, 40)
	q_row.add_child(_question_spin)

	var settings_section_spacer := Control.new()
	settings_section_spacer.custom_minimum_size = Vector2(0, 16)
	_ear_settings_screen.add_child(settings_section_spacer)

	_refresh_ear_settings_ui()

	_interval_options_box = VBoxContainer.new()
	_interval_options_box.add_theme_constant_override("separation", 16)
	_home_panel.add_child(_interval_options_box)

	var intervals_label := Label.new()
	intervals_label.text = "Interval Options"
	intervals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interval_options_box.add_child(intervals_label)

	var interval_row := HBoxContainer.new()
	interval_row.alignment = BoxContainer.ALIGNMENT_CENTER
	interval_row.add_theme_constant_override("separation", 10)
	var interval_main_group := _create_home_option_group(_interval_options_box)
	interval_main_group.add_child(interval_row)
	_home_interval_degree_row = interval_row

	var degree_label := Label.new()
	degree_label.text = "Scale Degrees:"
	interval_row.add_child(degree_label)

	for degree in range(1, 9):
		var degree_btn := Button.new()
		degree_btn.text = str(degree)
		degree_btn.toggle_mode = true
		degree_btn.button_pressed = DEFAULT_INTERVAL_DEGREES.has(degree)
		degree_btn.custom_minimum_size = Vector2(42, 30)
		degree_btn.set_meta("compact_btn", true)
		degree_btn.toggled.connect(_on_degree_toggled.bind(degree))
		interval_row.add_child(degree_btn)
		_degree_toggles[degree] = degree_btn
		_home_material_buttons.append(degree_btn)

	var interval_minor_row := HBoxContainer.new()
	interval_minor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	interval_minor_row.add_theme_constant_override("separation", 10)
	var interval_minor_group := _create_home_option_group(_interval_options_box, true)
	interval_minor_group.add_child(interval_minor_row)

	_include_minor_toggle = Button.new()
	_include_minor_toggle.toggle_mode = true
	_include_minor_toggle.text = "Minor Intervals Off"
	_include_minor_toggle.button_pressed = false
	_include_minor_toggle.custom_minimum_size = Vector2(240, 64)
	_include_minor_toggle.tooltip_text = "Include minor interval options (m2, m3, m6, m7)."
	_include_minor_toggle.toggled.connect(_on_include_minor_toggled)
	interval_minor_row.add_child(_include_minor_toggle)
	_style_include_minor_toggle(_include_minor_toggle.button_pressed)

	_descending_intervals_toggle = Button.new()
	_descending_intervals_toggle.toggle_mode = true
	_descending_intervals_toggle.button_pressed = _use_descending_intervals
	_descending_intervals_toggle.custom_minimum_size = Vector2(230, 64)
	_descending_intervals_toggle.tooltip_text = "Play interval as top note down to root."
	_descending_intervals_toggle.toggled.connect(_on_descending_intervals_toggled)
	interval_minor_row.add_child(_descending_intervals_toggle)
	_style_descending_intervals_toggle(_use_descending_intervals)

	_harmonic_intervals_toggle = Button.new()
	_harmonic_intervals_toggle.toggle_mode = true
	_harmonic_intervals_toggle.button_pressed = _use_harmonic_intervals
	_harmonic_intervals_toggle.custom_minimum_size = Vector2(220, 64)
	_harmonic_intervals_toggle.tooltip_text = "Play both interval notes together (harmonic interval)."
	_harmonic_intervals_toggle.toggled.connect(_on_harmonic_intervals_toggled)
	interval_minor_row.add_child(_harmonic_intervals_toggle)
	_style_harmonic_intervals_toggle(_use_harmonic_intervals)

	_chord_options_box = VBoxContainer.new()
	_chord_options_box.add_theme_constant_override("separation", 16)
	_home_panel.add_child(_chord_options_box)

	var chord_options_title := Label.new()
	chord_options_title.text = "Chord Options"
	chord_options_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chord_options_box.add_child(chord_options_title)

	var family_inversion_row := HBoxContainer.new()
	family_inversion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	family_inversion_row.add_theme_constant_override("separation", 20)
	var chord_family_group := _create_home_option_group(_chord_options_box)
	chord_family_group.add_child(family_inversion_row)

	var family_left_box := VBoxContainer.new()
	family_left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	family_left_box.custom_minimum_size = Vector2(360, 0)
	family_inversion_row.add_child(family_left_box)

	var family_row := HBoxContainer.new()
	family_row.alignment = BoxContainer.ALIGNMENT_CENTER
	family_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	family_row.add_theme_constant_override("separation", 8)
	family_left_box.add_child(family_row)

	var inversion_right_box := VBoxContainer.new()
	inversion_right_box.alignment = BoxContainer.ALIGNMENT_CENTER
	inversion_right_box.custom_minimum_size = Vector2(190, 0)
	family_inversion_row.add_child(inversion_right_box)

	_inversion_toggle = Button.new()
	_inversion_toggle.toggle_mode = true
	_inversion_toggle.text = "Inversions"
	_inversion_toggle.button_pressed = true
	_inversion_toggle.custom_minimum_size = Vector2(168, 56)
	_inversion_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inversion_toggle.tooltip_text = "Root, 1st, and 2nd inversion"
	_inversion_toggle.toggled.connect(_on_inversion_toggled)
	inversion_right_box.add_child(_inversion_toggle)

	var group_defs := {
		1: "Maj/Min",
		2: "Aug/Dim",
		3: "Sus & 7th",
		4: "All"
	}
	for group_id in [1, 2, 3, 4]:
		var g_btn := Button.new()
		g_btn.text = str(group_defs[group_id])
		g_btn.custom_minimum_size = Vector2(104, 34)
		g_btn.set_meta("compact_btn", true)
		g_btn.pressed.connect(_on_chord_group_button_pressed.bind(group_id))
		family_row.add_child(g_btn)
		_chord_group_buttons[group_id] = g_btn
		_home_material_buttons.append(g_btn)

	_adaptive_toggle = CheckButton.new()
	_adaptive_toggle.text = "Adaptive (All mode)"
	_adaptive_toggle.button_pressed = true
	_adaptive_toggle.disabled = true
	_adaptive_toggle.custom_minimum_size = Vector2(280, 46)
	_adaptive_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_adaptive_toggle.tooltip_text = "All mode auto-progresses by streak"
	var chord_adaptive_group := _create_home_option_group(_chord_options_box, true)
	chord_adaptive_group.add_child(_adaptive_toggle)

	_sight_options_box = VBoxContainer.new()
	_sight_options_box.add_theme_constant_override("separation", 18)
	_home_panel.add_child(_sight_options_box)

	var sight_mode_row := HBoxContainer.new()
	sight_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_mode_row.add_theme_constant_override("separation", 12)
	_sight_options_box.add_child(sight_mode_row)
	_home_sight_mode_row = sight_mode_row

	var sight_notes_btn := Button.new()
	sight_notes_btn.text = "Notes"
	sight_notes_btn.custom_minimum_size = Vector2(124, 44)
	sight_notes_btn.pressed.connect(_on_sight_mode_button_pressed.bind("Notes"))
	sight_mode_row.add_child(sight_notes_btn)
	_sight_mode_buttons["Notes"] = sight_notes_btn
	_home_material_buttons.append(sight_notes_btn)

	var sight_chords_btn := Button.new()
	sight_chords_btn.text = "Chords"
	sight_chords_btn.custom_minimum_size = Vector2(124, 44)
	sight_chords_btn.pressed.connect(_on_sight_mode_button_pressed.bind("Chords"))
	sight_mode_row.add_child(sight_chords_btn)
	_sight_mode_buttons["Chords"] = sight_chords_btn
	_home_material_buttons.append(sight_chords_btn)

	var sight_continuous_btn := Button.new()
	sight_continuous_btn.text = "Note Flow"
	sight_continuous_btn.custom_minimum_size = Vector2(146, 44)
	sight_continuous_btn.pressed.connect(_on_sight_mode_button_pressed.bind("Continuous"))
	sight_mode_row.add_child(sight_continuous_btn)
	_sight_mode_buttons["Continuous"] = sight_continuous_btn
	_home_material_buttons.append(sight_continuous_btn)

	_sight_note_chase_button = Button.new()
	_sight_note_chase_button.text = "Note Chase"
	_sight_note_chase_button.custom_minimum_size = Vector2(146, 44)
	_sight_note_chase_button.pressed.connect(_on_mode_button_pressed.bind(MODE_NOTE_CHASE))
	sight_mode_row.add_child(_sight_note_chase_button)
	_home_material_buttons.append(_sight_note_chase_button)

	_sight_settings_more_panel = VBoxContainer.new()
	_sight_settings_more_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_sight_settings_more_panel.add_theme_constant_override("separation", 8)
	_sight_settings_more_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sight_settings_more_panel.visible = true
	_ear_settings_screen.add_child(_sight_settings_more_panel)

	_sight_settings_header_label = Label.new()
	_sight_settings_header_label.text = "Sight Reading"
	_sight_settings_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_settings_header_label.set_meta("settings_section_header", true)
	_sight_settings_more_panel.add_child(_sight_settings_header_label)

	var sight_q_row := HBoxContainer.new()
	sight_q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_q_row.add_theme_constant_override("separation", 8)
	_sight_settings_more_panel.add_child(sight_q_row)
	_sight_questions_label = Label.new()
	_sight_questions_label.text = "Number of questions:"
	_sight_questions_label.set_meta("settings_small_label", true)
	sight_q_row.add_child(_sight_questions_label)
	_sight_question_spin = SpinBox.new()
	_sight_question_spin.min_value = 1
	_sight_question_spin.max_value = 100
	_sight_question_spin.step = 1
	_sight_question_spin.value = 10
	_sight_question_spin.custom_minimum_size = Vector2(90, 32)
	sight_q_row.add_child(_sight_question_spin)

	var clef_row := HBoxContainer.new()
	clef_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clef_row.add_theme_constant_override("separation", 12)
	var sight_setup_group := _create_home_option_group(_sight_options_box)
	sight_setup_group.add_child(clef_row)
	_sight_clef_row = clef_row

	var treble_btn := Button.new()
	treble_btn.text = "Treble Clef"
	treble_btn.custom_minimum_size = Vector2(140, 34)
	treble_btn.set_meta("compact_btn", true)
	treble_btn.pressed.connect(_on_clef_button_pressed.bind("Treble"))
	clef_row.add_child(treble_btn)
	_clef_buttons["Treble"] = treble_btn
	_home_material_buttons.append(treble_btn)

	var bass_btn := Button.new()
	bass_btn.text = "Bass Clef"
	bass_btn.custom_minimum_size = Vector2(140, 34)
	bass_btn.set_meta("compact_btn", true)
	bass_btn.pressed.connect(_on_clef_button_pressed.bind("Bass"))
	clef_row.add_child(bass_btn)
	_clef_buttons["Bass"] = bass_btn
	_home_material_buttons.append(bass_btn)

	_sight_key_sig_row = HBoxContainer.new()
	_sight_key_sig_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sight_key_sig_row.add_theme_constant_override("separation", 12)
	sight_setup_group.add_child(_sight_key_sig_row)

	var key_sig_label := Label.new()
	key_sig_label.text = "Key Signature:"
	key_sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_key_sig_row.add_child(key_sig_label)

	var sig_none_btn := Button.new()
	sig_none_btn.text = "C"
	sig_none_btn.custom_minimum_size = Vector2(58, 30)
	sig_none_btn.set_meta("compact_btn", true)
	sig_none_btn.pressed.connect(_on_sight_key_sig_button_pressed.bind("C"))
	_sight_key_sig_row.add_child(sig_none_btn)
	_sight_key_sig_buttons["C"] = sig_none_btn
	_home_material_buttons.append(sig_none_btn)

	var sig_2s_btn := Button.new()
	sig_2s_btn.text = "2" + char(0x266F)
	sig_2s_btn.custom_minimum_size = Vector2(56, 30)
	sig_2s_btn.set_meta("compact_btn", true)
	sig_2s_btn.pressed.connect(_on_sight_key_sig_button_pressed.bind("2#"))
	_sight_key_sig_row.add_child(sig_2s_btn)
	_sight_key_sig_buttons["2#"] = sig_2s_btn
	_home_material_buttons.append(sig_2s_btn)

	var sig_3s_btn := Button.new()
	sig_3s_btn.text = "3" + char(0x266F)
	sig_3s_btn.custom_minimum_size = Vector2(56, 30)
	sig_3s_btn.set_meta("compact_btn", true)
	sig_3s_btn.pressed.connect(_on_sight_key_sig_button_pressed.bind("3#"))
	_sight_key_sig_row.add_child(sig_3s_btn)
	_sight_key_sig_buttons["3#"] = sig_3s_btn
	_home_material_buttons.append(sig_3s_btn)

	var sig_2b_btn := Button.new()
	sig_2b_btn.text = "2" + char(0x266D)
	sig_2b_btn.custom_minimum_size = Vector2(56, 30)
	sig_2b_btn.set_meta("compact_btn", true)
	sig_2b_btn.pressed.connect(_on_sight_key_sig_button_pressed.bind("2b"))
	_sight_key_sig_row.add_child(sig_2b_btn)
	_sight_key_sig_buttons["2b"] = sig_2b_btn
	_home_material_buttons.append(sig_2b_btn)

	var sig_3b_btn := Button.new()
	sig_3b_btn.text = "3" + char(0x266D)
	sig_3b_btn.custom_minimum_size = Vector2(56, 30)
	sig_3b_btn.set_meta("compact_btn", true)
	sig_3b_btn.pressed.connect(_on_sight_key_sig_button_pressed.bind("3b"))
	_sight_key_sig_row.add_child(sig_3b_btn)
	_sight_key_sig_buttons["3b"] = sig_3b_btn
	_home_material_buttons.append(sig_3b_btn)

	var sight_acc_row := HBoxContainer.new()
	sight_acc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_setup_group.add_child(sight_acc_row)

	_sight_accidentals_toggle = CheckButton.new()
	_sight_accidentals_toggle.text = "Accidentals"
	_sight_accidentals_toggle.button_pressed = false
	_sight_accidentals_toggle.custom_minimum_size = Vector2(220, 42)
	_sight_accidentals_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sight_accidentals_toggle.toggled.connect(_on_sight_accidentals_toggled)
	sight_acc_row.add_child(_sight_accidentals_toggle)

	_sight_range_container = VBoxContainer.new()
	_sight_range_container.add_theme_constant_override("separation", 4)
	var sight_range_group := _create_home_option_group(_sight_options_box, true)
	sight_range_group.add_child(_sight_range_container)

	var range_title := Label.new()
	range_title.text = "Range"
	range_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_container.add_child(range_title)

	_sight_range_info_label = Label.new()
	_sight_range_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_info_label.visible = false
	_sight_range_container.add_child(_sight_range_info_label)

	var range_row := HBoxContainer.new()
	range_row.alignment = BoxContainer.ALIGNMENT_CENTER
	range_row.add_theme_constant_override("separation", 8)
	_sight_range_container.add_child(range_row)

	var lower_minus := Button.new()
	lower_minus.text = "-"
	lower_minus.custom_minimum_size = Vector2(30, 26)
	lower_minus.set_meta("compact_btn", true)
	lower_minus.pressed.connect(_on_sight_range_adjust.bind(1, false))
	range_row.add_child(lower_minus)
	_home_material_buttons.append(lower_minus)

	_sight_range_lower_value_label = Label.new()
	_sight_range_lower_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_lower_value_label.custom_minimum_size = Vector2(54, 0)
	range_row.add_child(_sight_range_lower_value_label)

	var lower_plus := Button.new()
	lower_plus.text = "+"
	lower_plus.custom_minimum_size = Vector2(30, 26)
	lower_plus.set_meta("compact_btn", true)
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
	upper_minus.custom_minimum_size = Vector2(30, 26)
	upper_minus.set_meta("compact_btn", true)
	upper_minus.pressed.connect(_on_sight_range_adjust.bind(1, true))
	range_row.add_child(upper_minus)
	_home_material_buttons.append(upper_minus)

	_sight_range_upper_value_label = Label.new()
	_sight_range_upper_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_range_upper_value_label.custom_minimum_size = Vector2(54, 0)
	range_row.add_child(_sight_range_upper_value_label)

	var upper_plus := Button.new()
	upper_plus.text = "+"
	upper_plus.custom_minimum_size = Vector2(30, 26)
	upper_plus.set_meta("compact_btn", true)
	upper_plus.pressed.connect(_on_sight_range_adjust.bind(-1, true))
	range_row.add_child(upper_plus)
	_home_material_buttons.append(upper_plus)

	_note_chase_options_box = VBoxContainer.new()
	_note_chase_options_box.add_theme_constant_override("separation", 16)
	_home_panel.add_child(_note_chase_options_box)
	var chase_note_row := HBoxContainer.new()
	chase_note_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chase_note_row.add_theme_constant_override("separation", 12)
	var chase_note_group := _create_home_option_group(_note_chase_options_box)
	chase_note_group.add_child(chase_note_row)
	_home_chase_note_row = chase_note_row
	var chase_note_label := Label.new()
	chase_note_label.text = "Target Notes (max 3):"
	chase_note_row.add_child(chase_note_label)
	for n in ["C", "D", "E", "F", "G", "A", "B"]:
		var t := Button.new()
		t.toggle_mode = true
		t.text = n
		t.custom_minimum_size = Vector2(36, 28)
		t.set_meta("mini_btn", true)
		t.button_pressed = _note_chase_selected_notes.has(n)
		t.pressed.connect(_on_note_chase_note_toggled.bind(n))
		chase_note_row.add_child(t)
		_note_chase_note_toggles[n] = t
		_home_material_buttons.append(t)
	var chase_clef_row := HBoxContainer.new()
	chase_clef_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chase_clef_row.add_theme_constant_override("separation", 12)
	var chase_clef_group := _create_home_option_group(_note_chase_options_box, true)
	chase_clef_group.add_child(chase_clef_row)
	_home_chase_clef_row = chase_clef_row
	var chase_clef_label := Label.new()
	chase_clef_label.text = "Clef:"
	chase_clef_row.add_child(chase_clef_label)
	var chase_treble_btn := Button.new()
	chase_treble_btn.text = "Treble"
	chase_treble_btn.custom_minimum_size = Vector2(102, 30)
	chase_treble_btn.set_meta("compact_btn", true)
	chase_treble_btn.pressed.connect(_on_note_chase_clef_mode_pressed.bind("Treble"))
	chase_clef_row.add_child(chase_treble_btn)
	_note_chase_clef_buttons["Treble"] = chase_treble_btn
	_home_material_buttons.append(chase_treble_btn)
	var chase_bass_btn := Button.new()
	chase_bass_btn.text = "Bass"
	chase_bass_btn.custom_minimum_size = Vector2(102, 30)
	chase_bass_btn.set_meta("compact_btn", true)
	chase_bass_btn.pressed.connect(_on_note_chase_clef_mode_pressed.bind("Bass"))
	chase_clef_row.add_child(chase_bass_btn)
	_note_chase_clef_buttons["Bass"] = chase_bass_btn
	_home_material_buttons.append(chase_bass_btn)
	var chase_both_btn := Button.new()
	chase_both_btn.text = "Both"
	chase_both_btn.custom_minimum_size = Vector2(102, 30)
	chase_both_btn.set_meta("compact_btn", true)
	chase_both_btn.pressed.connect(_on_note_chase_clef_mode_pressed.bind("Both"))
	chase_clef_row.add_child(chase_both_btn)
	_note_chase_clef_buttons["Both"] = chase_both_btn
	_home_material_buttons.append(chase_both_btn)
	_read_options_box = VBoxContainer.new()
	_read_options_box.add_theme_constant_override("separation", 14)
	_home_panel.add_child(_read_options_box)

	var read_title := Label.new()
	read_title.text = "Read Notation Module"
	read_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_read_options_box.add_child(read_title)

	var read_row := HBoxContainer.new()
	read_row.alignment = BoxContainer.ALIGNMENT_CENTER
	read_row.add_theme_constant_override("separation", 8)
	var read_group := _create_home_option_group(_read_options_box, true)
	read_group.add_child(read_row)

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
	_home_disabled_reason_label = Label.new()
	_home_disabled_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_disabled_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_disabled_reason_label.add_theme_font_size_override("font_size", 14)
	_home_panel.add_child(_home_disabled_reason_label)
	_finalize_home_menu_layout()

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
	_hud_left_box.custom_minimum_size = Vector2(230, 60)
	hud_row.add_child(_hud_left_box)

	var hud_left_v := VBoxContainer.new()
	hud_left_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_left_v.add_theme_constant_override("separation", 6)
	_hud_left_box.add_child(hud_left_v)
	_lives_label = Label.new()
	_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lives_label.add_theme_font_size_override("font_size", 20)
	hud_left_v.add_child(_lives_label)
	_note_chase_target_box = PanelContainer.new()
	_note_chase_target_box.custom_minimum_size = Vector2(222, 28)
	hud_left_v.add_child(_note_chase_target_box)
	_note_chase_target_label = Label.new()
	_note_chase_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_target_label.add_theme_font_size_override("font_size", 15)
	_note_chase_target_box.add_child(_note_chase_target_label)
	_note_chase_speed_box = PanelContainer.new()
	_note_chase_speed_box.custom_minimum_size = Vector2(222, 26)
	hud_left_v.add_child(_note_chase_speed_box)
	_note_chase_speed_label = Label.new()
	_note_chase_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_speed_label.add_theme_font_size_override("font_size", 14)
	_note_chase_speed_box.add_child(_note_chase_speed_label)
	_note_chase_combo_box = PanelContainer.new()
	_note_chase_combo_box.custom_minimum_size = Vector2(222, 26)
	hud_left_v.add_child(_note_chase_combo_box)
	_note_chase_combo_label = Label.new()
	_note_chase_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_combo_label.add_theme_font_size_override("font_size", 14)
	_note_chase_combo_box.add_child(_note_chase_combo_label)
	_note_chase_shield_box = PanelContainer.new()
	_note_chase_shield_box.custom_minimum_size = Vector2(222, 26)
	hud_left_v.add_child(_note_chase_shield_box)
	_note_chase_shield_label = Label.new()
	_note_chase_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_shield_label.add_theme_font_size_override("font_size", 14)
	_note_chase_shield_box.add_child(_note_chase_shield_label)
	_note_chase_target_box.visible = false
	_note_chase_speed_box.visible = false
	_note_chase_combo_box.visible = false
	_note_chase_shield_box.visible = false

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
	_sight_key_label = Label.new()
	_sight_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sight_key_label.add_theme_font_size_override("font_size", 14)
	_sight_key_label.add_theme_color_override("font_color", Color(0.66, 0.96, 0.98, 1.0))
	_sight_key_label.visible = false
	hud_center_v.add_child(_sight_key_label)

	_hud_right_box = PanelContainer.new()
	_hud_right_box.custom_minimum_size = Vector2(170, 74)
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
	_note_chase_level_label = Label.new()
	_note_chase_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_chase_level_label.add_theme_font_size_override("font_size", 20)
	hud_right_v.add_child(_note_chase_level_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 20)
	_game_panel.add_child(_status_label)

	_interval_center_top_spacer = Control.new()
	_interval_center_top_spacer.custom_minimum_size = Vector2(0, 70)
	_interval_center_top_spacer.visible = false
	_game_panel.add_child(_interval_center_top_spacer)

	_control_row = HBoxContainer.new()
	_control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_control_row.add_theme_constant_override("separation", 12)
	_game_panel.add_child(_control_row)

	_replay_button = Button.new()
	_replay_button.text = "Replay"
	_replay_button.custom_minimum_size = Vector2(130, 44)
	_replay_button.pressed.connect(_on_replay_pressed)
	_control_row.add_child(_replay_button)

	_round_start_button = Button.new()
	_round_start_button.text = "Start Round"
	_round_start_button.custom_minimum_size = Vector2(150, 44)
	_round_start_button.visible = false
	_round_start_button.pressed.connect(_on_round_start_pressed)
	_control_row.add_child(_round_start_button)

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
	_staff_area.custom_minimum_size = Vector2(760, 470)
	_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_area.gui_input.connect(_on_staff_area_gui_input)
	sight_staff_row.add_child(_staff_area)

	_continuous_sight_play_line = ColorRect.new()
	_continuous_sight_play_line.color = Color(0.95, 0.92, 0.74, 0.86)
	_continuous_sight_play_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continuous_sight_play_line.visible = false
	_continuous_sight_play_line.z_index = 240
	_staff_area.add_child(_continuous_sight_play_line)

	_sight_side_controls = VBoxContainer.new()
	_sight_side_controls.add_theme_constant_override("separation", 16)
	_sight_side_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_staff_row.add_child(_sight_side_controls)

	_note_chase_side_panel = PanelContainer.new()
	_note_chase_side_panel.custom_minimum_size = Vector2(240, 170)
	_note_chase_side_panel.visible = false
	_sight_side_controls.add_child(_note_chase_side_panel)
	var nc_side_v := VBoxContainer.new()
	nc_side_v.add_theme_constant_override("separation", 6)
	_note_chase_side_panel.add_child(nc_side_v)
	_note_chase_side_target_box = PanelContainer.new()
	_note_chase_side_target_box.custom_minimum_size = Vector2(224, 30)
	nc_side_v.add_child(_note_chase_side_target_box)
	_note_chase_side_target_label = Label.new()
	_note_chase_side_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_side_target_label.add_theme_font_size_override("font_size", 15)
	_note_chase_side_target_box.add_child(_note_chase_side_target_label)
	_note_chase_side_speed_box = PanelContainer.new()
	_note_chase_side_speed_box.custom_minimum_size = Vector2(224, 28)
	nc_side_v.add_child(_note_chase_side_speed_box)
	_note_chase_side_speed_label = Label.new()
	_note_chase_side_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_side_speed_label.add_theme_font_size_override("font_size", 14)
	_note_chase_side_speed_box.add_child(_note_chase_side_speed_label)
	_note_chase_side_combo_box = PanelContainer.new()
	_note_chase_side_combo_box.custom_minimum_size = Vector2(224, 28)
	nc_side_v.add_child(_note_chase_side_combo_box)
	_note_chase_side_combo_label = Label.new()
	_note_chase_side_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_side_combo_label.add_theme_font_size_override("font_size", 14)
	_note_chase_side_combo_box.add_child(_note_chase_side_combo_label)
	_note_chase_side_shield_box = PanelContainer.new()
	_note_chase_side_shield_box.custom_minimum_size = Vector2(224, 28)
	nc_side_v.add_child(_note_chase_side_shield_box)
	_note_chase_side_shield_label = Label.new()
	_note_chase_side_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note_chase_side_shield_label.add_theme_font_size_override("font_size", 14)
	_note_chase_side_shield_box.add_child(_note_chase_side_shield_label)

	_note_chase_bottom_row = HBoxContainer.new()
	_note_chase_bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_note_chase_bottom_row.add_theme_constant_override("separation", 8)
	_note_chase_bottom_row.visible = false
	_note_chase_bottom_spacer = Control.new()
	_note_chase_bottom_spacer.custom_minimum_size = Vector2(0, 8)
	_note_chase_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_note_chase_bottom_spacer.visible = false
	_sight_container.add_child(_note_chase_bottom_spacer)
	_sight_container.add_child(_note_chase_bottom_row)

	_note_chase_bottom_target_box = PanelContainer.new()
	_note_chase_bottom_target_box.custom_minimum_size = Vector2(170, 38)
	_note_chase_bottom_row.add_child(_note_chase_bottom_target_box)
	_note_chase_bottom_target_label = RichTextLabel.new()
	_note_chase_bottom_target_label.bbcode_enabled = true
	_note_chase_bottom_target_label.fit_content = true
	_note_chase_bottom_target_label.scroll_active = false
	_note_chase_bottom_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_bottom_target_box.add_child(_note_chase_bottom_target_label)

	_note_chase_bottom_speed_box = PanelContainer.new()
	_note_chase_bottom_speed_box.custom_minimum_size = Vector2(170, 38)
	_note_chase_bottom_row.add_child(_note_chase_bottom_speed_box)
	_note_chase_bottom_speed_label = RichTextLabel.new()
	_note_chase_bottom_speed_label.bbcode_enabled = true
	_note_chase_bottom_speed_label.fit_content = true
	_note_chase_bottom_speed_label.scroll_active = false
	_note_chase_bottom_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_bottom_speed_box.add_child(_note_chase_bottom_speed_label)

	_note_chase_bottom_combo_box = PanelContainer.new()
	_note_chase_bottom_combo_box.custom_minimum_size = Vector2(170, 38)
	_note_chase_bottom_row.add_child(_note_chase_bottom_combo_box)
	_note_chase_bottom_combo_label = RichTextLabel.new()
	_note_chase_bottom_combo_label.bbcode_enabled = true
	_note_chase_bottom_combo_label.fit_content = true
	_note_chase_bottom_combo_label.scroll_active = false
	_note_chase_bottom_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_bottom_combo_box.add_child(_note_chase_bottom_combo_label)

	_note_chase_bottom_shield_box = PanelContainer.new()
	_note_chase_bottom_shield_box.custom_minimum_size = Vector2(170, 38)
	_note_chase_bottom_row.add_child(_note_chase_bottom_shield_box)
	_note_chase_bottom_shield_label = RichTextLabel.new()
	_note_chase_bottom_shield_label.bbcode_enabled = true
	_note_chase_bottom_shield_label.fit_content = true
	_note_chase_bottom_shield_label.scroll_active = false
	_note_chase_bottom_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_bottom_shield_box.add_child(_note_chase_bottom_shield_label)

	_staff_clef_label = Label.new()
	_staff_clef_label.text = char(0x1D11E)
	_staff_clef_label.position = Vector2(16, STAFF_TOP_LINE_Y - 36)
	_staff_clef_label.add_theme_font_size_override("font_size", 132)
	_staff_clef_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_staff_area.add_child(_staff_clef_label)

	for _i in 3:
		var ks := Label.new()
		ks.text = ""
		ks.visible = false
		ks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ks.z_index = 126
		ks.size = Vector2(24, 64)
		ks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ks.add_theme_font_size_override("font_size", 58)
		ks.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
		ks.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.65))
		ks.add_theme_constant_override("outline_size", 2)
		_staff_area.add_child(ks)
		_staff_key_sig_labels.append(ks)

	_note_chase_clef_clone = Label.new()
	_note_chase_clef_clone.text = _staff_clef_label.text
	_note_chase_clef_clone.position = _staff_clef_label.position + Vector2(STAFF_LINE_WIDTH, 0)
	_note_chase_clef_clone.add_theme_font_size_override("font_size", 132)
	_note_chase_clef_clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_clef_clone.visible = false
	_staff_area.add_child(_note_chase_clef_clone)

	for i in 5:
		var line := ColorRect.new()
		line.color = Color(1.0, 1.0, 1.0, 0.95)
		line.size = Vector2(STAFF_LINE_WIDTH, 2)
		line.position = Vector2(STAFF_LEFT_X, STAFF_TOP_LINE_Y + (i * STAFF_LINE_GAP_Y))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(line)
		_staff_lines.append(line)

		var line_clone := ColorRect.new()
		line_clone.color = line.color
		line_clone.size = line.size
		line_clone.position = line.position + Vector2(STAFF_LINE_WIDTH + 120.0, 0.0)
		line_clone.visible = false
		line_clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(line_clone)
		_note_chase_staff_clone_lines.append(line_clone)

		var n_lbl := Label.new()
		n_lbl.text = str(5 - i)
		n_lbl.position = Vector2(STAFF_LEFT_X + STAFF_LINE_WIDTH + 10, line.position.y - 10)
		n_lbl.add_theme_font_size_override("font_size", 16)
		n_lbl.visible = false
		n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(n_lbl)
		_staff_line_number_labels.append(n_lbl)

	_note_chase_fail_line = ColorRect.new()
	_note_chase_fail_line.color = Color(1.0, 0.36, 0.46, 0.95)
	_note_chase_fail_line.size = Vector2(3, (STAFF_LINE_GAP_Y * 4.0) + 22.0)
	_note_chase_fail_line.position = Vector2(STAFF_LEFT_X + 8.0, STAFF_TOP_LINE_Y - 10.0)
	_note_chase_fail_line.visible = false
	_note_chase_fail_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_fail_line.z_index = 125
	_staff_area.add_child(_note_chase_fail_line)

	_note_chase_spawn_line = ColorRect.new()
	_note_chase_spawn_line.color = Color(0.35, 0.86, 1.0, 0.92)
	_note_chase_spawn_line.size = Vector2(3, (STAFF_LINE_GAP_Y * 4.0) + 22.0)
	_note_chase_spawn_line.position = Vector2(STAFF_LEFT_X + 250.0, STAFF_TOP_LINE_Y - 10.0)
	_note_chase_spawn_line.visible = false
	_note_chase_spawn_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_spawn_line.z_index = 125
	_staff_area.add_child(_note_chase_spawn_line)

	_note_chase_staff_frame = Panel.new()
	_note_chase_staff_frame.position = Vector2(STAFF_LEFT_X - 22.0, 8.0)
	_note_chase_staff_frame.size = Vector2(448, 252)
	_note_chase_staff_frame.visible = false
	_note_chase_staff_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_staff_frame.z_index = 110
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0.0)
	frame_style.corner_radius_top_left = 10
	frame_style.corner_radius_top_right = 10
	frame_style.corner_radius_bottom_left = 10
	frame_style.corner_radius_bottom_right = 10
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = Color(0.95, 0.84, 0.42, 0.82)
	_note_chase_staff_frame.add_theme_stylebox_override("panel", frame_style)
	_staff_area.add_child(_note_chase_staff_frame)

	_note_chase_overlay = ColorRect.new()
	_note_chase_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_note_chase_overlay.color = Color(0.03, 0.05, 0.04, 0.28)
	_note_chase_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_chase_overlay.visible = false
	_note_chase_overlay.z_index = 180
	_staff_area.add_child(_note_chase_overlay)

	_note_chase_overlay_label = Label.new()
	_note_chase_overlay_label.set_anchors_preset(PRESET_FULL_RECT)
	_note_chase_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_chase_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_chase_overlay_label.add_theme_font_size_override("font_size", 32)
	_note_chase_overlay_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
	_note_chase_overlay_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	_note_chase_overlay_label.add_theme_constant_override("outline_size", 6)
	_note_chase_overlay_label.text = ""
	_note_chase_overlay.add_child(_note_chase_overlay_label)

	_staff_note = Panel.new()
	_staff_note.size = Vector2(40, 28)
	_staff_note.rotation_degrees = -15.0
	_staff_note.z_index = 160
	_staff_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_staff_note.gui_input.connect(_on_staff_note_gui_input)
	_apply_notehead_material(_staff_note, Color(1.0, 1.0, 1.0, 0.98), Color(0.08, 0.08, 0.10, 0.9))
	_staff_area.add_child(_staff_note)

	for i in range(6):
		var pl := ColorRect.new()
		pl.color = Color(1.0, 0.47, 0.73, 1.0)
		pl.size = Vector2(96, 2)
		pl.visible = false
		pl.z_index = 130
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
		extra_note.z_index = 160
		extra_note.visible = false
		extra_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_notehead_material(extra_note, Color(1.0, 1.0, 1.0, 0.98), Color(0.08, 0.08, 0.10, 0.9))
		_staff_area.add_child(extra_note)
		_staff_chord_notes.append(extra_note)

	for _i in 3:
		var acc_lbl := Label.new()
		acc_lbl.text = ""
		acc_lbl.visible = false
		acc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		acc_lbl.z_index = 165
		acc_lbl.size = Vector2(24, 48)
		acc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		acc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		acc_lbl.add_theme_font_size_override("font_size", 40)
		acc_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
		acc_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.7))
		acc_lbl.add_theme_constant_override("outline_size", 2)
		_staff_area.add_child(acc_lbl)
		_staff_chord_accidental_labels.append(acc_lbl)

	var keyboard_spacer := Control.new()
	keyboard_spacer.custom_minimum_size = Vector2(0, 0)
	_sight_container.add_child(keyboard_spacer)

	_sight_keyboard_row = HBoxContainer.new()
	_sight_keyboard_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sight_keyboard_row.add_theme_constant_override("separation", 2)
	_sight_container.add_child(_sight_keyboard_row)

	for note_name in ["C", "D", "E", "F", "G", "A", "B"]:
		var k_btn := Button.new()
		k_btn.text = note_name
		k_btn.custom_minimum_size = Vector2(86, 52)
		k_btn.pressed.connect(_on_sight_key_chosen.bind(note_name))
		_sight_keyboard_row.add_child(k_btn)
		_answer_buttons.append(k_btn)
		_sight_key_buttons[note_name] = k_btn
		_style_key_button(k_btn)
	for acc_note in ["C#", "F#", "G#", "Bb", "Eb", "Ab"]:
		var acc_btn := Button.new()
		acc_btn.text = acc_note
		acc_btn.custom_minimum_size = Vector2(86, 52)
		acc_btn.pressed.connect(_on_sight_key_chosen.bind(acc_note))
		_sight_keyboard_row.add_child(acc_btn)
		_answer_buttons.append(acc_btn)
		_sight_key_buttons[acc_note] = acc_btn
		_style_key_button(acc_btn)

	_continuous_keyboard_row = HBoxContainer.new()
	_continuous_keyboard_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_continuous_keyboard_row.add_theme_constant_override("separation", 1)
	_continuous_keyboard_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continuous_keyboard_row.visible = false
	_sight_container.add_child(_continuous_keyboard_row)
	for octave in range(2, 7):
		for note_name in ["C", "D", "E", "F", "G", "A", "B"]:
			if octave == 6 and note_name != "C":
				continue
			var key_btn := Button.new()
			key_btn.text = "%s%d" % [note_name, octave]
			key_btn.custom_minimum_size = Vector2(66, 132)
			key_btn.size_flags_vertical = Control.SIZE_SHRINK_END
			key_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			key_btn.set_meta("piano_key", true)
			key_btn.set_meta("piano_note", note_name)
			key_btn.set_meta("piano_octave", octave)
			key_btn.pressed.connect(_on_sight_key_chosen.bind(note_name))
			_style_virtual_piano_key_button(key_btn)
			_attach_virtual_black_key(key_btn, note_name, octave)
			_continuous_keyboard_row.add_child(key_btn)
			_continuous_key_buttons.append(key_btn)
			_answer_buttons.append(key_btn)
	_refresh_continuous_keyboard_range()

	var sight_chord_row := HBoxContainer.new()
	sight_chord_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sight_chord_row.add_theme_constant_override("separation", 8)
	_sight_container.add_child(sight_chord_row)
	for i in 3:
		var sc_btn := Button.new()
		sc_btn.text = "?"
		sc_btn.custom_minimum_size = Vector2(208, 56)
		sc_btn.pressed.connect(_on_sight_chord_choice_index.bind(i))
		sight_chord_row.add_child(sc_btn)
		_answer_buttons.append(sc_btn)
		_sight_chord_choice_buttons.append(sc_btn)

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
	_bird_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	_bird_sprite.position = Vector2(24, 110)
	_bird_sprite.pivot_offset = _bird_sprite.custom_minimum_size * 0.5
	_bird_sprite.gui_input.connect(_on_bird_gui_input)
	_sky_area.add_child(_bird_sprite)

	_tutorial_bubble = PanelContainer.new()
	_tutorial_bubble.visible = false
	_tutorial_bubble.position = Vector2(146, 18)
	_tutorial_bubble.custom_minimum_size = Vector2(620, 148)
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
	for i in 3:
		var dot := Panel.new()
		dot.visible = false
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
		dot_style.border_color = Color(0.02, 0.02, 0.02, 0.95)
		dot_style.border_width_left = 2
		dot_style.border_width_top = 2
		dot_style.border_width_right = 2
		dot_style.border_width_bottom = 2
		var rad := 4 + (i * 3)
		dot_style.corner_radius_top_left = rad
		dot_style.corner_radius_top_right = rad
		dot_style.corner_radius_bottom_left = rad
		dot_style.corner_radius_bottom_right = rad
		dot.add_theme_stylebox_override("panel", dot_style)
		dot.size = Vector2(8 + (i * 6), 8 + (i * 6))
		_sky_area.add_child(dot)
		_tutorial_bubble_dots.append(dot)

	_tutorial_bubble_label = Label.new()
	_tutorial_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tutorial_bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_bubble_label.add_theme_font_size_override("font_size", 22)
	_tutorial_bubble_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 1.0))
	_tutorial_bubble_label.position = Vector2(24, 16)
	_tutorial_bubble_label.size = Vector2(568, 114)
	_tutorial_bubble.add_child(_tutorial_bubble_label)

	_tutorial_chicken = TextureRect.new()
	_tutorial_chicken.texture = _load_texture(TUTORIAL_CHICKEN_PATH)
	_tutorial_chicken.visible = false
	_tutorial_chicken.custom_minimum_size = Vector2(152, 152)
	_tutorial_chicken.size = Vector2(152, 152)
	_tutorial_chicken.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tutorial_chicken.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tutorial_chicken.modulate = Color(1.0, 0.90, 0.72, 1.0)
	_tutorial_chicken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_chicken.position = Vector2(18, 44)
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

	_interval_prompt_top_spacer = Control.new()
	_interval_prompt_top_spacer.custom_minimum_size = Vector2(0, 18)
	_interval_prompt_top_spacer.visible = false
	_game_panel.add_child(_interval_prompt_top_spacer)

	_prompt_label = Label.new()
	_prompt_label.text = "Choose the interval number:"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_game_panel.add_child(_prompt_label)

	_interval_choices_top_spacer = Control.new()
	_interval_choices_top_spacer.custom_minimum_size = Vector2(0, 18)
	_interval_choices_top_spacer.visible = false
	_game_panel.add_child(_interval_choices_top_spacer)

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

	_interval_choices_row = HBoxContainer.new()
	_interval_choices_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_interval_choices_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_interval_choices_row.add_theme_constant_override("separation", 8)
	_game_panel.add_child(_interval_choices_row)

	for i in 6:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "?"
		btn.pressed.connect(_on_interval_choice_index.bind(i))
		_interval_choices_row.add_child(btn)
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

	_interval_center_bottom_spacer = Control.new()
	_interval_center_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_interval_center_bottom_spacer.visible = false
	_game_panel.add_child(_interval_center_bottom_spacer)


	_end_button = Button.new()
	_end_button.text = "Back"
	_end_button.custom_minimum_size = Vector2(130, 44)
	_end_button.anchor_left = 1.0
	_end_button.anchor_right = 1.0
	_end_button.anchor_top = 0.0
	_end_button.anchor_bottom = 0.0
	_end_button.offset_left = -176
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
	_restart_button.offset_left = -340
	_restart_button.offset_right = -188
	_restart_button.offset_top = 24
	_restart_button.offset_bottom = 68
	_restart_button.pressed.connect(_on_restart_quiz_pressed)
	add_child(_restart_button)

	_apply_pro_style()
	_style_settings_button(_home_settings_button)
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
	_refresh_note_chase_note_toggles()
	_refresh_note_chase_clef_buttons()
	_setup_home_hints()
	_setup_home_focus_navigation()

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


func _register_home_section_card(section: VBoxContainer) -> void:
	if section == null or _home_panel == null:
		return
	if section.get_parent() != _home_panel:
		return
	var idx := _home_panel.get_children().find(section)
	if idx < 0:
		return
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_top", 14)
	content.add_theme_constant_override("margin_bottom", 14)
	card.add_child(content)
	_home_panel.remove_child(section)
	content.add_child(section)
	_home_panel.add_child(card)
	_home_panel.move_child(card, idx)
	_home_section_cards[section] = card


func _create_home_option_group(parent: VBoxContainer, compact: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("home_option_group", true)
	panel.set_meta("compact_group", compact)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8 if compact else 10)
	margin.add_theme_constant_override("margin_bottom", 8 if compact else 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4 if compact else 8)
	margin.add_child(content)
	parent.add_child(panel)
	_home_option_group_cards.append(panel)
	return content


func _group_has_visible_content(node: Node) -> bool:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if not control.visible:
				continue
			if control.get_child_count() == 0:
				return true
			if _group_has_visible_content(control):
				return true
		elif _group_has_visible_content(child):
			return true
	return false


func _refresh_home_option_group_visibility() -> void:
	for group_card in _home_option_group_cards:
		if group_card == null:
			continue
		var margin := group_card.get_child(0) if group_card.get_child_count() > 0 else null
		var content := margin.get_child(0) if margin != null and margin.get_child_count() > 0 else null
		group_card.visible = content != null and _group_has_visible_content(content)


func _finalize_home_menu_layout() -> void:
	if _home_panel == null:
		return
	_home_panel.add_theme_constant_override("separation", 12)
	if _home_q_row != null:
		_home_q_row.add_theme_constant_override("separation", 10)
	if _home_mode_buttons_row != null:
		_home_mode_buttons_row.add_theme_constant_override("separation", 10)
	if _home_hub_row != null:
		_home_hub_row.add_theme_constant_override("separation", 10)
	for key in _mode_buttons.keys():
		var btn: Button = _mode_buttons[key]
		if btn != null:
			btn.custom_minimum_size = Vector2(154, 38)
	for key in _home_hub_buttons.keys():
		var hbtn: Button = _home_hub_buttons[key]
		if hbtn != null:
			hbtn.custom_minimum_size = Vector2(160, 40)
	_register_home_section_card(_interval_options_box)
	_register_home_section_card(_chord_options_box)
	_register_home_section_card(_sight_options_box)
	_register_home_section_card(_note_chase_options_box)
	_register_home_section_card(_read_options_box)


func _setup_home_hints() -> void:
	if _home_menu_ui == null:
		return
	_home_hint_labels["interval"] = _home_menu_ui.ensure_section_hint(_interval_options_box, "Pick scale degrees for interval drills.", false, false)
	_home_hint_labels["chord"] = _home_menu_ui.ensure_section_hint(_chord_options_box, "Choose chord family and inversion behavior.", false, false)
	_home_hint_labels["sight"] = _home_menu_ui.ensure_section_hint(_sight_options_box, "", false, false)
	_home_hint_labels["chase"] = _home_menu_ui.ensure_section_hint(_note_chase_options_box, "Pick up to 3 target notes for faster focus gains.", false, false)
	_home_hint_labels["read"] = _home_menu_ui.ensure_section_hint(_read_options_box, "Learn flow unlocks guided notation modules.", false, false)
	if _home_hint_labels.has("sight"):
		var sight_hint := _home_hint_labels["sight"] as Label
		if sight_hint != null:
			sight_hint.visible = false
			sight_hint.add_theme_font_size_override("font_size", 16)
	if _home_hint_labels.has("chase"):
		var chase_hint := _home_hint_labels["chase"] as Label
		if chase_hint != null:
			chase_hint.add_theme_font_size_override("font_size", 16)


func _setup_home_focus_navigation() -> void:
	if _home_menu_ui == null:
		return
	var ordered: Array[Control] = []
	for key in ["Practice", "Learn"]:
		if _home_hub_buttons.has(key):
			ordered.append(_home_hub_buttons[key])
	if _home_settings_button != null:
		ordered.append(_home_settings_button)
	for key in ["Ear", "Sight", "Read"]:
		if _mode_buttons.has(key):
			ordered.append(_mode_buttons[key])
	for mode_key in _ear_mode_buttons.keys():
		ordered.append(_ear_mode_buttons[mode_key])
	for key_sig in _sight_mode_buttons.keys():
		ordered.append(_sight_mode_buttons[key_sig])
	if _sight_note_chase_button != null:
		ordered.append(_sight_note_chase_button)
	for clef in _clef_buttons.keys():
		ordered.append(_clef_buttons[clef])
	for chase_clef in _note_chase_clef_buttons.keys():
		ordered.append(_note_chase_clef_buttons[chase_clef])
	for degree in _degree_toggles.keys():
		ordered.append(_degree_toggles[degree])
	for note_key in _note_chase_note_toggles.keys():
		ordered.append(_note_chase_note_toggles[note_key])
	if _home_start_button != null:
		ordered.append(_home_start_button)
	var default_focus: Control = _home_start_button if _home_mode_detail_active else (_home_hub_buttons.get("Practice", null) as Control)
	_home_menu_ui.apply_focus_chain(ordered, default_focus)


func _set_home_section_visible(section: VBoxContainer, visible: bool) -> void:
	if section == null:
		return
	var card_v: Variant = _home_section_cards.get(section, null)
	var card: Control = null
	if card_v != null and card_v is Control:
		card = card_v as Control
	if _home_menu_ui != null:
		_home_menu_ui.animate_section_visibility(section, card, visible)
	else:
		section.visible = visible
		if card != null:
			card.visible = visible


func _apply_pro_style() -> void:
	if ResourceLoader.exists(UI_FONT_PATH, "Font"):
		_ui_font = ResourceLoader.load(UI_FONT_PATH) as Font
	elif ResourceLoader.exists("res://assets/fonts/Righteous-Regular.ttf", "Font"):
		_ui_font = ResourceLoader.load("res://assets/fonts/Righteous-Regular.ttf") as Font
	else:
		_ui_font = null
	if _ui_font == null:
		var sys_font := SystemFont.new()
		sys_font.font_names = PackedStringArray(["Inter", "Segoe UI", "Arial"])
		_ui_font = sys_font
	if _ui_font == null:
		return
	if ResourceLoader.exists(UI_TITLE_FONT_PATH, "Font"):
		_ui_title_font = ResourceLoader.load(UI_TITLE_FONT_PATH) as Font
	elif ResourceLoader.exists("res://assets/fonts/Righteous-Regular.ttf", "Font"):
		_ui_title_font = ResourceLoader.load("res://assets/fonts/Righteous-Regular.ttf") as Font
	else:
		_ui_title_font = null
	if _ui_title_font == null:
		var title_sys_font := SystemFont.new()
		title_sys_font.font_names = PackedStringArray(["Poppins", "Inter", "Segoe UI", "Arial"])
		_ui_title_font = title_sys_font
	var colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {"text_primary": Color(0.98, 0.96, 0.88), "panel_bg": Color(0.10, 0.14, 0.11, 0.74)}

	_title_label.add_theme_font_override("font", _ui_title_font)
	_title_label.add_theme_color_override("font_color", colors["text_primary"])
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	if _home_title_label != null:
		_home_title_label.add_theme_font_override("font", _ui_font)
	if _header_tagline_label != null:
		_header_tagline_label.add_theme_font_override("font", _ui_font)
		_header_tagline_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.95, 0.92))
	if _tutorial_title_label != null:
		_tutorial_title_label.add_theme_font_override("font", _ui_title_font)

	_style_card(_home_card, colors["panel_bg"])
	_style_card(_game_card, Color(colors["panel_bg"].r, colors["panel_bg"].g, colors["panel_bg"].b, 0.70))
	for group_card in _home_option_group_cards:
		_style_home_option_group_card(group_card)
	var header_bg := Color(
		clampf(colors["panel_bg"].r + 0.06, 0.0, 1.0),
		clampf(colors["panel_bg"].g + 0.10, 0.0, 1.0),
		clampf(colors["panel_bg"].b + 0.16, 0.0, 1.0),
		0.70
	)
	_style_header_card(_header_card, header_bg)
	_style_hud_box(_hud_left_box)
	_style_hud_box(_hud_right_box)
	_style_hud_box(_hud_center_box)
	_style_note_chase_metric_box(_note_chase_target_box)
	_style_note_chase_metric_box(_note_chase_speed_box)
	_style_note_chase_metric_box(_note_chase_combo_box)
	_style_note_chase_metric_box(_note_chase_shield_box)
	_style_hud_box(_note_chase_side_panel)
	_style_note_chase_metric_box(_note_chase_side_target_box)
	_style_note_chase_metric_box(_note_chase_side_speed_box)
	_style_note_chase_metric_box(_note_chase_side_combo_box)
	_style_note_chase_metric_box(_note_chase_side_shield_box)
	_style_note_chase_metric_box(_note_chase_bottom_target_box)
	_style_note_chase_metric_box(_note_chase_bottom_speed_box)
	_style_note_chase_metric_box(_note_chase_bottom_combo_box)
	_style_note_chase_metric_box(_note_chase_bottom_shield_box)
	_style_controls_recursive(self)
	_style_include_minor_toggle(_include_minor_toggle != null and _include_minor_toggle.button_pressed)
	_style_descending_intervals_toggle(_descending_intervals_toggle != null and _descending_intervals_toggle.button_pressed)
	_style_harmonic_intervals_toggle(_harmonic_intervals_toggle != null and _harmonic_intervals_toggle.button_pressed)
	_style_menu_toggle(_inversion_toggle, _inversion_toggle != null and _inversion_toggle.button_pressed, false)
	_style_menu_toggle(_adaptive_toggle, _adaptive_toggle != null and _adaptive_toggle.button_pressed, true)
	_style_menu_toggle(_sight_accidentals_toggle, _sight_accidentals_toggle != null and _sight_accidentals_toggle.button_pressed, false)
	for btn in _home_material_buttons:
		_style_material_button(btn)
	if _home_mode_back_button != null:
		_home_mode_back_button.add_theme_font_size_override("font_size", 20)
	_style_home_start_button()
	_refresh_home_section_emphasis()
	for btn_v in _sight_key_buttons.values():
		var kbtn := btn_v as Button
		if kbtn != null:
			_style_key_button(kbtn)
	for cbtn in _sight_chord_choice_buttons:
		if cbtn != null:
			_style_material_button(cbtn)
	if _tutorial_bubble_label != null:
		_tutorial_bubble_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 1.0))
		_tutorial_bubble_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))


func _style_card(card: PanelContainer, color: Color) -> void:
	if card == null:
		return
	var colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {}
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = _home_tokens.RADIUS["card"] if _home_tokens != null else 18
	sb.corner_radius_top_right = _home_tokens.RADIUS["card"] if _home_tokens != null else 18
	sb.corner_radius_bottom_left = _home_tokens.RADIUS["card"] if _home_tokens != null else 18
	sb.corner_radius_bottom_right = _home_tokens.RADIUS["card"] if _home_tokens != null else 18
	sb.border_color = colors.get("panel_border", Color(0.92, 0.84, 0.58, 0.45))
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = _home_tokens.SHADOW["card_size"] if _home_tokens != null else 10
	sb.content_margin_left = 20
	sb.content_margin_top = 16
	sb.content_margin_right = 20
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)


func _style_home_option_group_card(card: PanelContainer) -> void:
	if card == null:
		return
	var compact := bool(card.get_meta("compact_group", false))
	var colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {}
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors.get("panel_bg", Color(0.10, 0.14, 0.11, 0.74)).lightened(0.02)
	sb.bg_color.a = 0.44 if compact else 0.48
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_color = colors.get("panel_border", Color(0.92, 0.84, 0.58, 0.45))
	sb.border_color.a = 0.38 if compact else 0.48
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	sb.shadow_size = 3
	card.add_theme_stylebox_override("panel", sb)


func _style_header_card(card: PanelContainer, color: Color) -> void:
	if card == null:
		return
	var colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {}
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.border_color = colors.get("panel_border", Color(0.92, 0.84, 0.58, 0.45)).lerp(Color(0.78, 0.92, 1.0, 0.70), 0.35)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0.03, 0.08, 0.12, 0.45)
	sb.shadow_size = 10
	sb.content_margin_left = 16
	sb.content_margin_top = 9
	sb.content_margin_right = 16
	sb.content_margin_bottom = 9
	card.add_theme_stylebox_override("panel", sb)


func _style_controls_recursive(node: Node) -> void:
	var colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {}
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			if label.has_meta("settings_section_header"):
				label.add_theme_font_override("font", _ui_title_font if _ui_title_font != null else _ui_font)
				label.add_theme_font_size_override("font_size", 22)
				label.add_theme_color_override("font_color", colors.get("focus_border", Color(0.26, 0.93, 0.98, 0.96)))
				label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.45))
				label.add_theme_constant_override("outline_size", 1)
			elif label.has_meta("settings_small_label"):
				label.add_theme_font_override("font", _ui_font)
				label.add_theme_font_size_override("font_size", 14)
				label.add_theme_color_override("font_color", colors.get("text_muted", Color(0.92, 0.90, 0.82, 0.86)))
			else:
				label.add_theme_font_override("font", _ui_font)
				label.add_theme_color_override("font_color", colors.get("text_primary", Color(0.98, 0.96, 0.88)))
		elif child is CheckButton:
			var sw := child as CheckButton
			sw.add_theme_font_override("font", _ui_font)
			sw.add_theme_font_size_override("font_size", 17)
			sw.add_theme_color_override("font_color", colors.get("text_primary", Color(0.98, 0.96, 0.88)))
		elif child is Button:
			var btn := child as Button
			if btn.has_meta("piano_black_key"):
				_style_virtual_black_key_button(btn)
				continue
			if btn.has_meta("piano_key"):
				if _ui_font != null:
					btn.add_theme_font_override("font", _ui_font)
				_style_virtual_piano_key_button(btn)
				continue
			btn.add_theme_font_override("font", _ui_font)
			btn.add_theme_font_size_override("font_size", 21)
			btn.add_theme_color_override("font_color", Color(0.20, 0.14, 0.06))
			btn.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.04))
			btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
			_style_button(btn)
			var click_call := Callable(self, "_on_any_ui_button_pressed")
			if not btn.pressed.is_connected(click_call):
				btn.pressed.connect(click_call)
		elif child is CheckBox:
			var cb := child as CheckBox
			cb.add_theme_font_override("font", _ui_font)
			cb.add_theme_font_size_override("font_size", 18)
			cb.add_theme_color_override("font_color", colors.get("text_primary", Color(0.98, 0.96, 0.88)))
		elif child is SpinBox:
			var spin := child as SpinBox
			spin.add_theme_font_override("font", _ui_font)
			spin.add_theme_font_size_override("font_size", 18)
		elif child is OptionButton:
			var option := child as OptionButton
			option.add_theme_font_override("font", _ui_font)
			option.add_theme_font_size_override("font_size", 18)
		elif child is LineEdit:
			var line := child as LineEdit
			line.add_theme_font_override("font", _ui_font)
			line.add_theme_font_size_override("font_size", 18)
		elif child is RichTextLabel:
			var rich := child as RichTextLabel
			rich.add_theme_font_override("normal_font", _ui_font)
			rich.add_theme_font_override("bold_font", _ui_font)
			rich.add_theme_font_override("italics_font", _ui_font)
		_style_controls_recursive(child)


func _theme_button_palette() -> Dictionary:
	var id := _ui_theme_id
	if _home_tokens != null:
		id = _home_tokens.theme_id()
	match id:
		"azure_cascade":
			return {
				"base_bg": Color(0.44, 0.67, 0.88, 0.96),
				"base_hover": Color(0.54, 0.76, 0.95, 1.0),
				"base_pressed": Color(0.32, 0.56, 0.78, 1.0),
				"base_border": Color(0.14, 0.32, 0.50, 0.72),
				"base_text": Color(0.08, 0.16, 0.26, 1.0),
				"selected_bg": Color(0.12, 0.34, 0.56, 0.98),
				"selected_hover": Color(0.16, 0.40, 0.64, 0.99),
				"selected_pressed": Color(0.08, 0.26, 0.44, 1.0),
				"selected_text": Color(0.92, 0.98, 1.0, 1.0),
				"settings_bg": Color(0.20, 0.56, 0.78, 0.98),
				"settings_hover": Color(0.28, 0.64, 0.86, 1.0),
				"settings_pressed": Color(0.14, 0.46, 0.66, 1.0),
				"settings_border": Color(0.10, 0.30, 0.44, 0.98),
				"settings_text": Color(0.92, 0.98, 1.0, 1.0),
				"start_bg": Color(0.30, 0.70, 0.92, 0.98),
				"start_hover": Color(0.40, 0.80, 1.0, 1.0),
				"start_pressed": Color(0.24, 0.58, 0.80, 1.0),
				"start_border": Color(0.10, 0.34, 0.52, 0.95),
				"start_text": Color(0.05, 0.14, 0.24, 1.0),
				"toggle_on_bg": Color(0.13, 0.36, 0.58, 0.98),
				"toggle_on_border": Color(0.44, 0.90, 1.0, 1.0),
				"toggle_off_bg": Color(0.44, 0.67, 0.88, 0.96),
				"toggle_off_border": Color(0.14, 0.32, 0.50, 0.70),
				"toggle_on_text": Color(0.93, 0.99, 1.0, 1.0),
				"toggle_off_text": Color(0.08, 0.16, 0.26, 1.0)
			}
		"slate_foundry":
			return {
				"base_bg": Color(0.62, 0.66, 0.72, 0.96),
				"base_hover": Color(0.71, 0.75, 0.80, 1.0),
				"base_pressed": Color(0.48, 0.52, 0.58, 1.0),
				"base_border": Color(0.20, 0.22, 0.26, 0.75),
				"base_text": Color(0.12, 0.13, 0.16, 1.0),
				"selected_bg": Color(0.24, 0.27, 0.33, 0.98),
				"selected_hover": Color(0.30, 0.34, 0.40, 0.99),
				"selected_pressed": Color(0.18, 0.21, 0.26, 1.0),
				"selected_text": Color(0.95, 0.96, 0.98, 1.0),
				"settings_bg": Color(0.40, 0.48, 0.58, 0.98),
				"settings_hover": Color(0.48, 0.56, 0.66, 1.0),
				"settings_pressed": Color(0.30, 0.38, 0.48, 1.0),
				"settings_border": Color(0.16, 0.20, 0.26, 0.98),
				"settings_text": Color(0.94, 0.96, 1.0, 1.0),
				"start_bg": Color(0.52, 0.58, 0.64, 0.98),
				"start_hover": Color(0.62, 0.68, 0.74, 1.0),
				"start_pressed": Color(0.42, 0.48, 0.54, 1.0),
				"start_border": Color(0.18, 0.22, 0.28, 0.95),
				"start_text": Color(0.10, 0.11, 0.14, 1.0),
				"toggle_on_bg": Color(0.28, 0.32, 0.38, 0.98),
				"toggle_on_border": Color(0.68, 0.84, 0.95, 1.0),
				"toggle_off_bg": Color(0.62, 0.66, 0.72, 0.96),
				"toggle_off_border": Color(0.20, 0.22, 0.26, 0.70),
				"toggle_on_text": Color(0.95, 0.96, 0.98, 1.0),
				"toggle_off_text": Color(0.12, 0.13, 0.16, 1.0)
			}
		"crimson_nocturne":
			return {
				"base_bg": Color(0.86, 0.44, 0.38, 0.96),
				"base_hover": Color(0.94, 0.52, 0.46, 1.0),
				"base_pressed": Color(0.70, 0.30, 0.28, 1.0),
				"base_border": Color(0.42, 0.14, 0.14, 0.76),
				"base_text": Color(0.26, 0.06, 0.07, 1.0),
				"selected_bg": Color(0.45, 0.12, 0.14, 0.98),
				"selected_hover": Color(0.54, 0.16, 0.18, 0.99),
				"selected_pressed": Color(0.34, 0.08, 0.10, 1.0),
				"selected_text": Color(1.0, 0.93, 0.90, 1.0),
				"settings_bg": Color(0.76, 0.24, 0.24, 0.98),
				"settings_hover": Color(0.86, 0.30, 0.30, 1.0),
				"settings_pressed": Color(0.62, 0.18, 0.18, 1.0),
				"settings_border": Color(0.38, 0.10, 0.10, 0.98),
				"settings_text": Color(1.0, 0.92, 0.90, 1.0),
				"start_bg": Color(0.90, 0.34, 0.26, 0.98),
				"start_hover": Color(1.0, 0.42, 0.32, 1.0),
				"start_pressed": Color(0.76, 0.24, 0.20, 1.0),
				"start_border": Color(0.44, 0.12, 0.10, 0.95),
				"start_text": Color(0.24, 0.05, 0.05, 1.0),
				"toggle_on_bg": Color(0.52, 0.14, 0.16, 0.98),
				"toggle_on_border": Color(1.0, 0.58, 0.45, 1.0),
				"toggle_off_bg": Color(0.86, 0.44, 0.38, 0.96),
				"toggle_off_border": Color(0.42, 0.14, 0.14, 0.70),
				"toggle_on_text": Color(1.0, 0.93, 0.90, 1.0),
				"toggle_off_text": Color(0.26, 0.06, 0.07, 1.0)
			}
		"rose_velvet":
			return {
				"base_bg": Color(0.90, 0.60, 0.76, 0.96),
				"base_hover": Color(0.96, 0.68, 0.83, 1.0),
				"base_pressed": Color(0.76, 0.46, 0.62, 1.0),
				"base_border": Color(0.44, 0.20, 0.34, 0.74),
				"base_text": Color(0.24, 0.08, 0.18, 1.0),
				"selected_bg": Color(0.50, 0.20, 0.38, 0.98),
				"selected_hover": Color(0.60, 0.26, 0.46, 0.99),
				"selected_pressed": Color(0.40, 0.14, 0.30, 1.0),
				"selected_text": Color(1.0, 0.94, 0.98, 1.0),
				"settings_bg": Color(0.78, 0.36, 0.60, 0.98),
				"settings_hover": Color(0.86, 0.44, 0.68, 1.0),
				"settings_pressed": Color(0.64, 0.26, 0.50, 1.0),
				"settings_border": Color(0.38, 0.14, 0.30, 0.98),
				"settings_text": Color(1.0, 0.94, 0.98, 1.0),
				"start_bg": Color(0.94, 0.52, 0.74, 0.98),
				"start_hover": Color(1.0, 0.62, 0.82, 1.0),
				"start_pressed": Color(0.80, 0.40, 0.62, 1.0),
				"start_border": Color(0.44, 0.16, 0.34, 0.95),
				"start_text": Color(0.24, 0.08, 0.18, 1.0),
				"toggle_on_bg": Color(0.56, 0.22, 0.42, 0.98),
				"toggle_on_border": Color(1.0, 0.66, 0.86, 1.0),
				"toggle_off_bg": Color(0.90, 0.60, 0.76, 0.96),
				"toggle_off_border": Color(0.44, 0.20, 0.34, 0.70),
				"toggle_on_text": Color(1.0, 0.94, 0.98, 1.0),
				"toggle_off_text": Color(0.24, 0.08, 0.18, 1.0)
			}
		_:
			return {
				"base_bg": Color(0.84, 0.74, 0.42, 0.96),
				"base_hover": Color(0.93, 0.82, 0.46, 1.0),
				"base_pressed": Color(0.73, 0.61, 0.33, 1.0),
				"base_border": Color(0.30, 0.23, 0.10, 0.68),
				"base_text": Color(0.20, 0.14, 0.06, 1.0),
				"selected_bg": Color(0.35, 0.27, 0.09, 0.98),
				"selected_hover": Color(0.43, 0.33, 0.11, 0.99),
				"selected_pressed": Color(0.27, 0.20, 0.07, 1.0),
				"selected_text": Color(1.0, 0.97, 0.86, 1.0),
				"settings_bg": Color(0.18, 0.46, 0.62, 0.98),
				"settings_hover": Color(0.23, 0.54, 0.72, 1.0),
				"settings_pressed": Color(0.14, 0.36, 0.50, 1.0),
				"settings_border": Color(0.08, 0.24, 0.34, 0.98),
				"settings_text": Color(0.93, 0.98, 1.0, 1.0),
				"start_bg": Color(0.92, 0.67, 0.20, 0.98),
				"start_hover": Color(0.98, 0.74, 0.27, 1.0),
				"start_pressed": Color(0.82, 0.58, 0.15, 1.0),
				"start_border": Color(0.46, 0.30, 0.06, 0.95),
				"start_text": Color(0.18, 0.11, 0.03, 1.0),
				"toggle_on_bg": Color(0.35, 0.27, 0.09, 0.98),
				"toggle_on_border": Color(0.95, 0.76, 0.31, 1.0),
				"toggle_off_bg": Color(0.84, 0.74, 0.42, 0.96),
				"toggle_off_border": Color(0.30, 0.23, 0.10, 0.68),
				"toggle_on_text": Color(1.0, 0.97, 0.86, 1.0),
				"toggle_off_text": Color(0.20, 0.14, 0.06, 1.0)
			}


func _pick_readable_text_color(bg: Color) -> Color:
	var light := Color(0.96, 0.97, 0.98, 1.0)
	var dark := Color(0.08, 0.09, 0.12, 1.0)
	var light_delta := absf(light.get_luminance() - bg.get_luminance())
	var dark_delta := absf(dark.get_luminance() - bg.get_luminance())
	return light if light_delta >= dark_delta else dark


func _style_button(btn: Button) -> void:
	var pal := _theme_button_palette()
	var base_text: Color = _pick_readable_text_color(pal["base_bg"])
	var normal := StyleBoxFlat.new()
	normal.bg_color = pal["base_bg"]
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_color = pal["base_border"]
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	normal.shadow_size = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = pal["base_hover"]
	hover.shadow_size = 6
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = pal["base_pressed"]
	pressed.shadow_size = 2
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", base_text)
	btn.add_theme_color_override("font_hover_color", _pick_readable_text_color(pal["base_hover"]))
	btn.add_theme_color_override("font_pressed_color", _pick_readable_text_color(pal["base_pressed"]))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))
	btn.add_theme_constant_override("outline_size", 1)


func _style_settings_button(btn: Button) -> void:
	if btn == null:
		return
	var pal := _theme_button_palette()
	var settings_text := _pick_readable_text_color(pal["settings_bg"])
	var normal := StyleBoxFlat.new()
	normal.bg_color = pal["settings_bg"]
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_color = pal["settings_border"]
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.shadow_color = Color(0.02, 0.08, 0.12, 0.36)
	normal.shadow_size = 5
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = pal["settings_hover"]
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = pal["settings_pressed"]
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", settings_text)
	btn.add_theme_color_override("font_hover_color", _pick_readable_text_color(pal["settings_hover"]))
	btn.add_theme_color_override("font_pressed_color", _pick_readable_text_color(pal["settings_pressed"]))
	btn.add_theme_constant_override("outline_size", 0)


func _style_interval_option_toggle(btn: Button, enabled: bool, on_text: String, off_text: String, is_disabled: bool = false) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	if is_disabled:
		normal.bg_color = Color(0.25, 0.25, 0.25, 0.58)
		normal.border_color = Color(0.12, 0.12, 0.12, 0.55)
	elif enabled:
		normal.bg_color = Color(0.52, 0.84, 0.62, 0.98)
		normal.border_color = Color(0.16, 0.40, 0.22, 0.90)
	else:
		normal.bg_color = Color(0.30, 0.30, 0.30, 0.92)
		normal.border_color = Color(0.12, 0.12, 0.12, 0.85)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08)
	btn.add_theme_stylebox_override("pressed", pressed)
	var on_color := Color(0.08, 0.20, 0.12, 1.0)
	var off_color := Color(0.98, 0.98, 0.98, 1.0)
	var text_color := off_color if (is_disabled or not enabled) else on_color
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_font_size_override("font_size", 20)
	btn.text = on_text if enabled else off_text
	btn.disabled = is_disabled


func _style_include_minor_toggle(enabled: bool) -> void:
	_style_interval_option_toggle(_include_minor_toggle, enabled, "Minor Intervals On", "Minor Intervals Off", false)


func _style_descending_intervals_toggle(enabled: bool) -> void:
	var disabled := _use_harmonic_intervals and not enabled
	_style_interval_option_toggle(_descending_intervals_toggle, enabled, "Descending Intervals On", "Descending Intervals Off", disabled)


func _style_harmonic_intervals_toggle(enabled: bool) -> void:
	_style_interval_option_toggle(_harmonic_intervals_toggle, enabled, "Harmonic Intervals On", "Harmonic Intervals Off", false)


func _style_menu_toggle(toggle: BaseButton, enabled: bool, is_disabled: bool) -> void:
	if toggle == null:
		return
	var pal := _theme_button_palette()
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	normal.shadow_size = 5
	if is_disabled:
		normal.bg_color = Color(0.30, 0.30, 0.30, 0.70)
		normal.border_color = Color(0.52, 0.52, 0.52, 0.75)
	elif enabled:
		normal.bg_color = pal["toggle_on_bg"]
		normal.border_color = pal["toggle_on_border"]
	else:
		normal.bg_color = pal["toggle_off_bg"]
		normal.border_color = pal["toggle_off_border"]
	toggle.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	toggle.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08)
	toggle.add_theme_stylebox_override("pressed", pressed)
	var on_text: Color = _pick_readable_text_color(pal["toggle_on_bg"])
	var off_text: Color = _pick_readable_text_color(pal["toggle_off_bg"])
	var disabled_text := Color(0.84, 0.84, 0.84, 0.78)
	var font_color := disabled_text if is_disabled else (on_text if enabled else off_text)
	toggle.add_theme_color_override("font_color", font_color)
	toggle.add_theme_color_override("font_hover_color", font_color)
	toggle.add_theme_color_override("font_pressed_color", font_color)
	toggle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.45))
	toggle.add_theme_constant_override("outline_size", 1 if not enabled else 2)
	if not toggle.has_meta("base_text"):
		toggle.set_meta("base_text", toggle.text)
	var base_v: Variant = toggle.get_meta("base_text")
	var base_text := str(base_v)
	if is_disabled:
		toggle.text = base_text + " (Locked)"
	else:
		toggle.text = (char(0x2713) + " " if enabled else "") + base_text


func _style_material_button(btn: Button) -> void:
	if btn == null:
		return
	if not btn.has_meta("base_text"):
		btn.set_meta("base_text", btn.text)
	var pal := _theme_button_palette()
	var normal := StyleBoxFlat.new()
	normal.bg_color = pal["base_bg"]
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 5
	normal.border_color = pal["base_border"]
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = pal["base_hover"]
	hover.shadow_size = 7
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = pal["base_pressed"]
	pressed.shadow_size = 3
	btn.add_theme_stylebox_override("pressed", pressed)

	var base_text: Color = _pick_readable_text_color(pal["base_bg"])
	btn.add_theme_color_override("font_color", base_text)
	btn.add_theme_color_override("font_hover_color", base_text.darkened(0.12))
	btn.add_theme_color_override("font_pressed_color", base_text.darkened(0.20))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_font_size_override("font_size", 16)


func _style_home_start_button() -> void:
	if _home_start_button == null:
		return
	var pal := _theme_button_palette()
	var start_text: Color = _pick_readable_text_color(pal["start_bg"])
	var normal := StyleBoxFlat.new()
	normal.bg_color = pal["start_bg"]
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.border_color = pal["start_border"]
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.shadow_color = Color(0.12, 0.08, 0.02, 0.55)
	normal.shadow_size = 9
	_home_start_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = pal["start_hover"]
	hover.shadow_size = 11
	_home_start_button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = pal["start_pressed"]
	pressed.shadow_size = 6
	_home_start_button.add_theme_stylebox_override("pressed", pressed)
	_home_start_button.add_theme_color_override("font_color", start_text)
	_home_start_button.add_theme_color_override("font_hover_color", _pick_readable_text_color(pal["start_hover"]))
	_home_start_button.add_theme_color_override("font_pressed_color", _pick_readable_text_color(pal["start_pressed"]))
	_home_start_button.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.70, 0.40))
	_home_start_button.add_theme_constant_override("outline_size", 1)
	_home_start_button.add_theme_font_size_override("font_size", 18)


func _home_button_base_text(btn: Button) -> String:
	if btn == null:
		return ""
	if not btn.has_meta("base_text"):
		btn.set_meta("base_text", btn.text)
	var base_v: Variant = btn.get_meta("base_text")
	if base_v is String:
		return base_v
	return btn.text


func _set_home_button_label_state(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var base_text := _home_button_base_text(btn)
	if selected:
		if base_text.length() <= 2:
			btn.text = "%s ●" % base_text
		else:
			btn.text = "✓ " + base_text
	else:
		btn.text = base_text


func _animate_home_button_selection(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var had_state := btn.has_meta("was_selected")
	var previous := bool(btn.get_meta("was_selected", false))
	btn.set_meta("was_selected", selected)
	if not had_state or previous == selected:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	btn.scale = Vector2.ONE
	if selected:
		tw.tween_property(btn, "scale", Vector2(1.07, 1.07), 0.08)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
	else:
		tw.tween_property(btn, "scale", Vector2(0.98, 0.98), 0.06)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)


func _set_home_selection_state(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var pal := _theme_button_palette()
	_set_home_button_label_state(btn, selected)
	_animate_home_button_selection(btn, selected)
	var token_colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {}
	var selected_border: Color = token_colors.get("focus_border", Color(0.95, 0.76, 0.31, 1.0))
	var selected_bg: Color = pal["selected_bg"]
	var contrast_delta := absf(selected_border.get_luminance() - selected_bg.get_luminance())
	if contrast_delta < 0.42:
		var against_light := absf(0.96 - selected_bg.get_luminance())
		var against_dark := absf(0.06 - selected_bg.get_luminance())
		selected_border = Color(0.96, 0.96, 0.96, 1.0) if against_light > against_dark else Color(0.06, 0.06, 0.06, 1.0)
	var normal := btn.get_theme_stylebox("normal")
	if normal is StyleBoxFlat:
		var sb := normal as StyleBoxFlat
		if selected:
			sb.bg_color = pal["selected_bg"]
			sb.border_color = selected_border
			sb.border_width_left = 4
			sb.border_width_top = 4
			sb.border_width_right = 4
			sb.border_width_bottom = 4
			sb.shadow_color = Color(0.20, 0.14, 0.04, 0.92)
			sb.shadow_size = 9
		else:
			sb.bg_color = pal["base_bg"]
			sb.border_color = pal["base_border"]
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			sb.shadow_size = 5
	var hover := btn.get_theme_stylebox("hover")
	if hover is StyleBoxFlat:
		var hb := hover as StyleBoxFlat
		if selected:
			hb.bg_color = pal["selected_hover"]
			hb.border_color = selected_border
			hb.border_width_left = 4
			hb.border_width_top = 4
			hb.border_width_right = 4
			hb.border_width_bottom = 4
			hb.shadow_color = Color(0.20, 0.14, 0.04, 0.92)
			hb.shadow_size = 10
		else:
			hb.bg_color = pal["base_hover"]
			hb.border_color = pal["base_border"]
			hb.border_width_left = 2
			hb.border_width_top = 2
			hb.border_width_right = 2
			hb.border_width_bottom = 2
			hb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			hb.shadow_size = 7
	var pressed := btn.get_theme_stylebox("pressed")
	if pressed is StyleBoxFlat:
		var pb := pressed as StyleBoxFlat
		if selected:
			pb.bg_color = pal["selected_pressed"]
			pb.border_color = selected_border
			pb.border_width_left = 4
			pb.border_width_top = 4
			pb.border_width_right = 4
			pb.border_width_bottom = 4
			pb.shadow_color = Color(0.20, 0.14, 0.04, 0.92)
			pb.shadow_size = 6
		else:
			pb.bg_color = pal["base_pressed"]
			pb.border_color = pal["base_border"]
			pb.border_width_left = 2
			pb.border_width_top = 2
			pb.border_width_right = 2
			pb.border_width_bottom = 2
			pb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			pb.shadow_size = 3
	if selected:
		btn.add_theme_color_override("font_color", _pick_readable_text_color(pal["selected_bg"]))
		btn.add_theme_color_override("font_hover_color", _pick_readable_text_color(pal["selected_hover"]))
		btn.add_theme_color_override("font_pressed_color", _pick_readable_text_color(pal["selected_pressed"]))
		btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
		btn.add_theme_constant_override("outline_size", 2)
	else:
		var base_text: Color = _pick_readable_text_color(pal["base_bg"])
		btn.add_theme_color_override("font_color", base_text)
		btn.add_theme_color_override("font_hover_color", _pick_readable_text_color(pal["base_hover"]))
		btn.add_theme_color_override("font_pressed_color", _pick_readable_text_color(pal["base_pressed"]))
		btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))
		btn.add_theme_constant_override("outline_size", 1)
	btn.modulate = Color(1, 1, 1, 0.58) if btn.disabled else Color(1, 1, 1, 1)


func _set_home_section_header_state(section: VBoxContainer, active: bool) -> void:
	if section == null:
		return
	for child in section.get_children():
		if child is Label:
			var lbl := child as Label
			if active:
				lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56, 1.0))
				lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.11, 0.02, 0.88))
				lbl.add_theme_constant_override("outline_size", 2)
				lbl.add_theme_font_size_override("font_size", 22)
			else:
				lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.80, 0.90))
				lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.45))
				lbl.add_theme_constant_override("outline_size", 1)
				lbl.add_theme_font_size_override("font_size", 19)
			break


func _set_home_section_card_state(section: VBoxContainer, active: bool) -> void:
	if section == null:
		return
	var card_v: Variant = _home_section_cards.get(section, null)
	if card_v == null or not (card_v is PanelContainer):
		return
	var card := card_v as PanelContainer
	if _home_menu_ui != null:
		card.add_theme_stylebox_override("panel", _home_menu_ui.section_card_style(active, false))


func _refresh_home_section_emphasis() -> void:
	var is_ear := _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD
	_set_home_section_header_state(_interval_options_box, is_ear and _selected_mode == MODE_INTERVAL)
	_set_home_section_header_state(_chord_options_box, is_ear and _selected_mode == MODE_CHORD)
	_set_home_section_header_state(_sight_options_box, _selected_mode == MODE_SIGHT)
	_set_home_section_header_state(_note_chase_options_box, _selected_mode == MODE_NOTE_CHASE)
	_set_home_section_header_state(_read_options_box, _selected_mode == MODE_READ)
	_set_home_section_card_state(_interval_options_box, is_ear and _selected_mode == MODE_INTERVAL)
	_set_home_section_card_state(_chord_options_box, is_ear and _selected_mode == MODE_CHORD)
	_set_home_section_card_state(_sight_options_box, _selected_mode == MODE_SIGHT)
	_set_home_section_card_state(_note_chase_options_box, _selected_mode == MODE_NOTE_CHASE)
	_set_home_section_card_state(_read_options_box, _selected_mode == MODE_READ)


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


func _interval_id_for_semitones(semitones: int) -> String:
	match semitones:
		0:
			return "P1"
		1:
			return "m2"
		2:
			return "M2"
		3:
			return "m3"
		4:
			return "M3"
		5:
			return "P4"
		6:
			return "TT"
		7:
			return "P5"
		8:
			return "m6"
		9:
			return "M6"
		10:
			return "m7"
		11:
			return "M7"
		12:
			return "P8"
		_:
			return "P1"


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


func _style_note_chase_metric_box(box: PanelContainer) -> void:
	if box == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.07, 0.72)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_color = Color(0.96, 0.86, 0.40, 0.88)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)


func _set_note_chase_metric_highlight(box: PanelContainer, active: bool) -> void:
	if box == null:
		return
	var sb := box.get_theme_stylebox("panel")
	if not (sb is StyleBoxFlat):
		return
	var s := (sb as StyleBoxFlat)
	if active:
		s.border_color = Color(0.48, 0.90, 1.0, 0.98)
		s.bg_color = Color(0.08, 0.16, 0.18, 0.82)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
	else:
		s.border_color = Color(0.96, 0.86, 0.40, 0.88)
		s.bg_color = Color(0.05, 0.07, 0.07, 0.72)
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 1
		s.border_width_bottom = 1


func _set_note_chase_top_text_only(enabled: bool) -> void:
	var boxes: Array[PanelContainer] = [_hud_left_box, _hud_center_box, _hud_right_box]
	for b in boxes:
		if b == null:
			continue
		if enabled:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.0)
			sb.border_width_left = 0
			sb.border_width_top = 0
			sb.border_width_right = 0
			sb.border_width_bottom = 0
			sb.content_margin_left = 0
			sb.content_margin_right = 0
			sb.content_margin_top = 0
			sb.content_margin_bottom = 0
			b.add_theme_stylebox_override("panel", sb)
		else:
			_style_hud_box(b)


func _set_note_chase_bottom_metric(label: RichTextLabel, icon_text: String, value_text: String) -> void:
	if label == null:
		return
	label.clear()
	label.append_text("[color=#F5DA70]%s[/color] [b][color=#6FEAFF]%s[/color][/b]" % [icon_text, value_text])


func _result_box_show(title_text: String, subtitle_text: String) -> void:
	_result_title.text = title_text
	_result_subtitle.text = subtitle_text
	_result_overlay.visible = true


func _result_box_hide() -> void:
	if _result_overlay != null:
		_result_overlay.visible = false


func _post_layout_init() -> void:
	if _bird_sprite != null:
		_bird_home_global_position = _compute_bird_home_global_position()
		_bird_home_ready = true
	_reset_bird_position()
	_start_bird_idle_anim()


func _on_any_ui_button_pressed() -> void:
	if _selected_mode == MODE_SIGHT and _quiz_active and _accepting_answer:
		return
	_play_ui_click_sfx()


func _on_bird_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _selected_mode == MODE_READ:
		return
	if _chicken_hint_busy:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < _chicken_hint_cooldown_until:
		if _status_label != null:
			_status_label.text = "Chicken is thinking..."
		return
	_play_ui_click_sfx()
	call_deferred("_request_chicken_hint")


func _cancel_chicken_turn_hint_cycle(hide_bubble: bool) -> void:
	_chicken_hint_turn_token += 1
	_chicken_hint_clicks_this_turn = 0
	_chicken_hint_locked_this_turn = false
	_chicken_prompt_ready_at = 0.0
	if hide_bubble:
		_hide_chicken_bubble()


func _show_chicken_prompt_line() -> void:
	if _chicken_hint_locked_this_turn:
		return
	var line := _pick_rotating_line(CHICKEN_HINT_PROMPT_LINES, _chicken_last_prompt_line)
	_chicken_last_prompt_line = line
	_set_chicken_bubble_text(line)


func _start_chicken_turn_hint_cycle() -> void:
	_cancel_chicken_turn_hint_cycle(false)
	_chicken_last_hint_by_topic.clear()
	_chicken_used_hints_by_topic.clear()
	if _selected_mode == MODE_READ or not _quiz_active:
		_hide_chicken_bubble()
		return
	_hide_chicken_bubble()
	_chicken_prompt_ready_at = (float(Time.get_ticks_msec()) / 1000.0) + 3.0
	var token := _chicken_hint_turn_token
	call_deferred("_run_chicken_nudge_cycle", token)


func _run_chicken_nudge_cycle(token: int) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var first_wait := maxf(0.0, _chicken_prompt_ready_at - now)
	if first_wait > 0.01:
		await get_tree().create_timer(first_wait).timeout
	if token != _chicken_hint_turn_token:
		return
	if _selected_mode == MODE_READ or not _quiz_active or not _accepting_answer:
		return
	if not _chicken_hint_locked_this_turn:
		_show_chicken_prompt_line()
	while true:
		if token != _chicken_hint_turn_token:
			return
		if _selected_mode == MODE_READ or not _quiz_active or not _accepting_answer:
			return
		await get_tree().create_timer(_rng.randf_range(3.8, 5.6)).timeout
		if token != _chicken_hint_turn_token:
			return
		if _selected_mode == MODE_READ or not _quiz_active or not _accepting_answer:
			return
		if not _chicken_hint_locked_this_turn:
			_show_chicken_prompt_line()


func _set_chicken_bubble_text(text: String) -> void:
	if _tutorial_bubble == null or _tutorial_bubble_label == null or _tutorial_bubble_tail == null:
		return
	if _selected_mode == MODE_READ:
		return
	var vp := get_viewport_rect().size
	var target_w := clampf(vp.x * 0.40, 260.0, 420.0)
	var target_h := clampf(vp.y * 0.12, 84.0, 118.0)
	_tutorial_bubble.custom_minimum_size = Vector2(target_w, target_h)
	var bubble_font := int(roundf(clampf(vp.y * 0.024, 16.0, 20.0)))
	_tutorial_bubble_label.add_theme_font_size_override("font_size", bubble_font)
	_tutorial_bubble_label.position = Vector2(18, 12)
	_tutorial_bubble_label.size = Vector2(target_w - 32.0, target_h - 24.0)
	_tutorial_bubble_label.text = text
	_tutorial_bubble.visible = true
	# In gameplay hint mode, use thought dots only (no square-ish tail).
	_tutorial_bubble_tail.visible = false
	for dot in _tutorial_bubble_dots:
		if dot != null:
			dot.visible = true
	_tutorial_bubble.move_to_front()
	_tutorial_bubble_tail.move_to_front()
	if _bird_sprite != null:
		_bird_sprite.move_to_front()
	for dot2 in _tutorial_bubble_dots:
		if dot2 != null:
			dot2.move_to_front()
	_update_chicken_bubble_position()


func _hide_chicken_bubble() -> void:
	if _tutorial_bubble != null:
		_tutorial_bubble.visible = false
	if _tutorial_bubble_tail != null:
		_tutorial_bubble_tail.visible = false
	for dot in _tutorial_bubble_dots:
		if dot != null:
			dot.visible = false


func _lock_chicken_hint_line(text: String) -> void:
	_chicken_hint_locked_this_turn = true
	_set_chicken_bubble_text(text)


func _on_player_answer_committed() -> void:
	_cancel_chicken_turn_hint_cycle(true)


func _update_chicken_bubble_position() -> void:
	if _selected_mode == MODE_READ:
		return
	if _tutorial_bubble == null or _tutorial_bubble_tail == null or _sky_area == null or _bird_sprite == null:
		return
	if not _tutorial_bubble.visible:
		return
	var bubble_size := _tutorial_bubble.size
	if bubble_size.x <= 1.0 or bubble_size.y <= 1.0:
		bubble_size = _tutorial_bubble.get_combined_minimum_size()
	var pad := 8.0
	var bounds_left := 0.0
	var bounds_top := 0.0
	var bounds_right := _sky_area.size.x
	var bounds_bottom := _sky_area.size.y
	if _game_panel != null:
		bounds_left = _game_panel.global_position.x - _sky_area.global_position.x
		bounds_top = _game_panel.global_position.y - _sky_area.global_position.y
		bounds_right = bounds_left + _game_panel.size.x
		bounds_bottom = bounds_top + _game_panel.size.y
	# Keep hint cloud closer to chicken (higher and slightly nearer on X).
	var target_x := _bird_sprite.position.x + (_bird_sprite.size.x * 0.72)
	var target_y := _bird_sprite.position.y - (bubble_size.y * 0.55)
	var min_x := bounds_left + pad
	var max_x := maxf(min_x, bounds_right - bubble_size.x - pad)
	var min_y := bounds_top + pad
	var max_y := maxf(min_y, bounds_bottom - bubble_size.y - pad)
	var bx := clampf(target_x, min_x, max_x)
	var by := clampf(target_y, min_y, max_y)
	# Keep cloud above/near chicken so it does not sit over answer options.
	var chicken_cap_y := _bird_sprite.position.y - (bubble_size.y * 0.28)
	by = minf(by, maxf(min_y, chicken_cap_y))
	_tutorial_bubble.position = Vector2(bx, by)
	var tail_y := clampf(by + bubble_size.y - 34.0, min_y, maxf(min_y, bounds_bottom - 34.0))
	var tail_x := clampf(bx - 14.0, bounds_left, maxf(bounds_left, bounds_right - 48.0))
	_tutorial_bubble_tail.position = Vector2(tail_x, tail_y)
	_tutorial_bubble_tail.rotation_degrees = -22.0
	# Shift chain to start higher/right from chicken head.
	var head_anchor := _bird_sprite.position + Vector2(_bird_sprite.size.x * 0.36, _bird_sprite.size.y * 0.24)
	var bubble_anchor := Vector2(bx + 8.0, by + bubble_size.y * 0.62)
	for i in _tutorial_bubble_dots.size():
		var dot := _tutorial_bubble_dots[i]
		if dot == null:
			continue
		var t := float(i + 1) / float(_tutorial_bubble_dots.size() + 1)
		var pos := head_anchor.lerp(bubble_anchor, t)
		dot.position = pos - (dot.size * 0.5)


func _pick_rotating_line(lines: Array, last_line: String) -> String:
	if lines.is_empty():
		return ""
	var idx := _rng.randi_range(0, lines.size() - 1)
	var line := str(lines[idx])
	if lines.size() > 1 and line == last_line:
		line = str(lines[(idx + 1 + _rng.randi_range(0, lines.size() - 2)) % lines.size()])
	return line


func _request_chicken_hint() -> void:
	if _chicken_hint_busy:
		return
	if not _quiz_active:
		if _status_label != null:
			_status_label.text = "Start a round to get a chicken hint."
		return
	if _awaiting_round_start:
		if _status_label != null:
			_status_label.text = "Tap Start Round, then ask chicken for a hint."
		return
	if _is_prompt_playing:
		if _status_label != null:
			_status_label.text = "Wait for prompt audio to finish."
		return
	_chicken_hint_clicks_this_turn += 1
	# 1st and 2nd tap: gentle hints. 3rd+ tap: clear hint with reason.
	var clear_hint := _chicken_hint_clicks_this_turn >= 3
	_chicken_hint_busy = true
	_chicken_hint_cooldown_until = (float(Time.get_ticks_msec()) / 1000.0) + 1.4
	await _provide_chicken_hint(clear_hint)
	_chicken_hint_busy = false


func _midi_pitch_class_name(midi: int) -> String:
	var names := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
	var idx := posmod(midi, 12)
	return names[idx]


func _chord_family_id_from_name(quality_name: String) -> String:
	var q := quality_name.to_lower()
	if q.find("dim7") >= 0 or q.find("diminished 7") >= 0:
		return "dim7"
	if q.find("maj7") >= 0 or q.find("major 7") >= 0:
		return "maj7"
	if q.find("min7") >= 0 or q.find("minor 7") >= 0:
		return "min7"
	if q.find("dom7") >= 0 or q.find("dominant 7") >= 0:
		return "dom7"
	if q.find("power") >= 0:
		return "power"
	if q.find("aug") >= 0:
		return "aug"
	if q.find("dim") >= 0:
		return "dim"
	if q.find("sus2") >= 0:
		return "sus2"
	if q.find("sus4") >= 0 or q.find("sus") >= 0:
		return "sus4"
	if q.find("min") >= 0 or q.find("minor") >= 0:
		return "minor"
	if q == "5":
		return "power"
	return "major"


func _chord_hint_meta(quality_name: String) -> Dictionary:
	var family := _chord_family_id_from_name(quality_name)
	match family:
		"maj7":
			return {"intervals": [0, 4, 7, 11], "family": family}
		"min7":
			return {"intervals": [0, 3, 7, 10], "family": family}
		"dom7":
			return {"intervals": [0, 4, 7, 10], "family": family}
		"dim7":
			return {"intervals": [0, 3, 6, 9], "family": family}
		"aug":
			return {"intervals": [0, 4, 8], "family": family}
		"dim":
			return {"intervals": [0, 3, 6], "family": family}
		"sus2":
			return {"intervals": [0, 2, 7], "family": family}
		"sus4":
			return {"intervals": [0, 5, 7], "family": family}
		"minor":
			return {"intervals": [0, 3, 7], "family": family}
		"power":
			return {"intervals": [0, 7], "family": family}
		_:
			return {"intervals": [0, 4, 7], "family": "major"}


func _parse_root_midi_from_chord_name(name: String) -> int:
	var t := name.strip_edges()
	if t.is_empty():
		return 60
	var parts := t.split(" ", false)
	var root_token := parts[0] if not parts.is_empty() else "C"
	var base := root_token.substr(0, 1).to_upper()
	var semis := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var semi := int(semis.get(base, 0))
	if root_token.find("#") >= 0:
		semi += 1
	if root_token.find("b") >= 0:
		semi -= 1
	return 60 + semi


func _note_letter_from_name(note_name: String) -> String:
	var t := note_name.strip_edges()
	if t.is_empty():
		return "C"
	var c := t.substr(0, 1).to_upper()
	if NOTE_NAME_ORDER.has(c):
		return c
	return "C"


func _pick_topic_hint_line(topic_key: String, lines: Array) -> String:
	if lines.is_empty():
		return ""
	var normalized: Array[String] = []
	for item in lines:
		normalized.append(str(item))
	var used: Array[String] = []
	if _chicken_used_hints_by_topic.has(topic_key):
		var prev: Variant = _chicken_used_hints_by_topic[topic_key]
		if prev is Array:
			for v in (prev as Array):
				used.append(str(v))
	var candidates: Array[String] = []
	for line in normalized:
		if not used.has(line):
			candidates.append(line)
	if candidates.is_empty():
		used.clear()
		candidates = normalized.duplicate()
	var last_line := str(_chicken_last_hint_by_topic.get(topic_key, ""))
	var line := _pick_rotating_line(candidates, last_line)
	if not line.is_empty():
		used.append(line)
	_chicken_used_hints_by_topic[topic_key] = used
	_chicken_last_hint_by_topic[topic_key] = line
	return line


func _interval_hint_lines(interval_id: String, clear_hint: bool) -> Array:
	var root_name := _midi_pitch_class_name(_current_root_midi)
	var top_name := _midi_pitch_class_name(_current_second_midi)
	var semis := absi(_current_second_midi - _current_root_midi)
	var bank := {
		"P1": [
			"It sounds like the same note again.",
			"No jump, just one pitch repeated.",
			"Unison: both notes match.",
			"Try matching your voice to one note only.",
			"Think 'same note, different time'."
		],
		"m2": [
			"Song idea: Jaws opening.",
			"Very tiny, tense step.",
			"Only 1 semitone apart.",
			"Feels like notes are rubbing together.",
			"Often sounds spooky."
		],
		"M2": [
			"Song idea: Happy Birthday opening.",
			"Small step, but less tense than m2.",
			"2 semitones apart.",
			"Common in simple melodies.",
			"Feels like a gentle move forward."
		],
		"m3": [
			"Song idea: Greensleeves opening color.",
			"Minor 3rd often sounds sadder.",
			"3 semitones apart.",
			"This interval helps form minor chords.",
			"Bigger than a step, still close."
		],
		"M3": [
			"Song idea: Oh When the Saints opening.",
			"Major 3rd often sounds brighter.",
			"4 semitones apart.",
			"This interval helps form major chords.",
			"Happy, clear color."
		],
		"P4": [
			"Song idea: Here Comes the Bride.",
			"Perfect 4th is a strong classic jump.",
			"5 semitones apart.",
			"Not too tight, not too wide.",
			"Often sounds bold."
		],
		"TT": [
			"Song idea: The Simpsons theme / Maria.",
			"Tritone = augmented 4th or diminished 5th.",
			"This was nicknamed 'Diabolus in Musica'.",
			"In medieval times it was often avoided for harsh dissonance.",
			"6 semitones: right in the middle of the octave."
		],
		"P5": [
			"Song idea: Twinkle Twinkle Little Star.",
			"Song idea: Star Wars main theme opening.",
			"Perfect 5th sounds open and stable.",
			"7 semitones apart.",
			"Very common 'strong' interval."
		],
		"m6": [
			"Song idea: The Entertainer phrase color.",
			"Minor 6th is a wide, darker jump.",
			"8 semitones apart.",
			"Feels bigger than a 5th.",
			"Can sound dramatic."
		],
		"M6": [
			"Song idea: My Bonnie Lies Over the Ocean.",
			"Major 6th is wide and warmer.",
			"9 semitones apart.",
			"Still singable, but clearly wide.",
			"Brighter than minor 6th."
		],
		"m7": [
			"Song idea: Somewhere color (near octave).",
			"Minor 7th sits just below octave.",
			"10 semitones apart.",
			"Wide and tense.",
			"Feels almost complete."
		],
		"M7": [
			"Song idea: Take On Me leap color.",
			"Major 7th is very close to octave.",
			"11 semitones apart.",
			"Strong pull to resolve to octave.",
			"Bright and tense."
		],
		"P8": [
			"Song idea: Somewhere Over the Rainbow opening.",
			"Octave means same note name, higher pitch.",
			"12 semitones apart.",
			"Big leap but very stable.",
			"Home note repeated higher."
		]
	}
	var interval_lines: Array = bank.get(interval_id, ["Listen for size first.", "Use replay.", "Compare to octave.", "Use root as anchor.", "Then choose closest label."])
	var interval_extra := [
		"Extra hint: this interval uses %d semitone(s)." % semis,
		"Extra hint: compare %s to %s slowly." % [root_name, top_name],
		"Extra hint: root is your fixed reference.",
		"Extra hint: clap once for each tiny step if needed.",
		"Extra hint: keep listening for jump size, not loudness."
	]
	var hints: Array[String] = []
	if clear_hint:
		hints.append("Clear: this interval is %d semitone(s)." % semis)
		hints.append("Clear: from %s to %s." % [root_name, top_name])
		hints.append("Theory: interval = distance between two notes.")
		hints.append("Theory: semitone is the smallest piano step.")
		hints.append("Tip: use root as your home note.")
	for line in interval_lines:
		hints.append(str(line))
	for line2 in interval_extra:
		hints.append(str(line2))
	while hints.size() < 20:
		hints.append("Replay and compare the jump size.")
	return hints


func _chord_hint_lines(quality_name: String, clear_hint: bool) -> Array:
	var meta: Dictionary = _chord_hint_meta(quality_name)
	var family := str(meta.get("family", "major"))
	var bank := {
		"major": ["Bright and stable.", "Song color: Let It Be style major.", "Major chords often feel 'home'.", "Listen for open, clear mood.", "Major triad is root-3rd-5th."],
		"minor": ["Darker, softer mood.", "Song color: House of the Rising Sun vibe.", "Minor chords often feel sadder.", "Listen for warm-dark tone.", "Minor triad has lowered 3rd."],
		"maj7": ["Dreamy and smooth.", "Jazz-ballad color.", "Major 7 adds sweet tension.", "Soft top-note shimmer.", "Major triad + major 7th."],
		"min7": ["Soulful and mellow.", "Common in R&B/jazz.", "Minor 7 is softer than dominant 7.", "Relaxed color on top.", "Minor triad + minor 7th."],
		"dom7": ["Bluesy, wants to resolve.", "Very common in blues turnarounds.", "Dominant 7 creates pull.", "Can sound bright + tense.", "Major triad + flat 7th."],
		"dim": ["Tight and tense.", "Spooky movie color.", "Feels unstable.", "Smaller stacked feel.", "Lowered 3rd and 5th."],
		"dim7": ["Very tense and dramatic.", "Classic suspense chord.", "Symmetric stacked sound.", "Strong pull to move.", "Great for tension in harmony."],
		"aug": ["Raised, floating sound.", "Unstable and bright.", "Cinematic lift feeling.", "Doesn't feel settled.", "Raised 5th gives the color."],
		"sus2": ["Open and neutral.", "No major/minor 3rd feel.", "Suspended color.", "Pop intro vibe.", "Third replaced by second."],
		"sus4": ["Suspended, unresolved.", "Wants to resolve.", "No clear major/minor color.", "Strong held tension.", "Third replaced by fourth."],
		"power": ["Strong rock sound.", "Root + fifth only.", "No major/minor color.", "Big and direct.", "Very common in guitar riffs."]
	}
	var lines: Array = bank.get(family, ["Listen for chord mood.", "Bright, dark, or tense?", "Use replay.", "Compare with major/minor.", "Pick closest family."])
	var chord_extra := [
		"Extra hint: chord family here is %s." % family,
		"Extra hint: start with mood, then label.",
		"Extra hint: replay and hear the whole color.",
		"Extra hint: bass note helps anchor the chord.",
		"Extra hint: check if the chord feels stable or unresolved."
	]
	var hints: Array[String] = []
	if clear_hint:
		hints.append("Clear: chord family is %s." % family)
		hints.append("Theory: chord = notes played together.")
		hints.append("Theory: the 3rd often decides major/minor.")
		hints.append("Tip: choose family first, exact label second.")
		hints.append("Tip: replay and focus on mood.")
	for line in lines:
		hints.append(str(line))
	for line2 in chord_extra:
		hints.append(str(line2))
	while hints.size() < 20:
		hints.append("Listen to the overall chord feeling.")
	return hints


func _sight_note_hint_lines(note_name: String, clef_name: String, clear_hint: bool) -> Array:
	var letter := _note_letter_from_name(note_name)
	var prof: Dictionary = SIGHT_NOTE_PROFILES.get(letter, SIGHT_NOTE_PROFILES["C"])
	var is_line := posmod(_current_sight_display_step, 2) == 0
	var lane_txt := "line" if is_line else "space"
	var note_bank := {
		"C": ["Look for middle-C area first.", "C is a common landmark.", "Find C, then move up/down.", "C often anchors reading.", "Say C first, then confirm."],
		"D": ["D is one step from C.", "Find C then move to D.", "D sits close to center often.", "Check line/space around C.", "Use step counting for D."],
		"E": ["E is easy near lower treble line.", "Find nearby D/F and step.", "E is often a chord tone.", "Check if it is line-based here.", "Anchor from C or G."],
		"F": ["F is tied to bass clef marker note.", "In treble, F is first space.", "Use clef clue for F quickly.", "Find E/G and step.", "F is a strong landmark note."],
		"G": ["G is tied to treble clef marker.", "Find treble clef curl line for G.", "G sits as a common anchor.", "Use F/A around it.", "G is often easy to spot."],
		"A": ["A is one step above G.", "Find G then move to A.", "A appears often in melodies.", "Check if line or space here.", "Use neighbor notes to confirm A."],
		"B": ["B sits near C anchor.", "Find C then step to B.", "B can be leading tone feel.", "Check accidental if key has sharps/flats.", "Use A/C around B."]
	}
	var lines: Array = note_bank.get(letter, ["Find nearby anchor.", "Count by steps.", "Check clef.", "Line or space first.", "Confirm letter."])
	var note_extra := [
		"Extra hint: target letter is %s." % letter,
		"Extra hint: read %s clef first." % clef_name,
		"Extra hint: confirm line vs space.",
		"Extra hint: move by one alphabet step at a time.",
		"Extra hint: use nearby landmark notes."
	]
	var hints: Array[String] = []
	if clear_hint:
		hints.append("Clear: note is %s on a %s." % [letter, lane_txt])
		hints.append("Clear: first check %s clef." % clef_name)
		hints.append("Theory: notes go A-B-C-D-E-F-G.")
		hints.append("Theory: line and space alternate by step.")
		hints.append("Tip: use landmarks like C/F/G.")
	for line in lines:
		hints.append(str(line))
	for line2 in note_extra:
		hints.append(str(line2))
	hints.append("In %s clef, look near %s." % [clef_name, str(prof.get("treble", "") if clef_name == "Treble" else prof.get("bass", ""))])
	while hints.size() < 20:
		hints.append("Count one staff step at a time.")
	return hints


func _sight_chord_hint_lines(chord_name: String, clear_hint: bool) -> Array:
	var clean_name := chord_name.strip_edges()
	var root_token := clean_name.split(" ", false)[0] if not clean_name.is_empty() else "C"
	var quality_part := clean_name
	var split_once := clean_name.split(" ", false, 1)
	if split_once.size() >= 2:
		quality_part = str(split_once[1])
	var family := _chord_family_id_from_name(quality_part)
	var bank := {
		"major": ["Start with root note.", "Major stacks look open and stable.", "Find bottom and top note first.", "Major often sounds bright.", "Then check middle note."],
		"minor": ["Start with root note.", "Minor looks similar but sounds darker.", "Bottom note then top note.", "Minor often sounds sadder.", "Check middle note distance."],
		"dim": ["Look for tight stacked look.", "Diminished feels tense.", "Root first, then compressed shape.", "Often used for tension.", "Double-check accidentals."],
		"dim7": ["Very tense stack.", "Symmetric feeling shape.", "Root then count small jumps.", "Used in dramatic moments.", "Check all note spellings."],
		"dom7": ["Dominant 7 often wants to resolve.", "Find major body + flat seventh.", "Listen for blues pull.", "Root first, top color second.", "Check the 7th note carefully."],
		"maj7": ["Major 7 sounds dreamy.", "Find major triad + soft top.", "Root first.", "Check if top feels close/tender.", "Then verify chord name."],
		"min7": ["Minor 7 sounds mellow.", "Find minor triad + extra top.", "Root first.", "Common in jazz/pop.", "Check the 7th note."],
		"sus2": ["No 3rd sound, open feel.", "Third replaced by second.", "Root + 2 + 5 shape.", "Suspended, less major/minor.", "Find open stack."],
		"sus4": ["No 3rd sound, unresolved feel.", "Third replaced by fourth.", "Root + 4 + 5 shape.", "Often wants to resolve.", "Check suspension feel."],
		"aug": ["Raised 5th gives lift.", "Bright but unstable.", "Check if top note is raised.", "Root first, then odd top color.", "Augmented sounds floating."],
		"power": ["Root + fifth only.", "No 3rd major/minor clue.", "Strong rock-style shape.", "Open, direct sound.", "Check if middle is missing."]
	}
	var lines: Array = bank.get(family, ["Root first.", "Read vertical stack.", "Check top note.", "Listen to mood.", "Choose closest family."])
	var sight_chord_extra := [
		"Extra hint: root token is %s." % root_token,
		"Extra hint: this family reads as %s." % family,
		"Extra hint: read bottom note first.",
		"Extra hint: then check top color note.",
		"Extra hint: choose family first, full chord next."
	]
	var hints: Array[String] = []
	if clear_hint:
		hints.append("Clear: root is %s." % root_token)
		hints.append("Clear: chord family is %s." % family)
		hints.append("Theory: chord notes are stacked vertically.")
		hints.append("Theory: 3rd often sets major/minor quality.")
		hints.append("Tip: choose family first, full name next.")
	for line in lines:
		hints.append(str(line))
	for line2 in sight_chord_extra:
		hints.append(str(line2))
	while hints.size() < 20:
		hints.append("Read bottom note first, then build upward.")
	return hints


func _interval_reason_text(interval_id: String) -> String:
	var reasons := {
		"P1": "both notes are the same pitch (unison).",
		"m2": "the notes are 1 semitone apart, a very tight sound.",
		"M2": "the notes are 2 semitones apart, a small step.",
		"m3": "the distance is 3 semitones with a minor color.",
		"M3": "the distance is 4 semitones with a major color.",
		"P4": "the notes are 5 semitones apart (perfect fourth).",
		"TT": "the notes are 6 semitones apart (tritone).",
		"P5": "the notes are 7 semitones apart (perfect fifth).",
		"m6": "the notes are 8 semitones apart (minor sixth).",
		"M6": "the notes are 9 semitones apart (major sixth).",
		"m7": "the notes are 10 semitones apart (minor seventh).",
		"M7": "the notes are 11 semitones apart (major seventh).",
		"P8": "the notes are 12 semitones apart (octave)."
	}
	return str(reasons.get(interval_id, "the distance matches this interval pattern."))


func _chord_reason_text(quality_name: String) -> String:
	var family := _chord_family_id_from_name(quality_name)
	var reasons := {
		"major": "it has a bright major color from its interval stack.",
		"minor": "it has a darker minor color from its interval stack.",
		"maj7": "it has major triad color plus a major 7th flavor.",
		"min7": "it has minor triad color plus a minor 7th flavor.",
		"dom7": "it has dominant 7th tension that wants to resolve.",
		"dim": "it has a tight diminished stack and tense sound.",
		"dim7": "it has a fully diminished, very tense color.",
		"aug": "it has a raised 5th that sounds lifted/unstable.",
		"sus2": "it replaces the 3rd with a 2nd, so it sounds suspended.",
		"sus4": "it replaces the 3rd with a 4th, so it sounds suspended.",
		"power": "it uses root and fifth without major/minor third."
	}
	return str(reasons.get(family, "its stacked notes match this chord family."))


func _sight_note_reason_text(note_name: String, clef_name: String) -> String:
	var letter := _note_letter_from_name(note_name)
	var line_space := "line" if posmod(_current_sight_display_step, 2) == 0 else "space"
	return "the note head position in %s clef matches %s on a %s." % [clef_name, letter, line_space]


func _sight_chord_reason_text(chord_name: String) -> String:
	var clean_name := chord_name.strip_edges()
	var root_token := clean_name.split(" ", false)[0] if not clean_name.is_empty() else "C"
	var quality_part := clean_name
	var split_once := clean_name.split(" ", false, 1)
	if split_once.size() >= 2:
		quality_part = str(split_once[1])
	var family := _chord_family_id_from_name(quality_part)
	return "the stacked notes match root %s with %s chord color." % [root_token, family]


func _provide_chicken_hint(clear_hint: bool) -> void:
	if _selected_mode == MODE_INTERVAL:
		var interval_topic := "interval:%s:%s" % [_current_interval_id, "clear" if clear_hint else "subtle"]
		var interval_line := _pick_topic_hint_line(interval_topic, _interval_hint_lines(_current_interval_id, clear_hint))
		if clear_hint:
			interval_line += " Why this is correct: %s" % _interval_reason_text(_current_interval_id)
		if _status_label != null:
			_status_label.text = "Hint: %s" % interval_line
		_lock_chicken_hint_line(interval_line)
		await _play_interval_prompt_async(_current_root_midi, _current_second_midi)
		return
	if _selected_mode == MODE_CHORD:
		var chord_topic := "ear_chord:%s:%s" % [_chord_family_id_from_name(_current_chord_quality), "clear" if clear_hint else "subtle"]
		var chord_line := _pick_topic_hint_line(chord_topic, _chord_hint_lines(_current_chord_quality, clear_hint))
		if clear_hint:
			chord_line += " Why this is correct: %s" % _chord_reason_text(_current_chord_quality)
		if _status_label != null:
			_status_label.text = "Hint: %s" % chord_line
		_lock_chicken_hint_line(chord_line)
		var meta: Dictionary = _chord_hint_meta(_current_chord_quality)
		var ivals: Array = meta.get("intervals", [0, 4, 7])
		var root := clampi(_current_root_midi, 48, 64)
		var notes: Array[int] = []
		for iv in ivals:
			notes.append(root + int(iv))
		await _play_chord(notes, 0.24)
		return
	if _selected_mode == MODE_SIGHT:
		if _sight_mode == "Notes":
			var note_topic := "sight_note:%s:%s:%s" % [_current_sight_note, _selected_clef, "clear" if clear_hint else "subtle"]
			var note_line := _pick_topic_hint_line(note_topic, _sight_note_hint_lines(_current_sight_note, _selected_clef, clear_hint))
			if clear_hint:
				note_line += " Why this is correct: %s" % _sight_note_reason_text(_current_sight_note, _selected_clef)
			if _status_label != null:
				_status_label.text = "Hint: %s" % note_line
			_lock_chicken_hint_line(note_line)
			return
		if _sight_mode == "Chords":
			var chord_name := _current_sight_chord_name.strip_edges()
			var sight_chord_topic := "sight_chord:%s:%s" % [chord_name, "clear" if clear_hint else "subtle"]
			var sight_chord_line := _pick_topic_hint_line(sight_chord_topic, _sight_chord_hint_lines(chord_name, clear_hint))
			if clear_hint:
				sight_chord_line += " Why this is correct: %s" % _sight_chord_reason_text(chord_name)
			if _status_label != null:
				_status_label.text = "Hint: %s" % sight_chord_line
			_lock_chicken_hint_line(sight_chord_line)
			var root2 := _parse_root_midi_from_chord_name(chord_name)
			var quality_part := chord_name
			var sp := chord_name.split(" ", false, 1)
			if sp.size() >= 2:
				quality_part = str(sp[1])
			var m2 := _chord_hint_meta(quality_part)
			var ivals2: Array = m2.get("intervals", [0, 4, 7])
			var notes2: Array[int] = []
			for iv2 in ivals2:
				notes2.append(root2 + int(iv2))
			await _play_chord(notes2, 0.22)
			return
		if _sight_mode == "Placement":
			var place_topic := "sight_place:%s:%s:%s" % [_current_sight_note, _selected_clef, "clear" if clear_hint else "subtle"]
			var place_line := _pick_topic_hint_line(place_topic, _sight_note_hint_lines(_current_sight_note, _selected_clef, clear_hint))
			if _status_label != null:
				_status_label.text = "Hint: %s" % place_line
			_lock_chicken_hint_line(place_line)
			return
		if _sight_mode == "Continuous":
			var cont_lines := [
				"Keep a steady beat.",
				"Look one note ahead.",
				"Hit notes as they cross the line.",
				"Stay calm after misses.",
				"Use small, relaxed finger motion."
			]
			var cont_key := "sight_cont:%s" % ("clear" if clear_hint else "subtle")
			var cont_line := _pick_topic_hint_line(cont_key, cont_lines)
			if _status_label != null:
				_status_label.text = "Hint: %s" % cont_line
			_lock_chicken_hint_line(cont_line)
			return
	if _selected_mode == MODE_NOTE_CHASE:
		var chase_line := "Note Chase hints are currently off."
		if _status_label != null:
			_status_label.text = "Hint: %s" % chase_line
		_lock_chicken_hint_line(chase_line)
		return
	if _status_label != null:
		_status_label.text = "Chicken has no hint for this screen yet."
	_lock_chicken_hint_line("Chicken has no hint for this screen yet.")


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
	_ui_sfx_player = AudioStreamPlayer.new()
	add_child(_ui_sfx_player)
	_shield_sfx_player = AudioStreamPlayer.new()
	add_child(_shield_sfx_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -16.0
	_music_player.autoplay = false
	add_child(_music_player)
	_ui_click_sfx = _load_audio_stream(UI_CLICK_SFX_PATH)
	_ui_sight_answer_click_sfx = _load_audio_stream(UI_SIGHT_ANSWER_CLICK_SFX_PATH)
	_correct_sfx = _load_audio_stream(CORRECT_SFX_PATH)
	_wrong_choice_sfx = _load_audio_stream(WRONG_CHOICE_SFX_PATH)
	_fail_gameover_sfx = _load_audio_stream(FAIL_GAMEOVER_SFX_PATH)
	_win_fanfare_sfx = _load_audio_stream(WIN_FANFARE_SFX_PATH)
	_module_complete_sfx = _load_audio_stream(MODULE_COMPLETE_SFX_PATH)
	_new_question_sfx = _load_audio_stream(NEW_QUESTION_SFX_PATH)
	_powerup_sfx = _load_audio_stream(POWERUP_SFX_PATH)
	_transition_whoosh_sfx = _load_audio_stream(TRANSITION_WHOOSH_SFX_PATH)
	_shield_activate_sfx = _load_audio_stream(SHIELD_ACTIVATE_SFX_PATH)
	_note_chase_bgm = _load_audio_stream(NOTE_CHASE_BGM_PATH)
	if _note_chase_bgm is AudioStreamOggVorbis:
		var ogg := _note_chase_bgm as AudioStreamOggVorbis
		ogg.loop = true
	elif _note_chase_bgm is AudioStreamMP3:
		var mp3 := _note_chase_bgm as AudioStreamMP3
		mp3.loop = true

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


func _load_ear_settings() -> void:
	_ear_choice_count = 6
	_ui_theme_id = "golden_harvest"
	_use_descending_intervals = false
	_use_harmonic_intervals = false
	if not FileAccess.file_exists(EAR_SETTINGS_PATH):
		if _home_tokens != null:
			_home_tokens.set_theme(_ui_theme_id)
		return
	var f := FileAccess.open(EAR_SETTINGS_PATH, FileAccess.READ)
	if f == null:
		if _home_tokens != null:
			_home_tokens.set_theme(_ui_theme_id)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d := parsed as Dictionary
	if d.has("choice_count"):
		_ear_choice_count = clampi(int(d["choice_count"]), 2, 6)
	if d.has("theme_id"):
		_ui_theme_id = str(d["theme_id"]).strip_edges()
	if d.has("use_descending_intervals"):
		_use_descending_intervals = bool(d["use_descending_intervals"])
	if d.has("use_harmonic_intervals"):
		_use_harmonic_intervals = bool(d["use_harmonic_intervals"])
	if _use_harmonic_intervals:
		_use_descending_intervals = false
	if _home_state != null:
		_home_state.use_descending_intervals = _use_descending_intervals
		_home_state.use_harmonic_intervals = _use_harmonic_intervals
	if _home_tokens != null:
		_home_tokens.set_theme(_ui_theme_id)
		_ui_theme_id = _home_tokens.theme_id()


func _save_ear_settings() -> void:
	var data := {
		"choice_count": _ear_choice_count,
		"theme_id": _ui_theme_id,
		"use_descending_intervals": _use_descending_intervals,
		"use_harmonic_intervals": _use_harmonic_intervals
	}
	var txt := JSON.stringify(data, "\t")
	var f := FileAccess.open(EAR_SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(txt)
	f.close()


func _refresh_ear_settings_ui() -> void:
	if _ear_choice_count_select != null:
		for i in range(_ear_choice_count_select.item_count):
			var v := int(_ear_choice_count_select.get_item_metadata(i))
			if v == _ear_choice_count:
				_ear_choice_count_select.select(i)
				break
	if _ear_theme_select != null:
		for i in range(_ear_theme_select.item_count):
			var v := str(_ear_theme_select.get_item_metadata(i))
			if v == _ui_theme_id:
				_ear_theme_select.select(i)
				break


func _refresh_ear_settings_subscreen() -> void:
	if _ear_settings_more_panel != null:
		_ear_settings_more_panel.visible = true
	_refresh_ear_settings_ui()


func _refresh_sight_settings_subscreen() -> void:
	if _sight_settings_more_panel != null:
		_sight_settings_more_panel.visible = true


func _on_mode_selected() -> void:
	_sync_home_state_from_runtime()
	var vis: Dictionary = _home_state.visibility(MODE_INTERVAL, MODE_CHORD, MODE_SIGHT, MODE_NOTE_CHASE, MODE_READ)
	var is_ear := bool(vis["is_ear"])
	var practice_flow := bool(vis["practice_flow"])
	var learn_flow := bool(vis["learn_flow"])
	var show_home_main := bool(vis["show_home_main"])
	var show_settings := practice_flow and _ear_settings_screen_active and show_home_main
	var show_overview := practice_flow and not _home_mode_detail_active and not show_settings and show_home_main
	var show_detail := practice_flow and _home_mode_detail_active and not show_settings and show_home_main
	var sight_in_more_settings := show_detail and _selected_mode == MODE_SIGHT and _sight_settings_screen_active

	if _home_q_row != null:
		_home_q_row.visible = false
	if _home_mode_label != null:
		_home_mode_label.visible = false
	if _home_mode_buttons_row != null:
		_home_mode_buttons_row.visible = show_overview
	if _home_title_label != null:
		_home_title_label.visible = show_home_main
	if _home_hub_row != null:
		_home_hub_row.visible = show_overview
	if _home_settings_button != null:
		_home_settings_button.visible = show_overview
	_ear_mode_row.visible = show_detail and is_ear
	if _ear_settings_screen != null:
		_ear_settings_screen.visible = show_settings
	if show_settings:
		_refresh_ear_settings_subscreen()
		_refresh_sight_settings_subscreen()
	if show_detail and _selected_mode == MODE_SIGHT:
		_refresh_sight_settings_subscreen()
	_set_home_section_visible(_interval_options_box, show_detail and bool(vis["show_interval"]))
	_set_home_section_visible(_chord_options_box, show_detail and bool(vis["show_chord"]))
	_set_home_section_visible(_sight_options_box, show_detail and bool(vis["show_sight"]))
	_set_home_section_visible(_note_chase_options_box, show_detail and bool(vis["show_chase"]))
	_set_home_section_visible(_read_options_box, show_detail and bool(vis["show_read"]))
	if _home_info_label != null:
		_home_info_label.visible = show_detail
	if _home_mode_back_button != null:
		var can_go_back := show_home_main and (_home_mode_detail_active or _ear_settings_screen_active or _sight_settings_screen_active)
		_home_mode_back_button.visible = can_go_back
	if _home_sight_mode_row != null:
		_home_sight_mode_row.visible = not sight_in_more_settings
	if _sight_clef_row != null:
		_sight_clef_row.visible = _selected_mode == MODE_SIGHT

	if _home_start_button != null:
		if show_detail:
			_home_start_button.text = "Start Training"
			_home_start_button.visible = true
		elif learn_flow and show_home_main:
			_home_start_button.text = "Start Module"
			_home_start_button.visible = true
		else:
			_home_start_button.visible = false
	if show_home_main:
		_refresh_home_subtitle()

	_refresh_mode_buttons()
	_refresh_ear_mode_buttons()
	_refresh_clef_buttons()
	_refresh_note_chase_clef_buttons()
	_refresh_chord_group_buttons()
	_refresh_sight_mode_buttons()
	_refresh_read_module_buttons()
	_refresh_home_hub_buttons()
	_refresh_home_option_group_visibility()
	_refresh_home_section_emphasis()
	_update_home_disabled_reason()
	_setup_home_focus_navigation()


func _refresh_home_subtitle() -> void:
	if _home_title_label == null:
		return
	if _ear_settings_screen_active:
		_home_title_label.text = "Settings"
		return
	var overview := _home_flow == "Practice" and not _home_mode_detail_active
	if overview:
		_home_title_label.text = "Choose Mode"
		return
	if _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD:
		_home_title_label.text = "Ear Training"
	elif _selected_mode == MODE_SIGHT:
		if _sight_mode == "Chords":
			_home_title_label.text = "Sight Reading - Chords"
		elif _sight_mode == "Continuous":
			_home_title_label.text = "Sight Reading - Note Flow"
		else:
			_home_title_label.text = "Sight Reading - Notes"
	elif _selected_mode == MODE_NOTE_CHASE:
		_home_title_label.text = "Note Chase"
	elif _selected_mode == MODE_READ:
		_home_title_label.text = "Read Notation"
	else:
		_home_title_label.text = "Choose Mode"


func _on_mode_button_pressed(mode: int) -> void:
	_home_mode_detail_active = true
	_sight_settings_screen_active = false
	_sync_home_state_from_runtime()
	_home_state.on_mode_button_pressed(mode, MODE_INTERVAL, MODE_SIGHT, MODE_NOTE_CHASE, MODE_READ)
	_sync_runtime_from_home_state()
	_on_mode_selected()


func _on_home_hub_pressed(hub_name: String) -> void:
	_home_mode_detail_active = false
	_sight_settings_screen_active = false
	_sync_home_state_from_runtime()
	_home_state.on_home_hub_pressed(hub_name, MODE_INTERVAL, MODE_CHORD, MODE_SIGHT, MODE_NOTE_CHASE, MODE_READ)
	_sync_runtime_from_home_state()
	_on_mode_selected()


func _refresh_home_hub_buttons() -> void:
	for key in _home_hub_buttons.keys():
		var btn: Button = _home_hub_buttons[key]
		var selected := str(key) == _home_flow
		_set_home_selection_state(btn, selected)
		if _home_menu_ui != null:
			_home_menu_ui.set_selected_text_marker(btn, selected)


func _on_ear_mode_button_pressed(mode: int) -> void:
	_home_mode_detail_active = true
	_sight_settings_screen_active = false
	_sync_home_state_from_runtime()
	_home_state.on_ear_mode_pressed(mode, MODE_INTERVAL, MODE_CHORD)
	_sync_runtime_from_home_state()
	_on_mode_selected()


func _on_read_module_button_pressed(module_id: int) -> void:
	_selected_read_module = clampi(module_id, 1, 2)
	if _home_state != null:
		_home_state.selected_read_module = _selected_read_module
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
	if _home_state != null:
		_home_state.include_minor_intervals = enabled
	_style_include_minor_toggle(enabled)
	_save_ear_settings()


func _on_descending_intervals_toggled(enabled: bool) -> void:
	if _use_harmonic_intervals and enabled:
		# Harmonic mode makes descending order irrelevant.
		if _descending_intervals_toggle != null:
			_descending_intervals_toggle.button_pressed = false
		enabled = false
	_use_descending_intervals = enabled
	if _home_state != null:
		_home_state.use_descending_intervals = enabled
	_style_descending_intervals_toggle(enabled)
	_save_ear_settings()


func _on_harmonic_intervals_toggled(enabled: bool) -> void:
	_use_harmonic_intervals = enabled
	if _home_state != null:
		_home_state.use_harmonic_intervals = enabled
	if enabled and _use_descending_intervals:
		_use_descending_intervals = false
		if _home_state != null:
			_home_state.use_descending_intervals = false
		if _descending_intervals_toggle != null:
			_descending_intervals_toggle.button_pressed = false
	_style_harmonic_intervals_toggle(enabled)
	_style_descending_intervals_toggle(_use_descending_intervals)
	_save_ear_settings()


func _on_inversion_toggled(enabled: bool) -> void:
	_style_menu_toggle(_inversion_toggle, enabled, _inversion_toggle != null and _inversion_toggle.disabled)


func _on_sight_accidentals_toggled(enabled: bool) -> void:
	_style_menu_toggle(_sight_accidentals_toggle, enabled, _sight_accidentals_toggle != null and _sight_accidentals_toggle.disabled)


func _on_note_chase_note_toggled(note_name: String) -> void:
	if not _note_chase_note_toggles.has(note_name):
		return
	var btn: Button = _note_chase_note_toggles[note_name]
	if btn.button_pressed:
		if _note_chase_selected_notes.has(note_name):
			return
		if _note_chase_selected_notes.size() >= 3:
			btn.button_pressed = false
			_home_info_label.text = "You can pick up to 3 target notes."
			return
		_note_chase_selected_notes.append(note_name)
	else:
		_note_chase_selected_notes.erase(note_name)
		if _note_chase_selected_notes.is_empty():
			btn.button_pressed = true
			_note_chase_selected_notes.append(note_name)
	_refresh_note_chase_note_toggles()
	if _home_state != null:
		_home_state.note_chase_selected_notes = _note_chase_selected_notes.duplicate()
	_update_home_disabled_reason()


func _refresh_note_chase_note_toggles() -> void:
	for key in _note_chase_note_toggles.keys():
		var btn: Button = _note_chase_note_toggles[key]
		var selected := _note_chase_selected_notes.has(str(key))
		btn.button_pressed = selected
		_set_home_selection_state(btn, selected)


func _on_clef_button_pressed(clef_name: String) -> void:
	_selected_clef = clef_name
	if _home_state != null:
		_home_state.selected_clef = clef_name
	if _note_chase_clef_clone != null:
		_note_chase_clef_clone.text = char(0x1D122) if _selected_clef == "Bass" else char(0x1D11E)
	_set_default_sight_range_for_clef(_selected_clef)
	_refresh_clef_buttons()
	_refresh_note_chase_clef_buttons()
	_update_sight_range_ui()
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous":
		_apply_continuous_level_profile()
	_refresh_continuous_keyboard_range()


func _set_default_sight_range_for_clef(clef_name: String) -> void:
	# Treble default: A3..G4 (steps 12..6)
	# Bass default: F3..E4 (steps 2..-4)
	if clef_name == "Bass":
		_sight_range_min_step = -4
		_sight_range_max_step = 2
	else:
		_sight_range_min_step = 6
		_sight_range_max_step = 12
	var bounds := _get_sight_step_bounds()
	_sight_range_min_step = clampi(_sight_range_min_step, bounds.x, bounds.y)
	_sight_range_max_step = clampi(_sight_range_max_step, _sight_range_min_step, bounds.y)


func _on_note_chase_clef_mode_pressed(mode_name: String) -> void:
	_note_chase_clef_mode = mode_name
	if _home_state != null:
		_home_state.note_chase_clef_mode = mode_name
	if mode_name == "Treble" or mode_name == "Bass":
		_selected_clef = mode_name
	_refresh_note_chase_clef_buttons()


func _on_sight_mode_button_pressed(mode_name: String) -> void:
	_sight_mode = mode_name
	_selected_mode = MODE_SIGHT
	_sight_settings_screen_active = false
	if _home_state != null:
		_home_state.selected_mode = MODE_SIGHT
		_home_state.sight_mode = mode_name
	_on_mode_selected()
	_refresh_sight_mode_buttons()
	_refresh_home_subtitle()
	_refresh_game_title()
	_refresh_sight_key_label()
	if mode_name == "Continuous":
		_refresh_continuous_keyboard_range()


func _on_sight_key_sig_button_pressed(sig_name: String) -> void:
	_sight_key_signature = sig_name
	if _home_state != null:
		_home_state.sight_key_signature = sig_name
	_refresh_sight_key_sig_buttons()
	_refresh_sight_note_key_buttons()
	_layout_staff_key_signature()
	_refresh_sight_key_label()


func _on_sight_range_adjust(delta: int, adjust_upper: bool) -> void:
	var bounds := _get_sight_step_bounds()
	if adjust_upper:
		# Upper note is represented by min step index.
		_sight_range_min_step = clampi(_sight_range_min_step + delta, bounds.x, _sight_range_max_step)
	else:
		# Lower note is represented by max step index.
		_sight_range_max_step = clampi(_sight_range_max_step + delta, _sight_range_min_step, bounds.y)
	if _home_state != null:
		_home_state.sight_range_min_step = _sight_range_min_step
		_home_state.sight_range_max_step = _sight_range_max_step
	_update_sight_range_ui()


func _on_chord_group_button_pressed(group_id: int) -> void:
	_selected_chord_group = clampi(group_id, 1, 4)
	_refresh_chord_group_buttons()


func _on_ear_settings_pressed() -> void:
	_ear_settings_screen_active = true
	_home_mode_detail_active = false
	_sight_settings_screen_active = false
	if _home_state != null:
		_home_state.ear_settings_screen_active = true
	_refresh_ear_settings_subscreen()
	_refresh_sight_settings_subscreen()
	_on_mode_selected()


func _on_ear_settings_back_pressed() -> void:
	_ear_settings_screen_active = false
	if _home_state != null:
		_home_state.ear_settings_screen_active = false
	_refresh_ear_settings_subscreen()
	_on_mode_selected()


func _on_sight_settings_pressed() -> void:
	_sight_settings_screen_active = true
	_refresh_sight_settings_subscreen()
	_on_mode_selected()


func _on_sight_settings_back_pressed() -> void:
	_sight_settings_screen_active = false
	_refresh_sight_settings_subscreen()
	_on_mode_selected()


func _on_home_mode_back_pressed() -> void:
	_ear_settings_screen_active = false
	_sight_settings_screen_active = false
	_home_mode_detail_active = false
	if _home_state != null:
		_home_state.ear_settings_screen_active = false
	_on_mode_selected()


func _on_home_back_pressed() -> void:
	if _ear_settings_screen_active:
		_on_ear_settings_back_pressed()
		return
	if _sight_settings_screen_active:
		_on_sight_settings_back_pressed()
		return
	if _home_mode_detail_active:
		_on_home_mode_back_pressed()


func _update_home_disabled_reason() -> void:
	if _home_disabled_reason_label == null:
		return
	if not _home_mode_detail_active:
		_home_disabled_reason_label.visible = false
		_home_disabled_reason_label.text = ""
		return
	var reason := ""
	if _home_state != null:
		reason = _home_state.disabled_reason_for_mode(_selected_mode, MODE_INTERVAL, MODE_CHORD, MODE_SIGHT, MODE_NOTE_CHASE, MODE_READ)
	_home_disabled_reason_label.text = reason
	_home_disabled_reason_label.visible = not reason.is_empty()
	var colors: Dictionary = _home_tokens.colors(false) if _home_tokens != null else {"text_error": Color(1.0, 0.35, 0.35)}
	_home_disabled_reason_label.add_theme_color_override("font_color", colors["text_error"])


func _on_ear_choice_count_selected(index: int) -> void:
	if _ear_choice_count_select == null:
		return
	var count := int(_ear_choice_count_select.get_item_metadata(index))
	_ear_choice_count = clampi(count, 2, 6)
	_save_ear_settings()
	_refresh_ear_settings_ui()
	if _home_info_label != null:
		_home_info_label.text = "Saved: %d choices." % _ear_choice_count


func _on_theme_selected(index: int) -> void:
	if _ear_theme_select == null:
		return
	var theme_id := str(_ear_theme_select.get_item_metadata(index)).strip_edges()
	if theme_id.is_empty():
		return
	_ui_theme_id = theme_id
	if _home_tokens != null:
		_home_tokens.set_theme(_ui_theme_id)
		_ui_theme_id = _home_tokens.theme_id()
	_apply_pro_style()
	_style_settings_button(_home_settings_button)
	_save_ear_settings()
	_refresh_ear_settings_ui()
	if _home_info_label != null and _home_info_label.text.begins_with("Theme:"):
		_home_info_label.text = ""


func _on_teacher_open_pressed() -> void:
	_show_home()


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
	var selected_allowed := _home_mode_detail_active
	if _mode_buttons.has("Ear"):
		var ear_btn: Button = _mode_buttons["Ear"]
		ear_btn.disabled = _home_flow == "Learn"
		ear_btn.tooltip_text = "Learn mode only supports Read Notation modules." if ear_btn.disabled else ""
		_set_home_selection_state(ear_btn, selected_allowed and is_ear)
		if _home_menu_ui != null:
			_home_menu_ui.set_selected_text_marker(ear_btn, selected_allowed and is_ear)
	if _mode_buttons.has("Sight"):
		var sight_btn: Button = _mode_buttons["Sight"]
		sight_btn.disabled = _home_flow == "Learn"
		sight_btn.tooltip_text = "Learn mode only supports Read Notation modules." if sight_btn.disabled else ""
		var sight_selected := _selected_mode == MODE_SIGHT or _selected_mode == MODE_NOTE_CHASE
		_set_home_selection_state(sight_btn, selected_allowed and sight_selected)
		if _home_menu_ui != null:
			_home_menu_ui.set_selected_text_marker(sight_btn, selected_allowed and sight_selected)
	if _mode_buttons.has("Read"):
		var read_btn: Button = _mode_buttons["Read"]
		read_btn.disabled = _home_flow != "Learn"
		read_btn.tooltip_text = "Read Notation modules are in Learn mode." if read_btn.disabled else ""
		_set_home_selection_state(read_btn, selected_allowed and _selected_mode == MODE_READ)
		if _home_menu_ui != null:
			_home_menu_ui.set_selected_text_marker(read_btn, selected_allowed and _selected_mode == MODE_READ)
		read_btn.visible = false


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


func _refresh_note_chase_clef_buttons() -> void:
	for clef_name in _note_chase_clef_buttons.keys():
		var btn: Button = _note_chase_clef_buttons[clef_name]
		_set_home_selection_state(btn, clef_name == _note_chase_clef_mode)


func _refresh_sight_mode_buttons() -> void:
	for key in _sight_mode_buttons.keys():
		var btn: Button = _sight_mode_buttons[key]
		_set_home_selection_state(btn, _selected_mode == MODE_SIGHT and str(key) == _sight_mode)
	if _sight_note_chase_button != null:
		_set_home_selection_state(_sight_note_chase_button, _selected_mode == MODE_NOTE_CHASE)
	var sight_active := _selected_mode == MODE_SIGHT
	if _sight_range_container != null:
		_sight_range_container.visible = sight_active and _sight_mode == "Notes"
	if _sight_key_sig_row != null:
		_sight_key_sig_row.visible = sight_active and (_sight_mode == "Chords" or _sight_mode == "Notes")
	if _sight_accidentals_toggle != null:
		_sight_accidentals_toggle.visible = sight_active and _sight_mode == "Chords"
	_refresh_sight_key_sig_buttons()
	_refresh_sight_note_key_buttons()
	_refresh_home_option_group_visibility()


func _refresh_sight_key_sig_buttons() -> void:
	for key in _sight_key_sig_buttons.keys():
		var btn: Button = _sight_key_sig_buttons[key]
		_set_home_selection_state(btn, str(key) == _sight_key_signature)


func _refresh_sight_note_key_buttons() -> void:
	var use_keysig := _selected_mode == MODE_SIGHT and _sight_mode == "Notes"
	var sig_map := _key_signature_accidental_map()
	for key in _sight_key_buttons.keys():
		var btn: Button = _sight_key_buttons[key]
		if btn == null:
			continue
		var key_name := str(key)
		var show_btn := use_keysig
		if key_name.find("#") >= 0 or key_name.find("b") >= 0:
			var letter := key_name.substr(0, 1)
			show_btn = use_keysig and int(sig_map.get(letter, 0)) != 0
		btn.visible = show_btn
		btn.disabled = not show_btn or _awaiting_round_start


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


func _sight_note_name_with_key_signature(base_name: String) -> String:
	if base_name.is_empty():
		return base_name
	var letter := base_name.substr(0, 1)
	var octave := base_name.substr(1)
	var acc := int(_key_signature_accidental_map().get(letter, 0))
	if acc > 0:
		return "%s#%s" % [letter, octave]
	if acc < 0:
		return "%sb%s" % [letter, octave]
	return base_name


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
		for degree in DEFAULT_INTERVAL_DEGREES:
			var btn: Button = _degree_toggles.get(degree, null)
			if btn != null:
				btn.button_pressed = true
			selected.append(degree)
		_refresh_degree_buttons()
	return selected


func _current_note_duration() -> float:
	return NOTE_DURATION * (1.6 if _slow_toggle != null and _slow_toggle.button_pressed else 1.0)


func _current_gap_duration() -> float:
	return GAP_DURATION * (1.7 if _slow_toggle != null and _slow_toggle.button_pressed else 1.0)


func _current_post_answer_delay() -> float:
	return 1.25 if _slow_toggle != null and _slow_toggle.button_pressed else 0.85


func _refresh_meta_ui() -> void:
	if _selected_mode == MODE_NOTE_CHASE:
		_set_note_chase_top_text_only(true)
		if _lives_label != null:
			_lives_label.text = "Focus Hearts: %d / 5" % _lives
		var target_text := "Targets: %s" % ", ".join(_note_chase_selected_notes)
		var speed_text := "Speed: %.1fx" % _note_chase_speed_multiplier()
		var combo_text := "Combo: x%d" % maxi(1, _note_chase_combo_mult)
		var shield_text := ("%.1fs" % _note_chase_shield_timer) if _note_chase_shield_timer > 0.0 else "0s"
		if _note_chase_target_label != null:
			_note_chase_target_label.text = target_text
		if _note_chase_speed_label != null:
			_note_chase_speed_label.text = speed_text
		if _note_chase_combo_label != null:
			_note_chase_combo_label.text = combo_text
		if _note_chase_shield_label != null:
			_note_chase_shield_label.text = shield_text
		if _note_chase_side_target_label != null:
			_note_chase_side_target_label.text = target_text
		if _note_chase_side_speed_label != null:
			_note_chase_side_speed_label.text = speed_text
		if _note_chase_side_combo_label != null:
			_note_chase_side_combo_label.text = combo_text
		if _note_chase_side_shield_label != null:
			_note_chase_side_shield_label.text = shield_text
		_set_note_chase_bottom_metric(_note_chase_bottom_target_label, "♪", ", ".join(_note_chase_selected_notes))
		_set_note_chase_bottom_metric(_note_chase_bottom_speed_label, "⚡", "%.1fx" % _note_chase_speed_multiplier())
		_set_note_chase_bottom_metric(_note_chase_bottom_combo_label, "xP", "x%d" % maxi(1, _note_chase_combo_mult))
		_set_note_chase_bottom_metric(_note_chase_bottom_shield_label, "🛡", shield_text)
		if _note_chase_level_label != null:
			_note_chase_level_label.text = "Level %d" % (_note_chase_speed_stage + 1)
		if _streak_label != null:
			_streak_label.visible = false
		if _xp_label != null:
			_xp_label.visible = false
		if _note_chase_target_box != null:
			_note_chase_target_box.visible = false
		if _note_chase_speed_box != null:
			_note_chase_speed_box.visible = false
		if _note_chase_combo_box != null:
			_note_chase_combo_box.visible = false
		if _note_chase_shield_box != null:
			_note_chase_shield_box.visible = false
		if _note_chase_side_panel != null:
			_note_chase_side_panel.visible = false
		if _note_chase_bottom_row != null:
			_note_chase_bottom_row.visible = true
		if _note_chase_bottom_spacer != null:
			_note_chase_bottom_spacer.visible = true
		_set_note_chase_metric_highlight(_note_chase_bottom_shield_box, _note_chase_shield_timer > 0.0)
		return
	_set_note_chase_top_text_only(false)
	if _lives_label != null:
		var shield_text := "Shield Ready" if _chicken_combo_shields > 0 else "Shield --"
		_lives_label.text = "Lives: %d | Feed: %d/%d | %s" % [_lives, _chicken_combo_charge, CHICKEN_COMBO_TARGET, shield_text]
	if _streak_label != null:
		_streak_label.text = "Streak: %d" % _streak
		_streak_label.visible = true
	if _xp_label != null:
		_xp_label.text = "Score: %d" % _xp
		_xp_label.visible = true
	if _note_chase_target_label != null:
		_note_chase_target_label.text = ""
	if _note_chase_speed_label != null:
		_note_chase_speed_label.text = ""
	if _note_chase_combo_label != null:
		_note_chase_combo_label.text = ""
	if _note_chase_shield_label != null:
		_note_chase_shield_label.text = ""
	if _note_chase_level_label != null:
		_note_chase_level_label.text = ""
	if _note_chase_side_target_label != null:
		_note_chase_side_target_label.text = ""
	if _note_chase_side_speed_label != null:
		_note_chase_side_speed_label.text = ""
	if _note_chase_side_combo_label != null:
		_note_chase_side_combo_label.text = ""
	if _note_chase_side_shield_label != null:
		_note_chase_side_shield_label.text = ""
	if _note_chase_side_panel != null:
		_note_chase_side_panel.visible = false
	if _note_chase_bottom_row != null:
		_note_chase_bottom_row.visible = false
	if _note_chase_bottom_spacer != null:
		_note_chase_bottom_spacer.visible = false
	_refresh_sight_key_label()


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
				var include_acc := _sight_accidentals_toggle != null and _sight_accidentals_toggle.button_pressed
				for triad in _sight_chord_candidates(include_acc):
					var chord_name := str(triad.get("name", ""))
					if chord_name == "":
						continue
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
	if _selected_mode == MODE_SIGHT:
		if parts.is_empty():
			return "Performance:\nN/A"
		return "Performance:\n" + "\n".join(parts)
	return "Performance: " + (" | ".join(parts) if not parts.is_empty() else "N/A")


func _performance_detail_only(perf_text: String) -> String:
	var p := perf_text.strip_edges()
	if p.begins_with("Performance:\n"):
		return p.substr("Performance:\n".length()).strip_edges()
	if p.begins_with("Performance:"):
		return p.substr("Performance:".length()).strip_edges()
	return p


func _final_quiz_result_text(total_correct: int, total_questions: int, final_score: int) -> String:
	var perf := _performance_detail_only(_session_performance_summary())
	return "Total correct: %d/%d | Final score: %d\nPerformance: %s" % [total_correct, total_questions, final_score, perf]


func _on_start_quiz_pressed() -> void:
	_awaiting_round_start = false
	if _round_start_button != null:
		_round_start_button.visible = false
		_round_start_button.disabled = true
	if _selected_mode == MODE_READ:
		_home_info_label.text = ""
		_show_game()
		await _start_read_module()
		return
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous":
		_home_info_label.text = ""
		_score = 0
		_question_index = 0
		_total_questions = 0
		_lives = 5
		_streak = 0
		_xp = 0
		_quiz_active = true
		_accepting_answer = true
		_awaiting_round_start = false
		_show_game()
		_start_continuous_sight_reading()
		_start_chicken_turn_hint_cycle()
		return

	if _selected_mode == MODE_INTERVAL:
		_active_intervals = _build_interval_pool_for_settings()
		if _active_intervals.size() < _ear_choice_count:
			_home_info_label.text = "Need at least %d interval options." % _ear_choice_count
			return
	elif _selected_mode == MODE_NOTE_CHASE:
		if _note_chase_selected_notes.is_empty():
			_home_info_label.text = "Pick at least one target note for Note Chase."
			return
	else:
		_active_intervals = []

	_home_info_label.text = ""
	if _selected_mode == MODE_SIGHT and _sight_question_spin != null:
		_total_questions = int(_sight_question_spin.value)
	else:
		_total_questions = int(_question_spin.value)
	_apply_answer_mode()
	_score = 0
	_question_index = 0
	_lives = 5 if (_selected_mode == MODE_NOTE_CHASE or (_selected_mode == MODE_SIGHT and _sight_mode == "Continuous")) else 3
	_streak = 0
	_chicken_combo_charge = 0
	_chicken_combo_shields = 0
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
	if _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD or _selected_mode == MODE_SIGHT or _selected_mode == MODE_NOTE_CHASE:
		_awaiting_round_start = true
		if _round_start_button != null:
			_round_start_button.visible = _selected_mode == MODE_SIGHT
			_round_start_button.disabled = false
		_apply_answer_mode()
		_replay_button.disabled = true
		if _selected_mode == MODE_NOTE_CHASE:
			_status_label.text = ""
		else:
			_status_label.text = "Tap Start Round when you're ready."
		return
	await _begin_next_question()


func _on_end_quiz_pressed() -> void:
	_continuous_sight_active = false
	_continuous_sight_waiting_start = false
	_clear_continuous_sight_notes()
	_set_continuous_rest_symbol_visible(false)
	if _continuous_sight_play_line != null:
		_continuous_sight_play_line.visible = false
	_in_tutorial = false
	_quiz_active = false
	_accepting_answer = false
	_cancel_chicken_turn_hint_cycle(true)
	_set_answer_buttons_enabled(false)
	_awaiting_round_start = false
	_note_chase_running = false
	_note_chase_fever_active = false
	_note_chase_boss_active = false
	_stop_note_chase_music()
	_set_note_chase_overlay("", false)
	_clear_note_chase_visual_notes()
	_set_note_chase_staff_scrolling(false)
	if _round_start_button != null:
		_round_start_button.visible = false
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
	_cancel_chicken_turn_hint_cycle(true)
	_note_chase_running = false
	_note_chase_fever_active = false
	_note_chase_boss_active = false
	_stop_note_chase_music()
	_set_note_chase_overlay("", false)
	_clear_note_chase_visual_notes()
	_set_note_chase_staff_scrolling(false)
	_set_answer_buttons_enabled(false)
	_awaiting_round_start = false
	if _round_start_button != null:
		_round_start_button.visible = false
		_round_start_button.disabled = true
	_replay_button.disabled = true
	_status_label.text = "Restarting..."
	_score = 0
	_question_index = 0
	_lives = 5 if (_selected_mode == MODE_NOTE_CHASE or (_selected_mode == MODE_SIGHT and _sight_mode == "Continuous")) else 3
	_streak = 0
	_chicken_combo_charge = 0
	_chicken_combo_shields = 0
	_xp = 0
	_last_interval_signature = ""
	_last_chord_signature = ""
	_last_sight_signature = ""
	_init_session_stats()
	_refresh_meta_ui()
	_result_box_hide()
	_quiz_active = true
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous":
		_accepting_answer = true
		_awaiting_round_start = false
		_show_game()
		_start_continuous_sight_reading()
		_start_chicken_turn_hint_cycle()
		return
	if _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD or _selected_mode == MODE_SIGHT or _selected_mode == MODE_NOTE_CHASE:
		_awaiting_round_start = true
		if _round_start_button != null:
			_round_start_button.visible = _selected_mode == MODE_SIGHT
			_round_start_button.disabled = false
		_apply_answer_mode()
		if _selected_mode == MODE_NOTE_CHASE:
			_status_label.text = ""
		else:
			_status_label.text = "Tap Start Round when you're ready."
		return
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
	var max_distractors := maxi(1, _ear_choice_count - 1)
	choices.append_array(distractors.slice(0, max_distractors))
	choices.shuffle()
	return choices


func _build_chord_choices(correct_name: String, pool: Array[String]) -> Array[String]:
	var distractors: Array[String] = []
	for name in pool:
		var n: String = str(name)
		if n != correct_name:
			distractors.append(n)
	distractors.shuffle()
	var choices: Array[String] = [correct_name]
	var max_distractors: int = maxi(0, mini(_ear_choice_count - 1, distractors.size()))
	choices.append_array(distractors.slice(0, max_distractors))
	choices.shuffle()
	return choices


func _apply_answer_mode() -> void:
	var gate_choices_for_round_start := _awaiting_round_start and (_selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD or _selected_mode == MODE_SIGHT or _selected_mode == MODE_NOTE_CHASE)
	var is_ear_mode := _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD

	if _selected_mode == MODE_INTERVAL:
		_prompt_label.text = "Choose the interval:"
	elif _selected_mode == MODE_CHORD:
		_prompt_label.text = "Choose the chord type:"
	elif _selected_mode == MODE_READ:
		_prompt_label.text = ""
	elif _selected_mode == MODE_NOTE_CHASE:
		_prompt_label.text = "Tap only target notes as they scroll."
	else:
		if _sight_mode == "Chords":
			_prompt_label.text = "Choose the chord name:"
		elif _sight_mode == "Placement":
			_prompt_label.text = "Drag note to the correct line/space:"
		elif _sight_mode == "Continuous":
			_prompt_label.text = "Press the key when note hits the line."
		else:
			_prompt_label.text = "Click the matching key:"

	if _selected_mode == MODE_SIGHT or _selected_mode == MODE_READ or _selected_mode == MODE_NOTE_CHASE:
		_replay_button.visible = false
		if _round_start_button != null:
			_round_start_button.visible = _selected_mode == MODE_SIGHT and _awaiting_round_start
		_slow_toggle.visible = false
		_sight_side_controls.visible = false
		_control_row.visible = _selected_mode == MODE_SIGHT and _awaiting_round_start
		_prompt_label.visible = ((_selected_mode == MODE_SIGHT and _sight_mode == "Placement") or _selected_mode == MODE_NOTE_CHASE) and not gate_choices_for_round_start
		_status_label.visible = _selected_mode == MODE_SIGHT and _awaiting_round_start
		_game_panel.add_theme_constant_override("separation", 2)
		_staff_note.mouse_filter = Control.MOUSE_FILTER_STOP if (_selected_mode == MODE_SIGHT and _sight_mode == "Placement") or _in_tutorial else Control.MOUSE_FILTER_IGNORE
		if _sight_container != null:
			_sight_container.alignment = BoxContainer.ALIGNMENT_BEGIN if _selected_mode == MODE_NOTE_CHASE else BoxContainer.ALIGNMENT_CENTER
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
		if _round_start_button != null:
			var needs_start := _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD or _selected_mode == MODE_SIGHT
			_round_start_button.visible = needs_start and _awaiting_round_start
		_slow_toggle.visible = true
		_sight_side_controls.visible = true
		_control_row.visible = true
		_prompt_label.visible = true
		_status_label.visible = true
		_game_panel.add_theme_constant_override("separation", 10)
	if _interval_center_top_spacer != null:
		_interval_center_top_spacer.visible = is_ear_mode
	if _interval_center_bottom_spacer != null:
		_interval_center_bottom_spacer.visible = is_ear_mode
	if _interval_prompt_top_spacer != null:
		_interval_prompt_top_spacer.visible = is_ear_mode
	if _interval_choices_top_spacer != null:
		_interval_choices_top_spacer.visible = is_ear_mode
	if _interval_choices_row != null:
		var target_row_w := clampf(get_viewport_rect().size.x * 0.60, 420.0, 900.0)
		_interval_choices_row.custom_minimum_size = Vector2(target_row_w, 0.0)
		var interval_sep := 8.0
		var shown_choices := maxf(1.0, float(_ear_choice_count))
		var choice_w := floorf((target_row_w - (interval_sep * (shown_choices - 1.0))) / shown_choices)
		for btn in _interval_choice_buttons:
			if btn != null:
				btn.custom_minimum_size = Vector2(maxf(70.0, choice_w), 52.0)
	if _sky_block != null:
		# Bird lives in _sky_block; keep this layer visible in Ear Training too.
		_sky_block.visible = true
	if _selected_mode != MODE_READ:
		var should_show_chicken_bubble := _quiz_active and not _awaiting_round_start
		if should_show_chicken_bubble:
			var now_hint := float(Time.get_ticks_msec()) / 1000.0
			if _tutorial_bubble != null and not _tutorial_bubble.visible and now_hint >= _chicken_prompt_ready_at and not _chicken_hint_locked_this_turn:
				_show_chicken_prompt_line()
		else:
			_hide_chicken_bubble()
	if _tutorial_button_row != null and _selected_mode != MODE_READ:
		_tutorial_button_row.visible = false
	if _tutorial_end_button_col != null and _selected_mode != MODE_READ:
		_tutorial_end_button_col.visible = false

	for i in _interval_choice_buttons.size():
		var btn: Button = _interval_choice_buttons[i]
		if btn == null:
			continue
		var is_active := _selected_mode == MODE_INTERVAL and not gate_choices_for_round_start and i < _ear_choice_count
		btn.visible = is_active
		btn.disabled = not is_active

	for chord_name in CHORD_INTERVALS.keys():
		if _chord_buttons.has(chord_name):
			var chord_btn: Button = _chord_buttons[chord_name]
			var show := _selected_mode == MODE_CHORD and _current_chord_choices.has(chord_name) and not gate_choices_for_round_start
			chord_btn.visible = show
			chord_btn.disabled = not show

	for note_name in _sight_key_buttons.keys():
		var k_btn: Button = _sight_key_buttons[note_name]
		var show_key := _selected_mode == MODE_SIGHT and _sight_mode == "Notes"
		k_btn.visible = show_key
		k_btn.disabled = not show_key or gate_choices_for_round_start
		k_btn.modulate = Color(1, 1, 1, 1)
	if _sight_keyboard_row != null:
		_sight_keyboard_row.visible = _selected_mode == MODE_SIGHT and _sight_mode == "Notes"
	_refresh_sight_note_key_buttons()
	if _continuous_keyboard_row != null:
		_continuous_keyboard_row.visible = _selected_mode == MODE_SIGHT and _sight_mode == "Continuous"
		_continuous_keyboard_row.custom_minimum_size = Vector2(0, 126)
		_continuous_keyboard_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_refresh_continuous_keyboard_range()
		var vp_w := get_viewport_rect().size.x
		var visible_white := 0
		for kb2 in _continuous_key_buttons:
			if kb2 != null and kb2.visible:
				visible_white += 1
		var denom := float(maxi(1, visible_white))
		var profile_now: Dictionary = _home_tokens.profile_for_viewport(get_viewport_rect().size) if _home_tokens != null else {"name": "large_phone"}
		var is_tablet_now := str(profile_now.get("name", "large_phone")) == "tablet"
		var key_min_w := 56.0 if is_tablet_now else 40.0
		var key_w := maxf(key_min_w, floorf((vp_w - 44.0) / denom) - 2.0)
		var in_continuous := _selected_mode == MODE_SIGHT and _sight_mode == "Continuous"
		for kb in _continuous_key_buttons:
			if kb == null:
				continue
			kb.disabled = not _continuous_sight_active or _continuous_sight_waiting_start or _continuous_rest_bar_active
			if not in_continuous:
				kb.visible = false
			kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			kb.custom_minimum_size.x = key_w
			_style_virtual_piano_key_button(kb)
		for bb in _continuous_black_key_buttons:
			if bb == null:
				continue
			bb.disabled = not _continuous_sight_active or _continuous_sight_waiting_start or _continuous_rest_bar_active
			if not in_continuous:
				bb.visible = false
			_style_virtual_black_key_button(bb)
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous":
		if _sight_keyboard_row != null:
			_sight_keyboard_row.visible = false

	for i in _sight_chord_choice_buttons.size():
		var sc_btn: Button = _sight_chord_choice_buttons[i]
		var show_chord_choice := _selected_mode == MODE_SIGHT and _sight_mode == "Chords"
		sc_btn.visible = show_chord_choice
		sc_btn.disabled = not show_chord_choice or gate_choices_for_round_start
		sc_btn.modulate = Color(1, 1, 1, 1)
	if _sight_key_label != null:
		_sight_key_label.visible = _selected_mode == MODE_SIGHT and (_sight_mode == "Chords" or _sight_mode == "Notes")
		_refresh_sight_key_label()

	_sight_container.visible = _selected_mode == MODE_SIGHT or _selected_mode == MODE_READ or _selected_mode == MODE_NOTE_CHASE
	if _selected_mode != MODE_NOTE_CHASE:
		_set_note_chase_staff_scrolling(false)
		_stop_note_chase_music()
		_note_chase_apply_theme()
		_set_note_chase_overlay("", false)
		_clear_note_chase_visual_notes()
	else:
		# Show colorful fixed staff immediately on entering Note Chase, even before Start Round.
		_set_note_chase_staff_scrolling(true)
		_set_note_chase_overlay("Tap Start Round When You're Ready", _awaiting_round_start)
	if _staff_note != null:
		var show_staff_note := _selected_mode != MODE_NOTE_CHASE
		if _selected_mode == MODE_SIGHT and _awaiting_round_start and not _in_tutorial:
			show_staff_note = false
		_staff_note.visible = show_staff_note
		if _selected_mode == MODE_SIGHT and _awaiting_round_start:
			for n in _staff_chord_notes:
				n.visible = false
			for lbl in _staff_chord_accidental_labels:
				if lbl != null:
					lbl.visible = false
			_clear_staff_ledger_lines()
	if _selected_mode == MODE_NOTE_CHASE:
		for n in _staff_chord_notes:
			n.visible = false
		for lbl in _staff_chord_accidental_labels:
			if lbl != null:
				lbl.visible = false
	if _sky_block != null:
		if _selected_mode == MODE_READ:
			_sky_block.custom_minimum_size = Vector2(0, 118)
		elif _selected_mode == MODE_SIGHT:
			_sky_block.custom_minimum_size = Vector2(0, 16)
		elif _selected_mode == MODE_NOTE_CHASE:
			_sky_block.custom_minimum_size = Vector2(0, 42)
		else:
			_sky_block.custom_minimum_size = Vector2(0, 140)
	if _staff_area != null:
		var vp := get_viewport_rect().size
		var is_large := vp.y >= 720.0 or vp.x >= 1100.0
		if _selected_mode == MODE_READ:
			_staff_area.custom_minimum_size = Vector2(920, 560) if is_large else Vector2(700, 430)
		elif _selected_mode == MODE_NOTE_CHASE:
			_staff_area.custom_minimum_size = Vector2(1120, 640) if is_large else Vector2(760, 470)
		elif _selected_mode == MODE_SIGHT:
			_staff_area.custom_minimum_size = Vector2(980, 460) if is_large else Vector2(760, 360)
		else:
			_staff_area.custom_minimum_size = Vector2(1040, 620) if is_large else Vector2(740, 460)
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
		_staff_clef_label.text = char(0x1D122) if _selected_clef == "Bass" else char(0x1D11E)
	_refresh_game_title()
	if _selected_mode == MODE_SIGHT or _selected_mode == MODE_READ:
		_start_sight_note_bounce()
	else:
		_stop_sight_note_bounce()
	if _selected_mode == MODE_NOTE_CHASE:
		if _streak_label != null:
			_streak_label.visible = false
		if _xp_label != null:
			_xp_label.visible = false
		if _note_chase_level_label != null:
			_note_chase_level_label.visible = true
		if _note_chase_target_label != null:
			_note_chase_target_label.visible = true
		if _note_chase_speed_label != null:
			_note_chase_speed_label.visible = true
		if _note_chase_combo_label != null:
			_note_chase_combo_label.visible = true
		if _note_chase_shield_label != null:
			_note_chase_shield_label.visible = true
	else:
		if _note_chase_level_label != null:
			_note_chase_level_label.visible = false
		if _note_chase_target_label != null:
			_note_chase_target_label.visible = false
		if _note_chase_speed_label != null:
			_note_chase_speed_label.visible = false
		if _note_chase_combo_label != null:
			_note_chase_combo_label.visible = false
		if _note_chase_shield_label != null:
			_note_chase_shield_label.visible = false
		if _note_chase_bottom_row != null:
			_note_chase_bottom_row.visible = false
	if _selected_mode == MODE_READ:
		call_deferred("_position_tutorial_button_row")
		call_deferred("_position_tutorial_title")
		call_deferred("_position_tutorial_end_buttons")


func _show_home() -> void:
	_play_transition_whoosh_sfx()
	_cancel_chicken_turn_hint_cycle(true)
	_continuous_sight_active = false
	_continuous_sight_waiting_start = false
	_clear_continuous_sight_notes()
	if _continuous_sight_play_line != null:
		_continuous_sight_play_line.visible = false
	_in_tutorial = false
	_note_chase_running = false
	_stop_note_chase_music()
	_set_note_chase_overlay("", false)
	_clear_note_chase_visual_notes()
	_set_note_chase_staff_scrolling(false)
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
	if _bird_sprite != null:
		# Re-anchor on every home return so the bird cannot stay off-screen
		# after gameplay/tweens or viewport/layout changes.
		_bird_home_global_position = _compute_bird_home_global_position()
		_bird_home_ready = true
		_bird_sprite.visible = true
		_reset_bird_position()
		_start_bird_idle_anim()
	_result_box_hide()
	_set_sight_result_background_hidden(false)
	if _title_label != null:
		_title_label.text = "Clefira"
	if _home_title_label != null:
		_home_title_label.visible = true
	_refresh_home_subtitle()
	call_deferred("_setup_home_focus_navigation")


func _show_game() -> void:
	_play_transition_whoosh_sfx()
	if _selected_mode != MODE_READ:
		_hide_chicken_bubble()
		_refresh_bird_perch_from_layout(true)
		call_deferred("_refresh_bird_perch_from_layout", true)
	_result_box_hide()
	_home_card.visible = false
	_home_panel.visible = false
	_game_card.visible = true
	_game_panel.visible = true
	if _home_title_label != null:
		_home_title_label.visible = false
	if _home_mode_back_button != null:
		_home_mode_back_button.visible = false
	_end_button.visible = true
	_restart_button.visible = true
	_hud_left_box.visible = true
	_hud_right_box.visible = true
	_hud_center_box.visible = true
	_set_sight_result_background_hidden(false)
	if _selected_mode == MODE_READ:
		_hud_left_box.visible = false
		_hud_right_box.visible = false
		_hud_center_box.visible = false
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
	_refresh_game_title()
	_refresh_sight_key_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st_any := event as InputEventScreenTouch
		if st_any.pressed and _try_handle_continuous_touch_key(st_any.position):
			get_viewport().set_input_as_handled()
			return
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous" and _continuous_sight_active and _continuous_sight_waiting_start:
		if event is InputEventScreenTouch:
			var st_start := event as InputEventScreenTouch
			if st_start.pressed:
				_continuous_sight_waiting_start = false
				_continuous_sight_spawn_timer = 0.0
				_seed_continuous_stream_near_line()
				_status_label.text = "Press the key when note hits the line."
				_apply_answer_mode()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton:
			var mb_start := event as InputEventMouseButton
			if mb_start.button_index == MOUSE_BUTTON_LEFT and mb_start.pressed:
				_continuous_sight_waiting_start = false
				_continuous_sight_spawn_timer = 0.0
				_seed_continuous_stream_near_line()
				_status_label.text = "Press the key when note hits the line."
				_apply_answer_mode()
				get_viewport().set_input_as_handled()
				return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_note_dragging:
		return
	if _game_panel != null and _game_panel.visible:
		_on_end_quiz_pressed()
		get_viewport().set_input_as_handled()
		return
	if _ear_settings_screen_active:
		_on_ear_settings_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if _sight_settings_screen_active:
		_on_sight_settings_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if _home_mode_detail_active:
		_on_home_mode_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if _home_flow == "Learn":
		_on_home_hub_pressed("Practice")
		get_viewport().set_input_as_handled()
		return
	if _selected_mode != MODE_INTERVAL and _selected_mode != MODE_CHORD:
		_on_mode_button_pressed(MODE_INTERVAL)
		get_viewport().set_input_as_handled()


func _set_sight_result_background_hidden(hidden: bool) -> void:
	if _selected_mode != MODE_SIGHT:
		return
	if _sight_container != null:
		_sight_container.visible = not hidden
	if _staff_area != null:
		_staff_area.visible = not hidden
	if _note_chase_staff_frame != null and hidden:
		_note_chase_staff_frame.visible = false


func _refresh_game_title() -> void:
	if _title_label == null:
		return
	_title_label.text = "Clefira"


func _sight_key_signature_display_text() -> String:
	match _sight_key_signature:
		"2#":
			return "Key: D Major / B Minor"
		"3#":
			return "Key: A Major / F# Minor"
		"2b":
			return "Key: Bb Major / G Minor"
		"3b":
			return "Key: Eb Major / C Minor"
		_:
			return "Key: C Major / A Minor"


func _refresh_sight_key_label() -> void:
	if _sight_key_label == null:
		return
	_sight_key_label.text = _sight_key_signature_display_text()
	_sight_key_label.visible = _selected_mode == MODE_SIGHT and (_sight_mode == "Chords" or _sight_mode == "Notes")


func _start_read_module() -> void:
	_in_tutorial = true
	_cancel_chicken_turn_hint_cycle(true)
	_tutorial_run_id += 1
	_tutorial_module_recorded = false
	_quiz_active = true
	_accepting_answer = false
	_awaiting_round_start = false
	if _round_start_button != null:
		_round_start_button.visible = false
		_round_start_button.disabled = true
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
		_tutorial_chicken.position = Vector2(18, 44)
	if _tutorial_bubble != null:
		_tutorial_bubble.position = Vector2(146, 18)
	if _tutorial_bubble_tail != null:
		_tutorial_bubble_tail.position = Vector2(174, 120)
	if step == 0:
		if _tutorial_chicken != null:
			_tutorial_chicken.position = Vector2(18, 64)
		if _tutorial_bubble != null:
			_tutorial_bubble.position = Vector2(146, 42)
		if _tutorial_bubble_tail != null:
			_tutorial_bubble_tail.position = Vector2(174, 144)
	if step == 1:
		if _tutorial_chicken != null:
			_tutorial_chicken.position = Vector2(18, 56)
		if _tutorial_bubble != null:
			_tutorial_bubble.position = Vector2(146, 36)
		if _tutorial_bubble_tail != null:
			_tutorial_bubble_tail.position = Vector2(174, 136)


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
	for lbl in _staff_chord_accidental_labels:
		if lbl != null:
			lbl.visible = false
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
				_play_module_complete_sfx()
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


func _start_note_chase_round() -> void:
	_note_chase_running = false
	if _note_chase_clef_mode == "Treble" or _note_chase_clef_mode == "Bass":
		_selected_clef = _note_chase_clef_mode
	else:
		_selected_clef = "Treble"
	_refresh_note_chase_clef_buttons()
	_refresh_clef_buttons()
	_note_chase_staff_scroll_x = 0.0
	_set_note_chase_staff_scrolling(true)
	_note_chase_spawn_timer = 0.0
	_note_chase_correct_clicks = 0
	_note_chase_correct_streak = 0
	_note_chase_wrongs = 0
	_note_chase_speed_stage = 0
	_note_chase_fever_active = false
	_note_chase_fever_timer = 0.0
	_note_chase_boss_active = false
	_note_chase_boss_timer = 0.0
	_note_chase_boss_last_stage = -1
	_note_chase_last_theme_stage = -1
	_note_chase_clef_switch_cd = 0.0
	_note_chase_freeze_timer = 0.0
	_note_chase_shield_timer = 0.0
	_note_chase_combo_mult = 1
	_note_chase_last_spawn_note = ""
	_note_chase_target_spawn_streak = 0
	_note_chase_spawned = 0
	_note_chase_elapsed = 0.0
	_note_chase_active_notes.clear()
	_clear_note_chase_visual_notes()
	_apply_note_chase_speed_from_option()
	_set_answer_buttons_enabled(false)
	_accepting_answer = false
	_replay_button.disabled = true
	_restart_button.disabled = false
	_score_label.text = "Score: 0"
	_progress_label.text = ""
	_status_label.text = "3"
	await get_tree().create_timer(0.45).timeout
	if not _quiz_active or _selected_mode != MODE_NOTE_CHASE:
		return
	_status_label.text = "2"
	await get_tree().create_timer(0.45).timeout
	if not _quiz_active or _selected_mode != MODE_NOTE_CHASE:
		return
	_status_label.text = "1"
	await get_tree().create_timer(0.45).timeout
	if not _quiz_active or _selected_mode != MODE_NOTE_CHASE:
		return
	_status_label.text = "Go!"
	await _play_new_question_cue()
	_start_note_chase_music()
	_note_chase_running = true
	_accepting_answer = true


func _apply_note_chase_speed_from_option() -> void:
	# Speed selector removed from menu; keep default "Normal" profile.
	_note_chase_base_scroll_speed = 82.0
	_note_chase_base_spawn_interval = 1.38
	_note_chase_apply_speed_stage()


func _note_chase_apply_speed_stage() -> void:
	var multiplier := _note_chase_speed_multiplier()
	_note_chase_scroll_speed = _note_chase_base_scroll_speed * multiplier
	# Softer acceleration curve so difficulty ramps up less aggressively.
	var spawn_mult := 1.0 + ((multiplier - 1.0) * 0.28)
	if _note_chase_speed_stage >= 7:
		# After level 7, increase spawn frequency each level.
		spawn_mult += 0.08 * float(_note_chase_speed_stage - 6)
	_note_chase_spawn_interval = maxf(0.52, _note_chase_base_spawn_interval / maxf(1.0, spawn_mult))
	_apply_note_chase_staff_colors()
	_note_chase_apply_theme()
	_note_chase_refresh_progress_text()
	if _note_chase_speed_stage > 0 and _note_chase_speed_stage % 3 == 0 and _note_chase_boss_last_stage != _note_chase_speed_stage:
		_note_chase_start_boss_round()
	if _note_chase_last_theme_stage != _note_chase_speed_stage:
		_note_chase_last_theme_stage = _note_chase_speed_stage
		_play_note_chase_stage_motif(_note_chase_speed_stage)


func _note_chase_speed_multiplier() -> float:
	var stage := mini(_note_chase_speed_stage, 12)
	var curve := [1.18, 1.62, 1.66, 1.84, 2.02, 2.24, 2.46, 2.68, 2.90, 3.12, 3.34, 3.56, 3.78]
	var mul := float(curve[stage])
	if stage >= 5:
		# Slight extra speed bump from level 6 onward.
		mul += 0.04 * float(stage - 4)
	return mul


func _note_chase_points_per_note() -> int:
	return 10 + (_note_chase_speed_stage * 2)


func _set_note_chase_overlay(text: String, visible: bool) -> void:
	if _note_chase_overlay == null or _note_chase_overlay_label == null:
		return
	_note_chase_overlay.visible = visible
	_note_chase_overlay_label.text = text if visible else ""


func _note_chase_stage_note_color() -> Color:
	if NOTE_CHASE_NOTE_COLORS.is_empty():
		return Color(0.99, 0.99, 0.99, 0.97)
	return NOTE_CHASE_NOTE_COLORS[_note_chase_speed_stage % NOTE_CHASE_NOTE_COLORS.size()]


func _note_chase_target_bias() -> float:
	var selected_count := maxi(1, _note_chase_selected_notes.size())
	var base := 0.72
	if selected_count == 2:
		base = 0.60
	elif selected_count >= 3:
		base = 0.48
	if _note_chase_boss_active:
		base += 0.10
	return clampf(base, 0.35, 0.86)


func _note_chase_decoy_chance() -> float:
	if _note_chase_speed_stage < 2:
		return 0.0
	var c := 0.10 + (0.02 * float(_note_chase_speed_stage - 2))
	if _note_chase_boss_active:
		c += 0.08
	return clampf(c, 0.0, 0.34)


func _note_chase_rainbow_chance() -> float:
	if _note_chase_speed_stage < 3:
		return 0.0
	var c := 0.07 + (0.01 * float(_note_chase_speed_stage - 3))
	# Slightly increase rainbow chance after level 7, then a bit more after level 10.
	if _note_chase_speed_stage >= 6:
		c += 0.012
	if _note_chase_speed_stage >= 9:
		c += 0.016
	return clampf(c, 0.0, 0.16)


func _note_chase_score_multiplier() -> float:
	var mul := 1.0
	if _note_chase_fever_active:
		mul *= 2.0
	if _note_chase_boss_active:
		mul *= 2.0
	mul *= float(maxi(1, _note_chase_combo_mult))
	return mul


func _note_chase_refresh_progress_text() -> void:
	var parts: Array[String] = []
	if _note_chase_freeze_timer > 0.0:
		parts.append("Freeze %.1fs" % _note_chase_freeze_timer)
	if _note_chase_fever_active:
		parts.append("Fever %.1fs" % _note_chase_fever_timer)
	if _note_chase_boss_active:
		parts.append("Boss %.1fs" % _note_chase_boss_timer)
	_progress_label.text = " | ".join(parts) if not parts.is_empty() else ""
	_refresh_meta_ui()


func _note_chase_start_fever() -> void:
	_note_chase_fever_active = true
	_note_chase_fever_timer = 5.0
	_status_label.text = "Fever! 2x points"
	_note_chase_refresh_progress_text()


func _note_chase_start_boss_round() -> void:
	_note_chase_boss_active = true
	_note_chase_boss_timer = 20.0
	_note_chase_boss_last_stage = _note_chase_speed_stage
	_status_label.text = "Boss Round! Dense targets + bonus points"
	_play_powerup_sfx()
	_note_chase_refresh_progress_text()


func _note_chase_apply_note_style(panel: Panel, is_target: bool, decoy: bool, rainbow: bool = false) -> void:
	if panel == null:
		return
	var base_color: Color = _note_chase_stage_note_color() if not rainbow else NOTE_CHASE_NOTE_COLORS[_rng.randi_range(0, NOTE_CHASE_NOTE_COLORS.size() - 1)]
	var border_color: Color = Color(0.0, 0.0, 0.0, 0.95)
	if rainbow:
		border_color = Color(1.0, 0.95, 0.55, 1.0)
	elif is_target or decoy:
		border_color = Color(0.94, 0.80, 0.24, 0.95)
	_apply_notehead_material(panel, base_color, border_color)


func _note_chase_fade_out_control(node: Control, duration: float = 0.22) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("nc_fading") and bool(node.get_meta("nc_fading")):
		return
	node.set_meta("nc_fading", true)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(node, "scale", node.scale * Vector2(0.96, 0.96), duration)


func _note_chase_attach_ledgers(panel: Panel, step: int) -> void:
	if panel == null:
		return
	var ledger_steps := _ledger_steps_for_note_step(step)
	if ledger_steps.is_empty():
		return
	for s in ledger_steps:
		var led := ColorRect.new()
		led.color = Color(1.0, 0.47, 0.73, 1.0)
		led.size = Vector2(96, 3)
		var y_abs := _staff_center_y_for_step(s)
		led.position = Vector2((panel.size.x * 0.5) - (led.size.x * 0.5), y_abs - panel.position.y - (led.size.y * 0.5))
		led.mouse_filter = Control.MOUSE_FILTER_IGNORE
		led.z_index = -1
		led.show_behind_parent = true
		panel.add_child(led)


func _note_chase_add_rainbow_aura(panel: Panel) -> void:
	if panel == null:
		return
	var aura := Panel.new()
	aura.size = panel.size + Vector2(20, 20)
	aura.position = Vector2(-10, -10)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.92, 0.45, 0.92)
	aura.add_theme_stylebox_override("panel", sb)
	panel.add_child(aura)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(aura, "modulate:a", 0.45, 0.35)
	tw.tween_property(aura, "modulate:a", 1.0, 0.35)


func _note_chase_add_special_aura(panel: Panel, glow_color: Color) -> void:
	if panel == null:
		return
	var aura := Panel.new()
	aura.size = panel.size + Vector2(22, 22)
	aura.position = Vector2(-11, -11)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = glow_color
	aura.add_theme_stylebox_override("panel", sb)
	panel.add_child(aura)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(aura, "modulate:a", 0.40, 0.30)
	tw.tween_property(aura, "modulate:a", 1.0, 0.30)


func _note_chase_spawn_pop_effect(center: Vector2, color: Color) -> void:
	if _staff_area == null:
		return
	for i in range(7):
		var b := Panel.new()
		b.size = Vector2(8, 8)
		b.position = center + Vector2(-4, -4)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		b.add_theme_stylebox_override("panel", sb)
		_staff_area.add_child(b)
		var ang := (TAU * float(i) / 7.0) + _rng.randf_range(-0.22, 0.22)
		var dist := 26.0 + _rng.randf() * 12.0
		var target := b.position + Vector2(cos(ang), sin(ang)) * dist
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", target, 0.22)
		tw.parallel().tween_property(b, "modulate:a", 0.0, 0.22)
		tw.finished.connect(func() -> void:
			if is_instance_valid(b):
				b.queue_free()
		)


func _note_chase_spawn_note_name_text(center: Vector2, text: String, color: Color) -> void:
	if _staff_area == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(56, 28)
	lbl.position = center + Vector2(-28, -30)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	lbl.add_theme_constant_override("outline_size", 4)
	_staff_area.add_child(lbl)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 20.0, 0.34)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.34)
	tw.finished.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func _note_chase_apply_level_reward() -> void:
	_note_chase_combo_mult += 2
	if _lives < 5:
		_lives += 1
		_status_label.text = "Level up! +1 Life | Combo x%d" % _note_chase_combo_mult
	else:
		_score += 25
		_status_label.text = "Level up! +25 Bonus | Combo x%d" % _note_chase_combo_mult
	_score_label.text = "Score: %d" % _score
	_refresh_meta_ui()
	_note_chase_refresh_progress_text()


func _spawn_note_chase_special(kind: String) -> void:
	if _staff_area == null:
		return
	var steps := _note_chase_step_pool()
	var step := steps[_rng.randi_range(0, steps.size() - 1)]
	var y := _staff_center_y_for_step(step)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(46, 34)
	p.size = Vector2(46, 34)
	p.position = Vector2(_note_chase_spawn_x() + 8.0, y - 17.0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.92, 0.96, 0.96)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.08, 0.10, 0.16, 0.9)
	if kind == "shield":
		sb.border_color = Color(0.38, 0.78, 1.0, 1.0)
	else:
		sb.border_color = Color(1.0, 0.82, 0.35, 1.0)
	p.add_theme_stylebox_override("panel", sb)
	var icon := Label.new()
	icon.set_anchors_preset(PRESET_FULL_RECT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.text = "🛡" if kind == "shield" else "𝄽"
	icon.add_theme_font_size_override("font_size", 23)
	icon.add_theme_color_override("font_color", Color(0.08, 0.10, 0.16, 1.0))
	p.add_child(icon)
	if kind == "freeze":
		_note_chase_add_special_aura(p, Color(1.0, 0.62, 0.22, 0.95))
	p.gui_input.connect(_on_note_chase_note_gui_input.bind(p))
	_staff_area.add_child(p)
	_note_chase_play_spawn_bubble_anim(p)
	_note_chase_active_notes.append({
		"node": p,
		"kind": kind,
		"note": "Shield" if kind == "shield" else "Time",
		"spawn_t": _note_chase_elapsed,
		"target": false,
		"hit": false
	})


func _spawn_note_chase_clef_switch() -> void:
	if _staff_area == null:
		return
	var next_clef := "Bass" if _selected_clef == "Treble" else "Treble"
	var p := Panel.new()
	p.custom_minimum_size = Vector2(54, 70)
	p.size = Vector2(54, 70)
	p.position = Vector2(_note_chase_spawn_x() + 8.0, _active_staff_top_y() + _active_staff_line_gap_y() - 18.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.set_anchors_preset(PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = "𝄢" if next_clef == "Bass" else "𝄞"
	lbl.add_theme_font_size_override("font_size", 128)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.86, 0.98))
	p.add_child(lbl)
	_staff_area.add_child(p)
	if _staff_clef_label != null:
		_staff_clef_label.visible = false
	_note_chase_play_spawn_bubble_anim(p)
	_note_chase_active_notes.append({
		"node": p,
		"kind": "clef",
		"next_clef": next_clef,
		"spawn_t": _note_chase_elapsed,
		"triggered": false,
		"hit": false
	})
	_note_chase_clef_switch_cd = 9.0 + _rng.randf() * 4.0


func _note_chase_capture_targets_with_rainbow(skip_node: Panel) -> int:
	var captured := 0
	for i in range(_note_chase_active_notes.size()):
		var n: Dictionary = _note_chase_active_notes[i]
		if bool(n.get("hit", false)):
			continue
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var p := node_obj as Panel
		if p == null or p == skip_node:
			continue
		var kind := str(n.get("kind", "note"))
		if kind != "note":
			continue
		var is_target := bool(n.get("target", false))
		var is_rainbow := bool(n.get("rainbow", false))
		if not is_target and not is_rainbow:
			continue
		_note_chase_spawn_pop_effect(p.position + (p.size * 0.5), Color(1.0, 0.92, 0.45, 1.0))
		n["hit"] = true
		_note_chase_active_notes[i] = n
		_note_chase_fade_out_control(p, 0.16)
		captured += 1
	return captured


func _note_chase_apply_theme() -> void:
	if _sky_area != null:
		if _selected_mode == MODE_NOTE_CHASE:
			var tint: Color = NOTE_CHASE_THEME_TINTS[_note_chase_speed_stage % NOTE_CHASE_THEME_TINTS.size()]
			_sky_area.modulate = tint
		else:
			_sky_area.modulate = Color(1, 1, 1, 1)


func _play_note_chase_stage_motif(stage: int) -> void:
	if _selected_mode != MODE_NOTE_CHASE or not _quiz_active:
		return
	var motifs := [
		[60, 64, 67],
		[62, 65, 69],
		[64, 67, 71],
		[65, 69, 72],
		[67, 71, 74],
		[69, 72, 76],
		[71, 74, 77]
	]
	var pick: Array = motifs[stage % motifs.size()]
	for midi_note in pick:
		await _play_note(int(midi_note), 0.07)
		await _push_silence(0.012)


func _apply_note_chase_staff_colors() -> void:
	if _staff_lines.is_empty():
		return
	var colorize := _selected_mode == MODE_NOTE_CHASE
	for i in range(_staff_lines.size()):
		var line := _staff_lines[i]
		if line != null:
			if colorize and not NOTE_CHASE_STAFF_COLORS.is_empty():
				var c: Color = NOTE_CHASE_STAFF_COLORS[(i + _note_chase_speed_stage) % NOTE_CHASE_STAFF_COLORS.size()]
				line.color = c
			else:
				line.color = Color(1.0, 1.0, 1.0, 0.95)
		if i < _note_chase_staff_clone_lines.size():
			var clone := _note_chase_staff_clone_lines[i]
			if clone != null:
				if colorize and not NOTE_CHASE_STAFF_COLORS.is_empty():
					var cc: Color = NOTE_CHASE_STAFF_COLORS[(i + _note_chase_speed_stage) % NOTE_CHASE_STAFF_COLORS.size()]
					clone.color = cc
				else:
					clone.color = Color(1.0, 1.0, 1.0, 0.95)


func _note_chase_step_for_letter(letter: String) -> int:
	for step in range(0, 9):
		if _staff_step_name_for_clef(step, _selected_clef) == letter:
			return step
	return 4


func _note_chase_step_pool() -> Array[int]:
	var pool: Array[int] = []
	var stage := _note_chase_speed_stage # stage 0 == level 1
	if _selected_clef == "Bass":
		# Base level (L1): include B3 explicitly.
		for s in range(-2, 6):
			if not pool.has(s):
				pool.append(s)
		if not pool.has(-1):
			pool.append(-1) # B3 (must appear at level 1)
		# Level 1+: include upper bass edge notes D4/E4.
		if stage >= 0:
			if not pool.has(-3):
				pool.append(-3) # D4
			if not pool.has(-4):
				pool.append(-4) # E4
		# Level 6+: add lower ledger notes D2/C2.
		if stage >= 5:
			if not pool.has(11):
				pool.append(11) # D2
			if not pool.has(12):
				pool.append(12) # C2
		# Keep broader range available as difficulty rises.
		if stage >= 1:
			for s in range(6, 11):
				if not pool.has(s):
					pool.append(s)
	else:
		# Base level (L1): include D4 explicitly.
		for s in range(4, 11):
			if not pool.has(s):
				pool.append(s)
		if not pool.has(9):
			pool.append(9) # D4 (must appear at level 1)
		# Level 1+: include lower ledger notes B3/A3.
		if stage >= 0:
			if not pool.has(11):
				pool.append(11) # B3
			if not pool.has(12):
				pool.append(12) # A3
			for s in range(-3, 4):
				if not pool.has(s):
					pool.append(s)
		# Level 6+: add upper ledger notes C6/B6.
		if stage >= 5:
			if not pool.has(-4):
				pool.append(-4) # C6
	var safe_top := _note_chase_safe_y_top()
	var safe_bottom := _note_chase_safe_y_bottom()
	var filtered: Array[int] = []
	for s in pool:
		var y := _staff_center_y_for_step(s)
		if y >= safe_top and y <= safe_bottom:
			filtered.append(s)
	# Ensure required milestone notes remain available even near safe-edge areas.
	var required_steps: Array[int] = []
	if _selected_clef == "Bass":
		required_steps.append(-1) # B3 level 1
		if stage >= 0:
			required_steps.append(-3) # D4 level 3+
			required_steps.append(-4) # E4 level 3+
		if stage >= 5:
			required_steps.append(11) # D2 level 6+
			required_steps.append(12) # C2 level 6+
	else:
		required_steps.append(9) # D4 level 1
		if stage >= 0:
			required_steps.append(11) # B3 level 2+
			required_steps.append(12) # A3 level 2+
		if stage >= 5:
			required_steps.append(-4) # C6 level 6+
	for rs in required_steps:
		if pool.has(rs) and not filtered.has(rs):
			filtered.append(rs)
	# Absolute clef bounds for Note Chaser:
	# Treble max high note C6 (step -4), Bass max low note C2 (step 12).
	var bounded: Array[int] = []
	for s in filtered:
		if _selected_clef == "Treble":
			if s < -4:
				continue
		elif _selected_clef == "Bass":
			if s > 12:
				continue
		bounded.append(s)
	filtered = bounded
	if not filtered.is_empty():
		return filtered
	if pool.is_empty():
		pool = [4, 5, 6, 7, 8]
	return pool


func _note_chase_safe_y_top() -> float:
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		return _note_chase_staff_frame.position.y + 72.0
	return _active_staff_top_y() - (_active_staff_step_y() * 1.2)


func _note_chase_safe_y_bottom() -> float:
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		return (_note_chase_staff_frame.position.y + _note_chase_staff_frame.size.y) - 88.0
	return (_active_staff_top_y() + (_active_staff_line_gap_y() * 4.0)) + (_active_staff_step_y() * 1.6)


func _note_chase_spawn_x() -> float:
	if _staff_area == null:
		return STAFF_LEFT_X + (STAFF_LINE_WIDTH * 0.75)
	var usable := maxf(240.0, _staff_area.size.x - STAFF_LEFT_X)
	return STAFF_LEFT_X + (usable * 0.75)


func _note_chase_end_x() -> float:
	if _staff_area == null:
		return STAFF_LEFT_X + (STAFF_LINE_WIDTH * 0.20)
	var usable := maxf(240.0, _staff_area.size.x - STAFF_LEFT_X)
	return STAFF_LEFT_X + (usable * 0.20)


func _note_chase_play_spawn_bubble_anim(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.35, 0.35)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.10)
	tw.tween_property(panel, "scale", Vector2(1.14, 1.14), 0.10)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.08)


func _note_chase_relabel_active_notes_for_clef() -> void:
	for i in range(_note_chase_active_notes.size()):
		var n: Dictionary = _note_chase_active_notes[i]
		if str(n.get("kind", "note")) != "note":
			continue
		if bool(n.get("hit", false)):
			continue
		var step_v = n.get("step", null)
		if step_v == null:
			continue
		var step_i := int(step_v)
		var note_name := _staff_step_name_for_clef(step_i, _selected_clef)
		n["note"] = note_name
		var is_target := _note_chase_selected_notes.has(note_name)
		n["target"] = is_target
		if bool(n.get("rainbow", false)) and not is_target:
			n["rainbow"] = false
		var node_obj = n.get("node", null)
		if node_obj != null and is_instance_valid(node_obj):
			var panel := node_obj as Panel
			if panel != null:
				_note_chase_apply_note_style(panel, is_target, bool(n.get("decoy", false)), bool(n.get("rainbow", false)))
		_note_chase_active_notes[i] = n


func _note_chase_visible_target_count() -> int:
	var count := 0
	for item in _note_chase_active_notes:
		var n: Dictionary = item
		if bool(n.get("hit", false)):
			continue
		if str(n.get("kind", "note")) != "note":
			continue
		if not bool(n.get("target", false)):
			continue
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var panel := node_obj as Panel
		if panel == null:
			continue
		if panel.position.x + panel.size.x < STAFF_LEFT_X:
			continue
		if panel.position.x > _note_chase_spawn_x() + 8.0:
			continue
		count += 1
	return count


func _note_chase_has_active_special(kind: String) -> bool:
	for item in _note_chase_active_notes:
		var n: Dictionary = item
		if bool(n.get("hit", false)):
			continue
		var note_kind := str(n.get("kind", ""))
		if kind == "rainbow":
			if note_kind != "note" or not bool(n.get("rainbow", false)):
				continue
		elif note_kind != kind:
			continue
		var node_obj = n.get("node", null)
		if node_obj != null and is_instance_valid(node_obj):
			return true
	return false


func _note_chase_next_spawn_x_with_spacing(base_x: float, min_gap: float = 58.0) -> float:
	var x := base_x
	for _i in range(16):
		var overlap := false
		for item in _note_chase_active_notes:
			var n: Dictionary = item
			if bool(n.get("hit", false)):
				continue
			if str(n.get("kind", "note")) == "clef":
				continue
			var node_obj = n.get("node", null)
			if node_obj == null or not is_instance_valid(node_obj):
				continue
			var panel := node_obj as Panel
			if panel == null:
				continue
			if absf(panel.position.x - x) < min_gap:
				x = panel.position.x + min_gap
				overlap = true
				break
		if not overlap:
			break
	return x


func _note_chase_item_speed_multiplier(n: Dictionary) -> float:
	var kind := str(n.get("kind", "note"))
	if kind == "clef":
		return 1.65
	if kind == "shield":
		return 1.55
	if kind == "freeze":
		return 0.88
	if kind == "note" and bool(n.get("rainbow", false)):
		return 1.22
	return 1.0


func _note_chase_has_untriggered_clef_token() -> bool:
	for item in _note_chase_active_notes:
		var n: Dictionary = item
		if bool(n.get("hit", false)):
			continue
		if str(n.get("kind", "")) != "clef":
			continue
		if bool(n.get("triggered", false)):
			continue
		var node_obj = n.get("node", null)
		if node_obj != null and is_instance_valid(node_obj):
			return true
	return false


func _note_chase_clear_recent_notes_after_clef_switch(_trigger_x: float, recent_seconds: float = 2.0) -> int:
	var kept: Array[Dictionary] = []
	var removed_notes := 0
	var spawn_cutoff_x := _note_chase_spawn_x() - 24.0
	for item in _note_chase_active_notes:
		var n: Dictionary = item
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var panel := node_obj as Panel
		if panel == null:
			continue
		var kind := str(n.get("kind", "note"))
		if kind == "clef":
			kept.append(n)
			continue
		var spawn_t := float(n.get("spawn_t", -9999.0))
		var age := _note_chase_elapsed - spawn_t
		var near_spawn_zone := panel.position.x >= spawn_cutoff_x
		if age <= recent_seconds or near_spawn_zone:
			if kind == "note":
				removed_notes += 1
			panel.queue_free()
			continue
		kept.append(n)
	_note_chase_active_notes = kept
	return removed_notes


func _spawn_note_chase_note(spawn_x_offset: float = 0.0) -> void:
	if _staff_area == null:
		return
	var visible_targets := _note_chase_visible_target_count()
	if _note_chase_speed_stage >= 1 and _rng.randf() < 0.035:
		_spawn_note_chase_special("shield")
		return
	if _note_chase_speed_stage >= 3 and visible_targets > 1 and _note_chase_freeze_timer <= 0.0 and not _note_chase_has_active_special("freeze") and _rng.randf() < 0.009:
		_spawn_note_chase_special("freeze")
		return
	if _note_chase_clef_mode == "Both" and _note_chase_speed_stage >= 3 and _note_chase_clef_switch_cd <= 0.0 and _rng.randf() < 0.02:
		_spawn_note_chase_clef_switch()
		return
	var steps := _note_chase_step_pool()
	var target_steps: Array[int] = []
	var non_target_steps: Array[int] = []
	for s in steps:
		var n_name := _staff_step_name_for_clef(s, _selected_clef)
		if _note_chase_selected_notes.has(n_name):
			target_steps.append(s)
		else:
			non_target_steps.append(s)
	var prefer_target := _rng.randf() < _note_chase_target_bias()
	if not target_steps.is_empty() and not non_target_steps.is_empty() and _note_chase_target_spawn_streak >= 3:
		prefer_target = false
	var step := steps[_rng.randi_range(0, steps.size() - 1)]
	if prefer_target and not target_steps.is_empty():
		step = target_steps[_rng.randi_range(0, target_steps.size() - 1)]
	elif not non_target_steps.is_empty():
		step = non_target_steps[_rng.randi_range(0, non_target_steps.size() - 1)]
	var note_name := _staff_step_name_for_clef(step, _selected_clef)
	if _note_chase_last_spawn_note != "":
		for _k in range(12):
			if note_name != _note_chase_last_spawn_note:
				break
			if prefer_target and not target_steps.is_empty():
				step = target_steps[_rng.randi_range(0, target_steps.size() - 1)]
			elif not non_target_steps.is_empty():
				step = non_target_steps[_rng.randi_range(0, non_target_steps.size() - 1)]
			else:
				step = steps[_rng.randi_range(0, steps.size() - 1)]
			note_name = _staff_step_name_for_clef(step, _selected_clef)
	var is_target := _note_chase_selected_notes.has(note_name)
	if is_target:
		_note_chase_target_spawn_streak += 1
	else:
		_note_chase_target_spawn_streak = 0
	var y := _staff_center_y_for_step(step)
	var decoy_chance := _note_chase_decoy_chance()
	var is_decoy := (not is_target) and (_rng.randf() < decoy_chance)
	var is_rainbow := false
	var rainbow_spawn_mul := 0.16
	if _note_chase_speed_stage >= 9:
		rainbow_spawn_mul = 0.24
	if _note_chase_speed_stage >= 11:
		rainbow_spawn_mul = 0.28
	if is_target and not _note_chase_has_active_special("rainbow") and _rng.randf() < (_note_chase_rainbow_chance() * rainbow_spawn_mul):
		is_rainbow = true

	var p := Panel.new()
	p.custom_minimum_size = Vector2(68, 50)
	p.size = Vector2(68, 50)
	p.z_index = 160
	var spawn_x := _note_chase_next_spawn_x_with_spacing(_note_chase_spawn_x() + 8.0 + spawn_x_offset)
	p.position = Vector2(spawn_x, y - 25.0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_note_chase_apply_note_style(p, is_target, is_decoy, is_rainbow)
	_note_chase_attach_ledgers(p, step)
	if is_rainbow:
		_note_chase_add_rainbow_aura(p)
	p.gui_input.connect(_on_note_chase_note_gui_input.bind(p))
	_staff_area.add_child(p)
	_note_chase_play_spawn_bubble_anim(p)
	_note_chase_active_notes.append({
		"node": p,
		"note": note_name,
		"step": step,
		"spawn_t": _note_chase_elapsed,
		"target": is_target,
		"kind": "note",
		"decoy": is_decoy,
		"rainbow_special": is_rainbow,
		"rainbow": is_rainbow,
		"hit": false
	})
	_question_index += 1
	_note_chase_last_spawn_note = note_name
	_note_chase_refresh_progress_text()


func _on_note_chase_note_gui_input(event: InputEvent, note_panel: Panel) -> void:
	if not _note_chase_running or not _quiz_active or _selected_mode != MODE_NOTE_CHASE:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in range(_note_chase_active_notes.size()):
		var n: Dictionary = _note_chase_active_notes[i]
		if n.get("node", null) != note_panel:
			continue
		if bool(n.get("hit", false)):
			return
		var click_cd := float(n.get("click_cd", 0.0))
		if click_cd > 0.0:
			return
		var kind := str(n.get("kind", "note"))
		var note_text := str(n.get("note", ""))
		var pop_center := note_panel.position + (note_panel.size * 0.5)
		_note_chase_spawn_note_name_text(pop_center, note_text, Color(1.0, 0.96, 0.88, 1.0))
		if kind == "shield":
			n["hit"] = true
			_note_chase_shield_timer += 10.0
			_status_label.text = "Shield active: %.1fs" % _note_chase_shield_timer
			_play_shield_activate_sfx()
			_note_chase_spawn_pop_effect(pop_center, Color(0.42, 0.86, 1.0, 1.0))
			if note_panel != null:
				note_panel.queue_free()
			_note_chase_active_notes[i] = n
			_note_chase_refresh_progress_text()
			return
		if kind == "freeze":
			n["hit"] = true
			_note_chase_freeze_timer = maxf(_note_chase_freeze_timer, 2.0)
			_status_label.text = "Time Freeze!"
			_play_powerup_sfx()
			_note_chase_spawn_pop_effect(pop_center, Color(1.0, 0.86, 0.36, 1.0))
			if note_panel != null:
				note_panel.queue_free()
			_note_chase_active_notes[i] = n
			_note_chase_refresh_progress_text()
			return
		if kind != "note":
			return
		var is_target := bool(n.get("target", false))
		var is_rainbow := bool(n.get("rainbow", false))
		var pop_color := _note_chase_stage_note_color()
		if is_rainbow:
			pop_color = Color(1.0, 0.92, 0.45, 1.0)
		elif not is_target:
			pop_color = Color(0.92, 0.36, 0.36, 1.0)
		if is_target:
			n["hit"] = true
			_note_chase_spawn_pop_effect(pop_center, pop_color)
			var gained := int(round(float(_note_chase_points_per_note()) * _note_chase_score_multiplier()))
			var captured_extra := 0
			if is_rainbow and _note_chase_speed_stage >= 3:
				captured_extra = _note_chase_capture_targets_with_rainbow(note_panel)
				gained += 5
				gained += int(round(float(captured_extra * _note_chase_points_per_note()) * _note_chase_score_multiplier()))
			_score += gained
			_note_chase_correct_clicks += 1
			_note_chase_correct_streak += 1
			if is_rainbow:
				_status_label.text = "Rainbow! +%d (captured %d)" % [gained, captured_extra]
			else:
				_status_label.text = "Nice! %s +%d" % [str(n.get("note", "")), gained]
			_play_success_sfx()
			if _note_chase_correct_streak == 8 or _note_chase_correct_streak == 16 or _note_chase_correct_streak == 24:
				_note_chase_start_fever()
			if _note_chase_correct_streak > 0 and _note_chase_correct_streak % 8 == 0:
				var prev_mult := _note_chase_speed_multiplier()
				_note_chase_speed_stage = mini(12, _note_chase_speed_stage + 1)
				_note_chase_apply_speed_stage()
				_note_chase_apply_level_reward()
				var new_mult := _note_chase_speed_multiplier()
				if _note_chase_speed_stage == 2:
					_status_label.text = "Decoys unlocked!"
				elif new_mult > prev_mult:
					_status_label.text = "Speed up!"
				else:
					_status_label.text = "Level up!"
				_play_powerup_sfx()
		else:
			# Wrong click: keep note moving, but reduce focus life unless shield is active.
			if _note_chase_shield_timer > 0.0:
				_status_label.text = "Shield blocked wrong"
			else:
				_score -= 6
				_lives = maxi(0, _lives - 1)
				_note_chase_wrongs += 1
				_note_chase_combo_mult = maxi(1, _note_chase_combo_mult - 1)
				_status_label.text = "Wrong note."
				_play_fail_sfx()
				_refresh_meta_ui()
			n["click_cd"] = 0.28
			_note_chase_active_notes[i] = n
			_score_label.text = "Score: %d" % _score
			_note_chase_refresh_progress_text()
			return
		if note_panel != null and bool(n.get("hit", false)):
			note_panel.queue_free()
		_note_chase_active_notes[i] = n
		_score_label.text = "Score: %d" % _score
		_note_chase_refresh_progress_text()
		return


func _update_note_chase(delta: float) -> void:
	if not _note_chase_running or not _quiz_active or _selected_mode != MODE_NOTE_CHASE:
		return
	_note_chase_elapsed += delta
	var pending_clef_switch := false
	var pending_switch_to := ""
	var pending_trigger_x := 0.0
	_update_note_chase_staff_scroll(delta)
	_note_chase_clef_switch_cd = maxf(0.0, _note_chase_clef_switch_cd - delta)
	_note_chase_freeze_timer = maxf(0.0, _note_chase_freeze_timer - delta)
	_note_chase_shield_timer = maxf(0.0, _note_chase_shield_timer - delta)
	if _note_chase_fever_active:
		_note_chase_fever_timer = maxf(0.0, _note_chase_fever_timer - delta)
		if _note_chase_fever_timer <= 0.0:
			_note_chase_fever_active = false
	if _note_chase_boss_active:
		_note_chase_boss_timer = maxf(0.0, _note_chase_boss_timer - delta)
		if _note_chase_boss_timer <= 0.0:
			_note_chase_boss_active = false
			_status_label.text = "Boss clear!"
	_note_chase_refresh_progress_text()
	if _note_chase_freeze_timer <= 0.0:
		_note_chase_spawn_timer -= delta
	var effective_spawn_interval := _note_chase_spawn_interval
	if _note_chase_boss_active:
		effective_spawn_interval *= 0.62
	if _note_chase_spawn_timer <= 0.0 and not _note_chase_has_untriggered_clef_token():
		_spawn_note_chase_note()
		_note_chase_spawned += 1
		_note_chase_spawn_timer = effective_spawn_interval

	var still_active: Array[Dictionary] = []
	for item in _note_chase_active_notes:
		var n: Dictionary = item
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var panel := node_obj as Panel
		if panel == null:
			continue
		var kind := str(n.get("kind", "note"))
		var hit := bool(n.get("hit", false))
		if not hit:
			var click_cd := float(n.get("click_cd", 0.0))
			if click_cd > 0.0:
				n["click_cd"] = maxf(0.0, click_cd - delta)
			if kind == "clef":
				var trigger_x := _note_chase_end_x()
				var already_triggered := bool(n.get("triggered", false))
				if not already_triggered:
					if _note_chase_freeze_timer <= 0.0:
						panel.position.x -= (_note_chase_scroll_speed * _note_chase_item_speed_multiplier(n)) * delta
					var blink := 0.45 + (absf(sin(_note_chase_elapsed * 13.0)) * 0.55)
					panel.modulate = Color(1.0, 1.0, 1.0, blink)
					if panel.position.x <= trigger_x:
						n["triggered"] = true
						panel.position.x = trigger_x
						panel.modulate = Color(1, 1, 1, 1)
						pending_clef_switch = true
						pending_switch_to = str(n.get("next_clef", "Treble"))
						pending_trigger_x = trigger_x
						_note_chase_fade_out_control(panel, 0.28)
				else:
					# Hold token on the switch line and let it fade out smoothly.
					panel.position.x = trigger_x
				if bool(n.get("triggered", false)) and panel.modulate.a <= 0.02:
					panel.queue_free()
					continue
				still_active.append(n)
				continue
			if bool(n.get("decoy", false)):
				var start_x := _note_chase_spawn_x() + 8.0
				var reveal_x := _note_chase_end_x() + ((start_x - _note_chase_end_x()) * 0.5)
				if panel.position.x <= reveal_x:
					n["decoy"] = false
					_note_chase_apply_note_style(panel, bool(n.get("target", false)), false, bool(n.get("rainbow", false)))
			if _note_chase_freeze_timer <= 0.0:
				panel.position.x -= (_note_chase_scroll_speed * _note_chase_item_speed_multiplier(n)) * delta
			var miss_x := STAFF_LEFT_X + 8.0
			if _note_chase_fail_line != null and _note_chase_fail_line.visible:
				miss_x = _note_chase_fail_line.position.x
			if panel.position.x + panel.size.x < miss_x:
				if not bool(n.get("missed", false)):
					n["missed"] = true
					if bool(n.get("target", false)):
						if _note_chase_shield_timer > 0.0:
							_status_label.text = "Shield blocked miss"
						else:
							_score -= 3
							_lives = maxi(0, _lives - 1)
							_note_chase_correct_streak = 0
							_note_chase_fever_active = false
							_note_chase_fever_timer = 0.0
							_note_chase_wrongs += 1
							_note_chase_combo_mult = maxi(1, _note_chase_combo_mult - 1)
							_status_label.text = "Missed target note."
							_play_fail_sfx()
							_score_label.text = "Score: %d" % _score
							_refresh_meta_ui()
					_note_chase_fade_out_control(panel, 0.24)
				if panel.modulate.a <= 0.02:
					panel.queue_free()
					continue
				still_active.append(n)
				continue
			still_active.append(n)
		else:
			panel.queue_free()
	_note_chase_active_notes = still_active
	if pending_clef_switch:
		_selected_clef = pending_switch_to
		_refresh_clef_buttons()
		_refresh_note_chase_clef_buttons()
		if _staff_clef_label != null:
			_staff_clef_label.visible = true
			_staff_clef_label.text = char(0x1D122) if _selected_clef == "Bass" else char(0x1D11E)
			_staff_clef_label.position.x = _note_chase_end_x() + 10.0
		var removed_count := _note_chase_clear_recent_notes_after_clef_switch(pending_trigger_x, 2.0)
		_question_index = maxi(0, _question_index - removed_count)
		for _j in range(removed_count):
			_spawn_note_chase_note(float(_j) * 72.0)
		_note_chase_spawn_timer = maxf(_note_chase_spawn_timer, _note_chase_spawn_interval * 0.65)
		_status_label.text = "Clef switched to %s" % pending_switch_to
		_play_transition_whoosh_sfx()

	if _lives <= 0:
		_note_chase_running = false
		_quiz_active = false
		_accepting_answer = false
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = ""
		var fail_perf := "Score: %d | Focus Hearts: 0/5 | Misses: %d" % [_score, _note_chase_wrongs]
		_progress_label.text = fail_perf
		_home_info_label.text = fail_perf
		await _play_gameover_fail_sfx()
		_result_box_show("Game Over", fail_perf)
		_stop_note_chase_music()
		_set_note_chase_staff_scrolling(false)
		return

	if _note_chase_speed_stage >= 12 and not _note_chase_boss_active:
		_note_chase_running = false
		_quiz_active = false
		_accepting_answer = false
		_set_answer_buttons_enabled(false)
		_replay_button.disabled = true
		_restart_button.disabled = false
		_status_label.text = "Complete!"
		var perf := "Final Score: %d | Reached max level speed" % _score
		_progress_label.text = perf
		_home_info_label.text = perf
		_result_box_show("Complete", perf)
		_stop_note_chase_music()
		await _play_win_fanfare_sfx()
		_set_note_chase_staff_scrolling(false)


func _clear_note_chase_visual_notes() -> void:
	for item in _note_chase_active_notes:
		var n: Dictionary = item
		var node_obj = n.get("node", null)
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		var panel := node_obj as Panel
		if panel != null:
			panel.queue_free()
	_note_chase_active_notes.clear()


func _set_note_chase_staff_scrolling(enabled: bool) -> void:
	if _staff_lines.is_empty():
		return
	var top_y := _active_staff_top_y()
	var gap_y := _active_staff_line_gap_y()
	var line_x := STAFF_LEFT_X
	var segment := maxf(STAFF_LINE_WIDTH, _staff_area.size.x - STAFF_LEFT_X - 28.0)
	if _selected_mode == MODE_SIGHT:
		var g := _sight_visual_staff_geometry()
		line_x = float(g.get("left", STAFF_LEFT_X))
		segment = float(g.get("width", STAFF_LINE_WIDTH))
	for i in range(_staff_lines.size()):
		var line := _staff_lines[i]
		if line == null:
			continue
		line.position.y = top_y + (i * gap_y)
		line.position.x = line_x
		line.size.x = segment
		line.visible = true
		if i < _note_chase_staff_clone_lines.size():
			var clone := _note_chase_staff_clone_lines[i]
			if clone != null:
				clone.visible = false
				clone.position.y = line.position.y
				clone.size.x = segment
				clone.position = Vector2(line_x + segment - 1.0, line.position.y)
	if _selected_mode == MODE_NOTE_CHASE:
		for ll in _staff_ledger_lines:
			if ll != null:
				ll.visible = false
		for pl in _staff_preview_ledgers:
			if pl != null:
				pl.visible = false
	if _staff_line_number_labels != null:
		for lbl in _staff_line_number_labels:
			if lbl != null:
				lbl.visible = false
	_apply_note_chase_staff_colors()
	if _staff_clef_label != null:
		_staff_clef_label.visible = true
		var clef_x := _note_chase_end_x() + 10.0 if enabled and _selected_mode == MODE_NOTE_CHASE else 16.0
		if _selected_mode == MODE_SIGHT:
			clef_x = line_x - 36.0
		_align_staff_clef_to_five_lines(clef_x)
		_layout_staff_key_signature()
		_staff_clef_label.modulate = Color(1, 1, 1, 1)
		_staff_clef_label.scale = Vector2.ONE
		_staff_clef_label.set_meta("nc_fading", false)
	if _note_chase_fail_line != null:
		_note_chase_fail_line.visible = _selected_mode == MODE_NOTE_CHASE
		_note_chase_fail_line.position.x = _note_chase_end_x()
		_note_chase_fail_line.position.y = top_y - 12.0
		_note_chase_fail_line.size.y = (gap_y * 4.0) + 26.0
	if _note_chase_spawn_line != null:
		_note_chase_spawn_line.visible = _selected_mode == MODE_NOTE_CHASE
		_note_chase_spawn_line.position.x = _note_chase_spawn_x()
		_note_chase_spawn_line.position.y = top_y - 12.0
		_note_chase_spawn_line.size.y = (gap_y * 4.0) + 26.0
	_note_chase_realign_staff_frame()
	if _note_chase_clef_clone != null:
		# In Note Chase we only show clef once at round start.
		_note_chase_clef_clone.visible = false


func _align_staff_clef_to_five_lines(anchor_x: float) -> void:
	if _staff_clef_label == null:
		return
	var gap := _active_staff_line_gap_y()
	var top_y := _active_staff_top_y()
	var span := gap * 4.0
	var size_factor := 1.18
	var y_factor := 0.62
	if _selected_mode == MODE_SIGHT:
		size_factor = 1.30
		y_factor = 1.02
		if _selected_clef == "Bass":
			size_factor = 1.78
			y_factor = 1.62
	var font_sz := int(round(clampf(span * size_factor, 86.0, 172.0)))
	_staff_clef_label.add_theme_font_size_override("font_size", font_sz)
	_staff_clef_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
	_staff_clef_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.75))
	_staff_clef_label.add_theme_constant_override("outline_size", 3)
	_staff_clef_label.scale = Vector2.ONE
	_staff_clef_label.position = Vector2(anchor_x, top_y - (gap * y_factor))
	if _note_chase_clef_clone != null:
		_note_chase_clef_clone.add_theme_font_size_override("font_size", font_sz)
		_note_chase_clef_clone.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
		_note_chase_clef_clone.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.72))
		_note_chase_clef_clone.add_theme_constant_override("outline_size", 3)
		_note_chase_clef_clone.scale = Vector2.ONE


func _key_sig_letter_steps() -> Array:
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	if _sight_key_signature == "2#":
		return [["F", sharp_sym], ["C", sharp_sym]]
	if _sight_key_signature == "3#":
		return [["F", sharp_sym], ["C", sharp_sym], ["G", sharp_sym]]
	if _sight_key_signature == "2b":
		return [["B", flat_sym], ["E", flat_sym]]
	if _sight_key_signature == "3b":
		return [["B", flat_sym], ["E", flat_sym], ["A", flat_sym]]
	return []


func _key_signature_step_for_letter(letter: String, clef_name: String) -> int:
	# Explicit key-signature placement for standard notation positions.
	if clef_name == "Treble":
		match letter:
			"F":
				return 0  # top line
			"C":
				return 3  # 2nd space from top
			"G":
				return 1  # top space
			"B":
				return 4  # middle line
			"E":
				return 1  # top space
			"A":
				return 7  # 4th space from top
	if clef_name == "Bass":
		match letter:
			"F":
				return 2  # 2nd line from top
			"C":
				return 5  # 3rd space from top
			"G":
				return 1  # top space
			"B":
				return 6  # 4th line from top
			"E":
				return 3  # 2nd space from top
			"A":
				return 0  # top line
	var best_step := 4
	var best_dist := 999999
	for s in range(STAFF_TOP_LINE_STEP, STAFF_BOTTOM_LINE_STEP + 1):
		if _staff_step_name_for_clef(s, clef_name) != letter:
			continue
		var d: int = absi(s - 4)
		if d < best_dist:
			best_dist = d
			best_step = s
	return best_step
func _layout_staff_key_signature() -> void:
	if _staff_key_sig_labels.is_empty():
		return
	var show_sig := _selected_mode == MODE_SIGHT and (_sight_mode == "Chords" or _sight_mode == "Notes")
	var defs: Array = _key_sig_letter_steps()
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	for i in range(_staff_key_sig_labels.size()):
		var lbl := _staff_key_sig_labels[i]
		if lbl == null:
			continue
		if not show_sig or i >= defs.size():
			lbl.visible = false
			continue
		var def: Array = defs[i]
		var letter := str(def[0])
		var symbol := str(def[1])
		var step := _key_signature_step_for_letter(letter, _selected_clef)
		var y := _staff_center_y_for_step(step)
		# Keep accidental signs aligned on their staff slots.
		if symbol == sharp_sym:
			y -= 8.0
		elif symbol == flat_sym:
			y -= 18.0
		# Raise the 3rd accidental in 3-sharp / 3-flat signatures by two staff steps.
		if i == 2 and (_sight_key_signature == "3#" or _sight_key_signature == "3b"):
			y -= (_active_staff_step_y() * 2.0)
		lbl.text = symbol
		lbl.visible = true
		var base_x := _staff_clef_label.position.x + 78.0
		var spacing := 20.0
		if _selected_clef == "Bass":
			base_x += 40.0
			spacing = 26.0
		elif symbol == flat_sym:
			base_x += 8.0
		lbl.position = Vector2(base_x + float(i) * spacing, y - 35.0)


func _sight_visual_staff_geometry() -> Dictionary:
	var left := STAFF_LEFT_X
	var width := STAFF_LINE_WIDTH
	if _staff_area != null and _selected_mode == MODE_SIGHT:
		if _sight_mode == "Continuous":
			width = maxf(720.0, _staff_area.size.x - 44.0)
			left = 22.0
		else:
			width = minf(STAFF_LINE_WIDTH, maxf(560.0, _staff_area.size.x * 0.56))
			left = clampf((_staff_area.size.x - width) * 0.5 + 18.0, 18.0, _staff_area.size.x - width - 10.0)
	return {"left": left, "width": width}


func _note_chase_realign_staff_frame() -> void:
	if _note_chase_staff_frame == null or _staff_area == null:
		return
	_note_chase_staff_frame.visible = _selected_mode == MODE_NOTE_CHASE or _selected_mode == MODE_SIGHT
	if not _note_chase_staff_frame.visible:
		return
	if _selected_mode == MODE_SIGHT:
		var g := _sight_visual_staff_geometry()
		var sight_left := float(g.get("left", STAFF_LEFT_X))
		var sight_width := float(g.get("width", STAFF_LINE_WIDTH))
		var top_staff := _active_staff_top_y()
		var gap_staff := _active_staff_line_gap_y()
		var top_y := _staff_center_y_for_step(-4) - 30.0
		var bottom_y := _staff_center_y_for_step(12) + 30.0
		var left_x_s := sight_left - 64.0
		var right_x_s := sight_left + sight_width + 16.0
		if _sight_mode == "Continuous":
			left_x_s = maxf(8.0, sight_left - 18.0)
			right_x_s = minf(_staff_area.size.x - 8.0, sight_left + sight_width + 18.0)
		top_y = clampf(top_y, 8.0, _staff_area.size.y - 120.0)
		bottom_y = clampf(bottom_y, top_y + 220.0, _staff_area.size.y - 8.0)
		_note_chase_staff_frame.position = Vector2(left_x_s, top_y)
		_note_chase_staff_frame.size = Vector2(maxf(360.0, right_x_s - left_x_s), maxf(220.0, bottom_y - top_y))
		var sb_s := _note_chase_staff_frame.get_theme_stylebox("panel")
		if sb_s != null and sb_s is StyleBoxFlat:
			var style_s := (sb_s as StyleBoxFlat).duplicate()
			style_s.border_color = _sight_staff_frame_border_color
			_note_chase_staff_frame.add_theme_stylebox_override("panel", style_s)
		# Keep staff lines, clones and clef locked to the same centered geometry.
		for i in range(_staff_lines.size()):
			var line := _staff_lines[i]
			if line == null:
				continue
			line.position = Vector2(sight_left, top_staff + (i * gap_staff))
			line.size.x = sight_width
			line.visible = true
			if i < _note_chase_staff_clone_lines.size():
				var clone := _note_chase_staff_clone_lines[i]
				if clone != null:
					clone.visible = false
					clone.position = Vector2(sight_left + sight_width - 1.0, line.position.y)
					clone.size.x = sight_width
		if _staff_clef_label != null:
			_align_staff_clef_to_five_lines(sight_left - 36.0)
			_layout_staff_key_signature()
		if _sight_mode == "Notes" and _staff_note != null and _staff_note.visible:
			var b := _effective_sight_step_bounds()
			_current_sight_display_step = clampi(_current_sight_display_step, b.x, b.y)
			var note_center_y := _staff_center_y_for_step(_current_sight_display_step) + SIGHT_NOTE_CENTER_OFFSET_Y
			_staff_note.scale = _note_scale_for_y(note_center_y)
			_staff_note.position = Vector2(_sight_note_snap_x(), note_center_y - (_staff_note.size.y * 0.5))
			var note_center_x := _staff_note.position.x + (_staff_note.size.x * 0.5)
			_update_staff_ledger_lines(note_center_y, note_center_x)
			_current_sight_note = _staff_step_name_for_clef(_current_sight_display_step, _selected_clef)
		return
	var left_x := 12.0
	var right_x := _staff_area.size.x - 12.0
	var top_pad := 2.0
	var bottom_pad := 2.0
	var frame_h := maxf(360.0, _staff_area.size.y - top_pad - bottom_pad)
	_note_chase_staff_frame.position = Vector2(left_x, top_pad)
	_note_chase_staff_frame.size = Vector2(maxf(360.0, right_x - left_x), frame_h)


func _update_note_chase_staff_scroll(delta: float) -> void:
	if _staff_lines.is_empty():
		return
	if _staff_clef_label != null:
		if _staff_clef_label.visible:
			if _selected_mode == MODE_NOTE_CHASE:
				_staff_clef_label.position.x = _note_chase_end_x() + 10.0
				_staff_clef_label.modulate = Color(1, 1, 1, 1)
			elif _note_chase_freeze_timer <= 0.0:
				_staff_clef_label.position.x -= _note_chase_scroll_speed * 0.55 * delta
				if _staff_clef_label.position.x + 42.0 < STAFF_LEFT_X:
					_note_chase_fade_out_control(_staff_clef_label, 0.28)
				if _staff_clef_label.has_meta("nc_fading") and bool(_staff_clef_label.get_meta("nc_fading")) and _staff_clef_label.modulate.a <= 0.02:
					_staff_clef_label.visible = false
	if _note_chase_clef_clone != null:
		_note_chase_clef_clone.visible = false


func _begin_next_question() -> void:
	if not _quiz_active:
		return

	if _question_index >= _total_questions:
		_finish_quiz()
		return

	_question_index += 1
	_score_label.text = "Correct: %d / %d" % [_score, _question_index - 1]
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
		_current_chord_choices = []
	elif _selected_mode == MODE_SIGHT:
		_current_available_chord_types = []
		_current_chord_choices = []
	else:
		_current_available_chord_types = []
		_current_chord_choices = []
	_apply_answer_mode()
	_generate_round()
	_start_chicken_turn_hint_cycle()
	_apply_answer_mode()
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
	_start_chicken_turn_hint_cycle()
	_replay_button.disabled = false
	_restart_button.disabled = false


func _finish_quiz() -> void:
	_quiz_active = false
	_accepting_answer = false
	_cancel_chicken_turn_hint_cycle(true)
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = false
	_status_label.text = ""
	var result_text := _final_quiz_result_text(_score, _total_questions, _xp)
	_progress_label.text = result_text
	_teacher_record_session_metrics(_selected_mode, _score, _total_questions)
	_home_info_label.text = result_text
	if _selected_mode == MODE_SIGHT:
		_set_sight_result_background_hidden(true)
	_result_box_show("Complete", result_text)
	await _play_win_fanfare_sfx()
	var score_pct := (float(_score) / float(maxi(1, _total_questions))) * 100.0
	_play_completion_reaction(score_pct)


func _generate_round() -> void:
	if _selected_mode == MODE_INTERVAL:
		if _active_intervals.is_empty():
			_active_intervals = _build_interval_pool_for_settings()
		var interval_sig := ""
		for attempt in range(16):
			_current_interval_id = _active_intervals[_rng.randi_range(0, _active_intervals.size() - 1)]
			var semitone_options: Array = INTERVAL_DATA[_current_interval_id]["semitones"]
			var semitones: int = int(semitone_options[_rng.randi_range(0, semitone_options.size() - 1)])
			_current_root_midi = _rng.randi_range(52, 64)
			_current_second_midi = _current_root_midi + semitones
			_current_interval_id = _interval_id_for_semitones(_current_second_midi - _current_root_midi)
			interval_sig = "%s:%d:%d" % [_current_interval_id, _current_root_midi, _current_second_midi]
			if interval_sig != _last_interval_signature or attempt == 15:
				break
		_last_interval_signature = interval_sig
		_current_interval_choices = _build_interval_choices(_current_interval_id, _active_intervals)
		_interval_option_map.clear()
		for i in _interval_choice_buttons.size():
			var btn: Button = _interval_choice_buttons[i]
			if btn == null:
				continue
			if i >= _current_interval_choices.size():
				btn.text = "?"
				btn.remove_meta("choice_id")
				continue
			var choice_id := _current_interval_choices[i]
			btn.text = _interval_display_name(choice_id)
			btn.set_meta("choice_id", choice_id)
			_interval_option_map[choice_id] = btn
	elif _selected_mode == MODE_CHORD:
		if _current_available_chord_types.is_empty():
			_current_available_chord_types = _get_available_chord_types()
		var chord_sig := ""
		for attempt in range(16):
			_current_chord_quality = _current_available_chord_types[_rng.randi_range(0, _current_available_chord_types.size() - 1)]
			_current_root_midi = _rng.randi_range(50, 60)
			_current_chord_inversion = 0
			# Keep Maj/Min group in root position so quality is unambiguous.
			var allow_inversions := _selected_chord_group != 1
			if allow_inversions and _inversion_toggle != null and _inversion_toggle.button_pressed:
				var max_inversion := mini(2, CHORD_INTERVALS[_current_chord_quality].size() - 1)
				if max_inversion > 0:
					_current_chord_inversion = _rng.randi_range(0, max_inversion)
			_current_chord_notes = _build_chord_notes(_current_root_midi, _current_chord_quality, _current_chord_inversion)
			chord_sig = "%s:%d:%d" % [_current_chord_quality, _current_root_midi, _current_chord_inversion]
			if chord_sig != _last_chord_signature or attempt == 15:
				break
		_last_chord_signature = chord_sig
		_current_chord_choices = _build_chord_choices(_current_chord_quality, _current_available_chord_types)
	else:
		if _sight_mode == "Chords":
			var sight_chord_sig := ""
			for attempt in range(16):
				_pick_random_sight_frame_border_color()
				_generate_sight_chord_round()
				sight_chord_sig = _current_sight_chord_name
				if _staff_note != null:
					sight_chord_sig += ":%d" % int(round(_staff_note.position.y))
				if sight_chord_sig != _last_sight_signature or attempt == 15:
					break
			_last_sight_signature = sight_chord_sig
		elif _sight_mode == "Placement":
			_pick_random_sight_frame_border_color()
			_generate_sight_placement_round()
		else:
			var sight_note_sig := ""
			for attempt in range(16):
				_pick_random_sight_frame_border_color()
				var slot := _pick_sight_note_slot()
				var note_display := str(slot.get("name", "C4"))
				var note_base := str(slot.get("base_name", _staff_step_name_for_clef(int(slot.get("step", 8)), _selected_clef)))
				_current_sight_note = note_display
				var center_y := float(slot.get("center_y", 96.0))
				_current_sight_display_step = int(slot.get("step", 8))
				_position_sight_note(note_base, center_y)
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

	await _play_interval_prompt_async(_current_root_midi, _current_second_midi)


func _play_interval_prompt_async(root_midi: int, other_midi: int) -> void:
	if _use_harmonic_intervals:
		await _play_harmonic_interval_async(root_midi, other_midi)
		return
	if _use_descending_intervals:
		await _play_two_notes_async(other_midi, root_midi)
		return
	await _play_two_notes_async(root_midi, other_midi)


func _play_two_notes_async(midi_a: int, midi_b: int) -> void:
	var d := _current_note_duration()
	var g := _current_gap_duration()
	await _play_note(midi_a, d)
	await _push_silence(g)
	await _play_note(midi_b, d)
	await _push_silence(0.05)


func _play_harmonic_interval_async(midi_a: int, midi_b: int) -> void:
	var d := _current_note_duration()
	var notes: Array[int] = [midi_a, midi_b]
	await _play_chord(notes, d)
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


func _on_round_start_pressed() -> void:
	if not _quiz_active or _is_prompt_playing or not _awaiting_round_start:
		return
	_awaiting_round_start = false
	_set_note_chase_overlay("", false)
	if _round_start_button != null:
		_round_start_button.visible = false
		_round_start_button.disabled = true
	if _selected_mode == MODE_NOTE_CHASE:
		await _start_note_chase_round()
		return
	await _begin_next_question()


func _maybe_play_powerup_on_streak() -> void:
	if _streak > 0 and _streak % 3 == 0:
		_play_powerup_sfx()


func _on_chicken_combo_correct() -> bool:
	if _selected_mode == MODE_NOTE_CHASE:
		return false
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous":
		return false
	if _chicken_combo_shields > 0:
		return false
	_chicken_combo_charge = mini(CHICKEN_COMBO_TARGET, _chicken_combo_charge + 1)
	if _chicken_combo_charge >= CHICKEN_COMBO_TARGET:
		_chicken_combo_shields = 1
		_chicken_combo_charge = 0
		_play_shield_activate_sfx()
		return true
	return false


func _consume_chicken_shield_on_wrong() -> bool:
	if _selected_mode == MODE_NOTE_CHASE:
		return false
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous":
		return false
	if _chicken_combo_shields <= 0:
		return false
	_chicken_combo_shields = maxi(0, _chicken_combo_shields - 1)
	_chicken_combo_charge = 0
	_play_shield_activate_sfx()
	return true


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
	var sample_map := _sample_map_for_current_mode()
	if sample_map.is_empty() or _chord_players.size() < notes.size():
		for midi_note in notes:
			await _play_note(midi_note, 0.08)
		await _push_silence(0.14)
		await _play_broken_chord(notes, duration)
		return

	for i in notes.size():
		var midi_note := notes[i]
		var nearest := _nearest_sample_midi_from_map(midi_note, sample_map)
		var stream: AudioStream = sample_map[nearest]
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
	var sample_map := _sample_map_for_current_mode()
	var can_use_players := not sample_map.is_empty() and not _chord_players.is_empty()
	for i in range(notes.size()):
		var midi_note := int(notes[i])
		if can_use_players:
			var player: AudioStreamPlayer = _chord_players[i % _chord_players.size()]
			var nearest := _nearest_sample_midi_from_map(midi_note, sample_map)
			var stream: AudioStream = sample_map.get(nearest, null)
			if stream != null:
				player.stop()
				player.stream = stream
				player.pitch_scale = pow(2.0, float(midi_note - nearest) / 12.0)
				player.play()
				await get_tree().create_timer(step_duration).timeout
				player.stop()
			else:
				await _play_note(midi_note, step_duration)
		else:
			await _play_note(midi_note, step_duration)
		await _push_silence(0.03)


func _on_interval_choice_index(choice_idx: int) -> void:
	if _selected_mode != MODE_INTERVAL:
		return
	if not _quiz_active or not _accepting_answer:
		return
	if choice_idx < 0 or choice_idx >= _interval_choice_buttons.size():
		return
	var choice_btn: Button = _interval_choice_buttons[choice_idx]
	if choice_btn == null:
		return
	if not choice_btn.has_meta("choice_id"):
		return
	var choice_id := str(choice_btn.get_meta("choice_id"))
	_on_player_answer_committed()

	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true
	var is_correct := choice_id == _current_interval_id
	var chosen_btn: Button = choice_btn
	var correct_btn: Button = _get_button_for_interval(_current_interval_id)
	if is_correct:
		_score += 1
		_streak += 1
		_maybe_play_powerup_on_streak()
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		var granted_shield := _on_chicken_combo_correct()
		_status_label.text = "Correct! It was %s." % _interval_display_name(_current_interval_id)
		if granted_shield:
			_status_label.text += " Chicken shield ready!"
		await _blink_answer_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		var shielded := _consume_chicken_shield_on_wrong()
		if not shielded:
			_streak = 0
			_lives = maxi(0, _lives - 1)
			_xp = maxi(0, _xp - 2)
			_status_label.text = "Not quite. Correct answer: %s." % _interval_display_name(_current_interval_id)
		else:
			_xp = maxi(0, _xp - 1)
			_status_label.text = "Shield blocked the miss. Correct answer: %s." % _interval_display_name(_current_interval_id)
		await _blink_answer_feedback(chosen_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Correct: %d / %d" % [_score, _question_index]
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
		_progress_label.text = _final_quiz_result_text(_score, _question_index, _xp)
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		await _play_gameover_fail_sfx()
		if _selected_mode == MODE_SIGHT:
			_set_sight_result_background_hidden(true)
		_result_box_show("Game Over", "No lives left. Restart or Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _on_chord_chosen(choice_quality: String) -> void:
	if _selected_mode != MODE_CHORD:
		return
	if not _quiz_active or not _accepting_answer:
		return

	_on_player_answer_committed()
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
		_maybe_play_powerup_on_streak()
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		var granted_shield := _on_chicken_combo_correct()
		_status_label.text = "Correct! It was %s." % _current_chord_quality
		if granted_shield:
			_status_label.text += " Chicken shield ready!"
		await _blink_answer_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		var shielded := _consume_chicken_shield_on_wrong()
		if not shielded:
			_streak = 0
			_lives = maxi(0, _lives - 1)
			_xp = maxi(0, _xp - 2)
			_status_label.text = "Not quite. Correct answer: %s." % _current_chord_quality
		else:
			_xp = maxi(0, _xp - 1)
			_status_label.text = "Shield blocked the miss. Correct answer: %s." % _current_chord_quality
		await _blink_answer_feedback(chosen_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Correct: %d / %d" % [_score, _question_index]
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
		_progress_label.text = _final_quiz_result_text(_score, _question_index, _xp)
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		await _play_gameover_fail_sfx()
		if _selected_mode == MODE_SIGHT:
			_set_sight_result_background_hidden(true)
		_result_box_show("Game Over", "No lives left. Restart or Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _on_sight_key_chosen(note_name: String) -> void:
	if _selected_mode != MODE_SIGHT:
		return
	if _sight_mode == "Continuous":
		_on_continuous_sight_key_pressed(note_name)
		return
	if not _quiz_active or not _accepting_answer:
		return
	_play_sight_answer_click_sfx()
	_on_player_answer_committed()

	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	_replay_button.disabled = true
	_restart_button.disabled = true

	var is_correct := note_name == _current_sight_note
	var correct_btn: Button = _sight_key_buttons[_current_sight_note]
	if is_correct:
		_score += 1
		_streak += 1
		_maybe_play_powerup_on_streak()
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		var granted_shield := _on_chicken_combo_correct()
		_status_label.text = "Correct! That note is %s." % _current_sight_note
		if granted_shield:
			_status_label.text += " Chicken shield ready!"
		await _blink_sight_feedback(null, correct_btn, 3)
		await _play_sight_note_correct_bounce_once()
		await _play_success_sfx()
	else:
		var shielded := _consume_chicken_shield_on_wrong()
		if not shielded:
			_streak = 0
			_lives = maxi(0, _lives - 1)
			_xp = maxi(0, _xp - 2)
			_status_label.text = "Not quite. Correct note: %s." % _current_sight_note
		else:
			_xp = maxi(0, _xp - 1)
			_status_label.text = "Shield blocked the miss. Correct note: %s." % _current_sight_note
		var wrong_btn: Button = _sight_key_buttons[note_name]
		await _blink_sight_feedback(wrong_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Correct: %d / %d" % [_score, _question_index]
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
		_progress_label.text = _final_quiz_result_text(_score, _question_index, _xp)
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		await _play_gameover_fail_sfx()
		if _selected_mode == MODE_SIGHT:
			_set_sight_result_background_hidden(true)
		_result_box_show("Game Over", "No lives left. Restart or Back.")
		return

	await get_tree().create_timer(_current_post_answer_delay()).timeout
	if _quiz_active:
		await _begin_next_question()


func _continuous_play_line_x() -> float:
	var frame_left := STAFF_LEFT_X - 20.0
	var frame_right := STAFF_LEFT_X + STAFF_LINE_WIDTH + 20.0
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		frame_left = _note_chase_staff_frame.position.x + 14.0
		frame_right = _note_chase_staff_frame.position.x + _note_chase_staff_frame.size.x - 14.0
	return lerpf(frame_left, frame_right, 0.20)


func _continuous_spawn_x() -> float:
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		return _note_chase_staff_frame.position.x + _note_chase_staff_frame.size.x - 24.0
	if _staff_area == null:
		return 860.0
	return _staff_area.size.x - 24.0


func _continuous_note_name_pool() -> Array[String]:
	return ["C", "D", "E", "F", "G", "A", "B"]


func _midi_for_note_octave(note_name: String, octave: int) -> int:
	var base_map := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	return ((octave + 1) * 12) + int(base_map.get(note_name, 0))


func _continuous_keyboard_range_midis() -> Vector2i:
	if _selected_clef == "Bass":
		return Vector2i(36, 64) # C2..E4
	return Vector2i(55, 84) # G3..C6


func _refresh_continuous_keyboard_range() -> void:
	if _continuous_keyboard_row == null:
		return
	var range_midi := _continuous_keyboard_range_midis()
	for key_btn in _continuous_key_buttons:
		if key_btn == null:
			continue
		var note_name := str(key_btn.get_meta("piano_note", "C"))
		var octave := int(key_btn.get_meta("piano_octave", 4))
		var midi := _midi_for_note_octave(note_name, octave)
		var white_visible := midi >= range_midi.x and midi <= range_midi.y
		key_btn.visible = white_visible
		var black_btn := key_btn.get_node_or_null("BlackKeyButton") as Button
		if black_btn != null:
			var black_midi := midi + 1
			black_btn.visible = white_visible and black_midi >= range_midi.x and black_midi <= range_midi.y


func _try_handle_continuous_touch_key(global_pos: Vector2) -> bool:
	if _selected_mode != MODE_SIGHT or _sight_mode != "Continuous":
		return false
	if not _continuous_sight_active or _continuous_sight_waiting_start:
		return false
	# Prioritize black keys because they visually overlap white keys.
	for bb in _continuous_black_key_buttons:
		if bb == null or not bb.visible or bb.disabled:
			continue
		var rect := Rect2(bb.global_position, bb.size)
		if rect.has_point(global_pos):
			_on_sight_key_chosen(str(bb.get_meta("piano_note", bb.text)))
			return true
	for kb in _continuous_key_buttons:
		if kb == null or not kb.visible or kb.disabled:
			continue
		var rect := Rect2(kb.global_position, kb.size)
		if rect.has_point(global_pos):
			_on_sight_key_chosen(str(kb.get_meta("piano_note", kb.text)))
			return true
	return false


func _continuous_level_config(clef_name: String, level: int) -> Dictionary:
	var lv := clampi(level, 1, 6)
	if clef_name == "Bass":
		match lv:
			1:
				return {"bounds": Vector2i(-2, 2), "accidentals": false, "speed_mult": 0.75}
			2:
				return {"bounds": Vector2i(-4, 2), "accidentals": false, "speed_mult": 1.0}
			3:
				return {"bounds": Vector2i(-4, 12), "accidentals": false, "speed_mult": 1.0}
			4:
				return {"bounds": Vector2i(-4, 12), "accidentals": true, "speed_mult": 1.0}
			5:
				return {"bounds": Vector2i(-4, 12), "accidentals": true, "speed_mult": 1.35}
			_:
				return {"bounds": Vector2i(-4, 12), "accidentals": true, "speed_mult": 1.75}
	match lv:
		1:
			return {"bounds": Vector2i(6, 10), "accidentals": false, "speed_mult": 0.75}
		2:
			return {"bounds": Vector2i(6, 12), "accidentals": false, "speed_mult": 1.0}
		3:
			return {"bounds": Vector2i(-4, 9), "accidentals": false, "speed_mult": 1.0}
		4:
			return {"bounds": Vector2i(-4, 12), "accidentals": true, "speed_mult": 1.0}
		5:
			return {"bounds": Vector2i(-4, 12), "accidentals": true, "speed_mult": 1.35}
		_:
			return {"bounds": Vector2i(-4, 12), "accidentals": true, "speed_mult": 1.75}


func _continuous_choose_accidental_for_letter(letter: String) -> String:
	var opts: Array[String] = []
	# Keep accidental spellings simple/readable for training.
	if letter != "E" and letter != "B":
		opts.append("#")
	if letter != "C" and letter != "F":
		opts.append("b")
	if opts.is_empty():
		return ""
	return opts[_rng.randi_range(0, opts.size() - 1)]


func _continuous_build_pattern_steps(bounds: Vector2i) -> Array[int]:
	var motifs: Array[Array] = [
		[0, 2, 4, 7],    # triad up to octave
		[0, 4, 2, 7],    # broken triad variation
		[0, 2, 4, 2],    # arpeggio turn
		[0, -2, -4, -7], # descending triad
		[0, -4, -2, -7], # descending variation
		[0, 1, 2, 4],    # scale fragment
		[0, -1, -2, -4]  # descending scale fragment
	]
	var motif: Array = motifs[_rng.randi_range(0, motifs.size() - 1)]
	var min_off := 999
	var max_off := -999
	for off_v in motif:
		var off := int(off_v)
		min_off = mini(min_off, off)
		max_off = maxi(max_off, off)
	var root_min := bounds.x + max_off
	var root_max := bounds.y + min_off
	if root_min > root_max:
		var out_fallback: Array[int] = []
		for i in range(4):
			out_fallback.append(_rng.randi_range(bounds.x, bounds.y))
		return out_fallback
	var root_step := _rng.randi_range(root_min, root_max)
	var out: Array[int] = []
	for off_v in motif:
		out.append(root_step - int(off_v))
	return out


func _continuous_build_next_bar_queue(bounds: Vector2i) -> void:
	if _continuous_bar_note_index == 0:
		_continuous_bar_accidentals.clear()
	var pattern_steps: Array[int] = []
	for attempt in range(12):
		pattern_steps = _continuous_build_pattern_steps(bounds)
		if pattern_steps.is_empty():
			continue
		if _continuous_last_spawn_step == 9999 or absi(int(pattern_steps[0]) - _continuous_last_spawn_step) <= 7:
			break
	if not pattern_steps.is_empty() and _continuous_last_spawn_step != 9999 and absi(int(pattern_steps[0]) - _continuous_last_spawn_step) > 7:
		var first_step := int(pattern_steps[0])
		var delta := first_step - _continuous_last_spawn_step
		var target_first := _continuous_last_spawn_step + clampi(delta, -7, 7)
		var shift := target_first - first_step
		for i in range(pattern_steps.size()):
			pattern_steps[i] = clampi(int(pattern_steps[i]) + shift, bounds.x, bounds.y)
	for i in range(pattern_steps.size()):
		var step := int(pattern_steps[i])
		if _continuous_last_spawn_step != 9999 and absi(step - _continuous_last_spawn_step) > 7:
			step = _continuous_last_spawn_step + clampi(step - _continuous_last_spawn_step, -7, 7)
			step = clampi(step, bounds.x, bounds.y)
		var letter := _staff_step_name_for_clef(step, _selected_clef)
		var prior_acc := str(_continuous_bar_accidentals.get(letter, ""))
		var effective_acc := prior_acc
		var explicit_symbol := ""
		var explicit_token := ""
		if _continuous_sight_allow_accidentals:
			if prior_acc != "" and _rng.randf() < _continuous_natural_probability:
				effective_acc = ""
				explicit_symbol = char(0x266E)
				_continuous_bar_accidentals[letter] = ""
			elif _rng.randf() < _continuous_accidental_probability:
				var chosen := _continuous_choose_accidental_for_letter(letter)
				if chosen != "" and chosen != prior_acc:
					effective_acc = chosen
					explicit_token = chosen
					explicit_symbol = char(0x266F) if chosen == "#" else char(0x266D)
					_continuous_bar_accidentals[letter] = chosen
		var bar_line_here := _continuous_bar_note_index == 0 and _continuous_total_spawned_notes > 0
		_continuous_spawn_queue.append({
			"step": step,
			"letter": letter,
			"name": letter + effective_acc,
			"display_name": letter + explicit_symbol,
			"acc_symbol": explicit_symbol,
			"bar_line": bar_line_here
		})
		_continuous_bar_note_index += 1
		_continuous_total_spawned_notes += 1
		_continuous_last_spawn_step = step
		if _continuous_bar_note_index >= 4:
			_continuous_bar_note_index = 0
			_continuous_bar_accidentals.clear()


func _continuous_take_next_note_spec(bounds: Vector2i) -> Dictionary:
	if _continuous_spawn_queue.is_empty():
		_continuous_build_next_bar_queue(bounds)
	if _continuous_spawn_queue.is_empty():
		var s := _rng.randi_range(bounds.x, bounds.y)
		var l := _staff_step_name_for_clef(s, _selected_clef)
		return {"step": s, "letter": l, "name": l, "display_name": l, "acc_symbol": "", "bar_line": false}
	return _continuous_spawn_queue.pop_front()


func _apply_continuous_level_profile() -> void:
	var cfg := _continuous_level_config(_selected_clef, _continuous_sight_level)
	_continuous_sight_level_bounds = cfg.get("bounds", Vector2i(-4, 12))
	_continuous_sight_allow_accidentals = bool(cfg.get("accidentals", false))
	_continuous_sight_speed = _continuous_sight_base_speed * float(cfg.get("speed_mult", 1.0))
	_continuous_accidental_probability = 0.08 if _continuous_sight_level >= 4 else 0.0
	_continuous_natural_probability = 0.20 if _continuous_sight_level >= 4 else 0.0


func _continuous_required_correct_for_level(level: int) -> int:
	return maxi(0, (level - 1) * 8)


func _continuous_try_level_up() -> void:
	var leveled := false
	while _continuous_sight_level < 6 and _continuous_sight_correct_hits >= _continuous_required_correct_for_level(_continuous_sight_level + 1):
		_continuous_sight_level += 1
		_lives += 1
		leveled = true
	if leveled:
		_apply_continuous_level_profile()
		_status_label.text = "Level %d unlocked (+1 Life)" % _continuous_sight_level
		_start_continuous_rest_bar()
		_refresh_meta_ui()


func _continuous_register_miss(play_sfx: bool = true, custom_status: String = "Miss") -> void:
	_continuous_sight_miss_hits += 1
	_score -= 2
	_xp += 2
	_continuous_sight_combo = 0
	_streak = 0
	if not _continuous_testing_no_life_loss:
		_lives = maxi(0, _lives - 1)
	_status_label.text = custom_status
	if play_sfx:
		call_deferred("_play_fail_sfx")
	_refresh_meta_ui()
	if not _continuous_testing_no_life_loss and _lives <= 0:
		_finish_continuous_sight_reading("Game Over")


func _continuous_register_click_miss(custom_status: String = "Miss") -> void:
	# Wrong key clicks count as a miss for score/combo, but do not remove lives.
	_continuous_sight_miss_hits += 1
	_score -= 2
	_xp += 2
	_continuous_sight_combo = 0
	_streak = 0
	_status_label.text = custom_status
	_refresh_meta_ui()


func _clear_continuous_sight_notes() -> void:
	for n in _continuous_sight_notes:
		var p: Panel = n.get("panel", null)
		if p != null and is_instance_valid(p):
			p.queue_free()
		var acc_label: Label = n.get("acc_label", null)
		if acc_label != null and is_instance_valid(acc_label):
			acc_label.queue_free()
		var bar_line: ColorRect = n.get("bar_line", null)
		if bar_line != null and is_instance_valid(bar_line):
			bar_line.queue_free()
		var ledgers: Array = n.get("ledgers", [])
		for ledger in ledgers:
			if ledger != null and is_instance_valid(ledger):
				ledger.queue_free()
	_continuous_sight_notes.clear()


func _setup_continuous_play_line() -> void:
	if _continuous_sight_play_line == null or _staff_area == null:
		return
	_continuous_sight_play_line.visible = _continuous_sight_active
	var top := 20.0
	var h := _staff_area.size.y - 40.0
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		top = _note_chase_staff_frame.position.y + 10.0
		h = _note_chase_staff_frame.size.y - 20.0
	_continuous_sight_play_line.position = Vector2(_continuous_play_line_x() - (_continuous_sight_zone_width * 0.5), top)
	_continuous_sight_play_line.size = Vector2(_continuous_sight_zone_width, h)
	_continuous_sight_play_line.color = Color(0.95, 0.92, 0.74, 0.18)
	_set_continuous_rest_symbol_visible(_continuous_rest_bar_active)


func _set_continuous_rest_symbol_visible(visible: bool) -> void:
	if not visible:
		if _continuous_rest_symbol != null and is_instance_valid(_continuous_rest_symbol):
			_continuous_rest_symbol.visible = false
		return
	if _staff_area == null:
		return
	if _continuous_rest_symbol == null or not is_instance_valid(_continuous_rest_symbol):
		_continuous_rest_symbol = ColorRect.new()
		_continuous_rest_symbol.color = Color(0.95, 0.92, 0.74, 0.88)
		_continuous_rest_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_continuous_rest_symbol.z_index = 248
		_staff_area.add_child(_continuous_rest_symbol)
	var line_y := _staff_center_y_for_step(4)
	var line_x := _continuous_play_line_x()
	_continuous_rest_symbol.visible = true
	_continuous_rest_symbol.size = Vector2(18, 8)
	_continuous_rest_symbol.position = Vector2(line_x + 8.0, line_y)


func _start_continuous_rest_bar() -> void:
	_continuous_rest_bar_active = true
	_continuous_rest_bar_timer = (60.0 / float(maxi(1, _continuous_sight_bpm))) * 4.0
	_clear_continuous_sight_notes()
	_set_continuous_rest_symbol_visible(true)
	_status_label.text = "Level %d rest bar" % _continuous_sight_level
	_apply_answer_mode()


func _spawn_continuous_sight_note(x_offset: float = 0.0, center_x_override: float = NAN) -> void:
	if _staff_area == null:
		return
	var bounds := _continuous_sight_level_bounds if _continuous_sight_active else _effective_sight_step_bounds()
	var note_spec := _continuous_take_next_note_spec(bounds)
	var step := int(note_spec.get("step", _rng.randi_range(bounds.x, bounds.y)))
	var note_name := str(note_spec.get("name", _staff_step_name_for_clef(step, _selected_clef)))
	var display_name := str(note_spec.get("display_name", note_name))
	var accidental_symbol := str(note_spec.get("acc_symbol", ""))
	var has_bar_line := bool(note_spec.get("bar_line", false))
	var center_y := _staff_center_y_for_step(step)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(36, 26)
	p.size = p.custom_minimum_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 246
	_apply_notehead_material(p, Color(0.95, 0.55, 0.24, 0.96), Color(0.10, 0.08, 0.05, 0.85))
	var center_x := _continuous_spawn_x() + x_offset
	if not is_nan(center_x_override):
		center_x = center_x_override
	p.position = Vector2(center_x - (p.size.x * 0.5), center_y - (p.size.y * 0.5))
	_staff_area.add_child(p)
	var bar_line: ColorRect = null
	if has_bar_line:
		bar_line = ColorRect.new()
		bar_line.color = Color(0.94, 0.90, 0.76, 0.60)
		bar_line.size = Vector2(2, (_note_chase_staff_frame.size.y - 20.0) if _note_chase_staff_frame != null and _note_chase_staff_frame.visible else (_staff_area.size.y - 40.0))
		bar_line.position = Vector2(p.position.x - 34.0, (_note_chase_staff_frame.position.y + 10.0) if _note_chase_staff_frame != null and _note_chase_staff_frame.visible else 20.0)
		bar_line.z_index = 244
		bar_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(bar_line)
	var acc_label: Label = null
	if accidental_symbol != "":
		acc_label = Label.new()
		acc_label.text = accidental_symbol
		acc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		acc_label.add_theme_font_size_override("font_size", 28)
		if _ui_font != null:
			acc_label.add_theme_font_override("font", _ui_font)
		acc_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
		acc_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.04, 0.75))
		acc_label.add_theme_constant_override("outline_size", 2)
		acc_label.z_index = 247
		acc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		acc_label.custom_minimum_size = Vector2(20, 28)
		acc_label.position = Vector2(p.position.x - 22.0, p.position.y - 3.0)
		_staff_area.add_child(acc_label)
	var ledgers: Array = []
	var ledger_steps := _ledger_steps_for_note_step(step)
	for ls in ledger_steps:
		var ledger := ColorRect.new()
		ledger.color = _sight_ledger_color
		ledger.size = Vector2(58, 2)
		ledger.position = Vector2((p.position.x + p.size.x * 0.5) - 29.0 + 0.0, _staff_center_y_for_step(int(ls)) - 1.0)
		ledger.z_index = 245
		ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_staff_area.add_child(ledger)
		ledgers.append(ledger)
	_continuous_sight_notes.append({
		"panel": p,
		"name": note_name,
		"display_name": display_name,
		"step": step,
		"seq": _continuous_spawn_seq,
		"answered": false,
		"zone_enter_time": -1.0,
		"bar_line": bar_line,
		"acc_label": acc_label,
		"ledgers": ledgers
	})
	_continuous_spawn_seq += 1


func _seed_continuous_stream_near_line() -> void:
	# Seed notes as if the stream already ran briefly, starting near the hit zone.
	var frame_left := STAFF_LEFT_X - 20.0
	var frame_right := STAFF_LEFT_X + STAFF_LINE_WIDTH + 20.0
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		frame_left = _note_chase_staff_frame.position.x + 14.0
		frame_right = _note_chase_staff_frame.position.x + _note_chase_staff_frame.size.x - 14.0
	var line_x := _continuous_play_line_x()
	var first_center_x := lerpf(frame_left, frame_right, 0.40)
	if first_center_x <= line_x + 28.0:
		first_center_x = line_x + maxf(36.0, _continuous_sight_min_gap * 0.5)
	var spacing := maxf(_continuous_sight_min_gap, 60.0)
	var seed_count := 10
	for i in range(seed_count):
		var center_x := first_center_x + (float(i) * spacing)
		_spawn_continuous_sight_note(0.0, center_x)


func _continuous_zone_bounds() -> Vector2:
	var line_x := _continuous_play_line_x()
	var half_w := _continuous_sight_zone_width * 0.5
	return Vector2(line_x - half_w, line_x + half_w)


func _continuous_note_in_zone(p: Panel) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var bounds := _continuous_zone_bounds()
	var note_left := p.position.x
	var note_right := p.position.x + p.size.x
	return note_right >= bounds.x and note_left <= bounds.y


func _continuous_grade_for_x(note_center_x: float) -> String:
	var bounds := _continuous_zone_bounds()
	if note_center_x < bounds.x or note_center_x > bounds.y:
		return "Miss"
	var split_x := (bounds.x + bounds.y) * 0.5
	# Notes move right-to-left, so early timing is the right half of the zone.
	if note_center_x >= split_x:
		return "Perfect"
	return "Good"


func _continuous_pitch_class_for_token(note_token: String) -> int:
	if note_token.is_empty():
		return -1
	var token := note_token.strip_edges()
	if token.length() < 1:
		return -1
	var letter := token.substr(0, 1).to_upper()
	var base_map := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	if not base_map.has(letter):
		return -1
	var suffix := token.substr(1, token.length() - 1)
	var acc := 0
	if suffix.find("#") >= 0 or suffix.find(char(0x266F)) >= 0:
		acc += 1
	if suffix.find("b") >= 0 or suffix.find(char(0x266D)) >= 0:
		acc -= 1
	return posmod(int(base_map[letter]) + acc, 12)


func _continuous_note_matches_input(expected_token: String, pressed_token: String) -> bool:
	if expected_token == pressed_token:
		return true
	var expected_pc := _continuous_pitch_class_for_token(expected_token)
	var pressed_pc := _continuous_pitch_class_for_token(pressed_token)
	return expected_pc >= 0 and pressed_pc >= 0 and expected_pc == pressed_pc


func _continuous_streak_multiplier() -> int:
	if _continuous_sight_combo < 3:
		return 1
	return _continuous_sight_combo - 1


func _continuous_active_note() -> Dictionary:
	var bounds := _continuous_zone_bounds()
	var center_x := (bounds.x + bounds.y) * 0.5
	var best: Dictionary = {}
	var best_dist := INF
	for n in _continuous_sight_notes:
		var p: Panel = n.get("panel", null)
		if p == null or not is_instance_valid(p):
			continue
		if bool(n.get("answered", false)):
			continue
		if not _continuous_note_in_zone(p):
			continue
		var note_center_x := p.position.x + (p.size.x * 0.5)
		var dist := absf(note_center_x - center_x)
		if dist < best_dist:
			best = n
			best_dist = dist
	return best


func _continuous_active_note_index() -> int:
	var bounds := _continuous_zone_bounds()
	var center_x := (bounds.x + bounds.y) * 0.5
	var best_idx := -1
	var best_dist := INF
	for i in range(_continuous_sight_notes.size()):
		var n := _continuous_sight_notes[i]
		var p: Panel = n.get("panel", null)
		if p == null or not is_instance_valid(p):
			continue
		if bool(n.get("answered", false)):
			continue
		if not _continuous_note_in_zone(p):
			continue
		var note_center_x := p.position.x + (p.size.x * 0.5)
		var dist := absf(note_center_x - center_x)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func _continuous_next_note_in_sequence() -> Dictionary:
	var best: Dictionary = {}
	var best_seq := 999999999
	for n in _continuous_sight_notes:
		var p: Panel = n.get("panel", null)
		if p == null or not is_instance_valid(p):
			continue
		if bool(n.get("answered", false)):
			continue
		var seq_i := int(n.get("seq", 999999999))
		if seq_i < best_seq:
			best_seq = seq_i
			best = n
	return best


func _continuous_next_note_index() -> int:
	var best_idx := -1
	var best_seq := 999999999
	for i in range(_continuous_sight_notes.size()):
		var n := _continuous_sight_notes[i]
		var p: Panel = n.get("panel", null)
		if p == null or not is_instance_valid(p):
			continue
		if bool(n.get("answered", false)):
			continue
		var seq_i := int(n.get("seq", 999999999))
		if seq_i < best_seq:
			best_seq = seq_i
			best_idx = i
	return best_idx


func _continuous_can_spawn_note() -> bool:
	if _continuous_sight_notes.is_empty():
		return true
	var rightmost_center_x := -INF
	for n in _continuous_sight_notes:
		var p: Panel = n.get("panel", null)
		if p == null or not is_instance_valid(p):
			continue
		var center_x := p.position.x + (p.size.x * 0.5)
		if not is_finite(center_x):
			continue
		rightmost_center_x = maxf(rightmost_center_x, center_x)
	if rightmost_center_x == -INF:
		return true
	if (_continuous_spawn_x() - rightmost_center_x) >= _continuous_sight_min_gap:
		return true
	# Safety fallback for low-FPS/mobile edge cases where spacing gate can stall.
	return (_continuous_sight_elapsed - _continuous_last_spawn_elapsed) >= 1.6


func _start_continuous_sight_reading() -> void:
	_continuous_sight_active = true
	_continuous_sight_waiting_start = true
	_continuous_sight_elapsed = 0.0
	_continuous_sight_spawn_timer = 0.0
	_continuous_sight_total_hits = 0
	_continuous_sight_correct_hits = 0
	_continuous_sight_combo = 0
	_continuous_sight_best_combo = 0
	_continuous_sight_perfect_hits = 0
	_continuous_sight_good_hits = 0
	_continuous_sight_miss_hits = 0
	_continuous_sight_reaction_sum = 0.0
	_continuous_sight_reaction_count = 0
	_continuous_sight_level = 1
	_continuous_rest_bar_active = false
	_continuous_rest_bar_timer = 0.0
	_continuous_spawn_queue.clear()
	_continuous_bar_accidentals.clear()
	_continuous_bar_note_index = 0
	_continuous_total_spawned_notes = 0
	_continuous_last_spawn_step = 9999
	_continuous_spawn_seq = 0
	_continuous_last_spawn_elapsed = 0.0
	_lives = 5
	_streak = 0
	_apply_continuous_level_profile()
	_clear_continuous_sight_notes()
	_setup_continuous_play_line()
	_set_continuous_rest_symbol_visible(false)
	_status_label.text = "Tap staff to start. Level 1"
	_prompt_label.text = "Tap staff to start."
	_set_answer_buttons_enabled(true)
	_refresh_continuous_keyboard_range()
	_apply_answer_mode()
	_refresh_meta_ui()


func _finish_continuous_sight_reading(result_title: String = "Complete") -> void:
	_continuous_sight_active = false
	_continuous_sight_waiting_start = false
	_quiz_active = false
	_accepting_answer = false
	_set_answer_buttons_enabled(false)
	if _continuous_sight_play_line != null:
		_continuous_sight_play_line.visible = false
	var acc := int(round((float(_continuous_sight_correct_hits) / float(maxi(1, _continuous_sight_total_hits))) * 100.0))
	var avg_rt_ms := 0.0
	if _continuous_sight_reaction_count > 0:
		avg_rt_ms = (_continuous_sight_reaction_sum / float(_continuous_sight_reaction_count)) * 1000.0
	var summary := "Level %d | Score %d | Accuracy %d%% | Avg RT %.0fms\nPerfect %d  Good %d  Miss %d | Best Combo %d" % [_continuous_sight_level, _score, acc, avg_rt_ms, _continuous_sight_perfect_hits, _continuous_sight_good_hits, _continuous_sight_miss_hits, _continuous_sight_best_combo]
	_progress_label.text = "Session Ended"
	_status_label.text = summary
	_home_info_label.text = summary
	_result_box_show(result_title, summary)
	_clear_continuous_sight_notes()
	_set_continuous_rest_symbol_visible(false)


func _on_continuous_sight_key_pressed(note_name: String) -> void:
	if not _continuous_sight_active or not _quiz_active:
		return
	if _continuous_rest_bar_active:
		return
	_play_sight_answer_click_sfx()
	# Prefer the note currently in the hit zone (more resilient on mobile/tablet FPS jitter).
	var target_idx := _continuous_active_note_index()
	if target_idx < 0:
		target_idx = _continuous_next_note_index()
	if target_idx < 0 or target_idx >= _continuous_sight_notes.size():
		return
	var target := _continuous_sight_notes[target_idx]
	var target_panel: Panel = target.get("panel", null)
	if target_panel == null or not is_instance_valid(target_panel):
		return
	var target_x := 0.0
	var in_window := _continuous_note_in_zone(target_panel)
	target_x = target_panel.position.x + (target_panel.size.x * 0.5)
	var zone_bounds := _continuous_zone_bounds()
	var early_max_x := zone_bounds.y + (_continuous_sight_zone_width * 1.35)
	var early_window := target_x > zone_bounds.y and target_x <= early_max_x
	var did_hit_note := false
	if not in_window and not early_window:
		return
	_continuous_sight_total_hits += 1
	if (in_window or early_window) and _continuous_note_matches_input(str(target.get("name", "")), note_name):
		did_hit_note = true
		var grade := "Good" if early_window and not in_window else _continuous_grade_for_x(target_x)
		var entered_t := float(target.get("zone_enter_time", -1.0))
		if entered_t >= 0.0:
			_continuous_sight_reaction_sum += maxf(0.0, _continuous_sight_elapsed - entered_t)
			_continuous_sight_reaction_count += 1
		_continuous_sight_correct_hits += 1
		_continuous_sight_combo += 1
		_continuous_sight_best_combo = maxi(_continuous_sight_best_combo, _continuous_sight_combo)
		_streak = _continuous_sight_combo
		var mult := _continuous_streak_multiplier()
		var base_points := 10 if grade == "Perfect" else 5
		_score += base_points * mult
		_xp += mult
		if grade == "Perfect":
			_continuous_sight_perfect_hits += 1
		else:
			_continuous_sight_good_hits += 1
		_continuous_sight_notes[target_idx]["answered"] = true
		var pop_center := Vector2(target_x, target_panel.position.y + (target_panel.size.y * 0.5))
		_note_chase_spawn_pop_effect(pop_center, Color(0.72, 1.0, 0.20, 1.0))
		_note_chase_spawn_note_name_text(pop_center, note_name, Color(1.0, 0.96, 0.86, 1.0))
		var note_ledgers: Array = target.get("ledgers", [])
		var bar_line: ColorRect = target.get("bar_line", null)
		var vanish_tw := create_tween()
		vanish_tw.set_trans(Tween.TRANS_SINE)
		vanish_tw.set_ease(Tween.EASE_OUT)
		vanish_tw.tween_property(target_panel, "modulate:a", 0.0, 0.16)
		if bar_line != null and is_instance_valid(bar_line):
			vanish_tw.parallel().tween_property(bar_line, "modulate:a", 0.0, 0.16)
		for ledger_v in note_ledgers:
			if not is_instance_valid(ledger_v):
				continue
			var ledger: ColorRect = ledger_v as ColorRect
			if ledger == null:
				continue
			vanish_tw.parallel().tween_property(ledger, "modulate:a", 0.0, 0.16)
		vanish_tw.finished.connect(func() -> void:
			if is_instance_valid(target_panel):
				target_panel.queue_free()
			if bar_line != null and is_instance_valid(bar_line):
				bar_line.queue_free()
			for ledger_v2 in note_ledgers:
				if not is_instance_valid(ledger_v2):
					continue
				var ledger2: ColorRect = ledger_v2 as ColorRect
				if ledger2 != null:
					ledger2.queue_free()
		)
		_status_label.text = "%s! %s  x%d" % [grade, str(target.get("display_name", note_name)), mult]
		_continuous_try_level_up()
		await _play_success_sfx()
	else:
		_continuous_register_click_miss("Miss")
		await _play_fail_sfx()
	if did_hit_note:
		# Note is removed by vanish tween; keep flow unchanged.
		pass
	_refresh_meta_ui()


func _update_continuous_sight(delta: float) -> void:
	if not _continuous_sight_active:
		return
	if _staff_area == null or _selected_mode != MODE_SIGHT or _sight_mode != "Continuous" or not _game_panel.visible:
		return
	if _continuous_sight_waiting_start:
		return
	_continuous_sight_elapsed += delta
	_setup_continuous_play_line()
	if _continuous_rest_bar_active:
		_continuous_rest_bar_timer = maxf(0.0, _continuous_rest_bar_timer - delta)
		if _continuous_rest_bar_timer <= 0.0:
			_continuous_rest_bar_active = false
			_set_continuous_rest_symbol_visible(false)
			_status_label.text = "Level %d" % _continuous_sight_level
			_apply_answer_mode()
		else:
			return
	_continuous_sight_spawn_timer -= delta
	if _continuous_sight_spawn_timer <= 0.0 and _continuous_can_spawn_note():
		_spawn_continuous_sight_note()
		_continuous_last_spawn_elapsed = _continuous_sight_elapsed
		_continuous_sight_spawn_timer = 60.0 / float(maxi(1, _continuous_sight_bpm))
	var line_x := _continuous_play_line_x()
	var remove_x := -40.0
	var zone_bounds := _continuous_zone_bounds()
	if _note_chase_staff_frame != null and _note_chase_staff_frame.visible:
		remove_x = _note_chase_staff_frame.position.x - 40.0
	for i in range(_continuous_sight_notes.size() - 1, -1, -1):
		var n := _continuous_sight_notes[i]
		var p: Panel = n.get("panel", null)
		if p == null or not is_instance_valid(p):
			_continuous_sight_notes.remove_at(i)
			continue
		p.position.x -= _continuous_sight_speed * delta
		var center_x := p.position.x + (p.size.x * 0.5)
		if float(n.get("zone_enter_time", -1.0)) < 0.0 and center_x <= zone_bounds.y:
			_continuous_sight_notes[i]["zone_enter_time"] = _continuous_sight_elapsed
		var note_ledgers: Array = n.get("ledgers", [])
		var acc_label: Label = n.get("acc_label", null)
		var bar_line: ColorRect = n.get("bar_line", null)
		if acc_label != null and is_instance_valid(acc_label):
			acc_label.position = Vector2(p.position.x - 22.0, p.position.y - 3.0)
			acc_label.modulate = p.modulate
		if bar_line != null and is_instance_valid(bar_line):
			var bar_top := (_note_chase_staff_frame.position.y + 10.0) if _note_chase_staff_frame != null and _note_chase_staff_frame.visible else 20.0
			bar_line.position = Vector2(p.position.x - 34.0, bar_top)
			bar_line.modulate = p.modulate
		var note_step := int(n.get("step", 0))
		var note_ledger_steps := _ledger_steps_for_note_step(note_step)
		for li in range(mini(note_ledgers.size(), note_ledger_steps.size())):
			var ledger_v: Variant = note_ledgers[li]
			if not is_instance_valid(ledger_v):
				continue
			var ledger: ColorRect = ledger_v as ColorRect
			if ledger == null:
				continue
			ledger.position = Vector2(center_x - 29.0 + 0.0, _staff_center_y_for_step(int(note_ledger_steps[li])) - 1.0)
			ledger.modulate = p.modulate
		if center_x < line_x - 6.0:
			var alpha := clampf(p.modulate.a - (delta * 1.8), 0.0, 1.0)
			p.modulate = Color(1, 1, 1, alpha)
		if center_x < remove_x or p.modulate.a <= 0.02:
			if acc_label != null and is_instance_valid(acc_label):
				acc_label.queue_free()
			if bar_line != null and is_instance_valid(bar_line):
				bar_line.queue_free()
			for ledger_v in note_ledgers:
				if not is_instance_valid(ledger_v):
					continue
				var ledger: ColorRect = ledger_v as ColorRect
				if ledger != null:
					ledger.queue_free()
			p.queue_free()
			_continuous_sight_notes.remove_at(i)
	var next_idx := _continuous_next_note_index()
	if next_idx >= 0 and next_idx < _continuous_sight_notes.size():
		var next_note := _continuous_sight_notes[next_idx]
		var next_panel: Panel = next_note.get("panel", null)
		if next_panel != null and is_instance_valid(next_panel):
			var next_x := next_panel.position.x + (next_panel.size.x * 0.5)
			if next_x < zone_bounds.x:
				_continuous_sight_notes[next_idx]["answered"] = true
				_continuous_sight_total_hits += 1
				_continuous_register_miss(true, "Miss")
				if not _continuous_sight_active:
					return
	var acc := int(round((float(_continuous_sight_correct_hits) / float(maxi(1, _continuous_sight_total_hits))) * 100.0))
	_progress_label.text = "LV:%d  ACC:%d%%  P:%d G:%d M:%d  COMBO:%d" % [_continuous_sight_level, acc, _continuous_sight_perfect_hits, _continuous_sight_good_hits, _continuous_sight_miss_hits, _continuous_sight_combo]
	_score_label.text = "Score: %d" % _score


func _on_sight_chord_choice_index(choice_idx: int) -> void:
	if _selected_mode != MODE_SIGHT or _sight_mode != "Chords":
		return
	if not _quiz_active or not _accepting_answer:
		return
	_play_sight_answer_click_sfx()
	if choice_idx < 0 or choice_idx >= _current_sight_chord_choices.size():
		return
	var chosen_name := _current_sight_chord_choices[choice_idx]
	_on_player_answer_committed()

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
		_maybe_play_powerup_on_streak()
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		var granted_shield := _on_chicken_combo_correct()
		_status_label.text = "Correct! It is %s." % _current_sight_chord_name
		if granted_shield:
			_status_label.text += " Chicken shield ready!"
		await _blink_answer_feedback(null, correct_btn, 3)
		await _play_success_sfx()
	else:
		var shielded := _consume_chicken_shield_on_wrong()
		if not shielded:
			_streak = 0
			_lives = maxi(0, _lives - 1)
			_xp = maxi(0, _xp - 2)
			_status_label.text = "Not quite. Correct chord: %s." % _current_sight_chord_name
		else:
			_xp = maxi(0, _xp - 1)
			_status_label.text = "Shield blocked the miss. Correct chord: %s." % _current_sight_chord_name
		await _blink_answer_feedback(chosen_btn, correct_btn, 3)
		await _play_fail_sfx()

	_score_label.text = "Correct: %d / %d" % [_score, _question_index]
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
		_progress_label.text = _final_quiz_result_text(_score, _question_index, _xp)
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		await _play_gameover_fail_sfx()
		if _selected_mode == MODE_SIGHT:
			_set_sight_result_background_hidden(true)
		_result_box_show("Game Over", "No lives left. Restart or Back.")
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
	if _selected_mode == MODE_NOTE_CHASE and _quiz_active and _awaiting_round_start:
		if event is InputEventMouseButton:
			var mb0 := event as InputEventMouseButton
			if mb0.button_index == MOUSE_BUTTON_LEFT and mb0.pressed:
				_on_round_start_pressed()
				accept_event()
				return
	if _selected_mode == MODE_SIGHT and _sight_mode == "Continuous" and _continuous_sight_active and _continuous_sight_waiting_start:
		if event is InputEventScreenTouch:
			var st_start := event as InputEventScreenTouch
			if st_start.pressed:
				_continuous_sight_waiting_start = false
				_continuous_sight_spawn_timer = 0.0
				_seed_continuous_stream_near_line()
				_status_label.text = "Press the key when note hits the line."
				_apply_answer_mode()
				accept_event()
				return
		if event is InputEventMouseButton:
			var mb_start := event as InputEventMouseButton
			if mb_start.button_index == MOUSE_BUTTON_LEFT and mb_start.pressed:
				_continuous_sight_waiting_start = false
				_continuous_sight_spawn_timer = 0.0
				_seed_continuous_stream_near_line()
				_status_label.text = "Press the key when note hits the line."
				_apply_answer_mode()
				accept_event()
				return
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
	var step := int(round((center_y - _active_staff_top_y()) / _active_staff_step_y()))
	var bounds := _effective_sight_step_bounds()
	return clampi(step, bounds.x, bounds.y)


func _active_staff_top_y() -> float:
	if _selected_mode == MODE_NOTE_CHASE and _staff_area != null:
		return clampf(_staff_area.size.y * 0.30, 120.0, 220.0)
	if _selected_mode == MODE_SIGHT and _staff_area != null:
		return clampf(_staff_area.size.y * 0.30, 136.0, 196.0)
	return STAFF_TOP_LINE_Y


func _active_staff_line_gap_y() -> float:
	if _selected_mode == MODE_NOTE_CHASE and _staff_area != null:
		return clampf(_staff_area.size.y * 0.13, 50.0, 70.0)
	if _selected_mode == MODE_SIGHT and _staff_area != null:
		return clampf(_staff_area.size.y * 0.085, 40.0, 52.0)
	return STAFF_LINE_GAP_Y


func _active_staff_step_y() -> float:
	if _selected_mode == MODE_NOTE_CHASE or _selected_mode == MODE_SIGHT:
		return _active_staff_line_gap_y() * 0.5
	return STAFF_STEP_Y


func _staff_center_y_for_step(step: int) -> float:
	var y := _active_staff_top_y() + float(step) * _active_staff_step_y()
	# Keep ledger notes visually centered: lower notes slightly higher, upper notes slightly lower.
	if step > STAFF_BOTTOM_LINE_STEP:
		y -= 2.0
	elif step < STAFF_TOP_LINE_STEP:
		y += 1.0
	# In Note Catcher, bring top ledger notes slightly closer to the top line.
	if _selected_mode == MODE_NOTE_CHASE and _selected_clef == "Treble" and step == -1:
		y += 6.0
	# Treble D4 (space below first line): raise it so top edge sits close to first line.
	if _selected_clef == "Treble" and step == 9:
		y -= 8.0
		if _selected_mode == MODE_SIGHT:
			y += 5.0
	if _selected_mode == MODE_NOTE_CHASE and _selected_clef == "Treble" and step == 9:
		y -= 4.0
	# Treble below-staff ledger notes (B3, A3) should sit closer to ledger line.
	if _selected_clef == "Treble" and step >= 10:
		y -= 4.0
		if _selected_mode == MODE_SIGHT:
			y += 7.0
	# G5 should sit slightly lower so it kisses the top line more naturally.
	if _selected_clef == "Treble" and step == -1:
		y += 2.0
	return y


func _snap_note_to_step(step: int, keep_current_x: bool = false) -> void:
	var center_y := _staff_center_y_for_step(step)
	_staff_note.scale = _note_scale_for_y(center_y)
	var px := _sight_note_snap_x()
	var min_x := STAFF_LEFT_X
	var max_x := STAFF_LEFT_X + STAFF_LINE_WIDTH - _staff_note.size.x
	if _selected_mode == MODE_SIGHT:
		var g := _sight_visual_staff_geometry()
		var left := float(g.get("left", STAFF_LEFT_X))
		var width := float(g.get("width", STAFF_LINE_WIDTH))
		min_x = left
		max_x = left + width - _staff_note.size.x
	if keep_current_x:
		px = _staff_note.position.x
	px = clampf(px, min_x, max_x)
	_staff_note.position = Vector2(px, center_y - (_staff_note.size.y * 0.5))


func _is_in_staff_drop_zone(center_x: float) -> bool:
	if _selected_mode == MODE_SIGHT:
		var g := _sight_visual_staff_geometry()
		var left := float(g.get("left", STAFF_LEFT_X))
		var width := float(g.get("width", STAFF_LINE_WIDTH))
		return center_x >= left and center_x <= (left + width)
	return center_x >= STAFF_LEFT_X and center_x <= (STAFF_LEFT_X + STAFF_LINE_WIDTH)


func _reset_placement_note_to_side() -> void:
	if _staff_note == null:
		return
	var bounds := _effective_sight_step_bounds()
	var home_center_y := _staff_center_y_for_step(clampi(bounds.y - 2, bounds.x, bounds.y))
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
	_on_player_answer_committed()
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
		_maybe_play_powerup_on_streak()
		_xp += 10 + mini(_streak, 10)
		_record_question_correct()
		var granted_shield := _on_chicken_combo_correct()
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
		if granted_shield:
			_status_label.text = "Chicken shield ready!"
	else:
		var shielded := _consume_chicken_shield_on_wrong()
		if not shielded:
			_streak = 0
			_lives = maxi(0, _lives - 1)
			_xp = maxi(0, _xp - 2)
		else:
			_xp = maxi(0, _xp - 1)
			_status_label.text = "Shield blocked the miss."
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

	_score_label.text = "Correct: %d / %d" % [_score, _question_index]
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
		_progress_label.text = _final_quiz_result_text(_score, _question_index, _xp)
		_teacher_record_session_metrics(_selected_mode, _score, _question_index)
		_home_info_label.text = _session_performance_summary()
		await _play_gameover_fail_sfx()
		if _selected_mode == MODE_SIGHT:
			_set_sight_result_background_hidden(true)
		_result_box_show("Game Over", "No lives left. Restart or Back.")
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
	# For notes in spaces outside the staff, keep only one ledger (the lower one).
	if step % 2 != 0 and (step < STAFF_TOP_LINE_STEP or step > STAFF_BOTTOM_LINE_STEP) and out.size() > 1:
		if step > STAFF_BOTTOM_LINE_STEP:
			# Below staff: keep the ledger above the notehead.
			var above := out[0]
			for s in out:
				if s < above:
					above = s
			out = [above]
		else:
			# Above staff: keep the ledger below the notehead (closer to staff).
			var below := out[0]
			for s in out:
				if s > below:
					below = s
			out = [below]
	return out


func _show_preview_ledger(step: int, color: Color) -> void:
	if _staff_preview_ledgers.is_empty():
		return
	_hide_preview_ledger()
	var ledger_steps := _ledger_steps_for_note_step(step)
	for i in range(mini(ledger_steps.size(), _staff_preview_ledgers.size())):
		var y := _active_staff_top_y() + float(ledger_steps[i]) * _active_staff_step_y()
		var pl: ColorRect = _staff_preview_ledgers[i]
		pl.color = color
		pl.position = Vector2((_staff_note.position.x + (_staff_note.size.x * 0.5)) - (pl.size.x * 0.5) + 8.0, y - 1.0)
		pl.visible = true


func _hide_preview_ledger() -> void:
	for pl in _staff_preview_ledgers:
		if pl != null:
			pl.visible = false


func _show_target_dotted_oval(step: int, color: Color, center_x_override: float = -1.0) -> void:
	if _placement_target_dots.is_empty():
		return
	var center_x := _sight_note_snap_x() + (_staff_note.size.x * 0.5)
	if center_x_override >= 0.0:
		center_x = center_x_override
	var center_y := _staff_center_y_for_step(step)
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


func _key_signature_accidental_map() -> Dictionary:
	var m := {"C": 0, "D": 0, "E": 0, "F": 0, "G": 0, "A": 0, "B": 0}
	if _sight_key_signature == "2#":
		m["F"] = 1
		m["C"] = 1
	elif _sight_key_signature == "3#":
		m["F"] = 1
		m["C"] = 1
		m["G"] = 1
	elif _sight_key_signature == "2b":
		m["B"] = -1
		m["E"] = -1
	elif _sight_key_signature == "3b":
		m["B"] = -1
		m["E"] = -1
		m["A"] = -1
	return m


func _note_letter_pitch_class(letter: String, accidental: int) -> int:
	var base_map := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	return posmod(int(base_map.get(letter, 0)) + accidental, 12)


func _triad_quality_from_intervals(i3: int, i5: int) -> String:
	if i3 == 4 and i5 == 7:
		return "Major"
	if i3 == 3 and i5 == 7:
		return "Minor"
	if i3 == 3 and i5 == 6:
		return "Diminished"
	if i3 == 4 and i5 == 6:
		return "Diminished"
	if i3 == 4 and i5 == 8:
		return "Augmented"
	return "Unknown"


func _make_sight_chord_candidate(root_letter: String, third_letter: String, fifth_letter: String, acc_r: int, acc_3: int, acc_5: int, sig_map: Dictionary) -> Dictionary:
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	var pc_r := _note_letter_pitch_class(root_letter, acc_r)
	var pc_3 := _note_letter_pitch_class(third_letter, acc_3)
	var pc_5 := _note_letter_pitch_class(fifth_letter, acc_5)
	var quality := _triad_quality_from_intervals(posmod(pc_3 - pc_r, 12), posmod(pc_5 - pc_r, 12))
	if quality == "Unknown":
		return {}
	var root_name := root_letter
	if acc_r > 0:
		root_name += sharp_sym
	elif acc_r < 0:
		root_name += flat_sym
	var display_quality := quality
	if display_quality == "Dim":
		display_quality = "Diminished"
	elif display_quality == "Aug":
		display_quality = "Augmented"
	var is_accidental := acc_r != int(sig_map.get(root_letter, 0))
	is_accidental = is_accidental or acc_3 != int(sig_map.get(third_letter, 0))
	is_accidental = is_accidental or acc_5 != int(sig_map.get(fifth_letter, 0))
	return {
		"root_letter": root_letter,
		"quality": quality,
		"name": "%s %s" % [root_name, display_quality],
		"tone_letters": [root_letter, third_letter, fifth_letter],
		"tone_accidentals": [acc_r, acc_3, acc_5],
		"is_accidental": is_accidental
	}


func _key_signature_tonic_info() -> Dictionary:
	match _sight_key_signature:
		"2#":
			return {"letter": "D", "acc": 0}
		"3#":
			return {"letter": "A", "acc": 0}
		"2b":
			return {"letter": "B", "acc": -1}
		"3b":
			return {"letter": "E", "acc": -1}
		_:
			return {"letter": "C", "acc": 0}


func _scale_letter_from_tonic(tonic_letter: String, degree_offset: int) -> String:
	var idx := NOTE_NAME_ORDER.find(tonic_letter)
	if idx < 0:
		idx = 0
	return str(NOTE_NAME_ORDER[posmod(idx + degree_offset, NOTE_NAME_ORDER.size())])


func _build_accidental_rule_candidate(root_letter: String, target_quality: String, sig_map: Dictionary) -> Dictionary:
	var root_i := NOTE_NAME_ORDER.find(root_letter)
	if root_i < 0:
		return {}
	var third_letter := str(NOTE_NAME_ORDER[(root_i + 2) % 7])
	var fifth_letter := str(NOTE_NAME_ORDER[(root_i + 4) % 7])
	var root_acc := int(sig_map.get(root_letter, 0))
	var key_acc3 := int(sig_map.get(third_letter, 0))
	var key_acc5 := int(sig_map.get(fifth_letter, 0))
	var target_i3 := 4
	var target_i5 := 7
	match target_quality:
		"Major":
			target_i3 = 4
			target_i5 = 7
		"Minor":
			target_i3 = 3
			target_i5 = 7
		"Augmented":
			target_i3 = 4
			target_i5 = 8
		"Diminished":
			# User-requested diminished spelling: major 3rd + flat 5th.
			target_i3 = 4
			target_i5 = 6
		_:
			return {}
	var best_a3 := key_acc3
	var best_a5 := key_acc5
	var best_score := 999999
	var found := false
	for a3 in range(-2, 3):
		for a5 in range(-2, 3):
			var pc_r := _note_letter_pitch_class(root_letter, root_acc)
			var pc_3 := _note_letter_pitch_class(third_letter, a3)
			var pc_5 := _note_letter_pitch_class(fifth_letter, a5)
			var i3 := posmod(pc_3 - pc_r, 12)
			var i5 := posmod(pc_5 - pc_r, 12)
			if i3 != target_i3 or i5 != target_i5:
				continue
			var score := absi(a3 - key_acc3) + absi(a5 - key_acc5)
			if score < best_score:
				best_score = score
				best_a3 = a3
				best_a5 = a5
				found = true
	if not found:
		return {}
	return _make_sight_chord_candidate(root_letter, third_letter, fifth_letter, root_acc, best_a3, best_a5, sig_map)


func _sight_chord_candidates(include_accidental_variants: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sig_map := _key_signature_accidental_map()
	var seen: Dictionary = {}
	for root_letter in NOTE_NAME_ORDER:
		var r := str(root_letter)
		var root_i := NOTE_NAME_ORDER.find(r)
		if root_i < 0:
			continue
		var third_letter: String = str(NOTE_NAME_ORDER[(root_i + 2) % 7])
		var fifth_letter: String = str(NOTE_NAME_ORDER[(root_i + 4) % 7])
		var acc_r := int(sig_map.get(r, 0))
		var acc_3 := int(sig_map.get(third_letter, 0))
		var acc_5 := int(sig_map.get(fifth_letter, 0))
		var base := _make_sight_chord_candidate(r, third_letter, fifth_letter, acc_r, acc_3, acc_5, sig_map)
		if base.is_empty():
			continue
		var base_key := "%s|%d|%d|%d|%s" % [str(base.get("name", "")), acc_r, acc_3, acc_5, str(base.get("quality", ""))]
		if not seen.has(base_key):
			seen[base_key] = true
			out.append(base)
	if include_accidental_variants:
		var tonic := _key_signature_tonic_info()
		var tonic_letter := str(tonic.get("letter", "C"))
		var rule_specs := [
			{"root": _scale_letter_from_tonic(tonic_letter, 0), "quality": "Minor"},       # i minor (e.g., C minor)
			{"root": _scale_letter_from_tonic(tonic_letter, 3), "quality": "Minor"},       # iv minor (e.g., F minor)
			{"root": _scale_letter_from_tonic(tonic_letter, 0), "quality": "Augmented"},   # I augmented
			{"root": _scale_letter_from_tonic(tonic_letter, 0), "quality": "Diminished"},  # I diminished (requested spelling)
			{"root": _scale_letter_from_tonic(tonic_letter, 1), "quality": "Major"},       # II major (e.g., D major)
			{"root": _scale_letter_from_tonic(tonic_letter, 2), "quality": "Major"}        # III major (e.g., E major)
		]
		for spec in rule_specs:
			var root_spec := str(spec.get("root", "C"))
			var quality_spec := str(spec.get("quality", "Major"))
			var alt := _build_accidental_rule_candidate(root_spec, quality_spec, sig_map)
			if alt.is_empty():
				continue
			if not bool(alt.get("is_accidental", false)):
				continue
			var aarr: Array = alt.get("tone_accidentals", [0, 0, 0])
			var alt_key := "%s|%d|%d|%d|%s" % [
				str(alt.get("name", "")),
				int(aarr[0]),
				int(aarr[1]),
				int(aarr[2]),
				str(alt.get("quality", ""))
			]
			if not seen.has(alt_key):
				seen[alt_key] = true
				out.append(alt)
	# Keep candidates strictly consistent with the selected key signature, so
	# drawn notes and answer labels always match.
	return out

func _generate_sight_chord_round() -> void:
	var triad: Dictionary = {}
	var centers: Array[float] = []
	var found := false
	var chosen_inversion := 0
	var include_accidental_variants := _sight_accidentals_toggle != null and _sight_accidentals_toggle.button_pressed
	var candidates := _sight_chord_candidates(include_accidental_variants)
	if include_accidental_variants:
		var accidental_pool: Array[Dictionary] = []
		var normal_pool: Array[Dictionary] = []
		for c in candidates:
			if bool(c.get("is_accidental", false)):
				accidental_pool.append(c)
			else:
				normal_pool.append(c)
		if not accidental_pool.is_empty() and not normal_pool.is_empty():
			candidates = accidental_pool if _rng.randf() < 0.5 else normal_pool
		elif not accidental_pool.is_empty():
			candidates = accidental_pool
	if candidates.is_empty():
		candidates = [{"root_letter": "C", "quality": "Major", "name": "C Major", "tone_letters": ["C", "E", "G"], "tone_accidentals": [0, 0, 0]}]
	for attempt in range(40):
		var t: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
		var root_t := str(t.get("root_letter", "C"))
		var quality_t := str(t.get("quality", "Major"))
		var inversion_t := _rng.randi_range(0, 2)
		var c := _pick_staff_centers_for_triad(root_t, quality_t, inversion_t)
		if not c.is_empty():
			triad = t
			centers = c
			chosen_inversion = inversion_t
			found = true
			break
	if not found:
		for t in candidates:
			var root_t := str(t.get("root_letter", "C"))
			var quality_t := str(t.get("quality", "Major"))
			for inversion_t in [0, 1, 2]:
				var c := _pick_staff_centers_for_triad(root_t, quality_t, inversion_t)
				if c.is_empty():
					continue
				triad = t
				centers = c
				chosen_inversion = inversion_t
				found = true
				break
			if found:
				break
	if not found:
		# Last-resort safe fallback that still matches labeling.
		triad = {"root_letter": "C", "quality": "Major", "name": "C Major", "tone_letters": ["C", "E", "G"], "tone_accidentals": [0, 0, 0]}
		centers = _pick_staff_centers_for_triad("C", "Major", 0)
		chosen_inversion = 0
		if centers.is_empty():
			var b := _effective_sight_step_bounds()
			centers = [_staff_center_y_for_step(b.y), _staff_center_y_for_step(maxi(b.x, b.y - 2)), _staff_center_y_for_step(maxi(b.x, b.y - 4))]

	var display_accidentals: Array[int] = [0, 0, 0]
	var display_letters: Array[String] = ["C", "E", "G"]
	var base_acc: Array = triad.get("tone_accidentals", [0, 0, 0])
	var base_letters: Array = triad.get("tone_letters", ["C", "E", "G"])
	if base_acc.size() >= 3:
		if chosen_inversion == 1:
			display_accidentals = [int(base_acc[1]), int(base_acc[2]), int(base_acc[0])]
			display_letters = [str(base_letters[1]), str(base_letters[2]), str(base_letters[0])]
		elif chosen_inversion == 2:
			display_accidentals = [int(base_acc[2]), int(base_acc[0]), int(base_acc[1])]
			display_letters = [str(base_letters[2]), str(base_letters[0]), str(base_letters[1])]
		else:
			display_accidentals = [int(base_acc[0]), int(base_acc[1]), int(base_acc[2])]
			display_letters = [str(base_letters[0]), str(base_letters[1]), str(base_letters[2])]
	triad["display_accidentals"] = display_accidentals
	triad["display_letters"] = display_letters
	_current_sight_chord_def = triad
	_current_sight_chord_name = str(triad.get("name", "C Major"))
	_position_sight_chord(centers, triad)

	var all_names: Array[String] = []
	for t in candidates:
		all_names.append(str(t.get("name", "C Major")))
	_current_sight_chord_choices = _build_sight_chord_choices(_current_sight_chord_name, all_names)
	for i in _sight_chord_choice_buttons.size():
		if i >= _current_sight_chord_choices.size():
			continue
		_sight_chord_choice_buttons[i].text = _current_sight_chord_choices[i]

func _generate_sight_placement_round() -> void:
	for n in _staff_chord_notes:
		n.visible = false
	for lbl in _staff_chord_accidental_labels:
		if lbl != null:
			lbl.visible = false
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
	var root_letter := str(NOTE_NAME_ORDER[root_i])
	var third_letter := str(NOTE_NAME_ORDER[third_i])
	var fifth_letter := str(NOTE_NAME_ORDER[fifth_i])
	# Placement is based on chord-tone letters; accidentals are rendered
	# separately next to the matching noteheads.
	var tones_low_to_high: Array[String] = []
	if inversion == 0:
		tones_low_to_high = [root_letter, third_letter, fifth_letter]
	elif inversion == 1:
		tones_low_to_high = [third_letter, fifth_letter, root_letter]
	else:
		tones_low_to_high = [fifth_letter, root_letter, third_letter]
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
				var c0 := _staff_center_y_for_step(s0)
				var c1 := _staff_center_y_for_step(s1)
				var c2 := _staff_center_y_for_step(s2)
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
		return []

	step_triplets.sort_custom(func(a: Array, b: Array) -> bool:
		var da: float = absf(float(a[0]) - 10.0)
		var db: float = absf(float(b[0]) - 10.0)
		return da < db
	)
	var top_bucket: int = mini(3, step_triplets.size()) - 1
	var picked: Array = step_triplets[_rng.randi_range(0, top_bucket)]
	return [
		_staff_center_y_for_step(picked[0]),
		_staff_center_y_for_step(picked[1]),
		_staff_center_y_for_step(picked[2])
	]


func _has_sight_chord_available_in_range() -> bool:
	for triad in _sight_chord_candidates():
		var root := str(triad.get("root_letter", "C"))
		var quality := str(triad.get("quality", "Major"))
		for inversion in [0, 1, 2]:
			var centers := _pick_staff_centers_for_triad(root, quality, inversion)
			if not centers.is_empty():
				return true
	return false


func _position_sight_chord(note_centers: Array[float], chord_def: Dictionary = {}) -> void:
	if _staff_note == null:
		return
	if _selected_mode == MODE_SIGHT:
		_pick_random_sight_visual_colors()
		_apply_sight_note_palette()
	if _staff_clef_label != null:
		_staff_clef_label.text = char(0x1D122) if _selected_clef == "Bass" else char(0x1D11E)
	if note_centers.size() < 3:
		return

	var x := _sight_note_snap_x()
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

	var tone_accidentals: Array = chord_def.get("display_accidentals", chord_def.get("tone_accidentals", [0, 0, 0]))
	var tone_letters: Array = chord_def.get("display_letters", chord_def.get("tone_letters", ["C", "E", "G"]))
	var sig_map := _key_signature_accidental_map()
	var sharp_sym := char(0x266F)
	var flat_sym := char(0x266D)
	var all_note_panels: Array[Panel] = [_staff_note]
	all_note_panels.append_array(_staff_chord_notes)
	for i in range(_staff_chord_accidental_labels.size()):
		var acc_lbl := _staff_chord_accidental_labels[i]
		if acc_lbl == null:
			continue
		if i >= note_centers.size() or i >= all_note_panels.size():
			acc_lbl.visible = false
			continue
		var acc_val := int(tone_accidentals[i]) if i < tone_accidentals.size() else 0
		var letter := str(tone_letters[i]) if i < tone_letters.size() else "C"
		var key_acc := int(sig_map.get(letter, 0))
		var needed_acc := acc_val - key_acc
		if needed_acc == 0:
			acc_lbl.visible = false
			continue
		var p := all_note_panels[i]
		acc_lbl.text = sharp_sym if needed_acc > 0 else flat_sym
		acc_lbl.visible = true
		# Use rendered (scaled) note center so accidental stays aligned in inversions.
		var center_y := p.position.y + (p.size.y * p.scale.y * 0.5)
		var note_left := p.position.x
		var y_adjust := -8.0 if needed_acc < 0 else -1.0
		acc_lbl.position = Vector2(note_left - 24.0, center_y - (acc_lbl.size.y * 0.5) + y_adjust)

	_stop_sight_note_bounce()
	_start_sight_note_bounce()


func _update_staff_ledger_lines_for_notes(note_centers: Array[float], note_center_x: float) -> void:
	_clear_staff_ledger_lines()
	var needed: Array[float] = []
	for note_center_y in note_centers:
		var step := int(round((note_center_y - _active_staff_top_y()) / _active_staff_step_y()))
		var ledger_steps := _ledger_steps_for_note_step(step)
		for s in ledger_steps:
			var y := _active_staff_top_y() + float(s) * _active_staff_step_y()
			if not needed.has(y):
				needed.append(y)
	needed.sort()
	for yv in needed:
		_add_staff_ledger_line(float(yv), note_center_x)


func _pick_sight_note_slot() -> Dictionary:
	var step := _rng.randi_range(_sight_range_min_step, _sight_range_max_step)
	var base_name := _staff_step_name_for_clef(step, _selected_clef)
	var display_name := _sight_note_name_with_key_signature(base_name)
	return {
		"name": display_name,
		"base_name": base_name,
		"center_y": _staff_center_y_for_step(step),
		"step": step
	}


func _pick_random_sight_visual_colors() -> void:
	if SIGHT_NOTE_COLORS.is_empty():
		_sight_note_color = Color(1.0, 0.47, 0.73, 0.98)
		_sight_ledger_color = Color(0.35, 0.58, 0.98, 0.98)
		return
	var i0 := _rng.randi_range(0, SIGHT_NOTE_COLORS.size() - 1)
	var i1 := _rng.randi_range(0, SIGHT_NOTE_COLORS.size() - 1)
	if SIGHT_NOTE_COLORS.size() > 1:
		var guard := 0
		while i1 == i0 and guard < 8:
			i1 = _rng.randi_range(0, SIGHT_NOTE_COLORS.size() - 1)
			guard += 1
	_sight_note_color = SIGHT_NOTE_COLORS[i0]
	_sight_ledger_color = SIGHT_NOTE_COLORS[i1]


func _pick_random_sight_frame_border_color() -> void:
	if SIGHT_NOTE_COLORS.is_empty():
		_sight_staff_frame_border_color = Color(0.95, 0.84, 0.42, 0.88)
		return
	_sight_staff_frame_border_color = SIGHT_NOTE_COLORS[_rng.randi_range(0, SIGHT_NOTE_COLORS.size() - 1)]


func _notehead_lift_color(c: Color, amount: float) -> Color:
	return Color(
		clampf(c.r + amount, 0.0, 1.0),
		clampf(c.g + amount, 0.0, 1.0),
		clampf(c.b + amount, 0.0, 1.0),
		c.a
	)


func _ensure_note_layer(panel: Panel, node_name: String, z: int) -> Panel:
	var existing := panel.get_node_or_null(node_name)
	if existing != null and existing is Panel:
		var p := existing as Panel
		p.z_index = z
		return p
	var layer := Panel.new()
	layer.name = node_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	panel.add_child(layer)
	return layer


func _apply_notehead_shimmer(panel: Panel, base_color: Color) -> void:
	if panel == null:
		return
	var shimmer_a := _ensure_note_layer(panel, "MatShimmerA", 3)
	var shimmer_b := _ensure_note_layer(panel, "MatShimmerB", 3)
	shimmer_a.visible = NOTEHEAD_SHIMMER_ENABLED
	shimmer_b.visible = NOTEHEAD_SHIMMER_ENABLED

	var shimmer_key := "%0.3f|%0.3f|%0.3f|%0.3f|%0.1f|%0.1f" % [base_color.r, base_color.g, base_color.b, base_color.a, panel.size.x, panel.size.y]
	var old_tween_variant: Variant = null
	var old_key := ""
	if panel.has_meta("note_shimmer_tween"):
		old_tween_variant = panel.get_meta("note_shimmer_tween")
	if panel.has_meta("note_shimmer_key"):
		old_key = str(panel.get_meta("note_shimmer_key"))
	if NOTEHEAD_SHIMMER_ENABLED and old_key == shimmer_key and old_tween_variant != null and old_tween_variant is Tween:
		var running_tween := old_tween_variant as Tween
		if running_tween != null and is_instance_valid(running_tween):
			return
	if old_tween_variant != null and old_tween_variant is Tween:
		var old_tween := old_tween_variant as Tween
		if old_tween != null and is_instance_valid(old_tween):
			old_tween.kill()
	panel.set_meta("note_shimmer_tween", null)
	panel.set_meta("note_shimmer_key", shimmer_key)
	if not NOTEHEAD_SHIMMER_ENABLED:
		return

	var w := panel.size.x
	var h := panel.size.y
	shimmer_a.size = Vector2(w * 0.30, h * 0.86)
	shimmer_a.position = Vector2(w * 0.10, h * 0.06)
	var sa := StyleBoxFlat.new()
	sa.bg_color = _notehead_lift_color(base_color, 0.34)
	sa.bg_color.a = 0.12
	sa.corner_radius_top_left = int(round(shimmer_a.size.y * 0.46))
	sa.corner_radius_top_right = int(round(shimmer_a.size.y * 0.46))
	sa.corner_radius_bottom_left = int(round(shimmer_a.size.y * 0.46))
	sa.corner_radius_bottom_right = int(round(shimmer_a.size.y * 0.46))
	shimmer_a.add_theme_stylebox_override("panel", sa)

	shimmer_b.size = Vector2(w * 0.18, h * 0.74)
	shimmer_b.position = Vector2(w * 0.56, h * 0.14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _notehead_lift_color(base_color, 0.42)
	sb.bg_color.a = 0.07
	sb.corner_radius_top_left = int(round(shimmer_b.size.y * 0.46))
	sb.corner_radius_top_right = int(round(shimmer_b.size.y * 0.46))
	sb.corner_radius_bottom_left = int(round(shimmer_b.size.y * 0.46))
	sb.corner_radius_bottom_right = int(round(shimmer_b.size.y * 0.46))
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


func _apply_notehead_material(panel: Panel, base_color: Color, border_color: Color) -> void:
	if panel == null:
		return
	var rx := int(round(maxf(6.0, panel.size.x * 0.5)))
	var ry := int(round(maxf(6.0, panel.size.y * 0.5)))
	var body := StyleBoxFlat.new()
	body.bg_color = base_color
	body.corner_radius_top_left = rx
	body.corner_radius_top_right = rx
	body.corner_radius_bottom_left = rx
	body.corner_radius_bottom_right = rx
	body.border_width_left = 2
	body.border_width_top = 2
	body.border_width_right = 2
	body.border_width_bottom = 2
	body.border_color = border_color
	panel.add_theme_stylebox_override("panel", body)

	var shadow := _ensure_note_layer(panel, "MatShadow", -2)
	shadow.size = panel.size + Vector2(8, 6)
	shadow.position = Vector2(-2, 2)
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	shadow_sb.corner_radius_top_left = rx
	shadow_sb.corner_radius_top_right = rx
	shadow_sb.corner_radius_bottom_left = rx
	shadow_sb.corner_radius_bottom_right = rx
	shadow.add_theme_stylebox_override("panel", shadow_sb)

	var gloss := _ensure_note_layer(panel, "MatGloss", 2)
	gloss.size = Vector2(panel.size.x * 0.52, panel.size.y * 0.34)
	gloss.position = Vector2(panel.size.x * 0.16, panel.size.y * 0.12)
	var gloss_sb := StyleBoxFlat.new()
	gloss_sb.bg_color = _notehead_lift_color(base_color, 0.28)
	gloss_sb.bg_color.a = 0.62
	gloss_sb.corner_radius_top_left = int(round(gloss.size.y * 0.9))
	gloss_sb.corner_radius_top_right = int(round(gloss.size.y * 0.9))
	gloss_sb.corner_radius_bottom_left = int(round(gloss.size.y * 0.9))
	gloss_sb.corner_radius_bottom_right = int(round(gloss.size.y * 0.9))
	gloss.add_theme_stylebox_override("panel", gloss_sb)
	_apply_notehead_shimmer(panel, base_color)


func _apply_sight_note_color(panel: Panel) -> void:
	if panel == null:
		return
	_apply_notehead_material(panel, _sight_note_color, Color(0.08, 0.08, 0.10, 0.9))


func _apply_sight_note_palette() -> void:
	_apply_sight_note_color(_staff_note)
	for n in _staff_chord_notes:
		_apply_sight_note_color(n)


func _clear_staff_ledger_lines() -> void:
	for line in _staff_ledger_lines:
		if is_instance_valid(line):
			line.queue_free()
	_staff_ledger_lines.clear()


func _add_staff_ledger_line(line_y: float, center_x: float) -> void:
	if _staff_area == null:
		return
	var ledger := ColorRect.new()
	ledger.color = _sight_ledger_color
	ledger.size = Vector2(96, 2)
	ledger.position = Vector2(center_x - 48.0 + 8.0, line_y - 1.0)
	ledger.z_index = 130
	_staff_area.add_child(ledger)
	_staff_ledger_lines.append(ledger)


func _update_staff_ledger_lines(note_center_y: float, note_center_x: float) -> void:
	_update_staff_ledger_lines_for_notes([note_center_y], note_center_x)


func _show_sight_note_accidental_for_current_note() -> void:
	if _staff_chord_accidental_labels.is_empty():
		return
	var lbl := _staff_chord_accidental_labels[0]
	if lbl == null:
		return
	# Notes mode key-signature behavior uses implied accidentals.
	# Keep the notehead clean (no explicit accidental symbol) here.
	lbl.visible = false


func _position_sight_note(note_name: String, center_y_override: float = NAN) -> void:
	if _staff_note == null:
		return
	if _selected_mode == MODE_SIGHT:
		_pick_random_sight_visual_colors()
		_apply_sight_note_palette()
	for n in _staff_chord_notes:
		n.visible = false
	for lbl in _staff_chord_accidental_labels:
		if lbl != null:
			lbl.visible = false
	var center_y := center_y_override
	if _selected_mode == MODE_SIGHT:
		var bounds := _effective_sight_step_bounds()
		if is_nan(center_y):
			_current_sight_display_step = _closest_step_for_note_name_in_bounds(note_name, _selected_clef, bounds)
		else:
			_current_sight_display_step = _nearest_staff_step_from_center_y(center_y)
		_current_sight_display_step = clampi(_current_sight_display_step, bounds.x, bounds.y)
		center_y = _staff_center_y_for_step(_current_sight_display_step)
		var base_note := _staff_step_name_for_clef(_current_sight_display_step, _selected_clef)
		_current_sight_note = _sight_note_name_with_key_signature(base_note) if _sight_mode == "Notes" else base_note
	if _selected_clef == "Bass":
		if _staff_clef_label != null:
			_staff_clef_label.text = char(0x1D122)
		if is_nan(center_y):
			var bass_center_map := {"C": 160.0, "D": 144.0, "E": 128.0, "F": 112.0, "G": 96.0, "A": 80.0, "B": 64.0}
			center_y = float(bass_center_map.get(note_name, 160.0))
	else:
		if _staff_clef_label != null:
			_staff_clef_label.text = char(0x1D11E)
		if is_nan(center_y):
			var treble_center_map := {"C": 112.0, "D": 96.0, "E": 80.0, "F": 64.0, "G": 48.0, "A": 32.0, "B": 16.0}
			center_y = float(treble_center_map.get(note_name, 112.0))
		if _selected_mode != MODE_SIGHT:
			center_y += 2.0
	if _selected_mode == MODE_SIGHT:
		var b := _effective_sight_step_bounds()
		_current_sight_display_step = clampi(_current_sight_display_step, b.x, b.y)
		center_y = _staff_center_y_for_step(_current_sight_display_step) + SIGHT_NOTE_CENTER_OFFSET_Y
		var base_note2 := _staff_step_name_for_clef(_current_sight_display_step, _selected_clef)
		_current_sight_note = _sight_note_name_with_key_signature(base_note2) if _sight_mode == "Notes" else base_note2
	var top_left_y := center_y - (_staff_note.size.y * 0.5)
	_staff_note.scale = _note_scale_for_y(center_y)
	_staff_note.position = Vector2(_sight_note_snap_x(), top_left_y)
	var center_x := _staff_note.position.x + (_staff_note.size.x * 0.5)
	_update_staff_ledger_lines(center_y, center_x)
	_show_sight_note_accidental_for_current_note()
	_start_sight_note_bounce()


func _closest_step_for_note_name_in_bounds(note_name: String, clef_name: String, bounds: Vector2i) -> int:
	var start: int = clampi(_current_sight_display_step, bounds.x, bounds.y)
	var best: int = start
	var best_dist: int = 999999
	for s in range(bounds.x, bounds.y + 1):
		if _staff_step_name_for_clef(s, clef_name) != note_name:
			continue
		var d: int = absi(s - start)
		if d < best_dist:
			best_dist = d
			best = s
	return best


func _sight_note_snap_x() -> float:
	if _staff_area == null:
		return STAFF_NOTE_SNAP_X
	if _selected_mode == MODE_SIGHT:
		var g := _sight_visual_staff_geometry()
		var left := float(g.get("left", STAFF_LEFT_X))
		var width := float(g.get("width", STAFF_LINE_WIDTH))
		return left + (width * 0.30)
	var usable_w := maxf(260.0, _staff_area.size.x - STAFF_LEFT_X)
	# Slightly center-left anchor for better readability on large screens.
	return STAFF_LEFT_X + (usable_w * 0.26)


func _note_scale_for_y(center_y: float) -> Vector2:
	if _selected_mode == MODE_NOTE_CHASE:
		return Vector2(1.0, 1.0)
	if _selected_mode == MODE_SIGHT:
		var ts := clampf((center_y - (_active_staff_top_y() - 120.0)) / 520.0, 0.0, 1.0)
		var ss := lerpf(1.01, 1.15, ts)
		return Vector2(ss, ss)
	var t := clampf((center_y - (STAFF_TOP_LINE_Y - 110.0)) / 460.0, 0.0, 1.0)
	var s := lerpf(1.06, 1.26, t)
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


func _play_sight_note_correct_bounce_once() -> void:
	if _staff_note == null or not _staff_note.visible:
		return
	_stop_sight_note_bounce()
	var y0 := _staff_note.position.y
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_staff_note, "position:y", y0 - 10.0, 0.10)
	t.tween_property(_staff_note, "position:y", y0, 0.14).set_ease(Tween.EASE_IN)
	await t.finished
	_staff_note.position.y = y0
	if _selected_mode == MODE_SIGHT:
		_start_sight_note_bounce()


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
	normal.bg_color = Color(0.90, 0.80, 0.45, 0.98)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_color = Color(0.30, 0.22, 0.08, 0.92)
	normal.border_width_left = 2
	normal.border_width_top = 3
	normal.border_width_right = 2
	normal.border_width_bottom = 6
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	normal.shadow_size = 6
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.97, 0.87, 0.50, 1.0)
	hover.shadow_size = 8
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.76, 0.63, 0.33, 1.0)
	pressed.shadow_size = 2
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.20, 0.14, 0.06))
	btn.add_theme_color_override("font_hover_color", Color(0.16, 0.10, 0.04))
	btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.30))
	btn.add_theme_constant_override("outline_size", 1)


func _ensure_key_layer(btn: Button, name: String, z: int) -> Panel:
	var layer := btn.get_node_or_null(name) as Panel
	if layer != null:
		return layer
	layer = Panel.new()
	layer.name = name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	btn.add_child(layer)
	return layer


func _apply_virtual_key_finish(btn: Button, is_black: bool) -> void:
	if btn == null:
		return
	var gloss := _ensure_key_layer(btn, "KeyGloss", 30)
	var shade := _ensure_key_layer(btn, "KeyShade", 28)
	if is_black:
		gloss.size = Vector2(btn.size.x * 0.62, maxf(12.0, btn.size.y * 0.20))
		gloss.position = Vector2(btn.size.x * 0.18, 2.0)
		var gloss_sb_black := StyleBoxFlat.new()
		gloss_sb_black.bg_color = Color(1.0, 1.0, 1.0, 0.18)
		gloss_sb_black.corner_radius_top_left = 4
		gloss_sb_black.corner_radius_top_right = 4
		gloss_sb_black.corner_radius_bottom_left = 6
		gloss_sb_black.corner_radius_bottom_right = 6
		gloss.add_theme_stylebox_override("panel", gloss_sb_black)
		shade.size = Vector2(btn.size.x, maxf(12.0, btn.size.y * 0.32))
		shade.position = Vector2(0.0, btn.size.y - shade.size.y)
		var shade_sb_black := StyleBoxFlat.new()
		shade_sb_black.bg_color = Color(0.0, 0.0, 0.0, 0.26)
		shade_sb_black.corner_radius_top_left = 0
		shade_sb_black.corner_radius_top_right = 0
		shade_sb_black.corner_radius_bottom_left = 6
		shade_sb_black.corner_radius_bottom_right = 6
		shade.add_theme_stylebox_override("panel", shade_sb_black)
	else:
		gloss.size = Vector2(btn.size.x * 0.74, maxf(14.0, btn.size.y * 0.18))
		gloss.position = Vector2(btn.size.x * 0.12, 3.0)
		var gloss_sb := StyleBoxFlat.new()
		gloss_sb.bg_color = Color(1.0, 1.0, 1.0, 0.42)
		gloss_sb.corner_radius_top_left = 5
		gloss_sb.corner_radius_top_right = 5
		gloss_sb.corner_radius_bottom_left = 10
		gloss_sb.corner_radius_bottom_right = 10
		gloss.add_theme_stylebox_override("panel", gloss_sb)
		# Keep white keys clean; bottom band looked too gray on tablets.
		shade.visible = false


func _style_virtual_piano_key_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.97, 0.96, 0.92, 1.0)
	normal.corner_radius_top_left = 2
	normal.corner_radius_top_right = 2
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.border_color = Color(0.12, 0.12, 0.10, 0.9)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.shadow_color = Color(0, 0, 0, 0.22)
	normal.shadow_size = 2
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.99, 0.95, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.88, 0.87, 0.82, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.12, 0.12, 0.10, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.10, 0.10, 0.08, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.08, 0.06, 1.0))
	btn.add_theme_font_size_override("font_size", 16)
	_apply_virtual_key_finish(btn, false)
	_layout_virtual_black_key(btn)


func _style_virtual_black_key_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.09, 1.0)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	normal.border_color = Color(0.0, 0.0, 0.0, 0.95)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.15, 0.15, 0.16, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.22, 0.24, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.98, 0.98, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 11)
	_apply_virtual_key_finish(btn, true)


func _attach_virtual_black_key(btn: Button, natural_name: String, octave: int) -> void:
	if btn == null:
		return
	if natural_name == "E" or natural_name == "B":
		return
	if btn.has_node("BlackKeyButton"):
		_layout_virtual_black_key(btn)
		return
	var sharp_name := "%s#" % natural_name
	var black := Button.new()
	black.name = "BlackKeyButton"
	black.text = sharp_name
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.focus_mode = Control.FOCUS_NONE
	black.clip_text = true
	black.z_index = 40
	black.set_meta("piano_black_key", true)
	black.set_meta("piano_note", sharp_name)
	black.set_meta("piano_octave", octave)
	black.pressed.connect(_on_sight_key_chosen.bind(sharp_name))
	_style_virtual_black_key_button(black)
	btn.add_child(black)
	_continuous_black_key_buttons.append(black)
	_answer_buttons.append(black)
	_layout_virtual_black_key(btn)


func _layout_virtual_black_key(btn: Button) -> void:
	if btn == null:
		return
	var black := btn.get_node_or_null("BlackKeyButton") as Button
	if black == null:
		return
	var w := maxf(16.0, btn.size.x * 0.42)
	var h := maxf(38.0, btn.size.y * 0.60)
	black.size = Vector2(w, h)
	black.position = Vector2(btn.size.x - (w * 0.5), 0.0)


func _get_button_for_interval(interval_id: String) -> Button:
	if _interval_option_map.has(interval_id):
		return _interval_option_map[interval_id]
	return null


func _compute_bird_home_global_position() -> Vector2:
	# Compute from active gameplay panel, then clamp to viewport to avoid
	# off-screen starts on first layout pass.
	var anchor_pos := global_position
	var anchor_size := Vector2(1080, 720)
	if _game_panel != null and _game_panel.visible and _game_panel.size.x > 1.0 and _game_panel.size.y > 1.0:
		anchor_pos = _game_panel.global_position
		anchor_size = _game_panel.size
	elif _game_card != null and _game_card.size.x > 1.0 and _game_card.size.y > 1.0:
		anchor_pos = _game_card.global_position
		anchor_size = _game_card.size
	var x := anchor_pos.x + clampf(anchor_size.x * 0.08, 52.0, 160.0)
	var y := anchor_pos.y + clampf(anchor_size.y * 0.62, 220.0, 460.0)
	var bounds_left := 0.0
	var bounds_top := 0.0
	var bounds_right := get_viewport_rect().size.x
	var bounds_bottom := get_viewport_rect().size.y
	if _game_card != null and _game_card.size.x > 1.0 and _game_card.size.y > 1.0:
		bounds_left = _game_card.global_position.x
		bounds_top = _game_card.global_position.y
		bounds_right = bounds_left + _game_card.size.x
		bounds_bottom = bounds_top + _game_card.size.y
	var min_x := bounds_left + 12.0
	var max_x := maxf(min_x, bounds_right - 220.0)
	var min_y := bounds_top + 90.0
	var max_y := maxf(min_y, bounds_bottom - 180.0)
	return Vector2(clampf(x, min_x, max_x), clampf(y, min_y, max_y))


func _refresh_bird_perch_from_layout(reset_now: bool) -> void:
	if _bird_sprite == null or _selected_mode == MODE_READ:
		return
	_bird_home_global_position = _compute_bird_home_global_position()
	_bird_home_ready = true
	if reset_now:
		_stop_bird_flap_anim()
		_bird_sprite.visible = true
		_bird_sprite.global_position = _bird_home_global_position
		_start_bird_idle_anim()


func _ensure_bird_visible_in_gameplay() -> void:
	if _bird_sprite == null or _selected_mode == MODE_READ:
		return
	if _game_panel == null or not _game_panel.visible:
		return
	var left := 0.0
	var top := 0.0
	var right := get_viewport_rect().size.x
	var bottom := get_viewport_rect().size.y
	if _game_card != null and _game_card.size.x > 1.0 and _game_card.size.y > 1.0:
		left = _game_card.global_position.x
		top = _game_card.global_position.y
		right = left + _game_card.size.x
		bottom = top + _game_card.size.y
	var p := _bird_sprite.global_position
	var out_x := p.x < (left - 40.0) or p.x > (right + 40.0)
	var out_y := p.y < (top - 40.0) or p.y > (bottom + 40.0)
	if out_x or out_y:
		_refresh_bird_perch_from_layout(true)
		return
	if not _bird_sprite.visible:
		_bird_sprite.visible = true
	_bird_sprite.move_to_front()


func _reset_bird_position() -> void:
	if _bird_sprite == null:
		return
	if not _bird_home_ready:
		_bird_home_global_position = _compute_bird_home_global_position()
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
	# Hard snap to perch to prevent tiny drift after repeated flights.
	_bird_sprite.global_position = _bird_home_global_position
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
	_piano_interval_anchor_samples.clear()
	_load_sampled_piano_from_folder()
	if not _piano_samples.is_empty():
		# Also load trusted fixed anchors for interval mode playback.
		for midi_key in PIANO_SAMPLE_PATHS.keys():
			var sample_path_a: String = PIANO_SAMPLE_PATHS[midi_key]
			if not ResourceLoader.exists(sample_path_a, "AudioStream"):
				continue
			var stream_a := ResourceLoader.load(sample_path_a)
			if stream_a is AudioStream:
				_piano_interval_anchor_samples[midi_key] = stream_a
		return
	# Fallback to legacy sparse sample map.
	for midi_key in PIANO_SAMPLE_PATHS.keys():
		var sample_path: String = PIANO_SAMPLE_PATHS[midi_key]
		if not ResourceLoader.exists(sample_path, "AudioStream"):
			continue
		var stream := ResourceLoader.load(sample_path)
		if stream is AudioStream:
			_piano_samples[midi_key] = stream
			_piano_interval_anchor_samples[midi_key] = stream


func _load_sampled_piano_from_folder() -> void:
	var dir := DirAccess.open(PIANO_SAMPLED_DIR)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	var lower_names: Dictionary = {}
	for file_name in files:
		var f := String(file_name).to_lower()
		lower_names[f.get_basename()] = true
	for file_name in files:
		var f := String(file_name)
		if not f.to_lower().ends_with(".ogg"):
			continue
		var midi := _sampled_filename_to_midi(f, lower_names)
		if midi < 0:
			continue
		var full_path := "%s/%s" % [PIANO_SAMPLED_DIR, f]
		if not ResourceLoader.exists(full_path, "AudioStream"):
			continue
		var stream := ResourceLoader.load(full_path)
		if stream is AudioStream and not _piano_samples.has(midi):
			_piano_samples[midi] = stream


func _sampled_filename_to_midi(file_name: String, lower_names: Dictionary) -> int:
	var base := file_name.get_basename().to_lower()
	var rx := RegEx.new()
	if rx.compile("^([a-g])(\\d)(?:_(\\d+))?$") != OK:
		return -1
	var m := rx.search(base)
	if m == null:
		return -1
	var letter := m.get_string(1)
	var octave := int(m.get_string(2))
	var variant_text := m.get_string(3)
	var variant := int(variant_text) if variant_text != "" else 1

	var natural_semi := _natural_letter_to_semitone(letter)
	if natural_semi < 0:
		return -1

	var midi := 12 * (octave + 1) + natural_semi
	var is_natural_only := letter == "b" or letter == "e"
	if not is_natural_only:
		# Naming convention:
		# - c4_2.ogg => C4 natural
		# - c4.ogg   => C#4 (one semitone above)
		# For E/B, no sharp mapping is used here.
		var has_natural_variant := lower_names.has("%s%d_2" % [letter, octave])
		if has_natural_variant:
			var is_natural_file := variant == 2
			if not is_natural_file:
				midi += 1

	if midi < 0 or midi > 127:
		return -1
	return midi


func _natural_letter_to_semitone(letter: String) -> int:
	match letter:
		"c":
			return 0
		"d":
			return 2
		"e":
			return 4
		"f":
			return 5
		"g":
			return 7
		"a":
			return 9
		"b":
			return 11
		_:
			return -1


func _play_note(midi_note: int, duration: float) -> void:
	var sample_map: Dictionary = _sample_map_for_current_mode()

	if sample_map.is_empty():
		await _push_sine(_midi_to_freq(midi_note), duration)
		return

	var nearest: int = _nearest_sample_midi_from_map(midi_note, sample_map)
	var stream: AudioStream = sample_map[nearest]
	_piano_player.stop()
	_piano_player.stream = stream
	_piano_player.pitch_scale = pow(2.0, float(midi_note - nearest) / 12.0)
	_piano_player.play()
	await get_tree().create_timer(duration).timeout
	_piano_player.stop()


func _sample_map_for_current_mode() -> Dictionary:
	var is_ear_mode := _selected_mode == MODE_INTERVAL or _selected_mode == MODE_CHORD
	if is_ear_mode and not _piano_interval_anchor_samples.is_empty():
		return _piano_interval_anchor_samples
	return _piano_samples


func _nearest_sample_midi_from_map(target_midi: int, sample_map: Dictionary) -> int:
	var keys: Array = sample_map.keys()
	var best: int = int(keys[0])
	var best_dist: int = int(abs(target_midi - best))
	for k in keys:
		var midi: int = int(k)
		var d: int = int(abs(target_midi - midi))
		if d < best_dist:
			best = midi
			best_dist = d
	return best


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
	if _correct_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _correct_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.33).timeout
		return
	await _push_sine(1046.5, 0.08)
	await _push_silence(0.03)
	await _push_sine(1318.5, 0.11)


func _play_new_question_cue() -> void:
	if _new_question_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _new_question_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.28).timeout
		return
	await _push_sine(880.0, 0.05)
	await _push_silence(0.015)
	await _push_sine(988.0, 0.06)


func _play_fail_sfx() -> void:
	if _wrong_choice_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _wrong_choice_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.34).timeout
		return
	await _push_sine(392.0, 0.09)
	await _push_silence(0.03)
	await _push_sine(293.7, 0.12)


func _play_gameover_fail_sfx() -> void:
	if _fail_gameover_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _fail_gameover_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.46).timeout
		return
	await _push_sine(220.0, 0.2)


func _play_win_fanfare_sfx() -> void:
	if _win_fanfare_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _win_fanfare_sfx
		_sfx_player.play()
		await get_tree().create_timer(0.8).timeout


func _play_module_complete_sfx() -> void:
	if _module_complete_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _module_complete_sfx
		_sfx_player.play()


func _play_powerup_sfx() -> void:
	if _powerup_sfx != null and _sfx_player != null:
		_sfx_player.stop()
		_sfx_player.stream = _powerup_sfx
		_sfx_player.play()


func _play_shield_activate_sfx() -> void:
	if _shield_activate_sfx != null and _shield_sfx_player != null:
		_shield_sfx_player.stop()
		_shield_sfx_player.stream = _shield_activate_sfx
		_shield_sfx_player.play()
		return
	_play_success_sfx()


func _play_transition_whoosh_sfx() -> void:
	if _transition_whoosh_sfx != null and _ui_sfx_player != null:
		_ui_sfx_player.stop()
		_ui_sfx_player.stream = _transition_whoosh_sfx
		_ui_sfx_player.play()


func _play_ui_click_sfx() -> void:
	if _ui_click_sfx != null and _ui_sfx_player != null:
		_ui_sfx_player.stop()
		_ui_sfx_player.stream = _ui_click_sfx
		_ui_sfx_player.play()


func _play_sight_answer_click_sfx() -> void:
	if _ui_sight_answer_click_sfx != null and _ui_sfx_player != null:
		_ui_sfx_player.stop()
		_ui_sfx_player.stream = _ui_sight_answer_click_sfx
		_ui_sfx_player.play()


func _start_note_chase_music() -> void:
	if _music_player == null or _note_chase_bgm == null:
		return
	_music_player.stream = _note_chase_bgm
	_music_player.pitch_scale = 1.0
	_music_player.play()


func _stop_note_chase_music() -> void:
	if _music_player != null and _music_player.playing:
		_music_player.stop()


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
