extends Node2D

@onready var transition_rect: ColorRect = $TransitionLayer/ColorRect
@onready var animation_player: AnimationPlayer = $TransitionLayer/AnimationPlayer
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground2
@onready var parallax_bg3: ParallaxBackground = $ParallaxBackground3
@onready var player: Node2D = get_node_or_null("Player1") as Node2D
@onready var player2: Node2D = get_node_or_null("Player2") as Node2D

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -200
const LIMIT_RIGHT: int = 1664
const LIMIT_BOTTOM: int = 192
const MAP_END_X: int = LIMIT_RIGHT
const NEXT_AREA_SCENE: String = "res://Tileset/area1/area_1_2.tscn"
const NEXT_PLAYER1_POSITION: Vector2 = Vector2(97, -94)
const NEXT_PLAYER2_POSITION: Vector2 = Vector2(145, -94)
const START_PLAYER2_POSITION: Vector2 = Vector2(128, -32)
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")
const FADE_WAIT_SECONDS: float = 0.55

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)

const COOP_CAMERA_CLOSE_ZOOM: Vector2 = Vector2(0.85, 0.85)
const COOP_CAMERA_FAR_ZOOM: Vector2 = Vector2(0.55, 0.55)
const COOP_CAMERA_CLOSE_DISTANCE: float = 140.0
const COOP_CAMERA_FAR_DISTANCE: float = 420.0
const COOP_CAMERA_FOLLOW_SPEED: float = 4.0
const COOP_CAMERA_ZOOM_SPEED: float = 2.5

var _parallax_stopped = false
var _is_transitioning: bool = false
var player_camera: Camera2D = null
var _camera_local_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	transition_rect.color.a = 0
	_prepare_transition_rect()
	_ensure_player2()
	$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)
	_hide_parallax_until_camera_ready()
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _hide_parallax_until_camera_ready() -> void:
	if parallax_bg != null:
		parallax_bg.visible = false
	if parallax_bg3 != null:
		parallax_bg3.visible = false
	_reveal_parallax_after_delay()

func _reveal_parallax_after_delay() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if parallax_bg != null:
		parallax_bg.visible = true
	if parallax_bg3 != null:
		parallax_bg3.visible = true

func _process(delta: float) -> void:
	_refresh_players()
	_clamp_players_to_area()
	if player != null and not _parallax_stopped and player.global_position.x >= MAP_END_X - 100:
		_stop_parallax()

	if player_camera == null or not is_instance_valid(player_camera):
		return

	if _is_coop_camera_active():
		_ensure_camera_top_level()
		_update_coop_camera(delta)
	else:
		_release_camera_top_level()

func _ensure_camera_top_level() -> void:
	if player_camera.top_level:
		return
	var current_global: Vector2 = player_camera.global_position
	player_camera.top_level = true
	player_camera.global_position = current_global

func _release_camera_top_level() -> void:
	if not player_camera.top_level:
		return
	player_camera.top_level = false
	player_camera.position = _camera_local_position

func _is_coop_camera_active() -> bool:
	return GameManager.current_game_mode == "coop" and player2 != null and is_instance_valid(player2)

func _update_coop_camera(delta: float) -> void:
	var target_position: Vector2 = (player.global_position + player2.global_position) * 0.5
	var distance: float = player.global_position.distance_to(player2.global_position)
	var t: float = clampf(inverse_lerp(COOP_CAMERA_CLOSE_DISTANCE, COOP_CAMERA_FAR_DISTANCE, distance), 0.0, 1.0)
	var target_zoom: Vector2 = COOP_CAMERA_CLOSE_ZOOM.lerp(COOP_CAMERA_FAR_ZOOM, t)

	var pos_weight: float = 1.0 - exp(-COOP_CAMERA_FOLLOW_SPEED * delta)
	var zoom_weight: float = 1.0 - exp(-COOP_CAMERA_ZOOM_SPEED * delta)
	player_camera.global_position = player_camera.global_position.lerp(target_position, pos_weight)
	player_camera.zoom = player_camera.zoom.lerp(target_zoom, zoom_weight)

func _on_transition_trigger_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_next_area()

func _transition_to_next_area() -> void:
	_is_transitioning = true
	if not _parallax_stopped:
		_stop_parallax()

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

	player_camera = _find_player_camera()
	for child in player.get_children():
		if child is Camera2D:
			_configure_camera_limits(child as Camera2D)

	if player_camera != null:
		if not player_camera.top_level:
			_camera_local_position = player_camera.position
		player_camera.call_deferred("make_current")

func _find_player_camera() -> Camera2D:
	var named_camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if named_camera != null:
		return named_camera

	for child in player.get_children():
		if child is Camera2D:
			return child as Camera2D

	return null

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
