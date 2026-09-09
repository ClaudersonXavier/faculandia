extends SceneTree

const SaveSlotsScript := preload("res://scripts/core/save_slots.gd")
const SaveJogoScript := preload("res://scripts/world/save_jogo.gd")
const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")

const PREFIXO_TESTE := "user://teste_save_"
const CENA_LOJA := "res://scenes/world/loja.tscn"
const CENA_INEXISTENTE := "res://scenes/world/fase_que_nao_existe.tscn"

var failures := 0
var _estado_criado_pelo_teste: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_limpar()
	_garantir_estado()

	# --- SaveSlots (mecanismo, sem autoload) ---
	_test_slots_iniciam_vazios()
	_test_caminhos_dos_quatro_slots()
	_test_gravar_e_ler_conteudo_opaco()
	_test_sobrescrever_troca_conteudo()
	_test_apagar_volta_a_vazio_e_e_idempotente()
	_test_arquivo_corrompido_e_tratado_como_vazio()
	_test_versao_futura_e_rejeitada()
	_test_secoes_desconhecidas_nao_quebram_leitura()
	_test_metadados_sem_carregar_partida()

	# --- EstadoDoJogo (serializacao) ---
	_test_to_dict_espelha_padroes()
	_test_from_dict_usa_padroes_para_campos_faltando()
	_test_from_dict_preserva_tipos_inteiros()
	_test_estado_de_vida_faz_round_trip()
	_test_estado_de_vida_faltante_cai_no_padrao()
	_test_reset_volta_para_padroes()
	_test_cena_inexistente_cai_para_cena_inicial()

	# --- SaveJogo (fachada, com GameState garantido) ---
	_test_autosave_grava_no_slot_zero_com_slot_origem()
	_test_salvar_no_slot_atual_grava_no_slot_certo()
	_test_carregar_autosave_define_slot_atual_como_origem()
	_test_definir_slot_atual_invalido_e_ignorado()
	_test_iniciar_nova_partida_reseta_e_reivindica_o_slot()
	_test_carregar_slot_vazio_devolve_string_vazia()
	_test_carregar_save_mais_recente()
	_test_rotulo_de_slot_vazio_e_cheio()
	_test_nomes_de_cena_cobre_selecao()
	_test_iniciar_nova_partida_manda_para_selecao()

	_limpar()
	_liberar_estado()

	if failures > 0:
		printerr("%d teste(s) de save falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de save do GameState passaram com sucesso!")
		quit(0)


# --- Fixture ---

func _garantir_estado() -> void:
	var existente := root.get_node_or_null(^"GameState")
	if existente != null:
		return
	var estado := EstadoDoJogoScript.new()
	estado.name = "GameState"
	root.add_child(estado)
	_estado_criado_pelo_teste = true


func _liberar_estado() -> void:
	if not _estado_criado_pelo_teste:
		var existente := root.get_node_or_null(^"GameState")
		if existente != null:
			existente.reset()
		return
	var estado := root.get_node_or_null(^"GameState")
	if estado != null:
		estado.free()


func _limpar() -> void:
	for slot: int in SaveSlotsScript.slots():
		SaveSlotsScript.apagar(slot, PREFIXO_TESTE)


# --- SaveSlots ---

func _test_slots_iniciam_vazios() -> void:
	_limpar()
	var entradas := SaveSlotsScript.listar(PREFIXO_TESTE)
	_assert_true(entradas.size() == 4, "listar deve devolver 4 entradas (obtido: %d)" % entradas.size())
	for i: int in entradas.size():
		_assert_true(bool(entradas[i]["vazio"]), "slot %d deveria comecar vazio" % int(entradas[i]["slot"]))
	var esperado: Array[int] = [SaveSlotsScript.SLOT_AUTOSAVE, 1, 2, 3]
	for i: int in entradas.size():
		_assert_true(int(entradas[i]["slot"]) == esperado[i], "ordem dos slots deve ser [autosave,1,2,3]")


