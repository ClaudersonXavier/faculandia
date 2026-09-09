extends SceneTree
## Testes de scripts/world/zona_populador.gd que dependem de fisica real
## (PhysicsDirectSpaceState2D de verdade) — por isso ficam separados de
## save_jogo_test.gd, que so testa serializacao (sem carregar cenas/fisica).

const ZonaPopuladorScript := preload("res://scripts/world/zona_populador.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_geracao_nao_nasce_com_visao_livre_do_jogador("res://scenes/world/zona_norte.tscn")
	await _test_geracao_nao_nasce_com_visao_livre_do_jogador("res://scenes/world/zona_sul.tscn")
	await _test_folga_ao_voltar_afasta_vivos_da_saida("res://scenes/world/zona_norte.tscn")
	await _test_folga_ao_voltar_afasta_vivos_da_saida("res://scenes/world/zona_sul.tscn")

	if failures > 0:
		printerr("%d teste(s) de zona_populador falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de zona_populador passaram com sucesso!")
		quit(0)


## Regressao: RAIO_EXCLUSAO_SPAWN_JOGADOR (180) e bem menor que
## Ameaca.vision_range (600) — so a distancia nao bastava pra evitar que uma
## Ameaca nascesse ja enxergando o jogador (sem parede no meio, como em
## zona_sul antes de ter tileset pintado). gerar_posicoes tambem rejeita
## candidatos com linha de visao livre ate o jogador dentro do alcance de
## visao — aqui provamos isso carregando a cena de verdade.
func _test_geracao_nao_nasce_com_visao_livre_do_jogador(caminho: String) -> void:
	var inst: Node = load(caminho).instantiate()
	root.add_child(inst)
	await process_frame
	await physics_frame
	await physics_frame
	await physics_frame
	await process_frame

	var mundo: Node = inst.get_node("Mundo")
	var geradas: Array = []
	for filho in mundo.get_children():
		if filho is Ameaca and filho.spawn_id >= 0:
			geradas.append(filho)
	_assert_true(geradas.size() > 0, "%s deveria ter gerado ao menos uma Ameaca" % caminho)

	var visiveis_de_cara := 0
	for a: Ameaca in geradas:
		if a.has_direct_vision_to_player():
			visiveis_de_cara += 1
	_assert_true(visiveis_de_cara == 0, "%s: %d Ameaca(s) nasceram ja com visao livre do jogador (deveria ser 0)" % [caminho, visiveis_de_cara])

	inst.queue_free()
	await process_frame


## Se o jogador sai com um monte de zumbi vivo perto da saida, ao voltar eles
## sao afastados (RAIO_FOLGA_AO_VOLTAR) — o corpo de uma Ameaca morta perto da
## saida, por outro lado, tem que continuar exatamente onde morreu.
func _test_folga_ao_voltar_afasta_vivos_da_saida(caminho: String) -> void:
	ZonaPopuladorScript.limpar_para_testes()

	var inst1: Node = load(caminho).instantiate()
	root.add_child(inst1)
	await process_frame
	for i in range(4):
		await physics_frame
	await process_frame

	var mundo1: Node = inst1.get_node("Mundo")
	var saida_pos: Vector2 = (mundo1.get_node("ZonaSaida") as Node2D).global_position
	var geradas: Array = []
	for filho in mundo1.get_children():
		if filho is Ameaca and filho.spawn_id >= 0:
			geradas.append(filho)

	# Forca um cerco artificial: 5 vivas bem perto da saida, uma delas morta
	# (o corpo tem que ficar exatamente ali apos restaurar).
	for i in range(5):
		geradas[i].global_position = saida_pos + Vector2(i * 10, 0)
	geradas[0].take_damage(9999.0)
	await process_frame

	var anterior := ZonaPopuladorScript.obter_snapshot(caminho)
	var snapshot := ZonaPopuladorScript.capturar_snapshot(self, anterior)
	ZonaPopuladorScript.registrar_snapshot(caminho, snapshot)
	inst1.queue_free()
	await process_frame

	var inst2: Node = load(caminho).instantiate()
	root.add_child(inst2)
	await process_frame
	for i in range(4):
		await physics_frame
	await process_frame

	var mundo2: Node = inst2.get_node("Mundo")
	var vivas_perto := 0
	var corpo_ficou_no_lugar := false
	for filho in mundo2.get_children():
		if filho is Ameaca and filho.spawn_id >= 0:
			var a: Ameaca = filho
			var dist := a.global_position.distance_to(saida_pos)
			if a.is_dead():
				if dist < 400.0:
					corpo_ficou_no_lugar = true
			elif dist < 400.0:
				vivas_perto += 1
	_assert_true(vivas_perto == 0, "%s: %d Ameaca(s) viva(s) continuaram perto da saida apos restaurar" % [caminho, vivas_perto])
	_assert_true(corpo_ficou_no_lugar, "%s: o corpo morto perto da saida deveria ter ficado exatamente onde morreu" % caminho)

	inst2.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)
