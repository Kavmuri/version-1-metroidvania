extends Area2D

@export var speed: float = 480.0
@export var damage: int = 1
@export var lifetime: float = 1.2

var direction: float = 1.0
var travel_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += travel_direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

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

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if body.has_method("receive_damage"):
		body.receive_damage(damage, global_position)
		queue_free()
	elif body.has_method("recibir_daño"):
		body.recibir_daño(damage, global_position)
		queue_free()
	else:
		queue_free()
