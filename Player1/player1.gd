extends CharacterBody2D
class_name Player

signal jumped

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var muzzle_up: Marker2D = $MuzzleUp
@onready var muzzle_duck: Marker2D = $MuzzleDuck
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D") as Camera2D

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
const WALL_JUMP_HORIZONTAL_SPEED = 360.0
const WALL_JUMP_VERTICAL_SPEED = -430.0
const DOUBLE_JUMP_UPGRADE_NAME := "Doble salto"
const DOUBLE_JUMP_UPGRADE_DESCRIPTION := "Kaizen puede hacer un segundo salto en el aire."
const BASE_PROJECTILE_SCENE := preload("res://Player1/bullet.tscn")
const KAIZEN_PROJECTILE_UPGRADES := [
	{
		"id": "01_disparo_rapido",
		"name": "Disparo rapido",
		"description": "Disparo mas veloz con menor espera entre tiros.",
		"scene": "res://Pickups/Kaizen/01_disparo_rapido/bullet.tscn",
		"icon": "res://Pickups/Kaizen/01_disparo_rapido/sprites/01_disparo_rapido_01.png",
	},
	{
		"id": "02_disparo_cargado",
		"name": "Disparo cargado",
		"description": "Disparo mas grande y fuerte, pero mas lento.",
		"scene": "res://Pickups/Kaizen/02_disparo_cargado/bullet.tscn",
		"icon": "res://Pickups/Kaizen/02_disparo_cargado/sprites/02_disparo_cargado_01.png",
	},
	{
		"id": "03_disparo_doble",
		"name": "Disparo doble",
		"description": "Kaizen lanza dos disparos separados.",
		"scene": "res://Pickups/Kaizen/03_disparo_doble/bullet.tscn",
		"icon": "res://Pickups/Kaizen/03_disparo_doble/sprites/03_disparo_doble_01.png",
	},
	{
		"id": "04_pulso_perforante",
		"name": "Pulso perforante",
		"description": "El disparo atraviesa un enemigo antes de desaparecer.",
		"scene": "res://Pickups/Kaizen/04_pulso_perforante/bullet.tscn",
		"icon": "res://Pickups/Kaizen/04_pulso_perforante/sprites/04_pulso_perforante_01.png",
	},
	{
		"id": "05_chispa_rebote",
		"name": "Chispa de rebote",
		"description": "El disparo puede rebotar una vez contra paredes.",
		"scene": "res://Pickups/Kaizen/05_chispa_rebote/bullet.tscn",
		"icon": "res://Pickups/Kaizen/05_chispa_rebote/sprites/05_chispa_rebote_01.png",
	},
	{
		"id": "06_onda_expansiva",
		"name": "Onda expansiva",
		"description": "Disparo amplio con movimiento ondulado.",
		"scene": "res://Pickups/Kaizen/06_onda_expansiva/bullet.tscn",
		"icon": "res://Pickups/Kaizen/06_onda_expansiva/sprites/06_onda_expansiva_01.png",
	},
]

@export var max_health: int = 100
@export var max_hearts: int = 3
@export var invulnerability_time: float = 1.2
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 0.45
@export var attack_damage: int = 10
@export var projectile_spawn_offset: Vector2 = Vector2(32, -24)
@export_enum("keyboard", "gamepad", "both") var input_mode: String = "both"

enum State {Idle, Run, Jump, Duck, Cling}
var current_state : State = State.Idle
var health: int
var hearts: int
var tiene_salto_infinito: bool = false
var tiene_dash: bool = false
var unlocked_projectile_upgrades: Array[int] = []
var active_projectile_upgrade_index: int = -1
var dash_timer: float = 0.0
var dash_direction: float = 1.0
var invulnerability_timer: float = 0.0
var hurt_timer: float = 0.0
var attack_timer: float = 0.0
var shoot_animation_timer: float = 0.0
var _air_jump_available := false
var is_dead := false
var is_crouching := false
var is_clinging := false

func _ready() -> void:
	health = max_health
	hearts = max_hearts
	add_to_group(&"Player")
	add_to_group(&"player")
	if GameManager.current_game_mode == "coop":
		input_mode = "keyboard"
	call_deferred("_configure_input_mode_for_coop")
	if camera_2d != null:
		camera_2d.call_deferred("make_current")

func _configure_input_mode_for_coop() -> void:
	var parent := get_parent()
	if parent != null and parent.has_node("Player2"):
		input_mode = "keyboard"

func _input(event: InputEvent) -> void:
	if is_dead or GameManager.dialogue_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cycle_projectile_upgrade()

func _physics_process(delta: float):
	if is_dead:
		velocity = Vector2.ZERO
		update_animations()
		return

	if GameManager.dialogue_open:
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
	if is_on_floor():
		_air_jump_available = true

	apply_gravity(delta)
	handle_jump()
	handle_dash(delta)
	handle_attack()
	handle_movement(delta)

	move_and_slide()

	if tiene_salto_infinito and not is_on_floor() and is_on_wall():
		_air_jump_available = true

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

	if _try_wall_jump():
		return

	if is_on_floor():
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY
		jumped.emit()
		if tiene_salto_infinito:
			_air_jump_available = true
	elif tiene_salto_infinito and _air_jump_available:
		AudioManager.play_sfx(&"player_jump")
		velocity.y = JUMP_VELOCITY
		_air_jump_available = false

