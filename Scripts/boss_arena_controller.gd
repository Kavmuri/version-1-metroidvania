extends Node2D

@export var arena_rect: Rect2 = Rect2(3000, -200, 3400, 1200)
@export var zoom_level: Vector2 = Vector2(0.7, 0.7)

var players_in_area: Array[Node2D] = []
var active: bool = false
var original_camera_limits: Dictionary = {}

func _ready() -> void:
	# Ensure we can find the transition area
	var area = get_node_or_null("transicionBOSS")
	if area:
		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)
		if not area.body_exited.is_connected(_on_body_exited):
			area.body_exited.connect(_on_body_exited)
	else:
		push_warning("BossArenaController: 'transicionBOSS' node not found.")

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

	var expected_players = 1
	# Check GameManager for current mode
	if GameManager.current_game_mode == "coop":
		expected_players = 2

	# Also check if there are actually 2 players registered in GameManager
	var p1 = GameManager.current_player1
	var p2 = GameManager.current_player2
	if expected_players == 2 and (p1 == null or p2 == null):
		expected_players = 1 # Fallback if P2 isn't spawned yet or died

	if players_in_area.size() >= expected_players:
		_activate_boss_fight()

func _activate_boss_fight() -> void:
	active = true
	print("Boss fight activated!")

	# Find Agis and activate him
	var agis = find_child("Agis", true, false)
	if agis:
		if agis.has_method("activate"):
			agis.activate()
		if agis.has_signal("boss_defeated"):
			agis.boss_defeated.connect(_on_boss_defeated)

	# Configure camera for all players in area
	_lock_camera()

func _on_boss_defeated() -> void:
	release_camera()

func _lock_camera() -> void:
	for player in players_in_area:
		var camera = player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			# Save original limits
			original_camera_limits[player] = {
				"left": camera.limit_left,
				"top": camera.limit_top,
				"right": camera.limit_right,
				"bottom": camera.limit_bottom,
				"zoom": camera.zoom
			}

			# Apply arena limits
			camera.limit_left = int(arena_rect.position.x)
			camera.limit_top = int(arena_rect.position.y)
			camera.limit_right = int(arena_rect.position.x + arena_rect.size.x)
			camera.limit_bottom = int(arena_rect.position.y + arena_rect.size.y)

			# Smooth zoom
			var tween = create_tween()
			tween.tween_property(camera, "zoom", zoom_level, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
				tween.tween_property(camera, "zoom", limits["zoom"], 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active = false
