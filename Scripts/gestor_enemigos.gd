extends Node

# ── Exports ───────────────────────────────────────────
@export var escenas_enemigos: Array[PackedScene]   # arrastra enemigo_1.tscn, etc.
@export var enemigos_por_sala: int = 3
@export var margen_paredes: float = 48.0           # distancia mínima a los bordes del room

# ── Referencias (las llena spawn_player.gd) ──────────
var generador: Node2D = null
var jugador: Node2D = null
var adyacencia: Dictionary = {}                    # { room_node: [vecinos] }

# ── Estado interno ────────────────────────────────────
# { room_node: [enemy_nodes] }  — solo rooms con enemigos vivos
var enemigos_activos: Dictionary = {}
var habitacion_actual: Node2D = null

# ─────────────────────────────────────────────────────
# Llamado desde spawn_player.gd después de instanciar al jugador
func iniciar(gen: Node2D, jug: Node2D, adj: Dictionary) -> void:
	generador  = gen
	jugador    = jug
	adyacencia = adj
	set_process(true)

# ─────────────────────────────────────────────────────
func _ready() -> void:
	set_process(false)   # inactivo hasta que iniciar() lo encienda

func _process(_delta: float) -> void:
	if jugador == null or generador == null:
		return

	var nueva_hab = _habitacion_del_jugador()

	# Solo actuar cuando el jugador cambia de habitación
	if nueva_hab == habitacion_actual:
		return

	habitacion_actual = nueva_hab

	# Actualizar límites de cámara
	if habitacion_actual != null:
		var camara = jugador.get_node_or_null("Camera2D")
		if camara != null and camara.has_method("actualizar_limites_camara"):
			camara.actualizar_limites_camara(_area_de(habitacion_actual))

	_actualizar_spawns()

# ─────────────────────────────────────────────────────
# Devuelve la habitación en cuyo ReferenceRect está el jugador
func _habitacion_del_jugador() -> Node2D:
	var pos = jugador.global_position
	for hab in generador.habitaciones_colocadas:
		if _area_de(hab).has_point(pos):
			return hab
	return null

# ─────────────────────────────────────────────────────
# Calcula el conjunto de rooms "activos" y hace spawn/despawn
func _actualizar_spawns() -> void:
	if habitacion_actual == null:
		return

	# Salas que deben tener enemigos = actual + vecinas
	var vecinas: Array = adyacencia.get(habitacion_actual, [])
	var activas: Array = [habitacion_actual] + vecinas

	# ── Despawnear rooms que ya no deben estar activas ──
	for hab in enemigos_activos.keys():
		if not activas.has(hab):
			_despawnear(hab)

	# ── Spawnear rooms que aún no tienen enemigos ──
	for hab in activas:
		if not enemigos_activos.has(hab):
			_spawnear_en(hab)

	print("[GestorEnemigos] Sala actual: ", habitacion_actual.name,
		  " | Vecinas activas: ", vecinas.size(),
		  " | Rooms con enemigos: ", enemigos_activos.size())

# ─────────────────────────────────────────────────────
func _spawnear_en(hab: Node2D) -> void:
	if escenas_enemigos.is_empty():
		push_warning("GestorEnemigos: no hay escenas_enemigos asignadas.")
		return

	# No spawnear en la habitación de inicio o zonas de spawn seguras
	if hab == generador.habitacion_inicio or hab.name.to_lower().contains("spawn"):
		print("[GestorEnemigos] Omitiendo spawn en zona segura: ", hab.name)
		return

	var area = _area_de(hab)
	if area == Rect2():
		return

	# Zona segura dentro del room (sin pegar a las paredes)
	var zona = Rect2(
		area.position + Vector2(margen_paredes, margen_paredes),
		area.size    - Vector2(margen_paredes * 2.0, margen_paredes * 2.0)
	)
	if zona.size.x <= 0 or zona.size.y <= 0:
		push_warning("GestorEnemigos: habitación demasiado pequeña para spawnear: " + hab.name)
		return

	var lista: Array = []
	for i in range(enemigos_por_sala):
		var escena: PackedScene = escenas_enemigos.pick_random()
		var enemigo: Node2D = escena.instantiate()
		generador.add_child(enemigo)

		# Spawn en la mitad inferior del room (más natural para plataformero)
		var x = randf_range(zona.position.x, zona.position.x + zona.size.x)
		var y = randf_range(
			zona.position.y + zona.size.y * 0.5,   # mitad inferior
			zona.position.y + zona.size.y
		)
		enemigo.global_position = Vector2(x, y)
		lista.append(enemigo)

	enemigos_activos[hab] = lista
	print("[GestorEnemigos] Spawneados ", lista.size(), " enemigos en ", hab.name)

# ─────────────────────────────────────────────────────
func _despawnear(hab: Node2D) -> void:
	if not enemigos_activos.has(hab):
		return
	var lista: Array = enemigos_activos[hab]
	for enemigo in lista:
		if is_instance_valid(enemigo):
			enemigo.queue_free()
	enemigos_activos.erase(hab)
	print("[GestorEnemigos] Despawneados enemigos de ", hab.name)

# ─────────────────────────────────────────────────────
func _area_de(hab: Node2D) -> Rect2:
	var r = hab.get_node_or_null("ReferenceRect")
	if r == null:
		return Rect2()
	return Rect2(hab.global_position + r.position, r.size)
