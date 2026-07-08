extends "res://Enemies/scripts/enemy_base.gd"

@export var attack_range: float = 45.0
@export var attack_cooldown: float = 0.6
@export var damage_to_boss_on_death: int = 500
@export var agis_zombie_speed: float = 58.0

var boss_node: Node2D = null
var difficulty_multiplier: float = 1.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false

func _ready() -> void:
	max_health = 500
	contact_damage = 100
	move_speed = agis_zombie_speed
	super._ready()
	_find_player()

func _physics_process(delta: float) -> void:
	if is_dying:
		velocity.x = move_toward(velocity.x, 0, 10)
		move_and_slide()
		return

	super._physics_process(delta)

	_attack_timer = max(_attack_timer - delta, 0.0)
	if player == null or not is_instance_valid(player):
		_find_player()

	if player != null and is_instance_valid(player):
		var dist: float = global_position.distance_to(player.global_position)
		var dir_to_player: Vector2 = (player.global_position - global_position).normalized()

		if abs(dir_to_player.x) > 0.01:
			facing = 1 if dir_to_player.x > 0 else -1
			_update_sprite_facing()

		if not _is_attacking:
			velocity.x = dir_to_player.x * move_speed * difficulty_multiplier
			play_anim(&"zombieAGIS_Run")
			sprite.speed_scale = max(difficulty_multiplier, 0.8)

			if dist < attack_range and _attack_timer <= 0.0:
				_start_attack()
		else:
			velocity.x = dir_to_player.x * move_speed * 0.35
	else:
		velocity.x = 0
		play_anim(&"zombieAGIS_Idle")
		sprite.speed_scale = 1.0

	move_and_slide()

func _find_player() -> void:
	var closest_player: Node2D = null
	var closest_distance: float = INF
	for group_name in [&"Player", &"player", &"players"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate is Node2D and is_instance_valid(candidate):
				var distance: float = global_position.distance_to(candidate.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_player = candidate
	var scene: Node = get_tree().current_scene
	if scene == null:
		player = closest_player
		return
	for node_name in ["Player1", "Player2"]:
		var named_player: Node2D = scene.find_child(node_name, true, false) as Node2D
		if named_player != null and is_instance_valid(named_player):
			var named_distance: float = global_position.distance_to(named_player.global_position)
			if named_distance < closest_distance:
				closest_distance = named_distance
				closest_player = named_player
	player = closest_player

func _start_attack() -> void:
	_is_attacking = true
	velocity.x = 0
	if player != null and is_instance_valid(player):
		var dir_to_player: Vector2 = player.global_position - global_position
		if abs(dir_to_player.x) > 0.01:
			facing = 1 if dir_to_player.x > 0 else -1
			_update_sprite_facing()
	play_anim(&"zombieAGIS_Atack")
	sprite.speed_scale = max(difficulty_multiplier, 0.8)

	await sprite.animation_finished

	if is_dying:
		return

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
	difficulty_multiplier = clampf(multiplier, 0.85, 1.35)

func play_anim(anim_name: StringName) -> void:
	if sprite == null:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func update_facing_from_velocity() -> void:
	_update_sprite_facing()

func _update_sprite_facing() -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
