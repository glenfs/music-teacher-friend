extends Control

signal lesson_completed(module_id: String)
signal back_to_map

const LMD = preload("res://scripts/learning/learning_module_data.gd")
const FONT_TITLE := preload("res://assets/fonts/Baloo2-SemiBold.ttf")
const FONT_BODY := preload("res://assets/fonts/Nunito-Regular.ttf")
const CHICKEN_TEXTURE := preload("res://assets/birds/chicken.svg")

const BG_COLOR := Color(0.06, 0.11, 0.19, 1.0)
const ACCENT_GOLD := Color(0.9098, 0.6275, 0.1255, 1.0)
const TEXT_PRIMARY := Color(0.92, 0.97, 1.0, 1.0)
const TEXT_MUTED := Color(0.82, 0.90, 0.97, 0.80)
const TEXT_DARK := Color(0.10, 0.10, 0.10, 1.0)
const BUBBLE_BG := Color(1.0, 1.0, 1.0, 0.96)
const CORRECT_COLOR := Color(0.30, 0.78, 0.40, 1.0)
const WRONG_COLOR := Color(0.90, 0.32, 0.30, 1.0)
const HIGHLIGHT_BG := Color(0.9098, 0.6275, 0.1255, 0.18)
const STAFF_LINE_SPACING := 18.0
const NOTE_G_COLOR := Color(0.95, 0.45, 0.20, 1.0)
const NOTE_F_COLOR := Color(0.30, 0.55, 0.90, 1.0)
const STAR_GOLD := Color(1.0, 0.85, 0.20, 1.0)
const STAR_EMPTY := Color(0.40, 0.42, 0.44, 0.50)
const METRONOME_ACCENT_STREAM := preload("res://assets/audio/sfx/ui-basic-click.wav")
const METRONOME_TICK_STREAM := preload("res://assets/audio/sfx/ui__snap-click-01.wav")
var CHICKEN_CLUCK_STREAM: AudioStream = null
var CLAP_STREAM: AudioStream = null
const NOTE_HEAD_PALETTE: Array[Color] = [
	Color(0.20, 0.45, 0.72, 0.95),  # teal-blue
	Color(0.72, 0.22, 0.44, 0.95),  # berry
	Color(0.18, 0.58, 0.45, 0.95),  # emerald
	Color(0.62, 0.35, 0.78, 0.95),  # violet
	Color(0.85, 0.48, 0.18, 0.95),  # amber
	Color(0.28, 0.56, 0.72, 0.95),  # steel blue
	Color(0.70, 0.28, 0.28, 0.95),  # brick red
]

const PIANO_DIR := "res://assets/audio/piano/piano"
const PIANO_BASE_MIDI := 21  # file 1.mp3 = MIDI 21 (A0)
const MELODY_AUTOPLAY_DELAY := 1.1
const RHYTHM_AUTOPLAY_DELAY := 1.1

const CHICKEN_CORRECT_LINES := [
	"That's right!", "Nice work!", "You got it!", "Excellent!",
	"Great job!", "Perfect!", "Well done!", "Awesome!",
]
const CHICKEN_WRONG_LINES := [
	"Not quite  --  try again!", "Almost! Give it another try.",
	"Hmm, not that one. Try again!", "Keep trying, you'll get it!",
	"Close, but not quite!", "Not quite  --  look carefully and try again!",
]

var _module_data: Dictionary = {}
var _progress: RefCounted
var _current_step: int = 0
var _quiz_answered: bool = false
var _quiz_correct: bool = false

var _title_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _chicken_bubble: PanelContainer
var _chicken_label: Label
var _content_area: MarginContainer
var _content_card: PanelContainer
var _content_vbox: VBoxContainer
var _prev_btn: Button
var _next_btn: Button
var _sfx_player: AudioStreamPlayer
var _metronome_player: AudioStreamPlayer
var _note_player: AudioStreamPlayer
var _note_player_2: AudioStreamPlayer
var _note_player_3: AudioStreamPlayer
var _replay_btn: Button
var _feedback_card: Control = null
var _note_stream_cache: Dictionary = {}
var _melody_playback_token: int = 0
var _rhythm_playback_token: int = 0

# Drag-note state
var _drag_note_completed: bool = false
var _drag_note_panel: Control = null
var _drag_note_head: Control = null
var _drag_is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_original_pos: Vector2 = Vector2.ZERO

# Quiz tracking for stars & anti-guessing
var _quiz_attempts_this_step: int = 0
var _step_render_time: float = 0.0
var _module_quiz_count: int = 0
var _module_first_try_correct: int = 0
var _module_start_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _chicken_anim_sprite: AnimatedSprite2D = null

# Cumulative quiz state
var _cumulative_pool: Array = []
var _cumulative_index: int = 0
var _cumulative_count: int = 0
var _cumulative_correct: int = 0


var _resume_pending: bool = false
var _resume_step: int = 0

# test-out mode
var _test_out_mode: bool = false
var _test_out_steps: Array = []
var _test_out_skill_totals: Dictionary = {}
var _test_out_skill_correct: Dictionary = {}
var _test_out_overall_answers: int = 0
var _test_out_overall_correct: int = 0
const TEST_OUT_REQUIRED_PERCENT := 90

# practice round state
var _practice_pool: Array = []
var _practice_index: int = 0
var _practice_correct: int = 0
var _practice_total: int = 0
var _practice_target: int = 10
var _practice_pool_type: String = "note"

# listening quiz state
var _listening_items: Array = []
var _listening_index: int = 0
var _listening_correct: int = 0

# rhythm tap state
var _rhythm_tap_completed: bool = false
var _rhythm_tap_pattern: Array = []
var _rhythm_tap_bpm: int = 100
var _rhythm_tap_started: bool = false
var _rhythm_tap_beat_start_ms: float = 0.0
var _rhythm_tap_targets_ms: Array = []  # absolute ms time each tap target starts
var _rhythm_tap_hits: int = 0
var _rhythm_tap_current_target: int = 0
var _rhythm_tap_tolerance_ms: float = 300.0

# note identify / listen-find state
var _note_identify_completed: bool = false

# quiz streak tracking
var _quiz_streak: int = 0

# current quiz notehead reference for visual flash
var _current_quiz_notehead: Panel = null

# MIDI input bridge — populated when a note quiz step is rendered, cleared on answer.
var _active_quiz_step: Dictionary = {}
var _active_quiz_choices: Array = []
var _active_quiz_correct_index: int = -1
var _active_quiz_btn_row: Control = null
var _active_quiz_buttons: Array[Button] = []
const MIDI_NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const MIDI_NOTE_NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Note intro multi-phase state
var _note_intro_phase: int = 0
var _note_intro_max_phase: int = 0
var _note_intro_data: Dictionary = {}
var _note_intro_first_note_done: bool = false
var _note_intro_phase3_variant: int = 0  # 0=spotlight, 1=peel-away

const STREAK_MESSAGES_3 := [
	"3 in a row! You're on fire!",
	"Three correct! Keep going!",
	"Hat trick! Nice streak!",
]
const STREAK_MESSAGES_5 := [
	"5 in a row! Incredible!",
	"Five straight! You're a star!",
	"Unstoppable! 5 in a row!",
]


func load_module(module_data: Dictionary, progress: RefCounted, force_restart: bool = false, test_out: bool = false) -> void:
	_module_data = module_data
	_progress = progress
	_current_step = 0
	_quiz_answered = false
	_drag_symbol_completed = false
	_module_quiz_count = 0
	_module_first_try_correct = 0
	_module_start_time = Time.get_ticks_msec() / 1000.0
	_quiz_streak = 0
	_current_quiz_notehead = null
	_note_intro_first_note_done = false
	_note_intro_phase = 0
	_feedback_card = null

	_melody_playback_token += 1
	_test_out_mode = test_out
	_test_out_steps = []
	_test_out_skill_totals = {}
	_test_out_skill_correct = {}
	_test_out_overall_answers = 0
	_test_out_overall_correct = 0
	_rng.randomize()
	if CHICKEN_CLUCK_STREAM == null and ResourceLoader.exists("res://assets/audio/sfx/chicken-cluck.wav"):
		CHICKEN_CLUCK_STREAM = load("res://assets/audio/sfx/chicken-cluck.wav")
	if CLAP_STREAM == null and ResourceLoader.exists("res://assets/audio/sfx/clap.wav"):
		CLAP_STREAM = load("res://assets/audio/sfx/clap.wav")
	_build_ui()

	if test_out:
		_start_test_out()
		return

	# Check for resume ---- only offer resume if module is NOT already completed
	# (completed modules should restart fresh; half-finished ones should offer continue)
	var module_id: String = module_data.get("id", "")
	var is_already_completed: bool = progress != null and progress.is_completed(module_id)
	var saved_step: int = 0
	if not force_restart and not is_already_completed and progress != null:
		saved_step = progress.get_last_step(module_id)
	var steps: Array = module_data.get("steps", [])
	if saved_step > 0 and saved_step < steps.size() and not force_restart:
		_resume_pending = true
		_resume_step = saved_step
		_show_resume_prompt()
	else:
		_render_step()


func _show_resume_prompt() -> void:
	_clear_content()
	_chicken_label.text = "Welcome back! You were partway through this lesson."
	_prev_btn.visible = false
	_next_btn.visible = false

	var title := Label.new()
	title.text = "Continue Lesson?"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	var steps: Array = _module_data.get("steps", [])
	var progress_text := "You completed %d of %d steps last time." % [_resume_step, steps.size()]
	var info := Label.new()
	info.text = progress_text
	info.add_theme_font_override("font", FONT_BODY)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", TEXT_MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(info)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	_content_vbox.add_child(btn_row)

	var continue_btn := _create_nav_button("Continue")
	continue_btn.pressed.connect(func():
		_resume_pending = false
		_current_step = _resume_step
		_quiz_answered = false
		_quiz_correct = false
		_render_step()
	)
	btn_row.add_child(continue_btn)

	var restart_btn := _create_nav_button("Start Over")
	var restart_sb: StyleBoxFlat = restart_btn.get_theme_stylebox("normal").duplicate()
	restart_sb.bg_color = Color(0.30, 0.32, 0.36, 0.70)
	restart_btn.add_theme_stylebox_override("normal", restart_sb)
	restart_btn.pressed.connect(func():
		_resume_pending = false
		_current_step = 0
		_quiz_answered = false
		_quiz_correct = false
		_render_step()
	)
	btn_row.add_child(restart_btn)


func _get_active_steps() -> Array:
	if _test_out_mode and not _test_out_steps.is_empty():
		return _test_out_steps
	return _module_data.get("steps", [])


func _start_test_out() -> void:
	var diagnostic_steps: Array = _build_test_out_steps(_module_data.get("steps", []))
	if diagnostic_steps.is_empty():
		_test_out_mode = false
		_render_step()
		return
	_test_out_steps = diagnostic_steps
	_current_step = 0
	_prev_btn.visible = false
	_next_btn.visible = false
	_render_step()


func _build_test_out_steps(module_steps: Array) -> Array:
	var family_buckets: Dictionary = {
		"note": [],
		"theory": [],
		"listening": [],
		"keyboard": [],
		"rhythm": [],
	}
	var seen_concepts: Dictionary = {}

	for step in module_steps:
		var stype: int = int(step.get("type", -1))
		match stype:
			LMD.STEP_NOTE_QUIZ:
				_add_test_out_candidate(family_buckets, seen_concepts, "note", _decorate_test_out_step(step.duplicate(true), "note"), _get_step_concept_id(step))
			LMD.STEP_QUIZ:
				var theory_step: Dictionary = _decorate_test_out_step(step.duplicate(true), "theory")
				if not theory_step.has("concept_id"):
					theory_step["concept_id"] = _get_step_concept_id(theory_step)
				_add_test_out_candidate(family_buckets, seen_concepts, "theory", theory_step, str(theory_step.get("concept_id", "")))
			LMD.STEP_KEYBOARD_QUIZ:
				var keyboard_step: Dictionary = _decorate_test_out_step(step.duplicate(true), "keyboard")
				keyboard_step["concept_id"] = _build_keyboard_concept_id(keyboard_step)
				_add_test_out_candidate(family_buckets, seen_concepts, "keyboard", keyboard_step, str(keyboard_step.get("concept_id", "")))
			LMD.STEP_RHYTHM_TAP:
				var rhythm_step: Dictionary = _decorate_test_out_step(step.duplicate(true), "rhythm")
				rhythm_step["concept_id"] = _build_rhythm_concept_id(rhythm_step)
				_add_test_out_candidate(family_buckets, seen_concepts, "rhythm", rhythm_step, str(rhythm_step.get("concept_id", "")))
			LMD.STEP_LISTENING_QUIZ:
				for item in step.get("items", []):
					if not (item is Dictionary):
						continue
					var item_copy: Dictionary = (item as Dictionary).duplicate(true)
					if str(item_copy.get("concept_id", "")).is_empty():
						item_copy["concept_id"] = _build_listening_concept_id(item_copy)
					var listening_step: Dictionary = LMD.create_listening_quiz_step(
						"Listening Check",
						"Listen carefully and answer on the first try.",
						[item_copy]
					)
					listening_step = _decorate_test_out_step(listening_step, "listening")
					listening_step["concept_id"] = item_copy["concept_id"]
					_add_test_out_candidate(family_buckets, seen_concepts, "listening", listening_step, str(item_copy.get("concept_id", "")))
			LMD.STEP_CUMULATIVE_QUIZ:
				for pool_item in step.get("pool", []):
					if pool_item is Dictionary:
						var note_step: Dictionary = _build_note_quiz_step_from_item(pool_item as Dictionary, "Note Check")
						_add_test_out_candidate(family_buckets, seen_concepts, "note", note_step, str(note_step.get("concept_id", "")))
			LMD.STEP_PRACTICE_ROUND:
				var pool_type: String = str(step.get("pool_type", "note"))
				for pool_item in step.get("pool", []):
					if not (pool_item is Dictionary):
						continue
					if pool_type == "theory":
						var theory_item: Dictionary = pool_item as Dictionary
						var quiz_step: Dictionary = LMD.create_quiz_step(
							str(theory_item.get("question", "")),
							theory_item.get("choices", []),
							int(theory_item.get("correct_index", 0)),
							"Correct.",
							"Not this time."
						)
						quiz_step = _decorate_test_out_step(quiz_step, "theory")
						quiz_step["concept_id"] = theory_item.get("concept_id", _get_step_concept_id(quiz_step))
						_add_test_out_candidate(family_buckets, seen_concepts, "theory", quiz_step, str(quiz_step.get("concept_id", "")))
					else:
						var review_note_step: Dictionary = _build_note_quiz_step_from_item(pool_item as Dictionary, "Note Check")
						_add_test_out_candidate(family_buckets, seen_concepts, "note", review_note_step, str(review_note_step.get("concept_id", "")))

	var selected_steps: Array = []
	var selected_counts: Dictionary = {}
	var family_order: Array[String] = ["note", "theory", "listening", "keyboard", "rhythm"]
	for family in family_order:
		var bucket: Array = family_buckets.get(family, [])
		bucket.shuffle()
		family_buckets[family] = bucket
		if not bucket.is_empty():
			selected_steps.append(bucket[0])
			bucket.remove_at(0)
			selected_counts[family] = 1

	var configured_max_questions: int = int(_module_data.get("test_out_max_questions", 0))
	var max_questions: int = configured_max_questions if configured_max_questions > 0 else mini(10, maxi(selected_steps.size() * 2, 6))
	while selected_steps.size() < max_questions:
		var next_family := ""
		var next_count := 1 << 20
		for family in family_order:
			var remaining: Array = family_buckets.get(family, [])
			if remaining.is_empty():
				continue
			var cur_count: int = int(selected_counts.get(family, 0))
			if cur_count < next_count:
				next_family = family
				next_count = cur_count
		if next_family == "":
			break
		var next_bucket: Array = family_buckets.get(next_family, [])
		selected_steps.append(next_bucket[0])
		next_bucket.remove_at(0)
		selected_counts[next_family] = int(selected_counts.get(next_family, 0)) + 1

	if selected_steps.is_empty():
		return []

	var is_placement_mode: bool = bool(_module_data.get("placement_mode", false))
	var intro_step: Dictionary = LMD.create_intro_step(
		"Placement Check" if is_placement_mode else "Test Out",
		"Answer on your first try. This check samples note reading, theory, listening, keyboard, and rhythm." if is_placement_mode else "Answer on your first try. You need %d%% overall and at least half correct in each skill area to skip this lesson." % TEST_OUT_REQUIRED_PERCENT,
		"Quick diagnostic: %d checks" % selected_steps.size()
	)
	intro_step["test_out_family"] = "intro"
	selected_steps.push_front(intro_step)
	return selected_steps


func _decorate_test_out_step(step: Dictionary, family: String) -> Dictionary:
	step["test_out_family"] = family
	step["test_out_mode"] = true
	return step


func _add_test_out_candidate(family_buckets: Dictionary, seen_concepts: Dictionary, family: String, step: Dictionary, concept_id: String) -> void:
	var dedupe_key: String = concept_id if not concept_id.is_empty() else "%s:%s" % [family, JSON.stringify(step, "")]
	if seen_concepts.has(dedupe_key):
		return
	seen_concepts[dedupe_key] = true
	var bucket: Array = family_buckets.get(family, [])
	bucket.append(step)
	family_buckets[family] = bucket


func _build_note_quiz_step_from_item(item: Dictionary, title: String = "Note Check") -> Dictionary:
	var correct_letter: String = str(item.get("note_name", "C"))
	var choice_data: Dictionary = _build_note_letter_choice_data(correct_letter)
	var quiz_step: Dictionary = LMD.create_note_quiz_step(
		str(item.get("clef", "treble")),
		correct_letter,
		int(item.get("note_step", 4)),
		choice_data.get("choices", []),
		int(choice_data.get("correct_index", 0)),
		"Correct.",
		"Not quite."
	)
	quiz_step["title"] = title
	quiz_step["chicken_text"] = "Name this note on your first try."
	quiz_step["concept_id"] = "%s:%s" % [str(item.get("clef", "treble")), str(item.get("note_id", ""))]
	return _decorate_test_out_step(quiz_step, "note")


func _build_note_letter_choice_data(correct_letter: String) -> Dictionary:
	var all_letters := ["C", "D", "E", "F", "G", "A", "B"]
	var ci: int = all_letters.find(correct_letter)
	var adjacent: Array[String] = []
	var non_adjacent: Array[String] = []
	for offset in [-1, 1]:
		var didx: int = (ci + offset + 7) % 7
		var d: String = all_letters[didx]
		if d != correct_letter and not adjacent.has(d):
			adjacent.append(d)
	for offset in [-3, 3, -4, 4]:
		var didx2: int = (ci + offset + 7) % 7
		var d2: String = all_letters[didx2]
		if d2 != correct_letter and not adjacent.has(d2) and not non_adjacent.has(d2):
			non_adjacent.append(d2)
		if non_adjacent.size() >= 2:
			break
	adjacent.shuffle()
	non_adjacent.shuffle()
	var distractors: Array[String] = []
	if not adjacent.is_empty():
		distractors.append(adjacent[0])
	for d in non_adjacent:
		distractors.append(d)
		if distractors.size() >= 3:
			break
	if distractors.size() < 3 and adjacent.size() > 1:
		distractors.append(adjacent[1])
	var choices: Array[String] = [correct_letter]
	for d in distractors:
		choices.append(d)
	choices.shuffle()
	return {"choices": choices, "correct_index": choices.find(correct_letter)}


func _build_listening_concept_id(item: Dictionary) -> String:
	var joined_ids := ""
	for note_id in item.get("note_ids", []):
		if joined_ids != "":
			joined_ids += "_"
		joined_ids += str(note_id)
	return "listening:%s:%s" % [str(item.get("label", "item")), joined_ids]


func _build_keyboard_concept_id(step: Dictionary) -> String:
	return "keyboard:%s" % str(step.get("target_note_id", ""))


func _get_rhythm_pattern_token(pattern_item: Variant) -> String:
	if pattern_item is Dictionary:
		var item: Dictionary = pattern_item
		var beats: float = float(item.get("beats", _get_rhythm_item_duration(item)))
		if bool(item.get("rest", false)):
			return "rest_%s" % String.num(beats, 2)
		var kind: String = str(item.get("kind", ""))
		if kind == "":
			kind = _get_rhythm_kind_for_beats(beats)
		return "%s_%s" % [kind, String.num(beats, 2)]
	return String.num(float(pattern_item), 2)


func _build_rhythm_concept_id(step: Dictionary) -> String:
	var pattern_text := ""
	for beat in step.get("pattern", []):
		if pattern_text != "":
			pattern_text += "-"
		pattern_text += _get_rhythm_pattern_token(beat)
	return "rhythm:%s:%s" % [str(step.get("title", "pattern")), pattern_text]


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 50

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	_metronome_player = AudioStreamPlayer.new()
	_metronome_player.bus = "Master"
	_metronome_player.volume_db = -6.0
	add_child(_metronome_player)

	_note_player = AudioStreamPlayer.new()
	_note_player.bus = "Master"
	_note_player.volume_db = -3.0
	add_child(_note_player)

	_note_player_2 = AudioStreamPlayer.new()
	_note_player_2.bus = "Master"
	_note_player_2.volume_db = -3.0
	add_child(_note_player_2)

	_note_player_3 = AudioStreamPlayer.new()
	_note_player_3.bus = "Master"
	_note_player_3.volume_db = -3.0
	add_child(_note_player_3)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)

	# Top bar
	add_child(_build_top_bar())

	# Content area ---- lesson card
	_content_area = MarginContainer.new()
	_content_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_area.anchor_top = 0.12
	_content_area.anchor_bottom = 0.83
	_content_area.add_theme_constant_override("margin_left", 28)
	_content_area.add_theme_constant_override("margin_right", 28)
	_content_area.add_theme_constant_override("margin_top", 4)
	_content_area.add_theme_constant_override("margin_bottom", 4)
	add_child(_content_area)

	# Styled card panel
	_content_card = PanelContainer.new()
	_content_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.09, 0.13, 0.20, 0.92)
	card_sb.corner_radius_top_left = 16
	card_sb.corner_radius_top_right = 16
	card_sb.corner_radius_bottom_left = 16
	card_sb.corner_radius_bottom_right = 16
	card_sb.border_color = Color(0.28, 0.34, 0.42, 0.35)
	card_sb.border_width_left = 1
	card_sb.border_width_top = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 1
	card_sb.content_margin_left = 24
	card_sb.content_margin_right = 24
	card_sb.content_margin_top = 18
	card_sb.content_margin_bottom = 18
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	card_sb.shadow_size = 10
	_content_card.add_theme_stylebox_override("panel", card_sb)
	_content_area.add_child(_content_card)

	# Inner layout: scrollable content + chicken row at bottom
	var inner_vbox := VBoxContainer.new()
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 6)
	_content_card.add_child(inner_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 16)
	_content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(_content_vbox)

	# Nav row
	_build_nav_row()

	# Chicken ---- center-left, overlaid on the card
	var chicken_row := _build_chicken_row()
	var chicken_anchor := Control.new()
	chicken_anchor.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	chicken_anchor.anchor_left = 0.0
	chicken_anchor.anchor_right = 0.55
	chicken_anchor.anchor_top = 0.45
	chicken_anchor.anchor_bottom = 0.45
	chicken_anchor.offset_left = 8
	chicken_anchor.offset_top = -30
	chicken_anchor.offset_bottom = 30
	chicken_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chicken_anchor.z_index = 50
	chicken_anchor.add_child(chicken_row)
	_content_card.add_child(chicken_anchor)


func _build_top_bar() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_bottom = 64
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "X"
	back_btn.add_theme_font_override("font", FONT_TITLE)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.add_theme_color_override("font_color", TEXT_MUTED)
	back_btn.add_theme_color_override("font_hover_color", WRONG_COLOR)
	_style_flat_button(back_btn)
	back_btn.pressed.connect(func():
		_play_sfx("res://assets/audio/sfx/ui-basic-click.wav")
		back_to_map.emit()
	)
	hbox.add_child(back_btn)

	_title_label = Label.new()
	_title_label.text = _module_data.get("title", "Lesson")
	_title_label.add_theme_font_override("font", FONT_TITLE)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_override("font", FONT_BODY)
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", TEXT_MUTED)
	hbox.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 4)
	_progress_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.20, 0.24, 0.30, 0.60)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT_GOLD
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_progress_bar)

	return margin


func _build_chicken_row() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Chicken sprite using spritesheet
	_chicken_anim_sprite = _build_chicken_animated_sprite()
	var chicken_container := Control.new()
	chicken_container.custom_minimum_size = Vector2(48, 48)
	chicken_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _chicken_anim_sprite != null:
		_chicken_anim_sprite.position = Vector2(24, 24)
		_chicken_anim_sprite.scale = Vector2(0.055, 0.055)
		chicken_container.add_child(_chicken_anim_sprite)
	else:
		var chicken := TextureRect.new()
		chicken.texture = CHICKEN_TEXTURE
		chicken.custom_minimum_size = Vector2(42, 42)
		chicken.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		chicken.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chicken.modulate = Color(1.0, 0.92, 0.74, 1.0)
		chicken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chicken_container.add_child(chicken)
	hbox.add_child(chicken_container)

	_chicken_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BUBBLE_BG
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = Color(0.78, 0.84, 0.88, 0.35)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.08)
	sb.shadow_size = 3
	_chicken_bubble.add_theme_stylebox_override("panel", sb)
	_chicken_bubble.custom_minimum_size = Vector2(340, 0)
	_chicken_bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_chicken_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chicken_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_chicken_bubble)

	_chicken_label = Label.new()
	_chicken_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chicken_label.custom_minimum_size = Vector2(310, 0)
	_chicken_label.add_theme_font_override("font", FONT_BODY)
	_chicken_label.add_theme_font_size_override("font_size", 17)
	_chicken_label.add_theme_color_override("font_color", TEXT_DARK)
	_chicken_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chicken_bubble.add_child(_chicken_label)

	return hbox


func _build_nav_row() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 0.85
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 20)
	margin.add_child(nav)

	_prev_btn = _create_nav_button("Previous")
	_prev_btn.pressed.connect(_on_prev_pressed)
	nav.add_child(_prev_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.add_theme_font_override("font", FONT_BODY)
	restart_btn.add_theme_font_size_override("font_size", 14)
	restart_btn.add_theme_color_override("font_color", TEXT_MUTED)
	restart_btn.add_theme_color_override("font_hover_color", ACCENT_GOLD)
	_style_flat_button(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)
	nav.add_child(restart_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)

	_next_btn = _create_nav_button("Next")
	_next_btn.pressed.connect(_on_next_pressed)
	nav.add_child(_next_btn)


func _create_nav_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", FONT_TITLE)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(140, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT_GOLD
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.96, 0.72, 0.22, 1.0)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = Color(0.78, 0.52, 0.10, 1.0)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	var sb_disabled := sb.duplicate()
	sb_disabled.bg_color = Color(0.30, 0.32, 0.34, 0.50)
	btn.add_theme_stylebox_override("disabled", sb_disabled)
	btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.52, 0.54, 0.50))
	return btn


# ---- Step rendering ----

func _get_pace() -> String:
	if _progress != null:
		return _progress.get_pace_setting()
	return "normal"


func _render_step() -> void:
	var steps: Array = _get_active_steps()
	if _current_step < 0 or _current_step >= steps.size():
		return
	var step: Dictionary = steps[_current_step]
	var step_type: int = step.get("type", LMD.STEP_INTRO)

	# Quick pace: auto-skip recap and intro steps
	var pace: String = _get_pace()
	if pace == "quick":
		if step_type == LMD.STEP_RECAP or step_type == LMD.STEP_INTRO:
			if _current_step < steps.size() - 1:
				_current_step += 1
				_render_step()
				return

	_step_render_time = Time.get_ticks_msec() / 1000.0
	_update_progress_ui()
	_save_step_progress()
	_clear_content()
	_play_sfx("res://assets/audio/sfx/ui-basic-click.wav")

	var chicken_text: String = step.get("chicken_text", "")
	_chicken_label.text = chicken_text
	if chicken_text.strip_edges() == "":
		_chicken_bubble.visible = false
	else:
		_chicken_bubble.visible = true
		_animate_bubble_in()

	match step_type:
		LMD.STEP_INTRO:
			_render_intro_step(step)
		LMD.STEP_EXPLANATION:
			_render_explanation_step(step)
		LMD.STEP_VISUAL:
			_render_visual_step(step)
		LMD.STEP_RECAP:
			_render_recap_step(step)
		LMD.STEP_QUIZ:
			_render_quiz_step(step)
		LMD.STEP_DRAG_NOTE:
			_render_drag_note_step(step)
		LMD.STEP_DRAG_SYMBOL:
			_render_drag_symbol_step(step)
		LMD.STEP_NOTE_QUIZ:
			_render_note_quiz_step(step)
		LMD.STEP_CUMULATIVE_QUIZ:
			_render_cumulative_quiz_step(step)
		LMD.STEP_PRACTICE_ROUND:
			_render_practice_round_step(step)
		LMD.STEP_LISTENING_QUIZ:
			_render_listening_quiz_step(step)
		LMD.STEP_MELODY_EXAMPLE:
			_render_melody_example_step(step)
		LMD.STEP_RHYTHM_TAP:
			_render_rhythm_tap_step(step)
		LMD.STEP_NOTE_IDENTIFY:
			_render_note_identify_step(step)
		LMD.STEP_LISTEN_FIND:
			_render_listen_find_step(step)
		LMD.STEP_KEYBOARD_QUIZ:
			_render_keyboard_quiz_step(step)

	_update_nav_buttons()
	_animate_content_in()


func _render_intro_step(step: Dictionary) -> void:
	var title := Label.new()
	title.text = step.get("title", "")
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	var subtitle: String = step.get("subtitle", "")
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_override("font", FONT_BODY)
		sub.add_theme_font_size_override("font_size", 18)
		sub.add_theme_color_override("font_color", TEXT_MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(sub)


func _render_explanation_step(step: Dictionary) -> void:
	var title := Label.new()
	title.text = step.get("title", "")
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	var highlight: String = step.get("highlight_text", "")
	if highlight != "":
		var hl_panel := PanelContainer.new()
		var hl_sb := StyleBoxFlat.new()
		hl_sb.bg_color = HIGHLIGHT_BG
		hl_sb.corner_radius_top_left = 12
		hl_sb.corner_radius_top_right = 12
		hl_sb.corner_radius_bottom_left = 12
		hl_sb.corner_radius_bottom_right = 12
		hl_sb.content_margin_left = 20
		hl_sb.content_margin_right = 20
		hl_sb.content_margin_top = 14
		hl_sb.content_margin_bottom = 14
		hl_sb.border_color = ACCENT_GOLD
		hl_sb.border_width_left = 2
		hl_sb.border_width_top = 2
		hl_sb.border_width_right = 2
		hl_sb.border_width_bottom = 2
		hl_panel.add_theme_stylebox_override("panel", hl_sb)
		hl_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content_vbox.add_child(hl_panel)

		var hl_label := Label.new()
		hl_label.text = highlight
		hl_label.add_theme_font_override("font", FONT_TITLE)
		hl_label.add_theme_font_size_override("font_size", 24)
		hl_label.add_theme_color_override("font_color", ACCENT_GOLD)
		hl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl_panel.add_child(hl_label)

	var detail: String = step.get("detail_text", "")
	if detail != "":
		var det := Label.new()
		det.text = detail
		det.add_theme_font_override("font", FONT_BODY)
		det.add_theme_font_size_override("font_size", 17)
		det.add_theme_color_override("font_color", TEXT_MUTED)
		det.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(det)


func _render_visual_step(step: Dictionary) -> void:
	var title := Label.new()
	title.text = step.get("title", "")
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	var visual_type: String = step.get("visual_type", "")
	var visual_data: Dictionary = step.get("visual_data", {})
	_draw_visual_content(visual_type, visual_data)


func _draw_visual_content(visual_type: String, visual_data: Dictionary) -> void:
	match visual_type:
		"clef_symbol":
			_draw_clef_symbol(visual_data.get("clef", "treble"))
		"clef_on_staff":
			_draw_clef_on_staff(visual_data.get("clef", "treble"))
		"symbol_large":
			_draw_symbol_large(visual_data)
		"time_signature":
			_draw_time_signature(visual_data)
		"staff_lines_intro":
			_draw_staff_lines_intro(visual_data)
		"staff_spaces_intro":
			_draw_staff_spaces_intro(visual_data)
		"notes_on_lines":
			_draw_notes_on_lines(visual_data)
		"notes_in_spaces":
			_draw_notes_in_spaces(visual_data)
		"note_on_staff":
			_draw_note_on_staff(visual_data)
		"bar_lines":
			_draw_bar_lines(visual_data)
		"rhythm_value":
			_draw_rhythm_value(visual_data)
		"rhythm_staff_example":
			_draw_rhythm_staff_example(visual_data)
		"rhythm_equivalence":
			_draw_rhythm_equivalence_visual(visual_data)
		"key_signature_visual":
			_draw_key_signature_visual(visual_data)
		"grand_staff_visual":
			_draw_grand_staff_visual(visual_data)
		"interval_on_staff":
			_draw_interval_on_staff(visual_data)
		"note_audio_compare":
			_draw_note_audio_compare(visual_data)
		"keyboard_half_step":
			_draw_keyboard_half_step(visual_data)
		"keyboard_enharmonic":
			_draw_keyboard_enharmonic(visual_data)
		"keyboard_natural_reset":
			_draw_keyboard_natural_reset(visual_data)


func _build_inline_choice_visual(visual_type: String, visual_data: Dictionary) -> Control:
	match visual_type:
		"rhythm_staff_example":
			return _build_rhythm_staff_example(visual_data)
		_:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 0)
			return spacer


func _collect_choice_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in root.get_children():
		if child is Button:
			buttons.append(child)
		elif child is Node:
			buttons.append_array(_collect_choice_buttons(child))
	return buttons


func _build_choice_card(choice_text: String, visual_type: String, visual_data: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 8)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if visual_type != "":
		var visual := _build_inline_choice_visual(visual_type, visual_data)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(visual)

	var btn := _create_quiz_choice_button(choice_text)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 220.0), btn.custom_minimum_size.y)
	card.add_child(btn)
	return card


func _render_recap_step(step: Dictionary) -> void:
	var title := Label.new()
	title.text = step.get("title", "")
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	for item in step.get("items", []):
		_content_vbox.add_child(_build_recap_card(item))


func _render_quiz_step(step: Dictionary) -> void:
	_quiz_answered = false
	_quiz_correct = false
	_quiz_attempts_this_step = 0

	var question := Label.new()
	question.text = step.get("question", "")
	question.add_theme_font_override("font", FONT_TITLE)
	question.add_theme_font_size_override("font_size", 24)
	question.add_theme_color_override("font_color", TEXT_PRIMARY)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(question)

	var reference_visual_type: String = str(step.get("reference_visual_type", ""))
	if reference_visual_type != "":
		_draw_visual_content(reference_visual_type, step.get("reference_visual_data", {}))

	# Guided pace: show hint text if available
	if _get_pace() == "guided":
		var hint_text: String = step.get("chicken_correct", "")
		if hint_text != "":
			var hint_lbl := Label.new()
			hint_lbl.text = " --  Hint: Think about what you just learned..."
			hint_lbl.add_theme_font_override("font", FONT_BODY)
			hint_lbl.add_theme_font_size_override("font_size", 14)
			hint_lbl.add_theme_color_override("font_color", Color(0.50, 0.75, 0.60, 0.80))
			hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_content_vbox.add_child(hint_lbl)

	var choices: Array = step.get("choices", [])
	var correct_index: int = step.get("correct_index", 0)
	var choice_visuals: Array = step.get("choice_visuals", [])
	var choice_visual_type: String = str(step.get("choice_visual_type", ""))
	var btn_row: Control
	if choice_visual_type != "" and choice_visuals.size() == choices.size():
		var grid := GridContainer.new()
		grid.columns = mini(choices.size(), 2)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 14)
		btn_row = grid
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		btn_row = row
	_content_vbox.add_child(btn_row)

	for i in choices.size():
		var choice_text := str(choices[i])
		var btn: Button
		if choice_visual_type != "" and i < choice_visuals.size():
			var choice_card := _build_choice_card(choice_text, choice_visual_type, choice_visuals[i])
			btn = _collect_choice_buttons(choice_card)[0]
			btn_row.add_child(choice_card)
		else:
			btn = _create_quiz_choice_button(choice_text)
			btn.custom_minimum_size = Vector2(200, 60)
			btn_row.add_child(btn)
		btn.pressed.connect(_on_quiz_answer.bind(i, correct_index, btn, btn_row, step))


