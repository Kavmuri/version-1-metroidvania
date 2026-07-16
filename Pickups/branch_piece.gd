extends Node2D

@export var flash_blinks: int = 2
@export var flash_duration: float = 0.06
@export var flash_color: Color = Color(2.5, 2.5, 2.5, 1.0)
@export var rise_distance: float = 120.0
@export var move_duration: float = 1.4

@onready var _particles: CPUParticles2D = get_node_or_null("DissolveParticles") as CPUParticles2D

var _opened := false

func open() -> void:
	if _opened:
		return
	_opened = true

	var normal_color: Color = modulate
	var tween := create_tween()
	for i in flash_blinks:
		tween.tween_property(self, "modulate", flash_color, flash_duration)
		tween.tween_property(self, "modulate", normal_color, flash_duration)
	tween.tween_callback(_start_dissolve)

func _start_dissolve() -> void:
	if _particles != null:
		_particles.emitting = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - rise_distance, move_duration)
	tween.tween_property(self, "modulate:a", 0.0, move_duration)
	tween.chain().tween_callback(func(): visible = false)
