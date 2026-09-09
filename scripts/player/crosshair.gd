extends Sprite2D

## Vive na CanvasLayer (camada_ui.tscn), como ultimo filho — assim desenha
## por cima de tudo (paredes, HUD, overlay de escuridao da visao) e nunca e'
## escurecida pelo shader de fog-of-war, que so' escurece o que ja foi
## desenhado ANTES dele na arvore (mundo em canvas layer 0). Por estar numa
## CanvasLayer, a posicao e' em coordenadas de tela/viewport, nao de mundo —
## por isso usa get_viewport().get_mouse_position() em vez de
## get_global_mouse_position(). Pelo mesmo motivo, tambem nao sofre mais o
## zoom da Camera2D do jogador (que so' afeta o que e' desenhado em espaco de
## mundo) — sem compensar isso a mira ficaria menor do que antes (quando era
## filha do Player e era ampliada pelo zoom da camera). Por isso escala pelo
## zoom da camera ativa a cada frame, pra manter o tamanho visual de sempre.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _physics_process(_delta: float) -> void:
	global_position = get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_2d()
	if camera:
		scale = camera.zoom
