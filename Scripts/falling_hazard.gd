extends CharacterBody2D

const GLOW_TEXTURE := preload("res://Assets/Fx/light_glow.png")

@export var fall_delay: float = 0.0
@export var fall_acceleration: float = 600.0
@export var max_fall_speed: float = 900.0
@export var contact_damage: int = 1
@export var glow_blinks: int = 2
@export var glow_duration: float = 0.25
@export var glow_color: Color = Color(2.5, 2.5, 2.5, 1.0)
@export var ambient_glow_energy: float = 0.7
@export var ambient_glow_scale: float = 1.0

@onready var _contact_area: Area2D = get_node_or_null("ContactArea") as Area2D
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _particles: CPUParticles2D = get_node_or_null("DisappearParticles") as CPUParticles2D

var _landed: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	if _contact_area != null:
		_contact_area.body_entered.connect(_on_contact_body_entered)
	_add_ambient_glow()

func _add_ambient_glow() -> void:
	if has_node("GlowLight"):
		return
	var light := PointLight2D.new()
	light.name = "GlowLight"
	light.texture = GLOW_TEXTURE
	light.color = Color(1.0, 1.0, 1.0, 1.0)
	light.energy = ambient_glow_energy
	light.texture_scale = ambient_glow_scale
	add_child(light)

func _physics_process(delta: float) -> void:
	if _landed:
		return
	if _elapsed < fall_delay:
		_elapsed += delta
		return
	velocity.y = min(velocity.y + fall_acceleration * delta, max_fall_speed)
	velocity.x = 0.0
	move_and_slide()
	if is_on_floor():
		_landed = true
		velocity = Vector2.ZERO
		_play_glow_and_disappear()

func _play_glow_and_disappear() -> void:
	if _particles != null:
		_particles.emitting = true
	if _sprite == null:
		queue_free()
		return
	var normal_color: Color = _sprite.modulate
	var tween := create_tween()
	for i in glow_blinks:
		tween.tween_property(_sprite, "modulate", glow_color, glow_duration)
		tween.tween_property(_sprite, "modulate", normal_color, glow_duration)
	tween.tween_callback(queue_free)

func _on_contact_body_entered(body: Node2D) -> void:
	if body.has_method("receive_damage"):
		body.receive_damage(contact_damage, global_position)
