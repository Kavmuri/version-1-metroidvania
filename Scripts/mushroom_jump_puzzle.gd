extends Node

@export var hongo1_path: NodePath
@export var hongo2_path: NodePath
@export var crumbling_target_path: NodePath
@export var first_hongo_jumps_required: int = 2
@export var second_hongo_jumps_required: int = 3
@export var hongo_time_limit: float = 7.0

@onready var _hongo1: Node = get_node_or_null(hongo1_path)
@onready var _hongo2: Node = get_node_or_null(hongo2_path)
@onready var _crumbling_target: Node = get_node_or_null(crumbling_target_path)

var _active_hongo: Node = null
var _other_hongo: Node = null
var _phase: int = 1
var _jump_count: int = 0
var _completed: bool = false
var _sequence_token: int = 0

func _ready() -> void:
	if _hongo1 != null:
		if _hongo1.has_signal("jump_performed"):
			_hongo1.jump_performed.connect(_on_hongo1_jump)
		if _hongo1.has_signal("occupied"):
			_hongo1.occupied.connect(_on_hongo1_occupied)
	if _hongo2 != null:
		if _hongo2.has_signal("jump_performed"):
			_hongo2.jump_performed.connect(_on_hongo2_jump)
		if _hongo2.has_signal("occupied"):
			_hongo2.occupied.connect(_on_hongo2_occupied)

func _on_hongo1_occupied(_player: Node) -> void:
	_register_occupied(_hongo1, _hongo2)

func _on_hongo2_occupied(_player: Node) -> void:
	_register_occupied(_hongo2, _hongo1)

func _register_occupied(source: Node, other: Node) -> void:
	if _completed or _phase != 1 or _active_hongo != null:
		return
	_set_active_hongo(source, other)

func _on_hongo1_jump(_player: Node) -> void:
	_register_jump(_hongo1, _hongo2)

func _on_hongo2_jump(_player: Node) -> void:
	_register_jump(_hongo2, _hongo1)

func _set_active_hongo(source: Node, other: Node) -> void:
	_active_hongo = source
	_other_hongo = other
	_jump_count = 0
	if source.has_method("play_hint_flash"):
		source.play_hint_flash(first_hongo_jumps_required)
	_start_sequence_timeout()

func _register_jump(source: Node, other: Node) -> void:
	if _completed:
		return

	if _phase == 1:
		if _active_hongo == null:
			_set_active_hongo(source, other)
		elif source != _active_hongo:
			return
		_jump_count += 1
		if _jump_count >= first_hongo_jumps_required:
			_start_phase_2()
	elif _phase == 2:
		if source != _other_hongo:
			return
		_jump_count += 1
		if _jump_count >= second_hongo_jumps_required:
			_complete_puzzle()

func _start_phase_2() -> void:
	_phase = 2
	_jump_count = 0
	if _active_hongo != null and _active_hongo.has_method("stop_hint_flash"):
		_active_hongo.stop_hint_flash()
	if _other_hongo != null and _other_hongo.has_method("play_hint_flash"):
		_other_hongo.play_hint_flash(second_hongo_jumps_required)
	_start_sequence_timeout()

func _start_sequence_timeout() -> void:
	_sequence_token += 1
	var token: int = _sequence_token
	var phase_at_start: int = _phase
	get_tree().create_timer(hongo_time_limit).timeout.connect(func():
		if _phase == phase_at_start and token == _sequence_token and not _completed:
			_reset_puzzle()
	)

func _reset_puzzle() -> void:
	if _active_hongo != null and _active_hongo.has_method("stop_hint_flash"):
		_active_hongo.stop_hint_flash()
	if _other_hongo != null and _other_hongo.has_method("stop_hint_flash"):
		_other_hongo.stop_hint_flash()
	_active_hongo = null
	_other_hongo = null
	_phase = 1
	_jump_count = 0

func _complete_puzzle() -> void:
	_completed = true
	if _other_hongo != null and _other_hongo.has_method("stop_hint_flash"):
		_other_hongo.stop_hint_flash()
	if _crumbling_target != null and _crumbling_target.has_method("trigger_collapse"):
		_crumbling_target.trigger_collapse()
