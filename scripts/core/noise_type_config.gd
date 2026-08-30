class_name NoiseTypeConfig

static func get_volume_db(noise_type: StringName) -> float:
	match noise_type:
		&"footstep":
			return -23.0
		&"gunshot":
			return -15.0
		&"bullet_impact":
			return -17.0
		_:
			return -20.0


static func get_color(noise_type: StringName) -> Color:
	match noise_type:
		&"footstep":
			return Color(0.2, 0.8, 1.0) # Azul claro
		&"gunshot":
			return Color(1.0, 0.25, 0.2) # Vermelho / Laranja
		&"bullet_impact":
			return Color(1.0, 0.85, 0.25) # Amarelo ouro
		_:
			return Color(1.0, 1.0, 1.0)


static func get_duration(noise_type: StringName) -> float:
	match noise_type:
		&"footstep":
			return 0.4
		&"gunshot":
			return 1.0
		&"bullet_impact":
			return 0.6
		_:
			return 0.6
