class_name Enemy
extends CharacterBody2D

@export var max_health: float = 24.0
@export var speed: float = 70.0
@export var hit_flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var hit_flash_duration: float = 0.1

var health: float = 24.0
var target_player: Node2D = null
var _hit_flash_tween: Tween = null

func _ready() -> void:
	health = max_health
	add_to_group(&"visible_entities")
	_find_player()


func _physics_process(_delta: float) -> void:
	if target_player == null or not is_instance_valid(target_player):
		_find_player()
			
	if target_player != null and is_instance_valid(target_player):
		var direction := (target_player.global_position - global_position).normalized()
		velocity = direction * speed
		rotation = direction.angle()
		move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		target_player = players[0]


func take_damage(amount: float) -> void:
	health -= amount
	_play_hit_flash()
	if health <= 0.0:
		die()


func _play_hit_flash() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()

	modulate = hit_flash_color
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func die() -> void:
	queue_free()
