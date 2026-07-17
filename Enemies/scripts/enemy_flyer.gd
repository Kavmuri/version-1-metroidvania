extends "res://Enemies/scripts/enemy_base.gd"

@export var float_amplitude: float = 12.0
@export var float_speed: float = 2.2
@export var chase_height_offset: float = 72.0
@export var max_hover_height_multiplier: float = 0.5
@export var dive_horizontal_range: float = 36.0
@export var initial_think_time: float = 1.0
@export var attack_range: float = 54.0
@export var attack_cooldown: float = 1.2
@export var attack_hit_delay: float = 0.18
var origin_y: float
var time_alive: float = 0.0
var _think_remaining: float = 0.0
var _enemy_height: float = 32.0
var _attack_cooldown_remaining: float = 0.0
var _attack_hit_remaining: float = 0.0
var _is_attacking: bool = false
var _attack_damage_applied: bool = false

func _ready() -> void:
	uses_gravity = false
	super._ready()
	origin_y = global_position.y
	_think_remaining = initial_think_time
	_enemy_height = _estimate_enemy_height()

func _physics_process(delta: float) -> void:
	time_alive += delta
	super._physics_process(delta)
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if _think_remaining > 0.0:
		transition_state(&"IdleFloat")
		_think_remaining = max(_think_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		play_first_available_anim([&"idle", &"chase"])
	elif _is_attacking:
		transition_state(&"DiveAttack")
		_update_attack(delta)
	elif has_attack_animation() and is_player_in_attack_area() and player != null \
			and distance_to_player() <= attack_range and _attack_cooldown_remaining <= 0.0:
		_start_attack(direction_to_player())
	elif is_player_in_attack_area():
		if player != null and abs(global_position.x - player.global_position.x) <= dive_horizontal_range:
			transition_state(&"DiveAttack")
		else:
			transition_state(&"HoverChase")
		velocity = _direction_to_hover_target() * move_speed
		play_first_available_anim([&"chase", &"walk", &"idle"])
	else:
		transition_state(&"IdleFloat")
		velocity = Vector2(facing * move_speed * 0.35, sin(time_alive * float_speed) * float_amplitude)
		play_first_available_anim([&"idle", &"chase"])
	update_facing_from_velocity()
	move_and_slide()

func _start_attack(dir: Vector2) -> void:
	transition_state(&"DiveAttack")
	_is_attacking = true
	_attack_damage_applied = false
	_attack_hit_remaining = maxf(attack_hit_delay, 0.0)
	_attack_cooldown_remaining = maxf(attack_cooldown, 0.01)
	velocity = Vector2.ZERO
	if abs(dir.x) > 0.1:
		facing = 1 if dir.x > 0.0 else -1
		sprite.flip_h = facing > 0 if flip_h_when_facing_right else facing < 0
	play_first_available_anim([&"attack", &"idle"])

func _update_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	play_first_available_anim([&"attack", &"idle"])
	_attack_hit_remaining = maxf(_attack_hit_remaining - delta, 0.0)
	if not _attack_damage_applied and _attack_hit_remaining <= 0.0:
		_attack_damage_applied = true
		if player != null and distance_to_player() <= attack_range + 12.0:
			_deal_contact_damage(player)
	if not _is_attack_animation_playing():
		_is_attacking = false

func _is_attack_animation_playing() -> bool:
	if not has_attack_animation() or sprite.animation != &"attack":
		return false
	return sprite.frame < sprite.sprite_frames.get_frame_count(&"attack") - 1

func _direction_to_hover_target() -> Vector2:
	if player == null:
		return Vector2.LEFT
	var max_hover_offset: float = maxf(_enemy_height * max_hover_height_multiplier, 8.0)
	var hover_offset: float = minf(chase_height_offset, max_hover_offset)
	var target_position: Vector2 = player.global_position + Vector2(0, -hover_offset)
	if abs(global_position.x - player.global_position.x) <= dive_horizontal_range:
		target_position = player.global_position
	return global_position.direction_to(target_position)

func _estimate_enemy_height() -> float:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return 32.0
	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule != null:
		return maxf(capsule.height, capsule.radius * 2.0)
	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		return circle.radius * 2.0
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		return rectangle.size.y
	return 32.0
