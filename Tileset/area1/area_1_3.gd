extends Node2D

@onready var transition_rect: ColorRect = _find_transition_rect()
@onready var animation_player: AnimationPlayer = _find_transition_animation_player()
@onready var player: Node2D = get_node_or_null("Player1") as Node2D
@onready var player2: Node2D = get_node_or_null("Player2") as Node2D

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -640
const LIMIT_RIGHT: int = 4352
const LIMIT_BOTTOM: int = 512
const FIRST_SECTION_CAMERA_LIMIT_NAME: String = "first_section"
const FIRST_SECTION_CAMERA_LIMIT_LEFT: int = 160
const FIRST_SECTION_CAMERA_LIMIT_TOP: int = -384
const FIRST_SECTION_CAMERA_LIMIT_RIGHT: int = 2048
const FIRST_SECTION_CAMERA_LIMIT_BOTTOM: int = 320
const SECOND_SECTION_CAMERA_LIMIT_NAME: String = "second_section"
const SECOND_SECTION_CAMERA_LIMIT_LEFT: int = 2112
const SECOND_SECTION_CAMERA_LIMIT_TOP: int = -640
const SECOND_SECTION_CAMERA_LIMIT_RIGHT: int = 4352
const SECOND_SECTION_CAMERA_LIMIT_BOTTOM: int = 320
const SECOND_SECTION_START_X: float = 2112.0

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)
const START_PLAYER2_POSITION: Vector2 = Vector2(344, 56)
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")
const PREVIOUS_AREA_SCENE: String = "res://Tileset/area1/area_1_2.tscn"
const NEXT_AREA_SCENE: String = "res://Tileset/area1/area_1_4.tscn"
const PREVIOUS_AREA_PLAYER1_POSITION: Vector2 = Vector2(3710, -94)
const PREVIOUS_AREA_PLAYER2_POSITION: Vector2 = Vector2(3662, -94)
const NEXT_AREA_PLAYER1_POSITION: Vector2 = Vector2(96, 176)
const NEXT_AREA_PLAYER2_POSITION: Vector2 = Vector2(144, 176)
const SECTION_1_PLAYER1_POSITION: Vector2 = Vector2(1888, 56)
const SECTION_1_PLAYER2_POSITION: Vector2 = Vector2(1840, 56)
const SECTION_2_PLAYER1_POSITION: Vector2 = Vector2(2208, 56)
const SECTION_2_PLAYER2_POSITION: Vector2 = Vector2(2256, 56)
const FADE_WAIT_SECONDS: float = 0.55

const GLOW_TEXTURE: Texture2D = preload("res://Assets/Fx/light_glow.png")
const DARKNESS_COLOR: Color = Color(0.08, 0.08, 0.12, 1.0)
const PLAYER_LIGHT_COLOR: Color = Color(1.0, 0.96, 0.85, 1.0)
const PLAYER_LIGHT_ENERGY: float = 1.3
const PLAYER_LIGHT_SCALE: float = 0.7
const PLAYER_LIGHT_OFFSET: Vector2 = Vector2(0.0, -20.0)

const FLOATING_PARTICLES_AMOUNT: int = 18
const FLOATING_PARTICLES_LIFETIME: float = 6.0
const FALLING_PARTICLES_AMOUNT: int = 26
const FALLING_PARTICLES_LIFETIME: float = 10.0

var player_camera: Camera2D = null
var _camera_local_position: Vector2 = Vector2.ZERO
var active_camera_limit_name: String = FIRST_SECTION_CAMERA_LIMIT_NAME
var _is_transitioning: bool = false
var normal_camera_zoom: Vector2 = Vector2(0.78, 0.78)
var gate_camera_zoom: Vector2 = Vector2(0.95, 0.95)
var gate_zoom_start_x: float = 4000.0
var gate_zoom_end_x: float = 4352.0

const CAMERA_CLOSE_ZOOM: Vector2 = Vector2(0.95, 0.95)
const CAMERA_PLATFORM_WIDE_ZOOM: Vector2 = Vector2(0.48, 0.48)
const CAMERA_ZOOM_HOLD_SECONDS: float = 6.0
const CAMERA_ZOOM_SMOOTH_SPEED: float = 0.9
const PLATFORM_PROXIMITY_RADIUS: float = 260.0
const PLATFORM_PROXIMITY_EXIT_RADIUS: float = 340.0

const COOP_CAMERA_CLOSE_DISTANCE: float = 140.0
const COOP_CAMERA_FAR_DISTANCE: float = 420.0
const COOP_CAMERA_FOLLOW_SPEED: float = 4.0
const COOP_CAMERA_ZOOM_SPEED: float = 2.5

const CAMERA_EVENT_FOCUS_ZOOM: Vector2 = Vector2(0.7, 0.7)
const CAMERA_EVENT_PAN_SPEED: float = 1.6

