extends Area2D

var direction: Vector2 = Vector2.ZERO
var speed: float = 600.0
var damage: float = 0.0
var lifetime: float = 2.0
var bullet_texture: Texture2D
var collision_size: Vector2


func _ready() -> void:
	rotation = direction.angle() + PI / 2
	if bullet_texture:
		var sprite = Sprite2D.new()
		sprite.texture = bullet_texture
		sprite.centered = true
		add_child(sprite)
	else:
		queue_redraw()

	var col_shape = RectangleShape2D.new()
	col_shape.size = collision_size

	var col = CollisionShape2D.new()
	col.shape = col_shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	collision_layer = 0
	collision_mask = 1


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	if not bullet_texture:
		draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
		draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.7, 0.0, 0.25))


func _on_body_entered(_b: Node2D) -> void:
	queue_free()


func _on_area_entered(_a: Area2D) -> void:
	queue_free()
