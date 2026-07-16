extends CharacterBody2D

@export var drip_interval: float = 1.2

@onready var _drip_particles: CPUParticles2D = get_node_or_null("DripParticles") as CPUParticles2D

var _timer: float = 0.0

func _ready() -> void:
	_timer = drip_interval

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = drip_interval
		_emit_drop()

func _emit_drop() -> void:
	if _drip_particles == null:
		return
	_drip_particles.restart()
	_drip_particles.emitting = true
