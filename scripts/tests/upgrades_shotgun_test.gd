extends SceneTree
## Testa UpgradesShotgun isolado (sem cena/fisica, so logica pura).

const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")
const UpgradesShotgunScript := preload("res://scripts/weapons/upgrades_shotgun.gd")
const WeaponScript := preload("res://scripts/weapons/weapon.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_comprar_falha_sem_dinheiro()
	_test_comprar_falha_no_nivel_maximo()
	_test_comprar_deduz_e_incrementa()
	_test_comprar_reserva_atualiza_municao_maxima()
	_test_aplicar_em_shotgun_usa_niveis_corretos()
	_test_capacidade_tubo()
	_test_tempo_recarga()
	_test_nivel_fora_da_faixa_nao_estoura_indice()

	if failures > 0:
		printerr("%d teste(s) de upgrades_shotgun falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de upgrades_shotgun passaram com sucesso!")
		quit(0)


func _test_comprar_falha_sem_dinheiro() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 10  # custo do nivel 1 e' 20
	var ok := UpgradesShotgunScript.comprar(estado, UpgradesShotgunScript.Trilha.DANO)
	_assert_false(ok, "comprar deve falhar sem dinheiro suficiente")
	_assert_true(estado.shotgun_nivel_dano == 0, "nivel nao deve mudar quando a compra falha")
	_assert_true(estado.dinheiro == 10, "dinheiro nao deve ser descontado quando a compra falha")
	estado.free()


func _test_comprar_falha_no_nivel_maximo() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 10000
	estado.shotgun_nivel_tubo = UpgradesShotgunScript.NIVEL_MAXIMO
	var custo := UpgradesShotgunScript.custo_do_proximo_nivel(estado, UpgradesShotgunScript.Trilha.TUBO)
	_assert_true(custo == -1, "custo no nivel maximo deve ser -1")
	var ok := UpgradesShotgunScript.comprar(estado, UpgradesShotgunScript.Trilha.TUBO)
	_assert_false(ok, "comprar deve falhar no nivel maximo")
	_assert_true(estado.dinheiro == 10000, "dinheiro nao deve ser descontado no nivel maximo")
	estado.free()


func _test_comprar_deduz_e_incrementa() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 1000
	var ok1 := UpgradesShotgunScript.comprar(estado, UpgradesShotgunScript.Trilha.RECARGA)
	_assert_true(ok1, "primeira compra deveria funcionar")
	_assert_true(estado.shotgun_nivel_recarga == 1, "nivel_recarga deveria ser 1 (obtido %d)" % estado.shotgun_nivel_recarga)
	_assert_true(estado.dinheiro == 980, "deveria ter descontado 20 (obtido %d)" % estado.dinheiro)

	var ok2 := UpgradesShotgunScript.comprar(estado, UpgradesShotgunScript.Trilha.RECARGA)
	_assert_true(ok2, "segunda compra deveria funcionar")
	_assert_true(estado.shotgun_nivel_recarga == 2, "nivel_recarga deveria ser 2")
	_assert_true(estado.dinheiro == 950, "deveria ter descontado mais 30 (obtido %d)" % estado.dinheiro)
	estado.free()


func _test_comprar_reserva_atualiza_municao_maxima() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 1000
	_assert_true(estado.shotgun_reserva_maxima == 4, "reserva maxima inicial da shotgun deveria ser 4")
	UpgradesShotgunScript.comprar(estado, UpgradesShotgunScript.Trilha.RESERVA)
	_assert_true(estado.shotgun_reserva_maxima == 6, "reserva maxima deveria virar 6 no nivel 1 (obtido %d)" % estado.shotgun_reserva_maxima)
	UpgradesShotgunScript.comprar(estado, UpgradesShotgunScript.Trilha.RESERVA)
	_assert_true(estado.shotgun_reserva_maxima == 8, "reserva maxima deveria virar 8 no nivel 2 (obtido %d)" % estado.shotgun_reserva_maxima)
	estado.free()


func _test_aplicar_em_shotgun_usa_niveis_corretos() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.shotgun_nivel_dano = 1
	estado.shotgun_nivel_tubo = 2
	estado.shotgun_nivel_recarga = 3

	var arma: Weapon = WeaponScript.new()
	UpgradesShotgunScript.aplicar_em_shotgun(arma, estado)
	_assert_true(arma.damage_min == 4.0 and arma.damage_max == 6.0, "dano nivel 1 deveria ser 4-6 (obtido %.1f-%.1f)" % [arma.damage_min, arma.damage_max])
	_assert_true(arma.magazine_size == 4, "tubo nivel 2 deveria ser 4 (obtido %d)" % arma.magazine_size)
	_assert_true(is_equal_approx(arma.reload_time, 0.38), "recarga nivel 3 deveria ser 0.38 (obtido %.2f)" % arma.reload_time)
	estado.free()
	arma.free()


func _test_capacidade_tubo() -> void:
	var estado := EstadoDoJogoScript.new()
	_assert_true(UpgradesShotgunScript.capacidade_tubo(estado) == 2, "tubo base deve ser 2")
	estado.shotgun_nivel_tubo = 1
	_assert_true(UpgradesShotgunScript.capacidade_tubo(estado) == 3, "nivel 1 deve ser 3")
	estado.shotgun_nivel_tubo = 3
	_assert_true(UpgradesShotgunScript.capacidade_tubo(estado) == 5, "nivel 3 deve ser 5")
	estado.free()


func _test_tempo_recarga() -> void:
	var estado := EstadoDoJogoScript.new()
	_assert_true(is_equal_approx(UpgradesShotgunScript.tempo_recarga(estado), 0.75), "recarga base deve ser 0.75s")
	estado.shotgun_nivel_recarga = 1
	_assert_true(is_equal_approx(UpgradesShotgunScript.tempo_recarga(estado), 0.60), "nivel 1 deve ser 0.60s")
	estado.free()


func _test_nivel_fora_da_faixa_nao_estoura_indice() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.shotgun_nivel_dano = 99
	estado.shotgun_nivel_tubo = -50
	var arma: Weapon = WeaponScript.new()
	UpgradesShotgunScript.aplicar_em_shotgun(arma, estado)
	_assert_true(arma.damage_min == 6.0 and arma.damage_max == 8.0, "nivel 99 deveria clampar pro maximo (nivel 3), obtido %.1f-%.1f" % [arma.damage_min, arma.damage_max])
	_assert_true(arma.magazine_size == 2, "nivel -50 deveria clampar pro minimo (nivel 0), obtido %d" % arma.magazine_size)

	var custo := UpgradesShotgunScript.custo_do_proximo_nivel(estado, UpgradesShotgunScript.Trilha.DANO)
	_assert_true(custo == -1, "nivel 99 (clampado pro maximo) nao deveria ter custo pra comprar mais (obtido %d)" % custo)
	estado.free()
	arma.free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
