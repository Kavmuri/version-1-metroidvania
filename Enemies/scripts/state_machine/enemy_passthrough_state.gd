extends "res://Enemies/scripts/state_machine/enemy_node_state.gd"

@export var animation_names: Array[StringName] = []

func enter() -> void:
	if enemy != null and not animation_names.is_empty() and enemy.has_method("play_first_available_anim"):
		enemy.play_first_available_anim(animation_names)
