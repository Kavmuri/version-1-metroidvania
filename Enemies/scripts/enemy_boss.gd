extends "res://Enemies/scripts/enemy_base.gd"

@export var attack_interval: float = 2.4
@export var attack_range: float = 120.0
@export var attack_hit_delay: float = 0.35
@export var boss_walk_speed: float = 36.0
@export var initial_think_time: float = 1.0
var attack_timer: float = 0.0
var _think_remaining: float = 0.0
var _attack_hit_remaining: float = 0.0
var _is_attacking: bool = false
var _attack_damage_applied: bool = false

func _ready() -> void:
	max_health = max(max_health, 12)
	super._ready()
	_think_remaining = initial_think_time

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	attack_timer -= delta
	if _think_remaining > 0.0:
		transition_state(&"Idle")
		_think_remaining = max(_think_remaining - delta, 0.0)
		velocity.x = 0
		play_first_available_anim([&"idle", &"walk"])
		move_and_slide()
		return
	if _is_attacking:
		transition_state(&"BossAttack")
		_update_attack(delta)
		move_and_slide()
		return
	if is_player_in_attack_area():
		transition_state(&"BossChase")
		var dir := direction_to_player()
		if has_attack_animation() and distance_to_player() <= attack_range and attack_timer <= 0.0:
			_start_attack(dir)
		else:
			velocity.x = sign(dir.x) * boss_walk_speed
			update_facing_from_velocity()
			play_first_available_anim([&"walk", &"idle"])
	else:
		transition_state(&"Idle")
		velocity.x = 0
		play_first_available_anim([&"idle", &"walk"])
	move_and_slide()

func _start_attack(dir: Vector2) -> void:
	transition_state(&"BossAttack")
	_is_attacking = true
	_attack_damage_applied = false
	_attack_hit_remaining = maxf(attack_hit_delay, 0.0)
	attack_timer = maxf(attack_interval, 0.01)
	velocity.x = 0.0
	if abs(dir.x) > 0.1:
		facing = 1 if dir.x > 0.0 else -1
		sprite.flip_h = facing > 0 if flip_h_when_facing_right else facing < 0
	play_first_available_anim([&"attack", &"idle"])

func _update_attack(delta: float) -> void:
	velocity.x = 0.0
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
