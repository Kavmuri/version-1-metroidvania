extends Node2D

# arena_rect: left, top, width, height
@export var arena_rect: Rect2 = Rect2(3800, -200, 2200, 785)
@export var global_limits: Rect2 = Rect2(0, -1000, 6000, 785) # Overall level limits
@export var zoom_level: Vector2 = Vector2(0.7, 0.7)

var players_in_area: Array[Node2D] = []
var active: bool = false
var original_camera_limits: Dictionary = {}

func _ready() -> void:
	var area = get_node_or_null("transicionBOSS")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	# Apply global limits immediately on start to hide purple
	call_deferred("_apply_global_limits")

func _apply_global_limits() -> void:
	var players = get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("player")
	for p in players:
		var cam = p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_bottom = int(global_limits.size.y)
			cam.limit_right = int(global_limits.size.x)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.is_in_group("player"):
		if not body in players_in_area:
			players_in_area.append(body)
			_check_activation()

func _on_body_exited(body: Node2D) -> void:
	if body in players_in_area:
		players_in_area.erase(body)

func _check_activation() -> void:
	if active: return
	var expected = 2 if GameManager.current_game_mode == "coop" and GameManager.current_player1 and GameManager.current_player2 else 1
	if players_in_area.size() >= expected:
		_activate_boss_fight()

func _activate_boss_fight() -> void:
	active = true
	var agis = find_child("Agis", true, false)
	if agis:
		if agis.has_method("activate"): agis.activate()
		if agis.has_signal("boss_defeated"): agis.boss_defeated.connect(_on_boss_defeated)
	_lock_camera()

func _on_boss_defeated() -> void:
	release_camera()

func _lock_camera() -> void:
	for player in players_in_area:
		var camera = player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			original_camera_limits[player] = {
				"left": camera.limit_left, "top": camera.limit_top,
				"right": camera.limit_right, "bottom": camera.limit_bottom,
				"zoom": camera.zoom
			}
			camera.limit_left = int(arena_rect.position.x)
			camera.limit_top = int(arena_rect.position.y)
			camera.limit_right = int(arena_rect.position.x + arena_rect.size.x)
			camera.limit_bottom = int(arena_rect.position.y + arena_rect.size.y)
			var tween = create_tween()
			tween.tween_property(camera, "zoom", zoom_level, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func release_camera() -> void:
	for player in original_camera_limits.keys():
		if is_instance_valid(player):
			var camera = player.get_node_or_null("Camera2D") as Camera2D
			if camera:
				var limits = original_camera_limits[player]
				camera.limit_left = limits["left"]
				camera.limit_top = limits["top"]
				camera.limit_right = limits["right"]
				camera.limit_bottom = limits["bottom"]
				var tween = create_tween()
				tween.tween_property(camera, "zoom", limits["zoom"], 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active = false
