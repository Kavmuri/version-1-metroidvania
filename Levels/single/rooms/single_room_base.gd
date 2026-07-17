class_name SingleRoomBase
extends Node2D

const PLAYER1_SCENE: PackedScene = preload("res://Player1/player.tscn")
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")
const GAMEPLAY_HUD_SCENE: PackedScene = preload("res://UI/scenes/gameplay_hud.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://UI/scenes/pause_menu.tscn")
const ENEMY_POOL: Array[PackedScene] = [
	preload("res://Enemies/basic/enemy_bat.tscn"),
	preload("res://Enemies/basic/enemy_ghost.tscn"),
	preload("res://Enemies/basic/enemy_skeleton_sword_white.tscn"),
	preload("res://Enemies/basic/enemy_skeleton_sword_yellow.tscn"),
	preload("res://Enemies/basic/enemy_mutant_toad.tscn"),
	preload("res://Enemies/basic/enemy_crab.tscn"),
	preload("res://Enemies/basic/enemy_flying_eye_demon.tscn"),
	preload("res://Enemies/basic/enemy_dragon.tscn"),
	preload("res://Enemies/basic/enemy_hell_beast_fire.tscn"),
	preload("res://Enemies/basic/enemy_hell_hound_fire.tscn"),
	preload("res://Enemies/basic/enemy_nightmare.tscn"),
]
const FADE_WAIT_SECONDS := 0.35

@export var camera_limits: Rect2 = Rect2(0, -640, 3904, 1152)
@export var camera_zoom: Vector2 = Vector2(0.78, 0.78)
@export_range(1, 10, 1) var min_enemy_count: int = 1
@export_range(1, 10, 1) var max_enemy_count: int = 3
@export var enemy_seed_offset: int = 0
@export var legacy_left_exit_name: StringName = &""

var player: Node2D = null
var player2: Node2D = null
var _is_transitioning := false
var _transition_rect: ColorRect = null


func _ready() -> void:
	_disable_legacy_transition_areas()
	_configure_single_player()
	_spawn_random_enemies()
	_connect_single_exit()
	_setup_room_mechanics()
	call_deferred("_apply_pending_transition_state")


func _process(_delta: float) -> void:
	_clamp_active_player()


func _setup_room_mechanics() -> void:
	pass


func _legacy_transition_names_to_keep() -> Array[StringName]:
	return []


func transition_to_next_room() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_to_black()
	GameManager.pending_load_data = {
		"player2_exists": GameManager.selected_single_player == "player2",
		"game_mode": "single",
		"selected_single_player": GameManager.selected_single_player,
	}
	GameManager.save_player_upgrade_state(player)
	var next_room := GameManager.get_next_single_room(scene_file_path)
	if next_room.is_empty():
		_is_transitioning = false
		return
	get_tree().change_scene_to_file(next_room)


func _configure_single_player() -> void:
	var spawn_marker := get_node_or_null("PlayerSpawn") as Marker2D
	var spawn_position := spawn_marker.global_position if spawn_marker != null else camera_limits.position
	if GameManager.selected_single_player == "player2":
		player2 = PLAYER2_SCENE.instantiate() as Node2D
		player2.name = "Player2"
		player2.global_position = spawn_position
		add_child(player2)
		player = player2
		_configure_active_player(player2)
		GameManager.register_player1(null)
		GameManager.register_player2(player2)
		_ensure_gameplay_hud(null, player2)
		_ensure_pause_menu(player2)
		return

	player = PLAYER1_SCENE.instantiate() as Node2D
	player.name = "Player1"
	player.global_position = spawn_position
	add_child(player)
	player2 = null
	_configure_active_player(player)
	GameManager.register_player1(player)
	GameManager.register_player2(null)
	_ensure_gameplay_hud(player, null)
	_ensure_pause_menu(player)


func _configure_active_player(active_player: Node2D) -> void:
	if active_player == null:
		return
	if "input_mode" in active_player:
		active_player.set("input_mode", "both")
	if active_player is CollisionObject2D:
		var collision_player := active_player as CollisionObject2D
		collision_player.collision_layer = 2
		collision_player.collision_mask = maxi(collision_player.collision_mask, 1)
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
		active_player.add_child(camera)
	_configure_camera(camera)
	camera.call_deferred("make_current")


func _configure_camera(camera: Camera2D) -> void:
	camera.limit_left = floori(camera_limits.position.x)
	camera.limit_top = floori(camera_limits.position.y)
	camera.limit_right = ceili(camera_limits.end.x)
	camera.limit_bottom = ceili(camera_limits.end.y)
	camera.zoom = camera_zoom


