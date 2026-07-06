extends "res://Enemies/scripts/enemy_base.gd"

@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var damage_to_boss_on_death: int = 500 # Agis will have a lot of HP

var boss_node: Node2D = null
var difficulty_multiplier: float = 1.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false

func _ready() -> void:
	max_health = 500
	contact_damage = 100
	super._ready()
	# Zombies should be aggressive from the start
	_find_player()

func _physics_process(delta: float) -> void:
	if is_dying:
		velocity.x = 0
		move_and_slide()
		return

	super._physics_process(delta)

	_attack_timer = max(_attack_timer - delta, 0.0)

	if player != null and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < attack_range and _attack_timer <= 0.0:
			_start_attack()
		elif not _is_attacking:
			_chase_player()
	else:
		velocity.x = 0
		play_anim(&"zombieAGIS_Idle")

	update_facing_from_velocity()
	move_and_slide()

func _chase_player() -> void:
	var dir = direction_to_player()
	var current_speed = move_speed * difficulty_multiplier
	velocity.x = dir.x * current_speed
	play_anim(&"zombieAGIS_Run")
	# Update animation speed based on difficulty
	sprite.speed_scale = difficulty_multiplier

func _start_attack() -> void:
	_is_attacking = true
	velocity.x = 0
	play_anim(&"zombieAGIS_Atack")
	_attack_timer = attack_cooldown / difficulty_multiplier

	await sprite.animation_finished
	_is_attacking = false

	# If player still in range, deal damage
	if player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) < attack_range + 10:
		_deal_contact_damage(player)

func die() -> void:
	if is_dying:
		return
	is_dying = true

	if boss_node != null and is_instance_valid(boss_node):
		if boss_node.has_method("receive_damage_from_zombie"):
			boss_node.receive_damage_from_zombie(damage_to_boss_on_death)

	_disable_damage_areas()
	play_anim(&"zombieAGIS_Died")
	await sprite.animation_finished
	queue_free()

func set_difficulty(multiplier: float) -> void:
	difficulty_multiplier = multiplier

func play_anim(anim_name: StringName) -> void:
	if sprite == null: return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
