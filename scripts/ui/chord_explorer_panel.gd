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
# Presets dropdown lives in the top toolbar next to the key selector.
# (The old _presets_row HBox under the chord display was removed — that
# space was crowded; DAW-style toolbar dropdown is cleaner.)
var _presets_option: OptionButton = null
var _preset_steps_row: HBoxContainer = null
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
	play_chord: Callable = Callable()
) -> void:
	_ui_font = ui_font
	_ui_title_font = ui_title_font
	_play_note_callable = play_note
	_sample_map_callable = sample_map_fn
	_nearest_sample_callable = nearest_sample_fn
	_score_font_picker_builder = score_font_picker_builder
	_play_chord_callable = play_chord
	_force_fullscreen_rect()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 780
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.11, 0.19, 1.0)
	add_theme_stylebox_override("panel", panel_style)
	_build_ui()


# Show the panel and reset note-tracking state.
func present() -> void:
	_recent_notes.clear()
	_window_expires_at = -1.0
	_force_fullscreen_rect()
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
	_recent_notes.clear()
	_window_expires_at = -1.0
	# Tear down preset state so re-presenting starts fresh.
	_active_preset_chords = []
	_active_preset_step_idx = -1
	_play_all_token += 1
	# Invalidate any in-flight A→B→A sequence too.
	_compare_token += 1
	_rebuild_preset_steps_row()
	_hide_help_overlay()
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


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	# Side-by-side top section: staff (40%) on the left, chord display (60%)
	# on the right. Frees vertical space so the virtual keyboard stays
	# visible without scrolling — a single chord never needed the staff's
	# full width anyway.
	var top_section := HBoxContainer.new()
	top_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_section.add_theme_constant_override("separation", 14)
	chord_body.add_child(top_section)

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

	# Three chord-detail surfaces collapsed into a TabContainer to cut the
	# vertical density that built up as features piled on:
	#   - Inversions: chord with each chord tone as bass (C, C/E, C/G ...)
	#   - Voicings:   Root / Drop 2 / Drop 3 / Shell / Open
	#   - Compare:    pick a second quality at the same root + play A↔B
	# Only one tab's row is visible at a time → ~3x vertical savings.
	_chord_detail_tabs = TabContainer.new()
	_chord_detail_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chord_detail_tabs.custom_minimum_size = Vector2(0, 80)
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

	_build_keyboard(chord_body)
	# Initial diatonic row population (key starts at C major by default).
	_rebuild_diatonic_row()


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
	# The label tells us which enharmonic the user picked — "Bb" means flats,
	# "A#" would mean sharps. KEY_OPTIONS uses "b" suffix for flat spellings.
	_key_uses_flats = String(KEY_OPTIONS[idx][0]).contains("b")
	_rebuild_diatonic_row()
	_refresh_display()


func _on_minor_toggled(pressed: bool) -> void:
	_key_is_minor = pressed
	_rebuild_diatonic_row()
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


