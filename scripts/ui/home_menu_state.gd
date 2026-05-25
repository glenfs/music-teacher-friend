class_name HomeMenuState
extends RefCounted

var home_flow := "Practice"
var selected_mode := 0
var ear_settings_screen_active := false
var selected_read_module := 1
var selected_clef := "Treble"
var sight_mode := "Notes"
var sight_key_signature := "C"
var sight_range_min_step := 6
var sight_range_max_step := 12
var sight_selected_notes_by_clef: Dictionary = {
	"Treble": PackedStringArray(),
	"Bass": PackedStringArray()
}
var include_minor_intervals := false
var use_descending_intervals := false
var use_harmonic_intervals := false
var progression_key := "C"
var progression_selected: Array[String] = ["IVviIV", "iiVI"]
var progression_broken := false
var progression_tempo := 90
var scale_root := "C"
var scale_selected_modes: Array[String] = ["Major", "Natural Minor", "Dorian", "Mixolydian"]
var scale_asc_desc := false
var scale_tempo := 90
var pitch_match_key := "C"
var pitch_match_scale := "Major"
var cadence_key := "C"
var cadence_selected: Array[String] = ["Perfect", "Plagal", "Half", "Deceptive"]
var cadence_broken := false
var cadence_tempo := 90
var note_chase_clef_mode := "Treble"
var note_chase_selected_notes: Array[String] = ["C", "E", "G"]

func on_home_hub_pressed(hub_name: String, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> void:
	ear_settings_screen_active = false
	home_flow = hub_name
	if hub_name == "Practice":
		if selected_mode != mode_interval and selected_mode != mode_chord and selected_mode != mode_pitch_match and selected_mode != mode_progression and selected_mode != mode_scale_mode and selected_mode != mode_cadence and selected_mode != mode_sight and selected_mode != mode_note_chase:
			selected_mode = mode_interval
	else:
		selected_mode = mode_read

func on_mode_button_pressed(mode: int, mode_interval: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> void:
	ear_settings_screen_active = false
	if mode == mode_sight:
		selected_mode = mode_sight
	elif mode == mode_note_chase:
		selected_mode = mode_note_chase
	elif mode == mode_read:
		selected_mode = mode_read
	else:
		if selected_mode != mode_interval:
			selected_mode = mode_interval

func on_ear_mode_pressed(mode: int, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int) -> void:
	if mode != mode_interval and mode != mode_chord and mode != mode_pitch_match and mode != mode_progression and mode != mode_scale_mode and mode != mode_cadence:
		return
	ear_settings_screen_active = false
	selected_mode = mode

func visibility(mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> Dictionary:
	var is_ear := selected_mode == mode_interval or selected_mode == mode_chord or selected_mode == mode_pitch_match or selected_mode == mode_progression or selected_mode == mode_scale_mode or selected_mode == mode_cadence
	var practice_flow := home_flow == "Practice"
	var learn_flow := home_flow == "Learn"
	# Ear "More Settings" now lives as an inline sub-panel and should not hide the page.
	var show_ear_settings_screen := false
	var show_home_main := true
	return {
		"show_home_main": show_home_main,
		"show_ear_settings_screen": show_ear_settings_screen,
		"practice_flow": practice_flow,
		"learn_flow": learn_flow,
		"is_ear": is_ear,
		"show_interval": practice_flow and is_ear and selected_mode == mode_interval and show_home_main,
		"show_chord": practice_flow and is_ear and selected_mode == mode_chord and show_home_main,
		"show_pitch_match": practice_flow and is_ear and selected_mode == mode_pitch_match and show_home_main,
		"show_progression": practice_flow and is_ear and selected_mode == mode_progression and show_home_main,
		"show_scale_mode": practice_flow and is_ear and selected_mode == mode_scale_mode and show_home_main,
		"show_cadence": practice_flow and is_ear and selected_mode == mode_cadence and show_home_main,
		# Keep Sight section visible when Note Chase is selected from within Sight Reader.
		"show_sight": practice_flow and (selected_mode == mode_sight or selected_mode == mode_note_chase) and show_home_main,
		"show_chase": practice_flow and selected_mode == mode_note_chase and show_home_main,
		"show_read": learn_flow and selected_mode == mode_read and show_home_main
	}

func disabled_reason_for_mode(mode: int, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> String:
	if home_flow == "Learn":
		if mode != mode_read:
			return "Learn mode only supports Read Notation modules."
		return ""
	if mode == mode_read:
		return "Read Notation modules are in Learn mode."
	if mode == mode_chord and selected_mode == mode_interval:
		return "Choose Ear > Chord for chord-family practice."
	if mode == mode_interval and selected_mode == mode_chord:
		return "Choose Ear > Interval for interval training."
	if mode == mode_pitch_match and selected_mode == mode_interval:
		return "Choose Ear > Pitch Match for pitch matching."
	if mode == mode_progression and selected_mode == mode_interval:
		return "Choose Ear > Progression for progression training."
	if mode == mode_scale_mode and selected_mode == mode_interval:
		return "Choose Ear > Scale/Mode for scale-mode training."
	if mode == mode_cadence and selected_mode == mode_interval:
		return "Choose Ear > Cadence for cadence training."
	if mode == mode_sight and sight_mode == "Placement":
		return "Placement drills are available inside Sight Reader mode."
	if mode == mode_note_chase and note_chase_selected_notes.is_empty():
		return "Pick at least one target note to start Note Chase."
	return ""
