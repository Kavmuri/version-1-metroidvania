extends CharacterBody2D


@export var patrol_points : Node
@export var speed : int = 25
@export var wait_time : int = 3

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer


const GRAVITY = 1000



enum State {Idle, Walk}

var current_state : State
var direction : Vector2 = Vector2.LEFT
var number_of_points : int
var point_positions : Array[Vector2]
var current_point : Vector2
var current_point_positions : int = 0
var can_walk : bool = false


func _ready():
	if patrol_points != null:
		number_of_points = patrol_points.get_children().size()
		for point in patrol_points.get_children():
			point_positions.append(point.global_position)
		current_point = point_positions[current_point_positions]
	else:
		print("No patrol points")
	timer.wait_time = wait_time

	current_state = State.Idle

	timer.start()

func _physics_process(delta):
	enemy_gravity(delta)


	match current_state:
		State.Idle:
			enemy_idle(delta)

		State.Walk:
			enemy_walk(delta)

	move_and_slide()
	enemy_animations()


func enemy_gravity(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta


func enemy_idle(delta):
	velocity.x = move_toward(velocity.x,0, speed * delta)


func enemy_walk(delta):
	var distance = abs(position.x - current_point.x)
	if distance > 0.5:
		velocity.x = direction.x * speed



	else:
		current_point_positions += 1

		if current_point_positions >= number_of_points:
			current_point_positions = 0

		current_point = point_positions[current_point_positions]



		current_state = State.Idle
		can_walk = false
		timer.start()


	if current_point.x > position.x:
		direction = Vector2.RIGHT

	else:
		direction = Vector2.LEFT
	animated_sprite_2d.flip_h = direction.x > 0



func enemy_animations():
	if current_state == State.Idle:
		animated_sprite_2d.play("idle")

	elif current_state == State.Walk:
		animated_sprite_2d.play("walk")


func _on_timer_timeout():

	can_walk = true
	current_state = State.Walk
