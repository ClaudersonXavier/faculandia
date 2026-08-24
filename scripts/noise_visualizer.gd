class_name NoiseVisualizer
extends Node2D

const NoiseBus := preload("res://scripts/noise_bus.gd")
const NoiseEventScript := preload("res://scripts/noise_event.gd")

@export var enabled: bool = false
@export var default_duration: float = 0.6
@export var gunshot_duration: float = 1.0
@export var footstep_duration: float = 0.4
@export var line_width: float = 2.0

class NoiseRing:
	var position: Vector2
	var max_radius: float
	var color: Color
	var duration: float
	var elapsed: float = 0.0

var _rings: Array[NoiseRing] = []


func _ready() -> void:
	z_index = 85 # Acima do cenario, abaixo da UI
	_connect_bus()


func _connect_bus() -> void:
	var bus := NoiseBus.get_instance()
	if bus != null and not bus.noise_emitted.is_connected(_on_noise_emitted):
		bus.noise_emitted.connect(_on_noise_emitted)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			enabled = not enabled
			queue_redraw()
			print("[DEBUG] Visualizador de som: %s" % ("LIGADO" if enabled else "DESLIGADO"))


func _get_ring_style(n_type: StringName) -> Dictionary:
	match n_type:
		&"footstep":
			return {
				"color": Color(0.2, 0.8, 1.0), # Azul claro
				"duration": footstep_duration
			}
		&"gunshot":
			return {
				"color": Color(1.0, 0.25, 0.2), # Vermelho / Laranja
				"duration": gunshot_duration
			}
		&"bullet_impact":
			return {
				"color": Color(1.0, 0.85, 0.25), # Amarelo ouro
				"duration": default_duration
			}
		_:
			return {
				"color": Color(1.0, 1.0, 1.0),
				"duration": default_duration
			}


func _on_noise_emitted(event: NoiseEvent) -> void:
	var ring := NoiseRing.new()
	ring.position = event.position
	ring.max_radius = event.radius

	var style := _get_ring_style(event.type)
	ring.color = style.get("color", Color.WHITE)
	ring.duration = float(style.get("duration", default_duration))

	_rings.append(ring)
	queue_redraw()


func _process(delta: float) -> void:
	if _rings.is_empty():
		return

	var i := 0
	while i < _rings.size():
		var ring := _rings[i]
		ring.elapsed += delta
		if ring.elapsed >= ring.duration:
			_rings.remove_at(i)
		else:
			i += 1

	queue_redraw()


func _draw() -> void:
	if not enabled or _rings.is_empty():
		return

	for ring in _rings:
		var progress: float = clampf(ring.elapsed / ring.duration, 0.0, 1.0)
		var current_radius: float = ring.max_radius * sqrt(progress) # Expansao rapida inicial
		var alpha: float = 1.0 - progress
		var draw_color := Color(ring.color.r, ring.color.g, ring.color.b, ring.color.a * alpha * 0.75)
		var fill_color := Color(ring.color.r, ring.color.g, ring.color.b, ring.color.a * alpha * 0.12)

		var local_center := to_local(ring.position)

		# Area preenchida sutil
		draw_circle(local_center, current_radius, fill_color)
		# Anel de onda sonora
		draw_arc(local_center, current_radius, 0.0, TAU, 48, draw_color, line_width, true)
		# Circulo de limite maximo pontilhado / fino
		var max_color := Color(ring.color.r, ring.color.g, ring.color.b, ring.color.a * alpha * 0.25)
		draw_arc(local_center, ring.max_radius, 0.0, TAU, 32, max_color, 1.0, true)


func get_active_ring_count() -> int:
	return _rings.size()
