extends Control

signal module_selected(module_id: String)
signal test_out_selected(module_id: String)
signal back_pressed
signal review_weak_pressed

const LMD = preload("res://scripts/learning/learning_module_data.gd")
const RegistryScript = preload("res://scripts/learning/learning_module_registry.gd")
const FONT_TITLE := preload("res://assets/fonts/Baloo2-SemiBold.ttf")
const FONT_BODY := preload("res://assets/fonts/Nunito-Regular.ttf")
const CHICKEN_TEXTURE := preload("res://assets/birds/chicken.svg")

const MAP_BG_TOP := Color(0.18, 0.42, 0.28, 1.0)
const PIN_LOCKED_COLOR := Color(0.45, 0.48, 0.50, 0.70)
const PIN_UNLOCKED_COLOR := Color(0.9098, 0.6275, 0.1255, 1.0)
const PIN_COMPLETED_COLOR := Color(0.30, 0.78, 0.40, 1.0)
const PIN_CAPSTONE_COLOR := Color(0.85, 0.65, 0.15, 1.0)
const PIN_CAPSTONE_BG := Color(0.28, 0.18, 0.08, 0.85)
const TEXT_PRIMARY := Color(0.92, 0.97, 1.0, 1.0)
const TEXT_MUTED := Color(0.82, 0.90, 0.97, 0.70)

var _progress: RefCounted
var _pin_container: VBoxContainer
var _chicken_label: Label
var _review_btn: Button = null
var _review_section: Control = null
var _pace_buttons: Array[Button] = []
var _current_pace: String = "normal"


func setup(progress: RefCounted) -> void:
	_progress = progress
	_build_ui()


func refresh() -> void:
	if _pin_container == null:
		return
	for child in _pin_container.get_children():
		child.queue_free()
	_populate_pins()
	if _chicken_label != null:
		_chicken_label.text = _get_progress_greeting()
	_update_review_visibility()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 50

	# Green background (full rect)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = MAP_BG_TOP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Main vertical layout using a single scroll
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(outer_vbox)

	# Top bar (back + title)
	var top_bar := _build_top_bar()
	outer_vbox.add_child(top_bar)

	# Chicken row
	var chicken_row := _build_chicken_row()
	outer_vbox.add_child(chicken_row)

	# Pace selector
	var pace_row := _build_pace_selector()
	outer_vbox.add_child(pace_row)

	# Review weak concepts section
	_review_section = _build_review_section()
	outer_vbox.add_child(_review_section)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	outer_vbox.add_child(spacer)

	# Pin list
	_pin_container = VBoxContainer.new()
	_pin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pin_container.add_theme_constant_override("separation", 0)
	outer_vbox.add_child(_pin_container)

	# Bottom padding
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 30)
	outer_vbox.add_child(bottom_pad)

	_populate_pins()


func _build_top_bar() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 4)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "  Back"
	back_btn.add_theme_font_override("font", FONT_TITLE)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", TEXT_PRIMARY)
	back_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.42, 1.0))
	_style_flat_button(back_btn)
	back_btn.pressed.connect(func(): back_pressed.emit())
	hbox.add_child(back_btn)

	var title := Label.new()
	title.text = "Learning Path"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(spacer)

	return margin