# Returns a root-MIDI anchor that keeps the chord rooted in the C4-octave
# whenever possible and never lets the top voice exceed KEYBOARD_HIGH (C6).
# Keyboard layout is C2-C6 (36-84) — we cap at 84 and floor at C3 (48) so
# even the widest chords stay visible + clickable on the on-screen piano.
func _anchor_root_for_chord(root_pc: int, intervals: Array) -> int:
	var pc: int = ((int(root_pc) % 12) + 12) % 12
	var base: int = 60 + pc  # default: C4-anchored root (60..71)
	if intervals.is_empty():
		return base
	var max_iv: int = 0
	for iv in intervals:
		max_iv = maxi(max_iv, int(iv))
	# Drop an octave at a time while the top voice clips above the keyboard.
	while base + max_iv > KEYBOARD_HIGH and base > 48:
		base -= 12
	# Don't let the root fall below C3 (48). If the chord is so wide that
	# even C3 + max_iv > C6, we accept the clip on the high end rather than
	# burying the root below the keyboard.
	if base < 48:
		base = 48
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
	# Build a button per chord-tone-as-bass.
	for i in intervals.size():
		var iv: int = int(intervals[i])
		var bass_pc: int = ((root_pc + iv) % 12 + 12) % 12
		var bass_letter: String = NOTE_NAMES_SHARP[bass_pc]
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
	var rotated: Array[int] = []
	for i in range(bass_index, intervals.size()):
		rotated.append(int(intervals[i]))
	for i in range(0, bass_index):
		rotated.append(int(intervals[i]) + 12)
	var chord_notes: Array[int] = []
	for offset in rotated:
		chord_notes.append(base_root_midi + offset)
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(chord_notes, 1.6)
	elif _play_note_callable.is_valid():
		for n in chord_notes:
			_play_note_callable.call(n, 1.6)


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
	var key_pc: int = int(preset.get("key_pc", 0))
	var is_minor: bool = bool(preset.get("is_minor", false))
	_key_pc = key_pc
	_key_is_minor = is_minor
	if _key_option != null:
		# Item order in _key_option mirrors KEY_OPTIONS (no metadata is set on
		# items, so look up the pitch class from KEY_OPTIONS by index).
		for i in range(_key_option.item_count):
			if i < KEY_OPTIONS.size() and int(KEY_OPTIONS[i][1]) == key_pc:
				_key_option.select(i)
				_key_uses_flats = String(KEY_OPTIONS[i][0]).contains("b")
				break
	if _minor_check != null:
		_minor_check.set_pressed_no_signal(is_minor)
	# Cache the preset's chord list and build the per-step button row, then
	# stage the first chord so the student sees immediate feedback.
	var chords_v: Variant = preset.get("chords", null)
	# Key may have changed when loading the preset — refresh the cheat sheet.
	_rebuild_diatonic_row()
	if typeof(chords_v) != TYPE_ARRAY or (chords_v as Array).is_empty():
		_active_preset_chords = []
		_rebuild_preset_steps_row()
		_refresh_display()
		return
	_active_preset_chords = (chords_v as Array).duplicate(true)
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
	var chord_v: Variant = _active_preset_chords[idx]
	if typeof(chord_v) != TYPE_ARRAY or (chord_v as Array).size() < 2:
		return
	var chord: Array = chord_v
	var root_pc: int = int(chord[0])
	var quality: String = str(chord[1])
	var intervals: Array = _intervals_for_quality(quality)
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
	_refresh_display()
	_restyle_preset_step_buttons()
	# Build the absolute MIDI note list and play as a single chord through
	# the pooled chord player. Falls back to the single-note callable (one
	# voice at a time) only if a parent that hasn't been updated didn't
	# pass play_chord into setup().
	var chord_notes: Array[int] = []
	for iv in intervals:
		chord_notes.append(base_root_midi + int(iv))
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
	_play_all_token += 1
	var my_token: int = _play_all_token
	for i in _active_preset_chords.size():
		if my_token != _play_all_token:
			return  # superseded by a newer Play-All / preset load
		if not is_inside_tree() or not visible:
			return
		_play_preset_step(i)
		# Hold each chord for ~1.8s before stepping to the next. The chord
		# voicing itself plays for 1.6s; the extra 0.2s lets the ear settle
		# before the harmony changes.
		await get_tree().create_timer(1.8).timeout


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
		"Maj7#11": [0, 4, 7, 11, 14, 18],
	}
	return table.get(quality, [])


# --- Voicings row (pianistic voicing variations of the current chord) ---