func _on_quiz_answer(selected: int, correct: int, _btn: Button, btn_row: Control, step: Dictionary) -> void:
	if _quiz_answered:
		return
	_quiz_answered = true
	_quiz_correct = selected == correct
	_quiz_attempts_this_step += 1
	if selected == correct:
		_active_quiz_choices = []
		_active_quiz_buttons.clear()
		_active_quiz_correct_index = -1
	var is_first_try: bool = _quiz_attempts_this_step == 1
	var concept_id: String = _get_step_concept_id(step)

	# Disable all buttons and show color feedback
	var buttons := _collect_choice_buttons(btn_row)
	for i in buttons.size():
		var child := buttons[i]
		child.disabled = true
		var sb: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate()
		if i == correct:
			sb.bg_color = Color(0.16, 0.52, 0.28, 0.90)
			sb.border_color = CORRECT_COLOR
			child.add_theme_color_override("font_color", CORRECT_COLOR)
		elif i == selected and not _quiz_correct:
			sb.bg_color = Color(0.50, 0.16, 0.14, 0.90)
			sb.border_color = WRONG_COLOR
			child.add_theme_color_override("font_color", WRONG_COLOR)
		child.add_theme_stylebox_override("normal", sb)
		child.add_theme_stylebox_override("disabled", sb)

	if _quiz_correct:
		_module_quiz_count += 1
		if is_first_try:
			_module_first_try_correct += 1
		# Streak tracking
		_quiz_streak += 1
		var streak_msg: String = ""
		if _quiz_streak == 3:
			streak_msg = STREAK_MESSAGES_3[randi() % STREAK_MESSAGES_3.size()]
		elif _quiz_streak == 5:
			streak_msg = STREAK_MESSAGES_5[randi() % STREAK_MESSAGES_5.size()]
		var custom_correct: String = step.get("chicken_correct", "")
		if streak_msg != "":
			_chicken_label.text = streak_msg
		else:
			_chicken_label.text = custom_correct if custom_correct != "" else _random_correct_line()
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		_play_chicken_reaction("idle")  # happy bounce
		_record_learning_result(step, true, is_first_try)

		# Play note audio on correct answer for note quizzes
		var note_id: String = _extract_note_id_from_step(step)
		if note_id != "":
			_play_note_audio(note_id)
		# Visual flash on correct: scale notehead up and flash gold
		if _current_quiz_notehead != null and is_instance_valid(_current_quiz_notehead):
			var flash_head := _current_quiz_notehead
			flash_head.pivot_offset = flash_head.size / 2.0
			var flash_tw := flash_head.create_tween()
			flash_tw.tween_property(flash_head, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			flash_tw.parallel().tween_callback(func(): _apply_notehead_material(flash_head, ACCENT_GOLD, ACCENT_GOLD.darkened(0.3)))
			flash_tw.tween_property(flash_head, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_quiz_streak = 0
		_module_quiz_count += 1
		var custom_wrong: String = step.get("chicken_wrong", "")
		_chicken_label.text = custom_wrong if custom_wrong != "" else _random_wrong_line()
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
		_shake_chicken()
		_record_learning_result(step, false, false)
		_show_wrong_answer_card(step)
		if _test_out_mode:
			_update_nav_buttons()
			return
		# Allow retry with increasing delay (anti-guessing)
		_quiz_answered = false
		var delay: float = minf(1.2 + (_quiz_attempts_this_step - 1) * 0.5, 3.0)
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self):
			return
		# After 3 wrong attempts, briefly highlight correct answer
		if _quiz_attempts_this_step >= 3:
			for i in btn_row.get_child_count():
				var child := btn_row.get_child(i)
				if child is Button and i == correct:
					var hint_sb: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate() if child.has_theme_stylebox_override("normal") else StyleBoxFlat.new()
					hint_sb.border_color = Color(0.30, 0.78, 0.40, 0.60)
					hint_sb.border_width_left = 3
					hint_sb.border_width_top = 3
					hint_sb.border_width_right = 3
					hint_sb.border_width_bottom = 3
					child.add_theme_stylebox_override("normal", hint_sb)
		for i in btn_row.get_child_count():
			var child := btn_row.get_child(i)
			if child is Button and i != selected:
				child.disabled = false

	_update_nav_buttons()


# ---- Visual helpers ----

func _draw_clef_symbol(clef: String) -> void:
	var container := CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 180)
	_content_vbox.add_child(container)

	var symbol_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.26, 0.70)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.border_color = ACCENT_GOLD.lerp(Color.WHITE, 0.3)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	symbol_panel.add_theme_stylebox_override("panel", sb)
	container.add_child(symbol_panel)

	var is_treble := clef == "treble"
	var lbl := Label.new()
	lbl.text = String.chr(0x1D11E) if is_treble else String.chr(0x1D122)
	lbl.add_theme_font_size_override("font_size", 120)
	lbl.add_theme_color_override("font_color", ACCENT_GOLD if is_treble else Color(0.45, 0.70, 1.0, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_panel.add_child(lbl)

	var name_label := Label.new()
	name_label.text = "Treble Clef" if is_treble else "Bass Clef"
	name_label.add_theme_font_override("font", FONT_TITLE)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(name_label)


func _draw_clef_on_staff(clef: String) -> void:
	var staff_container := Control.new()
	staff_container.custom_minimum_size = Vector2(400, 160)
	staff_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(staff_container)

	# Light background
	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.96, 0.94, 0.90, 0.95)
	bg_sb.corner_radius_top_left = 14
	bg_sb.corner_radius_top_right = 14
	bg_sb.corner_radius_bottom_left = 14
	bg_sb.corner_radius_bottom_right = 14
	bg_panel.add_theme_stylebox_override("panel", bg_sb)
	staff_container.add_child(bg_panel)

	# 5 staff lines
	var staff_top := 40.0
	for i in 5:
		var line := ColorRect.new()
		line.color = Color(0.30, 0.32, 0.36, 0.70)
		line.position = Vector2(30, staff_top + i * STAFF_LINE_SPACING)
		line.size = Vector2(340, 1.5)
		staff_container.add_child(line)

	# Clef symbol on staff ---- positioned to wrap around correct line
	var is_treble := clef == "treble"
	var clef_label := Label.new()
	clef_label.text = String.chr(0x1D11E) if is_treble else String.chr(0x1D122)
	clef_label.add_theme_font_size_override("font_size", 52)
	clef_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.90))
	if is_treble:
		var g_line_y := staff_top + 3 * STAFF_LINE_SPACING
		clef_label.position = Vector2(36, g_line_y - 34 - STAFF_LINE_SPACING)
	else:
		var f_line_y := staff_top + 1 * STAFF_LINE_SPACING
		clef_label.position = Vector2(36, f_line_y - 20 - STAFF_LINE_SPACING)
	staff_container.add_child(clef_label)

	# Highlight the special line with blinking animation
	if is_treble:
		# G = 2nd line from bottom = index 3 from top
		var g_y := staff_top + 3 * STAFF_LINE_SPACING
		var g_hl := ColorRect.new()
		g_hl.color = NOTE_G_COLOR
		g_hl.position = Vector2(30, g_y - 0.5)
		g_hl.size = Vector2(340, 3.0)
		staff_container.add_child(g_hl)
		_blink_highlight(g_hl, NOTE_G_COLOR)
		var g_lbl := Label.new()
		g_lbl.text = "G line"
		g_lbl.add_theme_font_override("font", FONT_TITLE)
		g_lbl.add_theme_font_size_override("font_size", 16)
		g_lbl.add_theme_color_override("font_color", NOTE_G_COLOR)
		g_lbl.position = Vector2(268, g_y - 12)
		staff_container.add_child(g_lbl)
	else:
		# F = 4th line from bottom = index 1 from top
		var f_y := staff_top + 1 * STAFF_LINE_SPACING
		var f_hl := ColorRect.new()
		f_hl.color = NOTE_F_COLOR
		f_hl.position = Vector2(30, f_y - 0.5)
		f_hl.size = Vector2(340, 3.0)
		staff_container.add_child(f_hl)
		_blink_highlight(f_hl, NOTE_F_COLOR)
		var f_lbl := Label.new()
		f_lbl.text = "F line"
		f_lbl.add_theme_font_override("font", FONT_TITLE)
		f_lbl.add_theme_font_size_override("font_size", 16)
		f_lbl.add_theme_color_override("font_color", NOTE_F_COLOR)
		f_lbl.position = Vector2(268, f_y - 12)
		staff_container.add_child(f_lbl)
		# Dot indicators for F
		for dot_offset in [-0.5, 0.5]:
			var dot := ColorRect.new()
			dot.color = Color(0.20, 0.20, 0.20, 0.85)
			dot.position = Vector2(78, staff_top + (1 + dot_offset) * STAFF_LINE_SPACING - 3)
			dot.size = Vector2(6, 6)
			staff_container.add_child(dot)


func _build_recap_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.26, 0.75)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.border_color = ACCENT_GOLD.lerp(Color.WHITE, 0.2)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var clef_str: String = item.get("clef", "")
	var note_step_val: Variant = item.get("note_step", null)

	# If we have clef + note_step, render a mini staff with the note on it
	if clef_str != "" and note_step_val != null:
		var mini_staff := _build_recap_mini_staff(clef_str, int(note_step_val))
		hbox.add_child(mini_staff)
	elif clef_str != "":
		var is_treble := clef_str == "treble"
		var clef_lbl := Label.new()
		clef_lbl.text = String.chr(0x1D11E) if is_treble else String.chr(0x1D122)
		clef_lbl.add_theme_font_size_override("font_size", 48)
		clef_lbl.add_theme_color_override("font_color", ACCENT_GOLD if is_treble else Color(0.45, 0.70, 1.0, 1.0))
		hbox.add_child(clef_lbl)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	hbox.add_child(text_col)

	var label := Label.new()
	label.text = item.get("label", "")
	label.add_theme_font_override("font", FONT_TITLE)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	text_col.add_child(label)

	var detail := Label.new()
	detail.text = item.get("detail", "")
	detail.add_theme_font_override("font", FONT_BODY)
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", TEXT_MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(detail)

	return card


func _build_recap_mini_staff(clef: String, note_step: int) -> Control:
	var is_treble := clef == "treble"
	var sc := STAFF_LINE_SPACING / 14.0
	var w := 90.0 * sc
	var h := 72.0 * sc
	var gap := 10.0 * sc
	var staff_top := 14.0 * sc
	var line_x := 4.0 * sc
	var line_w := w - 8.0 * sc

	# Expand height for ledger notes
	if note_step >= 10:
		var extra := (note_step - 8) * (gap / 2.0)
		h += extra
	elif note_step <= -2:
		var extra := (-2 - note_step + 2) * (gap / 2.0)
		h += extra
		staff_top += extra

	var container := Control.new()
	container.custom_minimum_size = Vector2(w, h)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.92, 0.90, 0.86, 0.95)
	bg_sb.corner_radius_top_left = 8
	bg_sb.corner_radius_top_right = 8
	bg_sb.corner_radius_bottom_left = 8
	bg_sb.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", bg_sb)
	container.add_child(bg)

	# Staff lines
	for i in 5:
		var line := ColorRect.new()
		line.color = Color(0.30, 0.32, 0.36, 0.60)
		line.position = Vector2(line_x, staff_top + i * gap)
		line.size = Vector2(line_w, 1.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(line)

	# Clef symbol (small)
	var clef_lbl := Label.new()
	clef_lbl.text = String.chr(0x1D11E) if is_treble else String.chr(0x1D122)
	clef_lbl.add_theme_font_size_override("font_size", int(28 * sc))
	clef_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.70))
	clef_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_treble:
		var g_line_y := staff_top + 3 * gap
		clef_lbl.position = Vector2(line_x + 1, g_line_y - 22 * sc - gap * 0.4)
	else:
		var f_line_y := staff_top + 1 * gap
		clef_lbl.position = Vector2(line_x + 1, f_line_y - 14 * sc - gap * 0.4)
	container.add_child(clef_lbl)

	# Note position
	var note_x := line_x + line_w * 0.62
	var note_y := staff_top + note_step * (gap / 2.0)

	# Ledger lines
	if note_step >= 10:
		var s := 10
		while s <= note_step:
			var ly := staff_top + s * (gap / 2.0)
			var ledger := ColorRect.new()
			ledger.color = Color(0.30, 0.32, 0.36, 0.60)
			ledger.size = Vector2(22 * sc, 1.0)
			ledger.position = Vector2(note_x - 7 * sc, ly)
			ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(ledger)
			s += 2
	elif note_step <= -2:
		var s := -2
		while s >= note_step:
			var ly := staff_top + s * (gap / 2.0)
			var ledger := ColorRect.new()
			ledger.color = Color(0.30, 0.32, 0.36, 0.60)
			ledger.size = Vector2(22 * sc, 1.0)
			ledger.position = Vector2(note_x - 7 * sc, ly)
			ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(ledger)
			s -= 2

	# Note head (small oval)
	var head := Panel.new()
	head.size = Vector2(14 * sc, 9 * sc)
	head.position = Vector2(note_x - 7, note_y - 4.5)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head_sb := StyleBoxFlat.new()
	head_sb.bg_color = Color(0.20, 0.45, 0.72, 0.95)
	head_sb.corner_radius_top_left = 5
	head_sb.corner_radius_top_right = 5
	head_sb.corner_radius_bottom_left = 5
	head_sb.corner_radius_bottom_right = 5
	head_sb.border_width_left = 1
	head_sb.border_width_top = 1
	head_sb.border_width_right = 1
	head_sb.border_width_bottom = 1
	head_sb.border_color = Color(0.06, 0.06, 0.08, 0.80)
	head.add_theme_stylebox_override("panel", head_sb)
	container.add_child(head)

	# Stem
	var stem := ColorRect.new()
	stem.color = Color(0.12, 0.12, 0.14, 0.85)
	stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if note_step >= 4:
		# Stem up (right side, going up)
		stem.size = Vector2(1.2, 28)
		stem.position = Vector2(note_x + 6, note_y - 32)
	else:
		# Stem down (left side, going down)
		stem.size = Vector2(1.2, 28)
		stem.position = Vector2(note_x - 7, note_y + 4)
	container.add_child(stem)

	return container


# ---- Reusable Staff Helpers ----

func _create_teaching_staff(clef: String, width: float = 500.0, height: float = 190.0) -> Dictionary:
	# Scale all dimensions proportionally from the base gap of 14
	var scale := STAFF_LINE_SPACING / 14.0
	var scaled_w := width * scale
	var scaled_h := height * scale

	var container := Control.new()
	container.custom_minimum_size = Vector2(scaled_w, scaled_h)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.96, 0.94, 0.90, 0.95)
	bg_sb.corner_radius_top_left = int(14 * scale)
	bg_sb.corner_radius_top_right = int(14 * scale)
	bg_sb.corner_radius_bottom_left = int(14 * scale)
	bg_sb.corner_radius_bottom_right = int(14 * scale)
	bg.add_theme_stylebox_override("panel", bg_sb)
	container.add_child(bg)

	var gap := STAFF_LINE_SPACING
	var staff_top := 45.0 * scale
	var line_x := 40.0 * scale
	var line_w := scaled_w - 80.0 * scale

	var lines: Array = []
	for i in 5:
		var line := ColorRect.new()
		line.color = Color(0.30, 0.32, 0.36, 0.70)
		line.position = Vector2(line_x, staff_top + i * gap)
		line.size = Vector2(line_w, 1.5)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(line)
		lines.append(line)

	var clef_lbl: Label = null
	if clef != "none":
		var is_treble := clef == "treble"
		clef_lbl = Label.new()
		clef_lbl.text = String.chr(0x1D11E) if is_treble else String.chr(0x1D122)
		clef_lbl.add_theme_font_size_override("font_size", int(52 * scale))
		clef_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.85))
		if is_treble:
			var g_line_y := staff_top + 3 * gap
			clef_lbl.position = Vector2(line_x + 2, g_line_y - 34 * scale - gap)
		else:
			var f_line_y := staff_top + 1 * gap
			clef_lbl.position = Vector2(line_x + 2, f_line_y - 20 * scale - gap)
		clef_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(clef_lbl)
	else:
		# Bare staff: add line numbers (1-5, bottom to top) and space labels
		for li in 5:
			var line_num := 5 - li  # bottom line = 1, top = 5
			var num_lbl := Label.new()
			num_lbl.text = str(line_num)
			num_lbl.add_theme_font_override("font", FONT_BODY)
			num_lbl.add_theme_font_size_override("font_size", int(11 * scale))
			num_lbl.add_theme_color_override("font_color", Color(0.45, 0.50, 0.55, 0.70))
			num_lbl.position = Vector2(line_x - 16 * scale, staff_top + li * gap - 8 * scale)
			num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(num_lbl)
		for si in 4:
			var space_num := 4 - si  # bottom space = 1, top = 4
			var sp_lbl := Label.new()
			sp_lbl.text = str(space_num)
			sp_lbl.add_theme_font_override("font", FONT_BODY)
			sp_lbl.add_theme_font_size_override("font_size", int(10 * scale))
			sp_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30, 0.55))
			var space_y := staff_top + si * gap + gap * 0.5
			sp_lbl.position = Vector2(line_x + line_w + 6 * scale, space_y - 7 * scale)
			sp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(sp_lbl)

	return {
		"container": container,
		"staff_top": staff_top,
		"gap": gap,
		"line_x": line_x,
		"line_w": line_w,
		"lines": lines,
		"clef_label": clef_lbl,
		"scale": scale,
	}


func _pick_note_head_color() -> Color:
	return NOTE_HEAD_PALETTE[randi() % NOTE_HEAD_PALETTE.size()]


func _create_oval_notehead(color: Color = Color(0.12, 0.12, 0.12, 0.90)) -> Panel:
	var scale := STAFF_LINE_SPACING / 14.0
	var head := Panel.new()
	head.size = Vector2(22 * scale, 14 * scale)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_notehead_material(head, color, Color(0.06, 0.06, 0.08, 0.85))
	return head


func _apply_notehead_material(panel: Panel, base_color: Color, border_color: Color, border_width: int = 1) -> void:
	var rx := int(round(maxf(5.0, panel.size.x * 0.5)))
	var body := StyleBoxFlat.new()
	body.bg_color = base_color
	body.corner_radius_top_left = rx
	body.corner_radius_top_right = rx
	body.corner_radius_bottom_left = rx
	body.corner_radius_bottom_right = rx
	body.border_width_left = border_width
	body.border_width_top = border_width
	body.border_width_right = border_width
	body.border_width_bottom = border_width
	body.border_color = border_color
	panel.add_theme_stylebox_override("panel", body)

	# Drop shadow ---- reuse or create
	var shadow: Panel = panel.get_node_or_null("Shadow") as Panel
	if shadow == null:
		shadow = Panel.new()
		shadow.name = "Shadow"
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.z_index = -2
		shadow.size = panel.size + Vector2(6, 4)
		shadow.position = Vector2(-1, 2)
		panel.add_child(shadow)
	var shadow_sb := StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0.0, 0.0, 0.0, 0.20)
	shadow_sb.corner_radius_top_left = rx
	shadow_sb.corner_radius_top_right = rx
	shadow_sb.corner_radius_bottom_left = rx
	shadow_sb.corner_radius_bottom_right = rx
	shadow.add_theme_stylebox_override("panel", shadow_sb)

	# Gloss highlight ---- reuse or create
	var gloss: Panel = panel.get_node_or_null("Gloss") as Panel
	if gloss == null:
		gloss = Panel.new()
		gloss.name = "Gloss"
		gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gloss.z_index = 2
		gloss.size = Vector2(panel.size.x * 0.50, panel.size.y * 0.32)
		gloss.position = Vector2(panel.size.x * 0.16, panel.size.y * 0.12)
		panel.add_child(gloss)
	var gloss_sb := StyleBoxFlat.new()
	var lift_color := Color(
		clampf(base_color.r + 0.28, 0.0, 1.0),
		clampf(base_color.g + 0.28, 0.0, 1.0),
		clampf(base_color.b + 0.28, 0.0, 1.0),
		0.55
	)
	gloss_sb.bg_color = lift_color
	var gr := int(round(gloss.size.y * 0.9))
	gloss_sb.corner_radius_top_left = gr
	gloss_sb.corner_radius_top_right = gr
	gloss_sb.corner_radius_bottom_left = gr
	gloss_sb.corner_radius_bottom_right = gr
	gloss.add_theme_stylebox_override("panel", gloss_sb)


func _create_open_rhythm_notehead(width: float = 22.0, height: float = 14.0) -> Panel:
	var head := Panel.new()
	head.size = Vector2(width, height)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_notehead_material(head, Color(0.97, 0.95, 0.91, 1.0), Color(0.12, 0.12, 0.15, 0.92), 2)

	var pearl: Panel = head.get_node_or_null("Pearl") as Panel
	if pearl == null:
		pearl = Panel.new()
		pearl.name = "Pearl"
		pearl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pearl.z_index = 2
		pearl.size = Vector2(width * 0.56, height * 0.26)
		pearl.position = Vector2(width * 0.17, height * 0.14)
		head.add_child(pearl)
	var pearl_sb := StyleBoxFlat.new()
	pearl_sb.bg_color = Color(1.0, 1.0, 1.0, 0.52)
	var pearl_r := int(round(pearl.size.y))
	pearl_sb.corner_radius_top_left = pearl_r
	pearl_sb.corner_radius_top_right = pearl_r
	pearl_sb.corner_radius_bottom_left = pearl_r
	pearl_sb.corner_radius_bottom_right = pearl_r
	pearl.add_theme_stylebox_override("panel", pearl_sb)

	var shade: Panel = head.get_node_or_null("Shade") as Panel
	if shade == null:
		shade = Panel.new()
		shade.name = "Shade"
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.z_index = 1
		shade.size = Vector2(width * 0.72, height * 0.30)
		shade.position = Vector2(width * 0.12, height * 0.54)
		head.add_child(shade)
	var shade_sb := StyleBoxFlat.new()
	shade_sb.bg_color = Color(0.62, 0.58, 0.52, 0.24)
	var shade_r := int(round(shade.size.y))
	shade_sb.corner_radius_top_left = shade_r
	shade_sb.corner_radius_top_right = shade_r
	shade_sb.corner_radius_bottom_left = shade_r
	shade_sb.corner_radius_bottom_right = shade_r
	shade.add_theme_stylebox_override("panel", shade_sb)
	return head


func _get_rhythm_item_duration(item: Dictionary) -> float:
	var beats := float(item.get("beats", -1.0))
	if beats > 0.0:
		return beats

	var kind: String = str(item.get("kind", "quarter"))
	match kind:
		"whole":
			return 4.0
		"half":
			return 2.0
		"dotted_half":
			return 3.0
		"quarter":
			return 1.0
		"dotted_quarter":
			return 1.5
		"eighth":
			return 0.5
		"sixteenth":
			return 0.25
	return 1.0


func _get_rhythm_kind_for_beats(beats: float) -> String:
	if is_equal_approx(beats, 4.0):
		return "whole"
	if is_equal_approx(beats, 3.0):
		return "dotted_half"
	if is_equal_approx(beats, 2.0):
		return "half"
	if is_equal_approx(beats, 1.5):
		return "dotted_quarter"
	if is_equal_approx(beats, 0.5):
		return "eighth"
	if is_equal_approx(beats, 0.25):
		return "sixteenth"
	return "quarter"


func _get_default_rest_kind_for_beats(beats: float) -> String:
	if is_equal_approx(beats, 4.0):
		return "whole_rest"
	if is_equal_approx(beats, 2.0):
		return "half_rest"
	if is_equal_approx(beats, 0.5):
		return "eighth_rest"
	if is_equal_approx(beats, 0.25):
		return "sixteenth_rest"
	return "quarter_rest"


func _normalize_rhythm_pattern_item(pattern_item: Variant) -> Dictionary:
	if pattern_item is Dictionary:
		var item: Dictionary = (pattern_item as Dictionary).duplicate(true)
		var beats := float(item.get("beats", -1.0))
		if beats <= 0.0:
			beats = _get_rhythm_item_duration(item)
		item["beats"] = beats
		if not item.has("kind"):
			item["kind"] = _get_rhythm_kind_for_beats(beats)
		if bool(item.get("rest", false)) and not item.has("rest_kind"):
			item["rest_kind"] = _get_default_rest_kind_for_beats(beats)
		return item
	var beats := float(pattern_item)
	return {"kind": _get_rhythm_kind_for_beats(beats), "beats": beats}


func _get_rhythm_value_label(beats: float) -> String:
	if is_equal_approx(beats, 4.0):
		return "Whole"
	if is_equal_approx(beats, 3.0):
		return "Dotted Half"
	if is_equal_approx(beats, 2.0):
		return "Half"
	if is_equal_approx(beats, 1.5):
		return "Dotted Quarter"
	if is_equal_approx(beats, 1.0):
		return "Quarter"
	if is_equal_approx(beats, 0.5):
		return "Eighth"
	if is_equal_approx(beats, 0.25):
		return "16th"
	return "%s beats" % String.num(beats, 1)


func _get_rhythm_rest_label(rest_kind: String, beats: float) -> String:
	match rest_kind:
		"whole_rest":
			return "Whole Rest"
		"half_rest":
			return "Half Rest"
		"quarter_rest":
			return "Quarter Rest"
		"eighth_rest":
			return "Eighth Rest"
		"sixteenth_rest":
			return "16th Rest"
	return "%s Rest" % _get_rhythm_value_label(beats)


func _build_rhythm_items_from_pattern(pattern: Array) -> Array:
	var items: Array = []
	for pattern_item in pattern:
		items.append(_normalize_rhythm_pattern_item(pattern_item))
	return items


func _play_metronome_click(is_downbeat: bool = false) -> void:
	if _metronome_player == null:
		return
	_metronome_player.stop()
	_metronome_player.stream = METRONOME_ACCENT_STREAM if is_downbeat else METRONOME_TICK_STREAM
	_metronome_player.volume_db = 3.0 if is_downbeat else -3.0
	_metronome_player.play()


func _get_rhythm_stem_tip(stem: ColorRect, stem_up: bool) -> Vector2:
	return Vector2(
		stem.position.x + stem.size.x * 0.5,
		stem.position.y if stem_up else stem.position.y + stem.size.y
	)


func _add_rhythm_eighth_flag(parent: Control, stem: ColorRect, stem_up: bool, symbol_color: Color) -> void:
	var stem_tip := _get_rhythm_stem_tip(stem, stem_up)
	var flag := Line2D.new()
	flag.default_color = symbol_color
	flag.width = 3.0
	flag.antialiased = true
	flag.z_index = 1

	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 1.0))
	width_curve.add_point(Vector2(0.45, 0.95))
	width_curve.add_point(Vector2(0.78, 0.55))
	width_curve.add_point(Vector2(1.0, 0.10))
	flag.width_curve = width_curve

	if stem_up:
		flag.position = stem_tip + Vector2(0.0, -1.5)
		flag.add_point(Vector2.ZERO)
		flag.add_point(Vector2(4.5, 0.8))
		flag.add_point(Vector2(8.6, 3.8))
		flag.add_point(Vector2(11.0, 8.8))
		flag.add_point(Vector2(10.6, 15.2))
		flag.add_point(Vector2(7.8, 21.2))
	else:
		flag.position = stem_tip + Vector2(0.0, 1.5)
		flag.add_point(Vector2.ZERO)
		flag.add_point(Vector2(-4.5, -0.8))
		flag.add_point(Vector2(-8.6, -3.8))
		flag.add_point(Vector2(-11.0, -8.8))
		flag.add_point(Vector2(-10.6, -15.2))
		flag.add_point(Vector2(-7.8, -21.2))

	parent.add_child(flag)


func _draw_rhythm_beam_group(parent: Control, note_layouts: Array, note_indices: Array) -> void:
	if note_indices.size() < 2:
		return
	var first_index: int = int(note_indices[0])
	var last_index: int = int(note_indices[note_indices.size() - 1])
	if first_index < 0 or first_index >= note_layouts.size() or last_index < 0 or last_index >= note_layouts.size():
		return
	var first_layout: Dictionary = note_layouts[first_index]
	var last_layout: Dictionary = note_layouts[last_index]
	var first_stem := first_layout.get("stem", null) as ColorRect
	var last_stem := last_layout.get("stem", null) as ColorRect
	if first_stem == null or last_stem == null:
		return
	var stem_up: bool = bool(first_layout.get("stem_up", true))
	var symbol_color: Color = first_layout.get("symbol_color", Color(0.10, 0.10, 0.12, 0.98))
	var first_tip := _get_rhythm_stem_tip(first_stem, stem_up)
	var last_tip := _get_rhythm_stem_tip(last_stem, stem_up)
	var beam := Line2D.new()
	beam.default_color = symbol_color
	beam.width = 6.0
	beam.antialiased = true
	beam.z_index = 1
	if stem_up:
		beam.add_point(first_tip + Vector2(0.0, 1.2))
		beam.add_point(last_tip + Vector2(0.0, 1.2))
	else:
		beam.add_point(first_tip + Vector2(0.0, -1.2))
		beam.add_point(last_tip + Vector2(0.0, -1.2))
	parent.add_child(beam)

	# Check if all notes in group are sixteenths ---- add second beam
	var all_sixteenths := true
	for ni in note_indices:
		var idx: int = int(ni)
		if idx >= 0 and idx < note_layouts.size():
			if str(note_layouts[idx].get("kind", "")) != "sixteenth":
				all_sixteenths = false
				break
	if all_sixteenths:
		var beam2 := Line2D.new()
		beam2.default_color = symbol_color
		beam2.width = 6.0
		beam2.antialiased = true
		beam2.z_index = 1
		var offset := 7.0 if stem_up else -7.0
		if stem_up:
			beam2.add_point(first_tip + Vector2(0.0, 1.2 + offset))
			beam2.add_point(last_tip + Vector2(0.0, 1.2 + offset))
		else:
			beam2.add_point(first_tip + Vector2(0.0, -1.2 + offset))
			beam2.add_point(last_tip + Vector2(0.0, -1.2 + offset))
		parent.add_child(beam2)


