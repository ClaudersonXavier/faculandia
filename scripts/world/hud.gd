extends Control

@export var weapon: Weapon
@onready var ammo_label: Label = $AmmoLabel
@onready var reload_label: Label = $ReloadLabel
@onready var dinheiro_label: Label = %DinheiroLabel

func _process(_delta: float) -> void:
	var game_state = get_node_or_null("/root/GameState")
	if dinheiro_label != null:
		dinheiro_label.text = "$" + str(game_state.dinheiro if game_state != null else 0)

	if not weapon:
		return

	if ammo_label != null:
		var mun_pente: int = game_state.municao_pente if game_state != null else weapon.current_ammo
		var mun_reserva: int = game_state.municao_reserva if game_state != null else 0
		ammo_label.text = str(mun_pente) + " / " + str(mun_reserva)
	if reload_label != null:
		reload_label.text = "Recarregando..."
		reload_label.visible = weapon.is_reloading
