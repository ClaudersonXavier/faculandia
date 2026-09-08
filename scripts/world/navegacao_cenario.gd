class_name NavegacaoCenario
extends NavigationRegion2D
## Bake automatico da malha de navegacao em tempo de execucao,
## recortando obstaculos nas camadas OBSTACULO e OBSTACULO_BAIXO.

const NAVMESH_SOURCE_GROUP := &"navmesh_source"
const AGENT_RADIUS: float = 24.0


func _ready() -> void:
	if navigation_polygon == null:
		return

	# Adiciona o pai (Mundo) ao grupo de source geometry para que o bake
	# encontre todas as paredes/filhos com colisores.
	var source_node := get_parent()
	if source_node and not source_node.is_in_group(NAVMESH_SOURCE_GROUP):
		source_node.add_to_group(NAVMESH_SOURCE_GROUP)

	navigation_polygon.agent_radius = AGENT_RADIUS
	navigation_polygon.parsed_collision_mask = PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO
	navigation_polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_polygon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_polygon.source_geometry_group_name = NAVMESH_SOURCE_GROUP

	# Assegura que o contorno cubra toda a area util do mapa
	_ensure_world_bounds_outline(source_node)

	# Aguarda dois frames de fisica para garantir que todos os colisores
	# estejam registrados no PhysicsServer antes do bake.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_baking():
		bake_navigation_polygon()


func _ensure_world_bounds_outline(source_node: Node) -> void:
	var total_rect := Rect2()
	if source_node:
		for child in source_node.get_children():
			if child is TileMapLayer:
				var tml: TileMapLayer = child
				var used_rect: Rect2i = tml.get_used_rect()
				if used_rect.size != Vector2i.ZERO and tml.tile_set:
					var cell_size := Vector2(tml.tile_set.tile_size)
					var pixel_rect := Rect2(Vector2(used_rect.position) * cell_size, Vector2(used_rect.size) * cell_size)
					total_rect = _merge_rect(total_rect, pixel_rect)
			elif child is Camera2D:
				total_rect = _merge_rect(total_rect, _get_camera_rect(child))

	# Verifica limites da camera nos players caso nao estejam no source_node
	var players := get_tree().get_nodes_in_group(&"player")
	for p in players:
		var cam := p.get_node_or_null("camera_player") as Camera2D
		total_rect = _merge_rect(total_rect, _get_camera_rect(cam))

	if total_rect.size != Vector2.ZERO:
		var padded := total_rect.grow(32.0)
		navigation_polygon.clear_outlines()
		navigation_polygon.add_outline(PackedVector2Array([
			padded.position,
			Vector2(padded.end.x, padded.position.y),
			padded.end,
			Vector2(padded.position.x, padded.end.y)
		]))


func _get_camera_rect(cam: Camera2D) -> Rect2:
	if cam and cam.limit_right > cam.limit_left and cam.limit_bottom > cam.limit_top:
		return Rect2(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)
	return Rect2()


func _merge_rect(base: Rect2, other: Rect2) -> Rect2:
	if other.size == Vector2.ZERO:
		return base
	return other if base.size == Vector2.ZERO else base.merge(other)

