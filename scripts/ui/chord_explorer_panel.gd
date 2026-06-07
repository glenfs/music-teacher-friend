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
signal build_quiz_requested                         # user clicked the Build quiz launcher in the toolbar



# --- Constants ---
const ARPEGGIO_WINDOW_SEC := 1.5
const CLICK_WINDOW_SEC := 12.0
const KEYBOARD_LOW := 36   # C2
const KEYBOARD_HIGH := 84  # C6
const GENERATED_CHORD_LOW := 48   # C3
const GENERATED_CHORD_HIGH := 83  # B5
const WHITE_W := 36.0
const WHITE_H := 174.0
const BLACK_W := 24.0
const BLACK_H := 112.0

const CHORD_FN_ROOT      := Color(1.00, 0.78, 0.22, 1.0)  # gold
const CHORD_FN_THIRD     := Color(0.36, 0.78, 1.00, 1.0)  # cyan
const CHORD_FN_FIFTH     := Color(0.40, 0.92, 0.55, 1.0)  # green
const CHORD_FN_SEVENTH   := Color(0.95, 0.50, 0.85, 1.0)  # magenta
const CHORD_FN_EXTENSION := Color(0.78, 0.74, 1.00, 1.0)  # lavender
const CHORD_FN_OTHER     := Color(0.86, 0.86, 0.94, 1.0)  # silver

const MENU_TITLE_TEXT := Color(0.9176, 0.9529, 1.0, 1.0)
const MENU_PRIMARY_ACCENT := Color(0.9098, 0.6275, 0.1255, 1.0)
const PRACTICE_ICON_PATH := "res://assets/icons/bullseye-arrow-v2.svg"

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT  := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

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
const MicListenerScript = preload("res://scripts/audio/mic_listener.gd")
const ChordFormationStepsScript = preload("res://scripts/music_theory/chord_formation_steps.gd")
const ChordToneSpellingScript = preload("res://scripts/music_theory/chord_tone_spelling.gd")
const MidiFileWriterScript = preload("res://scripts/exercises/midi_file_writer.gd")


# --- Injected dependencies (set via setup()) ---
var _ui_font: Font = null
var _ui_title_font: Font = null
var _play_note_callable: Callable = Callable()           # (pitch:int, dur:float) -> void
var _sample_map_callable: Callable = Callable()          # () -> Dictionary
var _nearest_sample_callable: Callable = Callable()      # (pitch:int, map:Dictionary) -> int
var _score_font_picker_builder: Callable = Callable()    # (parent:Control) -> void (optional)
# Plays multiple notes simultaneously through the chord-player pool with a
# small loudness boost. Used for preset playback so all voices actually
# sound together (vs. _play_note_callable which uses a single shared
# player and clobbers itself when called in rapid succession).
var _play_chord_callable: Callable = Callable()          # (notes:Array[int], dur:float) -> void
var _nav_home_style_callable: Callable = Callable()      # (btn:Button) -> void — applies sight-reader nav-home skin


# --- Internal state ---
var _key_pc: int = 0
var _key_is_minor: bool = false
# Tracks whether the user picked a flat-spelled key (Bb, Eb, Ab, Db, Gb, F).
# Drives enharmonic spelling in _spell_pc_in_key — without this every chord
# in flat keys shows up as sharps (Bb → "A#m" etc.).
var _key_uses_flats: bool = false
var _recent_notes: Dictionary = {}        # pitch (int) -> last note-on time (float)
var _window_expires_at: float = -1.0
var _last_info: Dictionary = {}
var _arpeggiate: bool = false             # Play rolls the chord note-by-note
var _spell_override: int = -1             # -1 = auto (key), 0 = force sharps, 1 = force flats
var _loop_active: bool = false            # repeatedly play the chord/progression
var _loop_token: int = 0
var _favorites: Array = []                # [[root_pc:int, quality:String], …]
var _target_pcs: Array[int] = []          # "build this chord" target pitch classes
var _target_name: String = ""
var _vl_prev_staff_pos: Dictionary = {}   # prev chord notehead positions, for staff voice-leading

const FAVORITES_PATH := "user://chord_explorer_favorites.json"
const DICTIONARY_QUALITIES := [
	"Major", "Minor", "Dim", "Aug", "Sus2", "Sus4", "Maj7", "Dom7",
	"Min7", "Half-dim", "Dim7", "mMaj7", "Maj6", "Min6", "Add9",
]


# --- Widget references ---
var _chord_name_label: Label = null
var _full_name_label: Label = null
var _theory_insight_label: Label = null
var _intervals_label: Label = null
var _roman_label: Label = null
var _diatonic_label: Label = null
var _inversion_label: Label = null
var _staff_area: Control = null
var _staff_tooltip_overlays: Array = []   # hover targets over staff noteheads
var _staff_tt_token: int = 0
var _key_option: OptionButton = null
var _minor_check: CheckButton = null
var _back_button: Button = null
var _clear_button: Button = null
var _play_button: Button = null
var _dict_menu: MenuButton = null
var _fav_menu: MenuButton = null
var _tools_menu: MenuButton = null
var _target_feedback_label: Label = null

# Tools-menu item ids.
const _TOOL_TRANSPOSE_DOWN := 0
const _TOOL_TRANSPOSE_UP := 1
const _TOOL_ARPEGGIATE := 2
const _TOOL_LOOP := 3
const _TOOL_TARGET := 4
const _TOOL_EXPORT := 5
const _SPELL_AUTO := 10
const _SPELL_SHARP := 11
const _SPELL_FLAT := 12
const _FAV_SAVE := 9000
var _window_bar: ProgressBar = null
var _keyboard_keys: Dictionary = {}       # pitch -> Button
var _inversions_row: HBoxContainer = null
# Pianistic voicings row — same chord quality, different distribution of
# the voices (Root / Drop 2 / Drop 3 / Shell / Open).
var _voicings_row: HBoxContainer = null
# Compare row — lets the user pick a second chord quality at the same root
# as the current chord, then plays the two back-to-back (A → B → A) so the
# difference is audible side-by-side without re-staging notes.
var _compare_row: HBoxContainer = null
var _compare_option: OptionButton = null
var _compare_token: int = 0
# Holds the three chord-detail rows above (Inversions / Voicings / Compare)
# as tabs — only one is visible at a time. Reduces vertical density on
# smaller screens from 3 stacked rows to 1 row + tab bar.
var _chord_detail_tabs: TabContainer = null
# One-screen lesson overlay invoked from the toolbar "?" button.
var _help_overlay: PanelContainer = null
# Playback busy lock: while non-zero, all chord-playback buttons are
# disabled + a "♪ Playing..." indicator shows. Token bumped on every
# new lock so a stale auto-unlock can't re-enable buttons mid-sequence.
var _playback_busy_until: float = 0.0
var _playback_lock_token: int = 0
var _playback_unlock_timer: Timer = null
var _playback_unlock_timer_token: int = 0
var _playback_indicator: Label = null

# Mic listening — optional input source. Builds the chord by accumulating each
# detected note (one at a time) over the click-accumulation window, just like
# tapping keys on the on-screen keyboard. Single-note polyphony only.
var _mic_listener: RefCounted = null   # MicListener (lazy-built)
var _mic_button: Button = null
var _mic_status_label: Label = null

# "Show me how to form this chord" step-through teaching panel.
# When open it overlays the chord-detail tabs and walks the user through
# adding chord tones one at a time (Root → +3rd → +5th → ...). Each step
# updates _recent_notes so the staff/keyboard show progress.
var _formation_button: Button = null
var _formation_panel: PanelContainer = null
var _formation_title_label: Label = null
var _formation_action_label: Label = null
var _formation_why_label: Label = null
var _formation_context_label: Label = null
var _formation_back_btn: Button = null
var _formation_play_btn: Button = null
var _formation_next_btn: Button = null
var _formation_steps_data: Array = []
var _formation_step_idx: int = -1
var _formation_base_root_midi: int = 60
var _formation_intervals: Array = []
# Chromatic degree labels from chord root (0..12 semitones). Used by the
# walkthrough to overlay "1, 2, 3, ..., 8" on the keys in the chord's octave
# so the student sees the chord's interval geometry on the keyboard itself.
const _FORMATION_DEGREE_LABELS := ["1", "♭2", "2", "♭3", "3", "4", "♯4", "5", "♭6", "6", "♭7", "7", "8"]
# Snapshots of state we restore when the user closes the formation panel,
# so resumed exploration picks up exactly where it was before "Show how".
var _formation_saved_recent_notes: Dictionary = {}
var _formation_saved_window_expires_at: float = -1.0

# Top section (staff + chord display) — built as HBoxContainer for the
# default desktop side-by-side layout. _apply_responsive_layout reads
# viewport width and rotates this into a vertical stack at narrow widths.
var _top_section: Container = null
var _last_applied_layout_breakpoint: int = -1
# Breakpoints (window width):
#   >= 1280  → wide   (40/60 side-by-side, full keyboard)
#   >= 1024  → tablet (still side-by-side but tighter margins)
#   <  1024  → narrow (staff stacks above chord display, keyboard scales)
const _LAYOUT_BREAKPOINT_WIDE: int = 1280
const _LAYOUT_BREAKPOINT_TABLET: int = 1024


# Presets dropdown lives in the top toolbar next to the key selector.
# (The old _presets_row HBox under the chord display was removed — that
# space was crowded; DAW-style toolbar dropdown is cleaner.)
var _presets_option: OptionButton = null
var _preset_steps_row: HBoxContainer = null
var _progression_analysis_label: Label = null
var _voice_leading_label: Label = null
var _add_progression_button: Button = null
# Always-visible diatonic chord cheat sheet — shows the 7 chords in the
# current key with Roman numerals. Refreshes on key / minor toggle.
var _diatonic_row: HBoxContainer = null
# Cached chord list of the currently-loaded preset. Each entry is the raw
# tuple [root_pc, quality_id, roman] from BUILT_IN_PRESETS. Lets the chord-
# step buttons reload a step without re-walking the preset definitions.
var _active_preset_chords: Array = []
var _active_preset_step_idx: int = -1
# Used so a Play-All loop can detect the user clicking another step (or
# leaving the panel) and abort cleanly.
var _play_all_token: int = 0

# Built-in teacher presets — chord+key setups ready to load. Loading a preset
# clears the played notes, picks the key, builds the chord-step row, and
# stages the first chord. Each chord tuple: [root_pc, quality_id, roman]
# where quality_id matches a CHORD_INTERVALS key and `roman` is the function
# label shown under the chord-step button.
const BUILT_IN_PRESETS: Array[Dictionary] = [
	{
		"id": "ii_V_I_C",
		"label": "ii-V-I in C",
		"key_pc": 0, "is_minor": false,
		"chords": [[2, "Min7", "ii"], [7, "Dom7", "V"], [0, "Maj7", "I"]],
	},
	{
		"id": "modal_mix_C",
		"label": "Modal mixture in C",
		"key_pc": 0, "is_minor": false,
		"chords": [[10, "Major", "bVII"], [3, "Major", "bIII"], [8, "Major", "bVI"]],
	},
	{
		"id": "neapolitan_C",
		"label": "Neapolitan (bII) in C",
		"key_pc": 0, "is_minor": false,
		"chords": [[1, "Major", "bII"], [7, "Dom7", "V"], [0, "Major", "I"]],
	},
	{
		"id": "blues_C",
		"label": "12-bar blues in C",
		"key_pc": 0, "is_minor": false,
		"chords": [[0, "Dom7", "I7"], [5, "Dom7", "IV7"], [7, "Dom7", "V7"]],
	},
	{
		"id": "jazz_color_C",
		"label": "Jazz color (Maj7#11)",
		"key_pc": 0, "is_minor": false,
		"chords": [[0, "Maj7#11", "I"], [5, "Maj7#11", "IV"], [10, "Maj7#11", "bVII"]],
	},
]


# --- Public lifecycle ---


# Call once after add_child(), before present(). Builds the UI tree.
func setup(
	ui_font: Font,
	ui_title_font: Font,
	play_note: Callable,
	sample_map_fn: Callable,
	nearest_sample_fn: Callable,
	score_font_picker_builder: Callable,
	play_chord: Callable = Callable(),
	nav_home_style: Callable = Callable()
) -> void:
	_ui_font = ui_font
	_ui_title_font = ui_title_font
	_play_note_callable = play_note
	_sample_map_callable = sample_map_fn
	_nearest_sample_callable = nearest_sample_fn
	_score_font_picker_builder = score_font_picker_builder
	_play_chord_callable = play_chord
	_nav_home_style_callable = nav_home_style
	_force_fullscreen_rect()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 780
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	add_theme_stylebox_override("panel", panel_style)
	_build_ui()


# Wire mic-listening callables. Optional — if not called, the mic button stays
# hidden. Parent passes start/stop/poll callables that drive its shared
# PitchDetector. Detected notes route into handle_note_on(midi, click_source=true).
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


# Show the panel and reset note-tracking state.
func present() -> void:
	_recent_notes.clear()
	_window_expires_at = -1.0
	_target_pcs = []
	_target_name = ""
	_set_target_menu_label(false)
	# Reset the Play button tint — an early return mid-arpeggio (panel dismissed
	# while a slow roll is playing) can leave it dimmed otherwise.
	if _play_button != null:
		_play_button.modulate = Color.WHITE
	_load_favorites()
	_refresh_favorites_menu()
	_force_fullscreen_rect()
	_apply_responsive_layout()
	visible = true
	move_to_front()
	# Stage a default chord (tonic triad in the current key) so the voicings
	# / compare / inversions rows are immediately visible — otherwise the
	# user opens the panel to an empty display and has no idea those rows
	# exist until they happen to click a diatonic chord button.
	_stage_default_demo_chord()
	_refresh_display()
	presented.emit()


# Stages the tonic triad in whatever key is currently selected so the panel
# never shows up empty. C major by default; if the user opened the panel
# already in another key (e.g. via _load_preset's side effects) we use it.
func _stage_default_demo_chord() -> void:
	var quality: String = "Minor" if _key_is_minor else "Major"
	var intervals: Array = _intervals_for_quality(quality)
	if intervals.is_empty():
		return
	var base_root_midi: int = _anchor_root_for_chord(_key_pc, intervals)
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for iv in intervals:
		_recent_notes[base_root_midi + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC


# Hide + clear state. Does not free the panel — parent can present() again.
# --- Playback busy lock ---


# Returns true if there's an in-flight chord/voicing/preset playback that
# should block another click from firing. Caller handlers should bail at
# entry when this returns true.
func _is_playback_busy() -> bool:
	return (float(Time.get_ticks_msec()) / 1000.0) < _playback_busy_until


# Disable all chord-playback buttons for `duration` seconds + show the
# "♪ Playing..." indicator. Token-guarded so a longer lock isn't undone
# by an earlier auto-unlock that fires later.
func _lock_playback(duration: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_playback_busy_until = max(_playback_busy_until, now + duration)
	_playback_lock_token += 1
	var my_token: int = _playback_lock_token
	_set_playback_buttons_disabled(true)
	if _playback_indicator != null:
		_playback_indicator.visible = true
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
	if _playback_indicator != null:
		_playback_indicator.visible = false


# Walks every chord-playback row and toggles `disabled` on each Button
# child. The set rebuilds every refresh so we re-walk live — no static
# button registry to keep in sync.
func _set_playback_buttons_disabled(disabled: bool) -> void:
	var rows: Array = [
		_diatonic_row, _preset_steps_row,
		_inversions_row, _voicings_row, _compare_row,
	]
	for row in rows:
		if row == null:
			continue
		for child in row.get_children():
			if child is Button:
				(child as Button).disabled = disabled


# --- Help overlay (lesson card) ---


# Toggles the in-panel help card. Lazy-built on first open so the cost
# isn't paid by users who never need it. The card has a single dismiss
# button + click-outside-to-close behavior.
func _show_help_overlay() -> void:
	if _help_overlay == null:
		_build_help_overlay()
	if _help_overlay == null:
		return
	_help_overlay.visible = true
	_help_overlay.move_to_front()


func _hide_help_overlay() -> void:
	if _help_overlay != null:
		_help_overlay.visible = false


func _build_help_overlay() -> void:
	# Full-screen scrim + centered card. Lives at the panel root so it
	# overlays the staff + keyboard + everything.
	_help_overlay = PanelContainer.new()
	_help_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.z_as_relative = false
	_help_overlay.z_index = 900
	var scrim_style := StyleBoxFlat.new()
	scrim_style.bg_color = Color(0.02, 0.04, 0.08, 0.82)
	_help_overlay.add_theme_stylebox_override("panel", scrim_style)
	add_child(_help_overlay)

	# Click on the scrim (outside the card) to dismiss.
	var scrim_button := Button.new()
	scrim_button.set_anchors_preset(PRESET_FULL_RECT)
	scrim_button.flat = true
	scrim_button.modulate = Color(1, 1, 1, 0)
	scrim_button.pressed.connect(_hide_help_overlay)
	_help_overlay.add_child(scrim_button)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 520)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.16, 0.26, 1.0)
	card_style.border_color = MENU_PRIMARY_ACCENT
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_left = 14
	card_style.corner_radius_bottom_right = 14
	card_style.shadow_color = Color(0, 0, 0, 0.55)
	card_style.shadow_size = 18
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 28)
	card_margin.add_theme_constant_override("margin_right", 28)
	card_margin.add_theme_constant_override("margin_top", 24)
	card_margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(card_margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card_margin.add_child(col)

	var title := Label.new()
	title.text = "Chord Explorer — Quick Guide"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_title_font != null:
		title.add_theme_font_override("font", _ui_title_font)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	col.add_child(title)

	# Body — RichTextLabel so we can bold the row names + indent the
	# explanations. Auto-wraps so long lines don't overflow the card.
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _ui_font != null:
		body.add_theme_font_override("normal_font", _ui_font)
		body.add_theme_font_override("bold_font", _ui_font)
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_font_size_override("bold_font_size", 14)
	body.add_theme_color_override("default_color", MENU_TITLE_TEXT)
	body.text = "Play notes on the keyboard or your MIDI device — the chord name + grand staff update live.\n\n" + \
		"[b][color=#E8A020]Quick presets[/color][/b]   Pick a key + chord progression from the dropdown (top toolbar). Loads ii-V-I, blues, Neapolitan, etc.\n\n" + \
		"[b][color=#73EB9E]Key chords[/color][/b]   The 7 diatonic chords in the current key, labeled with Roman numerals (I, ii, iii, IV, V, vi, vii°). Click any to play it.\n\n" + \
		"[b][color=#5CD0FF]Inversions[/color][/b]   Same chord, different note in the bass. C, C/E, C/G show how the bass moves while the harmony stays the same.\n\n" + \
		"[b][color=#C7BDFF]Voicings[/color][/b]   Same chord, different spacing of the notes. Try [b]Open[/b] for a wide pianistic sound, or [b]Shell[/b] for the bare jazz-comping skeleton (root + 3rd + 7th).\n\n" + \
		"[b][color=#F381CD]Compare[/color][/b]   Pick a second chord quality at the same root and click [b]A → B → A[/b] to hear them back-to-back. Best way to learn Maj7 vs Dom7, Major vs Minor, etc.\n\n" + \
		"Click [b]Clear[/b] (right side) to start fresh. Press [b]?[/b] any time to reopen this guide."
	col.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Got it"
	close_btn.custom_minimum_size = Vector2(160, 42)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_hide_help_overlay)
	col.add_child(close_btn)
	_help_overlay.visible = false