func _draw_rhythm_note_symbol(parent: Control, item: Dictionary, center: Vector2) -> Dictionary:
	var kind: String = str(item.get("kind", "quarter"))
	var dotted: bool = bool(item.get("dotted", false)) or kind.begins_with("dotted_")
	var stem_direction: String = str(item.get("stem", "up"))
	var stem_up := stem_direction != "down"
	var is_open := kind in ["whole", "half", "dotted_half", "dotted_quarter"]
	var symbol_color: Color = item.get("symbol_color", Color(0.12, 0.12, 0.15, 0.95))
	var sc := STAFF_LINE_SPACING / 14.0
	var stem: ColorRect = null
	var head := _create_open_rhythm_notehead(22.0 * sc, 14.0 * sc) if is_open else _create_oval_notehead(symbol_color)
	head.position = Vector2(center.x - head.size.x / 2.0, center.y - head.size.y / 2.0)
	parent.add_child(head)

	if kind != "whole":
		var stem_anchor_x_up := center.x + head.size.x * 0.37
		var stem_anchor_x_down := center.x - head.size.x * 0.30
		stem = ColorRect.new()
		stem.color = symbol_color
		stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stem.size = Vector2(2.2 * sc, 38.0 * sc)
		if stem_up:
			stem.position = Vector2(stem_anchor_x_up, center.y - stem.size.y + 2.0)
		else:
			stem.position = Vector2(stem_anchor_x_down, center.y - 1.0)
		parent.add_child(stem)

		if kind == "eighth" and not bool(item.get("beamed", false)):
			_add_rhythm_eighth_flag(parent, stem, stem_up, symbol_color)
		elif kind == "sixteenth" and not bool(item.get("beamed", false)):
			_add_rhythm_eighth_flag(parent, stem, stem_up, symbol_color)
			# Second flag offset below the first
			var flag_offset := 6.0 * sc if stem_up else -6.0 * sc
			var stem2 := ColorRect.new()
			stem2.color = Color(0, 0, 0, 0)
			stem2.size = stem.size
			stem2.position = Vector2(stem.position.x, stem.position.y + flag_offset)
			stem2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(stem2)
			_add_rhythm_eighth_flag(parent, stem2, stem_up, symbol_color)

	if dotted:
		var dot := Panel.new()
		dot.size = Vector2(4.5 * sc, 4.5 * sc)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot_sb := StyleBoxFlat.new()
		dot_sb.bg_color = Color(0.10, 0.10, 0.12, 0.95)
		dot_sb.corner_radius_top_left = 3
		dot_sb.corner_radius_top_right = 3
		dot_sb.corner_radius_bottom_left = 3
		dot_sb.corner_radius_bottom_right = 3
		dot.add_theme_stylebox_override("panel", dot_sb)
		dot.position = Vector2(center.x + head.size.x * 0.62, center.y - 2.0)
		parent.add_child(dot)

	# Pop-in then gentle scale breathing (staggered per note via item_index)
	head.pivot_offset = head.size / 2.0
	head.scale = Vector2(0.3, 0.3)
	var pop_tw := head.create_tween()
	pop_tw.tween_property(head, "scale", Vector2(1.06, 1.06), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(head, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Subtle scale breathing -- stagger each note with a different initial delay
	var stagger_delay := float(item.get("_note_index", 0)) * 0.18
	var breathe_tw := head.create_tween()
	breathe_tw.set_loops()
	breathe_tw.tween_property(head, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(stagger_delay + 0.4)
	breathe_tw.tween_property(head, "scale", Vector2(0.97, 0.97), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe_tw.tween_property(head, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return {
		"kind": kind,
		"center": center,
		"head": head,
		"stem": stem,
		"stem_up": stem_up,
		"symbol_color": symbol_color,
	}


func _draw_rhythm_rest_symbol(parent: Control, kind: String, center: Vector2, gap: float) -> Dictionary:
	var rest_color := Color(0.15, 0.15, 0.18, 0.92)
	var rest_node: Control = null
	match kind:
		"whole_rest":
			# Rectangle hanging below line 2 (a filled block below a line)
			var block := ColorRect.new()
			block.color = rest_color
			block.size = Vector2(16.0, 6.0)
			block.position = Vector2(center.x - 8.0, center.y - gap * 0.5)
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(block)
			rest_node = block
		"half_rest":
			# Rectangle sitting on top of line 3 (a filled block on top of a line)
			var block := ColorRect.new()
			block.color = rest_color
			block.size = Vector2(16.0, 6.0)
			block.position = Vector2(center.x - 8.0, center.y - 6.0 + gap * 0.5)
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(block)
			rest_node = block
		"quarter_rest":
			# Zig-zag shape approximated with Unicode
			var lbl := Label.new()
			lbl.text = " -- "
			lbl.add_theme_font_size_override("font_size", 32)
			lbl.add_theme_color_override("font_color", rest_color)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(24.0, 40.0)
			lbl.position = Vector2(center.x - 12.0, center.y - 20.0)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(lbl)
			rest_node = lbl
		"eighth_rest":
			# Eighth rest approximated with Unicode
			var lbl := Label.new()
			lbl.text = " -- "
			lbl.add_theme_font_size_override("font_size", 24)
			lbl.add_theme_color_override("font_color", rest_color)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.size = Vector2(20.0, 30.0)
			lbl.position = Vector2(center.x - 10.0, center.y - 15.0)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(lbl)
			rest_node = lbl
		_:
			# Fallback: simple text label
			var lbl := Label.new()
			lbl.text = "rest"
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", rest_color)
			lbl.position = Vector2(center.x - 12.0, center.y - 8.0)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(lbl)
			rest_node = lbl

	if rest_node != null:
		rest_node.pivot_offset = rest_node.size / 2.0
		rest_node.scale = Vector2(0.3, 0.3)
		var pop_tw := rest_node.create_tween()
		pop_tw.tween_property(rest_node, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tw.tween_property(rest_node, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return {"kind": kind, "center": center, "head": rest_node, "stem": null, "stem_up": true, "symbol_color": rest_color}


func _add_staff_time_signature(parent: Control, top_num: int, bottom_num: int, ts_x: float, staff_top: float, gap: float, font_size: int = 38, highlight_top: bool = false) -> void:
	var number_height := gap * 2.15
	var number_size := Vector2(36.0, number_height)
	# Center top number between lines 1-2, bottom number between lines 3-4
	var top_y := staff_top - gap * 0.58
	var bottom_y := staff_top + gap * 1.42

	var top_lbl := Label.new()
	top_lbl.text = str(top_num)
	top_lbl.add_theme_font_override("font", FONT_TITLE)
	top_lbl.add_theme_font_size_override("font_size", font_size)
	top_lbl.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10, 0.94))
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_lbl.size = number_size
	top_lbl.position = Vector2(ts_x - number_size.x * 0.5, top_y)
	top_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top_lbl)

	if highlight_top:
		top_lbl.add_theme_color_override("font_color", Color(0.85, 0.20, 0.15, 1.0))
		top_lbl.add_theme_font_size_override("font_size", font_size + 4)
		top_lbl.pivot_offset = number_size / 2.0
		var pulse_tw := top_lbl.create_tween()
		pulse_tw.set_loops()
		pulse_tw.tween_property(top_lbl, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tw.tween_property(top_lbl, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var bot_lbl := Label.new()
	bot_lbl.text = str(bottom_num)
	bot_lbl.add_theme_font_override("font", FONT_TITLE)
	bot_lbl.add_theme_font_size_override("font_size", font_size)
	bot_lbl.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10, 0.94))
	bot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bot_lbl.size = number_size
	bot_lbl.position = Vector2(ts_x - number_size.x * 0.5, bottom_y)
	bot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bot_lbl)


func _build_rhythm_staff_example(visual_data: Dictionary) -> Control:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var all_note_layouts: Array = []  # flat list of {head, stem, ...} for animation
	var all_beat_labels: Array = []   # flat list of beat count Labels for animation

	var bars: Array = visual_data.get("bars", [])
	if bars.is_empty():
		bars = [[
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0},
		]]

	var top_num: int = int(visual_data.get("top", 4))
	var bottom_num: int = int(visual_data.get("bottom", 4))
	var clef: String = str(visual_data.get("clef", "treble"))
	var show_time_signature: bool = bool(visual_data.get("show_time_signature", true))
	var show_counts: bool = bool(visual_data.get("show_counts", true))
	var beam_groups_per_bar: Array = visual_data.get("beam_groups", [])
	var width := float(visual_data.get("width", 580.0 if bars.size() > 1 else 500.0))
	var staff_height := float(visual_data.get("staff_height", 190.0))
	var staff := _create_teaching_staff(clef, width, staff_height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	root.add_child(container)

	var sc := STAFF_LINE_SPACING / 14.0
	var signature_pad := 0.0
	if show_time_signature:
		var ts_x := line_x + (68.0 * sc if clef != "none" else 24.0 * sc)
		_add_staff_time_signature(container, top_num, bottom_num, ts_x, staff_top, gap, int(visual_data.get("font_size", 38)), bool(visual_data.get("highlight_top", false)))
		signature_pad = 38.0 * sc

	var left_pad := (50.0 if clef != "none" else 14.0) * sc
	left_pad += signature_pad
	var bar_gap := float(visual_data.get("bar_gap", 18.0))
	var available_width := line_w - left_pad - maxf(float(bars.size() - 1), 0.0) * bar_gap - 6.0
	var bar_width := maxf(available_width / float(max(bars.size(), 1)), 110.0)
	var bar_beat_total := float(top_num) * (4.0 / maxf(float(bottom_num), 1.0))
	var note_y := staff_top + 2.0 * gap + float(visual_data.get("note_y_offset", 0.0))
	var bar_line_top := staff_top - 1.0
	var bar_line_height := gap * 4.0 + 2.0

	for bar_index in bars.size():
		var bar_x := line_x + left_pad + bar_index * (bar_width + bar_gap)
		var end_line := ColorRect.new()
		end_line.color = Color(0.20, 0.20, 0.22, 0.80)
		end_line.position = Vector2(bar_x + bar_width, bar_line_top)
		end_line.size = Vector2(2.0, bar_line_height)
		end_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(end_line)

		var beat_width := bar_width / maxf(bar_beat_total, 1.0)
		if show_counts:
			# Detect if bar has any eighth notes for "1 & 2 &" counting
			var has_eighths := false
			for check_item in bars[bar_index]:
				if str(check_item.get("kind", "")) == "eighth":
					has_eighths = true
					break
			var count_y := staff_top + gap * 4.5 + 8.0
			for beat_index in top_num:
				var count_lbl := Label.new()
				count_lbl.text = str(beat_index + 1)
				count_lbl.add_theme_font_override("font", FONT_BODY)
				count_lbl.add_theme_font_size_override("font_size", 13)
				count_lbl.add_theme_color_override("font_color", Color(0.48, 0.35, 0.08, 0.98))
				count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				count_lbl.position = Vector2(bar_x + beat_width * beat_index + beat_width * 0.15 - 10.0 if has_eighths else bar_x + beat_width * (beat_index + 0.5) - 10.0, count_y)
				count_lbl.size = Vector2(20.0, 18.0)
				count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				container.add_child(count_lbl)
				all_beat_labels.append(count_lbl)
				if has_eighths:
					var and_lbl := Label.new()
					and_lbl.text = "&"
					and_lbl.add_theme_font_override("font", FONT_BODY)
					and_lbl.add_theme_font_size_override("font_size", 12)
					and_lbl.add_theme_color_override("font_color", Color(0.48, 0.35, 0.08, 0.65))
					and_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					and_lbl.position = Vector2(bar_x + beat_width * (beat_index + 0.6) - 6.0, count_y)
					and_lbl.size = Vector2(14.0, 18.0)
					and_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					container.add_child(and_lbl)

		var items: Array = bars[bar_index]
		var bar_beam_groups: Array = []
		if bar_index < beam_groups_per_bar.size():
			bar_beam_groups = beam_groups_per_bar[bar_index]
		var beamed_indices: Dictionary = {}
		for beam_group in bar_beam_groups:
			for note_index in beam_group:
				beamed_indices[int(note_index)] = true

		var beat_cursor := 0.0
		var note_layouts: Array = []
		var item_index := 0
		for item in items:
			var beats := _get_rhythm_item_duration(item)
			if beats <= 0.0:
				item_index += 1
				continue
			var horizontal_offset_beats := minf(beats * 0.5, 0.5)
			var center_x := bar_x + beat_width * (beat_cursor + horizontal_offset_beats) + float(item.get("x_offset", 0.0))
			var draw_item: Dictionary = item.duplicate(true)
			draw_item["_note_index"] = item_index
			if beamed_indices.has(item_index):
				draw_item["beamed"] = true
			var is_rest := bool(item.get("rest", false))
			var layout: Dictionary
			if is_rest:
				layout = _draw_rhythm_rest_symbol(container, str(item.get("rest_kind", "quarter_rest")), Vector2(center_x, note_y + float(item.get("y_offset", 0.0))), gap)
			else:
				layout = _draw_rhythm_note_symbol(container, draw_item, Vector2(center_x, note_y + float(item.get("y_offset", 0.0))))
			layout["beats"] = beats
			note_layouts.append(layout)
			all_note_layouts.append(layout)
			beat_cursor += beats
			item_index += 1

		for beam_group in bar_beam_groups:
			_draw_rhythm_beam_group(container, note_layouts, beam_group)

	var prompt_text: String = str(visual_data.get("prompt", ""))
	if prompt_text != "":
		var prompt_lbl := Label.new()
		prompt_lbl.text = prompt_text
		prompt_lbl.add_theme_font_override("font", FONT_TITLE)
		prompt_lbl.add_theme_font_size_override("font_size", 16)
		prompt_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(prompt_lbl)

	var caption_text: String = str(visual_data.get("caption", ""))
	if caption_text != "":
		var caption_lbl := Label.new()
		caption_lbl.text = caption_text
		caption_lbl.add_theme_font_override("font", FONT_BODY)
		caption_lbl.add_theme_font_size_override("font_size", 15)
		caption_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(caption_lbl)

	# Store animation targets on root for _play_rhythm_demo to use
	root.set_meta("_note_layouts", all_note_layouts)
	root.set_meta("_beat_labels", all_beat_labels)
	return root


func _draw_rhythm_staff_example(visual_data: Dictionary) -> void:
	var staff_root := _build_rhythm_staff_example(visual_data)
	_content_vbox.add_child(staff_root)
	var has_loop := int(visual_data.get("loop_count", 0)) > 1
	var has_playable := bool(visual_data.get("playable", false))
	# Add "Hear the Demo" button for playable or looping visuals
	if has_playable or has_loop:
		var demo_btn := Button.new()
		demo_btn.text = "Hear the Demo"
		demo_btn.add_theme_font_override("font", FONT_BODY)
		demo_btn.add_theme_font_size_override("font_size", 14)
		demo_btn.custom_minimum_size = Vector2(140, 34)
		demo_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_style_flat_button(demo_btn)
		demo_btn.add_theme_color_override("font_color", ACCENT_GOLD)
		var captured_visual := visual_data.duplicate(true)
		var captured_root := staff_root
		demo_btn.pressed.connect(func(): _play_rhythm_demo(captured_visual, 0.0, captured_root))
		_content_vbox.add_child(demo_btn)
	# Auto-play on load (looping or single)
	if has_loop or has_playable:
		var autoplay_visual := visual_data.duplicate(true)
		var autoplay_root := staff_root
		var autoplay_wait := maxf(RHYTHM_AUTOPLAY_DELAY - (Time.get_ticks_msec() / 1000.0 - _step_render_time), 0.0)
		_play_rhythm_demo(autoplay_visual, autoplay_wait, autoplay_root)


func _draw_rhythm_equivalence_visual(visual_data: Dictionary) -> void:
	var warm_note_color: Color = visual_data.get("warm_note_color", Color(0.98, 0.78, 0.24, 1.0))
	var cool_note_color: Color = visual_data.get("cool_note_color", Color(0.55, 0.82, 1.0, 1.0))
	var wrapper := VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 10)
	_content_vbox.add_child(wrapper)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	wrapper.add_child(row)

	var left_panel := Control.new()
	left_panel.custom_minimum_size = Vector2(86, 112)
	row.add_child(left_panel)
	var left_item: Dictionary = (visual_data.get("left_item", {"kind": "quarter", "beats": 1.0}) as Dictionary).duplicate(true)
	left_item["symbol_color"] = left_item.get("symbol_color", warm_note_color)
	_draw_rhythm_note_symbol(left_panel, left_item, Vector2(43, 54))

	var eq_lbl := Label.new()
	eq_lbl.text = "="
	eq_lbl.add_theme_font_override("font", FONT_TITLE)
	eq_lbl.add_theme_font_size_override("font_size", 36)
	eq_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(eq_lbl)

	var right_panel := Control.new()
	right_panel.custom_minimum_size = Vector2(124, 112)
	row.add_child(right_panel)
	var right_items: Array = visual_data.get("right_items", [
		{"kind": "eighth", "beats": 0.5, "beamed": true},
		{"kind": "eighth", "beats": 0.5, "beamed": true},
	])
	var right_layouts: Array = []
	var start_x := 34.0
	var spacing := 34.0
	for i in right_items.size():
		var right_item: Dictionary = (right_items[i] as Dictionary).duplicate(true)
		right_item["beamed"] = true
		right_item["symbol_color"] = right_item.get("symbol_color", cool_note_color)
		right_layouts.append(_draw_rhythm_note_symbol(right_panel, right_item, Vector2(start_x + spacing * i, 54)))
	_draw_rhythm_beam_group(right_panel, right_layouts, visual_data.get("beam_group", [0, 1]))

	var labels_row := HBoxContainer.new()
	labels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	labels_row.add_theme_constant_override("separation", 44)
	wrapper.add_child(labels_row)

	var left_lbl := Label.new()
	left_lbl.text = str(visual_data.get("left_label", "1 beat"))
	left_lbl.add_theme_font_override("font", FONT_BODY)
	left_lbl.add_theme_font_size_override("font_size", 15)
	left_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	labels_row.add_child(left_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 1)
	labels_row.add_child(spacer)

	var right_lbl := Label.new()
	right_lbl.text = str(visual_data.get("right_label", "1/2 + 1/2 beats"))
	right_lbl.add_theme_font_override("font", FONT_BODY)
	right_lbl.add_theme_font_size_override("font_size", 15)
	right_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	labels_row.add_child(right_lbl)

	var caption_text: String = str(visual_data.get("caption", ""))
	if caption_text != "":
		var caption_lbl := Label.new()
		caption_lbl.text = caption_text
		caption_lbl.add_theme_font_override("font", FONT_TITLE)
		caption_lbl.add_theme_font_size_override("font_size", 16)
		caption_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrapper.add_child(caption_lbl)

	var detail_text: String = str(visual_data.get("detail", ""))
	if detail_text != "":
		var detail_lbl := Label.new()
		detail_lbl.text = detail_text
		detail_lbl.add_theme_font_override("font", FONT_BODY)
		detail_lbl.add_theme_font_size_override("font_size", 14)
		detail_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrapper.add_child(detail_lbl)

	# "Play Comparison" button ---- sequential highlight animation with sound
	var compare_btn := Button.new()
	compare_btn.text = "Play Comparison"
	compare_btn.add_theme_font_override("font", FONT_BODY)
	compare_btn.add_theme_font_size_override("font_size", 14)
	compare_btn.custom_minimum_size = Vector2(150, 34)
	compare_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_flat_button(compare_btn)
	compare_btn.add_theme_color_override("font_color", ACCENT_GOLD)
	wrapper.add_child(compare_btn)

	var left_head: Control = null
	if left_panel.get_child_count() > 0:
		left_head = left_panel.get_child(0)
	var right_heads: Array[Control] = []
	for rl in right_layouts:
		if rl.has("head") and rl["head"] != null:
			right_heads.append(rl["head"])

	var highlight_green := Color(0.30, 0.95, 0.45, 1.0)
	var captured_left := left_head
	var captured_right := right_heads
	var captured_btn := compare_btn
	compare_btn.pressed.connect(func():
		if captured_btn.disabled:
			return
		captured_btn.disabled = true
		_rhythm_playback_token += 1
		var token: int = _rhythm_playback_token
		# Phase 1: Highlight quarter note + play click
		if captured_left != null and is_instance_valid(captured_left):
			captured_left.modulate = highlight_green
			captured_left.pivot_offset = captured_left.size / 2.0
			var tw := captured_left.create_tween()
			tw.tween_property(captured_left, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(captured_left, "scale", Vector2(1.0, 1.0), 0.15)
		_play_metronome_click(true)
		await get_tree().create_timer(0.7).timeout
		if not is_instance_valid(self) or token != _rhythm_playback_token:
			return
		# Reset quarter
		if captured_left != null and is_instance_valid(captured_left):
			captured_left.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self) or token != _rhythm_playback_token:
			return
		# Phase 2: Highlight each eighth note sequentially + play click
		for rh in captured_right:
			if not is_instance_valid(self) or token != _rhythm_playback_token:
				return
			if is_instance_valid(rh):
				rh.modulate = highlight_green
				rh.pivot_offset = rh.size / 2.0
				var tw2 := rh.create_tween()
				tw2.tween_property(rh, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw2.tween_property(rh, "scale", Vector2(1.0, 1.0), 0.12)
			_play_metronome_click(false)
			await get_tree().create_timer(0.35).timeout
		# Reset all
		await get_tree().create_timer(0.3).timeout
		for rh in captured_right:
			if is_instance_valid(rh):
				rh.modulate = Color(1, 1, 1, 1)
		if is_instance_valid(captured_btn):
			captured_btn.disabled = false
	)
	# Auto-play comparison after a short delay
	_rhythm_playback_token += 1
	var auto_token: int = _rhythm_playback_token
	get_tree().create_timer(RHYTHM_AUTOPLAY_DELAY).timeout.connect(func():
		if is_instance_valid(self) and auto_token == _rhythm_playback_token and is_instance_valid(captured_btn):
			captured_btn.emit_signal("pressed")
	)


func _add_teaching_notehead(parent: Control, center: Vector2, label_text: String, label_color: Color = ACCENT_GOLD) -> void:
	var head := _create_oval_notehead(_pick_note_head_color())
	head.position = Vector2(center.x - head.size.x / 2.0, center.y - head.size.y / 2.0)
	parent.add_child(head)

	# Idle bob
	var bob_tw := parent.create_tween()
	bob_tw.set_loops()
	bob_tw.tween_property(head, "position:y", head.position.y - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tw.tween_property(head, "position:y", head.position.y + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Dark pill background for readability over staff lines
	var lbl_bg := PanelContainer.new()
	var lbl_sb := StyleBoxFlat.new()
	lbl_sb.bg_color = Color(0.06, 0.10, 0.18, 0.88)
	lbl_sb.corner_radius_top_left = 6
	lbl_sb.corner_radius_top_right = 6
	lbl_sb.corner_radius_bottom_left = 6
	lbl_sb.corner_radius_bottom_right = 6
	lbl_sb.content_margin_left = 5
	lbl_sb.content_margin_right = 5
	lbl_sb.content_margin_top = 1
	lbl_sb.content_margin_bottom = 1
	lbl_bg.add_theme_stylebox_override("panel", lbl_sb)
	lbl_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bg.position = Vector2(center.x - 10, center.y + 10)
	parent.add_child(lbl_bg)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", label_color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bg.add_child(lbl)


# ---- Staff Teaching Visuals ----

func _draw_staff_lines_intro(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var staff := _create_teaching_staff(clef, 500.0, 190.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	var lines: Array = staff["lines"]
	var clef_label: Label = staff["clef_label"]
	_content_vbox.add_child(container)

	# Start with everything hidden
	if clef_label != null:
		clef_label.modulate.a = 0.0
	var number_labels: Array = []
	for i in 5:
		lines[i].modulate.a = 0.0
		var num_lbl := Label.new()
		num_lbl.text = str(5 - i)
		num_lbl.add_theme_font_override("font", FONT_TITLE)
		num_lbl.add_theme_font_size_override("font_size", 16)
		num_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		num_lbl.position = Vector2(line_x + line_w + 8, staff_top + i * gap - 10)
		num_lbl.modulate.a = 0.0
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(num_lbl)
		number_labels.append(num_lbl)

	# Animate: clef first, then lines from bottom (i=4) to top (i=0)
	var tw := container.create_tween()
	if clef_label != null:
		tw.tween_property(clef_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.2)
	for idx in range(4, -1, -1):
		tw.tween_property(lines[idx], "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(number_labels[idx], "modulate:a", 1.0, 0.2)
		tw.tween_interval(0.25)


func _draw_staff_spaces_intro(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var staff := _create_teaching_staff(clef, 500.0, 190.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	_content_vbox.add_child(container)

	# Create space highlight rectangles between lines, from bottom to top
	var space_rects: Array = []
	var space_labels: Array = []
	for space_num in range(1, 5):
		var top_line_idx := 4 - space_num
		var y_top := staff_top + top_line_idx * gap + 1.5
		var y_bot := staff_top + (top_line_idx + 1) * gap

		var rect := ColorRect.new()
		rect.color = Color(0.40, 0.75, 0.95, 0.28)
		rect.position = Vector2(line_x + 60, y_top)
		rect.size = Vector2(line_w - 80, y_bot - y_top)
		rect.modulate.a = 0.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)
		space_rects.append(rect)

		var lbl := Label.new()
		lbl.text = str(space_num)
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.20, 0.55, 0.85, 1.0))
		lbl.position = Vector2(line_x + line_w + 8, (y_top + y_bot) / 2.0 - 10)
		lbl.modulate.a = 0.0
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
		space_labels.append(lbl)

	# Animate spaces from bottom (1) to top (4)
	var tw := container.create_tween()
	tw.tween_interval(0.3)
	for i in 4:
		tw.tween_property(space_rects[i], "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(space_labels[i], "modulate:a", 1.0, 0.3)
		tw.tween_interval(0.3)


func _draw_notes_on_lines(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var notes: Array = visual_data.get("notes", [])
	var staff := _create_teaching_staff(clef, 500.0, 190.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	_content_vbox.add_child(container)

	# notes array is bottom-to-top: notes[0]=bottom line, notes[4]=top line
	for i in mini(notes.size(), 5):
		var line_idx := 4 - i
		var y := staff_top + line_idx * gap
		var x := line_x + 90 + i * 68
		_add_teaching_notehead(container, Vector2(x, y), notes[i])


func _draw_notes_in_spaces(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var notes: Array = visual_data.get("notes", [])
	var staff := _create_teaching_staff(clef, 500.0, 190.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	_content_vbox.add_child(container)

	# notes array is bottom-to-top: notes[0]=bottom space, notes[3]=top space
	for i in mini(notes.size(), 4):
		var top_line_idx := 3 - i
		var center_y := staff_top + (top_line_idx + 0.5) * gap
		var x := line_x + 90 + i * 80
		_add_teaching_notehead(container, Vector2(x, center_y), notes[i])


# ---- Note-on-Staff Multi-Phase Introduction ----

func _note_position_text(clef: String, note_step: int) -> String:
	var is_on_line: bool = (note_step % 2 == 0)
	if clef == "treble":
		if is_on_line:
			match note_step:
				8: return "1st line (bottom)"
				6: return "2nd line"
				4: return "3rd line (middle)"
				2: return "4th line"
				0: return "5th line (top)"
				10: return "ledger line below the staff"
				_: return "ledger line"
		else:
			match note_step:
				7: return "1st space"
				5: return "2nd space"
				3: return "3rd space"
				1: return "4th space (top)"
				9: return "space below the staff"
				_: return "space"
	else:  # bass
		if is_on_line:
			match note_step:
				8: return "1st line (bottom)"
				6: return "2nd line"
				4: return "3rd line (middle)"
				2: return "4th line"
				0: return "5th line (top)"
				-2: return "ledger line above the staff"
				_: return "ledger line"
		else:
			match note_step:
				7: return "1st space"
				5: return "2nd space"
				3: return "3rd space"
				1: return "4th space (top)"
				-1: return "space above the staff"
				9: return "space below the staff"
				_: return "space"
	return ""


func _draw_note_on_staff(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var note_name: String = visual_data.get("note_name", "C")
	var note_step: int = visual_data.get("note_step", 4)

	# Build the full note ID for audio
	var full_note_id: String = LMD.step_to_note_id(clef, note_step)
	var accidental: String = visual_data.get("accidental", "")
	if accidental == "sharp" and full_note_id.length() >= 2:
		full_note_id = full_note_id[0] + "#" + full_note_id.substr(1)
	elif accidental == "flat" and full_note_id.length() >= 2:
		full_note_id = full_note_id[0] + "b" + full_note_id.substr(1)

	# Cache data for phase rendering
	_note_intro_data = {
		"clef": clef,
		"note_name": note_name,
		"note_step": note_step,
		"full_note_id": full_note_id,
		"note_color": _pick_note_head_color(),
		"accidental": accidental,
	}

	# Determine phases
	_note_intro_phase3_variant = randi() % 2
	if not _note_intro_first_note_done:
		_note_intro_phase = 1
		_note_intro_max_phase = 4  # clef anchor(1) + spotlight/peel(2) + piano(3) + final(4)
	else:
		_note_intro_phase = 1
		_note_intro_max_phase = 3  # spotlight/peel(1) + piano(2) + final(3)

	_render_note_intro_phase()
	_update_nav_buttons()


func _advance_note_intro_phase() -> void:
	_note_intro_phase += 1
	_clear_content()
	_render_note_intro_phase()
	_update_nav_buttons()


func _render_note_intro_phase() -> void:
	var is_first_note: bool = not _note_intro_first_note_done
	var phase := _note_intro_phase

	if is_first_note:
		# Phases: 1=clef anchor, 2=spotlight/peel, 3=piano, 4=final
		match phase:
			1: _render_phase_clef_anchor()
			2: _render_phase_spotlight_or_peel()
			3: _render_phase_piano()
			4:
				_note_intro_phase = 0
				_render_phase_final_note()
	else:
		# Phases: 1=spotlight/peel, 2=piano, 3=final
		match phase:
			1: _render_phase_spotlight_or_peel()
			2: _render_phase_piano()
			3:
				_note_intro_phase = 0
				_render_phase_final_note()


# ---- Phase 1+2: Clef Anchor + Target Glow ----

func _render_phase_clef_anchor() -> void:
	var d := _note_intro_data
	var clef: String = d["clef"]
	var note_step: int = d["note_step"]

	var height := 200.0
	var extra_top := _note_intro_extra_top(note_step)
	height += extra_top if note_step < -2 else ((note_step - 10) * 10.0 if note_step > 10 else 0.0)

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	var lines: Array = staff["lines"]
	var clef_lbl: Label = staff["clef_label"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	_content_vbox.add_child(container)

	# Draw ledger lines if needed
	var note_x := line_x + line_w * 0.5
	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)

	# Target glow highlight
	var note_y := staff_top + note_step * (gap / 2.0)
	var is_on_line: bool = (note_step % 2 == 0)
	var highlight := _create_note_highlight(container, note_step, note_y, is_on_line, gap, line_x, line_w, lines, extra_top, staff_top)

	# Add instruction label
	var clef_name := "Treble" if clef == "treble" else "Bass"
	var anchor_note := "G" if clef == "treble" else "F"
	var instruction := Label.new()
	instruction.text = "This is the %s Clef  --  it marks the %s line" % [clef_name, anchor_note]
	instruction.add_theme_font_override("font", FONT_BODY)
	instruction.add_theme_font_size_override("font_size", 14)
	instruction.add_theme_color_override("font_color", TEXT_MUTED)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(instruction)

	# Animate: clef blink + target glow simultaneously
	if clef_lbl != null:
		# Gold glow behind clef
		var glow := ColorRect.new()
		glow.color = Color(0.91, 0.63, 0.13, 0.35)
		glow.size = Vector2(40, 60)
		glow.position = clef_lbl.position + Vector2(-5, 5)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.modulate.a = 0.0
		# Add glow behind clef (insert before clef label)
		var clef_idx := clef_lbl.get_index()
		container.add_child(glow)
		container.move_child(glow, clef_idx)

		var tw := container.create_tween()
		# Clef glow + scale blink (2 cycles)
		tw.set_parallel(true)
		tw.tween_property(glow, "modulate:a", 0.8, 0.3)
		tw.chain().tween_property(glow, "modulate:a", 0.2, 0.3)
		tw.chain().tween_property(glow, "modulate:a", 0.8, 0.3)
		tw.chain().tween_property(glow, "modulate:a", 0.2, 0.3)
		tw.chain().tween_property(glow, "modulate:a", 0.6, 0.3)

		# Target highlight fade in simultaneously
		if highlight != null:
			var tw2 := container.create_tween()
			tw2.tween_property(highlight, "modulate:a", 1.0, 0.4).set_delay(0.6)
			tw2.tween_property(highlight, "modulate:a", 0.5, 0.4)
			tw2.tween_property(highlight, "modulate:a", 1.0, 0.4)

	_note_intro_first_note_done = true


# ---- Phase 3: Spotlight or Peel-Away ----

func _render_phase_spotlight_or_peel() -> void:
	if _note_intro_phase3_variant == 0:
		_render_phase_spotlight()
	else:
		_render_phase_peel_away()


func _render_phase_spotlight() -> void:
	var d := _note_intro_data
	var clef: String = d["clef"]
	var note_step: int = d["note_step"]
	var note_name: String = d["note_name"]

	var height := 200.0
	var extra_top := _note_intro_extra_top(note_step)
	height += extra_top if note_step < -2 else ((note_step - 10) * 10.0 if note_step > 10 else 0.0)

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	var lines: Array = staff["lines"]
	var clef_lbl: Label = staff["clef_label"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	_content_vbox.add_child(container)

	var note_y := staff_top + note_step * (gap / 2.0)
	var is_on_line: bool = (note_step % 2 == 0)

	# Dim ALL staff lines + clef
	for line in lines:
		line.modulate.a = 0.15
	if clef_lbl != null:
		clef_lbl.modulate.a = 0.2

	# Draw ledger lines if needed (also dimmed initially)
	var note_x := line_x + line_w * 0.5
	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)

	# Restore target lines
	if is_on_line:
		var line_idx: int = note_step / 2
		if line_idx >= 0 and line_idx < lines.size():
			lines[line_idx].modulate.a = 1.0
			lines[line_idx].size.y = 3.0
			lines[line_idx].color = Color(0.50, 0.32, 0.72, 0.85)
		# For ledger line notes, restore the ledger lines we just drew
		if note_step >= 10 or note_step <= -2:
			for child in container.get_children():
				if child is ColorRect and child.size.x == 30 and child.size.y == 1.5:
					child.modulate.a = 1.0
					child.size.y = 2.5
					child.color = Color(0.50, 0.32, 0.72, 0.85)
	else:
		var space_idx: int = (note_step - 1) / 2
		if space_idx >= 0 and space_idx < lines.size():
			lines[space_idx].modulate.a = 1.0
			lines[space_idx].size.y = 3.0
			lines[space_idx].color = Color(0.50, 0.32, 0.72, 0.85)
		if space_idx + 1 >= 0 and space_idx + 1 < lines.size():
			lines[space_idx + 1].modulate.a = 1.0
			lines[space_idx + 1].size.y = 3.0
			lines[space_idx + 1].color = Color(0.50, 0.32, 0.72, 0.85)

	# Position label ---- "2nd line", "top space", etc.
	var pos_text := _note_position_text(clef, note_step)
	var pos_lbl := Label.new()
	pos_lbl.text = "->  %s   -- " % pos_text
	pos_lbl.add_theme_font_override("font", FONT_TITLE)
	pos_lbl.add_theme_font_size_override("font_size", 16)
	pos_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0, 1.0))
	pos_lbl.position = Vector2(line_x + line_w * 0.5 - 60, note_y + 14)
	pos_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_lbl.modulate.a = 0.0
	container.add_child(pos_lbl)

	# Highlight the target
	var highlight := _create_note_highlight(container, note_step, note_y, is_on_line, gap, line_x, line_w, lines, extra_top, staff_top)

	# Animate fade-ins
	var tw := container.create_tween()
	if highlight != null:
		tw.tween_property(highlight, "modulate:a", 1.0, 0.3)
	tw.tween_property(pos_lbl, "modulate:a", 1.0, 0.3)

	# Title below
	var title_lbl := Label.new()
	title_lbl.text = "%s sits on the %s" % [note_name, pos_text]
	title_lbl.add_theme_font_override("font", FONT_BODY)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(title_lbl)


func _render_phase_peel_away() -> void:
	var d := _note_intro_data
	var clef: String = d["clef"]
	var note_step: int = d["note_step"]
	var note_name: String = d["note_name"]
	var note_color: Color = d["note_color"]

	var height := 200.0
	var extra_top := _note_intro_extra_top(note_step)
	height += extra_top if note_step < -2 else ((note_step - 10) * 10.0 if note_step > 10 else 0.0)

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	var lines: Array = staff["lines"]
	var clef_lbl: Label = staff["clef_label"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	_content_vbox.add_child(container)

	var note_x := line_x + line_w * 0.5
	var note_y := staff_top + note_step * (gap / 2.0)
	var is_on_line: bool = (note_step % 2 == 0)

	# Draw ledger lines
	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)

	# Place note at correct position immediately (hidden at first)
	var head := _create_oval_notehead(note_color)
	var head_w: float = head.size.x
	var head_h: float = head.size.y
	var final_pos := Vector2(note_x - head_w / 2.0, note_y - head_h / 2.0)
	head.position = final_pos
	head.modulate.a = 0.0
	container.add_child(head)

	# Note name label (hidden at first)
	var lbl_bg := _create_note_name_pill(d["note_name"])
	lbl_bg.position = Vector2(final_pos.x + head_w / 2.0 - 10, final_pos.y + head_h + 2)
	lbl_bg.modulate.a = 0.0
	container.add_child(lbl_bg)

	# Determine which lines to keep
	var keep_indices: Array[int] = []
	if is_on_line:
		var line_idx: int = note_step / 2
		if line_idx >= 0 and line_idx < lines.size():
			keep_indices.append(line_idx)
	else:
		var space_idx: int = (note_step - 1) / 2
		if space_idx >= 0 and space_idx < lines.size():
			keep_indices.append(space_idx)
		if space_idx + 1 >= 0 and space_idx + 1 < lines.size():
			keep_indices.append(space_idx + 1)

	# Animate: peel away non-target lines, show note, then restore
	var tw := container.create_tween()
	# Phase A: dim non-target lines + clef (0.5s)
	for i in lines.size():
		if i not in keep_indices:
			tw.parallel().tween_property(lines[i], "modulate:a", 0.12, 0.5)
	if clef_lbl != null:
		tw.parallel().tween_property(clef_lbl, "modulate:a", 0.2, 0.5)
	# Bold target lines
	for idx in keep_indices:
		tw.parallel().tween_property(lines[idx], "size:y", 3.0, 0.3)

	# Phase B: show note (fade in)
	tw.tween_property(head, "modulate:a", 1.0, 0.3)
	tw.tween_property(lbl_bg, "modulate:a", 1.0, 0.2)

	# Phase C: hold 1.0s then restore
	tw.tween_interval(1.0)
	for i in lines.size():
		if i not in keep_indices:
			tw.parallel().tween_property(lines[i], "modulate:a", 1.0, 0.5)
	if clef_lbl != null:
		tw.parallel().tween_property(clef_lbl, "modulate:a", 1.0, 0.5)

	# Position text
	var pos_text := _note_position_text(clef, note_step)
	var title_lbl := Label.new()
	title_lbl.text = "%s sits on the %s" % [note_name, pos_text]
	title_lbl.add_theme_font_override("font", FONT_BODY)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(title_lbl)


# ---- Phase 4: Piano Split-Screen ----

func _render_phase_piano() -> void:
	var d := _note_intro_data
	var clef: String = d["clef"]
	var note_step: int = d["note_step"]
	var note_name: String = d["note_name"]
	var note_color: Color = d["note_color"]
	var full_note_id: String = d["full_note_id"]

	# Split-screen: piano (left) + staff (right)
	var split := HBoxContainer.new()
	split.alignment = BoxContainer.ALIGNMENT_CENTER
	split.add_theme_constant_override("separation", 12)
	split.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(split)

	# ---- Build piano ----
	var piano_result := _build_piano_keyboard(clef, full_note_id, note_color)
	var piano_container: Control = piano_result["container"]
	split.add_child(piano_container)

	# ---- Build small staff with note ----
	var height := 160.0
	var extra_top := _note_intro_extra_top(note_step)
	height += extra_top if note_step < -2 else ((note_step - 10) * 10.0 if note_step > 10 else 0.0)

	var staff := _create_teaching_staff(clef, 200.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	split.add_child(container)

	# Draw ledger lines
	var note_x := line_x + line_w * 0.5
	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)

	# Place note
	var note_y := staff_top + note_step * (gap / 2.0)
	var head := _create_oval_notehead(note_color)
	var head_w: float = head.size.x
	var head_h: float = head.size.y
	var final_pos := Vector2(note_x - head_w / 2.0, note_y - head_h / 2.0)
	head.position = final_pos
	head.modulate.a = 0.0
	container.add_child(head)

	# Note label
	var lbl_bg := _create_note_name_pill(note_name)
	lbl_bg.position = Vector2(final_pos.x + head_w / 2.0 - 10, final_pos.y + head_h + 2)
	lbl_bg.modulate.a = 0.0
	container.add_child(lbl_bg)

	# ---- Arc overlay ---- drawn on top of the split container ----
	# We use a Control overlay that spans the split
	var arc_overlay := Control.new()
	arc_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	arc_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc_overlay.z_index = 10
	split.add_child(arc_overlay)

	var arc_line := Line2D.new()
	arc_line.width = 2.5
	arc_line.default_color = ACCENT_GOLD
	arc_line.z_index = 10
	arc_overlay.add_child(arc_line)

	# We need to compute arc positions after a frame so layout is finalized
	var captured_piano_result := piano_result
	var captured_head := head
	var captured_lbl_bg := lbl_bg
	var captured_arc_line := arc_line
	var captured_arc_overlay := arc_overlay
	var captured_split := split
	var captured_note_id := full_note_id
	var captured_container := container
	var captured_final_pos := final_pos

	# Defer arc animation to next frame when positions are computed
	await get_tree().process_frame
	await get_tree().process_frame  # two frames for layout settle

	if not is_instance_valid(self) or not is_instance_valid(captured_split):
		return

	# Get the piano key position (relative to split)
	var key_local: Vector2 = captured_piano_result.get("target_key_local", Vector2.ZERO)
	var key_global: Vector2 = captured_piano_result["container"].global_position + key_local
	var note_global := captured_head.global_position + Vector2(captured_head.size.x / 2.0, captured_head.size.y / 2.0)

	# Convert to arc_overlay local coords (Control has no to_local ---- subtract global_position)
	var overlay_origin: Vector2 = captured_arc_overlay.global_position
	var arc_start: Vector2 = key_global - overlay_origin
	var arc_end: Vector2 = note_global - overlay_origin

	# Generate bezier arc points
	var arc_points := _compute_bezier_arc(arc_start, arc_end, 25)

	# Animate arc progressively
	var tw := create_tween()
	tw.tween_method(func(count: int):
		if is_instance_valid(captured_arc_line):
			var pts := PackedVector2Array()
			for ii in mini(count, arc_points.size()):
				pts.append(arc_points[ii])
			captured_arc_line.points = pts
	, 0, arc_points.size(), 0.8)

	# After arc: show note + play sound
	tw.tween_property(captured_head, "modulate:a", 1.0, 0.2)
	tw.tween_property(captured_lbl_bg, "modulate:a", 1.0, 0.2)

	if captured_note_id != "":
		tw.tween_callback(func():
			if is_instance_valid(self):
				_play_note_audio_immediate(captured_note_id)
		)

	# Piano + arc stay visible ---- they fade when user taps Next (content cleared)

	# Connection label
	var conn_lbl := Label.new()
	conn_lbl.text = "See it on the keyboard → hear it → read it on the staff"
	conn_lbl.add_theme_font_override("font", FONT_BODY)
	conn_lbl.add_theme_font_size_override("font_size", 13)
	conn_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	conn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conn_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(conn_lbl)


# ---- Final Phase: Note on Staff with Idle Bob + Replay ----

func _render_phase_final_note() -> void:
	var d := _note_intro_data
	var clef: String = d["clef"]
	var note_step: int = d["note_step"]
	var note_name: String = d["note_name"]
	var note_color: Color = d["note_color"]
	var full_note_id: String = d["full_note_id"]

	var height := 200.0
	var extra_top := _note_intro_extra_top(note_step)
	height += extra_top if note_step < -2 else ((note_step - 10) * 10.0 if note_step > 10 else 0.0)

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	var lines: Array = staff["lines"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	_content_vbox.add_child(container)

	var note_x := line_x + line_w * 0.5
	var note_y := staff_top + note_step * (gap / 2.0)
	var is_on_line: bool = (note_step % 2 == 0)

	# Bold target lines
	if is_on_line:
		var line_idx: int = note_step / 2
		if line_idx >= 0 and line_idx < lines.size():
			lines[line_idx].size.y = 3.0
			lines[line_idx].color = Color(0.50, 0.32, 0.72, 0.85)
	else:
		var space_idx: int = (note_step - 1) / 2
		if space_idx >= 0 and space_idx < lines.size():
			lines[space_idx].size.y = 3.0
			lines[space_idx].color = Color(0.50, 0.32, 0.72, 0.85)
		if space_idx + 1 >= 0 and space_idx + 1 < lines.size():
			lines[space_idx + 1].size.y = 3.0
			lines[space_idx + 1].color = Color(0.50, 0.32, 0.72, 0.85)

	# Highlight
	var highlight := _create_note_highlight(container, note_step, note_y, is_on_line, gap, line_x, line_w, lines, extra_top, staff_top)

	# Ledger lines
	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)

	# Note head at final position
	var head := _create_oval_notehead(note_color)
	var head_w: float = head.size.x
	var head_h: float = head.size.y
	var final_pos := Vector2(note_x - head_w / 2.0, note_y - head_h / 2.0)
	head.position = final_pos
	container.add_child(head)

	# Note name label
	var lbl_bg := _create_note_name_pill(note_name)
	lbl_bg.position = Vector2(final_pos.x + head_w / 2.0 - 10, final_pos.y + head_h + 2)
	container.add_child(lbl_bg)

	# Highlight glow
	if highlight != null:
		highlight.modulate.a = 0.7

	# Play audio
	if full_note_id != "":
		var captured_id := full_note_id
		_play_note_audio(captured_id)

	# Idle bob
	var bob_tw := container.create_tween()
	bob_tw.set_loops()
	bob_tw.tween_property(head, "position:y", final_pos.y - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
	bob_tw.tween_property(head, "position:y", final_pos.y + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Replay button
	if full_note_id != "":
		var replay_row := HBoxContainer.new()
		replay_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_content_vbox.add_child(replay_row)
		var replay := Button.new()
		replay.text = " --  Hear it"
		replay.add_theme_font_override("font", FONT_BODY)
		replay.add_theme_font_size_override("font_size", 14)
		replay.custom_minimum_size = Vector2(100, 32)
		_style_flat_button(replay)
		replay.add_theme_color_override("font_color", ACCENT_GOLD)
		var captured_id2 := full_note_id
		replay.pressed.connect(func(): _play_note_audio(captured_id2))
		replay_row.add_child(replay)


# ---- Helpers ----

func _note_intro_extra_top(note_step: int) -> float:
	if note_step < -2:
		return absf(note_step + 2) * 10.0
	return 0.0


func _create_note_highlight(container: Control, note_step: int, note_y: float, is_on_line: bool, gap: float, line_x: float, line_w: float, lines: Array, extra_top: float, staff_top: float) -> ColorRect:
	var highlight: ColorRect = null
	if is_on_line:
		var line_idx: int = note_step / 2
		var ly: float = note_y
		if line_idx >= 0 and line_idx < lines.size():
			if extra_top == 0:
				ly = lines[line_idx].position.y
		highlight = ColorRect.new()
		highlight.color = Color(0.62, 0.42, 0.85, 0.40)
		highlight.size = Vector2(line_w, 4.0)
		highlight.position = Vector2(line_x, ly - 1.5)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.modulate.a = 0.0
		container.add_child(highlight)
	else:
		var space_top_y: float = note_y - gap * 0.4
		highlight = ColorRect.new()
		highlight.color = Color(0.58, 0.38, 0.82, 0.22)
		highlight.size = Vector2(line_w, gap * 0.8)
		highlight.position = Vector2(line_x, space_top_y)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		highlight.modulate.a = 0.0
		container.add_child(highlight)
	return highlight


func _create_note_name_pill(note_name: String) -> PanelContainer:
	var lbl_bg := PanelContainer.new()
	var lbl_sb := StyleBoxFlat.new()
	lbl_sb.bg_color = Color(0.06, 0.10, 0.18, 0.88)
	lbl_sb.corner_radius_top_left = 6
	lbl_sb.corner_radius_top_right = 6
	lbl_sb.corner_radius_bottom_left = 6
	lbl_sb.corner_radius_bottom_right = 6
	lbl_sb.content_margin_left = 5
	lbl_sb.content_margin_right = 5
	lbl_sb.content_margin_top = 1
	lbl_sb.content_margin_bottom = 1
	lbl_bg.add_theme_stylebox_override("panel", lbl_sb)
	lbl_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = note_name
	lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bg.add_child(lbl)
	return lbl_bg


func _get_note_audio_stream(note_id: String) -> AudioStream:
	if note_id.is_empty():
		return null
	if _note_stream_cache.has(note_id):
		return _note_stream_cache[note_id] as AudioStream
	var midi: int = LMD.note_id_to_midi(note_id)
	if midi < 0:
		return null
	var file_idx: int = midi - PIANO_BASE_MIDI + 1
	if file_idx < 1 or file_idx > 88:
		return null
	var path := "%s/%d.mp3" % [PIANO_DIR, file_idx]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_note_stream_cache[note_id] = stream
	return stream


func _preload_note_audio_streams(note_ids: Array) -> void:
	for note_id_variant in note_ids:
		_get_note_audio_stream(str(note_id_variant))


func _play_note_audio_immediate(note_id: String) -> void:
	if _note_player == null:
		return
	var stream := _get_note_audio_stream(note_id)
	if stream == null:
		return
	_note_player.stream = stream
	_note_player.play()


func _compute_bezier_arc(start: Vector2, end: Vector2, count: int) -> Array:
	# Quadratic bezier: control point is midpoint raised 50px
	var mid := (start + end) / 2.0
	var control := mid + Vector2(0, -50)
	var points: Array = []
	for i in count:
		var t: float = float(i) / float(count - 1)
		var p: Vector2 = (1 - t) * (1 - t) * start + 2 * (1 - t) * t * control + t * t * end
		points.append(p)
	return points


# ---- Piano Keyboard Builder ----

func _build_piano_keyboard(clef: String, target_note_id: String, highlight_color: Color) -> Dictionary:
	# Determine range
	var start_midi: int
	var end_midi: int
	if clef == "treble":
		start_midi = LMD.note_id_to_midi("A3")   # 57
		end_midi = LMD.note_id_to_midi("C6")     # 84
	else:
		start_midi = LMD.note_id_to_midi("C2")   # 36
		end_midi = LMD.note_id_to_midi("E4")     # 64

	var target_midi: int = LMD.note_id_to_midi(target_note_id)
	var middle_c_midi: int = LMD.note_id_to_midi("C4")  # 60

	# Note name lookup
	var semitone_to_white := {0: true, 2: true, 4: true, 5: true, 7: true, 9: true, 11: true}
	var semitone_to_black := {1: true, 3: true, 6: true, 8: true, 10: true}

	# Count white keys
	var white_count := 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if semitone_to_white.has(s):
			white_count += 1

	# Piano container
	var piano_height := 120.0
	var piano_width := mini(white_count * 18, 380)
	var white_w: float = float(piano_width) / float(white_count)
	var black_w: float = white_w * 0.6
	var black_h: float = piano_height * 0.6

	var piano := Control.new()
	piano.custom_minimum_size = Vector2(piano_width, piano_height + 20)
	piano.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Draw white keys first, then black keys on top
	var white_index := 0
	var key_positions: Dictionary = {}  # midi -> global center Vector2
	var white_keys: Array = []
	var black_keys: Array = []

	# First pass: white keys
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if not semitone_to_white.has(s):
			continue
		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		var is_target: bool = (m == target_midi)
		var is_middle_c: bool = (m == middle_c_midi)

		if is_target:
			sb.bg_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.85)
		else:
			sb.bg_color = Color(0.97, 0.97, 0.95, 1.0)
		sb.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_width_top = 0
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		key.add_theme_stylebox_override("panel", sb)

		var kx: float = white_index * white_w
		key.position = Vector2(kx, 0)
		key.size = Vector2(white_w, piano_height)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(key)

		# Store center position
		key_positions[m] = Vector2(kx + white_w / 2.0, piano_height * 0.7)

		# Middle C label
		if is_middle_c:
			var c_lbl := Label.new()
			c_lbl.text = "C4"
			c_lbl.add_theme_font_size_override("font_size", 9)
			c_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 0.8) if not is_target else Color(1, 1, 1, 0.9))
			c_lbl.position = Vector2(kx + white_w / 2.0 - 7, piano_height + 2)
			c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(c_lbl)

		# Target note label on key
		if is_target and m != middle_c_midi:
			var t_lbl := Label.new()
			t_lbl.text = target_note_id
			t_lbl.add_theme_font_size_override("font_size", 9)
			t_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			t_lbl.position = Vector2(kx + white_w / 2.0 - 7, piano_height - 16)
			t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(t_lbl)

		white_keys.append({"midi": m, "panel": key, "x": kx})
		white_index += 1

	# Second pass: black keys
	white_index = 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if semitone_to_white.has(s):
			white_index += 1
			continue
		if not semitone_to_black.has(s):
			continue

		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		var is_target: bool = (m == target_midi)

		if is_target:
			sb.bg_color = Color(highlight_color.r * 0.8, highlight_color.g * 0.8, highlight_color.b * 0.8, 0.95)
		else:
			sb.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		key.add_theme_stylebox_override("panel", sb)

		# Position: centered between the white key before and the current white_index
		var kx: float = (white_index - 1) * white_w + white_w - black_w / 2.0
		key.position = Vector2(kx, 0)
		key.size = Vector2(black_w, black_h)
		key.z_index = 1
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(key)

		key_positions[m] = Vector2(kx + black_w / 2.0, black_h * 0.7)

	# Compute target key center in global coords (deferred ---- store local for now)
	var target_key_local: Vector2 = key_positions.get(target_midi, Vector2(piano_width / 2.0, piano_height / 2.0))

	# We return a dict; the caller will convert to global after layout
	# Store the piano node + local position; caller uses piano.global_position + local to get global
	return {
		"container": piano,
		"key_positions": key_positions,
		"target_key_local": target_key_local,
		"target_key_center": Vector2.ZERO,  # will be set after layout
		"target_midi": target_midi,
	}


func _build_interval_piano_keyboard(note1_id: String, note2_id: String, color1: Color, color2: Color) -> Control:
	# Piano keyboard highlighting two notes and tinting keys between them.
	# Range: C3-C6 (wide enough for all intervals taught).
	var start_midi: int = LMD.note_id_to_midi("C3")   # 48
	var end_midi: int = LMD.note_id_to_midi("C6")      # 84
	var midi1: int = LMD.note_id_to_midi(note1_id)
	var midi2: int = LMD.note_id_to_midi(note2_id)
	var lo_midi: int = mini(midi1, midi2)
	var hi_midi: int = maxi(midi1, midi2)
	var middle_c_midi: int = LMD.note_id_to_midi("C4")  # 60

	var semitone_to_white := {0: true, 2: true, 4: true, 5: true, 7: true, 9: true, 11: true}
	var semitone_to_black := {1: true, 3: true, 6: true, 8: true, 10: true}

	# Count white keys in range
	var white_count := 0
	for m in range(start_midi, end_midi + 1):
		if semitone_to_white.has(m % 12):
			white_count += 1

	# Dimensions
	var piano_height := 110.0
	var piano_width: float = mini(white_count * 16, 420)
	var white_w: float = float(piano_width) / float(white_count)
	var black_w: float = white_w * 0.6
	var black_h: float = piano_height * 0.6

	# Wrapper with centering
	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(0, piano_height + 28)

	var piano := Control.new()
	piano.custom_minimum_size = Vector2(piano_width, piano_height + 24)
	piano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(piano)

	var between_tint_white := Color(0.9, 0.8, 0.3, 0.15)
	var between_tint_black := Color(0.9, 0.8, 0.3, 0.10)

	# ---- White keys pass ----
	var white_index := 0
	var white_midi_to_x: Dictionary = {}
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if not semitone_to_white.has(s):
			continue
		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		var is_note1: bool = (m == midi1)
		var is_note2: bool = (m == midi2)
		var is_between: bool = (m > lo_midi and m < hi_midi)

		if is_note1:
			sb.bg_color = Color(color1.r, color1.g, color1.b, 0.85)
		elif is_note2:
			sb.bg_color = Color(color2.r, color2.g, color2.b, 0.85)
		elif is_between:
			sb.bg_color = Color(0.97, 0.97, 0.95, 1.0).lerp(between_tint_white, 0.55)
		else:
			sb.bg_color = Color(0.97, 0.97, 0.95, 1.0)
		sb.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_width_top = 0
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		key.add_theme_stylebox_override("panel", sb)

		var kx: float = white_index * white_w
		key.position = Vector2(kx, 0)
		key.size = Vector2(white_w, piano_height)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(key)
		white_midi_to_x[m] = kx

		# Note name label on highlighted keys
		if is_note1 or is_note2:
			var n_lbl := Label.new()
			n_lbl.text = note1_id if is_note1 else note2_id
			n_lbl.add_theme_font_size_override("font_size", 9)
			n_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
			n_lbl.position = Vector2(kx + white_w / 2.0 - 8, piano_height - 16)
			n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(n_lbl)

		# Middle C label (below key)
		if m == middle_c_midi:
			var c_lbl := Label.new()
			c_lbl.text = "C4"
			c_lbl.add_theme_font_size_override("font_size", 9)
			var c_col := Color(1, 1, 1, 0.9) if (is_note1 or is_note2) else Color(0.3, 0.3, 0.3, 0.8)
			c_lbl.add_theme_color_override("font_color", c_col)
			c_lbl.position = Vector2(kx + white_w / 2.0 - 7, piano_height + 2)
			c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(c_lbl)

		white_index += 1

	# ---- Black keys pass ----
	white_index = 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if semitone_to_white.has(s):
			white_index += 1
			continue
		if not semitone_to_black.has(s):
			continue

		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		var is_note1: bool = (m == midi1)
		var is_note2: bool = (m == midi2)
		var is_between: bool = (m > lo_midi and m < hi_midi)

		if is_note1:
			sb.bg_color = Color(color1.r * 0.8, color1.g * 0.8, color1.b * 0.8, 0.95)
		elif is_note2:
			sb.bg_color = Color(color2.r * 0.8, color2.g * 0.8, color2.b * 0.8, 0.95)
		elif is_between:
			sb.bg_color = Color(0.15, 0.15, 0.18, 1.0).lerp(between_tint_black, 0.35)
		else:
			sb.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		key.add_theme_stylebox_override("panel", sb)

		var kx: float = (white_index - 1) * white_w + white_w - black_w / 2.0
		key.position = Vector2(kx, 0)
		key.size = Vector2(black_w, black_h)
		key.z_index = 1
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(key)

		# Label on highlighted black keys
		if is_note1 or is_note2:
			var n_lbl := Label.new()
			n_lbl.text = note1_id if is_note1 else note2_id
			n_lbl.add_theme_font_size_override("font_size", 8)
			n_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			n_lbl.position = Vector2(kx + black_w / 2.0 - 8, black_h - 14)
			n_lbl.z_index = 2
			n_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(n_lbl)

	return wrapper


# ---- Keyboard Visual Helpers (Sharps & Flats module) ----

func _build_half_step_piano(note_natural: String, note_altered: String, highlight_natural_color: Color, highlight_altered_color: Color) -> Dictionary:
	# Build a compact C3-C5 piano with TWO highlighted keys.
	var start_midi: int = LMD.note_id_to_midi("C3")   # 48
	var end_midi: int = LMD.note_id_to_midi("C5")     # 72
	var natural_midi: int = LMD.note_id_to_midi(note_natural)
	var altered_midi: int = LMD.note_id_to_midi(note_altered)
	var middle_c_midi: int = LMD.note_id_to_midi("C4")

	var semitone_to_white := {0: true, 2: true, 4: true, 5: true, 7: true, 9: true, 11: true}
	var semitone_to_black := {1: true, 3: true, 6: true, 8: true, 10: true}

	var white_count := 0
	for m in range(start_midi, end_midi + 1):
		if semitone_to_white.has(m % 12):
			white_count += 1

	var piano_height := 110.0
	var piano_width: float = mini(white_count * 18, 400)
	var white_w: float = float(piano_width) / float(white_count)
	var black_w: float = white_w * 0.6
	var black_h: float = piano_height * 0.6

	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(0, piano_height + 24)

	var piano := Control.new()
	piano.custom_minimum_size = Vector2(piano_width, piano_height + 20)
	piano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(piano)

	var key_positions: Dictionary = {}
	var key_panels: Dictionary = {}  # midi -> Panel

	# White keys
	var white_index := 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if not semitone_to_white.has(s):
			continue
		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		if m == natural_midi:
			sb.bg_color = Color(highlight_natural_color.r, highlight_natural_color.g, highlight_natural_color.b, 0.85)
		elif m == altered_midi:
			sb.bg_color = Color(highlight_altered_color.r, highlight_altered_color.g, highlight_altered_color.b, 0.85)
		else:
			sb.bg_color = Color(0.97, 0.97, 0.95, 1.0)
		sb.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_width_top = 0
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		key.add_theme_stylebox_override("panel", sb)
		var kx: float = white_index * white_w
		key.position = Vector2(kx, 0)
		key.size = Vector2(white_w, piano_height)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(key)
		key_positions[m] = Vector2(kx + white_w / 2.0, piano_height * 0.7)
		key_panels[m] = key

		if m == middle_c_midi:
			var c_lbl := Label.new()
			c_lbl.text = "C4"
			c_lbl.add_theme_font_size_override("font_size", 9)
			c_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 0.8))
			c_lbl.position = Vector2(kx + white_w / 2.0 - 7, piano_height + 2)
			c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(c_lbl)
		white_index += 1

	# Black keys
	white_index = 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if semitone_to_white.has(s):
			white_index += 1
			continue
		if not semitone_to_black.has(s):
			continue
		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		if m == natural_midi:
			sb.bg_color = Color(highlight_natural_color.r * 0.8, highlight_natural_color.g * 0.8, highlight_natural_color.b * 0.8, 0.95)
		elif m == altered_midi:
			sb.bg_color = Color(highlight_altered_color.r * 0.8, highlight_altered_color.g * 0.8, highlight_altered_color.b * 0.8, 0.95)
		else:
			sb.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		key.add_theme_stylebox_override("panel", sb)
		var kx: float = (white_index - 1) * white_w + white_w - black_w / 2.0
		key.position = Vector2(kx, 0)
		key.size = Vector2(black_w, black_h)
		key.z_index = 1
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(key)
		key_positions[m] = Vector2(kx + black_w / 2.0, black_h * 0.7)
		key_panels[m] = key

	return {"wrapper": wrapper, "piano": piano, "key_positions": key_positions, "key_panels": key_panels,
		"piano_height": piano_height, "piano_width": piano_width, "white_w": white_w, "black_w": black_w, "black_h": black_h}


func _build_interactive_piano(start_midi: int, end_midi: int) -> Dictionary:
	# Build a C3-C5 piano where ALL keys are clickable (MOUSE_FILTER_STOP).
	# Returns: wrapper, piano, key_panels (midi->Panel), key_positions (midi->Vector2)
	var semitone_to_white := {0: true, 2: true, 4: true, 5: true, 7: true, 9: true, 11: true}
	var semitone_to_black := {1: true, 3: true, 6: true, 8: true, 10: true}
	var middle_c_midi: int = LMD.note_id_to_midi("C4")

	var white_count := 0
	for m in range(start_midi, end_midi + 1):
		if semitone_to_white.has(m % 12):
			white_count += 1

	var piano_height := 120.0
	var piano_width: float = mini(white_count * 18, 420)
	var white_w: float = float(piano_width) / float(white_count)
	var black_w: float = white_w * 0.6
	var black_h: float = piano_height * 0.6

	var wrapper := CenterContainer.new()
	wrapper.custom_minimum_size = Vector2(0, piano_height + 24)

	var piano := Control.new()
	piano.custom_minimum_size = Vector2(piano_width, piano_height + 20)
	piano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(piano)

	var key_positions: Dictionary = {}
	var key_panels: Dictionary = {}

	# White keys
	var white_index := 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if not semitone_to_white.has(s):
			continue
		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.97, 0.95, 1.0)
		sb.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_width_top = 0
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		key.add_theme_stylebox_override("panel", sb)
		var kx: float = white_index * white_w
		key.position = Vector2(kx, 0)
		key.size = Vector2(white_w, piano_height)
		key.mouse_filter = Control.MOUSE_FILTER_STOP
		piano.add_child(key)
		key_positions[m] = Vector2(kx + white_w / 2.0, piano_height * 0.7)
		key_panels[m] = key

		if m == middle_c_midi:
			var c_lbl := Label.new()
			c_lbl.text = "C4"
			c_lbl.add_theme_font_size_override("font_size", 9)
			c_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 0.8))
			c_lbl.position = Vector2(kx + white_w / 2.0 - 7, piano_height + 2)
			c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piano.add_child(c_lbl)
		white_index += 1

	# Black keys (on top, also clickable)
	white_index = 0
	for m in range(start_midi, end_midi + 1):
		var s: int = m % 12
		if semitone_to_white.has(s):
			white_index += 1
			continue
		if not semitone_to_black.has(s):
			continue
		var key := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		key.add_theme_stylebox_override("panel", sb)
		var kx: float = (white_index - 1) * white_w + white_w - black_w / 2.0
		key.position = Vector2(kx, 0)
		key.size = Vector2(black_w, black_h)
		key.z_index = 1
		key.mouse_filter = Control.MOUSE_FILTER_STOP
		piano.add_child(key)
		key_positions[m] = Vector2(kx + black_w / 2.0, black_h * 0.7)
		key_panels[m] = key

	return {"wrapper": wrapper, "piano": piano, "key_positions": key_positions, "key_panels": key_panels,
		"piano_height": piano_height, "piano_width": piano_width}


func _draw_keyboard_half_step(visual_data: Dictionary) -> void:
	var note_natural: String = visual_data.get("note_natural", "F4")
	var note_altered: String = visual_data.get("note_altered", "F#4")
	var direction: String = visual_data.get("direction", "up")

	var blue := Color(0.30, 0.55, 0.90, 0.85)
	var gold := Color(0.91, 0.63, 0.13, 0.85)

	var result := _build_half_step_piano(note_natural, note_altered, blue, gold)
	var wrapper: CenterContainer = result["wrapper"]
	var piano: Control = result["piano"]
	var key_positions: Dictionary = result["key_positions"]
	_content_vbox.add_child(wrapper)

	# Arrow between the two highlighted keys
	var nat_midi: int = LMD.note_id_to_midi(note_natural)
	var alt_midi: int = LMD.note_id_to_midi(note_altered)
	var nat_pos: Vector2 = key_positions.get(nat_midi, Vector2.ZERO)
	var alt_pos: Vector2 = key_positions.get(alt_midi, Vector2.ZERO)
	if nat_pos != Vector2.ZERO and alt_pos != Vector2.ZERO:
		var arrow_lbl := Label.new()
		if direction == "up":
			arrow_lbl.text = ">"
		else:
			arrow_lbl.text = "<"
		arrow_lbl.add_theme_font_override("font", FONT_TITLE)
		arrow_lbl.add_theme_font_size_override("font_size", 22)
		arrow_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		var mid_pos: Vector2 = (nat_pos + alt_pos) / 2.0
		arrow_lbl.position = Vector2(mid_pos.x - 6, mid_pos.y - 14)
		arrow_lbl.z_index = 2
		arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(arrow_lbl)

	# Description label
	var nat_name: String = note_natural.replace("4", "").replace("3", "").replace("5", "")
	var alt_name: String = note_altered.replace("4", "").replace("3", "").replace("5", "")
	var dir_word: String = "UP" if direction == "up" else "DOWN"
	var desc := Label.new()
	desc.text = "%s  >  %s: one half step %s" % [nat_name, alt_name, dir_word]
	desc.add_theme_font_override("font", FONT_TITLE)
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", ACCENT_GOLD)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(desc)

	# Auto-play both notes
	_play_note_audio_immediate(note_natural)
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		_play_note_audio_immediate(note_altered)


func _draw_keyboard_enharmonic(visual_data: Dictionary) -> void:
	var note_id: String = visual_data.get("note_id", "F#4")
	var name1: String = visual_data.get("name1", "F#")
	var name2: String = visual_data.get("name2", "Gb")

	var gold := Color(0.91, 0.63, 0.13, 0.85)
	# Build a piano with one highlighted key ---- use the half-step builder with both targets same
	var result := _build_half_step_piano(note_id, note_id, gold, gold)
	var wrapper: CenterContainer = result["wrapper"]
	var piano: Control = result["piano"]
	var key_positions: Dictionary = result["key_positions"]
	_content_vbox.add_child(wrapper)

	var target_midi: int = LMD.note_id_to_midi(note_id)
	var target_pos: Vector2 = key_positions.get(target_midi, Vector2.ZERO)

	if target_pos != Vector2.ZERO:
		# Name1 label (left)
		var lbl1 := Label.new()
		lbl1.text = name1 + " >"
		lbl1.add_theme_font_override("font", FONT_TITLE)
		lbl1.add_theme_font_size_override("font_size", 14)
		lbl1.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
		lbl1.position = Vector2(target_pos.x - 48, target_pos.y - 24)
		lbl1.z_index = 2
		lbl1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(lbl1)

		# Name2 label (right)
		var lbl2 := Label.new()
		lbl2.text = "< " + name2
		lbl2.add_theme_font_override("font", FONT_TITLE)
		lbl2.add_theme_font_size_override("font_size", 14)
		lbl2.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
		lbl2.position = Vector2(target_pos.x + 10, target_pos.y - 24)
		lbl2.z_index = 2
		lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piano.add_child(lbl2)

	# Message below
	var msg := Label.new()
	msg.text = "Same key, same sound -- two different names!"
	msg.add_theme_font_override("font", FONT_TITLE)
	msg.add_theme_font_size_override("font_size", 18)
	msg.add_theme_color_override("font_color", ACCENT_GOLD)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(msg)

	# Auto-play the note
	_play_note_audio_immediate(note_id)


func _draw_keyboard_natural_reset(visual_data: Dictionary) -> void:
	var note_natural: String = visual_data.get("note_natural", "F4")
	var note_altered: String = visual_data.get("note_altered", "F#4")

	var blue := Color(0.30, 0.55, 0.90, 0.85)
	var gold := Color(0.91, 0.63, 0.13, 0.85)
	var green := Color(0.30, 0.78, 0.40, 0.85)
	var dim := Color(0.70, 0.70, 0.68, 1.0)

	# Build piano ---- initially highlight natural in blue
	var result := _build_half_step_piano(note_natural, "", blue, gold)
	var wrapper: CenterContainer = result["wrapper"]
	var key_panels: Dictionary = result["key_panels"]
	_content_vbox.add_child(wrapper)

	var nat_midi: int = LMD.note_id_to_midi(note_natural)
	var alt_midi: int = LMD.note_id_to_midi(note_altered)
	var nat_panel: Panel = key_panels.get(nat_midi)
	var alt_panel: Panel = key_panels.get(alt_midi)

	# Determine natural name for label
	var nat_name: String = note_natural.replace("4", "").replace("3", "").replace("5", "")
	var alt_name: String = note_altered.replace("4", "").replace("3", "").replace("5", "")
	var is_sharp: bool = note_altered.find("#") >= 0

	# Description label
	var desc := Label.new()
	if is_sharp:
		desc.text = "%s > %s > %s%s (natural cancels the sharp)" % [nat_name, alt_name, nat_name, "\u266e"]
	else:
		desc.text = "%s > %s > %s%s (natural cancels the flat)" % [nat_name, alt_name, nat_name, "\u266e"]
	desc.add_theme_font_override("font", FONT_TITLE)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", ACCENT_GOLD)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(desc)

	# Phase 1: Natural key highlighted (blue), play natural
	_play_note_audio_immediate(note_natural)

	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return

	# Phase 2: Highlight altered key (gold), dim natural
	if nat_panel != null:
		var sb_nat := StyleBoxFlat.new()
		sb_nat.bg_color = dim
		sb_nat.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb_nat.border_width_left = 1
		sb_nat.border_width_right = 1
		sb_nat.border_width_bottom = 1
		sb_nat.corner_radius_bottom_left = 3
		sb_nat.corner_radius_bottom_right = 3
		nat_panel.add_theme_stylebox_override("panel", sb_nat)

	if alt_panel != null:
		var sb_alt := StyleBoxFlat.new()
		var semitone_to_white := {0: true, 2: true, 4: true, 5: true, 7: true, 9: true, 11: true}
		var is_white: bool = semitone_to_white.has(alt_midi % 12)
		if is_white:
			sb_alt.bg_color = Color(gold.r, gold.g, gold.b, 0.85)
		else:
			sb_alt.bg_color = Color(gold.r * 0.8, gold.g * 0.8, gold.b * 0.8, 0.95)
		sb_alt.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb_alt.border_width_left = 1
		sb_alt.border_width_right = 1
		sb_alt.border_width_bottom = 1
		sb_alt.corner_radius_bottom_left = 2
		sb_alt.corner_radius_bottom_right = 2
		alt_panel.add_theme_stylebox_override("panel", sb_alt)

	_play_note_audio_immediate(note_altered)

	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return

	# Phase 3: Re-highlight natural (green = restored), dim altered
	if alt_panel != null:
		var sb_dim := StyleBoxFlat.new()
		var semitone_to_white2 := {0: true, 2: true, 4: true, 5: true, 7: true, 9: true, 11: true}
		var is_white2: bool = semitone_to_white2.has(alt_midi % 12)
		if is_white2:
			sb_dim.bg_color = dim
		else:
			sb_dim.bg_color = Color(0.15, 0.15, 0.18, 1.0)
		sb_dim.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb_dim.border_width_left = 1
		sb_dim.border_width_right = 1
		sb_dim.border_width_bottom = 1
		sb_dim.corner_radius_bottom_left = 2
		sb_dim.corner_radius_bottom_right = 2
		alt_panel.add_theme_stylebox_override("panel", sb_dim)

	if nat_panel != null:
		var sb_green := StyleBoxFlat.new()
		sb_green.bg_color = Color(green.r, green.g, green.b, 0.85)
		sb_green.border_color = Color(0.45, 0.45, 0.45, 0.6)
		sb_green.border_width_left = 1
		sb_green.border_width_right = 1
		sb_green.border_width_bottom = 1
		sb_green.corner_radius_bottom_left = 3
		sb_green.corner_radius_bottom_right = 3
		nat_panel.add_theme_stylebox_override("panel", sb_green)

	_play_note_audio_immediate(note_natural)


func _render_keyboard_quiz_step(step: Dictionary) -> void:
	_quiz_answered = false
	_quiz_correct = false
	_quiz_attempts_this_step = 0

	var clef: String = step.get("clef", "treble")
	var note_id_on_staff: String = step.get("note_id_on_staff", "F#4")
	var note_step: int = step.get("note_step", 7)
	var target_note_id: String = step.get("target_note_id", "F#4")
	var accidental: String = step.get("accidental", "")
	var chicken_correct: String = step.get("chicken_correct", "")
	var chicken_wrong: String = step.get("chicken_wrong", "")
	if chicken_correct.is_empty():
		chicken_correct = "That's the right key!"
	if chicken_wrong.is_empty():
		chicken_wrong = "Not quite -- try another key!"

	# Title
	var title := Label.new()
	title.text = "Find this note on the keyboard!"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	# Staff with note
	var height := 140.0
	var staff := _create_teaching_staff(clef, 300.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	_content_vbox.add_child(container)

	var note_x := line_x + line_w * 0.5
	var note_y := staff_top + note_step * (gap / 2.0)
	var head := _create_oval_notehead(_pick_note_head_color())
	head.position = Vector2(note_x - 11, note_y - 7)
	container.add_child(head)
	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)

	# Accidental symbol
	if accidental != "":
		var acc_lbl := Label.new()
		if accidental == "sharp":
			acc_lbl.text = "#"
		elif accidental == "flat":
			acc_lbl.text = "b"
		elif accidental == "natural":
			acc_lbl.text = "\u266e"
		acc_lbl.add_theme_font_override("font", FONT_TITLE)
		acc_lbl.add_theme_font_size_override("font_size", 20)
		acc_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.9))
		acc_lbl.position = Vector2(note_x - 28, note_y - 12)
		acc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(acc_lbl)

	# Note name label below staff
	var name_lbl := Label.new()
	name_lbl.text = note_id_on_staff
	name_lbl.add_theme_font_override("font", FONT_TITLE)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.30, 0.30, 0.36, 0.80))
	name_lbl.position = Vector2(note_x - 12, staff_top + 5 * gap + 6)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_lbl)

	# Build interactive piano (C3-C5)
	var start_midi: int = LMD.note_id_to_midi("C3")
	var end_midi: int = LMD.note_id_to_midi("C5")
	var piano_result := _build_interactive_piano(start_midi, end_midi)
	var piano_wrapper: CenterContainer = piano_result["wrapper"]
	var key_panels: Dictionary = piano_result["key_panels"]
	_content_vbox.add_child(piano_wrapper)

	var target_midi: int = LMD.note_id_to_midi(target_note_id)

	# Hint / feedback label
	var feedback_lbl := Label.new()
	feedback_lbl.text = ""
	feedback_lbl.add_theme_font_override("font", FONT_BODY)
	feedback_lbl.add_theme_font_size_override("font_size", 15)
	feedback_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(feedback_lbl)

	# Connect gui_input to each key
	for midi_val in key_panels:
		var panel: Panel = key_panels[midi_val]
		var captured_midi: int = midi_val
		panel.gui_input.connect(func(event: InputEvent):
			if _quiz_correct or (_test_out_mode and _quiz_answered):
				return
			if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
				return
			# Anti-guessing delay
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - _step_render_time
			var required_delay: float = minf(1.2 + _quiz_attempts_this_step * 0.5, 3.0)
			if elapsed < required_delay:
				return
			if captured_midi == target_midi:
				# Correct!
				_quiz_correct = true
				_quiz_answered = true
				if _quiz_attempts_this_step == 0:
					_module_first_try_correct += 1
				_module_quiz_count += 1
				# Flash green
				var sb_ok := StyleBoxFlat.new()
				sb_ok.bg_color = CORRECT_COLOR
				sb_ok.border_color = Color(0.2, 0.6, 0.3, 0.8)
				sb_ok.border_width_left = 2
				sb_ok.border_width_right = 2
				sb_ok.border_width_bottom = 2
				sb_ok.corner_radius_bottom_left = 3
				sb_ok.corner_radius_bottom_right = 3
				panel.add_theme_stylebox_override("panel", sb_ok)
				feedback_lbl.text = "Correct!"
				feedback_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
				_chicken_label.text = chicken_correct
				var concept_id: String = _build_keyboard_concept_id(step)
				_record_learning_result(step, true, _quiz_attempts_this_step == 0, concept_id, "keyboard")

				_play_note_audio_immediate(target_note_id)
				_update_nav_buttons()
			else:
				# Wrong
				_quiz_answered = true
				_quiz_attempts_this_step += 1
				_module_quiz_count += 1
				_chicken_label.text = chicken_wrong
				# Flash red briefly
				var old_sb: StyleBox = panel.get_theme_stylebox("panel")
				var sb_err := StyleBoxFlat.new()
				sb_err.bg_color = WRONG_COLOR
				sb_err.border_color = Color(0.7, 0.2, 0.2, 0.8)
				sb_err.border_width_left = 1
				sb_err.border_width_right = 1
				sb_err.border_width_bottom = 1
				sb_err.corner_radius_bottom_left = 3
				sb_err.corner_radius_bottom_right = 3
				panel.add_theme_stylebox_override("panel", sb_err)
				feedback_lbl.text = "Try again!"
				feedback_lbl.add_theme_color_override("font_color", WRONG_COLOR)
				_record_learning_result(step, false, false, _build_keyboard_concept_id(step), "keyboard")
				_show_wrong_answer_card(step)
				if _test_out_mode:
					_update_nav_buttons()
					return
				# Revert after 0.3s
				await get_tree().create_timer(0.3).timeout
				if is_instance_valid(panel) and not _quiz_correct:
					panel.add_theme_stylebox_override("panel", old_sb)
		)


