extends Node

const MAIN_MENU_SCENE := "res://UI/scenes/main_menu.tscn"
const WORLD_SCENE := "res://Tileset/area1/Area1.tscn"
const SINGLE_WORLD_SCENE := "res://Levels/single/spawn/SpawnRoom.tscn"
const ENEMY_ARENA_SCENE := "res://Levels/test_levels/enemy_arena.tscn"
const DEATH_SCREEN_SCENE := preload("res://UI/Interfaz/menuMuerte/MenuMuerte.tscn")
const SAVE_PATH := "user://save_game.cfg"
const CONTROLS_PATH := "user://controls.cfg"

const DEFAULT_KEYS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"crouch": KEY_S,
	"aim_up": KEY_W,
	"dash": KEY_F,
	"attack": MOUSE_BUTTON_LEFT,
	"pause_game": KEY_ESCAPE
}

const DEFAULT_JOYPAD_BUTTONS := {
	"jump_JOY": 1,
	"attack_JOY": 2,
	"crouch_JOY": 12,
	"aim_up_JOY": 11
}

const DEFAULT_JOYPAD_MOTIONS := {
	"move_left_JOY": {"axis": 0, "value": -1.0},
	"move_right_JOY": {"axis": 0, "value": 1.0}
}

const UI_KEYS := {
	"ui_up": [KEY_W],
	"ui_down": [KEY_S],
	"ui_left": [KEY_A],
	"ui_right": [KEY_D],
	"ui_accept": [KEY_ENTER, KEY_SPACE],
	"ui_cancel": [KEY_ESCAPE]
}

const BLOCKED_GAMEPLAY_KEYS := {
	"move_left": [KEY_LEFT],
	"move_right": [KEY_RIGHT],
	"jump": [KEY_UP],
	"aim_up": [KEY_UP],
	"crouch": [KEY_DOWN]
}

var current_world: Node2D = null
var current_player1: Node2D = null
var current_player2: Node2D = null
var player1_upgrade_state: Dictionary = {}
var player2_upgrade_state: Dictionary = {}
var completed_areas: Dictionary = {}
var current_world_seed: int = 0
var current_game_mode: String = "single"
var selected_single_player: String = "player1"
var pending_load_data: Dictionary = {}
var dialogue_open: bool = false
var _death_screen: CanvasLayer = null
var _is_restoring_save := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.44, 0.12, 0.53, 1.00))
	_ensure_control_actions()
	load_controls()

func start_new_game(mode: String = "single", selected_player: String = "player1") -> void:
	get_tree().paused = false
	pending_load_data.clear()
	player1_upgrade_state.clear()
	player2_upgrade_state.clear()
	_is_restoring_save = false
	current_game_mode = mode
	selected_single_player = selected_player if selected_player in ["player1", "player2"] else "player1"
	current_world_seed = _make_seed()
	current_world = null
	current_player1 = null
	current_player2 = null
	get_tree().change_scene_to_file(_world_scene_for_mode(mode))

func continue_game() -> bool:
	var data = _read_save_data()
	if data.is_empty():
		return false

	get_tree().paused = false
	_clear_death_screen()
	pending_load_data = data
	_is_restoring_save = true
	current_game_mode = str(data.get("game_mode", "coop" if bool(data.get("player2_exists", false)) else "single"))
	selected_single_player = str(data.get("selected_single_player", "player1"))
	current_world_seed = int(data.get("world_seed", _make_seed()))
	completed_areas = data.get("completed_areas", {}) as Dictionary
	player1_upgrade_state = data.get("player1_upgrade_state", {}) as Dictionary
	player2_upgrade_state = data.get("player2_upgrade_state", {}) as Dictionary
	current_world = null
	current_player1 = null
	current_player2 = null
	var scene_path = str(data.get("scene", _world_scene_for_mode(current_game_mode)))
	if scene_path.is_empty():
		scene_path = _world_scene_for_mode(current_game_mode)
	return get_tree().change_scene_to_file(scene_path) == OK

func go_to_main_menu() -> void:
	get_tree().paused = false
	_clear_death_screen()
	pending_load_data.clear()
	current_world = null
	current_player1 = null
	current_player2 = null
	PauseManager.force_close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func open_enemy_arena() -> void:
	get_tree().paused = false
	_clear_death_screen()
	pending_load_data.clear()
	current_world = null
	current_player1 = null
	current_player2 = null
	PauseManager.force_close()
	get_tree().change_scene_to_file(ENEMY_ARENA_SCENE)

func has_save_game() -> bool:
	return not _read_save_data().is_empty()

