class_name NoiseBus
extends Node

signal noise_emitted(event: Dictionary)

static var instance: NoiseBus

@export var max_history: int = 50
@export var play_sfx: bool = true

var _recent_noises: Array[Dictionary] = []
var _audio_streams: Dictionary = {}


func _init() -> void:
	if not is_instance_valid(instance):
		instance = self
	_init_default_sfx()


func _enter_tree() -> void:
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
) -> Dictionary:
	var bus := get_instance()
	if bus != null:
		return bus._do_emit(pos, radius, noise_type, emitter, intensity)
	printerr("NoiseBus: get_instance() retornou null!")
	return {
		"position": pos,
		"radius": radius,
		"type": noise_type,
		"emitter": emitter,
		"intensity": intensity,
		"timestamp": Time.get_ticks_msec()
	}


func _do_emit(
	pos: Vector2,
	radius: float,
	noise_type: StringName,
	emitter: Node,
	intensity: float
) -> Dictionary:
	var event := {
		"position": pos,
		"radius": radius,
		"type": noise_type,
		"emitter": emitter,
		"intensity": intensity,
		"timestamp": Time.get_ticks_msec()
	}

	_recent_noises.append(event)
	if _recent_noises.size() > max_history:
		_recent_noises.pop_front()

	noise_emitted.emit(event)

	if play_sfx:
		_play_sfx_for_event(event)

	return event


static func is_noise_heard(listener_pos: Vector2, event: Dictionary, hearing_multiplier: float = 1.0) -> bool:
	var noise_pos: Vector2 = event.get("position", Vector2.ZERO)
	var noise_radius: float = float(event.get("radius", 0.0))
	var effective_radius := noise_radius * hearing_multiplier
	return listener_pos.distance_to(noise_pos) <= effective_radius


static func get_noises_in_range(listener_pos: Vector2, listener_radius: float = 0.0) -> Array[Dictionary]:
	var bus := get_instance()
	if bus != null:
		return bus._get_noises_in_range(listener_pos, listener_radius)
	return []


func _get_noises_in_range(listener_pos: Vector2, listener_radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _recent_noises:
		var noise_pos: Vector2 = event.get("position", Vector2.ZERO)
		var noise_radius: float = float(event.get("radius", 0.0))
		if listener_pos.distance_to(noise_pos) <= (noise_radius + listener_radius):
			result.append(event)
	return result


func _play_sfx_for_event(event: Dictionary) -> void:
	if not play_sfx or not is_inside_tree():
		return

	var n_type: StringName = event.get("type", &"generic")
	var stream: AudioStream = _audio_streams.get(n_type)
	if stream == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = event.get("position", Vector2.ZERO)
	player.bus = &"Master"

	var intensity: float = float(event.get("intensity", 1.0))
	if n_type == &"footstep":
		player.volume_db = -14.0 + (intensity - 1.0) * 6.0
	elif n_type == &"gunshot":
		player.volume_db = 0.0 + (intensity - 1.0) * 6.0
	elif n_type == &"bullet_impact":
		player.volume_db = -4.0 + (intensity - 1.0) * 6.0
	else:
		player.volume_db = -6.0

	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _init_default_sfx() -> void:
	_audio_streams[&"footstep"] = _create_footstep_sfx()
	_audio_streams[&"gunshot"] = _create_gunshot_sfx()
	_audio_streams[&"bullet_impact"] = _create_impact_sfx()


func _create_footstep_sfx() -> AudioStreamWAV:
	return _generate_procedural_wav(80.0, 0.06, 35.0, false)


func _create_gunshot_sfx() -> AudioStreamWAV:
	return _generate_procedural_wav(200.0, 0.18, 18.0, true)


func _create_impact_sfx() -> AudioStreamWAV:
	return _generate_procedural_wav(400.0, 0.08, 30.0, true)


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
		var byte_val := clampi(int((val * 0.45 + 0.5) * 255.0), 0, 255)
		byte_array[i] = byte_val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_array
	return wav
