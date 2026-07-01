extends "res://Enemies/scripts/enemy_base.gd"

@export var patrol_points: Node
@export var speed: float = 25.0
@export var wait_time: float = 3.0
@export var blocked_wait_time: float = 0.8

@onready var timer: Timer = $Timer

enum State { IDLE, WALK, CHASE }

var current_state: State = State.IDLE
var direction: Vector2 = Vector2.LEFT
var point_positions: Array[Vector2] = []
var current_point_index: int = 0
var _blocked_wait_remaining: float = 0.0

func _ready() -> void:
	_load_patrol_points()
	timer.one_shot = true
	timer.wait_time = wait_time
	super._ready()
	_enter_idle_wait()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if _blocked_wait_remaining > 0.0:
		_blocked_wait_remaining -= delta
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		if _blocked_wait_remaining <= 0.0 and distance_to_player() > detection_range:
			_enter_idle_wait()
	elif distance_to_player() <= detection_range:
		_chase_player()
	else:
		if current_state == State.CHASE:
			_enter_idle_wait()
		_update_patrol(delta)

	var tried_to_move: bool = abs(velocity.x) > 0.1
	update_facing_from_velocity()
	_play_state_animation()
	move_and_slide()
	if tried_to_move and _is_blocked_horizontally():
		_enter_blocked_wait()

func _load_patrol_points() -> void:
	point_positions.clear()
	if patrol_points == null:
		return
	for point in patrol_points.get_children():
		if point is Node2D:
			point_positions.append((point as Node2D).global_position)

func _chase_player() -> void:
	if not timer.is_stopped():
		timer.stop()
	current_state = State.CHASE
	var chase_direction := direction_to_player()
	velocity.x = sign(chase_direction.x) * move_speed

func _update_patrol(delta: float) -> void:
	if current_state == State.IDLE:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		return

	if point_positions.is_empty():
		_enter_idle_wait()
		return

	var target := point_positions[current_point_index]
	var distance_x := target.x - global_position.x
	if abs(distance_x) <= 2.0:
		current_point_index = (current_point_index + 1) % point_positions.size()
		_enter_idle_wait()
		return

	direction = Vector2.RIGHT if distance_x > 0.0 else Vector2.LEFT
	velocity.x = direction.x * speed

func _enter_idle_wait() -> void:
	current_state = State.IDLE
	if point_positions.is_empty():
		return
	if timer.is_stopped():
		timer.start(wait_time)

func _enter_blocked_wait() -> void:
	current_state = State.IDLE
	_blocked_wait_remaining = blocked_wait_time
	velocity.x = 0.0
	if not timer.is_stopped():
		timer.stop()

func _is_blocked_horizontally() -> bool:
	if not is_on_wall():
		return false
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if abs(collision.get_normal().x) > 0.6:
			return true
	return false

func _play_state_animation() -> void:
	if current_state == State.IDLE:
		play_first_available_anim([&"idle", &"walk"])
	else:
		play_first_available_anim([&"walk", &"idle"])

func _on_timer_timeout() -> void:
	if distance_to_player() <= detection_range or point_positions.is_empty():
		return
	current_state = State.WALK
