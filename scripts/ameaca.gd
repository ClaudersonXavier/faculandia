class_name Ameaca
extends CharacterBody2D

# Camadas de fisica do projeto
const LAYER_OBSTACULO := 1
const LAYER_JOGADOR := 2
const LAYER_AMEACA := 4
const LAYER_OBSTACULO_BAIXO := 8

const MIN_MOVEMENT_DISTANCE_SQUARED: float = 0.001
const DEFAULT_STOP_DISTANCE: float = 60.0

@export var max_health: float = 24.0
@export var speed: float = 70.0
@export var hit_flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var hit_flash_duration: float = 0.1
@export var path_update_interval: float = 0.2
@export var separation_radius: float = 60.0
@export var separation_weight: float = 0.6
@export var debug_logging: bool = false

var health: float = 24.0
var target_player: Node2D = null
var _hit_flash_tween: Tween = null
var _is_dead: bool = false
var _path_timer: float = 0.0

# Variaveis de rastreamento para debug
var _debug_prev_rotation: float = 0.0
var _debug_prev_has_direct_vision: bool = false
var _debug_heartbeat_timer: float = 0.0
var _debug_prev_next_waypoint: Vector2 = Vector2.ZERO

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var sprite = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = LAYER_AMEACA
	collision_mask = LAYER_OBSTACULO | LAYER_OBSTACULO_BAIXO | LAYER_JOGADOR
	add_to_group(&"ameacas")
	add_to_group(&"visible_entities")
	_find_player()
	_debug_prev_rotation = rotation
	if is_instance_valid(target_player):
		_debug_prev_has_direct_vision = has_direct_line_of_sight_to(target_player.global_position)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_instance_valid(target_player):
		_find_player()

	if not is_instance_valid(target_player):
		_stop_moving()
		return

	var target_pos := target_player.global_position
	var to_player := target_pos - global_position
	var distance_squared := to_player.length_squared()
	var stop_dist := navigation_agent.target_desired_distance if navigation_agent else DEFAULT_STOP_DISTANCE

	var has_direct_vision := has_direct_line_of_sight_to(target_pos)
	var move_direction := Vector2.ZERO
	var nav_next_pos := Vector2.ZERO
	var is_at_target := false

	if has_direct_vision:
		if distance_squared <= stop_dist * stop_dist:
			is_at_target = true
			if distance_squared > MIN_MOVEMENT_DISTANCE_SQUARED:
				rotation = to_player.angle()
		else:
			move_direction = to_player.normalized()
	elif navigation_agent:
		_path_timer -= delta
		if _path_timer <= 0.0:
			_path_timer = path_update_interval
			navigation_agent.target_position = target_pos

		if navigation_agent.is_navigation_finished():
			is_at_target = true
		else:
			nav_next_pos = navigation_agent.get_next_path_position()
			var to_next := nav_next_pos - global_position
			if to_next.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
				move_direction = to_next.normalized()
	else:
		if distance_squared <= stop_dist * stop_dist:
			is_at_target = true
		else:
			move_direction = to_player.normalized()

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
			if sprite.animation != &"walk" or not sprite.is_playing():
				sprite.play(&"walk")
		move_and_slide()
	else:
		_stop_moving()

	if debug_logging:
		_debug_log_frame(delta, has_direct_vision, move_direction, nav_next_pos, prev_pos, prev_rot)


func _calculate_separation_vector(forward_dir: Vector2) -> Vector2:
	var separation := Vector2.ZERO
	var ameacas = get_tree().get_nodes_in_group(&"ameacas")
	for other in ameacas:
		if other == self or not is_instance_valid(other):
			continue
		var to_me := global_position - (other as Node2D).global_position
		var dist := to_me.length()
		if dist < separation_radius:
			if dist > 0.001:
				var dir := to_me / dist
				var strength := (1.0 - dist / separation_radius)
				if forward_dir != Vector2.ZERO and dir.dot(forward_dir) < -0.5:
					var perp := Vector2(-forward_dir.y, forward_dir.x)
					var side_sign := 1.0 if (get_instance_id() > other.get_instance_id()) else -1.0
					dir = (dir + perp * side_sign * 0.8).normalized()
				separation += dir * strength
			else:
				var angle_offset := float(get_instance_id() % 8) * (TAU / 8.0)
				separation += Vector2.from_angle(angle_offset)
	return separation


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	if sprite and sprite is AnimatedSprite2D:
		if sprite.animation != &"idle":
			sprite.play(&"idle")


