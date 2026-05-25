extends Control

const MAIN_MENU_SCENE: String = "res://scenes/IntervalBirds.tscn"
const MAIN_MENU_PACKED: PackedScene = preload("res://scenes/IntervalBirds.tscn")
const AudioEngineScript = preload("res://scripts/product/audio_engine.gd")
const LOGO_FONT_PATH: String = "res://assets/fonts/Baloo2-SemiBold.ttf"
const TAGLINE_FONT_PATH: String = "res://assets/fonts/Nunito-Regular.ttf"
const ONE_SEMITONE_UP: float = 1.059463
const CHORD_STREAM_PATHS := [
	"res://assets/audio/piano/piano/52.mp3",
	"res://assets/audio/piano/piano/59.mp3",
]

@onready var _background: ColorRect = $Background
@onready var _fade_overlay: ColorRect = $FadeOverlay
@onready var _staff: Node2D = $Staff
@onready var _logo_text: Label = $CenterContent/VBox/LogoText
@onready var _tagline_text: Label = $CenterContent/VBox/TaglineText
@onready var _version_text: Label = $CenterContent/VBox/VersionText
@onready var _piano_players: Array[AudioStreamPlayer] = [
	$PianoC5 as AudioStreamPlayer,
	$PianoG5 as AudioStreamPlayer,
]
@onready var _staff_lines: Array[Line2D] = [
	$Staff/Line1 as Line2D,
	$Staff/Line2 as Line2D,
	$Staff/Line3 as Line2D,
	$Staff/Line4 as Line2D,
	$Staff/Line5 as Line2D,
]

var _sequence_tween: Tween = null
var _arpeggio_tween: Tween = null
var _staff_glow_tween: Tween = null
var _transitioned: bool = false
var _audio_engine: AudioEngine = AudioEngineScript.new()


func _ready() -> void:
	_apply_background_shader()
	_configure_audio()
	_apply_fonts()
	_set_initial_state()
	_update_staff_layout()
	resized.connect(_on_resized)
	_start_sequence()


func _exit_tree() -> void:
	if _sequence_tween != null and is_instance_valid(_sequence_tween):
		_sequence_tween.kill()
	_sequence_tween = null
	if _arpeggio_tween != null and is_instance_valid(_arpeggio_tween):
		_arpeggio_tween.kill()
	_arpeggio_tween = null
	if _staff_glow_tween != null and is_instance_valid(_staff_glow_tween):
		_staff_glow_tween.kill()
	_staff_glow_tween = null
	for player in _piano_players:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null
	if _background != null and is_instance_valid(_background):
		_background.material = null
	if _logo_text != null and is_instance_valid(_logo_text):
		_logo_text.remove_theme_font_override("font")
	if _tagline_text != null and is_instance_valid(_tagline_text):
		_tagline_text.remove_theme_font_override("font")
	if _version_text != null and is_instance_valid(_version_text):
		_version_text.remove_theme_font_override("font")
	_audio_engine = null


func _input(event: InputEvent) -> void:
	if _transitioned:
		return

	var should_skip: bool = false
	if event is InputEventKey:
		should_skip = (event as InputEventKey).pressed
	elif event is InputEventMouseButton:
		should_skip = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		should_skip = (event as InputEventScreenTouch).pressed
	elif event is InputEventJoypadButton:
		should_skip = (event as InputEventJoypadButton).pressed

	if should_skip:
		get_viewport().set_input_as_handled()
		_go_to_main_menu()


func _set_initial_state() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_fade_overlay.color = Color(0.4745, 0.7804, 0.9608, 0.0)
	_staff.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_staff.scale = Vector2(0.86, 0.86)
	_logo_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_logo_text.scale = Vector2(0.94, 0.94)
	_tagline_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_version_text.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _apply_background_shader() -> void:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.4745, 0.7804, 0.9608, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.9647, 0.9843, 1.0, 1.0);
uniform float grain_strength : hint_range(0.0, 0.08) = 0.02;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 base = mix(top_color, bottom_color, UV.y);
	float grain = hash(floor(UV * vec2(1920.0, 1080.0)));
	base.rgb += (grain - 0.5) * grain_strength;
	COLOR = base;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_background.material = material


func _configure_audio() -> void:
	for index in range(_piano_players.size()):
		var player: AudioStreamPlayer = _piano_players[index]
		if player == null:
			continue
		if player.stream == null and index < CHORD_STREAM_PATHS.size():
			var path: String = CHORD_STREAM_PATHS[index]
			player.stream = _audio_engine.load_audio_stream_from_path(path)
		player.pitch_scale = ONE_SEMITONE_UP if index == 1 else 1.0
		player.volume_db = -27.0 if index == 0 else -28.0


