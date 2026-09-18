extends SceneTree
## Testa a troca de armas (pistola <-> shotgun), disparos e recarga incremental da shotgun.

const PlayerScene := preload("res://scenes/objects/player.tscn")
const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")
const ShotgunScript := preload("res://scripts/weapons/shotgun.gd")
const UpgradesShotgunScript := preload("res://scripts/weapons/upgrades_shotgun.gd")

var failures := 0
var _estado_criado: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_garantir_estado()

	await _test_troca_bloqueada_sem_possuir_shotgun()
	await _test_troca_permitida_com_shotgun()
	await _test_tiro_da_shotgun_consome_municao_da_shotgun()
	await _test_recarga_incremental_da_shotgun()

	_liberar_estado()

	if failures > 0:
		printerr("%d teste(s) de troca de armas falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de troca de armas passaram com sucesso!")
		quit(0)


func _garantir_estado() -> EstadoDoJogo:
	var estado: EstadoDoJogo = root.get_node_or_null(^"GameState") as EstadoDoJogo
	if estado == null:
		estado = EstadoDoJogoScript.new()
		estado.name = "GameState"
		root.add_child(estado)
		_estado_criado = true
	estado.reset()
	return estado


func _liberar_estado() -> void:
	if _estado_criado:
		var estado = root.get_node_or_null(^"GameState")
		if estado:
			estado.free()
	else:
		var estado: EstadoDoJogo = root.get_node_or_null(^"GameState") as EstadoDoJogo
		if estado:
			estado.reset()


func _test_troca_bloqueada_sem_possuir_shotgun() -> void:
	var estado := _garantir_estado()
	estado.possui_shotgun = false
	estado.arma_ativa = "pistola"

	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	_assert_true(player.weapon != null, "Player deve ter arma inicial")
	_assert_true(player.weapon.weapon_name == "Pistola", "Arma inicial deve ser Pistola")

	player.trocar_arma("shotgun")
	await create_timer(0.4).timeout

	_assert_true(player.weapon.weapon_name == "Pistola", "Nao deve trocar para shotgun se nao possuir")
	_assert_true(estado.arma_ativa == "pistola", "arma_ativa continua pistola no GameState")

	player.queue_free()
	await process_frame


func _test_troca_permitida_com_shotgun() -> void:
	var estado := _garantir_estado()
	estado.possui_shotgun = true
	estado.shotgun_pente = 2
	estado.shotgun_reserva = 4
	estado.arma_ativa = "pistola"

	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	_assert_true(player.weapon.weapon_name == "Pistola", "Comeca com pistola")

	player.trocar_arma("shotgun")
	_assert_true(player._trocando_arma, "Deve entrar em estado _trocando_arma")

	await create_timer(0.4).timeout

	_assert_false(player._trocando_arma, "Deve finalizar troca")
	_assert_true(player.weapon.weapon_name == "Escopeta", "Arma ativa agora e' Escopeta")
	_assert_true(estado.arma_ativa == "shotgun", "GameState reflete arma_ativa = shotgun")

	# Troca de volta para pistola
	player.trocar_arma("pistola")
	await create_timer(0.4).timeout
	_assert_true(player.weapon.weapon_name == "Pistola", "Voltou para Pistola")

	player.queue_free()
	await process_frame


func _test_tiro_da_shotgun_consome_municao_da_shotgun() -> void:
	var estado := _garantir_estado()
	estado.possui_shotgun = true
	estado.municao_pente = 7
	estado.shotgun_pente = 2
	estado.shotgun_reserva = 4
	estado.arma_ativa = "shotgun"

	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	_assert_true(player.weapon.weapon_name == "Escopeta", "Nasceu com shotgun ativa")
	_assert_true(player.weapon.current_ammo == 2, "Municao inicial da shotgun = 2")

	player.weapon.shoot(Vector2.RIGHT, 0.0)

	_assert_true(player.weapon.current_ammo == 1, "Municao no pente da shotgun decrementou para 1")
	_assert_true(estado.shotgun_pente == 1, "GameState.shotgun_pente sincronizado para 1")
	_assert_true(estado.municao_pente == 7, "Municao da pistola nao foi afetada")

	player.queue_free()
	await process_frame


func _test_recarga_incremental_da_shotgun() -> void:
	var estado := _garantir_estado()
	estado.possui_shotgun = true
	estado.shotgun_pente = 0
	estado.shotgun_reserva = 2
	estado.shotgun_nivel_tubo = 0 # max 2
	estado.arma_ativa = "shotgun"

	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	player.weapon.reload()
	_assert_true(player.weapon.is_reloading, "Shotgun entrou em recarga")

	# Espera o tempo de 1 cartucho (0.75s + folga)
	await create_timer(0.85).timeout
	_assert_true(player.weapon.current_ammo >= 1, "Recarregou pelo menos 1 cartucho")

	# Espera o segundo cartucho
	await create_timer(0.85).timeout
	_assert_true(player.weapon.current_ammo == 2, "Recarregou 2 cartuchos completamente")
	_assert_false(player.weapon.is_reloading, "Terminou recarga")
	_assert_true(estado.shotgun_reserva == 0, "Reserva da shotgun zerou")

	player.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