func _test_caminhos_dos_quatro_slots() -> void:
	var vistos := {}
	for slot: int in SaveSlotsScript.slots():
		vistos[SaveSlotsScript.caminho(slot, PREFIXO_TESTE)] = true
	_assert_true(vistos.size() == 4, "os 4 slots devem apontar para arquivos distintos")
	_assert_true(SaveSlotsScript.caminho(9, PREFIXO_TESTE) == "", "slot invalido (9) deve devolver caminho vazio")
	_assert_true(SaveSlotsScript.caminho(-1, PREFIXO_TESTE) == "", "slot invalido (-1) deve devolver caminho vazio")


func _test_gravar_e_ler_conteudo_opaco() -> void:
	_limpar()
	var gravado := SaveSlotsScript.gravar(1, {"estado": {"dinheiro": 42}}, PREFIXO_TESTE)
	_assert_true(gravado, "gravar deve retornar true em caminho valido")
	var dados := SaveSlotsScript.ler(1, PREFIXO_TESTE)
	_assert_false(dados.is_empty(), "ler deve devolver conteudo apos gravar")
	_assert_true(int(dados.get("meta", {}).get("versao", 0)) == SaveSlotsScript.VERSAO, "envelope deve conter a versao atual")
	_assert_true(int(dados.get("meta", {}).get("salvo_em", 0)) > 0, "envelope deve conter salvo_em maior que zero")
	_assert_true(int(dados.get("estado", {}).get("dinheiro", -1)) == 42, "conteudo de dominio deve ser preservado (opaco)")
	_limpar()


func _test_sobrescrever_troca_conteudo() -> void:
	_limpar()
	SaveSlotsScript.gravar(2, {"estado": {"dinheiro": 10}}, PREFIXO_TESTE)
	SaveSlotsScript.gravar(2, {"estado": {"dinheiro": 20}}, PREFIXO_TESTE)
	var dados := SaveSlotsScript.ler(2, PREFIXO_TESTE)
	_assert_true(int(dados.get("estado", {}).get("dinheiro", -1)) == 20, "a segunda gravacao deve vencer")
	_limpar()


func _test_apagar_volta_a_vazio_e_e_idempotente() -> void:
	_limpar()
	SaveSlotsScript.gravar(3, {"estado": {"dinheiro": 5}}, PREFIXO_TESTE)
	SaveSlotsScript.apagar(3, PREFIXO_TESTE)
	_assert_true(SaveSlotsScript.ler(3, PREFIXO_TESTE).is_empty(), "apagar deve esvaziar o slot")
	SaveSlotsScript.apagar(3, PREFIXO_TESTE) # nao deve crashar
	_assert_false(SaveSlotsScript.existe(3, PREFIXO_TESTE), "existe deve ser false apos apagar")


func _test_arquivo_corrompido_e_tratado_como_vazio() -> void:
	_limpar()
	var caminho := SaveSlotsScript.caminho(1, PREFIXO_TESTE)
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string("isso nao e um ini valido {{{")
	arquivo.close()
	_assert_true(SaveSlotsScript.ler(1, PREFIXO_TESTE).is_empty(), "arquivo corrompido deve ser tratado como vazio")
	_limpar()


func _test_versao_futura_e_rejeitada() -> void:
	_limpar()
	var caminho := SaveSlotsScript.caminho(2, PREFIXO_TESTE)
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "versao", 999)
	cfg.set_value("estado", "dinheiro", 123)
	cfg.save(caminho)
	_assert_true(SaveSlotsScript.ler(2, PREFIXO_TESTE).is_empty(), "versao futura deve ser rejeitada")
	var entradas := SaveSlotsScript.listar(PREFIXO_TESTE)
	_assert_true(bool(entradas[2]["vazio"]), "listar deve marcar slot de versao futura como vazio")
	_limpar()


func _test_secoes_desconhecidas_nao_quebram_leitura() -> void:
	## Trava a regressao de extensibilidade: um save de uma versao futura com
	## secoes que o codigo atual nao conhece ([mapas], [jogador]) continua
	## legivel, sem crashar e sem perder o que o codigo atual entende.
	_limpar()
	var caminho := SaveSlotsScript.caminho(1, PREFIXO_TESTE)
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "versao", SaveSlotsScript.VERSAO)
	cfg.set_value("meta", "salvo_em", int(Time.get_unix_time_from_system()))
	cfg.set_value("estado", "dinheiro", 77)
	cfg.set_value("estado", "campo_do_futuro", 1)
	cfg.set_value("mapas", "res://scenes/world/cena_principal.tscn", {"concluido": false})
	cfg.set_value("jogador", "posicao", Vector2(10, 20))
	cfg.save(caminho)
	var dados := SaveSlotsScript.ler(1, PREFIXO_TESTE)
	_assert_false(dados.is_empty(), "save com secoes desconhecidas deve continuar legivel")
	_assert_true(int(dados.get("estado", {}).get("dinheiro", -1)) == 77, "secao conhecida deve continuar acessivel")
	_assert_true(dados.has("mapas"), "secao desconhecida deve ser preservada na leitura bruta")
	_limpar()


