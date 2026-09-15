extends Control

const TRILHAS := [
	UpgradesPistola.Trilha.DANO,
	UpgradesPistola.Trilha.TAMBOR,
	UpgradesPistola.Trilha.RESERVA,
	UpgradesPistola.Trilha.CRITICO,
]

@onready var dialog: ConfirmationDialog = %ConfirmarPartidaSemReabastecer
@onready var dinheiro_label: Label = %DinheiroLoja
@onready var info_labels := {
	UpgradesPistola.Trilha.DANO: %InfoDano,
	UpgradesPistola.Trilha.TAMBOR: %InfoTambor,
	UpgradesPistola.Trilha.RESERVA: %InfoReserva,
	UpgradesPistola.Trilha.CRITICO: %InfoCritico,
}
@onready var comprar_buttons := {
	UpgradesPistola.Trilha.DANO: %ComprarDano,
	UpgradesPistola.Trilha.TAMBOR: %ComprarTambor,
	UpgradesPistola.Trilha.RESERVA: %ComprarReserva,
	UpgradesPistola.Trilha.CRITICO: %ComprarCritico,
}


func _ready() -> void:
	# A cena principal esconde o cursor; a loja precisa dele de volta.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicaTema.tocar()
	for trilha: UpgradesPistola.Trilha in TRILHAS:
		(comprar_buttons[trilha] as Button).pressed.connect(_comprar.bind(trilha))
	_atualizar_upgrades()


func _on_button_pressed() -> void:
	var tambor_max := UpgradesPistola.capacidade_tambor(GameState)
	if GameState.municao_pente < tambor_max or GameState.municao_reserva < GameState.municao_reserva_maxima:
		dialog.popup_centered()
	else:
		_voltar_pro_jogo()

func _on_recarregar_pressed() -> void:
	GameState.municao_pente = UpgradesPistola.capacidade_tambor(GameState)
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


## UpgradesPistola.comprar() e' o unico lugar que mexe em dinheiro/nivel —
## aqui so chama e re-renderiza se deu certo.
func _comprar(trilha: UpgradesPistola.Trilha) -> void:
	if UpgradesPistola.comprar(GameState, trilha):
		_atualizar_upgrades()


func _atualizar_upgrades() -> void:
	dinheiro_label.text = "$%d" % GameState.dinheiro
	for trilha: UpgradesPistola.Trilha in TRILHAS:
		var nivel := UpgradesPistola.nivel_atual(GameState, trilha)
		var custo := UpgradesPistola.custo_do_proximo_nivel(GameState, trilha)
		(info_labels[trilha] as Label).text = _texto_info(trilha, nivel)
		var botao := comprar_buttons[trilha] as Button
		if custo < 0:
			botao.text = "MÁXIMO"
			botao.disabled = true
		else:
			botao.text = "Comprar ($%d)" % custo
			botao.disabled = GameState.dinheiro < custo


func _texto_info(trilha: UpgradesPistola.Trilha, nivel: int) -> String:
	match trilha:
		UpgradesPistola.Trilha.DANO:
			var faixa: Vector2 = UpgradesPistola.FAIXA_DANO[nivel]
			return "Dano: Nível %d/3 (%d-%d)" % [nivel, int(faixa.x), int(faixa.y)]
		UpgradesPistola.Trilha.TAMBOR:
			return "Tambor: Nível %d/3 (%d tiros)" % [nivel, UpgradesPistola.TAMBOR[nivel]]
		UpgradesPistola.Trilha.RESERVA:
			return "Reserva máxima: Nível %d/3 (%d)" % [nivel, UpgradesPistola.RESERVA_MAXIMA[nivel]]
		UpgradesPistola.Trilha.CRITICO:
			return "Crítico: Nível %d/3 (%d%%)" % [nivel, int(UpgradesPistola.CHANCE_CRITICO[nivel] * 100)]
	return ""
