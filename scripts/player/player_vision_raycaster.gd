class_name PlayerVisionRaycaster
extends RefCounted

## Motor de raycast puro usado por PlayerVision: resolve onde um raio para
## ao atingir um obstaculo (empurrando a saida para alem da borda do
## objeto atingido) e encontra esquinas expostas de obstaculos proximos.
## Nao depende de nenhum estado de PlayerVision alem do Node2D usado para
## acessar get_world_2d().

var _owner: Node2D

# Cache de cantos expostos por TileMapLayer (chave "<instance_id>:<layer_mask>").
# Paredes de TileMapLayer sao estaticas em tempo de execucao, entao os cantos
# so precisam ser calculados uma vez por combinacao de mapa+mascara.
var _tile_corner_cache: Dictionary = {}


func _init(owner_node: Node2D) -> void:
	_owner = owner_node


func resolve_ray_hit(origin: Vector2, ray_dir: Vector2, distance: float, layer_mask: int, exclude: Array[RID] = []) -> Vector2:
	var space_state := _owner.get_world_2d().direct_space_state
	var end := origin + ray_dir * distance
	var query := PhysicsRayQueryParameters2D.create(origin, end, layer_mask, exclude)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return end

	var collider = hit["collider"]
	if collider is CollisionObject2D:
		return _get_collider_ray_exit_point(collider, origin, ray_dir, hit["position"], layer_mask)
	elif collider is TileMapLayer:
		return _get_tilemap_ray_exit_point(collider, origin, ray_dir, hit["position"], hit.get("normal", -ray_dir), layer_mask)
	return hit["position"]


func get_obstacle_corners_near(source_pos: Vector2, radius: float, layer_mask: int) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, source_pos)
	query.collision_mask = layer_mask
	var space_state := _owner.get_world_2d().direct_space_state
	var results := space_state.intersect_shape(query)
	for res in results:
		var collider = res["collider"]
		if collider is CollisionObject2D:
			for owner_id in collider.get_shape_owners():
				if collider.is_shape_owner_disabled(owner_id):
					continue
				for shape_id in collider.shape_owner_get_shape_count(owner_id):
					var col_shape = collider.shape_owner_get_shape(owner_id, shape_id)
					var trans = collider.global_transform * collider.shape_owner_get_transform(owner_id)
					if col_shape is RectangleShape2D:
						var ext = col_shape.size / 2.0
						var raw_corners := [
							trans * Vector2(-ext.x, -ext.y),
							trans * Vector2(ext.x, -ext.y),
							trans * Vector2(ext.x, ext.y),
							trans * Vector2(-ext.x, ext.y)
						]
						for c: Vector2 in raw_corners:
							if _is_exposed_corner(space_state, c, layer_mask):
								corners.append(c)
					elif col_shape is CircleShape2D:
						var r = col_shape.radius
						for k in 8:
							var a = TAU * float(k) / 8.0
							corners.append(trans * (Vector2.RIGHT.rotated(a) * r))
		elif collider is TileMapLayer:
			var tile_map: TileMapLayer = collider
			var reach := radius + Vector2(tile_map.tile_set.tile_size).length()
			var cache_key := "%d:%d" % [tile_map.get_instance_id(), layer_mask]
			if not _tile_corner_cache.has(cache_key):
				_tile_corner_cache[cache_key] = _compute_tile_corners(tile_map, layer_mask, space_state)
			for c: Vector2 in _tile_corner_cache[cache_key]:
				if c.distance_to(source_pos) <= reach:
					corners.append(c)
	return corners