func dismiss() -> void:
	# Stop any running loop so it doesn't keep playing behind the menu.
	_loop_active = false
	_loop_token += 1
	_set_tool_check(_TOOL_LOOP, false)
	if _mic_listener != null and _mic_listener.is_listening():
		_mic_listener.stop()
	if _mic_button != null:
		_mic_button.set_pressed_no_signal(false)
		_mic_button.text = "%s  Mic" % char(0x1F3A4)
	if _mic_status_label != null:
		_mic_status_label.visible = false
	# Hide the Help overlay so it doesn't persist on top of a fresh chord the
	# next time the panel is opened.
	if _help_overlay != null:
		_help_overlay.visible = false
	if _formation_panel != null and _formation_panel.visible:
		# Skip the state-restore branch — panel is going away entirely.
		_formation_panel.visible = false
		_formation_step_idx = -1
		_formation_steps_data.clear()
		_formation_saved_recent_notes.clear()
		_clear_formation_keyboard_labels()
	_recent_notes.clear()
	_window_expires_at = -1.0
	_playback_busy_until = 0.0
	_playback_lock_token += 1
	_stop_playback_unlock_timer()
	_set_playback_buttons_disabled(false)
	if _playback_indicator != null:
		_playback_indicator.visible = false
	# Tear down preset state so re-presenting starts fresh.
	_active_preset_chords = []
	_active_preset_step_idx = -1
	_play_all_token += 1
	# Invalidate any in-flight A→B→A sequence too.
	_compare_token += 1
	_rebuild_preset_steps_row()
	_hide_help_overlay()
	visible = false


# Override of Control._process — runs every frame while the panel exists.
# We use it (rather than the parent's _chord_explorer_tick, which is gated by
# _midi_active) so the mic listener still polls when MIDI is off.
func _process(_delta: float) -> void:
	if not visible:
		return
	if _mic_listener != null and _mic_listener.is_listening():
		_mic_listener.tick()


func _on_mic_button_toggled(pressed: bool) -> void:
	if _mic_listener == null:
		return
	if pressed:
		var ok: bool = _mic_listener.start()
		if not ok:
			_mic_button.set_pressed_no_signal(false)
		else:
			_mic_status_label.visible = true
			_mic_button.text = "%s  Mic on" % char(0x1F3A4)
	else:
		_mic_listener.stop()
		_mic_status_label.visible = false
		_mic_button.text = "%s  Mic" % char(0x1F3A4)


func _on_mic_note_detected(midi: int, _note_name: String, _full_name: String, _cents_off: float) -> void:
	# Route detected pitches through the same accumulator the on-screen
	# keyboard uses. click_source=true gives a 12s window so notes sung over
	# the course of phrasing a chord still group together.
	handle_note_on(midi, true)


func _on_mic_status_changed(text: String, listening: bool) -> void:
	if _mic_status_label == null:
		return
	_mic_status_label.text = text
	_mic_status_label.visible = listening or not text.is_empty()


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


func _apply_responsive_layout() -> void:
	# Reads current viewport width, picks a layout breakpoint (wide /
	# tablet / narrow), and reconfigures the top section + chord-body
	# margins accordingly. Idempotent — guarded by
	# _last_applied_layout_breakpoint so resize spam doesn't thrash.
	var vp := get_viewport()
	if vp == null:
		return
	var w: float = vp.get_visible_rect().size.x
	# Defensive guard: during initial scene build the viewport rect can
	# briefly read as zero. If we run the layout then we'd incorrectly
	# rotate into narrow mode and the chord display would be cut off.
	# Defer until the viewport is genuinely sized.
	if w < 200.0:
		call_deferred("_apply_responsive_layout")
		return
	var bp: int
	if w >= _LAYOUT_BREAKPOINT_WIDE:
		bp = 2  # wide
	elif w >= _LAYOUT_BREAKPOINT_TABLET:
		bp = 1  # tablet
	else:
		bp = 0  # narrow
	if bp == _last_applied_layout_breakpoint:
		return
	_last_applied_layout_breakpoint = bp
	# Rotation: HBox for wide+tablet (side-by-side), VBox for narrow (stack).
	if _top_section != null and is_instance_valid(_top_section):
		var want_vertical: bool = (bp == 0)
		var is_vertical: bool = _top_section is VBoxContainer
		if want_vertical != is_vertical:
			_rotate_top_section(want_vertical)
	# Tighten section separation on smaller screens.
	if _top_section != null:
		_top_section.add_theme_constant_override("separation", 10 if bp == 2 else (8 if bp == 1 else 6))


