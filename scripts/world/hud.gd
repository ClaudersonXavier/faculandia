extends Control

const COR_DENSIDADE_LIMPA := Color(0.2, 0.8, 0.2)
const COR_DENSIDADE_BAIXA := Color(0.9, 0.85, 0.1)
const COR_DENSIDADE_MEDIA := Color(0.95, 0.55, 0.1)
const COR_DENSIDADE_ALTA := Color(0.9, 0.15, 0.15)

const COR_VIDA_CHEIA := Color(0.85, 0.1, 0.1, 1.0)
const COR_VIDA_VAZIA := Color(1.0, 1.0, 1.0, 0.15)

@export var weapon: Weapon
@export var player: Node2D
@onready var ammo_label: Label = get_node_or_null("AmmoLabel") as Label
@onready var reload_label: Label = get_node_or_null("ReloadLabel") as Label
@onready var dinheiro_label: Label = get_node_or_null("../DinheiroLabel") as Label
@onready var health_bar: ProgressBar = _find_health_node("HealthBar") as ProgressBar
@onready var health_label: Label = _find_health_node("HealthLabel") as Label


func _ready() -> void:
	_configure_health_bar()


func _find_health_node(node_name: String) -> Node:
	var direct := get_node_or_null(node_name)
	if direct != null:
		return direct
	return get_node_or_null("../" + node_name)


func _find_player() -> Node2D:
	if is_instance_valid(player):
		return player
	var jogadores := get_tree().get_nodes_in_group(&"player")
	if not jogadores.is_empty() and jogadores[0] is Node2D:
		player = jogadores[0] as Node2D
	return player


func _configure_health_bar() -> void:
	if health_bar == null:
		return
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.08, 0.08, 0.95)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.85, 0.25, 1.0)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("background", background)
	health_bar.add_theme_stylebox_override("fill", fill)


func _update_health() -> void:
	var jogador := _find_player()
	if jogador == null or not jogador.has_method("get_health"):
		return
	var atual := float(jogador.get_health())
	var maxima := maxf(float(jogador.get_max_health()), 1.0)
	if health_bar != null:
		health_bar.max_value = maxima
		health_bar.value = atual
		var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			var proporcao := atual / maxima
			fill.bg_color = Color(0.2, 0.85, 0.25, 1.0) if proporcao > 0.6 else Color(0.95, 0.75, 0.1, 1.0) if proporcao > 0.3 else Color(0.9, 0.15, 0.12, 1.0)
	if health_label != null:
		health_label.text = "%d / %d" % [roundi(atual), roundi(maxima)]

@onready var densidade_ameaca_label: Label = get_node_or_null("../IndicadoresSuperiores/DensidadeAmeaca/DensidadeAmeacaLabel") as Label

func _process(_delta: float) -> void:
	var game_state = get_node_or_null("/root/GameState")
	_update_health()
	if dinheiro_label != null:
		dinheiro_label.text = "$" + str(game_state.dinheiro if game_state != null else 0)

	if densidade_ameaca_label != null:
		_atualizar_densidade_de_ameaca()

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
