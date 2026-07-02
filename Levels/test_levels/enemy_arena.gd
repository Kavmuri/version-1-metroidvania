extends Node2D

const ENEMY_CATALOG := [
	{"name": "Crab", "scene": preload("res://Enemies/enemy_crab.tscn")},
	{"name": "Flying Eye Demon", "scene": preload("res://Enemies/scenes/enemy_flying_eye_demon.tscn")},
	{"name": "Ghost", "scene": preload("res://Enemies/scenes/enemy_ghost.tscn")},
	{"name": "Wizard", "scene": preload("res://Enemies/scenes/enemy_wizard.tscn")},
	{"name": "Hell Hound Fire", "scene": preload("res://Enemies/scenes/enemy_hell_hound_fire.tscn")},
	{"name": "Mutant Toad", "scene": preload("res://Enemies/scenes/enemy_mutant_toad.tscn")},
	{"name": "Nightmare", "scene": preload("res://Enemies/scenes/enemy_nightmare.tscn")},
	{"name": "Ogre", "scene": preload("res://Enemies/scenes/enemy_ogre.tscn")},
	{"name": "Dragon", "scene": preload("res://Enemies/scenes/enemy_dragon.tscn")},
	{"name": "Hell Beast Fire", "scene": preload("res://Enemies/scenes/enemy_hell_beast_fire.tscn")},
	{"name": "Demon Boss", "scene": preload("res://Enemies/scenes/enemy_demon_boss.tscn")},
]

@onready var _player: Node2D = $Player
@onready var _player_spawn: Marker2D = $PlayerSpawn
@onready var _enemy_spawn: Marker2D = $EnemySpawn
@onready var _ui: CanvasLayer = $UI
@onready var _enemy_selector: OptionButton = $UI/Panel/Content/EnemySelector
@onready var _gameplay_hud: CanvasLayer = $GameplayHUD

var _selected_enemy_index := 0
var _spawned_enemy: Node2D

func _ready() -> void:
	get_tree().paused = false
	GameManager.register_player1(_player)
	if _gameplay_hud.has_method("setup"):
		_gameplay_hud.setup(_player)
	_populate_enemy_selector()
	_enemy_selector.item_selected.connect(_on_enemy_selected)
	_ui.visible = false
	_reset_player()
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
		_enemy_selector.grab_focus()
	else:
		var viewport := get_viewport()
		if viewport != null:
			viewport.gui_release_focus()

func _populate_enemy_selector() -> void:
	_enemy_selector.clear()
	for enemy_data in ENEMY_CATALOG:
		_enemy_selector.add_item(str(enemy_data["name"]))
	_enemy_selector.select(_selected_enemy_index)

func _on_enemy_selected(index: int) -> void:
	_selected_enemy_index = clampi(index, 0, ENEMY_CATALOG.size() - 1)
	_spawn_selected_enemy()

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

func _reset_player() -> void:
	_player.global_position = _player_spawn.global_position
	var player_body := _player as CharacterBody2D
	if player_body != null:
		player_body.velocity = Vector2.ZERO

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
