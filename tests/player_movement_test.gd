extends SceneTree

const PlayerMovementScript := preload("res://scripts/player_moviment.gd")
const NoiseBus := preload("res://scripts/noise_bus.gd")
const NoiseEventScript := preload("res://scripts/noise_event.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_diagonal_movement_is_normalized()
	await _test_acceleration_and_deceleration()
	await _test_backpedal_speed_penalty()
	await _test_animation_speed_scale_and_state()
	await _test_animation_backpedal_transition()
	await _test_footstep_distance_sync()

	var bus := NoiseBus.get_instance()
	if is_instance_valid(bus) and bus.is_inside_tree():
		bus.free()

	if failures > 0:
		printerr("%d teste(s) de movimento falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de movimento passaram com sucesso!")
		quit(0)


func _create_player_fixture() -> Dictionary:
	var scene_root := Node2D.new()
	get_root().add_child(scene_root)

	var player = PlayerMovementScript.new()
	player.global_position = Vector2(100, 100)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "player_sprite"
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_animation(&"walk")
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(32, 32)
	frames.add_frame(&"idle", tex)
	frames.add_frame(&"walk", tex)
	sprite.sprite_frames = frames
	player.add_child(sprite)

	var collision := CollisionShape2D.new()
	collision.name = "player_collision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	player.add_child(collision)

	var camera := Camera2D.new()
	camera.name = "camera_player"
	camera.limit_left = -1000
	camera.limit_top = -1000
	camera.limit_right = 1000
	camera.limit_bottom = 1000
	player.add_child(camera)

	var weapon := Node2D.new()
	weapon.name = "Weapon"
	player.add_child(weapon)

	scene_root.add_child(player)
	return {"root": scene_root, "player": player, "sprite": sprite}


func _test_diagonal_movement_is_normalized() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player

	# Entrada diagonal bruta nao-normalizada
	var raw_diagonal_input := Vector2(1.0, 1.0)
	for i in 60:
		player.apply_movement(raw_diagonal_input, 1.0 / 60.0)

	var speed_magnitude: float = player.velocity.length()
	_assert_true(
		is_equal_approx(speed_magnitude, player.speed) or speed_magnitude <= player.speed + 0.01,
		"Velocidade com entrada diagonal bruta (1,1) nao deve exceder speed=%f (obtido: %f)" % [player.speed, speed_magnitude]
	)

	fixture.root.free()


func _test_acceleration_and_deceleration() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	player.velocity = Vector2.ZERO

	var delta := 1.0 / 60.0
	player.apply_movement(Vector2.RIGHT, delta)

	_assert_true(
		player.velocity.x > 0.0 and player.velocity.x < player.speed,
		"Velocidade deve acelerar suavemente, sem teletransporte instantaneo para velocidade maxima"
	)

	for i in 60:
		player.apply_movement(Vector2.RIGHT, delta)

	_assert_true(
		is_equal_approx(player.velocity.x, player.speed),
		"Apos aceleracao continua, deve atingir a velocidade maxima (speed=%f, atual=%f)" % [player.speed, player.velocity.x]
	)

	player.apply_movement(Vector2.ZERO, delta)
	_assert_true(
		player.velocity.x < player.speed and player.velocity.x > 0.0,
		"Sem entrada, o personagem deve desacelerar suavemente pela friccao"
	)

	fixture.root.free()


func _test_backpedal_speed_penalty() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	player.aim_direction = Vector2.RIGHT

	var delta := 1.0 / 60.0
	for i in 60:
		player.apply_movement(Vector2.LEFT, delta)

	var expected_backpedal_speed: float = player.speed * player.backpedal_multiplier
	_assert_true(
		is_equal_approx(player.velocity.length(), expected_backpedal_speed),
		"Velocidade ao recuar/andar de costas deve ter penalidade tatica (esperado: %f, obtido: %f)" % [expected_backpedal_speed, player.velocity.length()]
	)

	fixture.root.free()


func _test_animation_speed_scale_and_state() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	var sprite: AnimatedSprite2D = fixture.sprite
	player.aim_direction = Vector2.RIGHT

	player.velocity = Vector2.ZERO
	player.update_animation()
	_assert_true(sprite.animation == &"idle", "Parado deve tocar idle (obtido: %s)" % sprite.animation)
	_assert_true(is_equal_approx(sprite.speed_scale, 1.0), "Parado deve ter speed_scale 1.0")

	player.velocity = Vector2.RIGHT * player.speed
	player.update_animation()
	_assert_true(sprite.animation == &"walk", "Movendo deve tocar walk (obtido: %s)" % sprite.animation)
	_assert_true(is_equal_approx(sprite.speed_scale, 1.0), "Velocidade maxima deve ter speed_scale ~1.0")

	player.velocity = Vector2.RIGHT * (player.speed * 0.5)
	player.update_animation()
	_assert_true(is_equal_approx(sprite.speed_scale, 0.5), "Meia velocidade deve ter speed_scale ~0.5 (obtido: %f)" % sprite.speed_scale)

	fixture.root.free()


func _test_animation_backpedal_transition() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	var sprite: AnimatedSprite2D = fixture.sprite
	player.aim_direction = Vector2.RIGHT

	# 1. Andando para frente
	player.velocity = Vector2.RIGHT * player.speed
	player.update_animation()
	_assert_false(player._is_backpedaling_state, "Andando para frente nao deve estar em estado de recuo")
	_assert_true(sprite.animation == &"walk", "Deve estar tocando animacao walk para frente")

	# 2. Transicao para recuo (andando para tras enquanto mira para frente)
	player.velocity = Vector2.LEFT * (player.speed * player.backpedal_multiplier)
	player.update_animation()
	_assert_true(player._is_backpedaling_state, "Andando para tras deve alternar estado de recuo")
	_assert_true(sprite.animation == &"walk", "Deve continuar tocando animacao walk")

	# 3. Transicao de volta para frente
	player.velocity = Vector2.RIGHT * player.speed
	player.update_animation()
	_assert_false(player._is_backpedaling_state, "Retornando para frente deve desativar estado de recuo")

	fixture.root.free()


func _test_footstep_distance_sync() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player

	var footstep_events: Array[NoiseEvent] = []
	var on_event = func(event: NoiseEvent) -> void:
		if event.type == &"footstep":
			footstep_events.append(event)
	var bus := NoiseBus.get_instance()
	bus.noise_emitted.connect(on_event)

	player.global_position = Vector2(100, 100)
	player._physics_process(0.1)

	# Move menos que o threshold (ex: 20px com threshold 27px)
	player.global_position = Vector2(120, 100)
	player._physics_process(0.1)
	_assert_true(footstep_events.is_empty(), "Nao deve emitir passo antes de 27px")

	# Move mais 10px (total 30px >= 27px)
	player.global_position = Vector2(130, 100)
	player._physics_process(0.1)
	_assert_true(footstep_events.size() == 1, "Deve emitir passo ao cruzar 27px")

	bus.noise_emitted.disconnect(on_event)
	fixture.root.free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
