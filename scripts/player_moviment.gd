extends CharacterBody2D

const NoiseBus := preload("res://scripts/noise_bus.gd")

@export var cone_angle = 75;
@export var vision_range = 600;
@export var footstep_noise_radius: float = 120.0
@export var footstep_distance_threshold: float = 40.0

@onready var weapon = $Weapon

var aim_angle = 0;
var aim_direction: Vector2

var _distance_walked: float = 0.0
var _last_step_position: Vector2 = Vector2.INF

const SPEED = 150.0

func _physics_process(_delta: float) -> void:
	
	var mouse_position = get_global_mouse_position()
	aim_direction = (mouse_position - global_position).normalized()
	aim_angle = aim_direction.angle() 
	var spr = get_node_or_null("player_sprite")
	if spr != null:
		spr.rotation = aim_angle

	var w = get_node_or_null("Weapon")
	if w != null:
		w.rotation = aim_angle

	# Handle jump.
	var ydirection = Input.get_axis("ui_up", "ui_down")
	if ydirection:
		velocity.y = ydirection * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var xdirection := Input.get_axis("ui_left", "ui_right") 
	if xdirection:
		velocity.x = xdirection * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	var camera = get_node_or_null("camera_player") as Camera2D
	var col = get_node_or_null("player_collision") as CollisionShape2D
	if camera != null and col != null and col.shape is RectangleShape2D:
		var half_col: Vector2 = (col.shape as RectangleShape2D).size / 2.0
		var min_pos: Vector2 = Vector2(camera.limit_left, camera.limit_top) + half_col
		var max_pos: Vector2 = Vector2(camera.limit_right, camera.limit_bottom) - half_col
		global_position.x = clamp(global_position.x, min_pos.x, max_pos.x)
		global_position.y = clamp(global_position.y, min_pos.y, max_pos.y)

	# Ruido de passos ao caminhar
	if _last_step_position == Vector2.INF:
		_last_step_position = global_position

	var moved_dist: float = global_position.distance_to(_last_step_position)
	if moved_dist == 0.0 and velocity.length_squared() > 0.0:
		moved_dist = velocity.length() * _delta

	_distance_walked += moved_dist
	_last_step_position = global_position

	if _distance_walked >= footstep_distance_threshold:
		NoiseBus.emit(global_position, footstep_noise_radius, &"footstep", self)
		_distance_walked = 0.0
	
	if Input.is_action_just_pressed("shoot"):
		weapon.shoot(aim_direction, aim_angle)


func is_in_vision(target_pos: Vector2) -> bool:
	var to_target = target_pos - global_position
	var dist = to_target.length()
	
	if dist > vision_range:
		return false
	
	var half_angle = deg_to_rad(cone_angle / 2.0)
	var target_angle = to_target.angle()
	var diff = abs(target_angle - aim_angle)
	if diff > PI:
		diff = TAU - diff
	
	return diff < half_angle
