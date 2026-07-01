extends "res://Enemies/scripts/enemy_base.gd"

@export var float_amplitude: float = 12.0
@export var float_speed: float = 2.2
var origin_y: float
var time_alive: float = 0.0

func _ready() -> void:
	uses_gravity = false
	super._ready()
	origin_y = global_position.y

func _physics_process(delta: float) -> void:
	time_alive += delta
	super._physics_process(delta)
	var dir := direction_to_player()
	if distance_to_player() <= detection_range:
		velocity = dir * move_speed
	else:
		velocity = Vector2(facing * move_speed * 0.35, sin(time_alive * float_speed) * float_amplitude)
	update_facing_from_velocity()
	if distance_to_player() <= detection_range:
		play_first_available_anim([&"chase", &"walk", &"idle"])
	else:
		play_first_available_anim([&"idle", &"chase"])
	move_and_slide()