# Swap top_section between HBoxContainer (side-by-side) and VBoxContainer
# (stacked) by replacing the node and re-parenting its children. Godot
# doesn't expose a runtime "change orientation" so we rebuild the
# container in-place.
func _rotate_top_section(vertical: bool) -> void:
	if _top_section == null or not is_instance_valid(_top_section):
		return
	var parent := _top_section.get_parent()
	if parent == null:
		return
	var children: Array[Node] = []
	for c in _top_section.get_children():
		children.append(c)
	for c in children:
		_top_section.remove_child(c)
	var idx := _top_section.get_index()
	parent.remove_child(_top_section)
	_top_section.queue_free()
	var new_box: Container
	if vertical:
		new_box = VBoxContainer.new()
	else:
		new_box = HBoxContainer.new()
	new_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	new_box.add_theme_constant_override("separation", 8 if vertical else 14)
	parent.add_child(new_box)
	parent.move_child(new_box, idx)
	for c in children:
		new_box.add_child(c)
		if c is Control:
			# In both modes the children should expand to fill their slot.
			# The original stretch_ratio (4 / 6) is preserved on the Control
			# itself so going back to HBox restores the 40/60 split.
			(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_section = new_box


func _force_fullscreen_rect() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


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


# UI 20 — Cross-module visual consistency. Mirrors the input-control
# style used in Practice Drills (dark blue bg + golden border + small
# content margins) so OptionButtons in Chord Explorer look like they
# belong to the same product. Full design-system extraction is future
# work; this is the first applied step.
func _apply_clefira_input_style(ctrl: Control) -> void:
	if _ui_font != null:
		ctrl.add_theme_font_override("font", _ui_font)
	ctrl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.98))
	ctrl.add_theme_color_override("font_hover_color", Color(0.96, 0.98, 1.0, 0.98))
	ctrl.add_theme_color_override("font_pressed_color", Color(0.96, 0.98, 1.0, 0.98))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.11, 0.20, 0.94)
	normal.border_color = Color(0.95, 0.75, 0.30, 0.92)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate()
	(hover as StyleBoxFlat).bg_color = Color(0.08, 0.16, 0.28, 0.98)
	(hover as StyleBoxFlat).border_color = Color(1.0, 0.83, 0.42, 0.98)
	var pressed := normal.duplicate()
	(pressed as StyleBoxFlat).bg_color = Color(0.03, 0.08, 0.16, 0.98)
	ctrl.add_theme_stylebox_override("normal", normal)
	ctrl.add_theme_stylebox_override("hover", hover)
	ctrl.add_theme_stylebox_override("pressed", pressed)


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 22)
	root_margin.add_theme_constant_override("margin_right", 22)
	root_margin.add_theme_constant_override("margin_top", 18)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)
	root_margin.add_child(root_vbox)

	# Top bar: Back | Title | Key selector
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(top_bar)

	# Home button — uses the exact sight-reader nav-home skin (SVG house icon
	# in a circular pill) so all top-level modules look consistent.
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

	# Clefira brand mark — unified across every panel screen so the product
	# identity reads the same wherever the user lands.
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

	var title_label := Label.new()
	title_label.text = "Chord Explorer"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _ui_title_font != null:
		title_label.add_theme_font_override("font", _ui_title_font)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98, 0.94))
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
	_apply_clefira_input_style(_key_option)
	key_row.add_child(_key_option)

	# Three-mode key flavor picker: Major / Natural Minor / Harmonic Minor.
	# Replaces the old Minor checkbox so classical-theory cadence teaching
	# (V Major + vii° in minor) is selectable. Drives _key_flavor +
	# _key_is_minor (= true when either Natural or Harmonic minor).
	_minor_check = CheckButton.new()  # kept as a hidden ghost var so any
	_minor_check.visible = false       # external references don't NPE
	add_child(_minor_check)
	var flavor_option := OptionButton.new()
	flavor_option.custom_minimum_size = Vector2(140, 38)
	flavor_option.add_item("Major")
	flavor_option.add_item("Minor (natural)")
	flavor_option.add_item("Minor (harmonic)")
	flavor_option.selected = 0
	flavor_option.tooltip_text = "Major: I, ii, iii, IV, V, vi, vii°.\nNatural minor: i, ii°, III, iv, v, VI, VII.\nHarmonic minor: i, ii°, III+, iv, V, VI, vii° (raised 7th — gives the strong cadence V → i)."
	flavor_option.item_selected.connect(_on_key_flavor_selected)
	_apply_clefira_input_style(flavor_option)
	key_row.add_child(flavor_option)

	# Presets dropdown — index 0 is a disabled placeholder so opening the
	# panel doesn't auto-trigger a preset. Selecting any other item loads
	# the corresponding BUILT_IN_PRESETS entry, which populates the
	# chord-step row + auditions the first chord.
	var presets_spacer := Control.new()
	presets_spacer.custom_minimum_size = Vector2(16, 0)
	key_row.add_child(presets_spacer)
	_presets_option = OptionButton.new()
	_presets_option.custom_minimum_size = Vector2(220, 38)
	_presets_option.add_item("Quick presets...")
	_presets_option.set_item_disabled(0, true)
	for preset in BUILT_IN_PRESETS:
		_presets_option.add_item(str(preset.get("label", "Preset")))
	_presets_option.selected = 0
	_presets_option.item_selected.connect(_on_presets_option_selected)
	_presets_option.tooltip_text = "Pre-built lesson setups. Each preset loads a key + a short chord progression you can step through."
	_apply_clefira_input_style(_presets_option)
	# Golden label so Quick Presets reads as part of the same themed dropdown
	# family as the Dictionary / Favorites / Tools menus below the keyboard.
	var presets_gold := Color(1.0, 0.83, 0.42, 1.0)
	_presets_option.add_theme_color_override("font_color", presets_gold)
	_presets_option.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.55, 1.0))
	_presets_option.add_theme_color_override("font_pressed_color", presets_gold)
	_presets_option.add_theme_color_override("font_focus_color", presets_gold)
	if _presets_option.get_popup() != null:
		_style_popup(_presets_option.get_popup())
	key_row.add_child(_presets_option)

	# Help button — opens a one-screen lesson card explaining presets,
	# diatonic chords, inversions, voicings, and the compare row. Sits
	# immediately right of the Quick Presets dropdown.
	var help_spacer := Control.new()
	help_spacer.custom_minimum_size = Vector2(6, 0)
	key_row.add_child(help_spacer)
	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(38, 38)
	help_btn.tooltip_text = "Open the Chord Explorer guide"
	help_btn.add_theme_font_size_override("font_size", 18)
	help_btn.pressed.connect(_show_help_overlay)
	key_row.add_child(help_btn)

	# (Inline Quiz button removed — Guided Practice is now the single
	# entry point for all quiz/training activities. The "Practice" button
	# below replaces it.)

	# Guided Practice — launches the dedicated full-screen guided-mode
	# panel (5 modes: Build / Identify / Compare / Function / Progression
	# with difficulty levels and escalating hints). Emits build_quiz_requested
	# signal so the parent can dismiss this panel + present Guided Practice.
	var build_btn := Button.new()
	build_btn.text = "Practice"
	var practice_icon: Texture2D = load(PRACTICE_ICON_PATH)
	if practice_icon != null:
		build_btn.icon = practice_icon
		build_btn.add_theme_constant_override("icon_max_width", 22)
	build_btn.custom_minimum_size = Vector2(108, 38)
	build_btn.tooltip_text = "Open Guided Practice: build chords, identify by ear, compare sounds, chord function in key, or build progressions."
	build_btn.add_theme_font_size_override("font_size", 14)
	build_btn.pressed.connect(func(): build_quiz_requested.emit())
	key_row.add_child(build_btn)

	# Mic toggle — hidden until parent calls setup_mic(). While on, the host's
	# PitchDetector feeds detected notes back through handle_note_on, building
	# the chord one sung/played note at a time. Single-note (monophonic) only.
	_mic_button = Button.new()
	_mic_button.toggle_mode = true
	_mic_button.text = "%s  Mic" % char(0x1F3A4)
	_mic_button.custom_minimum_size = Vector2(96, 38)
	_mic_button.tooltip_text = "Listen to your microphone — sing or play notes to build a chord."
	_mic_button.add_theme_font_size_override("font_size", 14)
	_mic_button.toggled.connect(_on_mic_button_toggled)
	_mic_button.visible = false
	key_row.add_child(_mic_button)

	# Music-notation font picker removed from Chord Explorer header — it now
	# lives only in the home Settings page so the toolbar stays focused on
	# chord-exploration controls. Default font is Leland (set globally).

	var chord_body_scroll := ScrollContainer.new()
	chord_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chord_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chord_body_scroll.follow_focus = false
	root_vbox.add_child(chord_body_scroll)

	var chord_body := VBoxContainer.new()
	chord_body.add_theme_constant_override("separation", 9)
	chord_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chord_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chord_body_scroll.add_child(chord_body)

	# Side-by-side top section: staff (40%) on the left, chord display (60%)
	# on the right. Frees vertical space so the virtual keyboard stays
	# visible without scrolling — a single chord never needed the staff's
	# full width anyway.
	# top_section starts as side-by-side HBox; _apply_responsive_layout
	# may swap it to vertical stacking on narrow viewports.
	_top_section = HBoxContainer.new()
	_top_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_top_section.add_theme_constant_override("separation", 14)
	chord_body.add_child(_top_section)
	var top_section := _top_section

	# Staff area (left, 40% of width via stretch_ratio = 4 against right=6)
	var staff_wrap := PanelContainer.new()
	staff_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_wrap.size_flags_stretch_ratio = 4.0
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
	top_section.add_child(staff_wrap)

	_staff_area = StaffRendererScript.new()
	_staff_area.custom_minimum_size = Vector2(380, 240)
	_staff_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staff_area.set("draw_paper", true)
	_staff_area.set("cluster_mode", true)
	_staff_area.set("inter_staff_gap_spaces", 5.0)
	staff_wrap.add_child(_staff_area)

	# Chord display (right, 60% via stretch_ratio = 6)
	var name_wrap := HBoxContainer.new()
	name_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	name_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_wrap.size_flags_stretch_ratio = 6.0
	name_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_section.add_child(name_wrap)
	var name_panel := PanelContainer.new()
	name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_panel.custom_minimum_size = Vector2(500, 0)
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

	# Mic status — hidden until the mic toggle is on. Shows live feedback
	# ("Heard: G4 (+8 cents)" / "Mic: too quiet" etc.).
	_mic_status_label = Label.new()
	_mic_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mic_status_label.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0, 0.94))
	_mic_status_label.add_theme_font_size_override("font_size", 13)
	if _ui_font != null:
		_mic_status_label.add_theme_font_override("font", _ui_font)
	_mic_status_label.visible = false
	name_inner.add_child(_mic_status_label)

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

	var name_head := VBoxContainer.new()
	name_head.alignment = BoxContainer.ALIGNMENT_CENTER
	name_head.add_theme_constant_override("separation", 6)
	name_inner.add_child(name_head)

	_chord_name_label = Label.new()
	_chord_name_label.text = "Play a chord..."
	_chord_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chord_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chord_name_label.clip_text = true
	if _ui_title_font != null:
		_chord_name_label.add_theme_font_override("font", _ui_title_font)
	_chord_name_label.add_theme_font_size_override("font_size", 36)
	_chord_name_label.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	name_head.add_child(_chord_name_label)

	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 12)
	info_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	_full_name_label.add_theme_font_size_override("font_size", 16)
	_full_name_label.add_theme_color_override("font_color", MENU_TITLE_TEXT)
	name_inner.add_child(_full_name_label)

	# Theory insight: where the chord wants to go (function/resolution) and which
	# scales improvise over it (chord–scale relationships).
	_theory_insight_label = Label.new()
	_theory_insight_label.text = ""
	_theory_insight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_theory_insight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font != null:
		_theory_insight_label.add_theme_font_override("font", _ui_font)
	_theory_insight_label.add_theme_font_size_override("font_size", 14)
	_theory_insight_label.add_theme_color_override("font_color", Color(0.74, 0.88, 0.98, 0.92))
	name_inner.add_child(_theory_insight_label)

	# Playback "♪ Playing..." indicator — appears while any chord playback
	# is in flight. Visual confirmation that the previous click was
	# received + a brake on click-spamming.
	_playback_indicator = Label.new()
	_playback_indicator.text = "%s  Playing..." % char(0x266A)
	_playback_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_playback_indicator.add_theme_font_size_override("font_size", 13)
	_playback_indicator.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	if _ui_font != null:
		_playback_indicator.add_theme_font_override("font", _ui_font)
	_playback_indicator.visible = false
	name_inner.add_child(_playback_indicator)

	# "Show how to form this chord" — opens the step-through teaching panel.
	_formation_button = Button.new()
	_formation_button.text = "%s  Show how to form this chord" % char(0x21BB)
	_formation_button.tooltip_text = "Walk through this chord one note at a time — root, then 3rd, then 5th, etc. — with the scale degree and why each note matters."
	_formation_button.custom_minimum_size = Vector2(280, 30)
	_formation_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_formation_button.add_theme_font_size_override("font_size", 13)
	if _ui_font != null:
		_formation_button.add_theme_font_override("font", _ui_font)
	_formation_button.pressed.connect(_on_formation_pressed)
	name_inner.add_child(_formation_button)

	_build_formation_panel(name_inner)

	# Three chord-detail surfaces collapsed into a TabContainer to cut the
	# vertical density that built up as features piled on:
	#   - Inversions: chord with each chord tone as bass (C, C/E, C/G ...)
	#   - Voicings:   Root / Drop 2 / Drop 3 / Shell / Open
	#   - Compare:    pick a second quality at the same root + play A↔B
	# Only one tab's row is visible at a time → ~3x vertical savings.
	_chord_detail_tabs = TabContainer.new()
	_chord_detail_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chord_detail_tabs.custom_minimum_size = Vector2(0, 70)
	_chord_detail_tabs.visible = false
	name_inner.add_child(_chord_detail_tabs)

	_inversions_row = HBoxContainer.new()
	_inversions_row.name = "Inversions"
	_inversions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inversions_row.add_theme_constant_override("separation", 8)
	_chord_detail_tabs.add_child(_inversions_row)

	_voicings_row = HBoxContainer.new()
	_voicings_row.name = "Voicings"
	_voicings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_voicings_row.add_theme_constant_override("separation", 6)
	_chord_detail_tabs.add_child(_voicings_row)

	_compare_row = HBoxContainer.new()
	_compare_row.name = "Compare"
	_compare_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_compare_row.add_theme_constant_override("separation", 6)
	_chord_detail_tabs.add_child(_compare_row)
	_build_compare_row()
	# Per-tab tooltips so hover on the tab title explains what's inside.
	_chord_detail_tabs.set_tab_tooltip(0, "Same chord, different note in the bass (root position, 1st, 2nd...).")
	_chord_detail_tabs.set_tab_tooltip(1, "Same chord, different spacing of the notes — closed, drop-2, shell, open.")
	_chord_detail_tabs.set_tab_tooltip(2, "Pick a second chord quality at this root and hear the two back-to-back.")

	# Diatonic cheat sheet — always-visible row of the 7 chords in the
	# current key (I, ii, iii, IV, V, vi, vii° for major; i, ii°, III, iv,
	# v, VI, VII for minor). Lives ABOVE the preset-step row so it never
	# fights for space with a loaded progression. Refreshed via
	# _rebuild_diatonic_row whenever key / minor toggle changes.
	_diatonic_row = HBoxContainer.new()
	_diatonic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_diatonic_row.add_theme_constant_override("separation", 6)
	name_inner.add_child(_diatonic_row)

	# Chord-step row — populated when a preset loads. Each chord in the preset
	# becomes a clickable button (with Roman numeral underneath) so the
	# teacher can walk through the progression at their own pace, plus a
	# "▶ Play all" button to hear the sequence.
	_preset_steps_row = HBoxContainer.new()
	_preset_steps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_preset_steps_row.add_theme_constant_override("separation", 8)
	_preset_steps_row.visible = false
	name_inner.add_child(_preset_steps_row)

	# Roman-numeral analysis of the current progression (built chord-by-chord or
	# loaded from a preset). E.g. "Progression:  ii – V – I".
	_progression_analysis_label = Label.new()
	_progression_analysis_label.text = ""
	_progression_analysis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progression_analysis_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font != null:
		_progression_analysis_label.add_theme_font_override("font", _ui_font)
	_progression_analysis_label.add_theme_font_size_override("font_size", 15)
	_progression_analysis_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.50, 0.96))
	name_inner.add_child(_progression_analysis_label)

	# Voice-leading readout: when stepping a progression, shows how each voice
	# moves between the previous and current chord, with a smooth/leapy flag.
	_voice_leading_label = Label.new()
	_voice_leading_label.text = ""
	_voice_leading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice_leading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font != null:
		_voice_leading_label.add_theme_font_override("font", _ui_font)
	_voice_leading_label.add_theme_font_size_override("font_size", 14)
	_voice_leading_label.add_theme_color_override("font_color", Color(0.72, 0.90, 0.98, 0.92))
	name_inner.add_child(_voice_leading_label)

	_build_keyboard(chord_body)
	# Initial diatonic row population (key starts at C major by default).
	_rebuild_diatonic_row()
	# Hook viewport resize so the layout swaps wide↔narrow live when
	# the user rotates a tablet or resizes the desktop window.
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_responsive_layout):
		vp.size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


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
	var keyboard_section := VBoxContainer.new()
	keyboard_section.alignment = BoxContainer.ALIGNMENT_CENTER
	keyboard_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keyboard_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keyboard_section.add_theme_constant_override("separation", 8)
	keyboard_section.mouse_filter = Control.MOUSE_FILTER_PASS
	parent_vbox.add_child(keyboard_section)

	var num_whites := 0
	for p in range(KEYBOARD_LOW, KEYBOARD_HIGH + 1):
		if not PianoKeyStylesScript.is_black_key(p):
			num_whites += 1
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
	var frame_center := CenterContainer.new()
	frame_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_center.add_child(frame)
	keyboard_section.add_child(frame_center)

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
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
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
			lbl.add_theme_font_size_override("font_size", 12)
			if _ui_font != null:
				lbl.add_theme_font_override("font", _ui_font)
			lbl.add_theme_color_override("font_color", Color(0.32, 0.34, 0.40, 0.92))
			lbl.position = Vector2(4, WHITE_H - 22)
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
		btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		btn.text = ""
		btn.z_index = 1
		var captured_pitch_b := pitch
		btn.pressed.connect(func(): _on_key_pressed(captured_pitch_b))
		PianoKeyStylesScript.apply_black_style(btn, Color.WHITE)
		keys_root.add_child(btn)
		_keyboard_keys[pitch] = btn

	# Compact control bar: the few primary actions, then three tidy dropdown
	# menus that hold everything else (so the panel isn't a wall of buttons).
	var controls_bar := HBoxContainer.new()
	controls_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_bar.add_theme_constant_override("separation", 10)
	controls_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	keyboard_section.add_child(controls_bar)

	_play_button = _build_side_button(controls_bar, "%s Play" % char(0x266A), MENU_PRIMARY_ACCENT, _on_play_pressed)
	_clear_button = _build_side_button(controls_bar, "Clear", Color(0.92, 0.46, 0.42, 1.0), _on_clear_pressed)
	_add_progression_button = _build_side_button(controls_bar, "%s Add" % char(0x2795), Color(0.55, 0.86, 0.62, 1.0), _on_add_to_progression)
	_add_progression_button.tooltip_text = "Append the current chord to a progression. The 'Play all' steps then play the sequence with its Roman-numeral analysis."

	# Dictionary menu: Root ▸ Quality (browse + stage any chord by name).
	_dict_menu = _build_menu_button(controls_bar, "%s Dictionary" % char(0x1F4D6))
	_dict_menu.tooltip_text = "Browse any chord by name and stage it on the staff + keyboard."
	var dpop := _dict_menu.get_popup()
	for ri in range(NOTE_NAMES_SHARP.size()):
		var sub := PopupMenu.new()
		sub.name = "dictroot_%d" % ri
		for qi in range(DICTIONARY_QUALITIES.size()):
			sub.add_item(str(DICTIONARY_QUALITIES[qi]), ri * 100 + qi)
		sub.id_pressed.connect(_on_dictionary_menu)
		_style_popup(sub)
		dpop.add_child(sub)
		dpop.add_submenu_item(str(NOTE_NAMES_SHARP[ri]), sub.name)

	# Favorites menu (Save current + saved chords).
	_fav_menu = _build_menu_button(controls_bar, "%s Favorites" % char(0x2605))
	_fav_menu.tooltip_text = "Save the current chord and recall any you've saved."
	_fav_menu.get_popup().id_pressed.connect(_on_favorites_menu)

	# Tools menu: transpose, spelling, arpeggiate, loop, target trainer, MIDI export.
	_tools_menu = _build_menu_button(controls_bar, "%s Tools" % char(0x2699))
	_tools_menu.tooltip_text = "Transpose, spelling, arpeggiate, loop, the 'build this chord' target trainer, and MIDI export."
	var tpop := _tools_menu.get_popup()
	tpop.add_item("%s  Transpose down" % char(0x266D), _TOOL_TRANSPOSE_DOWN)
	tpop.add_item("%s  Transpose up" % char(0x266F), _TOOL_TRANSPOSE_UP)
	tpop.add_separator()
	var spellsub := PopupMenu.new()
	spellsub.name = "spellsub"
	spellsub.add_radio_check_item("Auto (follows key)", _SPELL_AUTO)
	spellsub.add_radio_check_item("Sharps", _SPELL_SHARP)
	spellsub.add_radio_check_item("Flats", _SPELL_FLAT)
	spellsub.set_item_checked(0, true)
	spellsub.id_pressed.connect(_on_spell_menu)
	_style_popup(spellsub)
	tpop.add_child(spellsub)
	tpop.add_submenu_item("Spelling", "spellsub")
	tpop.add_check_item("Arpeggiate (roll the chord)", _TOOL_ARPEGGIATE)
	tpop.add_check_item("Loop (keep replaying)", _TOOL_LOOP)
	tpop.add_separator()
	tpop.add_item("Set 'build this chord' target", _TOOL_TARGET)
	tpop.add_item("%s  Export MIDI" % char(0x2913), _TOOL_EXPORT)
	tpop.id_pressed.connect(_on_tools_menu)

	# Target / export feedback line under the bar.
	_target_feedback_label = Label.new()
	_target_feedback_label.text = ""
	_target_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_feedback_label.add_theme_font_size_override("font_size", 14)
	_target_feedback_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.78, 0.96))
	keyboard_section.add_child(_target_feedback_label)


func _build_side_button(parent: Control, text: String, accent: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(112, 40)
	btn.focus_mode = Control.FOCUS_NONE
	if _ui_title_font != null:
		btn.add_theme_font_override("font", _ui_title_font)
	btn.add_theme_font_size_override("font_size", 14)
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


# A dropdown menu button in the Clefira theme: deep navy face, golden border
# and golden label, with a matching themed popup.
func _build_menu_button(parent: Control, text: String) -> MenuButton:
	var mb := MenuButton.new()
	mb.text = text
	mb.flat = false
	mb.focus_mode = Control.FOCUS_NONE
	mb.custom_minimum_size = Vector2(128, 40)
	if _ui_title_font != null:
		mb.add_theme_font_override("font", _ui_title_font)
	mb.add_theme_font_size_override("font_size", 15)
	var gold := Color(1.0, 0.83, 0.42, 1.0)
	mb.add_theme_color_override("font_color", gold)
	mb.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.55, 1.0))
	mb.add_theme_color_override("font_pressed_color", gold)
	mb.add_theme_color_override("font_focus_color", gold)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.11, 0.20, 0.96)
	sb.border_color = Color(0.95, 0.75, 0.30, 0.92)
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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	mb.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.16, 0.28, 0.99)
	hover.border_color = Color(1.0, 0.83, 0.42, 0.98)
	mb.add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = Color(0.03, 0.08, 0.16, 0.99)
	mb.add_theme_stylebox_override("pressed", pressed_sb)
	mb.add_theme_stylebox_override("focus", sb)
	mb.add_theme_stylebox_override("disabled", sb)
	_style_popup(mb.get_popup())
	parent.add_child(mb)
	return mb


# Themes a PopupMenu (and is reused for submenus) in deep navy + gold so the
# open dropdown matches its button.
func _style_popup(pop: PopupMenu) -> void:
	if _ui_font != null:
		pop.add_theme_font_override("font", _ui_font)
	pop.add_theme_font_size_override("font_size", 15)
	pop.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0, 0.98))
	pop.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.45, 1.0))
	pop.add_theme_color_override("font_accelerator_color", Color(0.72, 0.82, 0.96, 0.85))
	pop.add_theme_color_override("font_separator_color", Color(0.95, 0.75, 0.30, 0.7))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.11, 0.20, 0.99)
	panel.border_color = Color(0.95, 0.75, 0.30, 0.85)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel.shadow_size = 8
	pop.add_theme_stylebox_override("panel", panel)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.13, 0.22, 0.36, 1.0)
	hover.border_color = Color(0.95, 0.75, 0.30, 0.55)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	pop.add_theme_stylebox_override("hover", hover)


# Tools menu dispatch.
func _on_tools_menu(id: int) -> void:
	match int(id):
		_TOOL_TRANSPOSE_DOWN:
			_on_transpose(-1)
		_TOOL_TRANSPOSE_UP:
			_on_transpose(1)
		_TOOL_ARPEGGIATE:
			_arpeggiate = not _arpeggiate
			_set_tool_check(_TOOL_ARPEGGIATE, _arpeggiate)
		_TOOL_LOOP:
			_loop_active = not _loop_active
			_loop_token += 1
			_set_tool_check(_TOOL_LOOP, _loop_active)
			if _loop_active:
				_run_loop(_loop_token)
		_TOOL_TARGET:
			_on_set_target()
		_TOOL_EXPORT:
			_on_export_midi()


