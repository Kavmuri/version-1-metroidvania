extends CharacterBody2D

@export var fall_acceleration: float = 2400.0
@export var max_fall_speed: float = 2200.0
@export var initial_fall_velocity: float = 260.0
@export var contact_damage: int = 1
@export var tremble_amplitude: float = 1.5
@export var tremble_speed: float = 10.0
@export var resets: bool = false
@export var reset_delay: float = 4.0
@export var return_speed: float = 120.0

@onready var _trigger_area: Area2D = get_node_or_null("TriggerArea") as Area2D
@onready var _contact_area: Area2D = get_node_or_null("ContactArea") as Area2D
@onready var _impact_particles: CPUParticles2D = get_node_or_null("ImpactParticles") as CPUParticles2D

var _initial_position: Vector2
var _triggered: bool = false
var _landed: bool = false
var _returning: bool = false
var _tremble_time: float = 0.0

func _ready() -> void:
	_initial_position = position
	if _trigger_area != null:
		_trigger_area.body_entered.connect(_on_trigger_body_entered)
	if _contact_area != null:
		_contact_area.body_entered.connect(_on_contact_body_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if _triggered or not _is_player_body(body):
		return
	_triggered = true
	velocity.y = initial_fall_velocity

func _on_contact_body_entered(body: Node2D) -> void:
	if body.has_method("receive_damage"):
		body.receive_damage(contact_damage, global_position)

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func _physics_process(delta: float) -> void:
	if _returning:
		_process_return(delta)
		return

	if _landed:
		return

	if not _triggered:
		_tremble_time += delta
		var offset: float = sin(_tremble_time * tremble_speed) * tremble_amplitude
		position = _initial_position + Vector2(offset, 0.0)
		return

	velocity.y = min(velocity.y + fall_acceleration * delta, max_fall_speed)
	velocity.x = 0.0
	move_and_slide()
	if is_on_floor():
		_land()

func _land() -> void:
	_landed = true
	velocity = Vector2.ZERO
	if _impact_particles != null:
		_impact_particles.restart()
		_impact_particles.emitting = true
	if resets:
		_wait_and_return()

func _wait_and_return() -> void:
	await get_tree().create_timer(reset_delay).timeout
	_returning = true

func _process_return(delta: float) -> void:
	_tremble_time += delta
	var wobble: float = sin(_tremble_time * tremble_speed) * tremble_amplitude
	var target: Vector2 = _initial_position + Vector2(wobble, 0.0)
	position = position.move_toward(target, return_speed * delta)
	if position.distance_to(_initial_position) < 2.0:
		position = _initial_position
		_returning = false
		_landed = false
		_triggered = false
		_check_trigger_overlap()

func _check_trigger_overlap() -> void:
	if _trigger_area == null:
		return
	for body in _trigger_area.get_overlapping_bodies():
		if _is_player_body(body):
			_on_trigger_body_entered(body)
			break
