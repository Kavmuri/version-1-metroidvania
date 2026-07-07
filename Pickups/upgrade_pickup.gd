extends Area2D

@export_enum("any", "kaizen", "eldric") var target_player: String = "any"
@export_enum("max_health", "damage", "cooldown", "dash", "double_jump") var upgrade_type: String = "damage"
@export var amount: int = 25
@export var cooldown_delta: float = -0.05
@export var consume_on_pickup := true

var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _collected or body == null or not _is_valid_player(body):
		return

	if not _apply_upgrade(body):
		return

	_collected = true
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx(&"ui_confirm")
	if consume_on_pickup:
		queue_free()

func _is_valid_player(body: Node2D) -> bool:
	if not (body.is_in_group(&"Player") or body.is_in_group(&"player") or body.name.begins_with("Player")):
		return false
	if target_player == "any":
		return true
	return _player_key(body) == target_player

func _player_key(body: Node2D) -> String:
	var script := body.get_script() as Script
	var script_path := script.resource_path if script != null else ""
	if body.name == "Kaizen" or body.name == "Player1" or script_path == "res://Player1/player1.gd":
		return "kaizen"
	if body.name == "Eldric" or body.name == "Player2" or script_path == "res://Player2/player2.gd":
		return "eldric"
	return ""

func _apply_upgrade(player: Node2D) -> bool:
	match upgrade_type:
		"max_health":
			return _increase_max_health(player)
		"damage":
			return _increase_damage(player)
		"cooldown":
			return _improve_cooldown(player)
		"dash":
			return _set_dash(player)
		"double_jump":
			return _set_double_jump(player)
	return false

func _increase_max_health(player: Node2D) -> bool:
	if not ("max_health" in player and "health" in player):
		return false
	player.max_health += amount
	player.health = min(player.health + amount, player.max_health)
	return true

func _increase_damage(player: Node2D) -> bool:
	if not ("attack_damage" in player):
		return false
	player.attack_damage += amount
	return true

func _improve_cooldown(player: Node2D) -> bool:
	if not ("attack_cooldown" in player):
		return false
	player.attack_cooldown = max(0.1, player.attack_cooldown + cooldown_delta)
	return true

func _set_dash(player: Node2D) -> bool:
	if player.has_method("set_dash_activo"):
		player.set_dash_activo(true)
		return true
	if not ("tiene_dash" in player):
		return false
	player.tiene_dash = true
	return true

func _set_double_jump(player: Node2D) -> bool:
	if player.has_method("set_salto_infinito_activo"):
		player.set_salto_infinito_activo(true)
		return true
	if not ("tiene_salto_infinito" in player):
		return false
	player.tiene_salto_infinito = true
	return true
