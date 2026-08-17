class_name PlayerVision
extends Node2D

const FRAGMENTO_PERCEPTIVEL_SHADER: Shader = preload("res://shaders/fragmento_perceptivel.gdshader")

@export var player: CharacterBody2D
@export var overlay: ColorRect
@export_range(1.0, 180.0, 1.0) var vision_angle: float = 70.0
@export var vision_distance: float = 520.0
@export var inner_light_radius: float = 80.0
@export_range(8, 256, 1) var ray_count: int = 120
@export_range(8, 256, 1) var light_ray_count: int = 32
@export_range(32, 1152, 1) var omnidirectional_ray_count: int = 360
@export_flags_2d_physics var obstacle_layer: int = 1
@export var visible_entity_group: StringName = &"visible_entities"
@export var light_source_group: StringName = &"light_sources"
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
var _last_omnidirectional_points: PackedVector2Array = []
var _custom_aim_position: Vector2
var _uses_custom_aim_position := false
var _fragmento_perceptivel_material: ShaderMaterial


func _ready() -> void:
	_fragmento_perceptivel_material = ShaderMaterial.new()
	_fragmento_perceptivel_material.shader = FRAGMENTO_PERCEPTIVEL_SHADER
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

	if not _has_clear_line(target_position):
		return false

	if distance <= vision_distance:
		var aim_angle := _get_aim_angle()
		var angle_diff: float = abs(angle_difference(aim_angle, to_target.angle()))
		if angle_diff <= deg_to_rad(vision_angle * 0.5):
			return true

	return is_position_lit_by_any_light_source(target_position)


