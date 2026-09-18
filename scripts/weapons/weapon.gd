class_name Weapon
extends Node2D

@export var weapon_name: String = "Arma Base"
@export var damage: float = 10.0
## Se damage_max > damage_min, shoot() sorteia o dano de cada tiro nesse
## intervalo em vez de usar o damage fixo acima. Default -1/-1 (desligado)
## mantem retrocompatibilidade com armas que so configuram damage.
@export var damage_min: float = -1.0
@export var damage_max: float = -1.0
## Chance (0.0-1.0) de um tiro ser critico e causar o dobro do dano.
@export var crit_chance: float = 0.0
@export var bullet_speed: float = 600.0
@export var fire_rate: float = 0.4
@export var bullet_lifetime: float = 2.0
@export var bullet_texture: Texture2D
@export var collision_size: Vector2 = Vector2(6.0, 2.0)
@export var gunshot_noise_radius: float = 600.0
@export var magazine_size: int = 7
@export var reload_time: float = 0.8
@export var projectiles_per_shot: int = 1
@export var spread_degrees: float = 0.0
@export var knockback_force: float = 0.0
@export var reload_one_by_one: bool = false

var current_ammo: int = 7
var is_reloading: bool = false

var can_fire: bool = true


func _campo_pente() -> String:
	return "municao_pente"


func _campo_reserva() -> String:
	return "municao_reserva"


func _campo_reserva_maxima() -> String:
	return "municao_reserva_maxima"


func _deve_sincronizar_com_game_state() -> bool:
	var p := get_parent()
	return p != null and p.is_in_group(&"player")


func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _ready() -> void:
	var game_state := _get_game_state()
	if _deve_sincronizar_com_game_state() and game_state and game_state.get(_campo_pente()) != null:
		current_ammo = int(game_state.get(_campo_pente()))
	else:
		current_ammo = magazine_size


func shoot(aim_direction: Vector2, _aim_angle: float) -> void:
	if not can_fire:
		return
	
	if current_ammo <= 0 or is_reloading:
		return
	current_ammo -= 1
	var game_state := _get_game_state()
	if _deve_sincronizar_com_game_state() and game_state:
		game_state.set(_campo_pente(), current_ammo)
	
	can_fire = false

	var muzzle: Node2D = get_node_or_null("muzzle_marker")
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position

	var perp := Vector2(-aim_direction.y, aim_direction.x)

	for i: int in range(projectiles_per_shot):
		var bullet = Area2D.new()
		bullet.set_script(preload("res://scripts/weapons/bullet.gd"))
		var dano_efetivo := randf_range(damage_min, damage_max) if damage_max > damage_min else damage
		if randf() < crit_chance:
			dano_efetivo *= 2.0

		var angle_offset := 0.0
		var lateral_offset := Vector2.ZERO
		if spread_degrees > 0.0:
			if projectiles_per_shot > 1:
				var t := (float(i) / float(projectiles_per_shot - 1)) - 0.5
				var jitter := randf_range(-spread_degrees * 0.12, spread_degrees * 0.12)
				angle_offset = deg_to_rad(t * spread_degrees + jitter)
				lateral_offset = perp * (t * 10.0 + randf_range(-1.5, 1.5))
			else:
				angle_offset = deg_to_rad(randf_range(-spread_degrees * 0.5, spread_degrees * 0.5))

		bullet.direction = aim_direction.rotated(angle_offset)
		bullet.speed = bullet_speed
		bullet.damage = dano_efetivo
		bullet.lifetime = bullet_lifetime
		bullet.bullet_texture = bullet_texture
		bullet.collision_size = collision_size
		bullet.knockback_force = knockback_force
		bullet.global_position = spawn_pos + lateral_offset
		get_tree().root.add_child(bullet)

	NoiseBus.emit(spawn_pos, gunshot_noise_radius, &"gunshot", self)

	await get_tree().create_timer(fire_rate).timeout
	can_fire = true


func reload() -> void:
	if is_reloading or current_ammo >= magazine_size:
		return
	var game_state := _get_game_state()
	var sinc := _deve_sincronizar_com_game_state() and game_state != null
	var campo_res := _campo_reserva()
	var campo_pnt := _campo_pente()
	var reserva: int = int(game_state.get(campo_res)) if sinc else magazine_size
	if reserva <= 0:
		return
	
	is_reloading = true

	if reload_one_by_one:
		while current_ammo < magazine_size and is_reloading and is_inside_tree():
			reserva = int(game_state.get(campo_res)) if sinc else reserva
			if reserva <= 0:
				break
			await get_tree().create_timer(reload_time).timeout
			if not is_reloading or not is_inside_tree():
				break
			current_ammo += 1
			if sinc:
				game_state.set(campo_pnt, current_ammo)
				game_state.set(campo_res, int(game_state.get(campo_res)) - 1)
			else:
				reserva -= 1
	else:
		var faltando := magazine_size - current_ammo
		var pegar := mini(faltando, reserva)
		await get_tree().create_timer(reload_time).timeout
		if is_reloading and is_inside_tree():
			current_ammo += pegar
			if sinc:
				game_state.set(campo_pnt, current_ammo)
				game_state.set(campo_res, int(game_state.get(campo_res)) - pegar)

	is_reloading = false


func cancelar_recarga() -> void:
	is_reloading = false
