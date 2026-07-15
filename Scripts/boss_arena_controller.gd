extends Node2D

# arena_rect: left, top, width, height
@export var arena_rect: Rect2 = Rect2(3008, -48, 2496, 688)
@export var global_limits: Rect2 = Rect2(0, -320, 6500, 960)
@export var zoom_level: Vector2 = Vector2(0.8, 0.8)
@export var camera_offset: Vector2 = Vector2.ZERO
@export var arena_wall_top: float = -48.0
@export var arena_wall_bottom: float = 640.0
@export var zombie_spawn_margin: float = 180.0
@export var clamp_players_during_fight: bool = true
@export var extra_limit_rect: Rect2 = Rect2(2272, -320, 176, 928)
@export var area14_first_section_camera_limits: Rect2 = Rect2(0, -64, 2496, 672)
@export var section_2_camera_limits: Rect2 = Rect2(3008, -48, 2496, 688)
@export var section_2_start_x: float = 2800.0
@export var section_normal_zoom: Vector2 = Vector2(0.78, 0.78)
@export var section_gate_zoom: Vector2 = Vector2(0.96, 0.96)
@export var transition_focus_zoom: Vector2 = Vector2(1.02, 1.02)
@export var transition_focus_seconds: float = 5.0
@export var camera_zoom_lerp_speed: float = 0.9
@export var gate_zoom_distance: float = 260.0
@export var boss_scene: bool = false
@export var create_extra_limit_walls_enabled: bool = false
@export var previous_area_scene: String = "res://Tileset/area1/area_1_3.tscn"
@export var previous_area_player1_position: Vector2 = Vector2(4208, -256)
@export var previous_area_player2_position: Vector2 = Vector2(4160, -256)
@export var next_area_scene: String = "res://Tileset/area1/area_1_5.tscn"
@export var next_area_player1_position: Vector2 = Vector2(3032, 32)
@export var next_area_player2_position: Vector2 = Vector2(3080, 32)

const PLAYER1_SCENE: PackedScene = preload("res://Player1/player.tscn")
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")
const SECTION_1_PLAYER1_POSITION: Vector2 = Vector2(96, 176)
const SECTION_1_PLAYER2_POSITION: Vector2 = Vector2(144, 176)
const SECTION_2_PLAYER1_POSITION: Vector2 = Vector2(3032, 32)
const SECTION_2_PLAYER2_POSITION: Vector2 = Vector2(3080, 32)
const FADE_WAIT_SECONDS: float = 0.55
const SECTION_1_NAME: String = "section_1"
const SECTION_2_NAME: String = "section_2"

var players_in_area: Array[Node2D] = []
var active: bool = false
var original_camera_limits: Dictionary = {}
var arena_walls: Array[StaticBody2D] = []
var extra_limit_walls: Array[StaticBody2D] = []
var transition_rect: ColorRect = null
var animation_player: AnimationPlayer = null
var _area_transitioning: bool = false
var active_section_name: String = SECTION_1_NAME
var _camera_focus_until_msec: int = 0
var _last_applied_section_name: String = ""
var _cached_gate_centers: Array[Vector2] = []

func _ready() -> void:
	if boss_scene:
		active_section_name = SECTION_2_NAME
	if GameManager.current_game_mode == "single":
		_configure_single_player()
	else:
		_ensure_player2_from_pending()
	_prepare_transition_rect()
	call_deferred("_register_scene_players")
	call_deferred("_apply_pending_transition_positions")
	set_process(true)

	var area: Area2D = get_node_or_null("transicionBOSS") as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	_connect_area14_transitions()
	call_deferred("_apply_global_limits")
	if create_extra_limit_walls_enabled:
		call_deferred("_create_extra_limit_walls")
	call_deferred("_cache_transition_gate_centers")

func _process(delta: float) -> void:
	if active and clamp_players_during_fight:
		_clamp_players_to_arena()
	if not active:
		_update_section_camera(delta)

func _apply_global_limits() -> void:
	_update_active_section_from_players()
	for player in _get_all_players():
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			_configure_camera(camera, _get_active_section_limits())
			camera.zoom = section_normal_zoom

