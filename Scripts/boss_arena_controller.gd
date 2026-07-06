extends Node2D

# arena_rect: left, top, width, height
@export var arena_rect: Rect2 = Rect2(3800, -360, 1950, 940)
@export var global_limits: Rect2 = Rect2(0, -1000, 6500, 1580)
@export var zoom_level: Vector2 = Vector2(0.85, 0.85)
@export var camera_offset: Vector2 = Vector2(0, 48)
@export var arena_wall_top: float = -360.0
@export var arena_wall_bottom: float = 620.0
@export var zombie_spawn_margin: float = 180.0

var players_in_area: Array[Node2D] = []
var active: bool = false
var original_camera_limits: Dictionary = {}
var arena_walls: Array[StaticBody2D] = []

func _ready() -> void:
	call_deferred("_register_scene_players")

	var area := get_node_or_null("transicionBOSS")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	call_deferred("_apply_global_limits")

func _apply_global_limits() -> void:
	for player in _get_all_players():
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			_configure_camera(camera, global_limits)

func _register_scene_players() -> void:
	var p1 := get_node_or_null("Player1") as Node2D
	if p1 != null:
		GameManager.register_player1(p1)
		if "input_mode" in p1:
			p1.set("input_mode", "keyboard")
		var camera := p1.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.make_current()

	var p2 := get_node_or_null("Player2") as Node2D
	if p2 != null:
		GameManager.register_player2(p2)

	var hud := get_node_or_null("GameplayHUD")
	if hud != null:
		hud.visible = false
		if hud.has_method("setup"):
			hud.setup(p1, p2)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.is_in_group("player"):
		if not body in players_in_area:
			players_in_area.append(body)
			_check_activation()

func _on_body_exited(body: Node2D) -> void:
	if body in players_in_area:
		players_in_area.erase(body)

func _check_activation() -> void:
	if active:
		return
	var expected := 2 if GameManager.current_game_mode == "coop" and GameManager.current_player1 and GameManager.current_player2 else 1
	if players_in_area.size() >= expected:
		_activate_boss_fight()

func _activate_boss_fight() -> void:
	active = true
	var agis := find_child("Agis", true, false) as Node2D
	if agis != null:
		if agis.has_method("activate"):
			agis.activate()
		if agis.has_signal("boss_defeated"):
			agis.boss_defeated.connect(_on_boss_defeated)
		_configure_agis_spawns(agis)
	_show_combat_hud(agis)
	_lock_arena_walls()
	_lock_camera()

func _show_combat_hud(agis: Node2D) -> void:
	var hud := get_node_or_null("GameplayHUD")
	if hud == null:
		return
	if hud.has_method("setup"):
		hud.setup(GameManager.current_player1, GameManager.current_player2)
	if agis != null and hud.has_method("set_boss"):
		hud.set_boss(agis)
	if hud.has_method("show_combat_hud"):
		hud.show_combat_hud()
	else:
		hud.visible = true

func _on_boss_defeated() -> void:
	release_camera()

func _lock_camera() -> void:
	for player in players_in_area:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			original_camera_limits[player] = {
				"left": camera.limit_left, "top": camera.limit_top,
				"right": camera.limit_right, "bottom": camera.limit_bottom,
				"zoom": camera.zoom, "offset": camera.offset
			}
			_configure_camera(camera, arena_rect)

			var tween := create_tween().set_parallel(true)
			tween.tween_property(camera, "zoom", zoom_level, 1.0).set_trans(Tween.TRANS_SINE)
			tween.tween_property(camera, "offset", camera_offset, 1.0).set_trans(Tween.TRANS_SINE)

func release_camera() -> void:
	_unlock_arena_walls()
	for player in original_camera_limits.keys():
		if is_instance_valid(player):
			var camera := player.get_node_or_null("Camera2D") as Camera2D
			if camera != null:
				var limits = original_camera_limits[player]
				camera.limit_left = limits["left"]
				camera.limit_top = limits["top"]
				camera.limit_right = limits["right"]
				camera.limit_bottom = limits["bottom"]
				var tween := create_tween().set_parallel(true)
				tween.tween_property(camera, "zoom", limits["zoom"], 1.0)
				tween.tween_property(camera, "offset", limits["offset"], 1.0)
	active = false

func _configure_camera(camera: Camera2D, limits: Rect2) -> void:
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.position.x + limits.size.x)
	camera.limit_bottom = int(limits.position.y + limits.size.y)
	camera.offset = camera_offset

func _configure_agis_spawns(agis: Node2D) -> void:
	if "spawn_range_x" in agis:
		agis.set("spawn_range_x", Vector2(
			arena_rect.position.x + zombie_spawn_margin,
			arena_rect.position.x + arena_rect.size.x - zombie_spawn_margin
		))
	if "spawn_y" in agis:
		agis.set("spawn_y", 560.0)

func _lock_arena_walls() -> void:
	_unlock_arena_walls()
	var left_x := arena_rect.position.x
	var right_x := arena_rect.position.x + arena_rect.size.x
	arena_walls.append(_create_arena_wall("AgisArenaLeftWall", Vector2(left_x, (arena_wall_top + arena_wall_bottom) * 0.5)))
	arena_walls.append(_create_arena_wall("AgisArenaRightWall", Vector2(right_x, (arena_wall_top + arena_wall_bottom) * 0.5)))

func _unlock_arena_walls() -> void:
	for wall in arena_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	arena_walls.clear()

func _create_arena_wall(wall_name: String, wall_position: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)
	wall.global_position = wall_position

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, arena_wall_bottom - arena_wall_top)
	shape.shape = rect
	wall.add_child(shape)
	return wall

func _get_all_players() -> Array[Node]:
	var players: Array[Node] = []
	for group_name in [&"Player", &"player"]:
		for player in get_tree().get_nodes_in_group(group_name):
			if player is Node2D and not players.has(player):
				players.append(player)
	for node_name in ["Player1", "Player2"]:
		var player := get_node_or_null(node_name)
		if player is Node2D and not players.has(player):
			players.append(player)
	return players