func save_game() -> bool:
	var player1 = _resolve_player1()
	var player2 = _resolve_player2()
	var active_player: Node2D = player2 if current_game_mode == "single" and selected_single_player == "player2" else player1
	if active_player == null:
		return false

	if player1 != null and player1.has_method("get_upgrade_state"):
		player1_upgrade_state = player1.get_upgrade_state()
	if player2 != null and player2.has_method("get_upgrade_state"):
		player2_upgrade_state = player2.get_upgrade_state()

	var is_coop_save := current_game_mode == "coop" and player2 != null
	var cfg = ConfigFile.new()
	cfg.set_value("game", "scene", _current_scene_path())
	cfg.set_value("game", "game_mode", "coop" if is_coop_save else current_game_mode)
	cfg.set_value("game", "selected_single_player", selected_single_player)
	cfg.set_value("game", "world_seed", current_world_seed)
	cfg.set_value("game", "player1_position", player1.global_position if player1 != null else active_player.global_position)
	cfg.set_value("game", "player2_exists", player2 != null)
	if player2 != null:
		cfg.set_value("game", "player2_position", player2.global_position)
	cfg.set_value("game", "completed_areas", completed_areas)
	cfg.set_value("game", "player1_upgrade_state", player1_upgrade_state)
	cfg.set_value("game", "player2_upgrade_state", player2_upgrade_state)
	return cfg.save(SAVE_PATH) == OK

func mark_area_completed(area_id: String) -> void:
	completed_areas[area_id] = true

func is_area_completed(area_id: String) -> bool:
	return bool(completed_areas.get(area_id, false))

func save_initial_spawn_if_needed() -> void:
	if _is_restoring_save:
		_is_restoring_save = false
		return
	if not pending_load_data.is_empty():
		return
	save_game()

func show_death_screen() -> void:
	if _death_screen != null and is_instance_valid(_death_screen):
		return
	get_tree().paused = true
	_death_screen = DEATH_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(_death_screen)

func get_world_seed_for_generation() -> int:
	if pending_load_data.has("world_seed"):
		current_world_seed = int(pending_load_data["world_seed"])
	elif current_world_seed == 0:
		current_world_seed = _make_seed()
	return current_world_seed

func register_world(world: Node2D, seed_value: int) -> void:
	current_world = world
	current_world_seed = seed_value

func register_player1(player: Node2D) -> void:
	current_player1 = player

func register_player2(player: Node2D = null) -> void:
	current_player2 = player

func _world_scene_for_mode(mode: String) -> String:
	return SINGLE_WORLD_SCENE if mode == "single" else WORLD_SCENE

func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		return scene.scene_file_path
	return _world_scene_for_mode(current_game_mode)

func should_restore_player2() -> bool:
	if bool(pending_load_data.get("player2_exists", false)):
		return true
	return current_game_mode == "coop"

func apply_pending_positions(player1: Node2D, player2: Node2D = null) -> void:
	_restore_upgrade_state(player1, player1_upgrade_state)
	_restore_upgrade_state(player2, player2_upgrade_state)

	if pending_load_data.is_empty():
		return

	if player1 != null and pending_load_data.has("player1_position"):
		player1.global_position = pending_load_data["player1_position"]
	if player2 != null and pending_load_data.has("player2_position"):
		player2.global_position = pending_load_data["player2_position"]
	pending_load_data.clear()

func save_player_upgrade_state(player: Node) -> void:
	if player == null or not player.has_method("get_upgrade_state"):
		return
	if player.name == "Player2":
		player2_upgrade_state = player.get_upgrade_state()
	else:
		player1_upgrade_state = player.get_upgrade_state()

func _restore_upgrade_state(player: Node, state: Dictionary) -> void:
	if player != null and not state.is_empty() and player.has_method("apply_upgrade_state"):
		player.apply_upgrade_state(state)

func _clear_death_screen() -> void:
	if _death_screen != null and is_instance_valid(_death_screen):
		_death_screen.queue_free()
	_death_screen = null

func set_keyboard_action(action_name: String, physical_keycode: int) -> void:
	if not is_keyboard_action_allowed(action_name, physical_keycode):
		physical_keycode = DEFAULT_KEYS.get(action_name, physical_keycode)
	_ensure_action(action_name)
	InputMap.action_erase_events(action_name)
	if action_name == "attack":
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(action_name, mouse_event)
	else:
		var event = InputEventKey.new()
		event.physical_keycode = physical_keycode
		InputMap.action_add_event(action_name, event)
	if action_name == "pause_game":
		var joy_event = InputEventJoypadButton.new()
		joy_event.button_index = 6
		InputMap.action_add_event(action_name, joy_event)
	_apply_ui_navigation_actions()

