class_name Ameaca
extends CharacterBody2D

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
var _jogador_na_area_loot: bool = false
var _path_timer: float = 0.0

var _debug_logger: AmeacaDebugLogger

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var sprite = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.AMEACA
	collision_mask = PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO | PhysicsLayers.JOGADOR
	add_to_group(&"ameacas")
	add_to_group(&"visible_entities")
	_find_player()
	_debug_logger = AmeacaDebugLogger.new()
	_debug_logger._prev_rotation = rotation
	if is_instance_valid(target_player):
		_debug_logger._prev_has_direct_vision = has_direct_line_of_sight_to(target_player.global_position)


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
			AnimationUtils.play_if_needed(sprite, &"walk")
		move_and_slide()
	else:
		_stop_moving()

	if debug_logging:
		_debug_logger.log_frame(self, delta, has_direct_vision, move_direction, nav_next_pos, prev_pos, prev_rot)


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
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.dinheiro += 5
	queue_free()
