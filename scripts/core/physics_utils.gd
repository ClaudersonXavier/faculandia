class_name PhysicsUtils

static func has_clear_line(space_state: PhysicsDirectSpaceState2D, from_pos: Vector2, to_pos: Vector2, mask: int, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos, mask, exclude)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return (hit["position"] - to_pos).length_squared() < 4.0


static func has_clear_motion(space_state: PhysicsDirectSpaceState2D, from_pos: Vector2, to_pos: Vector2, shape_radius: float, mask: int, exclude: Array[RID] = []) -> bool:
	var motion := to_pos - from_pos
	if motion.length_squared() < 0.001:
		return true
	var shape := CircleShape2D.new()
	shape.radius = shape_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = mask
	query.exclude = exclude
	query.transform = Transform2D(0.0, from_pos)
	query.motion = motion
	var cast_res := space_state.cast_motion(query)
	if cast_res.is_empty():
		return true
	return cast_res[1] >= 0.99


static func is_position_clear(space_state: PhysicsDirectSpaceState2D, pos: Vector2, radius: float, mask: int, exclude: Array[RID] = []) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = mask
	query.exclude = exclude
	query.transform = Transform2D(0.0, pos)
	return space_state.intersect_shape(query, 1).is_empty()