func set_gamepad_action(action_name: String, button_index: int) -> void:
	var gamepad_action = action_name + "_JOY"
	_ensure_action(gamepad_action)
	InputMap.action_erase_events(gamepad_action)
	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = button_index
	InputMap.action_add_event(gamepad_action, joy_event)
	save_controls()

func is_keyboard_action_allowed(action_name: String, physical_keycode: int) -> bool:
	return not physical_keycode in BLOCKED_GAMEPLAY_KEYS.get(action_name, [])

func save_controls() -> void:
	var cfg = ConfigFile.new()
	for action_name in DEFAULT_KEYS.keys():
		var keycode = _first_keycode_for_action(action_name)
		if keycode != 0:
			cfg.set_value("controls", action_name, keycode)
	cfg.save(CONTROLS_PATH)

func load_controls() -> void:
	_ensure_control_actions()
	var cfg = ConfigFile.new()
	if cfg.load(CONTROLS_PATH) != OK:
		return

	for action_name in DEFAULT_KEYS.keys():
		var keycode = int(cfg.get_value("controls", action_name, 0))
		if keycode != 0:
			if not is_keyboard_action_allowed(action_name, keycode):
				keycode = DEFAULT_KEYS[action_name]
			set_keyboard_action(action_name, keycode)

func reset_controls() -> void:
	for action_name in DEFAULT_KEYS.keys():
		set_keyboard_action(action_name, DEFAULT_KEYS[action_name])
	save_controls()

func get_action_display(action_name: String) -> String:
	_ensure_action(action_name)
	var events = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Sin asignar"
	return events[0].as_text().replace(" (Physical)", "")

func _read_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return {}
	if not cfg.has_section_key("game", "world_seed"):
		return {}

	return {
		"scene": cfg.get_value("game", "scene", WORLD_SCENE),
		"game_mode": cfg.get_value("game", "game_mode", "single"),
		"selected_single_player": cfg.get_value("game", "selected_single_player", "player1"),
		"world_seed": cfg.get_value("game", "world_seed", 0),
		"player1_position": cfg.get_value("game", "player1_position", Vector2.ZERO),
		"player2_exists": cfg.get_value("game", "player2_exists", false),
		"player2_position": cfg.get_value("game", "player2_position", Vector2.ZERO),
		"completed_areas": cfg.get_value("game", "completed_areas", {}),
		"player1_upgrade_state": cfg.get_value("game", "player1_upgrade_state", {}),
		"player2_upgrade_state": cfg.get_value("game", "player2_upgrade_state", {})
	}

func _resolve_player1() -> Node2D:
	if current_player1 != null and is_instance_valid(current_player1):
		return current_player1
	current_player1 = _find_node_by_name(get_tree().current_scene, "Player1")
	return current_player1

func _resolve_player2() -> Node2D:
	if current_player2 != null and is_instance_valid(current_player2):
		return current_player2
	current_player2 = _find_node_by_name(get_tree().current_scene, "Player2")
	return current_player2

func _find_node_by_name(root: Node, node_name: String) -> Node2D:
	if root == null:
		return null
	if root.name == node_name and root is Node2D:
		return root as Node2D
	for child in root.get_children():
		var found = _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null

func _make_seed() -> int:
	return int(Time.get_ticks_usec() % 2147483647)

func _ensure_control_actions() -> void:
	for action_name in DEFAULT_KEYS.keys():
		_ensure_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			set_keyboard_action(action_name, DEFAULT_KEYS[action_name])
	for action_name in DEFAULT_JOYPAD_BUTTONS.keys():
		_ensure_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			var joy_event = InputEventJoypadButton.new()
			joy_event.button_index = DEFAULT_JOYPAD_BUTTONS[action_name]
			InputMap.action_add_event(action_name, joy_event)
	for action_name in DEFAULT_JOYPAD_MOTIONS.keys():
		_ensure_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			var motion_data: Dictionary = DEFAULT_JOYPAD_MOTIONS[action_name]
			var motion_event = InputEventJoypadMotion.new()
			motion_event.axis = int(motion_data["axis"])
			motion_event.axis_value = float(motion_data["value"])
			InputMap.action_add_event(action_name, motion_event)
	if InputMap.action_get_events("pause_game").is_empty():
		set_keyboard_action("pause_game", KEY_ESCAPE)
	_apply_ui_navigation_actions()

func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _apply_ui_navigation_actions() -> void:
	for action_name in UI_KEYS.keys():
		_ensure_action(action_name)
		InputMap.action_erase_events(action_name)
		for keycode in UI_KEYS[action_name]:
			var event = InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)

func _first_keycode_for_action(action_name: String) -> int:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return event.physical_keycode
	return 0
