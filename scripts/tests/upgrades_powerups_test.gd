extends SceneTree
## Testa UpgradesPowerups isolado (sem cena/fisica, so logica pura).

const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")
const UpgradesPowerupsScript := preload("res://scripts/world/upgrades_powerups.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_comprar_lanterna_sucesso_e_limite()
	_test_comprar_sapatos_sucesso_e_limite()
	_test_comprar_cura()
	_test_comprar_boletim()

	if failures > 0:
		printerr("%d teste(s) de upgrades_powerups falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de upgrades_powerups passaram com sucesso!")
		quit(0)


func _test_comprar_lanterna_sucesso_e_limite() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 100
	_assert_true(UpgradesPowerupsScript.angulo_lanterna(estado) == 75.0, "Angulo inicial deve ser 75")
	_assert_true(UpgradesPowerupsScript.custo_do_proximo_nivel(estado, UpgradesPowerupsScript.Trilha.LANTERNA) == 20, "Custo do nivel 1 deve ser 20")

	var ok1 := UpgradesPowerupsScript.comprar(estado, UpgradesPowerupsScript.Trilha.LANTERNA)
	_assert_true(ok1, "Compra nivel 1 deve ter sucesso")
	_assert_true(estado.powerup_lanterna_nivel == 1, "Nivel deve ser 1")
	_assert_true(estado.dinheiro == 80, "Dinheiro deve ser 80")
	_assert_true(UpgradesPowerupsScript.angulo_lanterna(estado) == 95.0, "Angulo nivel 1 deve ser 95")

	# Compra niveis restantes ate o maximo
	UpgradesPowerupsScript.comprar(estado, UpgradesPowerupsScript.Trilha.LANTERNA) # nivel 2 ($30)
	UpgradesPowerupsScript.comprar(estado, UpgradesPowerupsScript.Trilha.LANTERNA) # nivel 3 ($40)
	_assert_true(estado.powerup_lanterna_nivel == 3, "Nivel deve ser 3 (maximo)")
	_assert_true(UpgradesPowerupsScript.custo_do_proximo_nivel(estado, UpgradesPowerupsScript.Trilha.LANTERNA) == -1, "Custo apos maximo deve ser -1")
	var ok_max := UpgradesPowerupsScript.comprar(estado, UpgradesPowerupsScript.Trilha.LANTERNA)
	_assert_false(ok_max, "Nao deve permitir comprar apos o nivel maximo")
	estado.free()


func _test_comprar_sapatos_sucesso_e_limite() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 100
	_assert_true(UpgradesPowerupsScript.recarga_dash(estado) == 0.0, "Sem sapatos recarga e 0 (bloqueado)")

	var ok1 := UpgradesPowerupsScript.comprar(estado, UpgradesPowerupsScript.Trilha.SAPATOS)
	_assert_true(ok1, "Compra sapatos nivel 1 deve ter sucesso")
	_assert_true(estado.powerup_sapatos_nivel == 1, "Nivel deve ser 1")
	_assert_true(UpgradesPowerupsScript.recarga_dash(estado) == 10.0, "Recarga nivel 1 deve ser 10s")

	var ok2 := UpgradesPowerupsScript.comprar(estado, UpgradesPowerupsScript.Trilha.SAPATOS)
	_assert_true(ok2, "Compra sapatos nivel 2 deve ter sucesso")
	_assert_true(estado.powerup_sapatos_nivel == 2, "Nivel deve ser 2")
	_assert_true(UpgradesPowerupsScript.recarga_dash(estado) == 5.0, "Recarga nivel 2 deve ser 5s")

	_assert_true(UpgradesPowerupsScript.custo_do_proximo_nivel(estado, UpgradesPowerupsScript.Trilha.SAPATOS) == -1, "Custo apos maximo deve ser -1")
	estado.free()


func _test_comprar_cura() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 30
	estado.vida = 40.0
	estado.vida_maxima = 100.0

	var ok := UpgradesPowerupsScript.comprar_cura(estado)
	_assert_true(ok, "Compra de cura deve ter sucesso quando ferido")
	_assert_true(estado.vida == 100.0, "Vida deve voltar ao maximo")
	_assert_true(estado.dinheiro == 15, "Dinheiro deve ser 15 apos compra de cura")

	var ok_cheia := UpgradesPowerupsScript.comprar_cura(estado)
	_assert_false(ok_cheia, "Nao deve comprar cura se ja estiver com vida cheia")
	_assert_true(estado.dinheiro == 15, "Dinheiro nao deve ser deduzido")
	estado.free()


func _test_comprar_boletim() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 50
	_assert_false(estado.powerup_boletim, "Boletim comeca como falso")

	var ok := UpgradesPowerupsScript.comprar_boletim(estado)
	_assert_true(ok, "Compra de boletim deve ter sucesso")
	_assert_true(estado.powerup_boletim, "Boletim deve ficar ativo")
	_assert_true(estado.dinheiro == 25, "Dinheiro deve ser 25")

	var ok_repetido := UpgradesPowerupsScript.comprar_boletim(estado)
	_assert_false(ok_repetido, "Nao deve poder comprar boletim mais de uma vez")
	estado.free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	if value:
		failures += 1
		printerr("FALHOU: %s" % message)
