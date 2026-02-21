class_name HomeMenuTokens
extends RefCounted

const THEMES := {
	"golden_harvest": {
		"label": "Golden Harvest",
		"colors": {
			"panel_bg": Color(0.10, 0.14, 0.11, 0.74),
			"panel_border": Color(0.92, 0.84, 0.58, 0.45),
			"text_primary": Color(0.98, 0.96, 0.88, 1.0),
			"text_muted": Color(0.92, 0.90, 0.82, 0.86),
			"text_error": Color(1.0, 0.83, 0.70, 1.0),
			"focus_border": Color(0.26, 0.93, 0.98, 0.96),
			"hint": Color(0.83, 0.95, 0.98, 0.95),
			"disabled_overlay": Color(0.55, 0.55, 0.55, 0.38)
		}
	},
	"azure_cascade": {
		"label": "Azure Cascade",
		"colors": {
			"panel_bg": Color(0.07, 0.13, 0.21, 0.76),
			"panel_border": Color(0.42, 0.72, 0.95, 0.52),
			"text_primary": Color(0.92, 0.97, 1.0, 1.0),
			"text_muted": Color(0.82, 0.90, 0.97, 0.90),
			"text_error": Color(1.0, 0.72, 0.72, 1.0),
			"focus_border": Color(1.0, 0.90, 0.42, 1.0),
			"hint": Color(0.72, 0.90, 1.0, 0.96),
			"disabled_overlay": Color(0.46, 0.50, 0.58, 0.40)
		}
	},
	"slate_foundry": {
		"label": "Slate Foundry",
		"colors": {
			"panel_bg": Color(0.12, 0.13, 0.16, 0.78),
			"panel_border": Color(0.62, 0.66, 0.72, 0.52),
			"text_primary": Color(0.94, 0.95, 0.97, 1.0),
			"text_muted": Color(0.82, 0.84, 0.88, 0.90),
			"text_error": Color(1.0, 0.76, 0.74, 1.0),
			"focus_border": Color(0.56, 0.92, 1.0, 1.0),
			"hint": Color(0.78, 0.85, 0.92, 0.96),
			"disabled_overlay": Color(0.50, 0.50, 0.54, 0.42)
		}
	},
	"crimson_nocturne": {
		"label": "Crimson Nocturne",
		"colors": {
			"panel_bg": Color(0.20, 0.08, 0.10, 0.78),
			"panel_border": Color(0.94, 0.46, 0.40, 0.52),
			"text_primary": Color(1.0, 0.94, 0.90, 1.0),
			"text_muted": Color(0.95, 0.84, 0.82, 0.90),
			"text_error": Color(1.0, 0.76, 0.70, 1.0),
			"focus_border": Color(0.56, 1.0, 0.86, 1.0),
			"hint": Color(1.0, 0.80, 0.72, 0.96),
			"disabled_overlay": Color(0.58, 0.40, 0.40, 0.40)
		}
	},
	"rose_velvet": {
		"label": "Rose Velvet",
		"colors": {
			"panel_bg": Color(0.22, 0.11, 0.18, 0.76),
			"panel_border": Color(0.95, 0.60, 0.77, 0.54),
			"text_primary": Color(1.0, 0.94, 0.98, 1.0),
			"text_muted": Color(0.96, 0.84, 0.92, 0.90),
			"text_error": Color(1.0, 0.74, 0.82, 1.0),
			"focus_border": Color(0.72, 1.0, 0.64, 1.0),
			"hint": Color(1.0, 0.78, 0.90, 0.96),
			"disabled_overlay": Color(0.60, 0.48, 0.56, 0.40)
		}
	}
}

const COLORS_HIGH_CONTRAST := {
	"panel_bg": Color(0.02, 0.02, 0.02, 0.94),
	"panel_border": Color(1.0, 1.0, 1.0, 0.98),
	"text_primary": Color(1.0, 1.0, 1.0, 1.0),
	"text_muted": Color(0.92, 0.92, 0.92, 1.0),
	"text_error": Color(1.0, 0.86, 0.50, 1.0),
	"focus_border": Color(1.0, 1.0, 0.38, 1.0),
	"hint": Color(0.92, 1.0, 0.92, 1.0),
	"disabled_overlay": Color(0.42, 0.42, 0.42, 0.62)
}

var _theme_id := "golden_harvest"

const SPACING := {
	"section_gap": 12,
	"row_gap": 8,
	"grid_h_gap": 8,
	"grid_v_gap": 8
}

const RADIUS := {
	"card": 18,
	"button": 12,
	"toggle": 16
}

const SHADOW := {
	"card_size": 10,
	"button_size": 4
}

const FONT_SIZES := {
	"title": 52,
	"section_title": 24,
	"button": 19,
	"hint": 14,
	"hint_large": 17
}

const LAYOUTS := {
	"small_phone": {"name": "small_phone", "columns_modes": 2, "columns_degrees": 4, "columns_notes": 4, "large_text_scale": 1.08},
	"large_phone": {"name": "large_phone", "columns_modes": 2, "columns_degrees": 8, "columns_notes": 7, "large_text_scale": 1.12},
	"tablet": {"name": "tablet", "columns_modes": 4, "columns_degrees": 8, "columns_notes": 7, "large_text_scale": 1.16}
}

func profile_for_viewport(vp: Vector2) -> Dictionary:
	if vp.x >= 960.0 or vp.y >= 700.0:
		return LAYOUTS["tablet"]
	if vp.x < 560.0:
		return LAYOUTS["small_phone"]
	return LAYOUTS["large_phone"]

func theme_ids() -> Array[String]:
	return ["golden_harvest", "azure_cascade", "slate_foundry", "crimson_nocturne", "rose_velvet"]

func set_theme(theme_id: String) -> void:
	if THEMES.has(theme_id):
		_theme_id = theme_id
	else:
		_theme_id = "golden_harvest"

func theme_id() -> String:
	return _theme_id

func theme_label(theme_id: String) -> String:
	if THEMES.has(theme_id):
		var d: Dictionary = THEMES[theme_id]
		return str(d.get("label", theme_id))
	return "Golden Harvest"

func colors(high_contrast: bool) -> Dictionary:
	if high_contrast:
		return COLORS_HIGH_CONTRAST
	var d: Dictionary = THEMES.get(_theme_id, THEMES["golden_harvest"])
	return d.get("colors", THEMES["golden_harvest"]["colors"])
