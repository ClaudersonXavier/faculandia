extends Control

const UpgradesPowerupsScript := preload("res://scripts/world/upgrades_powerups.gd")

const CUSTO_COMPRA_SHOTGUN := 50
const CUSTO_RECARGA_SHOTGUN := 10

const TRILHAS_PISTOLA := [
	UpgradesPistola.Trilha.DANO,
	UpgradesPistola.Trilha.TAMBOR,
	UpgradesPistola.Trilha.RESERVA,
	UpgradesPistola.Trilha.CRITICO,
]

const TRILHAS_SHOTGUN := [
	UpgradesShotgun.Trilha.DANO,
	UpgradesShotgun.Trilha.TUBO,
	UpgradesShotgun.Trilha.RESERVA,
	UpgradesShotgun.Trilha.RECARGA,
]

@onready var dialog: ConfirmationDialog = %ConfirmarPartidaSemReabastecer
@onready var dinheiro_label: Label = %DinheiroLoja

@onready var botao_comprar_shotgun: Button = %BotaoComprarShotgun
@onready var coluna_shotgun: VBoxContainer = %ColunaShotgun
@onready var recarregar_pistola_btn: Button = %RecarregarMunicaoPistola
@onready var recarregar_shotgun_btn: Button = %RecarregarMunicaoShotgun

@onready var info_municao_pistola: Label = %InfoMunicaoPistola
@onready var info_municao_shotgun: Label = %InfoMunicaoShotgun

@onready var info_lanterna: Label = %InfoLanterna
@onready var btn_lanterna: Button = %ComprarLanterna
@onready var info_sapatos: Label = %InfoSapatos
@onready var btn_sapatos: Button = %ComprarSapatos
@onready var info_cura: Label = %InfoCura
@onready var btn_cura: Button = %ComprarCura
@onready var info_boletim: Label = %InfoBoletim
@onready var btn_boletim: Button = %ComprarBoletim

@onready var info_labels_pistola := {
	UpgradesPistola.Trilha.DANO: %InfoDano,
	UpgradesPistola.Trilha.TAMBOR: %InfoTambor,
	UpgradesPistola.Trilha.RESERVA: %InfoReserva,
	UpgradesPistola.Trilha.CRITICO: %InfoCritico,
}
@onready var comprar_buttons_pistola := {
	UpgradesPistola.Trilha.DANO: %ComprarDano,
	UpgradesPistola.Trilha.TAMBOR: %ComprarTambor,
	UpgradesPistola.Trilha.RESERVA: %ComprarReserva,
	UpgradesPistola.Trilha.CRITICO: %ComprarCritico,
}

@onready var info_labels_shotgun := {
	UpgradesShotgun.Trilha.DANO: %InfoDanoShotgun,
	UpgradesShotgun.Trilha.TUBO: %InfoTuboShotgun,
	UpgradesShotgun.Trilha.RESERVA: %InfoReservaShotgun,
	UpgradesShotgun.Trilha.RECARGA: %InfoRecargaShotgun,
}
@onready var comprar_buttons_shotgun := {
	UpgradesShotgun.Trilha.DANO: %ComprarDanoShotgun,
	UpgradesShotgun.Trilha.TUBO: %ComprarTuboShotgun,
	UpgradesShotgun.Trilha.RESERVA: %ComprarReservaShotgun,
	UpgradesShotgun.Trilha.RECARGA: %ComprarRecargaShotgun,
}


func _ready() -> void:
	# A cena principal esconde o cursor; a loja precisa dele de volta.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicaTema.tocar()

	btn_lanterna.pressed.connect(_comprar_powerup.bind(UpgradesPowerupsScript.Trilha.LANTERNA))
	btn_sapatos.pressed.connect(_comprar_powerup.bind(UpgradesPowerupsScript.Trilha.SAPATOS))
	btn_cura.pressed.connect(_comprar_cura)
	btn_boletim.pressed.connect(_comprar_boletim)

	for trilha: UpgradesPistola.Trilha in TRILHAS_PISTOLA:
		(comprar_buttons_pistola[trilha] as Button).pressed.connect(_comprar_pistola.bind(trilha))

	for trilha: UpgradesShotgun.Trilha in TRILHAS_SHOTGUN:
		(comprar_buttons_shotgun[trilha] as Button).pressed.connect(_comprar_shotgun.bind(trilha))

	_atualizar_tudo()


func _on_button_pressed() -> void:
	var precisa_reabastecer := false

	var tambor_max := UpgradesPistola.capacidade_tambor(GameState)
	if GameState.municao_pente < tambor_max or GameState.municao_reserva < GameState.municao_reserva_maxima:
		precisa_reabastecer = true

	if GameState.possui_shotgun:
		var tubo_max := UpgradesShotgun.capacidade_tubo(GameState)
		if GameState.shotgun_pente < tubo_max or GameState.shotgun_reserva < GameState.shotgun_reserva_maxima:
			precisa_reabastecer = true

	if precisa_reabastecer:
		dialog.popup_centered()
	else:
		_voltar_pro_jogo()


