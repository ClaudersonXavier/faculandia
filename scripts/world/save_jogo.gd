class_name SaveJogo
## Fachada de save: monta e aplica o conteudo da partida, sabe qual slot esta
## em uso, descreve um slot para a UI e centraliza as trocas de fase.
## O conteudo tem duas secoes: "estado" (EstadoDoJogo, campos flat) e "mundo"
## (ZonaPopulador, snapshot de Ameaca por zona — ver AGENTS.md, "Save Schema").

const CENA_ZONA_NORTE := "res://scenes/world/zona_norte.tscn"
const CENA_ZONA_SUL := "res://scenes/world/zona_sul.tscn"
const CENA_LOJA := "res://scenes/world/loja.tscn"
const CENA_MENU := "res://scenes/world/menu_principal.tscn"
const CENA_SELECAO := "res://scenes/world/selecao_de_cenario.tscn"

## Cena de teste/desenvolvimento — copia-origem de zona_norte.tscn, usada pelos
## testes automatizados (scripts/tests/player_vision_test.gd) e por um atalho
## secreto (F3) no hub para pular direto pra ela sem passar pelos cartoes.
## Nao faz parte do fluxo normal do jogador; nao entra em NOMES_DE_CENA.
const CENA_TESTE := "res://scenes/world/cena_principal.tscn"

## "Cenario" segue o glossario do CONTEXT.md, que marca "mundo"/"mapa" como
## termos a evitar. "Selecao de Cenario" e a tela de escolha de zona entre o
## menu e as fases (ver CONTEXT.md). Nomes de exibicao ficam aqui, nunca
## gravados no save.
const NOMES_DE_CENA := {
	CENA_ZONA_NORTE: "Zona Norte",
	CENA_ZONA_SUL: "Zona Sul",
	CENA_LOJA: "Loja",
	CENA_SELECAO: "Seleção de Zona",
}

## Slot em que o botao Salvar grava. Static para sobreviver a troca de cena
## sem autoload novo. Default 1 para que rodar cena_principal.tscn direto do
## editor (F6) continue funcionando sem passar pelo menu.
static var _slot_atual: int = 1


static func slot_atual() -> int:
	return _slot_atual


static func definir_slot_atual(slot: int) -> void:
	if slot >= 1 and slot <= SaveSlots.TOTAL_SLOTS:
		_slot_atual = slot


static func existe_alguma_partida(prefixo: String = SaveSlots.PREFIXO_PADRAO) -> bool:
	for entrada: Dictionary in SaveSlots.listar(prefixo):
		if not bool(entrada["vazio"]):
			return true
	return false


## Comeca uma partida nova no slot escolhido e devolve a cena a carregar.
## Reivindica o slot na hora: sem isso ele ficaria "vazio" ate o primeiro
## Salvar, e o aviso de sobrescrita ficaria incoerente.
static func iniciar_nova_partida(slot: int, prefixo: String = SaveSlots.PREFIXO_PADRAO) -> String:
	definir_slot_atual(slot)
	var estado := _estado()
	if estado != null:
		estado.reset()
	SaveSlots.gravar(slot, _montar_secoes(CENA_SELECAO), prefixo)
	return CENA_SELECAO


static func salvar_no_slot_atual(prefixo: String = SaveSlots.PREFIXO_PADRAO) -> bool:
	return SaveSlots.gravar(_slot_atual, _montar_secoes(""), prefixo)


static func autosalvar(cena: String = "", prefixo: String = SaveSlots.PREFIXO_PADRAO) -> bool:
	return SaveSlots.gravar(SaveSlots.SLOT_AUTOSAVE, _montar_secoes(cena), prefixo)


## Aplica o slot no estado e devolve a cena a carregar ("" se nao deu).
static func carregar_slot(slot: int, prefixo: String = SaveSlots.PREFIXO_PADRAO) -> String:
	var dados := SaveSlots.ler(slot, prefixo)
	if dados.is_empty():
		return ""
	return _aplicar(dados)


## Carrega o checkpoint com o maior timestamp entre autosave e slots manuais.
## Em empate, a ordem de listar() faz o slot manual mais alto prevalecer.
static func carregar_mais_recente(prefixo: String = SaveSlots.PREFIXO_PADRAO) -> String:
	var melhor_slot: int = -1
	var melhor_timestamp: int = -1
	for entrada: Dictionary in SaveSlots.listar(prefixo):
		if bool(entrada.get("vazio", true)):
			continue
		var timestamp := int(entrada.get("salvo_em", 0))
		if timestamp >= melhor_timestamp:
			melhor_timestamp = timestamp
			melhor_slot = int(entrada.get("slot", -1))
	if melhor_slot < 0:
		return ""
	return carregar_slot(melhor_slot, prefixo)


## Unico caminho para trocar de fase: autossalva (o que tambem captura o
## snapshot de Ameaca da zona atual, via _capturar_snapshot_da_cena_atual),
## despausa (SceneTree.paused sobrevive a troca de cena) e troca.
static func trocar_fase(cena: String) -> void:
	autosalvar(cena)
	var arvore := _arvore()
	if arvore == null:
		return
	arvore.paused = false
	arvore.change_scene_to_file(cena)


