class_name EstadoDoJogo
extends Node
## Estado corrente da partida (autoload "GameState").
## PADROES e a fonte unica dos valores iniciais e tambem define o conjunto de
## campos que vai para o save: adicionar um campo persistente = 1 entrada aqui
## mais 1 var. A persistencia em disco fica em scripts/core/save_slots.gd e
## scripts/world/save_jogo.gd.
## O class_name difere do nome do autoload de proposito: `class_name GameState`
## colidiria com o autoload, e sem class_name o acesso ficaria sem tipo.

## O default de "cena" repete o literal de SaveJogo.CENA_ZONA_NORTE em vez de
## referencia-lo: um const aqui apontando para outra classe global criaria uma
## dependencia circular entre class_names (SaveJogo tambem referencia
## EstadoDoJogo). Mantenha os dois literais em sincronia.
const PADROES := {
	"municao_reserva": 14,
	"municao_reserva_maxima": 14,
	"municao_pente": 7,
	"dinheiro": 0,
	"vida": 100.0,
	"vida_maxima": 100.0,
	"cena": "res://scenes/world/zona_norte.tscn",
	"nivel_dano": 0,
	"nivel_tambor": 0,
	"nivel_reserva": 0,
	"nivel_critico": 0,
	"shotgun_pente": 0,
	"shotgun_reserva": 0,
	"shotgun_reserva_maxima": 4,
	"possui_shotgun": false,
	"shotgun_nivel_dano": 0,
	"shotgun_nivel_tubo": 0,
	"shotgun_nivel_reserva": 0,
	"shotgun_nivel_recarga": 0,
	"arma_ativa": "pistola",
	"powerup_lanterna_nivel": 0,
	"powerup_sapatos_nivel": 0,
	"powerup_boletim": false,
	"caixas_coletadas": [],
}

var municao_reserva: int
var municao_reserva_maxima: int
var municao_pente: int
var dinheiro: int
var vida: float
var vida_maxima: float
var cena: String
var nivel_dano: int
var nivel_tambor: int
var nivel_reserva: int
var nivel_critico: int
var shotgun_pente: int
var shotgun_reserva: int
var shotgun_reserva_maxima: int
var possui_shotgun: bool
var shotgun_nivel_dano: int
var shotgun_nivel_tubo: int
var shotgun_nivel_reserva: int
var shotgun_nivel_recarga: int
var arma_ativa: String
var powerup_lanterna_nivel: int
var powerup_sapatos_nivel: int
var powerup_boletim: bool
var caixas_coletadas: Array

## Flag de transicao entre cenas; e runtime, nao entra no save.
var voltando_da_loja: bool = false


func _init() -> void:
	reset()


## Serializa apenas os campos persistentes.
func to_dict() -> Dictionary:
	var dados := {}
	for chave: String in PADROES:
		dados[chave] = get(chave)
	return dados


## Aplica um dicionario de save. Campos ausentes voltam ao padrao e chaves
## desconhecidas sao ignoradas: e isso que faz um save v1 carregar sem
## migracao quando campos novos aparecerem.
func from_dict(dados: Dictionary) -> void:
	for chave: String in PADROES:
		var valor_padrao = PADROES[chave]
		if valor_padrao is Array:
			valor_padrao = valor_padrao.duplicate(true)
		var val = dados.get(chave, valor_padrao)
		if val is Array:
			val = val.duplicate(true)
		set(chave, val)
	if not ResourceLoader.exists(cena):
		push_warning("Cena do save nao existe mais: %s" % cena)
		cena = String(PADROES.cena)
	voltando_da_loja = false


## Volta a partida para os valores de PADROES.
func reset() -> void:
	from_dict({})
