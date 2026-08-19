class_name NavegacaoCenario
extends NavigationRegion2D


func _ready() -> void:
	if navigation_polygon != null:
		navigation_polygon.parsed_collision_mask = Ameaca.LAYER_OBSTACULO
		bake_navigation_polygon()

