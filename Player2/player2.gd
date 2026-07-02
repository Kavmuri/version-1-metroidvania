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
const HURT_ANIMATION_TIME = 0.25

@export var max_health: int = 3
@export var invulnerability_time: float = 1.2
@export_enum("keyboard", "gamepad", "both") var input_mode: String = "both"

enum State {Idle, Run, Jump}
var current_state : State = State.Idle
var health: int
var invulnerability_timer: float = 0.0
var hurt_timer: float = 0.0
var is_dead := false

func _ready() -> void:
	health = max_health
	add_to_group(&"Player")
	add_to_group(&"player")

func _physics_process(delta: float):
	if is_dead:
		velocity = Vector2.ZERO
		update_animations()
		return

	invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	hurt_timer = max(hurt_timer - delta, 0.0)
	_update_invulnerability_blink()

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
	if _is_action_just_pressed_for_mode("jump", "jump_JOY") and is_on_floor():
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY

func handle_movement(delta: float):
	var direction = _input_axis()

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
	if hurt_timer > 0.0:
		animated_sprite_2d.play("hurtP2")
		return
	match current_state:
		State.Idle:
			animated_sprite_2d.play("idleP2")
		State.Run:
			animated_sprite_2d.play("runP2")
		State.Jump:
			animated_sprite_2d.play("jumpP2")

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or health <= 0:
		return

	health = max(health - cantidad, 0)
	AudioManager.play_sfx(&"player_hurt")
	invulnerability_timer = invulnerability_time
	hurt_timer = HURT_ANIMATION_TIME
	if health <= 0:
		_die()
		return
	if fuente_pos != Vector2.ZERO:
		var knockback_direction: float = sign(global_position.x - fuente_pos.x)
		if knockback_direction != 0.0:
			velocity.x = knockback_direction * 180.0

func receive_damage(amount: int = 1, source_pos: Vector2 = Vector2.ZERO) -> void:
	recibir_daño(amount, source_pos)

func _die() -> void:
	if is_dead:
		return
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("handle_player_death"):
		if current_scene.handle_player_death(self):
			return
	is_dead = true
	velocity = Vector2.ZERO
	animated_sprite_2d.modulate = Color.WHITE
	GameManager.show_death_screen()

func _update_invulnerability_blink() -> void:
	if invulnerability_timer <= 0.0:
		animated_sprite_2d.modulate = Color.WHITE
		return

	var blink_step := int(invulnerability_timer * 16.0)
	if blink_step % 2 == 0:
		animated_sprite_2d.modulate = Color(1.0, 1.0, 1.0, 0.35)
	else:
		animated_sprite_2d.modulate = Color.WHITE

func _input_axis() -> float:
	var axis := 0.0
	if input_mode == "keyboard" or input_mode == "both":
		axis += Input.get_axis("move_left", "move_right")
	if input_mode == "gamepad" or input_mode == "both":
		axis += Input.get_axis("move_left_JOY", "move_right_JOY")
	return clampf(axis, -1.0, 1.0)

func _is_action_just_pressed_for_mode(keyboard_action: StringName, gamepad_action: StringName) -> bool:
	if (input_mode == "keyboard" or input_mode == "both") and keyboard_action != &"" and Input.is_action_just_pressed(keyboard_action):
		return true
	if (input_mode == "gamepad" or input_mode == "both") and gamepad_action != &"" and Input.is_action_just_pressed(gamepad_action):
		return true
	return false