func _apply_fonts() -> void:
	var logo_font: FontFile = _load_font(LOGO_FONT_PATH)
	if logo_font != null:
		_logo_text.add_theme_font_override("font", logo_font)
		_version_text.add_theme_font_override("font", logo_font)

	var tagline_font: FontFile = _load_font(TAGLINE_FONT_PATH)
	if tagline_font != null:
		_tagline_text.add_theme_font_override("font", tagline_font)

	_logo_text.add_theme_color_override("font_color", Color(0.07, 0.20, 0.38, 1.0))
	_logo_text.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.18, 0.18))
	_logo_text.add_theme_constant_override("shadow_offset_x", 0)
	_logo_text.add_theme_constant_override("shadow_offset_y", 2)
	_tagline_text.add_theme_color_override("font_color", Color(0.10, 0.27, 0.49, 0.86))
	_version_text.add_theme_color_override("font_color", Color(0.10, 0.27, 0.49, 0.82))
	_update_font_sizes()


func _load_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is FontFile:
		return res as FontFile
	return null


func _update_font_sizes() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var logo_size: int = int(round(clampf(viewport_size.y * 0.12, 56.0, 120.0)))
	var tagline_size: int = int(round(clampf(viewport_size.y * 0.037, 20.0, 38.0)))
	var version_size: int = int(round(clampf(viewport_size.y * 0.028, 16.0, 26.0)))
	_logo_text.add_theme_font_size_override("font_size", logo_size)
	_tagline_text.add_theme_font_size_override("font_size", tagline_size)
	_version_text.add_theme_font_size_override("font_size", version_size)


func _update_staff_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var staff_width: float = viewport_size.x * 0.66
	var spacing: float = clampf(viewport_size.y * 0.026, 14.0, 22.0)
	var thickness: float = clampf(viewport_size.y * 0.0035, 3.0, 4.8)
	_staff.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.33)

	for index in range(_staff_lines.size()):
		var line: Line2D = _staff_lines[index]
		if line == null:
			continue
		var y_offset: float = (float(index) - 2.0) * spacing
		line.width = thickness
		line.points = PackedVector2Array([
			Vector2(-staff_width * 0.5, y_offset),
			Vector2(staff_width * 0.5, y_offset),
		])
		if index == 2:
			line.default_color = Color(0.99, 0.84, 0.30, 0.92)
		else:
			line.default_color = Color(0.95, 0.74, 0.20, 0.78)
		line.antialiased = true
	_start_middle_staff_glow()


func _start_middle_staff_glow() -> void:
	if _staff_glow_tween != null:
		_staff_glow_tween.kill()
	if _staff_lines.size() < 3:
		return
	var middle_line: Line2D = _staff_lines[2]
	if middle_line == null:
		return
	_staff_glow_tween = create_tween()
	_staff_glow_tween.set_loops()
	_staff_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_staff_glow_tween.tween_property(middle_line, "default_color", Color(1.0, 0.92, 0.40, 1.0), 0.45)
	_staff_glow_tween.tween_property(middle_line, "default_color", Color(0.99, 0.82, 0.28, 0.88), 0.5)


func _start_sequence() -> void:
	if _sequence_tween != null:
		_sequence_tween.kill()

	_sequence_tween = create_tween()
	_sequence_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence_tween.tween_interval(0.1)
	# Staff blooms in
	_sequence_tween.tween_property(_staff, "modulate:a", 0.52, 0.35)
	_sequence_tween.parallel().tween_property(_staff, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Logo + tagline fade in together
	_sequence_tween.tween_property(_logo_text, "modulate:a", 1.0, 0.3)
	_sequence_tween.parallel().tween_property(_logo_text, "scale", Vector2.ONE, 0.3)
	_sequence_tween.parallel().tween_property(_tagline_text, "modulate:a", 0.88, 0.35)
	_sequence_tween.parallel().tween_property(_version_text, "modulate:a", 0.80, 0.35)
	_sequence_tween.tween_interval(0.15)
	_sequence_tween.tween_callback(Callable(self, "_play_piano_arpeggio"))
	_sequence_tween.tween_interval(0.8)
	_sequence_tween.tween_property(_fade_overlay, "color:a", 1.0, 0.25)
	_sequence_tween.tween_callback(Callable(self, "_go_to_main_menu"))


func _play_piano_arpeggio() -> void:
	if _transitioned:
		return
	if _arpeggio_tween != null:
		_arpeggio_tween.kill()
	_arpeggio_tween = create_tween()
	for player in _piano_players:
		if player != null and player.stream != null:
			_arpeggio_tween.tween_callback(Callable(self, "_play_piano_note").bind(player))
			_arpeggio_tween.tween_interval(0.3)


func _play_piano_note(player: AudioStreamPlayer) -> void:
	if _transitioned:
		return
	if player != null and player.stream != null:
		player.play()


func _go_to_main_menu() -> void:
	if _transitioned:
		return

	_transitioned = true
	if _sequence_tween != null:
		_sequence_tween.kill()
	if _arpeggio_tween != null:
		_arpeggio_tween.kill()
	if _staff_glow_tween != null:
		_staff_glow_tween.kill()
	for player in _piano_players:
		if player != null and player.playing:
			player.stop()

	if MAIN_MENU_PACKED != null:
		var next_scene: Node = MAIN_MENU_PACKED.instantiate()
		get_tree().root.add_child(next_scene)
		get_tree().current_scene = next_scene
		queue_free()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_resized() -> void:
	_update_font_sizes()
	_update_staff_layout()
