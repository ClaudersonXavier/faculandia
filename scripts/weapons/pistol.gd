extends Weapon


func _ready() -> void:
	super._ready()
	bullet_texture = preload("res://resources/sprites/bala.png")
	weapon_name = "Pistola"
	damage_min = 7.0
	damage_max = 9.0
	bullet_speed = 1500.0
	fire_rate = 0.2
	bullet_lifetime = 2.0
	collision_size = Vector2(6.0, 2.0)