func _register_scene_players() -> void:
	var p1: Node2D = get_node_or_null("Player1") as Node2D
	if p1 != null:
		GameManager.register_player1(p1 if GameManager.current_game_mode != "single" or GameManager.selected_single_player != "player2" else null)
		if GameManager.current_game_mode == "single" and GameManager.selected_single_player == "player2":
			GameManager.register_player2(p1)
		if "input_mode" in p1:
			p1.set("input_mode", "keyboard" if GameManager.current_game_mode == "coop" else "both")
		var camera: Camera2D = p1.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.make_current()

	var p2: Node2D = get_node_or_null("Player2") as Node2D
	if p2 != null and GameManager.current_game_mode != "single":
		GameManager.register_player2(p2)

	var hud: Node = get_node_or_null("GameplayHUD")
	if hud != null:
		hud.visible = false
		if hud.has_method("setup"):
			if GameManager.current_game_mode == "single":
				_setup_single_hud(hud, p1)
			else:
				hud.setup(p1, p2)

func _setup_single_hud(hud: Node, active_player: Node2D) -> void:
	if GameManager.selected_single_player == "player2":
		hud.setup(null, active_player, "", "Eldric")
	else:
		hud.setup(active_player, null, "Kaizen", "")

func _apply_pending_transition_positions() -> void:
	var p1: Node2D = get_node_or_null("Player1") as Node2D
	var p2: Node2D = get_node_or_null("Player2") as Node2D
	GameManager.apply_pending_positions(p1, p2)
	_update_active_section_from_players()
	_apply_section_camera_limits()
	_start_camera_focus()

func _configure_single_player() -> void:
	if get_node_or_null("Player1") != null:
		return
	var spawn_marker: Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
	var spawn_position: Vector2 = spawn_marker.global_position if spawn_marker != null else Vector2.ZERO
	var player_scene: PackedScene = PLAYER2_SCENE if GameManager.selected_single_player == "player2" else PLAYER1_SCENE
	var player: Node2D = player_scene.instantiate() as Node2D
	if player == null:
		return
	player.name = "Player1"
	player.global_position = spawn_position
	add_child(player)
	if "input_mode" in player:
		player.set("input_mode", "both")
	if player is CollisionObject2D:
		var collision_player := player as CollisionObject2D
		collision_player.collision_layer = 2
		collision_player.collision_mask = max(collision_player.collision_mask, 1)
	GameManager.apply_player_progress(player)
	_ensure_player_camera(player)

func _ensure_player_camera(active_player: Node2D) -> void:
	var camera := active_player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		for child in active_player.get_children():
			if child is Camera2D:
				camera = child as Camera2D
				break
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.position = Vector2(0, -21)
		camera.zoom = section_normal_zoom
		active_player.add_child(camera)
	camera.call_deferred("make_current")

func _ensure_player2_from_pending() -> void:
	if get_node_or_null("Player2") != null:
		return
	if not GameManager.should_restore_player2():
		return

	var new_player: Node = PLAYER2_SCENE.instantiate()
	if new_player is Node2D:
		var player2: Node2D = new_player as Node2D
		player2.name = "Player2"
		player2.global_position = SECTION_2_PLAYER2_POSITION if boss_scene else SECTION_1_PLAYER2_POSITION
		add_child(player2)

func _connect_area14_transitions() -> void:
	if boss_scene:
		_connect_transition_area("transicionarea14ENTER2", _on_area14_enter_transition_entered)
		_connect_transition_area("transicionarea14ENTER4", _on_area14_enter_transition_entered)
	else:
		_connect_transition_area("transicionarea14ENTER2", _on_area14_enter_transition_entered)
		_connect_transition_area("transicionarea14OUT2", _on_area14_out_transition_entered)

func _on_area14_enter_transition_entered(body: Node2D) -> void:
	if _area_transitioning:
		return
	if _is_player_body(body):
		_transition_to_previous_area()

func _on_area14_out_transition_entered(body: Node2D) -> void:
	if _area_transitioning:
		return
	if _is_player_body(body):
		_transition_to_next_area()

func _on_area14_section_2_enter_transition_entered(body: Node2D) -> void:
	if _area_transitioning:
		return
	if _is_player_body(body):
		_transition_to_section_1()

