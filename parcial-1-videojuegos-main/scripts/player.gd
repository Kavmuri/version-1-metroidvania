extends CharacterBody2D

# ── Físicas ──────────────────────────────────────────
const SPEED = 200.0
const JUMP_VELOCITY = -350.0
const JUMP_VELOCITY_ALTO = -800.0

# ── Referencias ──────────────────────────────────────
@onready var sprite      = $cuerpo/AnimatedSprite2D
@onready var anim_player = $AnimationPlayer
@onready var cuerpo      = $cuerpo

# ── Exports ──────────────────────────────────────────
@export var distancia_activacion_asomo: float = 150.0
@export var fuerza_asomo: float = 100.0
@export var velocidad_ataque: float = 2.0
@export var escena_derrota: PackedScene

# ── Salud ─────────────────────────────────────────────
@export var vida_maxima: int = 5
var vida_actual: int

# ── Sistema de armas ─────────────────────────────────
enum Arma { PUNOS, ESPADA, PISTOLA }

var slots: Array = [null, null]   # Máximo 2 armas equipadas
var slot_activo: int = 0          # 0 o 1
var arma_activa: Arma = Arma.PUNOS

# Sufijo de animación por arma
const SUFIJO_ARMA = {
	Arma.PUNOS:   "Punch",
	Arma.ESPADA:  "Sword",
	Arma.PISTOLA: "Gun"
}

# ── Sistema de ataque ─────────────────────────────────
var combo_paso = 1
var esta_atacando = false
var tiempo_ultimo_ataque = 0.0
const TIEMPO_RESET_COMBO = 1000

# ── Habilidades ───────────────────────────────────────
var tiene_doble_salto: bool = false
var tiene_salto_alto: bool = false
var saltos_restantes: int = 1

# ── Muerte ────────────────────────────────────────────
var _pantalla_derrota = null

# ── Hit flash / knockback / i-frames ─────────────────
@export var knockback_fuerza: float = 300.0
@export var knockback_duracion: float = 0.15
@export var iframes_duracion: float = 0.6
@export var flash_duracion: float = 0.08   # tiempo por parpadeo
var _invencible: bool = false
var _knockback_vel: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0

# ─────────────────────────────────────────────────────
func _ready():
	vida_actual = vida_maxima
	if escena_derrota != null:
		_pantalla_derrota = escena_derrota.instantiate()
		get_tree().root.add_child.call_deferred(_pantalla_derrota)
	
	# Conectar señales programáticamente
	var hurtbox = get_node_or_null("hurtbox")
	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Siempre inicia sin armas — solo puños
	slots = [null, null]
	slot_activo = 0
	arma_activa = Arma.PUNOS
	print("Jugador iniciado sin armas (puños)")

# ─────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ── Knockback ─────────────────────────────────────────
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity = _knockback_vel
		move_and_slide()
		return   # bloquea el input mientras dura el empuje
	# ─────────────────────────────────────────────────────

	# Salto
	if is_on_floor():
		saltos_restantes = 2 if tiene_doble_salto else 1
	if Input.is_action_just_pressed("salto") and saltos_restantes > 0:
		var salto_alto_activo = tiene_salto_alto and Input.is_action_pressed("arriba")
		velocity.y = JUMP_VELOCITY_ALTO if salto_alto_activo else JUMP_VELOCITY
		saltos_restantes -= 1

	# Ataque
	if Input.is_action_just_pressed("atacar"):
		ejecutar_ataque()

	if esta_atacando:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# Cambio de slot con Q (o el botón que prefieras)
	if Input.is_action_just_pressed("cambiar_arma"):
		cambiar_slot()

	# Movimiento horizontal
	var direction := Input.get_axis("izquierda", "derecha")
	if direction:
		velocity.x = direction * SPEED
		cuerpo.scale.x = 1 if direction > 0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	actualizar_animaciones_locomocion(direction)
	move_and_slide()
	gestionar_asomo_camara()

# ─────────────────────────────────────────────────────
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			morir()

# ── Animaciones ───────────────────────────────────────
func actualizar_animaciones_locomocion(dir: float):
	var sufijo = SUFIJO_ARMA[arma_activa]
	if is_on_floor():
		if dir == 0:
			sprite.play("idle" + sufijo)
		else:
			sprite.play("run" + sufijo)
	else:
		# El salto es genérico por ahora — ajusta si tienes jumpSword etc.
		sprite.play("jump")

