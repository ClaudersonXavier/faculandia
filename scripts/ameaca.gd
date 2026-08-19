class_name Ameaca
extends CharacterBody2D

# Camadas de fisica do projeto
const LAYER_OBSTACULO := 1
const LAYER_JOGADOR := 2
const LAYER_AMEACA := 4

const MIN_MOVEMENT_DISTANCE_SQUARED: float = 0.001
const DEFAULT_STOP_DISTANCE: float = 60.0

@export var max_health: float = 24.0
@export var speed: float = 70.0
@export var hit_flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var hit_flash_duration: float = 0.1
@export var path_update_interval: float = 0.2

var health: float = 24.0
var target_player: Node2D = null
var _hit_flash_tween: Tween = null
var _is_dead: bool = false
var _path_timer: float = 0.0

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")


func _ready() -> void:
	health = max_health
	collision_layer = LAYER_AMEACA
	collision_mask = LAYER_OBSTACULO | LAYER_JOGADOR | LAYER_AMEACA
	add_to_group(&"visible_entities")
	_find_player()
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_navigation_agent_velocity_computed)


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
	if distance_squared <= stop_dist * stop_dist:
		_stop_moving()
		if distance_squared > MIN_MOVEMENT_DISTANCE_SQUARED:
			rotation = to_player.angle()
		return

	var has_direct_vision := has_direct_line_of_sight_to(target_pos)
	var move_direction := to_player.normalized()

	if not has_direct_vision and navigation_agent:
		_path_timer -= delta
		if _path_timer <= 0.0:
			_path_timer = path_update_interval
			navigation_agent.target_position = target_pos

		if not navigation_agent.is_navigation_finished():
			var next_pos := navigation_agent.get_next_path_position()
			var to_next := next_pos - global_position
			if to_next.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
				move_direction = to_next.normalized()

	if move_direction.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
		rotation = move_direction.angle()
		var intended_velocity := move_direction * speed

		if navigation_agent and navigation_agent.avoidance_enabled:
			navigation_agent.set_velocity(intended_velocity)
		else:
			velocity = intended_velocity
			move_and_slide()
	else:
		_stop_moving()


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	if navigation_agent and navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(Vector2.ZERO)


func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	if _is_dead:
		return
	velocity = safe_velocity
	move_and_slide()



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
	var query := PhysicsRayQueryParameters2D.create(global_position, target_pos, LAYER_OBSTACULO)
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
