class_name MapNavigation
extends NavigationRegion2D


func _ready() -> void:
	if navigation_polygon:
		bake_navigation_polygon()
