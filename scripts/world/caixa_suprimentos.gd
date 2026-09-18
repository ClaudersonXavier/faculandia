class_name CaixaSuprimentos
extends StaticBody2D

@export var id_caixa: String = ""
@export var valor: int = 15

var _coletada: bool = false
var _jogador_na_area: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var prompt_label: Label = get_node_or_null("AreaInteracao/PromptLabel")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var area_col_shape: CollisionShape2D = get_node_or_null("AreaInteracao/CollisionShape2D")


func _ready() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null and id_caixa != "" and game_state.caixas_coletadas.has(id_caixa):
		_coletada = true
		queue_free()


func _process(_delta: float) -> void:
	if _jogador_na_area and not _coletada and prompt_label != null and prompt_label.visible:
		prompt_label.global_position = global_position + Vector2(-70, -28)


func _unhandled_input(event: InputEvent) -> void:
	if _jogador_na_area and not _coletada and event.is_action_pressed(&"interact"):
		abrir()


func abrir() -> void:
	if _coletada:
		return
	_coletada = true
	_jogador_na_area = false

	# Desativa colisão imediatamente para liberar passagem e iluminação
	collision_layer = 0
	if col_shape != null:
		col_shape.set_deferred("disabled", true)
	if area_col_shape != null:
		area_col_shape.set_deferred("disabled", true)

	var game_state = get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.dinheiro += valor
		if id_caixa != "" and not game_state.caixas_coletadas.has(id_caixa):
			game_state.caixas_coletadas.append(id_caixa)

	_marcar_coletada(true)


func _marcar_coletada(com_animacao: bool) -> void:
	_coletada = true
	if not com_animacao:
		queue_free()
		return

	var tween := create_tween()
	if sprite != null:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.25)

	if prompt_label != null:
		prompt_label.text = "+$%d!" % valor
		prompt_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		tween.tween_property(prompt_label, "position:y", prompt_label.position.y - 20.0, 0.6)
		tween.parallel().tween_property(prompt_label, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)
	else:
		tween.tween_callback(queue_free)


func _on_area_interacao_body_entered(body: Node2D) -> void:
	if _coletada:
		return
	if body.is_in_group(&"player"):
		_jogador_na_area = true
		if prompt_label != null:
			prompt_label.global_position = global_position + Vector2(-70, -28)
			prompt_label.text = "Aperte 'E' para abrir [+$%d]" % valor
			prompt_label.modulate = Color.WHITE
			prompt_label.visible = true


func _on_area_interacao_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_jogador_na_area = false
		if not _coletada and prompt_label != null:
			prompt_label.visible = false
