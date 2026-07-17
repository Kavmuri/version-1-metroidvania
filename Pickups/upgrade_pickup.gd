extends Area2D

@export_enum("any", "kaizen", "eldric") var target_player: String = "any"
@export_enum("max_health", "damage", "cooldown", "dash", "double_jump") var upgrade_type: String = "damage"
@export var amount: int = 25
@export var cooldown_delta: float = -0.05
@export var use_linear_progression := true
## -1 = da la siguiente mejora en la secuencia (comportamiento anterior).
## 0-6 = fuerza una mejora especifica sin importar el orden de recoleccion:
## 0=Doble salto, 1=nivel 2, 2=nivel 3, 3=nivel 4, 4=nivel 5, 5=nivel 6, 6=nivel 7.
## (Kaizen: rapido/cargado/doble/perforante/rebote/onda. Eldric: dash/escudo/corazon/perforante/furia/planeo)
@export_range(-1, 6) var target_upgrade_index: int = -1
@export var consume_on_pickup := true

var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _collected or body == null or not _is_valid_player(body):
		return

	var upgrade_result := _apply_upgrade(body)
	if not bool(upgrade_result.get("applied", false)):
		return

	_collected = true
	_show_upgrade_feedback(body, upgrade_result)
	GameManager.save_player_upgrade_state(body)
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

func _apply_upgrade(player: Node2D) -> Dictionary:
	if target_upgrade_index >= 0 and player.has_method("apply_specific_upgrade"):
		var specific_result = player.apply_specific_upgrade(target_upgrade_index)
		if specific_result is Dictionary:
			return specific_result
	if use_linear_progression and player.has_method("apply_next_linear_upgrade"):
		var linear_result = player.apply_next_linear_upgrade()
		if linear_result is Dictionary:
			return linear_result

	match upgrade_type:
		"max_health":
			return _legacy_result(_increase_max_health(player), "Vida maxima", "Aumenta la vida maxima.")
		"damage":
			return _legacy_result(_increase_damage(player), "Daño", "Aumenta el daño base.")
		"cooldown":
			return _legacy_result(_improve_cooldown(player), "Cadencia", "Reduce el tiempo entre ataques.")
		"dash":
			return _legacy_result(_set_dash(player), "Dash", "Desbloquea el dash.")
		"double_jump":
			return _legacy_result(_set_double_jump(player), "Doble salto", "Desbloquea un salto extra.")
	return _legacy_result(false, "", "")

func _legacy_result(applied: bool, title: String, description: String) -> Dictionary:
	return {
		"applied": applied,
		"title": title,
		"description": description,
		"icon_path": "",
	}

func _show_upgrade_feedback(player: Node2D, upgrade_result: Dictionary) -> void:
	var hud := _find_gameplay_hud()
	if hud == null:
		return
	var title := str(upgrade_result.get("title", "Mejora obtenida"))
	var description := str(upgrade_result.get("description", ""))
	var control_hint := str(upgrade_result.get("control_hint", ""))
	var text := title
	if not description.is_empty():
		text += "\n" + description
	if not control_hint.is_empty():
		text += "\nControl: " + control_hint
	if hud.has_method("show_upgrade_text"):
		hud.show_upgrade_text(text)
	if _player_key(player) == "kaizen" and hud.has_method("set_player1_powerup_icon"):
		var icon_path := str(upgrade_result.get("icon_path", ""))
		if not icon_path.is_empty():
			hud.set_player1_powerup_icon(icon_path)

func _find_gameplay_hud() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	var named_hud := current_scene.find_child("GameplayHUD", true, false)
	if named_hud != null:
		return named_hud
	return _find_node_with_method(current_scene, "show_upgrade_text")

func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null

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
