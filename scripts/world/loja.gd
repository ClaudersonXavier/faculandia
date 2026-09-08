extends Control

@onready var dialog: ConfirmationDialog = %ConfirmarPartidaSemReabastecer


func _ready() -> void:
	# A cena principal esconde o cursor; a loja precisa dele de volta.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	SaveJogo.trocar_fase(SaveJogo.CENA_CENARIO)

func _on_confirmation_dialog_confirmed() -> void:
	_voltar_pro_jogo()
