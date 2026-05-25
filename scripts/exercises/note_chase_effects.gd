class_name NoteChaseEffects
extends RefCounted

# Pure visual-effect helpers for Note Chase mode. All animations and
# child-node creation are factored out of the parent controller so the
# parent stays focused on game state.
#
# Each function takes the host node (where children/auras are added) plus
# any other inputs it needs. Tweens are created on the host so they
# auto-clean when the host is freed.


# Fade + slight shrink, marking the node so successive calls don't double-tween.
static func fade_out_control(node: Control, duration: float = 0.22) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("nc_fading") and bool(node.get_meta("nc_fading")):
		return
	node.set_meta("nc_fading", true)
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(node, "scale", node.scale * Vector2(0.96, 0.96), duration)


# Pulsing golden rim — rainbow notes get this aura layered behind them.
static func add_rainbow_aura(panel: Panel) -> void:
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
	var tw := aura.create_tween()
	tw.set_loops()
	tw.tween_property(aura, "modulate:a", 0.45, 0.35)
	tw.tween_property(aura, "modulate:a", 1.0, 0.35)


# Generic colored aura used for freeze / shield / special notes.
static func add_special_aura(panel: Panel, glow_color: Color) -> void:
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
	var tw := aura.create_tween()
	tw.set_loops()
	tw.tween_property(aura, "modulate:a", 0.40, 0.30)
	tw.tween_property(aura, "modulate:a", 1.0, 0.30)


# Radial burst of 7 tiny circles flying outward from `center`. RNG used
# for angular jitter + distance variance so successive pops don't look
# identical when many notes are popped in quick succession.
static func spawn_pop_effect(host: Control, center: Vector2, color: Color, rng: RandomNumberGenerator) -> void:
	if host == null:
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
		host.add_child(b)
		var ang := (TAU * float(i) / 7.0) + rng.randf_range(-0.22, 0.22)
		var dist := 26.0 + rng.randf() * 12.0
		var target := b.position + Vector2(cos(ang), sin(ang)) * dist
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", target, 0.22)
		tw.parallel().tween_property(b, "modulate:a", 0.0, 0.22)
		tw.finished.connect(func() -> void:
			if is_instance_valid(b):
				b.queue_free()
		)


# Floats a letter (e.g. the note name the player just popped) upward and
# fades it out — confirms which letter was hit.
static func spawn_note_name_text(host: Control, center: Vector2, text: String, color: Color) -> void:
	if host == null:
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
	host.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 20.0, 0.34)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.34)
	tw.finished.connect(func() -> void:
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


# Bouncy "pop in" when a note first appears: scales from 35% to 114% to 100%
# with the back-out easing curve, plus a quick fade-in.
static func play_spawn_bubble_anim(panel: Control) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.35, 0.35)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := panel.create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.10)
	tw.tween_property(panel, "scale", Vector2(1.14, 1.14), 0.10)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.08)
