extends "res://Enemies/scripts/enemy_base.gd"

@export var patrol_points: Node
@export var idle_patrol_speed: float = 28.0
@export var patrol_wait_time: float = 1.0

var _patrol_timer: Timer
var _patrol_positions: Array[Vector2] = []
var _patrol_target_index: int = 0
var _waiting_for_patrol: bool = false
var _is_chasing_player: bool = false

func _ready() -> void:
	super._ready()
	_load_patrol_points()
	_patrol_timer = Timer.new()
	_patrol_timer.one_shot = true
	_patrol_timer.timeout.connect(_on_patrol_timer_timeout)
	add_child(_patrol_timer)
	_enter_patrol_wait()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if distance_to_player() <= detection_range:
		_chase_player()
	else:
		if _is_chasing_player:
			_is_chasing_player = false
			_enter_patrol_wait()
		_update_patrol(delta)

	update_facing_from_velocity()
	if _waiting_for_patrol:
		play_first_available_anim([&"idle", &"walk"])
	elif abs(velocity.x) > idle_patrol_speed:
		play_first_available_anim([&"run", &"walk", &"idle"])
	else:
		play_first_available_anim([&"walk", &"idle"])
	move_and_slide()

func _load_patrol_points() -> void:
	_patrol_positions.clear()
	if patrol_points == null:
		return
	for point in patrol_points.get_children():
		if point is Node2D:
			_patrol_positions.append((point as Node2D).global_position)

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
		velocity.x = facing * idle_patrol_speed
		return

	var target := _patrol_positions[_patrol_target_index]
	var distance_x := target.x - global_position.x
	if abs(distance_x) <= 2.0:
		_patrol_target_index = (_patrol_target_index + 1) % _patrol_positions.size()
		_enter_patrol_wait()
		return

	velocity.x = sign(distance_x) * idle_patrol_speed

func _enter_patrol_wait() -> void:
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