func _draw_bar_lines(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var num_bars: int = visual_data.get("bars", 3)

	var staff := _create_teaching_staff(clef, 500.0, 170.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	_content_vbox.add_child(container)

	var staff_bottom := staff_top + 4 * gap

	for i in range(1, num_bars):
		var bx := line_x + line_w * (float(i) / num_bars)
		var bar_line := ColorRect.new()
		bar_line.color = Color(0.20, 0.20, 0.22, 0.85)
		bar_line.position = Vector2(bx, staff_top)
		bar_line.size = Vector2(2, staff_bottom - staff_top)
		bar_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(bar_line)

	for i in num_bars:
		var mx := line_x + line_w * ((float(i) + 0.5) / num_bars)
		var lbl := Label.new()
		lbl.text = "Bar %d" % [i + 1]
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.50, 0.05, 1.0))
		lbl.position = Vector2(mx - 18, staff_bottom + 8)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)


func _draw_note_ledger_lines(container: Control, note_step: int, staff_top: float, gap: float, note_x: float) -> void:
	if note_step <= -2:
		var s := -2
		while s >= note_step:
			var ly := staff_top + s * (gap / 2.0)
			var ledger := ColorRect.new()
			ledger.color = Color(0.30, 0.32, 0.36, 0.70)
			ledger.size = Vector2(30, 1.5)
			ledger.position = Vector2(note_x - 15, ly)
			ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(ledger)
			s -= 2
	elif note_step >= 10:
		var s := 10
		while s <= note_step:
			var ly := staff_top + s * (gap / 2.0)
			var ledger := ColorRect.new()
			ledger.color = Color(0.30, 0.32, 0.36, 0.70)
			ledger.size = Vector2(30, 1.5)
			ledger.position = Vector2(note_x - 15, ly)
			ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(ledger)
			s += 2


