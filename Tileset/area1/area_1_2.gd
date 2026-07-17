extends Node2D

@onready var transition_rect: ColorRect = _find_transition_rect()
@onready var animation_player: AnimationPlayer = _find_transition_animation_player()
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
const PREVIOUS_AREA_SCENE: String = "res://Tileset/area1/Area1.tscn"
const NEXT_AREA_SCENE: String = "res://Tileset/area1/area_1_3.tscn"
const PREVIOUS_PLAYER1_POSITION: Vector2 = Vector2(1500, 122)
const PREVIOUS_PLAYER2_POSITION: Vector2 = Vector2(1548, 122)
const NEXT_PLAYER1_POSITION: Vector2 = Vector2(296, 56)
const NEXT_PLAYER2_POSITION: Vector2 = Vector2(344, 56)
const FADE_WAIT_SECONDS: float = 0.55
const HUD_SCENE: PackedScene = preload("res://UI/scenes/gameplay_hud.tscn")

const GLOW_TEXTURE: Texture2D = preload("res://Assets/Fx/light_glow.png")
const DARKNESS_COLOR: Color = Color(0.08, 0.08, 0.12, 1.0)
const PLAYER_LIGHT_COLOR: Color = Color(1.0, 0.96, 0.85, 1.0)
const PLAYER_LIGHT_ENERGY: float = 1.3
const PLAYER_LIGHT_SCALE: float = 0.7
const PLAYER_LIGHT_OFFSET: Vector2 = Vector2(0.0, -20.0)
const GLOW_LAYER_NAMES: Array[String] = ["estantes", "detalles", "detalles2"]
const GLOW_LIGHT_ENERGY: float = 0.5
const GLOW_LIGHT_SCALE: float = 3.0
const GLOW_LIGHT_X_RATIOS: Array[float] = [0.2, 0.5, 0.8]
const GLOW_PULSE_MIN_RATIO: float = 0.4
const GLOW_PULSE_SPEED: float = 1.5

const FALLING_PARTICLES_AMOUNT: int = 28
const FALLING_PARTICLES_LIFETIME: float = 10.0
const FALLING_PARTICLES_SCALE_MIN: float = 1.0
const FALLING_PARTICLES_SCALE_MAX: float = 2.1

@export var close_zoom: Vector2 = Vector2(0.85, 0.85)
@export var far_zoom: Vector2 = Vector2(0.74, 0.74)
@export var zoom_start_x: float = 256.0
@export var zoom_end_x: float = 3600.0
@export var zoom_lerp_speed: float = 1.1
@export var wide_camera_zoom: Vector2 = Vector2(0.48, 0.48)
@export var wide_camera_limit_left: int = 0
@export var wide_camera_limit_top: int = -640
@export var wide_camera_limit_right: int = 3904
@export var wide_camera_limit_bottom: int = 512

const COOP_CAMERA_CLOSE_DISTANCE: float = 140.0
const COOP_CAMERA_FAR_DISTANCE: float = 420.0
const COOP_CAMERA_FOLLOW_SPEED: float = 4.0
const COOP_CAMERA_ZOOM_SPEED: float = 2.5

var player_camera: Camera2D = null
var _is_transitioning: bool = false
var _wide_camera_active: bool = false
var _last_player_x: Dictionary = {}
var _glow_lights: Array[PointLight2D] = []
var _glow_pulse_time: float = 0.0
var _transition_area_bodies: Dictionary = {}

func _ready() -> void:
	_prepare_transition_rect()
	_ensure_player2()
	_ensure_gameplay_hud()
	_connect_transition_area("areadetransicionINICIO1_2", _on_start_transition_entered, ["areadetransicionINICIO1_5"])
	_connect_transition_area("areadetransicionFINAL1_2", _on_final_transition_entered, ["areadetransicionFINAL1_3", "TransitionTrigger"])
	_connect_camera_transition_area("transicioncamaraENTER", _on_camera_enter_transition)
	_connect_camera_transition_area("transicioncamaraOUT", _on_camera_out_transition)
	_apply_darkness_effect()
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _ensure_gameplay_hud() -> Node:
	var hud: Node = get_node_or_null("GameplayHUD")
	if hud != null:
		return hud
	hud = HUD_SCENE.instantiate()
	hud.name = "GameplayHUD"
	add_child(hud)
	hud.visible = true
	var top_bar: Node = hud.get_node_or_null("TopBar")
	if top_bar != null:
		top_bar.visible = false
	return hud

func _apply_darkness_effect() -> void:
	var darkness := CanvasModulate.new()
	darkness.name = "Darkness"
	darkness.color = DARKNESS_COLOR
	add_child(darkness)

	_add_player_light(player)
	_add_player_light(player2)

	for layer_name in GLOW_LAYER_NAMES:
		var layer: Node = get_node_or_null(layer_name)
		if layer != null:
			_add_glow_lights(layer)

	_add_falling_particles()

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

