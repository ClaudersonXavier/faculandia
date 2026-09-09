extends Node
## Autoload: musica-tema das telas fora de fase (menu, hub, loja) — nunca
## toca dentro de uma zona jogavel. parar() e' chamado no _ready() de
## player_moviment.gd, que roda em toda zona jogavel (esse e' o hook unico,
## nao precisa chamar em cada cena de zona individualmente).
## Caminho fixo: se resources/sounds/musica/tema.mp3 nao existir (ou for
## removido), tocar() vira no-op — sem erro, sem regressao.

const CAMINHO_TEMA := "res://resources/sounds/musica/tema.mp3"

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	if ResourceLoader.exists(CAMINHO_TEMA):
		_player.stream = load(CAMINHO_TEMA)
	add_child(_player)


func tocar() -> void:
	if _player.stream == null or _player.playing:
		return
	_player.play()


func parar() -> void:
	if _player.playing:
		_player.stop()
