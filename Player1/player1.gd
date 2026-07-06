extends CharacterBody2D
class_name Player

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var muzzle_up: Marker2D = $MuzzleUp
@onready var muzzle_duck: Marker2D = $MuzzleDuck

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
const HURT_ANIMATION_TIME = 0.25
const SHOOT_ANIMATION_TIME = 1.0
const WALL_CLING_FALL_SPEED = 32.0

@export var max_health: int = 800
@export var invulnerability_time: float = 1.2
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 0.45
@export var attack_damage: int = 100
@export var projectile_spawn_offset: Vector2 = Vector2(32, -24)
@export_enum("keyboard", "gamepad", "both") var input_mode: String = "both"

enum State {Idle, Run, Jump, Duck, Cling}
var current_state : State = State.Idle
var health: int
var tiene_salto_infinito: bool = false
var tiene_dash: bool = false
var dash_timer: float = 0.0
var dash_direction: float = 1.0
var invulnerability_timer: float = 0.0
var hurt_timer: float = 0.0
var attack_timer: float = 0.0
var shoot_animation_timer: float = 0.0
var is_dead := false
var is_crouching := false
var is_clinging := false

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
	attack_timer = max(attack_timer - delta, 0.0)
	shoot_animation_timer = max(shoot_animation_timer - delta, 0.0)
	_update_invulnerability_blink()
	is_clinging = false
	_update_crouch_state()

	apply_gravity(delta)
	handle_jump()
	handle_dash(delta)
	handle_attack()
	handle_movement(delta)

	move_and_slide()

	update_state()
	update_animations()

func apply_gravity(delta: float):
	if not is_on_floor() and dash_timer <= 0.0:
		velocity.y += GRAVITY * delta
		if _should_wall_cling():
			is_clinging = true
			velocity.y = WALL_CLING_FALL_SPEED
			_update_cling_facing()

func handle_jump():
	if not _is_action_just_pressed_for_mode("jump", "jump_JOY"):
		return

	if is_on_floor():
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY
	elif tiene_salto_infinito:
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY

func handle_dash(delta: float):
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0
		return

	if tiene_dash and Input.is_action_just_pressed("dash"):
		var direction = _input_axis()
		if direction == 0:
			direction = -1.0 if animated_sprite_2d.flip_h else 1.0
		AudioManager.play_sfx(&"player_dash")
		dash_direction = direction
		dash_timer = DASH_TIME
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0

func handle_movement(delta: float):
	if dash_timer > 0.0:
		return

	var direction = _input_axis()
	var is_aiming_up := is_on_floor() and _is_action_pressed_for_mode("aim_up", "aim_up_JOY")

	var accel = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var friction = FRICTION if is_on_floor() else AIR_FRICTION

	if is_crouching or is_aiming_up:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	elif direction != 0:
		# Smoothly accelerate to speed
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		# Smoothly decelerate to 0
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_attack() -> void:
	if not _is_action_just_pressed_for_mode("attack", "attack_JOY") or attack_timer > 0.0:
		return
	if projectile_scene == null:
		push_warning("Player1: projectile_scene no asignado.")
		return

	var projectile := projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	var shot_direction := _shot_direction()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_spawn_position(shot_direction)
	if projectile.has_method("setup"):
		projectile.setup(shot_direction, attack_damage)

	AudioManager.play_sfx(&"player_shoot")
	attack_timer = attack_cooldown
	shoot_animation_timer = SHOOT_ANIMATION_TIME

func activar_debug_habilidades():
	tiene_salto_infinito = true
	tiene_dash = true

func set_salto_infinito_activo(activo: bool) -> void:
	tiene_salto_infinito = activo

func set_dash_activo(activo: bool) -> void:
	tiene_dash = activo
	if not activo:
		dash_timer = 0.0

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
			velocity.x = knockback_direction * 340.0
			velocity.y = min(velocity.y, -120.0)

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

func update_state():
	if is_clinging:
		current_state = State.Cling
	elif is_crouching:
		current_state = State.Duck
	elif not is_on_floor():
		current_state = State.Jump
	elif abs(velocity.x) > 5.0:
		current_state = State.Run
	else:
		current_state = State.Idle

func _shoot_animation_for_current_motion() -> StringName:
	if is_clinging:
		return &"cling"
	if not is_on_floor():
		return &"jump"
	if _is_aiming_up_on_floor():
		return &"shootingUpP"
	if is_crouching:
		return &"duck"
	if abs(_input_axis()) > 0.0 or abs(velocity.x) > 5.0:
		return &"runshooting"
	return &"stand"

