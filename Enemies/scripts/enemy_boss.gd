extends "res://Enemies/scripts/enemy_base.gd"

@export var attack_interval: float = 2.4
@export var boss_walk_speed: float = 36.0
var attack_timer: float = 0.0

func _ready() -> void:
	max_health = max(max_health, 12)
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	attack_timer -= delta
	if distance_to_player() <= detection_range:
		var dir := direction_to_player()
		velocity.x = sign(dir.x) * boss_walk_speed
		update_facing_from_velocity()
		if attack_timer <= 0.0:
			play_anim("attack")
			attack_timer = attack_interval
		else:
			play_anim("walk")
	else:
		velocity.x = 0
		play_anim("idle")
	move_and_slide()
