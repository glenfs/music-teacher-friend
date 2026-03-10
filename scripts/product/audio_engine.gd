class_name AudioEngine
extends RefCounted


func setup_players(owner: Node, chord_player_count: int = 8) -> Dictionary:
	var piano_player: AudioStreamPlayer = AudioStreamPlayer.new()
	owner.add_child(piano_player)
	var chord_players: Array[AudioStreamPlayer] = []
	for _i in range(chord_player_count):
		var chord_player: AudioStreamPlayer = AudioStreamPlayer.new()
		owner.add_child(chord_player)
		chord_players.append(chord_player)

	var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
	owner.add_child(sfx_player)
	var ui_sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
	owner.add_child(ui_sfx_player)
	var rhythm_metronome_player: AudioStreamPlayer = AudioStreamPlayer.new()
	rhythm_metronome_player.volume_db = -7.0
	owner.add_child(rhythm_metronome_player)
	var shield_sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
	owner.add_child(shield_sfx_player)
	var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
	music_player.volume_db = -16.0
	music_player.autoplay = false
	owner.add_child(music_player)
	var home_ambient_player: AudioStreamPlayer = AudioStreamPlayer.new()
	home_ambient_player.volume_db = -24.0
	home_ambient_player.autoplay = false
	owner.add_child(home_ambient_player)

	var audio_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	audio_stream.mix_rate = 44100
	audio_stream.buffer_length = 0.45

	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_player.stream = audio_stream
	owner.add_child(audio_player)
	audio_player.play()
	var playback: AudioStreamGeneratorPlayback = audio_player.get_stream_playback()

	return {
		"piano_player": piano_player,
		"chord_players": chord_players,
		"sfx_player": sfx_player,
		"ui_sfx_player": ui_sfx_player,
		"rhythm_metronome_player": rhythm_metronome_player,
		"shield_sfx_player": shield_sfx_player,
		"music_player": music_player,
		"home_ambient_player": home_ambient_player,
		"audio_stream": audio_stream,
		"audio_player": audio_player,
		"playback": playback
	}


func load_audio_stream(path: String, should_simulate_missing_resource: Callable) -> AudioStream:
	if should_simulate_missing_resource.is_valid():
		var should_skip: Variant = should_simulate_missing_resource.call(path, "audio")
		if bool(should_skip):
			return null
	if ResourceLoader.exists(path, "AudioStream"):
		return ResourceLoader.load(path) as AudioStream

	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null

	if path.to_lower().ends_with(".mp3"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_path)
		if not bytes.is_empty():
			var stream: AudioStreamMP3 = AudioStreamMP3.new()
			stream.data = bytes
			return stream

	return null


