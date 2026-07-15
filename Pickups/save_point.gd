extends Area2D

@export var area_id: String = "area1"

const INTERACT_KEY := KEY_F
const INTERACT_JOY_BUTTON := JOY_BUTTON_Y
const CONFIRM_DIALOG_SCENE := preload("res://UI/scenes/save_confirm_dialog.tscn")

@onready var _prompt_panel: Control = get_node_or_null("PromptPanel") as Control

var _players_in_range: int = 0
var _dialog: CanvasLayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt_panel != null:
		_prompt_panel.visible = false

func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_players_in_range += 1
	if _prompt_panel != null:
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
	AudioManager.play_sfx(&"ui_confirm")
	_dialog = CONFIRM_DIALOG_SCENE.instantiate()
	get_tree().root.add_child(_dialog)
	_dialog.answered.connect(_on_dialog_answered)
	_dialog.open_dialog()

func _on_dialog_answered(confirmed: bool) -> void:
	if confirmed:
		GameManager.mark_area_completed(area_id)
		GameManager.save_game()
