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


static func populate_random_count(parent: Node, spawn_points: Array[Vector2], pool: Array[PackedScene], seed_value: int, min_count: int = 1, max_count: int = -1) -> void:
	var selected_points := choose_spawn_points(spawn_points, seed_value, min_count, max_count)
	populate(parent, selected_points, pool, seed_value)


static func choose_spawn_points(spawn_points: Array[Vector2], seed_value: int, min_count: int = 1, max_count: int = -1) -> Array[Vector2]:
	var selected: Array[Vector2] = []
	if spawn_points.is_empty():
		return selected

	var upper_bound := spawn_points.size() if max_count < 0 else mini(max_count, spawn_points.size())
	upper_bound = maxi(upper_bound, 0)
	var lower_bound := clampi(min_count, 0, upper_bound)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var desired_count := rng.randi_range(lower_bound, upper_bound)
	var shuffled_points: Array[Vector2] = spawn_points.duplicate()
	_shuffle_with_rng(shuffled_points, rng)
	for index in range(desired_count):
		selected.append(shuffled_points[index])
	return selected

static func _shuffle_with_rng(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
