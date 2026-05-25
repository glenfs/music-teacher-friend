class_name PianoKeyStyles
extends RefCounted

# Shared visual styling for piano-keyboard widgets used in the Chord Explorer
# panel, the Sight Reader's big piano, and other keyboard surfaces. Caller
# passes in a Button + tint color; this module owns the StyleBoxFlat shapes
# (white-key cream, black-key dark, with hover/pressed variants).
#
# `tint == Color.WHITE` is the sentinel for "unlit" — use the neutral key
# color. Any other tint is blended in to indicate the key's role (root /
# third / fifth / etc.) in the currently-played chord.


static func is_black_key(pitch: int) -> bool:
	var pc := ((int(pitch) % 12) + 12) % 12
	return pc in [1, 3, 6, 8, 10]


static func apply_white_style(btn: Button, tint: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.985, 0.985, 0.975, 1.0).blend(Color(tint.r, tint.g, tint.b, 0.55) if tint != Color.WHITE else Color(0, 0, 0, 0))
	if tint == Color.WHITE:
		sb.bg_color = Color(0.985, 0.985, 0.975, 1.0)
	sb.border_color = Color(0.62, 0.60, 0.58, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	(hover as StyleBoxFlat).bg_color = (sb.bg_color as Color).lightened(0.04)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate()
	(pressed_sb as StyleBoxFlat).bg_color = (sb.bg_color as Color).darkened(0.06)
	btn.add_theme_stylebox_override("pressed", pressed_sb)


static func apply_black_style(btn: Button, tint: Color) -> void:
	var sb := StyleBoxFlat.new()
	if tint == Color.WHITE:
		sb.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	else:
		sb.bg_color = Color(tint.r * 0.55, tint.g * 0.55, tint.b * 0.55, 1.0)
	sb.border_color = Color(0.02, 0.02, 0.04, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 3
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	(hover as StyleBoxFlat).bg_color = (sb.bg_color as Color).lightened(0.05)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate()
	(pressed_sb as StyleBoxFlat).bg_color = (sb.bg_color as Color).lightened(0.10)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
