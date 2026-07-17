extends CharacterBody2D

@export var max_health: int = 3
@export var contact_damage: int = 10
@export var move_speed: float = 55.0
@export var gravity: float = 1000.0
@export var detection_range: float = 360.0
@export var uses_gravity: bool = true
@export var contact_damage_enabled: bool = true
@export var contact_damage_interval: float = 0.6
@export var contact_groups: Array[StringName] = [&"Player", &"player"]
@export var flip_h_when_facing_right: bool = true
@export var death_effect_scene: PackedScene = preload("res://Enemies/basic/enemy_death_effect.tscn")
@export var auto_create_hurtbox: bool = true
@export var show_world_health_bar: bool = true
@export var world_health_bar_offset: Vector2 = Vector2(0, -54)
@export var world_health_bar_scale: float = 0.4

const WORLD_HEALTH_BAR_TEXTURE: Texture2D = preload("res://UI/Interfaz/EnemyUI/skulls.png")
const WORLD_HEALTH_BAR_FRAME_REGION: Rect2 = Rect2(24, 9, 86, 19)
const WORLD_HEALTH_BAR_FILL_REGION: Rect2 = Rect2(32, 42, 67, 10)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var contact_area: Area2D = get_node_or_null("ContactArea") as Area2D
@onready var state_machine: Node = get_node_or_null("StateMachine")

var health: int
var player: Node2D
var facing: int = -1
var _contact_damage_cooldowns: Dictionary = {}
var hurtbox: Area2D
var _player_in_attack_area := false
var is_dying := false
var _world_health_bar_fill: Sprite2D = null

func _ready() -> void:
	health = max_health
	_setup_hurtbox()
	_find_player()
	play_anim("idle")
	if show_world_health_bar:
		_create_world_health_bar()

func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return
	_update_nearest_player()
	if uses_gravity and not is_on_floor():
		velocity.y += gravity * delta
	_tick_contact_damage(delta)

