extends AnimatableBody2D

var move_speed: float = 150.0
var max_offset: float = 100.0
var paired_platform: AnimatableBody2D

var _target_offset: float = 0.0
var _current_offset: float = 0.0
var _initial_position: Vector2
var _players_count: int = 0

func _ready() -> void:
	_initial_position = global_position

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_players_count += 1

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_players_count = max(0, _players_count - 1)

func _process(delta: float) -> void:
	if paired_platform == null:
		return

	var weight_other = 0
	if paired_platform.has_meta("player_count"):
		weight_other = paired_platform.get_meta("player_count")

	set_meta("player_count", _players_count)

	# Calcular desplazamiento
	var weight_difference = _players_count - weight_other
	_target_offset = clamp(weight_difference * 50.0, -max_offset, max_offset)

	# Movimiento suave
	_current_offset = lerp(_current_offset, _target_offset, move_speed * delta / 100.0)

	# Aplicar posición
	global_position = _initial_position + Vector2(0, _current_offset)
