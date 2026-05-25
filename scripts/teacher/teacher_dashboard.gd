extends Control

signal back_pressed
signal student_saved(student: Dictionary)
signal student_deleted(student_id: String)
signal student_selected(student_id: String)
signal piece_added(student_id: String, piece: Dictionary)
signal piece_updated(student_id: String, piece_idx: int, piece: Dictionary)
signal piece_removed(student_id: String, piece_idx: int)
signal lesson_added(student_id: String, entry: Dictionary)
signal lesson_updated(student_id: String, entry_idx: int, entry: Dictionary)
signal assignment_added(student_id: String, task: String, due: String)
signal assignment_toggled(student_id: String, idx: int)
signal assignment_removed(student_id: String, idx: int)
signal tech_added(student_id: String, item: Dictionary)
signal tech_updated(student_id: String, idx: int, item: Dictionary)
signal tech_removed(student_id: String, idx: int)
signal data_changed
# First-run onboarding signals. The main script handles persistence + bulk
# demo-data creation; the dashboard just emits intent so it stays UI-only.
signal onboarding_add_first_student
signal onboarding_load_sample_studio
signal onboarding_skipped

const T = preload("res://scripts/teacher/teacher_dashboard_tokens.gd")
const FONT_TITLE := preload("res://assets/fonts/Baloo2-SemiBold.ttf")
const FONT_BODY := preload("res://assets/fonts/Nunito-Regular.ttf")
const LessonSessionScript = preload("res://scripts/students/lesson_session.gd")
const CloudSyncDialogScript = preload("res://scripts/sync/cloud_sync_dialog.gd")

const TAB_OVERVIEW := 0
const TAB_REPERTOIRE := 1
const TAB_LESSON_LOG := 2
const TAB_ASSIGNMENTS := 3
const TAB_TECHNIQUE := 4

const TAB_NAMES := ["Overview", "Repertoire", "Lesson Log", "Assignments", "Technique"]

const PIECE_STATUSES := ["assigned", "working", "polishing", "performed", "paused"]
const MEMORY_STATUSES := ["reading", "partial_memory", "memorized"]
const STAR_CATEGORIES := ["notes", "rhythm", "technique", "musicality", "memory"]

const TECH_CATEGORIES := ["scale", "arpeggio", "cadence", "broken_chord", "exercise", "technique"]
const TECH_HANDS := ["RH", "LH", "HT"]
const TECH_STATUSES := ["not_started", "working", "comfortable", "mastered"]
const TECH_STATUS_COLORS := {
	"not_started": Color(0.55, 0.55, 0.55, 0.70),
	"working": Color(0.90, 0.70, 0.20, 0.90),
	"comfortable": Color(0.30, 0.78, 0.40, 0.90),
	"mastered": Color(0.475, 0.82, 0.80, 0.90),
}
const MAJOR_SCALE_KEYS := ["C", "G", "D", "A", "E", "B", "F#", "Db", "Ab", "Eb", "Bb", "F"]
const MINOR_SCALE_KEYS := ["A", "E", "B", "F#", "C#", "G#", "D#", "Bb", "F", "C", "G", "D"]

var _data: Dictionary = {}
var _selected_student_id: String = ""
var _active_tab: int = TAB_OVERVIEW
var _delete_confirm_id: String = ""
var _delete_piece_confirm_idx: int = -1
var _delete_tech_confirm_idx: int = -1
# Cloud Sync (Tier A). The SyncProvider is owned by interval_birds.gd (a single
# instance per app run) and handed to us via set_sync_provider(). The dialog
# itself is built lazily on first open. The top-bar button reference is kept so
# we can update its label (e.g. add a "●" badge when a newer snapshot is pending).
var _sync_provider: Node = null
var _cloud_sync_dialog: Node = null
var _cloud_sync_button: Button = null

# Top-level containers
var _sidebar_container: VBoxContainer
var _content_scroll: ScrollContainer
var _content_container: VBoxContainer
var _tab_bar: HBoxContainer
var _tab_buttons: Array[Button] = []
var _student_count_label: Label
var _empty_message: CenterContainer

# Expanded lesson log entries — tracks which indices are expanded
var _expanded_log_entries: Dictionary = {}
# When >= 0, that lesson-log entry index is in edit mode (form fields shown).
var _editing_log_entry_idx: int = -1
# Free-text search filter for lesson logs (matches summary/practice/next/date).
var _log_search_filter: String = ""
# When non-empty, the next lesson-log form will pre-fill from this entry (Duplicate flow).
var _pending_log_prefill: Dictionary = {}
# Scroll preservation: captured before _refresh_content, restored deferred after.
var _pending_scroll_v: int = -1
# Undo-delete: stores the most recent deleted entry so user can undo for 5 seconds.
var _pending_undo_delete: Dictionary = {}
var _undo_toast: PanelContainer = null
# Module-progress snapshot (passed in from interval_birds.gd via refresh/setup).
# Used to surface device-wide practice activity in the Overview tab.
var _module_progress_stats: Dictionary = {}
# Phase 2c: callable provided by parent — given a student_id returns that
# student's practice stats dict (loaded fresh from their per-student progress
# file). When set, the App Activity card uses per-student data instead of the
# device-wide snapshot.
var _per_student_stats_provider: Callable = Callable()
# Expanded completed assignments section
var _completed_section_expanded: bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

func setup(teacher_data: Dictionary, module_progress_stats: Dictionary = {}) -> void:
	_data = teacher_data
	_module_progress_stats = module_progress_stats
	_selected_student_id = ""
	_active_tab = TAB_OVERVIEW
	_expanded_log_entries.clear()
	_completed_section_expanded = false
	_build_ui()


func refresh(teacher_data: Dictionary, module_progress_stats: Dictionary = {}) -> void:
	_data = teacher_data
	_module_progress_stats = module_progress_stats
	_rebuild_student_list()
	_refresh_content()
	_update_student_count()


# Jump straight to a student's detail (Overview tab) — used when the dashboard
# is opened mid-lesson so the teacher lands on the active student's page
# instead of the unselected student list. Does NOT emit student_selected: the
# student is already the active one, so no progress reload is needed.
func open_to_student(student_id: String) -> void:
	if student_id.is_empty():
		return
	_selected_student_id = student_id
	_active_tab = TAB_OVERVIEW
	_expanded_log_entries.clear()
	_completed_section_expanded = false
	_rebuild_student_list()
	_refresh_tab_styles()
	_refresh_content()


# =============================================================================
# UI BUILD
# =============================================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 50

	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = T.BG_PRIMARY
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Main VBox: top bar + body
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# Top bar
	root_vbox.add_child(_build_top_bar())

	# Body: sidebar + content
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root_vbox.add_child(body)

	# Left sidebar
	body.add_child(_build_sidebar())

	# Vertical separator
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 0)
	sep.color = T.BORDER_SUBTLE
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sep)

	# Right content area
	body.add_child(_build_content_area())

	# Populate
	_rebuild_student_list()
	_refresh_content()
	_update_student_count()


func _build_top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = T.BG_SIDEBAR
	panel_sb.content_margin_left = 16
	panel_sb.content_margin_right = 16
	panel_sb.content_margin_top = 10
	panel_sb.content_margin_bottom = 10
	panel_sb.border_color = T.BORDER_SUBTLE
	panel_sb.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", panel_sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.add_theme_font_override("font", FONT_TITLE)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color", T.ACCENT_TEAL)
	back_btn.add_theme_color_override("font_hover_color", T.ACCENT_TEAL.lightened(0.2))
	_style_flat_button(back_btn)
	back_btn.pressed.connect(func(): back_pressed.emit())
	hbox.add_child(back_btn)

	# Title
	var title := Label.new()
	title.text = "Teacher Dashboard"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", T.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)

	# Cloud Sync (Tier A — Supabase snapshot backup/restore). The button just
	# opens the dialog; the SyncProvider is injected from interval_birds.gd via
	# set_sync_provider() before the user gets here. Its label updates to
	# "☁ Cloud Sync ●" when the provider has a pending newer snapshot.
	_cloud_sync_button = Button.new()
	_cloud_sync_button.text = "☁ Cloud Sync"
	_cloud_sync_button.add_theme_font_override("font", FONT_TITLE)
	_cloud_sync_button.add_theme_font_size_override("font_size", 14)
	_cloud_sync_button.add_theme_color_override("font_color", T.ACCENT_TEAL)
	_cloud_sync_button.add_theme_color_override("font_hover_color", T.ACCENT_TEAL.lightened(0.2))
	_style_flat_button(_cloud_sync_button)
	_cloud_sync_button.pressed.connect(func(): _on_cloud_sync_open_pressed())
	hbox.add_child(_cloud_sync_button)

	# Student count
	_student_count_label = Label.new()
	_student_count_label.add_theme_font_override("font", FONT_BODY)
	_student_count_label.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	_student_count_label.add_theme_color_override("font_color", T.TEXT_MUTED)
	_student_count_label.custom_minimum_size = Vector2(100, 0)
	_student_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_student_count_label)

	return panel


func _build_sidebar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(T.SIDEBAR_WIDTH, 0)
	panel.size_flags_horizontal = Control.SIZE_FILL
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = T.BG_SIDEBAR
	panel_sb.content_margin_left = 0
	panel_sb.content_margin_right = 0
	panel_sb.content_margin_top = 0
	panel_sb.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", panel_sb)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# Scroll area for student cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_sidebar_container = VBoxContainer.new()
	_sidebar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_container.add_theme_constant_override("separation", 2)
	scroll.add_child(_sidebar_container)

	# Add Student button at bottom
	var btn_margin := MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_left", 8)
	btn_margin.add_theme_constant_override("margin_right", 8)
	btn_margin.add_theme_constant_override("margin_top", 8)
	btn_margin.add_theme_constant_override("margin_bottom", 8)
	vbox.add_child(btn_margin)

	var add_btn := _build_button("+ Add Student", T.ACCENT_TEAL, _on_add_student_pressed)
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_margin.add_child(add_btn)

	return panel


func _build_content_area() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)

	# Tab bar
	var tab_margin := MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 12)
	tab_margin.add_theme_constant_override("margin_right", 12)
	tab_margin.add_theme_constant_override("margin_top", 8)
	tab_margin.add_theme_constant_override("margin_bottom", 4)
	vbox.add_child(tab_margin)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 6)
	tab_margin.add_child(_tab_bar)

	_tab_buttons.clear()
	for i in TAB_NAMES.size():
		var tab_btn := Button.new()
		tab_btn.text = TAB_NAMES[i]
		tab_btn.add_theme_font_override("font", FONT_TITLE)
		tab_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_TAB)
		tab_btn.custom_minimum_size = Vector2(0, T.BTN_HEIGHT)
		var tab_idx: int = i
		tab_btn.pressed.connect(func(): _on_tab_pressed(tab_idx))
		_tab_bar.add_child(tab_btn)
		_tab_buttons.append(tab_btn)

	_refresh_tab_badge_counts()
	_refresh_tab_styles()

	# Content scroll
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_content_scroll)

	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", T.SECTION_GAP)
	_content_scroll.add_child(_content_container)

	# Empty state message
	_empty_message = CenterContainer.new()
	_empty_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty_lbl := _build_label("Select a student or add a new one.", T.FONT_SIZE_HEADING, T.TEXT_MUTED)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_message.add_child(empty_lbl)
	_content_scroll.add_child(_empty_message)

	return vbox


# =============================================================================
# STUDENT LIST
# =============================================================================

func _rebuild_student_list() -> void:
	if _sidebar_container == null:
		return
	for child in _sidebar_container.get_children():
		child.queue_free()

	# First-run welcome banner: empty roster + not skipped/seen. Three options
	# let the teacher choose how to start: solo, with sample data, or skip.
	var students: Array = _data.get("students", [])
	var onboarding_done: bool = bool(_data.get("teacher_onboarding_done", false))
	if students.is_empty() and not onboarding_done:
		_sidebar_container.add_child(_build_onboarding_welcome_card())

	# Today's agenda + weekly workflow stats above the student list.
	var summary := _build_sidebar_top_summary()
	_sidebar_container.add_child(summary)

	for student in students:
		var sid: String = str(student.get("id", ""))
		if sid == "":
			continue
		_sidebar_container.add_child(_build_student_card(student, sid == _selected_student_id))


func _build_student_card(student: Dictionary, selected: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)

	var border_color: Color = T.BORDER_ACTIVE if selected else T.BORDER_SUBTLE
	var bg_color: Color = T.BG_CARD if selected else Color(T.BG_SIDEBAR.r, T.BG_SIDEBAR.g, T.BG_SIDEBAR.b, 0.0)
	var card_sb := _build_card_style(bg_color, border_color)
	card_sb.content_margin_left = 12
	card_sb.content_margin_right = 12
	card_sb.content_margin_top = 8
	card_sb.content_margin_bottom = 8
	card_sb.corner_radius_top_left = 6
	card_sb.corner_radius_top_right = 6
	card_sb.corner_radius_bottom_left = 6
	card_sb.corner_radius_bottom_right = 6
	if selected:
		card_sb.border_width_left = 3
		card_sb.border_width_top = 1
		card_sb.border_width_right = 1
		card_sb.border_width_bottom = 1
	else:
		card_sb.border_width_left = 1
		card_sb.border_width_top = 1
		card_sb.border_width_right = 1
		card_sb.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(student.get("name", "Unnamed"))
	name_lbl.add_theme_font_override("font", FONT_TITLE)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", T.TEXT_PRIMARY if selected else T.TEXT_SECONDARY)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var level_text: String = str(student.get("level", ""))
	if level_text != "":
		var level_lbl := Label.new()
		level_lbl.text = level_text
		level_lbl.add_theme_font_override("font", FONT_BODY)
		level_lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		level_lbl.add_theme_color_override("font_color", T.TEXT_MUTED)
		level_lbl.clip_text = true
		level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(level_lbl)

	# Last session date (sidebar enrichment)
	var s_metrics: Dictionary = student.get("metrics", {})
	var last_session_str: String = str(s_metrics.get("last_session", ""))
	if last_session_str != "" and last_session_str != "--":
		var session_lbl := Label.new()
		session_lbl.text = "Last: " + last_session_str
		session_lbl.add_theme_font_override("font", FONT_BODY)
		session_lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		session_lbl.add_theme_color_override("font_color", T.TEXT_MUTED)
		session_lbl.clip_text = true
		session_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(session_lbl)

	# Open assignment count badge
	var s_assignments: Array = student.get("assignments", [])
	var open_count: int = 0
	for a in s_assignments:
		if not a.get("done", false):
			open_count += 1
	if open_count > 0:
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 4)
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(badge_row)
		var badge_panel := PanelContainer.new()
		var badge_sb := StyleBoxFlat.new()
		badge_sb.bg_color = T.ACCENT_GOLD.darkened(0.5)
		badge_sb.bg_color.a = 0.5
		badge_sb.corner_radius_top_left = 4
		badge_sb.corner_radius_top_right = 4
		badge_sb.corner_radius_bottom_left = 4
		badge_sb.corner_radius_bottom_right = 4
		badge_sb.content_margin_left = 5
		badge_sb.content_margin_right = 5
		badge_sb.content_margin_top = 1
		badge_sb.content_margin_bottom = 1
		badge_panel.add_theme_stylebox_override("panel", badge_sb)
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_lbl := Label.new()
		badge_lbl.text = "%d open" % open_count
		badge_lbl.add_theme_font_override("font", FONT_BODY)
		badge_lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		badge_lbl.add_theme_color_override("font_color", T.ACCENT_GOLD)
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.add_child(badge_lbl)
		badge_row.add_child(badge_panel)

	# Click overlay
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sid: String = str(student.get("id", ""))
	btn.pressed.connect(func(): _on_student_card_pressed(sid))
	card.add_child(btn)

	return card


