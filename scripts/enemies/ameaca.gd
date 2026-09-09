class_name Ameaca
extends CharacterBody2D

const MIN_MOVEMENT_DISTANCE_SQUARED: float = 0.001
## Raio do circulo de colisao da Ameaca (14px) + metade da caixa do player
## (~10-14px dependendo do angulo) = contato fisico real entre ~24 e ~28px.
## 30px da uma folga pequena pra garantir que "chegou" dispare de forma
## confiavel mesmo com o ajuste de colisao da fisica, sem parecer que ataca
## de longe (o valor antigo, 60px, parava bem antes do contato de verdade —
## dava a impressao de "bater" de longe, quase no raio do circulo de visao).
const DEFAULT_STOP_DISTANCE: float = 30.0
const DEFAULT_PATH_DESIRED_DISTANCE: float = 8.0
const STUCK_CHECK_FRAMES: int = 15
const STUCK_MIN_DISTANCE_SQ: float = 16.0  # 4px
const AmeacaDebugVisualizerScript := preload("res://scripts/enemies/ameaca_debug_visualizer.gd")
## "Tapa" corpo-a-corpo: dispara quando a Ameaca ja chegou perto do jogador
## (mesmo DEFAULT_STOP_DISTANCE que ja usa pra parar de andar), respeitando
## um cooldown pra nao descontar vida a cada frame parada ali.
const ATTACK_COOLDOWN: float = 1.0
const ATTACK_DAMAGE: int = 1

enum BehaviorState { IDLE, CHASING_PLAYER, INVESTIGATING_SOUND, INVESTIGATING_LAST_SEEN }

@export var max_health: float = 20.0
@export var speed: float = 70.0
@export var hit_flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var hit_flash_duration: float = 0.1
@export var path_update_interval: float = 0.2
@export var separation_radius: float = 60.0
@export var separation_weight: float = 0.6
@export var hearing_sensitivity: float = 1.0
@export var vision_range: float = 380.0
@export var sound_investigate_stop_distance: float = 30.0
@export var debug_logging: bool = false

var health: float = 20.0
var target_player: Node2D = null
var _hit_flash_tween: Tween = null
var _is_dead: bool = false
var _jogador_na_area_loot: bool = false
var _path_timer: float = 0.0

## Id estavel dentro do snapshot da zona (ver scripts/world/zona_populador.gd).
## -1 = nao veio de um snapshot (ex. instancia fixa em cena de teste).
var spawn_id: int = -1
var _looteado: bool = false

var _sound_target_pos: Vector2 = Vector2.INF
var _has_sound_target: bool = false
var _last_seen_player_pos: Vector2 = Vector2.INF
var _is_investigating_last_seen: bool = false
var _had_direct_vision_prev: bool = false
var _is_noise_bus_connected: bool = false
var _last_nav_target: Vector2 = Vector2.INF
var _stuck_check_pos: Vector2 = Vector2.INF
var _stuck_frame_count: int = 0
var _attack_cooldown_timer: float = 0.0

var _debug_logger: AmeacaDebugLogger
var _debug_visualizer: Node2D

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var sprite = get_node_or_null("AnimatedSprite2D")


func _enter_tree() -> void:
	_connect_noise_bus()


func _exit_tree() -> void:
	_disconnect_noise_bus()


func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.AMEACA
	collision_mask = PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO | PhysicsLayers.JOGADOR
	add_to_group(&"ameacas")
	add_to_group(&"visible_entities")
	_connect_noise_bus()
	_find_player()
	_debug_logger = AmeacaDebugLogger.new()
	_debug_logger._prev_rotation = rotation
	if is_instance_valid(target_player):
		_debug_logger._prev_has_direct_vision = has_direct_vision_to_player()
	_debug_visualizer = AmeacaDebugVisualizerScript.new(self)
	add_child(_debug_visualizer)
	if navigation_agent:
		navigation_agent.path_desired_distance = DEFAULT_PATH_DESIRED_DISTANCE