func _build_chicken_row() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var chicken_container := Control.new()
	chicken_container.custom_minimum_size = Vector2(72, 72)
	chicken_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chicken_anim := _build_chicken_animated_sprite()
	if chicken_anim != null:
		chicken_anim.position = Vector2(36, 36)
		chicken_anim.scale = Vector2(0.08, 0.08)
		chicken_container.add_child(chicken_anim)
	else:
		var chicken := TextureRect.new()
		chicken.texture = CHICKEN_TEXTURE
		chicken.custom_minimum_size = Vector2(72, 72)
		chicken.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		chicken.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chicken.modulate = Color(1.0, 0.92, 0.74, 1.0)
		chicken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chicken_container.add_child(chicken)
	hbox.add_child(chicken_container)

	var bubble := PanelContainer.new()
	var bubble_sb := StyleBoxFlat.new()
	bubble_sb.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	bubble_sb.corner_radius_top_left = 22
	bubble_sb.corner_radius_top_right = 22
	bubble_sb.corner_radius_bottom_left = 6
	bubble_sb.corner_radius_bottom_right = 22
	bubble_sb.content_margin_left = 18
	bubble_sb.content_margin_right = 18
	bubble_sb.content_margin_top = 12
	bubble_sb.content_margin_bottom = 12
	bubble_sb.border_color = Color(0.72, 0.82, 0.72, 0.50)
	bubble_sb.border_width_left = 2
	bubble_sb.border_width_top = 2
	bubble_sb.border_width_right = 2
	bubble_sb.border_width_bottom = 2
	bubble_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	bubble_sb.shadow_size = 6
	bubble.add_theme_stylebox_override("panel", bubble_sb)
	bubble.custom_minimum_size = Vector2(280, 0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.add_child(bubble)

	_chicken_label = Label.new()
	_chicken_label.text = _get_progress_greeting()
	_chicken_label.add_theme_font_override("font", FONT_BODY)
	_chicken_label.add_theme_font_size_override("font_size", 16)
	_chicken_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1.0))
	_chicken_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chicken_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(_chicken_label)

	return margin


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

	var frame_w := 914
	var frame_h := 838
	var cols := 8
	var rows := 4
	var total_frames := cols * rows

	var atlas_frames: Array[AtlasTexture] = []
	for r in rows:
		for c in cols:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * frame_w, r * frame_h, frame_w, frame_h)
			atlas_frames.append(atlas)

	# Ping-pong for smooth continuous loop
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


func _build_pace_selector() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 4)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = "Learning Pace"
	label.add_theme_font_override("font", FONT_TITLE)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_current_pace = _progress.get_pace_setting() if _progress != null else "normal"
	_pace_buttons.clear()
	var paces := [
		{"id": "guided", "label": "Guided", "tip": "Extra hints & recap"},
		{"id": "normal", "label": "Normal", "tip": "Standard flow"},
		{"id": "quick", "label": "Quick", "tip": "Skip intros & recaps"},
	]
	for p in paces:
		var btn := Button.new()
		btn.text = p["label"]
		btn.add_theme_font_override("font", FONT_BODY)
		btn.add_theme_font_size_override("font_size", 14)
		btn.custom_minimum_size = Vector2(90, 32)
		btn.tooltip_text = p["tip"]
		var pace_id: String = p["id"]
		_apply_pace_button_style(btn, pace_id == _current_pace)
		btn.pressed.connect(_on_pace_selected.bind(pace_id))
		btn_row.add_child(btn)
		_pace_buttons.append(btn)

	return margin


func _apply_pace_button_style(btn: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if selected:
		sb.bg_color = Color(0.9098, 0.6275, 0.1255, 0.85)
		sb.border_color = Color(1.0, 0.85, 0.20, 0.90)
		btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
	else:
		sb.bg_color = Color(0.20, 0.24, 0.30, 0.60)
		sb.border_color = Color(0.40, 0.45, 0.52, 0.40)
		btn.add_theme_color_override("font_color", TEXT_MUTED)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = sb.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", sb)


func _on_pace_selected(pace_id: String) -> void:
	_current_pace = pace_id
	if _progress != null:
		_progress.set_pace_setting(pace_id)
	var pace_ids := ["guided", "normal", "quick"]
	for i in _pace_buttons.size():
		_apply_pace_button_style(_pace_buttons[i], pace_ids[i] == pace_id)


func _populate_pins() -> void:
	var modules := RegistryScript.resolve_states(_progress)
	for i in modules.size():
		var entry: Dictionary = modules[i]
		var m: Dictionary = entry["module"]
		var state: int = entry["state"]
		if i > 0:
			_pin_container.add_child(_build_connector())
		_pin_container.add_child(_build_pin_row(m, state, i))


func _build_connector() -> CenterContainer:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 24)
	var dots_col := VBoxContainer.new()
	dots_col.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_col.add_theme_constant_override("separation", 6)
	center.add_child(dots_col)
	for _d in 2:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 4)
		dot.color = Color(1.0, 1.0, 1.0, 0.22)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dots_col.add_child(dot)
	return center