func _on_student_card_pressed(sid: String) -> void:
	_selected_student_id = sid
	_active_tab = TAB_OVERVIEW
	_expanded_log_entries.clear()
	_completed_section_expanded = false
	_rebuild_student_list()
	_refresh_tab_styles()
	_refresh_content()
	student_selected.emit(sid)


func _on_add_student_pressed() -> void:
	var new_id := _generate_id()
	var new_student := {
		"id": new_id,
		"name": "New Student",
		"age": 10,
		"level": "",
		"instrument": "",
		"lesson_day": "",
		"lesson_duration": 30,
		"current_book": "",
		"current_book_part": "",
		"next_lesson_focus": "",
		"metrics": {},
		"training_stats": {},
		"session_history": [],
		"current_pieces": [],
		"lesson_log": [],
		"assignments": [],
		"current_technical": [],
	}
	if not _data.has("students"):
		_data["students"] = []
	_data["students"].append(new_student)
	_selected_student_id = new_id
	_active_tab = TAB_OVERVIEW
	_rebuild_student_list()
	_refresh_tab_styles()
	_refresh_content()
	_update_student_count()
	student_saved.emit(new_student)
	data_changed.emit()


# =============================================================================
# TAB MANAGEMENT
# =============================================================================

func _on_tab_pressed(tab_idx: int) -> void:
	_active_tab = tab_idx
	_expanded_log_entries.clear()
	_completed_section_expanded = false
	_refresh_tab_styles()
	_refresh_content()


func _refresh_tab_styles() -> void:
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var is_active: bool = (i == _active_tab)
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		if is_active:
			sb.bg_color = T.BG_TAB_ACTIVE
			sb.border_color = T.ACCENT_TEAL
			sb.border_width_bottom = 2
			btn.add_theme_color_override("font_color", T.TEXT_PRIMARY)
		else:
			sb.bg_color = T.BG_TAB_INACTIVE
			sb.border_color = Color(0, 0, 0, 0)
			btn.add_theme_color_override("font_color", T.TEXT_MUTED)
		btn.add_theme_stylebox_override("normal", sb)
		var hover_sb: StyleBoxFlat = sb.duplicate()
		hover_sb.bg_color = sb.bg_color.lightened(0.08)
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_stylebox_override("pressed", sb)


func _refresh_content() -> void:
	if _content_container == null:
		return
	# Capture scroll position before tearing down children so we can restore it
	# after the rebuild. Without this, editing/deleting an entry jumps the user
	# back to the top of the list.
	if _content_scroll != null:
		_pending_scroll_v = _content_scroll.scroll_vertical

	for child in _content_container.get_children():
		child.queue_free()

	var student := _get_selected_student()
	if student.is_empty():
		_content_container.visible = false
		_empty_message.visible = true
		_tab_bar.visible = false
		return

	_content_container.visible = true
	_empty_message.visible = false
	_tab_bar.visible = true

	_refresh_tab_badge_counts()

	match _active_tab:
		TAB_OVERVIEW:
			_build_tab_overview(student)
		TAB_REPERTOIRE:
			_build_tab_repertoire(student)
		TAB_LESSON_LOG:
			_build_tab_lesson_log(student)
		TAB_ASSIGNMENTS:
			_build_tab_assignments(student)
		TAB_TECHNIQUE:
			_build_tab_technique(student)

	# Restore scroll position (deferred — wait for layout pass to compute scrollable height).
	if _pending_scroll_v >= 0 and _content_scroll != null:
		var target_v: int = _pending_scroll_v
		_pending_scroll_v = -1
		call_deferred("_apply_pending_scroll", target_v)


func _apply_pending_scroll(v: int) -> void:
	if _content_scroll != null:
		_content_scroll.scroll_vertical = v


# =============================================================================
# TAB 1: OVERVIEW
# =============================================================================

func _build_tab_overview(student: Dictionary) -> void:
	var margin := _build_content_margin()
	_content_container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", T.SECTION_GAP)
	margin.add_child(vbox)

	# "Since Last Lesson" prep card — the 60-second pre-lesson snapshot:
	# what the student practiced, weak now, open assignments, plan from last time.
	_build_since_last_lesson_card(vbox, student)

	# Info section card
	var info_card := _build_content_card()
	vbox.add_child(info_card)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_card.add_child(info_vbox)

	# Lesson statistics card — count, cadence, last seen (helps end-of-term reviews).
	_build_lesson_stats_card(vbox, student)
	# Device-wide practice activity from learning modules (#11) — caveat-labeled.
	_build_app_activity_card(vbox)
	# Phase 3: bookended lesson sessions (Start Lesson → End Lesson) with per-round
	# scores. Only shows when the selected student actually has recorded sessions.
	_build_lesson_sessions_card(vbox, student)
	# SS3 — Per-key sight reading accuracy bar chart. Only shows if the student
	# has accumulated meaningful per-key data via the sight modes.
	_build_per_key_radar_card(vbox, student)

	info_vbox.add_child(_build_section_title("Student Information"))

	# Name
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_row)
	name_row.add_child(_build_field_label("Name"))
	var name_input := _build_input("Student name", str(student.get("name", "")))
	name_input.name = "name_input"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_input)

	# Age + Level row
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	info_vbox.add_child(row2)

	row2.add_child(_build_field_label("Age"))
	var age_spin := SpinBox.new()
	age_spin.name = "age_spin"
	age_spin.min_value = 3
	age_spin.max_value = 99
	age_spin.value = int(student.get("age", 10))
	age_spin.custom_minimum_size = Vector2(80, T.INPUT_HEIGHT)
	_style_spin_box(age_spin)
	row2.add_child(age_spin)

	row2.add_child(_build_field_label("Level"))
	var level_input := _build_input("e.g. Beginner, Grade 2", str(student.get("level", "")))
	level_input.name = "level_input"
	level_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(level_input)

	# Instrument + Lesson Day row
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 12)
	info_vbox.add_child(row3)

	row3.add_child(_build_field_label("Instrument"))
	var inst_input := _build_input("e.g. Piano, Violin", str(student.get("instrument", "")))
	inst_input.name = "instrument_input"
	inst_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(inst_input)

	row3.add_child(_build_field_label("Lesson Day"))
	var day_input := _build_input("e.g. Tuesday", str(student.get("lesson_day", "")))
	day_input.name = "day_input"
	day_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(day_input)

	row3.add_child(_build_field_label("Duration"))
	var dur_spin := SpinBox.new()
	dur_spin.name = "duration_spin"
	dur_spin.min_value = 15
	dur_spin.max_value = 120
	dur_spin.step = 5
	dur_spin.suffix = " min"
	dur_spin.value = int(student.get("lesson_duration", 30))
	dur_spin.custom_minimum_size = Vector2(100, T.INPUT_HEIGHT)
	_style_spin_box(dur_spin)
	row3.add_child(dur_spin)

	# Current Book
	info_vbox.add_child(_build_section_title("Current Book"))
	var book_row := HBoxContainer.new()
	book_row.add_theme_constant_override("separation", 12)
	info_vbox.add_child(book_row)

	var book_data: Dictionary = student.get("current_book", {}) if student.get("current_book") is Dictionary else {"name": str(student.get("current_book", "")), "part": ""}
	book_row.add_child(_build_field_label("Name"))
	var book_input := _build_input("Book name", str(book_data.get("name", "")))
	book_input.name = "book_input"
	book_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_row.add_child(book_input)

	book_row.add_child(_build_field_label("Part"))
	var part_input := _build_input("e.g. Unit 3", str(book_data.get("part", "")))
	part_input.name = "part_input"
	part_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_row.add_child(part_input)

	# Next Lesson Focus
	info_vbox.add_child(_build_section_title("Next Lesson Focus"))
	var focus_edit := _build_text_edit("Plan for next lesson...", str(student.get("next_lesson_focus", "")), 2)
	focus_edit.name = "focus_edit"
	info_vbox.add_child(focus_edit)

	# Save + Delete row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	action_row.alignment = BoxContainer.ALIGNMENT_END
	info_vbox.add_child(action_row)

	var save_btn := _build_button("Save Changes", T.ACCENT_GREEN, func():
		_on_save_student(info_card)
	)
	action_row.add_child(save_btn)

	var delete_btn := _build_button("Delete Student", T.ACCENT_RED, func():
		_on_delete_student()
	)
	delete_btn.name = "delete_student_btn"
	action_row.add_child(delete_btn)

	# Stats chips card
	var stats_card := _build_content_card()
	vbox.add_child(stats_card)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_card.add_child(stats_vbox)

	stats_vbox.add_child(_build_section_title("Training Stats"))

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	stats_vbox.add_child(stats_row)

	var metrics: Dictionary = student.get("metrics", {})
	if metrics.is_empty():
		metrics = student.get("training_stats", {})

	stats_row.add_child(_build_stat_chip("Ear Accuracy", _format_pct(metrics.get("ear_accuracy", -1)), T.ACCENT_GOLD))
	stats_row.add_child(_build_stat_chip("Sight Accuracy", _format_pct(metrics.get("sight_accuracy", -1)), T.ACCENT_TEAL))
	var total_sessions := int(metrics.get("ear_sessions", 0)) + int(metrics.get("sight_sessions", 0))
	stats_row.add_child(_build_stat_chip("Total Sessions", str(total_sessions), T.ACCENT_BLUE))
	stats_row.add_child(_build_stat_chip("Last Session", str(metrics.get("last_session", "—")), T.ACCENT_PURPLE))

	# Accuracy Trend (Task 6) — colored dots for last 10 sessions
	var history_for_trend: Array = student.get("session_history", [])
	if history_for_trend.size() > 0:
		var trend_card := _build_content_card()
		vbox.add_child(trend_card)
		var trend_vbox := VBoxContainer.new()
		trend_vbox.add_theme_constant_override("separation", 6)
		trend_card.add_child(trend_vbox)
		trend_vbox.add_child(_build_section_title("Recent Trend"))
		var trend_dots_row := HBoxContainer.new()
		trend_dots_row.add_theme_constant_override("separation", 6)
		trend_vbox.add_child(trend_dots_row)
		var trend_dates_row := HBoxContainer.new()
		trend_dates_row.add_theme_constant_override("separation", 6)
		trend_vbox.add_child(trend_dates_row)
		var trend_start := maxi(0, history_for_trend.size() - 10)
		for ti in range(trend_start, history_for_trend.size()):
			var t_entry: Dictionary = history_for_trend[ti]
			var t_acc = t_entry.get("accuracy", -1)
			var t_color: Color = T.TEXT_MUTED
			if t_acc != null and t_acc != -1:
				var t_acc_f := float(t_acc)
				if t_acc_f >= 80.0:
					t_color = T.ACCENT_GREEN
				elif t_acc_f >= 60.0:
					t_color = T.ACCENT_GOLD
				else:
					t_color = T.ACCENT_RED
			# Dot/bar
			var dot_panel := PanelContainer.new()
			dot_panel.custom_minimum_size = Vector2(24, 24)
			var dot_sb := StyleBoxFlat.new()
			dot_sb.bg_color = t_color
			dot_sb.corner_radius_top_left = 4
			dot_sb.corner_radius_top_right = 4
			dot_sb.corner_radius_bottom_left = 4
			dot_sb.corner_radius_bottom_right = 4
			dot_panel.add_theme_stylebox_override("panel", dot_sb)
			dot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Show accuracy value inside the dot
			var dot_lbl := Label.new()
			var dot_text: String = "%d" % int(float(t_acc)) if (t_acc != null and t_acc != -1) else "--"
			dot_lbl.text = dot_text
			dot_lbl.add_theme_font_override("font", FONT_BODY)
			dot_lbl.add_theme_font_size_override("font_size", 9)
			dot_lbl.add_theme_color_override("font_color", T.TEXT_PRIMARY)
			dot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot_panel.add_child(dot_lbl)
			trend_dots_row.add_child(dot_panel)
			# Date label below
			var t_date_str: String = str(t_entry.get("date", ""))
			if t_date_str.length() > 5:
				t_date_str = t_date_str.substr(5)  # Show MM-DD only
			var date_lbl := Label.new()
			date_lbl.text = t_date_str
			date_lbl.add_theme_font_override("font", FONT_BODY)
			date_lbl.add_theme_font_size_override("font_size", 9)
			date_lbl.add_theme_color_override("font_color", T.TEXT_MUTED)
			date_lbl.custom_minimum_size = Vector2(24, 0)
			date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trend_dates_row.add_child(date_lbl)

	# Quick Note (Task 4) — fast one-field lesson log entry
	var quick_note_card := _build_content_card()
	vbox.add_child(quick_note_card)
	var quick_note_vbox := VBoxContainer.new()
	quick_note_vbox.add_theme_constant_override("separation", 6)
	quick_note_card.add_child(quick_note_vbox)
	quick_note_vbox.add_child(_build_section_title("Quick Note"))
	var quick_note_row := HBoxContainer.new()
	quick_note_row.add_theme_constant_override("separation", 8)
	quick_note_vbox.add_child(quick_note_row)
	var quick_note_input := _build_input("Type a quick lesson note...", "")
	quick_note_input.name = "quick_note_input"
	quick_note_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_note_row.add_child(quick_note_input)
	var quick_note_save := _build_button("Save", T.ACCENT_GREEN, func():
		_on_quick_note_save(quick_note_card)
	)
	quick_note_row.add_child(quick_note_save)

	# Weak Areas (items the student struggles with)
	var item_stats: Dictionary = student.get("item_stats", {})
	var weak_items: Array = []
	for category in item_stats:
		var cat_stats: Dictionary = item_stats.get(category, {})
		if not cat_stats is Dictionary:
			continue
		for item_key in cat_stats:
			var entry: Dictionary = cat_stats.get(item_key, {})
			if not entry is Dictionary:
				continue
			var asked := int(entry.get("asked", 0))
			var correct := int(entry.get("correct", 0))
			if asked < 3:
				continue
			var accuracy := int(round(float(correct) / float(maxi(1, asked)) * 100.0))
			if accuracy < 70:
				weak_items.append({"category": str(category), "item": str(item_key), "accuracy": accuracy, "asked": asked})
	weak_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("accuracy", 100)) < int(b.get("accuracy", 100)))

	if weak_items.size() > 0:
		var weak_card := _build_content_card()
		vbox.add_child(weak_card)
		var weak_vbox := VBoxContainer.new()
		weak_vbox.add_theme_constant_override("separation", 6)
		weak_card.add_child(weak_vbox)
		weak_vbox.add_child(_build_section_title("Needs Work"))
		var show_count := mini(weak_items.size(), 6)
		for wi in range(show_count):
			var w: Dictionary = weak_items[wi]
			var w_row := HBoxContainer.new()
			w_row.add_theme_constant_override("separation", 8)
			weak_vbox.add_child(w_row)
			var cat_lbl := _build_label(str(w.get("category", "")).capitalize(), T.FONT_SIZE_SMALL, T.TEXT_MUTED)
			cat_lbl.custom_minimum_size = Vector2(60, 0)
			w_row.add_child(cat_lbl)
			var item_lbl := _build_label(str(w.get("item", "")), T.FONT_SIZE_BODY, T.TEXT_PRIMARY)
			item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w_row.add_child(item_lbl)
			var acc_pct := int(w.get("accuracy", 0))
			var acc_color: Color = T.ACCENT_RED if acc_pct < 50 else T.ACCENT_GOLD
			w_row.add_child(_build_label("%d%%" % acc_pct, T.FONT_SIZE_BODY, acc_color))
			w_row.add_child(_build_label("(%d tries)" % int(w.get("asked", 0)), T.FONT_SIZE_SMALL, T.TEXT_MUTED))

	# Recent Sessions
	var history: Array = student.get("session_history", [])
	if history.size() > 0:
		var sessions_card := _build_content_card()
		vbox.add_child(sessions_card)

		var sess_vbox := VBoxContainer.new()
		sess_vbox.add_theme_constant_override("separation", 6)
		sessions_card.add_child(sess_vbox)

		sess_vbox.add_child(_build_section_title("Recent Sessions"))

		var count := mini(history.size(), 5)
		for i in range(history.size() - 1, history.size() - count - 1, -1):
			if i < 0:
				break
			var entry: Dictionary = history[i]
			var sess_row := HBoxContainer.new()
			sess_row.add_theme_constant_override("separation", 12)
			sess_vbox.add_child(sess_row)

			var date_lbl := _build_label(str(entry.get("date", "")), T.FONT_SIZE_BODY, T.TEXT_SECONDARY)
			date_lbl.custom_minimum_size = Vector2(90, 0)
			sess_row.add_child(date_lbl)

			var mode_lbl := _build_label(str(entry.get("mode", "")), T.FONT_SIZE_BODY, T.TEXT_PRIMARY)
			mode_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sess_row.add_child(mode_lbl)

			var acc_val = entry.get("accuracy", -1)
			var acc_text: String = _format_pct(acc_val)
			var acc_color: Color = T.ACCENT_GREEN if float(acc_val) >= 80.0 else (T.ACCENT_GOLD if float(acc_val) >= 60.0 else T.ACCENT_RED)
			if acc_val == -1 or acc_val == null:
				acc_color = T.TEXT_MUTED
			sess_row.add_child(_build_label(acc_text, T.FONT_SIZE_BODY, acc_color))

	# Bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad)


