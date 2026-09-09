extends Control
## Overlay exibido quando a Vida do jogador chega a zero.

@onready var painel: Control = %Painel
@onready var botao_voltar: Button = %VoltarAoSave
@onready var botao_menu: Button = %MenuPrincipal

var _player_conectado: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	painel.visible = false
	botao_voltar.pressed.connect(_voltar_ao_save)
	botao_menu.pressed.connect(_voltar_ao_menu)
	call_deferred("_conectar_ao_jogador")


func _process(_delta: float) -> void:
	if not _player_conectado:
		_conectar_ao_jogador()


func _conectar_ao_jogador() -> void:
	var jogadores := get_tree().get_nodes_in_group(&"player")
	if jogadores.is_empty():
		return
	var player: Node = jogadores[0]
	if not player.has_signal(&"died"):
		return
	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	_player_conectado = true
	if player.has_method("is_dead") and player.is_dead():
		_on_player_died()


func _on_player_died() -> void:
	painel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	botao_voltar.grab_focus()


func _voltar_ao_save() -> void:
	var cena := SaveJogo.carregar_mais_recente()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if cena.is_empty():
		get_tree().change_scene_to_file(SaveJogo.CENA_MENU)
	else:
		get_tree().change_scene_to_file(cena)


func _voltar_ao_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(SaveJogo.CENA_MENU)
