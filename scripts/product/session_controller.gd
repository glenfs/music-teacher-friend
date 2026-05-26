class_name SessionController
extends RefCounted


func current_post_answer_delay(qa_enabled: bool, slow_enabled: bool) -> float:
	if qa_enabled:
		return 0.05
	return 1.25 if slow_enabled else 0.85


func validate_start(
	host,
	mode_interval: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	mode_note_chase: int,
	build_interval_pool: Callable,
	selected_progression_ids: Callable,
	selected_scale_mode_ids: Callable,
	selected_cadence_ids: Callable
) -> Dictionary:
	if host._selected_mode == mode_interval:
		host._active_intervals = build_interval_pool.call() if build_interval_pool.is_valid() else []
		if host._active_intervals.size() < host._ear_choice_count:
			return {"ok": false, "message": "Need at least %d interval options." % host._ear_choice_count}
	elif host._selected_mode == mode_progression:
		var progression_ids: Array = selected_progression_ids.call() if selected_progression_ids.is_valid() else []
		if progression_ids.size() < 2:
			return {"ok": false, "message": "Pick at least 2 progression patterns."}
	elif host._selected_mode == mode_scale_mode:
		var scale_mode_ids: Array = selected_scale_mode_ids.call() if selected_scale_mode_ids.is_valid() else []
		if scale_mode_ids.size() < 2:
			return {"ok": false, "message": "Pick at least 2 scale/mode options."}
	elif host._selected_mode == mode_cadence:
		var cadence_ids: Array = selected_cadence_ids.call() if selected_cadence_ids.is_valid() else []
		if cadence_ids.size() < 2:
			return {"ok": false, "message": "Pick at least 2 cadence types."}
	elif host._selected_mode == mode_note_chase:
		if host._note_chase_selected_notes.is_empty():
			return {"ok": false, "message": "Pick at least one target note for Note Chase."}
	else:
		host._active_intervals.clear()
	return {"ok": true, "message": ""}


func apply_continuous_start_state(host) -> void:
	host._score = 0
	host._question_index = 0
	host._total_questions = 0
	host._lives = 5
	host._streak = 0
	host._xp = 0
	host._quiz_active = true
	host._accepting_answer = true
	host._awaiting_round_start = false


func apply_standard_start_state(host, mode_sight: int, mode_note_chase: int) -> void:
	host._grand_staff_active = host._selected_mode == mode_sight and host._sight_mode == "Chords" and host._selected_clef == "Grand Staff"
	if host._selected_mode == mode_sight and host._sight_question_spin != null:
		host._total_questions = int(host._sight_question_spin.value)
	else:
		host._total_questions = int(host._question_spin.value)
	host._score = 0
	host._question_index = 0
	host._lives = 5 if (host._selected_mode == mode_note_chase or host._is_continuous_flow_sight_mode()) else 3
	host._streak = 0
	host._chicken_combo_charge = 0
	host._chicken_combo_shields = 0
	host._xp = 0
	host._last_interval_signature = ""
	host._last_chord_signature = ""
	host._last_pitch_match_signature = ""
	host._last_sight_signature = ""
	host._quiz_start_time = Time.get_ticks_msec() / 1000.0
	host._quiz_active = true
	host._accepting_answer = false


func apply_end_state(host) -> void:
	host._grand_staff_active = false
	host._continuous_sight_active = false
	host._continuous_sight_waiting_start = false
	host._in_tutorial = false
	host._quiz_active = false
	host._accepting_answer = false
	host._awaiting_round_start = false
	if host._note_chase_runtime != null:
		host._note_chase_runtime.running = false
		host._note_chase_runtime.fever_active = false
		host._note_chase_runtime.boss_active = false


func apply_restart_state(host, mode_note_chase: int) -> void:
	host._quiz_active = false
	host._accepting_answer = false
	host._awaiting_round_start = false
	if host._note_chase_runtime != null:
		host._note_chase_runtime.running = false
		host._note_chase_runtime.fever_active = false
		host._note_chase_runtime.boss_active = false
	host._score = 0
	host._question_index = 0
	host._lives = 5 if (host._selected_mode == mode_note_chase or host._is_continuous_flow_sight_mode()) else 3
	host._streak = 0
	host._chicken_combo_charge = 0
	host._chicken_combo_shields = 0
	host._xp = 0
	host._last_interval_signature = ""
	host._last_chord_signature = ""
	host._last_pitch_match_signature = ""
	host._last_sight_signature = ""
	host._quiz_active = true


