extends CharacterBody2D

@export var speed: float = 135.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var backpedal_multiplier: float = 0.85

@export var cone_angle: float = 75.0
@export var vision_range: float = 450.0
@export var footstep_noise_radius: float = 120.0
@export var footstep_distance_threshold: float = 27.0

@onready var weapon: Node2D = get_node_or_null("Weapon")

const HIT_FLASH_COLOR := Color(1.0, 0.3, 0.3, 1.0)
const HIT_FLASH_DURATION := 0.15

## Som de passo toca em loop continuo desde o _ready() (nunca reinicia, sem
## "pop" de restart) — so' o volume alterna entre audivel/mudo conforme anda
## ou fica parado. Nao usa o NoiseSfxPlayer automatico (que dispara um
## AudioStreamPlayer2D novo por evento de ruido, pensado pra sons curtos tipo
## tiro/impacto): o arquivo de passo real dura ~13s, entao um evento por
## ~27px andados sobreporia dezenas de instancias — ver noise_sfx_player.gd,
## que deliberadamente NAO tem entrada de audio pra "footstep" por causa
## disso (o evento de ruido em si continua sendo emitido, so' pra IA ouvir).
const CAMINHO_PASSO := "res://resources/sounds/sfx/passo.mp3"
const VOLUME_PASSO_MUDO_DB := -80.0
const VOLUME_PASSO_AUDIVEL_DB := -22.0

var aim_angle: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT

var _distance_walked: float = 0.0
var _last_step_position: Vector2 = Vector2.INF
var _is_backpedaling_state: bool = false
var _hit_flash_tween: Tween = null
var _morrendo: bool = false
var _passo_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group(&"player")
	# get_node_or_null (nao a referencia global "MusicaTema" direto) pelo
	# mesmo motivo do GameState logo abaixo: scripts que fazem preload() deste
	# arquivo em modo headless (ex. scripts/tests/noise_system_test.gd) compilam
	# antes dos autoloads existirem como identificador global — get_node_or_null
	# so resolve em runtime, entao nao quebra a compilacao antecipada.
	var musica = get_node_or_null("/root/MusicaTema")
	if musica:
		musica.parar()
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.voltando_da_loja:
		position = Vector2(60, 50)
		game_state.voltando_da_loja = false
	_iniciar_som_de_passo()


func _iniciar_som_de_passo() -> void:
	_passo_player = AudioStreamPlayer.new()
	add_child(_passo_player)
	if not ResourceLoader.exists(CAMINHO_PASSO):
		return
	_passo_player.stream = load(CAMINHO_PASSO)
	if _passo_player.stream is AudioStreamMP3:
		(_passo_player.stream as AudioStreamMP3).loop = true
	_passo_player.volume_db = VOLUME_PASSO_MUDO_DB
	_passo_player.play()


## Contrato duck-typed identico ao de Ameaca.take_damage — bullet.gd ja chama
## qualquer target.take_damage(amount) generico, e Ameaca._atacar_jogador()
## chama isso direto (ataque corpo-a-corpo, sem passar por bullet/Area2D).
func take_damage(amount: int) -> void:
	if _morrendo:
		return
	var game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.vida -= amount
	_play_hit_flash()
	if game_state.vida <= 0:
		# _morrendo evita que 2+ Ameaca acertando o jogador no mesmo frame
		# (cercado, vida ja baixa) agendem _morrer() mais de uma vez.
		# Deferido: quem chama take_damage aqui e' o _physics_process de uma
		# Ameaca atacante — trocar de cena nesse meio do callback dela e' arriscado.
		_morrendo = true
		call_deferred("_morrer")


func _play_hit_flash() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	modulate = HIT_FLASH_COLOR
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, HIT_FLASH_DURATION)


func _morrer() -> void:
	SaveJogo.jogador_morreu()


