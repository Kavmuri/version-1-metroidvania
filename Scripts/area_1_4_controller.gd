extends Node2D

@onready var player: Node2D = get_node_or_null("Player1") as Node2D
@onready var player2: Node2D = get_node_or_null("Player2") as Node2D

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -320
const LIMIT_RIGHT: int = 5000
const LIMIT_BOTTOM: int = 320

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)
const START_PLAYER2_POSITION: Vector2 = Vector2(104, 16)
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")

const COOP_CAMERA_CLOSE_ZOOM: Vector2 = Vector2(0.9, 0.9)
const COOP_CAMERA_FAR_ZOOM: Vector2 = Vector2(0.55, 0.55)
const COOP_CAMERA_CLOSE_DISTANCE: float = 140.0
const COOP_CAMERA_FAR_DISTANCE: float = 420.0
const COOP_CAMERA_FOLLOW_SPEED: float = 4.0
const COOP_CAMERA_ZOOM_SPEED: float = 2.5
const CAMERA_OFFSET: Vector2 = Vector2(0, -60)

const DUST_RUN_THRESHOLD: float = 40.0
const DUST_LIFETIME: float = 0.35
const DUST_AMOUNT: int = 8
const DUST_COLOR: Color = Color(0.55, 0.55, 0.6, 0.55)

const PREVIOUS_AREA_SCENE: String = "res://Tileset/area1/area_1_3.tscn"
const PREVIOUS_AREA_PLAYER1_POSITION: Vector2 = Vector2(4208, -256)
const PREVIOUS_AREA_PLAYER2_POSITION: Vector2 = Vector2(4160, -256)
const NEXT_AREA_SCENE: String = "res://Tileset/area1/area_1_5.tscn"
const NEXT_AREA_PLAYER1_POSITION: Vector2 = Vector2(3032, 32)
const NEXT_AREA_PLAYER2_POSITION: Vector2 = Vector2(3080, 32)
const FADE_WAIT_SECONDS: float = 0.55

const CAMERA_EVENT_FOCUS_ZOOM: Vector2 = Vector2(0.7, 0.7)
const CAMERA_EVENT_PAN_SPEED: float = 0.9

var player_camera: Camera2D = null
var _camera_local_position: Vector2 = Vector2.ZERO
var _player_dust: CPUParticles2D = null
var _player2_dust: CPUParticles2D = null
var transition_rect: ColorRect = null
var animation_player: AnimationPlayer = null
var _is_area_transitioning: bool = false

const CAMERA_RETURN_DISTANCE_THRESHOLD: float = 4.0

var _camera_event_active: bool = false
var _camera_returning: bool = false
var _camera_event_target: Vector2 = Vector2.ZERO
var _camera_event_timer: float = 0.0
var _camera_pre_event_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	_ensure_player2()
	_prepare_transition_rect()
	_connect_transition_area("transicionarea14ENTER2", _on_enter_transition_entered)
	_connect_transition_area("transicionarea14OUT2", _on_out_transition_entered)
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _process(delta: float) -> void:
	_refresh_players()
	if player == null:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_apply_area_limits()

	if _camera_event_active:
		_ensure_camera_top_level()
		_update_camera_event(delta)
	elif _camera_returning:
		_ensure_camera_top_level()
		_update_camera_return(delta)
	elif _is_coop_camera_active():
		_ensure_camera_top_level()
		_update_coop_camera(delta)
	else:
		_release_camera_top_level()

	_clamp_players_to_area()
	_update_dust_trails()

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

func focus_camera_on_point(target_position: Vector2, hold_duration: float = 3.0) -> void:
	if player_camera != null:
		_camera_pre_event_zoom = player_camera.zoom
	_camera_event_target = target_position
	_camera_event_timer = hold_duration
	_camera_event_active = true
	_camera_returning = false

