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
const DASH_SPEED = 700.0
const DASH_TIME = 0.16

enum State {Idle, Run, Jump}
var current_state : State = State.Idle
var tiene_salto_infinito: bool = false
var tiene_dash: bool = false
var dash_timer: float = 0.0
var dash_direction: float = 1.0

func _physics_process(delta: float):
	apply_gravity(delta)
	handle_jump()
	handle_dash(delta)
	handle_movement(delta)

	move_and_slide()

	update_state()
	update_animations()

func apply_gravity(delta: float):
	if not is_on_floor() and dash_timer <= 0.0:
		velocity.y += GRAVITY * delta

func handle_jump():
	if not Input.is_action_just_pressed("jump"):
		return

	if is_on_floor():
		velocity.y = JUMP_VELOCITY
	elif tiene_salto_infinito:
		velocity.y = JUMP_VELOCITY

func handle_dash(delta: float):
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0
		return

	if tiene_dash and Input.is_action_just_pressed("dash"):
		var direction = Input.get_axis("move_left", "move_right")
		if direction == 0:
			direction = -1.0 if animated_sprite_2d.flip_h else 1.0
		dash_direction = direction
		dash_timer = DASH_TIME
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0

func handle_movement(delta: float):
	if dash_timer > 0.0:
		return

	var direction = Input.get_axis("move_left", "move_right")

	var accel = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var friction = FRICTION if is_on_floor() else AIR_FRICTION

	if direction != 0:
		# Smoothly accelerate to speed
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		# Smoothly decelerate to 0
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func activar_debug_habilidades():
	tiene_salto_infinito = true
	tiene_dash = true

func set_salto_infinito_activo(activo: bool) -> void:
	tiene_salto_infinito = activo

func set_dash_activo(activo: bool) -> void:
	tiene_dash = activo
	if not activo:
		dash_timer = 0.0

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
			animated_sprite_2d.play("idle")
		State.Run:
			animated_sprite_2d.play("run")
		State.Jump:
			animated_sprite_2d.play("jump")