func _on_save_student(info_card: PanelContainer) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return

	# Traverse the info_card to find named inputs
	var name_input := _find_child_by_name(info_card, "name_input") as LineEdit
	var age_spin := _find_child_by_name(info_card, "age_spin") as SpinBox
	var level_input := _find_child_by_name(info_card, "level_input") as LineEdit
	var inst_input := _find_child_by_name(info_card, "instrument_input") as LineEdit
	var day_input := _find_child_by_name(info_card, "day_input") as LineEdit
	var dur_spin := _find_child_by_name(info_card, "duration_spin") as SpinBox
	var book_input := _find_child_by_name(info_card, "book_input") as LineEdit
	var part_input := _find_child_by_name(info_card, "part_input") as LineEdit
	var focus_edit := _find_child_by_name(info_card, "focus_edit") as TextEdit

	if name_input != null:
		student["name"] = name_input.text
	if age_spin != null:
		student["age"] = int(age_spin.value)
	if level_input != null:
		student["level"] = level_input.text
	if inst_input != null:
		student["instrument"] = inst_input.text
	if day_input != null:
		student["lesson_day"] = day_input.text
	if dur_spin != null:
		student["lesson_duration"] = int(dur_spin.value)
	if book_input != null or part_input != null:
		student["current_book"] = {
			"name": book_input.text if book_input != null else "",
			"part": part_input.text if part_input != null else ""
		}
	if focus_edit != null:
		student["next_lesson_focus"] = focus_edit.text

	student_saved.emit(student)
	data_changed.emit()
	_rebuild_student_list()


func _on_delete_student() -> void:
	if _selected_student_id == "":
		return
	# Two-click confirm: first click changes button text, second click deletes
	if _delete_confirm_id != _selected_student_id:
		_delete_confirm_id = _selected_student_id
		# Find and update the delete button text
		var del_btn := _find_child_by_name(_content_container, "delete_student_btn") as Button
		if del_btn != null:
			del_btn.text = "Confirm Delete?"
			del_btn.modulate = Color(1.3, 0.9, 0.9, 1.0)
		return
	_delete_confirm_id = ""
	var students: Array = _data.get("students", [])
	for i in range(students.size() - 1, -1, -1):
		if str(students[i].get("id", "")) == _selected_student_id:
			students.remove_at(i)
			break
	var deleted_id := _selected_student_id
	_selected_student_id = ""
	_rebuild_student_list()
	_refresh_content()
	_update_student_count()
	student_deleted.emit(deleted_id)
	data_changed.emit()


# =============================================================================
# TAB 2: REPERTOIRE
# =============================================================================

func _build_tab_repertoire(student: Dictionary) -> void:
	var margin := _build_content_margin()
	_content_container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", T.SECTION_GAP)
	margin.add_child(vbox)

	# Add Piece button
	var add_row := HBoxContainer.new()
	add_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(add_row)

	var add_btn := _build_button("+ Add Piece", T.ACCENT_TEAL, func():
		_on_add_piece()
	)
	add_row.add_child(add_btn)

	# Piece cards
	var pieces: Array = student.get("current_pieces", [])
	if pieces.size() == 0:
		var empty_lbl := _build_label("No pieces yet. Click '+ Add Piece' to get started.", T.FONT_SIZE_BODY, T.TEXT_MUTED)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty_lbl)
	else:
		for i in pieces.size():
			var piece: Dictionary = pieces[i]
			vbox.add_child(_build_piece_card(piece, i))

	# Bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad)


func _build_piece_card(piece: Dictionary, piece_idx: int) -> PanelContainer:
	var card := _build_content_card()
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card.add_child(card_vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(title_row)

	# Status badge
	var status_str: String = str(piece.get("status", "assigned"))
	var badge := _build_status_badge(status_str)
	title_row.add_child(badge)

	title_row.add_child(_build_field_label("Title"))
	var title_input := _build_input("Piece title", str(piece.get("title", "")))
	title_input.name = "piece_title_%d" % piece_idx
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_input)

	# Composer row
	var composer_row := HBoxContainer.new()
	composer_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(composer_row)

	composer_row.add_child(_build_field_label("Composer"))
	var composer_input := _build_input("Composer name", str(piece.get("composer", "")))
	composer_input.name = "piece_composer_%d" % piece_idx
	composer_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer_row.add_child(composer_input)

	composer_row.add_child(_build_field_label("Status"))
	var status_option := OptionButton.new()
	status_option.name = "piece_status_%d" % piece_idx
	for s in PIECE_STATUSES:
		status_option.add_item(s)
	var current_status_idx := PIECE_STATUSES.find(status_str)
	if current_status_idx >= 0:
		status_option.selected = current_status_idx
	_style_option_button(status_option)
	composer_row.add_child(status_option)

	# BPM row
	var bpm_row := HBoxContainer.new()
	bpm_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(bpm_row)

	bpm_row.add_child(_build_field_label("Current BPM"))
	var cur_bpm := SpinBox.new()
	cur_bpm.name = "piece_cur_bpm_%d" % piece_idx
	cur_bpm.min_value = 20
	cur_bpm.max_value = 300
	cur_bpm.value = int(piece.get("current_bpm", 60))
	cur_bpm.custom_minimum_size = Vector2(90, T.INPUT_HEIGHT)
	_style_spin_box(cur_bpm)
	bpm_row.add_child(cur_bpm)

	bpm_row.add_child(_build_field_label("Target BPM"))
	var tgt_bpm := SpinBox.new()
	tgt_bpm.name = "piece_tgt_bpm_%d" % piece_idx
	tgt_bpm.min_value = 20
	tgt_bpm.max_value = 300
	tgt_bpm.value = int(piece.get("target_bpm", 120))
	tgt_bpm.custom_minimum_size = Vector2(90, T.INPUT_HEIGHT)
	_style_spin_box(tgt_bpm)
	bpm_row.add_child(tgt_bpm)

	bpm_row.add_child(_build_field_label("Memory"))
	var mem_option := OptionButton.new()
	mem_option.name = "piece_memory_%d" % piece_idx
	for ms in MEMORY_STATUSES:
		mem_option.add_item(ms)
	var mem_str: String = str(piece.get("memory_status", "reading"))
	var mem_idx := MEMORY_STATUSES.find(mem_str)
	if mem_idx >= 0:
		mem_option.selected = mem_idx
	_style_option_button(mem_option)
	bpm_row.add_child(mem_option)

	# Star ratings
	card_vbox.add_child(_build_section_title("Ratings"))
	var stars_dict: Dictionary = piece.get("ratings", {})
	var star_rows_container := VBoxContainer.new()
	star_rows_container.name = "piece_stars_%d" % piece_idx
	star_rows_container.add_theme_constant_override("separation", 4)
	card_vbox.add_child(star_rows_container)

	for cat in STAR_CATEGORIES:
		var star_row := HBoxContainer.new()
		star_row.add_theme_constant_override("separation", 4)
		star_rows_container.add_child(star_row)

		var cat_label := _build_label(cat.capitalize() + ":", T.FONT_SIZE_SMALL, T.TEXT_SECONDARY)
		cat_label.custom_minimum_size = Vector2(90, 0)
		star_row.add_child(cat_label)

		var current_val: int = int(stars_dict.get(cat, 0))
		for s in range(1, 6):
			var star_btn := Button.new()
			var is_filled: bool = s <= current_val
			star_btn.text = "★" if is_filled else "☆"
			star_btn.add_theme_font_size_override("font_size", 18)
			star_btn.add_theme_color_override("font_color", T.STAR_FILLED if is_filled else T.STAR_EMPTY)
			star_btn.custom_minimum_size = Vector2(28, 28)
			_style_flat_button(star_btn)
			star_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var cat_name: String = cat
			var star_val: int = s
			var idx: int = piece_idx
			star_btn.pressed.connect(func():
				_on_star_clicked(idx, cat_name, star_val)
			)
			star_row.add_child(star_btn)

	# Notes
	card_vbox.add_child(_build_field_label("Notes"))
	var notes_edit := _build_text_edit("Practice notes...", str(piece.get("notes", "")), 2)
	notes_edit.name = "piece_notes_%d" % piece_idx
	card_vbox.add_child(notes_edit)

	# Focus bars
	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(focus_row)
	focus_row.add_child(_build_field_label("Focus Bars"))
	var focus_input := _build_input("e.g. mm. 12-16", str(piece.get("focus_bars", "")))
	focus_input.name = "piece_focus_%d" % piece_idx
	focus_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_row.add_child(focus_input)

	# Actions
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	action_row.alignment = BoxContainer.ALIGNMENT_END
	card_vbox.add_child(action_row)

	var save_piece_btn := _build_button("Save Piece", T.ACCENT_GREEN, func():
		_on_save_piece(card, piece_idx)
	)
	action_row.add_child(save_piece_btn)

	var remove_text := "Confirm Remove?" if _delete_piece_confirm_idx == piece_idx else "Remove"
	var remove_btn := _build_button(remove_text, T.ACCENT_RED, func():
		_on_remove_piece(piece_idx)
	)
	action_row.add_child(remove_btn)

	return card


