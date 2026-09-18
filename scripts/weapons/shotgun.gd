class_name Shotgun
extends Weapon


func _campo_pente() -> String:
	return "shotgun_pente"


func _campo_reserva() -> String:
	return "shotgun_reserva"


func _campo_reserva_maxima() -> String:
	return "shotgun_reserva_maxima"


func _ready() -> void:
	if ResourceLoader.exists("res://resources/sprites/bago.png"):
		bullet_texture = load("res://resources/sprites/bago.png")
	weapon_name = "Escopeta"
	bullet_speed = 900.0
	fire_rate = 0.8
	bullet_lifetime = 0.35
	collision_size = Vector2(4.0, 4.0)
	gunshot_noise_radius = 900.0
	projectiles_per_shot = 6
	spread_degrees = 38.0
	knockback_force = 120.0
	reload_one_by_one = true
	UpgradesShotgun.aplicar_em_shotgun(self, _get_game_state())
	super._ready()
