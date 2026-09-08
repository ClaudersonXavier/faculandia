class_name SaveSlots
## Mecanismo de slots de save: caminhos, escrita, leitura e metadados.
## Nao interpreta o conteudo da partida; cuida so do envelope ([meta] com
## versao e salvo_em) e do arquivo em disco. Por isso os testes desta camada
## rodam sem nenhum autoload.

const PREFIXO_PADRAO := "user://save_"
const SUFIXO := ".cfg"
const VERSAO: int = 1
const SLOT_AUTOSAVE: int = 0
const TOTAL_SLOTS: int = 3
const SECAO_META := "meta"


static func slots() -> Array[int]:
	var lista: Array[int] = [SLOT_AUTOSAVE]
	for slot: int in range(1, TOTAL_SLOTS + 1):
		lista.append(slot)
	return lista


static func e_slot_valido(slot: int) -> bool:
	return slot >= SLOT_AUTOSAVE and slot <= TOTAL_SLOTS


static func caminho(slot: int, prefixo: String = PREFIXO_PADRAO) -> String:
	if not e_slot_valido(slot):
		return ""
	if slot == SLOT_AUTOSAVE:
		return "%sauto%s" % [prefixo, SUFIXO]
	return "%sslot_%d%s" % [prefixo, slot, SUFIXO]


static func existe(slot: int, prefixo: String = PREFIXO_PADRAO) -> bool:
	var arq := caminho(slot, prefixo)
	return not arq.is_empty() and FileAccess.file_exists(arq)


## Grava as secoes de dominio, injetando o envelope. "secoes" e opaco aqui:
## {"estado": {...}} hoje, {"estado": {...}, "mapas": {...}} amanha.
static func gravar(slot: int, secoes: Dictionary, prefixo: String = PREFIXO_PADRAO) -> bool:
	var arq := caminho(slot, prefixo)
	if arq.is_empty():
		printerr("SaveSlots: slot invalido (%d)" % slot)
		return false
	var cfg := ConfigFile.new()
	cfg.set_value(SECAO_META, "versao", VERSAO)
	cfg.set_value(SECAO_META, "salvo_em", int(Time.get_unix_time_from_system()))
	for secao: String in secoes:
		var conteudo: Dictionary = secoes[secao]
		for chave: String in conteudo:
			cfg.set_value(secao, chave, conteudo[chave])
	var erro := cfg.save(arq)
	if erro != OK:
		printerr("SaveSlots: falha ao escrever %s (erro %d)" % [arq, erro])
		return false
	return true


## Devolve {secao: {chave: valor}} ou {} para slot vazio, arquivo corrompido
## ou versao incompativel. Unico validador da camada.
static func ler(slot: int, prefixo: String = PREFIXO_PADRAO) -> Dictionary:
	var arq := caminho(slot, prefixo)
	# Slot ausente nao emite aviso, para nao poluir o console na tela de selecao.
	if arq.is_empty() or not FileAccess.file_exists(arq):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(arq) != OK:
		printerr("SaveSlots: conteudo invalido em %s" % arq)
		return {}
	var versao := int(cfg.get_value(SECAO_META, "versao", 0))
	if versao <= 0 or versao > VERSAO:
		printerr("SaveSlots: versao incompativel em %s (%d, suportado ate %d)" % [arq, versao, VERSAO])
		return {}
	var dados := {}
	for secao: String in cfg.get_sections():
		var conteudo := {}
		for chave: String in cfg.get_section_keys(secao):
			conteudo[chave] = cfg.get_value(secao, chave)
		dados[secao] = conteudo
	return dados


static func apagar(slot: int, prefixo: String = PREFIXO_PADRAO) -> void:
	var arq := caminho(slot, prefixo)
	if arq.is_empty() or not FileAccess.file_exists(arq):
		return
	DirAccess.remove_absolute(arq)


## Metadados dos 4 slots sem carregar a partida. Sempre 4 entradas, na ordem
## [autosave, 1, 2, 3]; "dados" ja vem parseado para quem souber interpretar.
static func listar(prefixo: String = PREFIXO_PADRAO) -> Array[Dictionary]:
	var entradas: Array[Dictionary] = []
	for slot: int in slots():
		var dados := ler(slot, prefixo)
		var meta: Dictionary = dados.get(SECAO_META, {})
		entradas.append({
			"slot": slot,
			"vazio": dados.is_empty(),
			"salvo_em": int(meta.get("salvo_em", 0)),
			"dados": dados,
		})
	return entradas
