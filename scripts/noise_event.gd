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


func to_dict() -> Dictionary:
	return {
		"position": position,
		"radius": radius,
		"type": type,
		"emitter": emitter,
		"intensity": intensity,
		"timestamp": timestamp
	}


static func from_dict(data: Dictionary) -> NoiseEvent:
	return NoiseEvent.new(
		data.get("position", Vector2.ZERO),
		float(data.get("radius", 0.0)),
		data.get("type", &"generic"),
		data.get("emitter", null),
		float(data.get("intensity", 1.0)),
		int(data.get("timestamp", 0))
	)