func _connect_noise_bus() -> void:
	var bus := NoiseBus.get_instance()
	if is_instance_valid(bus):
		if not bus.noise_emitted.is_connected(_on_noise_emitted):
			bus.noise_emitted.connect(_on_noise_emitted)
		_is_noise_bus_connected = true


func _disconnect_noise_bus() -> void:
	var bus := NoiseBus.instance
	if is_instance_valid(bus) and bus.noise_emitted.is_connected(_on_noise_emitted):
		bus.noise_emitted.disconnect(_on_noise_emitted)
	_is_noise_bus_connected = false


func _on_noise_emitted(event: NoiseEvent) -> void:
	if _is_dead or not is_inside_tree():
		return
	if event == null or event.emitter == self:
		return
	if NoiseBus.is_noise_heard(global_position, event, hearing_sensitivity):
		_on_noise_heard(event)


func _on_noise_heard(event: NoiseEvent) -> void:
	# Se ja possui visao direta para o jogador, prioriza a visao direta
	if has_direct_vision_to_player():
		return
	investigate_sound(event.position)


func investigate_sound(sound_pos: Vector2) -> void:
	_sound_target_pos = sound_pos
	_has_sound_target = true
	_is_investigating_last_seen = false
	_path_timer = 0.0
	_last_nav_target = sound_pos
	if navigation_agent:
		navigation_agent.target_desired_distance = sound_investigate_stop_distance
		navigation_agent.target_position = sound_pos


func is_dead() -> bool:
	return _is_dead


func foi_looteado() -> bool:
	return _looteado


## Coloca a ameaca direto no estado de corpo (sem passar por take_damage/die
## visualmente) — usado ao restaurar um snapshot onde essa ameaca ja morreu
## numa visita anterior a zona. So deve ser chamada logo apos add_child, ja
## que reaproveita die() (que assume _ready() ja rodou e setou max_health).
func spawn_como_corpo() -> void:
	health = 0.0
	die()


func get_behavior_state() -> BehaviorState:
	if has_direct_vision_to_player():
		return BehaviorState.CHASING_PLAYER
	if _has_sound_target:
		return BehaviorState.INVESTIGATING_SOUND
	if _is_investigating_last_seen:
		return BehaviorState.INVESTIGATING_LAST_SEEN
	return BehaviorState.IDLE


func get_debug_target_info() -> Dictionary:
	if has_direct_vision_to_player() and is_instance_valid(target_player):
		return {
			"position": target_player.global_position,
			"label": "JOGADOR (VISAO DIRETA)",
			"color": Color(0.2, 1.0, 0.3)
		}
	if _has_sound_target:
		return {
			"position": _sound_target_pos,
			"label": "SOM (RUIDO)",
			"color": Color(1.0, 0.85, 0.1)
		}
	if _is_investigating_last_seen:
		return {
			"position": _last_seen_player_pos,
			"label": "ULTIMO LOCAL VISTO",
			"color": Color(0.5, 0.8, 1.0)
		}
	return {
		"position": Vector2.INF,
		"label": "",
		"color": Color.WHITE
	}


func has_investigate_target() -> bool:
	return _has_sound_target or _is_investigating_last_seen


func get_investigate_target() -> Vector2:
	if _has_sound_target:
		return _sound_target_pos
	if _is_investigating_last_seen:
		return _last_seen_player_pos
	return Vector2.INF


