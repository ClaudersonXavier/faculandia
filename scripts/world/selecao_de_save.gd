extends Control
## Painel de escolha de slot, reusavel entre "Novo Jogo" e "Continuar".
## Vive em scenes/ui/ (overlay reusavel) mas o script mora em scripts/world/,
## no mesmo padrao de scenes/ui/camada_ui.tscn -> scripts/world/hud.gd.

signal slot_escolhido(slot: int, modo: int)
signal voltar_pedido

enum Modo { NOVO_JOGO, CONTINUAR }

@onready var titulo: Label = %Titulo
@onready var lista: VBoxContainer = %Lista
@onready var botao_voltar: Button = %Voltar
@onready var dialogo: ConfirmationDialog = %ConfirmarSobrescrita

var _modo: int = Modo.NOVO_JOGO
var _slot_pendente: int = -1


func _ready() -> void:
	visible = false
	botao_voltar.pressed.connect(_ao_voltar)
	dialogo.confirmed.connect(_ao_confirmar_sobrescrita)


func configurar(modo: int) -> void:
	_modo = modo
	titulo.text = "Escolha um slot" if modo == Modo.NOVO_JOGO else "Continuar de onde parou"
	_reconstruir_lista()
	visible = true


func _reconstruir_lista() -> void:
	for filho: Node in lista.get_children():
		filho.queue_free()

	var primeiro: Button = null
	for entrada: Dictionary in SaveSlots.listar():
		var slot := int(entrada["slot"])
		var vazio := bool(entrada["vazio"])
		# O autosave nao e um slot do jogador: so aparece em Continuar.
		if _modo == Modo.NOVO_JOGO and slot == SaveSlots.SLOT_AUTOSAVE:
			continue

		var botao := Button.new()
		botao.text = SaveJogo.rotulo(entrada)
		botao.clip_text = true
		botao.add_theme_font_size_override(&"font_size", 18)
		# Em Continuar so entradas com partida sao clicaveis; em Novo Jogo o
		# slot cheio e clicavel e cai no aviso de sobrescrita.
		botao.disabled = vazio and _modo == Modo.CONTINUAR
		botao.pressed.connect(_ao_escolher.bind(slot, vazio))
		lista.add_child(botao)
		if primeiro == null and not botao.disabled:
			primeiro = botao

	if primeiro != null:
		primeiro.grab_focus()
	else:
		botao_voltar.grab_focus()


func _ao_escolher(slot: int, vazio: bool) -> void:
	if _modo == Modo.NOVO_JOGO and not vazio:
		_slot_pendente = slot
		dialogo.dialog_text = "O slot %d já tem um jogo salvo. Começar um novo apaga esse progresso." % slot
		dialogo.popup_centered()
		return
	_confirmar(slot)


func _ao_confirmar_sobrescrita() -> void:
	if _slot_pendente > 0:
		_confirmar(_slot_pendente)


func _confirmar(slot: int) -> void:
	_slot_pendente = -1
	visible = false
	slot_escolhido.emit(slot, _modo)


func _ao_voltar() -> void:
	_slot_pendente = -1
	visible = false
	voltar_pedido.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if dialogo.visible:
		return # o dialogo trata o proprio ESC
	_ao_voltar()
	get_viewport().set_input_as_handled()
