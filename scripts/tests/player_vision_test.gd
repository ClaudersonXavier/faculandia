extends SceneTree

const PlayerVisionScript := preload("res://scripts/player/player_vision.gd")

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
	## TDD Cycles (RED→GREEN)
	# - [x] T1: Fonte de luz revela ameaça fora da Mira
	# - [x] T2: Bloqueador entre fonte e ameaça impede revelação
	# - [x] T3: Percepção 360° limita revelação visual
	# - [x] T4: Malha da percepção 360° para no bloqueador
	# - [x] T5: Malha da percepção 360° cabe no overlay
	# - [x] T6: Cena principal cabe no overlay
	# - [x] T7: Fonte de luz não usa PointLight2D
	# - [x] T8: Núcleo da fonte respeita malha da luz
	# - [x] T9: Fonte ilumina do corpo inteiro
	# - [x] T10: Malha da fonte para no bloqueador
	# - [ ] T11: Malha da fonte usa quinas do bloqueador
	await _test_fonte_de_luz_revela_ameaca_fora_da_mira()
	await _test_bloqueador_entre_fonte_e_ameaca_impede_revelacao()
	await _test_percepcao_360_limita_revelacao_visual()
	await _test_malha_da_percepcao_360_para_no_bloqueador()
	await _test_malha_da_percepcao_360_cabe_no_overlay()
	await _test_cena_principal_cabe_no_overlay()
	await _test_fonte_de_luz_nao_usa_point_light_2d()
	await _test_malha_da_fonte_para_no_bloqueador()
	await _test_fonte_ilumina_do_corpo_inteiro()
	await _test_malha_da_fonte_usa_quinas_do_bloqueador()
	await _test_ameaca_parcialmente_percebida_recebe_fragmento_perceptivel()
	await _test_objeto_na_visao_direta_fica_completamente_dentro_da_malha_iluminada()
	await _test_objeto_atras_de_outro_fica_em_sombra()
	await _test_percepcao_periferica_atravessa_obstaculos_baixos_mas_para_em_paredes()
	await _test_luz_nao_vaza_atraves_de_parede()
	await _test_visao_direta_nao_vaza_atraves_de_parede()
	await _test_quinas_internas_entre_paredes_conectadas_sao_filtradas()
	await _test_paredes_conectadas_sao_tratadas_como_bloco_unico()
	await _test_caixas_conectadas_sao_tratadas_como_bloco_unico()
	await _test_parede_exposta_a_luz_ou_visao_e_perceptivel()

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
	var packed_scene := load("res://scenes/world/cena_principal.tscn") as PackedScene
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


func _test_fonte_de_luz_revela_ameaca_fora_da_mira() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	_add_fonte_de_luz(fixture.root, Vector2(-90, 0), 80.0)
	await physics_frame

	_assert_true(
		fixture.vision.is_position_visible(Vector2(-90, 0)),
		"Fonte de Luz fora da Mira revela ameaca pela propria luz"
	)

	fixture.root.queue_free()


func _test_bloqueador_entre_fonte_e_ameaca_impede_revelacao() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Jogador em (0,0), mira para direita (200, 0).
	# Alvo (Ameaca) embaixo (0, 150). Fora da periferia e fora do cone. Linha clara ok.
	var target_pos := Vector2(0, 150)
	
	# Fonte de luz a esquerda do alvo (-80, 150).
	_add_fonte_de_luz(fixture.root, Vector2(-80, 150), 100.0)
	
	# Bloqueador entre a fonte e o alvo (-40, 150).
	_add_bloqueador_de_visao(fixture.root, Vector2(-40, 150))
	await physics_frame

	_assert_false(
		fixture.vision.is_position_visible(target_pos),
		"Bloqueador de visao oculta luz da fonte"
	)

	fixture.root.queue_free()


func _test_percepcao_360_limita_revelacao_visual() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Jogador em (0,0). Alvo em (0, 150).
	var target_pos := Vector2(0, 150)
	
	# Fonte de luz bem do lado do alvo (0, 150).
	_add_fonte_de_luz(fixture.root, Vector2(0, 150), 100.0)
	
	# Bloqueador entre o JOGADOR e o alvo (0, 75).
	_add_bloqueador_de_visao(fixture.root, Vector2(0, 75))
	await physics_frame

	_assert_false(
		fixture.vision.is_position_visible(target_pos),
		"Percepcao 360 do jogador bloqueada impede revelacao mesmo com fonte de luz iluminando"
	)

	fixture.root.queue_free()


