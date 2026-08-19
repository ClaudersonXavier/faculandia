class_name Ameaca
extends CharacterBody2D

# Camadas de fisica do projeto
const LAYER_OBSTACULO := 1
const LAYER_JOGADOR := 2
const LAYER_AMEACA := 4

const MIN_MOVEMENT_DISTANCE_SQUARED: float = 0.001

@export var max_health: float = 24.0
@export var speed: float = 70.0
@export var hit_flash_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var hit_flash_duration: float = 0.1

var health: float = 24.0
var target_player: Node2D = null
var _hit_flash_tween: Tween = null
var _is_dead: bool = false


func _ready() -> void:
	health = max_health
	collision_layer = LAYER_AMEACA
	collision_mask = LAYER_OBSTACULO | LAYER_JOGADOR | LAYER_AMEACA
	add_to_group(&"visible_entities")
	_find_player()


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	if not is_instance_valid(target_player):
		_find_player()

	if is_instance_valid(target_player):
		var to_player := target_player.global_position - global_position
		if to_player.length_squared() > MIN_MOVEMENT_DISTANCE_SQUARED:
			var direction := to_player.normalized()
			velocity = direction * speed
			rotation = direction.angle()
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		target_player = players[0]


func take_damage(amount: float) -> void:
	if _is_dead:
		return

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
	_is_dead = true
	set_physics_process(false)
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape:
		col_shape.set_deferred("disabled", true)

	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		await _hit_flash_tween.finished

	queue_free()
