extends Control

@export var weapon: Weapon
@onready var ammo_label: Label = $AmmoLabel
@onready var reload_label: Label = $ReloadLabel
@onready var dinheiro_label: Label = %DinheiroLabel

func _process(_delta: float) -> void:
	dinheiro_label.text = "$" + str(GameState.dinheiro)

	if not weapon:
		return

	ammo_label.text = str(GameState.municao_pente) + " / " + str(GameState.municao_reserva)
	reload_label.text = "Recarregando..."
	reload_label.visible = weapon.is_reloading