func _on_recarregar_pressed() -> void:
	GameState.municao_pente = UpgradesPistola.capacidade_tambor(GameState)
	GameState.municao_reserva = GameState.municao_reserva_maxima
	_atualizar_tudo()


func _on_comprar_shotgun_pressed() -> void:
	if GameState.dinheiro < CUSTO_COMPRA_SHOTGUN or GameState.possui_shotgun:
		return
	GameState.dinheiro -= CUSTO_COMPRA_SHOTGUN
	GameState.possui_shotgun = true
	GameState.shotgun_pente = UpgradesShotgun.capacidade_tubo(GameState)
	GameState.shotgun_reserva = GameState.shotgun_reserva_maxima
	_atualizar_tudo()


func _on_recarregar_shotgun_pressed() -> void:
	if not GameState.possui_shotgun:
		return
	var tubo_max := UpgradesShotgun.capacidade_tubo(GameState)
	var ja_cheio := GameState.shotgun_pente >= tubo_max and GameState.shotgun_reserva >= GameState.shotgun_reserva_maxima
	if ja_cheio:
		return
	if GameState.dinheiro < CUSTO_RECARGA_SHOTGUN:
		return
	GameState.dinheiro -= CUSTO_RECARGA_SHOTGUN
	GameState.shotgun_pente = tubo_max
	GameState.shotgun_reserva = GameState.shotgun_reserva_maxima
	_atualizar_tudo()


func _voltar_pro_jogo() -> void:
	GameState.voltando_da_loja = true
	SaveJogo.trocar_fase(SaveJogo.CENA_SELECAO)


func _on_confirmation_dialog_confirmed() -> void:
	_voltar_pro_jogo()


func _comprar_pistola(trilha: UpgradesPistola.Trilha) -> void:
	if UpgradesPistola.comprar(GameState, trilha):
		_atualizar_tudo()


func _comprar_shotgun(trilha: UpgradesShotgun.Trilha) -> void:
	if UpgradesShotgun.comprar(GameState, trilha):
		_atualizar_tudo()


func _comprar_powerup(trilha: UpgradesPowerupsScript.Trilha) -> void:
	if UpgradesPowerupsScript.comprar(GameState, trilha):
		_atualizar_tudo()


func _comprar_cura() -> void:
	if UpgradesPowerupsScript.comprar_cura(GameState):
		_atualizar_tudo()


func _comprar_boletim() -> void:
	if UpgradesPowerupsScript.comprar_boletim(GameState):
		_atualizar_tudo()


