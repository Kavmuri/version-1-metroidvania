extends AnimatedSprite2D

@export var speed: float = 480.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var impact_scene: PackedScene

@onready var cleanup_timer: Timer = $Timer
@onready var hitbox: Area2D = $Hitbox

var direction: float = 1.0
var travel_direction: Vector2 = Vector2.RIGHT
var _has_hit := false

func _ready() -> void:
	cleanup_timer.start(lifetime)
	play(&"shot")

func _physics_process(delta: float) -> void:
	global_position += travel_direction * speed * delta

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
	if _has_hit:
		return false
	_has_hit = true
	if target.has_method("receive_damage"):
		target.receive_damage(get_damage_amount(), global_position)
		_spawn_impact()
		queue_free()
		return true
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