# ---- Note Quiz Step (Sight Reader Style) ----

func _render_note_quiz_step(step: Dictionary) -> void:
	_quiz_answered = false
	_quiz_correct = false
	_quiz_attempts_this_step = 0

	var clef: String = step.get("clef", "treble")
	var note_step: int = step.get("note_step", 4)
	var choices: Array = step.get("choices", [])
	var correct_index: int = step.get("correct_index", 0)

	# Auto-play note audio
	var note_id: String = _extract_note_id_from_step(step)
	if note_id != "":
		_play_note_audio(note_id)

	# Build staff with the note
	var height := 180.0
	var extra_top := 0.0
	if note_step < -2:
		extra_top = absf(note_step + 2) * 10.0
		height += extra_top
	elif note_step > 10:
		height += (note_step - 10) * 10.0

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	_content_vbox.add_child(container)

	var note_x := line_x + line_w * 0.5
	var note_y := staff_top + note_step * (gap / 2.0)

	_draw_note_ledger_lines(container, note_step, staff_top, gap, note_x)
	var head := _create_oval_notehead(_pick_note_head_color())
	head.position = Vector2(note_x - head.size.x / 2.0, note_y - head.size.y / 2.0)
	container.add_child(head)
	_current_quiz_notehead = head

	# Idle bob ---- matches sight reader ---1px sine bounce
	var _head_y0: float = head.position.y
	var bob_tw := container.create_tween()
	bob_tw.set_loops()
	bob_tw.tween_property(head, "position:y", _head_y0 - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tw.tween_property(head, "position:y", _head_y0 + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Question + replay row
	var q_row := HBoxContainer.new()
	q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	q_row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(q_row)

	var q_label := Label.new()
	q_label.text = "What note is this?"
	q_label.add_theme_font_override("font", FONT_TITLE)
	q_label.add_theme_font_size_override("font_size", 20)
	q_label.add_theme_color_override("font_color", TEXT_MUTED)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_row.add_child(q_label)

	if note_id != "":
		var replay := Button.new()
		replay.text = " -- "
		replay.add_theme_font_size_override("font_size", 18)
		replay.custom_minimum_size = Vector2(40, 34)
		replay.tooltip_text = "Replay note"
		_style_flat_button(replay)
		replay.add_theme_color_override("font_color", ACCENT_GOLD)
		var captured_note_id := note_id
		replay.pressed.connect(func(): _play_note_audio(captured_note_id))
		q_row.add_child(replay)

	# Answer buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(btn_row)

	for i in choices.size():
		var btn := Button.new()
		btn.text = choices[i]
		btn.add_theme_font_override("font", FONT_TITLE)
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(90, 50)
		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.14, 0.22, 0.36, 0.90)
		btn_sb.corner_radius_top_left = 14
		btn_sb.corner_radius_top_right = 14
		btn_sb.corner_radius_bottom_left = 14
		btn_sb.corner_radius_bottom_right = 14
		btn_sb.border_color = ACCENT_GOLD
		btn_sb.border_width_left = 2
		btn_sb.border_width_top = 2
		btn_sb.border_width_right = 2
		btn_sb.border_width_bottom = 2
		btn_sb.content_margin_left = 14
		btn_sb.content_margin_right = 14
		btn_sb.content_margin_top = 8
		btn_sb.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", btn_sb)
		var btn_hover := btn_sb.duplicate()
		btn_hover.bg_color = Color(0.20, 0.30, 0.46, 0.95)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60, 1.0))
		btn.pressed.connect(_on_quiz_answer.bind(i, correct_index, btn, btn_row, step))
		btn_row.add_child(btn)

	_active_quiz_step = step
	_active_quiz_choices = choices.duplicate()
	_active_quiz_correct_index = correct_index
	_active_quiz_btn_row = btn_row
	_active_quiz_buttons.clear()
	for child in btn_row.get_children():
		if child is Button:
			_active_quiz_buttons.append(child as Button)


# ---- Drag Note Step ----

func _render_drag_note_step(step: Dictionary) -> void:
	_drag_note_completed = false
	var clef: String = step.get("clef", "treble")
	var target_step: int = step.get("target_step", 4)
	var target_note: String = step.get("target_note", "")
	var show_hint: bool = step.get("show_hint", true)

	var staff := _create_teaching_staff(clef, 500.0, 220.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]

	# Enable input on container for drag handling
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	_content_vbox.add_child(container)
	_drag_note_panel = container

	# Target Y: step 0 = top line, step 8 = bottom line; half-steps for spaces
	var target_y := staff_top + target_step * (gap / 2.0)
	var note_x := line_x + line_w * 0.55

	# Dotted hint oval
	if show_hint:
		var hint := Panel.new()
		hint.size = Vector2(24 * STAFF_LINE_SPACING / 14.0, 15 * STAFF_LINE_SPACING / 14.0)
		hint.position = Vector2(note_x - 12, target_y - 7.5)
		var hint_sb := StyleBoxFlat.new()
		hint_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		hint_sb.corner_radius_top_left = 8
		hint_sb.corner_radius_top_right = 8
		hint_sb.corner_radius_bottom_left = 8
		hint_sb.corner_radius_bottom_right = 8
		hint_sb.border_color = Color(0.30, 0.70, 0.40, 0.50)
		hint_sb.border_width_left = 2
		hint_sb.border_width_top = 2
		hint_sb.border_width_right = 2
		hint_sb.border_width_bottom = 2
		hint.add_theme_stylebox_override("panel", hint_sb)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(hint)

	# Ledger lines
	_draw_drag_ledger_lines(container, target_step, staff_top, gap, note_x, line_w)

	# Note name label (hidden until correct)
	var note_name_lbl := Label.new()
	note_name_lbl.text = target_note
	note_name_lbl.add_theme_font_override("font", FONT_TITLE)
	note_name_lbl.add_theme_font_size_override("font_size", 20)
	note_name_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
	note_name_lbl.position = Vector2(note_x + 16, target_y - 12)
	note_name_lbl.visible = false
	note_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(note_name_lbl)

	# Draggable oval notehead
	var note_head := _create_oval_notehead(_pick_note_head_color())
	var start_pos := Vector2(line_x + line_w - 50, staff_top + 5 * gap + 12)
	note_head.position = start_pos
	container.add_child(note_head)
	_drag_note_head = note_head
	_drag_original_pos = start_pos

	# "Drag me!" hint label ---- below the note head so it stays inside the staff area
	var drag_hint_lbl := Label.new()
	drag_hint_lbl.text = "Drag to staff!"
	drag_hint_lbl.add_theme_font_override("font", FONT_BODY)
	drag_hint_lbl.add_theme_font_size_override("font_size", 13)
	drag_hint_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40, 0.80))
	drag_hint_lbl.position = Vector2(start_pos.x - 20, start_pos.y + note_head.size.y + 4)
	drag_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(drag_hint_lbl)

	# Connect drag input on the container (all children have MOUSE_FILTER_IGNORE)
	container.gui_input.connect(func(event: InputEvent) -> void:
		_handle_drag_input(event, note_head, target_y, gap, step, note_name_lbl, drag_hint_lbl)
	)


func _handle_drag_input(event: InputEvent, note_head: Control, target_y: float, gap: float, step: Dictionary, name_lbl: Label, hint_lbl: Label) -> void:
	if _drag_note_completed:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var note_rect := Rect2(note_head.position, note_head.size)
				var expanded := note_rect.grow(22.0 * STAFF_LINE_SPACING / 14.0)
				if expanded.has_point(mb.position):
					_drag_is_dragging = true
					_drag_offset = mb.position - note_head.position
			else:
				if _drag_is_dragging:
					_drag_is_dragging = false
					_check_drag_placement(note_head, target_y, gap, step, name_lbl, hint_lbl)

	elif event is InputEventMouseMotion and _drag_is_dragging:
		var mm := event as InputEventMouseMotion
		note_head.position = mm.position - _drag_offset


func _check_drag_placement(note_head: Control, target_y: float, gap: float, step: Dictionary, name_lbl: Label, hint_lbl: Label) -> void:
	var note_center_y := note_head.position.y + note_head.size.y / 2.0
	var snap_tolerance := gap * 1.0  # Generous tolerance for mobile

	if absf(note_center_y - target_y) < snap_tolerance:
		# Correct!
		_drag_note_completed = true
		note_head.position.y = target_y - note_head.size.y / 2.0
		_apply_notehead_material(note_head, CORRECT_COLOR, Color(0.15, 0.55, 0.22, 0.85))
		name_lbl.visible = true
		hint_lbl.visible = false
		_chicken_label.text = step.get("chicken_correct", "That's the right spot!")
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		_update_nav_buttons()
	else:
		# Wrong ---- return to start
		note_head.position = _drag_original_pos
		_chicken_label.text = step.get("chicken_wrong", "Not quite -- try again!")
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")


func _draw_drag_ledger_lines(container: Control, target_step: int, staff_top: float, gap: float, note_x: float, _line_w: float) -> void:
	if target_step < 0:
		var s := 0
		while s > target_step:
			s -= 2
			var ly := staff_top + s * (gap / 2.0)
			var ledger := ColorRect.new()
			ledger.color = Color(0.30, 0.32, 0.36, 0.55)
			ledger.size = Vector2(28, 1.5)
			ledger.position = Vector2(note_x - 14, ly)
			ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(ledger)
	elif target_step > 8:
		var s := 8
		while s < target_step:
			s += 2
			var ly := staff_top + s * (gap / 2.0)
			var ledger := ColorRect.new()
			ledger.color = Color(0.30, 0.32, 0.36, 0.55)
			ledger.size = Vector2(28, 1.5)
			ledger.position = Vector2(note_x - 14, ly)
			ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(ledger)


# ---- Drag Symbol Step ----

var _drag_symbol_completed: bool = false

func _render_drag_symbol_step(step: Dictionary) -> void:
	_drag_symbol_completed = false
	_drag_note_completed = false  # reuse for nav button gating
	_quiz_attempts_this_step = 0
	var symbol_text: String = step.get("symbol", "?")
	var choices: Array = step.get("choices", [])
	var correct_idx: int = step.get("correct_index", 0)

	# Instruction
	var prompt_lbl := Label.new()
	prompt_lbl.text = "Drag the symbol to the correct answer:"
	prompt_lbl.add_theme_font_override("font", FONT_BODY)
	prompt_lbl.add_theme_font_size_override("font_size", 16)
	prompt_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(prompt_lbl)

	# Container for drag interaction
	var drag_area := Control.new()
	drag_area.custom_minimum_size = Vector2(500, 220)
	drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_content_vbox.add_child(drag_area)

	# Large symbol to drag
	var symbol_panel := PanelContainer.new()
	var sym_sb := StyleBoxFlat.new()
	sym_sb.bg_color = Color(0.9098, 0.6275, 0.1255, 0.25)
	sym_sb.corner_radius_top_left = 16
	sym_sb.corner_radius_top_right = 16
	sym_sb.corner_radius_bottom_left = 16
	sym_sb.corner_radius_bottom_right = 16
	sym_sb.border_color = ACCENT_GOLD
	sym_sb.border_width_left = 2
	sym_sb.border_width_top = 2
	sym_sb.border_width_right = 2
	sym_sb.border_width_bottom = 2
	sym_sb.content_margin_left = 16
	sym_sb.content_margin_right = 16
	sym_sb.content_margin_top = 10
	sym_sb.content_margin_bottom = 10
	symbol_panel.add_theme_stylebox_override("panel", sym_sb)
	symbol_panel.size = Vector2(80, 60)
	var sym_start_pos := Vector2(210, 10)
	symbol_panel.position = sym_start_pos
	symbol_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sym_lbl := Label.new()
	sym_lbl.text = symbol_text
	sym_lbl.add_theme_font_override("font", FONT_TITLE)
	sym_lbl.add_theme_font_size_override("font_size", 32)
	sym_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol_panel.add_child(sym_lbl)
	drag_area.add_child(symbol_panel)

	# Drop target boxes
	var targets: Array[Rect2] = []
	var target_panels: Array[PanelContainer] = []
	var target_labels: Array[Label] = []
	var x_start := 20.0
	var box_w := 120.0
	var spacing := (460.0 - box_w * mini(choices.size(), 4)) / maxi(choices.size() - 1, 1)
	var box_y := 130.0

	for i in choices.size():
		var t_panel := PanelContainer.new()
		var t_sb := StyleBoxFlat.new()
		t_sb.bg_color = Color(0.14, 0.20, 0.30, 0.60)
		t_sb.corner_radius_top_left = 12
		t_sb.corner_radius_top_right = 12
		t_sb.corner_radius_bottom_left = 12
		t_sb.corner_radius_bottom_right = 12
		t_sb.border_color = Color(0.40, 0.45, 0.50, 0.50)
		t_sb.border_width_left = 2
		t_sb.border_width_top = 2
		t_sb.border_width_right = 2
		t_sb.border_width_bottom = 2
		t_sb.content_margin_left = 8
		t_sb.content_margin_right = 8
		t_sb.content_margin_top = 8
		t_sb.content_margin_bottom = 8
		t_panel.add_theme_stylebox_override("panel", t_sb)
		var bx := x_start + i * (box_w + spacing)
		t_panel.position = Vector2(bx, box_y)
		t_panel.size = Vector2(box_w, 60)
		t_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var t_lbl := Label.new()
		t_lbl.text = str(choices[i])
		t_lbl.add_theme_font_override("font", FONT_BODY)
		t_lbl.add_theme_font_size_override("font_size", 16)
		t_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t_panel.add_child(t_lbl)
		drag_area.add_child(t_panel)

		targets.append(Rect2(bx, box_y, box_w, 60))
		target_panels.append(t_panel)
		target_labels.append(t_lbl)

	# Drag logic
	var is_dragging := [false]
	var drag_off := [Vector2.ZERO]

	drag_area.gui_input.connect(func(event: InputEvent) -> void:
		if _drag_symbol_completed:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var sym_rect := Rect2(symbol_panel.position, symbol_panel.size)
					if sym_rect.grow(16.0).has_point(mb.position):
						is_dragging[0] = true
						drag_off[0] = mb.position - symbol_panel.position
				else:
					if is_dragging[0]:
						is_dragging[0] = false
						var center := symbol_panel.position + symbol_panel.size / 2.0
						var dropped_on := -1
						for ti in targets.size():
							if targets[ti].grow(20.0).has_point(center):
								dropped_on = ti
								break
						if dropped_on >= 0:
							_quiz_attempts_this_step += 1
							if dropped_on == correct_idx:
								_drag_symbol_completed = true
								_drag_note_completed = true
								var t_sb_ok: StyleBoxFlat = target_panels[dropped_on].get_theme_stylebox("panel").duplicate()
								t_sb_ok.border_color = CORRECT_COLOR
								t_sb_ok.bg_color = Color(0.20, 0.55, 0.30, 0.40)
								target_panels[dropped_on].add_theme_stylebox_override("panel", t_sb_ok)
								symbol_panel.position = Vector2(targets[dropped_on].position.x + (box_w - symbol_panel.size.x) / 2.0, targets[dropped_on].position.y - 70)
								_chicken_label.text = step.get("chicken_correct", "You got it!")
								_play_sfx("res://assets/audio/sfx/correct.mp3")
								_module_quiz_count += 1
								if _quiz_attempts_this_step == 1:
									_module_first_try_correct += 1
								_update_nav_buttons()
							else:
								var t_sb_bad: StyleBoxFlat = target_panels[dropped_on].get_theme_stylebox("panel").duplicate()
								t_sb_bad.border_color = WRONG_COLOR
								target_panels[dropped_on].add_theme_stylebox_override("panel", t_sb_bad)
								_chicken_label.text = step.get("chicken_wrong", "Not that one -- try again!")
								_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
								symbol_panel.position = sym_start_pos
								# Reset border after delay
								var reset_panel := target_panels[dropped_on]
								get_tree().create_timer(0.8).timeout.connect(func():
									if is_instance_valid(reset_panel) and not _drag_symbol_completed:
										var t_sb_r: StyleBoxFlat = reset_panel.get_theme_stylebox("panel").duplicate()
										t_sb_r.border_color = Color(0.40, 0.45, 0.50, 0.50)
										reset_panel.add_theme_stylebox_override("panel", t_sb_r)
								)
						else:
							symbol_panel.position = sym_start_pos
		elif event is InputEventMouseMotion and is_dragging[0]:
			var mm := event as InputEventMouseMotion
			symbol_panel.position = mm.position - drag_off[0]
	)


# ---- Symbol Large Visual ----

func _draw_symbol_large(visual_data: Dictionary) -> void:
	var symbol_text: String = visual_data.get("symbol", "")
	var label_text: String = visual_data.get("label", "")
	var color_name: String = visual_data.get("color", "gold")

	var color: Color
	match color_name:
		"gold":
			color = ACCENT_GOLD
		"blue":
			color = Color(0.30, 0.55, 0.90, 1.0)
		"green":
			color = CORRECT_COLOR
		"red":
			color = WRONG_COLOR
		_:
			color = ACCENT_GOLD

	var container := CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 160)
	_content_vbox.add_child(container)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.26, 0.70)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.border_color = color.lerp(Color.WHITE, 0.3)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 50
	sb.content_margin_right = 50
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	container.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var sym_lbl := Label.new()
	sym_lbl.text = symbol_text
	sym_lbl.add_theme_font_override("font", FONT_TITLE)
	sym_lbl.add_theme_font_size_override("font_size", 96)
	sym_lbl.add_theme_color_override("font_color", color)
	sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sym_lbl)

	if label_text != "":
		var name_lbl := Label.new()
		name_lbl.text = label_text
		name_lbl.add_theme_font_override("font", FONT_TITLE)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", color)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)


# ---- Time Signature Visual ----

func _draw_time_signature(visual_data: Dictionary) -> void:
	var top_num: int = visual_data.get("top", 4)
	var bottom_num: int = visual_data.get("bottom", 4)
	var beat_note := "quarter note"
	match bottom_num:
		1:
			beat_note = "whole note"
		2:
			beat_note = "half note"
		4:
			beat_note = "quarter note"
		8:
			beat_note = "eighth note"

	var example_data := visual_data.duplicate(true)
	var bars: Array = example_data.get("bars", [])
	if bars.is_empty():
		bars = [[
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0},
			{"kind": "quarter", "beats": 1.0},
		]]
		example_data["bars"] = bars
	if not example_data.has("prompt"):
		example_data["prompt"] = "Count the bar aloud before you move on."
	if not example_data.has("caption"):
		example_data["caption"] = "%d beats in each bar. The %s gets one beat." % [top_num, beat_note]
	example_data["font_size"] = int(example_data.get("font_size", 38))
	example_data["show_counts"] = example_data.get("show_counts", true)
	_draw_rhythm_staff_example(example_data)

	var sig_label := Label.new()
	sig_label.text = "%d/%d Time" % [top_num, bottom_num]
	sig_label.add_theme_font_override("font", FONT_TITLE)
	sig_label.add_theme_font_size_override("font_size", 20)
	sig_label.add_theme_color_override("font_color", ACCENT_GOLD)
	sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(sig_label)

func _on_prev_pressed() -> void:
	if _current_step > 0:
		_current_step -= 1
		_play_sfx("res://assets/audio/sfx/ui-basic-click.wav")
		_render_step()


func _on_restart_pressed() -> void:
	_current_step = 0
	_quiz_answered = false
	_quiz_correct = false
	_drag_note_completed = false
	_drag_symbol_completed = false
	_quiz_attempts_this_step = 0
	_module_quiz_count = 0
	_module_first_try_correct = 0
	_module_start_time = Time.get_ticks_msec() / 1000.0
	_practice_pool = []
	_practice_index = 0
	_cumulative_pool = []
	_cumulative_index = 0
	_listening_items = []
	_listening_index = 0
	if _test_out_mode:
		_test_out_skill_totals = {}
		_test_out_skill_correct = {}
		_test_out_overall_answers = 0
		_test_out_overall_correct = 0
	_play_sfx("res://assets/audio/sfx/ui-basic-click.wav")
	_render_step()


func _on_next_pressed() -> void:
	# Note intro sub-phase intercept
	if _note_intro_phase > 0 and _note_intro_phase < _note_intro_max_phase:
		_advance_note_intro_phase()
		return
	if _note_intro_phase == _note_intro_max_phase:
		_note_intro_phase = 0
	var steps: Array = _get_active_steps()
	if _current_step >= steps.size() - 1:
		if _test_out_mode:
			_finish_test_out()
		else:
			_complete_module()
		return
	var step: Dictionary = steps[_current_step]
	var stype: int = step.get("type", -1)
	var allow_test_out_advance: bool = _test_out_mode and ((_quiz_answered and (stype == LMD.STEP_QUIZ or stype == LMD.STEP_NOTE_QUIZ or stype == LMD.STEP_CUMULATIVE_QUIZ or stype == LMD.STEP_PRACTICE_ROUND or stype == LMD.STEP_KEYBOARD_QUIZ)) or (stype == LMD.STEP_LISTENING_QUIZ and _quiz_correct) or (stype == LMD.STEP_RHYTHM_TAP and _rhythm_tap_completed))
	if not allow_test_out_advance and (stype == LMD.STEP_QUIZ or stype == LMD.STEP_NOTE_QUIZ or stype == LMD.STEP_CUMULATIVE_QUIZ or stype == LMD.STEP_PRACTICE_ROUND or stype == LMD.STEP_LISTENING_QUIZ or stype == LMD.STEP_KEYBOARD_QUIZ) and not _quiz_correct:
		return
	if not allow_test_out_advance and stype == LMD.STEP_RHYTHM_TAP and not _rhythm_tap_completed:
		return
	if (stype == LMD.STEP_DRAG_NOTE or stype == LMD.STEP_DRAG_SYMBOL) and not _drag_note_completed:
		return
	_current_step += 1
	_quiz_answered = false
	_quiz_correct = false
	_drag_note_completed = false
	_drag_symbol_completed = false
	_rhythm_tap_completed = false
	_rhythm_tap_started = false
	_quiz_attempts_this_step = 0
	_play_sfx("res://assets/audio/sfx/ui-basic-click.wav")
	_render_step()


func _complete_module() -> void:
	var module_id: String = _module_data.get("id", "")
	_progress.set_module_completed(module_id)
	_play_sfx("res://assets/audio/sfx/fanfare-2-rpg.wav")

	# Compute stars
	var stars := _compute_stars()
	_progress.set_module_stars(module_id, stars)

	# Record study time
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _module_start_time
	_progress.add_study_time(module_id, elapsed)

	_clear_content()
	var module_title: String = _module_data.get("title", "this lesson")
	var badge_name: String = _module_data.get("badge_name", "")
	if stars == 3:
		_chicken_label.text = "Perfect score! You're a star! %s complete!" % module_title
	elif stars == 2:
		_chicken_label.text = "Great work on %s! Almost perfect!" % module_title
	else:
		_chicken_label.text = "You completed %s! Keep practicing to earn more stars!" % module_title

	var title := Label.new()
	title.text = "Lesson Complete!"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	# Stars display
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(star_row)
	for i in 3:
		var star_lbl := Label.new()
		star_lbl.text = "★"
		star_lbl.add_theme_font_size_override("font_size", 48)
		star_lbl.add_theme_color_override("font_color", STAR_GOLD if i < stars else STAR_EMPTY)
		star_row.add_child(star_lbl)

	# Badge
	if badge_name != "":
		var badge_lbl := Label.new()
		badge_lbl.text = " --  %s" % badge_name
		badge_lbl.add_theme_font_override("font", FONT_TITLE)
		badge_lbl.add_theme_font_size_override("font_size", 20)
		badge_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(badge_lbl)

	# Stats line
	var stats_text := ""
	if _module_quiz_count > 0:
		var accuracy := int(float(_module_first_try_correct) / float(_module_quiz_count) * 100.0)
		stats_text = "Accuracy: %d%%  |  " % accuracy
	var mins := int(elapsed / 60.0)
	var secs := int(elapsed) % 60
	stats_text += "Time: %dm %ds" % [mins, secs]
	var stats_lbl := Label.new()
	stats_lbl.text = stats_text
	stats_lbl.add_theme_font_override("font", FONT_BODY)
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(stats_lbl)

	var msg := Label.new()
	msg.text = _module_data.get("description", "")
	msg.add_theme_font_override("font", FONT_BODY)
	msg.add_theme_font_size_override("font_size", 17)
	msg.add_theme_color_override("font_color", TEXT_MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(msg)

	# App mode bridge suggestion
	var bridge: String = _get_bridge_suggestion(module_id)
	if bridge != "":
		var bridge_lbl := Label.new()
		bridge_lbl.text = bridge
		bridge_lbl.add_theme_font_override("font", FONT_BODY)
		bridge_lbl.add_theme_font_size_override("font_size", 15)
		bridge_lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 0.65, 0.90))
		bridge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bridge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(bridge_lbl)

	var return_btn := _create_nav_button("Return to Map")
	return_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_btn.pressed.connect(func():
		_play_sfx("res://assets/audio/sfx/ui-basic-click.wav")
		lesson_completed.emit(module_id)
	)
	_content_vbox.add_child(return_btn)

	_prev_btn.visible = false
	_next_btn.visible = false
	_progress_bar.value = _progress_bar.max_value
	_animate_content_in()


func _update_nav_buttons() -> void:
	if _note_intro_phase > 0 and _note_intro_phase < _note_intro_max_phase:
		_next_btn.text = "Tap to continue"
		_next_btn.visible = true
		_next_btn.disabled = false
		_prev_btn.visible = false
		return
	var steps: Array = _get_active_steps()
	_prev_btn.visible = _current_step > 0
	_prev_btn.disabled = _current_step <= 0

	var is_last: bool = _current_step >= steps.size() - 1
	var cur_type: int = steps[_current_step].get("type", -1) if _current_step < steps.size() else -1
	var is_quiz: bool = cur_type == LMD.STEP_QUIZ or cur_type == LMD.STEP_NOTE_QUIZ or cur_type == LMD.STEP_KEYBOARD_QUIZ
	var is_cumulative: bool = cur_type == LMD.STEP_CUMULATIVE_QUIZ
	var is_practice: bool = cur_type == LMD.STEP_PRACTICE_ROUND
	var is_listening: bool = cur_type == LMD.STEP_LISTENING_QUIZ
	var is_drag: bool = cur_type == LMD.STEP_DRAG_NOTE or cur_type == LMD.STEP_DRAG_SYMBOL
	var is_rhythm_tap: bool = cur_type == LMD.STEP_RHYTHM_TAP
	var is_note_identify: bool = cur_type == LMD.STEP_NOTE_IDENTIFY or cur_type == LMD.STEP_LISTEN_FIND
	_next_btn.visible = true
	_next_btn.text = "Finish!" if is_last else "Next"
	var can_advance_test_out: bool = _test_out_mode and ((_quiz_answered and (is_quiz or is_cumulative or is_practice)) or _rhythm_tap_completed or _note_identify_completed or (is_listening and _quiz_correct))
	_next_btn.disabled = false if can_advance_test_out else ((is_quiz and not _quiz_correct) or (is_drag and not _drag_note_completed) or (is_cumulative and not _quiz_correct) or (is_practice and not _quiz_correct) or (is_listening and not _quiz_correct) or (is_rhythm_tap and not _rhythm_tap_completed) or (is_note_identify and not _note_identify_completed))


func _update_progress_ui() -> void:
	var total: int = _get_active_steps().size()
	_progress_bar.max_value = total
	_progress_bar.value = _current_step + 1
	_progress_label.text = "%d / %d" % [_current_step + 1, total]


func _save_step_progress() -> void:
	if _progress != null and not _test_out_mode:
		_progress.set_last_step(_module_data.get("id", ""), _current_step)


func _clear_content() -> void:
	_melody_playback_token += 1
	_rhythm_playback_token += 1
	_feedback_card = null

	for child in _content_vbox.get_children():
		child.queue_free()


# ---- Animation ----

func _animate_bubble_in() -> void:
	if _chicken_bubble == null:
		return
	_chicken_bubble.visible = true
	# Play chicken chirp when bubble appears
	_play_chicken_cluck()
	# Keep chicken sprite always visible -- only animate the speech bubble
	if _chicken_anim_sprite != null:
		_chicken_anim_sprite.modulate.a = 1.0
	# Bubble pops in with bounce
	_chicken_bubble.modulate = Color(1, 1, 1, 0)
	_chicken_bubble.scale = Vector2(0.75, 0.75)
	_chicken_bubble.pivot_offset = Vector2(0, _chicken_bubble.size.y * 0.5)
	var tw := create_tween()
	tw.tween_property(_chicken_bubble, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_chicken_bubble, "scale", Vector2(1.06, 1.06), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chicken_bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_chicken_cluck() -> void:
	if _sfx_player == null or CHICKEN_CLUCK_STREAM == null:
		return
	_sfx_player.stream = CHICKEN_CLUCK_STREAM
	_sfx_player.volume_db = -6.0
	_sfx_player.play()


func _animate_content_in() -> void:
	if _content_vbox == null:
		return
	_content_vbox.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_content_vbox, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_delay(1.0)


func _blink_highlight(rect: ColorRect, base_color: Color) -> void:
	var tw := create_tween()
	tw.set_loops(5)
	tw.tween_property(rect, "color:a", 0.25, 0.4).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(rect, "color:a", base_color.a, 0.4).set_ease(Tween.EASE_IN_OUT)


# ---- Utilities ----

func _play_sfx(path: String) -> void:
	if _sfx_player == null or not ResourceLoader.exists(path):
		return
	_sfx_player.stream = load(path)
	_sfx_player.play()


func _style_flat_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, sb)


# ---- Chicken Spritesheet Animation ----

func _build_chicken_animated_sprite() -> AnimatedSprite2D:
	var sheet_path := "res://assets/birds/idle.png"
	if not ResourceLoader.exists(sheet_path):
		return null
	var tex: Texture2D = load(sheet_path)
	if tex == null:
		return null

	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# idle.png: 914x838 per frame, 8 cols, 4 rows = 32 frames
	var frame_w := 914
	var frame_h := 838
	var cols := 8
	var rows := 4
	var total_frames := cols * rows  # 32

	# Build atlas textures for each frame
	var atlas_frames: Array[AtlasTexture] = []
	for r in rows:
		for c in cols:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * frame_w, r * frame_h, frame_w, frame_h)
			atlas_frames.append(atlas)

	# Ping-pong: forward (0-31) then reverse (30-1) for smooth continuous loop
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 14)
	frames.set_animation_loop("idle", true)
	for i in total_frames:
		frames.add_frame("idle", atlas_frames[i])
	for i in range(total_frames - 2, 0, -1):
		frames.add_frame("idle", atlas_frames[i])

	sprite.sprite_frames = frames
	sprite.play("idle")
	return sprite


func _play_chicken_reaction(anim_name: String) -> void:
	if _chicken_anim_sprite == null:
		return
	if _chicken_anim_sprite.sprite_frames.has_animation(anim_name):
		_chicken_anim_sprite.play(anim_name)
	# Bounce animation on the sprite
	var tw := create_tween()
	tw.tween_property(_chicken_anim_sprite, "position:y", _chicken_anim_sprite.position.y - 6, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chicken_anim_sprite, "position:y", _chicken_anim_sprite.position.y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	# Return to idle after one play
	if not _chicken_anim_sprite.animation_finished.is_connected(_on_chicken_anim_done):
		_chicken_anim_sprite.animation_finished.connect(_on_chicken_anim_done)


func _on_chicken_anim_done() -> void:
	if _chicken_anim_sprite != null and _chicken_anim_sprite.sprite_frames.has_animation("idle"):
		_chicken_anim_sprite.play("idle")


func _shake_chicken() -> void:
	if _chicken_anim_sprite == null:
		return
	var base_x: float = _chicken_anim_sprite.position.x
	var tw := create_tween()
	tw.tween_property(_chicken_anim_sprite, "position:x", base_x + 4, 0.05)
	tw.tween_property(_chicken_anim_sprite, "position:x", base_x - 4, 0.05)
	tw.tween_property(_chicken_anim_sprite, "position:x", base_x + 2, 0.05)
	tw.tween_property(_chicken_anim_sprite, "position:x", base_x - 2, 0.05)
	tw.tween_property(_chicken_anim_sprite, "position:x", base_x, 0.05)


# ---- Note Audio ----

func _play_note_audio(note_id: String) -> void:
	if _note_player == null or note_id.is_empty():
		return
	# Delay audio to match content fade-in (1s after step render)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _step_render_time
	if elapsed < 1.0:
		var wait := 1.0 - elapsed
		await get_tree().create_timer(wait).timeout
		if not is_instance_valid(self):
			return
	var stream := _get_note_audio_stream(note_id)
	if stream == null:
		return
	_note_player.stream = stream
	_note_player.play()


func _extract_note_id_from_step(step: Dictionary) -> String:
	if step.has("target_note_id"):
		return str(step.get("target_note_id", ""))
	if step.has("note_id_on_staff"):
		return str(step.get("note_id_on_staff", ""))
	var note_name: String = step.get("note_name", "")
	if note_name.length() >= 2 and note_name[-1].is_valid_int():
		return note_name  # Already has octave like "C4"
	var clef: String = step.get("clef", "")
	var note_step: Variant = step.get("note_step", null)
	if clef != "" and note_step != null:
		return LMD.step_to_note_id(clef, int(note_step))
	return ""


func _get_step_concept_id(step: Dictionary) -> String:
	if step.has("concept_id"):
		return str(step.get("concept_id", ""))
	var stype: int = int(step.get("type", -1))
	if stype == LMD.STEP_KEYBOARD_QUIZ:
		return _build_keyboard_concept_id(step)
	if stype == LMD.STEP_RHYTHM_TAP:
		return _build_rhythm_concept_id(step)
	var clef: String = step.get("clef", "")
	var note_id: String = _extract_note_id_from_step(step)
	if clef != "" and note_id != "":
		return "%s:%s" % [clef, note_id]
	var question: String = step.get("question", "")
	if question != "":
		return "quiz:%s" % question.left(40)
	return ""


func _get_response_ms() -> float:
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _step_render_time
	return maxf(0.0, elapsed * 1000.0)


func _get_skill_family_for_step(step: Dictionary, concept_id: String = "") -> String:
	var explicit_family: String = str(step.get("test_out_family", ""))
	if explicit_family != "":
		return explicit_family
	var stype: int = int(step.get("type", -1))
	if stype == LMD.STEP_KEYBOARD_QUIZ:
		return "keyboard"
	if stype == LMD.STEP_RHYTHM_TAP:
		return "rhythm"
	if stype == LMD.STEP_LISTENING_QUIZ:
		return "listening"
	if stype == LMD.STEP_NOTE_QUIZ or stype == LMD.STEP_CUMULATIVE_QUIZ or stype == LMD.STEP_NOTE_IDENTIFY or stype == LMD.STEP_LISTEN_FIND:
		return "note"
	if stype == LMD.STEP_PRACTICE_ROUND:
		return "theory" if str(step.get("pool_type", "note")) == "theory" else "note"
	if concept_id.begins_with("theory:") or concept_id.begins_with("quiz:"):
		return "theory"
	if concept_id.begins_with("listening:"):
		return "listening"
	if concept_id.begins_with("keyboard:"):
		return "keyboard"
	if concept_id.begins_with("rhythm:"):
		return "rhythm"
	if concept_id.begins_with("treble:") or concept_id.begins_with("bass:"):
		return "note"
	return "theory"


func _record_learning_result(step: Dictionary, correct: bool, first_try: bool, concept_id_override: String = "", skill_family_override: String = "") -> void:
	if _progress == null:
		return
	var concept_id: String = concept_id_override if not concept_id_override.is_empty() else _get_step_concept_id(step)
	if concept_id.is_empty():
		return
	var skill_family: String = skill_family_override if not skill_family_override.is_empty() else _get_skill_family_for_step(step, concept_id)
	_progress.record_quiz_result(_module_data.get("id", ""), concept_id, correct, first_try, _get_response_ms(), "", skill_family)
	if _test_out_mode and skill_family != "" and skill_family != "intro":
		_test_out_skill_totals[skill_family] = int(_test_out_skill_totals.get(skill_family, 0)) + 1
		if correct:
			_test_out_skill_correct[skill_family] = int(_test_out_skill_correct.get(skill_family, 0)) + 1
		_test_out_overall_answers += 1
		if correct:
			_test_out_overall_correct += 1


func _record_confidence(concept_id: String, confidence: String) -> void:
	if _progress == null or concept_id.is_empty() or confidence.is_empty():
		return
	if not _progress.has_method("record_confidence"):
		return
	_progress.record_confidence(concept_id, confidence)


func _describe_staff_position(note_step: int) -> String:
	if note_step % 2 == 0:
		return "on a line"
	return "in a space"


func _build_wrong_feedback_text(step: Dictionary, fallback: String = "") -> String:
	var stype: int = int(step.get("type", -1))
	match stype:
		LMD.STEP_QUIZ:
			var choices: Array = step.get("choices", [])
			var correct_index: int = int(step.get("correct_index", -1))
			if correct_index >= 0 and correct_index < choices.size():
				return "Correct answer: %s." % str(choices[correct_index])
		LMD.STEP_NOTE_QUIZ:
			var note_name: String = str(step.get("note_name", ""))
			var note_step: int = int(step.get("note_step", 0))
			var clef: String = str(step.get("clef", "treble"))
			if note_name != "":
				return "%s belongs %s on the %s staff." % [note_name, _describe_staff_position(note_step), clef]
		LMD.STEP_KEYBOARD_QUIZ:
			var target_note_id: String = str(step.get("target_note_id", ""))
			if target_note_id != "":
				return "Match the staff note to the %s key on the keyboard." % target_note_id
		LMD.STEP_NOTE_IDENTIFY, LMD.STEP_LISTEN_FIND:
			var target_id: String = str(step.get("target_note_id", ""))
			var target_step: int = int(step.get("target_step", 0))
			var target_clef: String = str(step.get("clef", "treble"))
			if target_id != "":
				return "%s sits %s on the %s staff." % [target_id, _describe_staff_position(target_step), target_clef]
	if fallback != "":
		return fallback
	return "Compare the correct answer and try the pattern again."


func _show_wrong_answer_card(step: Dictionary, detail_text: String = "") -> void:
	if _content_vbox == null:
		return

	if _feedback_card != null and is_instance_valid(_feedback_card):
		_feedback_card.queue_free()
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.10, 0.12, 0.92)
	sb.border_color = Color(0.95, 0.42, 0.38, 0.85)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(card)
	_feedback_card = card

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Why this was wrong"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.70, 1.0))
	vbox.add_child(title)

	var detail := Label.new()
	detail.text = _build_wrong_feedback_text(step, detail_text)
	detail.add_theme_font_override("font", FONT_BODY)
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", TEXT_PRIMARY)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(detail)


