extends Node

const ZOMBIE_TEXTURE_PATH := "res://resources/sprites/test/zumbi-de-teste.png"
const LIGHT_TEXTURE_PATH := "res://resources/sprites/test/fonte-de-luz-teste.png"
const TEST_ENTITY_SCRIPT: Script = preload("res://scripts/testing/test_entity.gd")

@export var world: Node2D
@export var initial_zombies: Array[Vector2] = [Vector2(320, 360), Vector2(180, 260)]
@export var initial_light_position: Vector2 = Vector2(320, 260)
@export var zombie_scale: float = 0.045
@export var light_scale: float = 0.045
@export var light_radius: float = 140.0
@export var light_emitter_radius: float = 24.0
@export var delete_radius: float = 80.0


func _ready() -> void:
	for position in initial_zombies:
		_spawn_zombie(position)
	_spawn_light(initial_light_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_spawn_zombie(_mouse_world_position())
		elif event.keycode == KEY_L:
			_spawn_light(_mouse_world_position())
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_delete_nearest_test_object(_mouse_world_position())


const AMEACA_SCENE: PackedScene = preload("res://scenes/objects/ameaca.tscn")

func _spawn_zombie(position: Vector2) -> void:
	var ameaca = AMEACA_SCENE.instantiate()
	ameaca.global_position = position
	world.add_child.call_deferred(ameaca)


func _spawn_light(position: Vector2) -> void:
	var light_source := Sprite2D.new()
	light_source.name = "FonteLuzTeste"
	light_source.texture = TextureUtils.load_png(LIGHT_TEXTURE_PATH)
	light_source.script = TEST_ENTITY_SCRIPT
	light_source.set("test_kind", &"light")
	light_source.set_meta("light_radius", light_radius)
	light_source.set_meta("light_emitter_radius", light_emitter_radius)
	light_source.centered = true
	light_source.z_index = 18
	light_source.global_position = position
	light_source.call("set_test_scale", light_scale)
	world.add_child.call_deferred(light_source)


func _delete_nearest_test_object(position: Vector2) -> void:
	var nearest: Node2D
	var nearest_distance := delete_radius
	for object in get_tree().get_nodes_in_group(&"test_objects"):
		var test_object := object as Node2D
		if test_object == null:
			continue
		var distance: float = test_object.global_position.distance_to(position)
		if distance < nearest_distance:
			nearest = test_object
			nearest_distance = distance
	if nearest != null:
		nearest.queue_free()


func _mouse_world_position() -> Vector2:
	return world.get_global_mouse_position() if world != null else Vector2.ZERO