func _host_validate_start(host) -> Dictionary:
	return validate_start(
		host,
		host.MODE_INTERVAL,
		host.MODE_PROGRESSION,
		host.MODE_SCALE_MODE,
		host.MODE_CADENCE,
		host.MODE_NOTE_CHASE,
		Callable(host, "_build_interval_pool_for_settings"),
		Callable(host, "_selected_progression_ids"),
		Callable(host, "_selected_scale_mode_ids"),
		Callable(host, "_selected_cadence_ids")
	)


func _host_init_session_stats(host) -> void:
	init_session_stats(
		host,
		host.MODE_INTERVAL,
		host.MODE_CHORD,
		host.MODE_PITCH_MATCH,
		host.MODE_PROGRESSION,
		host.MODE_SCALE_MODE,
		host.MODE_CADENCE,
		host.CHORD_INTERVALS,
		Callable(host, "_selected_ear_mode_choices"),
		Callable(host, "_sight_include_accidental_variants"),
		Callable(host, "_sight_chord_candidates")
	)


func _host_reuse_current_rhythm(host) -> bool:
	return host._is_rhythm_flow_mode() and (not host._rhythm_flow_patterns.is_empty() or not host._rhythm_flow_generated_bars.is_empty())


func _enter_pre_round_gate(host) -> bool:
	if host._first_run_assessment_active:
		return false
	if not (host._is_ear_training_mode() or host._selected_mode == host.MODE_SIGHT or host._selected_mode == host.MODE_NOTE_CHASE):
		return false
	host._awaiting_round_start = true
	if host._round_start_button != null:
		host._round_start_button.visible = host._selected_mode == host.MODE_SIGHT
		host._round_start_button.disabled = false
	host._apply_answer_mode()
	host._reset_game_hud_for_pre_round()
	host._replay_button.disabled = true
	if host._selected_mode == host.MODE_NOTE_CHASE:
		host._status_label.text = ""
	else:
		host._status_label.text = "Tap Start Round when you're ready."
	return true


func _show_first_run_intro(host) -> void:
	if host._qa_enabled:
		return
	if host._selected_mode in [host.MODE_INTERVAL, host.MODE_CHORD] and not host._ear_intro_seen:
		if host._ear_intro_overlay != null and host._ear_intro_dismiss != null:
			host._set_ear_intro_text_for_mode()
			host._ear_intro_overlay.visible = true
			await host._ear_intro_dismiss.pressed
			host._ear_intro_overlay.visible = false
			host._ear_intro_seen = true
			host._save_ear_settings()
	elif host._selected_mode == host.MODE_NOTE_CHASE and not host._note_chase_intro_seen:
		if host._note_chase_intro_overlay != null and host._note_chase_intro_dismiss != null:
			host._note_chase_intro_overlay.visible = true
			await host._note_chase_intro_dismiss.pressed
			host._note_chase_intro_overlay.visible = false
			host._note_chase_intro_seen = true
			host._save_ear_settings()
	elif host._selected_mode == host.MODE_CADENCE and not host._cadence_intro_seen:
		if host._cadence_intro_overlay != null and host._cadence_intro_dismiss != null:
			host._cadence_intro_overlay.visible = true
			await host._cadence_intro_dismiss.pressed
			host._cadence_intro_overlay.visible = false
			host._cadence_intro_seen = true
			host._save_ear_settings()


func start_quiz_from_home(host) -> void:
	host._clear_gameplay_transient_visuals()
	host._awaiting_round_start = false
	if host._round_start_button != null:
		host._round_start_button.visible = false
		host._round_start_button.disabled = true
	if host._selected_mode == host.MODE_READ:
		host._home_info_label.text = ""
		host._show_game()
		await host._start_read_module()
		return
	if host._is_continuous_flow_sight_mode():
		host._home_info_label.text = ""
		host._bump_quiz_run_token()
		apply_continuous_start_state(host)
		host._show_game()
		host._start_continuous_sight_reading(false, _host_reuse_current_rhythm(host))
		host._start_chicken_turn_hint_cycle()
		return
	var validation: Dictionary = _host_validate_start(host)
	if not bool(validation.get("ok", false)):
		host._home_info_label.text = str(validation.get("message", ""))
		return
	host._home_info_label.text = ""
	host._bump_quiz_run_token()
	apply_standard_start_state(host, host.MODE_SIGHT, host.MODE_NOTE_CHASE)
	if host._is_new_theory_mode() and host._advanced_session != null:
		host._advanced_session.start(host._total_questions)
	host._apply_answer_mode()
	_host_init_session_stats(host)
	host._refresh_meta_ui()
	host._result_box_hide()
	host._show_game()
	await _show_first_run_intro(host)
	if _enter_pre_round_gate(host):
		return
	await begin_next_question(host, host._quiz_run_token)


