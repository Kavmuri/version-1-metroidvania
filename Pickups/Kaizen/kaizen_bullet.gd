extends Node2D

@export var speed: float = 480.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var impact_scene: PackedScene
@export var pierce_count: int = 0
@export var bounce_count: int = 0
@export var wave_amplitude: float = 0.0
@export var wave_frequency: float = 8.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cleanup_timer: Timer = $Timer
@onready var hitbox: Area2D = $Hitbox

var direction: float = 1.0
var travel_direction: Vector2 = Vector2.RIGHT
var _has_hit := false
var _hit_targets: Array[Node2D] = []
var _age := 0.0

func _ready() -> void:
	cleanup_timer.start(lifetime)
	sprite.play(&"shot")

func _physics_process(delta: float) -> void:
	_age += delta
	var movement := travel_direction * speed * delta
	if wave_amplitude > 0.0:
		var perpendicular := Vector2(-travel_direction.y, travel_direction.x)
		movement += perpendicular * sin(_age * wave_frequency) * wave_amplitude * delta
	global_position += movement

func setup(projectile_direction, projectile_damage: int) -> void:
	if projectile_direction is Vector2:
		travel_direction = projectile_direction.normalized()
	else:
		direction = sign(float(projectile_direction))
		if direction == 0.0:
			direction = 1.0
		travel_direction = Vector2(direction, 0)
	if travel_direction == Vector2.ZERO:
		travel_direction = Vector2.RIGHT
	damage = projectile_damage
	rotation = travel_direction.angle()

func get_damage_amount() -> int:
	return damage

func _on_timer_timeout() -> void:
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == null:
		return
	try_apply_damage_to(body)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == null:
		return
	if area.name != &"Hurtbox":
		return
	var target := area.get_parent() as Node2D
	if target == null:
		return
	try_apply_damage_to(target)

func try_apply_damage_to(target: Node2D) -> bool:
	if _has_hit or _hit_targets.has(target):
		return false
	if target.has_method("receive_damage"):
		target.receive_damage(get_damage_amount(), global_position)
		_spawn_impact()
		_hit_targets.append(target)
		if pierce_count > 0:
			pierce_count -= 1
			return true
		_has_hit = true
		queue_free()
		return true
	if bounce_count > 0:
		bounce_count -= 1
		travel_direction = -travel_direction
		rotation = travel_direction.angle()
		_spawn_impact()
		return false
	_has_hit = true
	_spawn_impact()
	queue_free()
	return false

func _spawn_impact() -> void:
	if impact_scene == null:
		return
	var impact := impact_scene.instantiate() as Node2D
	if impact == null:
		return
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
	impact.rotation = rotation
