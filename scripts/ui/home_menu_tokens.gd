class_name HomeMenuTokens
extends RefCounted

const FIXED_THEME_ID := "azure_cascade"

const THEMES := {
	"golden_harvest": {
		"label": "Golden Harvest",
		"colors": {
			"panel_bg": Color(0.10, 0.14, 0.11, 0.20),
			"panel_border": Color(0.92, 0.84, 0.58, 0.45),
			"text_primary": Color(0.98, 0.96, 0.88, 1.0),
			"text_muted": Color(0.92, 0.90, 0.82, 0.86),
			"text_error": Color(1.0, 0.83, 0.70, 1.0),
			"focus_border": Color(0.95, 0.76, 0.31, 0.96),
			"hint": Color(0.83, 0.95, 0.98, 0.95),
			"disabled_overlay": Color(0.55, 0.55, 0.55, 0.38)
		}
	},
	"azure_cascade": {
		"label": "Azure Cascade",
		"colors": {
			"panel_bg": Color(0.07, 0.13, 0.21, 0.20),
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
			"panel_bg": Color(0.12, 0.13, 0.16, 0.22),
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
			"panel_bg": Color(0.20, 0.08, 0.10, 0.22),
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
			"panel_bg": Color(0.22, 0.11, 0.18, 0.20),
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

var _theme_id := FIXED_THEME_ID

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

# Single source of truth for menu/config visuals.
# Keep these stable so all menu screens style consistently.
const MENU_STYLE_CONTRACT := {
	# Panels/cards
	"panel_bg": Color(0.0588, 0.1529, 0.2510, 0.72), # #0F2740
	"panel_bg_compact": Color(0.0902, 0.2235, 0.3608, 0.74), # #17395C
	"panel_border": Color(0.9098, 0.6275, 0.1255, 0.46), # #E8A020
	"panel_border_strong": Color(0.9098, 0.6275, 0.1255, 0.94),
	# Buttons/chips (inactive)
	"btn_inactive_bg": Color(0.10, 0.19, 0.32, 0.82),
	"btn_inactive_hover": Color(0.13, 0.24, 0.39, 0.88),
	"btn_inactive_pressed": Color(0.08, 0.16, 0.28, 0.90),
	"btn_inactive_border": Color(0.9098, 0.6275, 0.1255, 0.44),
	"btn_inactive_text": Color(0.7176, 0.7804, 0.8549, 1.0), # #B7C7DA
	# Buttons/chips (selected)
	"btn_selected_bg": Color(0.9098, 0.6275, 0.1255, 0.26),
	"btn_selected_hover": Color(0.9098, 0.6275, 0.1255, 0.34),
	"btn_selected_pressed": Color(0.9098, 0.6275, 0.1255, 0.22),
	"btn_selected_border": Color(0.9098, 0.6275, 0.1255, 0.94),
	"btn_selected_text": Color(0.9176, 0.9529, 1.0, 1.0), # #EAF3FF
	"btn_selected_text_dark": Color(0.12, 0.18, 0.27, 1.0),
	# CTA
	"cta_bg": Color(0.9098, 0.6275, 0.1255, 0.98),
	"cta_hover": Color(0.95, 0.70, 0.20, 0.99),
	"cta_pressed": Color(0.82, 0.54, 0.08, 0.99),
	"cta_border": Color(0.97, 0.86, 0.40, 0.94),
	"cta_text": Color(0.12, 0.18, 0.27, 1.0),
	# Gloss / shadow intensity
	"gloss_alpha": 0.24,
	"gloss_height_ratio": 0.24,
	"gloss_min_h": 10.0,
	"gloss_max_h": 32.0,
	"shadow_panel_alpha": 0.14,
	"shadow_panel_size": 6,
	"shadow_chip_alpha": 0.10,
	"shadow_chip_size": 2,
	"shadow_button_alpha": 0.28,
	"shadow_button_size": 4,
	"shadow_nav_alpha": 0.0,
	"shadow_nav_size": 0,
	"shadow_nav_hover_size": 0,
	"shadow_nav_pressed_size": 0
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

# Theme picker removed — the app uses a single fixed palette. set_theme is
# kept as a no-op so existing callers don't NPE; theme_id is kept for any
# legacy debug logging that might reference it. theme_ids / theme_label
# were only used by the (now-deleted) picker UI.
func set_theme(_theme_id: String) -> void:
	_theme_id = FIXED_THEME_ID

func theme_id() -> String:
	return _theme_id

func colors(high_contrast: bool) -> Dictionary:
	if high_contrast:
		return COLORS_HIGH_CONTRAST
	var d: Dictionary = THEMES.get(FIXED_THEME_ID, THEMES["azure_cascade"])
	return d.get("colors", THEMES["azure_cascade"]["colors"])

func menu_style_contract() -> Dictionary:
	return MENU_STYLE_CONTRACT.duplicate(true)