# Voicing definitions: ordered list rendered as buttons. Each "fn" is the
# name of a helper that takes the chord's interval list (semitones from
# root, e.g. [0,4,7,11] for Cmaj7) and returns the transformed interval
# list. Buttons whose voicing returns [] for the current chord are hidden.
const _VOICING_DEFS: Array[Dictionary] = [
	{"id": "root",   "label": "Root",    "fn": "_voicing_root"},
	{"id": "drop2",  "label": "Drop 2",  "fn": "_voicing_drop2"},
	{"id": "drop3",  "label": "Drop 3",  "fn": "_voicing_drop3"},
	{"id": "shell",  "label": "Shell",   "fn": "_voicing_shell"},
	{"id": "open",   "label": "Open",    "fn": "_voicing_open"},
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
	# Shell voicing: root + 3rd + 7th, dropping the 5th. Only meaningful
	# for 7th chords (need a 7th — interval 10 or 11). Triads + 9ths fall
	# through here too if they have a 7th.
	var has_seventh: bool = false
	for iv in intervals:
		var n: int = ((int(iv) % 12) + 12) % 12
		if n == 10 or n == 11:
			has_seventh = true
			break
	if not has_seventh:
		return []
	# Pick root (0), the lowest 3rd (3 or 4), and the 7th (10 or 11).
	var third: int = -1
	var seventh: int = -1
	for iv in intervals:
		var pc: int = ((int(iv) % 12) + 12) % 12
		if (pc == 3 or pc == 4) and third < 0:
			third = int(iv)
		if (pc == 10 or pc == 11) and seventh < 0:
			seventh = int(iv)
	if third < 0 or seventh < 0:
		return []
	return [0, third, seventh]


func _voicing_open(intervals: Array) -> Array:
	# Open voicing: root low, 5th below middle, 3rd above middle, top
	# tone (7th if present, else 5th up an octave) high. Spreads the
	# chord across roughly 2 octaves — the "wide pianistic" sound.
	if intervals.size() < 3:
		return []
	# Sort + identify root / 3rd / 5th / 7th by pitch class.
	var third: int = -1
	var fifth: int = -1
	var seventh: int = -1
	for iv in intervals:
		var pc: int = ((int(iv) % 12) + 12) % 12
		if (pc == 3 or pc == 4) and third < 0:
			third = int(iv)
		if (pc == 6 or pc == 7 or pc == 8) and fifth < 0:
			fifth = int(iv)
		if (pc == 10 or pc == 11) and seventh < 0:
			seventh = int(iv)
	# Build wide voicing: root, third up octave, fifth or seventh higher.
	var out: Array = [0]
	if fifth >= 0:
		out.append(fifth)  # keep 5th close to root for stability
	if third >= 0:
		out.append(third + 12)  # 3rd one octave up
	if seventh >= 0:
		out.append(seventh + 12)
	# Need >= 3 unique pitches and at least 1 octave span to feel "open".
	if out.size() < 3:
		return []
	return out


func _play_voicing(base_root_midi: int, voicing_intervals: Array) -> void:
	# Re-anchor so the highest voice still respects the keyboard ceiling
	# even after open-voicing transposition pushes notes up an octave.
	var anchor: int = base_root_midi
	var max_iv: int = 0
	for iv in voicing_intervals:
		max_iv = maxi(max_iv, int(iv))
	while anchor + max_iv > KEYBOARD_HIGH and anchor > 36:
		anchor -= 12
	# Don't drop below the keyboard low — accept a clipped top if needed.
	if anchor < 36:
		anchor = 36
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_recent_notes.clear()
	for iv in voicing_intervals:
		_recent_notes[anchor + int(iv)] = now
	_window_expires_at = now + CLICK_WINDOW_SEC
	_refresh_display()
	var chord_notes: Array[int] = []
	for iv in voicing_intervals:
		chord_notes.append(anchor + int(iv))
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
	_compare_row.add_child(_compare_option)
	var btn_a := Button.new()
	btn_a.text = "▶ A"
	btn_a.custom_minimum_size = Vector2(56, 32)
	btn_a.add_theme_font_size_override("font_size", 12)
	btn_a.pressed.connect(func(): _compare_play_side("a"))
	_apply_compare_button_style(btn_a, false)
	_compare_row.add_child(btn_a)
	var btn_b := Button.new()
	btn_b.text = "▶ B"
	btn_b.custom_minimum_size = Vector2(56, 32)
	btn_b.add_theme_font_size_override("font_size", 12)
	btn_b.pressed.connect(func(): _compare_play_side("b"))
	_apply_compare_button_style(btn_b, false)
	_compare_row.add_child(btn_b)
	var btn_ab := Button.new()
	btn_ab.text = "▶ A → B → A"
	btn_ab.custom_minimum_size = Vector2(140, 32)
	btn_ab.add_theme_font_size_override("font_size", 12)
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
	if _last_info.is_empty():
		_chord_detail_tabs.visible = false
		return
	var quality := str(_last_info.get("quality", ""))
	if quality == "" or quality == "single" or quality == "cluster":
		_chord_detail_tabs.visible = false
		return
	_chord_detail_tabs.visible = true


func _compare_play_side(which: String) -> void:
	# A = current chord, B = same root + quality picked in the dropdown.
	if _compare_option == null or _last_info.is_empty():
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
	# Token-guard so a new compare press aborts any in-flight sequence.
	_compare_token += 1
	var my_token: int = _compare_token
	match which:
		"a":
			_play_chord_now(notes_a)
		"b":
			_play_chord_now(notes_b)
		"ab":
			await _play_compare_sequence(notes_a, notes_b, my_token)


# Plays a single chord through the chord callable (single-note fallback).
func _play_chord_now(notes: Array[int]) -> void:
	if _play_chord_callable.is_valid():
		_play_chord_callable.call(notes, 1.4)
	elif _play_note_callable.is_valid():
		for n in notes:
			_play_note_callable.call(n, 1.4)


# A → short gap → B → short gap → A. The return-to-A is the pedagogical
# magic — students hear the contrast both forward and backward, which
# locks in the difference. ~0.45s gap so each chord has clean attack.
func _play_compare_sequence(notes_a: Array[int], notes_b: Array[int], my_token: int) -> void:
	if my_token != _compare_token:
		return
	_play_chord_now(notes_a)
	await get_tree().create_timer(1.55).timeout
	if my_token != _compare_token or not is_inside_tree() or not visible:
		return
	_play_chord_now(notes_b)
	await get_tree().create_timer(1.55).timeout
	if my_token != _compare_token or not is_inside_tree() or not visible:
		return
	_play_chord_now(notes_a)


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

# Per-degree triad quality + Roman label for each mode. Index 0 = tonic.
const _MAJOR_DIATONIC := [
	{"quality": "Major",  "roman": "I"},
	{"quality": "Minor",  "roman": "ii"},
	{"quality": "Minor",  "roman": "iii"},
	{"quality": "Major",  "roman": "IV"},
	{"quality": "Major",  "roman": "V"},
	{"quality": "Minor",  "roman": "vi"},
	{"quality": "Dim",    "roman": "vii°"},  # vii°
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
	var scale := _MINOR_SCALE if _key_is_minor else _MAJOR_SCALE
	var defs := _MINOR_DIATONIC if _key_is_minor else _MAJOR_DIATONIC
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
		_refresh_inversions_row()
		_refresh_voicings_row()
		_refresh_compare_row()
		_refresh_chord_detail_tabs_visibility()
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
	_refresh_inversions_row()
	_refresh_voicings_row()
	_refresh_compare_row()
	_refresh_chord_detail_tabs_visibility()


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
