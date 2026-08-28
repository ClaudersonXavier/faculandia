extends Control

@onready var dialog: ConfirmationDialog = %ConfirmarPartidaSemReabastecer

func _on_button_pressed() -> void:
	if GameState.municao_pente < 7 or GameState.municao_reserva < GameState.municao_reserva_maxima:
		dialog.popup_centered()
	else:
		_voltar_pro_jogo()

func _on_recarregar_pressed() -> void:
	GameState.municao_pente = 7
	GameState.municao_reserva = GameState.municao_reserva_maxima


func _voltar_pro_jogo() -> void:
	GameState.voltando_da_loja = true
	get_tree().change_scene_to_file("res://scenes/cena_principal.tscn")

func _on_confirmation_dialog_confirmed() -> void:
	_voltar_pro_jogo()
