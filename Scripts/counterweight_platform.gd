extends AnimatableBody2D

@export var paired_platform_path: NodePath
@export var move_speed: float = 150.0
@export var max_offset: float = 100.0

@onready var _detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D

var _paired_platform: Node = null
var _initial_position: Vector2
var _target_offset: float = 0.0
var _current_offset: float = 0.0
var _players_count: int = 0

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
	if _is_player_body(body):
		_players_count += 1

func _on_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_players_count = max(_players_count - 1, 0)

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func get_players_count() -> int:
	return _players_count

func _physics_process(delta: float) -> void:
	var weight_other: int = 0
	if _paired_platform != null and is_instance_valid(_paired_platform) and _paired_platform.has_method("get_players_count"):
		weight_other = _paired_platform.get_players_count()

	var weight_difference: int = _players_count - weight_other
	_target_offset = clampf(weight_difference * 50.0, -max_offset, max_offset)
	_current_offset = lerpf(_current_offset, _target_offset, clampf(move_speed * delta / 100.0, 0.0, 1.0))
	position = _initial_position + Vector2(0.0, _current_offset)