func _on_star_clicked(piece_idx: int, category: String, value: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var pieces: Array = student.get("current_pieces", [])
	if piece_idx < 0 or piece_idx >= pieces.size():
		return
	var piece: Dictionary = pieces[piece_idx]
	if not piece.has("ratings"):
		piece["ratings"] = {}
	# Toggle: clicking the same star value again clears it
	var current_val: int = int(piece["ratings"].get(category, 0))
	if current_val == value:
		piece["ratings"][category] = 0
	else:
		piece["ratings"][category] = value
	piece_updated.emit(_selected_student_id, piece_idx, piece)
	data_changed.emit()
	_refresh_content()


func _on_add_piece() -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	if not student.has("current_pieces"):
		student["current_pieces"] = []
	var new_piece := {
		"title": "",
		"composer": "",
		"status": "assigned",
		"current_bpm": 60,
		"target_bpm": 120,
		"ratings": {},
		"notes": "",
		"focus_bars": "",
		"memory_status": "reading",
	}
	student["current_pieces"].append(new_piece)
	piece_added.emit(_selected_student_id, new_piece)
	data_changed.emit()
	_refresh_content()


func _on_save_piece(card: PanelContainer, piece_idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var pieces: Array = student.get("current_pieces", [])
	if piece_idx < 0 or piece_idx >= pieces.size():
		return
	var piece: Dictionary = pieces[piece_idx]

	var title_input := _find_child_by_name(card, "piece_title_%d" % piece_idx) as LineEdit
	var composer_input := _find_child_by_name(card, "piece_composer_%d" % piece_idx) as LineEdit
	var status_option := _find_child_by_name(card, "piece_status_%d" % piece_idx) as OptionButton
	var cur_bpm := _find_child_by_name(card, "piece_cur_bpm_%d" % piece_idx) as SpinBox
	var tgt_bpm := _find_child_by_name(card, "piece_tgt_bpm_%d" % piece_idx) as SpinBox
	var mem_option := _find_child_by_name(card, "piece_memory_%d" % piece_idx) as OptionButton
	var notes_edit := _find_child_by_name(card, "piece_notes_%d" % piece_idx) as TextEdit
	var focus_input := _find_child_by_name(card, "piece_focus_%d" % piece_idx) as LineEdit

	if title_input != null:
		piece["title"] = title_input.text
	if composer_input != null:
		piece["composer"] = composer_input.text
	if status_option != null and status_option.selected >= 0 and status_option.selected < PIECE_STATUSES.size():
		piece["status"] = PIECE_STATUSES[status_option.selected]
	if cur_bpm != null:
		piece["current_bpm"] = int(cur_bpm.value)
	if tgt_bpm != null:
		piece["target_bpm"] = int(tgt_bpm.value)
	if mem_option != null and mem_option.selected >= 0 and mem_option.selected < MEMORY_STATUSES.size():
		piece["memory_status"] = MEMORY_STATUSES[mem_option.selected]
	if notes_edit != null:
		piece["notes"] = notes_edit.text
	if focus_input != null:
		piece["focus_bars"] = focus_input.text

	# Collect star ratings from the stored piece (already updated via _on_star_clicked)
	piece_updated.emit(_selected_student_id, piece_idx, piece)
	data_changed.emit()


func _on_remove_piece(piece_idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var pieces: Array = student.get("current_pieces", [])
	if piece_idx < 0 or piece_idx >= pieces.size():
		return
	if _delete_piece_confirm_idx != piece_idx:
		_delete_piece_confirm_idx = piece_idx
		_refresh_content()
		return
	_delete_piece_confirm_idx = -1
	pieces.remove_at(piece_idx)
	piece_removed.emit(_selected_student_id, piece_idx)
	data_changed.emit()
	_refresh_content()


# =============================================================================
# TAB 3: LESSON LOG
# =============================================================================

func _build_tab_lesson_log(student: Dictionary) -> void:
	var margin := _build_content_margin()
	_content_container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", T.SECTION_GAP)
	margin.add_child(vbox)

	# Add Entry form
	var form_card := _build_content_card()
	vbox.add_child(form_card)

	var form_vbox := VBoxContainer.new()
	form_vbox.add_theme_constant_override("separation", 8)
	form_card.add_child(form_vbox)

	form_vbox.add_child(_build_section_title("New Lesson Entry"))

	# Consume pending prefill from Duplicate-Previous (if any).
	var prefill: Dictionary = _pending_log_prefill
	_pending_log_prefill = {}
	var prefill_date: String = _today_date()  # always use today for the new entry
	var prefill_summary: String = str(prefill.get("summary", ""))
	var prefill_practice: String = str(prefill.get("practice_note", ""))
	var prefill_next: String = str(prefill.get("next_focus", ""))
	if not prefill.is_empty():
		var hint := _build_label("Pre-filled from previous entry — edit before saving.", T.FONT_SIZE_SMALL, T.ACCENT_GOLD)
		form_vbox.add_child(hint)

	# Date
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(date_row)
	date_row.add_child(_build_field_label("Date"))
	var date_input := _build_input("YYYY-MM-DD", prefill_date)
	date_input.name = "log_date_input"
	date_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_row.add_child(date_input)

	# Summary
	form_vbox.add_child(_build_field_label("Summary"))
	var summary_edit := _build_text_edit("What was covered in this lesson...", prefill_summary, 3)
	summary_edit.name = "log_summary_edit"
	form_vbox.add_child(summary_edit)

	# Home Practice Note
	var practice_row := HBoxContainer.new()
	practice_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(practice_row)
	practice_row.add_child(_build_field_label("Home Practice"))
	var practice_input := _build_input("Practice assignment for student...", prefill_practice)
	practice_input.name = "log_practice_input"
	practice_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	practice_row.add_child(practice_input)

	# Next Focus
	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 8)
	form_vbox.add_child(next_row)
	next_row.add_child(_build_field_label("Next Focus"))
	var next_input := _build_input("Focus for next lesson...", prefill_next)
	next_input.name = "log_next_input"
	next_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_row.add_child(next_input)

	# Save button
	var save_row := HBoxContainer.new()
	save_row.alignment = BoxContainer.ALIGNMENT_END
	form_vbox.add_child(save_row)

	var save_btn := _build_button("Save Entry", T.ACCENT_GREEN, func():
		_on_save_lesson_entry(form_card)
	)
	save_row.add_child(save_btn)

	# Past entries header + search box
	var log: Array = student.get("lesson_log", [])
	if log.size() > 0:
		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 12)
		vbox.add_child(header_row)
		header_row.add_child(_build_section_title("Past Entries (%d)" % log.size()))
		var search_input := LineEdit.new()
		search_input.placeholder_text = "Search: date or text..."
		search_input.text = _log_search_filter
		search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_input.custom_minimum_size = Vector2(180, 0)
		# Live-filter via text_changed signal — refresh content when query changes.
		search_input.text_changed.connect(func(new_text: String):
			_log_search_filter = new_text
			_refresh_content()
		)
		header_row.add_child(search_input)

		# Build display list: sorted by date descending, with original index preserved
		# so edit/delete still target the correct underlying array slot.
		var display_list: Array = []
		for i in range(log.size()):
			var entry: Dictionary = log[i]
			if not _log_matches_search(entry, _log_search_filter):
				continue
			display_list.append({"idx": i, "entry": entry})
		display_list.sort_custom(func(a, b):
			# Compare YYYY-MM-DD strings (lex order = chrono order).
			# Fall back to insertion order when dates are equal/missing.
			var da: String = str((a.entry as Dictionary).get("date", ""))
			var db: String = str((b.entry as Dictionary).get("date", ""))
			if da == db:
				return int(a.idx) > int(b.idx)
			return da > db
		)

		if display_list.is_empty() and _log_search_filter.length() > 0:
			vbox.add_child(_build_label("No entries match \"%s\"" % _log_search_filter, T.FONT_SIZE_SMALL, T.TEXT_MUTED))

		for item in display_list:
			vbox.add_child(_build_log_entry_card(item.entry, int(item.idx)))

	# Bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad)


# Returns true if the entry matches the free-text filter (case-insensitive).
# Empty filter matches everything.
func _log_matches_search(entry: Dictionary, filter: String) -> bool:
	if filter.is_empty():
		return true
	var needle: String = filter.to_lower()
	for field in ["date", "summary", "practice_note", "next_focus"]:
		if str(entry.get(field, "")).to_lower().contains(needle):
			return true
	return false


func _build_log_entry_card(entry: Dictionary, entry_idx: int) -> PanelContainer:
	var card := _build_content_card()
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	# Edit mode short-circuits the normal display.
	if _editing_log_entry_idx == entry_idx:
		_build_log_entry_edit_form(card_vbox, entry, entry_idx)
		return card

	var is_expanded: bool = _expanded_log_entries.get(entry_idx, false)
	var summary_str: String = str(entry.get("summary", ""))

	# Header is now a flat Button — clicking it toggles expansion. Avoids the
	# z-order conflict the old full-rect overlay had with Edit/Delete buttons.
	var header_btn := Button.new()
	header_btn.flat = true
	header_btn.custom_minimum_size = Vector2(0, 36)
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var preview_suffix: String = ""
	if not is_expanded and summary_str.length() > 0:
		preview_suffix = "    " + (summary_str.substr(0, 80) + ("..." if summary_str.length() > 80 else ""))
	header_btn.text = "%s   %s%s" % [
		"▸" if not is_expanded else "▾",
		str(entry.get("date", "")),
		preview_suffix,
	]
	header_btn.clip_text = true
	header_btn.add_theme_font_override("font", FONT_TITLE)
	header_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	header_btn.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	var captured_expand_idx: int = entry_idx
	header_btn.pressed.connect(func():
		_expanded_log_entries[captured_expand_idx] = not _expanded_log_entries.get(captured_expand_idx, false)
		_refresh_content()
	)
	card_vbox.add_child(header_btn)

	# Expanded content
	if is_expanded:
		if summary_str.length() > 0:
			var summary_lbl := _build_label(summary_str, T.FONT_SIZE_BODY, T.TEXT_SECONDARY)
			summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_vbox.add_child(summary_lbl)

		var practice_str: String = str(entry.get("practice_note", ""))
		if practice_str.length() > 0:
			var practice_row := HBoxContainer.new()
			practice_row.add_theme_constant_override("separation", 6)
			card_vbox.add_child(practice_row)
			var prac_label := _build_label("Practice:", T.FONT_SIZE_SMALL, T.ACCENT_TEAL)
			prac_label.custom_minimum_size = Vector2(60, 0)
			practice_row.add_child(prac_label)
			var prac_text := _build_label(practice_str, T.FONT_SIZE_SMALL, T.TEXT_SECONDARY)
			prac_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			prac_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			practice_row.add_child(prac_text)

		var next_str: String = str(entry.get("next_focus", ""))
		if next_str.length() > 0:
			var next_row := HBoxContainer.new()
			next_row.add_theme_constant_override("separation", 6)
			card_vbox.add_child(next_row)
			var next_label := _build_label("Next:", T.FONT_SIZE_SMALL, T.ACCENT_GOLD)
			next_label.custom_minimum_size = Vector2(60, 0)
			next_row.add_child(next_label)
			var next_text := _build_label(next_str, T.FONT_SIZE_SMALL, T.TEXT_SECONDARY)
			next_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			next_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			next_row.add_child(next_text)

		# Show last-edited timestamp if present (added on every save/update).
		var updated_at: String = str(entry.get("updated_at", ""))
		if updated_at.length() > 0:
			var meta_row := HBoxContainer.new()
			meta_row.alignment = BoxContainer.ALIGNMENT_END
			card_vbox.add_child(meta_row)
			var meta_lbl := _build_label("Last edited: %s" % updated_at, T.FONT_SIZE_SMALL, T.TEXT_MUTED)
			meta_row.add_child(meta_lbl)

		# Action row: Edit + Delete buttons (only when expanded).
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation", 8)
		card_vbox.add_child(actions)

		var dup_btn := Button.new()
		dup_btn.text = "⎘ Duplicate"
		dup_btn.custom_minimum_size = Vector2(96, 30)
		dup_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		dup_btn.tooltip_text = "Pre-fill the New Lesson Entry form from this entry."
		var captured_dup_entry: Dictionary = entry
		dup_btn.pressed.connect(func():
			_pending_log_prefill = captured_dup_entry.duplicate(true)
			_refresh_content()
		)
		actions.add_child(dup_btn)

		var edit_btn := Button.new()
		edit_btn.text = "✎ Edit"
		edit_btn.custom_minimum_size = Vector2(80, 30)
		edit_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		var captured_edit_idx: int = entry_idx
		edit_btn.pressed.connect(func():
			_editing_log_entry_idx = captured_edit_idx
			_expanded_log_entries[captured_edit_idx] = true
			_refresh_content()
		)
		actions.add_child(edit_btn)

		var delete_btn := Button.new()
		delete_btn.text = "🗑 Delete"
		delete_btn.custom_minimum_size = Vector2(86, 30)
		delete_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		delete_btn.add_theme_color_override("font_color", Color(0.92, 0.45, 0.42, 1.0))
		var captured_del_idx: int = entry_idx
		delete_btn.pressed.connect(func():
			_request_delete_lesson_entry(captured_del_idx, str(entry.get("date", "")))
		)
		actions.add_child(delete_btn)

	return card


# Inline edit form rendered inside a log card when _editing_log_entry_idx matches.
# Pre-populates fields with the existing entry; Save merges new values back; Cancel
# discards changes.
func _build_log_entry_edit_form(parent: VBoxContainer, entry: Dictionary, entry_idx: int) -> void:
	var header := _build_label("Editing entry (changes are saved when you press Save)", T.FONT_SIZE_SMALL, T.ACCENT_GOLD)
	parent.add_child(header)

	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 6)
	parent.add_child(date_row)
	var date_lbl := _build_label("Date:", T.FONT_SIZE_SMALL, T.TEXT_MUTED)
	date_lbl.custom_minimum_size = Vector2(70, 0)
	date_row.add_child(date_lbl)
	var date_input := LineEdit.new()
	date_input.text = str(entry.get("date", ""))
	date_input.placeholder_text = "YYYY-MM-DD"
	date_input.custom_minimum_size = Vector2(140, 0)
	date_row.add_child(date_input)

	var summary_lbl := _build_label("Summary:", T.FONT_SIZE_SMALL, T.TEXT_MUTED)
	parent.add_child(summary_lbl)
	var summary_edit := TextEdit.new()
	summary_edit.text = str(entry.get("summary", ""))
	summary_edit.custom_minimum_size = Vector2(0, 80)
	summary_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(summary_edit)

	var practice_row := HBoxContainer.new()
	practice_row.add_theme_constant_override("separation", 6)
	parent.add_child(practice_row)
	var prac_lbl := _build_label("Practice:", T.FONT_SIZE_SMALL, T.ACCENT_TEAL)
	prac_lbl.custom_minimum_size = Vector2(70, 0)
	practice_row.add_child(prac_lbl)
	var practice_input := LineEdit.new()
	practice_input.text = str(entry.get("practice_note", ""))
	practice_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	practice_row.add_child(practice_input)

	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 6)
	parent.add_child(next_row)
	var next_lbl := _build_label("Next:", T.FONT_SIZE_SMALL, T.ACCENT_GOLD)
	next_lbl.custom_minimum_size = Vector2(70, 0)
	next_row.add_child(next_lbl)
	var next_input := LineEdit.new()
	next_input.text = str(entry.get("next_focus", ""))
	next_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_row.add_child(next_input)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	parent.add_child(actions)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.pressed.connect(func():
		_editing_log_entry_idx = -1
		_refresh_content()
	)
	actions.add_child(cancel_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Changes"
	save_btn.custom_minimum_size = Vector2(120, 32)
	var captured_idx: int = entry_idx
	save_btn.pressed.connect(func():
		_on_save_edited_lesson_entry(captured_idx, date_input, summary_edit, practice_input, next_input)
	)
	actions.add_child(save_btn)


func _on_save_edited_lesson_entry(entry_idx: int, date_input: LineEdit, summary_edit: TextEdit, practice_input: LineEdit, next_input: LineEdit) -> void:
	if _selected_student_id == "":
		_editing_log_entry_idx = -1
		_refresh_content()
		return
	var student := _get_selected_student()
	if student.is_empty():
		_editing_log_entry_idx = -1
		_refresh_content()
		return
	var log: Array = student.get("lesson_log", [])
	if entry_idx < 0 or entry_idx >= log.size():
		_editing_log_entry_idx = -1
		_refresh_content()
		return
	# Merge: keep any unknown fields the UI doesn't know about (forward-compat).
	var existing: Dictionary = log[entry_idx] if typeof(log[entry_idx]) == TYPE_DICTIONARY else {}
	var updated: Dictionary = existing.duplicate(true)
	updated["date"] = date_input.text if date_input != null else str(existing.get("date", ""))
	updated["summary"] = summary_edit.text if summary_edit != null else str(existing.get("summary", ""))
	updated["practice_note"] = practice_input.text if practice_input != null else str(existing.get("practice_note", ""))
	updated["next_focus"] = next_input.text if next_input != null else str(existing.get("next_focus", ""))
	updated["updated_at"] = _now_iso()  # audit trail — when did this edit happen
	log[entry_idx] = updated
	student["lesson_log"] = log
	lesson_updated.emit(_selected_student_id, entry_idx, updated)
	data_changed.emit()
	_editing_log_entry_idx = -1
	_refresh_content()


# Pop a ConfirmationDialog before actually deleting a lesson log entry.
func _request_delete_lesson_entry(entry_idx: int, entry_date: String) -> void:
	if _selected_student_id == "":
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete lesson log?"
	dialog.dialog_text = "Delete the lesson log dated \"%s\"?\n\nThis cannot be undone." % entry_date
	dialog.ok_button_text = "Delete"
	add_child(dialog)
	dialog.confirmed.connect(func():
		_on_confirm_delete_lesson_entry(entry_idx)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	_apply_clefira_dialog_style(dialog)
	dialog.popup_centered()


# Mirror of interval_birds.gd::_apply_clefira_dialog_style — kept local so the
# dashboard scene doesn't depend on the main script being already-loaded. Same
# palette so the visual identity carries across all dialogs.
func _apply_clefira_dialog_style(dlg: AcceptDialog) -> void:
	if dlg == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.20, 0.98)
	sb.border_color = Color(0.475, 0.82, 0.80, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	dlg.add_theme_stylebox_override("panel", sb)
	dlg.add_theme_color_override("title_color", Color(0.62, 0.95, 0.88, 1.0))
	dlg.add_theme_font_size_override("title_font_size", 18)
	var lbl: Label = dlg.get_label()
	if lbl != null:
		lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 0.95))
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok_btn: Button = dlg.get_ok_button()
	if ok_btn != null:
		_style_branded_primary_button(ok_btn)
		ok_btn.custom_minimum_size = Vector2(140, 38)
	if dlg is ConfirmationDialog:
		var cancel_btn: Button = (dlg as ConfirmationDialog).get_cancel_button()
		if cancel_btn != null:
			_style_branded_secondary_button(cancel_btn)
			cancel_btn.custom_minimum_size = Vector2(120, 38)


func _style_branded_primary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.475, 0.82, 0.80, 0.92)
	sb.border_color = Color(0.62, 0.95, 0.88, 1.0)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0.475, 0.82, 0.80, 0.30)
	sb.shadow_size = 4
	btn.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(0.55, 0.92, 0.88, 0.96)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = Color(0.40, 0.72, 0.70, 0.96)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.10, 0.16, 0.22, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.06, 0.10, 0.16, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.06, 0.10, 0.16, 1.0))


