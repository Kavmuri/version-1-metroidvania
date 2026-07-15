extends Node2D

@onready var transition_rect: ColorRect = _find_transition_rect()
@onready var animation_player: AnimationPlayer = _find_transition_animation_player()
@onready var _spawn_marker: Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
var player: Node2D = null
var player2: Node2D = null

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -384
const LIMIT_RIGHT: int = 4352
const LIMIT_BOTTOM: int = 512
const FIRST_SECTION_CAMERA_LIMIT_NAME: String = "first_section"
const FIRST_SECTION_CAMERA_LIMIT_LEFT: int = 160
const FIRST_SECTION_CAMERA_LIMIT_TOP: int = -256
const FIRST_SECTION_CAMERA_LIMIT_RIGHT: int = 2048
const FIRST_SECTION_CAMERA_LIMIT_BOTTOM: int = 320
const SECOND_SECTION_CAMERA_LIMIT_NAME: String = "second_section"
const SECOND_SECTION_CAMERA_LIMIT_LEFT: int = 2112
const SECOND_SECTION_CAMERA_LIMIT_TOP: int = -320
const SECOND_SECTION_CAMERA_LIMIT_RIGHT: int = 4352
const SECOND_SECTION_CAMERA_LIMIT_BOTTOM: int = 320
const SECOND_SECTION_START_X: float = 2112.0

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)
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
	preload("res://Enemies/basic/enemy_demon_boss.tscn"),
]
const ENEMY_SEED_OFFSET: int = 103

const PREVIOUS_AREA_SCENE: String = "res://Levels/single/Tileset/area1/area_1_2.tscn"
const PREVIOUS_AREA_PLAYER1_POSITION: Vector2 = Vector2(3710, -94)
const PREVIOUS_AREA_PLAYER2_POSITION: Vector2 = Vector2(3662, -94)
const SECTION_1_PLAYER1_POSITION: Vector2 = Vector2(1888, 56)
const SECTION_1_PLAYER2_POSITION: Vector2 = Vector2(1840, 56)
const SECTION_2_PLAYER1_POSITION: Vector2 = Vector2(2208, 56)
const SECTION_2_PLAYER2_POSITION: Vector2 = Vector2(2256, 56)
const FADE_WAIT_SECONDS: float = 0.55

var player_camera: Camera2D = null
var active_camera_limit_name: String = FIRST_SECTION_CAMERA_LIMIT_NAME
var _is_transitioning: bool = false

func _ready() -> void:
	_prepare_transition_rect()
	_configure_single_player()
	_spawn_random_enemies()
	_connect_transition_area("transicionarea1_3ENTER2seccion1", _on_section_1_enter_transition_entered)
	_connect_transition_area("transicionarea1_3OUTseccion1_22", _on_section_1_out_transition_entered)
	_connect_transition_area("transicionarea1_3ENTER2seccion2", _on_section_2_enter_transition_entered)
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _process(_delta: float) -> void:
	_refresh_players()
	if player == null:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_apply_area_limits()

	_update_active_camera_limit()
	_clamp_players_to_area()

func _on_section_1_enter_transition_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_previous_area()

func _on_section_1_out_transition_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_section_2()

func _on_section_2_enter_transition_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_section_1()

func _transition_to_previous_area() -> void:
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3ENTERseccion1")

	var player2_exists: bool = GameManager.current_game_mode != "single" and player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": PREVIOUS_AREA_PLAYER1_POSITION,
		"player2_exists": player2_exists,
		"player2_position": PREVIOUS_AREA_PLAYER2_POSITION,
		"game_mode": GameManager.current_game_mode,
		"selected_single_player": GameManager.selected_single_player
	}
	GameManager.capture_player_progress(player)
	get_tree().change_scene_to_file(PREVIOUS_AREA_SCENE)