func _update_camera_event(delta: float) -> void:
	var pos_weight: float = 1.0 - exp(-CAMERA_EVENT_PAN_SPEED * delta)
	player_camera.global_position = player_camera.global_position.lerp(_camera_event_target, pos_weight)
	player_camera.zoom = player_camera.zoom.lerp(CAMERA_EVENT_FOCUS_ZOOM, pos_weight)

	_camera_event_timer -= delta
	if _camera_event_timer <= 0.0:
		_camera_event_active = false
		_camera_returning = true

func _update_camera_return(delta: float) -> void:
	var target_position: Vector2 = player.global_position
	var pos_weight: float = 1.0 - exp(-CAMERA_EVENT_PAN_SPEED * delta)
	player_camera.global_position = player_camera.global_position.lerp(target_position, pos_weight)
	player_camera.zoom = player_camera.zoom.lerp(_camera_pre_event_zoom, pos_weight)

	if player_camera.global_position.distance_to(target_position) <= CAMERA_RETURN_DISTANCE_THRESHOLD:
		_camera_returning = false
		if not _is_coop_camera_active():
			_release_camera_top_level()

func _update_dust_trails() -> void:
	if _player_dust == null or not is_instance_valid(_player_dust):
		_player_dust = _get_or_create_dust_trail(player)
	if _player_dust != null:
		_player_dust.emitting = _is_running(player)

	if player2 != null and is_instance_valid(player2):
		if _player2_dust == null or not is_instance_valid(_player2_dust):
			_player2_dust = _get_or_create_dust_trail(player2)
		if _player2_dust != null:
			_player2_dust.emitting = _is_running(player2)

func _is_running(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not (target is CharacterBody2D):
		return false
	var body := target as CharacterBody2D
	return body.is_on_floor() and absf(body.velocity.x) > DUST_RUN_THRESHOLD

func _get_or_create_dust_trail(target: Node2D) -> CPUParticles2D:
	if target == null or not is_instance_valid(target):
		return null
	var existing := target.get_node_or_null("RunDustTrail") as CPUParticles2D
	if existing != null:
		return existing

	var dust := CPUParticles2D.new()
	dust.name = "RunDustTrail"
	dust.emitting = false
	dust.one_shot = false
	dust.amount = DUST_AMOUNT
	dust.lifetime = DUST_LIFETIME
	dust.explosiveness = 0.0
	dust.randomness = 0.6
	dust.direction = Vector2(0, -1)
	dust.spread = 50.0
	dust.gravity = Vector2(0, 220)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 24.0
	dust.scale_amount_min = 0.3
	dust.scale_amount_max = 0.55
	dust.color = DUST_COLOR
	target.add_child(dust)
	return dust

func _on_enter_transition_entered(body: Node2D) -> void:
	if _is_area_transitioning:
		return
	if _is_player_body(body):
		_transition_to_previous_area()

func _on_out_transition_entered(body: Node2D) -> void:
	if _is_area_transitioning:
		return
	if _is_player_body(body):
		_transition_to_next_area()

func _transition_to_previous_area() -> void:
	_is_area_transitioning = true
	await _play_fade_to_black("transicionarea14ENTER1")

	var player2_exists: bool = player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": PREVIOUS_AREA_PLAYER1_POSITION,
		"player2_exists": player2_exists,
		"player2_position": PREVIOUS_AREA_PLAYER2_POSITION,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
	get_tree().change_scene_to_file(PREVIOUS_AREA_SCENE)

func _transition_to_next_area() -> void:
	_is_area_transitioning = true
	await _play_fade_to_black("transicionarea14OUT1")

	var player2_exists: bool = player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": NEXT_AREA_PLAYER1_POSITION,
		"player2_exists": player2_exists,
		"player2_position": NEXT_AREA_PLAYER2_POSITION,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
	get_tree().change_scene_to_file(NEXT_AREA_SCENE)

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
		player_camera.zoom = COOP_CAMERA_CLOSE_ZOOM
		player_camera.offset = CAMERA_OFFSET
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
	if GameManager.current_game_mode != "coop":
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
