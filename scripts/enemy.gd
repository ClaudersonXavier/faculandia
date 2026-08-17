class_name Enemy
extends CharacterBody2D

@export var max_health: float = 24.0
@export var speed: float = 70.0

var health: float = 24.0
var target_player: Node2D = null

func _ready() -> void:
	health = max_health
	add_to_group(&"visible_entities")
	add_to_group(&"enemies")
	
	# Busca o player no grupo ou na árvore
	var players = get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		target_player = players[0]
	else:
		target_player = get_tree().root.find_child("Player", true, false)


func _physics_process(_delta: float) -> void:
	if target_player == null or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group(&"player")
		if not players.is_empty():
			target_player = players[0]
		else:
			target_player = get_tree().root.find_child("Player", true, false)
			
	if target_player != null and is_instance_valid(target_player):
		var direction := (target_player.global_position - global_position).normalized()
		velocity = direction * speed
		rotation = direction.angle()
		move_and_slide()


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()


func die() -> void:
	queue_free()
