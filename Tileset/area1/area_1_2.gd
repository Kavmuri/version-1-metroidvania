extends Node2D

@onready var transition_rect: ColorRect = $TransitionLayer/ColorRect
@onready var animation_player: AnimationPlayer = $TransitionLayer/AnimationPlayer
@onready var player: Node2D = get_node_or_null("Player1") as Node2D
@onready var player2: Node2D = get_node_or_null("Player2") as Node2D

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -640
const LIMIT_RIGHT: int = 3904
const LIMIT_BOTTOM: int = 512

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)
const START_PLAYER2_POSITION: Vector2 = Vector2(145, -94)
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")
const NEXT_AREA_SCENE: String = "res://Tileset/area1/area_1_3.tscn"
const NEXT_PLAYER1_POSITION: Vector2 = Vector2(296, 56)
const NEXT_PLAYER2_POSITION: Vector2 = Vector2(344, 56)
const FADE_WAIT_SECONDS: float = 0.55

@export var close_zoom: Vector2 = Vector2(0.85, 0.85)
@export var far_zoom: Vector2 = Vector2(0.74, 0.74)
@export var zoom_start_x: float = 256.0
@export var zoom_end_x: float = 3600.0
@export var zoom_lerp_speed: float = 1.1

var player_camera: Camera2D = null
var _is_transitioning: bool = false

func _ready() -> void:
	transition_rect.color.a = 0
	_prepare_transition_rect()
	_ensure_player2()
	$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _process(delta: float) -> void:
	_refresh_players()
	if player == null:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_apply_area_limits()

	_clamp_players_to_area()
	_update_camera_zoom(delta)

func _on_transition_trigger_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_next_area()

func _transition_to_next_area() -> void:
	_is_transitioning = true
	await _play_fade_to_black()

	var player2_exists: bool = player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": NEXT_PLAYER1_POSITION,
		"player2_exists": player2_exists,
		"player2_position": NEXT_PLAYER2_POSITION,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
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

func _apply_area_limits() -> void:
	_refresh_players()
	if player == null:
		return

	player_camera = _find_player_camera()
	for child in player.get_children():
		if child is Camera2D:
			_configure_camera_limits(child as Camera2D)

	if player_camera != null:
		player_camera.zoom = close_zoom
		player_camera.call_deferred("make_current")

func _apply_pending_transition_positions() -> void:
	_refresh_players()
	GameManager.apply_pending_positions(player, player2)
	_clamp_players_to_area()

func _refresh_players() -> void:
	if player == null or not is_instance_valid(player):
		player = get_node_or_null("Player1") as Node2D
	if player2 == null or not is_instance_valid(player2):
		player2 = get_node_or_null("Player2") as Node2D

func _ensure_player2() -> void:
	_refresh_players()
	if player2 != null:
		return

	var new_player: Node = PLAYER2_SCENE.instantiate()
	if new_player is Node2D:
		player2 = new_player as Node2D
		player2.name = "Player2"
		player2.global_position = START_PLAYER2_POSITION
		add_child(player2)

func _find_player_camera() -> Camera2D:
	var named_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if named_camera != null:
		return named_camera

	for child in player.get_children():
		if child is Camera2D:
			return child as Camera2D

	return null

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

func _update_camera_zoom(delta: float) -> void:
	if player == null:
		return

	if player_camera == null or not is_instance_valid(player_camera):
		player_camera = _find_player_camera()
		if player_camera == null:
			return
		_configure_camera_limits(player_camera)

	var progress: float = inverse_lerp(zoom_start_x, zoom_end_x, player.global_position.x)
	progress = clampf(progress, 0.0, 1.0)

	var target_zoom: Vector2 = close_zoom.lerp(far_zoom, progress)
	var lerp_weight: float = clampf(delta * zoom_lerp_speed, 0.0, 1.0)
	player_camera.zoom = player_camera.zoom.lerp(target_zoom, lerp_weight)
