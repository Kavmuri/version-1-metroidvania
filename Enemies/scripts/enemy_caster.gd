extends "res://Enemies/scripts/enemy_base.gd"

@export var cast_interval: float = 2.0
@export var keep_distance: float = 190.0
var cast_timer: float = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	cast_timer -= delta
	var dist := distance_to_player()
	if dist <= detection_range:
		var dir := direction_to_player()
		facing = 1 if dir.x > 0 else -1
		sprite.flip_h = facing > 0
		if dist < keep_distance:
			velocity.x = -sign(dir.x) * move_speed
			play_first_available_anim([&"walk", &"idle"])
		else:
			velocity.x = 0
			if cast_timer <= 0.0:
				play_first_available_anim([&"attack", &"idle"])
				cast_timer = cast_interval
			else:
				play_first_available_anim([&"idle", &"walk"])
	else:
		velocity.x = 0
		play_first_available_anim([&"idle", &"walk"])
	move_and_slide()
