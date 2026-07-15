class_name EnemyEncounterPool
extends RefCounted

const SPAWN_FALL_HEIGHT := 24.0

static func populate(parent: Node, spawn_points: Array[Vector2], pool: Array[PackedScene], seed_value: int, spawn_chance: float = 1.0) -> void:
	if pool.is_empty() or spawn_points.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var shuffled_pool := pool.duplicate()
	_shuffle_with_rng(shuffled_pool, rng)

	var pool_index := 0
	for point in spawn_points:
		if rng.randf() > spawn_chance:
			continue
		var enemy_scene: PackedScene = shuffled_pool[pool_index % shuffled_pool.size()]
		pool_index += 1
		var enemy := enemy_scene.instantiate()
		if enemy == null:
			continue
		parent.add_child(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = point - Vector2(0, SPAWN_FALL_HEIGHT)

static func _shuffle_with_rng(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
