extends SceneTree

const WeaponScript := preload("res://scripts/weapon.gd")
const PistolScript := preload("res://scripts/pistol.gd")
const HudScript := preload("res://scripts/hud.gd")
const PlayerMovementScript := preload("res://scripts/player_moviment.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _test_initial_ammo()
	await _test_shooting_decrements_ammo()
	await _test_cannot_shoot_when_empty()
	await _test_reloading_restores_ammo()
	await _test_cannot_shoot_while_reloading()
	await _test_cannot_reload_when_full_or_reloading()
	await _test_pistol_inherits_ammo_mechanics()
	await _test_hud_updates_labels()
	await _test_player_reload_without_weapon_does_not_crash()

	if failures > 0:
		printerr("%d teste(s) de recarregamento/HUD falharam" % failures)
		quit(1)
	else:
		print("Todos os testes de recarregamento e HUD passaram com sucesso!")
		quit(0)


func _test_initial_ammo() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 10
	root.add_child(weapon)
	await process_frame

	_assert_true(weapon.current_ammo == 10, "Municao inicial deve ser igual ao magazine_size")
	_assert_false(weapon.is_reloading, "Arma nao deve iniciar recarregando")

	root.queue_free()
	await process_frame


func _test_shooting_decrements_ammo() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 5
	weapon.fire_rate = 0.05
	root.add_child(weapon)
	await process_frame

	weapon.shoot(Vector2.RIGHT, 0.0)
	_assert_true(weapon.current_ammo == 4, "Disparo deve decrementar 1 projetil da municao atual (atual: %d)" % weapon.current_ammo)

	root.queue_free()
	await process_frame


func _test_cannot_shoot_when_empty() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 1
	weapon.fire_rate = 0.05
	root.add_child(weapon)
	await process_frame

	weapon.shoot(Vector2.RIGHT, 0.0)
	_assert_true(weapon.current_ammo == 0, "Municao deve zerar apos 1 disparo")

	await create_timer(0.06).timeout

	# Tenta disparar com municao zerada
	weapon.shoot(Vector2.RIGHT, 0.0)
	_assert_true(weapon.current_ammo == 0, "Nao deve disparar quando municao for 0")

	root.queue_free()
	await process_frame


func _test_reloading_restores_ammo() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 7
	weapon.reload_time = 0.1
	weapon.fire_rate = 0.05
	root.add_child(weapon)
	await process_frame

	weapon.shoot(Vector2.RIGHT, 0.0)
	_assert_true(weapon.current_ammo == 6, "Municao deve ser 6 apos 1 tiro")

	weapon.reload()
	_assert_true(weapon.is_reloading, "Arma deve entrar em estado is_reloading=true")

	await create_timer(0.15).timeout
	_assert_false(weapon.is_reloading, "Arma deve sair de is_reloading apos reload_time")
	_assert_true(weapon.current_ammo == 7, "Municao deve ser restaurada para magazine_size (7)")

	root.queue_free()
	await process_frame


func _test_cannot_shoot_while_reloading() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 7
	weapon.reload_time = 0.2
	weapon.fire_rate = 0.05
	root.add_child(weapon)
	await process_frame

	weapon.shoot(Vector2.RIGHT, 0.0)
	_assert_true(weapon.current_ammo == 6, "Municao inicial = 6 apos tiro")

	await create_timer(0.06).timeout
	weapon.reload()
	_assert_true(weapon.is_reloading, "Em recarregamento")

	# Tenta disparar durante o recarregamento
	weapon.shoot(Vector2.RIGHT, 0.0)
	_assert_true(weapon.current_ammo == 6, "Nao deve disparar ou decrementar municao durante recarregamento")

	await create_timer(0.25).timeout
	_assert_true(weapon.current_ammo == 7, "Apos recarregamento completo, municao restaurada")

	root.queue_free()
	await process_frame


func _test_cannot_reload_when_full_or_reloading() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 7
	weapon.reload_time = 0.1
	root.add_child(weapon)
	await process_frame

	weapon.reload()
	_assert_false(weapon.is_reloading, "Nao deve iniciar recarregamento se municao estiver cheia")

	root.queue_free()
	await process_frame


func _test_pistol_inherits_ammo_mechanics() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var pistol: Weapon = PistolScript.new()
	root.add_child(pistol)
	await process_frame

	_assert_true(pistol.current_ammo == pistol.magazine_size, "Pistola herda e inicializa municao corretamente")
	_assert_true(pistol.magazine_size == 7, "Pistola tem magazine_size 7 por padrao")

	root.queue_free()
	await process_frame


func _test_hud_updates_labels() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var weapon: Weapon = WeaponScript.new()
	weapon.magazine_size = 7
	weapon.reload_time = 0.1
	root.add_child(weapon)

	var hud := Control.new()
	hud.set_script(HudScript)
	hud.set("weapon", weapon)

	var ammo_label := Label.new()
	ammo_label.name = "AmmoLabel"
	hud.add_child(ammo_label)

	var weapon_sprite := Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	hud.add_child(weapon_sprite)

	var reload_label := Label.new()
	reload_label.name = "ReloadLabel"
	hud.add_child(reload_label)

	root.add_child(hud)
	await process_frame

	hud._process(0.016)
	_assert_true(ammo_label.text == "7 / 7", "HUD deve exibir '7 / 7' inicialmente (obtido: '%s')" % ammo_label.text)
	_assert_false(reload_label.visible, "ReloadLabel nao deve estar visivel inicialmente")

	weapon.current_ammo = 3
	hud._process(0.016)
	_assert_true(ammo_label.text == "3 / 7", "HUD deve atualizar para '3 / 7'")

	weapon.is_reloading = true
	hud._process(0.016)
	_assert_true(reload_label.visible, "ReloadLabel deve ficar visivel quando is_reloading=true")

	root.queue_free()
	await process_frame


func _test_player_reload_without_weapon_does_not_crash() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var player := CharacterBody2D.new()
	player.set_script(PlayerMovementScript)
	root.add_child(player)
	await process_frame

	# player sem nó Weapon filho
	_assert_true(player.weapon == null, "Player nao possui arma")
	player._physics_process(0.016)
	# Se nao crashou, passou

	root.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALHOU: %s" % message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)