func _debug_log_frame(
	delta: float,
	has_direct_vision: bool,
	move_direction: Vector2,
	nav_next_pos: Vector2,
	prev_pos: Vector2,
	prev_rot: float
) -> void:
	var me_id := name
	var moved_vec := global_position - prev_pos
	var actual_speed := (moved_vec.length() / delta) if delta > 0.0 else 0.0
	var mode_name := "DIRECT" if has_direct_vision else "NAVMESH"
	var real_vel := get_real_velocity()
	var slide_count := get_slide_collision_count()

	# 1. Mudanca de estado de visao direta
	if has_direct_vision != _debug_prev_has_direct_vision:
		var dist_to_p := global_position.distance_to(target_player.global_position) if is_instance_valid(target_player) else 0.0
		print("[DEBUG-AMEACA][VISION-SWITCH] %s | modo: %s | pos=(%.1f, %.1f) | dist_player=%.1f" % [
			me_id, mode_name, global_position.x, global_position.y, dist_to_p
		])
		_debug_prev_has_direct_vision = has_direct_vision

	# 2. Curva fechada
	var rot_diff_deg := rad_to_deg(abs(wrapf(rotation - prev_rot, -PI, PI)))
	if rot_diff_deg > 25.0 and move_direction.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
		var waypoint_dist := global_position.distance_to(nav_next_pos) if nav_next_pos != Vector2.ZERO else 0.0
		print("[DEBUG-AMEACA][SHARP-TURN] %s | virou %.1f deg | modo=%s | waypoint=(%.1f, %.1f), dist_waypoint=%.1f | vel=(%.1f, %.1f)" % [
			me_id, rot_diff_deg, mode_name, nav_next_pos.x, nav_next_pos.y, waypoint_dist, velocity.x, velocity.y
		])

	# 3. Colisoes com obstaculos
	var obstacles: Array[String] = []
	for i in range(slide_count):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		var col_name: String = str(collider.name) if collider != null else "null"
		var col_normal := col.get_normal()
		var depth := col.get_depth()
		obstacles.append("%s(n=(%.2f, %.2f), depth=%.2f)" % [col_name, col_normal.x, col_normal.y, depth])

	# 4. Pico anormal de velocidade
	if actual_speed > (speed * 1.25):
		print("[DEBUG-AMEACA][SPEED-SPIKE] %s | VELOCIDADE ANORMAL: %.1f px/s (esperado %.1f px/s, fator %.2fx) | real_vel=(%.1f, %.1f) | modo=%s | obstaculos=%s" % [
			me_id, actual_speed, speed, (actual_speed / speed), real_vel.x, real_vel.y, mode_name, str(obstacles)
		])

	# 5. Heartbeat periodico
	_debug_heartbeat_timer += delta
	if _debug_heartbeat_timer >= 1.0:
		_debug_heartbeat_timer = 0.0
		var dist_player := global_position.distance_to(target_player.global_position) if is_instance_valid(target_player) else 0.0
		print("[DEBUG-AMEACA][HEARTBEAT] %s | pos=(%.1f, %.1f) | modo=%s | vel=(%.1f, %.1f) | dist_player=%.1f" % [
			me_id, global_position.x, global_position.y, mode_name, velocity.x, velocity.y, dist_player
		])

	_debug_prev_rotation = rotation
	_debug_prev_next_waypoint = nav_next_pos



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
	var query := PhysicsRayQueryParameters2D.create(global_position, target_pos, LAYER_OBSTACULO | LAYER_OBSTACULO_BAIXO)
	var result := space_state.intersect_ray(query)
	return result.is_empty()


func take_damage(amount: float) -> void:
	if _is_dead:
		return

	health -= amount
	_play_hit_flash()
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
	set_physics_process(false)
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape:
		col_shape.set_deferred("disabled", true)

	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		await _hit_flash_tween.finished

	queue_free()
