extends SceneTree

const SaveSlotsScript := preload("res://scripts/core/save_slots.gd")
const SaveJogoScript := preload("res://scripts/world/save_jogo.gd")
const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")
const ZonaPopuladorScript := preload("res://scripts/world/zona_populador.gd")

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
	_test_vida_round_trip_e_cai_para_padrao_quando_ausente()
	_test_niveis_de_upgrade_round_trip_e_caem_para_padrao_quando_ausentes()
	_test_shotgun_campos_round_trip()
	_test_shotgun_campos_faltantes_caem_no_padrao()
	_test_powerups_e_caixas_campos_round_trip()
	_test_powerups_e_caixas_faltantes_caem_no_padrao()
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
	_test_jogador_morreu_restaura_autosave_com_vida_cheia_no_hub()

	# --- ZonaPopulador (snapshot de mundo, secao "mundo" do save) ---
	_test_snapshot_de_dict_round_trip()
	_test_snapshot_ausente_cai_para_lista_vazia()
	_test_zona_malformada_nao_derruba_as_outras()
	_test_montar_secoes_inclui_secao_mundo()
	_test_aplicar_restaura_snapshots_em_memoria()
	_test_iniciar_nova_partida_limpa_snapshots_de_mundo()

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
	ZonaPopuladorScript.limpar_para_testes()


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


func _test_vida_round_trip_e_cai_para_padrao_quando_ausente() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({"vida": 2})
	_assert_true(estado.vida == 2, "vida presente deve ser aplicada (obtido: %d)" % estado.vida)
	estado.from_dict({})
	_assert_true(estado.vida == int(EstadoDoJogoScript.PADROES.vida), "vida ausente deve cair no padrao (obtido: %d)" % estado.vida)
	var dados := estado.to_dict()
	_assert_true(dados.has("vida"), "to_dict deve conter o campo 'vida'")
	estado.free()


func _test_niveis_de_upgrade_round_trip_e_caem_para_padrao_quando_ausentes() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({"nivel_dano": 2, "nivel_tambor": 1, "nivel_reserva": 3, "nivel_critico": 2})
	_assert_true(estado.nivel_dano == 2, "nivel_dano presente deve ser aplicado")
	_assert_true(estado.nivel_tambor == 1, "nivel_tambor presente deve ser aplicado")
	_assert_true(estado.nivel_reserva == 3, "nivel_reserva presente deve ser aplicado")
	_assert_true(estado.nivel_critico == 2, "nivel_critico presente deve ser aplicado")
	estado.from_dict({})
	_assert_true(estado.nivel_dano == 0, "nivel_dano ausente deve cair no padrao (0)")
	_assert_true(estado.nivel_tambor == 0, "nivel_tambor ausente deve cair no padrao (0)")
	_assert_true(estado.nivel_reserva == 0, "nivel_reserva ausente deve cair no padrao (0)")
	_assert_true(estado.nivel_critico == 0, "nivel_critico ausente deve cair no padrao (0)")
	var dados := estado.to_dict()
	for chave in ["nivel_dano", "nivel_tambor", "nivel_reserva", "nivel_critico"]:
		_assert_true(dados.has(chave), "to_dict deve conter o campo '%s'" % chave)
	estado.free()


func _test_shotgun_campos_round_trip() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({
		"shotgun_pente": 3,
		"shotgun_reserva": 8,
		"shotgun_reserva_maxima": 10,
		"possui_shotgun": true,
		"shotgun_nivel_dano": 2,
		"shotgun_nivel_tubo": 1,
		"shotgun_nivel_reserva": 3,
		"shotgun_nivel_recarga": 2,
		"arma_ativa": "shotgun",
	})
	_assert_true(estado.shotgun_pente == 3, "shotgun_pente deve ser preservado")
	_assert_true(estado.shotgun_reserva == 8, "shotgun_reserva deve ser preservado")
	_assert_true(estado.shotgun_reserva_maxima == 10, "shotgun_reserva_maxima deve ser preservado")
	_assert_true(estado.possui_shotgun == true, "possui_shotgun deve ser preservado")
	_assert_true(estado.shotgun_nivel_dano == 2, "shotgun_nivel_dano deve ser preservado")
	_assert_true(estado.shotgun_nivel_tubo == 1, "shotgun_nivel_tubo deve ser preservado")
	_assert_true(estado.shotgun_nivel_reserva == 3, "shotgun_nivel_reserva deve ser preservado")
	_assert_true(estado.shotgun_nivel_recarga == 2, "shotgun_nivel_recarga deve ser preservado")
	_assert_true(estado.arma_ativa == "shotgun", "arma_ativa deve ser preservado")

	var dict := estado.to_dict()
	var novo := EstadoDoJogoScript.new()
	novo.from_dict(dict)
	_assert_true(novo.possui_shotgun == true, "round trip to_dict/from_dict deve manter possui_shotgun")
	_assert_true(novo.shotgun_pente == 3, "round trip deve manter shotgun_pente")
	_assert_true(novo.arma_ativa == "shotgun", "round trip deve manter arma_ativa")
	estado.free()
	novo.free()


