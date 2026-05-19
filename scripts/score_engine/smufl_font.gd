extends RefCounted
class_name SMuFLFont

# SMuFL (Standard Music Font Layout) glyph wrapper.
#
# Loads Bravura.otf (or any SMuFL-compatible font) and exposes its glyphs by
# semantic name ("noteheadBlack", "gClef", etc.). When Bravura is not present,
# falls back to common Unicode music symbols so the app degrades gracefully.
#
# Bravura is a free, open-source SMuFL reference font from Steinberg. Download:
#   https://github.com/steinbergmedia/bravura/raw/master/redist/otf/Bravura.otf
# Place at: res://assets/fonts/Bravura.otf
#
# All codepoints below come from the official SMuFL spec:
#   https://www.smufl.org/version/latest/

# Available SMuFL fonts the user can pick from. All three share the same SMuFL
# codepoint table (sect. 3 above), so switching between them is purely a visual
# style change — no glyph remapping needed.
const FONT_REGISTRY := {
	"Bravura": "res://assets/fonts/Bravura.otf",
	"Leland":  "res://assets/fonts/Leland.otf",
	"Petaluma": "res://assets/fonts/Petaluma.otf",
}
const DEFAULT_FONT_NAME := "Bravura"
const FONT_PATH := "res://assets/fonts/Bravura.otf"  # legacy alias used elsewhere; resolved through FONT_REGISTRY now

# Standard SMuFL codepoints (Private Use Area E000-F8FF).
# Stored as integers and resolved to char(...) at runtime.
const CODEPOINTS := {
	# Clefs
	"gClef": 0xE050,
	"fClef": 0xE062,
	"cClef": 0xE05C,
	# Noteheads
	"noteheadBlack": 0xE0A4,
	"noteheadHalf": 0xE0A3,
	"noteheadWhole": 0xE0A2,
	"noteheadDoubleWhole": 0xE0A0,
	# Accidentals
	"accidentalSharp": 0xE262,
	"accidentalFlat": 0xE260,
	"accidentalNatural": 0xE261,
	"accidentalDoubleSharp": 0xE263,
	"accidentalDoubleFlat": 0xE264,
	# Time signature digits
	"timeSig0": 0xE080,
	"timeSig1": 0xE081,
	"timeSig2": 0xE082,
	"timeSig3": 0xE083,
	"timeSig4": 0xE084,
	"timeSig5": 0xE085,
	"timeSig6": 0xE086,
	"timeSig7": 0xE087,
	"timeSig8": 0xE088,
	"timeSig9": 0xE089,
	"timeSigCommon": 0xE08A,
	"timeSigCutCommon": 0xE08B,
	# Rests
	"restWhole": 0xE4E3,
	"restHalf": 0xE4E4,
	"restQuarter": 0xE4E5,
	"rest8th": 0xE4E6,
	"rest16th": 0xE4E7,
	# Flags (single-stem flags for unbeamed notes)
	"flag8thUp": 0xE240,
	"flag8thDown": 0xE241,
	"flag16thUp": 0xE242,
	"flag16thDown": 0xE243,
	# Augmentation dot
	"augmentationDot": 0xE1E7,
	# Brace and brackets (for grand staff and group brackets)
	"brace": 0xE000,
	"bracket": 0xE002,
	# Dynamics
	"dynamicPiano": 0xE520,
	"dynamicMezzo": 0xE521,
	"dynamicForte": 0xE522,
	"dynamicPianissimo": 0xE52B,
	"dynamicFortissimo": 0xE52F,
}

# Fallback Unicode codepoints for environments without Bravura. These render
# from a generic system font and look much rougher, but at least the app shows
# something useful before the user installs the real font.
const FALLBACK_CODEPOINTS := {
	"gClef": 0x1D11E,           # 𝄞
	"fClef": 0x1D122,           # 𝄢
	"cClef": 0x1D121,           # 𝄡
	"noteheadBlack": 0x25CF,    # ●
	"noteheadHalf": 0x25CB,     # ○
	"noteheadWhole": 0x25CB,    # ○
	"accidentalSharp": 0x266F,  # ♯
	"accidentalFlat": 0x266D,   # ♭
	"accidentalNatural": 0x266E, # ♮
	"timeSig0": 0x0030,
	"timeSig1": 0x0031,
	"timeSig2": 0x0032,
	"timeSig3": 0x0033,
	"timeSig4": 0x0034,
	"timeSig5": 0x0035,
	"timeSig6": 0x0036,
	"timeSig7": 0x0037,
	"timeSig8": 0x0038,
	"timeSig9": 0x0039,
	"restWhole": 0x1D13B,       # 𝄻
	"restHalf": 0x1D13C,        # 𝄼
	"restQuarter": 0x1D13D,     # 𝄽
	"rest8th": 0x1D13E,         # 𝄾
	"flag8thUp": 0x266A,        # ♪ (rough fallback)
	"flag8thDown": 0x266A,
}

