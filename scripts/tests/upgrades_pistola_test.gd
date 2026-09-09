extends SceneTree
## Testa UpgradesPistola isolado (sem cena/fisica, so logica pura).

const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")
const UpgradesPistolaScript := preload("res://scripts/weapons/upgrades_pistola.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_comprar_falha_sem_dinheiro()
	_test_comprar_falha_no_nivel_maximo()
	_test_comprar_deduz_e_incrementa()
	_test_comprar_reserva_atualiza_municao_maxima()
	_test_aplicar_em_pistola_usa_niveis_corretos()
	_test_nivel_fora_da_faixa_nao_estoura_indice()

	if failures > 0:
		printerr("%d teste(s) de upgrades_pistola falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de upgrades_pistola passaram com sucesso!")
		quit(0)


func _test_comprar_falha_sem_dinheiro() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 10  # custo do nivel 1 e' 15
	var ok := UpgradesPistolaScript.comprar(estado, UpgradesPistolaScript.Trilha.DANO)
	_assert_false(ok, "comprar deve falhar sem dinheiro suficiente")
	_assert_true(estado.nivel_dano == 0, "nivel nao deve mudar quando a compra falha")
	_assert_true(estado.dinheiro == 10, "dinheiro nao deve ser descontado quando a compra falha")
	estado.free()


func _test_comprar_falha_no_nivel_maximo() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 10000
	estado.nivel_tambor = UpgradesPistolaScript.NIVEL_MAXIMO
	var custo := UpgradesPistolaScript.custo_do_proximo_nivel(estado, UpgradesPistolaScript.Trilha.TAMBOR)
	_assert_true(custo == -1, "custo no nivel maximo deve ser -1")
	var ok := UpgradesPistolaScript.comprar(estado, UpgradesPistolaScript.Trilha.TAMBOR)
	_assert_false(ok, "comprar deve falhar no nivel maximo")
	_assert_true(estado.dinheiro == 10000, "dinheiro nao deve ser descontado no nivel maximo")
	estado.free()


func _test_comprar_deduz_e_incrementa() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 1000
	var ok1 := UpgradesPistolaScript.comprar(estado, UpgradesPistolaScript.Trilha.CRITICO)
	_assert_true(ok1, "primeira compra deveria funcionar")
	_assert_true(estado.nivel_critico == 1, "nivel_critico deveria ser 1 (obtido %d)" % estado.nivel_critico)
	_assert_true(estado.dinheiro == 985, "deveria ter descontado 15 (obtido %d)" % estado.dinheiro)

	var ok2 := UpgradesPistolaScript.comprar(estado, UpgradesPistolaScript.Trilha.CRITICO)
	_assert_true(ok2, "segunda compra deveria funcionar")
	_assert_true(estado.nivel_critico == 2, "nivel_critico deveria ser 2")
	_assert_true(estado.dinheiro == 965, "deveria ter descontado mais 20 (obtido %d)" % estado.dinheiro)
	estado.free()


func _test_comprar_reserva_atualiza_municao_maxima() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 1000
	_assert_true(estado.municao_reserva_maxima == 14, "reserva maxima inicial deveria ser 14 (padrao)")
	UpgradesPistolaScript.comprar(estado, UpgradesPistolaScript.Trilha.RESERVA)
	_assert_true(estado.municao_reserva_maxima == 21, "reserva maxima deveria virar 21 no nivel 1 (obtido %d)" % estado.municao_reserva_maxima)
	UpgradesPistolaScript.comprar(estado, UpgradesPistolaScript.Trilha.RESERVA)
	_assert_true(estado.municao_reserva_maxima == 28, "reserva maxima deveria virar 28 no nivel 2 (obtido %d)" % estado.municao_reserva_maxima)
	estado.free()


func _test_aplicar_em_pistola_usa_niveis_corretos() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.nivel_dano = 1
	estado.nivel_tambor = 2
	estado.nivel_critico = 3

	var arma := Weapon.new()
	UpgradesPistolaScript.aplicar_em_pistola(arma, estado)
	_assert_true(arma.damage_min == 8.0 and arma.damage_max == 10.0, "dano nivel 1 deveria ser 8-10 (obtido %.1f-%.1f)" % [arma.damage_min, arma.damage_max])
	_assert_true(arma.magazine_size == 9, "tambor nivel 2 deveria ser 9 (obtido %d)" % arma.magazine_size)
	_assert_true(arma.crit_chance == 0.30, "critico nivel 3 deveria ser 0.30 (obtido %.2f)" % arma.crit_chance)
	estado.free()
	arma.free()


## Regressao: um save corrompido/editado a mao com nivel_* fora de [0,3]
## (ex. save antigo de uma versao com mais niveis, ou edicao manual) nao
## pode estourar o indice das tabelas de valor e crashar o jogo inteiro.
func _test_nivel_fora_da_faixa_nao_estoura_indice() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.nivel_dano = 99
	estado.nivel_tambor = -50
	var arma := Weapon.new()
	UpgradesPistolaScript.aplicar_em_pistola(arma, estado)
	_assert_true(arma.damage_min == 10.0 and arma.damage_max == 12.0, "nivel 99 deveria clampar pro maximo (nivel 3), obtido %.1f-%.1f" % [arma.damage_min, arma.damage_max])
	_assert_true(arma.magazine_size == 7, "nivel -50 deveria clampar pro minimo (nivel 0), obtido %d" % arma.magazine_size)

	var custo := UpgradesPistolaScript.custo_do_proximo_nivel(estado, UpgradesPistolaScript.Trilha.DANO)
	_assert_true(custo == -1, "nivel 99 (clampado pro maximo) nao deveria ter custo pra comprar mais (obtido %d)" % custo)
	estado.free()
	arma.free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