func _style_branded_secondary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.86, 0.96, 0.10)
	sb.border_color = Color(0.62, 0.86, 0.96, 0.80)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(0.62, 0.86, 0.96, 0.20)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = Color(0.62, 0.86, 0.96, 0.06)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.96))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.95, 1.0, 0.96))


func _on_confirm_delete_lesson_entry(entry_idx: int) -> void:
	if _selected_student_id == "":
		return
	var student := _get_selected_student()
	if student.is_empty():
		return
	var log: Array = student.get("lesson_log", [])
	if entry_idx < 0 or entry_idx >= log.size():
		return
	# Stash the deleted entry so the user can Undo within ~5 seconds.
	var removed: Dictionary = (log[entry_idx] as Dictionary).duplicate(true) if typeof(log[entry_idx]) == TYPE_DICTIONARY else {}
	_pending_undo_delete = {
		"student_id": _selected_student_id,
		"entry_idx": entry_idx,
		"entry": removed,
		"expires_at": Time.get_unix_time_from_system() + 5.0,
	}
	log.remove_at(entry_idx)
	student["lesson_log"] = log
	if _editing_log_entry_idx == entry_idx:
		_editing_log_entry_idx = -1
	_expanded_log_entries.erase(entry_idx)
	data_changed.emit()
	_show_undo_toast()
	_refresh_content()


# Floating "Deleted — Undo" toast. Auto-dismisses after 5 seconds via Timer.
func _show_undo_toast() -> void:
	_dismiss_undo_toast()
	_undo_toast = PanelContainer.new()
	_undo_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_undo_toast.position = Vector2(-180, -90)
	_undo_toast.custom_minimum_size = Vector2(360, 56)
	_undo_toast.z_as_relative = false
	_undo_toast.z_index = 500
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.28, 0.97)
	sb.border_color = T.ACCENT_GOLD
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	_undo_toast.add_theme_stylebox_override("panel", sb)
	add_child(_undo_toast)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 16)
	inner_margin.add_theme_constant_override("margin_right", 16)
	inner_margin.add_theme_constant_override("margin_top", 10)
	inner_margin.add_theme_constant_override("margin_bottom", 10)
	_undo_toast.add_child(inner_margin)
	inner_margin.add_child(row)

	var msg := _build_label("Lesson entry deleted", T.FONT_SIZE_BODY, T.TEXT_PRIMARY)
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg)

	var undo_btn := Button.new()
	undo_btn.text = "↶ Undo"
	undo_btn.custom_minimum_size = Vector2(86, 32)
	undo_btn.add_theme_color_override("font_color", T.ACCENT_GOLD)
	undo_btn.pressed.connect(_on_undo_delete_pressed)
	row.add_child(undo_btn)

	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(_dismiss_undo_toast)
	_undo_toast.add_child(timer)
	timer.start()


func _dismiss_undo_toast() -> void:
	if _undo_toast != null and is_instance_valid(_undo_toast):
		_undo_toast.queue_free()
	_undo_toast = null


func _on_undo_delete_pressed() -> void:
	if _pending_undo_delete.is_empty():
		_dismiss_undo_toast()
		return
	if Time.get_unix_time_from_system() > float(_pending_undo_delete.get("expires_at", 0.0)):
		_dismiss_undo_toast()
		_pending_undo_delete = {}
		return
	var student_id: String = str(_pending_undo_delete.get("student_id", ""))
	var entry_idx: int = int(_pending_undo_delete.get("entry_idx", -1))
	var entry: Dictionary = _pending_undo_delete.get("entry", {})
	_pending_undo_delete = {}
	_dismiss_undo_toast()
	if student_id == "" or entry.is_empty():
		return
	# Re-insert at the original index if possible; otherwise prepend.
	var students: Array = _data.get("students", [])
	for s in students:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if str((s as Dictionary).get("id", "")) != student_id:
			continue
		var log: Array = (s as Dictionary).get("lesson_log", [])
		var insert_at: int = clampi(entry_idx, 0, log.size())
		log.insert(insert_at, entry)
		(s as Dictionary)["lesson_log"] = log
		break
	data_changed.emit()
	_refresh_content()


# ISO-8601 timestamp helper for audit fields.
func _now_iso() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]


# --- Stats helpers (lesson counts, weekly activity) ---

# Parse YYYY-MM-DD → Unix epoch seconds. Returns 0 on invalid input.
func _parse_iso_date_to_unix(s: String) -> int:
	if s.length() < 10:
		return 0
	var y: int = int(s.substr(0, 4))
	var m: int = int(s.substr(5, 2))
	var d: int = int(s.substr(8, 2))
	if y < 1970 or m < 1 or m > 12 or d < 1 or d > 31:
		return 0
	var dt := {"year": y, "month": m, "day": d, "hour": 0, "minute": 0, "second": 0}
	return int(Time.get_unix_time_from_datetime_dict(dt))


# Returns Unix seconds for the start of "today" (local).
func _today_unix_start() -> int:
	var d := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"]), "hour": 0, "minute": 0, "second": 0}))


# Stats for a single student's lesson_log array.
func _compute_lesson_stats(log: Array) -> Dictionary:
	var stats := {
		"total_count": log.size(),
		"this_week_count": 0,
		"last_lesson_date": "",
		"first_lesson_date": "",
		"avg_days_between": 0.0,
	}
	if log.is_empty():
		return stats
	var week_ago: int = _today_unix_start() - 6 * 86400  # last 7 days inclusive
	var earliest: int = -1
	var latest: int = -1
	for entry_any in log:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var date_s: String = str((entry_any as Dictionary).get("date", ""))
		var u: int = _parse_iso_date_to_unix(date_s)
		if u == 0:
			continue
		if u >= week_ago:
			stats["this_week_count"] = int(stats["this_week_count"]) + 1
		if earliest < 0 or u < earliest:
			earliest = u
			stats["first_lesson_date"] = date_s
		if u > latest:
			latest = u
			stats["last_lesson_date"] = date_s
	if earliest > 0 and latest > earliest and stats["total_count"] > 1:
		var span_days: float = float(latest - earliest) / 86400.0
		stats["avg_days_between"] = span_days / float(int(stats["total_count"]) - 1)
	return stats


# Cross-student stats: total log entries added this week across all students (#25).
func _compute_weekly_workflow_stats() -> Dictionary:
	var out := {"logs_this_week": 0}
	var week_ago: int = _today_unix_start() - 6 * 86400
	for s_any in _data.get("students", []):
		if typeof(s_any) != TYPE_DICTIONARY:
			continue
		for entry_any in (s_any as Dictionary).get("lesson_log", []):
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var u: int = _parse_iso_date_to_unix(str((entry_any as Dictionary).get("date", "")))
			if u >= week_ago:
				out["logs_this_week"] = int(out["logs_this_week"]) + 1
	return out


# Returns up to N students whose most recent log has a non-empty next_focus, for the
# sidebar agenda view (#13). Each item: {student_id, student_name, next_focus, date}.
func _build_today_agenda_items(max_items: int = 6) -> Array:
	var items: Array = []
	for s_any in _data.get("students", []):
		if typeof(s_any) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_any
		var log: Array = s.get("lesson_log", [])
		if log.is_empty():
			continue
		# Find latest entry by date.
		var latest_entry: Dictionary = {}
		var latest_unix: int = -1
		for entry_any in log:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var u: int = _parse_iso_date_to_unix(str((entry_any as Dictionary).get("date", "")))
			if u > latest_unix:
				latest_unix = u
				latest_entry = entry_any
		var next_focus: String = str(latest_entry.get("next_focus", "")).strip_edges()
		if next_focus.is_empty():
			continue
		items.append({
			"student_id": str(s.get("id", "")),
			"student_name": str(s.get("name", "(unnamed)")),
			"next_focus": next_focus,
			"date": str(latest_entry.get("date", "")),
		})
		if items.size() >= max_items:
			break
	return items


# --- Card builders ---

func _build_lesson_stats_card(parent: VBoxContainer, student: Dictionary) -> void:
	var log: Array = student.get("lesson_log", [])
	var stats: Dictionary = _compute_lesson_stats(log)
	var card := _build_content_card()
	parent.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	vbox.add_child(_build_section_title("Lesson Stats"))
	if int(stats["total_count"]) == 0:
		vbox.add_child(_build_label("No lessons logged yet.", T.FONT_SIZE_SMALL, T.TEXT_MUTED))
		return
	var line1 := _build_label(
		"%d total lesson%s    •    %d this week" % [
			int(stats["total_count"]),
			"" if int(stats["total_count"]) == 1 else "s",
			int(stats["this_week_count"]),
		],
		T.FONT_SIZE_BODY, T.TEXT_PRIMARY
	)
	vbox.add_child(line1)
	var last_str: String = str(stats["last_lesson_date"])
	var first_str: String = str(stats["first_lesson_date"])
	if not last_str.is_empty():
		var detail_parts: Array[String] = []
		detail_parts.append("Last: %s" % last_str)
		if not first_str.is_empty() and first_str != last_str:
			detail_parts.append("Started: %s" % first_str)
		var avg: float = float(stats["avg_days_between"])
		if avg > 0.0:
			detail_parts.append("≈ every %.1f days" % avg)
		vbox.add_child(_build_label("    ".join(detail_parts), T.FONT_SIZE_SMALL, T.TEXT_MUTED))


# --- "Since Last Lesson" pre-lesson snapshot ---

# Compute a summary of student activity since the most recent lesson_log entry.
# Returns a dict: { has_last_lesson, last_lesson_date, days_since, sessions_count,
#   total_correct, total_asked, avg_accuracy, modes_practiced, open_assignments,
#   due_this_week, weak_items, next_focus, last_summary }.
func _compute_since_last_lesson(student: Dictionary) -> Dictionary:
	var out := {
		"has_last_lesson": false,
		"last_lesson_date": "",
		"days_since": 0,
		"sessions_count": 0,
		"total_correct": 0,
		"total_asked": 0,
		"avg_accuracy": -1,
		"modes_practiced": [],
		"open_assignments": 0,
		"due_this_week": 0,
		"weak_items": [],
		"next_focus": "",
		"last_summary": "",
	}
	# Pick the most-recent lesson_log entry by date.
	var log: Array = student.get("lesson_log", [])
	var latest_unix: int = -1
	var latest_entry: Dictionary = {}
	for entry_any in log:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var u: int = _parse_iso_date_to_unix(str((entry_any as Dictionary).get("date", "")))
		if u > latest_unix:
			latest_unix = u
			latest_entry = entry_any
	if latest_unix > 0:
		out["has_last_lesson"] = true
		out["last_lesson_date"] = str(latest_entry.get("date", ""))
		out["days_since"] = int(maxi(0, (_today_unix_start() - latest_unix) / 86400))
		out["next_focus"] = str(latest_entry.get("next_focus", "")).strip_edges()
		out["last_summary"] = str(latest_entry.get("summary", "")).strip_edges()

	# Scope session_history to entries on/after the last lesson date. When there
	# is no last lesson, fall back to last 14 days so the card still says
	# something useful for brand-new students.
	var cutoff_unix: int = latest_unix if latest_unix > 0 else (_today_unix_start() - 14 * 86400)
	var sessions: Array = student.get("session_history", [])
	var modes_seen: Dictionary = {}
	var sum_acc: float = 0.0
	var sum_acc_count: int = 0
	for s_any in sessions:
		if typeof(s_any) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_any
		var s_date: String = str(s.get("date", ""))
		var s_unix: int = _parse_iso_date_to_unix(s_date)
		if s_unix == 0 or s_unix < cutoff_unix:
			continue
		out["sessions_count"] = int(out["sessions_count"]) + 1
		out["total_correct"] = int(out["total_correct"]) + int(s.get("correct", 0))
		out["total_asked"] = int(out["total_asked"]) + int(s.get("asked", 0))
		var acc_v = s.get("accuracy", -1)
		if acc_v != null and int(acc_v) >= 0:
			sum_acc += float(acc_v)
			sum_acc_count += 1
		var mode_label: String = str(s.get("mode", "")).strip_edges()
		if mode_label != "":
			modes_seen[mode_label] = true
	if sum_acc_count > 0:
		out["avg_accuracy"] = int(round(sum_acc / float(sum_acc_count)))
	var modes_arr: Array = modes_seen.keys()
	modes_arr.sort()
	out["modes_practiced"] = modes_arr

	# Assignments: count open + count due in next 7 days.
	var assignments: Array = student.get("assignments", [])
	var week_ahead_unix: int = _today_unix_start() + 7 * 86400
	for a_any in assignments:
		if typeof(a_any) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = a_any
		if bool(a.get("done", false)):
			continue
		out["open_assignments"] = int(out["open_assignments"]) + 1
		var due_unix: int = _parse_iso_date_to_unix(str(a.get("due", "")))
		if due_unix > 0 and due_unix <= week_ahead_unix:
			out["due_this_week"] = int(out["due_this_week"]) + 1

	# Weak items: pull current snapshot (top 3) from item_stats. Same heuristic
	# as the "Needs Work" card below, but capped at 3 for the at-a-glance view.
	var item_stats: Dictionary = student.get("item_stats", {})
	var weak: Array = []
	for category in item_stats:
		var cat_stats_any = item_stats.get(category, {})
		if typeof(cat_stats_any) != TYPE_DICTIONARY:
			continue
		var cat_stats: Dictionary = cat_stats_any
		for item_key in cat_stats:
			var entry_any = cat_stats.get(item_key, {})
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any
			var asked := int(entry.get("asked", 0))
			var correct := int(entry.get("correct", 0))
			if asked < 3:
				continue
			var accuracy := int(round(float(correct) / float(maxi(1, asked)) * 100.0))
			if accuracy < 70:
				weak.append({"item": str(item_key), "category": str(category), "accuracy": accuracy})
	weak.sort_custom(func(a, b): return int(a.accuracy) < int(b.accuracy))
	if weak.size() > 3:
		weak.resize(3)
	out["weak_items"] = weak
	return out