func _note_label_from_id(note_id: String) -> String:
	var end_idx: int = note_id.length() - 1
	while end_idx >= 0 and note_id[end_idx].is_valid_int():
		end_idx -= 1
	return note_id.substr(0, end_idx + 1)


func _apply_accidental_to_note_id(note_id: String, accidental: String) -> String:
	if accidental.is_empty():
		return note_id
	var note_label: String = _note_label_from_id(note_id)
	if note_label.is_empty():
		return note_id
	var octave_text: String = note_id.substr(note_label.length())
	var letter: String = note_label[0]
	match accidental:
		"sharp":
			return letter + "#" + octave_text
		"flat":
			return letter + "b" + octave_text
		"natural":
			return letter + octave_text
		_:
			return note_id


func _accidental_symbol(accidental: String) -> String:
	match accidental:
		"sharp":
			return "#"
		"flat":
			return "b"
		"natural":
			return "\u266e"
		_:
			return ""


func _add_staff_accidental_label(container: Control, accidental: String, center: Vector2) -> void:
	var symbol: String = _accidental_symbol(accidental)
	if symbol.is_empty():
		return
	var acc_lbl := Label.new()
	acc_lbl.text = symbol
	acc_lbl.add_theme_font_override("font", FONT_TITLE)
	acc_lbl.add_theme_font_size_override("font_size", 20)
	acc_lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.9))
	acc_lbl.position = Vector2(center.x - 28, center.y - 12)
	acc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(acc_lbl)


# ---- Stars ----

func _compute_stars() -> int:
	if _module_quiz_count == 0:
		return 1
	var ratio: float = float(_module_first_try_correct) / float(_module_quiz_count)
	if ratio >= 0.95:
		return 3
	elif ratio >= 0.70:
		return 2
	else:
		return 1


func _get_bridge_suggestion(module_id: String) -> String:
	match module_id:
		"treble_part1a", "treble_part1b", "treble_part2", "bass_part1", "bass_part2":
			return " --  Tip: Try Sight Reading on the home screen to practice your new note skills!"
		"treble_part3", "bass_part3":
			return " --  Tip: Try Sight Reading with your full note range  --  you've earned it!"
		"sharps_flats":
			return " --  Tip: Enable sharps & flats in Sight Reading settings for a challenge!"
		"rhythm_notation":
			return " --  Tip: Try Rhythm Flow on the home screen to test your rhythm skills!"
		"intervals_intro":
			return " --  Tip: Try Interval Training on the home screen to train your ear!"
		"grand_staff":
			return " --  Tip: Try Sight Reading Chords on the home screen  --  it uses the grand staff!"
		"key_signatures":
			return " --  Tip: Try different key signatures in Sight Reading settings!"
		"chord_basics":
			return " --  Tip: Try Chord Training on the home screen to identify chords by ear!"
		_:
			return ""


# ---- Varied Chicken Feedback ----

func _random_correct_line() -> String:
	return CHICKEN_CORRECT_LINES[_rng.randi_range(0, CHICKEN_CORRECT_LINES.size() - 1)]


func _random_wrong_line() -> String:
	return CHICKEN_WRONG_LINES[_rng.randi_range(0, CHICKEN_WRONG_LINES.size() - 1)]


# ---- Cumulative Quiz Step ----

func _render_cumulative_quiz_step(step: Dictionary) -> void:
	_quiz_answered = false
	_quiz_correct = false
	_quiz_attempts_this_step = 0

	var pool: Array = step.get("pool", [])
	var count: int = step.get("count", 5)
	var title_text: String = step.get("title", "Review Challenge!")

	# Initialize cumulative state on first entry
	if _cumulative_pool.is_empty() or _cumulative_index == 0:
		_cumulative_pool = pool.duplicate()
		_cumulative_pool.shuffle()
		if _cumulative_pool.size() > count:
			_cumulative_pool.resize(count)
		_cumulative_index = 0
		_cumulative_count = _cumulative_pool.size()
		_cumulative_correct = 0

	if _cumulative_index >= _cumulative_pool.size():
		# All done ---- show summary and allow advancing
		_quiz_correct = true
		_chicken_label.text = "You got %d out of %d! Great review!" % [_cumulative_correct, _cumulative_count]

		var done_title := Label.new()
		done_title.text = "Review Complete!"
		done_title.add_theme_font_override("font", FONT_TITLE)
		done_title.add_theme_font_size_override("font_size", 28)
		done_title.add_theme_color_override("font_color", ACCENT_GOLD)
		done_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(done_title)

		var score_lbl := Label.new()
		score_lbl.text = "%d / %d correct" % [_cumulative_correct, _cumulative_count]
		score_lbl.add_theme_font_override("font", FONT_BODY)
		score_lbl.add_theme_font_size_override("font_size", 20)
		score_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(score_lbl)

		_cumulative_pool = []
		_cumulative_index = 0
		_update_nav_buttons()
		return

	# Show current review note
	var item: Dictionary = _cumulative_pool[_cumulative_index]
	var clef: String = item.get("clef", "treble")
	var note_step: int = int(item.get("note_step", 4))
	var note_id: String = item.get("note_id", "")

	# Title with progress
	var progress_lbl := Label.new()
	progress_lbl.text = "%s  (%d/%d)" % [title_text, _cumulative_index + 1, _cumulative_count]
	progress_lbl.add_theme_font_override("font", FONT_TITLE)
	progress_lbl.add_theme_font_size_override("font_size", 20)
	progress_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(progress_lbl)

	# Build staff
	var height := 170.0
	var extra_top := 0.0
	if note_step < -2:
		extra_top = absf(note_step + 2) * 10.0
		height += extra_top
	elif note_step > 10:
		height += (note_step - 10) * 10.0

	var staff := _create_teaching_staff(clef, 380.0, height)
	var container: Control = staff["container"]
	var s_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))
	_content_vbox.add_child(container)

	var note_x := line_x + line_w * 0.5
	var note_y := s_top + note_step * (gap / 2.0)
	_draw_note_ledger_lines(container, note_step, s_top, gap, note_x)
	var head := _create_oval_notehead(_pick_note_head_color())
	head.position = Vector2(note_x - head.size.x / 2.0, note_y - head.size.y / 2.0)
	container.add_child(head)

	# Idle bob ---- matches sight reader ---1px sine bounce
	var _head_y0: float = head.position.y
	var bob_tw := container.create_tween()
	bob_tw.set_loops()
	bob_tw.tween_property(head, "position:y", _head_y0 - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tw.tween_property(head, "position:y", _head_y0 + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Play note audio
	if note_id != "":
		_play_note_audio(note_id)

	# Generate choices: 1 adjacent + 2 non-adjacent distractors (4 total)
	var correct_letter: String = item.get("note_name", "C")
	var all_letters := ["C", "D", "E", "F", "G", "A", "B"]
	var correct_idx_in_letters: int = all_letters.find(correct_letter)
	var adjacent: Array[String] = []
	var non_adjacent: Array[String] = []
	for offset in [-1, 1]:
		var didx: int = (correct_idx_in_letters + offset + 7) % 7
		var d: String = all_letters[didx]
		if d != correct_letter and not adjacent.has(d):
			adjacent.append(d)
	for offset in [-3, 3, -4, 4]:
		var didx: int = (correct_idx_in_letters + offset + 7) % 7
		var d: String = all_letters[didx]
		if d != correct_letter and not adjacent.has(d) and not non_adjacent.has(d):
			non_adjacent.append(d)
		if non_adjacent.size() >= 2:
			break
	adjacent.shuffle()
	non_adjacent.shuffle()
	var distractors: Array[String] = []
	if adjacent.size() > 0:
		distractors.append(adjacent[0])
	for d in non_adjacent:
		distractors.append(d)
		if distractors.size() >= 3:
			break
	if distractors.size() < 3 and adjacent.size() > 1:
		distractors.append(adjacent[1])

	var choices: Array[String] = []
	choices.append(correct_letter)
	for d in distractors:
		choices.append(d)
	choices.shuffle()
	var correct_index: int = choices.find(correct_letter)

	# Answer buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(btn_row)

	var cum_step := step.duplicate()
	cum_step["clef"] = clef
	cum_step["note_step"] = note_step
	cum_step["note_name"] = note_id
	cum_step["chicken_correct"] = ""
	cum_step["chicken_wrong"] = ""

	for i in choices.size():
		var btn := Button.new()
		btn.text = choices[i]
		btn.add_theme_font_override("font", FONT_TITLE)
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(90, 50)
		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.14, 0.22, 0.36, 0.90)
		btn_sb.corner_radius_top_left = 14
		btn_sb.corner_radius_top_right = 14
		btn_sb.corner_radius_bottom_left = 14
		btn_sb.corner_radius_bottom_right = 14
		btn_sb.border_color = ACCENT_GOLD
		btn_sb.border_width_left = 2
		btn_sb.border_width_top = 2
		btn_sb.border_width_right = 2
		btn_sb.border_width_bottom = 2
		btn_sb.content_margin_left = 14
		btn_sb.content_margin_right = 14
		btn_sb.content_margin_top = 8
		btn_sb.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", btn_sb)
		var btn_hover := btn_sb.duplicate()
		btn_hover.bg_color = Color(0.20, 0.30, 0.46, 0.95)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60, 1.0))
		btn.pressed.connect(_on_cumulative_answer.bind(i, correct_index, btn, btn_row, cum_step))
		btn_row.add_child(btn)


func _on_cumulative_answer(selected: int, correct: int, _btn: Button, btn_row: HBoxContainer, step: Dictionary) -> void:
	if _quiz_answered:
		return
	_quiz_answered = true
	var is_correct: bool = selected == correct
	_quiz_attempts_this_step += 1
	var is_first_try: bool = _quiz_attempts_this_step == 1

	# Show feedback colors
	for i in btn_row.get_child_count():
		var child := btn_row.get_child(i)
		if not (child is Button):
			continue
		child.disabled = true
		var sb: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate()
		if i == correct:
			sb.bg_color = Color(0.16, 0.52, 0.28, 0.90)
			sb.border_color = CORRECT_COLOR
			child.add_theme_color_override("font_color", CORRECT_COLOR)
		elif i == selected and not is_correct:
			sb.bg_color = Color(0.50, 0.16, 0.14, 0.90)
			sb.border_color = WRONG_COLOR
			child.add_theme_color_override("font_color", WRONG_COLOR)
		child.add_theme_stylebox_override("normal", sb)
		child.add_theme_stylebox_override("disabled", sb)

	if is_correct:
		if is_first_try:
			_cumulative_correct += 1
			_module_first_try_correct += 1
		_module_quiz_count += 1
		_chicken_label.text = _random_correct_line()
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		var note_id: String = _extract_note_id_from_step(step)
		if note_id != "":
			_play_note_audio(note_id)
		_record_learning_result(step, true, is_first_try)

		# Show inline Next button for user to advance
		_add_inline_next_button(btn_row.get_parent(), func():
			_cumulative_index += 1
			_quiz_answered = false
			_quiz_correct = false
			_quiz_attempts_this_step = 0
			_step_render_time = Time.get_ticks_msec() / 1000.0
			_clear_content()
			var steps2: Array = _get_active_steps()
			if _current_step < steps2.size():
				_render_cumulative_quiz_step(steps2[_current_step])
				_animate_content_in()
		)
	else:
		_module_quiz_count += 1
		_chicken_label.text = _random_wrong_line()
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
		_record_learning_result(step, false, false)
		_show_wrong_answer_card(step)
		_quiz_answered = false
		var delay: float = minf(1.2 + (_quiz_attempts_this_step - 1) * 0.5, 3.0)
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self):
			return
		for i in btn_row.get_child_count():
			var child := btn_row.get_child(i)
			if child is Button and i != selected:
				child.disabled = false


# ---- New Visual Renderers ----

func _draw_rhythm_value(visual_data: Dictionary) -> void:
	var value_name: String = visual_data.get("value", "quarter")
	var beats: float = visual_data.get("beats", 1.0)
	var display_name := value_name.replace("_", " ").capitalize()

	var summary := PanelContainer.new()
	summary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var summary_sb := StyleBoxFlat.new()
	summary_sb.bg_color = Color(0.10, 0.16, 0.26, 0.72)
	summary_sb.corner_radius_top_left = 18
	summary_sb.corner_radius_top_right = 18
	summary_sb.corner_radius_bottom_left = 18
	summary_sb.corner_radius_bottom_right = 18
	summary_sb.border_color = ACCENT_GOLD.lerp(Color.WHITE, 0.20)
	summary_sb.border_width_left = 2
	summary_sb.border_width_top = 2
	summary_sb.border_width_right = 2
	summary_sb.border_width_bottom = 2
	summary_sb.content_margin_left = 20
	summary_sb.content_margin_right = 20
	summary_sb.content_margin_top = 10
	summary_sb.content_margin_bottom = 10
	summary.add_theme_stylebox_override("panel", summary_sb)
	_content_vbox.add_child(summary)

	var summary_row := HBoxContainer.new()
	summary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_row.add_theme_constant_override("separation", 12)
	summary.add_child(summary_row)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_override("font", FONT_TITLE)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	summary_row.add_child(name_lbl)

	var beats_text := "%s beats" % String.num(beats, 1)
	if is_equal_approx(beats, 0.5):
		beats_text = "1/2 beat"
	elif is_equal_approx(beats, round(beats)):
		var whole_beats := int(round(beats))
		beats_text = "%d beat%s" % [whole_beats, "s" if whole_beats != 1 else ""]
	var beats_lbl := Label.new()
	beats_lbl.text = beats_text
	beats_lbl.add_theme_font_override("font", FONT_BODY)
	beats_lbl.add_theme_font_size_override("font_size", 16)
	beats_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	summary_row.add_child(beats_lbl)

	var example_data := visual_data.duplicate(true)
	var bars: Array = example_data.get("bars", [])
	if bars.is_empty():
		match value_name:
			"whole":
				bars = [[{"kind": "whole", "beats": 4.0}]]
			"half":
				bars = [[
					{"kind": "half", "beats": 2.0},
					{"kind": "half", "beats": 2.0},
				]]
			"quarter":
				bars = [[
					{"kind": "quarter", "beats": 1.0},
					{"kind": "quarter", "beats": 1.0},
					{"kind": "quarter", "beats": 1.0},
					{"kind": "quarter", "beats": 1.0},
				]]
			"eighth":
				bars = [[
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
					{"kind": "eighth", "beats": 0.5},
				]]
			"dotted_half":
				bars = [[
					{"kind": "dotted_half", "beats": 3.0},
					{"kind": "quarter", "beats": 1.0},
				]]
			"sixteenth":
				bars = [[
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
					{"kind": "sixteenth", "beats": 0.25, "beamed": true},
				]]
			_:
				bars = [[{"kind": value_name, "beats": beats}]]
		example_data["bars"] = bars
	if value_name == "eighth" and not example_data.has("beam_groups"):
		example_data["beam_groups"] = [[[0, 1], [2, 3], [4, 5], [6, 7]]]
	if value_name == "sixteenth" and not example_data.has("beam_groups"):
		example_data["beam_groups"] = [[[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15]]]
	if not example_data.has("prompt"):
		example_data["prompt"] = "See it on the staff before you answer."
	var staff_root := _build_rhythm_staff_example(example_data)
	_content_vbox.add_child(staff_root)

	var demo_row := HBoxContainer.new()
	demo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_vbox.add_child(demo_row)
	var demo_btn := Button.new()
	demo_btn.text = "Hear the count"
	demo_btn.add_theme_font_override("font", FONT_BODY)
	demo_btn.add_theme_font_size_override("font_size", 14)
	demo_btn.custom_minimum_size = Vector2(130, 34)
	_style_flat_button(demo_btn)
	demo_btn.add_theme_color_override("font_color", ACCENT_GOLD)
	var captured_visual := example_data.duplicate(true)
	var captured_root := staff_root
	demo_btn.pressed.connect(func(): _play_rhythm_demo(captured_visual, 0.0, captured_root))
	demo_row.add_child(demo_btn)

	var autoplay_wait := maxf(RHYTHM_AUTOPLAY_DELAY - (Time.get_ticks_msec() / 1000.0 - _step_render_time), 0.0)
	_play_rhythm_demo(example_data, autoplay_wait, staff_root)

func _draw_key_signature_visual(visual_data: Dictionary) -> void:
	var key_name: String = visual_data.get("key", "C")
	var sharps: Array = visual_data.get("sharps", [])
	var flats: Array = visual_data.get("flats", [])

	var staff := _create_teaching_staff("treble", 450.0, 180.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	_content_vbox.add_child(container)

	# Draw accidentals after clef
	var acc_x := line_x + 50.0
	var sharp_positions := {"F": 0, "C": 3, "G": -1, "D": 2, "A": 5, "E": 1, "B": 4}
	var flat_positions := {"B": 4, "E": 1, "A": 5, "D": 2, "G": 6, "C": 3, "F": 7}

	for s in sharps:
		var step_pos: int = sharp_positions.get(s, 0)
		var y: float = staff_top + step_pos * (gap / 2.0)
		var lbl := Label.new()
		lbl.text = "#"
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10, 0.90))
		lbl.position = Vector2(acc_x, y - 13)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
		acc_x += 16

	for f in flats:
		var step_pos: int = flat_positions.get(f, 4)
		var y: float = staff_top + step_pos * (gap / 2.0)
		var lbl := Label.new()
		lbl.text = "b"
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.10, 0.10, 0.10, 0.90))
		lbl.position = Vector2(acc_x, y - 13)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)
		acc_x += 16

	# Key name label
	var key_lbl := Label.new()
	var acc_text := ""
	if sharps.size() > 0:
		acc_text = "%d sharp%s" % [sharps.size(), "s" if sharps.size() > 1 else ""]
	elif flats.size() > 0:
		acc_text = "%d flat%s" % [flats.size(), "s" if flats.size() > 1 else ""]
	else:
		acc_text = "no sharps or flats"
	key_lbl.text = "%s Major  --  %s" % [key_name, acc_text]
	key_lbl.add_theme_font_override("font", FONT_TITLE)
	key_lbl.add_theme_font_size_override("font_size", 20)
	key_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(key_lbl)

	# "Hear the scale" button
	var scale_notes: Array[String] = _get_major_scale_notes(key_name, sharps, flats)
	if scale_notes.size() > 0:
		var scale_row := HBoxContainer.new()
		scale_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_content_vbox.add_child(scale_row)
		var scale_btn := Button.new()
		scale_btn.text = " --  Hear the scale"
		scale_btn.add_theme_font_override("font", FONT_BODY)
		scale_btn.add_theme_font_size_override("font_size", 14)
		scale_btn.custom_minimum_size = Vector2(140, 32)
		_style_flat_button(scale_btn)
		scale_btn.add_theme_color_override("font_color", ACCENT_GOLD)
		var captured_notes := scale_notes.duplicate()
		scale_btn.pressed.connect(func(): _play_scale_sequence(captured_notes))
		scale_row.add_child(scale_btn)
		# Auto-play on load
		_play_scale_sequence(scale_notes)


func _get_major_scale_notes(key_name: String, sharps: Array, flats: Array) -> Array[String]:
	var scale_degrees := {"C": ["C4","D4","E4","F4","G4","A4","B4","C5"],
		"G": ["G4","A4","B4","C5","D5","E5","F#5","G5"],
		"F": ["F4","G4","A4","Bb4","C5","D5","E5","F5"],
		"D": ["D4","E4","F#4","G4","A4","B4","C#5","D5"],
		"Bb": ["Bb3","C4","D4","Eb4","F4","G4","A4","Bb4"]}
	if scale_degrees.has(key_name):
		var result: Array[String] = []
		for n in scale_degrees[key_name]:
			result.append(n)
		return result
	return []


func _play_scale_sequence(notes: Array[String]) -> void:
	if notes.is_empty():
		return
	_play_note_audio(notes[0])
	for i in range(1, notes.size()):
		var captured_note := notes[i]
		var delay := float(i) * 0.35
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self):
				_play_note_audio(captured_note)
		)


func _draw_grand_staff_visual(visual_data: Dictionary) -> void:
	var show_middle_c: bool = visual_data.get("show_middle_c", true)

	var container := Control.new()
	container.custom_minimum_size = Vector2(450, 280)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_vbox.add_child(container)

	# Background
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.96, 0.94, 0.90, 0.95)
	bg_sb.corner_radius_top_left = 14
	bg_sb.corner_radius_top_right = 14
	bg_sb.corner_radius_bottom_left = 14
	bg_sb.corner_radius_bottom_right = 14
	bg.add_theme_stylebox_override("panel", bg_sb)
	container.add_child(bg)

	var gap := STAFF_LINE_SPACING
	var line_x := 50.0
	var line_w := 350.0

	# Treble staff (top)
	var treble_top := 30.0
	for i in 5:
		var line := ColorRect.new()
		line.color = Color(0.30, 0.32, 0.36, 0.70)
		line.position = Vector2(line_x, treble_top + i * gap)
		line.size = Vector2(line_w, 1.5)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(line)

	# Treble clef
	var t_clef := Label.new()
	t_clef.text = " -- "
	t_clef.add_theme_font_size_override("font_size", 48)
	t_clef.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.85))
	t_clef.position = Vector2(line_x + 2, treble_top - 18)
	t_clef.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(t_clef)

	# Bass staff (bottom)
	var bass_top := treble_top + 4 * gap + gap * 4.0
	for i in 5:
		var line := ColorRect.new()
		line.color = Color(0.30, 0.32, 0.36, 0.70)
		line.position = Vector2(line_x, bass_top + i * gap)
		line.size = Vector2(line_w, 1.5)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(line)

	# Bass clef
	var b_clef := Label.new()
	b_clef.text = " -- "
	b_clef.add_theme_font_size_override("font_size", 48)
	b_clef.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.85))
	b_clef.position = Vector2(line_x + 2, bass_top - 10)
	b_clef.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(b_clef)

	# Brace (left side)
	var brace := Label.new()
	brace.text = "{"
	brace.add_theme_font_size_override("font_size", 140)
	brace.add_theme_color_override("font_color", Color(0.20, 0.20, 0.20, 0.80))
	brace.position = Vector2(line_x - 36, treble_top - 10)
	brace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(brace)

	# Middle C
	if show_middle_c:
		var mid_y := (treble_top + 4 * gap + bass_top) / 2.0
		var mid_x := line_x + line_w * 0.5
		# Ledger line for middle C
		var ledger := ColorRect.new()
		ledger.color = Color(0.30, 0.32, 0.36, 0.70)
		ledger.size = Vector2(30, 1.5)
		ledger.position = Vector2(mid_x - 15, mid_y)
		ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(ledger)
		_add_teaching_notehead(container, Vector2(mid_x, mid_y), "C4")

	# Label
	var gs_lbl := Label.new()
	gs_lbl.text = "Grand Staff"
	gs_lbl.add_theme_font_override("font", FONT_TITLE)
	gs_lbl.add_theme_font_size_override("font_size", 20)
	gs_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	gs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(gs_lbl)


func _draw_interval_on_staff(visual_data: Dictionary) -> void:
	var clef: String = visual_data.get("clef", "treble")
	var note1_step: int = visual_data.get("note1_step", 10)
	var note2_step: int = visual_data.get("note2_step", 9)
	var note1_accidental: String = str(visual_data.get("note1_accidental", ""))
	var note2_accidental: String = str(visual_data.get("note2_accidental", ""))
	var interval_label: String = visual_data.get("label", "")

	var min_step: int = mini(note1_step, note2_step)
	var max_step: int = maxi(note1_step, note2_step)
	var height := 200.0
	var extra_top := 0.0
	if min_step < -2:
		extra_top = absf(min_step + 2) * 10.0
		height += extra_top
	if max_step > 10:
		height += (max_step - 10) * 10.0

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))
	_content_vbox.add_child(container)

	# Draw first note
	var x1 := line_x + line_w * 0.35
	var y1 := staff_top + note1_step * (gap / 2.0)
	_draw_note_ledger_lines(container, note1_step, staff_top, gap, x1)
	var note1_id := LMD.step_to_note_id(clef, note1_step)
	note1_id = _apply_accidental_to_note_id(note1_id, note1_accidental)
	_add_staff_accidental_label(container, note1_accidental, Vector2(x1, y1))
	_add_teaching_notehead(container, Vector2(x1, y1), _note_label_from_id(note1_id))

	# Draw second note
	var x2 := line_x + line_w * 0.65
	var y2 := staff_top + note2_step * (gap / 2.0)
	_draw_note_ledger_lines(container, note2_step, staff_top, gap, x2)
	var note2_id := LMD.step_to_note_id(clef, note2_step)
	note2_id = _apply_accidental_to_note_id(note2_id, note2_accidental)
	_add_staff_accidental_label(container, note2_accidental, Vector2(x2, y2))
	_add_teaching_notehead(container, Vector2(x2, y2), _note_label_from_id(note2_id))

	# Interval bracket/label
	if interval_label != "":
		var lbl := Label.new()
		lbl.text = interval_label
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(lbl)

	# Keyboard visual showing the interval distance on piano keys
	var show_keyboard: bool = visual_data.get("show_keyboard", false)
	if show_keyboard and note1_id != "" and note2_id != "":
		var kb_color1 := Color(0.20, 0.45, 0.72, 0.95)
		var kb_color2 := Color(0.85, 0.48, 0.18, 0.95)
		var kb_wrapper: Control = _build_interval_piano_keyboard(note1_id, note2_id, kb_color1, kb_color2)
		_content_vbox.add_child(kb_wrapper)

		# Count label: "C - F: count up 4 letter names"
		var letter_names := ["C", "D", "E", "F", "G", "A", "B"]
		var n1_letter: String = note1_id[0]
		var n2_letter: String = note2_id[0]
		var idx1: int = letter_names.find(n1_letter)
		var idx2: int = letter_names.find(n2_letter)
		if idx1 >= 0 and idx2 >= 0:
			var letter_count: int = ((idx2 - idx1) % 7 + 7) % 7 + 1
			var count_lbl := Label.new()
			count_lbl.text = "%s → %s: count up %d letter name%s" % [note1_id, note2_id, letter_count, "s" if letter_count != 1 else ""]
			count_lbl.add_theme_font_override("font", FONT_BODY)
			count_lbl.add_theme_font_size_override("font_size", 14)
			count_lbl.add_theme_color_override("font_color", TEXT_MUTED)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_content_vbox.add_child(count_lbl)

	# Play both notes
	if note1_id != "":
		_play_note_audio(note1_id)
	if note2_id != "":
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self):
			_play_note_audio(note2_id)


func _draw_note_audio_compare(visual_data: Dictionary) -> void:
	var note1_id: String = visual_data.get("note1_id", "C4")
	var note2_id: String = visual_data.get("note2_id", "C#4")
	var label1: String = visual_data.get("label1", note1_id)
	var label2: String = visual_data.get("label2", note2_id)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	_content_vbox.add_child(hbox)

	# Build two side-by-side panels
	for i in 2:
		var n_id: String = note1_id if i == 0 else note2_id
		var n_label: String = label1 if i == 0 else label2

		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.16, 0.26, 0.70)
		sb.corner_radius_top_left = 16
		sb.corner_radius_top_right = 16
		sb.corner_radius_bottom_left = 16
		sb.corner_radius_bottom_right = 16
		sb.border_color = ACCENT_GOLD.lerp(Color.WHITE, 0.3) if i == 0 else Color(0.45, 0.65, 0.95, 0.8)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", sb)
		hbox.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		panel.add_child(vbox)

		var note_lbl := Label.new()
		note_lbl.text = n_label
		note_lbl.add_theme_font_override("font", FONT_TITLE)
		note_lbl.add_theme_font_size_override("font_size", 32)
		note_lbl.add_theme_color_override("font_color", ACCENT_GOLD if i == 0 else Color(0.50, 0.72, 1.0, 1.0))
		note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(note_lbl)

		var play_btn := Button.new()
		play_btn.text = " --  Play"
		play_btn.add_theme_font_override("font", FONT_BODY)
		play_btn.add_theme_font_size_override("font_size", 14)
		play_btn.custom_minimum_size = Vector2(90, 32)
		_style_flat_button(play_btn)
		play_btn.add_theme_color_override("font_color", ACCENT_GOLD)
		var captured := n_id
		play_btn.pressed.connect(func(): _play_note_audio(captured))
		vbox.add_child(play_btn)

	# Replay both button
	var replay_row := HBoxContainer.new()
	replay_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_vbox.add_child(replay_row)
	var replay := Button.new()
	replay.text = " --  Play Both"
	replay.add_theme_font_override("font", FONT_BODY)
	replay.add_theme_font_size_override("font_size", 14)
	replay.custom_minimum_size = Vector2(120, 32)
	_style_flat_button(replay)
	replay.add_theme_color_override("font_color", ACCENT_GOLD)
	var cap1 := note1_id
	var cap2 := note2_id
	replay.pressed.connect(func():
		_play_note_audio(cap1)
		await get_tree().create_timer(0.7).timeout
		if is_instance_valid(self):
			_play_note_audio(cap2)
	)
	replay_row.add_child(replay)

	# Auto-play both on load
	_play_note_audio(note1_id)
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(self):
		_play_note_audio(note2_id)


