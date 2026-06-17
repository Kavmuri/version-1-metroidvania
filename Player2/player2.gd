extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Movement constants
const SPEED = 300.0
const ACCELERATION = 1200.0
const FRICTION = 1000.0
const AIR_ACCELERATION = 800.0
const AIR_FRICTION = 400.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 1200.0

enum State {Idle, Run, Jump}
var current_state : State = State.Idle

func _physics_process(delta: float):
	apply_gravity(delta)
	handle_jump()
	handle_movement(delta)

	move_and_slide()

	update_state()
	update_animations()

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func handle_jump():
	if Input.is_action_just_pressed("jump_JOY") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func handle_movement(delta: float):
	var direction = Input.get_axis("move_left_JOY", "move_right_JOY")

	var accel = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var friction = FRICTION if is_on_floor() else AIR_FRICTION

	if direction != 0:
		# Smoothly accelerate to speed
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		# Smoothly decelerate to 0
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func update_state():
	if not is_on_floor():
		current_state = State.Jump
	elif velocity.x != 0:
		current_state = State.Run
	else:
		current_state = State.Idle

func update_animations():
	match current_state:
		State.Idle:
			animated_sprite_2d.play("idleP2")
		State.Run:
			animated_sprite_2d.play("runP2")
		State.Jump:
			animated_sprite_2d.play("jumpP2")
