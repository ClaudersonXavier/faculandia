class_name SaveJogo
## Fachada de save: monta e aplica o conteudo da partida, sabe qual caixa esta
## em uso, descreve um slot para a UI e centraliza as trocas de fase.
## Hoje o conteudo e so o EstadoDoJogo; o snapshot completo do mundo entra em
## _montar_secoes()/_aplicar(), sem mexer no SaveSlots nem nos call sites.

const CENA_CENARIO := "res://scenes/world/cena_principal.tscn"
const CENA_LOJA := "res://scenes/world/loja.tscn"
const CENA_MENU := "res://scenes/world/menu_principal.tscn"

## "Cenario" segue o glossario do CONTEXT.md, que marca "mundo" como termo a
## evitar. Nomes de exibicao ficam aqui, nunca gravados no save.
const NOMES_DE_CENA := {
	CENA_CENARIO: "Cenário",
	CENA_LOJA: "Loja",
}

## Caixa em que o botao Salvar grava. Static para sobreviver a troca de cena
## sem autoload novo. Default 1 para que rodar cena_principal.tscn direto do
## editor (F6) continue funcionando sem passar pelo menu.
static var _caixa_atual: int = 1


static func caixa_atual() -> int:
	return _caixa_atual


static func definir_caixa_atual(caixa: int) -> void:
	if caixa >= 1 and caixa <= SaveSlots.TOTAL_CAIXAS:
		_caixa_atual = caixa


static func existe_alguma_partida(prefixo: String = SaveSlots.PREFIXO_PADRAO) -> bool:
	for entrada: Dictionary in SaveSlots.listar(prefixo):
		if not bool(entrada["vazio"]):
			return true
	return false


## Comeca uma partida nova na caixa escolhida e devolve a cena a carregar.
## Reivindica a caixa na hora: sem isso ela ficaria "vazia" ate o primeiro
## Salvar, e o aviso de sobrescrita ficaria incoerente.
static func iniciar_nova_partida(caixa: int, prefixo: String = SaveSlots.PREFIXO_PADRAO) -> String:
	definir_caixa_atual(caixa)
	var estado := _estado()
	if estado != null:
		estado.reset()
	SaveSlots.gravar(caixa, _montar_secoes(CENA_CENARIO), prefixo)
	return CENA_CENARIO


static func salvar_na_caixa_atual(prefixo: String = SaveSlots.PREFIXO_PADRAO) -> bool:
	return SaveSlots.gravar(_caixa_atual, _montar_secoes(""), prefixo)


static func autosalvar(cena: String = "", prefixo: String = SaveSlots.PREFIXO_PADRAO) -> bool:
	return SaveSlots.gravar(SaveSlots.SLOT_AUTOSAVE, _montar_secoes(cena), prefixo)


## Aplica o slot no estado e devolve a cena a carregar ("" se nao deu).
static func carregar_slot(slot: int, prefixo: String = SaveSlots.PREFIXO_PADRAO) -> String:
	var dados := SaveSlots.ler(slot, prefixo)
	if dados.is_empty():
		return ""
	return _aplicar(dados)


## Unico caminho para trocar de fase: autossalva, despausa (SceneTree.paused
## sobrevive a troca de cena) e troca. Gancho do snapshot de mundo futuro.
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
	# No autosave, mostrar de qual caixa ele veio evita confusao.
	if slot == SaveSlots.SLOT_AUTOSAVE:
		return "%s — %s (slot %d)" % [nome, partes, int(meta.get("caixa_origem", 1))]
	return "%s — %s" % [nome, partes]


static func nome_da_cena(cena: String) -> String:
	return String(NOMES_DE_CENA.get(cena, "Fase"))


static func _montar_secoes(cena: String) -> Dictionary:
	var estado := _estado()
	if estado != null and not cena.is_empty():
		estado.cena = cena
	var conteudo: Dictionary = estado.to_dict() if estado != null else {}
	return {
		SaveSlots.SECAO_META: {"caixa_origem": _caixa_atual},
		"estado": conteudo,
	}


static func _aplicar(dados: Dictionary) -> String:
	var estado := _estado()
	if estado != null:
		estado.from_dict(dados.get("estado", {}))
	var meta: Dictionary = dados.get(SaveSlots.SECAO_META, {})
	definir_caixa_atual(int(meta.get("caixa_origem", _caixa_atual)))
	return estado.cena if estado != null else CENA_CENARIO


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