func _build_pin_row(module: Dictionary, state: int, index: int) -> Control:
	var margin := MarginContainer.new()
	var offset_x := 40 if index % 2 == 0 else -40
	margin.add_theme_constant_override("margin_left", 50 + maxi(offset_x, 0))
	margin.add_theme_constant_override("margin_right", 50 + maxi(-offset_x, 0))
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb := StyleBoxFlat.new()
	card_sb.corner_radius_top_left = 18
	card_sb.corner_radius_top_right = 18
	card_sb.corner_radius_bottom_left = 18
	card_sb.corner_radius_bottom_right = 18
	card_sb.content_margin_left = 16
	card_sb.content_margin_right = 16
	card_sb.content_margin_top = 14
	card_sb.content_margin_bottom = 14
	card_sb.border_width_left = 2
	card_sb.border_width_top = 2
	card_sb.border_width_right = 2
	card_sb.border_width_bottom = 2
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	card_sb.shadow_size = 8

	var is_capstone: bool = module.get("id", "") == "capstone"

	match state:
		LMD.STATE_LOCKED:
			card_sb.bg_color = Color(0.20, 0.22, 0.24, 0.60)
			card_sb.border_color = PIN_LOCKED_COLOR
		LMD.STATE_UNLOCKED:
			card_sb.bg_color = Color(0.12, 0.18, 0.28, 0.80)
			card_sb.border_color = PIN_UNLOCKED_COLOR
		LMD.STATE_COMPLETED:
			card_sb.bg_color = Color(0.10, 0.26, 0.14, 0.80)
			card_sb.border_color = PIN_COMPLETED_COLOR

	if is_capstone and state != LMD.STATE_LOCKED:
		card_sb.bg_color = PIN_CAPSTONE_BG
		card_sb.border_color = PIN_CAPSTONE_COLOR
		card_sb.border_width_left = 3
		card_sb.border_width_top = 3
		card_sb.border_width_right = 3
		card_sb.border_width_bottom = 3
		card_sb.shadow_color = Color(0.85, 0.65, 0.15, 0.25)
		card_sb.shadow_size = 12
		card.custom_minimum_size = Vector2(280, 80)

	card.add_theme_stylebox_override("panel", card_sb)
	margin.add_child(card)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	# Numbered circle (trophy for capstone)
	if is_capstone:
		inner.add_child(_build_pin_circle_capstone(state))
	else:
		inner.add_child(_build_pin_circle(state, index + 1))

	# Text
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(text_col)

	var title_label := Label.new()
	title_label.text = module.get("title", "")
	title_label.add_theme_font_override("font", FONT_TITLE)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_color: Color = TEXT_MUTED if state == LMD.STATE_LOCKED else TEXT_PRIMARY
	if is_capstone and state != LMD.STATE_LOCKED:
		title_color = Color(1.0, 0.88, 0.40, 1.0)
	title_label.add_theme_color_override("font_color", title_color)
	text_col.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = module.get("description", "")
	desc_label.add_theme_font_override("font", FONT_BODY)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.60, 0.55) if state == LMD.STATE_LOCKED else TEXT_MUTED)
	text_col.add_child(desc_label)

	# Stars + estimated time row
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(meta_row)

	if state == LMD.STATE_COMPLETED:
		var module_id: String = module.get("id", "")
		var stars: int = _progress.get_module_stars(module_id) if _progress != null else 0
		var star_lbl := Label.new()
		var star_text := ""
		for _i in 3:
			star_text += "★" if _i < stars else "☆"
		star_lbl.text = star_text
		star_lbl.add_theme_font_size_override("font_size", 14)
		star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20, 1.0) if stars > 0 else Color(0.50, 0.52, 0.54, 0.50))
		star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_row.add_child(star_lbl)

	var est: int = module.get("est_minutes", 0)
	if est > 0 and state != LMD.STATE_COMPLETED:
		var time_lbl := Label.new()
		time_lbl.text = "~%d min" % est
		time_lbl.add_theme_font_override("font", FONT_BODY)
		time_lbl.add_theme_font_size_override("font_size", 12)
		time_lbl.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70, 0.60))
		time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_row.add_child(time_lbl)

	# Test Out button for unlocked modules
	if state == LMD.STATE_UNLOCKED:
		var test_out_btn := Button.new()
		test_out_btn.text = "Test Out"
		test_out_btn.add_theme_font_override("font", FONT_BODY)
		test_out_btn.add_theme_font_size_override("font_size", 12)
		test_out_btn.custom_minimum_size = Vector2(70, 24)
		test_out_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		test_out_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var to_sb := StyleBoxFlat.new()
		to_sb.bg_color = Color(0.45, 0.30, 0.70, 0.70)
		to_sb.corner_radius_top_left = 6
		to_sb.corner_radius_top_right = 6
		to_sb.corner_radius_bottom_left = 6
		to_sb.corner_radius_bottom_right = 6
		to_sb.content_margin_left = 6
		to_sb.content_margin_right = 6
		to_sb.content_margin_top = 2
		to_sb.content_margin_bottom = 2
		test_out_btn.add_theme_stylebox_override("normal", to_sb)
		var to_hover: StyleBoxFlat = to_sb.duplicate()
		to_hover.bg_color = Color(0.55, 0.38, 0.80, 0.80)
		test_out_btn.add_theme_stylebox_override("hover", to_hover)
		test_out_btn.add_theme_color_override("font_color", Color(0.92, 0.90, 1.0, 1.0))
		var mid: String = module.get("id", "")
		test_out_btn.pressed.connect(func(): test_out_selected.emit(mid))
		meta_row.add_child(test_out_btn)

	# Status icon
	if state == LMD.STATE_COMPLETED:
		var check_label := Label.new()
		check_label.text = "🏆" if is_capstone else "✓"
		check_label.add_theme_font_override("font", FONT_TITLE)
		check_label.add_theme_font_size_override("font_size", 28)
		check_label.add_theme_color_override("font_color", PIN_CAPSTONE_COLOR if is_capstone else PIN_COMPLETED_COLOR)
		check_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(check_label)

	# Click overlay button
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0)
	var module_id: String = module.get("id", "")
	if state == LMD.STATE_LOCKED:
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		btn.disabled = true
	elif state == LMD.STATE_UNLOCKED:
		# Use MOUSE_FILTER_PASS so the Test Out button inside the card
		# can receive clicks without the overlay stealing them.
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): module_selected.emit(module_id))
	else:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): module_selected.emit(module_id))
	card.add_child(btn)

	return margin


