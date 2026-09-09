extends Control
## Hub de selecao de zona entre o menu principal e as fases jogaveis.
## Ver CONTEXT.md, verbete "Selecao de Cenario".

const ZONAS := [
	{"cena": SaveJogo.CENA_ZONA_NORTE, "nome": "Zona Norte"},
	{"cena": SaveJogo.CENA_ZONA_SUL, "nome": "Zona Sul"},
]

@onready var cartoes: HBoxContainer = %Cartoes
@onready var botao_voltar: Button = %Voltar


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cartoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botao_voltar.pressed.connect(_ao_voltar)
	_construir_cartoes()


func _construir_cartoes() -> void:
	for filho: Node in cartoes.get_children():
		filho.queue_free()
	var primeiro: Button = null
	for zona: Dictionary in ZONAS:
		var botao := Button.new()
		botao.text = "%s\n\n" % [zona["nome"]]
		botao.custom_minimum_size = Vector2(280, 200)
		botao.add_theme_font_size_override(&"font_size", 22)
		botao.pressed.connect(_ao_escolher.bind(zona["cena"]))
		cartoes.add_child(botao)
		if primeiro == null:
			primeiro = botao
	if primeiro != null:
		primeiro.grab_focus()
	else:
		botao_voltar.grab_focus()


func _ao_escolher(cena: String) -> void:
	# A partida ja comecou nesse ponto (viemos do menu ou de outra zona/loja),
	# entao a troca precisa passar por SaveJogo.trocar_fase para autossalvar.
	SaveJogo.trocar_fase(cena)


func _ao_voltar() -> void:
	SaveJogo.sair_para_o_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		# Atalho secreto de dev: pula direto pra cena de teste, sem autossalvar
		# (nao queremos que o save real do jogador aponte pra cena_principal.tscn
		# por acidente). Mesmo padrao de tecla hardcoded sem action que
		# scripts/testing/test_spawner.gd ja usa pra Z/L/Delete/Backspace.
		# Aqui F3 nao tem relacao com o F3 de scripts/noise/noise_visualizer.gd
		# (que so existe dentro das cenas de fase) — sao dois handlers separados
		# em cenas diferentes, sem conflito de runtime.
		# set_input_as_handled() TEM que vir ANTES de trocar de cena: depois
		# que a troca acontece este no ja saiu da arvore e get_viewport()
		# retorna null (era exatamente o bug: crash em "_unhandled_input").
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(SaveJogo.CENA_TESTE)
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_ao_voltar()
