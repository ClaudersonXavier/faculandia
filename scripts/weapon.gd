class_name Weapon
extends Node2D

const NoiseBus := preload("res://scripts/noise_bus.gd")

@export var weapon_name: String = "Arma Base"
@export var damage: float = 10.0
@export var bullet_speed: float = 600.0
@export var fire_rate: float = 0.4
@export var bullet_lifetime: float = 2.0
@export var bullet_texture: Texture2D
@export var collision_size: Vector2 = Vector2(6.0, 2.0)
@export var gunshot_noise_radius: float = 600.0
@export var magazine_size: int = 7
@export var reload_time: float = 0.8

var current_ammo: int = 7
var is_reloading: bool = false

var can_fire: bool = true


func _ready() -> void:
	current_ammo = magazine_size


func shoot(aim_direction: Vector2, aim_angle: float) -> void:
	if not can_fire:
		return
	
	if current_ammo <= 0 or is_reloading:
		return
	current_ammo -= 1
	
	can_fire = false

	var muzzle: Node2D = get_node_or_null("muzzle_marker")
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position

	var bullet = Area2D.new()
	bullet.set_script(preload("res://scripts/bullet.gd"))
	bullet.direction = aim_direction
	bullet.speed = bullet_speed
	bullet.damage = damage
	bullet.lifetime = bullet_lifetime
	bullet.bullet_texture = bullet_texture
	bullet.collision_size = collision_size
	bullet.global_position = spawn_pos
	get_tree().root.add_child(bullet)

	NoiseBus.emit(spawn_pos, gunshot_noise_radius, &"gunshot", self)

	await get_tree().create_timer(fire_rate).timeout
	can_fire = true
	

func reload() -> void:
	if is_reloading or current_ammo == magazine_size:
		return
	is_reloading = true
	await get_tree().create_timer(reload_time).timeout
	current_ammo = magazine_size
	is_reloading = false
