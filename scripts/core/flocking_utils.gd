class_name FlockingUtils
extends RefCounted

## Calcula um vetor de separacao suave entre membros de um grupo, para
## evitar que se sobreponham. Generico o suficiente para ser reusado por
## qualquer tipo de inimigo, nao apenas Ameaca.
static func calculate_separation(
	self_node: Node2D,
	group_name: StringName,
	forward_dir: Vector2,
	separation_radius: float
) -> Vector2:
	var separation := Vector2.ZERO
	var members := self_node.get_tree().get_nodes_in_group(group_name)
	for other in members:
		if other == self_node or not is_instance_valid(other):
			continue
		var to_me := self_node.global_position - (other as Node2D).global_position
		var dist := to_me.length()
		if dist < separation_radius:
			if dist > 0.001:
				var dir := to_me / dist
				var strength := (1.0 - dist / separation_radius)
				if forward_dir != Vector2.ZERO and dir.dot(forward_dir) < -0.5:
					var perp := Vector2(-forward_dir.y, forward_dir.x)
					var side_sign := 1.0 if (self_node.get_instance_id() > other.get_instance_id()) else -1.0
					dir = (dir + perp * side_sign * 0.8).normalized()
				separation += dir * strength
			else:
				var angle_offset := float(self_node.get_instance_id() % 8) * (TAU / 8.0)
				separation += Vector2.from_angle(angle_offset)
	return separation