func _build_since_last_lesson_card(parent: VBoxContainer, student: Dictionary) -> void:
	var d: Dictionary = _compute_since_last_lesson(student)
	var card := PanelContainer.new()
	# Distinct visual treatment — teal left bar draws the eye to the prep card.
	var sb := _build_card_style(T.BG_CARD, T.ACCENT_TEAL)
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	# Header line — "Since Last Lesson · 10 days ago · May 15" or "No lessons logged yet".
	var header_text: String = ""
	if bool(d.get("has_last_lesson", false)):
		var days_i: int = int(d.get("days_since", 0))
		var when_text := "today" if days_i == 0 else ("yesterday" if days_i == 1 else ("%d days ago" % days_i))
		header_text = "Since Last Lesson  ·  %s  ·  %s" % [when_text, str(d.get("last_lesson_date", ""))]
	else:
		header_text = "Pre-Lesson Snapshot  ·  No lessons logged yet"
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	v.add_child(header_row)
	var header_lbl := _build_label(header_text, T.FONT_SIZE_HEADING, T.ACCENT_TEAL)
	header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_lbl)

	# Practice activity row — chips for sessions / minutes-ish (via questions) / accuracy.
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	v.add_child(act_row)
	var n_sessions: int = int(d.get("sessions_count", 0))
	if n_sessions == 0:
		act_row.add_child(_build_label("Nothing recorded since then — gentle nudge!", T.FONT_SIZE_BODY, T.ACCENT_GOLD))
	else:
		act_row.add_child(_build_stat_chip("Sessions", str(n_sessions), T.ACCENT_BLUE))
		var asked_n: int = int(d.get("total_asked", 0))
		if asked_n > 0:
			act_row.add_child(_build_stat_chip("Questions", str(asked_n), T.ACCENT_PURPLE))
		var avg_acc: int = int(d.get("avg_accuracy", -1))
		if avg_acc >= 0:
			var acc_color: Color = T.ACCENT_GREEN if avg_acc >= 80 else (T.ACCENT_GOLD if avg_acc >= 60 else T.ACCENT_RED)
			act_row.add_child(_build_stat_chip("Avg Accuracy", "%d%%" % avg_acc, acc_color))

	# Modes practiced (chips).
	var modes: Array = d.get("modes_practiced", [])
	if modes.size() > 0:
		var modes_row := HBoxContainer.new()
		modes_row.add_theme_constant_override("separation", 6)
		v.add_child(modes_row)
		modes_row.add_child(_build_label("Modes:", T.FONT_SIZE_SMALL, T.TEXT_MUTED))
		for m in modes:
			modes_row.add_child(_build_label(str(m), T.FONT_SIZE_SMALL, T.TEXT_SECONDARY))

	# Weak items right now (top 3).
	var weak: Array = d.get("weak_items", [])
	if weak.size() > 0:
		var weak_row := HBoxContainer.new()
		weak_row.add_theme_constant_override("separation", 8)
		v.add_child(weak_row)
		weak_row.add_child(_build_label("Focus on:", T.FONT_SIZE_SMALL, T.ACCENT_RED))
		for w_any in weak:
			var w: Dictionary = w_any
			var w_text := "%s (%d%%)" % [str(w.get("item", "")), int(w.get("accuracy", 0))]
			weak_row.add_child(_build_label(w_text, T.FONT_SIZE_SMALL, T.TEXT_PRIMARY))

	# Open assignments line.
	var open_n: int = int(d.get("open_assignments", 0))
	if open_n > 0:
		var due_n: int = int(d.get("due_this_week", 0))
		var assign_text := "%d open assignment%s" % [open_n, "" if open_n == 1 else "s"]
		if due_n > 0:
			assign_text += "  ·  %d due this week" % due_n
		v.add_child(_build_label(assign_text, T.FONT_SIZE_BODY, T.ACCENT_GOLD))

	# Plan from last lesson — what the teacher said to focus on next time.
	var next_focus: String = str(d.get("next_focus", "")).strip_edges()
	if next_focus != "":
		var plan_lbl := _build_label("Plan: %s" % next_focus, T.FONT_SIZE_BODY, T.TEXT_PRIMARY)
		plan_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(plan_lbl)


func set_per_student_stats_provider(fn: Callable) -> void:
	_per_student_stats_provider = fn
	if _content_container != null and _content_container.visible:
		_refresh_content()


# Cloud Sync wiring. The SyncProvider instance is owned by interval_birds.gd
# and handed to us once per app run; we just remember it and forward to the
# dialog when it gets built (or right away if the dialog already exists).
# Also subscribes to provider signals so the top-bar button can show a "●"
# badge whenever a newer snapshot is pending from another device.
func set_sync_provider(provider: Node) -> void:
	_sync_provider = provider
	if _cloud_sync_dialog != null and is_instance_valid(_cloud_sync_dialog):
		_cloud_sync_dialog.call("set_sync_provider", provider)
	if _sync_provider != null:
		# These signals are what affect the badge state. We connect with
		# CONNECT_REFERENCE_COUNTED so multiple set_sync_provider() calls don't
		# accidentally stack duplicate handlers.
		var safe_connect := func(sig: String, cb: Callable) -> void:
			if _sync_provider.has_signal(sig) and not _sync_provider.is_connected(sig, cb):
				_sync_provider.connect(sig, cb)
		safe_connect.call("newer_snapshot_available", Callable(self, "_on_cloud_sync_badge_changed_args3"))
		safe_connect.call("snapshot_pushed", Callable(self, "_on_cloud_sync_badge_changed_args2"))
		safe_connect.call("snapshot_pulled", Callable(self, "_on_cloud_sync_badge_changed_args3_dict"))
		safe_connect.call("signed_out", Callable(self, "_refresh_cloud_sync_badge"))
		safe_connect.call("session_restored", Callable(self, "_on_cloud_sync_badge_changed_args2"))
		_refresh_cloud_sync_badge()


# Single source of truth for the top-bar Cloud Sync button label.
func _refresh_cloud_sync_badge() -> void:
	if _cloud_sync_button == null:
		return
	var pending: bool = _sync_provider != null and _sync_provider.call("has_pending_newer_snapshot")
	_cloud_sync_button.text = "☁ Cloud Sync ●" if pending else "☁ Cloud Sync"


# Signal-handler shims — provider signals carry varying argument lists but we
# only need to refresh the badge from any of them.
func _on_cloud_sync_badge_changed_args2(_a, _b) -> void:
	_refresh_cloud_sync_badge()


func _on_cloud_sync_badge_changed_args3(_a, _b, _c) -> void:
	_refresh_cloud_sync_badge()


func _on_cloud_sync_badge_changed_args3_dict(_bundle: Dictionary, _created_at: String, _device_label: String) -> void:
	_refresh_cloud_sync_badge()


# Lazy-instantiates the dialog on first open. Subsequent opens just show it.
# The dialog lives as a child of the dashboard so it z-orders correctly above
# the dashboard content but below the global modal band.
func _on_cloud_sync_open_pressed() -> void:
	if _cloud_sync_dialog == null or not is_instance_valid(_cloud_sync_dialog):
		_cloud_sync_dialog = CloudSyncDialogScript.new()
		add_child(_cloud_sync_dialog)
		if _sync_provider != null:
			_cloud_sync_dialog.call("set_sync_provider", _sync_provider)
	_cloud_sync_dialog.call("show_dialog")


func _resolve_stats_for_current_student() -> Dictionary:
	# Phase 2c: prefer per-student data when the provider is available.
	# Falls back to the device-wide snapshot for backward compat.
	if _per_student_stats_provider.is_valid() and _selected_student_id != "":
		var stats: Variant = _per_student_stats_provider.call(_selected_student_id)
		if typeof(stats) == TYPE_DICTIONARY:
			return stats
	return _module_progress_stats


# SS3 — Per-key accuracy bar chart for one student. Mirrors the home-overview
# radar but reads from this specific student's item_stats.sight_key. Hidden
# when there are fewer than 5 attempts total (bars wouldn't be meaningful).
func _build_per_key_radar_card(parent: VBoxContainer, student: Dictionary) -> void:
	var item_stats: Dictionary = student.get("item_stats", {})
	if typeof(item_stats) != TYPE_DICTIONARY:
		return
	var per_key: Dictionary = item_stats.get("sight_key", {}) if typeof(item_stats.get("sight_key", {})) == TYPE_DICTIONARY else {}
	if per_key.is_empty():
		return
	# Sum attempts; suppress display under threshold.
	var total_attempts: int = 0
	for k in per_key.keys():
		var entry_v: Variant = per_key[k]
		if typeof(entry_v) == TYPE_DICTIONARY:
			total_attempts += int((entry_v as Dictionary).get("asked", 0))
	if total_attempts < 5:
		return
	var card := _build_content_card()
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	v.add_child(_build_section_title("Sight Reading Accuracy by Key"))
	var key_order: Array[String] = ["C", "1#", "2#", "3#", "1b", "2b", "3b"]
	for k in key_order:
		var entry_any: Variant = per_key.get(k, null)
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any
		var asked: int = int(entry.get("asked", 0))
		if asked == 0:
			continue
		var correct: int = int(entry.get("correct", 0))
		var pct: int = int(round(float(correct) / float(maxi(1, asked)) * 100.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var key_lbl := Label.new()
		key_lbl.text = k.replace("#", char(0x266F)).replace("b", char(0x266D))
		key_lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
		key_lbl.add_theme_color_override("font_color", T.TEXT_PRIMARY)
		key_lbl.custom_minimum_size = Vector2(40, 0)
		row.add_child(key_lbl)
		var bar_bg := PanelContainer.new()
		bar_bg.custom_minimum_size = Vector2(260, 14)
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = Color(0.10, 0.12, 0.16, 0.85)
		bg_sb.corner_radius_top_left = 3
		bg_sb.corner_radius_top_right = 3
		bg_sb.corner_radius_bottom_left = 3
		bg_sb.corner_radius_bottom_right = 3
		bar_bg.add_theme_stylebox_override("panel", bg_sb)
		row.add_child(bar_bg)
		var fill := ColorRect.new()
		var bar_color: Color = T.ACCENT_GREEN if pct >= 80 else (T.ACCENT_GOLD if pct >= 60 else T.ACCENT_RED)
		fill.color = bar_color
		fill.custom_minimum_size = Vector2(int(260.0 * (float(pct) / 100.0)), 14)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(fill)
		var stat_lbl := Label.new()
		stat_lbl.text = "%d%%  (%d / %d)" % [pct, correct, asked]
		stat_lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
		stat_lbl.add_theme_color_override("font_color", T.TEXT_MUTED)
		row.add_child(stat_lbl)


func _build_app_activity_card(parent: VBoxContainer) -> void:
	var stats: Dictionary = _resolve_stats_for_current_student()
	if stats.is_empty() or not bool(stats.get("available", false)):
		return
	var card := _build_content_card()
	parent.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	vbox.add_child(_build_section_title("App Practice Activity"))
	# Label clearly per-student when we have per-student data; device-wide otherwise.
	var is_per_student: bool = _per_student_stats_provider.is_valid() and _selected_student_id != ""
	var sub: String = "This student's recorded practice in the app" if is_per_student else "Device-wide totals (not per-student yet)"
	vbox.add_child(_build_label(sub, T.FONT_SIZE_SMALL, T.TEXT_MUTED))
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 22)
	vbox.add_child(rows)
	rows.add_child(_build_label("%d questions correct" % int(stats.get("total_correct", 0)), T.FONT_SIZE_BODY, T.TEXT_PRIMARY))
	rows.add_child(_build_label("%d modules done" % int(stats.get("completed_modules", 0)), T.FONT_SIZE_BODY, T.TEXT_PRIMARY))
	var mins: int = int(float(stats.get("total_study_seconds", 0.0)) / 60.0)
	if mins > 0:
		rows.add_child(_build_label("%d min studied" % mins, T.FONT_SIZE_BODY, T.TEXT_PRIMARY))
	var due: int = int(stats.get("due_reviews", 0))
	if due > 0:
		rows.add_child(_build_label("%d due for review" % due, T.FONT_SIZE_SMALL, T.ACCENT_GOLD))
	var weakest: String = str(stats.get("weakest_family", ""))
	if not weakest.is_empty():
		vbox.add_child(_build_label("Weakest skill area: %s" % weakest, T.FONT_SIZE_SMALL, T.ACCENT_TEAL))


# Past lesson sessions for the selected student — one row per "Start Lesson →
# End Lesson" bookend, with duration + activity summary. Auto-hidden when there
# are no sessions yet.
func _build_lesson_sessions_card(parent: VBoxContainer, student: Dictionary) -> void:
	var sid: String = str(student.get("id", ""))
	if sid == "":
		return
	var sessions: Array = LessonSessionScript.load_sessions_for(sid)
	if sessions.is_empty():
		return
	var card := _build_content_card()
	parent.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	vbox.add_child(_build_section_title("Recent Lesson Sessions"))
	vbox.add_child(_build_label("Bookended Start Lesson → End Lesson recordings", T.FONT_SIZE_SMALL, T.TEXT_MUTED))
	# Cap to the 8 most recent to keep the card compact. Older sessions stay on
	# disk and are still surfaced via lesson-log entries created from them.
	var shown: int = mini(sessions.size(), 8)
	for i in range(shown):
		var s_any: Variant = sessions[i]
		if typeof(s_any) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_any
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)
		var date_str: String = str(s.get("started_at", ""))
		var dur_sec: int = int(s.get("duration_sec", 0))
		var mm: int = dur_sec / 60
		var ss: int = dur_sec % 60
		var activities: Array = s.get("activities", [])
		var head := _build_label("%s  •  %d:%02d  •  %d round%s" % [
			date_str, mm, ss, activities.size(), "" if activities.size() == 1 else "s"
		], T.FONT_SIZE_BODY, T.TEXT_PRIMARY)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(head)
		var summary_str: String = LessonSessionScript.summarize_activities(s)
		if not summary_str.is_empty():
			vbox.add_child(_build_label("    " + summary_str, T.FONT_SIZE_SMALL, T.TEXT_MUTED))
	if sessions.size() > shown:
		vbox.add_child(_build_label("…and %d earlier" % (sessions.size() - shown), T.FONT_SIZE_SMALL, T.TEXT_MUTED))


# First-run welcome card for teachers with empty rosters. Three CTAs: add
# the first real student, populate a sample studio for exploration, or skip.
# All three set the teacher_onboarding_done flag via signals so this card
# disappears on the next refresh.
func _build_onboarding_welcome_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.22, 0.30, 0.95)
	sb.border_color = T.ACCENT_TEAL
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var header := Label.new()
	header.text = "Welcome to Clefira"
	header.add_theme_font_override("font", FONT_TITLE)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", T.ACCENT_TEAL)
	v.add_child(header)

	var body := Label.new()
	body.text = "Your studio is empty. Start by adding your first student, or load a sample studio to explore the workflow."
	body.add_theme_font_override("font", FONT_BODY)
	body.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	body.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)

	var add_btn := _build_button("+ Add my first student", T.ACCENT_GREEN, func():
		_on_onboarding_add_first_pressed()
	)
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(add_btn)

	var sample_btn := _build_button("Load sample studio (2 demo students)", T.ACCENT_TEAL, func():
		_on_onboarding_load_sample_pressed()
	)
	sample_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sample_btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip — I'll explore on my own"
	skip_btn.flat = true
	skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_btn.add_theme_color_override("font_color", T.TEXT_MUTED)
	skip_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	skip_btn.pressed.connect(func(): _on_onboarding_skip_pressed())
	v.add_child(skip_btn)

	return card


func _on_onboarding_add_first_pressed() -> void:
	onboarding_add_first_student.emit()
	_on_add_student_pressed()


func _on_onboarding_load_sample_pressed() -> void:
	onboarding_load_sample_studio.emit()
	# The main script handles bulk creation + persistence + dashboard refresh.


func _on_onboarding_skip_pressed() -> void:
	onboarding_skipped.emit()
	# Mirror locally so the card disappears immediately even before persistence
	# lands; the main script will re-confirm on its next refresh() call.
	_data["teacher_onboarding_done"] = true
	_rebuild_student_list()