func _test_shotgun_campos_faltantes_caem_no_padrao() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({})
	_assert_true(estado.shotgun_pente == 0, "shotgun_pente default deve ser 0")
	_assert_true(estado.shotgun_reserva == 0, "shotgun_reserva default deve ser 0")
	_assert_true(estado.shotgun_reserva_maxima == 4, "shotgun_reserva_maxima default deve ser 4")
	_assert_true(estado.possui_shotgun == false, "possui_shotgun default deve ser false")
	_assert_true(estado.shotgun_nivel_dano == 0, "shotgun_nivel_dano default deve ser 0")
	_assert_true(estado.shotgun_nivel_tubo == 0, "shotgun_nivel_tubo default deve ser 0")
	_assert_true(estado.shotgun_nivel_reserva == 0, "shotgun_nivel_reserva default deve ser 0")
	_assert_true(estado.shotgun_nivel_recarga == 0, "shotgun_nivel_recarga default deve ser 0")
	_assert_true(estado.arma_ativa == "pistola", "arma_ativa default deve ser pistola")
	estado.free()


func _test_powerups_e_caixas_campos_round_trip() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({
		"powerup_lanterna_nivel": 2,
		"powerup_sapatos_nivel": 1,
		"powerup_boletim": true,
		"caixas_coletadas": ["zn_caixa_1", "zs_caixa_2"],
	})
	_assert_true(estado.powerup_lanterna_nivel == 2, "powerup_lanterna_nivel deve ser preservado")
	_assert_true(estado.powerup_sapatos_nivel == 1, "powerup_sapatos_nivel deve ser preservado")
	_assert_true(estado.powerup_boletim == true, "powerup_boletim deve ser preservado")
	_assert_true(estado.caixas_coletadas.size() == 2, "caixas_coletadas deve ter tamanho 2")
	_assert_true(estado.caixas_coletadas.has("zn_caixa_1"), "caixas_coletadas deve conter zn_caixa_1")

	var dict := estado.to_dict()
	var novo := EstadoDoJogoScript.new()
	novo.from_dict(dict)
	_assert_true(novo.powerup_lanterna_nivel == 2, "round trip deve manter powerup_lanterna_nivel")
	_assert_true(novo.powerup_sapatos_nivel == 1, "round trip deve manter powerup_sapatos_nivel")
	_assert_true(novo.powerup_boletim == true, "round trip deve manter powerup_boletim")
	_assert_true(novo.caixas_coletadas.size() == 2, "round trip deve manter caixas_coletadas")
	estado.free()
	novo.free()


func _test_powerups_e_caixas_faltantes_caem_no_padrao() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.from_dict({})
	_assert_true(estado.powerup_lanterna_nivel == 0, "powerup_lanterna_nivel default deve ser 0")
	_assert_true(estado.powerup_sapatos_nivel == 0, "powerup_sapatos_nivel default deve ser 0")
	_assert_true(estado.powerup_boletim == false, "powerup_boletim default deve ser false")
	_assert_true(estado.caixas_coletadas.is_empty(), "caixas_coletadas default deve ser vazio")
	estado.free()


func _test_reset_volta_para_padroes() -> void:
	var estado := EstadoDoJogoScript.new()
	estado.dinheiro = 999
	estado.municao_pente = 0
	estado.cena = CENA_LOJA
	estado.voltando_da_loja = true
	estado.vida = 1
	estado.reset()
	_assert_true(estado.dinheiro == 0, "reset deve zerar o dinheiro")
	_assert_true(estado.municao_pente == 7, "reset deve devolver o pente cheio")
	_assert_true(estado.cena == String(EstadoDoJogoScript.PADROES.cena), "reset deve voltar a cena inicial")
	_assert_false(estado.voltando_da_loja, "reset deve limpar as flags de transicao")
	_assert_true(estado.vida == int(EstadoDoJogoScript.PADROES.vida), "reset deve devolver a vida cheia")
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


