extends "res://scripts/ui/device_profiles/device_profile_base.gd"

func build_profile(viewport_size: Vector2) -> Dictionary:
	var p := super.build_profile(viewport_size)
	p["id"] = "desktop"
	p["ui_class"] = "desktop"
	p["is_touch_primary"] = false
	p["touch_hit_padding"] = 0.0
	p["use_global_touch_rect"] = true
	p["render_profile"] = "desktop_full"
	p["rhythm_overlay_left_nudge"] = 0.0
	return p