static func sair_para_o_menu() -> void:
	autosalvar()
	var arvore := _arvore()
	if arvore == null:
		return
	arvore.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arvore.change_scene_to_file(CENA_MENU)


## Recarrega o save mais recente entre autosave e slots manuais (sem salvar o
## momento da morte por cima — senao o jogador poderia "bancar" o estado do
## instante em que morreu), forca vida cheia por cima, e manda pro hub
## ignorando a cena que o autosave apontava — o jogador nao volta pra onde
## morreu, ele "acorda" na base.
static func jogador_morreu(prefixo: String = SaveSlots.PREFIXO_PADRAO) -> void:
	carregar_mais_recente(prefixo)
	var estado := _estado()
	if estado != null:
		estado.vida = float(EstadoDoJogo.PADROES.vida)
	var arvore := _arvore()
	if arvore == null:
		return
	arvore.paused = false
	arvore.change_scene_to_file(CENA_SELECAO)


## Texto do botao de um slot, derivado em runtime a partir de uma entrada de
## SaveSlots.listar(). Nada disso e gravado no arquivo.
static func rotulo(entrada: Dictionary) -> String:
	var slot := int(entrada.get("slot", -1))
	var nome := "Autosave" if slot == SaveSlots.SLOT_AUTOSAVE else "Slot %d" % slot
	if bool(entrada.get("vazio", true)):
		return "%s — %s" % [nome, "vazio" if slot == SaveSlots.SLOT_AUTOSAVE else "vazia"]
	var dados: Dictionary = entrada.get("dados", {})
	var estado: Dictionary = dados.get("estado", {})
	var meta: Dictionary = dados.get(SaveSlots.SECAO_META, {})
	var partes := "$%d · %d/%d · %s · %s" % [
		int(estado.get("dinheiro", 0)),
		int(estado.get("municao_pente", 0)),
		int(estado.get("municao_reserva", 0)),
		nome_da_cena(String(estado.get("cena", ""))),
		_data_hora(int(entrada.get("salvo_em", 0))),
	]
	# No autosave, mostrar de qual slot ele veio evita confusao.
	if slot == SaveSlots.SLOT_AUTOSAVE:
		return "%s — %s (slot %d)" % [nome, partes, int(meta.get("slot_origem", 1))]
	return "%s — %s" % [nome, partes]


static func nome_da_cena(cena: String) -> String:
	return String(NOMES_DE_CENA.get(cena, "Fase"))


static func _montar_secoes(cena: String) -> Dictionary:
	_capturar_snapshot_da_cena_atual()
	var estado := _estado()
	if estado != null and not cena.is_empty():
		estado.cena = cena
	var conteudo: Dictionary = estado.to_dict() if estado != null else {}
	return {
		SaveSlots.SECAO_META: {"slot_origem": _slot_atual},
		"estado": conteudo,
		"mundo": ZonaPopulador.todos_snapshots_para_dict(),
	}


static func _aplicar(dados: Dictionary) -> String:
	var estado := _estado()
	if estado != null:
		estado.from_dict(dados.get("estado", {}))
	ZonaPopulador.carregar_todos_snapshots_de_dict(dados.get("mundo", {}))
	var meta: Dictionary = dados.get(SaveSlots.SECAO_META, {})
	definir_slot_atual(int(meta.get("slot_origem", _slot_atual)))
	return estado.cena if estado != null else CENA_ZONA_NORTE


## Se uma zona jogavel estiver carregada agora (achavel pelo grupo
## "zona_mundo_sync"), atualiza o snapshot dela em memoria com o estado atual
## das Ameaca vivas na arvore, antes que a cena seja trocada e elas se percam.
## Sem zona carregada (loja, hub, menu), e um no-op — os snapshots ja
## registrados continuam validos como estao.
static func _capturar_snapshot_da_cena_atual() -> void:
	var arvore := _arvore()
	if arvore == null:
		return
	var sync := arvore.get_first_node_in_group(&"zona_mundo_sync")
	if sync == null:
		return
	var cena_id: String = sync.cena_id
	if not ZonaPopulador.tem_snapshot(cena_id):
		# ZonaMundoSync ainda nao terminou a geracao inicial (esta no meio do
		# await de fisica) — nao ha nada de valido pra capturar ainda. Sem essa
		# guarda, um trocar_fase disparado nesse instante registraria um
		# snapshot vazio e a zona ficaria selada como "gerada com 0 inimigos"
		# para sempre.
		return
	var anterior := ZonaPopulador.obter_snapshot(cena_id)
	ZonaPopulador.registrar_snapshot(cena_id, ZonaPopulador.capturar_snapshot(arvore, anterior))


## Time.get_unix_time_from_system() e get_datetime_dict_from_unix_time() sao
## UTC; soma o bias do sistema para o rotulo mostrar a hora local.
static func _data_hora(unix: int) -> String:
	if unix <= 0:
		return "--/-- --:--"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d/%02d %02d:%02d" % [int(d.day), int(d.month), int(d.hour), int(d.minute)]


static func _arvore() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Resolve por nome de no, e nao pelo global GameState, para funcionar em
## teste headless, onde o autoload pode nao existir.
static func _estado() -> EstadoDoJogo:
	var arvore := _arvore()
	if arvore == null or arvore.root == null:
		return null
	return arvore.root.get_node_or_null(^"GameState") as EstadoDoJogo
