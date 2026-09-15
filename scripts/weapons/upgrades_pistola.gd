class_name UpgradesPistola
## Fachada estatica: tabelas de valor/custo dos upgrades da pistola e a
## logica de compra. Os niveis atuais moram em GameState (persistidos, ver
## AGENTS.md "Save Schema"); esta classe so sabe os valores de cada nivel,
## quanto custa avancar, e como aplicar os niveis atuais numa Weapon.

enum Trilha { DANO, TAMBOR, RESERVA, CRITICO }

const NIVEL_MAXIMO := 3
## Custo pra comprar o PROXIMO nivel — indice = nivel atual (0..2), ou seja
## CUSTO_POR_NIVEL[0] e' o preco de ir do nivel 0 pro 1. Mesma progressao
## pras 4 trilhas por simplicidade; ajustar aqui nao mexe em nenhuma logica.
const CUSTO_POR_NIVEL := [15, 20, 25]

## Indice 0 = nivel atual (sem upgrade, valores de hoje) .. indice 3 = nivel 3.
const FAIXA_DANO := [
	Vector2(7.0, 9.0),
	Vector2(8.0, 10.0),
	Vector2(9.0, 11.0),
	Vector2(10.0, 12.0),
]
const TAMBOR := [7, 8, 9, 10]
const RESERVA_MAXIMA := [14, 21, 28, 35]
const CHANCE_CRITICO := [0.0, 0.10, 0.20, 0.30]


static func capacidade_tambor(game_state: EstadoDoJogo) -> int:
	return TAMBOR[nivel_atual(game_state, Trilha.TAMBOR)]


## Sempre clampado em [0, NIVEL_MAXIMO] — um save corrompido/editado a mao
## com um nivel_* fora da faixa (ex. negativo ou 99) nao pode estourar o
## indice das tabelas abaixo (FAIXA_DANO/TAMBOR/RESERVA_MAXIMA/CHANCE_CRITICO).
static func nivel_atual(game_state: EstadoDoJogo, trilha: Trilha) -> int:
	if game_state == null:
		return 0
	var nivel: int
	match trilha:
		Trilha.DANO:
			nivel = game_state.nivel_dano
		Trilha.TAMBOR:
			nivel = game_state.nivel_tambor
		Trilha.RESERVA:
			nivel = game_state.nivel_reserva
		Trilha.CRITICO:
			nivel = game_state.nivel_critico
		_:
			nivel = 0
	return clampi(nivel, 0, NIVEL_MAXIMO)


## -1 quando ja esta no nivel maximo (nada pra comprar).
static func custo_do_proximo_nivel(game_state: EstadoDoJogo, trilha: Trilha) -> int:
	var nivel := nivel_atual(game_state, trilha)
	if nivel >= NIVEL_MAXIMO:
		return -1
	return CUSTO_POR_NIVEL[nivel]


## Unico lugar que mexe em dinheiro pra upgrade: valida saldo e nivel
## maximo, deduz e incrementa. Devolve false sem nenhum efeito colateral se
## nao puder comprar (saldo insuficiente ou ja no nivel maximo).
static func comprar(game_state: EstadoDoJogo, trilha: Trilha) -> bool:
	if game_state == null:
		return false
	var custo := custo_do_proximo_nivel(game_state, trilha)
	if custo < 0 or game_state.dinheiro < custo:
		return false
	game_state.dinheiro -= custo
	match trilha:
		Trilha.DANO:
			game_state.nivel_dano += 1
		Trilha.TAMBOR:
			game_state.nivel_tambor += 1
		Trilha.RESERVA:
			game_state.nivel_reserva += 1
			# municao_reserva_maxima e' o campo que o resto do jogo (loja.gd,
			# reload) realmente le — os dois sempre mudam juntos, aqui e' o
			# unico lugar que escreve em qualquer um dos dois.
			game_state.municao_reserva_maxima = RESERVA_MAXIMA[game_state.nivel_reserva]
		Trilha.CRITICO:
			game_state.nivel_critico += 1
	return true


## Chamado por pistol.gd em _ready(): a Weapon e' recriada do zero toda vez
## que o player troca de cena, entao aplicar os niveis aqui garante que um
## upgrade comprado ja vale na proxima zona sem nenhuma sincronizacao extra.
static func aplicar_em_pistola(weapon: Weapon, game_state: EstadoDoJogo) -> void:
	var faixa: Vector2 = FAIXA_DANO[nivel_atual(game_state, Trilha.DANO)]
	weapon.damage_min = faixa.x
	weapon.damage_max = faixa.y
	weapon.magazine_size = capacidade_tambor(game_state)
	weapon.crit_chance = CHANCE_CRITICO[nivel_atual(game_state, Trilha.CRITICO)]
