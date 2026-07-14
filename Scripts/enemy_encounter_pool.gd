class_name EnemyEncounterPool
extends RefCounted

const SPAWN_FALL_HEIGHT := 24.0

static func populate(parent: Node, spawn_points: Array[Vector2], pool: Array[PackedScene], seed_value: int, spawn_chance: float = 0.65) -> void:
	if pool.is_empty() or spawn_points.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for point in spawn_points:
		if rng.randf() > spawn_chance:
			continue
		var enemy_scene: PackedScene = pool[rng.randi_range(0, pool.size() - 1)]
		var enemy := enemy_scene.instantiate()
		if enemy == null:
			continue
		parent.add_child(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = point - Vector2(0, SPAWN_FALL_HEIGHT)
