extends AnimatableBody2D

@export var move_speed: float = 150.0
@export var max_offset: float = 100.0

var _paired_platform: AnimatableBody2D
var _target_offset: float = 0.0
var _current_offset: float = 0.0
var _initial_position: Vector2
var _players_on_platform: int = 0

func _ready() -> void:
	_initial_position = global_position
	_find_paired_platform()
	_setup_detection_area()

func _find_paired_platform() -> void:
	var parent = get_parent()
	if parent == null:
		return

	# Buscar la otra plataforma en el padre
	for child in parent.get_children():
		if child != self and child is AnimatableBody2D:
			_paired_platform = child
			break

	if _paired_platform == null:
		push_error("BalancedPlatform: No paired platform found!")

func _setup_detection_area() -> void:
	var area = Area2D.new()
	area.name = "DetectionArea"
	add_child(area)

	var collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		var detection_shape = CollisionShape2D.new()
		detection_shape.shape = collision_shape.shape
		area.add_child(detection_shape)

		area.body_entered.connect(_on_detection_body_entered)
		area.body_exited.connect(_on_detection_body_exited)

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_players_on_platform += 1

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_players_on_platform = max(0, _players_on_platform - 1)

func _process(delta: float) -> void:
	if _paired_platform == null:
		return

	var weight_other = 0
	if _paired_platform.has_meta("player_count"):
		weight_other = _paired_platform.get_meta("player_count")

	set_meta("player_count", _players_on_platform)

	var weight_difference = _players_on_platform - weight_other
	_target_offset = clamp(weight_difference * 50.0, -max_offset, max_offset)

	_current_offset = lerp(_current_offset, _target_offset, move_speed * delta / 100.0)
	global_position = _initial_position + Vector2(0, _current_offset)