func _transition_to_previous_area() -> void:
	if previous_area_scene.is_empty():
		return
	_area_transitioning = true
	await _play_fade_to_black("transicionarea14ENTER1")

	var p1: Node2D = get_node_or_null("Player1") as Node2D
	var p2: Node2D = get_node_or_null("Player2") as Node2D
	var player2_exists: bool = p2 != null and is_instance_valid(p2)
	GameManager.pending_load_data = {
		"player1_position": previous_area_player1_position,
		"player2_exists": player2_exists,
		"player2_position": previous_area_player2_position,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode,
		"selected_single_player": GameManager.selected_single_player
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
	GameManager.capture_player_progress(p1)
	get_tree().change_scene_to_file(previous_area_scene)

func _transition_to_next_area() -> void:
	if next_area_scene.is_empty():
		return
	_area_transitioning = true
	await _play_fade_to_black("transicionarea14OUT1")

	var p1: Node2D = get_node_or_null("Player1") as Node2D
	var p2: Node2D = get_node_or_null("Player2") as Node2D
	var player2_exists: bool = p2 != null and is_instance_valid(p2)
	GameManager.pending_load_data = {
		"player1_position": next_area_player1_position,
		"player2_exists": player2_exists,
		"player2_position": next_area_player2_position,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode,
		"selected_single_player": GameManager.selected_single_player
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
	GameManager.capture_player_progress(p1)
	get_tree().change_scene_to_file(next_area_scene)

func _transition_to_section_1() -> void:
	_area_transitioning = true
	await _play_fade_to_black("transicionarea14ENTER3")
	_move_players_to_positions(SECTION_1_PLAYER1_POSITION, SECTION_1_PLAYER2_POSITION)
	active_section_name = SECTION_1_NAME
	_apply_section_camera_limits()
	_start_camera_focus()
	await _fade_from_black()
	_area_transitioning = false

func _move_players_to_positions(player1_position: Vector2, player2_position: Vector2) -> void:
	var p1: Node2D = get_node_or_null("Player1") as Node2D
	var p2: Node2D = get_node_or_null("Player2") as Node2D
	if p1 != null:
		p1.global_position = player1_position
	if p2 != null and is_instance_valid(p2):
		p2.global_position = player2_position

func _start_camera_focus() -> void:
	_camera_focus_until_msec = Time.get_ticks_msec() + int(transition_focus_seconds * 1000.0)
	for player in _get_all_players():
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.zoom = transition_focus_zoom

func _update_section_camera(delta: float) -> void:
	_update_active_section_from_players()
	var target_zoom: Vector2 = _get_target_section_zoom()
	var lerp_weight: float = clampf(delta * camera_zoom_lerp_speed, 0.0, 1.0)
	if _last_applied_section_name != active_section_name:
		_apply_section_camera_limits()

	for player in _get_all_players():
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.zoom = camera.zoom.lerp(target_zoom, lerp_weight)

func _apply_section_camera_limits() -> void:
	_last_applied_section_name = active_section_name
	for player in _get_all_players():
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			_configure_camera(camera, _get_active_section_limits())

func _update_active_section_from_players() -> void:
	var p1: Node2D = get_node_or_null("Player1") as Node2D
	if p1 == null:
		return
	if p1.global_position.x >= section_2_start_x:
		active_section_name = SECTION_2_NAME
	else:
		active_section_name = SECTION_1_NAME

func _get_active_section_limits() -> Rect2:
	if active_section_name == SECTION_2_NAME:
		return section_2_camera_limits
	return area14_first_section_camera_limits

func _get_target_section_zoom() -> Vector2:
	if Time.get_ticks_msec() < _camera_focus_until_msec:
		return transition_focus_zoom
	if _is_player_near_transition_gate():
		return section_gate_zoom
	return section_normal_zoom

func _is_player_near_transition_gate() -> bool:
	var p1: Node2D = get_node_or_null("Player1") as Node2D
	if p1 == null:
		return false

	for gate_center in _cached_gate_centers:
		if p1.global_position.distance_to(gate_center) <= gate_zoom_distance:
			return true

	return false

func _cache_transition_gate_centers() -> void:
	_cached_gate_centers.clear()
	var gate_names: Array[String] = [
		"transicionarea14ENTER2",
		"transicionarea14OUT2",
		"transicionarea14ENTER4",
		"transicionarea14ENTER6",
		"transicionBOSS"
	]
	for gate_name in gate_names:
		var gate: Area2D = _find_area2d_by_name(gate_name)
		if gate != null:
			_cached_gate_centers.append(_get_area_collision_center(gate))

func _get_area_collision_center(area: Area2D) -> Vector2:
	for child in area.get_children():
		if child is CollisionShape2D:
			var shape: CollisionShape2D = child as CollisionShape2D
			return shape.global_position
	return area.global_position

func _is_player_body(body: Node2D) -> bool:
	if body == null:
		return false
	return body.name.begins_with("Player") or body.is_in_group(&"Player") or body.is_in_group(&"player")

func _connect_transition_area(area_name: String, callback: Callable) -> void:
	var transition_area: Area2D = _find_area2d_by_name(area_name)
	if transition_area == null:
		return
	if not transition_area.body_entered.is_connected(callback):
		transition_area.body_entered.connect(callback)

func _find_area2d_by_name(node_name: String) -> Area2D:
	var node: Node = find_child(node_name, true, false)
	if node is Area2D:
		return node as Area2D
	return null

func _prepare_transition_rect() -> void:
	if transition_rect == null:
		transition_rect = _find_transition_rect()
	if animation_player == null:
		animation_player = _find_transition_animation_player()
	if transition_rect == null:
		return

	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.offset_left = 0.0
	transition_rect.offset_top = 0.0
	transition_rect.offset_right = 0.0
	transition_rect.offset_bottom = 0.0
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.z_index = 4096
	transition_rect.color = Color(0, 0, 0, 0)

func _play_fade_to_black(canvas_name: String = "") -> void:
	_select_transition_nodes(canvas_name)
	_prepare_transition_rect()
	await get_tree().process_frame
	if transition_rect == null:
		return

	if animation_player != null and animation_player.has_animation("fade_to_black"):
		animation_player.play("fade_to_black")
	else:
		var tween: Tween = create_tween()
		tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), FADE_WAIT_SECONDS)

	await get_tree().create_timer(FADE_WAIT_SECONDS).timeout
	transition_rect.color = Color(0, 0, 0, 1)