func _set_tool_check(id: int, checked: bool) -> void:
	if _tools_menu == null:
		return
	var pop := _tools_menu.get_popup()
	var idx := pop.get_item_index(id)
	if idx >= 0:
		pop.set_item_checked(idx, checked)


func _set_target_menu_label(active: bool) -> void:
	if _tools_menu == null:
		return
	var pop := _tools_menu.get_popup()
	var idx := pop.get_item_index(_TOOL_TARGET)
	if idx >= 0:
		pop.set_item_text(idx, "Clear target" if active else "Set 'build this chord' target")


# --- Event handlers ---


func _on_back_pressed() -> void:
	dismiss()
	closed.emit()


func _on_clear_pressed() -> void:
	_recent_notes.clear()
	_window_expires_at = -1.0
	# Discard any loaded preset + cancel an in-flight Play-All so the panel
	# returns to a neutral state.
	_active_preset_chords = []
	_active_preset_step_idx = -1
	_play_all_token += 1
	_rebuild_preset_steps_row()
	chord_cleared.emit()
	_refresh_display()


func _on_play_pressed() -> void:
	if _recent_notes.is_empty():
		return
	var pitches: Array[int] = _active_pitches()
	if pitches.is_empty():
		return
	if _play_button != null:
		_play_button.modulate = Color(0.78, 0.78, 0.78, 1.0)
	# Route through the host's chord-player pool — applies ear_prompt_volume_db
	# + voice normalization so the chord is as loud as preset / voicing /
	# compare playback. The old per-note _play_note_soft path peaked at
	# -12 dB and felt much quieter than the other Chord Explorer playback paths.
	if _arpeggiate and _play_note_callable.is_valid():
		# Slow arpeggio: roll the notes low→high with a relaxed gap, each note
		# left ringing into the next, THEN restate the whole chord as a block so
		# the harmony lands as a unit. (Teaches "here are the notes… here's the
		# chord they make".)
		var roll_gap := 0.34
		_lock_playback(float(pitches.size()) * roll_gap + 0.25 + 1.8)
		for p in pitches:
			_play_note_callable.call(int(p), 1.7)
			if not await _wait_sequence_seconds(roll_gap):
				return
		if not await _wait_sequence_seconds(0.2):
			return
		if _play_chord_callable.is_valid():
			_play_chord_callable.call(pitches, 1.6)
		else:
			for p in pitches:
				_play_note_callable.call(int(p), 1.6)
	else:
		_lock_playback(1.6)
		if _play_chord_callable.is_valid():
			_play_chord_callable.call(pitches, 1.4)
		elif _play_note_callable.is_valid():
			for p in pitches:
				_play_note_callable.call(int(p), 0.55)
	if not await _wait_sequence_seconds(0.25):
		return
	if _play_button != null:
		_play_button.modulate = Color.WHITE


func _on_arpeggiate_toggled(pressed: bool) -> void:
	_arpeggiate = pressed


# Exports the current chord — or the built progression — as a Standard MIDI File.
func _on_export_midi() -> void:
	var chords: Array = []
	if _active_preset_chords.size() >= 2:
		for i in range(_active_preset_chords.size()):
			var voiced: Array[int] = _voiced_notes_for_step(i)
			if not voiced.is_empty():
				chords.append(voiced)
	else:
		var pitches: Array[int] = _active_pitches()
		if not pitches.is_empty():
			chords.append(pitches)
	if chords.is_empty():
		if _target_feedback_label != null:
			_target_feedback_label.text = "Play or stage a chord first, then export."
		return
	var bytes: PackedByteArray = MidiFileWriterScript.encode(chords, 90, 1.2)
	var path := "user://clefira_chord_export.mid"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		if _target_feedback_label != null:
			_target_feedback_label.text = "Could not write the MIDI file."
		return
	f.store_buffer(bytes)
	f.close()
	if _target_feedback_label != null:
		_target_feedback_label.text = "%s Saved MIDI → %s" % [char(0x2713), ProjectSettings.globalize_path(path)]


# Appends the currently-recognized chord to the working progression.
func _on_add_to_progression() -> void:
	if _last_info.is_empty() or not bool(_last_info.get("recognized", false)):
		return
	var quality := str(_last_info.get("quality", ""))
	if quality in ["", "single", "interval", "cluster"]:
		return
	var root_pc := int(_last_info.get("root_pc", 0))
	var roman := str(_last_info.get("roman", ""))
	# Store the recognizer's actual intervals-from-root as the source of truth for
	# playback. The recognizer's `quality` codes ("7", "maj7", "m7", "dim", …) don't
	# match _intervals_for_quality's vocabulary ("Dom7", "Maj7", …), so deriving
	# notes from the quality string alone left most added chords silent.
	var ivs: Array = []
	var ivs_v: Variant = _last_info.get("intervals_from_root", [])
	if ivs_v is Array:
		ivs = (ivs_v as Array).duplicate()
	_active_preset_chords.append([root_pc, quality, roman, ivs])
	_active_preset_step_idx = -1
	_rebuild_preset_steps_row()


# Builds the "ii – V – I" analysis line from the active progression. Uses each
# step's Roman numeral when known, else its chord short name.
func _update_progression_analysis() -> void:
	if _progression_analysis_label == null:
		return
	if _active_preset_chords.size() < 2:
		_progression_analysis_label.text = ""
		if _voice_leading_label != null:
			_voice_leading_label.text = ""
		return
	var tokens: Array[String] = []
	for chord_v in _active_preset_chords:
		if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
			continue
		var chord: Array = chord_v
		var roman := str(chord[2]) if chord.size() >= 3 else ""
		if roman.strip_edges() != "":
			tokens.append(roman.strip_edges())
		else:
			tokens.append(_chord_short_label(int(chord[0]), str(chord[1])))
	_progression_analysis_label.text = "Progression:   %s" % "  –  ".join(tokens)


# --- #5 Voice-leading readout ---


# Builds the consistently-voiced MIDI notes for a progression step.
func _voiced_notes_for_step(idx: int) -> Array[int]:
	var out: Array[int] = []
	if idx < 0 or idx >= _active_preset_chords.size():
		return out
	var chord_v: Variant = _active_preset_chords[idx]
	if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
		return out
	var chord: Array = chord_v
	var intervals: Array = _intervals_for_chord_entry(chord)
	if intervals.is_empty():
		return out
	var base: int = _anchor_root_for_chord(int(chord[0]), intervals)
	for iv in intervals:
		out.append(base + int(iv))
	out.sort()
	return out


# Shows how each voice moves from the previous chord to step `idx`, with a
# smooth/leapy flag. Cleared at the start of a progression (idx 0).
func _update_voice_leading(idx: int) -> void:
	if _voice_leading_label == null:
		return
	if idx <= 0:
		_voice_leading_label.text = ""
		return
	var prev: Array[int] = _voiced_notes_for_step(idx - 1)
	var cur: Array[int] = _voiced_notes_for_step(idx)
	if prev.is_empty() or cur.is_empty():
		_voice_leading_label.text = ""
		return
	var n: int = mini(prev.size(), cur.size())
	var moves: Array[String] = []
	var total_motion: int = 0
	for i in range(n):
		var d: int = int(cur[i]) - int(prev[i])
		total_motion += absi(d)
		moves.append("%s%s%s" % [_note_name_midi(int(prev[i])), char(0x2192), _note_name_midi(int(cur[i]))])
	var avg: float = float(total_motion) / float(maxi(1, n))
	var flag := "smooth" if avg <= 2.0 else "wider leaps"
	_voice_leading_label.text = "Voice leading:  %s   (%s)" % ["   ".join(moves), flag]
	_animate_voice_leading(prev, cur)
	# Capture the PREVIOUS chord's staff notehead positions now (the renderer still
	# shows it — _refresh_display runs right after this), then animate on the staff.
	if _staff_area != null and _staff_area.has_method("get_note_screen_positions"):
		_vl_prev_staff_pos = _staff_area.get_note_screen_positions()
		_animate_staff_voice_leading(idx)


# Animates each moving voice as a gold dot gliding from its source key to its
# destination key on the keyboard — a literal picture of the voice leading.
func _animate_voice_leading(prev: Array[int], cur: Array[int]) -> void:
	if not visible or not is_inside_tree():
		return
	var n: int = mini(prev.size(), cur.size())
	for i in range(n):
		var src: int = int(prev[i])
		var dst: int = int(cur[i])
		if src == dst:
			continue
		var src_btn := _keyboard_keys.get(src, null) as Button
		var dst_btn := _keyboard_keys.get(dst, null) as Button
		if src_btn == null or dst_btn == null or not is_instance_valid(src_btn) or not is_instance_valid(dst_btn):
			continue
		_spawn_voice_dot(src_btn, dst_btn, float(i) * 0.07)


# Animates voice leading on the STAFF: a gold dot glides from each voice's
# previous notehead position to its new one. Uses positions the StaffRenderer
# recorded on its last two draws (previous captured before _refresh_display,
# new read after the redraw settles).
func _animate_staff_voice_leading(idx: int) -> void:
	var prev_pos: Dictionary = _vl_prev_staff_pos
	if prev_pos.is_empty() or _staff_area == null or not _staff_area.has_method("get_note_screen_positions"):
		return
	# Let the new score redraw so its notehead positions are available.
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible or not is_instance_valid(_staff_area):
		return
	var new_pos: Dictionary = _staff_area.get_note_screen_positions()
	var prev_notes: Array[int] = _voiced_notes_for_step(idx - 1)
	var cur_notes: Array[int] = _voiced_notes_for_step(idx)
	var n: int = mini(prev_notes.size(), cur_notes.size())
	for i in range(n):
		var pn: int = int(prev_notes[i])
		var cn: int = int(cur_notes[i])
		if pn == cn or not prev_pos.has(pn) or not new_pos.has(cn):
			continue
		_spawn_staff_voice_dot(prev_pos[pn], new_pos[cn], float(i) * 0.07)


