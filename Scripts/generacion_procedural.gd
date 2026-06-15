extends Node2D

@export var plantillas_spawn: Array[PackedScene]
@export var plantillas_habitaciones: Array[PackedScene]
@export var plantillas_deadends: Array[PackedScene]
@export var max_misma_hab_seguida: int = 1

var habitaciones_colocadas: Array[Node2D] = []
var puertas_abiertas: Array[Dictionary] = []
var historial_tipos: Array[String] = []
var opuestos = {"izq": "der", "der": "izq", "arriba": "abajo", "abajo": "arriba"}
var habitacion_inicio: Node2D = null

# { habitacion_node: [habitacion_vecina, ...] }
var adyacencia: Dictionary = {}

func _ready():
	var objetivo = randi_range(5, 10) # Reducido para pruebas iniciales
	print("Objetivo: ", objetivo, " habitaciones")
	generar_mazmorra(objetivo)
	cerrar_puertas_abiertas()
	if has_node("spawnPlayer"):
		$spawnPlayer.iniciar(self)
	print("\n=== REPORTE FINAL ===")
	print("Total habitaciones: ", habitaciones_colocadas.size())
	print("Puertas sin cerrar: ", puertas_abiertas.size())
	if puertas_abiertas.size() > 0:
		var faltantes = {}
		for p in puertas_abiertas:
			var nombre = "salida_" + opuestos[p.direccion]
			faltantes[nombre] = faltantes.get(nombre, 0) + 1
		for nombre in faltantes:
			print("  → ", nombre, " (", faltantes[nombre], " veces)")

# ─────────────────────────────────────────────────────
func generar_mazmorra(limite: int):
	if plantillas_spawn.is_empty():
		push_warning("No hay plantillas de spawn asignadas.")
		return

	var inicio = plantillas_spawn.pick_random().instantiate()
	habitacion_inicio = inicio
	add_child(inicio)
	inicio.global_position = Vector2.ZERO
	habitaciones_colocadas.append(inicio)
	adyacencia[inicio] = []
	registrar_puertas(inicio)
	historial_tipos.append(inicio.scene_file_path)

	print("Sala spawn colocada. Puertas registradas: ", puertas_abiertas.size())

	var creadas = 1
	var intentos_sin_exito = 0

	while creadas < limite and puertas_abiertas.size() > 0:
		if intentos_sin_exito >= 20:
			puertas_abiertas.remove_at(0)
			intentos_sin_exito = 0
			continue

		var p_idx = randi() % puertas_abiertas.size()
		var p_salida = puertas_abiertas[p_idx]
		var dir_necesitada = opuestos[p_salida.direccion]
		var nombre_buscado = "salida_" + dir_necesitada

		var plantilla_valida = buscar_plantilla_compatible_sin_repetir(nombre_buscado, plantillas_habitaciones)

		if plantilla_valida == null:
			if cerrar_puerta_individual(p_salida):
				puertas_abiertas.remove_at(p_idx)
			else:
				puertas_abiertas.remove_at(p_idx)
			continue

		var nueva_hab = plantilla_valida.instantiate()
		add_child(nueva_hab)

		var p_entrada = obtener_marcador(nueva_hab, nombre_buscado)
		nueva_hab.global_position = p_salida.nodo.global_position - p_entrada.position

		if not esta_chocando(nueva_hab):
			habitaciones_colocadas.append(nueva_hab)
			registrar_puertas(nueva_hab)
			puertas_abiertas.remove_at(p_idx)
			creadas += 1
			intentos_sin_exito = 0
			historial_tipos.append(plantilla_valida.resource_path)
			if historial_tipos.size() > 5:
				historial_tipos.remove_at(0)

			_registrar_adyacencia(p_salida.habitacion, nueva_hab)

			print("Habitación #", creadas, " (", plantilla_valida.resource_path.get_file(), ") colocada. Puertas abiertas: ", puertas_abiertas.size())
			cerrar_puertas_bloqueadas()
		else:
			nueva_hab.queue_free()
			intentos_sin_exito += 1

	print("Generación terminada. Habitaciones: ", creadas)

