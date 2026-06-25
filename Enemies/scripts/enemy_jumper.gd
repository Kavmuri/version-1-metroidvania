extends "res://Enemies/scripts/enemy_base.gd"

@export var jump_velocity: float = -430.0
@export var jump_cooldown: float = 1.4
@export var horizontal_jump_speed: float = 130.0
var jump_timer: float = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	jump_timer -= delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		play_anim("idle")
		if jump_timer <= 0.0 and distance_to_player() <= detection_range:
			var dir := direction_to_player()
			velocity.x = sign(dir.x) * horizontal_jump_speed
			velocity.y = jump_velocity
			jump_timer = jump_cooldown
	else:
		play_anim("jump")
	update_facing_from_velocity()
	move_and_slide()
