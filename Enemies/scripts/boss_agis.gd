extends "res://Enemies/scripts/enemy_base.gd"

@export var use_animation_visual_offsets: bool = true
@export var animation_visual_offsets: Dictionary = {
	"idle": Vector2.ZERO,
	"attack1": Vector2.ZERO,
	"attack2": Vector2.ZERO,
	"attack3": Vector2.ZERO,
	"attack4": Vector2.ZERO,
	"teleportIN": Vector2.ZERO,
	"teleportOUT": Vector2.ZERO,
	"teleport": Vector2.ZERO
}

@export var boss_name: String = "Agis"
@export var zombie_scene: PackedScene = preload("res://Enemies/boss/zombie_agis.tscn")
@export var effect_scene: PackedScene = preload("res://Enemies/boss/efects_z.tscn")

@export var wave_delay: float = 8.0
@export var symbolic_damage_taken: int = 5

@export var spawn_range_x: Vector2 = Vector2(4000, 5600)
@export var spawn_y: float = 536.0

@export var zombie_entrance_delay: float = 0.9
@export var zombie_effect_speed_scale: float = 0.55

@export var time_between_cleared_waves: float = 5.0
@export var intro_wait_seconds: float = 3.0
@export var attack_animation_gap_seconds: float = 2.0

@export var boss_appearance_delay: float = 3.0
@export var teleport_in_speed_scale: float = 0.75
@export var boss_sprite_offset: Vector2 = Vector2.ZERO

@export var max_alive_zombies: int = 24
@export var min_spawn_interval_during_attack: float = 0.08

enum AgisState {
	HIDDEN,
	INTRO,
	IDLE,
	ATTACK_ANIMATION,
	ATTACK_RECOVERY,
	SUMMONING,
	COOLDOWN,
	DEAD
}

var is_active: bool = false
var current_wave_index: int = 0

var waves: Array[int] = [4, 6, 8, 10, 12]
var wave_animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"attack4"]

var _wave_timer: float = 0.0
var _alive_wave_zombies: int = 0
var _reserved_zombie_spawns: int = 0

var _current_action_anim: StringName = &"idle"
var _state: int = AgisState.HIDDEN
var _action_running: bool = false

var _sprite_base_position: Vector2 = Vector2.ZERO
var _sprite_default_speed_scale: float = 1.0
var _can_receive_damage: bool = false

signal boss_defeated


func _ready() -> void:
	max_health = 15000

	if sprite != null:
		_sprite_base_position = sprite.position
		_sprite_default_speed_scale = sprite.speed_scale

	super._ready()

	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_disable_generic_state_machine()
	_configure_boss_animation_loops()
	_apply_boss_sprite_offset(&"idle")

	play_anim(&"idle")

func _process(_delta: float) -> void:
	if is_dying or sprite == null:
		return

	if _state == AgisState.IDLE or _state == AgisState.ATTACK_RECOVERY or _state == AgisState.COOLDOWN:
		_keep_anim_looping(&"idle")


func _physics_process(delta: float) -> void:
	if not is_active or is_dying:
		return

	if _state != AgisState.IDLE:
		return

	if _action_running:
		return

	_wave_timer -= delta

	if _wave_timer <= 0.0:
		_run_wave_state()


func activate() -> void:
	if is_active:
		return

	is_active = true
	visible = false
	_can_receive_damage = false
	_wave_timer = 0.0
	_state = AgisState.INTRO

	call_deferred("_delayed_boss_start")
	
func _delayed_boss_start() -> void:
	if boss_appearance_delay > 0.0:
		var ok: bool = await _wait_seconds_safe(boss_appearance_delay)
		if not ok:
			return

	if is_dying or not is_active:
		return

	visible = true

	await _play_intro_state()

	if is_dying or not is_active:
		return

	_can_receive_damage = true

	var hud: Node = get_tree().current_scene.get_node_or_null("GameplayHUD")
	if hud and hud.has_method("set_boss"):
		hud.set_boss(self)
	if hud and hud.has_method("show_combat_hud"):
		hud.show_combat_hud()

