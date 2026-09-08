class_name AmeacaDebugVisualizer
extends Node2D

## Renderiza visualmente o alcance de visão, linha de visada, destino atual
## (jogador, ruído ou último ponto) e caminho de navegação das Ameaças.
## Ativado/desativado pela tecla F2 (ou ação debug_zombie).

static var debug_draw_enabled: bool = false
static var _last_toggle_frame: int = -1

var ameaca: CharacterBody2D
var _was_active: bool = false


func _init(p_ameaca: CharacterBody2D = null) -> void:
	ameaca = p_ameaca
	top_level = true
	z_index = 100
	visible = false


static func toggle_debug() -> void:
	debug_draw_enabled = not debug_draw_enabled
	print("[DEBUG-AMEACA] Visao e destino debug: %s (F2)" % ("LIGADA" if debug_draw_enabled else "DESLIGADA"))


static func check_toggle_input() -> void:
	var pressed := false
	if Input.is_action_just_pressed(&"debug_zombie"):
		pressed = true
	elif not InputMap.has_action(&"debug_zombie") and Input.is_key_pressed(KEY_F2):
		pressed = true

	if pressed:
		var current_frame := Engine.get_physics_frames()
		if current_frame != _last_toggle_frame:
			_last_toggle_frame = current_frame
			toggle_debug()


func update_frame() -> void:
	if debug_draw_enabled:
		visible = true
		queue_redraw()
		_was_active = true
	elif _was_active:
		_was_active = false
		visible = false
		queue_redraw()


func _draw() -> void:
	if not debug_draw_enabled or not is_instance_valid(ameaca) or ameaca.is_dead():
		return

	var me_pos := ameaca.global_position

	# 1. Raio de Visão da Ameaça (círculo azul/ciano)
	var vis_range: float = ameaca.vision_range
	if vis_range > 0.0:
		draw_arc(me_pos, vis_range, 0.0, TAU, 48, Color(0.2, 0.6, 1.0, 0.25), 1.5)

	# 2. Linha de Visão Direta para o Jogador
	var raw_player = ameaca.target_player
	var player: Node2D = raw_player if is_instance_valid(raw_player) else null
	if player != null:
		var p_pos := player.global_position
		var has_direct: bool = ameaca.has_direct_vision_to_player()
		if has_direct:
			# Linha verde brilhante até o jogador
			draw_line(me_pos, p_pos, Color(0.2, 1.0, 0.2, 0.85), 2.0)
			draw_circle(p_pos, 7.0, Color(0.2, 1.0, 0.2, 0.4))
			draw_arc(p_pos, 11.0, 0.0, TAU, 16, Color(0.2, 1.0, 0.2, 0.9), 1.5)
		else:
			# Linha vermelha suave mostrando visão bloqueada
			draw_line(me_pos, p_pos, Color(1.0, 0.2, 0.2, 0.35), 1.0)

	# 3. Onde o zumbi quer ir (Destino)
	var target_info: Dictionary = ameaca.get_debug_target_info()
	var target_pos: Vector2 = target_info.get("position", Vector2.INF)
	var target_label: String = target_info.get("label", "")
	var target_color: Color = target_info.get("color", Color.WHITE)

	if target_pos != Vector2.INF:
		# Desenha marcador no alvo de destino
		draw_circle(target_pos, 8.0, Color(target_color.r, target_color.g, target_color.b, 0.35))
		draw_arc(target_pos, 14.0, 0.0, TAU, 24, target_color, 2.0)
		draw_line(target_pos + Vector2(-6, 0), target_pos + Vector2(6, 0), Color.WHITE, 1.5)
		draw_line(target_pos + Vector2(0, -6), target_pos + Vector2(0, 6), Color.WHITE, 1.5)

		var font_tgt := ThemeDB.fallback_font
		if font_tgt != null and target_label != "":
			var tgt_lbl_pos := target_pos + Vector2(10, 4)
			draw_string(font_tgt, tgt_lbl_pos, target_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, target_color)

		# 4. Caminho de Navegação (NavigationAgent2D)
		var nav_agent: NavigationAgent2D = ameaca.navigation_agent
		if nav_agent != null:
			var nav_path := nav_agent.get_current_navigation_path()
			if nav_path.size() >= 2:
				draw_polyline(nav_path, Color(target_color.r, target_color.g, target_color.b, 0.85), 2.5)
				for pt in nav_path:
					draw_circle(pt, 3.0, target_color)
				var next_wp := nav_agent.get_next_path_position()
				if next_wp != Vector2.ZERO:
					draw_arc(next_wp, 6.0, 0.0, TAU, 16, Color.CYAN, 2.0)
					draw_line(me_pos, next_wp, Color(0.2, 0.9, 1.0, 0.8), 1.5)
			else:
				draw_line(me_pos, target_pos, Color(target_color.r, target_color.g, target_color.b, 0.7), 2.0)


	# 5. Rótulo de status flutuante sobre a ameaça
	var font := ThemeDB.fallback_font
	if font != null:
		var status_text := ""
		var status_color := Color.WHITE
		match ameaca.get_behavior_state():
			Ameaca.BehaviorState.CHASING_PLAYER:
				status_text = "PERSEGUINDO (VISAO)"
				status_color = Color(0.3, 1.0, 0.3)
			Ameaca.BehaviorState.INVESTIGATING_SOUND:
				status_text = "INVESTIGANDO SOM"
				status_color = Color(1.0, 0.85, 0.2)
			Ameaca.BehaviorState.INVESTIGATING_LAST_SEEN:
				status_text = "BUSCANDO ULTIMO PONTO"
				status_color = Color(0.5, 0.8, 1.0)
			_:
				status_text = "OCIOSO (SEM ESTIMULO)"
				status_color = Color(0.7, 0.7, 0.7)

		var text_pos := me_pos + Vector2(-55, -28)
		draw_rect(Rect2(text_pos + Vector2(-4, -11), Vector2(130, 15)), Color(0, 0, 0, 0.65))
		draw_string(font, text_pos, status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, status_color)