func _add_glow_lights(layer: Node) -> void:
	if layer.has_node("GlowLight0"):
		return
	var mid_y: float = (LIMIT_TOP + LIMIT_BOTTOM) / 2.0
	for i in GLOW_LIGHT_X_RATIOS.size():
		var light := PointLight2D.new()
		light.name = "GlowLight%d" % i
		light.texture = GLOW_TEXTURE
		light.color = Color(1.0, 1.0, 1.0, 1.0)
		light.energy = GLOW_LIGHT_ENERGY
		light.texture_scale = GLOW_LIGHT_SCALE
		light.position = Vector2(lerpf(LIMIT_LEFT, LIMIT_RIGHT, GLOW_LIGHT_X_RATIOS[i]), mid_y)
		layer.add_child(light)
		_glow_lights.append(light)

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
	particles.scale_amount_min = FALLING_PARTICLES_SCALE_MIN
	particles.scale_amount_max = FALLING_PARTICLES_SCALE_MAX
	particles.color = Color(1.0, 1.0, 1.0, 0.75)
	add_child(particles)

func _process(delta: float) -> void:
	_update_glow_pulse(delta)

	_refresh_players()
	if player == null:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_apply_area_limits()

	_clamp_players_to_area()

	if _is_coop_camera_active():
		player_camera.top_level = true
		_update_coop_camera(delta)
	else:
		if player_camera.top_level:
			player_camera.top_level = false
		_update_camera_zoom(delta)

	_remember_player_positions()

func _is_coop_camera_active() -> bool:
	return GameManager.current_game_mode == "coop" and player2 != null and is_instance_valid(player2)

func _update_coop_camera(delta: float) -> void:
	var target_position: Vector2 = (player.global_position + player2.global_position) * 0.5
	var distance: float = player.global_position.distance_to(player2.global_position)
	var t: float = clampf(inverse_lerp(COOP_CAMERA_CLOSE_DISTANCE, COOP_CAMERA_FAR_DISTANCE, distance), 0.0, 1.0)
	var target_zoom: Vector2 = close_zoom.lerp(wide_camera_zoom, t)
	if _wide_camera_active and target_zoom.x > wide_camera_zoom.x:
		target_zoom = wide_camera_zoom

	var pos_weight: float = 1.0 - exp(-COOP_CAMERA_FOLLOW_SPEED * delta)
	var zoom_weight: float = 1.0 - exp(-COOP_CAMERA_ZOOM_SPEED * delta)
	player_camera.global_position = player_camera.global_position.lerp(target_position, pos_weight)
	player_camera.zoom = player_camera.zoom.lerp(target_zoom, zoom_weight)

func _update_glow_pulse(delta: float) -> void:
	if _glow_lights.is_empty():
		return
	_glow_pulse_time += delta
	var pulse: float = (sin(_glow_pulse_time * GLOW_PULSE_SPEED) * 0.5) + 0.5
	var factor: float = lerpf(GLOW_PULSE_MIN_RATIO, 1.0, pulse)
	for light in _glow_lights:
		if is_instance_valid(light):
			light.energy = GLOW_LIGHT_ENERGY * factor

func _on_start_transition_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_area(PREVIOUS_AREA_SCENE, PREVIOUS_PLAYER1_POSITION, PREVIOUS_PLAYER2_POSITION)

func _on_final_transition_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
	if _is_player_body(body):
		_transition_to_area(NEXT_AREA_SCENE, NEXT_PLAYER1_POSITION, NEXT_PLAYER2_POSITION)

func _transition_to_area(scene_path: String, player1_position: Vector2, player2_position: Vector2) -> void:
	_is_transitioning = true
	await _play_fade_to_black()

	var player2_exists: bool = player2 != null and is_instance_valid(player2)
	GameManager.pending_load_data = {
		"player1_position": player1_position,
		"player2_exists": player2_exists,
		"player2_position": player2_position,
		"game_mode": "coop" if player2_exists else GameManager.current_game_mode
	}
	GameManager.current_game_mode = "coop" if player2_exists else GameManager.current_game_mode
	get_tree().change_scene_to_file(scene_path)

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

func _play_fade_to_black() -> void:
	_prepare_transition_rect()
	await get_tree().process_frame

	if animation_player != null and animation_player.has_animation("fade_to_black"):
		animation_player.play("fade_to_black")
	else:
		var tween: Tween = create_tween()
		tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), FADE_WAIT_SECONDS)

	await get_tree().create_timer(FADE_WAIT_SECONDS).timeout
	transition_rect.color = Color(0, 0, 0, 1)

