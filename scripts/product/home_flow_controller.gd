class_name HomeFlowController
extends RefCounted

const HomeMenuStateScript = preload("res://scripts/ui/home_menu_state.gd")

var state: HomeMenuState


func _init(initial_state: HomeMenuState = null) -> void:
	if initial_state != null:
		state = initial_state
	else:
		state = HomeMenuStateScript.new()


func sync_from_runtime(snapshot: Dictionary) -> void:
	if state == null:
		state = HomeMenuStateScript.new()
	state.home_flow = str(snapshot.get("home_flow", state.home_flow))
	state.selected_mode = int(snapshot.get("selected_mode", state.selected_mode))
	state.ear_settings_screen_active = bool(snapshot.get("ear_settings_screen_active", state.ear_settings_screen_active))
	state.selected_read_module = int(snapshot.get("selected_read_module", state.selected_read_module))
	state.selected_clef = str(snapshot.get("selected_clef", state.selected_clef))
	state.sight_mode = str(snapshot.get("sight_mode", state.sight_mode))
	state.sight_key_signature = str(snapshot.get("sight_key_signature", state.sight_key_signature))
	state.sight_range_min_step = int(snapshot.get("sight_range_min_step", state.sight_range_min_step))
	state.sight_range_max_step = int(snapshot.get("sight_range_max_step", state.sight_range_max_step))
	var sight_notes_any: Variant = snapshot.get("sight_selected_notes_by_clef", state.sight_selected_notes_by_clef)
	if typeof(sight_notes_any) == TYPE_DICTIONARY:
		state.sight_selected_notes_by_clef = (sight_notes_any as Dictionary).duplicate(true)
	state.include_minor_intervals = bool(snapshot.get("include_minor_intervals", state.include_minor_intervals))
	state.use_descending_intervals = bool(snapshot.get("use_descending_intervals", state.use_descending_intervals))
	state.use_harmonic_intervals = bool(snapshot.get("use_harmonic_intervals", state.use_harmonic_intervals))
	state.progression_key = str(snapshot.get("progression_key", state.progression_key))
	var progression_selected_any: Variant = snapshot.get("progression_selected", state.progression_selected)
	if typeof(progression_selected_any) == TYPE_ARRAY:
		state.progression_selected = _string_array_from_variant(progression_selected_any)
	state.progression_broken = bool(snapshot.get("progression_broken", state.progression_broken))
	state.progression_tempo = int(snapshot.get("progression_tempo", state.progression_tempo))
	state.scale_root = str(snapshot.get("scale_root", state.scale_root))
	var scale_modes_any: Variant = snapshot.get("scale_selected_modes", state.scale_selected_modes)
	if typeof(scale_modes_any) == TYPE_ARRAY:
		state.scale_selected_modes = _string_array_from_variant(scale_modes_any)
	state.scale_asc_desc = bool(snapshot.get("scale_asc_desc", state.scale_asc_desc))
	state.scale_tempo = int(snapshot.get("scale_tempo", state.scale_tempo))
	state.pitch_match_key = str(snapshot.get("pitch_match_key", state.pitch_match_key))
	state.pitch_match_scale = str(snapshot.get("pitch_match_scale", state.pitch_match_scale))
	state.cadence_key = str(snapshot.get("cadence_key", state.cadence_key))
	var cadence_selected_any: Variant = snapshot.get("cadence_selected", state.cadence_selected)
	if typeof(cadence_selected_any) == TYPE_ARRAY:
		state.cadence_selected = _string_array_from_variant(cadence_selected_any)
	state.cadence_broken = bool(snapshot.get("cadence_broken", state.cadence_broken))
	state.cadence_tempo = int(snapshot.get("cadence_tempo", state.cadence_tempo))
	state.note_chase_clef_mode = str(snapshot.get("note_chase_clef_mode", state.note_chase_clef_mode))
	var note_chase_selected_any: Variant = snapshot.get("note_chase_selected_notes", state.note_chase_selected_notes)
	if typeof(note_chase_selected_any) == TYPE_ARRAY:
		state.note_chase_selected_notes = _string_array_from_variant(note_chase_selected_any)


func runtime_snapshot() -> Dictionary:
	if state == null:
		state = HomeMenuStateScript.new()
	return {
		"home_flow": state.home_flow,
		"selected_mode": state.selected_mode,
		"ear_settings_screen_active": state.ear_settings_screen_active,
		"selected_read_module": state.selected_read_module,
		"selected_clef": state.selected_clef,
		"sight_mode": state.sight_mode,
		"sight_key_signature": state.sight_key_signature,
		"sight_range_min_step": state.sight_range_min_step,
		"sight_range_max_step": state.sight_range_max_step,
		"sight_selected_notes_by_clef": state.sight_selected_notes_by_clef.duplicate(true),
		"include_minor_intervals": state.include_minor_intervals,
		"use_descending_intervals": state.use_descending_intervals,
		"use_harmonic_intervals": state.use_harmonic_intervals,
		"progression_key": state.progression_key,
		"progression_selected": state.progression_selected.duplicate(),
		"progression_broken": state.progression_broken,
		"progression_tempo": state.progression_tempo,
		"scale_root": state.scale_root,
		"scale_selected_modes": state.scale_selected_modes.duplicate(),
		"scale_asc_desc": state.scale_asc_desc,
		"scale_tempo": state.scale_tempo,
		"pitch_match_key": state.pitch_match_key,
		"pitch_match_scale": state.pitch_match_scale,
		"cadence_key": state.cadence_key,
		"cadence_selected": state.cadence_selected.duplicate(),
		"cadence_broken": state.cadence_broken,
		"cadence_tempo": state.cadence_tempo,
		"note_chase_clef_mode": state.note_chase_clef_mode,
		"note_chase_selected_notes": state.note_chase_selected_notes.duplicate()
	}


func visibility(mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> Dictionary:
	if state == null:
		state = HomeMenuStateScript.new()
	return state.visibility(mode_interval, mode_chord, mode_pitch_match, mode_progression, mode_scale_mode, mode_cadence, mode_sight, mode_note_chase, mode_read)


func on_mode_button_pressed(mode: int, mode_interval: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> void:
	if state == null:
		state = HomeMenuStateScript.new()
	state.on_mode_button_pressed(mode, mode_interval, mode_sight, mode_note_chase, mode_read)


func on_home_hub_pressed(hub_name: String, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> void:
	if state == null:
		state = HomeMenuStateScript.new()
	state.on_home_hub_pressed(hub_name, mode_interval, mode_chord, mode_pitch_match, mode_progression, mode_scale_mode, mode_cadence, mode_sight, mode_note_chase, mode_read)


func on_ear_mode_pressed(mode: int, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int) -> void:
	if state == null:
		state = HomeMenuStateScript.new()
	state.on_ear_mode_pressed(mode, mode_interval, mode_chord, mode_pitch_match, mode_progression, mode_scale_mode, mode_cadence)


func disabled_reason_for_mode(mode: int, mode_interval: int, mode_chord: int, mode_pitch_match: int, mode_progression: int, mode_scale_mode: int, mode_cadence: int, mode_sight: int, mode_note_chase: int, mode_read: int) -> String:
	if state == null:
		state = HomeMenuStateScript.new()
	return state.disabled_reason_for_mode(mode, mode_interval, mode_chord, mode_pitch_match, mode_progression, mode_scale_mode, mode_cadence, mode_sight, mode_note_chase, mode_read)


func _string_array_from_variant(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	var source: Array = value as Array
	for item in source:
		out.append(str(item))
	return out
