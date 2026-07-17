extends "res://Enemies/scripts/enemy_base.gd"

@export var boss_name: String = "Dark Sun Agis Guardián Corrupto del Hollow"
@export var zombie_scene: PackedScene = preload("res://Enemies/boss/zombie_agis.tscn")
@export var effect_scene: PackedScene = preload("res://Enemies/boss/efects_z.tscn")
@export var symbolic_damage_taken: int = 5
@export var spawn_range_x: Vector2 = Vector2(4000, 5600)
@export var spawn_y: float = 560.0
@export var zombie_entrance_delay: float = 0.9
@export var zombie_effect_speed_scale: float = 0.55
@export var horde_spawn_margin: float = 400.0
@export var death_teleport_delay: float = 5.0
@export var idle_attack_delay: float = 3.0
@export var transition_flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)

const ATTACK_NAMES: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"attack4"]
const ATTACK_HORDE_COUNTS: Dictionary = {
	&"attack1": 10,
	&"attack2": 4,
	&"attack3": 12,
	&"attack4": 18,
}
const HEALTH_THRESHOLDS: Array[float] = [90.0, 80.0, 70.0, 60.0, 50.0, 30.0, 20.0, 5.0]

signal boss_defeated

@onready var _zombie_spawn_zone: Area2D = get_node_or_null("ZombieSpawnZone") as Area2D

var is_active: bool = false
var _next_threshold_index: int = 0
var _current_animation: StringName = &""
var _queued_animation: StringName = &""
var _animation_locked: bool = false
var _base_modulate: Color = Color(1, 1, 1, 1)
var _flash_tween: Tween = null

func _ready() -> void:
	max_health = 15000
	show_world_health_bar = false
	super._ready()
	visible = false
	# enemy_base.gd::_ready() already called play_anim("idle") via virtual dispatch,
	# which locked the animation state before teleportIN ever gets a chance to play.
	# Clear that so begin_teleport_in() is guaranteed to be the first real animation.
	_current_animation = &""
	_animation_locked = false
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if sprite != null:
		_base_modulate = sprite.modulate

func begin_teleport_in() -> void:
	if visible:
		return
	visible = true
	play_anim(&"teleportIN")

func activate() -> void:
	if is_active:
		return
	is_active = true

	var hud: Node = get_tree().current_scene.get_node_or_null("GameplayHUD")
	if hud and hud.has_method("set_boss"):
		hud.set_boss(self)
	if hud and hud.has_method("show_combat_hud"):
		hud.show_combat_hud()
	if hud != null:
		var top_bar: Node = hud.get_node_or_null("TopBar")
		if top_bar != null:
			top_bar.visible = false
		var bar_container: Node = hud.get_node_or_null("BossContainer/BarContainer")
		if bar_container != null:
			bar_container.visible = false

	var agis_hud: Node = get_tree().current_scene.get_node_or_null("AgisHUD")
	if agis_hud != null:
		agis_hud.visible = true

	if _current_animation == &"idle":
		_schedule_next_attack()

