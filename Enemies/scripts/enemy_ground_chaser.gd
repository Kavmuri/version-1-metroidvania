extends "res://Enemies/scripts/enemy_base.gd"

@export var idle_patrol_speed: float = 28.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var dir := Vector2(facing, 0)
	if distance_to_player() <= detection_range:
		dir = direction_to_player()
	velocity.x = dir.x * move_speed if abs(dir.x) > 0.1 else facing * idle_patrol_speed
	update_facing_from_velocity()
	play_anim("run" if abs(velocity.x) > idle_patrol_speed else "walk")
	move_and_slide()
