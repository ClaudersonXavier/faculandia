class_name UpgradesPowerups
## Fachada estatica: tabelas de valor/custo dos powerups gerais e a
## logica de compra. Os niveis moram em GameState (persistidos, ver
## AGENTS.md "Save Schema").

enum Trilha { LANTERNA, SAPATOS }

const NIVEL_MAX_LANTERNA := 3
const NIVEL_MAX_SAPATOS := 2

const CUSTO_LANTERNA := [20, 30, 40]
const ANGULOS_LANTERNA := [75.0, 95.0, 115.0, 135.0]
const ALCANCES_LANTERNA := [450.0, 480.0, 510.0, 540.0]

const CUSTO_SAPATOS := [30, 40]
const RECARGA_SAPATOS := [0.0, 10.0, 5.0]

const CUSTO_CURA := 15
const CUSTO_BOLETIM := 25


static func nivel_atual(game_state: EstadoDoJogo, trilha: Trilha) -> int:
	if game_state == null:
		return 0
	match trilha:
		Trilha.LANTERNA:
			return clampi(game_state.powerup_lanterna_nivel, 0, NIVEL_MAX_LANTERNA)
		Trilha.SAPATOS:
			return clampi(game_state.powerup_sapatos_nivel, 0, NIVEL_MAX_SAPATOS)
		_:
			return 0


static func custo_do_proximo_nivel(game_state: EstadoDoJogo, trilha: Trilha) -> int:
	var nivel := nivel_atual(game_state, trilha)
	match trilha:
		Trilha.LANTERNA:
			if nivel >= NIVEL_MAX_LANTERNA:
				return -1
			return CUSTO_LANTERNA[nivel]
		Trilha.SAPATOS:
			if nivel >= NIVEL_MAX_SAPATOS:
				return -1
			return CUSTO_SAPATOS[nivel]
		_:
			return -1


static func angulo_lanterna(game_state: EstadoDoJogo) -> float:
	var nivel := nivel_atual(game_state, Trilha.LANTERNA)
	return ANGULOS_LANTERNA[nivel]


static func alcance_lanterna(game_state: EstadoDoJogo) -> float:
	var nivel := nivel_atual(game_state, Trilha.LANTERNA)
	return ALCANCES_LANTERNA[nivel]


static func recarga_dash(game_state: EstadoDoJogo) -> float:
	var nivel := nivel_atual(game_state, Trilha.SAPATOS)
	return RECARGA_SAPATOS[nivel]


static func comprar(game_state: EstadoDoJogo, trilha: Trilha) -> bool:
	if game_state == null:
		return false
	var custo := custo_do_proximo_nivel(game_state, trilha)
	if custo < 0 or game_state.dinheiro < custo:
		return false

	game_state.dinheiro -= custo
	match trilha:
		Trilha.LANTERNA:
			game_state.powerup_lanterna_nivel = clampi(game_state.powerup_lanterna_nivel + 1, 0, NIVEL_MAX_LANTERNA)
		Trilha.SAPATOS:
			game_state.powerup_sapatos_nivel = clampi(game_state.powerup_sapatos_nivel + 1, 0, NIVEL_MAX_SAPATOS)
	return true


static func comprar_cura(game_state: EstadoDoJogo) -> bool:
	if game_state == null:
		return false
	if game_state.vida >= game_state.vida_maxima:
		return false
	if game_state.dinheiro < CUSTO_CURA:
		return false

	game_state.dinheiro -= CUSTO_CURA
	game_state.vida = game_state.vida_maxima
	return true


static func comprar_boletim(game_state: EstadoDoJogo) -> bool:
	if game_state == null:
		return false
	if game_state.powerup_boletim:
		return false
	if game_state.dinheiro < CUSTO_BOLETIM:
		return false

	game_state.dinheiro -= CUSTO_BOLETIM
	game_state.powerup_boletim = true
	return true