func _play_rhythm_demo(visual_data: Dictionary, initial_delay: float = 0.0, staff_root: Control = null) -> void:
	var bars: Array = visual_data.get("bars", [])
	if bars.is_empty():
		bars = [[{"kind": str(visual_data.get("value", "quarter")), "beats": float(visual_data.get("beats", 1.0))}]]

	var total_beats := 0.0
	for bar in bars:
		for item in bar:
			total_beats += _get_rhythm_item_duration(item)
	if total_beats <= 0.0:
		return

	_rhythm_playback_token += 1
	var playback_token: int = _rhythm_playback_token
	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay).timeout
		if not is_instance_valid(self) or playback_token != _rhythm_playback_token:
			return

	# Find animation targets from staff_root metadata
	var note_layouts: Array = []
	var beat_labels: Array = []
	if staff_root != null and is_instance_valid(staff_root):
		if staff_root.has_meta("_note_layouts"):
			note_layouts = staff_root.get_meta("_note_layouts")
		if staff_root.has_meta("_beat_labels"):
			beat_labels = staff_root.get_meta("_beat_labels")

	var bpm: int = int(visual_data.get("bpm", 84))
	var top_num: int = int(visual_data.get("top", 4))
	var bottom_num: int = int(visual_data.get("bottom", 4))
	var beats_per_bar := float(top_num) * (4.0 / maxf(float(bottom_num), 1.0))
	var beat_dur_sec: float = 60.0 / float(maxi(bpm, 1))

	# Build per-note schedule: each note's start beat and duration
	var note_schedule: Array = []
	var cursor := 0.0
	for bar in bars:
		for item in bar:
			var dur := _get_rhythm_item_duration(item)
			note_schedule.append({"start": cursor, "duration": dur})
			cursor += dur

	var click_count := int(ceil(total_beats))
	var highlight_color := Color(0.30, 0.95, 0.45, 1.0)  # fluorescent green
	var loop_count: int = int(visual_data.get("loop_count", 1))

	for loop_idx in range(loop_count):
		var prev_note_idx := -1
		for click_index in range(click_count):
			if not is_instance_valid(self) or playback_token != _rhythm_playback_token:
				return
			var is_downbeat := is_zero_approx(fmod(float(click_index), beats_per_bar))
			_play_metronome_click(is_downbeat)

			# Animate beat label: pulse scale + green color
			if click_index < beat_labels.size():
				var bl: Label = beat_labels[click_index]
				if is_instance_valid(bl):
					bl.add_theme_color_override("font_color", highlight_color if is_downbeat else Color(0.20, 0.85, 0.35, 0.95))
					bl.pivot_offset = bl.size / 2.0
					var bl_tw := bl.create_tween()
					bl_tw.tween_property(bl, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					bl_tw.tween_property(bl, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

			# Find which note is active at this beat and highlight it
			var active_note_idx := -1
			for ni in note_schedule.size():
				if float(click_index) >= note_schedule[ni]["start"] and float(click_index) < note_schedule[ni]["start"] + note_schedule[ni]["duration"]:
					active_note_idx = ni
					break
			if active_note_idx != prev_note_idx:
				# Un-highlight previous note
				if prev_note_idx >= 0 and prev_note_idx < note_layouts.size():
					var prev_layout: Dictionary = note_layouts[prev_note_idx]
					var prev_head: Control = prev_layout.get("head")
					if prev_head != null and is_instance_valid(prev_head):
						prev_head.modulate = Color(1, 1, 1, 1)
					var prev_stem: Control = prev_layout.get("stem")
					if prev_stem != null and is_instance_valid(prev_stem):
						prev_stem.modulate = Color(1, 1, 1, 1)
				# Highlight current note with green glow + scale pulse
				if active_note_idx >= 0 and active_note_idx < note_layouts.size():
					var layout: Dictionary = note_layouts[active_note_idx]
					var head: Control = layout.get("head")
					if head != null and is_instance_valid(head):
						head.modulate = highlight_color
						head.pivot_offset = head.size / 2.0
						var head_tw := head.create_tween()
						head_tw.tween_property(head, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
						head_tw.tween_property(head, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					var stem: Control = layout.get("stem")
					if stem != null and is_instance_valid(stem):
						stem.modulate = highlight_color
				prev_note_idx = active_note_idx

			if click_index < click_count - 1:
				await get_tree().create_timer(beat_dur_sec).timeout

		# Brief pause between loops
		if loop_idx < loop_count - 1:
			# Reset highlights before next loop
			for layout in note_layouts:
				var lh: Control = layout.get("head")
				if lh != null and is_instance_valid(lh):
					lh.modulate = Color(1, 1, 1, 1)
				var ls: Control = layout.get("stem")
				if ls != null and is_instance_valid(ls):
					ls.modulate = Color(1, 1, 1, 1)
			for bl in beat_labels:
				if is_instance_valid(bl):
					bl.add_theme_color_override("font_color", Color(0.48, 0.35, 0.08, 0.98))
			await get_tree().create_timer(beat_dur_sec * 0.5).timeout
			if not is_instance_valid(self) or playback_token != _rhythm_playback_token:
				return

	# Reset all highlights after playback
	for layout in note_layouts:
		var head: Control = layout.get("head")
		if head != null and is_instance_valid(head):
			head.modulate = Color(1, 1, 1, 1)
		var stem: Control = layout.get("stem")
		if stem != null and is_instance_valid(stem):
			stem.modulate = Color(1, 1, 1, 1)
	for bl in beat_labels:
		if is_instance_valid(bl):
			bl.add_theme_color_override("font_color", Color(0.48, 0.35, 0.08, 0.98))


# ---- Practice Round Step ----

func _render_practice_round_step(step: Dictionary) -> void:
	_quiz_answered = false
	_quiz_correct = false

	var pool: Array = step.get("pool", [])
	var target: int = step.get("target_correct", 10)
	var pool_type: String = step.get("pool_type", "note")

	# Initialize on first entry
	if _practice_pool.is_empty() or _practice_index == 0:
		_practice_pool = pool.duplicate()
		_practice_pool.shuffle()
		_practice_target = mini(target, _practice_pool.size())
		_practice_total = _practice_pool.size()
		_practice_index = 0
		_practice_correct = 0
		_practice_pool_type = pool_type

	if _practice_index >= _practice_total:
		_show_practice_summary()
		return

	_render_practice_item()


func _render_practice_item() -> void:
	_step_render_time = Time.get_ticks_msec() / 1000.0
	_clear_content()
	_quiz_answered = false
	_quiz_attempts_this_step = 0
	_prev_btn.visible = false
	_next_btn.visible = false

	# Progress header
	var progress_lbl := Label.new()
	progress_lbl.text = "Practice  %d / %d" % [_practice_index + 1, _practice_total]
	progress_lbl.add_theme_font_override("font", FONT_TITLE)
	progress_lbl.add_theme_font_size_override("font_size", 18)
	progress_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(progress_lbl)

	# Score indicator
	var score_lbl := Label.new()
	score_lbl.text = "%d correct so far" % _practice_correct
	score_lbl.add_theme_font_override("font", FONT_BODY)
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.add_theme_color_override("font_color", Color(0.50, 0.80, 0.55, 0.80))
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(score_lbl)

	var item: Dictionary = _practice_pool[_practice_index]

	if _practice_pool_type == "theory":
		_render_practice_theory_item(item)
	else:
		_render_practice_note_item(item)

	_animate_content_in()


func _render_practice_note_item(item: Dictionary) -> void:
	var clef: String = item.get("clef", "treble")
	var note_step: int = int(item.get("note_step", 4))
	var note_id: String = item.get("note_id", "")
	var correct_letter: String = item.get("note_name", "C")

	# Build staff
	var height := 170.0
	var extra_top := 0.0
	if note_step < -2:
		extra_top = absf(note_step + 2) * 10.0
		height += extra_top
	elif note_step > 10:
		height += (note_step - 10) * 10.0

	var staff := _create_teaching_staff(clef, 380.0, height)
	var container: Control = staff["container"]
	var s_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))
	_content_vbox.add_child(container)

	var note_x := line_x + line_w * 0.5
	var note_y := s_top + note_step * (gap / 2.0)
	_draw_note_ledger_lines(container, note_step, s_top, gap, note_x)
	var head := _create_oval_notehead(_pick_note_head_color())
	head.position = Vector2(note_x - head.size.x / 2.0, note_y - head.size.y / 2.0)
	container.add_child(head)

	# Idle bob ---- matches sight reader ---1px sine bounce
	var _head_y0: float = head.position.y
	var bob_tw := container.create_tween()
	bob_tw.set_loops()
	bob_tw.tween_property(head, "position:y", _head_y0 - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tw.tween_property(head, "position:y", _head_y0 + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if note_id != "":
		_play_note_audio(note_id)

	# Generate choices: 1 adjacent + 2 non-adjacent distractors (4 total)
	var all_letters := ["C", "D", "E", "F", "G", "A", "B"]
	var ci: int = all_letters.find(correct_letter)
	var adjacent: Array[String] = []
	var non_adjacent: Array[String] = []
	for offset in [-1, 1]:
		var didx: int = (ci + offset + 7) % 7
		var d: String = all_letters[didx]
		if d != correct_letter and not adjacent.has(d):
			adjacent.append(d)
	for offset in [-3, 3, -4, 4]:
		var didx: int = (ci + offset + 7) % 7
		var d: String = all_letters[didx]
		if d != correct_letter and not adjacent.has(d) and not non_adjacent.has(d):
			non_adjacent.append(d)
		if non_adjacent.size() >= 2:
			break
	adjacent.shuffle()
	non_adjacent.shuffle()
	var distractors: Array[String] = []
	if adjacent.size() > 0:
		distractors.append(adjacent[0])
	for d in non_adjacent:
		distractors.append(d)
		if distractors.size() >= 3:
			break
	# Fill remaining from adjacent if needed
	if distractors.size() < 3 and adjacent.size() > 1:
		distractors.append(adjacent[1])

	var choices: Array[String] = [correct_letter]
	for d in distractors:
		choices.append(d)
	choices.shuffle()
	var correct_index: int = choices.find(correct_letter)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(btn_row)

	for i in choices.size():
		var btn := _create_quiz_choice_button(choices[i])
		btn.pressed.connect(_on_practice_answer.bind(i, correct_index, btn, btn_row, item))
		btn_row.add_child(btn)


func _render_practice_theory_item(item: Dictionary) -> void:
	var question: String = item.get("question", "")
	var choices: Array = item.get("choices", [])
	var correct_index: int = item.get("correct_index", 0)

	var q_label := Label.new()
	q_label.text = question
	q_label.add_theme_font_override("font", FONT_TITLE)
	q_label.add_theme_font_size_override("font_size", 20)
	q_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(q_label)

	var reference_visual_type: String = str(item.get("reference_visual_type", ""))
	if reference_visual_type != "":
		_draw_visual_content(reference_visual_type, item.get("reference_visual_data", {}))

	var choice_visuals: Array = item.get("choice_visuals", [])
	var choice_visual_type: String = str(item.get("choice_visual_type", ""))
	var btn_row: Control
	if choice_visual_type != "" and choice_visuals.size() == choices.size():
		var grid := GridContainer.new()
		grid.columns = mini(choices.size(), 2)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 14)
		btn_row = grid
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		btn_row = row
	_content_vbox.add_child(btn_row)

	for i in choices.size():
		var btn: Button
		if choice_visual_type != "" and i < choice_visuals.size():
			var choice_card := _build_choice_card(str(choices[i]), choice_visual_type, choice_visuals[i])
			btn = _collect_choice_buttons(choice_card)[0]
			btn_row.add_child(choice_card)
		else:
			btn = _create_quiz_choice_button(str(choices[i]))
			btn_row.add_child(btn)
		btn.pressed.connect(_on_practice_answer.bind(i, correct_index, btn, btn_row, item))


func _on_practice_answer(selected: int, correct: int, _btn: Button, btn_row: Control, item: Dictionary) -> void:
	if _quiz_answered:
		return
	_quiz_answered = true
	_quiz_attempts_this_step += 1

	# Color feedback
	var buttons := _collect_choice_buttons(btn_row)
	for i in buttons.size():
		var child := buttons[i]
		child.disabled = true
		if i == correct:
			var sb_ok: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate()
			sb_ok.bg_color = CORRECT_COLOR
			child.add_theme_stylebox_override("disabled", sb_ok)
		elif i == selected and selected != correct:
			var sb_bad: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate()
			sb_bad.bg_color = WRONG_COLOR
			child.add_theme_stylebox_override("disabled", sb_bad)

	var concept_id: String = item.get("concept_id", "")
	if concept_id == "":
		var clef: String = item.get("clef", "")
		var note_id: String = item.get("note_id", "")
		if clef != "" and note_id != "":
			concept_id = "%s:%s" % [clef, note_id]

	if selected == correct:
		_practice_correct += 1
		_chicken_label.text = _random_correct_line()
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		_record_learning_result(item, true, _quiz_attempts_this_step == 1, concept_id, _get_skill_family_for_step(item, concept_id))
		_module_quiz_count += 1
		if _quiz_attempts_this_step == 1:
			_module_first_try_correct += 1
		# Play note audio on correct
		var note_id: String = item.get("note_id", "")
		if note_id != "":
			_play_note_audio(note_id)
	else:
		# Build specific wrong-answer feedback
		var feedback_text: String = ""
		if item.has("note_name") and item.get("clef", "") != "":
			# Note practice item ---- show correct note + position hint
			var correct_note: String = item.get("note_name", "")
			var note_step: int = int(item.get("note_step", 0))
			var is_on_line: bool = (note_step % 2 == 0)
			var position_hint: String = "on a line" if is_on_line else "in a space"
			feedback_text = "That's %s  --  %s on the %s staff" % [correct_note, position_hint, item.get("clef", "treble")]
		elif item.has("choices") and item.has("correct_index"):
			# Theory practice item ---- show correct answer text
			var choices_arr: Array = item.get("choices", [])
			var ci2: int = item.get("correct_index", 0)
			if ci2 >= 0 and ci2 < choices_arr.size():
				feedback_text = "The answer is: %s" % str(choices_arr[ci2])
		if feedback_text == "":
			feedback_text = _random_wrong_line()
		_chicken_label.text = feedback_text
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
		_record_learning_result(item, false, false, concept_id, _get_skill_family_for_step(item, concept_id))
		_show_wrong_answer_card(item, feedback_text)
		_module_quiz_count += 1

	# Show inline Next button (user must click to advance)
	_add_inline_next_button(btn_row.get_parent(), func():
		_practice_index += 1
		_quiz_answered = false
		if _test_out_mode:
			if _practice_index >= _practice_total:
				_finish_test_out()
			else:
				_render_practice_item()
		elif _practice_index >= _practice_total:
			var steps2: Array = _get_active_steps()
			if _current_step < steps2.size():
				_show_practice_summary()
		else:
			_render_practice_item()
	)


func _show_practice_summary() -> void:
	_clear_content()
	_quiz_correct = true  # Allow advancing

	var pct: int = 0
	if _practice_total > 0:
		pct = int(float(_practice_correct) / float(_practice_total) * 100.0)

	var title := Label.new()
	title.text = "Practice Complete!"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	var score_lbl := Label.new()
	score_lbl.text = "%d / %d correct  (%d%%)" % [_practice_correct, _practice_total, pct]
	score_lbl.add_theme_font_override("font", FONT_BODY)
	score_lbl.add_theme_font_size_override("font_size", 20)
	score_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(score_lbl)

	if pct >= 90:
		_chicken_label.text = "Outstanding! You really know this material!"
	elif pct >= 70:
		_chicken_label.text = "Good work! Keep practicing to master this!"
	else:
		_chicken_label.text = "Keep at it! Practice makes perfect!"

	# Reset for potential re-entry
	_practice_pool = []
	_practice_index = 0
	_update_nav_buttons()
	_animate_content_in()


func _finish_test_out() -> void:
	_clear_content()
	var pct: int = 0
	if _test_out_overall_answers > 0:
		pct = int(round((float(_test_out_overall_correct) / float(_test_out_overall_answers)) * 100.0))
	var family_pass: bool = true
	var family_lines: Array[String] = []
	for family in _test_out_skill_totals.keys():
		var total: int = int(_test_out_skill_totals.get(family, 0))
		if total <= 0:
			continue
		var correct: int = int(_test_out_skill_correct.get(family, 0))
		var needed: int = maxi(1, int(ceil(float(total) * 0.5)))
		var family_name: String = str(family).capitalize()
		family_lines.append("%s: %d/%d" % [family_name, correct, total])
		if correct < needed:
			family_pass = false

	var is_placement_mode: bool = bool(_module_data.get("placement_mode", false))
	if is_placement_mode:
		if _progress != null and _progress.has_method("set_placement_result"):
			_progress.set_placement_result(pct, _test_out_skill_correct.duplicate(true), _test_out_skill_totals.duplicate(true))
		_play_sfx("res://assets/audio/sfx/fanfare-2-rpg.wav")
		_chicken_label.text = "Placement check complete. Your learning path is updated."

		var placement_title := Label.new()
		placement_title.text = "Placement Check Complete"
		placement_title.add_theme_font_override("font", FONT_TITLE)
		placement_title.add_theme_font_size_override("font_size", 30)
		placement_title.add_theme_color_override("font_color", ACCENT_GOLD)
		placement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(placement_title)

		var placement_score := Label.new()
		placement_score.text = "%d / %d  (%d%%)" % [_test_out_overall_correct, _test_out_overall_answers, pct]
		placement_score.add_theme_font_override("font", FONT_BODY)
		placement_score.add_theme_font_size_override("font_size", 20)
		placement_score.add_theme_color_override("font_color", TEXT_PRIMARY)
		placement_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(placement_score)

		var placement_info := Label.new()
		placement_info.text = "Use the unlocked modules and review plan on the map to start at the right level."
		placement_info.add_theme_font_override("font", FONT_BODY)
		placement_info.add_theme_font_size_override("font_size", 16)
		placement_info.add_theme_color_override("font_color", TEXT_MUTED)
		placement_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placement_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(placement_info)

		if not family_lines.is_empty():
			var placement_family_lbl := Label.new()
			placement_family_lbl.text = "Skill checks: %s" % ", ".join(family_lines)
			placement_family_lbl.add_theme_font_override("font", FONT_BODY)
			placement_family_lbl.add_theme_font_size_override("font_size", 15)
			placement_family_lbl.add_theme_color_override("font_color", TEXT_MUTED)
			placement_family_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placement_family_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content_vbox.add_child(placement_family_lbl)

		var placement_return_btn := _create_nav_button("Return to Map")
		placement_return_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var placement_module_id: String = _module_data.get("id", "")
		placement_return_btn.pressed.connect(func():
			lesson_completed.emit(placement_module_id)
		)
		_content_vbox.add_child(placement_return_btn)
		_prev_btn.visible = false
		_next_btn.visible = false
		_progress_bar.value = _progress_bar.max_value
		_animate_content_in()
		return

	var passed: bool = pct >= TEST_OUT_REQUIRED_PERCENT and family_pass

	if passed:
		var module_id: String = _module_data.get("id", "")
		var stars := 2
		if pct == 100:
			stars = 3
		_progress.set_module_completed(module_id)
		_progress.set_module_stars(module_id, stars)
		_play_sfx("res://assets/audio/sfx/fanfare-2-rpg.wav")
		_chicken_label.text = "You already know this! Module complete!"

		var title := Label.new()
		title.text = "Test Out: Passed!"
		title.add_theme_font_override("font", FONT_TITLE)
		title.add_theme_font_size_override("font_size", 30)
		title.add_theme_color_override("font_color", CORRECT_COLOR)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(title)

		var score_lbl := Label.new()
		score_lbl.text = "%d / %d  (%d%%)" % [_test_out_overall_correct, _test_out_overall_answers, pct]
		score_lbl.add_theme_font_override("font", FONT_BODY)
		score_lbl.add_theme_font_size_override("font_size", 20)
		score_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(score_lbl)

		if not family_lines.is_empty():
			var family_lbl := Label.new()
			family_lbl.text = "Skill checks: %s" % ", ".join(family_lines)
			family_lbl.add_theme_font_override("font", FONT_BODY)
			family_lbl.add_theme_font_size_override("font_size", 15)
			family_lbl.add_theme_color_override("font_color", TEXT_MUTED)
			family_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			family_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content_vbox.add_child(family_lbl)

		var return_btn := _create_nav_button("Return to Map")
		return_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return_btn.pressed.connect(func():
			lesson_completed.emit(module_id)
		)
		_content_vbox.add_child(return_btn)
	else:
		_chicken_label.text = "Not quite - let's go through the lesson!"

		var title := Label.new()
		title.text = "Test Out: %d%%" % pct
		title.add_theme_font_override("font", FONT_TITLE)
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", ACCENT_GOLD)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(title)

		var info := Label.new()
		var info_text := "You need %d%% overall to skip this lesson." % TEST_OUT_REQUIRED_PERCENT
		if not family_pass:
			info_text += " You also need at least half correct in each skill area."
		info_text += " Let's learn together!"
		info.text = info_text
		info.add_theme_font_override("font", FONT_BODY)
		info.add_theme_font_size_override("font_size", 16)
		info.add_theme_color_override("font_color", TEXT_MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(info)

		if not family_lines.is_empty():
			var family_lbl := Label.new()
			family_lbl.text = "Skill checks: %s" % ", ".join(family_lines)
			family_lbl.add_theme_font_override("font", FONT_BODY)
			family_lbl.add_theme_font_size_override("font_size", 15)
			family_lbl.add_theme_color_override("font_color", TEXT_MUTED)
			family_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			family_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content_vbox.add_child(family_lbl)

		var start_btn := _create_nav_button("Start Lesson")
		start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		start_btn.pressed.connect(func():
			_test_out_mode = false
			_test_out_steps = []
			_test_out_skill_totals = {}
			_test_out_skill_correct = {}
			_test_out_overall_answers = 0
			_test_out_overall_correct = 0
			_current_step = 0
			_practice_pool = []
			_practice_index = 0
			_render_step()
		)
		_content_vbox.add_child(start_btn)

	_prev_btn.visible = false
	_next_btn.visible = false
	_practice_pool = []
	_practice_index = 0
	_animate_content_in()


func _create_quiz_choice_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", FONT_TITLE)
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(90, 50)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.14, 0.22, 0.36, 0.90)
	btn_sb.corner_radius_top_left = 14
	btn_sb.corner_radius_top_right = 14
	btn_sb.corner_radius_bottom_left = 14
	btn_sb.corner_radius_bottom_right = 14
	btn_sb.border_color = ACCENT_GOLD
	btn_sb.border_width_left = 2
	btn_sb.border_width_top = 2
	btn_sb.border_width_right = 2
	btn_sb.border_width_bottom = 2
	btn_sb.content_margin_left = 14
	btn_sb.content_margin_right = 14
	btn_sb.content_margin_top = 8
	btn_sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate()
	btn_hover.bg_color = Color(0.20, 0.30, 0.46, 0.95)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60, 1.0))
	return btn


func _add_inline_next_button(parent: Control, callback: Callable) -> void:
	# Add a "Next" button below the quiz choices for user to advance
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	row.add_child(spacer)

	var next_btn := Button.new()
	next_btn.text = "Next  >"
	next_btn.add_theme_font_override("font", FONT_TITLE)
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.custom_minimum_size = Vector2(120, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9098, 0.6275, 0.1255, 0.85)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	next_btn.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(1.0, 0.75, 0.20, 0.95)
	next_btn.add_theme_stylebox_override("hover", sb_hover)
	next_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
	next_btn.pressed.connect(callback)
	row.add_child(next_btn)

	# Animate fade-in
	next_btn.modulate.a = 0.0
	var tw := next_btn.create_tween()
	tw.tween_property(next_btn, "modulate:a", 1.0, 0.2).set_delay(0.3)


# ---- Listening Quiz Step ----

func _render_listening_quiz_step(step: Dictionary) -> void:
	_quiz_answered = false
	_quiz_correct = false

	var items: Array = step.get("items", [])
	if _listening_items.is_empty() or _listening_index == 0:
		_listening_items = items.duplicate()
		_listening_items.shuffle()
		_listening_index = 0
		_listening_correct = 0

	if _listening_index >= _listening_items.size():
		_quiz_correct = true
		_clear_content()
		_chicken_label.text = "Listening review done! %d / %d correct!" % [_listening_correct, _listening_items.size()]
		var done_lbl := Label.new()
		done_lbl.text = "Listening Complete!"
		done_lbl.add_theme_font_override("font", FONT_TITLE)
		done_lbl.add_theme_font_size_override("font_size", 26)
		done_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(done_lbl)
		_listening_items = []
		_listening_index = 0
		_update_nav_buttons()
		_animate_content_in()
		return

	_render_listening_item()


func _render_listening_item() -> void:
	_clear_content()
	_quiz_answered = false
	_quiz_attempts_this_step = 0
	_prev_btn.visible = false
	_next_btn.visible = false

	var item: Dictionary = _listening_items[_listening_index]
	var note_ids: Array = item.get("note_ids", [])
	var choices: Array = item.get("choices", [])
	var correct_index: int = item.get("correct_index", 0)

	_chicken_label.text = "Listen carefully  --  what do you hear?"

	var title := Label.new()
	title.text = "Listening  %d / %d" % [_listening_index + 1, _listening_items.size()]
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEXT_MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	# Play button
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(play_row)

	var play_btn := Button.new()
	play_btn.text = " --   Play"
	play_btn.add_theme_font_override("font", FONT_TITLE)
	play_btn.add_theme_font_size_override("font_size", 22)
	play_btn.custom_minimum_size = Vector2(160, 56)
	var play_sb := StyleBoxFlat.new()
	play_sb.bg_color = Color(0.18, 0.35, 0.55, 0.90)
	play_sb.corner_radius_top_left = 14
	play_sb.corner_radius_top_right = 14
	play_sb.corner_radius_bottom_left = 14
	play_sb.corner_radius_bottom_right = 14
	play_sb.content_margin_left = 16
	play_sb.content_margin_right = 16
	play_sb.content_margin_top = 10
	play_sb.content_margin_bottom = 10
	play_btn.add_theme_stylebox_override("normal", play_sb)
	play_btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	var captured_ids := note_ids.duplicate()
	play_btn.pressed.connect(func(): _play_listening_notes(captured_ids))
	play_row.add_child(play_btn)

	# Auto-play
	_play_listening_notes(note_ids)

	# Answer buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(btn_row)

	for i in choices.size():
		var btn := _create_quiz_choice_button(str(choices[i]))
		btn.pressed.connect(_on_listening_answer.bind(i, correct_index, btn, btn_row, item))
		btn_row.add_child(btn)

	_animate_content_in()


func _load_note_stream(note_id: String) -> AudioStream:
	return _get_note_audio_stream(note_id)


func _play_notes_harmonic(note_ids: Array) -> void:
	# Play up to 3 notes simultaneously on separate AudioStreamPlayers
	var players: Array[AudioStreamPlayer] = [_note_player, _note_player_2, _note_player_3]
	for i in mini(note_ids.size(), players.size()):
		var stream := _load_note_stream(str(note_ids[i]))
		if stream != null and players[i] != null:
			players[i].stream = stream
			players[i].play()


func _play_listening_notes(note_ids: Array) -> void:
	if note_ids.is_empty():
		return
	# Chords (3+ notes): play harmonically (simultaneously)
	if note_ids.size() >= 3:
		_play_notes_harmonic(note_ids)
		return
	# Intervals (2 notes) or single notes: play sequentially
	for i in note_ids.size():
		_play_note_audio(str(note_ids[i]))
		if i < note_ids.size() - 1:
			await get_tree().create_timer(0.5).timeout
			if not is_instance_valid(self):
				return


func _on_listening_answer(selected: int, correct: int, btn: Button, btn_row: HBoxContainer, item: Dictionary) -> void:
	if _quiz_answered:
		return
	_quiz_answered = true
	_quiz_attempts_this_step += 1

	for i in btn_row.get_child_count():
		var child := btn_row.get_child(i)
		if child is Button:
			child.disabled = true
			if i == correct:
				var sb_ok: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate()
				sb_ok.bg_color = CORRECT_COLOR
				child.add_theme_stylebox_override("disabled", sb_ok)
			elif i == selected and selected != correct:
				var sb_bad: StyleBoxFlat = child.get_theme_stylebox("normal").duplicate()
				sb_bad.bg_color = WRONG_COLOR
				child.add_theme_stylebox_override("disabled", sb_bad)

	var concept_id: String = item.get("concept_id", "listening:" + str(item.get("label", "")))
	if selected == correct:
		_listening_correct += 1
		_chicken_label.text = "Correct! That's a %s!" % str(item.get("label", ""))
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		_module_quiz_count += 1
		if _quiz_attempts_this_step == 1:
			_module_first_try_correct += 1
		_record_learning_result({"type": LMD.STEP_LISTENING_QUIZ, "concept_id": concept_id, "test_out_family": "listening"}, true, _quiz_attempts_this_step == 1, concept_id, "listening")
	else:
		var correct_label: String = str(item.get("label", ""))
		_chicken_label.text = "That was a %s  --  listen again!" % correct_label
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
		_module_quiz_count += 1
		_record_learning_result({"type": LMD.STEP_LISTENING_QUIZ, "concept_id": concept_id, "test_out_family": "listening"}, false, false, concept_id, "listening")
		_show_wrong_answer_card({"type": LMD.STEP_LISTENING_QUIZ, "concept_id": concept_id}, "That sound was %s. Replay it and compare the contour before answering again." % correct_label)
		# Replay the correct answer
		var note_ids: Array = item.get("note_ids", [])
		if not note_ids.is_empty():
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(self):
				_play_listening_notes(note_ids)

	# Show inline Next button for user to advance
	_add_inline_next_button(btn_row.get_parent(), func():
		_listening_index += 1
		_quiz_answered = false
		var steps2: Array = _get_active_steps()
		if _listening_index >= _listening_items.size():
			if _current_step < steps2.size():
				_render_listening_quiz_step(steps2[_current_step])
		else:
			_render_listening_item()
	)


# ---- Melody Example Step ----

func _render_melody_example_step(step: Dictionary) -> void:
	var clef: String = step.get("clef", "treble")
	var notes: Array = step.get("notes", [])
	var melody_name: String = step.get("melody_name", "")

	var title := Label.new()
	title.text = step.get("title", "Melody")
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	if melody_name != "":
		var name_lbl := Label.new()
		name_lbl.text = melody_name
		name_lbl.add_theme_font_override("font", FONT_BODY)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(name_lbl)

	# Build wide staff
	var width := 520.0
	var staff := _create_teaching_staff(clef, width, 160.0)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"]
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]
	_content_vbox.add_child(container)

	# Place notes evenly across the staff
	var note_count: int = notes.size()
	if note_count == 0:
		return
	var spacing: float = line_w / float(note_count + 1)
	var note_ids: Array[String] = []

	for i in note_count:
		var n: Dictionary = notes[i]
		var note_step: int = n.get("note_step", 4)
		var note_id: String = n.get("note_id", "")
		note_ids.append(note_id)
		var nx := line_x + spacing * (i + 1)
		var ny := staff_top + note_step * (gap / 2.0)
		_draw_note_ledger_lines(container, note_step, staff_top, gap, nx)
		var head_color := _pick_note_head_color()
		var head_w := 26.0
		var head_h := 18.0
		var head := Panel.new()
		head.size = Vector2(head_w, head_h)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_notehead_material(head, head_color, Color(0.06, 0.06, 0.08, 0.85))
		head.position = Vector2(nx - head_w / 2.0, ny - head_h / 2.0)
		container.add_child(head)

		# Note name inside the note head in contrasting white
		var note_text: String = note_id.left(note_id.length() - 1) if note_id.length() >= 2 else note_id
		var lbl := Label.new()
		lbl.text = note_text
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.5))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.position = Vector2(head_w / 2.0 - 5, -1)
		head.add_child(lbl)

	# Play button
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_vbox.add_child(play_row)

	var play_btn := Button.new()
	play_btn.text = " --   Play Melody"
	play_btn.add_theme_font_override("font", FONT_TITLE)
	play_btn.add_theme_font_size_override("font_size", 18)
	play_btn.custom_minimum_size = Vector2(160, 44)
	_style_flat_button(play_btn)
	play_btn.add_theme_color_override("font_color", ACCENT_GOLD)
	var captured_ids := note_ids.duplicate()
	var captured_notes := notes.duplicate()
	_preload_note_audio_streams(captured_ids)
	play_btn.pressed.connect(func(): _play_melody_notes(captured_ids, captured_notes, 0.0))
	play_row.add_child(play_btn)

	# Sing-along prompt
	var sing_lbl := Label.new()
	sing_lbl.text = "🎤  Now try singing or humming it back!"
	sing_lbl.add_theme_font_override("font", FONT_BODY)
	sing_lbl.add_theme_font_size_override("font_size", 14)
	sing_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 0.85))
	sing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(sing_lbl)

	# Auto-play
	var autoplay_wait := maxf(MELODY_AUTOPLAY_DELAY - (Time.get_ticks_msec() / 1000.0 - _step_render_time), 0.0)
	_play_melody_notes(note_ids, notes, autoplay_wait)


func _play_melody_notes(note_ids: Array, notes: Array, initial_delay: float = 0.0) -> void:
	_melody_playback_token += 1
	var playback_token: int = _melody_playback_token
	_preload_note_audio_streams(note_ids)
	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay).timeout
		if not is_instance_valid(self) or playback_token != _melody_playback_token:
			return
	for i in note_ids.size():
		if not is_instance_valid(self) or playback_token != _melody_playback_token:
			return
		_play_note_audio_immediate(str(note_ids[i]))
		var beats: float = 1.0
		if i < notes.size():
			beats = notes[i].get("beats", 1.0)
		var delay := beats * 0.45
		if i < note_ids.size() - 1:
			await get_tree().create_timer(delay).timeout
			if not is_instance_valid(self) or playback_token != _melody_playback_token:
				return
			if not is_instance_valid(self) or playback_token != _melody_playback_token:
				return


# ---- Rhythm Tap Step ----