func _transition_to_section_2() -> void:
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3OUTseccion1")
	_move_players_to_positions(SECTION_2_PLAYER1_POSITION, SECTION_2_PLAYER2_POSITION)
	active_camera_limit_name = SECOND_SECTION_CAMERA_LIMIT_NAME
	if player_camera != null and is_instance_valid(player_camera):
		_configure_camera_limits(player_camera)
	await _fade_from_black()
	_is_transitioning = false

func _transition_to_section_1() -> void:
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3ENTERseccion2")
	_move_players_to_positions(SECTION_1_PLAYER1_POSITION, SECTION_1_PLAYER2_POSITION)
	active_camera_limit_name = FIRST_SECTION_CAMERA_LIMIT_NAME
	if player_camera != null and is_instance_valid(player_camera):
		_configure_camera_limits(player_camera)
	await _fade_from_black()
	_is_transitioning = false

func _move_players_to_positions(player1_position: Vector2, player2_position: Vector2) -> void:
	_refresh_players()
	if player != null:
		player.global_position = player1_position
	if player2 != null and is_instance_valid(player2):
		player2.global_position = player2_position
	_clamp_players_to_area()

func _prepare_transition_rect() -> void:
	if transition_rect == null:
		transition_rect = _create_transition_rect()
	if animation_player == null:
		animation_player = _find_transition_animation_player()

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

func _is_player_body(body: Node2D) -> bool:
	if body == null:
		return false
	return body.name.begins_with("Player") or body.is_in_group(&"Player") or body.is_in_group(&"player")

func _connect_transition_area(area_name: String, callback: Callable) -> void:
	var transition_area: Area2D = _find_area2d_by_name(area_name)
	if transition_area == null:
		push_warning("No se encontro el area de transicion: " + area_name)
		return

	if not transition_area.body_entered.is_connected(callback):
		transition_area.body_entered.connect(callback)

func _find_area2d_by_name(node_name: String) -> Area2D:
	var node: Node = find_child(node_name, true, false)
	if node is Area2D:
		return node as Area2D
	return null

func _find_transition_rect() -> ColorRect:
	var transition_layer_rect: Node = get_node_or_null("TransitionLayer/ColorRect")
	if transition_layer_rect is ColorRect:
		return transition_layer_rect as ColorRect

	for child in get_children():
		if child is CanvasLayer:
			var rect: Node = child.get_node_or_null("ColorRect")
			if rect is ColorRect:
				return rect as ColorRect

	return null

func _find_transition_animation_player() -> AnimationPlayer:
	var transition_layer_player: Node = get_node_or_null("TransitionLayer/AnimationPlayer")
	if transition_layer_player is AnimationPlayer:
		return transition_layer_player as AnimationPlayer

	for child in get_children():
		if child is CanvasLayer:
			var anim: Node = child.get_node_or_null("AnimationPlayer")
			if anim is AnimationPlayer:
				return anim as AnimationPlayer

	return null

func _create_transition_rect() -> ColorRect:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TransitionLayer"
	add_child(layer)

	var rect: ColorRect = ColorRect.new()
	rect.name = "ColorRect"
	layer.add_child(rect)
	return rect

func _apply_area_limits() -> void:
	_refresh_players()
	if player == null:
		return

	player_camera = _find_player_camera()
	for child in player.get_children():
		if child is Camera2D:
			_configure_camera_limits(child as Camera2D)

	if player_camera != null:
		player_camera.call_deferred("make_current")

func _apply_pending_transition_positions() -> void:
	_refresh_players()
	GameManager.apply_pending_positions(player, player2)
	_clamp_players_to_area()

func _refresh_players() -> void:
	if GameManager.current_game_mode == "single" and GameManager.selected_single_player == "player2":
		if player2 == null or not is_instance_valid(player2):
			player2 = get_node_or_null("Player2") as Node2D
		player = player2
		return
	if player == null or not is_instance_valid(player):
		player = get_node_or_null("Player1") as Node2D
	if player2 == null or not is_instance_valid(player2):
		player2 = get_node_or_null("Player2") as Node2D