func _test_metadados_sem_carregar_partida() -> void:
	_limpar()
	SaveSlotsScript.gravar(1, {"estado": {"dinheiro": 15, "cena": CENA_LOJA}}, PREFIXO_TESTE)
	var entradas := SaveSlotsScript.listar(PREFIXO_TESTE)
	var entrada_1: Dictionary = entradas[1]
	_assert_false(bool(entrada_1["vazio"]), "slot 1 gravado nao deve aparecer vazio")
	_assert_true(int(entrada_1["salvo_em"]) > 0, "metadados devem trazer salvo_em")
	_limpar()


# --- EstadoDoJogo ---

func _test_to_dict_espelha_padroes() -> void:
	var estado := EstadoDoJogoScript.new()
	var dados := estado.to_dict()
	for chave: String in EstadoDoJogoScript.PADROES:
		_assert_true(dados.has(chave), "to_dict deve conter o campo '%s'" % chave)
	estado.free()


func _test_from_dict_usa_padroes_para_campos_faltando() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({"dinheiro": 50})
	_assert_true(estado.dinheiro == 50, "campo presente deve ser aplicado (obtido: %d)" % estado.dinheiro)
	_assert_true(estado.municao_pente == 7, "campo ausente deve cair no padrao (prova compat. v1 -> v2)")
	_assert_true(estado.municao_reserva == 14, "campo ausente deve cair no padrao")
	estado.free()


func _test_from_dict_preserva_tipos_inteiros() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({"dinheiro": 120})
	_assert_true(typeof(estado.dinheiro) == TYPE_INT, "dinheiro deve continuar TYPE_INT apos from_dict")
	estado.free()


func _test_estado_de_vida_faz_round_trip() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.vida = 64.0
	estado.vida_maxima = 125.0
	var salvo := estado.to_dict()
	var restaurado := EstadoDoJogoScript.new()
	restaurado.from_dict(salvo)
	_assert_true(is_equal_approx(restaurado.vida, 64.0), "round-trip deve preservar a Vida atual")
	_assert_true(is_equal_approx(restaurado.vida_maxima, 125.0), "round-trip deve preservar a Vida maxima")
	estado.free()
	restaurado.free()


func _test_estado_de_vida_faltante_cai_no_padrao() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({})
	_assert_true(is_equal_approx(estado.vida, 100.0), "save antigo sem Vida deve usar 100.0")
	_assert_true(is_equal_approx(estado.vida_maxima, 100.0), "save antigo sem Vida maxima deve usar 100.0")
	estado.free()


func _test_reset_volta_para_padroes() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 999
	estado.municao_pente = 0
	estado.cena = CENA_LOJA
	estado.voltando_da_loja = true
	estado.reset()
	_assert_true(estado.dinheiro == 0, "reset deve zerar o dinheiro")
	_assert_true(estado.municao_pente == 7, "reset deve devolver o pente cheio")
	_assert_true(estado.cena == String(EstadoDoJogoScript.PADROES.cena), "reset deve voltar a cena inicial")
	_assert_false(estado.voltando_da_loja, "reset deve limpar as flags de transicao")
	estado.free()


func _test_cena_inexistente_cai_para_cena_inicial() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({"cena": CENA_INEXISTENTE})
	_assert_true(estado.cena == String(EstadoDoJogoScript.PADROES.cena), "cena obsoleta deve cair para a cena inicial")
	estado.free()


# --- SaveJogo ---