func _spawn_staff_voice_dot(src_local: Vector2, dst_local: Vector2, delay: float) -> void:
	if _staff_area == null or not is_instance_valid(_staff_area):
		return
	var dot := ColorRect.new()
	dot.color = Color(0.98, 0.82, 0.40, 1.0)
	dot.size = Vector2(12, 12)
	dot.z_index = 50
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.modulate = Color(1, 1, 1, 0.0)
	_staff_area.add_child(dot)
	dot.position = src_local - Vector2(6, 6)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(dot, "modulate:a", 1.0, 0.12)
	tw.set_parallel(false)
	tw.tween_property(dot, "position", dst_local - Vector2(6, 6), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(dot, "modulate:a", 0.0, 0.28)
	tw.tween_callback(dot.queue_free)


func _spawn_voice_dot(src_btn: Button, dst_btn: Button, delay: float) -> void:
	var dot := ColorRect.new()
	dot.color = Color(0.98, 0.82, 0.40, 1.0)
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size = Vector2(14, 14)
	dot.z_as_relative = false
	dot.z_index = 600
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.modulate = Color(1, 1, 1, 0.0)
	add_child(dot)
	var src_c: Vector2 = src_btn.global_position + src_btn.size * 0.5 - Vector2(7, 7)
	var dst_c: Vector2 = dst_btn.global_position + dst_btn.size * 0.5 - Vector2(7, 7)
	dot.global_position = src_c
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(dot, "modulate:a", 1.0, 0.12)
	tw.set_parallel(false)
	tw.tween_property(dot, "global_position", dst_c, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(dot, "modulate:a", 0.0, 0.28)
	tw.tween_callback(dot.queue_free)


func _note_name_midi(midi: int) -> String:
	var pc: int = ((midi % 12) + 12) % 12
	var octave: int = int(floor(float(midi) / 12.0)) - 1
	return "%s%d" % [_spell_pc_in_key(pc), octave]


# --- #6 Dictionary + favorites ---


# Stage a chord (root pc + quality) on the staff/keyboard without needing to
# play it key-by-key — the dictionary / favorites entry point.
func _stage_chord_by_name(root_pc: int, quality: String) -> void:
	var intervals: Array = _intervals_for_quality(quality)
	if intervals.is_empty():
		return
	var base_root: int = _anchor_root_for_chord(((root_pc % 12) + 12) % 12, intervals)
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for iv in intervals:
		_recent_notes[base_root + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_active_preset_chords = []
	_active_preset_step_idx = -1
	_rebuild_preset_steps_row()
	_refresh_display()


# Dictionary menu: id encodes root_pc * 100 + quality_index.
func _on_dictionary_menu(id: int) -> void:
	var root_pc: int = int(id) / 100
	var qi: int = int(id) % 100
	if qi < 0 or qi >= DICTIONARY_QUALITIES.size():
		return
	_stage_chord_by_name(root_pc, str(DICTIONARY_QUALITIES[qi]))
	_on_play_pressed()


func _on_save_favorite() -> void:
	if _last_info.is_empty() or not bool(_last_info.get("recognized", false)):
		_set_target_feedback("Play a recognizable chord first, then save it.")
		return
	var quality := str(_last_info.get("quality", ""))
	if quality in ["", "single", "interval", "cluster"]:
		_set_target_feedback("That's not a full chord — play a triad or 7th to save.")
		return
	var root_pc := int(_last_info.get("root_pc", 0))
	for fav in _favorites:
		if int(fav[0]) == root_pc and str(fav[1]) == quality:
			_set_target_feedback("Already in Favorites.")
			return
	_favorites.append([root_pc, quality])
	_save_favorites()
	_refresh_favorites_menu()
	_set_target_feedback("%s Saved to Favorites." % char(0x2605))


# Favorites menu: id _FAV_SAVE = save current; 0..n-1 = recall that favorite.
func _on_favorites_menu(id: int) -> void:
	if int(id) == _FAV_SAVE:
		_on_save_favorite()
		return
	if int(id) < 0 or int(id) >= _favorites.size():
		return
	var fav: Array = _favorites[int(id)]
	_stage_chord_by_name(int(fav[0]), str(fav[1]))
	_on_play_pressed()


func _refresh_favorites_menu() -> void:
	if _fav_menu == null:
		return
	var pop := _fav_menu.get_popup()
	pop.clear()
	pop.add_item("%s Save current chord" % char(0x2605), _FAV_SAVE)
	if not _favorites.is_empty():
		pop.add_separator()
		for i in range(_favorites.size()):
			pop.add_item(_chord_short_label(int(_favorites[i][0]), str(_favorites[i][1])), i)


func _save_favorites() -> void:
	var f := FileAccess.open(FAVORITES_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_favorites))
		f.close()


func _load_favorites() -> void:
	if not FileAccess.file_exists(FAVORITES_PATH):
		return
	var f := FileAccess.open(FAVORITES_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Array:
		_favorites = []
		for e in (parsed as Array):
			if e is Array and (e as Array).size() >= 2:
				_favorites.append([int(e[0]), str(e[1])])


# --- #10 Loop ---


func _on_loop_toggled(pressed: bool) -> void:
	_loop_active = pressed
	_loop_token += 1
	if pressed:
		_run_loop(_loop_token)


func _run_loop(token: int) -> void:
	while _loop_active and token == _loop_token and is_inside_tree() and visible:
		if _active_preset_chords.size() >= 2:
			_play_all_preset_steps()
			await get_tree().create_timer(maxf(2.0, float(_active_preset_chords.size()) * 0.95)).timeout
		elif not _recent_notes.is_empty():
			if _play_chord_callable.is_valid():
				_play_chord_callable.call(_active_pitches(), 1.4)
			await get_tree().create_timer(1.8).timeout
		else:
			await get_tree().create_timer(0.4).timeout


# --- #2 Live "build this chord" target feedback ---


func _on_set_target() -> void:
	if not _target_pcs.is_empty():
		# Toggle off — clear the target.
		_target_pcs = []
		_target_name = ""
		_set_target_menu_label(false)
		_update_target_feedback()
		return
	if _last_info.is_empty() or not bool(_last_info.get("recognized", false)):
		_set_target_feedback("Play or stage a chord first, then set it as the target.")
		return
	var pitches: Array[int] = _active_pitches()
	if pitches.is_empty():
		_set_target_feedback("Play or stage a chord first, then set it as the target.")
		return
	_target_pcs = []
	for p in pitches:
		var pc := ((int(p) % 12) + 12) % 12
		if not _target_pcs.has(pc):
			_target_pcs.append(pc)
	_target_name = str(_last_info.get("short_name", ""))
	# Clear the staged chord so the student rebuilds it from scratch.
	_recent_notes.clear()
	_window_expires_at = -1.0
	_set_target_menu_label(true)
	_refresh_display()


# Short status line under the control bar (used by save/target/export guards so
# actions that can't proceed tell the user why instead of silently no-op'ing).
func _set_target_feedback(msg: String) -> void:
	if _target_feedback_label != null:
		_target_feedback_label.text = msg


func _update_target_feedback() -> void:
	if _target_feedback_label == null:
		return
	if _target_pcs.is_empty():
		_target_feedback_label.text = ""
		return
	var played: Dictionary = {}
	for p in _active_pitches():
		played[((int(p) % 12) + 12) % 12] = true
	var got: Array[String] = []
	var missing: Array[String] = []
	for pc in _target_pcs:
		if played.has(pc):
			got.append(_spell_pc_in_key(int(pc)))
		else:
			missing.append(_spell_pc_in_key(int(pc)))
	var extra: Array[String] = []
	for pc in played.keys():
		if not _target_pcs.has(int(pc)):
			extra.append(_spell_pc_in_key(int(pc)))
	if missing.is_empty() and extra.is_empty():
		_target_feedback_label.text = "%s  Built %s!" % [char(0x2713), _target_name]
		return
	var parts: Array[String] = ["Target %s:" % _target_name]
	if not got.is_empty():
		parts.append("%s %s" % [char(0x2713), ", ".join(got)])
	if not missing.is_empty():
		parts.append("missing %s" % ", ".join(missing))
	if not extra.is_empty():
		parts.append("extra %s" % ", ".join(extra))
	_target_feedback_label.text = "   ".join(parts)


# Shifts every staged note by `delta` semitones (staying within the keyboard),
# then re-displays and plays the transposed chord.
func _on_transpose(delta: int) -> void:
	if _recent_notes.is_empty():
		return
	var pitches: Array[int] = _active_pitches()
	if pitches.is_empty():
		return
	if int(pitches[0]) + delta < KEYBOARD_LOW or int(pitches[pitches.size() - 1]) + delta > KEYBOARD_HIGH:
		return
	var shifted: Dictionary = {}
	for k in _recent_notes.keys():
		shifted[int(k) + delta] = _recent_notes[k]
	_recent_notes = shifted
	_window_expires_at = -1.0
	# A manual transpose is a fresh chord — drop any loaded preset state.
	_active_preset_chords = []
	_active_preset_step_idx = -1
	_refresh_display()
	_on_play_pressed()


func _on_spell_menu(id: int) -> void:
	match int(id):
		_SPELL_AUTO:
			_set_spell_override(-1)
		_SPELL_SHARP:
			_set_spell_override(0)
		_SPELL_FLAT:
			_set_spell_override(1)


func _set_spell_override(v: int) -> void:
	_spell_override = v
	if _tools_menu != null:
		var spellsub := _tools_menu.get_popup().get_node_or_null("spellsub") as PopupMenu
		if spellsub != null:
			spellsub.set_item_checked(0, v == -1)
			spellsub.set_item_checked(1, v == 0)
			spellsub.set_item_checked(2, v == 1)
	_refresh_display()


# The flat/sharp preference for chord spelling: manual override wins, else key.
func _effective_uses_flats() -> bool:
	if _spell_override == 0:
		return false
	if _spell_override == 1:
		return true
	return _key_uses_flats


func _on_key_changed(idx: int) -> void:
	if idx < 0 or idx >= KEY_OPTIONS.size():
		return
	_key_pc = int(KEY_OPTIONS[idx][1])
	# The label tells us which enharmonic the user picked — "Bb" means flats,
	# "A#" would mean sharps. KEY_OPTIONS uses "b" suffix for flat spellings.
	_key_uses_flats = String(KEY_OPTIONS[idx][0]).contains("b")
	_rebuild_diatonic_row()
	# Step data was bound to the previous key — close the walkthrough so the
	# user re-launches it under the new key context.
	if _formation_panel != null and _formation_panel.visible:
		_close_formation()
	_refresh_display()


func _on_minor_toggled(pressed: bool) -> void:
	# Kept for backward-compat (the hidden ghost _minor_check still emits).
	_key_is_minor = pressed
	_key_flavor = KeyFlavor.NATURAL_MINOR if pressed else KeyFlavor.MAJOR
	_rebuild_diatonic_row()
	_refresh_display()


func _on_key_flavor_selected(idx: int) -> void:
	_key_flavor = clampi(idx, 0, 2)
	_key_is_minor = _key_flavor != KeyFlavor.MAJOR
	_rebuild_diatonic_row()
	if _formation_panel != null and _formation_panel.visible:
		_close_formation()
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
	player.volume_db = -36.0
	add_child(player)
	player.play()
	var attack_tween := create_tween()
	attack_tween.tween_property(player, "volume_db", -12.0, 0.012)
	var fade_tween := create_tween()
	fade_tween.tween_interval(maxf(0.0, float(stream.get_length()) - 0.035))
	fade_tween.tween_property(player, "volume_db", -60.0, 0.03)
	fade_tween.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	)


# --- Display refresh ---


# Returns a root-MIDI anchor that keeps the chord rooted in the C4-octave
# whenever possible and never lets the top voice exceed KEYBOARD_HIGH (C6).
# Keyboard layout is C2-C6 (36-84) — we cap at 84 and floor at C3 (48) so
# even the widest chords stay visible + clickable on the on-screen piano.
func _anchor_root_for_chord(root_pc: int, intervals: Array) -> int:
	var pc: int = ((int(root_pc) % 12) + 12) % 12
	var base: int = 60 + pc  # default: C4-anchored root (60..71)
	if intervals.is_empty():
		return base
	var min_iv: int = 0
	var max_iv: int = 0
	for iv in intervals:
		min_iv = mini(min_iv, int(iv))
		max_iv = maxi(max_iv, int(iv))
	# Keep generated chords in octaves 3-5; the wider keyboard remains for manual play.
	while base + max_iv > GENERATED_CHORD_HIGH and base > GENERATED_CHORD_LOW:
		base -= 12
	while base + min_iv < GENERATED_CHORD_LOW and base + 12 + max_iv <= GENERATED_CHORD_HIGH:
		base += 12
	if base + min_iv < GENERATED_CHORD_LOW:
		base = GENERATED_CHORD_LOW - min_iv
	if base + max_iv > GENERATED_CHORD_HIGH:
		base = GENERATED_CHORD_HIGH - max_iv
	return base


# --- Inversions row ---


func _refresh_inversions_row() -> void:
	if _inversions_row == null:
		return
	# Clear previous buttons.
	for child in _inversions_row.get_children():
		child.queue_free()
	# Only build content for proper chords (2+ tones).
	if _last_info.is_empty():
		return
	var quality := str(_last_info.get("quality", ""))
	if quality == "" or quality == "single" or quality == "interval" or quality == "cluster":
		return
	var intervals_v: Variant = _last_info.get("intervals_from_root", null)
	if typeof(intervals_v) != TYPE_ARRAY:
		return
	var intervals: Array = intervals_v
	if intervals.size() < 2:
		return
	var root_pc: int = int(_last_info.get("root_pc", 0))
	var root_letter: String = str(_last_info.get("root_letter", ""))
	var current_bass_pc: int = int(_last_info.get("bass_pc", root_pc))
	# Anchor inversions in the same C4-octave-with-C6-ceiling window as the
	# preset playback uses, so the student isn't surprised by a higher /
	# lower register when they click a different inversion of the same chord.
	var base_root_midi: int = _anchor_root_for_chord(root_pc, intervals)
	# Determine the root letter + accidental so the spelling helper knows
	# whether to call e.g. the 7th letter "B" (root C) vs "B#" (root B). The
	# panel stores the root letter as a plain ASCII string ("C", "C#", "Bb");
	# split it into letter + accidental for the chord-tone spelling helper.
	var root_letter_only: String = root_letter.substr(0, 1) if root_letter.length() > 0 else "C"
	var root_acc_int: int = 0
	if root_letter.length() > 1:
		var suffix := root_letter.substr(1)
		if suffix == "#":
			root_acc_int = 1
		elif suffix == "b":
			root_acc_int = -1
	# Quality drives slot assignment (which letter is the 3rd, 5th, 7th, etc.).
	var quality_for_spelling: String = str(_last_info.get("quality", ""))
	# Build a button per chord-tone-as-bass.
	for i in intervals.size():
		var iv: int = int(intervals[i])
		var bass_pc: int = ((root_pc + iv) % 12 + 12) % 12
		# Use chord-structural spelling so e.g. C7's 7th displays as "Bb"
		# (stack-of-thirds rule) rather than "A#" (naive key preference).
		var bass_letter: String = ChordToneSpellingScript.spell_chord_bass(
			root_letter_only, root_acc_int, intervals, quality_for_spelling, bass_pc
		)
		if bass_letter == "":
			bass_letter = _spell_pc_in_key(bass_pc)
		var label_text: String
		if i == 0:
			label_text = "%s (root)" % root_letter
		else:
			label_text = "%s/%s" % [_chord_short_name(), bass_letter]
		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = Vector2(110, 32)
		btn.add_theme_font_size_override("font_size", 13)
		_apply_inversion_button_style(btn, bass_pc == current_bass_pc)
		var captured_idx := i
		btn.pressed.connect(func(): _play_inversion(base_root_midi, intervals, captured_idx))
		_inversions_row.add_child(btn)


func _chord_short_name() -> String:
	# Returns just the chord-quality portion of the short_name, dropping any
	# "/<bass>" suffix the recognizer added for the currently-played voicing.
	var name := str(_last_info.get("short_name", ""))
	var slash := name.find("/")
	if slash >= 0:
		return name.substr(0, slash)
	return name


func _apply_inversion_button_style(btn: Button, is_current: bool) -> void:
	var sb := StyleBoxFlat.new()
	var accent := MENU_PRIMARY_ACCENT if is_current else Color(0.36, 0.78, 1.00, 1.0)
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.18 if is_current else 0.10)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.85 if is_current else 0.50)
	sb.border_width_left = 2 if is_current else 1
	sb.border_width_right = 2 if is_current else 1
	sb.border_width_top = 2 if is_current else 1
	sb.border_width_bottom = 2 if is_current else 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.26)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


# Plays the chord with the chord-tone at `bass_index` as the lowest voice.
# Rotates intervals: the chosen tone moves to position 0, everything below it
# gets +12 semitones to keep the chord intact.
func _play_inversion(base_root_midi: int, intervals: Array, bass_index: int) -> void:
	if bass_index < 0 or bass_index >= intervals.size():
		return
	if _is_playback_busy():
		return
	var rotated: Array[int] = []
	for i in range(bass_index, intervals.size()):
		rotated.append(int(intervals[i]))
	for i in range(0, bass_index):
		rotated.append(int(intervals[i]) + 12)
	var chord_notes: Array[int] = []
	for offset in rotated:
		chord_notes.append(base_root_midi + offset)
	# Stage the rotated voicing so the staff, virtual keyboard, and
	# recognizer (chord-name chip + bass/inversion chip) ALL reflect the
	# inversion the user clicked — not just the audio.
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for n in chord_notes:
		_recent_notes[n] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_refresh_display()
	_lock_playback(1.6)
	# Visual cue: pulse the bass key so the student connects slash
	# notation (C/E) to the actual lowest sounding note.
	var bass_note: int = chord_notes[0]
	for note_for_bass in chord_notes:
		if note_for_bass < bass_note:
			bass_note = note_for_bass
	_pulse_keyboard_key(bass_note)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(chord_notes, 1.6)
	elif _play_note_callable.is_valid():
		for n in chord_notes:
			_play_note_callable.call(n, 1.6)


# Brief scale-pulse on a keyboard key. Used to draw the eye to the bass
# note when the user clicks an inversion. Safe no-op if the keyboard
# hasn't been built yet or the pitch is outside the visible range.
func _pulse_keyboard_key(pitch: int) -> void:
	var btn_v: Variant = _keyboard_keys.get(pitch, null)
	if btn_v == null or not is_instance_valid(btn_v):
		return
	var btn := btn_v as Button
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2.ONE
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.18)
	t.tween_property(btn, "scale", Vector2.ONE, 0.42)


# --- Teacher presets row ---


func _on_presets_option_selected(idx: int) -> void:
	# Dropdown index 0 is the disabled "Quick presets..." placeholder; real
	# presets start at index 1 and map 1:1 to BUILT_IN_PRESETS.
	if idx <= 0:
		return
	var preset_idx := idx - 1
	if preset_idx < 0 or preset_idx >= BUILT_IN_PRESETS.size():
		return
	_load_preset(BUILT_IN_PRESETS[preset_idx])
	# Snap the OptionButton back to the placeholder so re-selecting the same
	# preset later re-triggers the load (item_selected only fires on changes).
	if _presets_option != null:
		_presets_option.select(0)


func _load_preset(preset: Dictionary) -> void:
	# Transpose the preset's C-rooted chord roots so the progression plays
	# in whatever key the user has currently selected. Preserves the
	# pedagogical pattern (ii-V-I, blues, modal mixture, etc.) without
	# forcing the user back into C.
	# If they haven't picked a key yet (still on default C), this is a no-op
	# because _key_pc = 0 = the preset's source key.
	var source_key_pc: int = int(preset.get("key_pc", 0))
	var target_key_pc: int = _key_pc  # use the user's currently-selected key
	var transpose_semis: int = ((target_key_pc - source_key_pc) % 12 + 12) % 12
	# Cache the preset's chord list and build the per-step button row, then
	# stage the first chord so the student sees immediate feedback.
	var chords_v: Variant = preset.get("chords", null)
	_rebuild_diatonic_row()
	if typeof(chords_v) != TYPE_ARRAY or (chords_v as Array).is_empty():
		_active_preset_chords = []
		_rebuild_preset_steps_row()
		_refresh_display()
		return
	# Apply transpose to each chord's root_pc. Roman numerals + qualities
	# are key-relative so they don't need transposing.
	var transposed: Array = []
	for chord_v in (chords_v as Array):
		if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
			continue
		var orig_root: int = int(chord_v[0])
		var new_root: int = ((orig_root + transpose_semis) % 12 + 12) % 12
		var t_chord: Array = [new_root]
		for i in range(1, (chord_v as Array).size()):
			t_chord.append(chord_v[i])
		transposed.append(t_chord)
	_active_preset_chords = transposed
	_active_preset_step_idx = -1
	# Invalidate any in-flight Play-All loop from a previous preset.
	_play_all_token += 1
	_rebuild_preset_steps_row()
	# Stage chord 0 so the teacher sees what they loaded.
	_play_preset_step(0)


