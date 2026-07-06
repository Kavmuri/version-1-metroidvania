extends Node2D

@onready var transition_rect: ColorRect = $TransitionLayer/ColorRect
@onready var animation_player: AnimationPlayer = $TransitionLayer/AnimationPlayer
@onready var player: Node2D = get_node_or_null("Player1") as Node2D
@onready var player2: Node2D = get_node_or_null("Player2") as Node2D

const LIMIT_LEFT: int = 0
const LIMIT_TOP: int = -384
const LIMIT_RIGHT: int = 4352
const LIMIT_BOTTOM: int = 512

const MAP_MIN: Vector2 = Vector2(LIMIT_LEFT, LIMIT_TOP)
const MAP_MAX: Vector2 = Vector2(LIMIT_RIGHT, LIMIT_BOTTOM)
const START_PLAYER2_POSITION: Vector2 = Vector2(344, 56)
const PLAYER2_SCENE: PackedScene = preload("res://Player2/player_2.tscn")

var player_camera: Camera2D = null

func _ready() -> void:
	transition_rect.color.a = 0
	_ensure_player2()
	$TransitionTrigger.body_entered.connect(_on_transition_trigger_entered)
	call_deferred("_apply_area_limits")
	call_deferred("_apply_pending_transition_positions")

func _process(_delta: float) -> void:
	_refresh_players()
	if player == null:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_apply_area_limits()

	_clamp_players_to_area()

func _on_transition_trigger_entered(body: Node2D) -> void:
	# Using 'Player' class name if it exists, otherwise checking for group or script
	if body.name.begins_with("Player"):
		animation_player.play("fade_to_black")

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
