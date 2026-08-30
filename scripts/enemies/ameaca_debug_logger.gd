class_name AmeacaDebugLogger
extends RefCounted

## Rastreia e imprime diagnosticos de movimento de uma Ameaca quando
## debug_logging esta ativo. Separado de ameaca.gd para nao inflar a
## logica principal de IA com codigo que so roda em depuracao.

var _prev_rotation: float = 0.0
var _prev_has_direct_vision: bool = false
var _heartbeat_timer: float = 0.0
var _prev_next_waypoint: Vector2 = Vector2.ZERO


func log_frame(
	ameaca: Ameaca,
	delta: float,
	has_direct_vision: bool,
	move_direction: Vector2,
	nav_next_pos: Vector2,
	prev_pos: Vector2,
	prev_rot: float
) -> void:
	var me_id := ameaca.name
	var moved_vec := ameaca.global_position - prev_pos
	var actual_speed := (moved_vec.length() / delta) if delta > 0.0 else 0.0
	var mode_name := "DIRECT" if has_direct_vision else "NAVMESH"
	var real_vel := ameaca.get_real_velocity()
	var slide_count := ameaca.get_slide_collision_count()

	# 1. Mudanca de estado de visao direta
	if has_direct_vision != _prev_has_direct_vision:
		var dist_to_p := ameaca.global_position.distance_to(ameaca.target_player.global_position) if is_instance_valid(ameaca.target_player) else 0.0
		print("[DEBUG-AMEACA][VISION-SWITCH] %s | modo: %s | pos=(%.1f, %.1f) | dist_player=%.1f" % [
			me_id, mode_name, ameaca.global_position.x, ameaca.global_position.y, dist_to_p
		])
		_prev_has_direct_vision = has_direct_vision

	# 2. Curva fechada
	var rot_diff_deg := rad_to_deg(abs(wrapf(ameaca.rotation - prev_rot, -PI, PI)))
	if rot_diff_deg > 25.0 and move_direction.length_squared() > Ameaca.MIN_MOVEMENT_DISTANCE_SQUARED:
		var waypoint_dist := ameaca.global_position.distance_to(nav_next_pos) if nav_next_pos != Vector2.ZERO else 0.0
		print("[DEBUG-AMEACA][SHARP-TURN] %s | virou %.1f deg | modo=%s | waypoint=(%.1f, %.1f), dist_waypoint=%.1f | vel=(%.1f, %.1f)" % [
			me_id, rot_diff_deg, mode_name, nav_next_pos.x, nav_next_pos.y, waypoint_dist, ameaca.velocity.x, ameaca.velocity.y
		])

	# 3. Colisoes com obstaculos
	var obstacles: Array[String] = []
	for i in range(slide_count):
		var col := ameaca.get_slide_collision(i)
		var collider := col.get_collider()
		var col_name: String = str(collider.name) if collider != null else "null"
		var col_normal := col.get_normal()
		var depth := col.get_depth()
		obstacles.append("%s(n=(%.2f, %.2f), depth=%.2f)" % [col_name, col_normal.x, col_normal.y, depth])

	# 4. Pico anormal de velocidade
	if actual_speed > (ameaca.speed * 1.25):
		print("[DEBUG-AMEACA][SPEED-SPIKE] %s | VELOCIDADE ANORMAL: %.1f px/s (esperado %.1f px/s, fator %.2fx) | real_vel=(%.1f, %.1f) | modo=%s | obstaculos=%s" % [
			me_id, actual_speed, ameaca.speed, (actual_speed / ameaca.speed), real_vel.x, real_vel.y, mode_name, str(obstacles)
		])

	# 5. Heartbeat periodico
	_heartbeat_timer += delta
	if _heartbeat_timer >= 1.0:
		_heartbeat_timer = 0.0
		var dist_player := ameaca.global_position.distance_to(ameaca.target_player.global_position) if is_instance_valid(ameaca.target_player) else 0.0
		print("[DEBUG-AMEACA][HEARTBEAT] %s | pos=(%.1f, %.1f) | modo=%s | vel=(%.1f, %.1f) | dist_player=%.1f" % [
			me_id, ameaca.global_position.x, ameaca.global_position.y, mode_name, ameaca.velocity.x, ameaca.velocity.y, dist_player
		])

	_prev_rotation = ameaca.rotation
	_prev_next_waypoint = nav_next_pos
