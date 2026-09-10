extends Node
## Um por zona jogavel (irmao de Mundo). Na primeira visita a essa cena_id
## nesse save, gera ~30 Ameaca aleatorias e memoriza o snapshot; nas visitas
## seguintes, restaura o que estava salvo — dando folga (reposicionando) pras
## que ficaram perto demais da saida (ver scripts/world/zona_populador.gd e
## scripts/world/save_jogo.gd).
## Entra no grupo "zona_mundo_sync" em _ready() — SaveJogo usa esse grupo pra
## achar a instancia da cena atual e capturar o snapshot antes de trocar de fase.

@export var world: Node2D
@export var cena_id: String


func _ready() -> void:
	add_to_group(&"zona_mundo_sync")
	# Espera os corpos de fisica da cena (paredes etc) registrarem, tanto pra
	# gerar posicoes novas quanto pra reposicionar quem ficou perto da saida
	# ao restaurar — mesmo padrao de navegacao_cenario.gd.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if ZonaPopulador.tem_snapshot(cena_id):
		_restaurar_com_folga()
	else:
		_gerar_populacao_inicial()


func _gerar_populacao_inicial() -> void:
	var jogador := world.get_node_or_null("Player")
	var bounds: Variant = _limites_da_zona()
	if jogador == null or bounds == null:
		push_warning("ZonaMundoSync: Player ou camera_player nao encontrado em %s, pulando geracao de Ameaca" % cena_id)
		return
	var space_state := world.get_world_2d().direct_space_state
	var mask := PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO
	var posicoes := ZonaPopulador.gerar_posicoes(
		space_state, bounds, jogador.position,
		ZonaPopulador.RAIO_EXCLUSAO_SPAWN_JOGADOR, ZonaPopulador.NUM_INIMIGOS, mask
	)
	var snapshot := ZonaPopulador.montar_snapshot_inicial(posicoes)
	ZonaPopulador.aplicar_snapshot(world, snapshot)
	ZonaPopulador.registrar_snapshot(cena_id, snapshot)


func _restaurar_com_folga() -> void:
	var snapshot := ZonaPopulador.obter_snapshot(cena_id)
	var saida := world.get_node_or_null("ZonaSaida") as Node2D
	var bounds: Variant = _limites_da_zona()
	if saida != null and bounds != null:
		var space_state := world.get_world_2d().direct_space_state
		var mask := PhysicsLayers.OBSTACULO | PhysicsLayers.OBSTACULO_BAIXO
		snapshot = ZonaPopulador.dar_folga_para_vivos_perto_da_saida(space_state, bounds, saida.global_position, snapshot, mask)
		ZonaPopulador.registrar_snapshot(cena_id, snapshot)
	ZonaPopulador.aplicar_snapshot(world, snapshot)


func _limites_da_zona() -> Variant:
	var camera := world.get_node_or_null("Player/camera_player") as Camera2D
	if camera == null:
		return null
	return Rect2(
		camera.limit_left, camera.limit_top,
		camera.limit_right - camera.limit_left,
		camera.limit_bottom - camera.limit_top
	)
