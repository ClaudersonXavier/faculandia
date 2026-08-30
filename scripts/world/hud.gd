extends Control

@export var weapon: Weapon
@onready var ammo_label: Label = $AmmoLabel
@onready var reload_label: Label = $ReloadLabel

func _process(_delta: float) -> void:
	if not weapon:
		return

	ammo_label.text = str(weapon.current_ammo) + " / " + str(GameState.municao_reserva)
	reload_label.text = "Recarregando..."
	reload_label.visible = weapon.is_reloading