# Build the "Today" agenda + workflow stats above the student list in the sidebar.
# Hidden when there's nothing to show (empty roster or no next_focus anywhere).
# SS1 — Top streak leaderboard. For each student, scan session_history for
# entries in the last 7 days, find the max best_streak. Return top N sorted
# desc. Skips students who never recorded a streak ≥3 (not noise-worthy).
func _compute_streak_leaderboard(limit: int = 3) -> Array:
	var week_ago: int = _today_unix_start() - 6 * 86400
	var rows: Array = []
	for s_any in _data.get("students", []):
		if typeof(s_any) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_any
		var sname: String = str(s.get("name", "(unnamed)"))
		var sessions: Array = s.get("session_history", [])
		var best: int = 0
		for sess_any in sessions:
			if typeof(sess_any) != TYPE_DICTIONARY:
				continue
			var sess: Dictionary = sess_any
			var date_s: String = str(sess.get("date", ""))
			if date_s.length() < 10:
				continue
			var u: int = _parse_iso_date_to_unix(date_s.substr(0, 10))
			if u == 0 or u < week_ago:
				continue
			var streak_v = sess.get("best_streak", 0)
			if streak_v != null:
				best = maxi(best, int(streak_v))
		if best >= 3:
			rows.append({"name": sname, "best_streak": best})
	rows.sort_custom(func(a, b): return int(a.best_streak) > int(b.best_streak))
	if rows.size() > limit:
		rows.resize(limit)
	return rows


func _build_sidebar_top_summary() -> Control:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrap_sb := StyleBoxFlat.new()
	wrap_sb.bg_color = Color(0.08, 0.12, 0.18, 0.6)
	wrap_sb.content_margin_left = 12
	wrap_sb.content_margin_right = 12
	wrap_sb.content_margin_top = 10
	wrap_sb.content_margin_bottom = 10
	wrap.add_theme_stylebox_override("panel", wrap_sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	wrap.add_child(vbox)
	# Weekly workflow stat (#25)
	var workflow: Dictionary = _compute_weekly_workflow_stats()
	var n_logs: int = int(workflow["logs_this_week"])
	if n_logs > 0:
		vbox.add_child(_build_label("%d log%s added this week" % [n_logs, "" if n_logs == 1 else "s"], T.FONT_SIZE_SMALL, T.ACCENT_TEAL))
	# SS1 — Streak leaderboard. Top 3 students by best streak this week.
	# Friendly competition; only shows when 2+ students have meaningful streaks.
	var leaderboard: Array = _compute_streak_leaderboard(3)
	if leaderboard.size() >= 2:
		vbox.add_child(_build_label("%s  Top streaks this week" % char(0x1F525), T.FONT_SIZE_SMALL, T.ACCENT_GOLD))
		var medals := [char(0x1F947), char(0x1F948), char(0x1F949)]
		for i in leaderboard.size():
			var entry: Dictionary = leaderboard[i]
			var line := Label.new()
			line.text = "%s  %s — streak %d" % [medals[i], str(entry.get("name", "")), int(entry.get("best_streak", 0))]
			line.add_theme_font_override("font", FONT_BODY)
			line.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
			line.add_theme_color_override("font_color", T.TEXT_SECONDARY)
			vbox.add_child(line)
	# Agenda (#13)
	var items: Array = _build_today_agenda_items(6)
	if items.is_empty() and n_logs == 0 and leaderboard.size() < 2:
		wrap.queue_free()
		return Control.new()  # nothing to show — caller adds an empty placeholder
	if not items.is_empty():
		vbox.add_child(_build_label("Today's focus", T.FONT_SIZE_SMALL, T.TEXT_MUTED))
		for it_any in items:
			var it: Dictionary = it_any
			var line_btn := Button.new()
			line_btn.text = "▸  %s — %s" % [str(it["student_name"]), str(it["next_focus"])]
			line_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			line_btn.flat = true
			line_btn.clip_text = true
			line_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
			line_btn.add_theme_color_override("font_color", T.TEXT_PRIMARY)
			line_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			line_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_id: String = str(it["student_id"])
			line_btn.pressed.connect(func():
				_selected_student_id = captured_id
				_active_tab = TAB_LESSON_LOG
				_refresh_tab_styles()
				_rebuild_student_list()
				_refresh_content()
			)
			vbox.add_child(line_btn)
	return wrap


func _on_save_lesson_entry(form_card: PanelContainer) -> void:
	if _selected_student_id == "":
		return

	var date_input := _find_child_by_name(form_card, "log_date_input") as LineEdit
	var summary_edit := _find_child_by_name(form_card, "log_summary_edit") as TextEdit
	var practice_input := _find_child_by_name(form_card, "log_practice_input") as LineEdit
	var next_input := _find_child_by_name(form_card, "log_next_input") as LineEdit

	var entry := {
		"date": date_input.text if date_input != null else _today_date(),
		"summary": summary_edit.text if summary_edit != null else "",
		"practice_note": practice_input.text if practice_input != null else "",
		"next_focus": next_input.text if next_input != null else "",
	}

	var student := _get_selected_student()
	if not student.is_empty():
		if not student.has("lesson_log"):
			student["lesson_log"] = []
		student["lesson_log"].append(entry)

	lesson_added.emit(_selected_student_id, entry)
	data_changed.emit()
	_refresh_content()


# =============================================================================
# TAB 4: ASSIGNMENTS
# =============================================================================

func _build_tab_assignments(student: Dictionary) -> void:
	var margin := _build_content_margin()
	_content_container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", T.SECTION_GAP)
	margin.add_child(vbox)

	# Add Assignment form
	var form_card := _build_content_card()
	vbox.add_child(form_card)

	var form_hbox := HBoxContainer.new()
	form_hbox.add_theme_constant_override("separation", 8)
	form_card.add_child(form_hbox)

	form_hbox.add_child(_build_field_label("Task"))
	var task_input := _build_input("Assignment description...", "")
	task_input.name = "assign_task_input"
	task_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_hbox.add_child(task_input)

	form_hbox.add_child(_build_field_label("Due"))
	var due_input := _build_input("YYYY-MM-DD", "")
	due_input.name = "assign_due_input"
	due_input.custom_minimum_size = Vector2(120, T.INPUT_HEIGHT)
	form_hbox.add_child(due_input)

	var add_btn := _build_button("Add", T.ACCENT_TEAL, func():
		_on_add_assignment(form_card)
	)
	form_hbox.add_child(add_btn)

	# Open assignments
	var assignments: Array = student.get("assignments", [])
	var open_assignments: Array[Dictionary] = []
	var done_assignments: Array[Dictionary] = []
	var open_indices: Array[int] = []
	var done_indices: Array[int] = []

	for i in assignments.size():
		var a: Dictionary = assignments[i]
		if a.get("done", false):
			done_assignments.append(a)
			done_indices.append(i)
		else:
			open_assignments.append(a)
			open_indices.append(i)

	if open_assignments.size() > 0:
		vbox.add_child(_build_section_title("Open Assignments"))
		for j in open_assignments.size():
			var a: Dictionary = open_assignments[j]
			var real_idx: int = open_indices[j]
			vbox.add_child(_build_assignment_row(a, real_idx, false))
	elif assignments.size() == 0:
		var empty_lbl := _build_label("No assignments yet.", T.FONT_SIZE_BODY, T.TEXT_MUTED)
		vbox.add_child(empty_lbl)

	# Completed section (collapsible)
	if done_assignments.size() > 0:
		var done_header_row := HBoxContainer.new()
		done_header_row.add_theme_constant_override("separation", 6)
		vbox.add_child(done_header_row)

		var toggle_icon := "▾" if _completed_section_expanded else "▸"
		var done_title_btn := Button.new()
		done_title_btn.text = "%s Completed (%d)" % [toggle_icon, done_assignments.size()]
		done_title_btn.add_theme_font_override("font", FONT_TITLE)
		done_title_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_HEADING)
		done_title_btn.add_theme_color_override("font_color", T.TEXT_MUTED)
		_style_flat_button(done_title_btn)
		done_title_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		done_title_btn.pressed.connect(func():
			_completed_section_expanded = not _completed_section_expanded
			_refresh_content()
		)
		done_header_row.add_child(done_title_btn)

		if _completed_section_expanded:
			for j in done_assignments.size():
				var a: Dictionary = done_assignments[j]
				var real_idx: int = done_indices[j]
				vbox.add_child(_build_assignment_row(a, real_idx, true))

	# Bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad)


func _build_assignment_row(assignment: Dictionary, real_idx: int, is_done: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var card_sb := _build_card_style(T.BG_CARD, T.BORDER_SUBTLE)
	card_sb.content_margin_left = 12
	card_sb.content_margin_right = 12
	card_sb.content_margin_top = 8
	card_sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Done checkbox button
	var check_btn := Button.new()
	check_btn.text = "[x]" if is_done else "[ ]"
	check_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	check_btn.add_theme_color_override("font_color", T.ACCENT_GREEN if is_done else T.TEXT_MUTED)
	check_btn.custom_minimum_size = Vector2(32, T.BTN_HEIGHT)
	_style_flat_button(check_btn)
	check_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var idx: int = real_idx
	check_btn.pressed.connect(func():
		_on_toggle_assignment(idx)
	)
	hbox.add_child(check_btn)

	# Task text
	var task_text: String = str(assignment.get("task", ""))
	var task_lbl := _build_label(task_text, T.FONT_SIZE_BODY, T.TEXT_SECONDARY if is_done else T.TEXT_PRIMARY)
	task_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_done:
		task_lbl.modulate.a = 0.6
	hbox.add_child(task_lbl)

	# Due date
	var due_str: String = str(assignment.get("due", ""))
	if due_str != "":
		var due_lbl := _build_label("Due: " + due_str, T.FONT_SIZE_SMALL, T.TEXT_MUTED)
		hbox.add_child(due_lbl)

	# Done date (for completed)
	if is_done:
		var done_at: String = str(assignment.get("done_at", ""))
		if done_at != "":
			var done_lbl := _build_label("Done: " + done_at, T.FONT_SIZE_SMALL, T.ACCENT_GREEN)
			hbox.add_child(done_lbl)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "x"
	remove_btn.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	remove_btn.add_theme_color_override("font_color", T.ACCENT_RED)
	remove_btn.custom_minimum_size = Vector2(24, 24)
	_style_flat_button(remove_btn)
	remove_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	remove_btn.pressed.connect(func():
		_on_remove_assignment(idx)
	)
	hbox.add_child(remove_btn)

	return card


func _on_add_assignment(form_card: PanelContainer) -> void:
	if _selected_student_id == "":
		return

	var task_input := _find_child_by_name(form_card, "assign_task_input") as LineEdit
	var due_input := _find_child_by_name(form_card, "assign_due_input") as LineEdit

	var task_str: String = task_input.text if task_input != null else ""
	var due_str: String = due_input.text if due_input != null else ""

	if task_str.strip_edges() == "":
		return

	var student := _get_selected_student()
	if not student.is_empty():
		if not student.has("assignments"):
			student["assignments"] = []
		student["assignments"].append({
			"task": task_str,
			"due": due_str,
			"done": false,
			"done_at": "",
		})

	assignment_added.emit(_selected_student_id, task_str, due_str)
	data_changed.emit()
	_refresh_content()


func _on_toggle_assignment(idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var assignments: Array = student.get("assignments", [])
	if idx < 0 or idx >= assignments.size():
		return
	var a: Dictionary = assignments[idx]
	a["done"] = not a.get("done", false)
	if a["done"]:
		a["done_at"] = _today_date()
	else:
		a["done_at"] = ""
	assignment_toggled.emit(_selected_student_id, idx)
	data_changed.emit()
	_refresh_content()


func _on_remove_assignment(idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var assignments: Array = student.get("assignments", [])
	if idx < 0 or idx >= assignments.size():
		return
	assignments.remove_at(idx)
	assignment_removed.emit(_selected_student_id, idx)
	data_changed.emit()
	_refresh_content()


# =============================================================================
# TAB 5: TECHNIQUE
# =============================================================================

func _build_tab_technique(student: Dictionary) -> void:
	var margin := _build_content_margin()
	_content_container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", T.SECTION_GAP)
	margin.add_child(vbox)

	# Add Technical Item button
	var add_row := HBoxContainer.new()
	add_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(add_row)

	var add_btn := _build_button("+ Add Technical Item", T.ACCENT_TEAL, func():
		_on_add_tech_item()
	)
	add_row.add_child(add_btn)

	# Technical item cards
	if not student.has("current_technical"):
		student["current_technical"] = []
	var items: Array = student.get("current_technical", [])
	if items.size() == 0:
		var empty_lbl := _build_label("No technical items yet. Add one above or use the presets below.", T.FONT_SIZE_BODY, T.TEXT_MUTED)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty_lbl)
	else:
		for i in items.size():
			var item: Dictionary = items[i]
			vbox.add_child(_build_tech_item_card(item, i))

	# Quick-add presets section
	var presets_card := _build_content_card()
	vbox.add_child(presets_card)
	var presets_vbox := VBoxContainer.new()
	presets_vbox.add_theme_constant_override("separation", 8)
	presets_card.add_child(presets_vbox)
	presets_vbox.add_child(_build_section_title("Quick-Add Presets"))
	var presets_row := HBoxContainer.new()
	presets_row.add_theme_constant_override("separation", 8)
	presets_vbox.add_child(presets_row)

	var major_btn := _build_button("All Major Scales", T.ACCENT_BLUE, func():
		_on_add_preset_scales(MAJOR_SCALE_KEYS, "Major Scale")
	)
	presets_row.add_child(major_btn)

	var minor_btn := _build_button("All Minor Scales", T.ACCENT_PURPLE, func():
		_on_add_preset_scales(MINOR_SCALE_KEYS, "Minor Scale")
	)
	presets_row.add_child(minor_btn)

	var arp_btn := _build_button("All Arpeggios", T.ACCENT_GOLD, func():
		_on_add_preset_scales(MAJOR_SCALE_KEYS, "Arpeggio")
	)
	presets_row.add_child(arp_btn)

	# Bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad)


func _build_tech_item_card(item: Dictionary, item_idx: int) -> PanelContainer:
	var card := _build_content_card()
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card.add_child(card_vbox)

	# Title row with status badge
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(title_row)

	var status_str: String = str(item.get("status", "not_started"))
	var badge := _build_tech_status_badge(status_str)
	title_row.add_child(badge)

	title_row.add_child(_build_field_label("Title"))
	var title_input := _build_input("e.g. C Major Scale", str(item.get("title", "")))
	title_input.name = "tech_title_%d" % item_idx
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_input)

	# Category + Key + Hands row
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(detail_row)

	detail_row.add_child(_build_field_label("Category"))
	var cat_option := OptionButton.new()
	cat_option.name = "tech_category_%d" % item_idx
	for c in TECH_CATEGORIES:
		cat_option.add_item(c)
	var cat_idx := TECH_CATEGORIES.find(str(item.get("category", "scale")))
	if cat_idx >= 0:
		cat_option.selected = cat_idx
	_style_option_button(cat_option)
	detail_row.add_child(cat_option)

	detail_row.add_child(_build_field_label("Key"))
	var key_input := _build_input("e.g. C, G, Bb", str(item.get("key", "")))
	key_input.name = "tech_key_%d" % item_idx
	key_input.custom_minimum_size = Vector2(80, T.INPUT_HEIGHT)
	detail_row.add_child(key_input)

	detail_row.add_child(_build_field_label("Hands"))
	var hands_option := OptionButton.new()
	hands_option.name = "tech_hands_%d" % item_idx
	for h in TECH_HANDS:
		hands_option.add_item(h)
	var hands_idx := TECH_HANDS.find(str(item.get("hands", "HT")))
	if hands_idx >= 0:
		hands_option.selected = hands_idx
	_style_option_button(hands_option)
	detail_row.add_child(hands_option)

	detail_row.add_child(_build_field_label("Status"))
	var status_option := OptionButton.new()
	status_option.name = "tech_status_%d" % item_idx
	for s in TECH_STATUSES:
		status_option.add_item(s)
	var st_idx := TECH_STATUSES.find(status_str)
	if st_idx >= 0:
		status_option.selected = st_idx
	_style_option_button(status_option)
	detail_row.add_child(status_option)

	# BPM + Notes row
	var bpm_row := HBoxContainer.new()
	bpm_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(bpm_row)

	bpm_row.add_child(_build_field_label("Current BPM"))
	var cur_bpm := SpinBox.new()
	cur_bpm.name = "tech_cur_bpm_%d" % item_idx
	cur_bpm.min_value = 20
	cur_bpm.max_value = 300
	cur_bpm.value = int(item.get("current_bpm", 60))
	cur_bpm.custom_minimum_size = Vector2(90, T.INPUT_HEIGHT)
	_style_spin_box(cur_bpm)
	bpm_row.add_child(cur_bpm)

	bpm_row.add_child(_build_field_label("Target BPM"))
	var tgt_bpm := SpinBox.new()
	tgt_bpm.name = "tech_tgt_bpm_%d" % item_idx
	tgt_bpm.min_value = 20
	tgt_bpm.max_value = 300
	tgt_bpm.value = int(item.get("target_bpm", 120))
	tgt_bpm.custom_minimum_size = Vector2(90, T.INPUT_HEIGHT)
	_style_spin_box(tgt_bpm)
	bpm_row.add_child(tgt_bpm)

	bpm_row.add_child(_build_field_label("Notes"))
	var notes_input := _build_input("Practice notes...", str(item.get("notes", "")))
	notes_input.name = "tech_notes_%d" % item_idx
	notes_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bpm_row.add_child(notes_input)

	# Actions row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	action_row.alignment = BoxContainer.ALIGNMENT_END
	card_vbox.add_child(action_row)

	var save_btn := _build_button("Save", T.ACCENT_GREEN, func():
		_on_save_tech_item(card, item_idx)
	)
	action_row.add_child(save_btn)

	var done_btn := _build_button("Mark Done", T.ACCENT_TEAL, func():
		_on_mark_tech_done(item_idx)
	)
	action_row.add_child(done_btn)

	var remove_text := "Confirm Remove?" if _delete_tech_confirm_idx == item_idx else "Remove"
	var remove_btn := _build_button(remove_text, T.ACCENT_RED, func():
		_on_remove_tech_item(item_idx)
	)
	action_row.add_child(remove_btn)

	return card


func _build_tech_status_badge(status: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var color: Color = TECH_STATUS_COLORS.get(status, T.TEXT_MUTED)

	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.5)
	sb.bg_color.a = 0.5
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_color = color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = status.replace("_", " ").capitalize()
	lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)

	return badge


