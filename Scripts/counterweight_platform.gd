extends AnimatableBody2D

@export var paired_platform_path: NodePath
@export var move_speed: float = 150.0
@export var max_offset: float = 100.0
@export var rise_delay: float = 1.5

@onready var _detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D

var _paired_platform: Node = null
var _initial_position: Vector2
var _target_offset: float = 0.0
var _current_offset: float = 0.0
var _players_count: int = 0
var _state: String = "idle"
var _rise_delay_timer: float = 0.0

func _ready() -> void:
	sync_to_physics = true
	_initial_position = position

	if _detection_area != null:
		_detection_area.body_entered.connect(_on_body_entered)
		_detection_area.body_exited.connect(_on_body_exited)

	if paired_platform_path != NodePath():
		_paired_platform = get_node_or_null(paired_platform_path)
		if _paired_platform == null:
			push_warning("CounterweightPlatform: no se encontro el nodo en paired_platform_path (%s)" % str(paired_platform_path))

func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	var was_empty: bool = _players_count == 0
	_players_count += 1

	if was_empty and _state == "idle":
		_try_claim_down()

func _on_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_count = max(_players_count - 1, 0)

	if _players_count == 0:
		_maybe_reset_pair()

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func get_players_count() -> int:
	return _players_count

func get_state() -> String:
	return _state

func set_state_from_pair(new_state: String) -> void:
	if new_state == "up" and _state != "up":
		_rise_delay_timer = rise_delay
	_state = new_state

func _try_claim_down() -> void:
	if _paired_platform == null or not is_instance_valid(_paired_platform):
		return
	if _paired_platform.has_method("get_state") and _paired_platform.get_state() != "idle":
		return

	_state = "down"
	if _paired_platform.has_method("set_state_from_pair"):
		_paired_platform.set_state_from_pair("up")

func _maybe_reset_pair() -> void:
	if _paired_platform == null or not is_instance_valid(_paired_platform):
		_state = "idle"
		return

	var other_count: int = 0
	if _paired_platform.has_method("get_players_count"):
		other_count = _paired_platform.get_players_count()

	if other_count == 0:
		_state = "idle"
		if _paired_platform.has_method("set_state_from_pair"):
			_paired_platform.set_state_from_pair("idle")

func _physics_process(delta: float) -> void:
	match _state:
		"down":
			_target_offset = max_offset
		"up":
			if _rise_delay_timer > 0.0:
				_rise_delay_timer -= delta
				_target_offset = 0.0
			else:
				_target_offset = -max_offset
		_:
			_target_offset = 0.0

	_current_offset = lerpf(_current_offset, _target_offset, clampf(move_speed * delta / 100.0, 0.0, 1.0))
	position = _initial_position + Vector2(0.0, _current_offset)
