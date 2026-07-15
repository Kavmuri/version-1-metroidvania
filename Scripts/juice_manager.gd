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

func show_speech_bubble(target: Node2D, text: String, duration: float = 2.4) -> void:
	if target == null or not is_instance_valid(target):
		return
	var existing := target.get_node_or_null("SpeechBubble")
	if existing != null:
		existing.queue_free()

	var bubble := PanelContainer.new()
	bubble.name = "SpeechBubble"
	bubble.z_index = 500
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_color = Color(0, 0, 0, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	bubble.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var arial_font := SystemFont.new()
	arial_font.font_names = ["Arial"]
	label.add_theme_font_override("font", arial_font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(140, 0)
	bubble.add_child(label)

	target.add_child(bubble)
	bubble.position = Vector2(-70, -92)
	bubble.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(bubble, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.queue_free)

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
