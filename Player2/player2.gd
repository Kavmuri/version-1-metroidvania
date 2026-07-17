extends CharacterBody2D

signal jumped

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_visual: ColorRect = get_node_or_null("ShieldVisual") as ColorRect

var _shield_material: ShaderMaterial
var _attack_palette_material: ShaderMaterial

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
const BASE_MAX_HEARTS = 2
const EXTRA_HEART_HEALTH_BONUS = 50
const SHIELD_RECHARGE_SECONDS = 12.0
const DASH_SPEED = 680.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.45
const PIERCING_SPEED = 600.0
const PIERCING_DURATION = 0.28
const GLIDE_DURATION = 1.0
const FURY_MAX_HITS = 5
const FURY_DAMAGE_PER_HIT = 0.2
const FURY_COMBO_TIMEOUT = 2.0
const ELDRIC_UPGRADES := [
	{
		"title": "Doble salto",
		"description": "Eldric puede hacer un segundo salto en el aire.",
		"control_hint": "Boton B / Circulo (salto, en el aire)",
	},
	{
		"title": "Dash sombrio",
		"description": "Eldric se desplaza rapidamente hacia adelante.",
		"control_hint": "RB / R1",
	},
	{
		"title": "Escudo espectral",
		"description": "Manten el boton de escudo para absorber un golpe; se recarga despues de 12 segundos.",
		"control_hint": "Boton Guia / PS (mantener)",
	},
	{
		"title": "Corazon adicional",
		"description": "Eldric obtiene un corazon permanente adicional.",
		"control_hint": "Automatico (mas vida maxima)",
	},
	{
		"title": "Golpe perforante",
		"description": "El dash golpea y atraviesa a los enemigos.",
		"control_hint": "RB / R1 (el dash ahora perfora)",
	},
	{
		"title": "Furia creciente",
		"description": "Los golpes consecutivos aumentan el dano de Eldric.",
		"control_hint": "Automatico (golpes seguidos)",
	},
	{
		"title": "Planeo abisal",
		"description": "Despues del dash aereo, Eldric suspende su caida por un segundo.",
		"control_hint": "RB / R1 en el aire (planeo automatico)",
	},
]

@export var max_health: int = 100
@export var max_hearts: int = 2
@export var invulnerability_time: float = 1.6
@export var attack_damage: int = 100
@export var attack_range: float = 52.0
@export var attack_cooldown: float = 0.35
@export_enum("keyboard", "gamepad", "both") var input_mode: String = "both"

enum State {Idle, Run, Jump, Fall, Duck, Attack, Dash, Glide}
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
var tiene_dash: bool = false
var tiene_escudo: bool = false
var tiene_golpe_perforante: bool = false
var tiene_furia_creciente: bool = false
var tiene_planeo: bool = false
var shield_ready := false
var is_guarding := false
var shield_recharge_timer := 0.0
var _unlocked_tiers: Array[bool] = [false, false, false, false, false, false, false]
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 1.0
var dash_started_in_air := false
var glide_timer := 0.0
var piercing_timer := 0.0
var piercing_direction := 1.0
var piercing_hit_targets: Dictionary = {}
var fury_hits := 0
var fury_combo_timer := 0.0
var debug_fury_counts_attacks := false
var _air_jump_available := false
var is_crouching := false
var is_dead := false
var _base_max_health: int = 0

func _ready() -> void:
	_shield_material = shield_visual.material as ShaderMaterial if shield_visual != null else null
	_attack_palette_material = animated_sprite_2d.material as ShaderMaterial
	_base_max_health = max_health
	health = max_health
	hearts = max_hearts
	add_to_group(&"Player")
	add_to_group(&"player")
	input_mode = "gamepad"
	_sync_shield_visual()
	_sync_attack_palette()

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
	attack_animation_timer = max(attack_animation_timer - delta, 0.0)
	_advance_upgrade_timers(delta)
	_update_invulnerability_blink()
	_update_crouch_state()
	_update_guard_state()
	if is_on_floor():
		_air_jump_available = true

	handle_dash()
	apply_gravity(delta)
	handle_jump()
	handle_attack()
	if piercing_timer > 0.0:
		velocity.x = piercing_direction * PIERCING_SPEED
		velocity.y = 0.0
		_apply_piercing_damage()
	elif dash_timer > 0.0:
		velocity.x = dash_direction * DASH_SPEED
		velocity.y = 0.0
	elif glide_timer > 0.0:
		velocity.y = 0.0
	else:
		handle_movement(delta)

	move_and_slide()

	if tiene_salto_infinito and not is_on_floor() and is_on_wall():
		_air_jump_available = true

	update_state()
	update_animations()