# ── Ataque ────────────────────────────────────────────
func ejecutar_ataque():
	var tiempo_actual = Time.get_ticks_msec()
	if tiempo_actual - tiempo_ultimo_ataque > TIEMPO_RESET_COMBO:
		combo_paso = 1
	if esta_atacando:
		return

	esta_atacando = true

	var sufijo = SUFIJO_ARMA[arma_activa]
	var sufijo_anim = sufijo.to_lower()
	
	sprite.play("atk" + sufijo + str(combo_paso))
	anim_player.play(sufijo_anim + str(combo_paso))

	await anim_player.animation_finished

	tiempo_ultimo_ataque = Time.get_ticks_msec()
	combo_paso = 1 if combo_paso >= 3 else combo_paso + 1
	esta_atacando = false
	reiniciar_combo_tras_espera()

func reiniciar_combo_tras_espera():
	await get_tree().create_timer(0.9).timeout
	if not esta_atacando:
		combo_paso = 1

# ── Sistema de armas ──────────────────────────────────
func otorgar_arma(tipo: String):
	var nueva_arma: Arma
	match tipo:
		"espada":   nueva_arma = Arma.ESPADA
		"pistola":  nueva_arma = Arma.PISTOLA
		_:
			push_warning("Tipo de arma desconocido: " + tipo)
			return

	# Buscar slot libre primero
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = nueva_arma
			slot_activo = i
			arma_activa = nueva_arma
			print("Arma obtenida en slot ", i, ": ", tipo)
			return

	# Si no hay slot libre, reemplazar el slot activo
	slots[slot_activo] = nueva_arma
	arma_activa = nueva_arma
	print("Slot ", slot_activo, " reemplazado con: ", tipo)

func cambiar_slot():
	# Alterna entre slot 0 y slot 1
	var otro_slot = 1 if slot_activo == 0 else 0
	if slots[otro_slot] == null and slots[slot_activo] == null:
		return  # Ambos vacíos, nada que cambiar
	slot_activo = otro_slot
	arma_activa = slots[slot_activo] if slots[slot_activo] != null else Arma.PUNOS
	print("Cambiado a slot ", slot_activo, ": ", Arma.keys()[arma_activa])

func arma_activa_nombre() -> String:
	return Arma.keys()[arma_activa].to_lower()

# ── Habilidades ───────────────────────────────────────
func otorgar_habilidad(tipo: String):
	match tipo:
		"doble_salto":
			tiene_doble_salto = true
			print("Habilidad: Doble salto")
		"salto_alto":
			tiene_salto_alto = true
			print("Habilidad: Salto alto")

# ── Cámara ────────────────────────────────────────────
func gestionar_asomo_camara():
	var camara = $Camera2D
	var salida_cercana = null
	var min_distancia = distancia_activacion_asomo
	for salida in get_tree().get_nodes_in_group("salidas"):
		var dist = global_position.distance_to(salida.global_position)
		if dist < min_distancia:
			min_distancia = dist
			salida_cercana = salida
	if salida_cercana:
		var dir_hacia_puerta = (salida_cercana.global_position - global_position).normalized()
		camara.offset_asomo = dir_hacia_puerta * fuerza_asomo
	else:
		camara.offset_asomo = Vector2.ZERO

# ── Muerte ────────────────────────────────────────────
func morir():
	if _pantalla_derrota != null:
		_pantalla_derrota.mostrar()

func recibir_daño(cantidad: int = 1, fuente_pos: Vector2 = Vector2.ZERO):
	if _invencible:
		return
	vida_actual -= cantidad
	print("Jugador recibió daño. Vida: ", vida_actual)
	if vida_actual <= 0:
		morir()
		return
	# Knockback: empuja en dirección opuesta a la fuente
	var dir_golpe = Vector2.RIGHT
	if fuente_pos != Vector2.ZERO:
		dir_golpe = (global_position - fuente_pos).normalized()
		if dir_golpe == Vector2.ZERO:
			dir_golpe = Vector2.RIGHT
	_knockback_vel = dir_golpe * knockback_fuerza
	_knockback_timer = knockback_duracion
	# Hit flash + i-frames
	_invencible = true
	_iniciar_hit_flash()

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("hitbox_enemigo"):
		recibir_daño(1, area.global_position)

# ── Hit flash (parpadeo blanco) ───────────────────────
func _iniciar_hit_flash():
	var tween = create_tween()
	var pasos = int(iframes_duracion / (flash_duracion * 2.0))
	for i in range(pasos):
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.0)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), flash_duracion)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), 0.0)
		tween.tween_property(sprite, "modulate", Color.WHITE, flash_duracion)
	tween.tween_callback(func():
		sprite.modulate = Color.WHITE
		_invencible = false
)
