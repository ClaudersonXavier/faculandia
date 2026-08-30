extends Sprite2D

@export var test_kind: StringName = &"zombie"
@export_file("*.png") var texture_path: String


func _ready() -> void:
	_load_texture()
	add_to_group(&"test_objects")
	if test_kind == &"zombie":
		add_to_group(&"visible_entities")
	elif test_kind == &"light":
		add_to_group(&"light_sources")


func set_test_scale(value: float) -> void:
	scale = Vector2.ONE * value


func _load_texture() -> void:
	if texture_path.is_empty():
		return
	texture = TextureUtils.load_png(texture_path)