# ─────────────────────────────────────────────────────
func cerrar_puertas_bloqueadas():
	var i = puertas_abiertas.size() - 1
	while i >= 0:
		var p = puertas_abiertas[i]
		if espacio_bloqueado(p):
			# La puerta tiene otra sala enfrente → son vecinas, no hace falta dead end
			var bloqueadora = _habitacion_en_direccion(p)
			if bloqueadora != null and bloqueadora != p.habitacion:
				_registrar_adyacencia(p.habitacion, bloqueadora)
				print("  → Puerta bloqueada: '", p.habitacion.name, "' ↔ '", bloqueadora.name, "' (conectadas)")
			else:
				print("  → Puerta bloqueada por geometría pura, descartada")
			puertas_abiertas.remove_at(i)
		i -= 1

# ─────────────────────────────────────────────────────
func cerrar_puertas_abiertas():
	if plantillas_deadends.is_empty():
		push_warning("No hay plantillas de dead ends asignadas.")
		return

	print("\nPuertas abiertas antes de cierre final: ", puertas_abiertas.size())
	var i = puertas_abiertas.size() - 1
	while i >= 0:
		var p = puertas_abiertas[i]
		if cerrar_puerta_individual(p):
			puertas_abiertas.remove_at(i)
		else:
			# Sin dead end que encaje → ver si hay sala adyacente bloqueando
			var bloqueadora = _habitacion_en_direccion(p)
			if bloqueadora != null and bloqueadora != p.habitacion:
				_registrar_adyacencia(p.habitacion, bloqueadora)
				print("  → Sin dead end: '", p.habitacion.name, "' conectada a '", bloqueadora.name, "'")
			else:
				print("  → Sin dead end y sin sala adyacente — sellada por geometría")
			puertas_abiertas.remove_at(i)
		i -= 1

# ─────────────────────────────────────────────────────
# Prueba TODAS las plantillas de dead end ordenadas de menor a mayor tamaño
func cerrar_puerta_individual(p_salida: Dictionary) -> bool:
	var dir_necesitada = opuestos[p_salida.direccion]
	var nombre_buscado = "salida_" + dir_necesitada

	var candidatos = _deadends_ordenados_por_tamano(nombre_buscado)
	for plantilla in candidatos:
		var sala = plantilla.instantiate()
		add_child(sala)

		var p_entrada = obtener_marcador(sala, nombre_buscado)
		if p_entrada == null:
			sala.queue_free()
			continue

		sala.global_position = p_salida.nodo.global_position - p_entrada.position

		if not esta_chocando(sala):
			habitaciones_colocadas.append(sala)
			_registrar_adyacencia(p_salida.habitacion, sala)
			print("  → Dead end '", nombre_buscado, "' OK (", plantilla.resource_path.get_file(), ")")
			return true
		else:
			sala.queue_free()

	return false

# Devuelve los dead ends compatibles con esa puerta, del más pequeño al más grande
func _deadends_ordenados_por_tamano(nombre_puerta: String) -> Array[PackedScene]:
	var resultado: Array[PackedScene] = []
	var con_tamano: Array = []

	for plantilla in plantillas_deadends:
		var prueba = plantilla.instantiate()
		if obtener_marcador(prueba, nombre_puerta) != null:
			var sup = _superficie_de(prueba)
			con_tamano.append({"plantilla": plantilla, "sup": sup})
		prueba.queue_free()

	con_tamano.sort_custom(func(a, b): return a.sup < b.sup)
	for entrada in con_tamano:
		resultado.append(entrada.plantilla)
	return resultado

func _superficie_de(nodo: Node2D) -> float:
	var r = nodo.get_node_or_null("ReferenceRect")
	if r == null:
		return 0.0   # Sin ReferenceRect → va primero (más fácil de colocar)
	return r.get_rect().size.x * r.get_rect().size.y