func has_direct_vision_to_player() -> bool:
	if not is_instance_valid(target_player):
		_find_player()
	if not is_instance_valid(target_player):
		return false
	var to_player := target_player.global_position - global_position
	if vision_range > 0.0 and to_player.length_squared() > (vision_range * vision_range):
		return false
	return has_direct_line_of_sight_to(target_player.global_position)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not _is_noise_bus_connected:
		_connect_noise_bus()

	if not is_instance_valid(target_player):
		_find_player()

	var has_direct_vision := has_direct_vision_to_player()
	var has_target := false
	var target_pos := Vector2.ZERO
	var is_player_target := false

	if has_direct_vision:
		target_pos = target_player.global_position
		has_target = true
		is_player_target = true
		_last_seen_player_pos = target_pos
		_is_investigating_last_seen = false
		_has_sound_target = false
		_sound_target_pos = Vector2.INF
	elif _has_sound_target:
		target_pos = _sound_target_pos
		has_target = true
	elif _had_direct_vision_prev and _last_seen_player_pos != Vector2.INF:
		target_pos = _last_seen_player_pos
		has_target = true
		_is_investigating_last_seen = true
		_last_nav_target = Vector2.INF
		_path_timer = 0.0
	elif _is_investigating_last_seen and _last_seen_player_pos != Vector2.INF:
		target_pos = _last_seen_player_pos
		has_target = true

	_had_direct_vision_prev = is_player_target

	var move_direction := Vector2.ZERO
	var nav_next_pos := Vector2.ZERO
	var is_at_target := false
	var has_direct_path := false

	if has_target:
		var to_target := target_pos - global_position
		var distance_squared := to_target.length_squared()
		var stop_dist := DEFAULT_STOP_DISTANCE if is_player_target else sound_investigate_stop_distance
		if navigation_agent and navigation_agent.target_desired_distance != stop_dist:
			navigation_agent.target_desired_distance = stop_dist

		# Verifica se ha caminho direto e livre de colisoes para o corpo fisico da ameaca
		has_direct_path = has_clear_path_to(target_pos)
		var arrived_direct := distance_squared <= stop_dist * stop_dist

		if has_direct_path or navigation_agent == null:
			if arrived_direct:
				is_at_target = true
				if distance_squared > MIN_MOVEMENT_DISTANCE_SQUARED:
					rotation = to_target.angle()
			else:
				move_direction = to_target.normalized()
		else:
			var target_changed := _last_nav_target == Vector2.INF or target_pos.distance_squared_to(_last_nav_target) > 16.0
			_path_timer -= delta
			if target_changed or _path_timer <= 0.0:
				_path_timer = path_update_interval
				_last_nav_target = target_pos
				navigation_agent.target_position = target_pos

			var nav_finished := navigation_agent.is_navigation_finished()
			var final_pos := navigation_agent.get_final_position()
			var near_final := final_pos != Vector2.ZERO and global_position.distance_squared_to(final_pos) <= stop_dist * stop_dist

			if arrived_direct or (nav_finished and near_final):
				is_at_target = true
			else:
				nav_next_pos = navigation_agent.get_next_path_position()
				var to_next := nav_next_pos - global_position
				if to_next.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
					move_direction = to_next.normalized()

		if is_at_target and not is_player_target:
			# Chegou ao local onde identificou o barulho ou ultimo ponto: encerra a investigacao
			_has_sound_target = false
			_sound_target_pos = Vector2.INF
			_is_investigating_last_seen = false
			_last_seen_player_pos = Vector2.INF
			_last_nav_target = Vector2.INF
	else:
		is_at_target = true
		move_direction = Vector2.ZERO

	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	if is_player_target and is_at_target and _attack_cooldown_timer <= 0.0:
		_atacar_jogador()
		_attack_cooldown_timer = ATTACK_COOLDOWN

	# Aplica forca de separacao suave entre ameacas para evitar sobreposicao
	var separation_vector := _calculate_separation_vector(move_direction)
	if separation_vector != Vector2.ZERO:
		if is_at_target:
			move_direction = separation_vector.normalized() * 0.5
		elif move_direction != Vector2.ZERO:
			move_direction = (move_direction + separation_vector * separation_weight).normalized()
		else:
			move_direction = separation_vector.normalized()
	elif is_at_target:
		move_direction = Vector2.ZERO

	var prev_pos := global_position
	var prev_rot := rotation

	if move_direction.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
		if not is_at_target:
			rotation = move_direction.angle()
		velocity = move_direction * speed
		if sprite and sprite is AnimatedSprite2D:
			AnimationUtils.play_if_needed(sprite, &"walk")
		move_and_slide()
	else:
		_stop_moving()

	# Deteccao de travamento: se tentando se mover via navmesh mas quase parado,
	# forca recalculo do caminho e descola o zumbi da parede usando a normal/tangente da colisao.
	if has_target and not is_at_target and not has_direct_path:
		_stuck_frame_count += 1
		if _stuck_frame_count >= STUCK_CHECK_FRAMES:
			var moved_sq := global_position.distance_squared_to(_stuck_check_pos) if _stuck_check_pos != Vector2.INF else 9999.0
			if moved_sq < STUCK_MIN_DISTANCE_SQ:
				# Travado: forca recalculo do caminho
				_path_timer = 0.0
				_last_nav_target = Vector2.INF
				if navigation_agent:
					navigation_agent.target_position = target_pos
				# Aplica impulso para descolar da parede/quina
				if get_slide_collision_count() > 0:
					var col := get_slide_collision(0)
					var normal := col.get_normal()
					var tangent := Vector2(-normal.y, normal.x)
					var to_tgt := target_pos - global_position
					if tangent.dot(to_tgt) < 0.0:
						tangent = -tangent
					velocity = (normal * 0.5 + tangent * 0.8).normalized() * speed
					move_and_slide()
				elif move_direction.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
					var perp := Vector2(-move_direction.y, move_direction.x)
					velocity = perp * speed * 0.7
					move_and_slide()
			_stuck_check_pos = global_position
			_stuck_frame_count = 0
		elif _stuck_check_pos == Vector2.INF:
			_stuck_check_pos = global_position
	else:
		_stuck_check_pos = Vector2.INF
		_stuck_frame_count = 0

	if debug_logging:
		_debug_logger.log_frame(self, delta, has_direct_path, move_direction, nav_next_pos, prev_pos, prev_rot)

	AmeacaDebugVisualizerScript.check_toggle_input()
	if _debug_visualizer != null:
		_debug_visualizer.update_frame()


