class_name NoiseSynthesizer
extends RefCounted


static func create_wav(sample_rate: int, byte_array: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_array
	return wav


static func create_footstep_sfx() -> AudioStreamWAV:
	return create_procedural_wav(60.0, 0.04, 50.0, false)


static func create_gunshot_sfx() -> AudioStreamWAV:
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

	return create_wav(sample_rate, byte_array)


static func create_impact_sfx() -> AudioStreamWAV:
	return create_procedural_wav(280.0, 0.05, 45.0, false)


static func create_procedural_wav(
	frequency: float,
	duration: float,
	decay: float,
	is_noise: bool
) -> AudioStreamWAV:
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

	return create_wav(sample_rate, byte_array)