func restart_quiz(host) -> void:
	host._clear_gameplay_transient_visuals()
	host._set_sight_result_background_hidden(false)
	host._bump_quiz_run_token()
	host._invalidate_audio_sequence_schedule()
	if host._selected_mode == host.MODE_READ:
		await host._start_read_module()
		return
	apply_restart_state(host, host.MODE_NOTE_CHASE)
	host._cancel_chicken_turn_hint_cycle(true)
	host._stop_note_chase_music()
	host._set_note_chase_overlay("", false)
	host._clear_note_chase_visual_notes()
	host._set_note_chase_staff_scrolling(false)
	host._set_answer_buttons_enabled(false)
	if host._round_start_button != null:
		host._round_start_button.visible = false
		host._round_start_button.disabled = true
	host._replay_button.disabled = true
	host._status_label.text = "Restarting..."
	_host_init_session_stats(host)
	host._refresh_meta_ui()
	host._result_box_hide()
	if host._is_continuous_flow_sight_mode():
		host._accepting_answer = true
		host._awaiting_round_start = false
		host._show_game()
		host._start_continuous_sight_reading(false, _host_reuse_current_rhythm(host))
		host._start_chicken_turn_hint_cycle()
		return
	if _enter_pre_round_gate(host):
		return
	await begin_next_question(host, host._quiz_run_token)


func handle_round_start_pressed(host) -> void:
	if not host._quiz_active or host._is_prompt_playing or not host._awaiting_round_start:
		return
	host._awaiting_round_start = false
	host._set_note_chase_overlay("", false)
	if host._round_start_button != null:
		host._round_start_button.visible = false
		host._round_start_button.disabled = true
	if host._selected_mode == host.MODE_NOTE_CHASE:
		await host._start_note_chase_round()
		return
	await begin_next_question(host, host._quiz_run_token)


func advance_after_answer(host, quiz_token: int, asked_count: int = -1) -> void:
	var final_asked_count: int = asked_count if asked_count >= 0 else host._question_index
	if host._lives <= 0:
		await handle_game_over(host, final_asked_count, host.MODE_SIGHT)
		return
	var slow_enabled: bool = host._slow_toggle != null and host._slow_toggle.button_pressed
	await host.get_tree().create_timer(current_post_answer_delay(host._qa_enabled, slow_enabled)).timeout
	if host._should_advance_after_delay(quiz_token):
		await begin_next_question(host, quiz_token)