func apply_gravity(delta: float):
	if dash_timer > 0.0 or piercing_timer > 0.0 or glide_timer > 0.0:
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func handle_jump():
	if dash_timer > 0.0 or piercing_timer > 0.0 or glide_timer > 0.0:
		return
	if not _is_action_just_pressed_for_mode("jump", "jump_JOY"):
		return

	if is_on_floor():
		AudioManager.play_sfx(&"eldric_jump", 0.03, 2.0)
		velocity.y = JUMP_VELOCITY
		jumped.emit()
		if tiene_salto_infinito:
			_air_jump_available = true
	elif tiene_salto_infinito and _air_jump_available:
		AudioManager.play_sfx(&"eldric_jump", 0.03, 2.0)
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

func _update_guard_state() -> void:
	var was_guarding := is_guarding
	is_guarding = tiene_escudo and shield_ready and _is_action_pressed_for_mode("shield", "shield_JOY")
	if is_guarding != was_guarding:
		_sync_shield_visual()

func handle_dash() -> void:
	if not tiene_dash or dash_timer > 0.0 or piercing_timer > 0.0 or dash_cooldown_timer > 0.0:
		return
	if not _is_action_just_pressed_for_mode("dash", "dash_JOY"):
		return
	var direction := _input_axis()
	if is_zero_approx(direction):
		direction = -1.0 if animated_sprite_2d.flip_h else 1.0
	_start_dash(not is_on_floor(), direction)

func _start_dash(in_air: bool, direction: float) -> void:
	if not tiene_dash:
		return
	dash_direction = -1.0 if direction < 0.0 else 1.0
	dash_started_in_air = in_air
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	glide_timer = 0.0
	piercing_timer = 0.0
	piercing_hit_targets.clear()
	if tiene_golpe_perforante:
		piercing_direction = dash_direction
		piercing_timer = PIERCING_DURATION
		attack_timer = attack_cooldown
		attack_animation_timer = PIERCING_DURATION
		attack_animation_name = &"golpeaireP2"
		attack_damage_applied = true
		velocity = Vector2(piercing_direction * PIERCING_SPEED, 0.0)
		if debug_fury_counts_attacks:
			_register_fury_hit()
	else:
		velocity = Vector2(dash_direction * DASH_SPEED, 0.0)
	animated_sprite_2d.flip_h = dash_direction < 0.0
	AudioManager.play_sfx(&"player_dash")

func handle_attack() -> void:
	if is_guarding:
		attack_animation_timer = 0.0
		attack_damage_applied = true
		return
	if piercing_timer > 0.0:
		_apply_piercing_damage()
		return
	if attack_animation_timer > 0.0 and not attack_damage_applied:
		_apply_melee_damage()
		attack_damage_applied = true
	if not _is_action_just_pressed_for_mode("attack", "attack_JOY") or attack_timer > 0.0:
		return
	attack_timer = attack_cooldown
	attack_animation_timer = ATTACK_ANIMATION_TIME
	attack_damage_applied = false
	attack_animation_name = _attack_animation_for_current_motion()
	if debug_fury_counts_attacks:
		_register_fury_hit()
	AudioManager.play_sfx(&"eldric_attack", 0.04)

func update_state():
	if piercing_timer > 0.0:
		current_state = State.Attack
	elif glide_timer > 0.0:
		current_state = State.Glide
	elif dash_timer > 0.0:
		current_state = State.Dash
	elif attack_animation_timer > 0.0:
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
		_sync_attack_palette()
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
		State.Dash:
			animated_sprite_2d.play("agacharP2")
		State.Glide:
			animated_sprite_2d.play("golpeaireP2")
	_sync_attack_palette()

func apply_next_linear_upgrade() -> Dictionary:
	for index in range(_unlocked_tiers.size()):
		if not _unlocked_tiers[index]:
			return _unlock_tier(index, false)
	return {
		"applied": false,
		"title": "Mejoras completas",
		"description": "Eldric ya tiene todas sus mejoras disponibles.",
		"icon_path": "",
	}

func apply_specific_upgrade(index: int) -> Dictionary:
	var clamped_index: int = clampi(index, 0, _unlocked_tiers.size() - 1)
	if _unlocked_tiers[clamped_index]:
		return {
			"applied": false,
			"title": "Mejoras completas",
			"description": "Eldric ya tiene esta mejora.",
			"icon_path": "",
		}
	return _unlock_tier(clamped_index, false)

