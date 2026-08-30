class_name PhysicsUtils

static func has_clear_line(space_state: PhysicsDirectSpaceState2D, from_pos: Vector2, to_pos: Vector2, mask: int, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos, mask, exclude)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return (hit["position"] - to_pos).length_squared() < 4.0
