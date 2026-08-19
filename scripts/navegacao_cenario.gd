class_name NavegacaoCenario
extends NavigationRegion2D
## Bake automatico da malha de navegacao em tempo de execucao,
## recortando obstaculos na camada LAYER_OBSTACULO.

const NAVMESH_SOURCE_GROUP := &"navmesh_source"


func _ready() -> void:
	if navigation_polygon == null:
		return

	# Adiciona o pai (Mundo) ao grupo de source geometry para que o bake
	# encontre todas as paredes/filhos com colisores.
	var source_node := get_parent()
	if source_node and not source_node.is_in_group(NAVMESH_SOURCE_GROUP):
		source_node.add_to_group(NAVMESH_SOURCE_GROUP)

	navigation_polygon.parsed_collision_mask = Ameaca.LAYER_OBSTACULO
	navigation_polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_polygon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_polygon.source_geometry_group_name = NAVMESH_SOURCE_GROUP

	# Aguarda dois frames de fisica para garantir que todos os colisores
	# estejam registrados no PhysicsServer antes do bake.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_baking():
		bake_navigation_polygon()
