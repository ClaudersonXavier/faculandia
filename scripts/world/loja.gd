extends Control

@onready var dialog: ConfirmationDialog = %ConfirmarPartidaSemReabastecer


func _ready() -> void:
	# A cena principal esconde o cursor; a loja precisa dele de volta.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A loja e' um ponto seguro: cura a vida, igual ja reabastece municao.
	GameState.vida = GameState.PADROES.vida


func _on_button_pressed() -> void:
	if GameState.municao_pente < 7 or GameState.municao_reserva < GameState.municao_reserva_maxima:
		dialog.popup_centered()
	else:
		_voltar_pro_jogo()

func _on_recarregar_pressed() -> void:
	GameState.municao_pente = 7
	GameState.municao_reserva = GameState.municao_reserva_maxima


func _voltar_pro_jogo() -> void:
	# Volta para o hub, nao para a zona jogada antes — o jogador escolhe de novo.
	# voltando_da_loja fica true e e' consumido pelo Player._ready() da PROXIMA
	# zona escolhida no hub (o hub em si nao tem Player, entao a flag so e'
	# resolvida quando uma zona de fato carrega).
	GameState.voltando_da_loja = true
	SaveJogo.trocar_fase(SaveJogo.CENA_SELECAO)

func _on_confirmation_dialog_confirmed() -> void:
	_voltar_pro_jogo()