func is_position_lit_by_any_light_source(target_position: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group(light_source_group):
		var source := node as Node2D
		if source == null:
			continue
		var radius: float = source.get_meta("light_radius", 0.0)
		if target_position.distance_to(source.global_position) <= radius:
			for emitter_pos in _get_light_emitter_positions(source):
				if _has_clear_line_between(emitter_pos, target_position):
					return true
	return false


func set_aim_position(target_position: Vector2) -> void:
	_custom_aim_position = target_position
	_uses_custom_aim_position = true


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
	_last_omnidirectional_points = _cast_omnidirectional_visibility()

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


func _cast_omnidirectional_visibility() -> PackedVector2Array:
	var result := PackedVector2Array()
	var space_state := get_world_2d().direct_space_state
	# Limita um pouco a distancia da visao omnidirecional, senao raios serao desperdicados muito longe
	var omni_distance: float = max(vision_distance, 1000.0)
	
	for index in omnidirectional_ray_count:
		var angle := TAU * float(index) / float(omnidirectional_ray_count)
		var end := player.global_position + Vector2.RIGHT.rotated(angle) * omni_distance
		var query := PhysicsRayQueryParameters2D.create(player.global_position, end, obstacle_layer, [player.get_rid()])
		var hit := space_state.intersect_ray(query)
		result.append(hit["position"] if not hit.is_empty() else end)
		
	return result


func get_omnidirectional_visibility_points() -> PackedVector2Array:
	return _last_omnidirectional_points


func get_light_visibility_points(source: Node2D) -> PackedVector2Array:
	var radius: float = source.get_meta("light_radius", 0.0)
	return _cast_light(source.global_position, radius)


func _get_light_emitter_positions(source: Node2D) -> PackedVector2Array:
	var emitter_radius: float = source.get_meta("light_emitter_radius", 0.0)
	var pos := source.global_position
	if emitter_radius <= 0.0:
		return PackedVector2Array([pos])
	
	return PackedVector2Array([
		pos,
		pos + Vector2(0, -emitter_radius),
		pos + Vector2(0, emitter_radius),
		pos + Vector2(-emitter_radius, 0),
		pos + Vector2(emitter_radius, 0)
	])


func _cast_light(source_pos: Vector2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var space_state := get_world_2d().direct_space_state
	
	var angles := PackedFloat32Array()
	for index in light_ray_count:
		angles.append(TAU * float(index) / float(light_ray_count))
		
	var corners = _get_obstacle_corners_near(source_pos, radius)
	for corner in corners:
		var angle = (corner - source_pos).angle()
		angles.append(angle - 0.0001)
		angles.append(angle)
		angles.append(angle + 0.0001)
		
	var sorted_angles := Array(angles)
	sorted_angles.sort()
	
	for angle in sorted_angles:
		var end := source_pos + Vector2.RIGHT.rotated(angle) * radius
		var query := PhysicsRayQueryParameters2D.create(source_pos, end, obstacle_layer)
		if player != null:
			query.exclude = [player.get_rid()]
		var hit := space_state.intersect_ray(query)
		result.append(hit["position"] if not hit.is_empty() else end)
		
	return result


func _get_obstacle_corners_near(source_pos: Vector2, radius: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, source_pos)
	query.collision_mask = obstacle_layer
	var space_state := get_world_2d().direct_space_state
	var results := space_state.intersect_shape(query)
	for res in results:
		var collider = res["collider"]
		if collider is CollisionObject2D:
			for owner_id in collider.get_shape_owners():
				for shape_id in collider.shape_owner_get_shape_count(owner_id):
					var col_shape = collider.shape_owner_get_shape(owner_id, shape_id)
					var trans = collider.global_transform * collider.shape_owner_get_transform(owner_id)
					if col_shape is RectangleShape2D:
						var ext = col_shape.size / 2.0
						corners.append(trans * Vector2(-ext.x, -ext.y))
						corners.append(trans * Vector2(ext.x, -ext.y))
						corners.append(trans * Vector2(ext.x, ext.y))
						corners.append(trans * Vector2(-ext.x, ext.y))
	return corners


func _update_visible_entities() -> void:
	_update_fragmento_perceptivel_material()
	for entity in get_tree().get_nodes_in_group(visible_entity_group):
		if not entity is CanvasItem:
			continue
		entity.visible = true
		entity.material = _fragmento_perceptivel_material


func _update_fragmento_perceptivel_material() -> void:
	if _fragmento_perceptivel_material == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	_apply_perception_shader_parameters(_fragmento_perceptivel_material, viewport_size, camera)


func _update_overlay_points() -> void:
	if overlay == null or overlay.material == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	var mat = overlay.material as ShaderMaterial
	mat.set_shader_parameter("darkness_alpha", darkness_alpha)
	_apply_perception_shader_parameters(mat, viewport_size, camera)


func _apply_perception_shader_parameters(mat: ShaderMaterial, viewport_size: Vector2, camera: Camera2D) -> void:
	var screen_points := PackedVector2Array()
	screen_points.append(_world_to_screen(player.global_position, viewport_size, camera))
	for point in _last_hit_points:
		screen_points.append(_world_to_screen(point, viewport_size, camera))

	mat.set_shader_parameter("vision_points", screen_points)
	mat.set_shader_parameter("vision_point_count", screen_points.size())
	mat.set_shader_parameter("player_screen_pos", screen_points[0])
	mat.set_shader_parameter("inner_light_radius", inner_light_radius * camera.zoom.x)

	var omni_screen_points := PackedVector2Array()
	for point in _last_omnidirectional_points:
		omni_screen_points.append(_world_to_screen(point, viewport_size, camera))

	mat.set_shader_parameter("omni_points", omni_screen_points)
	mat.set_shader_parameter("omni_point_count", omni_screen_points.size())

	var light_starts := PackedInt32Array()
	var light_ends := PackedInt32Array()
	var all_light_points := PackedVector2Array()

	var light_nodes = get_tree().get_nodes_in_group(light_source_group)
	for l_node in light_nodes:
		var source = l_node as Node2D
		if source == null: continue
		var points = get_light_visibility_points(source)
		if points.is_empty(): continue
		
		var start_idx = all_light_points.size()
		for pt in points:
			all_light_points.append(_world_to_screen(pt, viewport_size, camera))
		var end_idx = all_light_points.size()
		
		light_starts.append(start_idx)
		light_ends.append(end_idx)
		
		if light_starts.size() >= 16: # MAX_LIGHT_SOURCES
			break
			
	mat.set_shader_parameter("light_count", light_starts.size())
	if light_starts.size() > 0:
		mat.set_shader_parameter("light_starts", light_starts)
		mat.set_shader_parameter("light_ends", light_ends)
		mat.set_shader_parameter("light_points", all_light_points)


func _world_to_screen(world_position: Vector2, viewport_size: Vector2, camera: Camera2D) -> Vector2:
	return viewport_size * 0.5 + (world_position - camera.get_screen_center_position()) * camera.zoom


func _has_clear_line(target_position: Vector2) -> bool:
	return _has_clear_line_between(player.global_position, target_position)


func _has_clear_line_between(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos, obstacle_layer)
	if player != null:
		query.exclude = [player.get_rid()]
	return space_state.intersect_ray(query).is_empty()


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var normalized_radius := 1.0 - 0.28 * (float(index % 2))
		points.append(Vector2.RIGHT.rotated(angle) * radius * normalized_radius)
	return points


func _get_aim_angle() -> float:
	if _uses_custom_aim_position:
		return (_custom_aim_position - player.global_position).angle()
	return (get_global_mouse_position() - player.global_position).angle()