func _fade_from_black() -> void:
	if transition_rect == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), FADE_WAIT_SECONDS)
	await tween.finished

func _select_transition_nodes(canvas_name: String) -> void:
	var canvas: Node = get_node_or_null(canvas_name)
	if canvas == null:
		return

	var rect: Node = canvas.get_node_or_null("ColorRect")
	if rect is ColorRect:
		transition_rect = rect as ColorRect

	var anim: Node = canvas.get_node_or_null("AnimationPlayer")
	if anim is AnimationPlayer:
		animation_player = anim as AnimationPlayer

func _find_transition_rect() -> ColorRect:
	for child in get_children():
		if child is CanvasLayer:
			var rect: Node = child.get_node_or_null("ColorRect")
			if rect is ColorRect:
				return rect as ColorRect
	return null

func _find_transition_animation_player() -> AnimationPlayer:
	for child in get_children():
		if child is CanvasLayer:
			var anim: Node = child.get_node_or_null("AnimationPlayer")
			if anim is AnimationPlayer:
				return anim as AnimationPlayer
	return null

func _on_body_entered(body: Node2D) -> void:
	if _is_player_body(body):
		if not body in players_in_area:
			players_in_area.append(body)
			_check_activation()

func _on_body_exited(body: Node2D) -> void:
	if body in players_in_area:
		players_in_area.erase(body)

func _check_activation() -> void:
	if active:
		return
	var expected: int = 2 if GameManager.current_game_mode == "coop" and GameManager.current_player1 and GameManager.current_player2 else 1
	if players_in_area.size() >= expected:
		_activate_boss_fight()

func _activate_boss_fight() -> void:
	active = true
	var agis: Node2D = find_child("Agis", true, false) as Node2D
	if agis != null:
		if agis.has_method("activate"):
			agis.activate()
		if agis.has_signal("boss_defeated"):
			agis.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
		_configure_agis_spawns(agis)
		# El HUD ahora lo muestra Agis después del delay y del teleportIN.
		# _show_combat_hud(agis)

	call_deferred("_lock_arena_walls")
	_lock_camera()

func _show_combat_hud(agis: Node2D) -> void:
	var hud: Node = get_node_or_null("GameplayHUD")
	if hud == null:
		return
	if hud.has_method("setup"):
		if GameManager.current_game_mode == "single":
			var p1: Node2D = get_node_or_null("Player1") as Node2D
			_setup_single_hud(hud, p1)
		else:
			hud.setup(GameManager.current_player1, GameManager.current_player2)
	if agis != null and hud.has_method("set_boss"):
		hud.set_boss(agis)
	if hud.has_method("show_combat_hud"):
		hud.show_combat_hud()
	else:
		hud.visible = true

func _on_boss_defeated() -> void:
	release_camera()

func _lock_camera() -> void:
	for player in players_in_area:
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			original_camera_limits[player] = {
				"left": camera.limit_left, "top": camera.limit_top,
				"right": camera.limit_right, "bottom": camera.limit_bottom,
				"zoom": camera.zoom, "offset": camera.offset
			}
			_configure_camera(camera, arena_rect)

			var tween: Tween = create_tween().set_parallel(true)
			tween.tween_property(camera, "zoom", zoom_level, 1.0).set_trans(Tween.TRANS_SINE)
			tween.tween_property(camera, "offset", camera_offset, 1.0).set_trans(Tween.TRANS_SINE)

