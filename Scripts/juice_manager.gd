extends Node

var _shake_camera: Camera2D = null
var _camera_base_offset := Vector2.ZERO
var _shake_time_left := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0

var _hit_stop_active := false

func _process(delta: float) -> void:
	_update_shake(delta)

func _update_shake(delta: float) -> void:
	if _shake_time_left <= 0.0:
		return
	_shake_time_left = max(_shake_time_left - delta, 0.0)
	if _shake_camera == null or not is_instance_valid(_shake_camera):
		_shake_time_left = 0.0
		return
	if _shake_time_left <= 0.0:
		_shake_camera.offset = _camera_base_offset
		return
	var progress := _shake_time_left / _shake_duration
	var current_strength := _shake_strength * progress
	_shake_camera.offset = _camera_base_offset + Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * current_strength

func screen_shake(strength: float = 6.0, duration: float = 0.2) -> void:
	var camera := get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera == null:
		return
	if _shake_camera != camera:
		_shake_camera = camera
		_camera_base_offset = camera.offset
	if strength < _shake_strength * (_shake_time_left / max(_shake_duration, 0.01)):
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_time_left = duration

func hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	if duration <= 0.0 or _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = time_scale
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hit_stop, CONNECT_ONE_SHOT)

func _end_hit_stop() -> void:
	Engine.time_scale = 1.0
	_hit_stop_active = false

func flash_sprite(sprite: CanvasItem, flash_color: Color = Color(1, 1, 1), duration: float = 0.08) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var original_modulate: Color = sprite.modulate
	sprite.modulate = flash_color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, duration)

func spawn_hit_particles(global_pos: Vector2, color: Color = Color(1, 1, 1), amount: int = 10) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var particles := CPUParticles2D.new()
	particles.global_position = global_pos
	particles.z_index = 4000
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 420)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = color
	scene_root.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free, CONNECT_ONE_SHOT)