func _update_nearest_player() -> void:
	var candidates: Array = get_tree().get_nodes_in_group("Player")
	if candidates.is_empty():
		candidates = get_tree().get_nodes_in_group("player")
	if candidates.is_empty():
		if player == null or not is_instance_valid(player):
			_find_player()
		return

	var nearest: Node2D = null
	var nearest_dist: float = INF
	for candidate in candidates:
		if candidate is Node2D and is_instance_valid(candidate):
			var dist: float = global_position.distance_to((candidate as Node2D).global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = candidate as Node2D
	if nearest != null:
		player = nearest

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		var candidates = get_tree().get_nodes_in_group("players")
		if not candidates.is_empty():
			player = candidates[0] as Node2D
	if player == null:
		player = _find_node_by_name(get_tree().current_scene, ["Player1", "Player", "Player2", "Kaizen", "Eldric"])

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
	if sprite == null:
		return
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

func play_first_available_anim(anim_names: Array[StringName]) -> void:
	if sprite == null:
		return
	if sprite.sprite_frames == null:
		return
	for anim_name in anim_names:
		if sprite.sprite_frames.has_animation(anim_name):
			play_anim(anim_name)
			return

func transition_state(state_name: StringName) -> void:
	if state_machine != null and state_machine.has_method("transition_to"):
		state_machine.transition_to(state_name)

func set_player_in_attack_area(is_inside: bool) -> void:
	_player_in_attack_area = is_inside

func is_player_in_attack_area() -> bool:
	return _player_in_attack_area

func receive_damage(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return
	health -= amount
	_update_world_health_bar()
	JuiceManager.flash_sprite(sprite, Color(1.0, 0.35, 0.35))
	JuiceManager.spawn_hit_particles(global_position + Vector2(0, -12), Color(1.0, 0.85, 0.3), 6)
	JuiceManager.hit_stop(0.04, 0.05)
	if health <= 0:
		AudioManager.play_sfx(&"enemy_death")
		JuiceManager.screen_shake(7.0, 0.22)
		die()
	else:
		AudioManager.play_sfx(&"enemy_hit")
		JuiceManager.screen_shake(2.5, 0.12)

func _create_world_health_bar() -> void:
	var bar_root := Node2D.new()
	bar_root.name = "WorldHealthBar"
	bar_root.position = world_health_bar_offset
	bar_root.scale = Vector2(world_health_bar_scale, world_health_bar_scale)
	add_child(bar_root)

	var fill := Sprite2D.new()
	fill.name = "Fill"
	fill.texture = WORLD_HEALTH_BAR_TEXTURE
	fill.centered = false
	fill.region_enabled = true
	fill.region_rect = WORLD_HEALTH_BAR_FILL_REGION
	fill.position = Vector2(
		WORLD_HEALTH_BAR_FILL_REGION.position.x - WORLD_HEALTH_BAR_FRAME_REGION.position.x - WORLD_HEALTH_BAR_FRAME_REGION.size.x * 0.5,
		-WORLD_HEALTH_BAR_FILL_REGION.size.y * 0.5
	)
	fill.modulate = Color(1, 1, 1, 1)
	bar_root.add_child(fill)
	_world_health_bar_fill = fill

	var frame := Sprite2D.new()
	frame.name = "Frame"
	frame.texture = WORLD_HEALTH_BAR_TEXTURE
	frame.centered = true
	frame.region_enabled = true
	frame.region_rect = WORLD_HEALTH_BAR_FRAME_REGION
	bar_root.add_child(frame)

	_update_world_health_bar()

func _update_world_health_bar() -> void:
	if _world_health_bar_fill == null or max_health <= 0:
		return
	var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
	var full_width: float = WORLD_HEALTH_BAR_FILL_REGION.size.x
	_world_health_bar_fill.region_rect = Rect2(
		WORLD_HEALTH_BAR_FILL_REGION.position.x,
		WORLD_HEALTH_BAR_FILL_REGION.position.y,
		full_width * ratio,
		WORLD_HEALTH_BAR_FILL_REGION.size.y
	)

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO) -> void:
	receive_damage(cantidad, fuente_pos)

func get_hurtbox_damage_receiver() -> Node2D:
	return self

const KILL_QUOTE_CHANCE := 0.22
const DEBUG_ARENA_SCENE_NAME := "EnemyArena"

func die() -> void:
	if is_dying:
		return
	is_dying = true
	_disable_damage_areas()
	_spawn_death_effect()
	JuiceManager.spawn_hit_particles(global_position + Vector2(0, -12), Color(1.0, 0.5, 0.5), 14)
	_maybe_show_kill_quote()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		play_anim("death")
		await sprite.animation_finished
	queue_free()

func _maybe_show_kill_quote() -> void:
	if player == null or not is_instance_valid(player):
		return
	var chance: float = 1.0 if _is_debug_arena() else KILL_QUOTE_CHANCE
	if randf() > chance:
		return
	var quote: String = KillQuotes.random_eldric_quote() if _is_eldric(player) else KillQuotes.random_kaizen_quote()
	JuiceManager.show_speech_bubble(player, quote)

func _is_debug_arena() -> bool:
	var current_scene := get_tree().current_scene
	return current_scene != null and current_scene.name == DEBUG_ARENA_SCENE_NAME

func _is_eldric(body: Node2D) -> bool:
	var script := body.get_script() as Script
	var script_path := script.resource_path if script != null else ""
	return body.name == "Eldric" or body.name == "Player2" or script_path == "res://Player2/player2.gd"

func _disable_damage_areas() -> void:
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if contact_area != null:
		contact_area.set_deferred("monitoring", false)
		contact_area.set_deferred("monitorable", false)
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	var attack_area := get_node_or_null("AttackArea2D") as Area2D
	if attack_area != null:
		attack_area.set_deferred("monitoring", false)
		attack_area.set_deferred("monitorable", false)

func _spawn_death_effect() -> void:
	if death_effect_scene == null:
		return
	var death_effect := death_effect_scene.instantiate() as Node2D
	if death_effect == null:
		return
	get_tree().current_scene.add_child(death_effect)
	death_effect.global_position = global_position + Vector2(0, -20)

func _setup_hurtbox() -> void:
	hurtbox = get_node_or_null("Hurtbox") as Area2D
	if hurtbox == null and auto_create_hurtbox:
		hurtbox = _create_hurtbox_from_collision()
	if hurtbox == null:
		return
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 8
	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _create_hurtbox_from_collision() -> Area2D:
	var source_shape := _find_collision_shape(self)
	if source_shape == null or source_shape.shape == null:
		return null

	var new_hurtbox := Area2D.new()
	new_hurtbox.name = "Hurtbox"
	add_child(new_hurtbox)

	var hurt_shape := CollisionShape2D.new()
	hurt_shape.name = "HurtboxShape"
	hurt_shape.position = source_shape.position
	hurt_shape.rotation = source_shape.rotation
	hurt_shape.scale = source_shape.scale
	hurt_shape.shape = source_shape.shape.duplicate()
	new_hurtbox.add_child(hurt_shape)
	return new_hurtbox

func _find_collision_shape(root: Node) -> CollisionShape2D:
	for child in root.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	for child in root.get_children():
		var found := _find_collision_shape(child)
		if found != null:
			return found
	return null

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var projectile := area as Node
	if projectile != null and projectile.has_method("try_apply_damage_to"):
		projectile.try_apply_damage_to(self)
		return
	if projectile != null and projectile.has_method("get_damage_amount"):
		receive_damage(projectile.get_damage_amount(), projectile.global_position)

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
