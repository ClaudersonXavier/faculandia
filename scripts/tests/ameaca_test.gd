extends SceneTree

const AmeacaScene := preload("res://scenes/objects/ameaca.tscn")

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
	await _test_ameaca_ouve_som_dentro_do_raio()
	await _test_ameaca_ignora_som_fora_do_raio()
	await _test_ameaca_prioriza_visao_direta_sobre_som()
	await _test_ameaca_investiga_ultimo_ponto_ao_perder_visao()
	await _test_ameaca_vai_para_som_como_ia_para_jogador()
	await _test_ameaca_debug_visualizer_alterna_e_renderiza()
	await _test_ameaca_aplica_velocidade_segura_avoidance()
	await _test_ameaca_usa_modo_movimento_floating()
	await _test_ameaca_mascara_de_colisao_ignora_outras_ameacas()
	await _test_ameaca_navigation_agent_distancias_adequadas()
	await _test_multiplas_ameacas_possuem_separacao_suave_sem_picos()
	await _test_ameaca_contorna_quina_sem_travar()

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
		ameaca._is_dead,
		"Ameaca deve estar marcada como morta apos dano letal"
	)
	_assert_false(
		ameaca.is_physics_processing(),
		"Ameaca deve ter processamento fisico desativado apos morte"
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
	obstacle.collision_layer = PhysicsLayers.OBSTACULO
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
	obstacle.collision_layer = PhysicsLayers.OBSTACULO
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

	# Executa passo de fisica sem som: ameaca NAO se move cegamente ate o jogador
	ameaca._physics_process(0.016)

	var nav_agent: NavigationAgent2D = ameaca.get_node_or_null("NavigationAgent2D")
	_assert_true(nav_agent != null, "Ameaca deve ter NavigationAgent2D")
	_assert_false(
		ameaca.has_investigate_target(),
		"Ameaca nao deve possuir alvo de investigacao sem som e sem visao direta"
	)
	_assert_true(
		ameaca.velocity == Vector2.ZERO,
		"Ameaca sem visao direta e sem estimulo sonoro deve permanecer parada"
	)

	# Quando um som e emitido dentro do alcance de audicao, a ameaca se guia por ele
	NoiseBus.emit(fake_player.global_position, 500.0, &"gunshot", fake_player)
	ameaca._physics_process(0.016)

	_assert_true(
		ameaca.has_investigate_target(),
		"Ao ouvir som, ameaca deve adquirir alvo de investigacao"
	)
	if nav_agent:
		_assert_true(
			nav_agent.target_position == fake_player.global_position,
			"Ao ouvir som, ameaca deve definir a posicao do som como target_position do NavigationAgent2D"
		)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_ouve_som_dentro_do_raio() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)
	await process_frame

	# Emite som a 80px de distancia (raio do som 100px)
	var sound_pos := Vector2(180, 100)
	NoiseBus.emit(sound_pos, 100.0, &"footstep")

	_assert_true(
		ameaca.has_investigate_target(),
		"Ameaca deve registrar alvo de investigacao para som ouvido dentro do raio"
	)
	_assert_true(
		ameaca.get_investigate_target() == sound_pos,
		"Posicao de investigacao deve ser igual a posicao do som"
	)

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_ignora_som_fora_do_raio() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)
	await process_frame

	# Emite som a 300px de distancia (raio do som 100px)
	var sound_pos := Vector2(400, 100)
	NoiseBus.emit(sound_pos, 100.0, &"footstep")

	_assert_false(
		ameaca.has_investigate_target(),
		"Ameaca nao deve registrar alvo para som fora do raio audivel"
	)

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_prioriza_visao_direta_sobre_som() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fake_player.global_position = Vector2(200, 100) # Direita (sem obstaculo)
	fixture.root.add_child(fake_player)
	await process_frame

	_assert_true(
		ameaca.has_direct_vision_to_player(),
		"Ameaca deve ter visao direta para jogador desobstruido"
	)

	# Emite som em direcao oposta (cima)
	var sound_pos := Vector2(100, 0)
	NoiseBus.emit(sound_pos, 200.0, &"footstep")

	ameaca._physics_process(0.016)

	_assert_false(
		ameaca.has_investigate_target(),
		"Ameaca com visao direta para o jogador nao deve se desviar para som secundario"
	)
	_assert_true(
		is_equal_approx(ameaca.rotation, 0.0),
		"Ameaca deve continuar mirando para o jogador a sua direita"
	)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_investiga_ultimo_ponto_ao_perder_visao() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)

	var fake_player := Node2D.new()
	fake_player.add_to_group(&"player")
	fake_player.global_position = Vector2(200, 100)
	fixture.root.add_child(fake_player)
	await process_frame

	# Frame 1: Persegue com visao direta
	ameaca._physics_process(0.016)
	_assert_true(ameaca.has_direct_vision_to_player(), "Deve ter visao direta no frame 1")

	# Move jogador para tras de um obstaculo
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = PhysicsLayers.OBSTACULO
	obstacle.collision_mask = 0
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(50, 50)
	col_shape.shape = rect_shape
	obstacle.add_child(col_shape)
	obstacle.global_position = Vector2(150, 100)
	fixture.root.add_child(obstacle)
	await process_frame

	_assert_false(ameaca.has_direct_vision_to_player(), "Visao deve estar bloqueada")

	# Frame 2: Ameaca investiga o local onde o jogador estava no frame 1
	ameaca._physics_process(0.016)
	_assert_true(
		ameaca.has_investigate_target(),
		"Ameaca deve investigar a ultima posicao vista do jogador ao perder a visao direta"
	)
	_assert_true(
		ameaca.get_investigate_target() == Vector2(200, 100),
		"Posicao de investigacao deve ser a ultima posicao vista do jogador"
	)

	fake_player.remove_from_group(&"player")
	fixture.root.queue_free()
	await process_frame


