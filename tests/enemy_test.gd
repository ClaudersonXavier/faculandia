extends SceneTree

const EnemyScene := preload("res://scenes/enemy.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_tomar_dano_aciona_flash_visual()
	await _test_flash_visual_retorna_para_cor_base()
	await _test_multiplos_danos_reiniciam_flash()

	if failures > 0:
		printerr("%d teste(s) falharam" % failures)
		quit(1)
	else:
		print("Todos testes do inimigo passaram")
		quit(0)


func _create_fixture() -> Dictionary:
	var scene_root := Node2D.new()
	scene_root.name = "EnemyTestFixture"
	scene_root.process_mode = Node.PROCESS_MODE_ALWAYS
	get_root().add_child(scene_root)

	var enemy = EnemyScene.instantiate()
	scene_root.add_child(enemy)
	current_scene = scene_root
	return {"root": scene_root, "enemy": enemy}


func _test_tomar_dano_aciona_flash_visual() -> void:
	var fixture := _create_fixture()
	var enemy: Enemy = fixture.enemy
	await process_frame

	_assert_true(enemy.modulate == Color.WHITE, "Inimigo inicia com modulacao branca padrao")

	enemy.take_damage(8.0)

	_assert_true(
		enemy.modulate == enemy.hit_flash_color,
		"Modulacao do inimigo deve mudar para hit_flash_color imediatamente ao tomar dano"
	)

	fixture.root.queue_free()


func _test_flash_visual_retorna_para_cor_base() -> void:
	var fixture := _create_fixture()
	var enemy: Enemy = fixture.enemy
	await process_frame

	enemy.take_damage(8.0)
	_assert_true(enemy.modulate == enemy.hit_flash_color, "Inimigo piscou ao tomar dano")

	# Espera passar a duracao do flash + margem
	var duration: float = enemy.hit_flash_duration
	await create_timer(duration + 0.05).timeout

	_assert_true(
		enemy.modulate.is_equal_approx(Color.WHITE),
		"Modulacao do inimigo deve retornar a Color.WHITE apos o tempo do flash"
	)

	fixture.root.queue_free()


func _test_multiplos_danos_reiniciam_flash() -> void:
	var fixture := _create_fixture()
	var enemy: Enemy = fixture.enemy
	await process_frame

	enemy.take_damage(8.0)
	await create_timer(enemy.hit_flash_duration * 0.5).timeout

	# Toma dano novamente durante o tween
	enemy.take_damage(8.0)
	_assert_true(
		enemy.modulate == enemy.hit_flash_color,
		"Segundo dano deve reiniciar o flash para hit_flash_color imediatamente"
	)

	await create_timer(enemy.hit_flash_duration + 0.05).timeout
	_assert_true(
		enemy.modulate.is_equal_approx(Color.WHITE),
		"Apos o segundo dano, modulacao deve retornar para Color.WHITE"
	)

	fixture.root.queue_free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