func _build_pin_circle(state: int, number: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(44, 44)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4

	match state:
		LMD.STATE_LOCKED:
			sb.bg_color = Color(0.30, 0.32, 0.34, 0.50)
			sb.border_color = PIN_LOCKED_COLOR
		LMD.STATE_UNLOCKED:
			sb.bg_color = Color(0.9098, 0.6275, 0.1255, 0.30)
			sb.border_color = PIN_UNLOCKED_COLOR
		LMD.STATE_COMPLETED:
			sb.bg_color = Color(0.22, 0.62, 0.32, 0.40)
			sb.border_color = PIN_COMPLETED_COLOR

	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = str(number)
	lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", TEXT_MUTED if state == LMD.STATE_LOCKED else TEXT_PRIMARY)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	return panel


func _build_pin_circle_capstone(state: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if state == LMD.STATE_LOCKED:
		sb.bg_color = Color(0.30, 0.32, 0.34, 0.50)
		sb.border_color = PIN_LOCKED_COLOR
	else:
		sb.bg_color = Color(0.45, 0.30, 0.08, 0.70)
		sb.border_color = PIN_CAPSTONE_COLOR
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = "🏆" if state != LMD.STATE_LOCKED else "🔒"
	lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	return panel


func _style_flat_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	for state_name in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state_name, sb)


func _build_review_section() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 2)

	var card := PanelContainer.new()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.16, 0.22, 0.38, 0.80)
	card_sb.corner_radius_top_left = 16
	card_sb.corner_radius_top_right = 16
	card_sb.corner_radius_bottom_left = 16
	card_sb.corner_radius_bottom_right = 16
	card_sb.border_color = Color(0.50, 0.70, 0.90, 0.60)
	card_sb.border_width_left = 2
	card_sb.border_width_top = 2
	card_sb.border_width_right = 2
	card_sb.border_width_bottom = 2
	card_sb.content_margin_left = 18
	card_sb.content_margin_right = 18
	card_sb.content_margin_top = 14
	card_sb.content_margin_bottom = 14
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.14)
	card_sb.shadow_size = 6
	card.add_theme_stylebox_override("panel", card_sb)
	margin.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "🔄"
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "Review Weak Concepts"
	title_lbl.add_theme_font_override("font", FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _get_review_description()
	desc_lbl.add_theme_font_override("font", FONT_BODY)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	_review_btn = Button.new()
	_review_btn.text = "Start Review"
	_review_btn.add_theme_font_override("font", FONT_TITLE)
	_review_btn.add_theme_font_size_override("font_size", 16)
	_review_btn.custom_minimum_size = Vector2(160, 40)
	_review_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.30, 0.55, 0.80, 0.90)
	btn_sb.corner_radius_top_left = 10
	btn_sb.corner_radius_top_right = 10
	btn_sb.corner_radius_bottom_left = 10
	btn_sb.corner_radius_bottom_right = 10
	btn_sb.content_margin_left = 16
	btn_sb.content_margin_right = 16
	btn_sb.content_margin_top = 6
	btn_sb.content_margin_bottom = 6
	_review_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover := btn_sb.duplicate()
	btn_hover.bg_color = Color(0.38, 0.62, 0.88, 0.95)
	_review_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed := btn_sb.duplicate()
	btn_pressed.bg_color = Color(0.22, 0.45, 0.68, 0.90)
	_review_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_review_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_review_btn.pressed.connect(func(): review_weak_pressed.emit())
	vbox.add_child(_review_btn)

	_update_review_visibility()
	return margin