func _try_wall_jump() -> bool:
	if not is_clinging and not _should_wall_cling():
		return false
	var wall_normal_x := _wall_normal_x()
	if wall_normal_x == 0.0:
		return false
	AudioManager.play_sfx(&"player_jump")
	velocity.x = wall_normal_x * WALL_JUMP_HORIZONTAL_SPEED
	velocity.y = WALL_JUMP_VERTICAL_SPEED
	_air_jump_available = false
	is_clinging = false
	animated_sprite_2d.flip_h = wall_normal_x < 0.0
	return true

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

	var shot_direction := _shot_direction()
	if _active_projectile_id() == "03_disparo_doble":
		_spawn_projectile(shot_direction.rotated(-0.16))
		_spawn_projectile(shot_direction.rotated(0.16))
	else:
		_spawn_projectile(shot_direction)

	AudioManager.play_sfx(&"player_shoot")
	attack_timer = _attack_cooldown_for_active_projectile()
	shoot_animation_timer = SHOOT_ANIMATION_TIME

func _spawn_projectile(shot_direction: Vector2) -> void:
	var projectile := projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = _projectile_spawn_position(shot_direction)
	if projectile.has_method("setup"):
		projectile.setup(shot_direction, _damage_for_active_projectile())
	_apply_active_projectile_modifiers(projectile)

func activar_debug_habilidades():
	tiene_salto_infinito = true
	tiene_dash = true

func set_salto_infinito_activo(activo: bool) -> void:
	tiene_salto_infinito = activo
	if not activo:
		_air_jump_available = false

func set_dash_activo(activo: bool) -> void:
	tiene_dash = activo
	if not activo:
		dash_timer = 0.0

func apply_next_linear_upgrade() -> Dictionary:
	if not tiene_salto_infinito:
		set_salto_infinito_activo(true)
		return {
			"applied": true,
			"title": DOUBLE_JUMP_UPGRADE_NAME,
			"description": DOUBLE_JUMP_UPGRADE_DESCRIPTION,
			"icon_path": "",
		}

	var next_projectile_index := unlocked_projectile_upgrades.size()
	if next_projectile_index >= KAIZEN_PROJECTILE_UPGRADES.size():
		return {
			"applied": false,
			"title": "Mejoras completas",
			"description": "Kaizen ya tiene todos los disparos disponibles.",
			"icon_path": get_active_powerup_icon_path(),
		}

	unlock_projectile_upgrade(next_projectile_index)
	var upgrade: Dictionary = KAIZEN_PROJECTILE_UPGRADES[next_projectile_index]
	return {
		"applied": true,
		"title": str(upgrade["name"]),
		"description": str(upgrade["description"]),
		"icon_path": str(upgrade["icon"]),
	}

func set_debug_upgrade_level(level: int) -> void:
	var debug_level := clampi(level, 0, KAIZEN_PROJECTILE_UPGRADES.size() + 1)
	set_salto_infinito_activo(debug_level >= 1)
	unlocked_projectile_upgrades.clear()
	for upgrade_index in range(maxi(debug_level - 1, 0)):
		unlocked_projectile_upgrades.append(upgrade_index)
	active_projectile_upgrade_index = unlocked_projectile_upgrades.size() - 1
	if active_projectile_upgrade_index >= 0:
		_apply_active_projectile_upgrade()
	else:
		projectile_scene = BASE_PROJECTILE_SCENE
	health = max_health
	hearts = max_hearts
	invulnerability_timer = 0.0
	hurt_timer = 0.0
	attack_timer = 0.0
	shoot_animation_timer = 0.0
	velocity = Vector2.ZERO
	_notify_active_powerup_icon()

func get_upgrade_level() -> int:
	return clampi((1 if tiene_salto_infinito else 0) + unlocked_projectile_upgrades.size(), 0, KAIZEN_PROJECTILE_UPGRADES.size() + 1)

func unlock_projectile_upgrade(upgrade_index: int) -> bool:
	if upgrade_index < 0 or upgrade_index >= KAIZEN_PROJECTILE_UPGRADES.size():
		return false
	if unlocked_projectile_upgrades.has(upgrade_index):
		active_projectile_upgrade_index = unlocked_projectile_upgrades.find(upgrade_index)
	else:
		unlocked_projectile_upgrades.append(upgrade_index)
		active_projectile_upgrade_index = unlocked_projectile_upgrades.size() - 1
	_apply_active_projectile_upgrade()
	_notify_active_powerup_icon()
	return true

func get_upgrade_state() -> Dictionary:
	return {
		"max_health": max_health,
		"attack_damage": attack_damage,
		"attack_cooldown": attack_cooldown,
		"tiene_salto_infinito": tiene_salto_infinito,
		"tiene_dash": tiene_dash,
		"unlocked_projectile_upgrades": unlocked_projectile_upgrades.duplicate(),
		"active_projectile_upgrade_index": active_projectile_upgrade_index,
	}

