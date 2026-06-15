extends CharacterBody2D


@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


const GRAVITY = 1000


@export var speed : int = 400
@export var max_horizontal_speed : int = 300
@export var slow_sown_speed : int = 1000

@export var jump : int = -300
@export var jump_horizontal_speed : int = 100
@export var max_jump_horizontal_speed : int = 100



enum State {Idle, Run, Jump}


var current_state : State



func _ready():

	current_state = State.Idle




func _physics_process(delta : float):

	player_falling(delta)

	player_jump()


	match current_state:


		State.Idle:

			player_idle(delta)


		State.Run:

			player_run(delta)


		State.Jump:

			player_jump_state(delta)



	move_and_slide()


	update_state_after_movement()

	player_animations()





func player_falling(delta : float):

	if !is_on_floor():

		velocity.y += GRAVITY * delta





func player_jump():

	if Input.is_action_just_pressed("jump") and is_on_floor():


		velocity.y = jump


		var direction = Input.get_axis(
			"move_left",
			"move_right"
		)


		velocity.x = direction * jump_horizontal_speed


		velocity.x = clamp(
			velocity.x,
			-max_jump_horizontal_speed,
			max_jump_horizontal_speed
		)


		change_state(State.Jump)





func player_jump_state(delta : float):

	var direction = Input.get_axis(
		"move_left",
		"move_right"
	)



	if direction != 0:


		velocity.x = direction * speed


		animated_sprite_2d.flip_h = direction < 0



	else:

		# pequeño deslizamiento al caer

		velocity.x = move_toward(
			velocity.x,
			0,
			slow_sown_speed * delta
		)





func player_idle(delta : float):


	velocity.x = move_toward(
		velocity.x,
		0,
		slow_sown_speed * delta
	)



	var direction = Input.get_axis(
		"move_left",
		"move_right"
	)



	if direction != 0:

		change_state(State.Run)





func player_run(delta : float):

	var direction = Input.get_axis(
		"move_left",
		"move_right"
	)



	if direction != 0:


		velocity.x += direction * speed * delta


		velocity.x = clamp(
			velocity.x,
			-max_horizontal_speed,
			max_horizontal_speed
		)


		animated_sprite_2d.flip_h = direction < 0



	else:


		# slide al dejar de correr

		velocity.x = move_toward(
			velocity.x,
			0,
			slow_sown_speed * delta
		)





func update_state_after_movement():


	# sigue en salto mientras esté en aire

	if !is_on_floor():

		change_state(State.Jump)

		return



	var direction = Input.get_axis(
		"move_left",
		"move_right"
	)



	if direction != 0:

		change_state(State.Run)



	elif abs(velocity.x) > 5:

		# todavía tiene deslizamiento

		change_state(State.Run)



	else:

		velocity.x = 0

		change_state(State.Idle)





func player_animations():


	if current_state == State.Idle:

		animated_sprite_2d.play("idle")


	elif current_state == State.Run:

		animated_sprite_2d.play("run")


	elif current_state == State.Jump:

		animated_sprite_2d.play("jump")





func change_state(new_state):

	if current_state != new_state:

		current_state = new_state

		print("State: ", State.keys()[current_state])