func receive_damage(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_active or is_dying:
		return

	if not _can_receive_damage:
		return

	_apply_boss_damage_without_cutting_animation(symbolic_damage_taken)


func receive_damage_from_zombie(amount: int) -> void:
	if not is_active or is_dying:
		return

	if not _can_receive_damage:
		return

	_apply_boss_damage_without_cutting_animation(amount)


func _apply_boss_damage_without_cutting_animation(amount: int) -> void:
	var should_restore_attack: bool = _state == AgisState.ATTACK_ANIMATION and sprite != null and _has_anim(_current_action_anim)
	var saved_anim: StringName = _current_action_anim
	var saved_frame: int = 0
	var saved_progress: float = 0.0

	if should_restore_attack:
		saved_frame = sprite.frame
		saved_progress = sprite.frame_progress

	super.receive_damage(amount)

	if should_restore_attack and not is_dying and _state == AgisState.ATTACK_ANIMATION:
		call_deferred("_restore_action_animation", saved_anim, saved_frame, saved_progress)


func _restore_action_animation(anim_name: StringName, frame: int, frame_progress: float) -> void:
	if is_dying:
		return

	if _state != AgisState.ATTACK_ANIMATION:
		return

	if not _has_anim(anim_name):
		return

	_apply_boss_sprite_offset()

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	sprite.play(anim_name)
	sprite.frame = clampi(frame, 0, frame_count - 1)
	sprite.frame_progress = clampf(frame_progress, 0.0, 1.0)


func _run_wave_state() -> void:
	if _action_running or is_dying or not is_active:
		return

	_action_running = true
	_state = AgisState.ATTACK_ANIMATION

	var wave_index: int = current_wave_index
	var attack_anim: StringName = _get_wave_animation_for_index(wave_index)

	_current_action_anim = attack_anim

	await _play_animation_once(attack_anim)

	if is_dying or not is_active:
		_finish_wave_action()
		return

	_state = AgisState.ATTACK_RECOVERY
	play_anim(&"idle")

	if attack_animation_gap_seconds > 0.0:
		var ok: bool = await _wait_seconds_safe(attack_animation_gap_seconds)
		if not ok or is_dying or not is_active:
			_finish_wave_action()
			return

	_state = AgisState.SUMMONING
	await _spawn_wave(wave_index)

	if is_dying or not is_active:
		_finish_wave_action()
		return

	current_wave_index = (current_wave_index + 1) % waves.size()

	play_anim(&"idle")
	_state = AgisState.IDLE
	_wave_timer = time_between_cleared_waves

	_action_running = false


func _finish_wave_action() -> void:
	_action_running = false
	if not is_dying and is_active:
		_state = AgisState.IDLE
		_wave_timer = time_between_cleared_waves


func _spawn_wave(wave_index: int) -> void:
	if zombie_scene == null:
		push_warning("Agis no tiene zombie_scene asignado.")
		return

	var count: int = _get_wave_count_for_index(wave_index)

	var available_slots: int = max_alive_zombies - (_alive_wave_zombies + _reserved_zombie_spawns)
	count = mini(count, maxi(available_slots, 0))

	if count <= 0:
		return

	var spawn_interval: float = maxf(min_spawn_interval_during_attack, zombie_entrance_delay)

	for i in range(count):
		if is_dying or not is_active:
			break

		var spawn_pos: Vector2 = _get_random_spawn_position()

		_reserved_zombie_spawns += 1

		_spawn_effect(spawn_pos)

		var ok: bool = await _wait_seconds_safe(zombie_entrance_delay)

		_reserved_zombie_spawns = maxi(_reserved_zombie_spawns - 1, 0)

		if not ok or is_dying or not is_active:
			break

		if _alive_wave_zombies < max_alive_zombies:
			var zombie: Node2D = zombie_scene.instantiate() as Node2D
			get_parent().add_child(zombie)

			zombie.global_position = spawn_pos
			zombie.boss_node = self

			_alive_wave_zombies += 1
			zombie.tree_exited.connect(Callable(self, "_on_wave_zombie_exited"), CONNECT_ONE_SHOT)

			var difficulty: float = 1.0 + (wave_index * 0.15)
			if zombie.has_method("set_difficulty"):
				zombie.set_difficulty(difficulty)

		if i < count - 1:
			ok = await _wait_seconds_safe(spawn_interval)
			if not ok:
				break


func _spawn_effect(spawn_pos: Vector2) -> void:
	if effect_scene == null:
		return

	var effect: Node2D = effect_scene.instantiate() as Node2D
	get_parent().add_child(effect)
	effect.global_position = spawn_pos

	if effect is AnimatedSprite2D:
		var effect_sprite: AnimatedSprite2D = effect as AnimatedSprite2D
		effect_sprite.speed_scale = zombie_effect_speed_scale
	else:
		var child_sprite: AnimatedSprite2D = effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if child_sprite != null:
			child_sprite.speed_scale = zombie_effect_speed_scale


func _get_random_spawn_position() -> Vector2:
	var spawn_left: float = minf(spawn_range_x.x, spawn_range_x.y)
	var spawn_right: float = maxf(spawn_range_x.x, spawn_range_x.y)
	return Vector2(randf_range(spawn_left, spawn_right), spawn_y)


func _get_wave_count_for_index(index: int) -> int:
	if waves.is_empty():
		return 4

	return waves[index % waves.size()]


func _play_intro_state() -> void:
	_state = AgisState.INTRO
	_apply_boss_sprite_offset(&"teleportIN")

	if _has_anim(&"teleportIN"):
		await _play_animation_once_with_speed(&"teleportIN", teleport_in_speed_scale, false)

	if is_dying:
		return

	play_anim(&"idle")

	var ok: bool = await _wait_seconds_safe(intro_wait_seconds)
	if not ok:
		return

	if is_dying:
		return

	_state = AgisState.IDLE
	_wave_timer = 0.0

func _on_wave_zombie_exited() -> void:
	_alive_wave_zombies = maxi(_alive_wave_zombies - 1, 0)


func _get_wave_animation_for_index(index: int) -> StringName:
	if wave_animations.is_empty():
		return &"attack1"

	var anim_name: StringName = wave_animations[index % wave_animations.size()]

	if _has_anim(anim_name):
		return anim_name

	var fallback_animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"attack4", &"teleportIN", &"teleportOUT"]

	for fallback in fallback_animations:
		if _has_anim(fallback):
			return fallback

	return &"idle"


