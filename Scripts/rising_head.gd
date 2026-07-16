extends AnimatableBody2D

@export var contact_damage: int = 1
@export var rise_distance: float = 180.0
@export var move_speed: float = 70.0
@export var hold_duration: float = 7.0

@onready var _contact_area: Area2D = get_node_or_null("ContactArea") as Area2D

var _initial_position: Vector2
var _target_offset: float = 0.0
var _current_offset: float = 0.0
var _state: String = "idle"
var _hold_timer: float = 0.0

func _ready() -> void:
	sync_to_physics = true
	_initial_position = position
	if _contact_area != null:
		_contact_area.body_entered.connect(_on_contact_body_entered)

func trigger_rise() -> void:
	if _state != "idle":
		return
	_state = "rising"
	_target_offset = -rise_distance

func _physics_process(delta: float) -> void:
	match _state:
		"rising":
			_current_offset = move_toward(_current_offset, _target_offset, move_speed * delta)
			position = _initial_position + Vector2(0, _current_offset)
			if is_equal_approx(_current_offset, _target_offset):
				_state = "holding"
				_hold_timer = hold_duration
		"holding":
			_hold_timer -= delta
			if _hold_timer <= 0.0:
				_state = "returning"
				_target_offset = 0.0
		"returning":
			_current_offset = move_toward(_current_offset, _target_offset, move_speed * delta)
			position = _initial_position + Vector2(0, _current_offset)
			if is_equal_approx(_current_offset, _target_offset):
				_state = "idle"

func _on_contact_body_entered(body: Node2D) -> void:
	if body.has_method("receive_damage"):
		body.receive_damage(contact_damage, global_position)
