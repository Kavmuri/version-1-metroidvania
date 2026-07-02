extends "res://Enemies/scripts/enemy_base.gd"

@export var jump_velocity: float = -430.0
@export var jump_cooldown: float = 1.4
@export var horizontal_jump_speed: float = 130.0
@export var always_run_on_ground: bool = false
@export var jump_trigger_horizontal_range: float = 115.0
@export var blocked_wait_time: float = 0.8
@export var max_consecutive_jumps: int = 0
@export var post_jump_walk_time: float = 2.0
@export var initial_think_time: float = 1.0
@export var close_attack_range: float = 62.0
@export var close_attack_cooldown: float = 1.1
@export var close_attack_hit_delay: float = 0.25
var jump_timer: float = 0.0
var _blocked_wait_remaining: float = 0.0
var _consecutive_jumps: int = 0
var _post_jump_walk_remaining: float = 0.0
var _think_remaining: float = 0.0
var _was_on_floor: bool = false
var _attack_cooldown_remaining: float = 0.0
var _attack_hit_remaining: float = 0.0
var _is_attacking: bool = false
var _attack_damage_applied: bool = false

func _ready() -> void:
	super._ready()
	_think_remaining = initial_think_time
	_was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	jump_timer -= delta
	_attack_cooldown_remaining = max(_attack_cooldown_remaining - delta, 0.0)
	_blocked_wait_remaining = max(_blocked_wait_remaining - delta, 0.0)
	_post_jump_walk_remaining = max(_post_jump_walk_remaining - delta, 0.0)
	var landed_this_frame: bool = is_on_floor() and not _was_on_floor
	if landed_this_frame:
		_think_remaining = max(_think_remaining, initial_think_time)
	if _think_remaining > 0.0:
		_think_remaining = max(_think_remaining - delta, 0.0)
		velocity.x = 0.0
		play_first_available_anim([&"idle", &"walk"])
		update_facing_from_velocity()
		move_and_slide()
		_was_on_floor = is_on_floor()
		return
	if _is_attacking:
		_update_close_attack(delta)
		update_facing_from_velocity()
		move_and_slide()
		_was_on_floor = is_on_floor()
		return
	if is_on_floor():
		var dir := direction_to_player()
		if _can_start_close_attack():
			_start_close_attack(dir)
		elif _blocked_wait_remaining > 0.0:
			velocity.x = 0.0
			play_first_available_anim([&"idle", &"walk"])
		elif always_run_on_ground and distance_to_player() <= detection_range:
			velocity.x = sign(dir.x) * move_speed
			play_first_available_anim([&"run", &"walk", &"idle"])
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
			play_first_available_anim([&"idle", &"walk"])
		if jump_timer <= 0.0 and _post_jump_walk_remaining <= 0.0 and _should_jump_at_player():
			velocity.x = sign(dir.x) * horizontal_jump_speed
			velocity.y = jump_velocity
			jump_timer = jump_cooldown
			_consecutive_jumps += 1
			if max_consecutive_jumps > 0 and _consecutive_jumps >= max_consecutive_jumps:
				_consecutive_jumps = 0
				_post_jump_walk_remaining = post_jump_walk_time
	else:
		play_first_available_anim([&"jump", &"walk", &"idle"])
	update_facing_from_velocity()
	var tried_to_move: bool = abs(velocity.x) > 0.1
	move_and_slide()
	if tried_to_move and is_on_floor() and _is_blocked_horizontally():
		_enter_blocked_wait()
	_was_on_floor = is_on_floor()

func _should_jump_at_player() -> bool:
	if player == null or distance_to_player() > detection_range:
		return false
	if not always_run_on_ground:
		return true
	return abs(player.global_position.x - global_position.x) <= jump_trigger_horizontal_range

func _can_start_close_attack() -> bool:
	if player == null or _attack_cooldown_remaining > 0.0:
		return false
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"attack"):
		return false
	return distance_to_player() <= close_attack_range

func _start_close_attack(dir: Vector2) -> void:
	_is_attacking = true
	_attack_damage_applied = false
	_attack_hit_remaining = close_attack_hit_delay
	_attack_cooldown_remaining = close_attack_cooldown
	velocity.x = 0.0
	if abs(dir.x) > 0.1:
		facing = 1 if dir.x > 0.0 else -1
		sprite.flip_h = facing > 0 if flip_h_when_facing_right else facing < 0
	play_first_available_anim([&"attack", &"idle"])

func _update_close_attack(delta: float) -> void:
	velocity.x = 0.0
	play_first_available_anim([&"attack", &"idle"])
	_attack_hit_remaining = max(_attack_hit_remaining - delta, 0.0)
	if not _attack_damage_applied and _attack_hit_remaining <= 0.0:
		_attack_damage_applied = true
		if player != null and distance_to_player() <= close_attack_range + 10.0:
			_deal_contact_damage(player)
	if not _is_attack_animation_playing():
		_is_attacking = false

func _is_attack_animation_playing() -> bool:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"attack"):
		return false
	if sprite.animation != &"attack":
		return false
	var frame_count := sprite.sprite_frames.get_frame_count(&"attack")
	return sprite.frame < frame_count - 1

func _enter_blocked_wait() -> void:
	_blocked_wait_remaining = blocked_wait_time
	velocity.x = 0.0

func _is_blocked_horizontally() -> bool:
	if not is_on_wall():
		return false
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if abs(collision.get_normal().x) > 0.6:
			return true
	return false