func _calculate_separation_vector(forward_dir: Vector2) -> Vector2:
	return FlockingUtils.calculate_separation(self, &"ameacas", forward_dir, separation_radius)


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	if sprite and sprite is AnimatedSprite2D:
		AnimationUtils.play_if_needed(sprite, &"idle")


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		target_player = players[0]


func has_direct_line_of_sight_to(target_pos: Vector2) -> bool:
	var world_2d := get_world_2d()
	if world_2d == null:
		return true
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return true
	return PhysicsUtils.has_clear_line(space_state, global_position, target_pos, PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO)


func has_clear_path_to(target_pos: Vector2, body_radius: float = 13.0) -> bool:
	var world_2d := get_world_2d()
	if world_2d == null:
		return true
	var space_state := world_2d.direct_space_state
	if space_state == null:
		return true
	return PhysicsUtils.has_clear_motion(space_state, global_position, target_pos, body_radius, PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO)


func _atacar_jogador() -> void:
	if is_instance_valid(target_player) and target_player.has_method("take_damage"):
		target_player.take_damage(ATTACK_DAMAGE)



func take_damage(amount: float) -> void:
	if _is_dead:
		return

	health -= amount
	_play_hit_flash()
	if not has_direct_vision_to_player() and is_instance_valid(target_player):
		investigate_sound(target_player.global_position)

	if health <= 0.0:
		die()


func _play_hit_flash() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()

	modulate = hit_flash_color
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func die() -> void:
	_is_dead = true
	_disconnect_noise_bus()
	set_physics_process(false)
	if _debug_visualizer != null:
		_debug_visualizer.visible = false
	if sprite and sprite is AnimatedSprite2D:
		AnimationUtils.play_if_needed(sprite, &"idle")
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape:
		col_shape.set_deferred("disabled", true)

	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		await _hit_flash_tween.finished

	modulate = Color(0.35, 0.35, 0.35)


func _on_area_loot_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_jogador_na_area_loot = true


func _on_area_loot_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_jogador_na_area_loot = false


func _process(_delta: float) -> void:
	var label := $AreaLoot/LootLabel
	label.visible = _is_dead and _jogador_na_area_loot
	label.global_position = global_position + Vector2(-70.0, -28.0)
	if _is_dead and _jogador_na_area_loot and Input.is_action_just_pressed("interact"):
		_lootar()


func _lootar() -> void:
	if _looteado:
		return
	_looteado = true
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.dinheiro += 5
	queue_free()