func _unlock_tier(index: int, refill_resources: bool) -> Dictionary:
	_unlocked_tiers[index] = true
	_sync_upgrade_flags(refill_resources)
	var upgrade: Dictionary = ELDRIC_UPGRADES[index]
	return {
		"applied": true,
		"title": str(upgrade["title"]),
		"description": str(upgrade["description"]),
		"control_hint": str(upgrade.get("control_hint", "")),
		"icon_path": "",
	}

func set_debug_upgrade_level(level: int) -> void:
	debug_fury_counts_attacks = true
	var clamped_level: int = clampi(level, 0, _unlocked_tiers.size())
	for index in range(_unlocked_tiers.size()):
		_unlocked_tiers[index] = index < clamped_level
	_sync_upgrade_flags(true)

func get_upgrade_level() -> int:
	var count := 0
	for unlocked in _unlocked_tiers:
		if unlocked:
			count += 1
	return count

func _sync_upgrade_flags(refill_resources: bool) -> void:
	var previous_max_hearts := max_hearts
	var previous_max_health := max_health
	tiene_salto_infinito = _unlocked_tiers[0]
	tiene_dash = _unlocked_tiers[1]
	tiene_escudo = _unlocked_tiers[2]
	max_hearts = BASE_MAX_HEARTS + (1 if _unlocked_tiers[3] else 0)
	max_health = _base_max_health + (EXTRA_HEART_HEALTH_BONUS if _unlocked_tiers[3] else 0)
	tiene_golpe_perforante = _unlocked_tiers[4]
	tiene_furia_creciente = _unlocked_tiers[5]
	tiene_planeo = _unlocked_tiers[6]
	if not tiene_salto_infinito:
		_air_jump_available = false
	if tiene_escudo:
		shield_ready = true
		shield_recharge_timer = 0.0
	else:
		shield_ready = false
		shield_recharge_timer = 0.0
	is_guarding = false
	if not tiene_dash:
		dash_timer = 0.0
		dash_cooldown_timer = 0.0
	if not tiene_golpe_perforante:
		piercing_timer = 0.0
		piercing_hit_targets.clear()
	if not tiene_furia_creciente:
		fury_hits = 0
		fury_combo_timer = 0.0
	if not tiene_planeo:
		glide_timer = 0.0
	_sync_shield_visual()
	_sync_attack_palette()
	if refill_resources:
		health = max_health
		hearts = max_hearts
		invulnerability_timer = 0.0
		hurt_timer = 0.0
		attack_timer = 0.0
		attack_animation_timer = 0.0
		velocity = Vector2.ZERO
	else:
		if max_hearts > previous_max_hearts:
			hearts = mini(hearts + (max_hearts - previous_max_hearts), max_hearts)
		else:
			hearts = mini(hearts, max_hearts)
		if max_health > previous_max_health:
			health = mini(health + (max_health - previous_max_health), max_health)
		else:
			health = mini(health, max_health)

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
		"unlocked_tiers": _unlocked_tiers.duplicate(),
		"eldric_upgrade_level": get_upgrade_level(),
	}

func apply_upgrade_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	debug_fury_counts_attacks = false
	max_health = int(state.get("max_health", max_health))
	attack_damage = int(state.get("attack_damage", attack_damage))
	attack_cooldown = float(state.get("attack_cooldown", attack_cooldown))
	var stored_tiers = state.get("unlocked_tiers", null)
	if stored_tiers is Array:
		for index in range(_unlocked_tiers.size()):
			_unlocked_tiers[index] = bool(stored_tiers[index]) if index < stored_tiers.size() else false
	else:
		# Compatibilidad con partidas guardadas antes de este cambio (nivel unico acumulativo).
		var legacy_level := int(state.get("eldric_upgrade_level", 1 if bool(state.get("tiene_salto_infinito", false)) else 0))
		for index in range(_unlocked_tiers.size()):
			_unlocked_tiers[index] = index < legacy_level
	_sync_upgrade_flags(true)

