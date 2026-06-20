extends CharacterBody2D

const SPEED = 200.0

func _physics_process(delta: float) -> void:
	
	var mouse_position = get_global_mouse_position()
	var aim_direction = (mouse_position - global_position).normalized()
	get_node("player_sprite").rotation = aim_direction.angle()

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
