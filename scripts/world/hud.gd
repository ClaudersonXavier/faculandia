extends Control

const COR_DENSIDADE_LIMPA := Color(0.2, 0.8, 0.2)
const COR_DENSIDADE_BAIXA := Color(0.9, 0.85, 0.1)
const COR_DENSIDADE_MEDIA := Color(0.95, 0.55, 0.1)
const COR_DENSIDADE_ALTA := Color(0.9, 0.15, 0.15)

const COR_VIDA_CHEIA := Color(0.85, 0.1, 0.1, 1.0)
const COR_VIDA_VAZIA := Color(1.0, 1.0, 1.0, 0.15)

@export var weapon: Weapon
@onready var ammo_label: Label = $AmmoLabel
@onready var reload_label: Label = $ReloadLabel
@onready var dinheiro_label: Label = %DinheiroLabel
@onready var densidade_ameaca_label: Label = %DensidadeAmeacaLabel
@onready var vida_container: HBoxContainer = %Vida

func _process(_delta: float) -> void:
	var game_state = get_node_or_null("/root/GameState")
	if dinheiro_label != null:
		dinheiro_label.text = "$" + str(game_state.dinheiro if game_state != null else 0)

	if densidade_ameaca_label != null:
		_atualizar_densidade_de_ameaca()

	if vida_container != null:
		_atualizar_vida(game_state)

	if not weapon:
		return

	if ammo_label != null:
		var mun_pente: int = game_state.municao_pente if game_state != null else weapon.current_ammo
		var mun_reserva: int = game_state.municao_reserva if game_state != null else 0
		ammo_label.text = str(mun_pente) + " / " + str(mun_reserva)
	if reload_label != null:
		reload_label.text = "Recarregando..."
		reload_label.visible = weapon.is_reloading


## Conta direto na arvore (nao no snapshot de ZonaPopulador, que so atualiza
## ao trocar de fase/salvar) pra refletir mortes em tempo real.
func _atualizar_densidade_de_ameaca() -> void:
	var vivas := 0
	for no in get_tree().get_nodes_in_group(&"ameacas"):
		var ameaca := no as Ameaca
		if ameaca != null and not ameaca.is_dead():
			vivas += 1

	var texto: String
	var cor: Color
	if vivas <= 0:
		texto = "Limpa"
		cor = COR_DENSIDADE_LIMPA
	elif vivas <= 10:
		texto = "Baixa"
		cor = COR_DENSIDADE_BAIXA
	elif vivas <= 20:
		texto = "Média"
		cor = COR_DENSIDADE_MEDIA
	else:
		texto = "Alta"
		cor = COR_DENSIDADE_ALTA

	densidade_ameaca_label.text = texto
	densidade_ameaca_label.add_theme_color_override("font_color", cor)


func _atualizar_vida(game_state: Variant) -> void:
	var vida: int = game_state.vida if game_state != null else int(EstadoDoJogo.PADROES.vida)
	var caixas := vida_container.get_children()
	for i in range(caixas.size()):
		(caixas[i] as ColorRect).color = COR_VIDA_CHEIA if i < vida else COR_VIDA_VAZIA