func _test_autosave_grava_no_slot_zero_com_slot_origem() -> void:
	_limpar()
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	SaveJogoScript.definir_slot_atual(2)
	estado.dinheiro = 77
	_assert_true(SaveJogoScript.autosalvar("", PREFIXO_TESTE), "autosalvar deve escrever o slot 0")
	var dados := SaveSlotsScript.ler(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE)
	_assert_false(dados.is_empty(), "slot de autosave deve estar preenchido")
	_assert_true(int(dados.get("meta", {}).get("slot_origem", -1)) == 2, "autosave deve registrar o slot_origem")
	_assert_true(SaveSlotsScript.ler(1, PREFIXO_TESTE).is_empty(), "autosave nao deve gravar no slot 1")
	_assert_true(SaveSlotsScript.ler(2, PREFIXO_TESTE).is_empty(), "autosave nao deve gravar no slot 2")
	_assert_true(SaveSlotsScript.ler(3, PREFIXO_TESTE).is_empty(), "autosave nao deve gravar no slot 3")
	_limpar()


func _test_salvar_no_slot_atual_grava_no_slot_certo() -> void:
	_limpar()
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	SaveJogoScript.definir_slot_atual(3)
	estado.dinheiro = 33
	_assert_true(SaveJogoScript.salvar_no_slot_atual(PREFIXO_TESTE), "salvar_no_slot_atual deve escrever")
	_assert_false(SaveSlotsScript.ler(3, PREFIXO_TESTE).is_empty(), "slot 3 deve estar preenchido")
	_assert_true(SaveSlotsScript.ler(1, PREFIXO_TESTE).is_empty(), "slot 1 nao deve ser afetado")
	_assert_true(SaveSlotsScript.ler(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE).is_empty(), "autosave nao deve ser afetado")
	_limpar()


func _test_carregar_autosave_define_slot_atual_como_origem() -> void:
	_limpar()
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	SaveJogoScript.definir_slot_atual(2)
	estado.dinheiro = 88
	SaveJogoScript.autosalvar("", PREFIXO_TESTE)

	SaveJogoScript.definir_slot_atual(1)
	estado.reset()
	var cena := SaveJogoScript.carregar_slot(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE)
	_assert_false(cena.is_empty(), "carregar_slot do autosave deve retornar uma cena")
	_assert_true(estado.dinheiro == 88, "estado deve ser restaurado pelo autosave")
	_assert_true(SaveJogoScript.slot_atual() == 2, "continuar pelo autosave deve restaurar o slot de origem (obtido: %d)" % SaveJogoScript.slot_atual())
	_limpar()


func _test_definir_slot_atual_invalido_e_ignorado() -> void:
	SaveJogoScript.definir_slot_atual(2)
	SaveJogoScript.definir_slot_atual(9)
	_assert_true(SaveJogoScript.slot_atual() == 2, "slot invalido nao deve ser aceito")
	SaveJogoScript.definir_slot_atual(-1)
	_assert_true(SaveJogoScript.slot_atual() == 2, "slot invalido nao deve ser aceito")


func _test_iniciar_nova_partida_reseta_e_reivindica_o_slot() -> void:
	_limpar()
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.dinheiro = 500
	var cena := SaveJogoScript.iniciar_nova_partida(3, PREFIXO_TESTE)
	_assert_true(cena == SaveJogoScript.CENA_SELECAO, "nova partida deve devolver o hub de selecao, nao uma zona direto")
	_assert_true(estado.dinheiro == 0, "nova partida deve resetar o estado")
	_assert_false(SaveSlotsScript.ler(3, PREFIXO_TESTE).is_empty(), "nova partida deve reivindicar o slot 3 imediatamente")
	_assert_true(SaveJogoScript.slot_atual() == 3, "slot atual deve ser o slot escolhido")
	_limpar()


func _test_carregar_slot_vazio_devolve_string_vazia() -> void:
	_limpar()
	var cena := SaveJogoScript.carregar_slot(1, PREFIXO_TESTE)
	_assert_true(cena.is_empty(), "carregar slot vazio deve devolver string vazia")


