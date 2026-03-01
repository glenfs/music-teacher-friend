extends "res://scripts/ui/device_profiles/device_profile_base.gd"

func build_profile(viewport_size: Vector2) -> Dictionary:
	var p := super.build_profile(viewport_size)
	p["id"] = "tablet"
	p["ui_class"] = "tablet"
	p["is_touch_primary"] = true
	p["touch_hit_padding"] = 14.0
	p["use_global_touch_rect"] = true
	p["render_profile"] = "tablet_balanced"
	p["rhythm_overlay_left_nudge"] = -8.0
	return p
