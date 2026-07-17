extends SceneTree

const SPAWN_ROOM := "res://Levels/single/spawn/SpawnRoom.tscn"
const ROOM_PATHS: Array[String] = [
	SPAWN_ROOM,
	"res://Levels/single/Tileset/area1/area_1_2.tscn",
	"res://Levels/single/Tileset/area1/area_1_3.tscn",
]

var _failures: Array[String] = []
var _game_manager: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_manager = root.get_node_or_null("GameManager")
	_check(_game_manager != null, "existe el autoload GameManager")
	if _game_manager == null:
		quit(1)
		return
	_test_invalid_single_save_recovery()
	for selected_player in ["player1", "player2"]:
		for room_path in ROOM_PATHS:
			await _load_and_check_room(room_path, selected_player)
	_test_timeout_game_over()
	_game_manager.call("register_player1", null)
	_game_manager.call("register_player2", null)
	_game_manager.call("_clear_single_run")
	if current_scene != null:
		current_scene.queue_free()
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null:
		for child in audio_manager.get_children():
			if child is AudioStreamPlayer:
				(child as AudioStreamPlayer).stop()
				(child as AudioStreamPlayer).stream = null
	await process_frame
	await create_timer(0.25).timeout

	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
		return
	print("RESULT: FAIL (", _failures.size(), ")")
	quit(1)


func _load_and_check_room(room_path: String, selected_player: String) -> void:
	_game_manager.set("current_game_mode", "single")
	_game_manager.set("selected_single_player", selected_player)
	_game_manager.set("current_world_seed", 4242)
	(_game_manager.get("pending_load_data") as Dictionary).clear()
	_game_manager.call("_clear_single_run")
	if room_path == SPAWN_ROOM:
		_game_manager.set("_is_restoring_save", true)
	if room_path != SPAWN_ROOM:
		_game_manager.call("begin_single_run")

	var change_error := change_scene_to_file(room_path)
	_check(change_error == OK, "carga %s" % room_path)
	if change_error != OK:
		return
	await scene_changed
	await process_frame
	await process_frame

	var expected_name := "Player2" if selected_player == "player2" else "Player1"
	var unexpected_name := "Player1" if selected_player == "player2" else "Player2"
	_check(current_scene.find_child(expected_name, true, false) != null, "%s aparece en %s" % [expected_name, room_path])
	_check(current_scene.find_child(unexpected_name, true, false) == null, "%s no aparece en %s" % [unexpected_name, room_path])
	_check(current_scene.find_child("GameplayHUD", true, false) != null, "hay HUD en %s" % room_path)
	_check(current_scene.find_child("PauseMenu", true, false) != null, "hay pausa en %s" % room_path)
	if room_path == SPAWN_ROOM:
		_check(not bool(_game_manager.call("is_single_run_active")), "el reloj no corre en SpawnRoom")
	else:
		_check(bool(_game_manager.call("is_single_run_active")), "el reloj corre en %s" % room_path)


func _test_invalid_single_save_recovery() -> void:
	var has_normalizer := _game_manager.has_method("_normalize_save_data")
	_check(has_normalizer, "existe la migracion de guardados antiguos")
	if not has_normalizer:
		return
	var stale_save := {
		"scene": "res://Levels/single/world_procedural.tscn",
		"game_mode": "single",
		"selected_single_player": "player1",
		"world_seed": 1193047,
		"player1_position": Vector2(40, -232),
		"player2_exists": false,
		"player1_upgrade_state": {"double_jump": true},
	}
	var migrated := _game_manager.call("_normalize_save_data", stale_save) as Dictionary
	_check(str(migrated.get("scene", "")) == SPAWN_ROOM, "el guardado obsoleto vuelve a SpawnRoom")
	_check(not migrated.has("player1_position"), "descarta la posicion de la escena inexistente")
	_check((migrated.get("player1_upgrade_state", {}) as Dictionary).is_empty(), "reinicia las mejoras del guardado incompatible")
	var procedural_save := stale_save.duplicate(true)
	procedural_save["scene"] = "res://Levels/world_procedural.tscn"
	var migrated_procedural := _game_manager.call("_normalize_save_data", procedural_save) as Dictionary
	_check(str(migrated_procedural.get("scene", "")) == SPAWN_ROOM, "world_procedural queda fuera del single aunque exista")


func _test_timeout_game_over() -> void:
	var active_player := current_scene.find_child("Player2", true, false)
	_check(active_player != null, "hay personaje activo para probar el fin del tiempo")
	if active_player == null:
		return
	var health_before := int(active_player.get("health"))
	var hearts_before := int(active_player.get("hearts"))
	_game_manager.call("_process", 60.0)
	_check(int(active_player.get("health")) == health_before and int(active_player.get("hearts")) == hearts_before, "el tiempo agotado no mata al personaje")
	var game_over := root.find_child("SingleGameOver", true, false)
	_check(game_over != null, "el tiempo agotado abre su propia pantalla")
	_check(root.find_child("MenuMuerte", true, false) == null, "no usa la pantalla de muerte")
	_check(paused, "la pantalla de tiempo agotado pausa la partida")
	if game_over != null:
		var title := game_over.find_child("Title", true, false) as Label
		var score := game_over.find_child("Score", true, false) as Label
		_check(title != null and title.text == "TIEMPO AGOTADO", "muestra el motivo del fin de la partida")
		_check(score != null and score.text.contains("Salas completadas"), "muestra el resultado para intentar superarlo")
		_check(game_over.find_child("Retry", true, false) != null, "ofrece reintentar la partida")
		_check(game_over.find_child("MainMenu", true, false) != null, "ofrece volver al menu principal")
	_game_manager.call("_clear_single_game_over")
	paused = false
	active_player.call("force_death")
	_check(root.find_child("MenuMuerte", true, false) != null, "la muerte normal conserva su pantalla")
	_game_manager.call("_clear_death_screen")
	paused = false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: " + message)
