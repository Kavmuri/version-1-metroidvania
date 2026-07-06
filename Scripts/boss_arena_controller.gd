extends Node2D

# arena_rect: left, top, width, height
@export var arena_rect: Rect2 = Rect2(3800, -360, 2200, 940)
@export var global_limits: Rect2 = Rect2(0, -1000, 6500, 1580)
@export var zoom_level: Vector2 = Vector2(0.85, 0.85)
@export var camera_offset: Vector2 = Vector2(0, 48)

var players_in_area: Array[Node2D] = []
var active: bool = false
var original_camera_limits: Dictionary = {}

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
	_show_combat_hud(agis)
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
