class_name MidiPianoViz
extends Control

# Persistent MIDI piano visualization that sits at the bottom of the game
# screen. Lights up keys as the user plays them on a MIDI device, with a
# short auto-release tail and "press offset" animation.
#
# The "feedback role" overlay (showing which keys are the correct chord
# tones / which one was the wrong answer in Sight Chords) is owned by the
# parent (interval_birds.gd) and applied via the injected feedback_style
# callable — because the role-to-color mapping is shared with the Sight
# Reader's big piano feedback and lives there for cohesion.


# --- Constants ---
const LOW := 48   # C3
const HIGH := 83  # B5
const WHITE_W := 30.0
const WHITE_H := 92.0
const BLACK_W := 19.0
const BLACK_H := 58.0
const FRAME_PAD := 10.0
const BOTTOM_MARGIN := 14.0
const MAX_HOLD_SEC := 1.2  # auto-release if no note-off arrives


# --- Internal state ---
var _keys: Dictionary = {}              # pitch -> Panel
var _lit_until: Dictionary = {}         # pitch -> float (release time); -1 means held
var _pressed_at: Dictionary = {}        # pitch -> float (press start time)
var _feedback_roles: Dictionary = {}    # pitch -> String (role: "root", "tone", "wrong", "correct", "")

# Injected: applies the feedback-role style for a key (caller owns the
# role-to-color mapping because it's shared with sight feedback display).
# Signature: (pitch:int, panel:Panel, role:String, is_black:bool) -> void
var _apply_feedback_style_callable: Callable = Callable()


# --- Public lifecycle ---


func setup(apply_feedback_style: Callable) -> void:
	_apply_feedback_style_callable = apply_feedback_style
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_as_relative = false
	z_index = 270
	_build_keyboard()


# Light a key on or off. `on=true` holds the key lit until note-off OR the
# auto-release timeout (MAX_HOLD_SEC) elapses.
func light(pitch: int, on: bool) -> void:
	var panel: Panel = _keys.get(pitch, null) as Panel
	if panel == null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if on:
		panel.modulate = _lit_color(pitch)
		_apply_press_offset(panel, true)
		_lit_until[pitch] = -1.0
		_pressed_at[pitch] = now
	else:
		_lit_until[pitch] = now + 0.35
		_pressed_at.erase(pitch)


# Parent calls this every frame.
func tick(_delta: float) -> void:
	if _lit_until.is_empty():
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var to_clear: Array[int] = []
	for pitch_key in _lit_until.keys():
		var pitch := int(pitch_key)
		var until: float = float(_lit_until[pitch])
		var panel: Panel = _keys.get(pitch, null) as Panel
		if panel == null:
			to_clear.append(pitch)
			continue
		if until < 0.0:
			var pressed_at: float = float(_pressed_at.get(pitch, now))
			if now - pressed_at >= MAX_HOLD_SEC:
				_lit_until[pitch] = now + 0.35
				_pressed_at.erase(pitch)
			continue
		if now >= until:
			panel.modulate = Color.WHITE
			_apply_feedback_role_style(pitch)
			_apply_press_offset(panel, false)
			to_clear.append(pitch)
		else:
			var t := clampf((until - now) / 0.35, 0.0, 1.0)
			panel.modulate = Color.WHITE.lerp(_lit_color(pitch), t)
			_apply_press_offset(panel, t > 0.5)
	for p in to_clear:
		_lit_until.erase(p)


func clear_all() -> void:
	_feedback_roles.clear()
	for k in _keys.keys():
		var panel: Panel = _keys[k] as Panel
		if panel != null:
			panel.modulate = Color.WHITE
			_apply_feedback_role_style(int(k))
			_apply_press_offset(panel, false)
	_lit_until.clear()
	_pressed_at.clear()


# Set the feedback role for a single pitch and immediately apply its style.
func set_feedback_role(pitch: int, role: String) -> void:
	_feedback_roles[pitch] = role
	_apply_feedback_role_style(pitch)


# Clear all feedback roles + reapply neutral styling.
func clear_feedback_roles() -> void:
	_feedback_roles.clear()
	for k in _keys.keys():
		_apply_feedback_role_style(int(k))


# Read-only accessor for the keys dict (caller iterates to apply styles externally).
func get_keys() -> Dictionary:
	return _keys


func get_feedback_role(pitch: int) -> String:
	return str(_feedback_roles.get(pitch, ""))


# --- Internal ---


func _lit_color(pitch: int) -> Color:
	if _is_black(pitch):
		return Color(0.32, 0.78, 1.0, 1.0)
	return Color(0.55, 0.88, 1.0, 1.0)


func _apply_press_offset(panel: Panel, pressed: bool) -> void:
	var base: Vector2 = panel.get_meta("base_pos", panel.position)
	if pressed:
		panel.position = base + Vector2(0, 2)
	else:
		panel.position = base


func _apply_feedback_role_style(pitch: int) -> void:
	var panel: Panel = _keys.get(pitch, null) as Panel
	if panel == null:
		return
	var role := str(_feedback_roles.get(pitch, ""))
	var is_black := bool(panel.get_meta("is_black", false))
	if _apply_feedback_style_callable.is_valid():
		_apply_feedback_style_callable.call(pitch, panel, role, is_black)


