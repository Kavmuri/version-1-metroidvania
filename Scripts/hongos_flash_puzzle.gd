extends Node

@export var hongo17_path: NodePath
@export var hongo18_path: NodePath
@export var hongo19_path: NodePath
@export var transition_area_path: NodePath
@export var phase1_flash_times: int = 3
@export var phase2_flash_times: int = 3
@export var phase1_flash_color: Color = Color(3.2, 3.2, 3.2, 1.0)
@export var phase2_flash_color: Color = Color(5.0, 5.0, 5.0, 1.0)

const MESSAGE_DIALOG_SCENE := preload("res://UI/scenes/npc_message_dialog.tscn")
const DIALOG_TEXT: String = "Dos lados de una misma moneda, inseparables e iguales..."
const SEQUENCE_PROMPT: String = "Ingresa la secuencia..."
const INTERACT_KEY := KEY_F
const INTERACT_JOY_BUTTON := JOY_BUTTON_Y
const SEQUENCE: Array = ["down", "right", "left"]
const SEQUENCE_LABELS: Dictionary = {"down": "ABAJO", "right": "DERECHA", "left": "IZQUIERDA"}

@onready var _hongo17: Node = get_node_or_null(hongo17_path)
@onready var _hongo18: Node = get_node_or_null(hongo18_path)
@onready var _hongo19: Node = get_node_or_null(hongo19_path)
@onready var _transition_area: Area2D = get_node_or_null(transition_area_path)
@onready var _prompt_panel: Control = (_transition_area.get_node_or_null("PromptPanel") as Control) if _transition_area != null else null

var _players_in_range: int = 0
var _puzzle_solved: bool = false
var _dialog: CanvasLayer = null
var _awaiting_sequence: bool = false
var _sequence_progress: int = 0
var _entered_labels: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var area: Node = get_parent()
	if area != null and area.has_method("set_out2_locked"):
		area.set_out2_locked(true)

	if _transition_area != null:
		_transition_area.body_entered.connect(_on_transition_area_entered)
		_transition_area.body_exited.connect(_on_transition_area_exited)

	if _prompt_panel != null:
		_prompt_panel.visible = false

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func _play_phase1_sequence() -> void:
	if _hongo18 != null and _hongo18.has_method("play_flash"):
		await _hongo18.play_flash(phase1_flash_times, phase1_flash_color)
	if _hongo19 != null and _hongo19.has_method("play_flash"):
		await _hongo19.play_flash(phase1_flash_times, phase1_flash_color)
	if _hongo17 != null and _hongo17.has_method("play_flash"):
		await _hongo17.play_flash(phase1_flash_times, phase1_flash_color)

func _on_transition_area_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_in_range += 1
	if not _puzzle_solved and _prompt_panel != null and _dialog == null:
		_prompt_panel.visible = true

func _on_transition_area_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_in_range = max(_players_in_range - 1, 0)
	if _players_in_range == 0 and _prompt_panel != null:
		_prompt_panel.visible = false

func _input(event: InputEvent) -> void:
	if _puzzle_solved:
		return

	if _players_in_range > 0 and (_dialog == null or not is_instance_valid(_dialog)):
		var triggered := false
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == INTERACT_KEY:
			triggered = true
		elif event is InputEventJoypadButton and event.pressed and event.button_index == INTERACT_JOY_BUTTON:
			triggered = true

		if triggered:
			_activate_dialog()
			get_viewport().set_input_as_handled()
			return

	if _awaiting_sequence:
		_handle_sequence_input(event)

func _activate_dialog() -> void:
	if _prompt_panel != null:
		_prompt_panel.visible = false
	_dialog = MESSAGE_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(_dialog)
	_dialog.page_shown.connect(_on_dialog_page_shown)
	_dialog.closed.connect(_on_dialog_closed)
	_dialog.open_dialog([DIALOG_TEXT, SEQUENCE_PROMPT])

func _on_dialog_page_shown(index: int) -> void:
	if index != 1 or _awaiting_sequence:
		return
	_awaiting_sequence = true
	_sequence_progress = 0
	_entered_labels.clear()
	_play_phase1_sequence()

func _on_dialog_closed() -> void:
	_dialog = null
	if not _puzzle_solved:
		_awaiting_sequence = false
		_sequence_progress = 0
		_entered_labels.clear()
	if not _puzzle_solved and _players_in_range > 0 and _prompt_panel != null:
		_prompt_panel.visible = true

func _handle_sequence_input(event: InputEvent) -> void:
	var direction: String = _direction_from_event(event)
	if direction == "":
		return

	get_viewport().set_input_as_handled()
	if direction == SEQUENCE[_sequence_progress]:
		_entered_labels.append(SEQUENCE_LABELS[direction])
		_sequence_progress += 1
		_update_sequence_display()
		if _sequence_progress >= SEQUENCE.size():
			_awaiting_sequence = false
			_complete_puzzle()
	else:
		_sequence_progress = 0
		_entered_labels.clear()
		_update_sequence_display()

func _update_sequence_display() -> void:
	if _dialog == null or not is_instance_valid(_dialog):
		return
	if _entered_labels.is_empty():
		_dialog.set_text(SEQUENCE_PROMPT)
	else:
		_dialog.set_text(" > ".join(_entered_labels))

func _direction_from_event(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_DOWN:
				return "down"
			KEY_RIGHT:
				return "right"
			KEY_LEFT:
				return "left"
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_Y and event.axis_value > 0.6:
			return "down"
		if event.axis == JOY_AXIS_LEFT_X and event.axis_value > 0.6:
			return "right"
		if event.axis == JOY_AXIS_LEFT_X and event.axis_value < -0.6:
			return "left"
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_DOWN:
				return "down"
			JOY_BUTTON_DPAD_RIGHT:
				return "right"
			JOY_BUTTON_DPAD_LEFT:
				return "left"
	return ""

func _complete_puzzle() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.set_text("Correcto...")

	for hongo in [_hongo17, _hongo18, _hongo19]:
		if hongo != null and hongo.has_method("play_flash"):
			hongo.play_flash(phase2_flash_times, phase2_flash_color)
	await get_tree().create_timer(phase2_flash_times * (0.25 * 2.0) + 0.3).timeout

	if _dialog != null and is_instance_valid(_dialog):
		_dialog.force_close()

	_puzzle_solved = true
	var area: Node = get_parent()
	if area != null and area.has_method("set_out2_locked"):
		area.set_out2_locked(false)
