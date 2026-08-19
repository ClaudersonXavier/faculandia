class_name NoiseEvent
extends RefCounted

var position: Vector2
var radius: float
var type: StringName
var emitter: Node
var intensity: float
var timestamp: int


func _init(
	p_position: Vector2 = Vector2.ZERO,
	p_radius: float = 0.0,
	p_type: StringName = &"generic",
	p_emitter: Node = null,
	p_intensity: float = 1.0,
	p_timestamp: int = 0
) -> void:
	position = p_position
	radius = p_radius
	type = p_type
	emitter = p_emitter
	intensity = p_intensity
	timestamp = p_timestamp if p_timestamp != 0 else Time.get_ticks_msec()
