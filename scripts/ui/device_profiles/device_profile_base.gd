extends RefCounted

func build_profile(viewport_size: Vector2) -> Dictionary:
	return {
		"id": "base",
		"ui_class": "desktop",
		"is_touch_primary": false,
		"touch_hit_padding": 0.0,
		"use_global_touch_rect": true,
		"render_profile": "default",
		"rhythm_overlay_left_nudge": 0.0
	}