func is_backpedaling_vector(direction: Vector2) -> bool:
	if direction == Vector2.ZERO or aim_direction == Vector2.ZERO:
		return false
	return aim_direction.dot(direction.normalized()) < -0.3


func get_movement_input() -> Vector2:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func apply_movement(input_dir: Vector2, delta: float) -> void:
	var target_speed := speed
	if is_backpedaling_vector(input_dir):
		target_speed *= backpedal_multiplier

	var target_velocity := input_dir.normalized() * (target_speed * minf(input_dir.length(), 1.0))
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func update_animation() -> void:
	var spr := get_node_or_null("player_sprite")
	if spr == null:
		return

	spr.rotation = aim_angle - SpriteConventions.UP_FACING_OFFSET
	if spr is AnimatedSprite2D:
		var current_speed := velocity.length()
		if current_speed > 1.0:
			var is_backpedaling := is_backpedaling_vector(velocity)
			var direction_changed := is_backpedaling != _is_backpedaling_state
			AnimationUtils.play_if_needed(spr, &"walk", is_backpedaling, direction_changed)
			_is_backpedaling_state = is_backpedaling
			var speed_ratio := current_speed / maxf(speed, 0.001)
			spr.speed_scale = clampf(speed_ratio, 0.2, 1.5)
		else:
			_is_backpedaling_state = false
			AnimationUtils.play_if_needed(spr, &"idle")
			spr.speed_scale = 1.0


## Mesmo limiar de "esta parado" que update_animation() ja usa (idle vs walk).
func _atualizar_som_de_passo() -> void:
	if _passo_player == null or _passo_player.stream == null:
		return
	var esta_parado := velocity.length() <= 1.0
	_passo_player.volume_db = VOLUME_PASSO_MUDO_DB if esta_parado else VOLUME_PASSO_AUDIVEL_DB


func _physics_process(delta: float) -> void:
	var mouse_position := get_global_mouse_position()
	aim_direction = (mouse_position - global_position).normalized()
	aim_angle = aim_direction.angle()

	var input_dir := get_movement_input()
	apply_movement(input_dir, delta)
	update_animation()
	_atualizar_som_de_passo()

	if weapon != null:
		weapon.rotation = aim_angle

	move_and_slide()

	var camera := get_node_or_null("camera_player") as Camera2D
	var col := get_node_or_null("player_collision") as CollisionShape2D
	if camera != null and col != null and col.shape is RectangleShape2D:
		var half_col: Vector2 = (col.shape as RectangleShape2D).size / 2.0
		var min_pos: Vector2 = Vector2(camera.limit_left, camera.limit_top) + half_col
		var max_pos: Vector2 = Vector2(camera.limit_right, camera.limit_bottom) - half_col
		global_position.x = clampf(global_position.x, min_pos.x, max_pos.x)
		global_position.y = clampf(global_position.y, min_pos.y, max_pos.y)

	# Ruido de passos ao caminhar
	if _last_step_position == Vector2.INF:
		_last_step_position = global_position

	var moved_dist: float = global_position.distance_to(_last_step_position)
	_distance_walked += moved_dist
	_last_step_position = global_position

	if _distance_walked >= footstep_distance_threshold:
		NoiseBus.emit(global_position, footstep_noise_radius, &"footstep", self)
		_distance_walked -= footstep_distance_threshold

	if Input.is_action_just_pressed("shoot") and weapon != null:
		weapon.shoot(aim_direction, aim_angle)

	if Input.is_action_just_pressed("reload") and weapon != null:
		weapon.reload()


func is_in_vision(target_pos: Vector2) -> bool:
	var to_target := target_pos - global_position
	var dist := to_target.length()

	if dist > vision_range:
		return false

	var half_angle := deg_to_rad(cone_angle / 2.0)
	var target_angle := to_target.angle()
	var diff := absf(target_angle - aim_angle)
	if diff > PI:
		diff = TAU - diff

	return diff < half_angle
