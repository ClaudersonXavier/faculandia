extends Node

const ZOMBIE_TEXTURE_PATH := "res://sprites/test/zumbi-de-teste.png"
const LIGHT_TEXTURE_PATH := "res://sprites/test/fonte-de-luz-teste.png"
const TEST_ENTITY_SCRIPT: Script = preload("res://scripts/test_entity.gd")

@export var world: Node2D
@export var initial_zombies: Array[Vector2] = [Vector2(430, 260), Vector2(180, 260)]
@export var initial_lights: Array[Vector2] = [Vector2(320, 360)]
@export var zombie_scale: float = 0.045
@export var light_scale: float = 0.045
@export var delete_radius: float = 80.0


func _ready() -> void:
	for position in initial_zombies:
		_spawn_zombie(position)
	for position in initial_lights:
		_spawn_light(position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_spawn_zombie(_mouse_world_position())
		elif event.keycode == KEY_L:
			_spawn_light(_mouse_world_position())
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_delete_nearest_test_object(_mouse_world_position())


func _spawn_zombie(position: Vector2) -> void:
	var zombie := Sprite2D.new()
	zombie.name = "ZumbiTeste"
	zombie.texture = _load_png_texture(ZOMBIE_TEXTURE_PATH)
	zombie.script = TEST_ENTITY_SCRIPT
	zombie.set("test_kind", &"zombie")
	zombie.centered = true
	zombie.z_index = 20
	zombie.global_position = position
	zombie.call("set_test_scale", zombie_scale)
	world.add_child(zombie)


func _spawn_light(position: Vector2) -> void:
	var light_source := Sprite2D.new()
	light_source.name = "FonteLuzTeste"
	light_source.texture = _load_png_texture(LIGHT_TEXTURE_PATH)
	light_source.script = TEST_ENTITY_SCRIPT
	light_source.set("test_kind", &"light")
	light_source.centered = true
	light_source.z_index = 18
	light_source.global_position = position
	light_source.call("set_test_scale", light_scale)
	world.add_child(light_source)

	var light := PointLight2D.new()
	light.name = "GlowTeste"
	light.energy = 0.65
	light.texture_scale = 1.4
	light.color = Color(1.0, 0.72, 0.35)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	light.texture = texture
	light_source.add_child(light)


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


func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("Nao foi possivel carregar textura de teste: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