func _test_carregar_save_mais_recente() -> void:
	_limpar()
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	estado.dinheiro = 10
	SaveSlotsScript.gravar(SaveSlotsScript.SLOT_AUTOSAVE, {"estado": estado.to_dict()}, PREFIXO_TESTE)
	var auto_cfg := ConfigFile.new()
	auto_cfg.load(SaveSlotsScript.caminho(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE))
	auto_cfg.set_value("meta", "salvo_em", 100)
	auto_cfg.save(SaveSlotsScript.caminho(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE))

	# O slot manual e gravado depois com um timestamp explicitamente maior para
	# testar a selecao sem depender do relogio de parede do runner.
	estado.dinheiro = 20
	SaveSlotsScript.gravar(2, {"estado": estado.to_dict()}, PREFIXO_TESTE)
	var cfg := ConfigFile.new()
	cfg.load(SaveSlotsScript.caminho(2, PREFIXO_TESTE))
	cfg.set_value("meta", "salvo_em", 200)
	cfg.save(SaveSlotsScript.caminho(2, PREFIXO_TESTE))

	estado.dinheiro = 0
	var cena := SaveJogoScript.carregar_mais_recente(PREFIXO_TESTE)
	_assert_false(cena.is_empty(), "deve carregar o save mais recente")
	_assert_true(estado.dinheiro == 20, "deve aplicar o conteudo do save mais recente")
	_limpar()


func _test_rotulo_de_slot_vazio_e_cheio() -> void:
	_limpar()
	var entradas_vazias := SaveSlotsScript.listar(PREFIXO_TESTE)
	var rotulo_vazio := SaveJogoScript.rotulo(entradas_vazias[1])
	_assert_true(rotulo_vazio.find("vazia") != -1, "rotulo de slot vazio deve conter 'vazia' (obtido: '%s')" % rotulo_vazio)
	var rotulo_autosave_vazio := SaveJogoScript.rotulo(entradas_vazias[0])
	_assert_true(rotulo_autosave_vazio.find("vazio") != -1, "rotulo de autosave vazio deve conter 'vazio' (obtido: '%s')" % rotulo_autosave_vazio)

	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	estado.dinheiro = 120
	estado.municao_pente = 7
	estado.municao_reserva = 14
	SaveJogoScript.definir_slot_atual(2)
	SaveSlotsScript.gravar(2, {"meta": {"slot_origem": 2}, "estado": estado.to_dict()}, PREFIXO_TESTE)
	SaveSlotsScript.gravar(SaveSlotsScript.SLOT_AUTOSAVE, {"meta": {"slot_origem": 2}, "estado": estado.to_dict()}, PREFIXO_TESTE)

	var entradas := SaveSlotsScript.listar(PREFIXO_TESTE)
	var rotulo_cheio := SaveJogoScript.rotulo(entradas[2])
	_assert_true(rotulo_cheio.find("$120") != -1, "rotulo de slot cheio deve conter o dinheiro (obtido: '%s')" % rotulo_cheio)
	_assert_true(rotulo_cheio.find("Zona Norte") != -1, "rotulo de slot cheio deve conter o nome da cena (obtido: '%s')" % rotulo_cheio)
	_assert_true(rotulo_cheio.find("Slot 2") != -1, "rotulo de slot cheio deve identificar o slot (obtido: '%s')" % rotulo_cheio)

	var rotulo_auto := SaveJogoScript.rotulo(entradas[0])
	_assert_true(rotulo_auto.find("(slot") != -1, "rotulo do autosave deve indicar o slot de origem (obtido: '%s')" % rotulo_auto)
	_limpar()


func _test_nomes_de_cena_cobre_selecao() -> void:
	_assert_true(SaveJogoScript.NOMES_DE_CENA.has(SaveJogoScript.CENA_SELECAO), "NOMES_DE_CENA deve ter entrada para CENA_SELECAO")
	_assert_true(SaveJogoScript.NOMES_DE_CENA.has(SaveJogoScript.CENA_ZONA_SUL), "NOMES_DE_CENA deve ter entrada para CENA_ZONA_SUL")
	_assert_true(SaveJogoScript.nome_da_cena(SaveJogoScript.CENA_SELECAO) != "Fase", "nome_da_cena nao deve cair no fallback generico para CENA_SELECAO")


func _test_iniciar_nova_partida_manda_para_selecao() -> void:
	_limpar()
	var cena := SaveJogoScript.iniciar_nova_partida(1, PREFIXO_TESTE)
	_assert_true(cena == SaveJogoScript.CENA_SELECAO, "iniciar_nova_partida deve devolver CENA_SELECAO, nao uma zona direto")
	_limpar()


# --- Helpers ---

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
