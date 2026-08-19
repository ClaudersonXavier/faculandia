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

	var sprite: Sprite2D = ameaca.get_node_or_null("Sprite2D")
	_assert_true(sprite != null, "Ameaca deve possuir nó Sprite2D")
	if sprite:
		var expected_rotation: float = -PI / 2.0
		_assert_true(
			is_equal_approx(sprite.rotation, expected_rotation),
			"Sprite2D deve ter compensacao de rotacao de -90 graus (-PI/2), atual: %f" % sprite.rotation
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

	fixture.root.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
