extends CharacterBody2D

@export var max_health: int = 3
@export var contact_damage: int = 1
@export var move_speed: float = 55.0
@export var gravity: float = 1000.0
@export var detection_range: float = 360.0
@export var uses_gravity: bool = true
@export var contact_damage_enabled: bool = true
@export var contact_damage_interval: float = 0.6
@export var contact_groups: Array[StringName] = [&"Player", &"player"]
@export var flip_h_when_facing_right: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_area: Area2D = get_node_or_null("ContactArea") as Area2D

var health: int
var player: Node2D
var facing: int = -1
var _contact_damage_cooldowns: Dictionary = {}

func _ready() -> void:
	health = max_health
	_find_player()
	play_anim("idle")

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
	if uses_gravity and not is_on_floor():
		velocity.y += gravity * delta
	_tick_contact_damage(delta)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		var candidates = get_tree().get_nodes_in_group("players")
		if not candidates.is_empty():
			player = candidates[0] as Node2D
	if player == null:
		player = _find_node_by_name(get_tree().current_scene, ["Player1", "Player", "Player2"])

func _find_node_by_name(root: Node, names: Array[String]) -> Node2D:
	if root == null:
		return null
	if names.has(root.name) and root is Node2D:
		return root as Node2D
	for child in root.get_children():
		var found := _find_node_by_name(child, names)
		if found != null:
			return found
	return null

func distance_to_player() -> float:
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)

func direction_to_player() -> Vector2:
	if player == null:
		return Vector2.LEFT
	return global_position.direction_to(player.global_position)

func update_facing_from_velocity() -> void:
	if abs(velocity.x) > 0.1:
		facing = 1 if velocity.x > 0 else -1
		sprite.flip_h = facing > 0 if flip_h_when_facing_right else facing < 0

func play_anim(anim_name: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

func play_first_available_anim(anim_names: Array[StringName]) -> void:
	if sprite.sprite_frames == null:
		return
	for anim_name in anim_names:
		if sprite.sprite_frames.has_animation(anim_name):
			play_anim(anim_name)
			return

func receive_damage(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	if health <= 0:
		AudioManager.play_sfx(&"enemy_death")
		die()
	else:
		AudioManager.play_sfx(&"enemy_hit")

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO) -> void:
	receive_damage(cantidad, fuente_pos)

func die() -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		play_anim("death")
		await sprite.animation_finished
	queue_free()

func _tick_contact_damage(delta: float) -> void:
	for body_id in _contact_damage_cooldowns.keys():
		var remaining_time := float(_contact_damage_cooldowns[body_id]) - delta
		if remaining_time <= 0.0:
			_contact_damage_cooldowns.erase(body_id)
		else:
			_contact_damage_cooldowns[body_id] = remaining_time

	if contact_area == null:
		return
	for body in contact_area.get_overlapping_bodies():
		_try_damage_contact_body(body as Node2D)

func _on_contact_body_entered(body: Node2D) -> void:
	_try_damage_contact_body(body)

func _try_damage_contact_body(body: Node2D) -> void:
	if not contact_damage_enabled or body == null or not _is_contact_damage_target(body):
		return

	var body_id := body.get_instance_id()
	if _contact_damage_cooldowns.has(body_id):
		return

	if _deal_contact_damage(body):
		_contact_damage_cooldowns[body_id] = max(contact_damage_interval, 0.01)

func _is_contact_damage_target(body: Node2D) -> bool:
	if body.name.begins_with("Player") or body.is_in_group(&"Player") or body.is_in_group(&"player"):
		return true
	for group_name in contact_groups:
		if body.is_in_group(group_name):
			return true
	return false

func _deal_contact_damage(body: Node2D) -> bool:
	if body.has_method("recibir_daño"):
		body.recibir_daño(contact_damage, global_position)
		return true
	if body.has_method("receive_damage"):
		body.receive_damage(contact_damage, global_position)
		return true
	return false
