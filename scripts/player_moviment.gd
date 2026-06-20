extends CharacterBody2D

const SPEED = 200.0

func _physics_process(delta: float) -> void:

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