func begin_next_question(host, expected_token: int = -1) -> void:
	if expected_token != -1 and expected_token != host._quiz_run_token:
		return
	if not host._quiz_active:
		return
	if host._awaiting_round_start:
		return
	if host._question_index >= host._total_questions:
		await finish_quiz(host, host.MODE_SIGHT)
		return
	host._question_index += 1
	host._score_label.text = "Correct: %d / %d" % [host._score, host._question_index - 1]
	if not host._is_ear_training_mode():
		host._progress_label.text = progress_dots_text(host._question_index, host._total_questions)
	host._status_label.text = "Listen..."
	host._refresh_meta_ui()
	if host._is_sight_notes_chords_game_mode() or host._is_ear_training_mode():
		host._refresh_sight_question_progress_ui(true)
	host._set_answer_buttons_enabled(false)
	host._accepting_answer = false
	host._replay_button.disabled = true
	host._restart_button.disabled = true
	if host._compare_bar != null:
		host._compare_bar.visible = false
	if host._cadence_roman_label != null:
		host._cadence_roman_label.visible = false
	host._reset_bird_position()
	if host._selected_mode == host.MODE_CHORD:
		host._current_available_chord_types = host._get_available_chord_types()
		host._current_chord_choices.clear()
	elif host._selected_mode == host.MODE_SIGHT:
		host._current_available_chord_types.clear()
		host._current_chord_choices.clear()
	else:
		host._current_available_chord_types.clear()
		host._current_chord_choices.clear()
	host._apply_answer_mode()
	host._generate_round()
	host._start_chicken_turn_hint_cycle()
	host._apply_answer_mode()
	if expected_token != -1 and expected_token != host._quiz_run_token:
		return
	await host._play_new_question_cue()
	if expected_token != -1 and expected_token != host._quiz_run_token:
		return
	record_question_asked(
		host,
		host.MODE_INTERVAL,
		host.MODE_CHORD,
		host.MODE_PITCH_MATCH,
		host.MODE_PROGRESSION,
		host.MODE_SCALE_MODE,
		host.MODE_CADENCE
	)
	var prompt_question_index: int = int(host._question_index)
	var allow_answer_during_prompt: bool = host._selected_mode == host.MODE_SCALE_MODE or host._selected_mode == host.MODE_INTERVAL
	if allow_answer_during_prompt:
		host._status_label.text = "Sing the highlighted melody." if host.has_method("_is_sight_singing_mode") and host._is_sight_singing_mode() else "Pick the correct nest."
		host._set_answer_buttons_enabled(true)
		host._accepting_answer = true
		host._start_chicken_turn_hint_cycle()
		host._replay_button.disabled = true
		host._restart_button.disabled = false
	host._is_prompt_playing = true
	await host._play_current_prompt()
	host._is_prompt_playing = false
	if expected_token != -1 and expected_token != host._quiz_run_token:
		return
	if host._question_index != prompt_question_index:
		return
	if not host._quiz_active:
		return
	if not allow_answer_during_prompt:
		host._status_label.text = "Sing the highlighted melody." if host.has_method("_is_sight_singing_mode") and host._is_sight_singing_mode() else "Pick the correct nest."
		host._set_answer_buttons_enabled(true)
		host._accepting_answer = true
		host._start_chicken_turn_hint_cycle()
	host._replay_button.disabled = false
	host._restart_button.disabled = false


func finish_quiz(host, mode_sight: int) -> void:
	host._quiz_active = false
	host._accepting_answer = false
	host._cancel_chicken_turn_hint_cycle(true)
	host._set_answer_buttons_enabled(false)
	host._replay_button.disabled = true
	host._restart_button.disabled = false
	host._status_label.text = ""
	var result_text := final_quiz_result_text(
		host,
		host._score,
		host._total_questions,
		host._xp,
		host.MODE_INTERVAL,
		host.MODE_CHORD,
		host.MODE_PITCH_MATCH,
		host.MODE_PROGRESSION,
		host.MODE_SCALE_MODE,
		host.MODE_CADENCE,
		mode_sight,
		host.MODE_NOTE_CHASE,
		Callable(host, "_interval_display_name")
	)
	host._progress_label.text = result_text
	if host._sight_progress_track != null:
		host._sight_progress_track.visible = false
		host._set_sight_progress_ratio(0.0, false)
	host._teacher_record_session_metrics(host._selected_mode, host._score, host._total_questions)
	host._home_info_label.text = ""
	if host._selected_mode == mode_sight:
		host._set_sight_result_background_hidden(true)
	host._update_daily_streak(true)
	host._merge_session_into_lifetime()
	host._save_progress_data()
	host._result_box_show("Complete", result_text)
	await host._play_win_fanfare_sfx()
	var score_pct := (float(host._score) / float(maxi(1, host._total_questions))) * 100.0
	host._play_completion_reaction(score_pct)


