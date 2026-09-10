extends SceneTree

const PlayerMovementScript := preload("res://scripts/player/player_moviment.gd")
const HudScript := preload("res://scripts/world/hud.gd")
const GameOverScene := preload("res://scenes/ui/game_over.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_vida_inicial_do_jogador()
	await _test_dano_respeita_invulnerabilidade()
	await _test_dano_letal_emite_morte_e_desativa_colisao()
	await _test_hud_exibe_vida()
	await _test_game_over_pausa_apos_morte()

	if failures > 0:
		printerr("%d teste(s) de Vida do jogador falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de Vida do jogador passaram com sucesso!")
		quit(0)


func _create_player_fixture() -> Dictionary:
	var root_node := Node2D.new()
	root_node.process_mode = Node.PROCESS_MODE_ALWAYS
	get_root().add_child(root_node)
	var game_state := get_root().get_node_or_null(^"GameState")
	if game_state != null:
		game_state.reset()

	var player = PlayerMovementScript.new()
	player.name = "Player"
	var collision := CollisionShape2D.new()
	collision.name = "player_collision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	player.add_child(collision)
	root_node.add_child(player)
	return {"root": root_node, "player": player, "collision": collision}


func _test_vida_inicial_do_jogador() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	await process_frame
	_assert_true(is_equal_approx(player.health, 100.0), "Jogador deve iniciar com 100 de Vida")
	_assert_true(is_equal_approx(player.max_health, 100.0), "Jogador deve iniciar com 100 de Vida maxima")
	fixture.root.queue_free()


func _test_dano_respeita_invulnerabilidade() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	await process_frame

	_assert_true(player.take_damage(8.0), "Primeiro golpe deve aplicar Dano")
	_assert_true(is_equal_approx(player.health, 92.0), "Primeiro golpe deve remover 8 de Vida")
	_assert_true(not player.take_damage(8.0), "Golpe dentro da invulnerabilidade deve ser ignorado")
	_assert_true(is_equal_approx(player.health, 92.0), "Invulnerabilidade deve impedir o segundo golpe")

	await create_timer(player.damage_invulnerability_duration + 0.05).timeout
	_assert_true(player.take_damage(8.0), "Golpe apos a invulnerabilidade deve aplicar Dano")
	_assert_true(is_equal_approx(player.health, 84.0), "Segundo golpe valido deve remover mais 8 de Vida")
	fixture.root.queue_free()


func _test_dano_letal_emite_morte_e_desativa_colisao() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	var mortes := [0]
	player.died.connect(func() -> void: mortes[0] += 1)
	await process_frame

	_assert_true(player.take_damage(100.0), "Dano letal deve ser aplicado")
	_assert_true(is_equal_approx(player.health, 0.0), "Vida nao pode ficar negativa")
	_assert_true(player.is_dead(), "Jogador deve ficar marcado como morto")
	_assert_true(mortes[0] == 1, "Jogador deve emitir o sinal de morte uma vez")
	await process_frame
	_assert_true(fixture.collision.disabled, "Colisao deve ser desativada apos a morte")
	fixture.root.queue_free()


func _test_hud_exibe_vida() -> void:
	var fixture := _create_player_fixture()
	var player = fixture.player
	await process_frame

	var hud := Control.new()
	hud.set_script(HudScript)
	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	hud.add_child(health_bar)
	var health_label := Label.new()
	health_label.name = "HealthLabel"
	hud.add_child(health_label)
	var dinheiro := Label.new()
	dinheiro.name = "DinheiroLabel"
	dinheiro.unique_name_in_owner = true
	hud.add_child(dinheiro)
	hud.player = player
	fixture.root.add_child(hud)
	await process_frame

	hud._process(0.016)
	_assert_true(is_equal_approx(health_bar.value, 100.0), "HUD deve preencher a barra com a Vida atual (obtido: %.1f)" % health_bar.value)
	_assert_true(health_label.text == "100 / 100", "HUD deve exibir Vida atual e maxima (obtido: '%s')" % health_label.text)
	player.take_damage(8.0)
	hud._process(0.016)
	_assert_true(is_equal_approx(health_bar.value, 92.0), "HUD deve atualizar a barra apos Dano (obtido: %.1f)" % health_bar.value)
	_assert_true(health_label.text == "92 / 100", "HUD deve atualizar o texto apos Dano (obtido: '%s')" % health_label.text)
	fixture.root.queue_free()


func _test_game_over_pausa_apos_morte() -> void:
	await process_frame
	var fixture := _create_player_fixture()
	var player = fixture.player
	var game_over = GameOverScene.instantiate()
	fixture.root.add_child(game_over)
	await process_frame

	player.take_damage(100.0)
	await process_frame
	_assert_true(paused, "Game Over deve pausar a partida")
	_assert_true(game_over.get_node("Painel").visible, "Game Over deve exibir o painel apos a morte")
	paused = false
	fixture.root.queue_free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)
