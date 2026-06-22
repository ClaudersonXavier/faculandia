class_name PlayerVision
extends Node2D

@export var player: CharacterBody2D
@export var overlay: ColorRect
@export_range(1.0, 180.0, 1.0) var vision_angle: float = 70.0
@export var vision_distance: float = 520.0
@export var inner_light_radius: float = 80.0
@export_range(8, 256, 1) var ray_count: int = 120
@export_flags_2d_physics var obstacle_layer: int = 1
@export var visible_entity_group: StringName = &"visible_entities"
@export_range(0.0, 1.0, 0.01) var darkness_alpha: float = 0.72
@export var light_color: Color = Color(1.0, 0.83, 0.48, 0.28)
@export var inner_light_color: Color = Color(1.0, 0.78, 0.36, 0.42)
@export var min_move_to_rebuild: float = 2.0
@export var min_angle_to_rebuild: float = 0.01
@export var draw_debug_polygons: bool = false

var _vision_polygon: Polygon2D
var _inner_polygon: Polygon2D
var _last_position := Vector2.INF
var _last_angle := INF
var _last_hit_points: PackedVector2Array = []


func _ready() -> void:
	_create_visuals()
	_rebuild(true)


func _physics_process(_delta: float) -> void:
	if player == null:
		return

	global_position = player.global_position
	_rebuild(false)
	_update_visible_entities()


func is_position_visible(target_position: Vector2) -> bool:
	if player == null:
		return true

	var to_target := target_position - player.global_position
	var distance := to_target.length()
	if distance <= inner_light_radius:
		return _has_clear_line(target_position)
	if distance > vision_distance:
		return false

	var aim_angle := _get_aim_angle()
	var angle_diff: float = abs(angle_difference(aim_angle, to_target.angle()))
	if angle_diff > deg_to_rad(vision_angle * 0.5):
		return false

	return _has_clear_line(target_position)


func _create_visuals() -> void:
	_vision_polygon = Polygon2D.new()
	_vision_polygon.name = "VisionConeVisual"
	_vision_polygon.color = light_color
	_vision_polygon.visible = draw_debug_polygons
	_vision_polygon.z_index = 90
	add_child(_vision_polygon)

	_inner_polygon = Polygon2D.new()
	_inner_polygon.name = "InnerLightVisual"
	_inner_polygon.color = inner_light_color
	_inner_polygon.visible = draw_debug_polygons
	_inner_polygon.z_index = 91
	add_child(_inner_polygon)


func _rebuild(force: bool) -> void:
	var aim_angle := _get_aim_angle()
	if not force:
		var moved: bool = player.global_position.distance_to(_last_position) >= min_move_to_rebuild
		var turned: bool = abs(angle_difference(aim_angle, _last_angle)) >= min_angle_to_rebuild
		if not moved and not turned:
			return

	_last_position = player.global_position
	_last_angle = aim_angle
	_last_hit_points = _cast_cone(aim_angle)

	var cone_points := PackedVector2Array([Vector2.ZERO])
	for point in _last_hit_points:
		cone_points.append(to_local(point))
	_vision_polygon.polygon = cone_points
	_inner_polygon.polygon = _build_circle_polygon(inner_light_radius, 48)
	_update_overlay_points()


func _cast_cone(aim_angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var half_angle := deg_to_rad(vision_angle * 0.5)
	var steps = max(ray_count - 1, 1)
	var space_state := get_world_2d().direct_space_state

	for index in ray_count:
		var t := float(index) / float(steps)
		var ray_angle := aim_angle - half_angle + (half_angle * 2.0 * t)
		var end := player.global_position + Vector2.RIGHT.rotated(ray_angle) * vision_distance
		var query := PhysicsRayQueryParameters2D.create(player.global_position, end, obstacle_layer, [player.get_rid()])
		var hit := space_state.intersect_ray(query)
		result.append(hit["position"] if not hit.is_empty() else end)

	return result


func _update_visible_entities() -> void:
	for entity in get_tree().get_nodes_in_group(visible_entity_group):
		if not entity is CanvasItem:
			continue
		entity.visible = is_position_visible(entity.global_position)


func _update_overlay_points() -> void:
	if overlay == null or overlay.material == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var screen_points := PackedVector2Array()
	screen_points.append(_world_to_screen(player.global_position, viewport_size, camera))
	for point in _last_hit_points:
		screen_points.append(_world_to_screen(point, viewport_size, camera))

	overlay.material.set_shader_parameter("vision_points", screen_points)
	overlay.material.set_shader_parameter("vision_point_count", screen_points.size())
	overlay.material.set_shader_parameter("player_screen_pos", screen_points[0])
	overlay.material.set_shader_parameter("inner_light_radius", inner_light_radius * camera.zoom.x)
	overlay.material.set_shader_parameter("darkness_alpha", darkness_alpha)


func _world_to_screen(world_position: Vector2, viewport_size: Vector2, camera: Camera2D) -> Vector2:
	return viewport_size * 0.5 + (world_position - camera.get_screen_center_position()) * camera.zoom


func _has_clear_line(target_position: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target_position, obstacle_layer, [player.get_rid()])
	return space_state.intersect_ray(query).is_empty()


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var normalized_radius := 1.0 - 0.28 * (float(index % 2))
		points.append(Vector2.RIGHT.rotated(angle) * radius * normalized_radius)
	return points


func _get_aim_angle() -> float:
	return (get_global_mouse_position() - player.global_position).angle()
