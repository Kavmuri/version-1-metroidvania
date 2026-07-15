extends Node2D

@onready var transition_rect: ColorRect = $TransitionLayer/ColorRect
@onready var animation_player: AnimationPlayer = $TransitionLayer/AnimationPlayer
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground2
@onready var parallax_bg3: ParallaxBackground = $ParallaxBackground3
@onready var _spawn_marker: Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
var player: Node2D = null
var player2: Node2D = null

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -384
const LIMIT_RIGHT: int = 1664
const LIMIT_BOTTOM: int = 192
const MAP_END_X: int = LIMIT_RIGHT
const NEXT_AREA_SCENE: String = "res://Levels/single/Tileset/area1/area_1_2.tscn"
const NEXT_PLAYER1_POSITION: Vector2 = Vector2(97, -94)
const NEXT_PLAYER2_POSITION: Vector2 = Vector2(145, -94)
const PLAYER1_SCENE: PackedScene = preload("res://Player1/player.tscn")
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")
const GAMEPLAY_HUD_SCENE: PackedScene = preload("res://UI/scenes/gameplay_hud.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://UI/scenes/pause_menu.tscn")
const FADE_WAIT_SECONDS: float = 0.55

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
const ENEMY_SEED_OFFSET: int = 101

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)

var _parallax_stopped = false
var _is_transitioning: bool = false

func _ready() -> void:
	transition_rect.color.a = 0
	_prepare_transition_rect()
	_configure_single_player()
	_spawn_random_enemies()
	$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _spawn_random_enemies() -> void:
	var spawn_points: Array[Vector2] = _find_enemy_spawn_points()
	EnemyEncounterPool.populate(self, spawn_points, ENEMY_POOL, GameManager.get_world_seed_for_generation() + ENEMY_SEED_OFFSET)

func _find_enemy_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("EnemySpawn"):
			points.append((child as Marker2D).global_position)
	return points

func _process(_delta: float) -> void:
	_refresh_players()
	_clamp_players_to_area()
	if player != null and not _parallax_stopped and player.global_position.x >= MAP_END_X - 100:
		_stop_parallax()

func _on_transition_trigger_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_next_area()

func _transition_to_next_area() -> void:
	_is_transitioning = true
	_show_hud_narration("Creo que ya no voy a poder volver aqui...")
	if not _parallax_stopped:
		_stop_parallax()

	await _play_fade_to_black()

	var player2_exists: bool = player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": NEXT_PLAYER1_POSITION,
		"player2_exists": player2_exists,
		"player2_position": NEXT_PLAYER2_POSITION,
		"game_mode": GameManager.current_game_mode,
		"selected_single_player": GameManager.selected_single_player
	}
	GameManager.capture_player_progress(player)
	get_tree().change_scene_to_file(NEXT_AREA_SCENE)

func _prepare_transition_rect() -> void:
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.offset_left = 0.0
	transition_rect.offset_top = 0.0
	transition_rect.offset_right = 0.0
	transition_rect.offset_bottom = 0.0
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.z_index = 4096
	transition_rect.color = Color(0, 0, 0, 0)

func _play_fade_to_black() -> void:
	_prepare_transition_rect()
	await get_tree().process_frame
	animation_player.play("fade_to_black")
	await get_tree().create_timer(FADE_WAIT_SECONDS).timeout
	transition_rect.color = Color(0, 0, 0, 1)

func _is_player_body(body: Node2D) -> bool:
	if body == null:
		return false
	return body.name.begins_with("Player") or body.is_in_group(&"Player") or body.is_in_group(&"player")

func _stop_parallax() -> void:
	_parallax_stopped = true
	# Disabling mirroring
	# Check existence of background nodes to avoid crashes if they don't exist
	var backgrounds: Array[Node] = []
	if has_node("ParallaxBackground2"):
		backgrounds.append(parallax_bg)
	if has_node("ParallaxBackground3"):
		backgrounds.append(parallax_bg3)

	for bg in backgrounds:
		for child in bg.get_children():
			if child is ParallaxLayer:
				child.motion_mirroring = Vector2.ZERO

func _apply_area_limits() -> void:
	_refresh_players()
	if player == null:
		return

	var player_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
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
	var spawn_position := _spawn_marker.global_position if _spawn_marker != null else Vector2(1400, 152)
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

func _show_hud_narration(text: String) -> void:
	var hud := get_node_or_null("GameplayHUD")
	if hud != null and hud.has_method("show_narration"):
		hud.show_narration(text)

func _ensure_pause_menu(active_player: Node2D) -> void:
	var pause_menu := get_node_or_null("PauseMenu")
	if pause_menu == null:
		pause_menu = PAUSE_MENU_SCENE.instantiate()
		pause_menu.name = "PauseMenu"
		add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.setup(active_player)

func _configure_camera_limits(camera: Camera2D) -> void:
	camera.limit_left = LIMIT_LEFT
	camera.limit_top = LIMIT_TOP
	camera.limit_right = LIMIT_RIGHT
	camera.limit_bottom = LIMIT_BOTTOM

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
