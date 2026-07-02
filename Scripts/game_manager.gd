extends Node

const MAIN_MENU_SCENE := "res://UI/scenes/main_menu.tscn"
const WORLD_SCENE := "res://Levels/world_procedural.tscn"
const ENEMY_ARENA_SCENE := "res://Levels/test_levels/enemy_arena.tscn"
const DEATH_SCREEN_SCENE := preload("res://UI/scenes/death_screen.tscn")
const SAVE_PATH := "user://save_game.cfg"
const CONTROLS_PATH := "user://controls.cfg"

const DEFAULT_KEYS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"dash": KEY_F,
	"attack": MOUSE_BUTTON_LEFT,
	"pause_game": KEY_ESCAPE
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
	"jump": [KEY_UP]
}

var current_world: Node2D = null
var current_player1: Node2D = null
var current_player2: Node2D = null
var current_world_seed: int = 0
var current_game_mode: String = "single"
var pending_load_data: Dictionary = {}
var _death_screen: CanvasLayer = null
var _is_restoring_save := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.44, 0.12, 0.53, 1.00))
	_ensure_control_actions()
	load_controls()

func start_new_game(mode: String = "single") -> void:
	get_tree().paused = false
	pending_load_data.clear()
	_is_restoring_save = false
	current_game_mode = mode
	current_world_seed = _make_seed()
	current_world = null
	current_player1 = null
	current_player2 = null
	get_tree().change_scene_to_file(WORLD_SCENE)

func continue_game() -> bool:
	var data = _read_save_data()
	if data.is_empty():
		return false

	get_tree().paused = false
	_clear_death_screen()
	pending_load_data = data
	_is_restoring_save = true
	current_game_mode = str(data.get("game_mode", "coop" if bool(data.get("player2_exists", false)) else "single"))
	current_world_seed = int(data.get("world_seed", _make_seed()))
	current_world = null
	current_player1 = null
	current_player2 = null
	var scene_path = str(data.get("scene", WORLD_SCENE))
	if scene_path.is_empty():
		scene_path = WORLD_SCENE
	return get_tree().change_scene_to_file(scene_path) == OK

func go_to_main_menu() -> void:
	get_tree().paused = false
	_clear_death_screen()
	pending_load_data.clear()
	current_world = null
	current_player1 = null
	current_player2 = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func open_enemy_arena() -> void:
	get_tree().paused = false
	_clear_death_screen()
	pending_load_data.clear()
	current_world = null
	current_player1 = null
	current_player2 = null
	get_tree().change_scene_to_file(ENEMY_ARENA_SCENE)

func has_save_game() -> bool:
	return not _read_save_data().is_empty()

func save_game() -> bool:
	var player1 = _resolve_player1()
	if player1 == null:
		return false

	var player2 = _resolve_player2()
	var cfg = ConfigFile.new()
	cfg.set_value("game", "scene", WORLD_SCENE)
	cfg.set_value("game", "game_mode", "coop" if player2 != null else current_game_mode)
	cfg.set_value("game", "world_seed", current_world_seed)
	cfg.set_value("game", "player1_position", player1.global_position)
	cfg.set_value("game", "player2_exists", player2 != null)
	if player2 != null:
		cfg.set_value("game", "player2_position", player2.global_position)
	return cfg.save(SAVE_PATH) == OK

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
	_death_screen.continue_requested.connect(_on_death_continue_requested)
	_death_screen.exit_requested.connect(_on_death_exit_requested)

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

func should_restore_player2() -> bool:
	if bool(pending_load_data.get("player2_exists", false)):
		return true
	return current_game_mode == "coop"

func apply_pending_positions(player1: Node2D, player2: Node2D = null) -> void:
	if pending_load_data.is_empty():
		return

	if player1 != null and pending_load_data.has("player1_position"):
		player1.global_position = pending_load_data["player1_position"]
	if player2 != null and pending_load_data.has("player2_position"):
		player2.global_position = pending_load_data["player2_position"]
	pending_load_data.clear()

func _on_death_continue_requested() -> void:
	continue_game()

func _on_death_exit_requested() -> void:
	go_to_main_menu()

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
		"world_seed": cfg.get_value("game", "world_seed", 0),
		"player1_position": cfg.get_value("game", "player1_position", Vector2.ZERO),
		"player2_exists": cfg.get_value("game", "player2_exists", false),
		"player2_position": cfg.get_value("game", "player2_position", Vector2.ZERO)
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
