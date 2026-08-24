extends SceneTree

const AmeacaScene := preload("res://scenes/ameaca.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_tomar_dano_aciona_flash_visual()
	await _test_flash_visual_retorna_para_cor_base()
	await _test_multiplos_danos_reiniciam_flash()
	await _test_morte_da_ameaca_apos_dano_letal()
	await _test_sprite_orientacao_compensada_na_cena()
	await _test_ameaca_rotaciona_na_direcao_do_jogador()
	await _test_ameaca_mantem_rotacao_sem_direcao()
	await _test_ameaca_detecta_linha_de_visao_direta_livre_e_obstruida()
	await _test_ameaca_possui_navigation_agent_configurado()
	await _test_ameaca_para_ao_atingir_distancia_desejada()
	await _test_ameaca_busca_caminho_quando_visao_obstruida()
	await _test_ameaca_aplica_velocidade_segura_avoidance()
	await _test_ameaca_usa_modo_movimento_floating()
	await _test_ameaca_mascara_de_colisao_ignora_outras_ameacas()
	await _test_ameaca_navigation_agent_distancias_adequadas()
	await _test_multiplas_ameacas_possuem_separacao_suave_sem_picos()

	if failures > 0:
		printerr("%d teste(s) falharam" % failures)
		quit(1)
	else:
		print("Todos testes da ameaca passaram")
		quit(0)


func _create_fixture() -> Dictionary:
	var scene_root := Node2D.new()
	scene_root.name = "AmeacaTestFixture"
	scene_root.process_mode = Node.PROCESS_MODE_ALWAYS
	get_root().add_child(scene_root)

	var ameaca = AmeacaScene.instantiate()
	scene_root.add_child(ameaca)
	current_scene = scene_root
	return {"root": scene_root, "ameaca": ameaca}


func _test_tomar_dano_aciona_flash_visual() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	_assert_true(ameaca.modulate == Color.WHITE, "Ameaca inicia com modulacao branca padrao")

	ameaca.take_damage(8.0)

	_assert_true(
		ameaca.modulate == ameaca.hit_flash_color,
		"Modulacao da ameaca deve mudar para hit_flash_color imediatamente ao tomar dano"
	)

	fixture.root.queue_free()


func _test_flash_visual_retorna_para_cor_base() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	ameaca.take_damage(8.0)
	_assert_true(ameaca.modulate == ameaca.hit_flash_color, "Ameaca piscou ao tomar dano")

	# Espera passar a duracao do flash + margem
	var duration: float = ameaca.hit_flash_duration
	await create_timer(duration + 0.05).timeout

	_assert_true(
		ameaca.modulate.is_equal_approx(Color.WHITE),
		"Modulacao da ameaca deve retornar a Color.WHITE apos o tempo do flash"
	)

	fixture.root.queue_free()


func _test_multiplos_danos_reiniciam_flash() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	ameaca.take_damage(8.0)
	await create_timer(ameaca.hit_flash_duration * 0.5).timeout

	# Toma dano novamente durante o tween
	ameaca.take_damage(8.0)
	_assert_true(
		ameaca.modulate == ameaca.hit_flash_color,
		"Segundo dano deve reiniciar o flash para hit_flash_color imediatamente"
	)

	await create_timer(ameaca.hit_flash_duration + 0.05).timeout
	_assert_true(
		ameaca.modulate.is_equal_approx(Color.WHITE),
		"Apos o segundo dano, modulacao deve retornar para Color.WHITE"
	)

	fixture.root.queue_free()


func _test_morte_da_ameaca_apos_dano_letal() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	ameaca.take_damage(24.0)
	_assert_true(
		ameaca.modulate == ameaca.hit_flash_color,
		"Dano letal aciona hit flash antes da destruicao"
	)
	await create_timer(ameaca.hit_flash_duration + 0.05).timeout
	_assert_true(
		not is_instance_valid(ameaca) or ameaca.is_queued_for_deletion(),
		"Ameaca deve ser liberada apos finalizar o flash de dano letal"
	)

	if is_instance_valid(fixture.root):
		fixture.root.queue_free()


func _test_sprite_orientacao_compensada_na_cena() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	var sprite: Node2D = ameaca.get_node_or_null("AnimatedSprite2D")
	if sprite == null:
		sprite = ameaca.get_node_or_null("Sprite2D")
	_assert_true(sprite != null, "Ameaca deve possuir nó de sprite (AnimatedSprite2D ou Sprite2D)")
	if sprite:
		var expected_rotation: float = -PI / 2.0
		_assert_true(
			is_equal_approx(sprite.rotation, expected_rotation),
			"Sprite deve ter compensacao de rotacao de -90 graus (-PI/2), atual: %f" % sprite.rotation
		)

	fixture.root.queue_free()


func _test_ameaca_rotaciona_na_direcao_do_jogador() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fixture.root.add_child(fake_player)

	var scenarios: Array[Dictionary] = [
		{"target_pos": Vector2(200, 100), "expected_angle": 0.0, "desc": "direita"},
		{"target_pos": Vector2(100, 200), "expected_angle": PI / 2.0, "desc": "baixo"},
		{"target_pos": Vector2(100, 0), "expected_angle": -PI / 2.0, "desc": "cima"},
	]

	for scenario in scenarios:
		ameaca.global_position = Vector2(100, 100)
		fake_player.global_position = scenario.target_pos
		ameaca._physics_process(0.016)
		_assert_true(
			is_equal_approx(ameaca.rotation, scenario.expected_angle),
			"Rotacao da ameaca deve ser %f rad ao perseguir para %s" % [scenario.expected_angle, scenario.desc]
		)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_mantem_rotacao_sem_direcao() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	ameaca.rotation = 1.234
	ameaca.velocity = Vector2(50, 50)
	ameaca.target_player = null
	ameaca._physics_process(0.016)

	_assert_true(
		is_equal_approx(ameaca.rotation, 1.234),
		"Ameaca sem alvo/direcao valida deve preservar a ultima rotacao"
	)
	_assert_true(
		ameaca.velocity == Vector2.ZERO,
		"Ameaca sem alvo/direcao valida deve zerar a velocidade"
	)

func _test_ameaca_detecta_linha_de_visao_direta_livre_e_obstruida() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)

	# Cria uma parede intermediaria na camada 1 (LAYER_OBSTACULO)
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = Ameaca.LAYER_OBSTACULO
	obstacle.collision_mask = 0
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(40, 40)
	col_shape.shape = rect_shape
	obstacle.add_child(col_shape)
	obstacle.global_position = Vector2(200, 100)
	fixture.root.add_child(obstacle)

	await process_frame

	# Alvo com obstaculo entre ameaca (100, 100) e alvo (300, 100)
	var obstructed_pos := Vector2(300, 100)
	_assert_false(
		ameaca.has_direct_line_of_sight_to(obstructed_pos),
		"Ameaca nao deve ter linha de visao direta atraves de uma Parede/Obstaculo"
	)

	# Alvo livre acima
	var clear_pos := Vector2(100, 200)
	_assert_true(
		ameaca.has_direct_line_of_sight_to(clear_pos),
		"Ameaca deve ter linha de visao direta para posicao desobstruida"
	)

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_possui_navigation_agent_configurado() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	var nav_agent: NavigationAgent2D = ameaca.get_node_or_null("NavigationAgent2D")
	_assert_true(nav_agent != null, "Ameaca deve possuir um nó filho NavigationAgent2D")
	if nav_agent:
		_assert_true(nav_agent.target_desired_distance > 0.0, "NavigationAgent2D deve ter target_desired_distance configurado")

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_para_ao_atingir_distancia_desejada() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fixture.root.add_child(fake_player)

	# Posiciona ameaca muito proxima do player (dentro da distancia de parada)
	ameaca.global_position = Vector2(100, 100)
	fake_player.global_position = Vector2(105, 100) # 5px de distancia

	await process_frame
	ameaca._physics_process(0.016)

	_assert_true(
		ameaca.velocity == Vector2.ZERO,
		"Ameaca deve zerar velocidade quando estiver na distancia de parada do alvo"
	)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_busca_caminho_quando_visao_obstruida() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fixture.root.add_child(fake_player)

	ameaca.global_position = Vector2(100, 100)
	fake_player.global_position = Vector2(400, 100)

	# Cria obstaculo bloqueando a visao direta
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = Ameaca.LAYER_OBSTACULO
	obstacle.collision_mask = 0
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(50, 50)
	col_shape.shape = rect_shape
	obstacle.add_child(col_shape)
	obstacle.global_position = Vector2(250, 100)
	fixture.root.add_child(obstacle)

	await process_frame

	_assert_false(
		ameaca.has_direct_line_of_sight_to(fake_player.global_position),
		"Visao direta deve estar bloqueada pelo obstaculo"
	)

	# Executa passo de fisica
	ameaca._physics_process(0.016)

	var nav_agent: NavigationAgent2D = ameaca.get_node_or_null("NavigationAgent2D")
	_assert_true(nav_agent != null, "Ameaca deve ter NavigationAgent2D")
	if nav_agent:
		_assert_true(
			nav_agent.target_position == fake_player.global_position,
			"Ao ter visao bloqueada, ameaca deve definir a posicao do jogador como target_position do NavigationAgent2D"
		)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_aplica_velocidade_segura_avoidance() -> void:
	# Regression test: ameaca must actually move toward the player, not just face them.
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fixture.root.add_child(fake_player)

	ameaca.global_position = Vector2(100, 100)
	fake_player.global_position = Vector2(500, 100)
	await process_frame

	var initial_pos := ameaca.global_position
	for i in range(10):
		ameaca._physics_process(0.016)
		await process_frame

	var moved := initial_pos.distance_to(ameaca.global_position)
	_assert_true(
		moved > 1.0,
		"Ameaca deve se mover em direcao ao jogador (moveu %.2f px)" % moved
	)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_usa_modo_movimento_floating() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	_assert_true(
		ameaca.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING,
		"Ameaca deve usar MOTION_MODE_FLOATING para movimento top-down 2D, atual: %d" % ameaca.motion_mode
	)

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_mascara_de_colisao_ignora_outras_ameacas() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	_assert_true(
		(ameaca.collision_mask & Ameaca.LAYER_OBSTACULO) != 0,
		"Ameaca deve colidir com LAYER_OBSTACULO"
	)
	_assert_true(
		(ameaca.collision_mask & Ameaca.LAYER_JOGADOR) != 0,
		"Ameaca deve colidir com LAYER_JOGADOR"
	)
	_assert_true(
		(ameaca.collision_mask & Ameaca.LAYER_AMEACA) == 0,
		"Ameaca nao deve ter LAYER_AMEACA na collision_mask de fisica rigida (para evitar picos de velocidade por despenatracao)"
	)

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_navigation_agent_distancias_adequadas() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	await process_frame

	var nav_agent: NavigationAgent2D = ameaca.get_node_or_null("NavigationAgent2D")
	_assert_true(nav_agent != null, "NavigationAgent2D deve existir")
	if nav_agent:
		_assert_true(
			nav_agent.path_desired_distance >= 30.0,
			"path_desired_distance (%.1f) deve ser >= ao raio do colisor (30.0) para contornar quinas sem travar" % nav_agent.path_desired_distance
		)

	fixture.root.queue_free()
	await process_frame


