extends SceneTree

const NoiseBus := preload("res://scripts/noise_bus.gd")
const NoiseEventScript := preload("res://scripts/noise_event.gd")
const WeaponScript := preload("res://scripts/weapon.gd")
const BulletScript := preload("res://scripts/bullet.gd")
const PlayerMovementScript := preload("res://scripts/player_moviment.gd")
const NoiseVisualizerScript := preload("res://scripts/noise_visualizer.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_noise_bus_emit_and_receive()
	await _test_is_noise_heard_within_radius()
	await _test_player_emits_footstep_on_movement()
	await _test_player_stationary_does_not_emit_footstep()
	await _test_weapon_emits_gunshot_on_shoot()
	await _test_bullet_emits_impact_on_collision()
	await _test_noise_visualizer_registers_rings()
	await _test_noise_bus_history_and_query()
	await _test_noise_bus_ttl_filtering()

	var bus := NoiseBus.get_instance()
	if is_instance_valid(bus) and bus.is_inside_tree():
		bus.free()

	if failures > 0:
		printerr("%d teste(s) de som falharam" % failures)
		quit(1)
	else:
		print("Todos os testes do sistema de som passaram com sucesso!")
		quit(0)


func _test_noise_bus_emit_and_receive() -> void:
	var bus := NoiseBus.get_instance()
	var received_events: Array[NoiseEvent] = []
	var on_event = func(event: NoiseEvent) -> void:
		received_events.append(event)
	bus.noise_emitted.connect(on_event)

	var emitted := NoiseBus.emit(Vector2(100, 200), 150.0, &"footstep", null, 0.8)

	_assert_true(received_events.size() >= 1, "NoiseBus deve emitir o sinal noise_emitted")
	_assert_true(emitted.position == Vector2(100, 200), "Evento deve conter a posicao correta")
	_assert_true(emitted.radius == 150.0, "Evento deve conter o raio correto")
	_assert_true(emitted.type == &"footstep", "Evento deve conter o tipo de som correto")
	_assert_true(emitted.intensity == 0.8, "Evento deve conter a intensidade correta")

	bus.noise_emitted.disconnect(on_event)


func _test_is_noise_heard_within_radius() -> void:
	var event := NoiseEventScript.new(Vector2(100, 100), 120.0, &"footstep", null, 1.0)

	# Dentro do raio
	_assert_true(
		NoiseBus.is_noise_heard(Vector2(150, 100), event),
		"Ouvinte a 50px de distancia deve ouvir som com raio de 120px"
	)
	_assert_true(
		NoiseBus.is_noise_heard(Vector2(220, 100), event),
		"Ouvinte exatamente no limite do raio (120px) deve ouvir o som"
	)

	# Fora do raio
	_assert_false(
		NoiseBus.is_noise_heard(Vector2(250, 100), event),
		"Ouvinte a 150px de distancia nao deve ouvir som com raio de 120px"
	)

	# Com multiplicador de sensibilidade de audicao (ex: Ameaca com percepcao apurada)
	_assert_true(
		NoiseBus.is_noise_heard(Vector2(250, 100), event, 1.5),
		"Ouvinte a 150px com sensibilidade 1.5 deve ouvir som de 120px (180px efetivos)"
	)


func _test_player_emits_footstep_on_movement() -> void:
	var scene_root := Node2D.new()
	get_root().add_child(scene_root)

	var player := CharacterBody2D.new()
	player.set_script(PlayerMovementScript)
	player.global_position = Vector2(100, 100)
	
	var sprite := Sprite2D.new()
	sprite.name = "player_sprite"
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
	await process_frame

	var footstep_events: Array[NoiseEvent] = []
	var on_event = func(event: NoiseEvent) -> void:
		if event.type == &"footstep":
			footstep_events.append(event)
	var bus := NoiseBus.get_instance()
	bus.noise_emitted.connect(on_event)

	# Simula movimento acumulando passos
	player.global_position = Vector2(100, 100)
	player._physics_process(0.1)
	_assert_true(footstep_events.size() == 0, "Nao deve emitir passo no repouso")

	player.global_position = Vector2(120, 100)
	player._physics_process(0.1) # moveu 20px (< threshold 40px)
	_assert_true(footstep_events.size() == 0, "Nao deve emitir passo antes de atingir threshold")

	player.global_position = Vector2(150, 100)
	player._physics_process(0.1) # moveu mais 30px (total 50px >= 40px)
	_assert_true(footstep_events.size() == 1, "Deve emitir passo ao cruzar o threshold de distancia")

	bus.noise_emitted.disconnect(on_event)
	scene_root.free()


func _test_player_stationary_does_not_emit_footstep() -> void:
	var scene_root := Node2D.new()
	get_root().add_child(scene_root)

	var player := CharacterBody2D.new()
	player.set_script(PlayerMovementScript)
	player.global_position = Vector2(100, 100)
	
	scene_root.add_child(player)
	await process_frame

	var footstep_events: Array[NoiseEvent] = []
	var on_event = func(event: NoiseEvent) -> void:
		if event.type == &"footstep":
			footstep_events.append(event)
	var bus := NoiseBus.get_instance()
	bus.noise_emitted.connect(on_event)

	# Configura velocidade simulada mas sem deslocamento real (bloqueado por obstáculo)
	player.velocity = Vector2(150.0, 0.0)
	for i in 10:
		player._physics_process(0.1) # Mantem a mesma global_position
	
	_assert_true(footstep_events.is_empty(), "Jogador parado contra obstaculo nao deve emitir passos")

	bus.noise_emitted.disconnect(on_event)
	scene_root.free()


func _test_weapon_emits_gunshot_on_shoot() -> void:
	var scene_root := Node2D.new()
	get_root().add_child(scene_root)

	var weapon := WeaponScript.new()
	var muzzle := Marker2D.new()
	muzzle.name = "muzzle_marker"
	muzzle.position = Vector2(15, 0)
	weapon.add_child(muzzle)
	scene_root.add_child(weapon)
	weapon.global_position = Vector2(200, 200)
	await process_frame

	var gunshot_events: Array[NoiseEvent] = []
	var on_event = func(event: NoiseEvent) -> void:
		if event.type == &"gunshot":
			gunshot_events.append(event)
	var bus := NoiseBus.get_instance()
	bus.noise_emitted.connect(on_event)

	weapon.shoot(Vector2.RIGHT, 0.0)

	_assert_true(gunshot_events.size() == 1, "Disparo de arma deve emitir evento de gunshot")
	if not gunshot_events.is_empty():
		var gunshot_event := gunshot_events[0]
		_assert_true(gunshot_event.position == muzzle.global_position, "Posicao do som deve ser a do cano da arma")
		_assert_true(gunshot_event.radius >= 500.0, "Raio do tiro deve ser longo (>= 500px)")

	bus.noise_emitted.disconnect(on_event)
	scene_root.free()


func _test_bullet_emits_impact_on_collision() -> void:
	var scene_root := Node2D.new()
	get_root().add_child(scene_root)

	var bullet := BulletScript.new()
	bullet.collision_size = Vector2(6, 2)
	bullet.global_position = Vector2(350, 400)
	scene_root.add_child(bullet)
	await process_frame

	var impact_events: Array[NoiseEvent] = []
	var on_event = func(event: NoiseEvent) -> void:
		if event.type == &"bullet_impact":
			impact_events.append(event)
	var bus := NoiseBus.get_instance()
	bus.noise_emitted.connect(on_event)

	var obstacle := StaticBody2D.new()
	bullet._on_body_entered(obstacle)
	obstacle.free()

	_assert_true(impact_events.size() == 1, "Colisao do projetil deve emitir som de impacto")
	if not impact_events.is_empty():
		var impact_event := impact_events[0]
		_assert_true(impact_event.position == Vector2(350, 400), "Posicao do impacto deve ser a posicao do projetil")
		_assert_true(impact_event.radius >= 200.0, "Raio de impacto deve ser medio (>= 200px)")

	bus.noise_emitted.disconnect(on_event)
	scene_root.free()


func _test_noise_visualizer_registers_rings() -> void:
	var scene_root := Node2D.new()
	get_root().add_child(scene_root)

	var visualizer := NoiseVisualizerScript.new()
	scene_root.add_child(visualizer)
	await process_frame

	_assert_true(visualizer.get_active_ring_count() == 0, "Visualizer comeca sem aneis")

	NoiseBus.emit(Vector2(50, 50), 100.0, &"footstep")
	_assert_true(visualizer.get_active_ring_count() == 1, "Visualizer deve registrar anel ao ouvir evento")

	NoiseBus.emit(Vector2(100, 100), 500.0, &"gunshot")
	_assert_true(visualizer.get_active_ring_count() == 2, "Visualizer deve acumular múltiplos aneis")

	visualizer._process(2.0) # avancar tempo para expirar anéis
	_assert_true(visualizer.get_active_ring_count() == 0, "Aneis devem expirar apos sua duracao")

	scene_root.free()


func _test_noise_bus_history_and_query() -> void:
	NoiseBus.emit(Vector2(0, 0), 100.0, &"footstep")
	NoiseBus.emit(Vector2(50, 0), 300.0, &"gunshot")

	var nearby := NoiseBus.get_noises_in_range(Vector2(0, 0), 1.0, 5000.0)
	_assert_true(nearby.size() >= 2, "Ambos os sons alcancam o ponto (0,0)")

	var far_away := NoiseBus.get_noises_in_range(Vector2(5000, 5000), 1.0, 5000.0)
	_assert_true(far_away.size() == 0, "Ponto distante nao deve detectar os sons")


func _test_noise_bus_ttl_filtering() -> void:
	var bus := NoiseBus.get_instance()
	var old_event := NoiseEventScript.new(
		Vector2(0, 0),
		200.0,
		&"footstep",
		null,
		1.0,
		Time.get_ticks_msec() - 5000 # 5 segundos atrás
	)
	bus._recent_noises.append(old_event)

	# Query com TTL padrão de 1000ms (1 segundo)
	var fresh_noises := NoiseBus.get_noises_in_range(Vector2(0, 0), 1.0, 1000.0)
	var contains_old := false
	for n in fresh_noises:
		if n == old_event:
			contains_old = true
			break
	_assert_false(contains_old, "Evento antigo (> TTL) nao deve ser retornado na consulta")

	# Query com TTL desativado (-1)
	var all_noises := NoiseBus.get_noises_in_range(Vector2(0, 0), 1.0, -1.0)
	var contains_old_unfiltered := false
	for n in all_noises:
		if n == old_event:
			contains_old_unfiltered = true
			break
	_assert_true(contains_old_unfiltered, "Evento antigo deve ser retornado se TTL for desativado")


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