## Calcula (uma unica vez por mapa+mascara) os cantos expostos de todas as
## celulas usadas de um TileMapLayer de forma deduplicada.
func _compute_tile_corners(tile_map: TileMapLayer, layer_mask: int, space_state: PhysicsDirectSpaceState2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	var seen := {}
	var ext := Vector2(tile_map.tile_set.tile_size) / 2.0
	for cell in tile_map.get_used_cells():
		var center: Vector2 = tile_map.to_global(tile_map.map_to_local(cell))
		var raw_corners := [
			center + Vector2(-ext.x, -ext.y),
			center + Vector2(ext.x, -ext.y),
			center + Vector2(ext.x, ext.y),
			center + Vector2(-ext.x, ext.y)
		]
		for c: Vector2 in raw_corners:
			var key := Vector2i(roundi(c.x), roundi(c.y))
			if not seen.has(key):
				seen[key] = true
				if _is_exposed_corner(space_state, c, layer_mask):
					out.append(c)
	return out


func _is_exposed_corner(space_state: PhysicsDirectSpaceState2D, corner: Vector2, layer_mask: int) -> bool:
	var q_nw := _is_point_in_obstacle(space_state, corner + Vector2(-2.0, -2.0), layer_mask)
	var q_ne := _is_point_in_obstacle(space_state, corner + Vector2(2.0, -2.0), layer_mask)
	var q_sw := _is_point_in_obstacle(space_state, corner + Vector2(-2.0, 2.0), layer_mask)
	var q_se := _is_point_in_obstacle(space_state, corner + Vector2(2.0, 2.0), layer_mask)

	var wall_count := int(q_nw) + int(q_ne) + int(q_sw) + int(q_se)
	if wall_count == 4 or wall_count == 3 or wall_count == 0:
		return false
	if (q_nw and q_ne and not q_sw and not q_se) or (q_sw and q_se and not q_nw and not q_ne):
		return false
	if (q_nw and q_sw and not q_ne and not q_se) or (q_ne and q_se and not q_nw and not q_sw):
		return false
	return true


func _is_point_in_obstacle(space_state: PhysicsDirectSpaceState2D, point: Vector2, layer_mask: int) -> bool:
	var point_query := PhysicsPointQueryParameters2D.new()
	point_query.position = point
	point_query.collision_mask = layer_mask
	return not space_state.intersect_point(point_query, 1).is_empty()


func _get_collider_ray_exit_point(collider: Object, ray_origin: Vector2, ray_dir: Vector2, hit_pos: Vector2, layer_mask: int = 0) -> Vector2:
	if not (collider is CollisionObject2D):
		return hit_pos

	var current_col: CollisionObject2D = collider as CollisionObject2D
	var mask := layer_mask
	if mask == 0:
		mask = current_col.collision_layer

	var space_state := _owner.get_world_2d().direct_space_state
	var final_exit_pos := hit_pos
	var visited_rids: Array[RID] = []

	for _step in 16:
		visited_rids.append(current_col.get_rid())
		var exit_pt := _calculate_col_obj_ray_exit(current_col, ray_origin, ray_dir, hit_pos)
		final_exit_pos = exit_pt

		# Verifica se na saída do bloco atual o raio entra imediatamente em um bloco vizinho da mesma camada
		var check_pos := exit_pt + ray_dir * 0.5
		var point_query := PhysicsPointQueryParameters2D.new()
		point_query.position = check_pos
		point_query.collision_mask = mask
		var results := space_state.intersect_point(point_query, 4)

		var found_next := false
		for res in results:
			var hit_collider = res.get("collider")
			if hit_collider is CollisionObject2D and not visited_rids.has(hit_collider.get_rid()):
				current_col = hit_collider as CollisionObject2D
				found_next = true
				break

		if not found_next:
			break

	return final_exit_pos


func _get_tilemap_ray_exit_point(tile_map: TileMapLayer, ray_origin: Vector2, ray_dir: Vector2, hit_pos: Vector2, hit_normal: Vector2, _layer_mask: int) -> Vector2:
	if tile_map.tile_set == null:
		return hit_pos

	var tile_size := Vector2(tile_map.tile_set.tile_size)
	var half_size := tile_size / 2.0
	# Ponto ligeiramente para dentro do primeiro tile
	var current_pos := hit_pos - hit_normal * 0.5
	var last_valid_exit := hit_pos

	for _step in 16:
		var local_pos := tile_map.to_local(current_pos)
		var cell := tile_map.local_to_map(local_pos)
		if tile_map.get_cell_source_id(cell) == -1:
			break

		var cell_center := tile_map.to_global(tile_map.map_to_local(cell))
		var rel_origin := ray_origin - cell_center
		var t_max := INF
		if absf(ray_dir.x) > 0.00001:
			var t1 := (-half_size.x - rel_origin.x) / ray_dir.x
			var t2 := (half_size.x - rel_origin.x) / ray_dir.x
			t_max = minf(t_max, maxf(t1, t2))
		if absf(ray_dir.y) > 0.00001:
			var t1 := (-half_size.y - rel_origin.y) / ray_dir.y
			var t2 := (half_size.y - rel_origin.y) / ray_dir.y
			t_max = minf(t_max, maxf(t1, t2))

		if t_max != INF and t_max > 0.0:
			var exit_pt := ray_origin + ray_dir * t_max
			last_valid_exit = exit_pt
			# Checa se entra na celula seguinte
			current_pos = exit_pt + ray_dir * 0.5
		else:
			break

	return last_valid_exit


func _march_exit_point(ray_dir: Vector2, hit_pos: Vector2, layer_mask: int) -> Vector2:
	var space_state := _owner.get_world_2d().direct_space_state
	var step := 4.0
	var max_distance := 48.0
	var traveled := 0.0
	var pos := hit_pos

	while traveled < max_distance:
		var next_pos := pos + ray_dir * step
		var confirm_pos := next_pos + ray_dir * step
		if not _is_point_in_obstacle(space_state, next_pos, layer_mask) and not _is_point_in_obstacle(space_state, confirm_pos, layer_mask):
			return pos
		pos = next_pos
		traveled += step

	return pos


func _calculate_col_obj_ray_exit(col_obj: CollisionObject2D, ray_origin: Vector2, ray_dir: Vector2, hit_pos: Vector2) -> Vector2:
	var max_exit_point := hit_pos
	var max_dist_sq := (hit_pos - ray_origin).length_squared()

	for owner_id in col_obj.get_shape_owners():
		if col_obj.is_shape_owner_disabled(owner_id):
			continue
		for shape_id in col_obj.shape_owner_get_shape_count(owner_id):
			var shape := col_obj.shape_owner_get_shape(owner_id, shape_id)
			var trans := col_obj.global_transform * col_obj.shape_owner_get_transform(owner_id)
			var exit_pt := _calculate_shape_ray_exit(shape, trans, ray_origin, ray_dir, hit_pos)
			var dist_sq := (exit_pt - ray_origin).length_squared()
			if dist_sq > max_dist_sq:
				max_dist_sq = dist_sq
				max_exit_point = exit_pt

	return max_exit_point


func _calculate_shape_ray_exit(shape: Shape2D, trans: Transform2D, ray_origin: Vector2, ray_dir: Vector2, hit_pos: Vector2) -> Vector2:
	var local_origin := trans.affine_inverse() * ray_origin
	var local_dir := trans.basis_xform_inv(ray_dir).normalized()

	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		var extents := rect.size / 2.0
		var t_min := -INF
		var t_max := INF
		if absf(local_dir.x) > 0.00001:
			var t1 := (-extents.x - local_origin.x) / local_dir.x
			var t2 := (extents.x - local_origin.x) / local_dir.x
			t_min = maxf(t_min, minf(t1, t2))
			t_max = minf(t_max, maxf(t1, t2))
		elif absf(local_origin.x) > extents.x:
			return hit_pos

		if absf(local_dir.y) > 0.00001:
			var t1 := (-extents.y - local_origin.y) / local_dir.y
			var t2 := (extents.y - local_origin.y) / local_dir.y
			t_min = maxf(t_min, minf(t1, t2))
			t_max = minf(t_max, maxf(t1, t2))
		elif absf(local_origin.y) > extents.y:
			return hit_pos

		if t_min <= t_max and t_max > 0.0:
			var local_exit := local_origin + local_dir * t_max
			return trans * local_exit

	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var radius := circle.radius
		var b := 2.0 * local_origin.dot(local_dir)
		var c := local_origin.dot(local_origin) - radius * radius
		var disc := b * b - 4.0 * c
		if disc >= 0.0:
			var t_max := (-b + sqrt(disc)) / 2.0
			if t_max > 0.0:
				var local_exit := local_origin + local_dir * t_max
				return trans * local_exit

	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var radius := capsule.radius
		var height := capsule.height
		var extents := Vector2(radius, height / 2.0)
		var t_max := INF
		if absf(local_dir.x) > 0.00001:
			var t1 := (-extents.x - local_origin.x) / local_dir.x
			var t2 := (extents.x - local_origin.x) / local_dir.x
			t_max = minf(t_max, maxf(t1, t2))
		if absf(local_dir.y) > 0.00001:
			var t1 := (-extents.y - local_origin.y) / local_dir.y
			var t2 := (extents.y - local_origin.y) / local_dir.y
			t_max = minf(t_max, maxf(t1, t2))
		if t_max != INF and t_max > 0.0:
			var local_exit := local_origin + local_dir * t_max
			return trans * local_exit

	return hit_pos