func release_camera() -> void:
	_unlock_arena_walls()
	for player in original_camera_limits.keys():
		if is_instance_valid(player):
			var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
			if camera != null:
				var limits: Dictionary = original_camera_limits[player]
				camera.limit_left = limits["left"]
				camera.limit_top = limits["top"]
				camera.limit_right = limits["right"]
				camera.limit_bottom = limits["bottom"]
				var tween: Tween = create_tween().set_parallel(true)
				tween.tween_property(camera, "zoom", limits["zoom"], 1.0)
				tween.tween_property(camera, "offset", limits["offset"], 1.0)
	active = false

func _configure_camera(camera: Camera2D, limits: Rect2) -> void:
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.position.x + limits.size.x)
	camera.limit_bottom = int(limits.position.y + limits.size.y)
	camera.offset = camera_offset

func _configure_agis_spawns(agis: Node2D) -> void:
	if "spawn_range_x" in agis:
		agis.set("spawn_range_x", Vector2(
			arena_rect.position.x + zombie_spawn_margin,
			arena_rect.position.x + arena_rect.size.x - zombie_spawn_margin
		))
	if "spawn_y" in agis:
		agis.set("spawn_y", 536.0)

func _clamp_players_to_arena() -> void:
	var min_position: Vector2 = arena_rect.position
	var max_position: Vector2 = arena_rect.position + arena_rect.size
	for player in _get_all_players():
		if player is Node2D:
			var player_2d: Node2D = player as Node2D
			player_2d.global_position = Vector2(
				clampf(player_2d.global_position.x, min_position.x, max_position.x),
				clampf(player_2d.global_position.y, min_position.y, max_position.y)
			)

func _lock_arena_walls() -> void:
	_unlock_arena_walls()
	var left_x: float = arena_rect.position.x
	var right_x: float = arena_rect.position.x + arena_rect.size.x
	arena_walls.append(_create_arena_wall("AgisArenaLeftWall", Vector2(left_x, (arena_wall_top + arena_wall_bottom) * 0.5)))
	arena_walls.append(_create_arena_wall("AgisArenaRightWall", Vector2(right_x, (arena_wall_top + arena_wall_bottom) * 0.5)))

func _unlock_arena_walls() -> void:
	for wall in arena_walls:
		if is_instance_valid(wall):
			wall.call_deferred("queue_free")
	arena_walls.clear()

func _create_arena_wall(wall_name: String, wall_position: Vector2) -> StaticBody2D:
	return _create_static_rect(
		wall_name,
		wall_position,
		Vector2(32, arena_wall_bottom - arena_wall_top)
	)

func _create_extra_limit_walls() -> void:
	_clear_extra_limit_walls()
	var left: float = extra_limit_rect.position.x
	var top: float = extra_limit_rect.position.y
	var right: float = extra_limit_rect.position.x + extra_limit_rect.size.x
	var bottom: float = extra_limit_rect.position.y + extra_limit_rect.size.y
	var center_x: float = (left + right) * 0.5
	var center_y: float = (top + bottom) * 0.5
	var width: float = extra_limit_rect.size.x
	var height: float = extra_limit_rect.size.y

	extra_limit_walls.append(_create_static_rect("ExtraLimitLeftWall", Vector2(left, center_y), Vector2(32, height)))
	extra_limit_walls.append(_create_static_rect("ExtraLimitRightWall", Vector2(right, center_y), Vector2(32, height)))
	extra_limit_walls.append(_create_static_rect("ExtraLimitTopWall", Vector2(center_x, top), Vector2(width, 32)))
	extra_limit_walls.append(_create_static_rect("ExtraLimitBottomWall", Vector2(center_x, bottom), Vector2(width, 32)))

func _clear_extra_limit_walls() -> void:
	for wall in extra_limit_walls:
		if is_instance_valid(wall):
			wall.call_deferred("queue_free")
	extra_limit_walls.clear()

func _create_static_rect(wall_name: String, wall_position: Vector2, wall_size: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)
	wall.global_position = wall_position

	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = wall_size
	shape.shape = rect
	wall.add_child(shape)
	return wall

func _get_all_players() -> Array[Node]:
	var players: Array[Node] = []
	for group_name in [&"Player", &"player"]:
		for player in get_tree().get_nodes_in_group(group_name):
			if player is Node2D and not players.has(player):
				players.append(player)
	for node_name in ["Player1", "Player2"]:
		var player: Node = get_node_or_null(node_name)
		if player is Node2D and not players.has(player):
			players.append(player)
	return players
