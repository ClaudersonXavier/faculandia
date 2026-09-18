class_name ZonaPopulador
## Fachada estatica: gera e persiste a populacao de Ameaca de cada zona.
## Ver AGENTS.md, secao "Save Schema" (adendo sobre a secao "mundo" do save).

const AMEACA_SCENE: PackedScene = preload("res://scenes/objects/ameaca.tscn")
const AMEACA_RAPIDA_SCENE: PackedScene = preload("res://scenes/objects/ameaca_rapida.tscn")

const TIPO_PADRAO := "padrao"
const TIPO_RAPIDA := "rapida"

const NUM_INIMIGOS := 30
const RAIO_EXCLUSAO_SPAWN_JOGADOR := 180.0
## Deve bater com Ameaca.vision_range (scripts/enemies/ameaca.gd) — usado pra
## rejeitar candidatos que teriam linha de visao livre ate o spawn do jogador
## (ver gerar_posicoes). So a distancia (RAIO_EXCLUSAO_SPAWN_JOGADOR) nao e
## suficiente: e bem menor que o alcance de visao, entao uma ameaca podia
## nascer fora do raio de exclusao mas ainda perfeitamente visivel — e sem
## paredes no caminho (ex. Zona Sul, que ainda nao tem tileset pintado), ja
## comecava perseguindo o jogador sem ele andar ou fazer barulho.
const RAIO_VISAO_INIMIGO := 380.0
const RAIO_CORPO := 14.0
const DISTANCIA_MINIMA_ENTRE_INIMIGOS := 40.0
const MARGEM_DOS_LIMITES := 32.0
const MAX_TENTATIVAS_POR_INIMIGO := 40
## Ao voltar pra uma zona ja visitada, Ameaca vivas que ficaram a menos disso
## da saida sao reposicionadas — sem isso, se o jogador saiu cercado, ele
## reentra cercado de novo no mesmo lugar (ver dar_folga_para_vivos_perto_da_saida).
const RAIO_FOLGA_AO_VOLTAR := 400.0
## Mais folga de tentativas que MAX_TENTATIVAS_POR_INIMIGO: reposicionar ao
## voltar e uma operacao rara (uma troca de fase, nao 30 de uma vez) e mais
## restrita (tem que ficar fora do raio de folga E nao empilhar em cima das
## outras 29 ja ocupando o mapa), entao vale gastar mais tentativas pra nao
## deixar ninguem perto da saida por falta de sorte no sorteio.
const MAX_TENTATIVAS_FOLGA := 150

const ESTADO_VIVO := "vivo"
const ESTADO_MORTO := "morto_com_corpo"
const ESTADO_LOOTEADO := "looteado"

## Cache em memoria, sobrevive a change_scene_to_file (mesmo truque de
## SaveJogo._slot_atual). {cena_path: Array[Dictionary]}
static var _snapshots: Dictionary = {}


static func tem_snapshot(cena: String) -> bool:
	return _snapshots.has(cena)


static func obter_snapshot(cena: String) -> Array:
	return _snapshots.get(cena, [])


static func registrar_snapshot(cena: String, inimigos: Array) -> void:
	_snapshots[cena] = inimigos


static func limpar_todos_snapshots() -> void:
	_snapshots.clear()


static func limpar_para_testes() -> void:
	limpar_todos_snapshots()


static func todos_snapshots_para_dict() -> Dictionary:
	var resultado := {}
	for cena: String in _snapshots.keys():
		resultado[cena] = snapshot_para_dict(cena, _snapshots[cena])
	return resultado


## dados pode conter lixo (save editado a mao, versao antiga, arquivo
## corrompido) — cada chave e validada isoladamente, entao uma zona malformada
## nao pode derrubar as outras.
static func carregar_todos_snapshots_de_dict(dados: Dictionary) -> void:
	_snapshots.clear()
	for cena: String in dados.keys():
		_snapshots[cena] = snapshot_de_dict(dados[cena])


static func snapshot_para_dict(_cena: String, inimigos: Array) -> Dictionary:
	return {"gerado": true, "inimigos": inimigos}


## dados e Variant (nao Dictionary) de proposito: pode vir de um save
## corrompido/editado a mao, e um tipo errado aqui nao pode derrubar o
## carregamento das outras zonas (ver carregar_todos_snapshots_de_dict).
static func snapshot_de_dict(dados: Variant) -> Array:
	if not (dados is Dictionary) or not dados.get("gerado", false):
		return []
	var inimigos: Variant = dados.get("inimigos", [])
	if not (inimigos is Array):
		return []
	var validos: Array = []
	for entrada: Variant in inimigos:
		if entrada is Dictionary and entrada.has("id") and entrada.has("pos") and entrada.has("estado"):
			validos.append(entrada)
	return validos