func die() -> void:
	if is_dying:
		return

	is_dying = true
	is_active = false
	_action_running = false
	_can_receive_damage = false
	_state = AgisState.DEAD

	_disable_damage_areas()

	if _has_anim(&"teleportOUT"):
		await _play_animation_once(&"teleportOUT")

	_spawn_final_teleport_effect()

	boss_defeated.emit()
	queue_free()


func play_anim(anim_name: StringName) -> void:
	if sprite == null:
		return

	if _has_anim(anim_name):
		_apply_boss_sprite_offset(anim_name)
		sprite.play(anim_name)


func _keep_anim_looping(anim_name: StringName) -> void:
	if not _has_anim(anim_name):
		return

	_apply_boss_sprite_offset(anim_name)

	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


func _has_anim(anim_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func _play_animation_once(anim_name: StringName, cancel_when_dying: bool = true) -> void:
	if not _has_anim(anim_name):
		await _wait_seconds_safe(0.8)
		return

	if not is_inside_tree() or get_tree() == null:
		return

	_apply_boss_sprite_offset(anim_name)

	sprite.sprite_frames.set_animation_loop(anim_name, false)

	sprite.stop()
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play(anim_name)

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0:
		return

	var safety_duration: float = maxf(_get_animation_length(anim_name) * 2.0, _get_animation_length(anim_name) + 1.5)
	var elapsed: float = 0.0

	while elapsed < safety_duration:
		if cancel_when_dying and is_dying:
			return

		var ok: bool = await _wait_process_frame_safe()
		if not ok:
			return

		if sprite == null or not _has_anim(anim_name):
			return

		elapsed += get_process_delta_time()

		if sprite.animation != anim_name:
			sprite.play(anim_name)

		if not sprite.is_playing() and sprite.frame < frame_count - 1:
			sprite.play(anim_name)

		if sprite.frame >= frame_count - 1:
			await _wait_seconds_safe(0.12)
			return


func _play_animation_once_with_speed(anim_name: StringName, temporary_speed_scale: float, cancel_when_dying: bool = true) -> void:
	if sprite == null:
		return

	var previous_speed_scale: float = sprite.speed_scale
	sprite.speed_scale = maxf(temporary_speed_scale, 0.05)

	await _play_animation_once(anim_name, cancel_when_dying)

	if sprite != null:
		sprite.speed_scale = previous_speed_scale


func _seek_sprite_animation_time(anim_name: StringName, time_seconds: float) -> void:
	if not _has_anim(anim_name):
		return

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0:
		return

	var animation_speed: float = maxf(sprite.sprite_frames.get_animation_speed(anim_name), 0.01)
	var sprite_speed: float = maxf(sprite.speed_scale, 0.01)

	var frame_float: float = time_seconds * animation_speed * sprite_speed
	frame_float = clampf(frame_float, 0.0, float(frame_count) - 0.001)

	var target_frame: int = int(floor(frame_float))
	var target_progress: float = frame_float - float(target_frame)

	sprite.frame = clampi(target_frame, 0, frame_count - 1)
	sprite.frame_progress = clampf(target_progress, 0.0, 1.0)


func _configure_boss_animation_loops() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	for anim_name in wave_animations:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.sprite_frames.set_animation_loop(anim_name, false)

	var one_shot_animations: Array[StringName] = [&"attack1", &"attack2", &"attack3", &"attack4", &"teleportIN", &"teleportOUT"]

	for anim_name in one_shot_animations:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.sprite_frames.set_animation_loop(anim_name, false)

	if sprite.sprite_frames.has_animation(&"idle"):
		sprite.sprite_frames.set_animation_loop(&"idle", true)

	if sprite.sprite_frames.has_animation(&"teleport"):
		sprite.sprite_frames.set_animation_loop(&"teleport", false)


func _apply_boss_sprite_offset(anim_name: StringName = &"") -> void:
	if sprite == null:
		return

	var target_anim: StringName = anim_name

	if target_anim == &"":
		target_anim = sprite.animation

	var extra_offset: Vector2 = Vector2.ZERO

	if use_animation_visual_offsets:
		var key: String = String(target_anim)
		if animation_visual_offsets.has(key):
			extra_offset = animation_visual_offsets[key]

	sprite.position = _sprite_base_position + boss_sprite_offset + extra_offset

func _disable_generic_state_machine() -> void:
	var state_machine_nodes: Array[String] = ["StateMachine", "StateMachineController"]

	for node_name in state_machine_nodes:
		var node: Node = get_node_or_null(node_name)

		if node != null:
			node.set_process(false)
			node.set_physics_process(false)
			node.process_mode = Node.PROCESS_MODE_DISABLED

	var attack_area: Area2D = get_node_or_null("AttackArea2D") as Area2D
	if attack_area != null:
		attack_area.set_deferred("monitoring", false)
		attack_area.set_deferred("monitorable", false)


func _spawn_final_teleport_effect() -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"teleport"):
		return

	var effect: AnimatedSprite2D = AnimatedSprite2D.new()
	effect.name = "AgisFinalTeleport"
	effect.sprite_frames = sprite.sprite_frames
	effect.animation = &"teleport"
	effect.scale = sprite.scale
	effect.z_index = sprite.z_index

	get_parent().add_child(effect)
	effect.global_position = sprite.global_position
	effect.play(&"teleport")

	var effect_lifetime: float = _get_animation_length(&"teleport")
	effect.get_tree().create_timer(effect_lifetime).timeout.connect(Callable(effect, "queue_free"))


func _get_animation_length(anim_name: StringName) -> float:
	if not _has_anim(anim_name):
		return 0.8

	var frame_count: int = sprite.sprite_frames.get_frame_count(anim_name)
	var speed: float = maxf(sprite.sprite_frames.get_animation_speed(anim_name), 0.01)
	var sprite_speed: float = maxf(sprite.speed_scale, 0.01)

	return float(frame_count) / speed / sprite_speed

func _wait_process_frame_safe() -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false

	var tree: SceneTree = get_tree()

	if tree == null:
		return false

	await tree.process_frame

	if not is_inside_tree() or is_queued_for_deletion():
		return false

	return true


func _wait_seconds_safe(seconds: float) -> bool:
	if seconds <= 0.0:
		return is_inside_tree() and not is_queued_for_deletion()

	if not is_inside_tree() or is_queued_for_deletion():
		return false

	var tree: SceneTree = get_tree()

	if tree == null:
		return false

	await tree.create_timer(seconds).timeout

	if not is_inside_tree() or is_queued_for_deletion():
		return false

	return true
