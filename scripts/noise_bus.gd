class_name NoiseBus
extends Node

const NoiseEventScript := preload("res://scripts/noise_event.gd")

signal noise_emitted(event: NoiseEvent)

static var instance: NoiseBus

@export var max_history: int = 50
@export var play_sfx: bool = true
@export_range(-40.0, 6.0, 0.5) var master_sfx_volume_db: float = -8.0
@export_range(-40.0, 6.0, 0.5) var footstep_volume_db: float = -23.0
@export_range(-40.0, 6.0, 0.5) var gunshot_volume_db: float = -15.0
@export_range(-40.0, 6.0, 0.5) var impact_volume_db: float = -17.0

var _recent_noises: Array[NoiseEvent] = []
var _audio_streams: Dictionary = {}


func _init() -> void:
	if not is_instance_valid(instance):
		instance = self
	_init_default_sfx()


func _enter_tree() -> void:
	if is_instance_valid(instance) and instance != self:
		var main_loop := Engine.get_main_loop() as SceneTree
		var root_node := main_loop.root if main_loop != null else null
		if not instance.is_inside_tree():
			instance = self
		elif root_node != null and instance.get_parent() == root_node and self.get_parent() != root_node:
			instance.queue_free()
			instance = self
	else:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null


func _ready() -> void:
	if _audio_streams.is_empty():
		_init_default_sfx()


static func get_instance() -> NoiseBus:
	if not is_instance_valid(instance):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			var new_bus := NoiseBus.new()
			new_bus.name = "NoiseBus"
			tree.root.add_child(new_bus)
			instance = new_bus
	return instance


static func emit(
	pos: Vector2,
	radius: float,
	noise_type: StringName = &"generic",
	emitter: Node = null,
	intensity: float = 1.0
) -> NoiseEvent:
	var bus := get_instance()
	if bus != null:
		return bus._do_emit(pos, radius, noise_type, emitter, intensity)
	printerr("NoiseBus: get_instance() retornou null!")
	return NoiseEventScript.new(pos, radius, noise_type, emitter, intensity)


func _do_emit(
	pos: Vector2,
	radius: float,
	noise_type: StringName,
	emitter: Node,
	intensity: float
) -> NoiseEvent:
	var event := NoiseEventScript.new(pos, radius, noise_type, emitter, intensity)

	_recent_noises.append(event)
	if _recent_noises.size() > max_history:
		_recent_noises.pop_front()

	noise_emitted.emit(event)

	if play_sfx:
		_play_sfx_for_event(event)

	return event


static func is_noise_heard(listener_pos: Vector2, event: Variant, hearing_multiplier: float = 1.0) -> bool:
	var noise_pos: Vector2
	var noise_radius: float

	if event is NoiseEventScript:
		noise_pos = (event as NoiseEventScript).position
		noise_radius = (event as NoiseEventScript).radius
	elif event is Dictionary:
		noise_pos = (event as Dictionary).get("position", Vector2.ZERO)
		noise_radius = float((event as Dictionary).get("radius", 0.0))
	else:
		return false

	var effective_radius := noise_radius * hearing_multiplier
	return listener_pos.distance_to(noise_pos) <= effective_radius


static func get_noises_in_range(
	listener_pos: Vector2,
	hearing_multiplier: float = 1.0,
	max_age_ms: float = 1000.0
) -> Array[NoiseEvent]:
	var bus := get_instance()
	if bus != null:
		return bus._get_noises_in_range(listener_pos, hearing_multiplier, max_age_ms)
	return []


func _get_noises_in_range(
	listener_pos: Vector2,
	hearing_multiplier: float,
	max_age_ms: float
) -> Array[NoiseEvent]:
	var now := Time.get_ticks_msec()
	var result: Array[NoiseEvent] = []
	for event in _recent_noises:
		if max_age_ms > 0.0 and (now - event.timestamp) > max_age_ms:
			continue
		var effective_radius := event.radius * hearing_multiplier
		if listener_pos.distance_to(event.position) <= effective_radius:
			result.append(event)
	return result


func _get_base_db(noise_type: StringName) -> float:
	match noise_type:
		&"footstep":
			return footstep_volume_db
		&"gunshot":
			return gunshot_volume_db
		&"bullet_impact":
			return impact_volume_db
		_:
			return -20.0


func _play_sfx_for_event(event: NoiseEvent) -> void:
	if not play_sfx or not is_inside_tree():
		return

	var stream: AudioStream = _audio_streams.get(event.type)
	if stream == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = event.position
	player.bus = &"Master"
	player.max_distance = 1200.0
	player.attenuation = 1.8

	var base_db: float = _get_base_db(event.type)
	player.volume_db = base_db + master_sfx_volume_db + (event.intensity - 1.0) * 4.0

	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _init_default_sfx() -> void:
	_audio_streams[&"footstep"] = _create_footstep_sfx()
	_audio_streams[&"gunshot"] = _create_gunshot_sfx()
	_audio_streams[&"bullet_impact"] = _create_impact_sfx()


func _create_wav(sample_rate: int, byte_array: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_array
	return wav


func _create_footstep_sfx() -> AudioStreamWAV:
	return _generate_procedural_wav(60.0, 0.04, 50.0, false)


func _create_gunshot_sfx() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.10
	var total_samples := int(sample_rate * duration)
	var byte_array := PackedByteArray()
	byte_array.resize(total_samples)

	var phase: float = 0.0
	for i in total_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-30.0 * t)
		# 420Hz descendo para 70Hz
		var freq := 70.0 + 350.0 * exp(-38.0 * t)
		phase += TAU * freq / float(sample_rate)

		var tone := sin(phase)
		var noise := (randf() * 2.0 - 1.0) * exp(-55.0 * t) * 0.25

		var val := (tone * 0.6 + noise) * envelope
		var byte_val := clampi(int((val * 0.23 + 0.5) * 255.0), 0, 255)
		byte_array[i] = byte_val

	return _create_wav(sample_rate, byte_array)


func _create_impact_sfx() -> AudioStreamWAV:
	return _generate_procedural_wav(280.0, 0.05, 45.0, false)


func _generate_procedural_wav(frequency: float, duration: float, decay: float, is_noise: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var total_samples := int(sample_rate * duration)
	var byte_array := PackedByteArray()
	byte_array.resize(total_samples)

	for i in total_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-decay * t)
		var val: float = 0.0
		if is_noise:
			val = (randf() * 2.0 - 1.0) * envelope
		else:
			val = sin(TAU * frequency * t) * envelope
		var byte_val := clampi(int((val * 0.23 + 0.5) * 255.0), 0, 255)
		byte_array[i] = byte_val

	return _create_wav(sample_rate, byte_array)
