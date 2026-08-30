class_name NoiseSfxPlayer
extends RefCounted

## Toca efeitos sonoros sintetizados para eventos de ruido. Separado do
## NoiseBus para isolar a responsabilidade de audio da de
## registro/consulta de eventos.

const NoiseSynthesizerScript := preload("res://scripts/noise/noise_synthesizer.gd")

var _audio_streams: Dictionary = {}


func _init() -> void:
	_audio_streams[&"footstep"] = NoiseSynthesizerScript.create_footstep_sfx()
	_audio_streams[&"gunshot"] = NoiseSynthesizerScript.create_gunshot_sfx()
	_audio_streams[&"bullet_impact"] = NoiseSynthesizerScript.create_impact_sfx()


func play_for_event(parent: Node, event: NoiseEvent, master_volume_db: float) -> void:
	if not parent.is_inside_tree():
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

	var base_db: float = NoiseTypeConfig.get_volume_db(event.type)
	player.volume_db = base_db + master_volume_db + (event.intensity - 1.0) * 4.0

	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
