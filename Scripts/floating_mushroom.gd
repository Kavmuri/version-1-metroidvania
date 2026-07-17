extends Node2D

@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var oscillation_amplitude: float = 6.0
@export var oscillation_speed: float = 1.6
@export var spin_speed: float = 0.8
@export var repel_radius: float = 100.0
@export var repel_force: float = 500.0
@export var max_repel_offset: float = 40.0
@export var return_speed: float = 2.5
@export var flash_blink_duration: float = 0.25

@onready var _visual: Node2D = get_node_or_null("Sprite2D") as Node2D
@onready var _detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D

var _home_position: Vector2
var _time: float = 0.0
var _repel_offset: Vector2 = Vector2.ZERO
var _nearby_players: Array[Node2D] = []
var _speed_variance: float = 1.0
var _base_modulate: Color = Color(1, 1, 1, 1)
var _flash_tween: Tween = null

func _ready() -> void:
	_home_position = position
	_time = randf_range(0.0, 100.0)
	_speed_variance = randf_range(0.85, 1.15)
	if _visual != null:
		_base_modulate = _visual.modulate
	if _detection_area != null:
		_detection_area.body_entered.connect(_on_body_entered)
		_detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if _is_player_body(body) and not _nearby_players.has(body):
		_nearby_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	_nearby_players.erase(body)

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func _process(delta: float) -> void:
	_time += delta * _speed_variance

	if _visual != null:
		_visual.rotation += spin_speed * _speed_variance * delta

	var push: Vector2 = Vector2.ZERO
	for player in _nearby_players:
		if not is_instance_valid(player):
			continue
		var away: Vector2 = global_position - player.global_position
		var dist: float = away.length()
		if dist > 0.001 and dist < repel_radius:
			push += away.normalized() * (1.0 - dist / repel_radius) * repel_force * delta

	_repel_offset = (_repel_offset + push).limit_length(max_repel_offset)
	_repel_offset = _repel_offset.lerp(Vector2.ZERO, return_speed * delta)

	var orbit_offset := Vector2(cos(_time * orbit_speed), sin(_time * orbit_speed)) * orbit_radius
	var bob_offset := Vector2(0, sin(_time * oscillation_speed) * oscillation_amplitude)

	position = _home_position + orbit_offset + bob_offset + _repel_offset

func play_flash(times: int, color: Color) -> void:
	if _visual == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_visual.modulate = _base_modulate
	_flash_tween = create_tween()
	for i in times:
		_flash_tween.tween_property(_visual, "modulate", color, flash_blink_duration)
		_flash_tween.tween_property(_visual, "modulate", _base_modulate, flash_blink_duration)
	await _flash_tween.finished