func _test_ameaca_vai_para_som_como_ia_para_jogador() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)
	await process_frame

	# Emite som a direita (300, 100) sem obstaculo
	var sound_pos := Vector2(300, 100)
	NoiseBus.emit(sound_pos, 400.0, &"gunshot")

	_assert_true(ameaca.has_investigate_target(), "Ameaca registrou o som")
	
	# Executa passo de fisica: com linha direta ate o som, deve andar diretamente para a direita
	ameaca._physics_process(0.016)

	_assert_true(
		ameaca.velocity.x > 0.0 and is_equal_approx(ameaca.velocity.y, 0.0),
		"Ameaca deve mover-se diretamente para a posicao do som (vel: %s)" % str(ameaca.velocity)
	)
	_assert_true(
		is_equal_approx(ameaca.rotation, 0.0),
		"Rotacao da ameaca deve alinhar com a direcao do som"
	)

	fixture.root.queue_free()
	await process_frame


func _test_ameaca_debug_visualizer_alterna_e_renderiza() -> void:
	var fixture := _create_fixture()
	var ameaca: Ameaca = fixture.ameaca
	ameaca.global_position = Vector2(100, 100)
	await process_frame

	var visualizer: Node2D = ameaca._debug_visualizer
	_assert_true(visualizer != null, "Ameaca deve possuir nó visualizer de debug instanciado")

	# Garante estado inicial desligado
	Ameaca.AmeacaDebugVisualizerScript.debug_draw_enabled = false
	ameaca._physics_process(0.016)
	_assert_false(visualizer.visible, "Visualizer deve iniciar oculto quando debug esta desligado")

	# Ativa o modo de depuração (F2)
	Ameaca.AmeacaDebugVisualizerScript.toggle_debug()
	_assert_true(Ameaca.AmeacaDebugVisualizerScript.debug_draw_enabled, "debug_draw_enabled deve ser true apos toggle")

	ameaca._physics_process(0.016)
	_assert_true(visualizer.visible, "Visualizer deve ficar visivel apos toggle_debug ativo")

	# Desativa o modo de depuração (F2)
	Ameaca.AmeacaDebugVisualizerScript.toggle_debug()
	_assert_false(Ameaca.AmeacaDebugVisualizerScript.debug_draw_enabled, "debug_draw_enabled deve ser false apos segundo toggle")

	ameaca._physics_process(0.016)
	_assert_false(visualizer.visible, "Visualizer deve voltar a ficar oculto apos desativacao")

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
		(ameaca.collision_mask & PhysicsLayers.OBSTACULO) != 0,
		"Ameaca deve colidir com LAYER_OBSTACULO"
	)
	_assert_true(
		(ameaca.collision_mask & PhysicsLayers.JOGADOR) != 0,
		"Ameaca deve colidir com LAYER_JOGADOR"
	)
	_assert_true(
		(ameaca.collision_mask & PhysicsLayers.AMEACA) == 0,
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
			nav_agent.path_desired_distance <= 12.0,
			"path_desired_distance (%.1f) deve ser <= 12.0 para contornar quinas sem cortar caminho nas paredes" % nav_agent.path_desired_distance
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


func _test_ameaca_contorna_quina_sem_travar() -> void:
	var scene_root := Node2D.new()
	scene_root.name = "CornerTestFixture"
	get_root().add_child(scene_root)

	var nav_region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 24.0
	nav_poly.parsed_collision_mask = PhysicsLayers.OBSTACULO
	nav_poly.add_outline(PackedVector2Array([
		Vector2(0, 0),
		Vector2(600, 0),
		Vector2(600, 600),
		Vector2(0, 600)
	]))
	nav_region.navigation_polygon = nav_poly
	scene_root.add_child(nav_region)

	# Obstaculo formando quina em x=[200, 400], y=[200, 400]
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = PhysicsLayers.OBSTACULO
	obstacle.collision_mask = 0
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(200, 200)
	col_shape.shape = rect_shape
	obstacle.add_child(col_shape)
	obstacle.position = Vector2(300, 300)
	nav_region.add_child(obstacle)

	nav_region.bake_navigation_polygon()
	await physics_frame
	await physics_frame

	var ameaca: Ameaca = AmeacaScene.instantiate()
	ameaca.position = Vector2(150, 160)
	scene_root.add_child(ameaca)

	# Som localizado no lado direito inferior, do outro lado da quina
	var sound_pos := Vector2(450, 450)
	ameaca.investigate_sound(sound_pos)

	await physics_frame
	await physics_frame

	# Executa fisica por 30 frames
	for i in range(30):
		ameaca._physics_process(0.016)
		await physics_frame

	_assert_true(
		ameaca.global_position.distance_to(Vector2(150, 160)) > 25.0,
		"Ameaca deve progredir e contornar a quina (distancia percorrida: %.1f)" % ameaca.global_position.distance_to(Vector2(150, 160))
	)
	_assert_true(
		ameaca.velocity.length_squared() > 1.0,
		"Ameaca nao deve ficar com velocidade zerada e travada na quina"
	)

	scene_root.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