func _input_axis() -> float:
	if input_mode == "keyboard" or input_mode == "both":
		var keyboard_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		if abs(keyboard_axis) > 0.0:
			return keyboard_axis
	if input_mode == "gamepad" or input_mode == "both":
		return Input.get_axis("move_left_JOY", "move_right_JOY")
	return 0.0

func _shot_direction() -> Vector2:
	if _is_aiming_up_on_floor():
		return Vector2.UP
	return Vector2.LEFT if animated_sprite_2d.flip_h else Vector2.RIGHT

func _projectile_spawn_position(shot_direction: Vector2) -> Vector2:
	var marker := _muzzle_marker_for_direction(shot_direction)
	if marker != null:
		var local_position := marker.position
		if animated_sprite_2d.flip_h:
			local_position.x = -abs(local_position.x)
		else:
			local_position.x = abs(local_position.x)
		return global_position + local_position
	return global_position + _projectile_spawn_offset_for_direction(shot_direction)

func _muzzle_marker_for_direction(shot_direction: Vector2) -> Marker2D:
	if shot_direction == Vector2.UP:
		return muzzle_up
	if is_crouching:
		return muzzle_duck
	return muzzle

func _projectile_spawn_offset_for_direction(shot_direction: Vector2) -> Vector2:
	var facing_offset := -1.0 if animated_sprite_2d.flip_h else 1.0
	if shot_direction == Vector2.UP:
		return Vector2(6 * facing_offset, -49)
	if is_crouching:
		return Vector2(projectile_spawn_offset.x * facing_offset, -13)
	return Vector2(projectile_spawn_offset.x * facing_offset, projectile_spawn_offset.y)

func _update_crouch_state() -> void:
	is_crouching = is_on_floor() and _is_action_pressed_for_mode("crouch", "crouch_JOY")

func _should_wall_cling() -> bool:
	if is_on_floor() or not is_on_wall():
		return false
	var direction := _input_axis()
	if abs(direction) <= 0.0:
		return false
	var wall_normal_x := _wall_normal_x()
	if wall_normal_x > 0.0:
		return direction < 0.0
	if wall_normal_x < 0.0:
		return direction > 0.0
	return false

func _update_cling_facing() -> void:
	var wall_normal_x := _wall_normal_x()
	if wall_normal_x == 0.0:
		return
	animated_sprite_2d.flip_h = wall_normal_x < 0.0

func _wall_normal_x() -> float:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if abs(collision.get_normal().x) > 0.6:
			return collision.get_normal().x
	return 0.0

func _is_action_just_pressed_for_mode(keyboard_action: StringName, gamepad_action: StringName) -> bool:
	if (input_mode == "keyboard" or input_mode == "both") and keyboard_action != &"" and Input.is_action_just_pressed(keyboard_action):
		return true
	if (input_mode == "gamepad" or input_mode == "both") and gamepad_action != &"" and Input.is_action_just_pressed(gamepad_action):
		return true
	return false

func _is_action_pressed_for_mode(keyboard_action: StringName, gamepad_action: StringName) -> bool:
	if (input_mode == "keyboard" or input_mode == "both") and keyboard_action != &"" and Input.is_action_pressed(keyboard_action):
		return true
	if (input_mode == "gamepad" or input_mode == "both") and gamepad_action != &"" and Input.is_action_pressed(gamepad_action):
		return true
	return false

func _is_aiming_up_on_floor() -> bool:
	return is_on_floor() and not is_clinging and _is_action_pressed_for_mode("aim_up", "aim_up_JOY")

func update_animations():
	if hurt_timer > 0.0:
		animated_sprite_2d.play("hurt")
		return
	if shoot_animation_timer > 0.0:
		animated_sprite_2d.play(_shoot_animation_for_current_motion())
		return
	if _is_aiming_up_on_floor():
		animated_sprite_2d.play("shootingUpP")
		return

	match current_state:
		State.Idle:
			animated_sprite_2d.play("idle")
		State.Run:
			animated_sprite_2d.play("run")
		State.Jump:
			animated_sprite_2d.play("jump")
		State.Duck:
			animated_sprite_2d.play("duck")
		State.Cling:
			animated_sprite_2d.play("cling")