func _update_review_visibility() -> void:
	if _review_section == null:
		return
	var has_weak: bool = _has_weak_concepts()
	_review_section.visible = has_weak


func _has_weak_concepts() -> bool:
	if _progress == null:
		return false
	var rq: RefCounted = _progress.get_review_queue()
	if rq == null:
		return false
	var weak: Array = rq.get_weak_concepts(1)
	return weak.size() > 0


func _get_review_description() -> String:
	if _progress == null:
		return "Review concepts you've struggled with."
	var rq: RefCounted = _progress.get_review_queue()
	if rq == null:
		return "Review concepts you've struggled with."
	var weak: Array = rq.get_weak_concepts(8)
	if weak.size() == 0:
		return "No weak concepts found — great job!"
	var count: int = weak.size()
	return "%d concept%s need%s practice. Focus on your weak spots!" % [count, "s" if count > 1 else "", "s" if count == 1 else ""]


func _get_progress_greeting() -> String:
	if _progress == null:
		return "Welcome to your Learning Path! Tap a module to begin."
	var completed: int = _progress.get_completed_count()
	var total_modules: int = RegistryScript.get_all_modules().size()
	var total_correct: int = _progress.get_total_quizzes_correct()
	if completed == 0:
		return "Welcome to your Learning Path! Tap a module to begin."
	elif completed == total_modules:
		return "Amazing! You've completed all %d modules! You're a music theory pro! 🎵" % total_modules
	elif completed >= total_modules - 2:
		return "Almost there! %d/%d modules done — just a few more to master!" % [completed, total_modules]
	elif completed >= 5:
		return "Great progress! %d modules complete and %d questions answered. Keep going!" % [completed, total_correct]
	else:
		return "Nice work! %d module%s complete. Tap the next golden module to continue!" % [completed, "s" if completed > 1 else ""]