# Active font state (the user-selected font). Defaults to Bravura.
# When set_active_font is called, the next get_font() call reloads.
static var _active_font_name: String = DEFAULT_FONT_NAME
static var _font: Font = null
static var _font_loaded_for_name: String = ""
static var _smufl_font_available: bool = false
# Listeners notified when the active font changes — usually StaffRenderer instances
# that need to invalidate their cached metrics and queue a redraw.
static var _change_listeners: Array[Callable] = []


static func set_active_font(name: String) -> void:
	# Switch to a different SMuFL font. Triggers all registered listeners.
	if not FONT_REGISTRY.has(name):
		return
	if name == _active_font_name and _font_loaded_for_name == name:
		return
	_active_font_name = name
	_font = null
	_font_loaded_for_name = ""
	_smufl_font_available = false
	# Notify any renderers so they can queue_redraw with the new glyphs.
	for cb in _change_listeners:
		if cb.is_valid():
			cb.call()


static func get_active_font_name() -> String:
	return _active_font_name


static func register_change_listener(cb: Callable) -> void:
	if not _change_listeners.has(cb):
		_change_listeners.append(cb)


static func unregister_change_listener(cb: Callable) -> void:
	_change_listeners.erase(cb)


static func get_font() -> Font:
	if _font_loaded_for_name == _active_font_name and _font != null:
		return _font
	var path: String = FONT_REGISTRY.get(_active_font_name, FONT_REGISTRY[DEFAULT_FONT_NAME])
	if ResourceLoader.exists(path):
		var res := ResourceLoader.load(path)
		if res is Font:
			_font = res as Font
			_font_loaded_for_name = _active_font_name
			_smufl_font_available = true
			return _font
	# Fallback: the system font renders the Unicode music symbols (rougher).
	_font = ThemeDB.fallback_font
	_font_loaded_for_name = _active_font_name
	_smufl_font_available = false
	return _font


static func bravura_present() -> bool:
	# Kept for backwards compat; really means "any SMuFL font is loaded".
	get_font()
	return _smufl_font_available


static func smufl_font_loaded() -> bool:
	get_font()
	return _smufl_font_available


static func glyph(name: String) -> String:
	# Returns a string containing the glyph for the given SMuFL name.
	# Uses the SMuFL codepoint when an SMuFL font is loaded; falls back to a
	# Unicode music symbol otherwise. Returns empty string if no mapping exists.
	get_font()
	if _smufl_font_available and CODEPOINTS.has(name):
		return char(int(CODEPOINTS[name]))
	if FALLBACK_CODEPOINTS.has(name):
		return char(int(FALLBACK_CODEPOINTS[name]))
	if CODEPOINTS.has(name):
		return char(int(CODEPOINTS[name]))
	return ""


static func time_sig_glyphs(value: int) -> String:
	# Renders a multi-digit time-signature number as a string of SMuFL digit glyphs.
	var s := str(maxi(0, int(value)))
	var out := ""
	for i in range(s.length()):
		var d := s[i]
		var key := "timeSig%s" % d
		out += glyph(key)
	return out


static func notehead_for_duration(duration_beats: float) -> String:
	# Pick the right notehead glyph for a given duration (in quarter-note beats).
	if duration_beats >= 4.0:
		return glyph("noteheadWhole")
	if duration_beats >= 2.0:
		return glyph("noteheadHalf")
	return glyph("noteheadBlack")


static func rest_for_duration(duration_beats: float) -> String:
	if duration_beats >= 4.0:
		return glyph("restWhole")
	if duration_beats >= 2.0:
		return glyph("restHalf")
	if duration_beats >= 1.0:
		return glyph("restQuarter")
	if duration_beats >= 0.5:
		return glyph("rest8th")
	return glyph("rest16th")