func _on_add_tech_item() -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	if not student.has("current_technical"):
		student["current_technical"] = []
	var new_item := {
		"title": "",
		"category": "scale",
		"key": "",
		"hands": "HT",
		"status": "not_started",
		"current_bpm": 60,
		"target_bpm": 120,
		"notes": "",
	}
	student["current_technical"].append(new_item)
	tech_added.emit(_selected_student_id, new_item)
	data_changed.emit()
	_refresh_content()


func _on_save_tech_item(card: PanelContainer, item_idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var items: Array = student.get("current_technical", [])
	if item_idx < 0 or item_idx >= items.size():
		return
	var item: Dictionary = items[item_idx]

	var title_input := _find_child_by_name(card, "tech_title_%d" % item_idx) as LineEdit
	var cat_option := _find_child_by_name(card, "tech_category_%d" % item_idx) as OptionButton
	var key_input := _find_child_by_name(card, "tech_key_%d" % item_idx) as LineEdit
	var hands_option := _find_child_by_name(card, "tech_hands_%d" % item_idx) as OptionButton
	var status_option := _find_child_by_name(card, "tech_status_%d" % item_idx) as OptionButton
	var cur_bpm := _find_child_by_name(card, "tech_cur_bpm_%d" % item_idx) as SpinBox
	var tgt_bpm := _find_child_by_name(card, "tech_tgt_bpm_%d" % item_idx) as SpinBox
	var notes_input := _find_child_by_name(card, "tech_notes_%d" % item_idx) as LineEdit

	if title_input != null:
		item["title"] = title_input.text
	if cat_option != null and cat_option.selected >= 0 and cat_option.selected < TECH_CATEGORIES.size():
		item["category"] = TECH_CATEGORIES[cat_option.selected]
	if key_input != null:
		item["key"] = key_input.text
	if hands_option != null and hands_option.selected >= 0 and hands_option.selected < TECH_HANDS.size():
		item["hands"] = TECH_HANDS[hands_option.selected]
	if status_option != null and status_option.selected >= 0 and status_option.selected < TECH_STATUSES.size():
		item["status"] = TECH_STATUSES[status_option.selected]
	if cur_bpm != null:
		item["current_bpm"] = int(cur_bpm.value)
	if tgt_bpm != null:
		item["target_bpm"] = int(tgt_bpm.value)
	if notes_input != null:
		item["notes"] = notes_input.text

	tech_updated.emit(_selected_student_id, item_idx, item)
	data_changed.emit()


func _on_mark_tech_done(item_idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var items: Array = student.get("current_technical", [])
	if item_idx < 0 or item_idx >= items.size():
		return
	items[item_idx]["status"] = "mastered"
	tech_updated.emit(_selected_student_id, item_idx, items[item_idx])
	data_changed.emit()
	_refresh_content()


func _on_remove_tech_item(item_idx: int) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	var items: Array = student.get("current_technical", [])
	if item_idx < 0 or item_idx >= items.size():
		return
	if _delete_tech_confirm_idx != item_idx:
		_delete_tech_confirm_idx = item_idx
		_refresh_content()
		return
	_delete_tech_confirm_idx = -1
	items.remove_at(item_idx)
	tech_removed.emit(_selected_student_id, item_idx)
	data_changed.emit()
	_refresh_content()


func _on_add_preset_scales(keys: Array, suffix: String) -> void:
	var student := _get_selected_student()
	if student.is_empty():
		return
	if not student.has("current_technical"):
		student["current_technical"] = []
	var category: String = "scale"
	if suffix == "Arpeggio":
		category = "arpeggio"
	for key in keys:
		var new_item := {
			"title": "%s %s" % [str(key), suffix],
			"category": category,
			"key": str(key),
			"hands": "HT",
			"status": "not_started",
			"current_bpm": 60,
			"target_bpm": 120,
			"notes": "",
		}
		student["current_technical"].append(new_item)
		tech_added.emit(_selected_student_id, new_item)
	data_changed.emit()
	_refresh_content()


# =============================================================================
# QUICK NOTE (OVERVIEW TAB)
# =============================================================================

func _on_quick_note_save(card: PanelContainer) -> void:
	if _selected_student_id == "":
		return
	var note_input := _find_child_by_name(card, "quick_note_input") as LineEdit
	if note_input == null or note_input.text.strip_edges() == "":
		return
	var student := _get_selected_student()
	if student.is_empty():
		return
	if not student.has("lesson_log"):
		student["lesson_log"] = []
	var entry := {
		"date": _today_date(),
		"summary": note_input.text,
		"practice_note": "",
		"next_focus": "",
	}
	student["lesson_log"].append(entry)
	lesson_added.emit(_selected_student_id, entry)
	data_changed.emit()
	_refresh_content()


# =============================================================================
# TAB BADGE COUNTS
# =============================================================================

func _refresh_tab_badge_counts() -> void:
	if _tab_buttons.size() < TAB_NAMES.size():
		return
	var student := _get_selected_student()

	# Reset all tabs to base names first
	for i in TAB_NAMES.size():
		if i < _tab_buttons.size():
			_tab_buttons[i].text = TAB_NAMES[i]

	if student.is_empty():
		return

	# Repertoire count
	var pieces_count: int = student.get("current_pieces", []).size()
	if pieces_count > 0 and TAB_REPERTOIRE < _tab_buttons.size():
		_tab_buttons[TAB_REPERTOIRE].text = "%s (%d)" % [TAB_NAMES[TAB_REPERTOIRE], pieces_count]

	# Open assignments count
	var assignments: Array = student.get("assignments", [])
	var open_count: int = 0
	for a in assignments:
		if not a.get("done", false):
			open_count += 1
	if open_count > 0 and TAB_ASSIGNMENTS < _tab_buttons.size():
		_tab_buttons[TAB_ASSIGNMENTS].text = "%s (%d)" % [TAB_NAMES[TAB_ASSIGNMENTS], open_count]

	# Technique count
	var tech_count: int = student.get("current_technical", []).size()
	if tech_count > 0 and TAB_TECHNIQUE < _tab_buttons.size():
		_tab_buttons[TAB_TECHNIQUE].text = "%s (%d)" % [TAB_NAMES[TAB_TECHNIQUE], tech_count]


# =============================================================================
# HELPER METHODS — UI BUILDERS
# =============================================================================

func _build_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = T.CARD_RADIUS
	sb.corner_radius_top_right = T.CARD_RADIUS
	sb.corner_radius_bottom_left = T.CARD_RADIUS
	sb.corner_radius_bottom_right = T.CARD_RADIUS
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = T.CARD_PADDING
	sb.content_margin_right = T.CARD_PADDING
	sb.content_margin_top = T.CARD_PADDING
	sb.content_margin_bottom = T.CARD_PADDING
	return sb


func _build_button(text: String, color: Color, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", FONT_TITLE)
	btn.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	btn.custom_minimum_size = Vector2(0, T.BTN_HEIGHT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)

	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb: StyleBoxFlat = sb.duplicate()
	pressed_sb.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	# Text color: use dark text for bright buttons, light text for dark
	var luminance: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var text_color: Color = T.TEXT_DARK if luminance > 0.5 else T.TEXT_PRIMARY
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)

	btn.pressed.connect(on_pressed)
	return btn


func _build_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _build_input(placeholder: String, initial: String) -> LineEdit:
	var input := LineEdit.new()
	input.text = initial
	input.placeholder_text = placeholder
	input.custom_minimum_size = Vector2(0, T.INPUT_HEIGHT)
	input.add_theme_font_override("font", FONT_BODY)
	input.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	input.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	input.add_theme_color_override("font_placeholder_color", T.TEXT_MUTED)

	var sb := StyleBoxFlat.new()
	sb.bg_color = T.BG_INPUT
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_color = T.BORDER_SUBTLE
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	input.add_theme_stylebox_override("normal", sb)

	var focus_sb: StyleBoxFlat = sb.duplicate()
	focus_sb.border_color = T.ACCENT_TEAL
	input.add_theme_stylebox_override("focus", focus_sb)

	return input


func _build_text_edit(placeholder: String, initial: String, lines: int) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = initial
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, lines * 22 + 16)
	edit.add_theme_font_override("font", FONT_BODY)
	edit.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	edit.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	edit.add_theme_color_override("font_placeholder_color", T.TEXT_MUTED)
	edit.scroll_fit_content_height = true

	var sb := StyleBoxFlat.new()
	sb.bg_color = T.BG_INPUT
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_color = T.BORDER_SUBTLE
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	edit.add_theme_stylebox_override("normal", sb)

	var focus_sb: StyleBoxFlat = sb.duplicate()
	focus_sb.border_color = T.ACCENT_TEAL
	edit.add_theme_stylebox_override("focus", focus_sb)

	return edit


func _build_section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_HEADING)
	lbl.add_theme_color_override("font_color", T.ACCENT_TEAL)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _build_field_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", T.TEXT_SECONDARY)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _build_content_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	return margin


func _build_content_card() -> PanelContainer:
	var card := PanelContainer.new()
	var card_sb := _build_card_style(T.BG_CARD, T.BORDER_SUBTLE)
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	card_sb.shadow_size = 4
	card.add_theme_stylebox_override("panel", card_sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _build_stat_chip(label_text: String, value_text: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.darkened(0.7)
	sb.bg_color.a = 0.4
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_color = accent
	sb.border_color.a = 0.3
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(vbox)

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_override("font", FONT_TITLE)
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", accent)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(val_lbl)

	var label_lbl := Label.new()
	label_lbl.text = label_text
	label_lbl.add_theme_font_override("font", FONT_BODY)
	label_lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	label_lbl.add_theme_color_override("font_color", T.TEXT_MUTED)
	label_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label_lbl)

	return chip


func _build_status_badge(status: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var color: Color
	match status:
		"assigned":
			color = T.STATUS_ASSIGNED
		"working":
			color = T.STATUS_WORKING
		"polishing":
			color = T.STATUS_POLISHING
		"performed":
			color = T.STATUS_PERFORMED
		"paused":
			color = T.STATUS_PAUSED
		_:
			color = T.TEXT_MUTED

	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.5)
	sb.bg_color.a = 0.5
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_color = color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = status.capitalize()
	lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", T.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)

	return badge


# =============================================================================
# STYLING HELPERS
# =============================================================================

func _style_flat_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, sb)


func _style_spin_box(spin: SpinBox) -> void:
	spin.add_theme_font_override("font", FONT_BODY)
	spin.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	# SpinBox contains a LineEdit child — we style it on the next frame
	# since the internal LineEdit may not be ready yet.
	spin.ready.connect(func():
		var line_edit := spin.get_line_edit()
		if line_edit != null:
			line_edit.add_theme_color_override("font_color", T.TEXT_PRIMARY)
			var sb := StyleBoxFlat.new()
			sb.bg_color = T.BG_INPUT
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			sb.border_color = T.BORDER_SUBTLE
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.content_margin_left = 6
			sb.content_margin_right = 6
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			line_edit.add_theme_stylebox_override("normal", sb)
			var focus_sb: StyleBoxFlat = sb.duplicate()
			focus_sb.border_color = T.ACCENT_TEAL
			line_edit.add_theme_stylebox_override("focus", focus_sb)
	)


func _style_option_button(opt: OptionButton) -> void:
	opt.add_theme_font_override("font", FONT_BODY)
	opt.add_theme_font_size_override("font_size", T.FONT_SIZE_BODY)
	opt.add_theme_color_override("font_color", T.TEXT_PRIMARY)
	opt.custom_minimum_size = Vector2(0, T.INPUT_HEIGHT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.BG_INPUT
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_color = T.BORDER_SUBTLE
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	opt.add_theme_stylebox_override("normal", sb)
	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.border_color = T.ACCENT_TEAL
	opt.add_theme_stylebox_override("hover", hover_sb)
	opt.add_theme_stylebox_override("pressed", sb)


# =============================================================================
# DATA HELPERS
# =============================================================================

func _get_selected_student() -> Dictionary:
	if _selected_student_id == "":
		return {}
	var students: Array = _data.get("students", [])
	for student in students:
		if str(student.get("id", "")) == _selected_student_id:
			return student
	return {}


func _update_student_count() -> void:
	if _student_count_label == null:
		return
	var count: int = _data.get("students", []).size()
	_student_count_label.text = "%d student%s" % [count, "" if count == 1 else "s"]


func _find_child_by_name(parent: Node, child_name: String) -> Node:
	if parent.name == child_name:
		return parent
	for child in parent.get_children():
		var found := _find_child_by_name(child, child_name)
		if found != null:
			return found
	return null


func _today_date() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


func _generate_id() -> String:
	var t := Time.get_unix_time_from_system()
	return "s_%d" % int(t * 1000.0)


func _format_pct(value) -> String:
	if value == null or value == -1:
		return "--"
	return "%d%%" % int(float(value))
