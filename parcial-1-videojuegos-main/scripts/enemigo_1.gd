extends CharacterBody2D

# ── Exports ──────────────────────────────────────────
@export var vida_maxima: int = 3
@export var velocidad: float = 60.0
@export var chance_drop: float = 0.30
@export var escena_drop_espada: PackedScene
@export var escena_drop_pistola: PackedScene

# ── Referencias ──────────────────────────────────────
@onready var sprite = $cuerpo/AnimatedSprite2D

# ── Estado ───────────────────────────────────────────
var vida_actual: int
var jugador: CharacterBody2D = null
var esta_muerto: bool = false
var dir_patrulla: float = 1.0

# ── Hit flash / knockback ─────────────────────────────
@export var knockback_fuerza: float = 250.0
@export var knockback_duracion: float = 0.12
@export var flash_duracion: float = 0.07
var _knockback_vel: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0

func _ready():
	vida_actual = vida_maxima
	# Buscar jugador en el grupo
	var jugadores = get_tree().get_nodes_in_group("jugador")
	if jugadores.size() > 0:
		jugador = jugadores[0]
	
	# Configurar hurtbox: capa 2 para detectar el hitbox del jugador
	var hurtbox = get_node_or_null("hurtbox")
	if hurtbox:
		hurtbox.collision_mask = 2   # el hitbox del jugador vive en capa 2
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _physics_process(delta: float):
	if esta_muerto:
		return

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ── Knockback ─────────────────────────────────────────
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity = _knockback_vel
		move_and_slide()
		return
	# ─────────────────────────────────────────────────────

	# Movimiento hacia el jugador si está cerca
	if jugador != null:
		var distancia = global_position.distance_to(jugador.global_position)
		if distancia < 200.0:
			var dir = sign(jugador.global_position.x - global_position.x)
			velocity.x = dir * velocidad
			sprite.flip_h = dir < 0
			_play_safe("run")
		else:
			_patrullar()
	else:
		_patrullar()

	move_and_slide()

func _patrullar():
	# Invertir dirección si choca con una pared
	if is_on_wall():
		dir_patrulla *= -1
	
	# Invertir dirección si hay un precipicio
	# Usamos test_move para ver si hay suelo un poco más adelante y abajo
	var offset_suelo = Vector2(dir_patrulla * 15, 10)
	if not test_move(transform.translated(offset_suelo), Vector2.DOWN * 20):
		# No hay suelo adelante -> dar la vuelta
		dir_patrulla *= -1
	
	velocity.x = dir_patrulla * (velocidad * 0.5) # Patrulla más lento
	sprite.flip_h = dir_patrulla < 0
	_play_safe("walk")

func _play_safe(anim_name: String):
	if sprite == null or sprite.sprite_frames == null:
		return
	
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		# Fallbacks
		if anim_name == "run" and sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")
		elif (anim_name == "walk" or anim_name == "run") and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		elif sprite.sprite_frames.has_animation("default"):
			sprite.play("default")

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO):
	if esta_muerto:
		return
	vida_actual -= cantidad
	print(name, " recibió daño. Vida: ", vida_actual)
	if vida_actual <= 0:
		morir()
		return
	# Knockback
	var dir_golpe = Vector2.RIGHT
	if fuente_pos != Vector2.ZERO:
		dir_golpe = (global_position - fuente_pos).normalized()
		if dir_golpe == Vector2.ZERO:
			dir_golpe = Vector2.RIGHT
	_knockback_vel = dir_golpe * knockback_fuerza
	_knockback_timer = knockback_duracion
	# Hit flash
	_iniciar_hit_flash()

func _iniciar_hit_flash():
	var tween = create_tween()
	var pasos = 3
	for i in range(pasos):
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 1.0), 0.0)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0.3), flash_duracion)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0.3), 0.0)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 1.0), flash_duracion)
	tween.tween_callback(func(): sprite.modulate = Color.WHITE)

func morir():
	esta_muerto = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	_drop_arma()
	# Animación de muerte si tienes una
	# sprite.play("death")
	# await sprite.animation_finished
	queue_free()

func _drop_arma():
	if randf() > chance_drop:
		return
	var drops = []
	if escena_drop_espada: drops.append(escena_drop_espada)
	if escena_drop_pistola: drops.append(escena_drop_pistola)
	if drops.is_empty():
		return
	var drop = drops.pick_random().instantiate()
	get_parent().add_child(drop)
	drop.global_position = global_position

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("hitbox_jugador"):
		recibir_daño(1, area.global_position)
