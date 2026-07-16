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
const ATTACK_ANIMATION_TIME = 0.45

@export var max_health: int = 100
@export var max_hearts: int = 2
@export var invulnerability_time: float = 1.2
@export var attack_damage: int = 10
@export var attack_range: float = 52.0
@export var attack_cooldown: float = 0.35
@export_enum("keyboard", "gamepad", "both") var input_mode: String = "both"

enum State {Idle, Run, Jump, Fall, Duck, Attack}
var current_state : State = State.Idle
var health: int
var hearts: int
var invulnerability_timer: float = 0.0
var hurt_timer: float = 0.0
var attack_timer: float = 0.0
var attack_animation_timer: float = 0.0
var attack_damage_applied := false
var attack_animation_name: StringName = &"golpeP2"
var use_next_hand_attack := false
var tiene_salto_infinito: bool = false
var _air_jump_available := false
var is_crouching := false
var is_dead := false

func _ready() -> void:
	health = max_health
	hearts = max_hearts
	add_to_group(&"Player")
	add_to_group(&"player")
	input_mode = "gamepad"

func _physics_process(delta: float):
	if is_dead:
		velocity = Vector2.ZERO
		update_animations()
		return

	invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	hurt_timer = max(hurt_timer - delta, 0.0)
	attack_timer = max(attack_timer - delta, 0.0)
	attack_animation_timer = max(attack_animation_timer - delta, 0.0)
	_update_invulnerability_blink()
	_update_crouch_state()
	if is_on_floor():
		_air_jump_available = true

	apply_gravity(delta)
	handle_jump()
	handle_attack()
	handle_movement(delta)

	move_and_slide()

	update_state()
	update_animations()

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func handle_jump():
	if not _is_action_just_pressed_for_mode("jump", "jump_JOY"):
		return

	if is_on_floor():
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY
		if tiene_salto_infinito:
			_air_jump_available = true
	elif tiene_salto_infinito and _air_jump_available:
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY
		_air_jump_available = false

func handle_movement(delta: float):
	var direction = _input_axis()

	var accel = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var friction = FRICTION if is_on_floor() else AIR_FRICTION

	if is_crouching:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	elif direction != 0:
		# Smoothly accelerate to speed
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		animated_sprite_2d.flip_h = direction < 0
	else:
		# Smoothly decelerate to 0
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func _update_crouch_state() -> void:
	is_crouching = is_on_floor() and _is_action_pressed_for_mode("crouch", "crouch_JOY")

func handle_attack() -> void:
	if attack_animation_timer > 0.0 and not attack_damage_applied:
		_apply_melee_damage()
		attack_damage_applied = true
	if not _is_action_just_pressed_for_mode("attack", "attack_JOY") or attack_timer > 0.0:
		return
	attack_timer = attack_cooldown
	attack_animation_timer = ATTACK_ANIMATION_TIME
	attack_damage_applied = false
	attack_animation_name = _attack_animation_for_current_motion()
	AudioManager.play_sfx(&"player_shoot")

func update_state():
	if attack_animation_timer > 0.0:
		current_state = State.Attack
	elif is_crouching:
		current_state = State.Duck
	elif not is_on_floor() and velocity.y > 0.0:
		current_state = State.Fall
	elif not is_on_floor():
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
		State.Fall:
			animated_sprite_2d.play("fallP2_1")
		State.Duck:
			animated_sprite_2d.play("agacharP2")
		State.Attack:
			animated_sprite_2d.play(attack_animation_name)

func apply_next_linear_upgrade() -> Dictionary:
	if not tiene_salto_infinito:
		set_salto_infinito_activo(true)
		return {
			"applied": true,
			"title": "Doble salto",
			"description": "Eldric puede hacer un segundo salto en el aire.",
			"icon_path": "",
		}
	return {
		"applied": false,
		"title": "Mejoras completas",
		"description": "Eldric ya tiene su mejora disponible.",
		"icon_path": "",
	}

func set_salto_infinito_activo(activo: bool) -> void:
	tiene_salto_infinito = activo
	if not activo:
		_air_jump_available = false

func get_upgrade_state() -> Dictionary:
	return {
		"max_health": max_health,
		"attack_damage": attack_damage,
		"attack_cooldown": attack_cooldown,
		"tiene_salto_infinito": tiene_salto_infinito,
	}

func apply_upgrade_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	max_health = int(state.get("max_health", max_health))
	health = max_health
	attack_damage = int(state.get("attack_damage", attack_damage))
	attack_cooldown = float(state.get("attack_cooldown", attack_cooldown))
	tiene_salto_infinito = bool(state.get("tiene_salto_infinito", tiene_salto_infinito))

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or hearts <= 0:
		return

	health = max(health - cantidad, 0)
	AudioManager.play_sfx(&"player_hurt")
	JuiceManager.screen_shake(4.0, 0.15)
	JuiceManager.hit_stop(0.05, 0.05)
	invulnerability_timer = invulnerability_time
	hurt_timer = HURT_ANIMATION_TIME
	if health <= 0:
		hearts = max(hearts - 1, 0)
		if hearts <= 0:
			_die()
			return
		health = max_health
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
	JuiceManager.screen_shake(10.0, 0.3)
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

func _attack_animation_for_current_motion() -> StringName:
	if not is_on_floor():
		return &"golpeaireP2"
	if is_crouching:
		return &"golpeagachadoP2"
	var selected_attack := &"golpeManoP2" if use_next_hand_attack else &"golpeP2"
	use_next_hand_attack = not use_next_hand_attack
	return selected_attack

func _apply_melee_damage() -> void:
	var facing_direction := -1.0 if animated_sprite_2d.flip_h else 1.0
	var attack_origin := global_position + Vector2(facing_direction * 24.0, -10.0)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.global_position.distance_to(attack_origin) > attack_range:
			continue
		if enemy_node.has_method("receive_damage"):
			enemy_node.receive_damage(attack_damage, global_position)
		elif enemy_node.has_method("recibir_daño"):
			enemy_node.recibir_daño(attack_damage, global_position)

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
