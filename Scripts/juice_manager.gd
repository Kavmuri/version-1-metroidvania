extends Node

var _hit_stop_active: bool = false

func screen_shake(strength: float = 4.0, duration: float = 0.15) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var original_offset: Vector2 = camera.offset
	var tween := create_tween()
	var steps: int = 6
	for i in range(steps):
		var shake_offset: Vector2 = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(camera, "offset", original_offset + shake_offset, duration / float(steps))
	tween.tween_property(camera, "offset", original_offset, duration / float(steps))

func hit_stop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false