func _test_jogador_morreu_restaura_autosave_com_vida_cheia_no_hub() -> void:
	_limpar()
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	estado.dinheiro = 55
	estado.vida = 3
	SaveJogoScript.autosalvar(SaveJogoScript.CENA_ZONA_NORTE, PREFIXO_TESTE)

	estado.vida = 0
	estado.dinheiro = 0
	SaveJogoScript.jogador_morreu(PREFIXO_TESTE)

	_assert_true(estado.vida == int(EstadoDoJogoScript.PADROES.vida), "jogador_morreu deve restaurar a vida cheia (obtido: %d)" % estado.vida)
	_assert_true(estado.dinheiro == 55, "jogador_morreu deve restaurar o dinheiro do ultimo autosave (obtido: %d)" % estado.dinheiro)
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


# --- ZonaPopulador ---

func _test_snapshot_de_dict_round_trip() -> void:
	var cena := SaveJogoScript.CENA_ZONA_NORTE
	var inimigos: Array = [
		{"id": 0, "pos": Vector2(10, 20), "estado": ZonaPopuladorScript.ESTADO_VIVO},
		{"id": 1, "pos": Vector2(30, 40), "estado": ZonaPopuladorScript.ESTADO_MORTO},
		{"id": 2, "pos": Vector2(50, 60), "estado": ZonaPopuladorScript.ESTADO_LOOTEADO},
	]
	_limpar()
	SaveSlotsScript.gravar(1, {"mundo": {cena: ZonaPopuladorScript.snapshot_para_dict(cena, inimigos)}}, PREFIXO_TESTE)
	var dados := SaveSlotsScript.ler(1, PREFIXO_TESTE)
	var restaurado: Array = ZonaPopuladorScript.snapshot_de_dict(dados.get("mundo", {}).get(cena, {}))
	_assert_true(restaurado.size() == 3, "snapshot deve preservar as 3 entradas (obtido: %d)" % restaurado.size())
	for i: int in range(3):
		_assert_true(int(restaurado[i]["id"]) == i, "id da entrada %d deve ser preservado" % i)
		_assert_true(restaurado[i]["pos"] == inimigos[i]["pos"], "posicao da entrada %d deve ser preservada" % i)
		_assert_true(restaurado[i]["estado"] == inimigos[i]["estado"], "estado da entrada %d deve ser preservado" % i)
	_limpar()


func _test_snapshot_ausente_cai_para_lista_vazia() -> void:
	_assert_true(ZonaPopuladorScript.snapshot_de_dict({}).is_empty(), "dict vazio deve cair para lista vazia")
	_assert_true(ZonaPopuladorScript.snapshot_de_dict({"gerado": false}).is_empty(), "gerado=false deve cair para lista vazia")
	_assert_true(ZonaPopuladorScript.snapshot_de_dict({"gerado": true, "inimigos": "nao e array"}).is_empty(), "inimigos malformado deve cair para lista vazia")
	# Regressao: dados[cena] pode nao ser nem um Dictionary (save editado a mao,
	# versao antiga) — antes disso, um valor assim quebrava com SCRIPT ERROR
	# (tipagem estrita do parametro) e derrubava o carregamento de TODAS as
	# outras zonas, nao so a malformada.
	_assert_true(ZonaPopuladorScript.snapshot_de_dict(123).is_empty(), "valor nao-Dictionary deve cair para lista vazia, sem erro")
	_assert_true(ZonaPopuladorScript.snapshot_de_dict("lixo").is_empty(), "String no lugar do dict da zona deve cair para lista vazia, sem erro")


