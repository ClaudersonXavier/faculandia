extends CharacterBody2D

@export var speed: float = 135.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var backpedal_multiplier: float = 0.85

@export var cone_angle: float = 75.0
@export var vision_range: float = 600.0
@export var footstep_noise_radius: float = 120.0
@export var footstep_distance_threshold: float = 27.0

@onready var weapon: Node2D = get_node_or_null("Weapon")

var aim_angle: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT

var _distance_walked: float = 0.0
var _last_step_position: Vector2 = Vector2.INF
var _is_backpedaling_state: bool = false


func _ready() -> void:
	add_to_group(&"player")
	if GameState.voltando_da_loja:
		position = Vector2(60, 50)
		GameState.voltando_da_loja = false


func is_backpedaling_vector(direction: Vector2) -> bool:
	if direction == Vector2.ZERO or aim_direction == Vector2.ZERO:
		return false
	return aim_direction.dot(direction.normalized()) < -0.3


func get_movement_input() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func apply_movement(input_dir: Vector2, delta: float) -> void:
	var target_speed := speed
	if is_backpedaling_vector(input_dir):
		target_speed *= backpedal_multiplier

	var target_velocity := input_dir.normalized() * (target_speed * minf(input_dir.length(), 1.0))
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func update_animation() -> void:
	var spr := get_node_or_null("player_sprite")
	if spr == null:
		return

	spr.rotation = aim_angle - SpriteConventions.UP_FACING_OFFSET
	if spr is AnimatedSprite2D:
		var current_speed := velocity.length()
		if current_speed > 1.0:
			var is_backpedaling := is_backpedaling_vector(velocity)
			var direction_changed := is_backpedaling != _is_backpedaling_state
			AnimationUtils.play_if_needed(spr, &"walk", is_backpedaling, direction_changed)
			_is_backpedaling_state = is_backpedaling
			var speed_ratio := current_speed / maxf(speed, 0.001)
			spr.speed_scale = clampf(speed_ratio, 0.2, 1.5)
		else:
			_is_backpedaling_state = false
			AnimationUtils.play_if_needed(spr, &"idle")
			spr.speed_scale = 1.0


func _physics_process(delta: float) -> void:
	var mouse_position := get_global_mouse_position()
	aim_direction = (mouse_position - global_position).normalized()
	aim_angle = aim_direction.angle()

	var input_dir := get_movement_input()
	apply_movement(input_dir, delta)
	update_animation()

	if weapon != null:
		weapon.rotation = aim_angle

	move_and_slide()

	var camera := get_node_or_null("camera_player") as Camera2D
	var col := get_node_or_null("player_collision") as CollisionShape2D
	if camera != null and col != null and col.shape is RectangleShape2D:
		var half_col: Vector2 = (col.shape as RectangleShape2D).size / 2.0
		var min_pos: Vector2 = Vector2(camera.limit_left, camera.limit_top) + half_col
		var max_pos: Vector2 = Vector2(camera.limit_right, camera.limit_bottom) - half_col
		global_position.x = clampf(global_position.x, min_pos.x, max_pos.x)
		global_position.y = clampf(global_position.y, min_pos.y, max_pos.y)

	# Ruido de passos ao caminhar
	if _last_step_position == Vector2.INF:
		_last_step_position = global_position

	var moved_dist: float = global_position.distance_to(_last_step_position)
	_distance_walked += moved_dist
	_last_step_position = global_position

	if _distance_walked >= footstep_distance_threshold:
		NoiseBus.emit(global_position, footstep_noise_radius, &"footstep", self)
		_distance_walked -= footstep_distance_threshold

	if Input.is_action_just_pressed("shoot") and weapon != null:
		weapon.shoot(aim_direction, aim_angle)

	if Input.is_action_just_pressed("reload") and weapon != null:
		weapon.reload()


func is_in_vision(target_pos: Vector2) -> bool:
	var to_target := target_pos - global_position
	var dist := to_target.length()

	if dist > vision_range:
		return false

	var half_angle := deg_to_rad(cone_angle / 2.0)
	var target_angle := to_target.angle()
	var diff := absf(target_angle - aim_angle)
	if diff > PI:
		diff = TAU - diff

	return diff < half_angle