func handle_game_over(
	host,
	asked_count: int,
	mode_sight: int,
	result_title: String = "Keep Practicing!",
	result_message: String = "Every miss is a lesson. Try again!"
) -> void:
	host._quiz_active = false
	host._accepting_answer = false
	if host._compare_bar != null:
		host._compare_bar.visible = false
	await host._fly_bird_away_sad()
	host._set_answer_buttons_enabled(false)
	host._replay_button.disabled = true
	host._restart_button.disabled = false
	host._status_label.text = ""
	host._progress_label.text = final_quiz_result_text(
		host,
		host._score,
		asked_count,
		host._xp,
		host.MODE_INTERVAL,
		host.MODE_CHORD,
		host.MODE_PITCH_MATCH,
		host.MODE_PROGRESSION,
		host.MODE_SCALE_MODE,
		host.MODE_CADENCE,
		mode_sight,
		host.MODE_NOTE_CHASE,
		Callable(host, "_interval_display_name")
	)
	if host._sight_progress_track != null:
		host._sight_progress_track.visible = false
		host._set_sight_progress_ratio(0.0, false)
	host._teacher_record_session_metrics(host._selected_mode, host._score, asked_count)
	host._home_info_label.text = ""
	await host._play_gameover_fail_sfx()
	if host._selected_mode == mode_sight:
		host._set_sight_result_background_hidden(true)
	host._merge_session_into_lifetime()
	host._save_progress_data()
	host._result_box_show(result_title, result_message)


func finish_continuous_sight_reading(host, result_title: String = "Complete") -> void:
	var was_rhythm_demo: bool = host._is_rhythm_flow_mode() and host._rhythm_flow_session_mode == host.RHYTHM_FLOW_SESSION_DEMO
	host._continuous_sight_active = false
	host._continuous_sight_waiting_start = false
	host._quiz_active = false
	host._accepting_answer = false
	host._rhythm_flow_paused = false
	host._set_answer_buttons_enabled(false)
	host._refresh_rhythm_flow_play_pause_button()
	if host._continuous_sight_play_line != null:
		host._continuous_sight_play_line.visible = false
	host._set_rhythm_triplet_guides_visible(false)
	host._rhythm_triplet_guide_last_tick_idx = -1
	host._rhythm_triplet_guide_flash_dot = -1
	host._rhythm_triplet_guide_flash_until_sec = -1.0
	var acc := int(round((float(host._continuous_sight_correct_hits) / float(maxi(1, host._continuous_sight_total_hits))) * 100.0))
	var avg_rt_ms := 0.0
	if host._continuous_sight_reaction_count > 0:
		avg_rt_ms = (host._continuous_sight_reaction_sum / float(host._continuous_sight_reaction_count)) * 1000.0
	var summary := ""
	if host._is_rhythm_flow_mode():
		if was_rhythm_demo:
			summary = "Listening and learning run finished | BPM %d\nScoring was paused." % [host._rhythm_flow_bpm]
		else:
			var perfect_pct := int(round((float(host._continuous_sight_perfect_hits) / float(maxi(1, host._continuous_sight_total_hits))) * 100.0))
			summary = "Rhythm Flow | BPM %d | Score %d | Accuracy %d%% | Perfect %d%%\nPerfect %d  Good %d  OK %d  Miss %d | Longest Streak %d" % [host._rhythm_flow_bpm, host._score, acc, perfect_pct, host._continuous_sight_perfect_hits, host._continuous_sight_good_hits, host._rhythm_flow_ok_hits, host._continuous_sight_miss_hits, host._continuous_sight_best_combo]
	else:
		summary = "Level %d | Score %d | Accuracy %d%% | Avg RT %.0fms\nPerfect %d  Good %d  Miss %d | Best Combo %d" % [host._continuous_sight_level, host._score, acc, avg_rt_ms, host._continuous_sight_perfect_hits, host._continuous_sight_good_hits, host._continuous_sight_miss_hits, host._continuous_sight_best_combo]
		var problem_summary: String = host._continuous_problem_area_summary()
		if not problem_summary.is_empty():
			summary += "\n" + problem_summary
	host._progress_label.text = "Session Ended"
	host._status_label.text = summary
	host._home_info_label.text = ""
	if not was_rhythm_demo:
		host._update_daily_streak(true)
	if was_rhythm_demo:
		var demo_title := "Listening and Learning Complete"
		if result_title == "Demo Stopped":
			demo_title = "Listening and Learning Stopped"
		host._result_box_show(demo_title, summary)
		if OS.is_debug_build():
			print("Rhythm Flow listening/learning run finished")
	else:
		host._result_box_show(result_title, summary)
	if host._is_rhythm_flow_mode() and host._result_action_row != null:
		host._result_action_row.visible = true
		if host._result_action_primary_button != null:
			host._result_action_primary_button.text = "Restart Rhythm"
			host._result_action_primary_button.disabled = false
		if host._result_action_secondary_button != null:
			host._result_action_secondary_button.text = "Back"
			host._result_action_secondary_button.disabled = false
	host._clear_continuous_sight_notes()
	host._hide_continuous_visual_aids()
	host._set_continuous_rest_symbol_visible(false)
	host._rhythm_flow_session_mode = host.RHYTHM_FLOW_SESSION_PLAYING
	host._rhythm_flow_scoring_enabled = true
	host._rhythm_flow_input_enabled = true
	host._rhythm_is_practice = was_rhythm_demo
	host._rhythm_flow_demo_next_event_idx = 0
	host._refresh_rhythm_flow_demo_buttons()
	if was_rhythm_demo:
		host._rhythm_flow_paused = true
		host._refresh_rhythm_flow_practice_scrub_overlay()


