extends "res://Enemies/scripts/enemy_base.gd"

@export var boss_name: String = "Agis"
@export var zombie_scene: PackedScene = preload("res://Enemies/boss/zombie_agis.tscn")
@export var effect_scene: PackedScene = preload("res://Enemies/boss/efects_z.tscn")
@export var wave_delay: float = 8.0
@export var symbolic_damage_taken: int = 5
@export var spawn_range_x: Vector2 = Vector2(4000, 5600)
@export var spawn_y: float = 560.0
@export var zombie_entrance_delay: float = 0.9
@export var zombie_effect_speed_scale: float = 0.55

var is_active: bool = false
var current_wave_index: int = 0
var waves: Array[int] = [4, 6, 8, 10, 12]
var _wave_timer: float = 0.0
var _summoning: bool = false

signal boss_defeated

func _ready() -> void:
	max_health = 15000
	super._ready()
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	play_anim(&"idle")

func _process(_delta: float) -> void:
	if is_dying or sprite == null:
		return
	if _summoning:
		_keep_anim_looping(&"attack")
	else:
		_keep_anim_looping(&"idle")

func _physics_process(delta: float) -> void:
	if not is_active or is_dying:
		return

	if _summoning:
		return

	_wave_timer -= delta
	if _wave_timer <= 0:
		_spawn_wave()

func activate() -> void:
	if is_active: return
	is_active = true
	_wave_timer = 2.0
	play_anim(&"idle")

	var hud = get_tree().current_scene.get_node_or_null("GameplayHUD")
	if hud and hud.has_method("set_boss"):
		hud.set_boss(self)
	if hud and hud.has_method("show_combat_hud"):
		hud.show_combat_hud()

func receive_damage(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_active or is_dying: return
	super.receive_damage(symbolic_damage_taken)

func receive_damage_from_zombie(amount: int) -> void:
	if not is_active or is_dying: return
	super.receive_damage(amount)

func _spawn_wave() -> void:
	_summoning = true
	play_anim(&"attack")

	var count = waves[current_wave_index]

	for i in range(count):
		if is_dying: break

		# Pick a random spot on the arena floor
		var spawn_pos = Vector2(randf_range(spawn_range_x.x, spawn_range_x.y), spawn_y)

		# Spawn individual effect for each zombie
		var effect = effect_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = spawn_pos
		if effect is AnimatedSprite2D:
			effect.speed_scale = zombie_effect_speed_scale

		# Wait for a bit of the effect before spawning zombie
		await get_tree().create_timer(zombie_entrance_delay).timeout

		if is_dying: break

		var zombie = zombie_scene.instantiate()
		get_parent().add_child(zombie)
		zombie.global_position = spawn_pos
		zombie.boss_node = self

		var difficulty = 1.0 + (current_wave_index * 0.15)
		if zombie.has_method("set_difficulty"):
			zombie.set_difficulty(difficulty)

		# Delay between individual spawns in a wave
		await get_tree().create_timer(randf_range(0.2, 0.6)).timeout

	current_wave_index = (current_wave_index + 1) % waves.size()
	if current_wave_index == 0:
		current_wave_index = 1

	_wave_timer = wave_delay
	_summoning = false
	play_anim(&"idle")

func die() -> void:
	if is_dying: return
	is_dying = true
	boss_defeated.emit()
	super.die()

func play_anim(anim_name: StringName) -> void:
	if sprite == null: return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func _keep_anim_looping(anim_name: StringName) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)