func _test_multiplas_ameacas_possuem_separacao_suave_sem_picos() -> void:
	var scene_root := Node2D.new()
	scene_root.name = "SeparationTestFixture"
	scene_root.process_mode = Node.PROCESS_MODE_ALWAYS
	get_root().add_child(scene_root)

	var ameaca1: Ameaca = AmeacaScene.instantiate()
	var ameaca2: Ameaca = AmeacaScene.instantiate()
	ameaca1.debug_logging = false
	ameaca2.debug_logging = false

	# Posiciona ambas muito proximas (distancia 20px, menor que o raio combinado de 60px)
	ameaca1.global_position = Vector2(100, 100)
	ameaca2.global_position = Vector2(120, 100)
	scene_root.add_child(ameaca1)
	scene_root.add_child(ameaca2)

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fake_player.global_position = Vector2(500, 100)
	scene_root.add_child(fake_player)

	await process_frame
	ameaca1.set_physics_process(false)
	ameaca2.set_physics_process(false)

	var delta := 0.016
	for i in range(15):
		var p1_before := ameaca1.global_position
		var p2_before := ameaca2.global_position

		ameaca1._physics_process(delta)
		ameaca2._physics_process(delta)

		var speed1 := (ameaca1.global_position - p1_before).length() / delta
		var speed2 := (ameaca2.global_position - p2_before).length() / delta

		_assert_true(
			speed1 <= ameaca1.speed * 1.15,
			"Velocidade da Ameaca 1 (%.1f px/s) nao deve ultrapassar o limite maximo (%.1f px/s)" % [speed1, ameaca1.speed * 1.15]
		)
		_assert_true(
			speed2 <= ameaca2.speed * 1.15,
			"Velocidade da Ameaca 2 (%.1f px/s) nao deve ultrapassar o limite maximo (%.1f px/s)" % [speed2, ameaca2.speed * 1.15]
		)

	# A separacao deve ter afastado verticalmente ou mantido distancia saudavel entre elas
	var final_dist_y: float = absf(ameaca1.global_position.y - ameaca2.global_position.y)
	_assert_true(
		final_dist_y > 1.0 or ameaca1.global_position.distance_to(ameaca2.global_position) >= 20.0,
		"Ameacas devem aplicar separacao e nao se fundir em um unico ponto"
	)

	fake_player.remove_from_group(&"player")
	scene_root.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
