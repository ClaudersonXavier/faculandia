extends Sprite2D

@export var test_kind: StringName = &"zombie"


func _ready() -> void:
	add_to_group(&"test_objects")
	if test_kind == &"zombie":
		add_to_group(&"visible_entities")
	elif test_kind == &"light":
		add_to_group(&"light_sources")


func set_test_scale(value: float) -> void:
	scale = Vector2.ONE * value