func _apply_rhythm_tap_panel_style(panel: Panel, bg_color: Color, border_color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = border_color
	panel.add_theme_stylebox_override("panel", sb)


func _run_rhythm_tap_metronome(playback_token: int, count_lbl: Label, bpm: int, total_beats: int, time_sig_top: int) -> void:
	var beat_dur_sec: float = 60.0 / float(maxi(bpm, 1))
	for beat_index in range(total_beats):
		if playback_token != _rhythm_playback_token or not is_instance_valid(self) or not is_instance_valid(count_lbl):
			return
		var beat_in_bar: int = beat_index % maxi(time_sig_top, 1)
		count_lbl.text = str(beat_in_bar + 1)
		count_lbl.add_theme_color_override("font_color", ACCENT_GOLD if beat_in_bar == 0 else TEXT_PRIMARY)
		_play_metronome_click(beat_in_bar == 0)
		if beat_index < total_beats - 1:
			await get_tree().create_timer(beat_dur_sec).timeout


func _get_rhythm_tap_bg_color(is_rest: bool) -> Color:
	return Color(0.14, 0.18, 0.28, 0.92) if is_rest else Color(0.18, 0.24, 0.36, 0.90)


func _get_rhythm_tap_border_color(is_rest: bool) -> Color:
	return Color(0.48, 0.60, 0.76, 0.78) if is_rest else Color(0.35, 0.45, 0.60, 0.70)


func _apply_rhythm_tap_default_panel_style(panel: Panel, is_rest: bool) -> void:
	_apply_rhythm_tap_panel_style(panel, _get_rhythm_tap_bg_color(is_rest), _get_rhythm_tap_border_color(is_rest))


func _build_rhythm_tap_segments(pattern: Array, beat_dur_ms: float) -> Array:
	var segments: Array = []
	var cursor_ms := 0.0
	for pattern_item in pattern:
		var item := _normalize_rhythm_pattern_item(pattern_item)
		var beats := _get_rhythm_item_duration(item)
		item["beats"] = beats
		item["start_ms"] = cursor_ms
		item["duration_ms"] = beats * beat_dur_ms
		item["end_ms"] = cursor_ms + float(item["duration_ms"])
		if bool(item.get("rest", false)):
			var rest_kind: String = str(item.get("rest_kind", _get_default_rest_kind_for_beats(beats)))
			item["label"] = _get_rhythm_rest_label(rest_kind, beats)
		else:
			item["label"] = _get_rhythm_value_label(beats)
		segments.append(item)
		cursor_ms = float(item["end_ms"])
	return segments


func _advance_rhythm_tap_glow(beat_panels: Array, segments: Array, current_index: int) -> void:
	var next_idx := current_index + 1
	if next_idx < beat_panels.size() and is_instance_valid(beat_panels[next_idx]):
		var next_segment: Dictionary = segments[next_idx]
		var next_is_rest: bool = bool(next_segment.get("rest", false))
		_apply_rhythm_tap_panel_style(beat_panels[next_idx] as Panel, _get_rhythm_tap_bg_color(next_is_rest), ACCENT_GOLD)


func _sync_rhythm_tap_progress(state: Dictionary, beat_panels: Array, segments: Array, close_window: float) -> void:
	if not bool(state.get("started", false)) or bool(state.get("finished", false)):
		return
	var elapsed_ms: float = Time.get_ticks_msec() - float(state.get("start_time_ms", 0.0))
	var drift: float = float(state.get("drift_ms", 0.0))
	var cur: int = int(state.get("current_target", 0))
	while cur < segments.size():
		var segment: Dictionary = segments[cur]
		var is_rest: bool = bool(segment.get("rest", false))
		if is_rest:
			if elapsed_ms >= float(segment.get("end_ms", 0.0)) + drift:
				var failed_rests: Dictionary = state.get("rest_failures", {})
				var rest_failed: bool = bool(failed_rests.get(cur, false))
				if cur < beat_panels.size() and is_instance_valid(beat_panels[cur]):
					if rest_failed:
						_apply_rhythm_tap_panel_style(beat_panels[cur] as Panel, WRONG_COLOR.lerp(_get_rhythm_tap_bg_color(true), 0.45), WRONG_COLOR)
					else:
						state["rest_success"] = int(state.get("rest_success", 0)) + 1
						_apply_rhythm_tap_panel_style(beat_panels[cur] as Panel, Color(0.16, 0.29, 0.37, 0.95), Color(0.52, 0.78, 0.95, 0.95))
				elif not rest_failed:
					state["rest_success"] = int(state.get("rest_success", 0)) + 1
				_advance_rhythm_tap_glow(beat_panels, segments, cur)
				cur += 1
				state["current_target"] = cur
				continue
			break
		if elapsed_ms > float(segment.get("start_ms", 0.0)) + drift + close_window:
			state["missed_notes"] = int(state.get("missed_notes", 0)) + 1
			if cur < beat_panels.size() and is_instance_valid(beat_panels[cur]):
				_apply_rhythm_tap_panel_style(beat_panels[cur] as Panel, WRONG_COLOR.lerp(_get_rhythm_tap_bg_color(false), 0.45), WRONG_COLOR)
			_advance_rhythm_tap_glow(beat_panels, segments, cur)
			cur += 1
			state["current_target"] = cur
			continue
		break


func _finish_rhythm_tap_step(step: Dictionary, state: Dictionary, beat_panels: Array, tap_zone: Control, status_lbl: Label, count_lbl: Label, feedback_lbl: Label, segments: Array) -> void:
	if bool(state.get("finished", false)):
		return
	state["finished"] = true
	tap_zone.visible = false
	_sync_rhythm_tap_progress(state, beat_panels, segments, 400.0)

	var current_target: int = int(state.get("current_target", 0))
	for panel_index in range(current_target, beat_panels.size()):
		var pending_panel := beat_panels[panel_index] as Panel
		if is_instance_valid(pending_panel):
			var pending_segment: Dictionary = segments[panel_index]
			var pending_is_rest: bool = bool(pending_segment.get("rest", false))
			_apply_rhythm_tap_panel_style(pending_panel, WRONG_COLOR.lerp(_get_rhythm_tap_bg_color(pending_is_rest), 0.45), WRONG_COLOR)

	if is_instance_valid(count_lbl):
		count_lbl.text = ""

	var perfect: int = int(state.get("perfect", 0))
	var good: int = int(state.get("good", 0))
	var close: int = int(state.get("close", 0))
	var note_hits: int = perfect + good + close
	var note_total: int = int(state.get("note_total", 0))
	var rest_total: int = int(state.get("rest_total", 0))
	var rest_success: int = int(state.get("rest_success", 0))
	var rest_mistakes: int = int(state.get("rest_mistakes", 0))
	var missed_notes: int = int(state.get("missed_notes", 0))
	var weighted_note_score := float(perfect + good) + float(close) * 0.5
	var note_hit_ratio := 1.0 if note_total <= 0 else float(note_hits) / float(note_total)
	var note_timing_ratio := 1.0 if note_total <= 0 else weighted_note_score / float(note_total)
	var silence_ratio := 1.0 if rest_total <= 0 else float(rest_success) / float(rest_total)
	var overall_total: int = note_total + rest_total
	var overall_ratio := 1.0 if overall_total <= 0 else (weighted_note_score + float(rest_success)) / float(overall_total)
	var rhythm_correct: bool = overall_ratio >= 0.75 and note_hit_ratio >= 0.75 and note_timing_ratio >= 0.65 and silence_ratio >= 0.75
	if is_instance_valid(status_lbl):
		if rest_total > 0:
			status_lbl.text = "Timing %d%% | Silence %d%%" % [int(round(note_timing_ratio * 100.0)), int(round(silence_ratio * 100.0))]
		else:
			status_lbl.text = "Timing %d%% | Hits %d%%" % [int(round(note_timing_ratio * 100.0)), int(round(note_hit_ratio * 100.0))]
		if perfect == note_total and rest_success == rest_total:
			status_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
			_chicken_label.text = "Perfect rhythm. The notes landed cleanly and the rests stayed silent."
		elif rhythm_correct:
			status_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
			_chicken_label.text = "Solid rhythm. The pulse stayed steady and the pattern added up cleanly."
		elif note_hits > 0 or rest_success > 0:
			status_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
			_chicken_label.text = "Some of it is there, but the timing is still loose. Slow it down and count through the rests."
		else:
			status_lbl.add_theme_color_override("font_color", TEXT_MUTED)
			_chicken_label.text = "Try again after listening once more. Feel the pulse before you tap."

	if is_instance_valid(feedback_lbl):
		var detail_parts: Array = []
		if perfect > 0:
			detail_parts.append("%d Perfect" % perfect)
		if good > 0:
			detail_parts.append("%d Good" % good)
		if close > 0:
			detail_parts.append("%d Close" % close)
		if missed_notes > 0:
			detail_parts.append("%d Missed" % missed_notes)
		if rest_total > 0:
			detail_parts.append("%d/%d Silent Rests" % [rest_success, rest_total])
		if rest_mistakes > 0:
			detail_parts.append("%d Rest Taps" % rest_mistakes)
		feedback_lbl.text = " | ".join(detail_parts)

	_module_quiz_count += 1
	if rhythm_correct:
		_module_first_try_correct += 1
	_record_learning_result(step, rhythm_correct, true, _build_rhythm_concept_id(step), "rhythm")
	_rhythm_tap_completed = true
	_update_nav_buttons()

	if _content_vbox != null:
		var retry_btn := Button.new()
		retry_btn.text = "Try Again"
		retry_btn.add_theme_font_override("font", FONT_TITLE)
		retry_btn.add_theme_font_size_override("font_size", 16)
		retry_btn.custom_minimum_size = Vector2(140, 38)
		retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var retry_sb := StyleBoxFlat.new()
		retry_sb.bg_color = ACCENT_GOLD
		retry_sb.corner_radius_top_left = 10
		retry_sb.corner_radius_top_right = 10
		retry_sb.corner_radius_bottom_left = 10
		retry_sb.corner_radius_bottom_right = 10
		retry_sb.content_margin_left = 14
		retry_sb.content_margin_right = 14
		retry_sb.content_margin_top = 6
		retry_sb.content_margin_bottom = 6
		retry_btn.add_theme_stylebox_override("normal", retry_sb)
		retry_btn.add_theme_color_override("font_color", TEXT_DARK)
		retry_btn.pressed.connect(func():
			_clear_content()
			_render_rhythm_tap_step(step)
		)
		_content_vbox.add_child(retry_btn)


func _run_rhythm_tap_sequence(step: Dictionary, state: Dictionary, tap_zone: Control, status_lbl: Label, count_lbl: Label, feedback_lbl: Label, beat_panels: Array, segments: Array, bpm: int, time_sig_top: int, total_dur_ms: float, bar_height: float) -> void:
	if bool(state.get("started", false)) or bool(state.get("finished", false)):
		return

	_rhythm_playback_token += 1
	var playback_token: int = _rhythm_playback_token
	var beat_dur_sec: float = 60.0 / float(maxi(bpm, 1))
	var total_beats := int(round(total_dur_ms / (beat_dur_sec * 1000.0)))

	tap_zone.visible = false
	count_lbl.visible = true

	status_lbl.text = "Listen first and watch the rhythm move."
	for segment_index in range(segments.size()):
		if playback_token != _rhythm_playback_token or not is_instance_valid(self):
			return
		var segment: Dictionary = segments[segment_index]
		var is_rest: bool = bool(segment.get("rest", false))
		if segment_index < beat_panels.size() and is_instance_valid(beat_panels[segment_index]):
			if is_rest:
				_apply_rhythm_tap_panel_style(beat_panels[segment_index] as Panel, Color(0.18, 0.34, 0.46, 0.95), Color(0.52, 0.78, 0.95, 1.0))
			else:
				_apply_rhythm_tap_panel_style(beat_panels[segment_index] as Panel, Color(0.18, 0.50, 0.30, 0.90), CORRECT_COLOR)
		var segment_start_ms: float = float(segment.get("start_ms", 0.0))
		var beat_dur_ms: float = beat_dur_sec * 1000.0
		var remainder := fmod(segment_start_ms, beat_dur_ms)
		if absf(remainder) < 1.0 or absf(remainder - beat_dur_ms) < 1.0:
			var beat_number: int = int(round(segment_start_ms / beat_dur_ms))
			var beat_in_bar: int = beat_number % maxi(time_sig_top, 1)
			_play_metronome_click(beat_in_bar == 0)
		await get_tree().create_timer(float(segment.get("duration_ms", 0.0)) / 1000.0).timeout
		if playback_token != _rhythm_playback_token or not is_instance_valid(self):
			return
		if segment_index < beat_panels.size() and is_instance_valid(beat_panels[segment_index]):
			_apply_rhythm_tap_default_panel_style(beat_panels[segment_index] as Panel, is_rest)

	await get_tree().create_timer(0.4).timeout
	if playback_token != _rhythm_playback_token or not is_instance_valid(self):
		return

	status_lbl.text = "Get ready. Count in with the metronome."
	if not beat_panels.is_empty() and is_instance_valid(beat_panels[0]):
		var first_segment: Dictionary = segments[0]
		_apply_rhythm_tap_panel_style(beat_panels[0] as Panel, _get_rhythm_tap_bg_color(bool(first_segment.get("rest", false))), ACCENT_GOLD)

	for beat_index in range(time_sig_top):
		if playback_token != _rhythm_playback_token or not is_instance_valid(self) or not is_instance_valid(count_lbl):
			return
		count_lbl.text = str(beat_index + 1)
		count_lbl.add_theme_color_override("font_color", ACCENT_GOLD if beat_index == 0 else TEXT_PRIMARY)
		_play_metronome_click(beat_index == 0)
		await get_tree().create_timer(beat_dur_sec).timeout

	if playback_token != _rhythm_playback_token or not is_instance_valid(self):
		return

	count_lbl.text = "GO"
	count_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
	status_lbl.text = "Tap on note starts. Stay silent on rests."
	await get_tree().create_timer(minf(beat_dur_sec * 0.3, 0.2)).timeout
	if playback_token != _rhythm_playback_token or not is_instance_valid(self):
		return

	tap_zone.visible = true
	var cursor := ColorRect.new()
	cursor.color = Color(1.0, 1.0, 1.0, 0.22)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.z_index = 10
	if not beat_panels.is_empty() and is_instance_valid(beat_panels[0]):
		var first_panel := beat_panels[0] as Panel
		cursor.size = Vector2(first_panel.custom_minimum_size.x, bar_height)
		first_panel.add_child(cursor)
		cursor.position = Vector2.ZERO

	var tw := create_tween()
	for panel_index in range(segments.size()):
		var segment: Dictionary = segments[panel_index]
		var dur_sec := float(segment.get("duration_ms", 0.0)) / 1000.0
		if panel_index > 0:
			var target_index := panel_index
			tw.tween_callback(func():
				if not is_instance_valid(cursor):
					return
				if cursor.get_parent() != null:
					cursor.get_parent().remove_child(cursor)
				if target_index < beat_panels.size() and is_instance_valid(beat_panels[target_index]):
					var target_panel := beat_panels[target_index] as Panel
					target_panel.add_child(cursor)
					cursor.position = Vector2.ZERO
					cursor.size = Vector2(target_panel.custom_minimum_size.x, bar_height)
			)
		tw.tween_interval(dur_sec)

	tw.tween_callback(func():
		if is_instance_valid(cursor):
			if cursor.get_parent() != null:
				cursor.get_parent().remove_child(cursor)
			cursor.queue_free()
	)

	state["started"] = true
	state["start_time_ms"] = Time.get_ticks_msec()
	state["current_target"] = 0
	_run_rhythm_tap_metronome(playback_token, count_lbl, bpm, total_beats, time_sig_top)

	var deadline_sec := maxf(total_dur_ms / 1000.0 + 1.2, 1.2)
	var start_watch_ms: float = float(state.get("start_time_ms", 0.0))
	while playback_token == _rhythm_playback_token and is_instance_valid(self) and not bool(state.get("finished", false)):
		_sync_rhythm_tap_progress(state, beat_panels, segments, 500.0)
		if int(state.get("current_target", 0)) >= segments.size():
			break
		var elapsed_sec: float = (Time.get_ticks_msec() - start_watch_ms) / 1000.0
		if elapsed_sec >= deadline_sec:
			break
		await get_tree().create_timer(0.03).timeout
	if playback_token != _rhythm_playback_token or not is_instance_valid(self):
		return
	_finish_rhythm_tap_step(step, state, beat_panels, tap_zone, status_lbl, count_lbl, feedback_lbl, segments)


func _render_rhythm_tap_step(step: Dictionary) -> void:
	_rhythm_tap_completed = false
	_rhythm_tap_started = false
	_rhythm_tap_hits = 0
	_rhythm_tap_current_target = 0
	_rhythm_tap_pattern = step.get("pattern", [1.0, 1.0, 1.0, 1.0])
	_rhythm_tap_bpm = step.get("bpm", 100)
	var time_sig_top: int = step.get("time_sig_top", 4)

	var beat_dur_ms: float = 60000.0 / float(_rhythm_tap_bpm)
	var segments := _build_rhythm_tap_segments(_rhythm_tap_pattern, beat_dur_ms)
	_rhythm_tap_targets_ms = []
	for segment in segments:
		_rhythm_tap_targets_ms.append(float((segment as Dictionary).get("start_ms", 0.0)))
	var total_dur_ms: float = 0.0 if segments.is_empty() else float((segments[segments.size() - 1] as Dictionary).get("end_ms", 0.0))

	var title := Label.new()
	title.text = step.get("title", "Tap the Beat")
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(title)

	var guide_lbl := Label.new()
	var has_rests := false
	for segment in segments:
		if bool((segment as Dictionary).get("rest", false)):
			has_rests = true
			break
	var default_guide := "You'll hear the pattern first. Then after the count-in, tap on each note start."
	if has_rests:
		default_guide = "You'll hear the pattern first. Then after the count-in, tap on the notes and stay silent on the rests."
	guide_lbl.text = step.get("description", default_guide)
	guide_lbl.add_theme_font_override("font", FONT_BODY)
	guide_lbl.add_theme_font_size_override("font_size", 15)
	guide_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	guide_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(guide_lbl)

	var tap_visual := {
		"top": time_sig_top,
		"bottom": 4,
		"bars": [_build_rhythm_items_from_pattern(_rhythm_tap_pattern)],
		"prompt": "",
		"caption": "",
		"show_counts": true,
		"show_time_signature": true,
	}
	_content_vbox.add_child(_build_rhythm_staff_example(tap_visual))

	var bar_container := HBoxContainer.new()
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_container.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(bar_container)

	var total_beats := 0.0
	for segment in segments:
		total_beats += float((segment as Dictionary).get("beats", 0.0))

	var bar_width := 500.0
	var bar_height := 54.0
	var beat_panels: Array = []

	for panel_index in range(segments.size()):
		var segment: Dictionary = segments[panel_index]
		var beats_val: float = float(segment.get("beats", 1.0))
		var is_rest: bool = bool(segment.get("rest", false))
		var panel_w: float = (beats_val / total_beats) * bar_width - 4.0
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(maxf(panel_w, 36.0), bar_height)
		_apply_rhythm_tap_default_panel_style(panel, is_rest)
		bar_container.add_child(panel)
		beat_panels.append(panel)

		var beat_lbl := Label.new()
		beat_lbl.text = str(segment.get("label", _get_rhythm_value_label(beats_val)))
		beat_lbl.add_theme_font_override("font", FONT_BODY)
		beat_lbl.add_theme_font_size_override("font_size", 13)
		beat_lbl.add_theme_color_override("font_color", Color(0.80, 0.86, 0.96, 0.92) if is_rest else TEXT_MUTED)
		beat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		beat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		beat_lbl.anchors_preset = Control.PRESET_FULL_RECT
		beat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(beat_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "Press Start to hear the pattern first."
	status_lbl.add_theme_font_override("font", FONT_BODY)
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(status_lbl)

	var count_lbl := Label.new()
	count_lbl.text = ""
	count_lbl.visible = false
	count_lbl.add_theme_font_override("font", FONT_TITLE)
	count_lbl.add_theme_font_size_override("font_size", 34)
	count_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(count_lbl)

	var feedback_lbl := Label.new()
	feedback_lbl.text = ""
	feedback_lbl.add_theme_font_override("font", FONT_TITLE)
	feedback_lbl.add_theme_font_size_override("font_size", 20)
	feedback_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
	feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(feedback_lbl)

	var tap_zone := Panel.new()
	tap_zone.custom_minimum_size = Vector2(0, 90)
	tap_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tap_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tz_sb := StyleBoxFlat.new()
	tz_sb.bg_color = Color(0.9098, 0.6275, 0.1255, 0.30)
	tz_sb.border_color = ACCENT_GOLD
	tz_sb.border_width_left = 3
	tz_sb.border_width_right = 3
	tz_sb.border_width_top = 3
	tz_sb.border_width_bottom = 3
	tz_sb.corner_radius_top_left = 16
	tz_sb.corner_radius_top_right = 16
	tz_sb.corner_radius_bottom_left = 16
	tz_sb.corner_radius_bottom_right = 16
	tap_zone.add_theme_stylebox_override("panel", tz_sb)
	var tz_label := Label.new()
	tz_label.text = "TAP HERE"
	tz_label.add_theme_font_override("font", FONT_TITLE)
	tz_label.add_theme_font_size_override("font_size", 28)
	tz_label.add_theme_color_override("font_color", Color(0.9098, 0.6275, 0.1255, 0.60))
	tz_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tz_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tz_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tz_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tap_zone.add_child(tz_label)
	tap_zone.visible = false
	_content_vbox.add_child(tap_zone)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.add_theme_font_override("font", FONT_TITLE)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.custom_minimum_size = Vector2(160, 46)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var start_sb := StyleBoxFlat.new()
	start_sb.bg_color = ACCENT_GOLD
	start_sb.corner_radius_top_left = 12
	start_sb.corner_radius_top_right = 12
	start_sb.corner_radius_bottom_left = 12
	start_sb.corner_radius_bottom_right = 12
	start_sb.content_margin_left = 16
	start_sb.content_margin_right = 16
	start_sb.content_margin_top = 8
	start_sb.content_margin_bottom = 8
	start_btn.add_theme_stylebox_override("normal", start_sb)
	var start_sb_hover: StyleBoxFlat = start_sb.duplicate()
	start_sb_hover.bg_color = Color(1.0, 0.75, 0.20, 0.95)
	start_btn.add_theme_stylebox_override("hover", start_sb_hover)
	start_btn.add_theme_color_override("font_color", TEXT_DARK)
	_content_vbox.add_child(start_btn)

	var note_total := 0
	var rest_total := 0
	for segment in segments:
		if bool((segment as Dictionary).get("rest", false)):
			rest_total += 1
		else:
			note_total += 1
	var state := {
		"started": false,
		"finished": false,
		"perfect": 0,
		"good": 0,
		"close": 0,
		"current_target": 0,
		"start_time_ms": 0.0,
		"drift_ms": 0.0,
		"drift_locked": false,
		"missed_notes": 0,
		"rest_total": rest_total,
		"note_total": note_total,
		"rest_success": 0,
		"rest_mistakes": 0,
		"rest_failures": {},
	}
	var pattern_size: int = segments.size()
	var perfect_window := 180.0
	var good_window := 350.0
	var close_window := 500.0

	var _show_tap_grade := func(grade: String, color: Color) -> void:
		if is_instance_valid(feedback_lbl):
			feedback_lbl.text = grade
			feedback_lbl.add_theme_color_override("font_color", color)
			feedback_lbl.pivot_offset = Vector2(feedback_lbl.size.x / 2.0, feedback_lbl.size.y / 2.0)
			var ftw := feedback_lbl.create_tween()
			ftw.tween_property(feedback_lbl, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ftw.tween_property(feedback_lbl, "scale", Vector2(1.0, 1.0), 0.15)

	var on_tap := func() -> void:
		if not bool(state.get("started", false)) or bool(state.get("finished", false)):
			return
		var now_ms: float = Time.get_ticks_msec()
		var elapsed_ms: float = now_ms - float(state.get("start_time_ms", 0.0))
		_sync_rhythm_tap_progress(state, beat_panels, segments, close_window)
		var cur: int = int(state.get("current_target", 0))
		if cur >= pattern_size:
			return
		var segment: Dictionary = segments[cur]
		var is_rest: bool = bool(segment.get("rest", false))
		if is_rest:
			var rest_failures: Dictionary = state.get("rest_failures", {})
			if not bool(rest_failures.get(cur, false)):
				rest_failures[cur] = true
				state["rest_failures"] = rest_failures
				state["rest_mistakes"] = int(state.get("rest_mistakes", 0)) + 1
			if cur < beat_panels.size() and is_instance_valid(beat_panels[cur]):
				_apply_rhythm_tap_panel_style(beat_panels[cur] as Panel, WRONG_COLOR.lerp(_get_rhythm_tap_bg_color(true), 0.35), WRONG_COLOR)
			status_lbl.text = "Rest here. Keep counting, but don't tap."
			_show_tap_grade.call("Rest", WRONG_COLOR)
			if is_instance_valid(tap_zone):
				var rest_flash := tap_zone.create_tween()
				rest_flash.tween_property(tap_zone, "modulate", Color(1.2, 0.85, 0.85, 1.0), 0.05)
				rest_flash.tween_property(tap_zone, "modulate", Color(1, 1, 1, 1), 0.15)
			return

		var drift: float = float(state.get("drift_ms", 0.0))
		var target_ms: float = float(segment.get("start_ms", 0.0)) + drift
		var diff: float = absf(elapsed_ms - target_ms)

		if diff <= close_window:
			if not bool(state.get("drift_locked", false)):
				var first_offset := elapsed_ms - float(segment.get("start_ms", 0.0))
				state["drift_ms"] = first_offset
				state["drift_locked"] = true
				target_ms = float(segment.get("start_ms", 0.0)) + first_offset
				diff = absf(elapsed_ms - target_ms)

			var grade_color := CORRECT_COLOR
			var grade_text := "Perfect!"
			if diff <= perfect_window:
				state["perfect"] = int(state.get("perfect", 0)) + 1
				grade_color = CORRECT_COLOR
				grade_text = "Perfect!"
			elif diff <= good_window:
				state["good"] = int(state.get("good", 0)) + 1
				grade_color = Color(0.55, 0.85, 0.35, 1.0)
				grade_text = "Good!"
			else:
				state["close"] = int(state.get("close", 0)) + 1
				grade_color = ACCENT_GOLD
				grade_text = "Close"

			if cur < beat_panels.size() and is_instance_valid(beat_panels[cur]):
				_apply_rhythm_tap_panel_style(beat_panels[cur] as Panel, grade_color.darkened(0.3), grade_color)
			_show_tap_grade.call(grade_text, grade_color)
			_advance_rhythm_tap_glow(beat_panels, segments, cur)
			state["current_target"] = cur + 1

			if is_instance_valid(tap_zone):
				var flash_tw := tap_zone.create_tween()
				flash_tw.tween_property(tap_zone, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.05)
				flash_tw.tween_property(tap_zone, "modulate", Color(1, 1, 1, 1), 0.15)
		else:
			_show_tap_grade.call("Wait...", Color(0.70, 0.55, 0.30, 0.80))

	tap_zone.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_tap.call()
	)
	start_btn.pressed.connect(func():
		start_btn.visible = false
		_run_rhythm_tap_sequence(step, state, tap_zone, status_lbl, count_lbl, feedback_lbl, beat_panels, segments, _rhythm_tap_bpm, time_sig_top, total_dur_ms, bar_height)
	)

func _render_note_identify_step(step: Dictionary) -> void:
	_note_identify_completed = false
	_quiz_answered = false
	_quiz_attempts_this_step = 0

	var clef: String = step.get("clef", "treble")
	var target_note_id: String = step.get("target_note_id", "")
	var target_step: int = step.get("target_step", 4)
	var distractor_steps: Array = step.get("distractor_steps", [])
	var chicken_correct: String = step.get("chicken_correct", "")
	var chicken_wrong: String = step.get("chicken_wrong", "")

	# Extract note letter from target_note_id (e.g. "C4" -> "C")
	var target_name: String = target_note_id[0] if target_note_id.length() > 0 else "?"

	# Build all note positions: target + distractors, shuffled
	var all_steps: Array = [{"step": target_step, "is_target": true, "note_id": target_note_id}]
	for ds in distractor_steps:
		var d_id: String = LMD.step_to_note_id(clef, int(ds))
		all_steps.append({"step": int(ds), "is_target": false, "note_id": d_id})
	# Shuffle positions
	for i in range(all_steps.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: Dictionary = all_steps[i]
		all_steps[i] = all_steps[j]
		all_steps[j] = tmp

	# Calculate needed staff height
	var all_step_vals: Array = []
	for ns in all_steps:
		all_step_vals.append(ns["step"])
	var min_step: int = all_step_vals.min()
	var max_step: int = all_step_vals.max()

	var height := 200.0
	var extra_top := 0.0
	if min_step < -2:
		extra_top = absf(min_step + 2) * 10.0
		height += extra_top
	if max_step > 10:
		height += (max_step - 10) * 10.0

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	# Override mouse filter so container receives events for children
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_vbox.add_child(container)

	# Auto-play target note
	if target_note_id != "":
		_play_note_audio(target_note_id)

	# Place noteheads at evenly spaced x positions
	var x_positions: Array = []
	var count: int = all_steps.size()
	for i in count:
		var frac: float = 0.3 + (0.4 * float(i) / maxf(float(count - 1), 1.0))
		x_positions.append(line_x + line_w * frac)

	var head_panels: Array = []
	var target_head_idx: int = -1
	for i in count:
		var ns: Dictionary = all_steps[i]
		var s: int = ns["step"]
		var note_x: float = x_positions[i]
		var note_y: float = staff_top + s * (gap / 2.0)

		_draw_note_ledger_lines(container, s, staff_top, gap, note_x)

		var head := Panel.new()
		head.size = Vector2(28 * STAFF_LINE_SPACING / 14.0, 18 * STAFF_LINE_SPACING / 14.0)
		head.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_notehead_material(head, _pick_note_head_color(), Color(0.06, 0.06, 0.08, 0.85))
		head.position = Vector2(note_x - head.size.x / 2.0, note_y - head.size.y / 2.0)
		container.add_child(head)
		head_panels.append(head)

		if ns["is_target"]:
			target_head_idx = i

		# Idle bob
		var bob_tw := container.create_tween()
		bob_tw.set_loops()
		bob_tw.tween_property(head, "position:y", head.position.y - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob_tw.tween_property(head, "position:y", head.position.y + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Connect click
		var captured_is_target: bool = ns["is_target"]
		var captured_head: Panel = head
		var captured_note_id: String = ns["note_id"]
		head.gui_input.connect(func(event: InputEvent):
			if _note_identify_completed:
				return
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_note_identify_tap(captured_is_target, captured_head, captured_note_id, head_panels, target_head_idx, step, container, staff_top, gap)
		)

	# Instruction label
	var q_row := HBoxContainer.new()
	q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	q_row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(q_row)

	var q_label := Label.new()
	q_label.text = "Tap the note %s!" % target_name
	q_label.add_theme_font_override("font", FONT_TITLE)
	q_label.add_theme_font_size_override("font_size", 20)
	q_label.add_theme_color_override("font_color", TEXT_MUTED)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_row.add_child(q_label)

	# Replay button
	if target_note_id != "":
		var replay := Button.new()
		replay.text = " -- "
		replay.add_theme_font_size_override("font_size", 18)
		replay.custom_minimum_size = Vector2(40, 34)
		replay.tooltip_text = "Replay note"
		_style_flat_button(replay)
		replay.add_theme_color_override("font_color", ACCENT_GOLD)
		var cap_id := target_note_id
		replay.pressed.connect(func(): _play_note_audio(cap_id))
		q_row.add_child(replay)


func _on_note_identify_tap(is_target: bool, head: Panel, note_id: String, all_heads: Array, target_head_idx: int, step: Dictionary, container: Control, staff_top: float, gap: float) -> void:
	_quiz_attempts_this_step += 1
	var is_first_try: bool = _quiz_attempts_this_step == 1

	if is_target:
		_note_identify_completed = true
		_module_quiz_count += 1
		if is_first_try:
			_module_first_try_correct += 1
		# Streak
		_quiz_streak += 1
		var streak_msg: String = ""
		if _quiz_streak == 3:
			streak_msg = STREAK_MESSAGES_3[randi() % STREAK_MESSAGES_3.size()]
		elif _quiz_streak == 5:
			streak_msg = STREAK_MESSAGES_5[randi() % STREAK_MESSAGES_5.size()]
		var custom_correct: String = step.get("chicken_correct", "")
		if streak_msg != "":
			_chicken_label.text = streak_msg
		elif custom_correct != "":
			_chicken_label.text = custom_correct
		else:
			_chicken_label.text = _random_correct_line()
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		_play_chicken_reaction("idle")
		# Flash green
		_apply_notehead_material(head, CORRECT_COLOR, CORRECT_COLOR.darkened(0.3))
		head.pivot_offset = head.size / 2.0
		var tw := head.create_tween()
		tw.tween_property(head, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(head, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Show note name label
		var name_lbl := Label.new()
		name_lbl.text = note_id
		name_lbl.add_theme_font_override("font", FONT_TITLE)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
		name_lbl.position = Vector2(head.position.x, head.position.y + head.size.y + 2)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_lbl)
		# Record in review queue
		var concept_id: String = "%s:%s" % [step.get("clef", ""), note_id]
		_record_learning_result(step, true, is_first_try, concept_id, "note")
		_play_note_audio(note_id)
		_update_nav_buttons()
	else:
		_quiz_streak = 0
		var custom_wrong: String = step.get("chicken_wrong", "")
		_chicken_label.text = custom_wrong if custom_wrong != "" else _random_wrong_line()
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
		_shake_chicken()
		# Flash red briefly
		var orig_color := _pick_note_head_color()
		_apply_notehead_material(head, WRONG_COLOR, WRONG_COLOR.darkened(0.3))
		head.pivot_offset = head.size / 2.0
		var tw := head.create_tween()
		tw.tween_interval(0.4)
		tw.tween_callback(func():
			if is_instance_valid(head):
				_apply_notehead_material(head, orig_color, Color(0.06, 0.06, 0.08, 0.85))
		)
		# Record miss
		var concept_id: String = "%s:%s" % [step.get("clef", ""), step.get("target_note_id", "")]
		_record_learning_result(step, false, false, concept_id, "note")
		_show_wrong_answer_card(step)
		# Anti-guessing hint after 3 wrong ---- highlight target with green border
		if _quiz_attempts_this_step >= 3 and target_head_idx >= 0 and target_head_idx < all_heads.size():
			var target_h: Panel = all_heads[target_head_idx]
			if is_instance_valid(target_h):
				_apply_notehead_material(target_h, Color(0.30, 0.78, 0.40, 0.60), CORRECT_COLOR)


# ---- Listen Find Step (hear note, find on staff) ----

func _render_listen_find_step(step: Dictionary) -> void:
	_note_identify_completed = false
	_quiz_answered = false
	_quiz_attempts_this_step = 0

	var clef: String = step.get("clef", "treble")
	var target_note_id: String = step.get("target_note_id", "")
	var target_step: int = step.get("target_step", 4)
	var distractor_steps: Array = step.get("distractor_steps", [])
	var chicken_correct: String = step.get("chicken_correct", "")
	var chicken_wrong: String = step.get("chicken_wrong", "")

	# Build all note positions: target + distractors, shuffled
	var all_steps: Array = [{"step": target_step, "is_target": true, "note_id": target_note_id}]
	for ds in distractor_steps:
		var d_id: String = LMD.step_to_note_id(clef, int(ds))
		all_steps.append({"step": int(ds), "is_target": false, "note_id": d_id})
	# Shuffle
	for i in range(all_steps.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp: Dictionary = all_steps[i]
		all_steps[i] = all_steps[j]
		all_steps[j] = tmp

	# Calculate needed staff height
	var all_step_vals: Array = []
	for ns in all_steps:
		all_step_vals.append(ns["step"])
	var min_step: int = all_step_vals.min()
	var max_step: int = all_step_vals.max()

	var height := 200.0
	var extra_top := 0.0
	if min_step < -2:
		extra_top = absf(min_step + 2) * 10.0
		height += extra_top
	if max_step > 10:
		height += (max_step - 10) * 10.0

	var staff := _create_teaching_staff(clef, 420.0, height)
	var container: Control = staff["container"]
	var staff_top: float = staff["staff_top"] + extra_top * float(staff.get("scale", 1.0))
	var gap: float = staff["gap"]
	var line_x: float = staff["line_x"]
	var line_w: float = staff["line_w"]

	if extra_top > 0:
		for child in container.get_children():
			child.position.y += extra_top * float(staff.get("scale", 1.0))

	container.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_vbox.add_child(container)

	# Auto-play target note
	if target_note_id != "":
		_play_note_audio(target_note_id)

	# Place noteheads ---- NO labels (user identifies by ear)
	var x_positions: Array = []
	var count: int = all_steps.size()
	for i in count:
		var frac: float = 0.3 + (0.4 * float(i) / maxf(float(count - 1), 1.0))
		x_positions.append(line_x + line_w * frac)

	var head_panels: Array = []
	# Track which head is the target for anti-guessing hint
	var target_head_idx: int = -1
	for i in count:
		var ns: Dictionary = all_steps[i]
		var s: int = ns["step"]
		var note_x: float = x_positions[i]
		var note_y: float = staff_top + s * (gap / 2.0)

		_draw_note_ledger_lines(container, s, staff_top, gap, note_x)

		var head := Panel.new()
		head.size = Vector2(28 * STAFF_LINE_SPACING / 14.0, 18 * STAFF_LINE_SPACING / 14.0)
		head.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_notehead_material(head, _pick_note_head_color(), Color(0.06, 0.06, 0.08, 0.85))
		head.position = Vector2(note_x - head.size.x / 2.0, note_y - head.size.y / 2.0)
		container.add_child(head)
		head_panels.append(head)

		if ns["is_target"]:
			target_head_idx = i

		# Idle bob
		var bob_tw := container.create_tween()
		bob_tw.set_loops()
		bob_tw.tween_property(head, "position:y", head.position.y - 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob_tw.tween_property(head, "position:y", head.position.y + 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Connect click
		var captured_is_target: bool = ns["is_target"]
		var captured_head: Panel = head
		var captured_note_id: String = ns["note_id"]
		head.gui_input.connect(func(event: InputEvent):
			if _note_identify_completed:
				return
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_listen_find_tap(captured_is_target, captured_head, captured_note_id, head_panels, target_head_idx, step, container, staff_top, gap)
		)

	# Instruction label
	var q_row := HBoxContainer.new()
	q_row.alignment = BoxContainer.ALIGNMENT_CENTER
	q_row.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(q_row)

	var q_label := Label.new()
	q_label.text = "Listen carefully  --  which note is this?"
	q_label.add_theme_font_override("font", FONT_TITLE)
	q_label.add_theme_font_size_override("font_size", 20)
	q_label.add_theme_color_override("font_color", TEXT_MUTED)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_row.add_child(q_label)

	# Replay button
	if target_note_id != "":
		var replay := Button.new()
		replay.text = " --  Replay"
		replay.add_theme_font_size_override("font_size", 16)
		replay.custom_minimum_size = Vector2(90, 34)
		replay.tooltip_text = "Replay note"
		_style_flat_button(replay)
		replay.add_theme_color_override("font_color", ACCENT_GOLD)
		var cap_id := target_note_id
		replay.pressed.connect(func(): _play_note_audio(cap_id))
		q_row.add_child(replay)


func _on_listen_find_tap(is_target: bool, head: Panel, note_id: String, all_heads: Array, target_head_idx: int, step: Dictionary, container: Control, staff_top: float, gap: float) -> void:
	_quiz_attempts_this_step += 1
	var is_first_try: bool = _quiz_attempts_this_step == 1

	if is_target:
		_note_identify_completed = true
		_module_quiz_count += 1
		if is_first_try:
			_module_first_try_correct += 1
		# Streak
		_quiz_streak += 1
		var streak_msg: String = ""
		if _quiz_streak == 3:
			streak_msg = STREAK_MESSAGES_3[randi() % STREAK_MESSAGES_3.size()]
		elif _quiz_streak == 5:
			streak_msg = STREAK_MESSAGES_5[randi() % STREAK_MESSAGES_5.size()]
		var custom_correct: String = step.get("chicken_correct", "")
		if streak_msg != "":
			_chicken_label.text = streak_msg
		elif custom_correct != "":
			_chicken_label.text = custom_correct
		else:
			_chicken_label.text = _random_correct_line()
		_play_sfx("res://assets/audio/sfx/correct.mp3")
		_play_chicken_reaction("idle")
		# Flash green
		_apply_notehead_material(head, CORRECT_COLOR, CORRECT_COLOR.darkened(0.3))
		head.pivot_offset = head.size / 2.0
		var tw := head.create_tween()
		tw.tween_property(head, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(head, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Show the note name on correct (reveal)
		var name_lbl := Label.new()
		name_lbl.text = note_id
		name_lbl.add_theme_font_override("font", FONT_TITLE)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", CORRECT_COLOR)
		name_lbl.position = Vector2(head.position.x, head.position.y + head.size.y + 2)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(name_lbl)
		# Record in review queue
		var concept_id: String = "%s:%s" % [step.get("clef", ""), note_id]
		_record_learning_result(step, true, is_first_try, concept_id, "note")
		_play_note_audio(note_id)
		_update_nav_buttons()
	else:
		_quiz_streak = 0
		var custom_wrong: String = step.get("chicken_wrong", "")
		_chicken_label.text = custom_wrong if custom_wrong != "" else _random_wrong_line()
		_play_sfx("res://assets/audio/sfx/wrong-choice.wav")
		_shake_chicken()
		# Flash red briefly
		var orig_color := _pick_note_head_color()
		_apply_notehead_material(head, WRONG_COLOR, WRONG_COLOR.darkened(0.3))
		head.pivot_offset = head.size / 2.0
		var tw := head.create_tween()
		tw.tween_interval(0.4)
		tw.tween_callback(func():
			if is_instance_valid(head):
				_apply_notehead_material(head, orig_color, Color(0.06, 0.06, 0.08, 0.85))
		)
		# Replay the target note so user can compare
		var target_id: String = step.get("target_note_id", "")
		if target_id != "":
			_play_note_audio(target_id)
		# Record miss
		var concept_id: String = "%s:%s" % [step.get("clef", ""), step.get("target_note_id", "")]
		_record_learning_result(step, false, false, concept_id, "note")
		_show_wrong_answer_card(step)
		# Anti-guessing hint after 3 wrong ---- highlight target with green border
		if _quiz_attempts_this_step >= 3 and target_head_idx >= 0 and target_head_idx < all_heads.size():
			var target_h: Panel = all_heads[target_head_idx]
			if is_instance_valid(target_h):
				_apply_notehead_material(target_h, Color(0.30, 0.78, 0.40, 0.60), CORRECT_COLOR)


func try_midi_note(pitch: int, _any_octave: bool) -> void:
	if _quiz_answered or _active_quiz_choices.is_empty():
		return
	if _active_quiz_buttons.is_empty() or _active_quiz_btn_row == null:
		return
	var pc := ((int(pitch) % 12) + 12) % 12
	var sharp_name: String = MIDI_NOTE_NAMES_SHARP[pc]
	var flat_name: String = MIDI_NOTE_NAMES_FLAT[pc]
	for i in range(_active_quiz_choices.size()):
		var raw := str(_active_quiz_choices[i]).strip_edges()
		var letter := raw
		while letter.length() > 0 and letter.right(1).is_valid_int():
			letter = letter.left(letter.length() - 1)
		if letter == sharp_name or letter == flat_name:
			if i < _active_quiz_buttons.size() and is_instance_valid(_active_quiz_buttons[i]):
				var btn: Button = _active_quiz_buttons[i]
				_on_quiz_answer(i, _active_quiz_correct_index, btn, _active_quiz_btn_row, _active_quiz_step)
			return
