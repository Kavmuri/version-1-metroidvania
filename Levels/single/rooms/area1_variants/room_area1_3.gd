extends "res://Levels/single/rooms/single_room_base.gd"

const SECTION_1_POSITION := Vector2(1888, 56)
const SECTION_2_POSITION := Vector2(2208, 56)


func _legacy_transition_names_to_keep() -> Array[StringName]:
	return [
		&"transicionarea1_3OUTseccion1_22",
		&"transicionarea1_3ENTER2seccion2",
	]


func _setup_room_mechanics() -> void:
	_connect_internal_transition(&"transicionarea1_3OUTseccion1_22", _on_section_2_entered)
	_connect_internal_transition(&"transicionarea1_3ENTER2seccion2", _on_section_1_entered)


func _connect_internal_transition(area_name: StringName, callback: Callable) -> void:
	var area := find_child(area_name, true, false) as Area2D
	if area == null:
		return
	area.monitoring = true
	area.collision_mask = 2
	if not area.body_entered.is_connected(callback):
		area.body_entered.connect(callback)


func _on_section_2_entered(body: Node2D) -> void:
	if _is_active_player(body):
		_move_player_between_sections(SECTION_2_POSITION)


func _on_section_1_entered(body: Node2D) -> void:
	if _is_active_player(body):
		_move_player_between_sections(SECTION_1_POSITION)


func _move_player_between_sections(target_position: Vector2) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_to_black()
	player.global_position = target_position
	await _fade_from_black()
	_is_transitioning = false