func load_audio_stream_from_path(path: String) -> AudioStream:
	if ResourceLoader.exists(path, "AudioStream"):
		var loaded_res: Resource = ResourceLoader.load(path)
		if loaded_res is AudioStream:
			return loaded_res as AudioStream
	if path.to_lower().ends_with(".mp3"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var mp3_stream: AudioStreamMP3 = AudioStreamMP3.new()
			mp3_stream.data = bytes
			return mp3_stream
	return null


func load_piano_samples(
	numbered_dir: String,
	numbered_first_index: int,
	numbered_last_index: int,
	numbered_base_midi: int,
	sampled_dir: String,
	sampled_midi_overrides: Dictionary,
	fallback_sample_paths: Dictionary
) -> Dictionary:
	var piano_samples: Dictionary = {}
	var interval_anchor_samples: Dictionary = {}
	_load_numbered_piano_from_folder(piano_samples, numbered_dir, numbered_first_index, numbered_last_index, numbered_base_midi)
	if not piano_samples.is_empty():
		interval_anchor_samples = piano_samples.duplicate()
		return {
			"piano_samples": piano_samples,
			"interval_anchor_samples": interval_anchor_samples
		}
	_load_sampled_piano_from_folder(piano_samples, sampled_dir, sampled_midi_overrides)
	if not piano_samples.is_empty():
		for midi_key in fallback_sample_paths.keys():
			var sample_path: String = str(fallback_sample_paths[midi_key])
			var stream: AudioStream = load_audio_stream_from_path(sample_path)
			if stream != null:
				interval_anchor_samples[midi_key] = stream
		return {
			"piano_samples": piano_samples,
			"interval_anchor_samples": interval_anchor_samples
		}
	for midi_key in fallback_sample_paths.keys():
		var sample_path_legacy: String = str(fallback_sample_paths[midi_key])
		var stream_legacy: AudioStream = load_audio_stream_from_path(sample_path_legacy)
		if stream_legacy != null:
			piano_samples[midi_key] = stream_legacy
			interval_anchor_samples[midi_key] = stream_legacy
	return {
		"piano_samples": piano_samples,
		"interval_anchor_samples": interval_anchor_samples
	}


func midi_to_freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


func sample_map_cache_key(sample_map: Dictionary, selected_mode: int, sight_mode: String, mode_sight: int) -> String:
	var keys: Array = sample_map.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append(str(key))
	var mode_tag: String = str(selected_mode)
	if selected_mode == mode_sight:
		mode_tag += ":" + sight_mode
	return "%s|%s" % [mode_tag, ",".join(parts)]


func nearest_sample_midi_from_map(target_midi: int, sample_map: Dictionary) -> int:
	var keys: Array = sample_map.keys()
	var best: int = int(keys[0])
	var best_dist: int = int(abs(target_midi - best))
	for key in keys:
		var midi: int = int(key)
		var distance: int = int(abs(target_midi - midi))
		if distance < best_dist:
			best = midi
			best_dist = distance
	return best


func _load_numbered_piano_from_folder(target: Dictionary, numbered_dir: String, first_index: int, last_index: int, base_midi: int) -> void:
	var dir: DirAccess = DirAccess.open(numbered_dir)
	if dir == null:
		return
	for sample_index in range(first_index, last_index + 1):
		var full_path: String = "%s/%d.mp3" % [numbered_dir, sample_index]
		var stream: AudioStream = load_audio_stream_from_path(full_path)
		if stream != null:
			var midi: int = base_midi + (sample_index - first_index)
			if not target.has(midi):
				target[midi] = stream


func _load_sampled_piano_from_folder(target: Dictionary, sampled_dir: String, sampled_midi_overrides: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(sampled_dir)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	var lower_names: Dictionary = {}
	for file_name in files:
		var file_name_lower: String = str(file_name).to_lower()
		lower_names[file_name_lower.get_basename()] = true
	for file_name in files:
		var file_name_str: String = str(file_name)
		if not file_name_str.to_lower().ends_with(".ogg"):
			continue
		var midi: int = _sampled_filename_to_midi(file_name_str, lower_names, sampled_midi_overrides)
		if midi < 0:
			continue
		var full_path: String = "%s/%s" % [sampled_dir, file_name_str]
		var stream: AudioStream = load_audio_stream_from_path(full_path)
		if stream != null and not target.has(midi):
			target[midi] = stream


func _sampled_filename_to_midi(file_name: String, lower_names: Dictionary, sampled_midi_overrides: Dictionary) -> int:
	var base: String = file_name.get_basename().to_lower()
	if sampled_midi_overrides.has(base):
		return int(sampled_midi_overrides[base])
	var rx: RegEx = RegEx.new()
	if rx.compile("^([a-g])(\\d)(?:_(\\d+))?$") != OK:
		return -1
	var match: RegExMatch = rx.search(base)
	if match == null:
		return -1
	var letter: String = match.get_string(1)
	var octave: int = int(match.get_string(2))
	var variant_text: String = match.get_string(3)
	var variant: int = int(variant_text) if variant_text != "" else 1

	var natural_semitone: int = _natural_letter_to_semitone(letter)
	if natural_semitone < 0:
		return -1

	var midi: int = 12 * (octave + 1) + natural_semitone
	var is_natural_only: bool = letter == "b" or letter == "e"
	if not is_natural_only:
		var has_natural_variant: bool = lower_names.has("%s%d_2" % [letter, octave])
		if has_natural_variant and variant != 2:
			midi += 1

	if midi < 0 or midi > 127:
		return -1
	return midi


func _natural_letter_to_semitone(letter: String) -> int:
	match letter:
		"c":
			return 0
		"d":
			return 2
		"e":
			return 4
		"f":
			return 5
		"g":
			return 7
		"a":
			return 9
		"b":
			return 11
		_:
			return -1
