class_name UpgradesShotgun
## Fachada estatica: tabelas de valor/custo dos upgrades da escopeta (shotgun)
## e a logica de compra. Os niveis atuais moram em GameState (persistidos);
## esta classe sabe os valores de cada nivel, precos, e como aplicar na Weapon.

enum Trilha { DANO, TUBO, RESERVA, RECARGA }

const NIVEL_MAXIMO := 3
const CUSTO_POR_NIVEL := [20, 30, 40]

## Dano por bago (min, max) — nivel 0 a 3
const FAIXA_DANO := [
	Vector2(3.0, 5.0),
	Vector2(4.0, 6.0),
	Vector2(5.0, 7.0),
	Vector2(6.0, 8.0),
]

## Capacidade do tubo (magazine size): 2 -> 3 -> 4 -> 5
const TUBO := [2, 3, 4, 5]

## Reserva maxima de cartuchos
const RESERVA_MAXIMA := [4, 6, 8, 10]

## Tempo de recarga por cartucho (segundos)
const TEMPO_RECARGA := [0.75, 0.60, 0.48, 0.38]


static func capacidade_tubo(game_state: EstadoDoJogo) -> int:
	return TUBO[nivel_atual(game_state, Trilha.TUBO)]


static func tempo_recarga(game_state: EstadoDoJogo) -> float:
	return TEMPO_RECARGA[nivel_atual(game_state, Trilha.RECARGA)]


static func nivel_atual(game_state: EstadoDoJogo, trilha: Trilha) -> int:
	if game_state == null:
		return 0
	var nivel: int
	match trilha:
		Trilha.DANO:
			nivel = game_state.shotgun_nivel_dano
		Trilha.TUBO:
			nivel = game_state.shotgun_nivel_tubo
		Trilha.RESERVA:
			nivel = game_state.shotgun_nivel_reserva
		Trilha.RECARGA:
			nivel = game_state.shotgun_nivel_recarga
		_:
			nivel = 0
	return clampi(nivel, 0, NIVEL_MAXIMO)


static func custo_do_proximo_nivel(game_state: EstadoDoJogo, trilha: Trilha) -> int:
	var nivel := nivel_atual(game_state, trilha)
	if nivel >= NIVEL_MAXIMO:
		return -1
	return CUSTO_POR_NIVEL[nivel]


static func comprar(game_state: EstadoDoJogo, trilha: Trilha) -> bool:
	if game_state == null:
		return false
	var custo := custo_do_proximo_nivel(game_state, trilha)
	if custo < 0 or game_state.dinheiro < custo:
		return false
	game_state.dinheiro -= custo
	match trilha:
		Trilha.DANO:
			game_state.shotgun_nivel_dano += 1
		Trilha.TUBO:
			game_state.shotgun_nivel_tubo += 1
		Trilha.RESERVA:
			game_state.shotgun_nivel_reserva += 1
			game_state.shotgun_reserva_maxima = RESERVA_MAXIMA[game_state.shotgun_nivel_reserva]
		Trilha.RECARGA:
			game_state.shotgun_nivel_recarga += 1
	return true


static func aplicar_em_shotgun(weapon: Weapon, game_state: EstadoDoJogo) -> void:
	var faixa: Vector2 = FAIXA_DANO[nivel_atual(game_state, Trilha.DANO)]
	weapon.damage_min = faixa.x
	weapon.damage_max = faixa.y
	weapon.magazine_size = capacidade_tubo(game_state)
	weapon.reload_time = tempo_recarga(game_state)