func init_session_stats(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	chord_intervals: Dictionary,
	selected_ear_mode_choices: Callable,
	sight_include_accidental_variants: Callable,
	sight_chord_candidates: Callable
) -> void:
	host._interval_stats_asked.clear()
	host._interval_stats_correct.clear()
	host._chord_stats_asked.clear()
	host._chord_stats_correct.clear()
	host._sight_stats_asked.clear()
	host._sight_stats_correct.clear()
	if host._selected_mode == mode_interval:
		for interval in host._active_intervals:
			host._interval_stats_asked[interval] = 0
			host._interval_stats_correct[interval] = 0
	elif host._selected_mode == mode_chord or host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		var keys: Array = chord_intervals.keys()
		if host._selected_mode == mode_chord:
			keys.sort()
			for key in keys:
				host._chord_stats_asked[key] = 0
				host._chord_stats_correct[key] = 0
		else:
			var ear_choices: Array = selected_ear_mode_choices.call() if selected_ear_mode_choices.is_valid() else []
			for choice_name in ear_choices:
				host._chord_stats_asked[choice_name] = 0
				host._chord_stats_correct[choice_name] = 0
	else:
		if host._sight_mode == "Chords":
			var include_acc: bool = bool(sight_include_accidental_variants.call()) if sight_include_accidental_variants.is_valid() else false
			var triads: Array = sight_chord_candidates.call(include_acc) if sight_chord_candidates.is_valid() else []
			for triad_any in triads:
				if typeof(triad_any) != TYPE_DICTIONARY:
					continue
				var triad: Dictionary = triad_any as Dictionary
				var chord_name: String = str(triad.get("name", ""))
				if chord_name == "":
					continue
				host._sight_stats_asked[chord_name] = 0
				host._sight_stats_correct[chord_name] = 0
		else:
			for note_name in ["C", "D", "E", "F", "G", "A", "B"]:
				host._sight_stats_asked[note_name] = 0
				host._sight_stats_correct[note_name] = 0


func record_question_asked(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int
) -> void:
	if host._selected_mode == mode_interval:
		host._interval_stats_asked[host._current_interval_id] = int(host._interval_stats_asked.get(host._current_interval_id, 0)) + 1
	elif host._selected_mode == mode_chord or host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		var ear_key: String = host._current_chord_quality if host._selected_mode == mode_chord else host._current_ear_text_answer
		host._chord_stats_asked[ear_key] = int(host._chord_stats_asked.get(ear_key, 0)) + 1
	else:
		var sight_key: String = host._current_sight_chord_name if host._sight_mode == "Chords" else host._current_sight_note
		host._sight_stats_asked[sight_key] = int(host._sight_stats_asked.get(sight_key, 0)) + 1


func record_question_correct(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int
) -> void:
	if host._selected_mode == mode_interval:
		host._interval_stats_correct[host._current_interval_id] = int(host._interval_stats_correct.get(host._current_interval_id, 0)) + 1
	elif host._selected_mode == mode_chord or host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		var ear_key: String = host._current_chord_quality if host._selected_mode == mode_chord else host._current_ear_text_answer
		host._chord_stats_correct[ear_key] = int(host._chord_stats_correct.get(ear_key, 0)) + 1
	else:
		var sight_key: String = host._current_sight_chord_name if host._sight_mode == "Chords" else host._current_sight_note
		host._sight_stats_correct[sight_key] = int(host._sight_stats_correct.get(sight_key, 0)) + 1