func _configure_single_player() -> void:
	var spawn_position := _spawn_marker.global_position if _spawn_marker != null else Vector2.ZERO
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

func _spawn_random_enemies() -> void:
	var spawn_points: Array[Vector2] = _find_enemy_spawn_points()
	EnemyEncounterPool.populate(self, spawn_points, ENEMY_POOL, GameManager.get_world_seed_for_generation() + ENEMY_SEED_OFFSET)

func _find_enemy_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("EnemySpawn"):
			points.append((child as Marker2D).global_position)
	return points

func _configure_active_player(active_player: Node2D) -> void:
	if active_player == null:
		return
	if "input_mode" in active_player:
		active_player.set("input_mode", "both")
	if active_player is CollisionObject2D:
		var collision_player := active_player as CollisionObject2D
		collision_player.collision_layer = 2
		collision_player.collision_mask = max(collision_player.collision_mask, 1)
	GameManager.apply_player_progress(active_player)
	_ensure_player_camera(active_player)

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
		camera.zoom = Vector2(0.85, 0.85)
		active_player.add_child(camera)
	_configure_camera_limits(camera)
	camera.call_deferred("make_current")

func _ensure_gameplay_hud(player1_node: Node2D, player2_node: Node2D) -> void:
	var hud := get_node_or_null("GameplayHUD")
	if hud == null:
		hud = GAMEPLAY_HUD_SCENE.instantiate()
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
	var pause_menu := get_node_or_null("PauseMenu")
	if pause_menu == null:
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		pause_menu.name = "PauseMenu"
		add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.setup(active_player)

func _find_player_camera() -> Camera2D:
	var named_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if named_camera != null:
		return named_camera

	for child in player.get_children():
		if child is Camera2D:
			return child as Camera2D

	return null

func _configure_camera_limits(camera: Camera2D) -> void:
	if active_camera_limit_name == FIRST_SECTION_CAMERA_LIMIT_NAME:
		camera.limit_left = FIRST_SECTION_CAMERA_LIMIT_LEFT
		camera.limit_top = FIRST_SECTION_CAMERA_LIMIT_TOP
		camera.limit_right = FIRST_SECTION_CAMERA_LIMIT_RIGHT
		camera.limit_bottom = FIRST_SECTION_CAMERA_LIMIT_BOTTOM
		return

	if active_camera_limit_name == SECOND_SECTION_CAMERA_LIMIT_NAME:
		camera.limit_left = SECOND_SECTION_CAMERA_LIMIT_LEFT
		camera.limit_top = SECOND_SECTION_CAMERA_LIMIT_TOP
		camera.limit_right = SECOND_SECTION_CAMERA_LIMIT_RIGHT
		camera.limit_bottom = SECOND_SECTION_CAMERA_LIMIT_BOTTOM
		return

	camera.limit_left = LIMIT_LEFT
	camera.limit_top = LIMIT_TOP
	camera.limit_right = LIMIT_RIGHT
	camera.limit_bottom = LIMIT_BOTTOM

func _update_active_camera_limit() -> void:
	if player == null:
		return

	var target_limit_name: String = FIRST_SECTION_CAMERA_LIMIT_NAME
	if player.global_position.x >= SECOND_SECTION_START_X:
		target_limit_name = SECOND_SECTION_CAMERA_LIMIT_NAME

	if active_camera_limit_name == target_limit_name:
		return

	active_camera_limit_name = target_limit_name
	if player_camera != null and is_instance_valid(player_camera):
		_configure_camera_limits(player_camera)

func _clamp_players_to_area() -> void:
	_clamp_player_to_area(player)
	_clamp_player_to_area(player2)

func _clamp_player_to_area(player_node: Node2D) -> void:
	if player_node == null:
		return

	player_node.global_position = Vector2(
		clampf(player_node.global_position.x, MAP_MIN.x, MAP_MAX.x),
		clampf(player_node.global_position.y, MAP_MIN.y, MAP_MAX.y)
	)
