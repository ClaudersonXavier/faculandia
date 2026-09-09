extends SceneTree
## Testa o autoload MusicaTema (scripts/audio/musica_tema.gd). Funciona tanto
## com o arquivo real presente (resources/sounds/musica/tema.mp3) quanto sem
## ele, pra nao ficar obsoleto se o arquivo for removido/trocado depois.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var musica := root.get_node_or_null(^"MusicaTema")
	_assert_true(musica != null, "autoload MusicaTema deveria existir em /root")

	var tem_arquivo_real := ResourceLoader.exists("res://resources/sounds/musica/tema.mp3")
	_assert_true(musica._player.stream != null == tem_arquivo_real, "stream carregado deveria bater com a existencia do arquivo real (tem_arquivo=%s)" % tem_arquivo_real)

	musica.tocar()
	await process_frame
	_assert_true(musica._player.playing == tem_arquivo_real, "tocar() so deve comecar a tocar se houver stream carregado (esperado playing=%s)" % tem_arquivo_real)

	# tocar() de novo nao deve reiniciar a faixa (idempotente) — sem forma
	# direta de medir "nao reiniciou" aqui, mas ao menos confirma que chamar
	# de novo nao crasha nem para de tocar.
	musica.tocar()
	await process_frame
	_assert_true(musica._player.playing == tem_arquivo_real, "tocar() de novo nao deveria mudar o estado de playing")

	musica.parar()
	await process_frame
	_assert_false(musica._player.playing, "parar() deveria parar a musica (ou continuar parada, se nunca tocou)")

	# parar() de novo (idempotente) nao deve crashar.
	musica.parar()
	await process_frame

	if failures > 0:
		printerr("%d teste(s) de musica_tema falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de musica_tema passaram com sucesso!")
		quit(0)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