func session_performance_summary(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	mode_sight: int,
	interval_display_name: Callable
) -> String:
	var parts: Array[String] = []
	if host._selected_mode == mode_interval:
		var interval_keys: Array = host._interval_stats_asked.keys()
		interval_keys.sort()
		for key in interval_keys:
			var asked: int = int(host._interval_stats_asked[key])
			if asked <= 0:
				continue
			var correct: int = int(host._interval_stats_correct.get(key, 0))
			var acc: int = int(round((float(correct) / float(asked)) * 100.0))
			var display_name: String = interval_display_name.call(str(key)) if interval_display_name.is_valid() else str(key)
			parts.append("%s:%d%%" % [display_name, acc])
	elif host._selected_mode == mode_chord or host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		var chord_keys: Array = host._chord_stats_asked.keys()
		chord_keys.sort()
		for key in chord_keys:
			var asked_chord: int = int(host._chord_stats_asked[key])
			if asked_chord <= 0:
				continue
			var correct_chord: int = int(host._chord_stats_correct.get(key, 0))
			var acc_chord: int = int(round((float(correct_chord) / float(asked_chord)) * 100.0))
			parts.append("%s:%d%%" % [str(key), acc_chord])
	else:
		var sight_keys: Array = host._sight_stats_asked.keys()
		sight_keys.sort()
		for key in sight_keys:
			var asked_sight: int = int(host._sight_stats_asked[key])
			if asked_sight <= 0:
				continue
			var correct_sight: int = int(host._sight_stats_correct.get(key, 0))
			var acc_sight: int = int(round((float(correct_sight) / float(asked_sight)) * 100.0))
			parts.append("%s:%d%%" % [str(key), acc_sight])
	if host._selected_mode == mode_sight:
		if parts.is_empty():
			return "Performance:\nN/A"
		return "Performance:\n" + "\n".join(parts)
	return "Performance: " + (" | ".join(parts) if not parts.is_empty() else "N/A")


func performance_detail_only(perf_text: String) -> String:
	var p: String = perf_text.strip_edges()
	if p.begins_with("Performance:\n"):
		return p.substr("Performance:\n".length()).strip_edges()
	if p.begins_with("Performance:"):
		return p.substr("Performance:".length()).strip_edges()
	return p


func miss_summary_text(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	interval_display_name: Callable
) -> String:
	var stats_asked: Dictionary
	var stats_correct: Dictionary
	var use_interval_display := false
	var show_ratio := false
	if host._selected_mode == mode_interval:
		stats_asked = host._interval_stats_asked
		stats_correct = host._interval_stats_correct
		use_interval_display = true
	elif host._selected_mode == mode_chord:
		stats_asked = host._chord_stats_asked
		stats_correct = host._chord_stats_correct
		show_ratio = true
	elif host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		stats_asked = host._chord_stats_asked
		stats_correct = host._chord_stats_correct
	else:
		stats_asked = host._sight_stats_asked
		stats_correct = host._sight_stats_correct
	var missed: Array[String] = []
	for key in stats_asked.keys():
		var asked: int = int(stats_asked.get(key, 0))
		if asked <= 0:
			continue
		var correct: int = int(stats_correct.get(key, 0))
		if correct < asked:
			var display: String = interval_display_name.call(str(key)) if use_interval_display and interval_display_name.is_valid() else str(key)
			if show_ratio:
				missed.append("%s (%d/%d)" % [display, correct, asked])
			else:
				missed.append(display)
	if missed.is_empty():
		return ""
	return "Needs practice: " + ", ".join(missed)


func progress_dots_text(current: int, total: int) -> String:
	if total <= 0:
		return "Question %d" % current
	var dot_count: int = mini(total, 10)
	var answered: int = clampi(current - 1, 0, dot_count)
	var dots := ""
	for i in range(dot_count):
		dots += (char(0x25CF) if i < answered else char(0x25CB))
	return "Q%d/%d  %s" % [current, total, dots]


func session_elapsed_text(quiz_start_time: float) -> String:
	if quiz_start_time <= 0.0:
		return ""
	var elapsed: int = int(Time.get_ticks_msec() / 1000.0 - quiz_start_time)
	if elapsed <= 0:
		return ""
	var mins: int = elapsed / 60
	var secs: int = elapsed % 60
	if mins > 0:
		return "%dm %ds" % [mins, secs]
	return "%ds" % secs


