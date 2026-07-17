extends Node

const ENEMY_ARENA_SCENE := preload("res://Levels/test_levels/enemy_arena.tscn")
const MAIN_MENU_SCENE := preload("res://UI/scenes/main_menu.tscn")
const KAIZEN_SCENE := preload("res://Player1/player.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_game_manager_contract()
	await _test_kaizen_debug_levels()
	await _test_main_menu_shortcut()
	await _test_enemy_arena_levels()
	await _finish()


func _test_game_manager_contract() -> void:
	_check(InputMap.has_action("dash_JOY"), "Eldric puede activar el dash con gamepad")
	_check(GameManager.has_method("set_debug_arena_player"), "GameManager recibe el personaje debug")
	_check(GameManager.has_method("get_debug_arena_player"), "GameManager informa el personaje debug")
	if GameManager.has_method("set_debug_arena_player"):
		GameManager.call("set_debug_arena_player", "player2")
		_check(str(GameManager.call("get_debug_arena_player")) == "player2", "GameManager conserva a Eldric para la arena")


func _test_kaizen_debug_levels() -> void:
	var kaizen := KAIZEN_SCENE.instantiate()
	add_child(kaizen)
	await get_tree().process_frame
	_check(kaizen.has_method("set_debug_upgrade_level") and kaizen.has_method("get_upgrade_level"), "Kaizen admite niveles debug 0 a 7")
	if kaizen.has_method("set_debug_upgrade_level") and kaizen.has_method("get_upgrade_level"):
		kaizen.call("set_debug_upgrade_level", 7)
		_check(int(kaizen.call("get_upgrade_level")) == 7, "Kaizen desbloquea doble salto y seis disparos")
		_check((kaizen.get("unlocked_projectile_upgrades") as Array).size() == 6, "el nivel 7 de Kaizen contiene seis disparos")
		kaizen.call("set_debug_upgrade_level", 0)
		_check(int(kaizen.call("get_upgrade_level")) == 0, "Kaizen puede volver al nivel 0")
	kaizen.queue_free()
	await get_tree().process_frame


func _test_main_menu_shortcut() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(menu.has_method("_on_player1_debug_button_down"), "Kaizen tiene acceso debug por pulsacion larga")
	_check(menu.has_method("_on_player2_debug_button_down"), "Eldric tiene acceso debug por pulsacion larga")
	var online_button := menu.get_node("ModePanel/Content/Options/OnlineButton") as Button
	var player1_button := menu.get_node("CharacterPanel/Content/Options/Player1Button") as Button
	_check(not _signal_targets_method(online_button.button_down, "_on_online_button_down"), "Coop online deja de alojar el acceso debug")
	_check(_signal_targets_method(player1_button.button_down, "_on_player1_debug_button_down"), "el selector singleplayer aloja el acceso debug")
	menu.queue_free()
	await get_tree().process_frame


func _test_enemy_arena_levels() -> void:
	if not GameManager.has_method("set_debug_arena_player"):
		return
	GameManager.call("set_debug_arena_player", "player2")
	var arena := ENEMY_ARENA_SCENE.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	var upgrade_selector := arena.get_node_or_null("UI/Panel/Content/UpgradeSelector") as OptionButton
	_check(arena.get_node_or_null("UI/Panel/Content/PlayerSelector") == null, "enemy_arena elimina el selector de personaje")
	_check(upgrade_selector != null, "enemy_arena muestra el selector de nivel")
	if upgrade_selector != null:
		_check(upgrade_selector.item_count == 8, "el selector ofrece niveles 0 a 7")
	var eldric := arena.find_child("Eldric", true, false)
	_check(eldric != null, "enemy_arena inicia con Eldric elegido desde singleplayer")
	_check(arena.has_method("_on_upgrade_level_selected"), "enemy_arena aplica niveles debug")
	if eldric != null and arena.has_method("_on_upgrade_level_selected"):
		arena.call("_on_upgrade_level_selected", 7)
		_check(int(eldric.call("get_upgrade_level")) == 7, "el selector aplica las siete mejoras de Eldric")
		arena.call("_on_upgrade_level_selected", 0)
		_check(int(eldric.call("get_upgrade_level")) == 0, "el selector puede reiniciar las mejoras")
	arena.queue_free()
	await get_tree().process_frame


func _signal_targets_method(signal_value: Signal, method_name: String) -> bool:
	for connection in signal_value.get_connections():
		var callable := connection.get("callable") as Callable
		if callable.is_valid() and str(callable.get_method()) == method_name:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: " + message)


func _finish() -> void:
	_cleanup_audio()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	if _failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
		return
	print("RESULT: FAIL (", _failures.size(), ")")
	get_tree().quit(1)


func _cleanup_audio() -> void:
	var audio_manager := get_tree().root.get_node_or_null("AudioManager")
	if audio_manager == null:
		return
	if audio_manager.has_method("stop_music"):
		audio_manager.stop_music()
	for child in audio_manager.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
