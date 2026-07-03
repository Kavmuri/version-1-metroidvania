extends "res://Enemies/scripts/enemy_base.gd"

@export var float_amplitude: float = 12.0
@export var float_speed: float = 2.2
@export var chase_height_offset: float = 72.0
@export var dive_horizontal_range: float = 36.0
@export var initial_think_time: float = 1.0
var origin_y: float
var time_alive: float = 0.0
var _think_remaining: float = 0.0

func _ready() -> void:
	uses_gravity = false
	super._ready()
	origin_y = global_position.y
	_think_remaining = initial_think_time

func _physics_process(delta: float) -> void:
	time_alive += delta
	super._physics_process(delta)
	if _think_remaining > 0.0:
		_think_remaining = max(_think_remaining - delta, 0.0)
		velocity = Vector2.ZERO
	elif distance_to_player() <= detection_range:
		velocity = _direction_to_hover_target() * move_speed
	else:
		velocity = Vector2(facing * move_speed * 0.35, sin(time_alive * float_speed) * float_amplitude)
	update_facing_from_velocity()
	if distance_to_player() <= detection_range:
		play_first_available_anim([&"chase", &"walk", &"idle"])
	else:
		play_first_available_anim([&"idle", &"chase"])
	move_and_slide()

func _direction_to_hover_target() -> Vector2:
	if player == null:
		return Vector2.LEFT
	var target_position := player.global_position + Vector2(0, -chase_height_offset)
	if abs(global_position.x - player.global_position.x) <= dive_horizontal_range:
		target_position = player.global_position
	return global_position.direction_to(target_position)