func _advance_upgrade_timers(delta: float) -> void:
	var dash_motion_was_active := dash_timer > 0.0 or piercing_timer > 0.0
	dash_timer = maxf(dash_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	piercing_timer = maxf(piercing_timer - delta, 0.0)
	glide_timer = maxf(glide_timer - delta, 0.0)
	var dash_motion_is_active := dash_timer > 0.0 or piercing_timer > 0.0
	if dash_motion_was_active and not dash_motion_is_active and dash_started_in_air and tiene_planeo:
		glide_timer = GLIDE_DURATION
		velocity.y = 0.0
	dash_started_in_air = dash_started_in_air and dash_motion_is_active
	if fury_combo_timer > 0.0:
		fury_combo_timer = maxf(fury_combo_timer - delta, 0.0)
		if is_zero_approx(fury_combo_timer):
			fury_hits = 0
			_sync_attack_palette()
	if not tiene_escudo or shield_ready or shield_recharge_timer <= 0.0:
		return
	shield_recharge_timer = maxf(shield_recharge_timer - delta, 0.0)
	if is_zero_approx(shield_recharge_timer):
		shield_ready = true
		_sync_shield_visual()

func _consume_shield() -> void:
	shield_ready = false
	is_guarding = false
	shield_recharge_timer = SHIELD_RECHARGE_SECONDS
	_sync_shield_visual()
	if _shield_material != null:
		_shield_material.set_shader_parameter("hit_flash", 1.0)
		var flash_tween := create_tween()
		flash_tween.tween_method(
			func(value: float): _shield_material.set_shader_parameter("hit_flash", value),
			1.0,
			0.0,
			0.18
		)

func get_current_melee_damage() -> int:
	if not tiene_furia_creciente:
		return attack_damage
	return roundi(float(attack_damage) * (1.0 + float(fury_hits) * FURY_DAMAGE_PER_HIT))

func _register_fury_hit() -> void:
	if not tiene_furia_creciente:
		return
	fury_hits = mini(fury_hits + 1, FURY_MAX_HITS)
	fury_combo_timer = FURY_COMBO_TIMEOUT
	_sync_attack_palette()

func _sync_shield_visual() -> void:
	if shield_visual == null:
		return
	shield_visual.visible = tiene_escudo and shield_ready and is_guarding
	if _shield_material != null:
		_shield_material.set_shader_parameter("strength", 1.0 if shield_ready else 0.0)

func _sync_attack_palette() -> void:
	if _attack_palette_material == null:
		return
	var replacement_color := Color(1.0, 0.08, 0.04, 1.0)
	var is_offensive_state := current_state == State.Attack or current_state == State.Glide
	var effect_strength := 1.0 if tiene_furia_creciente and fury_hits > 0 and is_offensive_state else 0.0
	_attack_palette_material.set_shader_parameter("replacement_color", replacement_color)
	_attack_palette_material.set_shader_parameter("effect_strength", effect_strength)

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO) -> void:
	if invulnerability_timer > 0.0 or hearts <= 0:
		return
	if tiene_escudo and shield_ready and is_guarding:
		_consume_shield()
		return
	fury_hits = 0
	fury_combo_timer = 0.0
	_sync_attack_palette()

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
	var hit_enemy := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.global_position.distance_to(attack_origin) > attack_range:
			continue
		if enemy_node.has_method("receive_damage"):
			enemy_node.receive_damage(get_current_melee_damage(), global_position)
			hit_enemy = true
		elif enemy_node.has_method("recibir_daño"):
			enemy_node.recibir_daño(get_current_melee_damage(), global_position)
			hit_enemy = true
	if hit_enemy and not debug_fury_counts_attacks:
		_register_fury_hit()
	if hit_enemy:
		AudioManager.play_sfx(&"eldric_impact", 0.05)

func _apply_piercing_damage() -> void:
	var attack_origin := global_position + Vector2(piercing_direction * 34.0, -10.0)
	var hit_enemy := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue
		var enemy_node := enemy as Node2D
		var enemy_id := enemy_node.get_instance_id()
		if piercing_hit_targets.has(enemy_id):
			continue
		if enemy_node.global_position.distance_to(attack_origin) > attack_range * 1.6:
			continue
		if enemy_node.has_method("receive_damage"):
			enemy_node.receive_damage(get_current_melee_damage(), global_position)
			hit_enemy = true
		elif enemy_node.has_method("recibir_daño"):
			enemy_node.recibir_daño(get_current_melee_damage(), global_position)
			hit_enemy = true
		if hit_enemy:
			piercing_hit_targets[enemy_id] = true
	if hit_enemy and not debug_fury_counts_attacks:
		_register_fury_hit()
	if hit_enemy:
		AudioManager.play_sfx(&"eldric_impact", 0.05)

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
