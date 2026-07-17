extends "res://Enemies/scripts/enemy_base.gd"

@export var patrol_points: Node
@export var patrol_distance: float = 96.0
@export var start_facing_right: bool = false
@export var idle_patrol_speed: float = 28.0
@export var patrol_wait_time: float = 1.0
@export var melee_attack_range: float = 58.0
@export var melee_attack_cooldown: float = 1.2
@export var melee_attack_hit_delay: float = 0.35
@export var initial_think_time: float = 1.0

var _patrol_timer: Timer
var _patrol_positions: Array[Vector2] = []
var _patrol_target_index: int = 0
var _waiting_for_patrol: bool = false
var _is_chasing_player: bool = false
var _attack_cooldown_timer: float = 0.0
var _attack_hit_timer: float = 0.0
var _is_attacking: bool = false
var _attack_damage_applied: bool = false
var _think_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	# This enemy already deals damage on a timed hit-frame during its own
	# attack animation (_update_attack); disable the generic contact-damage
	# system so touching it doesn't ALSO deal damage outside of that attack.
	contact_damage_enabled = false
	if start_facing_right:
		facing = 1
		sprite.flip_h = facing > 0 if flip_h_when_facing_right else facing < 0
	_think_remaining = initial_think_time
	_load_patrol_points()
	_patrol_timer = get_node_or_null("PatrolTimer") as Timer
	if _patrol_timer == null:
		_patrol_timer = Timer.new()
		_patrol_timer.name = "PatrolTimer"
		_patrol_timer.one_shot = true
		add_child(_patrol_timer)
	if not _patrol_timer.timeout.is_connected(_on_patrol_timer_timeout):
		_patrol_timer.timeout.connect(_on_patrol_timer_timeout)
	_enter_patrol_wait()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_attack_cooldown_timer = max(_attack_cooldown_timer - delta, 0.0)

	if _think_remaining > 0.0:
		transition_state(&"Idle")
		_think_remaining = max(_think_remaining - delta, 0.0)
		velocity.x = 0.0
	elif _is_attacking:
		transition_state(&"MeleeAttack")
		_update_attack(delta)
	elif has_attack_animation() and is_player_in_attack_area() and distance_to_player() <= melee_attack_range and _attack_cooldown_timer <= 0.0:
		_start_attack()
	elif is_player_in_attack_area():
		transition_state(&"Chase")
		_chase_player()
	else:
		if _is_chasing_player:
			_is_chasing_player = false
			_enter_patrol_wait()
		transition_state(&"Patrol")
		_update_patrol(delta)

	update_facing_from_velocity()
	if _is_attacking:
		play_first_available_anim([&"attack", &"idle"])
	elif _waiting_for_patrol:
		play_first_available_anim([&"idle", &"walk"])
	elif abs(velocity.x) > idle_patrol_speed:
		play_first_available_anim([&"run", &"walk", &"idle"])
	else:
		play_first_available_anim([&"walk", &"idle"])
	move_and_slide()

func _load_patrol_points() -> void:
	_patrol_positions.clear()
	if patrol_points != null:
		for point in patrol_points.get_children():
			if point is Node2D:
				_patrol_positions.append((point as Node2D).global_position)

	if _patrol_positions.is_empty():
		var patrol_extent: float = max(patrol_distance, 8.0)
		_patrol_positions = [
			global_position + Vector2.LEFT * patrol_extent,
			global_position + Vector2.RIGHT * patrol_extent
		]

func _chase_player() -> void:
	_is_chasing_player = true
	_stop_patrol_wait()
	var dir := direction_to_player()
	velocity.x = dir.x * move_speed if abs(dir.x) > 0.1 else 0.0

func _update_patrol(_delta: float) -> void:
	if _waiting_for_patrol:
		velocity.x = 0.0
		return

	if _patrol_positions.is_empty():
		_waiting_for_patrol = true
		velocity.x = 0.0
		return

	var target := _patrol_positions[_patrol_target_index]
	var distance_x := target.x - global_position.x
	if abs(distance_x) <= 2.0:
		_patrol_target_index = (_patrol_target_index + 1) % _patrol_positions.size()
		_enter_patrol_wait()
		return

	velocity.x = sign(distance_x) * idle_patrol_speed

func _enter_patrol_wait() -> void:
	transition_state(&"Idle")
	_waiting_for_patrol = true
	velocity.x = 0.0
	if _patrol_timer != null:
		_patrol_timer.start(max(patrol_wait_time, 0.01))

func _stop_patrol_wait() -> void:
	_waiting_for_patrol = false
	if _patrol_timer != null and not _patrol_timer.is_stopped():
		_patrol_timer.stop()

func _on_patrol_timer_timeout() -> void:
	_waiting_for_patrol = false

func _start_attack() -> void:
	transition_state(&"MeleeAttack")
	_is_attacking = true
	_attack_damage_applied = false
	_attack_hit_timer = max(melee_attack_hit_delay, 0.0)
	_attack_cooldown_timer = max(melee_attack_cooldown, 0.01)
	velocity.x = 0.0
	_is_chasing_player = false
	_stop_patrol_wait()
	if player != null:
		var direction_x := player.global_position.x - global_position.x
		if abs(direction_x) > 0.1:
			facing = 1 if direction_x > 0.0 else -1
			sprite.flip_h = facing > 0
	play_first_available_anim([&"attack", &"idle"])

func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	_attack_hit_timer = max(_attack_hit_timer - delta, 0.0)
	if not _attack_damage_applied and _attack_hit_timer <= 0.0:
		_attack_damage_applied = true
		if distance_to_player() <= melee_attack_range + 10.0 and player is Node2D:
			_deal_contact_damage(player)

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"attack"):
		var attack_frame_count: float = float(sprite.sprite_frames.get_frame_count(&"attack"))
		var attack_speed: float = maxf(sprite.sprite_frames.get_animation_speed(&"attack"), 0.01)
		var attack_length: float = attack_frame_count / attack_speed
		if _attack_cooldown_timer <= max(melee_attack_cooldown - attack_length, 0.0):
			_is_attacking = false
	elif _attack_damage_applied:
		_is_attacking = false