# Stages the chord at `idx` in the active preset (root_pc, quality from the
# cached tuple). Plays it, refreshes the display, and updates the step-row
# highlight so the active chord is visually distinguished.
func _play_preset_step(idx: int) -> void:
	if idx < 0 or idx >= _active_preset_chords.size():
		return
	if _is_playback_busy():
		return
	var chord_v: Variant = _active_preset_chords[idx]
	if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
		return
	var chord: Array = chord_v
	var root_pc: int = int(chord[0])
	var intervals: Array = _intervals_for_chord_entry(chord)
	if intervals.is_empty():
		return
	# Anchor in C4-octave (root in 60..71) then drop another octave only if
	# the top voice would sail above the virtual keyboard's C6 (84). Also
	# clamp the floor at C3 (48) so we never go below the keyboard low.
	var base_root_midi: int = _anchor_root_for_chord(root_pc, intervals)
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for iv in intervals:
		_recent_notes[base_root_midi + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_active_preset_step_idx = idx
	_update_voice_leading(idx)
	_refresh_display()
	_restyle_preset_step_buttons()
	# Build the absolute MIDI note list and play as a single chord through
	# the pooled chord player. Falls back to the single-note callable (one
	# voice at a time) only if a parent that hasn't been updated didn't
	# pass play_chord into setup().
	var chord_notes: Array[int] = []
	for iv in intervals:
		chord_notes.append(base_root_midi + int(iv))
	_lock_playback(1.6)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(chord_notes, 1.6)
	elif _play_note_callable.is_valid():
		for n in chord_notes:
			_play_note_callable.call(n, 1.6)


# Plays every chord in the active preset in sequence with a short gap.
# A token is bumped on entry so a second click (or a new preset load) can
# abort the previous loop cleanly without overlapping audio.
func _play_all_preset_steps() -> void:
	if _active_preset_chords.is_empty():
		return
	if _is_playback_busy():
		return
	_play_all_token += 1
	var my_token: int = _play_all_token
	# Lock for the whole sequence up front so the per-step _play_preset_step
	# calls don't each try to re-lock for just 1.6s (which would let other
	# buttons re-enable between steps).
	_lock_playback(_active_preset_chords.size() * 1.8 + 0.1)
	for i in _active_preset_chords.size():
		if my_token != _play_all_token:
			return  # superseded by a newer Play-All / preset load
		if not is_inside_tree() or not visible:
			return
		# Bypass _play_preset_step's busy-check by calling its core staging
		# directly — we hold the lock for the whole sequence.
		_play_preset_step_unlocked(i)
		# Hold each chord for ~1.8s before stepping to the next. The chord
		# voicing itself plays for 1.6s; the extra 0.2s lets the ear settle
		# before the harmony changes.
		if not await _wait_sequence_seconds(1.8, my_token, -1):
			return


# Same as _play_preset_step but skips the busy-check + per-step lock.
# Used by _play_all_preset_steps which holds one lock for the whole loop.
func _play_preset_step_unlocked(idx: int) -> void:
	if idx < 0 or idx >= _active_preset_chords.size():
		return
	var chord_v: Variant = _active_preset_chords[idx]
	if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
		return
	var chord: Array = chord_v
	var root_pc: int = int(chord[0])
	var intervals: Array = _intervals_for_chord_entry(chord)
	if intervals.is_empty():
		return
	var base_root_midi: int = _anchor_root_for_chord(root_pc, intervals)
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for iv in intervals:
		_recent_notes[base_root_midi + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_active_preset_step_idx = idx
	_update_voice_leading(idx)
	_refresh_display()
	_restyle_preset_step_buttons()
	var chord_notes: Array[int] = []
	for iv in intervals:
		chord_notes.append(base_root_midi + int(iv))
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(chord_notes, 1.6)
	elif _play_note_callable.is_valid():
		for n in chord_notes:
			_play_note_callable.call(n, 1.6)


# Rebuilds the chord-step row UI: one labelled button per chord in the
# active preset + a trailing "▶ Play all" button. Hides the row entirely
# when no preset is loaded.
func _rebuild_preset_steps_row() -> void:
	if _preset_steps_row == null:
		return
	for child in _preset_steps_row.get_children():
		child.queue_free()
	if _active_preset_chords.is_empty():
		_preset_steps_row.visible = false
		_update_progression_analysis()
		return
	for i in _active_preset_chords.size():
		var chord_v: Variant = _active_preset_chords[i]
		if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
			continue
		var chord: Array = chord_v
		var root_pc: int = int(chord[0])
		var quality: String = str(chord[1])
		var roman: String = str(chord[2]) if chord.size() >= 3 else ""
		var chord_short: String = _chord_short_label(root_pc, quality)
		var btn := Button.new()
		# Two-line label: chord short name on top, Roman numeral underneath.
		btn.text = "%s\n%s" % [chord_short, roman]
		btn.custom_minimum_size = Vector2(96, 50)
		btn.add_theme_font_size_override("font_size", 14)
		var captured_idx := i
		btn.pressed.connect(func(): _play_preset_step(captured_idx))
		_apply_preset_step_button_style(btn, i == _active_preset_step_idx)
		_preset_steps_row.add_child(btn)
	# Play-all button at the end.
	var play_all_btn := Button.new()
	play_all_btn.text = "%s  Play all" % char(0x25B6)
	play_all_btn.custom_minimum_size = Vector2(120, 50)
	play_all_btn.add_theme_font_size_override("font_size", 14)
	play_all_btn.pressed.connect(_play_all_preset_steps)
	_apply_play_all_button_style(play_all_btn)
	_preset_steps_row.add_child(play_all_btn)
	_preset_steps_row.visible = true
	_update_progression_analysis()


# Re-applies the active/inactive styling to each step button so the
# currently-playing chord stands out. Called from _play_preset_step rather
# than rebuilding the row, so click responses stay instant.
func _restyle_preset_step_buttons() -> void:
	if _preset_steps_row == null:
		return
	var children := _preset_steps_row.get_children()
	for i in _active_preset_chords.size():
		if i >= children.size():
			break
		var btn := children[i] as Button
		if btn == null:
			continue
		_apply_preset_step_button_style(btn, i == _active_preset_step_idx)


# Returns a short chord label for the step button (e.g. "Dm7", "Cmaj7").
# Uses the note letter from NOTE_NAMES_SHARP + a small quality suffix map.
func _chord_short_label(root_pc: int, quality: String) -> String:
	var pc: int = ((root_pc % 12) + 12) % 12
	var root_letter: String = _spell_pc_in_key(pc)
	var suffix: String
	match quality:
		"Major": suffix = ""
		"Minor": suffix = "m"
		_:
			suffix = quality
	return "%s%s" % [root_letter, suffix]


# Enharmonic spelling based on the currently-selected key. Flat keys use the
# flat names (Bb, Eb, Ab...); sharp keys use the sharp names (F#, C#, G#...).
# Picked from the KEY_OPTIONS label the user clicked — that lets pc=6 read
# as F# OR Gb depending on which entry they chose.
func _spell_pc_in_key(pc: int) -> String:
	var pc_clamped: int = ((int(pc) % 12) + 12) % 12
	if _key_uses_flats:
		return NOTE_NAMES_FLAT[pc_clamped]
	return NOTE_NAMES_SHARP[pc_clamped]


func _apply_preset_step_button_style(btn: Button, is_active: bool) -> void:
	var sb := StyleBoxFlat.new()
	var accent := MENU_PRIMARY_ACCENT if is_active else Color(0.36, 0.78, 1.00, 1.0)
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.22 if is_active else 0.10)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.92 if is_active else 0.55)
	sb.border_width_left = 2 if is_active else 1
	sb.border_width_right = 2 if is_active else 1
	sb.border_width_top = 2 if is_active else 1
	sb.border_width_bottom = 2 if is_active else 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.30)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


func _apply_play_all_button_style(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.28)
	sb.border_color = Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(MENU_PRIMARY_ACCENT.r, MENU_PRIMARY_ACCENT.g, MENU_PRIMARY_ACCENT.b, 0.40)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


# Resolves a quality id to its semitone interval array. Local table covers
# every quality used by the built-in presets; extend here when adding new
# preset entries that reference qualities not listed below.
# --- "Show how to form this chord" step-through ---


func _build_formation_panel(parent: Container) -> void:
	_formation_panel = PanelContainer.new()
	_formation_panel.visible = false
	_formation_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.10, 0.18, 0.97)
	sb.border_color = MENU_PRIMARY_ACCENT
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_formation_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(_formation_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_formation_panel.add_child(col)

	# Header row: step counter + close button.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	col.add_child(header_row)
	_formation_title_label = Label.new()
	_formation_title_label.text = "Step 1 of 3"
	_formation_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_title_label.add_theme_font_size_override("font_size", 14)
	_formation_title_label.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	if _ui_font != null:
		_formation_title_label.add_theme_font_override("font", _ui_font)
	header_row.add_child(_formation_title_label)
	var close_btn := Button.new()
	close_btn.text = char(0x2715)  # ✕
	close_btn.tooltip_text = "Close — back to chord display"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_close_formation)
	header_row.add_child(close_btn)

	# Action line — big: "Add the major 3rd (E)"
	_formation_action_label = Label.new()
	_formation_action_label.text = ""
	_formation_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formation_action_label.add_theme_font_size_override("font_size", 22)
	_formation_action_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.98))
	if _ui_title_font != null:
		_formation_action_label.add_theme_font_override("font", _ui_title_font)
	col.add_child(_formation_action_label)

	# Why line — short, italic-ish.
	_formation_why_label = Label.new()
	_formation_why_label.text = ""
	_formation_why_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_formation_why_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formation_why_label.add_theme_font_size_override("font_size", 13)
	_formation_why_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.88))
	if _ui_font != null:
		_formation_why_label.add_theme_font_override("font", _ui_font)
	col.add_child(_formation_why_label)

	# Key-relative context — "Scale degree 5 of C major"
	_formation_context_label = Label.new()
	_formation_context_label.text = ""
	_formation_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formation_context_label.add_theme_font_size_override("font_size", 12)
	_formation_context_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.96, 0.92))
	if _ui_font != null:
		_formation_context_label.add_theme_font_override("font", _ui_font)
	col.add_child(_formation_context_label)

	# Button row: Back / Play / Next
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	col.add_child(btn_row)
	_formation_back_btn = Button.new()
	_formation_back_btn.text = "%s  Back" % char(0x2190)
	_formation_back_btn.custom_minimum_size = Vector2(96, 34)
	_formation_back_btn.pressed.connect(_on_formation_back)
	btn_row.add_child(_formation_back_btn)
	_formation_play_btn = Button.new()
	_formation_play_btn.text = "%s  Play" % char(0x266A)
	_formation_play_btn.custom_minimum_size = Vector2(96, 34)
	_formation_play_btn.pressed.connect(_on_formation_play)
	btn_row.add_child(_formation_play_btn)
	_formation_next_btn = Button.new()
	_formation_next_btn.text = "Next  %s" % char(0x2192)
	_formation_next_btn.custom_minimum_size = Vector2(96, 34)
	_formation_next_btn.pressed.connect(_on_formation_next)
	btn_row.add_child(_formation_next_btn)


func _on_formation_pressed() -> void:
	if _last_info.is_empty():
		return
	var quality: String = str(_last_info.get("quality", ""))
	if quality == "" or quality == "single" or quality == "interval" or quality == "cluster":
		return
	# Pull intervals straight from the recognizer's output instead of going
	# through _intervals_for_quality. The recognizer's quality_short vocabulary
	# (e.g. "7", "maj7", "m7", "dim") doesn't match the panel's preset
	# vocabulary (e.g. "Dom7", "Maj7", "Min7", "Dim"), so the lookup path
	# only worked for "Major" and "Minor" by coincidence. Using intervals
	# directly makes every chord the recognizer can name walk-throughable.
	var intervals_v: Variant = _last_info.get("intervals_from_root", null)
	if typeof(intervals_v) != TYPE_ARRAY:
		return
	var intervals: Array = intervals_v
	if intervals.size() < 2:
		return  # single note / nothing to step through
	var root_pc: int = int(_last_info.get("root_pc", _key_pc))
	var data: Dictionary = ChordFormationStepsScript.build(intervals, root_pc, quality, _key_pc, _key_is_minor, _key_uses_flats)
	if not bool(data.get("valid", false)):
		return
	_formation_steps_data = data.get("steps", [])
	if _formation_steps_data.is_empty():
		return
	# Snapshot current chord-builder state so we restore it on close.
	_formation_saved_recent_notes = _recent_notes.duplicate()
	_formation_saved_window_expires_at = _window_expires_at
	# Use the tertian-ordered intervals so step playback adds notes in the
	# same order the step labels describe (Root → 3rd → 5th → 7th → 9th, etc.).
	_formation_intervals = data.get("ordered_intervals", intervals)
	_formation_base_root_midi = _anchor_root_for_chord(root_pc, _formation_intervals)
	_formation_step_idx = -1
	_formation_panel.visible = true
	if _chord_detail_tabs != null:
		_chord_detail_tabs.visible = false
	_advance_formation_to(0, data)


func _advance_formation_to(idx: int, data_or_null: Variant = null) -> void:
	if _formation_steps_data.is_empty():
		return
	idx = clampi(idx, 0, _formation_steps_data.size() - 1)
	_formation_step_idx = idx
	# Rebuild _recent_notes to contain exactly the first (idx+1) chord tones.
	_recent_notes.clear()
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for i in idx + 1:
		var iv: int = int(_formation_intervals[i])
		_recent_notes[_formation_base_root_midi + iv] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_refresh_display()
	_apply_formation_keyboard_labels()
	_render_formation_step(data_or_null)
	_play_formation_step_audio()


# Overlays chord-degree numbers on the on-screen keyboard for the octave that
# the walkthrough is anchored to. Each key in [base_root, base_root+12] gets
# "1", "♭2", "2", ..., "8" labeled on it. Chord-tone keys (1, 3, 5, ♭7 etc.)
# get the high-contrast color; non-chord-tone keys are muted so the chord's
# interval geometry stands out at a glance.
func _apply_formation_keyboard_labels() -> void:
	if _keyboard_keys.is_empty() or _formation_step_idx < 0:
		return
	var root: int = _formation_base_root_midi
	# Which chord-tone intervals (mod 12) are in the chord?
	var chord_tone_mods: Dictionary = {}
	for iv in _formation_intervals:
		chord_tone_mods[((int(iv) % 12) + 12) % 12] = true
	for pitch_key in _keyboard_keys.keys():
		var pitch: int = int(pitch_key)
		var btn: Button = _keyboard_keys[pitch_key] as Button
		if btn == null:
			continue
		var semi_from_root: int = pitch - root
		if semi_from_root < 0 or semi_from_root > 12:
			btn.text = ""
			btn.remove_theme_color_override("font_color")
			continue
		btn.text = _FORMATION_DEGREE_LABELS[semi_from_root]
		btn.add_theme_font_size_override("font_size", 11)
		var is_chord_tone: bool = chord_tone_mods.has(((semi_from_root % 12) + 12) % 12)
		var is_black: bool = PianoKeyStylesScript.is_black_key(pitch)
		if is_chord_tone:
			if is_black:
				btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			else:
				btn.add_theme_color_override("font_color", Color(0.10, 0.13, 0.18, 1.0))
		else:
			if is_black:
				btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
			else:
				btn.add_theme_color_override("font_color", Color(0.42, 0.48, 0.56, 0.62))


# Wipes the walkthrough's degree-number overlay. Called when the formation
# panel closes or the panel is dismissed.
func _clear_formation_keyboard_labels() -> void:
	if _keyboard_keys.is_empty():
		return
	for pitch_key in _keyboard_keys.keys():
		var btn: Button = _keyboard_keys[pitch_key] as Button
		if btn == null:
			continue
		btn.text = ""
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_font_size_override("font_size")


func _render_formation_step(data_or_null: Variant) -> void:
	if _formation_step_idx < 0 or _formation_step_idx >= _formation_steps_data.size():
		return
	var step: Dictionary = _formation_steps_data[_formation_step_idx]
	var total: int = int(step.get("total_steps", _formation_steps_data.size()))
	var step_num: int = int(step.get("step_number", _formation_step_idx + 1))
	_formation_title_label.text = "Step %d of %d" % [step_num, total]
	var note_letter: String = str(step.get("note_letter", ""))
	var full_name: String = str(step.get("full_name", ""))
	if _formation_step_idx == 0:
		_formation_action_label.text = "Start on the root: %s" % note_letter
	else:
		_formation_action_label.text = "Add the %s (%s)" % [full_name, note_letter]
	_formation_why_label.text = str(step.get("why", ""))
	# Build the key-context line. On step 1 we also surface the chord's function
	# in the current key (from the headline data) when we have it.
	var ctx_parts: Array[String] = []
	var key_degree: String = str(step.get("key_degree", ""))
	var key_letter: String = ChordFormationStepsScript._spell_pc(_key_pc, _key_uses_flats)
	var key_mode: String = "minor" if _key_is_minor else "major"
	if key_degree != "" and key_degree != "?":
		ctx_parts.append("Scale degree %s of %s %s" % [key_degree, key_letter, key_mode])
	if _formation_step_idx == 0 and data_or_null is Dictionary:
		var fn: String = str((data_or_null as Dictionary).get("function_in_key", ""))
		if fn != "":
			ctx_parts.append(fn)
	_formation_context_label.text = "  ·  ".join(ctx_parts)
	# Button state.
	_formation_back_btn.disabled = _formation_step_idx == 0
	var last: bool = _formation_step_idx == _formation_steps_data.size() - 1
	_formation_next_btn.text = ("%s  Done" % char(0x2713)) if last else ("Next  %s" % char(0x2192))


func _on_formation_back() -> void:
	if _formation_step_idx <= 0:
		return
	_advance_formation_to(_formation_step_idx - 1)


func _on_formation_next() -> void:
	if _formation_step_idx < _formation_steps_data.size() - 1:
		_advance_formation_to(_formation_step_idx + 1)
	else:
		_close_formation()


func _on_formation_play() -> void:
	_play_formation_step_audio()


# Plays the accumulated notes-so-far. Uses the chord player so all voices
# sound together when more than one note is staged.
func _play_formation_step_audio() -> void:
	if _formation_step_idx < 0:
		return
	var notes: Array[int] = []
	for i in _formation_step_idx + 1:
		notes.append(_formation_base_root_midi + int(_formation_intervals[i]))
	if notes.size() <= 1:
		if _play_note_callable.is_valid() and notes.size() == 1:
			_play_note_callable.call(notes[0], 0.6)
		return
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(notes, 0.7)
	elif _play_note_callable.is_valid():
		for n in notes:
			_play_note_callable.call(n, 0.55)


func _close_formation() -> void:
	if _formation_panel == null:
		return
	_formation_panel.visible = false
	if _chord_detail_tabs != null:
		# Restore tabs visibility only if there's a real chord present.
		_chord_detail_tabs.visible = not _last_info.is_empty()
	_formation_step_idx = -1
	_formation_steps_data.clear()
	_clear_formation_keyboard_labels()
	# Restore the chord state the user had before they opened the walkthrough,
	# so they can keep exploring without re-staging.
	_recent_notes = _formation_saved_recent_notes.duplicate()
	_window_expires_at = _formation_saved_window_expires_at
	_formation_saved_recent_notes.clear()
	_refresh_display()


