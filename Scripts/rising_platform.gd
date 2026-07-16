extends AnimatableBody2D

@export var move_speed: float = 90.0
@export var max_offset: float = 180.0
@export var toggle_mode: bool = false

@onready var _top_detector: Area2D = get_node_or_null("TopDetector") as Area2D

var _initial_position: Vector2
var _current_offset: float = 0.0
var _target_offset: float = 0.0
var _players_count: int = 0
var _state: String = "bottom"

func _ready() -> void:
	sync_to_physics = true
	_initial_position = position
	if _top_detector != null:
		_top_detector.body_entered.connect(_on_body_entered)
		_top_detector.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_count += 1
	if toggle_mode:
		if _players_count == 1 and (_state == "bottom" or _state == "top"):
			if _state == "bottom":
				_state = "rising"
				_target_offset = -max_offset
			else:
				_state = "lowering"
				_target_offset = 0.0
	else:
		_target_offset = -max_offset

func _on_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_count = max(_players_count - 1, 0)
	if toggle_mode:
		if _state == "rising" and _players_count == 0:
			_state = "lowering"
			_target_offset = 0.0
	elif _players_count == 0:
		_target_offset = 0.0

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func _physics_process(delta: float) -> void:
	_current_offset = move_toward(_current_offset, _target_offset, move_speed * delta)
	position = _initial_position + Vector2(0.0, _current_offset)

	if toggle_mode:
		if _state == "rising" and is_equal_approx(_current_offset, _target_offset):
			_state = "top"
		elif _state == "lowering" and is_equal_approx(_current_offset, _target_offset):
			_state = "bottom"
