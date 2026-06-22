extends SceneTree

const PlayerVisionScript := preload("res://scripts/player_vision.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_ameaca_na_visao_direta_fica_visivel()
	await _test_ameaca_atras_fora_da_percepcao_periferica_fica_invisivel()
	await _test_ameaca_atras_dentro_da_percepcao_periferica_fica_visivel()
	await _test_bloqueador_de_visao_oculta_ameaca()
	await _test_jogador_inicia_com_percepcao_periferica_sem_corte()

	if failures > 0:
		printerr("%d teste(s) falharam" % failures)
		quit(1)
	else:
		print("Todos testes passaram")
		quit(0)


func _test_ameaca_na_visao_direta_fica_visivel() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	await physics_frame

	_assert_true(
		fixture.vision.is_position_visible(Vector2(180, 0)),
		"Ameaca na Visao Direta sem Bloqueador de Visao fica visivel"
	)

	fixture.root.queue_free()


func _test_ameaca_atras_fora_da_percepcao_periferica_fica_invisivel() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	await physics_frame

	_assert_false(
		fixture.vision.is_position_visible(Vector2(-90, 0)),
		"Ameaca atras e fora da Percepcao Periferica fica invisivel"
	)

	fixture.root.queue_free()


func _test_ameaca_atras_dentro_da_percepcao_periferica_fica_visivel() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	await physics_frame

	_assert_true(
		fixture.vision.is_position_visible(Vector2(-30, 0)),
		"Ameaca atras dentro da Percepcao Periferica fica visivel"
	)

	fixture.root.queue_free()


func _test_bloqueador_de_visao_oculta_ameaca() -> void:
	var fixture := _create_fixture()
	_add_bloqueador_de_visao(fixture.root, Vector2(80, 0))
	fixture.vision.set_aim_position(Vector2(200, 0))
	await physics_frame

	_assert_false(
		fixture.vision.is_position_visible(Vector2(160, 0)),
		"Bloqueador de Visao oculta Ameaca atras dele"
	)

	fixture.root.queue_free()


func _test_jogador_inicia_com_percepcao_periferica_sem_corte() -> void:
	var packed_scene := load("res://scenes/cena_principal.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	get_root().add_child(scene)
	await process_frame

	var player := scene.get_node("Mundo/Player") as CharacterBody2D
	var vision := player.get_node("PlayerVision")
	var required_margin: float = vision.inner_light_radius

	_assert_true(
		player.global_position.x >= required_margin and player.global_position.y >= required_margin,
		"Jogador inicia com Percepcao Periferica sem corte no canto da cena"
	)

	scene.queue_free()


func _create_fixture() -> Dictionary:
	var scene_root := Node2D.new()
	scene_root.name = "PlayerVisionFixture"
	scene_root.process_mode = Node.PROCESS_MODE_ALWAYS
	get_root().add_child(scene_root)

	var camera := Camera2D.new()
	camera.global_position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	scene_root.add_child(camera)
	camera.make_current()

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.global_position = Vector2.ZERO
	scene_root.add_child(player)

	var vision := PlayerVisionScript.new()
	vision.name = "PlayerVision"
	vision.player = player
	vision.vision_angle = 70.0
	vision.vision_distance = 220.0
	vision.inner_light_radius = 40.0
	vision.ray_count = 16
	player.add_child(vision)
	current_scene = scene_root
	return {"root": scene_root, "player": player, "vision": vision}


func _add_bloqueador_de_visao(parent: Node, position: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "BloqueadorDeVisao"
	body.collision_layer = 1
	body.collision_mask = 0
	body.global_position = position

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 80)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
