extends "res://Enemies/scripts/enemy_base.gd"

@export var attack_interval: float = 2.4
@export var boss_walk_speed: float = 36.0
@export var initial_think_time: float = 1.0
var attack_timer: float = 0.0
var _think_remaining: float = 0.0

func _ready() -> void:
	max_health = max(max_health, 12)
	super._ready()
	_think_remaining = initial_think_time

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	attack_timer -= delta
	if _think_remaining > 0.0:
		_think_remaining = max(_think_remaining - delta, 0.0)
		velocity.x = 0
		play_first_available_anim([&"idle", &"walk"])
		move_and_slide()
		return
	if distance_to_player() <= detection_range:
		var dir := direction_to_player()
		velocity.x = sign(dir.x) * boss_walk_speed
		update_facing_from_velocity()
		if attack_timer <= 0.0:
			play_first_available_anim([&"attack", &"idle"])
			attack_timer = attack_interval
		else:
			play_first_available_anim([&"walk", &"idle"])
	else:
		velocity.x = 0
		play_first_available_anim([&"idle", &"walk"])
	move_and_slide()