func apply_upgrade_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	max_health = int(state.get("max_health", max_health))
	health = max_health
	attack_damage = int(state.get("attack_damage", attack_damage))
	attack_cooldown = float(state.get("attack_cooldown", attack_cooldown))
	tiene_salto_infinito = bool(state.get("tiene_salto_infinito", tiene_salto_infinito))
	tiene_dash = bool(state.get("tiene_dash", tiene_dash))
	unlocked_projectile_upgrades.clear()
	for idx in state.get("unlocked_projectile_upgrades", []):
		unlocked_projectile_upgrades.append(int(idx))
	active_projectile_upgrade_index = int(state.get("active_projectile_upgrade_index", -1))
	_apply_active_projectile_upgrade()
	_notify_active_powerup_icon()

func cycle_projectile_upgrade() -> bool:
	if unlocked_projectile_upgrades.is_empty():
		return false
	active_projectile_upgrade_index = (active_projectile_upgrade_index + 1) % unlocked_projectile_upgrades.size()
	_apply_active_projectile_upgrade()
	_notify_active_powerup_icon()
	return true

func get_active_powerup_icon_path() -> String:
	var upgrade: Dictionary = _active_projectile_definition()
	if upgrade.is_empty():
		return ""
	return str(upgrade["icon"])

func _apply_active_projectile_upgrade() -> void:
	var upgrade: Dictionary = _active_projectile_definition()
	if upgrade.is_empty():
		return
	var next_projectile_scene := load(str(upgrade["scene"])) as PackedScene
	if next_projectile_scene == null:
		push_warning("Kaizen: no se pudo cargar el disparo " + str(upgrade["scene"]))
		return
	projectile_scene = next_projectile_scene

func _active_projectile_definition() -> Dictionary:
	if active_projectile_upgrade_index < 0 or active_projectile_upgrade_index >= unlocked_projectile_upgrades.size():
		return {}
	var upgrade_index := int(unlocked_projectile_upgrades[active_projectile_upgrade_index])
	if upgrade_index < 0 or upgrade_index >= KAIZEN_PROJECTILE_UPGRADES.size():
		return {}
	return KAIZEN_PROJECTILE_UPGRADES[upgrade_index]

func _active_projectile_id() -> String:
	var upgrade: Dictionary = _active_projectile_definition()
	if upgrade.is_empty():
		return ""
	return str(upgrade["id"])

func _attack_cooldown_for_active_projectile() -> float:
	match _active_projectile_id():
		"01_disparo_rapido":
			return max(0.18, attack_cooldown * 0.65)
		"02_disparo_cargado":
			return attack_cooldown * 1.3
		"03_disparo_doble":
			return attack_cooldown * 1.15
	return attack_cooldown

func _damage_for_active_projectile() -> int:
	match _active_projectile_id():
		"02_disparo_cargado":
			return attack_damage + 50
		"06_onda_expansiva":
			return attack_damage + 25
	return attack_damage

func _apply_active_projectile_modifiers(projectile: Node2D) -> void:
	match _active_projectile_id():
		"01_disparo_rapido":
			if "speed" in projectile:
				projectile.speed = 720.0
		"02_disparo_cargado":
			if "speed" in projectile:
				projectile.speed = 360.0
			projectile.scale *= 1.25
		"04_pulso_perforante":
			if "pierce_count" in projectile:
				projectile.pierce_count = 1
		"05_chispa_rebote":
			if "bounce_count" in projectile:
				projectile.bounce_count = 1
		"06_onda_expansiva":
			projectile.scale *= 1.35
			if "wave_amplitude" in projectile:
				projectile.wave_amplitude = 36.0
			if "wave_frequency" in projectile:
				projectile.wave_frequency = 9.0

func _notify_active_powerup_icon() -> void:
	var hud := _find_gameplay_hud()
	if hud != null and hud.has_method("set_player1_powerup_icon"):
		hud.set_player1_powerup_icon(get_active_powerup_icon_path())

func _find_gameplay_hud() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	var named_hud := current_scene.find_child("GameplayHUD", true, false)
	if named_hud != null:
		return named_hud
	return _find_node_with_method(current_scene, "set_player1_powerup_icon")

func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null

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
			velocity.x = knockback_direction * 340.0
			velocity.y = min(velocity.y, -120.0)

func receive_damage(amount: int = 1, source_pos: Vector2 = Vector2.ZERO) -> void:
	recibir_daño(amount, source_pos)

func force_death() -> void:
	health = 0
	hearts = 0
	_die()

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
		var left_strength := Input.get_action_strength("move_left")
		var right_strength := Input.get_action_strength("move_right")
		if InputMap.has_action("ui_left"):
			left_strength = max(left_strength, Input.get_action_strength("ui_left"))
		if InputMap.has_action("ui_right"):
			right_strength = max(right_strength, Input.get_action_strength("ui_right"))
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			left_strength = 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			right_strength = 1.0
		var keyboard_axis := right_strength - left_strength
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
	return Input.is_key_pressed(KEY_SHIFT)

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