var _zoom_timer: float = 0.0
var _camera_focus_nodes: Array[Node2D] = []
var _near_platform_state: bool = false

var _camera_event_active: bool = false
var _camera_event_target: Vector2 = Vector2.ZERO
var _camera_event_timer: float = 0.0

func _ready() -> void:
	_prepare_transition_rect()
	_ensure_player2()
	_connect_transition_area("transicionarea1_3ENTER2seccion1", _on_section_1_enter_transition_entered)
	_connect_transition_area("transicionarea1_3OUTseccion1_22", _on_section_1_out_transition_entered)
	_connect_transition_area("transicionarea1_3ENTER2seccion2", _on_section_2_enter_transition_entered)
	_connect_transition_area("transicionarea1_3ENTER2seccion3", _on_section_3_enter_transition_entered)
	_apply_darkness_effect()
	_add_floating_particles()
	_add_falling_particles()
	_zoom_timer = 0.0
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")
	call_deferred("_gather_camera_focus_nodes")

func _gather_camera_focus_nodes() -> void:
	_camera_focus_nodes.clear()
	for child in get_children():
		if child is Node2D and ("Plataforma" in child.name or "Platform" in child.name):
			_camera_focus_nodes.append(child)

func _is_near_platform_mechanism() -> bool:
	var radius: float = PLATFORM_PROXIMITY_EXIT_RADIUS if _near_platform_state else PLATFORM_PROXIMITY_RADIUS
	var found: bool = false
	if not _camera_focus_nodes.is_empty():
		for node in _camera_focus_nodes:
			if not is_instance_valid(node):
				continue
			if player != null and player.global_position.distance_to(node.global_position) <= radius:
				found = true
				break
			if player2 != null and is_instance_valid(player2) and player2.global_position.distance_to(node.global_position) <= radius:
				found = true
				break
	_near_platform_state = found
	return found

func _apply_darkness_effect() -> void:
	var darkness := CanvasModulate.new()
	darkness.name = "Darkness"
	darkness.color = DARKNESS_COLOR
	add_child(darkness)

	_add_player_light(player)
	_add_player_light(player2)

func _add_player_light(target: Node2D) -> void:
	if target == null or target.has_node("PlayerLight"):
		return
	var light := PointLight2D.new()
	light.name = "PlayerLight"
	light.texture = GLOW_TEXTURE
	light.color = PLAYER_LIGHT_COLOR
	light.energy = PLAYER_LIGHT_ENERGY
	light.texture_scale = PLAYER_LIGHT_SCALE
	light.position = PLAYER_LIGHT_OFFSET
	target.add_child(light)

func _add_floating_particles() -> void:
	if has_node("FloatingParticles"):
		return

	var particles := CPUParticles2D.new()
	particles.name = "FloatingParticles"
	particles.position = Vector2((LIMIT_LEFT + LIMIT_RIGHT) / 2.0, (LIMIT_TOP + LIMIT_BOTTOM) / 2.0)
	particles.amount = FLOATING_PARTICLES_AMOUNT
	particles.lifetime = FLOATING_PARTICLES_LIFETIME
	particles.preprocess = FLOATING_PARTICLES_LIFETIME
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2((LIMIT_RIGHT - LIMIT_LEFT) / 2.0, (LIMIT_BOTTOM - LIMIT_TOP) / 2.0)
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 12.0
	particles.scale_amount_min = 1.6
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 1.0, 1.0, 1.0)
	particles.color_ramp = _build_fade_gradient()
	add_child(particles)

func _add_falling_particles() -> void:
	if has_node("FallingParticles"):
		return

	var particles := CPUParticles2D.new()
	particles.name = "FallingParticles"
	particles.position = Vector2((LIMIT_LEFT + LIMIT_RIGHT) / 2.0, LIMIT_TOP - 40.0)
	particles.amount = FALLING_PARTICLES_AMOUNT
	particles.lifetime = FALLING_PARTICLES_LIFETIME
	particles.preprocess = FALLING_PARTICLES_LIFETIME
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2((LIMIT_RIGHT - LIMIT_LEFT) / 2.0, 4.0)
	particles.direction = Vector2(0.0, 1.0)
	particles.spread = 4.0
	particles.gravity = Vector2(0.0, 25.0)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 1.0, 1.0, 0.75)
	add_child(particles)

func _build_fade_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.9),
		Color(1.0, 1.0, 1.0, 0.0)
	])
	return gradient

func _process(delta: float) -> void:
	_refresh_players()
	if player == null:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_apply_area_limits()

	_update_active_camera_limit()

	if _camera_event_active:
		_ensure_camera_top_level()
		_update_camera_event(delta)
	elif _is_coop_camera_active():
		_ensure_camera_top_level()
		_update_coop_camera(delta)
	else:
		_release_camera_top_level()
		_update_camera_zoom(delta)