func _spawn_random_enemies() -> void:
	var spawn_points := _find_enemy_spawn_points()
	if spawn_points.is_empty():
		return
	var minimum := clampi(min_enemy_count, 1, spawn_points.size())
	var maximum := clampi(max_enemy_count, minimum, spawn_points.size())
	var encounter_seed := GameManager.get_single_encounter_seed(scene_file_path) + enemy_seed_offset
	EnemyEncounterPool.populate_random_count(self, spawn_points, ENEMY_POOL, encounter_seed, minimum, maximum)


func _find_enemy_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	_collect_enemy_spawn_points(self, points)
	return points


func _collect_enemy_spawn_points(node: Node, points: Array[Vector2]) -> void:
	if node is Marker2D and node.name.begins_with("EnemySpawn"):
		points.append((node as Marker2D).global_position)
	for child in node.get_children():
		_collect_enemy_spawn_points(child, points)


func _connect_single_exit() -> void:
	var exit_area := get_node_or_null("SingleExitTrigger") as Area2D
	if exit_area == null:
		push_warning("La sala single no tiene SingleExitTrigger: " + scene_file_path)
	else:
		_connect_exit_area(exit_area)
	if not legacy_left_exit_name.is_empty():
		var left_exit := find_child(legacy_left_exit_name, true, false) as Area2D
		if left_exit == null:
			push_warning("No se encontro la salida izquierda %s en %s" % [legacy_left_exit_name, scene_file_path])
		else:
			_connect_exit_area(left_exit)


func _connect_exit_area(exit_area: Area2D) -> void:
	exit_area.monitoring = true
	exit_area.collision_mask = 2
	if not exit_area.body_entered.is_connected(_on_single_exit_entered):
		exit_area.body_entered.connect(_on_single_exit_entered)


func _on_single_exit_entered(body: Node2D) -> void:
	if _is_active_player(body):
		transition_to_next_room()


func _disable_legacy_transition_areas() -> void:
	var kept_names := _legacy_transition_names_to_keep()
	if not legacy_left_exit_name.is_empty():
		kept_names.append(legacy_left_exit_name)
	for node in find_children("*", "Area2D", true, false):
		var area := node as Area2D
		var lowered_name := area.name.to_lower()
		if area.name == "SingleExitTrigger" or kept_names.has(area.name):
			continue
		if "transicion" in lowered_name or "transition" in lowered_name:
			area.monitoring = false
			area.collision_mask = 0


func _apply_pending_transition_state() -> void:
	GameManager.apply_pending_positions(player if player != player2 else null, player2)
	_clamp_active_player()


func _clamp_active_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = Vector2(
		clampf(player.global_position.x, camera_limits.position.x, camera_limits.end.x),
		clampf(player.global_position.y, camera_limits.position.y, camera_limits.end.y)
	)


func _ensure_gameplay_hud(player1_node: Node2D, player2_node: Node2D) -> void:
	var hud := GAMEPLAY_HUD_SCENE.instantiate()
	hud.name = "GameplayHUD"
	add_child(hud)
	if hud.has_method("setup"):
		if player2_node != null:
			hud.setup(null, player2_node, "", "Eldric")
		else:
			hud.setup(player1_node, null, "Kaizen", "")
	if hud.has_method("show_combat_hud"):
		hud.show_combat_hud()


func _ensure_pause_menu(active_player: Node2D) -> void:
	var pause_menu := PAUSE_MENU_SCENE.instantiate()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.setup(active_player)


func _is_active_player(body: Node2D) -> bool:
	return body != null and body == player


func _fade_to_black() -> void:
	_ensure_transition_rect()
	var tween := create_tween()
	tween.tween_property(_transition_rect, "color", Color(0, 0, 0, 1), FADE_WAIT_SECONDS)
	await tween.finished


func _fade_from_black() -> void:
	_ensure_transition_rect()
	_transition_rect.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(_transition_rect, "color", Color(0, 0, 0, 0), FADE_WAIT_SECONDS)
	await tween.finished


func _ensure_transition_rect() -> void:
	if _transition_rect != null and is_instance_valid(_transition_rect):
		return
	var layer := CanvasLayer.new()
	layer.name = "SingleTransitionLayer"
	add_child(layer)
	_transition_rect = ColorRect.new()
	_transition_rect.name = "ColorRect"
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.z_index = 4096
	_transition_rect.color = Color(0, 0, 0, 0)
	layer.add_child(_transition_rect)