# ─────────────────────────────────────────────────────
# Qué habitación ocupa el espacio justo frente a una puerta
func _habitacion_en_direccion(puerta: Dictionary) -> Node2D:
	var pos = puerta.nodo.global_position
	var offset = Vector2.ZERO
	match puerta.direccion:
		"der":    offset = Vector2(8, 0)
		"izq":    offset = Vector2(-8, 0)
		"abajo":  offset = Vector2(0, 8)
		"arriba": offset = Vector2(0, -8)
	var punto = pos + offset
	for hab in habitaciones_colocadas:
		if obtener_area(hab).has_point(punto):
			return hab
	return null

# Adyacencia bidireccional
func _registrar_adyacencia(a: Node2D, b: Node2D) -> void:
	if not adyacencia.has(a): adyacencia[a] = []
	if not adyacencia.has(b): adyacencia[b] = []
	if not adyacencia[a].has(b): adyacencia[a].append(b)
	if not adyacencia[b].has(a): adyacencia[b].append(a)

# ─────────────────────────────────────────────────────
func espacio_bloqueado(puerta: Dictionary) -> bool:
	var pos = puerta.nodo.global_position
	var offset = Vector2.ZERO
	match puerta.direccion:
		"der":    offset = Vector2(8, 0)
		"izq":    offset = Vector2(-8, 0)
		"abajo":  offset = Vector2(0, 8)
		"arriba": offset = Vector2(0, -8)
	return _habitacion_en_punto(pos + offset) != null

func _habitacion_en_punto(punto: Vector2) -> Node2D:
	for hab in habitaciones_colocadas:
		if obtener_area(hab).has_point(punto):
			return hab
	return null

func buscar_plantilla_compatible_sin_repetir(nombre_puerta: String, plantillas: Array[PackedScene]) -> PackedScene:
	var lista = plantillas.duplicate()
	lista.shuffle()
	var recientes = historial_tipos.slice(max(0, historial_tipos.size() - max_misma_hab_seguida))

	for plantilla in lista:
		if recientes.has(plantilla.resource_path):
			continue
		var prueba = plantilla.instantiate()
		var tiene = obtener_marcador(prueba, nombre_puerta) != null
		prueba.queue_free()
		if tiene:
			return plantilla

	for plantilla in lista:
		var prueba = plantilla.instantiate()
		var tiene = obtener_marcador(prueba, nombre_puerta) != null
		prueba.queue_free()
		if tiene:
			return plantilla

	return null

func buscar_plantilla_compatible(nombre_puerta: String, plantillas: Array[PackedScene]) -> PackedScene:
	var lista = plantillas.duplicate()
	lista.shuffle()
	for plantilla in lista:
		var prueba = plantilla.instantiate()
		var tiene = obtener_marcador(prueba, nombre_puerta) != null
		prueba.queue_free()
		if tiene:
			return plantilla
	return null

func registrar_puertas(hab: Node2D):
	var nodo_p = hab.get_node_or_null("puertas")
	if nodo_p == null:
		push_warning("No se encontró el nodo 'puertas' en: " + hab.name)
		return
	for hijo in nodo_p.get_children():
		if hijo is Marker2D and hijo.name.begins_with("salida_"):
			var partes = str(hijo.name).split("_")
			if partes.size() < 2:
				push_warning("Nombre mal formado: " + hijo.name)
				continue
			puertas_abiertas.append({
				"nodo": hijo,
				"direccion": partes[1],
				"habitacion": hab
			})

func obtener_marcador(hab: Node2D, nombre: String) -> Marker2D:
	return hab.get_node_or_null("puertas/" + nombre) as Marker2D

func esta_chocando(nueva: Node2D) -> bool:
	var rect_n = obtener_area(nueva)
	if rect_n == Rect2():
		return false
	for vieja in habitaciones_colocadas:
		if rect_n.intersects(obtener_area(vieja), false):
			return true
	return false

func obtener_area(hab: Node2D) -> Rect2:
	var r = hab.get_node_or_null("ReferenceRect")
	if r == null:
		return Rect2()
	return Rect2(hab.global_position + r.position, r.size)