func _intervals_for_quality(quality: String) -> Array:
	var table := {
		"Major": [0, 4, 7],
		"Minor": [0, 3, 7],
		"Dim": [0, 3, 6],
		"Aug": [0, 4, 8],
		"Sus2": [0, 2, 7],
		"Sus4": [0, 5, 7],
		"Dom7": [0, 4, 7, 10],
		"Min7": [0, 3, 7, 10],
		"Maj7": [0, 4, 7, 11],
		"Dim7": [0, 3, 6, 9],
		"Half-dim": [0, 3, 6, 10],
		"mMaj7": [0, 3, 7, 11],
		"Maj7#11": [0, 4, 7, 11, 14, 18],
		"Maj6": [0, 4, 7, 9],
		"Min6": [0, 3, 7, 9],
		"Add9": [0, 4, 7, 14],
		"Madd9": [0, 3, 7, 14],
		"7sus4": [0, 5, 7, 10],
	}
	return table.get(quality, [])


# Resolves a progression entry's intervals-from-root. Prefers the stored
# recognizer intervals (entry[3], present for user-added chords) and falls back
# to the quality-string table (used by built-in presets).
func _intervals_for_chord_entry(chord: Array) -> Array:
	if chord.size() >= 4 and chord[3] is Array and not (chord[3] as Array).is_empty():
		return (chord[3] as Array)
	return _intervals_for_quality(str(chord[1]))


# --- Voicings row (pianistic voicing variations of the current chord) ---


# Voicing definitions: ordered list rendered as buttons. Each "fn" is the
# name of a helper that takes the chord's interval list (semitones from
# root, e.g. [0,4,7,11] for Cmaj7) and returns the transformed interval
# list. Buttons whose voicing returns [] for the current chord are hidden.
const _VOICING_DEFS: Array[Dictionary] = [
	{"id": "root", "label": "Root", "fn": "_voicing_root",
		"tooltip": "Closed position: notes stacked in thirds, root at the bottom."},
	{"id": "drop2", "label": "Drop 2", "fn": "_voicing_drop2",
		"tooltip": "Drop 2: the second-highest voice moves down an octave. Classic guitar/jazz wide voicing."},
	{"id": "drop3", "label": "Drop 3", "fn": "_voicing_drop3",
		"tooltip": "Drop 3: the third-highest voice moves down an octave. Wider, more open spread than Drop 2."},
	{"id": "shell", "label": "Shell", "fn": "_voicing_shell",
		"tooltip": "Shell: just root + 3rd + 7th (no 5th). The bare-bones jazz comping skeleton."},
	{"id": "open", "label": "Open", "fn": "_voicing_open",
		"tooltip": "Open: voices spread across two octaves (root low, 3rd + 7th high). The wide pianistic sound."},
]


func _refresh_voicings_row() -> void:
	if _voicings_row == null:
		return
	for child in _voicings_row.get_children():
		child.queue_free()
	if _last_info.is_empty():
		return
	var quality := str(_last_info.get("quality", ""))
	if quality == "" or quality == "single" or quality == "interval" or quality == "cluster":
		return
	var intervals_v: Variant = _last_info.get("intervals_from_root", null)
	if typeof(intervals_v) != TYPE_ARRAY:
		return
	var intervals: Array = intervals_v
	if intervals.size() < 3:
		return
	var root_pc: int = int(_last_info.get("root_pc", 0))
	var base_root_midi: int = _anchor_root_for_chord(root_pc, intervals)
	var label := Label.new()
	label.text = "Voicings:"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.78))
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	_voicings_row.add_child(label)
	for vdef in _VOICING_DEFS:
		var voicing_intervals: Array = call(str(vdef["fn"]), intervals)
		if voicing_intervals.is_empty():
			continue  # voicing not applicable to this chord (e.g. Shell on a triad)
		var btn := Button.new()
		btn.text = str(vdef["label"])
		btn.custom_minimum_size = Vector2(78, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = str(vdef.get("tooltip", ""))
		var captured_intervals := voicing_intervals
		btn.pressed.connect(func(): _play_voicing(base_root_midi, captured_intervals))
		_apply_voicing_button_style(btn)
		_voicings_row.add_child(btn)


# Voicing transformations — return [] when the voicing isn't applicable.


func _voicing_root(intervals: Array) -> Array:
	# Identity — original close-position voicing.
	var out: Array = []
	for iv in intervals:
		out.append(int(iv))
	return out


func _voicing_drop2(intervals: Array) -> Array:
	# Drop the SECOND-from-top voice down an octave. Classic jazz/guitar
	# voicing — opens up the chord without losing any tones. Needs at
	# least 4 voices; returns [] for triads.
	if intervals.size() < 4:
		return []
	var voices: Array[int] = []
	for iv in intervals:
		voices.append(int(iv))
	voices.sort()
	# Identify the 2nd-from-top index; drop that voice by an octave.
	var drop_idx: int = voices.size() - 2
	voices[drop_idx] -= 12
	voices.sort()
	return voices


func _voicing_drop3(intervals: Array) -> Array:
	# Drop the THIRD-from-top voice. Wider, more open spread.
	if intervals.size() < 4:
		return []
	var voices: Array[int] = []
	for iv in intervals:
		voices.append(int(iv))
	voices.sort()
	var drop_idx: int = voices.size() - 3
	voices[drop_idx] -= 12
	voices.sort()
	return voices


func _voicing_shell(intervals: Array) -> Array:
	# Shell voicing: root + 3rd + 7th, omitting the 5th — the classic jazz
	# guide-tone skeleton. Only offered for plain 4-note 7th chords built on a
	# PERFECT 5th (Maj7 / Dom7 / Min7 / mMaj7). For extended chords (9/11/13) a
	# shell would drop the colour tones, and for altered-5th chords (m7♭5, dim7,
	# aug7) it would drop the characteristic 5th — either way the chord on the
	# staff would no longer match the name, so the shell isn't offered there.
	if intervals.size() != 4:
		return []
	var third: int = -1
	var seventh: int = -1
	var has_perfect_fifth: bool = false
	for iv in intervals:
		var pc: int = ((int(iv) % 12) + 12) % 12
		if (pc == 3 or pc == 4) and third < 0:
			third = int(iv)
		if pc == 7:
			has_perfect_fifth = true
		if (pc == 10 or pc == 11) and seventh < 0:
			seventh = int(iv)
	if third < 0 or seventh < 0 or not has_perfect_fifth:
		return []
	return [0, third, seventh]


func _voicing_open(intervals: Array) -> Array:
	# Open voicing: take the close-position chord and spread it by lifting every
	# other voice up an octave, so adjacent voices sit roughly a 6th–10th apart —
	# the "wide pianistic" sound. Crucially this PRESERVES every chord tone
	# (including 9ths/11ths/13ths), so the notes on the staff still match the
	# chord name (an open Cmaj9 is still a Cmaj9, not a Cmaj7).
	if intervals.size() < 3:
		return []
	var voices: Array[int] = []
	for iv in intervals:
		voices.append(int(iv))
	voices.sort()
	var out: Array = []
	for i in range(voices.size()):
		if i % 2 == 1:
			out.append(voices[i] + 12)   # lift alternate voices an octave
		else:
			out.append(voices[i])
	out.sort()
	return out


func _play_voicing(base_root_midi: int, voicing_intervals: Array) -> void:
	if _is_playback_busy():
		return
	# Re-anchor so the highest voice still respects the keyboard ceiling
	# even after open-voicing transposition pushes notes up an octave.
	var anchor: int = base_root_midi
	var min_iv: int = 0
	var max_iv: int = 0
	for iv in voicing_intervals:
		min_iv = mini(min_iv, int(iv))
		max_iv = maxi(max_iv, int(iv))
	while anchor + max_iv > GENERATED_CHORD_HIGH and anchor > GENERATED_CHORD_LOW:
		anchor -= 12
	# Don't drop below the keyboard low — accept a clipped top if needed.
	while anchor + min_iv < GENERATED_CHORD_LOW and anchor + 12 + max_iv <= GENERATED_CHORD_HIGH:
		anchor += 12
	if anchor + min_iv < GENERATED_CHORD_LOW:
		anchor = GENERATED_CHORD_LOW - min_iv
	if anchor + max_iv > GENERATED_CHORD_HIGH:
		anchor = GENERATED_CHORD_HIGH - max_iv
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for iv in voicing_intervals:
		_recent_notes[anchor + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_refresh_display()
	var chord_notes: Array[int] = []
	for iv in voicing_intervals:
		chord_notes.append(anchor + int(iv))
	_lock_playback(1.6)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(chord_notes, 1.6)
	elif _play_note_callable.is_valid():
		for n in chord_notes:
			_play_note_callable.call(n, 1.6)


func _apply_voicing_button_style(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	var accent := Color(0.78, 0.74, 1.00, 1.0)  # lavender — extension chip color
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


# --- Compare row (A/B chord listening) ---


# Comparison qualities offered in the dropdown. Same set as the chord
# explorer's main library — kept small and focused on the comparisons
# students actually need ("Maj vs Min", "Maj7 vs Dom7", "Dom7 vs Dim7").
const _COMPARE_QUALITIES: Array[Dictionary] = [
	{"label": "Major",   "quality": "Major"},
	{"label": "Minor",   "quality": "Minor"},
	{"label": "Dim",     "quality": "Dim"},
	{"label": "Aug",     "quality": "Aug"},
	{"label": "Sus2",    "quality": "Sus2"},
	{"label": "Sus4",    "quality": "Sus4"},
	{"label": "Maj7",    "quality": "Maj7"},
	{"label": "Dom7",    "quality": "Dom7"},
	{"label": "Min7",    "quality": "Min7"},
	{"label": "Dim7",    "quality": "Dim7"},
	{"label": "Half-dim","quality": "Half-dim"},
	{"label": "Maj7#11", "quality": "Maj7#11"},
]


func _build_compare_row() -> void:
	if _compare_row == null:
		return
	for child in _compare_row.get_children():
		child.queue_free()
	var label := Label.new()
	label.text = "Compare with:"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.78))
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	_compare_row.add_child(label)
	_compare_option = OptionButton.new()
	_compare_option.custom_minimum_size = Vector2(140, 32)
	for q in _COMPARE_QUALITIES:
		_compare_option.add_item(str(q["label"]))
	_compare_option.selected = 1  # default to Minor — most-used compare for Major
	_compare_option.tooltip_text = "Quality of chord B (same root as the staged chord). E.g. Maj7 vs Dom7."
	_compare_row.add_child(_compare_option)
	var btn_a := Button.new()
	btn_a.text = "▶ A"
	btn_a.custom_minimum_size = Vector2(56, 32)
	btn_a.add_theme_font_size_override("font_size", 12)
	btn_a.tooltip_text = "Play the currently-staged chord (A)."
	btn_a.pressed.connect(func(): _compare_play_side("a"))
	_apply_compare_button_style(btn_a, false)
	_compare_row.add_child(btn_a)
	var btn_b := Button.new()
	btn_b.text = "▶ B"
	btn_b.custom_minimum_size = Vector2(56, 32)
	btn_b.add_theme_font_size_override("font_size", 12)
	btn_b.tooltip_text = "Play the comparison chord (B): same root, picked quality."
	btn_b.pressed.connect(func(): _compare_play_side("b"))
	_apply_compare_button_style(btn_b, false)
	_compare_row.add_child(btn_b)
	var btn_ab := Button.new()
	btn_ab.text = "▶ A → B → A"
	btn_ab.custom_minimum_size = Vector2(140, 32)
	btn_ab.add_theme_font_size_override("font_size", 12)
	btn_ab.tooltip_text = "Play A, then B, then A again — the back-to-back contrast that locks the difference in your ear."
	btn_ab.pressed.connect(func(): _compare_play_side("ab"))
	_apply_compare_button_style(btn_ab, true)
	_compare_row.add_child(btn_ab)


func _refresh_compare_row() -> void:
	# Compare-row content (label + dropdown + buttons) is static; the row
	# itself is always populated by _build_compare_row at startup. The
	# tab-container-level visibility is now managed centrally — this
	# function is kept only for symmetry with the other two refresh hooks
	# and gates the overall tab container together with them.
	pass


# Hides the chord-detail tab container when no chord is staged AND no useful
# rows can render (cluster / single note). Shows it otherwise so the user
# can access Inversions / Voicings / Compare via the tab bar.
func _refresh_chord_detail_tabs_visibility() -> void:
	if _chord_detail_tabs == null:
		return
	# Suppress the tabs while the formation walkthrough panel owns the slot.
	var formation_open: bool = _formation_panel != null and _formation_panel.visible
	var can_show_formation_btn: bool = false
	if _last_info.is_empty():
		_chord_detail_tabs.visible = false
	else:
		var quality := str(_last_info.get("quality", ""))
		if quality == "" or quality == "single" or quality == "cluster" or quality == "interval":
			_chord_detail_tabs.visible = false
		else:
			_chord_detail_tabs.visible = not formation_open
			can_show_formation_btn = true
	if _formation_button != null:
		_formation_button.visible = can_show_formation_btn and not formation_open


func _compare_play_side(which: String) -> void:
	# A = current chord, B = same root + quality picked in the dropdown.
	if _compare_option == null or _last_info.is_empty():
		return
	if _is_playback_busy():
		return
	var root_pc: int = int(_last_info.get("root_pc", 0))
	var intervals_a_v: Variant = _last_info.get("intervals_from_root", null)
	if typeof(intervals_a_v) != TYPE_ARRAY:
		return
	var intervals_a: Array = intervals_a_v
	var sel: int = _compare_option.selected
	if sel < 0 or sel >= _COMPARE_QUALITIES.size():
		return
	var quality_b: String = str(_COMPARE_QUALITIES[sel]["quality"])
	var intervals_b: Array = _intervals_for_quality(quality_b)
	if intervals_b.is_empty():
		return
	# Anchor each chord independently so wide voicings (Maj7#11 etc.) still
	# fit on the keyboard. Same anchoring as preset playback.
	var anchor_a: int = _anchor_root_for_chord(root_pc, intervals_a)
	var anchor_b: int = _anchor_root_for_chord(root_pc, intervals_b)
	var notes_a: Array[int] = []
	for iv in intervals_a:
		notes_a.append(anchor_a + int(iv))
	var notes_b: Array[int] = []
	for iv in intervals_b:
		notes_b.append(anchor_b + int(iv))
	# Snapshot _recent_notes so the staff/keyboard return to the user's
	# anchor chord (A) after a single-B preview or after an A→B→A sequence
	# completes. Without the snapshot a single "B" press would silently
	# overwrite _last_info and the next "A" press would actually play B.
	var anchor_recent: Dictionary = _recent_notes.duplicate()
	var anchor_window: float = _window_expires_at
	# Token-guard so a new compare press aborts any in-flight sequence.
	_compare_token += 1
	var my_token: int = _compare_token
	match which:
		"a":
			_lock_playback(1.6)
			_stage_chord_for_compare(notes_a)
			_play_chord_now(notes_a)
		"b":
			# Show B on the staff during preview, restore A after the audio
			# tail so the user's anchor chord doesn't silently change.
			_lock_playback(1.9)
			_stage_chord_for_compare(notes_b)
			_play_chord_now(notes_b)
			if not await _wait_sequence_seconds(1.55, -1, my_token):
				return
			if my_token == _compare_token and is_inside_tree() and visible:
				_recent_notes = anchor_recent
				_window_expires_at = anchor_window
				_refresh_display()
		"ab":
			# A → B → A is ~3 × 1.55s + 0.1 safety.
			_lock_playback(4.75)
			await _play_compare_sequence(notes_a, notes_b, my_token)
			# Sequence ends on A. Re-stamp from the original snapshot so the
			# anchor-restored state matches the user's pre-compare display.
			if my_token == _compare_token and is_inside_tree() and visible:
				_recent_notes = anchor_recent
				_window_expires_at = anchor_window
				_refresh_display()


# Replace _recent_notes with the given chord so the staff + keyboard + chord-
# name labels reflect what compare is currently playing. Mirrors the formation
# walkthrough's staging path. Caller is responsible for restoring the original
# _recent_notes snapshot after the playback completes.
func _stage_chord_for_compare(notes: Array[int]) -> void:
	_recent_notes.clear()
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for n in notes:
		_recent_notes[int(n)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_refresh_display()


# Plays a single chord through the chord callable (single-note fallback).
func _play_chord_now(notes: Array[int]) -> void:
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(notes, 1.4)
	elif _play_note_callable.is_valid():
		for n in notes:
			_play_note_callable.call(n, 1.4)


# A → short gap → B → short gap → A. The return-to-A is the pedagogical
# magic — students hear the contrast both forward and backward, which
# locks in the difference. Staff + keyboard sync each step so the user
# sees what they're hearing.
func _play_compare_sequence(notes_a: Array[int], notes_b: Array[int], my_token: int) -> void:
	if my_token != _compare_token:
		return
	_stage_chord_for_compare(notes_a)
	_play_chord_now(notes_a)
	if not await _wait_sequence_seconds(1.55, -1, my_token):
		return
	if my_token != _compare_token or not is_inside_tree() or not visible:
		return
	_stage_chord_for_compare(notes_b)
	_play_chord_now(notes_b)
	if not await _wait_sequence_seconds(1.55, -1, my_token):
		return
	if my_token != _compare_token or not is_inside_tree() or not visible:
		return
	_stage_chord_for_compare(notes_a)
	_play_chord_now(notes_a)


func _wait_sequence_seconds(seconds: float, play_all_token: int = -1, compare_token: int = -1) -> bool:
	var deadline := (float(Time.get_ticks_msec()) / 1000.0) + maxf(0.0, seconds)
	while (float(Time.get_ticks_msec()) / 1000.0) < deadline:
		if not is_inside_tree() or not visible:
			return false
		if play_all_token != -1 and play_all_token != _play_all_token:
			return false
		if compare_token != -1 and compare_token != _compare_token:
			return false
		await get_tree().process_frame
	return true


func _apply_compare_button_style(btn: Button, emphasized: bool) -> void:
	var sb := StyleBoxFlat.new()
	var accent := MENU_PRIMARY_ACCENT if emphasized else Color(0.95, 0.50, 0.85, 1.0)
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.20 if emphasized else 0.12)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.90 if emphasized else 0.60)
	sb.border_width_left = 2 if emphasized else 1
	sb.border_width_right = 2 if emphasized else 1
	sb.border_width_top = 2 if emphasized else 1
	sb.border_width_bottom = 2 if emphasized else 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.30)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


