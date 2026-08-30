extends SceneTree

const AmeacaScene := preload("res://scenes/objects/ameaca.tscn")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_navigation_mesh_path_generation()

	if failures > 0:
		printerr("%d teste(s) de navegacao falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de navegacao passaram!")
		quit(0)


func _test_navigation_mesh_path_generation() -> void:
	var root := Node2D.new()
	root.name = "NavTestRoot"
	get_root().add_child(root)
	current_scene = root

	var nav_region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()

	# Define outline do mapa (0, 0) a (600, 600)
	var outline := PackedVector2Array([
		Vector2(0, 0),
		Vector2(600, 0),
		Vector2(600, 600),
		Vector2(0, 600)
	])
	nav_poly.add_outline(outline)
	nav_poly.parsed_collision_mask = Ameaca.LAYER_OBSTACULO
	nav_region.navigation_polygon = nav_poly
	root.add_child(nav_region)

	# Adiciona obstaculo no centro (x: 200 a 400, y: 100 a 300)
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = Ameaca.LAYER_OBSTACULO
	obstacle.collision_mask = 0
	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(200, 200)
	col_shape.shape = rect_shape
	obstacle.add_child(col_shape)
	obstacle.position = Vector2(300, 200)
	nav_region.add_child(obstacle)

	nav_region.bake_navigation_polygon()

	# Aguarda sincronizacao do NavigationServer
	await physics_frame
	await physics_frame

	var ameaca: Ameaca = AmeacaScene.instantiate()
	ameaca.position = Vector2(100, 200)
	root.add_child(ameaca)

	var player := Node2D.new()
	player.add_to_group(&"player")
	player.position = Vector2(500, 200)
	root.add_child(player)

	await physics_frame
	await physics_frame

	# Ameaca nao deve ter visao direta devido ao obstaculo no meio
	_assert_false(ameaca.has_direct_line_of_sight_to(player.global_position), "Visao deve estar bloqueada pelo obstaculo central")

	# Dispara processamento fisico
	ameaca._physics_process(0.016)

	var nav_agent: NavigationAgent2D = ameaca.get_node("NavigationAgent2D")
	_assert_true(nav_agent.target_position == player.global_position, "Target position do agent deve ser a posicao do player")

	# Aguarda a geracao do caminho pelo NavigationServer
	await physics_frame
	await physics_frame

	ameaca._physics_process(0.016)

	var next_pos := nav_agent.get_next_path_position()
	# O próximo ponto não deve ser a linha direta y=200 através da parede, mas sim contornando (y < 100 ou y > 300) ou progredindo
	_assert_true(next_pos != Vector2.ZERO, "Next path position deve ser valida")

	# Limpa
	player.remove_from_group(&"player")
	root.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