func _is_player_body(body: Node2D) -> bool:
	if body == null:
		return false
	return body.name.begins_with("Player") or body.is_in_group(&"Player") or body.is_in_group(&"player")

func _on_camera_enter_transition(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	if _get_player_direction_x(body) >= 0.0:
		_set_wide_camera_active(true)
	else:
		_set_wide_camera_active(false)

func _on_camera_out_transition(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	if _get_player_direction_x(body) >= 0.0:
		_set_wide_camera_active(false)
	else:
		_set_wide_camera_active(true)

func _connect_camera_transition_area(area_name: String, callback: Callable) -> void:
	var transition_area: Area2D = _find_area2d_by_name(area_name)
	if transition_area == null:
		push_warning("No se encontro el area de camara: " + area_name)
		return

	if not transition_area.body_entered.is_connected(callback):
		transition_area.body_entered.connect(callback)

func _set_wide_camera_active(is_active: bool) -> void:
	_wide_camera_active = is_active
	if player_camera == null or not is_instance_valid(player_camera):
		player_camera = _find_player_camera()
	if player_camera == null:
		return

	if _wide_camera_active:
		_configure_camera_wide_limits(player_camera)
	else:
		_configure_camera_limits(player_camera)

func _get_player_direction_x(body: Node2D) -> float:
	if body is CharacterBody2D:
		var character_body: CharacterBody2D = body as CharacterBody2D
		if not is_zero_approx(character_body.velocity.x):
			return character_body.velocity.x

	var body_id: int = body.get_instance_id()
	if _last_player_x.has(body_id):
		return body.global_position.x - float(_last_player_x[body_id])
	return 1.0

func _remember_player_positions() -> void:
	_remember_player_position(player)
	_remember_player_position(player2)

func _remember_player_position(player_node: Node2D) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	_last_player_x[player_node.get_instance_id()] = player_node.global_position.x

func _connect_transition_area(area_name: String, callback: Callable, fallback_names: Array[String]) -> void:
	var transition_area: Area2D = _find_area2d_by_name(area_name)
	if transition_area == null:
		for fallback_name in fallback_names:
			transition_area = _find_area2d_by_name(fallback_name)
			if transition_area != null:
				break

	if transition_area == null:
		push_warning("No se encontro el area de transicion: " + area_name)
		return

	_transition_area_bodies[area_name] = []
	var entered_callable: Callable = Callable(self, "_on_transition_area_body_entered").bind(area_name, callback)
	var exited_callable: Callable = Callable(self, "_on_transition_area_body_exited").bind(area_name)

	if not transition_area.body_entered.is_connected(entered_callable):
		transition_area.body_entered.connect(entered_callable)
	if not transition_area.body_exited.is_connected(exited_callable):
		transition_area.body_exited.connect(exited_callable)

func _on_transition_area_body_entered(body: Node2D, area_name: String, callback: Callable) -> void:
	if not _is_player_body(body):
		return
	var bodies: Array = _transition_area_bodies.get(area_name, [])
	if not bodies.has(body):
		bodies.append(body)
	_transition_area_bodies[area_name] = bodies
	if _all_required_players_present(bodies):
		callback.call(body)

func _on_transition_area_body_exited(body: Node2D, area_name: String) -> void:
	var bodies: Array = _transition_area_bodies.get(area_name, [])
	bodies.erase(body)
	_transition_area_bodies[area_name] = bodies

func _all_required_players_present(bodies: Array) -> bool:
	var valid_count: int = 0
	for b in bodies:
		if is_instance_valid(b):
			valid_count += 1
	var required: int = 2 if (GameManager.current_game_mode == "coop" and player2 != null and is_instance_valid(player2)) else 1
	return valid_count >= required

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
	if not GameManager.should_restore_player2():
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

func _configure_camera_wide_limits(camera: Camera2D) -> void:
	camera.limit_left = wide_camera_limit_left
	camera.limit_top = wide_camera_limit_top
	camera.limit_right = wide_camera_limit_right
	camera.limit_bottom = wide_camera_limit_bottom

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
		if _wide_camera_active:
			_configure_camera_wide_limits(player_camera)
		else:
			_configure_camera_limits(player_camera)

	if _wide_camera_active:
		var wide_lerp_weight: float = clampf(delta * zoom_lerp_speed, 0.0, 1.0)
		player_camera.zoom = player_camera.zoom.lerp(wide_camera_zoom, wide_lerp_weight)
		return

	var progress: float = inverse_lerp(zoom_start_x, zoom_end_x, player.global_position.x)
	progress = clampf(progress, 0.0, 1.0)

	var target_zoom: Vector2 = close_zoom.lerp(far_zoom, progress)
	var lerp_weight: float = clampf(delta * zoom_lerp_speed, 0.0, 1.0)
	player_camera.zoom = player_camera.zoom.lerp(target_zoom, lerp_weight)
