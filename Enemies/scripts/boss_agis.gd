extends "res://Enemies/scripts/enemy_base.gd"

@export var boss_name: String = "Agis"
@export var zombie_scene: PackedScene = preload("res://Enemies/boss/zombie_agis.tscn")
@export var effect_scene: PackedScene = preload("res://Enemies/boss/efects_z.tscn")
@export var wave_delay: float = 5.0
@export var symbolic_damage_taken: int = 5

var is_active: bool = false
var current_wave_index: int = 0
var waves: Array[int] = [4, 6, 8, 10, 12]
var _wave_timer: float = 0.0
var _summoning: bool = false

signal boss_defeated

func _ready() -> void:
	max_health = 15000 # High HP, mainly reduced by killing zombies
	super._ready()
	visible = true # Agis exists in level
	process_mode = Node.PROCESS_MODE_PAUSABLE

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
	_wave_timer = 1.0 # Start first wave soon

	# Register boss in HUD if possible
	var hud = get_tree().current_scene.get_node_or_null("GameplayHUD")
	if hud and hud.has_method("set_boss"):
		hud.set_boss(self)

func receive_damage(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_active or is_dying: return
	# Players deal symbolic damage
	super.receive_damage(symbolic_damage_taken)

func receive_damage_from_zombie(amount: int) -> void:
	if not is_active or is_dying: return
	super.receive_damage(amount)

func _spawn_wave() -> void:
	_summoning = true
	play_anim(&"attack") # Use attack for summoning

	var count = waves[current_wave_index]

	# Spawn effect first
	var effect = effect_scene.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position + Vector2(0, 140) # Adjust based on Agis size

	await get_tree().create_timer(0.5).timeout

	for i in range(count):
		var zombie = zombie_scene.instantiate()
		get_parent().add_child(zombie)
		# Spread zombies slightly around the effect position
		zombie.global_position = effect.global_position + Vector2(randf_range(-40, 40), 0)
		zombie.boss_node = self
		# Scale difficulty based on wave index or time
		var difficulty = 1.0 + (current_wave_index * 0.1)
		if zombie.has_method("set_difficulty"):
			zombie.set_difficulty(difficulty)
		await get_tree().create_timer(0.2).timeout

	current_wave_index = (current_wave_index + 1) % waves.size()
	if current_wave_index == 0:
		current_wave_index = 1 # Restart from 6 as requested (cycle: 4, 6, 8, 10, 12, then 6...)

	_wave_timer = wave_delay
	_summoning = false
	play_anim(&"idle")

func die() -> void:
	if is_dying: return
	is_dying = true
	boss_defeated.emit()
	# Handle Agis death (explosion, fade out, etc.)
	# For now just use base death
	super.die()

func play_anim(anim_name: StringName) -> void:
	if sprite == null: return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
