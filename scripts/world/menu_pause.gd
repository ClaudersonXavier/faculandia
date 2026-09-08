extends CanvasLayer
## Menu de pause (ESC), instanciado nas cenas de fase.

@onready var painel: Control = %PainelPause
@onready var botao_retomar: Button = %Retomar
@onready var botao_salvar: Button = %Salvar
@onready var botao_sair_menu: Button = %SairParaMenu
@onready var botao_sair_jogo: Button = %SairDoJogo
@onready var status: Label = %Status

## Restaurado ao retomar: na cena principal o cursor fica escondido,
## na loja fica visivel.
var _modo_mouse_anterior: int = Input.MOUSE_MODE_HIDDEN


func _ready() -> void:
	painel.visible = false
	botao_retomar.pressed.connect(_retomar)
	botao_salvar.pressed.connect(_on_salvar_pressed)
	botao_sair_menu.pressed.connect(_on_sair_para_o_menu_pressed)
	botao_sair_jogo.pressed.connect(_on_sair_do_jogo_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if painel.visible:
		_retomar()
	elif not get_tree().paused:
		_pausar()
	else:
		# Outro dialogo (ex. ZonaSaida) ja pausou e trata o ESC sozinho.
		return
	get_viewport().set_input_as_handled()


func _pausar() -> void:
	status.text = ""
	_modo_mouse_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	botao_salvar.text = "Salvar no slot %d" % SaveJogo.caixa_atual()
	painel.visible = true
	get_tree().paused = true
	botao_retomar.grab_focus()


func _retomar() -> void:
	painel.visible = false
	get_tree().paused = false
	Input.mouse_mode = _modo_mouse_anterior


func _on_salvar_pressed() -> void:
	var caixa := SaveJogo.caixa_atual()
	if SaveJogo.salvar_na_caixa_atual():
		status.text = "Salvo no slot %d!" % caixa
	else:
		status.text = "Não foi possível salvar"


func _on_sair_para_o_menu_pressed() -> void:
	SaveJogo.sair_para_o_menu()


func _on_sair_do_jogo_pressed() -> void:
	SaveJogo.autosalvar()
	get_tree().paused = false
	get_tree().quit()
