extends Area2D

const ORB_SCENE := preload("res://Pickups/puzzle_orb.tscn")

@export var is_trigger: bool = true
@export var spawn_count: int = 6
@export var spawn_radius: float = 70.0
@export var collect_time_limit: float = 15.0
@export var wall_path: NodePath

@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var _collected := false
var _owner_trigger: Node = null
var _spawned_orbs: Array[Node2D] = []
var _collected_spawn_count: int = 0
var _challenge_active := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _collected or body == null or not _is_valid_player(body):
		return
	_collected = true

	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx(&"ui_confirm")

	if is_trigger:
		_hide_trigger()
		call_deferred("_spawn_orbs")
	else:
		if _owner_trigger != null and is_instance_valid(_owner_trigger):
			_owner_trigger.call("_on_spawned_orb_collected")
		queue_free()

func _hide_trigger() -> void:
	visible = false
	set_deferred("monitoring", false)
	if _collision != null:
		_collision.set_deferred("disabled", true)

func _show_trigger() -> void:
	_collected = false
	visible = true
	set_deferred("monitoring", true)
	if _collision != null:
		_collision.set_deferred("disabled", false)

func _is_valid_player(body: Node2D) -> bool:
	return body.is_in_group(&"Player") or body.is_in_group(&"player") or body.name.begins_with("Player")

func _get_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D:
			positions.append(child.global_position)

	if not positions.is_empty():
		return positions

	# Sin marcadores colocados a mano: usa un circulo alrededor de la bola inicial.
	for i in spawn_count:
		var angle: float = TAU * float(i) / float(spawn_count)
		positions.append(global_position + Vector2(cos(angle), sin(angle)) * spawn_radius)
	return positions

func _spawn_orbs() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var spawn_positions: Array[Vector2] = _get_spawn_positions()

	_spawned_orbs.clear()
	_collected_spawn_count = 0
	_challenge_active = true

	for spawn_pos in spawn_positions:
		var orb := ORB_SCENE.instantiate()
		orb.is_trigger = false
		orb._owner_trigger = self
		parent.add_child(orb)
		orb.global_position = spawn_pos
		_spawned_orbs.append(orb)

	var timer := get_tree().create_timer(collect_time_limit)
	timer.timeout.connect(_on_challenge_timeout)

func _on_spawned_orb_collected() -> void:
	if not _challenge_active:
		return
	_collected_spawn_count += 1
	if _collected_spawn_count >= _spawned_orbs.size():
		_on_challenge_success()

func _on_challenge_success() -> void:
	_challenge_active = false
	var wall := get_node_or_null(wall_path)
	if wall != null and wall.has_method("register_orb_completed"):
		wall.register_orb_completed()
	queue_free()

func _on_challenge_timeout() -> void:
	if not _challenge_active:
		return
	_challenge_active = false
	for orb in _spawned_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_spawned_orbs.clear()
	_show_trigger()
