extends Node

@export var state_machine_path: NodePath = NodePath("../StateMachine")
@export var entered_state: StringName = &"Chase"
@export var exited_state: StringName = &"Idle"

@onready var state_machine: Node = get_node_or_null(state_machine_path)
@onready var enemy: Node = get_parent()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	if enemy != null and enemy.has_method("set_player_in_attack_area"):
		enemy.set_player_in_attack_area(true)
	if state_machine != null and state_machine.has_method("transition_to"):
		state_machine.transition_to(entered_state)

func _on_attack_area_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return

func _is_player_body(body: Node2D) -> bool:
	return body != null and (body.is_in_group(&"Player") or body.is_in_group(&"player") or body.name.begins_with("Player"))
