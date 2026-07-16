extends AnimatableBody2D

const GLOW_TEXTURE := preload("res://Assets/Fx/light_glow.png")

@export var move_offset: Vector2 = Vector2(0, -284)
@export var move_duration: float = 4.0
@export var glow_energy: float = 0.9
@export var glow_scale: float = 1.2

var _start_position: Vector2
var _elapsed: float = 0.0
var _going_up: bool = true

func _ready() -> void:
	sync_to_physics = true
	_start_position = position
	_add_glow()

func _add_glow() -> void:
	if has_node("GlowLight"):
		return
	var light := PointLight2D.new()
	light.name = "GlowLight"
	light.texture = GLOW_TEXTURE
	light.color = Color(1.0, 1.0, 1.0, 1.0)
	light.energy = glow_energy
	light.texture_scale = glow_scale
	add_child(light)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / move_duration, 0.0, 1.0)
	var eased_t: float = (sin((t - 0.5) * PI) * 0.5) + 0.5
	var end_position: Vector2 = _start_position + move_offset

	if _going_up:
		position = _start_position.lerp(end_position, eased_t)
	else:
		position = end_position.lerp(_start_position, eased_t)

	if t >= 1.0:
		_elapsed = 0.0
		_going_up = not _going_up