func accuracy_motivational_message(total_correct: int, total_questions: int) -> String:
	if total_questions <= 0:
		return ""
	var pct: int = int(float(total_correct) / float(total_questions) * 100.0)
	if pct >= 95:
		return "%s Perfect session!" % char(0x1F3C6)
	if pct >= 80:
		return "%s Great work!" % char(0x2B50)
	if pct >= 60:
		return "%s Good effort!" % char(0x1F4AA)
	return "%s Keep practicing!" % char(0x1F3B5)


func final_quiz_result_text(
	host,
	total_correct: int,
	total_questions: int,
	final_score: int,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	mode_sight: int,
	mode_note_chase: int,
	interval_display_name: Callable
) -> String:
	var pct: int = int(float(total_correct) / maxf(1.0, float(total_questions)) * 100.0)
	var elapsed: String = session_elapsed_text(host._quiz_start_time)
	var time_part: String = ("   %s" % elapsed) if not elapsed.is_empty() else ""
	var result := "%d%%  Accuracy   (%d/%d correct)%s" % [pct, total_correct, total_questions, time_part]
	var weak_lines: String = result_weak_breakdown(host, mode_interval, mode_chord, mode_pitch_match, mode_progression, mode_scale_mode, mode_cadence, interval_display_name)
	if not weak_lines.is_empty():
		result += "\n\n%s" % weak_lines
	var insight: String = session_insight_text(host, mode_interval, mode_chord, mode_pitch_match, mode_progression, mode_scale_mode, mode_cadence, mode_sight, mode_note_chase, interval_display_name)
	if not insight.is_empty():
		result += "\n\n%s" % insight
	return result


func result_weak_breakdown(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	interval_display_name: Callable
) -> String:
	var stats_asked: Dictionary
	var stats_correct: Dictionary
	var use_interval_display := false
	if host._selected_mode == mode_interval:
		stats_asked = host._interval_stats_asked
		stats_correct = host._interval_stats_correct
		use_interval_display = true
	elif host._selected_mode == mode_chord or host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		stats_asked = host._chord_stats_asked
		stats_correct = host._chord_stats_correct
	else:
		stats_asked = host._sight_stats_asked
		stats_correct = host._sight_stats_correct
	var items: Array[String] = []
	for key in stats_asked.keys():
		var asked: int = int(stats_asked.get(key, 0))
		if asked <= 0:
			continue
		var correct: int = int(stats_correct.get(key, 0))
		if correct >= asked:
			continue
		var display: String = interval_display_name.call(str(key)) if use_interval_display and interval_display_name.is_valid() else str(key)
		items.append("%s  %d/%d" % [display, correct, asked])
	if items.is_empty():
		return ""
	return "Needs work:  %s" % "   ".join(items)


func session_insight_text(
	host,
	mode_interval: int,
	mode_chord: int,
	mode_pitch_match: int,
	mode_progression: int,
	mode_scale_mode: int,
	mode_cadence: int,
	mode_sight: int,
	mode_note_chase: int,
	interval_display_name: Callable
) -> String:
	var stats_asked: Dictionary
	var stats_correct: Dictionary
	var use_interval_display := false
	if host._selected_mode == mode_interval:
		stats_asked = host._interval_stats_asked
		stats_correct = host._interval_stats_correct
		use_interval_display = true
	elif host._selected_mode == mode_chord or host._selected_mode == mode_pitch_match or host._selected_mode == mode_progression or host._selected_mode == mode_scale_mode or host._selected_mode == mode_cadence:
		stats_asked = host._chord_stats_asked
		stats_correct = host._chord_stats_correct
	elif host._selected_mode == mode_sight or host._selected_mode == mode_note_chase:
		stats_asked = host._sight_stats_asked
		stats_correct = host._sight_stats_correct
	else:
		return ""
	var worst_key := ""
	var worst_miss_count := 0
	for key in stats_asked.keys():
		var asked: int = int(stats_asked.get(key, 0))
		if asked <= 0:
			continue
		var correct: int = int(stats_correct.get(key, 0))
		var missed: int = asked - correct
		if missed > worst_miss_count:
			worst_miss_count = missed
			worst_key = str(key)
	if worst_key.is_empty() or worst_miss_count <= 0:
		return ""
	var display: String = interval_display_name.call(worst_key) if use_interval_display and interval_display_name.is_valid() else worst_key
	return "%s  Next time, focus on %s" % [char(0x1F4A1), display]