func _atualizar_tudo() -> void:
	dinheiro_label.text = "$%d" % GameState.dinheiro

	# --- Atualiza Power-ups ---
	var nivel_lanterna := UpgradesPowerupsScript.nivel_atual(GameState, UpgradesPowerupsScript.Trilha.LANTERNA)
	var custo_lanterna := UpgradesPowerupsScript.custo_do_proximo_nivel(GameState, UpgradesPowerupsScript.Trilha.LANTERNA)
	var angulo := UpgradesPowerupsScript.angulo_lanterna(GameState)
	info_lanterna.text = "Lanterna: Nível %d/3 (%d°)" % [nivel_lanterna, int(angulo)]
	if custo_lanterna < 0:
		btn_lanterna.text = "MÁXIMO"
		btn_lanterna.disabled = true
	else:
		btn_lanterna.text = "Comprar ($%d)" % custo_lanterna
		btn_lanterna.disabled = GameState.dinheiro < custo_lanterna

	var nivel_sapatos := UpgradesPowerupsScript.nivel_atual(GameState, UpgradesPowerupsScript.Trilha.SAPATOS)
	var custo_sapatos := UpgradesPowerupsScript.custo_do_proximo_nivel(GameState, UpgradesPowerupsScript.Trilha.SAPATOS)
	var recarga_sapatos := UpgradesPowerupsScript.recarga_dash(GameState)
	info_sapatos.text = "Sapatos: Nível %d/2 (%s)" % [nivel_sapatos, "Bloq." if nivel_sapatos == 0 else "%ds" % int(recarga_sapatos)]
	if custo_sapatos < 0:
		btn_sapatos.text = "MÁXIMO"
		btn_sapatos.disabled = true
	else:
		btn_sapatos.text = "Comprar ($%d)" % custo_sapatos
		btn_sapatos.disabled = GameState.dinheiro < custo_sapatos

	info_cura.text = "Cura (%d/%d HP)" % [roundi(GameState.vida), roundi(GameState.vida_maxima)]
	if GameState.vida >= GameState.vida_maxima:
		btn_cura.text = "Vida Cheia"
		btn_cura.disabled = true
	else:
		btn_cura.text = "Comprar ($%d)" % UpgradesPowerupsScript.CUSTO_CURA
		btn_cura.disabled = GameState.dinheiro < UpgradesPowerupsScript.CUSTO_CURA

	if GameState.powerup_boletim:
		info_boletim.text = "Boletim (Ativo)"
		btn_boletim.text = "COMPRADO"
		btn_boletim.disabled = true
	else:
		info_boletim.text = "Boletim (Contador HUD)"
		btn_boletim.text = "Comprar ($%d)" % UpgradesPowerupsScript.CUSTO_BOLETIM
		btn_boletim.disabled = GameState.dinheiro < UpgradesPowerupsScript.CUSTO_BOLETIM

	# --- Atualiza Indicadores de Municao ---
	info_municao_pistola.text = "Atual: %d / %d" % [GameState.municao_pente, GameState.municao_reserva]
	info_municao_shotgun.text = "Atual: %d / %d" % [GameState.shotgun_pente, GameState.shotgun_reserva]


	# --- Atualiza Pistola ---
	for trilha: UpgradesPistola.Trilha in TRILHAS_PISTOLA:
		var nivel := UpgradesPistola.nivel_atual(GameState, trilha)
		var custo := UpgradesPistola.custo_do_proximo_nivel(GameState, trilha)
		(info_labels_pistola[trilha] as Label).text = _texto_info_pistola(trilha, nivel)
		var botao := comprar_buttons_pistola[trilha] as Button
		if custo < 0:
			botao.text = "MÁXIMO"
			botao.disabled = true
		else:
			botao.text = "Comprar ($%d)" % custo
			botao.disabled = GameState.dinheiro < custo

	# --- Atualiza Shotgun (Visibilidade e Upgrades) ---
	var tem_shotgun: bool = GameState.possui_shotgun
	botao_comprar_shotgun.visible = not tem_shotgun
	coluna_shotgun.visible = tem_shotgun

	if not tem_shotgun:
		botao_comprar_shotgun.text = "💥 Comprar Escopeta ($%d)" % CUSTO_COMPRA_SHOTGUN
		botao_comprar_shotgun.disabled = GameState.dinheiro < CUSTO_COMPRA_SHOTGUN
	else:
		for trilha: UpgradesShotgun.Trilha in TRILHAS_SHOTGUN:
			var nivel := UpgradesShotgun.nivel_atual(GameState, trilha)
			var custo := UpgradesShotgun.custo_do_proximo_nivel(GameState, trilha)
			(info_labels_shotgun[trilha] as Label).text = _texto_info_shotgun(trilha, nivel)
			var botao := comprar_buttons_shotgun[trilha] as Button
			if custo < 0:
				botao.text = "MÁXIMO"
				botao.disabled = true
			else:
				botao.text = "Comprar ($%d)" % custo
				botao.disabled = GameState.dinheiro < custo

		var tubo_max := UpgradesShotgun.capacidade_tubo(GameState)
		var ja_cheio := GameState.shotgun_pente >= tubo_max and GameState.shotgun_reserva >= GameState.shotgun_reserva_maxima
		if ja_cheio:
			recarregar_shotgun_btn.text = "Munição Cheia"
			recarregar_shotgun_btn.disabled = true
		else:
			recarregar_shotgun_btn.text = "Recarregar Escopeta ($%d)" % CUSTO_RECARGA_SHOTGUN
			recarregar_shotgun_btn.disabled = GameState.dinheiro < CUSTO_RECARGA_SHOTGUN


func _texto_info_pistola(trilha: UpgradesPistola.Trilha, nivel: int) -> String:
	match trilha:
		UpgradesPistola.Trilha.DANO:
			var faixa: Vector2 = UpgradesPistola.FAIXA_DANO[nivel]
			return "Dano: Nível %d/3 (%d-%d)" % [nivel, int(faixa.x), int(faixa.y)]
		UpgradesPistola.Trilha.TAMBOR:
			return "Tambor: Nível %d/3 (%d tiros)" % [nivel, UpgradesPistola.TAMBOR[nivel]]
		UpgradesPistola.Trilha.RESERVA:
			return "Reserva: Nível %d/3 (%d)" % [nivel, UpgradesPistola.RESERVA_MAXIMA[nivel]]
		UpgradesPistola.Trilha.CRITICO:
			return "Crítico: Nível %d/3 (%d%%)" % [nivel, int(UpgradesPistola.CHANCE_CRITICO[nivel] * 100)]
	return ""


func _texto_info_shotgun(trilha: UpgradesShotgun.Trilha, nivel: int) -> String:
	match trilha:
		UpgradesShotgun.Trilha.DANO:
			var faixa: Vector2 = UpgradesShotgun.FAIXA_DANO[nivel]
			return "Dano: Nível %d/3 (%d-%d por bago)" % [nivel, int(faixa.x), int(faixa.y)]
		UpgradesShotgun.Trilha.TUBO:
			return "Tubo: Nível %d/3 (%d tiros)" % [nivel, UpgradesShotgun.TUBO[nivel]]
		UpgradesShotgun.Trilha.RESERVA:
			return "Reserva: Nível %d/3 (%d)" % [nivel, UpgradesShotgun.RESERVA_MAXIMA[nivel]]
		UpgradesShotgun.Trilha.RECARGA:
			return "Recarga: Nível %d/3 (%.2fs/b)" % [nivel, UpgradesShotgun.TEMPO_RECARGA[nivel]]
	return ""