func receive_damage(_amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_active or is_dying:
		return
	_apply_damage(symbolic_damage_taken)

func receive_damage_from_zombie(amount: int) -> void:
	if not is_active or is_dying:
		return
	_apply_damage(amount)

func _apply_damage(amount: int) -> void:
	super.receive_damage(amount)
	if is_dying:
		return
	_check_health_thresholds()

func _check_health_thresholds() -> void:
	if _next_threshold_index >= HEALTH_THRESHOLDS.size():
		return
	var percent: float = (float(health) / float(max_health)) * 100.0
	while _next_threshold_index < HEALTH_THRESHOLDS.size() and percent <= HEALTH_THRESHOLDS[_next_threshold_index]:
		print("[Agis] umbral de vida alcanzado -> ", HEALTH_THRESHOLDS[_next_threshold_index], "%")
		_next_threshold_index += 1

func die() -> void:
	if is_dying:
		return
	is_dying = true
	_disable_damage_areas()
	play_anim(&"teleportOUT")

func play_anim(anim_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return

	if anim_name == _current_animation and (_animation_locked or sprite.is_playing()):
		return

	if _animation_locked:
		_queued_animation = anim_name
		return

	_start_animation(anim_name)

func _start_animation(anim_name: StringName) -> void:
	_current_animation = anim_name
	_queued_animation = &""
	sprite.play(anim_name)
	_flash_transition()
	print("[Agis] estado -> ", anim_name)
	if anim_name == &"idle":
		_animation_locked = false
		if is_active and not is_dying:
			_schedule_next_attack()
	else:
		_animation_locked = true
		_await_transient_animation(anim_name)

func _flash_transition() -> void:
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.modulate = _base_modulate
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", transition_flash_color, 0.05)
	_flash_tween.tween_property(sprite, "modulate", _base_modulate, 0.15)

func _schedule_next_attack() -> void:
	await get_tree().create_timer(idle_attack_delay).timeout
	if is_dying or not is_active:
		return
	if _current_animation != &"idle":
		return
	var attack_name: StringName = ATTACK_NAMES[randi() % ATTACK_NAMES.size()]
	play_anim(attack_name)

func _await_transient_animation(anim_name: StringName) -> void:
	# Attacks stay "busy" for as long as their horde takes to fully spawn (the
	# attack animation loops the whole time), so the next state never starts
	# before that attack's zombies have finished appearing.
	if ATTACK_HORDE_COUNTS.has(anim_name):
		await _spawn_horde(ATTACK_HORDE_COUNTS[anim_name])
	else:
		var duration: float = _animation_duration(anim_name)
		await get_tree().create_timer(duration).timeout

	if _current_animation != anim_name:
		return
	_animation_locked = false
	if _queued_animation != &"":
		var next_anim: StringName = _queued_animation
		_start_animation(next_anim)
		return
	_auto_advance(anim_name)

func _animation_duration(anim_name: StringName) -> float:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return 1.0
	var frames: SpriteFrames = sprite.sprite_frames
	var frame_count: int = frames.get_frame_count(anim_name)
	var fps: float = frames.get_animation_speed(anim_name)
	var total_duration_units: float = 0.0
	for i in range(frame_count):
		total_duration_units += frames.get_frame_duration(anim_name, i)
	return total_duration_units / maxf(fps, 0.01)

func _auto_advance(finished_state: StringName) -> void:
	match finished_state:
		&"teleportIN":
			play_anim(&"idle")
		&"attack1", &"attack2", &"attack3", &"attack4":
			play_anim(&"idle")
		&"teleportOUT":
			_after_teleport_out()
		&"teleport":
			_finish_death()
		_:
			pass

func _after_teleport_out() -> void:
	await get_tree().create_timer(death_teleport_delay).timeout
	play_anim(&"teleport")

func _finish_death() -> void:
	var agis_hud: Node = get_tree().current_scene.get_node_or_null("AgisHUD")
	if agis_hud != null:
		agis_hud.visible = false
	boss_defeated.emit()
	_spawn_death_effect()
	queue_free()

func get_combat_bounds_x() -> Vector2:
	if _zombie_spawn_zone != null:
		var zone_shape: CollisionShape2D = _zombie_spawn_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rect_shape: RectangleShape2D = zone_shape.shape as RectangleShape2D if zone_shape != null else null
		var half_width: float = rect_shape.size.x * 0.5 if rect_shape != null else horde_spawn_margin
		var zone_x: float = _zombie_spawn_zone.global_position.x
		return Vector2(zone_x - half_width, zone_x + half_width)
	var arena_left: float = minf(spawn_range_x.x, spawn_range_x.y)
	var arena_right: float = maxf(spawn_range_x.x, spawn_range_x.y)
	return Vector2(arena_left, arena_right)

func _spawn_horde(count: int) -> void:
	var bounds: Vector2 = get_combat_bounds_x()
	var spawn_left: float = bounds.x
	var spawn_right: float = bounds.y
	var floor_y: float = _zombie_spawn_zone.global_position.y if _zombie_spawn_zone != null else spawn_y

	for i in range(count):
		if is_dying:
			break

		var spawn_pos: Vector2 = Vector2(randf_range(spawn_left, spawn_right), floor_y)

		var effect: Node2D = effect_scene.instantiate() as Node2D
		get_parent().add_child(effect)
		effect.global_position = spawn_pos
		if effect is AnimatedSprite2D:
			effect.speed_scale = zombie_effect_speed_scale

		await get_tree().create_timer(zombie_entrance_delay).timeout

		if is_dying:
			break

		var zombie: Node2D = zombie_scene.instantiate() as Node2D
		get_parent().add_child(zombie)
		zombie.global_position = spawn_pos
		zombie.boss_node = self

		var difficulty: float = 1.0 + (float(_next_threshold_index) * 0.1)
		if zombie.has_method("set_difficulty"):
			zombie.set_difficulty(difficulty)

		await get_tree().create_timer(randf_range(0.2, 0.6)).timeout
