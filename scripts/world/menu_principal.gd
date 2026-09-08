extends Control
## Primeira tela do jogo. O mesmo painel de selecao de slots serve "Novo
## Jogo" (3 slots) e "Continuar" (autosave + 3 slots); so o modo muda.

const SelecaoDeSave := preload("res://scripts/world/selecao_de_save.gd")

@onready var botao_novo_jogo: Button = %NovoJogo
@onready var botao_continuar: Button = %Continuar
@onready var botao_sair: Button = %Sair
@onready var selecao: Control = %SelecaoDeSave


func _ready() -> void:
	# paused sobrevive a troca de cena: garante que o menu nasca vivo.
	get_tree().paused = false
	# O crosshair do jogo esconde o cursor do sistema; aqui ele e obrigatorio.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	botao_novo_jogo.pressed.connect(_ao_pressionar_novo_jogo)
	botao_continuar.pressed.connect(_ao_pressionar_continuar)
	botao_sair.pressed.connect(_ao_pressionar_sair)
	selecao.slot_escolhido.connect(_ao_escolher_slot)
	selecao.voltar_pedido.connect(_atualizar_continuar)

	_atualizar_continuar()


func _atualizar_continuar() -> void:
	botao_continuar.disabled = not SaveJogo.existe_alguma_partida()
	if botao_continuar.disabled:
		botao_novo_jogo.grab_focus()
	else:
		botao_continuar.grab_focus()


func _ao_pressionar_novo_jogo() -> void:
	selecao.configurar(SelecaoDeSave.Modo.NOVO_JOGO)


func _ao_pressionar_continuar() -> void:
	selecao.configurar(SelecaoDeSave.Modo.CONTINUAR)


func _ao_pressionar_sair() -> void:
	get_tree().quit()


func _ao_escolher_slot(slot: int, modo: int) -> void:
	if modo == SelecaoDeSave.Modo.NOVO_JOGO:
		# iniciar_nova_partida aplica o reset ANTES da troca de cena, entao
		# Weapon._ready() ja nasce com a municao certa.
		get_tree().change_scene_to_file(SaveJogo.iniciar_nova_partida(slot))
		return
	var cena := SaveJogo.carregar_slot(slot)
	if cena.is_empty():
		_atualizar_continuar()
		return
	get_tree().change_scene_to_file(cena)