static func _posicao_e_valida(
	space_state: PhysicsDirectSpaceState2D,
	candidato: Vector2,
	exclusao_pos: Vector2,
	exclusao_raio_sq: float,
	ocupadas: Array,
	min_dist_sq: float,
	mask: int
) -> bool:
	if candidato.distance_squared_to(exclusao_pos) < exclusao_raio_sq:
		return false
	if candidato.distance_squared_to(exclusao_pos) < RAIO_VISAO_INIMIGO * RAIO_VISAO_INIMIGO \
			and PhysicsUtils.has_clear_line(space_state, candidato, exclusao_pos, mask):
		# Dentro do alcance de visao de uma Ameaca E sem parede no meio:
		# enxergaria o jogador de cara. Rejeita, mesmo fora do raio de
		# exclusao de proximidade acima.
		return false
	if not PhysicsUtils.is_position_clear(space_state, candidato, RAIO_CORPO, mask):
		return false
	for existente: Vector2 in ocupadas:
		if candidato.distance_squared_to(existente) < min_dist_sq:
			return false
	return true


## Sorteia ate max_tentativas candidatos dentro de area e devolve o primeiro
## valido (fora do raio de exclusao/visao/obstaculo/aglomeracao — ver
## _posicao_e_valida), ou null se nao achar nenhum.
static func _sortear_candidato_valido(
	space_state: PhysicsDirectSpaceState2D,
	area: Rect2,
	exclusao_pos: Vector2,
	exclusao_raio_sq: float,
	ocupadas: Array,
	min_dist_sq: float,
	mask: int,
	max_tentativas: int = MAX_TENTATIVAS_POR_INIMIGO
) -> Variant:
	for _tentativa in range(max_tentativas):
		var candidato := Vector2(
			randf_range(area.position.x, area.end.x),
			randf_range(area.position.y, area.end.y)
		)
		if _posicao_e_valida(space_state, candidato, exclusao_pos, exclusao_raio_sq, ocupadas, min_dist_sq, mask):
			return candidato
	return null


## Rejection sampling: sorteia posicoes dentro de bounds, evitando o raio de
## exclusao ao redor do spawn do jogador, sobreposicao com obstaculos (query
## de fisica em runtime — o tileset de paredes nao tem colisao por-tile
## confiavel o bastante pra validar isso so lendo dados estaticos) e
## aglomeracao entre si. Se nao achar posicao valida pra algum inimigo apos
## MAX_TENTATIVAS_POR_INIMIGO tentativas, pula essa posicao (o array final
## pode sair com menos de NUM_INIMIGOS) em vez de travar ou crashar.
static func gerar_posicoes(
	space_state: PhysicsDirectSpaceState2D,
	bounds: Rect2,
	exclusao_pos: Vector2,
	exclusao_raio: float,
	quantidade: int,
	mask: int
) -> Array:
	var resultado: Array = []
	var area := bounds.grow(-MARGEM_DOS_LIMITES)
	var exclusao_raio_sq := exclusao_raio * exclusao_raio
	var min_dist_sq := DISTANCIA_MINIMA_ENTRE_INIMIGOS * DISTANCIA_MINIMA_ENTRE_INIMIGOS
	for i in range(quantidade):
		var candidato: Variant = _sortear_candidato_valido(space_state, area, exclusao_pos, exclusao_raio_sq, resultado, min_dist_sq, mask)
		if candidato == null:
			push_warning("ZonaPopulador: nao encontrou posicao valida para inimigo %d apos %d tentativas" % [i, MAX_TENTATIVAS_POR_INIMIGO])
			continue
		resultado.append(candidato)
	return resultado


