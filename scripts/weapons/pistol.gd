extends Weapon


func _ready() -> void:
	super._ready()
	bullet_texture = preload("res://resources/sprites/bala.png")
	weapon_name = "Pistola"
	bullet_speed = 1500.0
	fire_rate = 0.2
	bullet_lifetime = 2.0
	collision_size = Vector2(6.0, 2.0)
	UpgradesPistola.aplicar_em_pistola(self, _get_game_state())
