class_name NoiseBus
extends Node

const NoiseEventScript := preload("res://scripts/noise/noise_event.gd")

signal noise_emitted(event: NoiseEvent)

static var instance: NoiseBus

@export var max_history: int = 50
@export var play_sfx: bool = true
@export_range(-40.0, 6.0, 0.5) var master_sfx_volume_db: float = -8.0

var _recent_noises: Array[NoiseEvent] = []
var _sfx_player: NoiseSfxPlayer


func _init() -> void:
	if not is_instance_valid(instance):
		instance = self
	_sfx_player = NoiseSfxPlayer.new()


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
	if _sfx_player == null:
		_sfx_player = NoiseSfxPlayer.new()


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
		_sfx_player.play_for_event(self, event, master_sfx_volume_db)

	return event


static func is_noise_heard(listener_pos: Vector2, event: NoiseEvent, hearing_multiplier: float = 1.0) -> bool:
	if event == null:
		return false
	return event.is_heard_at(listener_pos, hearing_multiplier)


static func get_noises_in_range(
	listener_pos: Vector2,
	listener_radius: float = 0.0,
	hearing_multiplier: float = 1.0,
	max_age_ms: float = 1000.0
) -> Array[NoiseEvent]:
	var bus := get_instance()
	if bus != null:
		return bus._get_noises_in_range(listener_pos, listener_radius, hearing_multiplier, max_age_ms)
	return []


func _get_noises_in_range(
	listener_pos: Vector2,
	listener_radius: float,
	hearing_multiplier: float,
	max_age_ms: float
) -> Array[NoiseEvent]:
	var now := Time.get_ticks_msec()
	var result: Array[NoiseEvent] = []
	for event in _recent_noises:
		if max_age_ms > 0.0 and (now - event.timestamp) > max_age_ms:
			continue
		if event.is_heard_at(listener_pos, hearing_multiplier, listener_radius):
			result.append(event)
	return result
