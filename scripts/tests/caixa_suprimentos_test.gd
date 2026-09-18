extends SceneTree
## Testa CaixaSuprimentos isolada com GameState.

const EstadoDoJogoScript := preload("res://scripts/world/game_state.gd")
const CaixaSuprimentosScript := preload("res://scripts/world/caixa_suprimentos.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_abrir_caixa_concede_15_e_persiste()
	await _test_caixa_ja_coletada_nao_abre_novamente()
	await _test_caixas_nas_cenas_estao_fora_de_paredes()

	if failures > 0:
		printerr("%d teste(s) de caixa_suprimentos falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de caixa_suprimentos passaram com sucesso!")
		quit(0)


func _test_abrir_caixa_concede_15_e_persiste() -> void:
	var estado = root.get_node("/root/GameState")
	estado.reset()

	var caixa = CaixaSuprimentosScript.new()
	caixa.id_caixa = "teste_cx_1"
	caixa.valor = 15
	root.add_child(caixa)
	await process_frame

	_assert_true(estado.dinheiro == 0, "Dinheiro deve comecar zerado")
	_assert_false(estado.caixas_coletadas.has("teste_cx_1"), "ID da caixa nao deve estar nas coletadas")

	caixa.abrir()
	_assert_true(estado.dinheiro == 15, "Abrir caixa deve conceder 15")
	_assert_true(estado.caixas_coletadas.has("teste_cx_1"), "ID da caixa deve estar registrado em caixas_coletadas")
	_assert_true(caixa.collision_layer == 0, "Colisao da caixa deve ser desativada apos abrir")

	# Tentar abrir de novo nao deve dar mais dinheiro
	caixa.abrir()
	_assert_true(estado.dinheiro == 15, "Segunda tentativa nao deve conceder mais dinheiro")

	caixa.queue_free()
	await process_frame


func _test_caixa_ja_coletada_nao_abre_novamente() -> void:
	var estado = root.get_node("/root/GameState")
	estado.reset()
	estado.caixas_coletadas = ["teste_cx_ja_aberta"]

	var caixa = CaixaSuprimentosScript.new()
	caixa.id_caixa = "teste_cx_ja_aberta"
	caixa.valor = 15
	root.add_child(caixa)

	_assert_true(caixa._coletada == true, "Caixa deve ser marcada como coletada no _ready()")
	_assert_true(caixa.is_queued_for_deletion(), "Caixa ja coletada deve ser enfileirada para delecao no _ready()")

	await process_frame
	_assert_false(is_instance_valid(caixa), "Caixa ja coletada deve ter sido completamente liberada da memoria")


func _test_caixas_nas_cenas_estao_fora_de_paredes() -> void:
	for scene_path in ["res://scenes/world/zona_norte.tscn", "res://scenes/world/zona_sul.tscn"]:
		var packed: PackedScene = load(scene_path)
		var scene: Node2D = packed.instantiate()
		root.add_child(scene)
		await process_frame
		await physics_frame

		var space := scene.get_world_2d().direct_space_state
		var paredes: TileMapLayer = scene.get_node_or_null("Mundo/paredes")

		for i in range(1, 4):
			var caixa_node: CaixaSuprimentos = scene.get_node_or_null("Mundo/Caixa%d" % i)
			_assert_true(caixa_node != null, "Caixa%d deve existir em %s" % [i, scene_path])
			if caixa_node != null:
				var pos = caixa_node.global_position
				var sq := PhysicsShapeQueryParameters2D.new()
				var circle := CircleShape2D.new()
				circle.radius = 20.0
				sq.shape = circle
				sq.transform = Transform2D(0, pos)
				sq.collision_mask = 1
				var hits := space.intersect_shape(sq, 4)
				_assert_true(hits.is_empty(), "Caixa%d em %s na posicao %s nao deve colidir com paredes" % [i, scene_path, pos])
				if paredes != null:
					var cell = paredes.local_to_map(pos)
					_assert_true(paredes.get_cell_source_id(cell) == -1, "Caixa%d em %s nao deve estar em cima de tile de parede" % [i, scene_path])

		scene.queue_free()
		await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	if value:
		failures += 1
		printerr("FALHOU: %s" % message)