# --- Diatonic cheat-sheet row ---


# Scale degree offsets (semitones from tonic) for the major + natural-minor
# scales. The 7 diatonic triads stack thirds at degrees [1,3,5] from each
# scale step — already encoded in the quality patterns below.
const _MAJOR_SCALE := [0, 2, 4, 5, 7, 9, 11]
const _MINOR_SCALE := [0, 2, 3, 5, 7, 8, 10]
# Harmonic minor: like natural minor but with raised 7th (10 → 11).
# Common-practice teaching uses this for V (Major) + vii° in minor keys.
const _HARMONIC_MINOR_SCALE := [0, 2, 3, 5, 7, 8, 11]

# Per-degree triad quality + Roman label for each mode. Index 0 = tonic.
const _MAJOR_DIATONIC := [
	{"quality": "Major",  "roman": "I"},
	{"quality": "Minor",  "roman": "ii"},
	{"quality": "Minor",  "roman": "iii"},
	{"quality": "Major",  "roman": "IV"},
	{"quality": "Major",  "roman": "V"},
	{"quality": "Minor",  "roman": "vi"},
	{"quality": "Dim",    "roman": "vii°"},
]
const _MINOR_DIATONIC := [
	{"quality": "Minor",  "roman": "i"},
	{"quality": "Dim",    "roman": "ii°"},
	{"quality": "Major",  "roman": "III"},
	{"quality": "Minor",  "roman": "iv"},
	{"quality": "Minor",  "roman": "v"},
	{"quality": "Major",  "roman": "VI"},
	{"quality": "Major",  "roman": "VII"},
]
# Harmonic minor diatonic triads — V becomes Major (the leading-tone V
# central to cadence teaching) and vii° becomes a true Diminished triad.
const _HARMONIC_MINOR_DIATONIC := [
	{"quality": "Minor",  "roman": "i"},
	{"quality": "Dim",    "roman": "ii°"},
	{"quality": "Aug",    "roman": "III+"},
	{"quality": "Minor",  "roman": "iv"},
	{"quality": "Major",  "roman": "V"},
	{"quality": "Major",  "roman": "VI"},
	{"quality": "Dim",    "roman": "vii°"},
]


# Three-mode key flavor — drives both the diatonic row and the preset key
# label. Major + natural minor are the existing toggle; harmonic minor is
# the new third option that classical teachers need for cadence work.
enum KeyFlavor { MAJOR, NATURAL_MINOR, HARMONIC_MINOR }
var _key_flavor: int = KeyFlavor.MAJOR


func _rebuild_diatonic_row() -> void:
	if _diatonic_row == null:
		return
	for child in _diatonic_row.get_children():
		child.queue_free()
	var label := Label.new()
	label.text = "Key chords:"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.78))
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	label.tooltip_text = "The 7 diatonic chords in the current key. Click any to play it."
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	_diatonic_row.add_child(label)
	var scale: Array
	var defs: Array
	match _key_flavor:
		KeyFlavor.HARMONIC_MINOR:
			scale = _HARMONIC_MINOR_SCALE
			defs = _HARMONIC_MINOR_DIATONIC
		KeyFlavor.NATURAL_MINOR:
			scale = _MINOR_SCALE
			defs = _MINOR_DIATONIC
		_:
			scale = _MAJOR_SCALE
			defs = _MAJOR_DIATONIC
	for i in 7:
		var degree_offset: int = int(scale[i])
		var degree_pc: int = ((_key_pc + degree_offset) % 12 + 12) % 12
		var quality: String = str(defs[i]["quality"])
		var roman: String = str(defs[i]["roman"])
		var chord_short: String = _chord_short_label(degree_pc, quality)
		var btn := Button.new()
		btn.text = "%s\n%s" % [chord_short, roman]
		btn.custom_minimum_size = Vector2(72, 50)
		btn.add_theme_font_size_override("font_size", 13)
		var captured_pc := degree_pc
		var captured_quality := quality
		btn.pressed.connect(func(): _stage_and_play_diatonic_chord(captured_pc, captured_quality))
		_apply_diatonic_button_style(btn)
		_diatonic_row.add_child(btn)
	_diatonic_row.visible = true


func _stage_and_play_diatonic_chord(root_pc: int, quality: String) -> void:
	if _is_playback_busy():
		return
	var intervals: Array = _intervals_for_quality(quality)
	if intervals.is_empty():
		return
	var base_root_midi: int = _anchor_root_for_chord(root_pc, intervals)
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for iv in intervals:
		_recent_notes[base_root_midi + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	# Clicking a diatonic chord is independent of any loaded preset — clear
	# the active preset step highlight so the chord-step row doesn't lie.
	_active_preset_step_idx = -1
	_restyle_preset_step_buttons()
	_refresh_display()
	var chord_notes: Array[int] = []
	for iv in intervals:
		chord_notes.append(base_root_midi + int(iv))
	# Lock playback like preset / voicing / compare paths so click-spam on
	# the diatonic row can't overlap chord audio.
	_lock_playback(1.6)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(chord_notes, 1.6)
	elif _play_note_callable.is_valid():
		for n in chord_notes:
			_play_note_callable.call(n, 1.6)


func _apply_diatonic_button_style(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	var accent := Color(0.45, 0.92, 0.62, 1.0)  # green — same as in-key chip
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.08)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.20)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", MENU_TITLE_TEXT)


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
	if pitches.is_empty():
		_push_notes_to_renderer(pitches)
		_chord_name_label.text = "Play a chord..."
		_chord_name_label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.96, 0.62))
		_full_name_label.text = ""
		if _theory_insight_label != null:
			_theory_insight_label.text = ""
		_set_chip(_roman_label, "")
		_set_chip(_inversion_label, "")
		_set_chip(_diatonic_label, "")
		_set_chip(_intervals_label, "")
		if _window_bar != null:
			_window_bar.modulate.a = 0.0
		_last_info = {}
		_refresh_keyboard_lighting()
		_refresh_inversions_row()
		_refresh_voicings_row()
		_refresh_compare_row()
		_refresh_chord_detail_tabs_visibility()
		_update_target_feedback()
		return
	var info: Dictionary = ChordRecognizerScript.recognize(
		pitches, _key_pc, _key_is_minor, _effective_uses_flats(), _key_flavor
	)
	_last_info = info
	# Engrave the staff with chord-tone-correct spelling (Bb vs A#, etc.).
	_push_notes_to_renderer(pitches, _build_chord_spelling_map(info))
	_refresh_keyboard_lighting()
	_chord_name_label.text = str(info.get("short_name", ""))
	_chord_name_label.add_theme_color_override("font_color", MENU_PRIMARY_ACCENT)
	_full_name_label.text = str(info.get("full_name", ""))
	if _theory_insight_label != null:
		_theory_insight_label.text = _theory_insight_text(info)
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
	_refresh_inversions_row()
	_refresh_voicings_row()
	_refresh_compare_row()
	_refresh_chord_detail_tabs_visibility()
	_update_target_feedback()


# --- Theory insight (chord function/resolution + chord–scale relationships) ---


func _theory_insight_text(info: Dictionary) -> String:
	var quality := str(info.get("quality", ""))
	if quality == "" or quality in ["single", "interval", "cluster"]:
		return ""
	var roman := str(info.get("roman", ""))
	var parts: Array[String] = []
	var fn := _function_insight(roman, quality)
	if fn != "":
		parts.append("%s  %s" % [char(0x21AA), fn])   # ↪ function/resolution
	var scales := _scales_for_quality(quality)
	if scales != "":
		parts.append("%s  Fits: %s" % [char(0x1F3B9), scales])   # 🎹 chord-scales
	return "     ·     ".join(parts)


# Where the chord wants to go. Uses the Roman numeral when the chord is diatonic;
# otherwise falls back to the chord quality's general tendency.
func _function_insight(roman: String, quality: String) -> String:
	var r := roman.to_lower().replace("°", "").strip_edges()
	if r.begins_with("vii"):
		return "leading-tone chord — resolves up a half step to the tonic"
	if r.begins_with("v") and not r.begins_with("vi"):
		return "dominant — pulls strongly home to I/i"
	if r.begins_with("iv"):
		return "subdominant — moves on to V or back home"
	if r.begins_with("ii"):
		return "pre-dominant — sets up the V"
	if r.begins_with("vi"):
		return "submediant — the 'deceptive' landing"
	if r.begins_with("iii"):
		return "mediant — a soft passing colour"
	if r == "i":
		return "tonic — home base, at rest"
	# Non-diatonic / unknown function: infer from quality.
	var q := quality.to_lower()
	if q.find("7") >= 0 and (q.begins_with("dom") or q in ["7", "9", "13", "11", "7b9", "7#9", "7b5", "7sus4"]):
		return "dominant 7th — wants to resolve down a 5th (e.g. G7 → C)"
	if q.find("dim") >= 0:
		return "diminished — very unstable, resolves up a half step"
	if q.find("maj7") >= 0:
		return "major 7th — lush and restful (a tonic colour)"
	return ""


# Scales/modes that improvise naturally over the chord quality.
func _scales_for_quality(quality: String) -> String:
	var q := quality.to_lower()
	if q.find("maj7") >= 0 or q.find("maj9") >= 0 or q == "major" or q == "maj6" or q == "6" or q.find("add9") >= 0 or q == "6/9":
		return "Ionian (major), Lydian"
	if q.find("m7b5") >= 0 or q.find("half") >= 0:
		return "Locrian, Locrian ♮2"
	if q.find("dim") >= 0:
		return "Whole–half diminished"
	if q.find("aug") >= 0:
		return "Whole-tone"
	if q == "minor" or q.begins_with("m") or q.find("min") >= 0:
		return "Dorian, Aeolian, Phrygian"
	if q.find("sus") >= 0:
		return "Mixolydian, Major"
	# Dominant family (7, 9, 13, altered).
	if q.find("7") >= 0 or q.find("9") >= 0 or q.find("13") >= 0:
		return "Mixolydian, Lydian dominant, Altered"
	return ""


func _push_notes_to_renderer(pitches: Array[int], spelling_map: Dictionary = {}) -> void:
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
	var fifths: int = ChordExplorerTheoryScript.key_pc_to_fifths(_key_pc, _key_is_minor, _key_uses_flats)
	var score_dict: Dictionary = ScoreModelScript.from_flat_notes_grand_staff(
		flat_notes, 4, 4, fifths, _key_is_minor, 80, "", 60
	)
	# Chord-tone spelling so the staff engraves e.g. a C7's b7 as Bb (on the B
	# line), not A# — the renderer honors this per-pitch-class override.
	if not spelling_map.is_empty():
		score_dict["spelling_map"] = spelling_map
	# Colour each notehead by its chord-tone role (root/3rd/5th/7th…), matching
	# the keyboard. Darkened so the light keyboard hues stay legible on the
	# cream staff paper. Only when a chord with a real root is recognized.
	if not _last_info.is_empty() and int(_last_info.get("root_pc", -1)) >= 0:
		var cmap: Dictionary = {}
		for p in pitches:
			cmap[int(p)] = _note_color_for_pitch(int(p)).darkened(0.42)
		if not cmap.is_empty():
			score_dict["color_map"] = cmap
	_staff_area.set_score(score_dict)
	_refresh_staff_note_tooltips()


# Role name (Root / 3rd / 5th / 7th / tension) for a pitch, relative to the
# recognized chord's root. Empty when nothing is recognized.
func _role_name_for_pitch(pitch: int) -> String:
	if _last_info.is_empty():
		return ""
	var root_pc_v: Variant = _last_info.get("root_pc", -1)
	if int(root_pc_v) < 0:
		return ""
	var pc: int = ((int(pitch) % 12) + 12) % 12
	var degree: int = ((pc - int(root_pc_v)) + 12) % 12
	match degree:
		0: return "Root"
		1: return "♭9 (tension)"
		2: return "9th (tension)"
		3, 4: return "3rd"
		5: return "11th (tension)"
		6, 7, 8: return "5th"
		9: return "6th / 13th"
		10, 11: return "7th"
		_: return "color tone"


# Places invisible hover targets over each staff notehead so mousing a coloured
# note tells you its role + name (e.g. "E4  —  3rd"). Rebuilt on every staff
# push; a token guards against overlapping rebuilds.
func _refresh_staff_note_tooltips() -> void:
	for o in _staff_tooltip_overlays:
		if is_instance_valid(o):
			o.queue_free()
	_staff_tooltip_overlays.clear()
	if _staff_area == null or not is_instance_valid(_staff_area):
		return
	if _last_info.is_empty() or int(_last_info.get("root_pc", -1)) < 0:
		return
	if not _staff_area.has_method("get_note_screen_positions"):
		return
	_staff_tt_token += 1
	var tok: int = _staff_tt_token
	# Wait for the score to draw so notehead positions are recorded.
	await get_tree().process_frame
	await get_tree().process_frame
	if tok != _staff_tt_token or not is_instance_valid(_staff_area) or not visible:
		return
	var positions: Dictionary = _staff_area.get_note_screen_positions()
	for midi_v in positions:
		var midi: int = int(midi_v)
		var role: String = _role_name_for_pitch(midi)
		if role == "":
			continue
		var pos: Vector2 = positions[midi_v]
		var hit := Control.new()
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.size = Vector2(22, 20)
		hit.position = pos - Vector2(11, 10)
		hit.tooltip_text = "%s  —  %s" % [_note_name_midi(midi), role]
		_staff_area.add_child(hit)
		_staff_tooltip_overlays.append(hit)


# Builds a { pitch_class -> {letter, acc} } map from the recognized chord so the
# staff spells each tone by its stack-of-thirds function (Bb not A#, etc.).
func _build_chord_spelling_map(info: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var intervals: Array = info.get("intervals_from_root", [])
	if intervals.size() < 2:
		return out
	var quality: String = str(info.get("quality", ""))
	# Pick the root enharmonic that engraves the whole chord cleanest (Bb not A#,
	# etc.) straight from the root pitch class — the single source of truth shared
	# with the recognizer, so the staff and the chord-name chip always agree.
	var root_pc: int = int(info.get("root_pc", -1))
	if root_pc < 0:
		return out
	var rspell: Dictionary = ChordToneSpellingScript.best_root_spelling(root_pc, intervals, quality, _effective_uses_flats())
	var root_letter: String = str(rspell.get("letter", "C"))
	var root_acc: int = int(rspell.get("acc", 0))
	var tones: Array = ChordToneSpellingScript.spell_chord_tones(root_letter, root_acc, intervals, quality)
	var letter_pc := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	for t in tones:
		var letter := str((t as Dictionary).get("letter", ""))
		if letter == "" or not letter_pc.has(letter):
			continue
		var acc := int((t as Dictionary).get("accidental", 0))
		var pc: int = posmod(int(letter_pc[letter]) + acc, 12)
		out[pc] = {"letter": letter, "acc": acc}
	return out


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
