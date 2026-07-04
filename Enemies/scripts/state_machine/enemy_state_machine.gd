extends Node

@export var initial_state_path: NodePath

var current_state: Node
var current_state_name: StringName = &""
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child.has_method("enter") and child.has_method("exit"):
			child.set("state_machine", self)
			child.set("enemy", owner as CharacterBody2D)
			states[StringName(child.name.to_lower())] = child

	var initial_state := get_node_or_null(initial_state_path)
	if initial_state == null and not states.is_empty():
		initial_state = states.values()[0]
	if initial_state != null:
		transition_to(StringName(initial_state.name))

func _process(delta: float) -> void:
	if current_state != null:
		current_state.on_process(delta)

func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.on_physics_process(delta)

func transition_to(state_name: StringName) -> void:
	var normalized_name := StringName(String(state_name).to_lower())
	if normalized_name == current_state_name:
		return
	var new_state := states.get(normalized_name) as Node
	if new_state == null:
		return
	if current_state != null:
		current_state.exit()
	current_state = new_state
	current_state_name = normalized_name
	current_state.enter()
