extends RefCounted

const PhoneProfileScript = preload("res://scripts/ui/device_profiles/phone_profile.gd")
const TabletProfileScript = preload("res://scripts/ui/device_profiles/tablet_profile.gd")
const DesktopProfileScript = preload("res://scripts/ui/device_profiles/desktop_profile.gd")

var _phone := PhoneProfileScript.new()
var _tablet := TabletProfileScript.new()
var _desktop := DesktopProfileScript.new()

func resolve_for_viewport(vp: Vector2) -> Dictionary:
	# Web: desktop browsers frequently report touch as available, which would
	# wrongly select the oversized touch (tablet/phone) profile. The web build is
	# a desktop-browser experience for now, so always use the desktop profile.
	# (Proper mobile-web sizing by real canvas size is a later refinement.)
	if OS.has_feature("web"):
		return _desktop.build_profile(vp)
	var is_touch := DisplayServer.is_touchscreen_available()
	var shortest := minf(vp.x, vp.y)
	var longest := maxf(vp.x, vp.y)
	if is_touch and (longest >= 960.0 or shortest >= 700.0):
		return _tablet.build_profile(vp)
	if is_touch:
		return _phone.build_profile(vp)
	return _desktop.build_profile(vp)
