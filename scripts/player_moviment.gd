extends CharacterBody2D

@export var cone_angle = 75;
@export var vision_range = 600;

@onready var weapon = $Weapon

var aim_angle = 0;
var aim_direction: Vector2


const SPEED = 150.0

func _physics_process(_delta: float) -> void:
	
	var mouse_position = get_global_mouse_position()
	aim_direction = (mouse_position - global_position).normalized()
	aim_angle = aim_direction.angle() 
	get_node("player_sprite").rotation = aim_angle
	weapon.rotation = aim_angle

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
	
	var camera := $camera_player
	var half_col: Vector2 = $player_collision.shape.size / 2.0
	var min_pos: Vector2 = Vector2(camera.limit_left, camera.limit_top) + half_col
	var max_pos: Vector2 = Vector2(camera.limit_right, camera.limit_bottom) - half_col

	global_position.x = clamp(global_position.x, min_pos.x, max_pos.x)
	global_position.y = clamp(global_position.y, min_pos.y, max_pos.y)
	
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
