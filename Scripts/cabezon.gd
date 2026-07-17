extends AnimatableBody2D

@export var cabezas3_path: NodePath
@export var cabezas3_paths: Array[NodePath] = []
@export var camera_focus_delay: float = 2.5
@export var camera_focus_hold_duration: float = 5.5
@export var message_pages: Array[String] = ["...", "hmmm", "Ya no habra vuelta atras."]

const INTERACT_KEY := KEY_F
const INTERACT_JOY_BUTTON := JOY_BUTTON_Y
const MESSAGE_DIALOG_SCENE := preload("res://UI/scenes/npc_message_dialog.tscn")

@onready var _prompt_panel: Control = get_node_or_null("PromptPanel") as Control
@onready var _proximity_area: Area2D = get_node_or_null("ProximityArea") as Area2D
@onready var _cabezas3_nodes: Array[Node] = _resolve_cabezas3_nodes()

var _players_in_range: int = 0
var _dialog: CanvasLayer = null

func _ready() -> void:
	if _proximity_area != null:
		_proximity_area.body_entered.connect(_on_body_entered)
		_proximity_area.body_exited.connect(_on_body_exited)
	if _prompt_panel != null:
		_prompt_panel.visible = false

func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_in_range += 1
	if _prompt_panel != null and _dialog == null:
		_prompt_panel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_in_range = max(_players_in_range - 1, 0)
	if _players_in_range == 0 and _prompt_panel != null:
		_prompt_panel.visible = false

func _is_player_body(body: Node2D) -> bool:
	return body.is_in_group(&"player") or body.is_in_group(&"Player")

func _unhandled_input(event: InputEvent) -> void:
	if _players_in_range <= 0 or (_dialog != null and is_instance_valid(_dialog)):
		return

	var triggered := false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == INTERACT_KEY:
		triggered = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == INTERACT_JOY_BUTTON:
		triggered = true

	if triggered:
		_activate()
		get_viewport().set_input_as_handled()

func _activate() -> void:
	if _prompt_panel != null:
		_prompt_panel.visible = false
	_dialog = MESSAGE_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(_dialog)
	_dialog.closed.connect(_on_dialog_closed)
	_dialog.open_dialog(message_pages)

func _on_dialog_closed() -> void:
	_dialog = null
	if _players_in_range > 0 and _prompt_panel != null:
		_prompt_panel.visible = true
	_trigger_cabezas3_sequence()

func _resolve_cabezas3_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	if cabezas3_path != NodePath(""):
		var node: Node = get_node_or_null(cabezas3_path)
		if node != null:
			nodes.append(node)
	for path in cabezas3_paths:
		var node: Node = get_node_or_null(path)
		if node != null and not nodes.has(node):
			nodes.append(node)
	return nodes

func _trigger_cabezas3_sequence() -> void:
	if _cabezas3_nodes.is_empty():
		return
	var focus_position: Vector2 = Vector2.ZERO
	for node in _cabezas3_nodes:
		if node is Node2D:
			focus_position += (node as Node2D).global_position
	focus_position /= _cabezas3_nodes.size()

	var area: Node = get_parent()
	if area != null and area.has_method("focus_camera_on_point"):
		area.focus_camera_on_point(focus_position, camera_focus_hold_duration)
	if camera_focus_delay > 0.0:
		await get_tree().create_timer(camera_focus_delay).timeout
	for node in _cabezas3_nodes:
		if is_instance_valid(node) and node.has_method("trigger_rise"):
			node.trigger_rise()