func _is_black(pitch: int) -> bool:
	var pc := ((pitch % 12) + 12) % 12
	return pc in [1, 3, 6, 8, 10]


func _build_keyboard() -> void:
	var num_octaves := int((HIGH - LOW + 1) / 12)
	var total_whites := num_octaves * 7
	var keys_w := total_whites * WHITE_W
	var keys_h := WHITE_H
	var frame_w := keys_w + FRAME_PAD * 2.0
	var frame_h := keys_h + FRAME_PAD * 2.0 + 6.0

	# Anchor bottom-center.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -frame_w * 0.5
	offset_right = frame_w * 0.5
	offset_top = -frame_h - BOTTOM_MARGIN
	offset_bottom = -BOTTOM_MARGIN
	custom_minimum_size = Vector2(frame_w, frame_h)

	var frame_panel := Panel.new()
	frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.10, 0.09, 0.96)
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = Color(0.32, 0.22, 0.16, 1.0)
	frame_style.corner_radius_top_left = 10
	frame_style.corner_radius_top_right = 10
	frame_style.corner_radius_bottom_left = 10
	frame_style.corner_radius_bottom_right = 10
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	frame_style.shadow_size = 8
	frame_style.shadow_offset = Vector2(0, 4)
	frame_panel.add_theme_stylebox_override("panel", frame_style)
	frame_panel.position = Vector2.ZERO
	frame_panel.size = Vector2(frame_w, frame_h)
	add_child(frame_panel)

	var felt := Panel.new()
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var felt_style := StyleBoxFlat.new()
	felt_style.bg_color = Color(0.55, 0.10, 0.12, 1.0)
	felt.add_theme_stylebox_override("panel", felt_style)
	felt.position = Vector2(FRAME_PAD, FRAME_PAD)
	felt.size = Vector2(keys_w, 4)
	add_child(felt)

	var keys_root := Control.new()
	keys_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys_root.position = Vector2(FRAME_PAD, FRAME_PAD + 6)
	keys_root.size = Vector2(keys_w, keys_h)
	add_child(keys_root)

	var white_style := StyleBoxFlat.new()
	white_style.bg_color = Color(0.985, 0.985, 0.975, 1.0)
	white_style.border_width_left = 1
	white_style.border_width_right = 1
	white_style.border_width_top = 0
	white_style.border_width_bottom = 2
	white_style.border_color = Color(0.62, 0.60, 0.58, 1.0)
	white_style.corner_radius_bottom_left = 5
	white_style.corner_radius_bottom_right = 5
	white_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	white_style.shadow_size = 2
	white_style.shadow_offset = Vector2(0, 2)

	var black_style := StyleBoxFlat.new()
	black_style.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	black_style.border_width_left = 1
	black_style.border_width_right = 1
	black_style.border_width_top = 1
	black_style.border_width_bottom = 3
	black_style.border_color = Color(0.02, 0.02, 0.04, 1.0)
	black_style.corner_radius_bottom_left = 4
	black_style.corner_radius_bottom_right = 4
	black_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	black_style.shadow_size = 3
	black_style.shadow_offset = Vector2(0, 2)

	var white_x := 0.0
	var white_positions: Dictionary = {}
	for pitch in range(LOW, HIGH + 1):
		if _is_black(pitch):
			continue
		var w_key := Panel.new()
		w_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w_key.add_theme_stylebox_override("panel", white_style)
		w_key.position = Vector2(white_x, 0)
		w_key.size = Vector2(WHITE_W, WHITE_H)
		w_key.set_meta("base_pos", w_key.position)
		w_key.set_meta("is_black", false)
		keys_root.add_child(w_key)
		_keys[pitch] = w_key
		white_positions[pitch] = white_x
		var pc := ((pitch % 12) + 12) % 12
		var letter_for_pc := {0: "C", 2: "D", 4: "E", 5: "F", 7: "G", 9: "A", 11: "B"}
		var letter: String = String(letter_for_pc.get(pc, ""))
		if not letter.is_empty():
			# Add label as sibling of the key (above in keys_root z-order) so
			# feedback-role color changes on the key don't hide it.
			var lbl := Label.new()
			if pc == 0:
				lbl.text = "C%d" % int(pitch / 12 - 1)
			else:
				lbl.text = letter
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(0.08, 0.10, 0.16, 1.0))
			lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			lbl.position = Vector2(white_x, WHITE_H - 18.0)
			lbl.size = Vector2(WHITE_W, 16.0)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.z_index = 5
			keys_root.add_child(lbl)
		white_x += WHITE_W

	for pitch in range(LOW, HIGH + 1):
		if not _is_black(pitch):
			continue
		var prev_white := pitch - 1
		if not white_positions.has(prev_white):
			continue
		var b_key := Panel.new()
		b_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_key.add_theme_stylebox_override("panel", black_style)
		var bx: float = float(white_positions[prev_white]) + WHITE_W - BLACK_W * 0.5
		b_key.position = Vector2(bx, 0)
		b_key.size = Vector2(BLACK_W, BLACK_H)
		b_key.set_meta("base_pos", b_key.position)
		b_key.set_meta("is_black", true)
		keys_root.add_child(b_key)
		_keys[pitch] = b_key
