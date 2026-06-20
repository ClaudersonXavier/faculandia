extends ColorRect

@export var player: CharacterBody2D

var opacidade = 0.7;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = true;
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	var camera = get_viewport().get_camera_2d()
	var player_screen = viewport_size / 2.0 + (player.global_position - camera.get_screen_center_position()) * camera.zoom
	
	var mouse_screen = get_viewport().get_mouse_position()
	var aim_direction = (mouse_screen  - player_screen).normalized()
	
	material.set_shader_parameter("player_screen_pos", player_screen)
	material.set_shader_parameter("player_angle", aim_direction.angle())
	material.set_shader_parameter("cone_half_angle", deg_to_rad(player.cone_angle/2))
	material.set_shader_parameter("vision_range", player.vision_range)
	material.set_shader_parameter("darkness_alpha", opacidade)
