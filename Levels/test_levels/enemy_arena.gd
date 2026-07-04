extends Node2D

const PLAYER_CATALOG := [
	{"name": "Kaizen", "scene": preload("res://Player1/player.tscn")},
	{"name": "Eldric", "scene": preload("res://Player2/player_2.tscn")},
]

const ENEMY_CATALOG := [
	{"name": "Crab", "scene": preload("res://Enemies/enemy_crab.tscn")},
	{"name": "Flying Eye Demon", "scene": preload("res://Enemies/scenes/enemy_flying_eye_demon.tscn")},
	{"name": "Ghost", "scene": preload("res://Enemies/scenes/enemy_ghost.tscn")},
	{"name": "Hell Hound Fire", "scene": preload("res://Enemies/scenes/enemy_hell_hound_fire.tscn")},
	{"name": "Mutant Toad", "scene": preload("res://Enemies/scenes/enemy_mutant_toad.tscn")},
	{"name": "Nightmare", "scene": preload("res://Enemies/scenes/enemy_nightmare.tscn")},
	{"name": "Ogre", "scene": preload("res://Enemies/scenes/enemy_ogre.tscn")},
	{"name": "Dragon", "scene": preload("res://Enemies/scenes/enemy_dragon.tscn")},
	{"name": "Hell Beast Fire", "scene": preload("res://Enemies/scenes/enemy_hell_beast_fire.tscn")},
	{"name": "Demon Boss", "scene": preload("res://Enemies/scenes/enemy_demon_boss.tscn")},
]

@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _enemy_spawn: Marker2D = $EnemySpawn
@onready var _ui: CanvasLayer = $UI
@onready var _player_selector: OptionButton = $UI/Panel/Content/PlayerSelector
@onready var _enemy_selector: OptionButton = $UI/Panel/Content/EnemySelector
@onready var _gameplay_hud: CanvasLayer = $GameplayHUD

var _selected_player_index := 0
var _selected_enemy_index := 0
var _player: Node2D
var _spawned_enemy: Node2D

func _ready() -> void:
	get_tree().paused = false
	_populate_player_selector()
	_populate_enemy_selector()
	_player_selector.item_selected.connect(_on_player_selected)
	_enemy_selector.item_selected.connect(_on_enemy_selected)
	_ui.visible = false
	_player = get_node_or_null("Player") as Node2D
	_spawn_selected_player()
	_spawn_selected_enemy()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_toggle_enemy_panel()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_go_to_main_menu()

func _toggle_enemy_panel() -> void:
	_ui.visible = not _ui.visible
	if _ui.visible:
		_player_selector.grab_focus()
	else:
		_release_panel_focus()

func _close_enemy_panel() -> void:
	_ui.visible = false
	_release_panel_focus()

func _release_panel_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()

func _populate_player_selector() -> void:
	_player_selector.clear()
	for player_data in PLAYER_CATALOG:
		_player_selector.add_item(str(player_data["name"]))
	_player_selector.select(_selected_player_index)

func _populate_enemy_selector() -> void:
	_enemy_selector.clear()
	for enemy_data in ENEMY_CATALOG:
		_enemy_selector.add_item(str(enemy_data["name"]))
	_enemy_selector.select(_selected_enemy_index)

func _on_player_selected(index: int) -> void:
	_selected_player_index = clampi(index, 0, PLAYER_CATALOG.size() - 1)
	_spawn_selected_player()
	_spawn_selected_enemy()
	_close_enemy_panel()

func _on_enemy_selected(index: int) -> void:
	_selected_enemy_index = clampi(index, 0, ENEMY_CATALOG.size() - 1)
	_spawn_selected_enemy()
	_close_enemy_panel()

func _spawn_selected_player() -> void:
	_clear_current_player()

	var player_data: Dictionary = PLAYER_CATALOG[_selected_player_index]
	var player_scene := player_data["scene"] as PackedScene
	var player := player_scene.instantiate() as Node2D
	if player == null:
		push_warning("No se pudo instanciar: " + str(player_data["name"]))
		return

	player.name = str(player_data["name"])
	add_child(player)
	_player = player
	_configure_player_for_arena()
	_reset_player()

func _clear_current_player() -> void:
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null

func _spawn_selected_enemy() -> void:
	_clear_current_enemy()
	_reset_player()

	var enemy_data: Dictionary = ENEMY_CATALOG[_selected_enemy_index]
	var enemy_scene := enemy_data["scene"] as PackedScene
	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_warning("No se pudo instanciar: " + str(enemy_data["name"]))
		return

	_configure_enemy_for_arena(enemy)
	add_child(enemy)
	_spawned_enemy = enemy
	enemy.global_position = _enemy_spawn.global_position

func _clear_current_enemy() -> void:
	if is_instance_valid(_spawned_enemy):
		_spawned_enemy.queue_free()
	_spawned_enemy = null

func _configure_player_for_arena() -> void:
	if _player == null:
		return
	if "input_mode" in _player:
		_player.set("input_mode", "both")
	if _gameplay_hud.has_method("setup"):
		_gameplay_hud.setup(_player, null, str(PLAYER_CATALOG[_selected_player_index]["name"]))
	GameManager.register_player1(_player)
	_ensure_player_camera()

func _ensure_player_camera() -> void:
	if _player == null or _player.get_node_or_null("Camera2D") != null:
		return
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(0, -32)
	camera.zoom = Vector2(2.5, 2.5)
	camera.enabled = true
	_player.add_child(camera)

func _reset_player() -> void:
	if _player == null:
		return
	_player.global_position = _player_spawn.global_position
	var player_body := _player as CharacterBody2D
	if player_body != null:
		player_body.velocity = Vector2.ZERO
	if "max_health" in _player and "health" in _player:
		_player.health = _player.max_health
	if "is_dead" in _player:
		_player.is_dead = false
	for timer_name in [&"invulnerability_timer", &"hurt_timer", &"attack_timer", &"shoot_animation_timer", &"dash_timer", &"attack_animation_timer"]:
		if timer_name in _player:
			_player.set(timer_name, 0.0)
	var sprite := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.modulate = Color.WHITE

func handle_player_death(player: Node2D) -> bool:
	if player != _player:
		return false
	_reset_player()
	return true

func _configure_enemy_for_arena(enemy: Node2D) -> void:
	if _has_property(enemy, "patrol_points"):
		var patrol_points := Node2D.new()
		patrol_points.name = "PatrolsPoints"
		enemy.add_child(patrol_points)

		var point_left := Marker2D.new()
		point_left.name = "PointLeft"
		point_left.position = Vector2(-96, 0)
		patrol_points.add_child(point_left)

		var point_right := Marker2D.new()
		point_right.name = "PointRight"
		point_right.position = Vector2(96, 0)
		patrol_points.add_child(point_right)

		enemy.set("patrol_points", patrol_points)

func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(str(property.get("name"))) == property_name:
			return true
	return false

func _go_to_main_menu() -> void:
	GameManager.go_to_main_menu()