## Ao restaurar uma zona ja visitada, afasta Ameaca vivas que ficaram a menos
## de RAIO_FOLGA_AO_VOLTAR da saida — sem isso, se o jogador saiu cercado de
## zumbis, ele reentra cercado de novo bem na porta. So mexe em ESTADO_VIVO:
## corpos mortos (ESTADO_MORTO) ficam exatamente onde morreram, pro loot
## continuar fazendo sentido visualmente; ja lootados nao tem posicao
## relevante. Reusa as mesmas regras de gerar_posicoes (fora de obstaculo,
## fora do alcance de visao da saida, sem empilhar em cima de outra Ameaca —
## viva ou corpo). Se nao achar onde reposicionar, deixa a entrada como
## estava em vez de sumir com ela ou empilhar em cima de outra.
static func dar_folga_para_vivos_perto_da_saida(
	space_state: PhysicsDirectSpaceState2D,
	bounds: Rect2,
	saida_pos: Vector2,
	snapshot: Array,
	mask: int
) -> Array:
	var area := bounds.grow(-MARGEM_DOS_LIMITES)
	var raio_sq := RAIO_FOLGA_AO_VOLTAR * RAIO_FOLGA_AO_VOLTAR
	var min_dist_sq := DISTANCIA_MINIMA_ENTRE_INIMIGOS * DISTANCIA_MINIMA_ENTRE_INIMIGOS

	var ocupadas: Array = []
	for entrada: Variant in snapshot:
		if entrada is Dictionary and entrada.get("estado", ESTADO_VIVO) != ESTADO_LOOTEADO and entrada.has("pos"):
			ocupadas.append(entrada["pos"])

	var resultado: Array = []
	for entrada: Variant in snapshot:
		if not (entrada is Dictionary):
			resultado.append(entrada)
			continue
		var estado: String = entrada.get("estado", ESTADO_VIVO)
		var pos: Vector2 = entrada.get("pos", Vector2.ZERO)
		if estado != ESTADO_VIVO or pos.distance_squared_to(saida_pos) >= raio_sq:
			resultado.append(entrada)
			continue
		ocupadas.erase(pos)
		var nova: Variant = _sortear_candidato_valido(space_state, area, saida_pos, raio_sq, ocupadas, min_dist_sq, mask, MAX_TENTATIVAS_FOLGA)
		if nova == null:
			push_warning("ZonaPopulador: nao encontrou onde reposicionar a Ameaca id=%s pra longe da saida, deixando no lugar antigo" % entrada.get("id", "?"))
			ocupadas.append(pos)
			resultado.append(entrada)
			continue
		ocupadas.append(nova)
		var nova_entrada: Dictionary = entrada.duplicate()
		nova_entrada["pos"] = nova
		resultado.append(nova_entrada)
	return resultado


static func montar_snapshot_inicial(posicoes: Array) -> Array:
	var inimigos: Array = []
	for i in range(posicoes.size()):
		var tipo := TIPO_RAPIDA if (i % 4 == 0) else TIPO_PADRAO
		inimigos.append({"id": i, "pos": posicoes[i], "estado": ESTADO_VIVO, "tipo": tipo})
	return inimigos


static func aplicar_snapshot(mundo: Node2D, snapshot: Array) -> void:
	for entrada: Variant in snapshot:
		if not (entrada is Dictionary):
			continue
		var estado: String = entrada.get("estado", ESTADO_VIVO)
		if estado == ESTADO_LOOTEADO:
			continue
		var tipo: String = entrada.get("tipo", TIPO_PADRAO)
		var cena: PackedScene = AMEACA_RAPIDA_SCENE if tipo == TIPO_RAPIDA else AMEACA_SCENE
		var ameaca: Ameaca = cena.instantiate()
		ameaca.spawn_id = entrada.get("id", -1)
		ameaca.set_meta("tipo", tipo)
		ameaca.global_position = entrada.get("pos", Vector2.ZERO)
		# add_child NAO pode ser deferred aqui: spawn_como_corpo() depende de
		# _ready() ja ter rodado (e setado health = max_health) antes dela
		# zerar health de novo — se rodasse antes do _ready(), seria sobrescrita.
		mundo.add_child(ameaca)
		if estado == ESTADO_MORTO:
			ameaca.spawn_como_corpo()


## Le o estado atual das Ameaca vivas na arvore e funde com o snapshot
## anterior: quem sumiu do grupo "ameacas" desde entao (queue_free() ja
## chamado por _lootar()) vira ESTADO_LOOTEADO.
static func capturar_snapshot(arvore: SceneTree, snapshot_anterior: Array) -> Array:
	var vivos_por_id := {}
	for no in arvore.get_nodes_in_group(&"ameacas"):
		var ameaca := no as Ameaca
		if ameaca == null or ameaca.spawn_id < 0:
			continue
		vivos_por_id[ameaca.spawn_id] = ameaca

	var resultado: Array = []
	for entrada: Variant in snapshot_anterior:
		if not (entrada is Dictionary):
			continue
		var id: int = entrada.get("id", -1)
		var tipo: String = entrada.get("tipo", TIPO_PADRAO)
		if entrada.get("estado", ESTADO_VIVO) == ESTADO_LOOTEADO:
			resultado.append(entrada)
			continue
		if not vivos_por_id.has(id):
			# Nao esta mais na arvore: so pode ter sido _lootar() (queue_free()).
			resultado.append({"id": id, "pos": entrada.get("pos", Vector2.ZERO), "estado": ESTADO_LOOTEADO, "tipo": tipo})
			continue
		var ameaca: Ameaca = vivos_por_id[id]
		var estado := ESTADO_MORTO if ameaca.is_dead() else ESTADO_VIVO
		resultado.append({"id": id, "pos": ameaca.global_position, "estado": estado, "tipo": tipo})
	return resultado
