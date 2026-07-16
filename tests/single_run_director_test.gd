extends SceneTree

const DIRECTOR_PATH := "res://Scripts/single_run_director.gd"

var _failures: Array[String] = []


func _init() -> void:
	var director_script := load(DIRECTOR_PATH) as Script
	_check(director_script != null, "existe SingleRunDirector")
	if director_script != null:
		_test_room_selection(director_script)
		_test_timer(director_script)
	_test_encounter_selection()
	_finish()


func _test_room_selection(director_script: Script) -> void:
	var rooms: Array[String] = ["room_a", "room_b", "room_c"]
	var director = director_script.new(rooms, 1234, 60.0)
	director.begin_run()
	var current := ""
	var seen: Dictionary = {}
	for index in range(20):
		var next_room: String = director.pick_next_room(current)
		_check(rooms.has(next_room), "la sala elegida pertenece al pool")
		_check(current.is_empty() or next_room != current, "no repite inmediatamente")
		seen[next_room] = true
		current = next_room
	_check(seen.size() >= 2, "el selector usa mas de una sala")
	var first_seed: int = director.encounter_seed("room_a")
	director.pick_next_room(current)
	var second_seed: int = director.encounter_seed("room_a")
	_check(first_seed != second_seed, "cada visita cambia la semilla del encuentro")


func _test_timer(director_script: Script) -> void:
	var rooms: Array[String] = ["room_a", "room_b"]
	var director = director_script.new(rooms, 99, 60.0)
	_check(not director.is_active(), "el tiempo no corre en SpawnRoom")
	_check(not director.advance_time(10.0), "un timer inactivo no expira")
	_check(is_equal_approx(director.get_time_left(), 60.0), "conserva 60 segundos antes de salir")
	director.begin_run()
	_check(director.is_active(), "el timer comienza al salir de SpawnRoom")
	_check(not director.advance_time(59.0), "no expira antes de 60 segundos")
	_check(director.advance_time(1.0), "expira exactamente al llegar a cero")
	_check(not director.is_active(), "el timer se detiene al expirar")
	_check(is_zero_approx(director.get_time_left()), "el tiempo termina en cero")
	_check(not director.advance_time(1.0), "la expiracion solo se reporta una vez")


func _test_encounter_selection() -> void:
	var points: Array[Vector2] = []
	for index in range(8):
		points.append(Vector2(index * 32, 0))
	var selected := EnemyEncounterPool.choose_spawn_points(points, 77, 2, 5)
	_check(selected.size() >= 2 and selected.size() <= 5, "la cantidad respeta el rango configurado")
	var unique_points: Dictionary = {}
	for point in selected:
		unique_points[point] = true
	_check(unique_points.size() == selected.size(), "no reutiliza un marcador en el mismo encuentro")
	var observed_counts: Dictionary = {}
	for seed_value in range(20, 40):
		var sample := EnemyEncounterPool.choose_spawn_points(points, seed_value, 2, 5)
		observed_counts[sample.size()] = true
	_check(observed_counts.size() > 1, "semillas distintas producen cantidades distintas")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
		return
	print("RESULT: FAIL (", _failures.size(), ")")
	quit(1)