func _test_malha_da_percepcao_360_para_no_bloqueador() -> void:
	var fixture := _create_fixture()
	_add_bloqueador_de_visao(fixture.root, Vector2(100, 0))
	await physics_frame
	fixture.vision._rebuild(true)

	var points: PackedVector2Array = fixture.vision.get_omnidirectional_visibility_points()
	_assert_true(points.size() > 10, "Malha 360 deve ter varios pontos")
	
	var passed_blocker := false
	for pt in points:
		if pt.x > 120 and abs(pt.y) < 20:
			passed_blocker = true
			
	_assert_false(passed_blocker, "Nenhum ponto da malha 360 deve passar por tras do bloqueador")

	fixture.root.queue_free()


func _test_malha_da_percepcao_360_cabe_no_overlay() -> void:
	var fixture := _create_fixture()
	await physics_frame

	var points: PackedVector2Array = fixture.vision.get_omnidirectional_visibility_points()
	# Precisamos garantir que cabem no MAX_OMNIDIRECTIONAL_POINTS do shader
	var shader_max_omni := 1152
	_assert_true(points.size() <= shader_max_omni, "Malha 360 (%d) estourou shader (%d)" % [points.size(), shader_max_omni])

	fixture.root.queue_free()


func _test_cena_principal_cabe_no_overlay() -> void:
	var packed_scene := load("res://scenes/world/cena_principal.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	get_root().add_child(scene)
	await process_frame
	await physics_frame

	var player := scene.get_node("Mundo/Player") as CharacterBody2D
	var vision := player.get_node("PlayerVision")
	vision._rebuild(true) # forca a geracao real na cena

	var omni_points: PackedVector2Array = vision.get_omnidirectional_visibility_points()
	var shader_max_omni := 1152
	_assert_true(omni_points.size() <= shader_max_omni, "Malha 360 da cena principal (%d) estourou shader (%d)" % [omni_points.size(), shader_max_omni])

	scene.queue_free()


func _test_fonte_de_luz_nao_usa_point_light_2d() -> void:
	var packed_scene := load("res://scenes/world/cena_principal.tscn") as PackedScene
	var scene := packed_scene.instantiate()
	get_root().add_child(scene)
	await process_frame
	
	var point_lights = scene.find_children("*", "PointLight2D", true, false)
	_assert_true(point_lights.is_empty(), "Nao deve haver PointLight2D na cena (luz agora e shader)")
	
	scene.queue_free()


func _test_malha_da_fonte_para_no_bloqueador() -> void:
	var fixture := _create_fixture()
	var source = _add_fonte_de_luz(fixture.root, Vector2(0, 0), 200.0)
	_add_bloqueador_de_visao(fixture.root, Vector2(100, 0))
	await physics_frame

	var points: PackedVector2Array = fixture.vision.get_light_visibility_points(source)
	_assert_true(points.size() > 10, "Malha da luz deve ter varios pontos")
	
	var passed_blocker := false
	for pt in points:
		# points of light are global!
		if pt.x > 120 and abs(pt.y) < 20:
			passed_blocker = true
			
	_assert_false(passed_blocker, "Nenhum ponto da malha da luz deve passar por tras do bloqueador")

	fixture.root.queue_free()


func _test_fonte_ilumina_do_corpo_inteiro() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Jogador longe (nao interfere). Alvo em (0, 150).
	var target_pos := Vector2(0, 150)
	
	# Fonte de luz acima do alvo (0, 50). Raio 150. Emitter radius 30!
	var source = _add_fonte_de_luz(fixture.root, Vector2(0, 50), 150.0)
	source.set_meta("light_emitter_radius", 30.0)
	
	# Bloqueador entre a fonte e o alvo, BEM no centro (0, 100), tamanho pequeno (20x20).
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.global_position = Vector2(0, 100)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	collision.shape = shape
	body.add_child(collision)
	fixture.root.add_child(body)
	await physics_frame

	# Mesmo com o bloqueador ocultando o centro da fonte de luz para o alvo,
	# como o light_emitter_radius = 30.0, a luz "vaza" pelos lados do bloqueador.
	# Entao a posicao deve estar iluminada!
	# (e precisamos mover o player para ter linha clara do player ao alvo)
	fixture.player.global_position = Vector2(50, 150) # player ve o alvo claramente de lado
	
	_assert_true(
		fixture.vision.is_position_visible(target_pos),
		"Fonte deve iluminar o alvo pelo seu raio de emissor mesmo se o centro estiver bloqueado"
	)

	fixture.root.queue_free()


func _test_malha_da_fonte_usa_quinas_do_bloqueador() -> void:
	var fixture := _create_fixture()
	var source = _add_fonte_de_luz(fixture.root, Vector2(0, 0), 200.0)
	
	# Adiciona um bloqueador pequeno. Suas quinas traseiras projetam a sombra
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.global_position = Vector2(80, 0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	collision.shape = shape
	body.add_child(collision)
	fixture.root.add_child(body)
	await physics_frame

	var points: PackedVector2Array = fixture.vision.get_light_visibility_points(source)
	
	# Verificamos se existem pontos alinhados com as quinas frontais do bloqueador
	# As quinas frontais estao em x=70, y=10 e y=-10.
	var hit_corner := false
	for pt in points:
		if abs(pt.x - 70.0) < 1.5 and (abs(pt.y - 10.0) < 1.5 or abs(pt.y + 10.0) < 1.5):
			hit_corner = true
			break
			
	_assert_true(hit_corner, "A malha da fonte de luz deve incluir as quinas dos bloqueadores para projetar sombra precisa")

	fixture.root.queue_free()


func _test_objeto_na_visao_direta_fica_completamente_dentro_da_malha_iluminada() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Adiciona uma caixa (obstaculo baixo na layer 8) em (100, 0), tamanho 28x28 (x de 86 a 114)
	var caixa := StaticBody2D.new()
	caixa.collision_layer = 8
	caixa.global_position = Vector2(100, 0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	collision.shape = shape
	caixa.add_child(collision)
	fixture.root.add_child(caixa)
	await physics_frame
	fixture.vision._rebuild(true)

	var cone_points: PackedVector2Array = fixture.vision._cast_cone(0.0)
	
	# Verifica se os raios que atingem a caixa chegam ou passam da face traseira (x >= 114)
	var reached_back := false
	for pt in cone_points:
		if pt.x >= 113.0 and abs(pt.y) < 15.0:
			reached_back = true
			break
			
	_assert_true(reached_back, "Os raios da visao direta devem envolver a caixa ate sua face traseira (sem desaturar o proprio objeto)")

	fixture.root.queue_free()


func _test_objeto_atras_de_outro_fica_em_sombra() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Caixa 1 em (80, 0), tamanho 20x20 (x de 70 a 90)
	var caixa1 := StaticBody2D.new()
	caixa1.collision_layer = 8
	caixa1.global_position = Vector2(80, 0)
	var col1 := CollisionShape2D.new()
	var shape1 := RectangleShape2D.new()
	shape1.size = Vector2(20, 20)
	col1.shape = shape1
	caixa1.add_child(col1)
	fixture.root.add_child(caixa1)

	# Caixa 2 diretamente atras da Caixa 1, em (140, 0)
	var caixa2 := StaticBody2D.new()
	caixa2.collision_layer = 8
	caixa2.global_position = Vector2(140, 0)
	var col2 := CollisionShape2D.new()
	var shape2 := RectangleShape2D.new()
	shape2.size = Vector2(20, 20)
	col2.shape = shape2
	caixa2.add_child(col2)
	fixture.root.add_child(caixa2)
	await physics_frame
	fixture.vision._rebuild(true)

	var cone_points: PackedVector2Array = fixture.vision._cast_cone(0.0)
	
	# Os raios que passam por y=0 devem parar na traseira da Caixa 1 (x ~ 90), sem alcancar a Caixa 2 (x >= 130)
	var reached_box2 := false
	for pt in cone_points:
		if pt.x > 120.0 and abs(pt.y) < 5.0:
			reached_box2 = true
			break
			
	_assert_false(reached_box2, "A Caixa 2 deve ficar na sombra da Caixa 1 (fora da malha iluminada)")

	fixture.root.queue_free()


func _test_percepcao_periferica_atravessa_obstaculos_baixos_mas_para_em_paredes() -> void:
	var fixture := _create_fixture()
	fixture.vision.inner_light_radius = 60.0
	
	# Caixa (obstaculo baixo, layer 8) a direita (30, 0)
	var caixa := StaticBody2D.new()
	caixa.collision_layer = 8
	caixa.global_position = Vector2(30, 0)
	var col_c := CollisionShape2D.new()
	var shape_c := RectangleShape2D.new()
	shape_c.size = Vector2(20, 20)
	col_c.shape = shape_c
	caixa.add_child(col_c)
	fixture.root.add_child(caixa)

	# Parede (bloqueador alto, layer 1) a esquerda (-30, 0)
	var parede := StaticBody2D.new()
	parede.collision_layer = 1
	parede.global_position = Vector2(-30, 0)
	var col_p := CollisionShape2D.new()
	var shape_p := RectangleShape2D.new()
	shape_p.size = Vector2(20, 20)
	col_p.shape = shape_p
	parede.add_child(col_p)
	fixture.root.add_child(parede)
	await physics_frame

	# Ameaca atras da caixa (dentro dos 60px de raio periferico)
	_assert_true(
		fixture.vision.is_position_visible(Vector2(50, 0)),
		"Percepcao periferica permite ver atras de obstaculos baixos como caixas e barris"
	)
	
	# Ameaca atras da parede
	_assert_false(
		fixture.vision.is_position_visible(Vector2(-50, 0)),
		"Percepcao periferica e bloqueada por paredes"
	)

	fixture.root.queue_free()


func _test_ameaca_parcialmente_percebida_recebe_fragmento_perceptivel() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	var ameaca := Sprite2D.new()
	ameaca.name = "AmeacaParcial"
	ameaca.centered = true
	ameaca.global_position = Vector2(210, 0)
	ameaca.add_to_group(&"visible_entities")
	fixture.root.add_child(ameaca)
	await physics_frame

	_assert_true(ameaca.visible, "Ameaca parcialmente percebida continua existindo visualmente")
	_assert_true(ameaca.material is ShaderMaterial, "Ameaca parcialmente percebida recebe mascara de Fragmento Perceptivel")
	var material := ameaca.material as ShaderMaterial
	_assert_true(material.get_shader_parameter("vision_point_count") > 2, "Mascara do Fragmento Perceptivel usa Visao Direta")
	_assert_true(material.get_shader_parameter("omni_point_count") > 2, "Mascara do Fragmento Perceptivel usa Percepcao Periferica")

	fixture.root.queue_free()


func _test_luz_nao_vaza_atraves_de_parede() -> void:
	var fixture := _create_fixture()
	var source = _add_fonte_de_luz(fixture.root, Vector2(0, 0), 200.0)
	
	# Parede em x=50 com espessura 20 (x de 40 a 60), altura 100
	var parede := StaticBody2D.new()
	parede.collision_layer = 1
	parede.global_position = Vector2(50, 0)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 100)
	col.shape = shape
	parede.add_child(col)
	fixture.root.add_child(parede)
	await physics_frame

	var points: PackedVector2Array = fixture.vision.get_light_visibility_points(source)
	var passed_behind_wall := false
	for pt in points:
		# Ponto atingindo atras da parede (x > 61 e dentro da altura da parede)
		if pt.x > 61.0 and abs(pt.y) < 45.0:
			passed_behind_wall = true
			break

	_assert_false(passed_behind_wall, "Nenhum ponto da fonte de luz deve vazar para tras da parede")

	fixture.root.queue_free()


func _test_visao_direta_nao_vaza_atraves_de_parede() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Parede em x=80 com espessura 32 (x de 64 a 96)
	var parede := StaticBody2D.new()
	parede.collision_layer = 1
	parede.global_position = Vector2(80, 0)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 100)
	col.shape = shape
	parede.add_child(col)
	fixture.root.add_child(parede)
	await physics_frame
	fixture.vision._rebuild(true)

	var cone_points: PackedVector2Array = fixture.vision._cast_cone(0.0)
	var leaked_behind := false
	for pt in cone_points:
		# Ponto atingindo atras da parede (x > 97 e dentro da altura da parede)
		if pt.x > 97.0 and abs(pt.y) < 45.0:
			leaked_behind = true
			break

	_assert_false(leaked_behind, "A visao direta deve parar na face traseira da parede sem vazar para tras")

	fixture.root.queue_free()


func _test_quinas_internas_entre_paredes_conectadas_sao_filtradas() -> void:
	var fixture := _create_fixture()
	
	# Dois blocos de parede adjacentes de 32x32: (0, 50) e (32, 50)
	var p1 := StaticBody2D.new()
	p1.collision_layer = 1
	p1.global_position = Vector2(0, 50)
	var col1 := CollisionShape2D.new()
	var shape1 := RectangleShape2D.new()
	shape1.size = Vector2(32, 32)
	col1.shape = shape1
	p1.add_child(col1)
	fixture.root.add_child(p1)

	var p2 := StaticBody2D.new()
	p2.collision_layer = 1
	p2.global_position = Vector2(32, 50)
	var col2 := CollisionShape2D.new()
	var shape2 := RectangleShape2D.new()
	shape2.size = Vector2(32, 32)
	col2.shape = shape2
	p2.add_child(col2)
	fixture.root.add_child(p2)
	await physics_frame

	var corners: PackedVector2Array = fixture.vision._get_obstacle_corners_near(Vector2(16, 0), 100.0, 1)
	
	# A costura interna entre p1 e p2 em x=16 (y=34 e y=66) nao deve estar presente nos corners
	var has_seam_corner := false
	for c in corners:
		if abs(c.x - 16.0) < 1.0:
			has_seam_corner = true
			break

	_assert_false(has_seam_corner, "Costuras internas entre blocos de parede adjacentes devem ser filtradas")

	fixture.root.queue_free()


func _test_paredes_conectadas_sao_tratadas_como_bloco_unico() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Duas paredes conectadas em fila horizontal (x de 64 a 96, e de 96 a 128)
	var p1 := StaticBody2D.new()
	p1.collision_layer = 1
	p1.global_position = Vector2(80, 0)
	var col1 := CollisionShape2D.new()
	var shape1 := RectangleShape2D.new()
	shape1.size = Vector2(32, 32)
	col1.shape = shape1
	p1.add_child(col1)
	fixture.root.add_child(p1)

	var p2 := StaticBody2D.new()
	p2.collision_layer = 1
	p2.global_position = Vector2(112, 0)
	var col2 := CollisionShape2D.new()
	var shape2 := RectangleShape2D.new()
	shape2.size = Vector2(32, 32)
	col2.shape = shape2
	p2.add_child(col2)
	fixture.root.add_child(p2)
	await physics_frame
	fixture.vision._rebuild(true)

	var cone_points: PackedVector2Array = fixture.vision._cast_cone(0.0)
	# O raio que entra em p1 em x=64 deve atravessar p1 e p2 continuamente e sair na face traseira de p2 (x=128)
	var reached_back_of_p2 := false
	for pt in cone_points:
		if pt.x >= 127.0 and abs(pt.y) < 15.0:
			reached_back_of_p2 = true
			break

	_assert_true(reached_back_of_p2, "Paredes conectadas em serie devem ser atravessadas como um unico bloco continuo ate a saida em espaco livre")

	fixture.root.queue_free()


func _test_caixas_conectadas_sao_tratadas_como_bloco_unico() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Duas caixas conectadas em fila horizontal (layer 8, x de 60 a 90, e de 90 a 120)
	var c1 := StaticBody2D.new()
	c1.collision_layer = 8
	c1.global_position = Vector2(75, 0)
	var col1 := CollisionShape2D.new()
	var shape1 := RectangleShape2D.new()
	shape1.size = Vector2(30, 30)
	col1.shape = shape1
	c1.add_child(col1)
	fixture.root.add_child(c1)

	var c2 := StaticBody2D.new()
	c2.collision_layer = 8
	c2.global_position = Vector2(105, 0)
	var col2 := CollisionShape2D.new()
	var shape2 := RectangleShape2D.new()
	shape2.size = Vector2(30, 30)
	col2.shape = shape2
	c2.add_child(col2)
	fixture.root.add_child(c2)
	await physics_frame
	fixture.vision._rebuild(true)

	var cone_points: PackedVector2Array = fixture.vision._cast_cone(0.0)
	var reached_back_of_c2 := false
	for pt in cone_points:
		if pt.x >= 119.0 and abs(pt.y) < 15.0:
			reached_back_of_c2 = true
			break

	_assert_true(reached_back_of_c2, "Caixas conectadas lado a lado devem ser atravessadas como um unico bloco continuo")

	fixture.root.queue_free()


func _test_parede_exposta_a_luz_ou_visao_e_perceptivel() -> void:
	var fixture := _create_fixture()
	fixture.vision.set_aim_position(Vector2(200, 0))
	
	# Parede em x=80 com espessura 32 (x de 64 a 96)
	var parede := StaticBody2D.new()
	parede.collision_layer = 1
	parede.global_position = Vector2(80, 0)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 100)
	col.shape = shape
	parede.add_child(col)
	fixture.root.add_child(parede)
	await physics_frame
	fixture.vision._rebuild(true)

	# A face frontal da parede (x=64) voltada para o jogador esta visivel
	_assert_true(
		fixture.vision.is_position_visible(Vector2(64, 0)),
		"A face frontal da parede voltada para a visao direta do jogador e visivel"
	)
	
	# O interior atras da parede (x=110) continua oculto
	_assert_false(
		fixture.vision.is_position_visible(Vector2(110, 0)),
		"O interior atras da parede permanece invisivel"
	)

	fixture.root.queue_free()


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


func _add_fonte_de_luz(parent: Node, position: Vector2, radius: float) -> Node2D:
	var light_source := Node2D.new()
	light_source.name = "FonteDeLuz"
	light_source.global_position = position
	light_source.set_meta("light_radius", radius)
	light_source.set_meta("light_emitter_radius", 0.0)
	light_source.add_to_group(&"light_sources")
	parent.add_child(light_source)
	return light_source


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
