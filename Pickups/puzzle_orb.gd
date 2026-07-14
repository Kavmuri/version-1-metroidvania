extends Area2D

const ORB_SCENE := preload("res://Pickups/puzzle_orb.tscn")

@export var is_trigger: bool = true
@export var spawn_count: int = 6
@export var spawn_radius: float = 70.0
@export var collect_time_limit: float = 7.0

var _collected := false

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
		call_deferred("_spawn_orbs")

	queue_free()

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

	var spawned: Array[Node2D] = []
	for spawn_pos in spawn_positions:
		var orb := ORB_SCENE.instantiate()
		orb.is_trigger = false
		parent.add_child(orb)
		orb.global_position = spawn_pos
		spawned.append(orb)

	var timer := get_tree().create_timer(collect_time_limit)
	timer.timeout.connect(func():
		for orb in spawned:
			if is_instance_valid(orb):
				orb.queue_free()
	)