func _release_camera_top_level() -> void:
	if not player_camera.top_level:
		return
	player_camera.top_level = false
	player_camera.position = _camera_local_position

func _ensure_camera_top_level() -> void:
	if player_camera.top_level:
		return
	var current_global: Vector2 = player_camera.global_position
	player_camera.top_level = true
	player_camera.global_position = current_global

	_clamp_players_to_area()

func _is_coop_camera_active() -> bool:
	return GameManager.current_game_mode == "coop" and player2 != null and is_instance_valid(player2)

func focus_camera_on_point(target_position: Vector2, hold_duration: float = 3.0) -> void:
	_camera_event_target = target_position
	_camera_event_timer = hold_duration
	_camera_event_active = true

func _update_camera_event(delta: float) -> void:
	var pos_weight: float = 1.0 - exp(-CAMERA_EVENT_PAN_SPEED * delta)
	player_camera.global_position = player_camera.global_position.lerp(_camera_event_target, pos_weight)
	player_camera.zoom = player_camera.zoom.lerp(CAMERA_EVENT_FOCUS_ZOOM, pos_weight)

	_camera_event_timer -= delta
	if _camera_event_timer <= 0.0:
		_camera_event_active = false

func _update_coop_camera(delta: float) -> void:
	var target_position: Vector2 = (player.global_position + player2.global_position) * 0.5
	var distance: float = player.global_position.distance_to(player2.global_position)
	var t: float = clampf(inverse_lerp(COOP_CAMERA_CLOSE_DISTANCE, COOP_CAMERA_FAR_DISTANCE, distance), 0.0, 1.0)
	var target_zoom: Vector2 = normal_camera_zoom.lerp(CAMERA_PLATFORM_WIDE_ZOOM, t)
	if _is_near_platform_mechanism() and target_zoom.x > CAMERA_PLATFORM_WIDE_ZOOM.x:
		target_zoom = CAMERA_PLATFORM_WIDE_ZOOM

	var pos_weight: float = 1.0 - exp(-COOP_CAMERA_FOLLOW_SPEED * delta)
	var zoom_weight: float = 1.0 - exp(-COOP_CAMERA_ZOOM_SPEED * delta)
	player_camera.global_position = player_camera.global_position.lerp(target_position, pos_weight)
	player_camera.zoom = player_camera.zoom.lerp(target_zoom, zoom_weight)

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

func _on_section_3_enter_transition_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_next_area()

func _transition_to_previous_area() -> void:
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3ENTERseccion1")

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
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3ENTERseccion3")

	var player2_exists: bool = player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": NEXT_AREA_PLAYER1_POSITION,
		"player2_exists": player2_exists,
		"player2_position": NEXT_AREA_PLAYER2_POSITION,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
	get_tree().change_scene_to_file(NEXT_AREA_SCENE)

func _transition_to_section_2() -> void:
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3OUTseccion1")
	_move_players_to_positions(SECTION_2_PLAYER1_POSITION, SECTION_2_PLAYER2_POSITION)
	active_camera_limit_name = SECOND_SECTION_CAMERA_LIMIT_NAME
	if player_camera != null and is_instance_valid(player_camera):
		_configure_camera_limits(player_camera)
	_zoom_timer = 0.0
	await _fade_from_black()
	_is_transitioning = false

func _transition_to_section_1() -> void:
	_is_transitioning = true
	await _play_fade_to_black("transicionarea1_3ENTERseccion2")
	_move_players_to_positions(SECTION_1_PLAYER1_POSITION, SECTION_1_PLAYER2_POSITION)
	active_camera_limit_name = FIRST_SECTION_CAMERA_LIMIT_NAME
	if player_camera != null and is_instance_valid(player_camera):
		_configure_camera_limits(player_camera)
	_zoom_timer = 0.0
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
		if not player_camera.top_level:
			_camera_local_position = player_camera.position
		player_camera.zoom = normal_camera_zoom
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

func _update_camera_zoom(delta: float) -> void:
	if player_camera == null or not is_instance_valid(player_camera):
		return

	_zoom_timer += delta

	var progress: float = inverse_lerp(gate_zoom_start_x, gate_zoom_end_x, player.global_position.x)
	progress = clampf(progress, 0.0, 1.0)
	var target_zoom: Vector2 = normal_camera_zoom.lerp(gate_camera_zoom, progress)

	if _is_near_platform_mechanism():
		target_zoom = CAMERA_PLATFORM_WIDE_ZOOM
	elif _zoom_timer < CAMERA_ZOOM_HOLD_SECONDS:
		target_zoom = CAMERA_CLOSE_ZOOM

	var weight: float = 1.0 - exp(-CAMERA_ZOOM_SMOOTH_SPEED * delta)
	player_camera.zoom = player_camera.zoom.lerp(target_zoom, weight)

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
