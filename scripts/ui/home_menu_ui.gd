class_name HomeMenuUI
extends RefCounted

var _tokens
var _styles: Dictionary = {}

func setup(tokens) -> void:
	_tokens = tokens
	_cache_styles(false)

func _cache_styles(high_contrast: bool) -> void:
	if _tokens == null:
		return
	var colors: Dictionary = _tokens.colors(high_contrast)
	var contract: Dictionary = _tokens.menu_style_contract() if _tokens.has_method("menu_style_contract") else {}
	var key: String = "hc" if high_contrast else "normal"
	if _styles.has(key):
		return

	var section_active := StyleBoxFlat.new()
	section_active.bg_color = Color(contract.get("panel_bg", Color(0.86, 0.93, 0.97, 0.92))) if not high_contrast else Color(0.10, 0.10, 0.10, 0.98)
	section_active.bg_color.a = 0.92 if not high_contrast else section_active.bg_color.a
	section_active.border_color = Color(contract.get("panel_border", colors["focus_border"])) if not high_contrast else colors["focus_border"]
	section_active.border_width_left = 1
	section_active.border_width_top = 1
	section_active.border_width_right = 1
	section_active.border_width_bottom = 1
	section_active.corner_radius_top_left = 18
	section_active.corner_radius_top_right = 18
	section_active.corner_radius_bottom_left = 18
	section_active.corner_radius_bottom_right = 18
	section_active.shadow_color = Color(0.0, 0.0, 0.0, float(contract.get("shadow_panel_alpha", 0.14)))
	section_active.shadow_size = int(contract.get("shadow_panel_size", 6))

	var section_idle := section_active.duplicate()
	section_idle.bg_color = Color(contract.get("panel_bg_compact", Color(0.82, 0.90, 0.96, 0.86))) if not high_contrast else Color(0.06, 0.06, 0.06, 0.90)
	section_idle.bg_color.a = 0.86 if not high_contrast else section_idle.bg_color.a
	section_idle.border_color = Color(contract.get("panel_border", _tokens.colors(high_contrast)["panel_border"])) if not high_contrast else _tokens.colors(high_contrast)["panel_border"]
	section_idle.shadow_color = Color(0.0, 0.0, 0.0, float(contract.get("shadow_panel_alpha", 0.14)))
	section_idle.shadow_size = maxi(1, int(contract.get("shadow_panel_size", 6)) - 1)

	_styles[key] = {
		"section_active": section_active,
		"section_idle": section_idle
	}

func section_card_style(active: bool, high_contrast: bool) -> StyleBoxFlat:
	_cache_styles(high_contrast)
	var key: String = "hc" if high_contrast else "normal"
	return (_styles[key]["section_active"] if active else _styles[key]["section_idle"]).duplicate()

func ensure_section_hint(section: VBoxContainer, text: String, high_contrast: bool, large_text: bool) -> Label:
	var lbl: Label = null
	for child in section.get_children():
		if child is Label and child.has_meta("home_hint"):
			lbl = child as Label
			break
	if lbl == null:
		lbl = Label.new()
		lbl.set_meta("home_hint", true)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(lbl)
		section.move_child(lbl, mini(section.get_child_count() - 1, 1))
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", _tokens.FONT_SIZES["hint_large"] if large_text else _tokens.FONT_SIZES["hint"])
	lbl.add_theme_color_override("font_color", _tokens.colors(high_contrast)["hint"])
	return lbl

func animate_section_visibility(section: VBoxContainer, card: Control, visible: bool) -> void:
	if section == null:
		return
	var target := card if card != null else section
	var current_visible := section.visible and target.visible and target.modulate.a >= 0.99
	if current_visible == visible:
		return
	if target.has_meta("home_section_tween"):
		target.remove_meta("home_section_tween")
	target.modulate = Color(1, 1, 1, 1)
	target.position = Vector2.ZERO
	target.visible = visible
	section.visible = visible
	if card != null:
		card.visible = visible

func apply_focus_chain(controls: Array[Control], default_focus: Control) -> void:
	var valid: Array[Control] = []
	for c in controls:
		if c != null and is_instance_valid(c) and c.focus_mode != Control.FOCUS_NONE:
			valid.append(c)
	if valid.is_empty():
		return
	for i in valid.size():
		var current := valid[i]
		var next := valid[(i + 1) % valid.size()]
		var prev := valid[(i - 1 + valid.size()) % valid.size()]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(prev)
	if default_focus != null and default_focus.visible and not default_focus.disabled:
		default_focus.grab_focus()

func set_selected_text_marker(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	if not btn.has_meta("base_text"):
		var clean := btn.text
		if clean.begins_with("[x] "):
			clean = clean.substr(4)
		elif clean.begins_with("[ ] "):
			clean = clean.substr(4)
		elif clean.begins_with("✓ "):
			clean = clean.substr(2)
		btn.set_meta("base_text", clean)
	var base_text := str(btn.get_meta("base_text"))
	btn.text = ("✓ " + base_text) if selected else base_text

func ensure_grid_layout(row: Control, columns: int, h_gap: int, v_gap: int) -> Control:
	if row == null:
		return row
	if row is GridContainer:
		var existing := row as GridContainer
		existing.columns = max(columns, 1)
		existing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		existing.add_theme_constant_override("h_separation", h_gap)
		existing.add_theme_constant_override("v_separation", v_gap)
		return existing
	var parent := row.get_parent()
	if parent == null:
		return row
	var index := row.get_index()
	var grid := GridContainer.new()
	grid.columns = max(columns, 1)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", h_gap)
	grid.add_theme_constant_override("v_separation", v_gap)
	parent.add_child(grid)
	parent.move_child(grid, index)
	parent.remove_child(row)
	for child in row.get_children():
		row.remove_child(child)
		grid.add_child(child)
	row.queue_free()
	return grid
