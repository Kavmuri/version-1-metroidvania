class_name SingleRunDirector
extends RefCounted

var _rooms: Array[String] = []
var _seed_value: int = 0
var _duration_seconds: float = 60.0
var _time_left: float = 60.0
var _visit_index: int = 0
var _last_room: String = ""
var _active: bool = false


func _init(room_paths: Array[String], seed_value: int, duration_seconds: float = 60.0) -> void:
	_rooms = room_paths.duplicate()
	_seed_value = seed_value
	_duration_seconds = maxf(duration_seconds, 0.0)
	_time_left = _duration_seconds


func begin_run() -> void:
	_time_left = _duration_seconds
	_visit_index = 0
	_last_room = ""
	_active = _time_left > 0.0


func pick_next_room(current_room: String = "") -> String:
	if _rooms.is_empty():
		return ""
	var blocked_room := current_room if not current_room.is_empty() else _last_room
	var candidates: Array[String] = []
	for room_path in _rooms:
		if room_path != blocked_room:
			candidates.append(room_path)
	if candidates.is_empty():
		return blocked_room if _rooms.has(blocked_room) else _rooms[0]

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + (_visit_index * 104729)
	var selected_room := candidates[rng.randi_range(0, candidates.size() - 1)]
	_last_room = selected_room
	_visit_index += 1
	return selected_room


func encounter_seed(room_path: String) -> int:
	return _seed_value + (_visit_index * 130363) + hash(room_path)


func advance_time(delta: float) -> bool:
	if not _active:
		return false
	_time_left = maxf(_time_left - maxf(delta, 0.0), 0.0)
	if _time_left > 0.0:
		return false
	_active = false
	return true


func is_active() -> bool:
	return _active


func get_time_left() -> float:
	return _time_left


func get_remaining_seconds() -> int:
	return ceili(_time_left)


func get_visit_index() -> int:
	return _visit_index