func _test_zona_malformada_nao_derruba_as_outras() -> void:
	ZonaPopuladorScript.limpar_para_testes()
	var dados := {
		SaveJogoScript.CENA_ZONA_NORTE: 123,
		SaveJogoScript.CENA_ZONA_SUL: {"gerado": true, "inimigos": [{"id": 0, "pos": Vector2.ZERO, "estado": ZonaPopuladorScript.ESTADO_VIVO}]},
	}
	ZonaPopuladorScript.carregar_todos_snapshots_de_dict(dados)
	_assert_true(ZonaPopuladorScript.obter_snapshot(SaveJogoScript.CENA_ZONA_NORTE).is_empty(), "zona malformada deve cair para lista vazia")
	_assert_true(ZonaPopuladorScript.obter_snapshot(SaveJogoScript.CENA_ZONA_SUL).size() == 1, "zona valida no mesmo dict nao deve ser afetada pela malformada")
	ZonaPopuladorScript.limpar_para_testes()


func _test_montar_secoes_inclui_secao_mundo() -> void:
	_limpar()
	var cena := SaveJogoScript.CENA_ZONA_SUL
	var inimigos: Array = [{"id": 0, "pos": Vector2(1, 2), "estado": ZonaPopuladorScript.ESTADO_VIVO}]
	ZonaPopuladorScript.registrar_snapshot(cena, inimigos)
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	_assert_true(SaveJogoScript.autosalvar("", PREFIXO_TESTE), "autosalvar deve escrever com a secao mundo presente")
	var dados := SaveSlotsScript.ler(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE)
	var mundo: Dictionary = dados.get("mundo", {})
	_assert_true(mundo.has(cena), "secao mundo deve conter a zona registrada")
	var restaurado := ZonaPopuladorScript.snapshot_de_dict(mundo.get(cena, {}))
	_assert_true(restaurado.size() == 1, "snapshot gravado no autosave deve preservar a entrada registrada")
	_limpar()


func _test_aplicar_restaura_snapshots_em_memoria() -> void:
	_limpar()
	var cena := SaveJogoScript.CENA_ZONA_NORTE
	var inimigos: Array = [{"id": 0, "pos": Vector2(5, 6), "estado": ZonaPopuladorScript.ESTADO_MORTO}]
	ZonaPopuladorScript.registrar_snapshot(cena, inimigos)
	var estado: EstadoDoJogoScript = root.get_node(^"GameState")
	estado.reset()
	SaveJogoScript.autosalvar("", PREFIXO_TESTE)

	ZonaPopuladorScript.limpar_para_testes()
	_assert_false(ZonaPopuladorScript.tem_snapshot(cena), "snapshot deve estar limpo antes de carregar")

	SaveJogoScript.carregar_slot(SaveSlotsScript.SLOT_AUTOSAVE, PREFIXO_TESTE)
	_assert_true(ZonaPopuladorScript.tem_snapshot(cena), "carregar_slot deve repovoar o snapshot em memoria")
	var restaurado := ZonaPopuladorScript.obter_snapshot(cena)
	_assert_true(restaurado.size() == 1, "snapshot restaurado deve ter a mesma quantidade de entradas")
	_assert_true(restaurado[0]["estado"] == ZonaPopuladorScript.ESTADO_MORTO, "estado da entrada restaurada deve ser preservado")
	_limpar()


func _test_iniciar_nova_partida_limpa_snapshots_de_mundo() -> void:
	_limpar()
	var cena := SaveJogoScript.CENA_ZONA_NORTE
	# Simula que uma partida anterior registrou zumbis mortos
	var inimigos_mortos: Array = [
		{"id": 0, "pos": Vector2(100, 100), "estado": ZonaPopuladorScript.ESTADO_LOOTEADO},
		{"id": 1, "pos": Vector2(200, 200), "estado": ZonaPopuladorScript.ESTADO_LOOTEADO},
	]
	ZonaPopuladorScript.registrar_snapshot(cena, inimigos_mortos)
	_assert_true(ZonaPopuladorScript.tem_snapshot(cena), "deve ter snapshot registrado antes de novo jogo")

	# Inicia nova partida
	SaveJogoScript.iniciar_nova_partida(1, PREFIXO_TESTE)

	# Memoria deve estar limpa de snapshots da partida anterior
	_assert_false(ZonaPopuladorScript.tem_snapshot(cena), "iniciar_nova_partida deve limpar snapshots em memoria")

	# Disco do novo save deve ter secao mundo vazia
	var dados := SaveSlotsScript.ler(1, PREFIXO_TESTE)
	var mundo: Dictionary = dados.get("mundo", {})
	_assert_true(mundo.is_empty(), "novo jogo gravado em disco deve ter secao mundo vazia")

	_limpar()


# --- Helpers ---

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
