extends "res://Enemies/scripts/enemy_base.gd"

@export var attack_range: float = 45.0
@export var attack_cooldown: float = 0.6
@export var damage_to_boss_on_death: int = 500

var boss_node: Node2D = null
var difficulty_multiplier: float = 1.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false

func _ready() -> void:
	max_health = 500
	contact_damage = 100
	move_speed = 90.0
	super._ready()
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
		var dir_to_p = (player.global_position - global_position).normalized()

		# GIRO CORREGIDO: El sprite base mira a la DERECHA.
		# Si el jugador está a la IZQUIERDA (player.x < zombie.x), activamos flip_h.
		if sprite != null:
			sprite.flip_h = (player.global_position.x < global_position.x)

		if not _is_attacking:
			velocity.x = dir_to_p.x * move_speed * difficulty_multiplier
			play_anim(&"zombieAGIS_Run")
			sprite.speed_scale = difficulty_multiplier * 1.8 # Sigue siendo rápido

			if dist < attack_range and _attack_timer <= 0.0:
				_start_attack()
		else:
			# Seguir al jugador durante el ataque (corretear)
			velocity.x = dir_to_p.x * move_speed * 0.6
	else:
		velocity.x = 0
		play_anim(&"zombieAGIS_Idle")
		sprite.speed_scale = 1.0

	move_and_slide()

func _start_attack() -> void:
	_is_attacking = true
	play_anim(&"zombieAGIS_Atack")
	sprite.speed_scale = difficulty_multiplier * 2.5

	await sprite.animation_finished

	if is_dying: return

	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) < attack_range + 30:
			_deal_contact_damage(player)

	_is_attacking = false
	_attack_timer = attack_cooldown / difficulty_multiplier

func die() -> void:
	if is_dying:
		return
	is_dying = true

	if boss_node != null and is_instance_valid(boss_node):
		if boss_node.has_method("receive_damage_from_zombie"):
			boss_node.receive_damage_from_zombie(damage_to_boss_on_death)

	_disable_damage_areas()
	play_anim(&"zombieAGIS_Died")
	sprite.speed_scale = 1.2
	await sprite.animation_finished
	queue_free()

func set_difficulty(multiplier: float) -> void:
	difficulty_multiplier = multiplier

func play_anim(anim_name: StringName) -> void:
	if sprite == null: return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func update_facing_from_velocity() -> void:
	pass
