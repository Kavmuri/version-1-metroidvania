extends Node

@export var escena_jugador: PackedScene
@export var escena_mapa_ui: PackedScene

func iniciar(generador: Node2D):
	if escena_jugador == null:
		push_warning("No hay escena de jugador asignada en SpawnManager.")
		return

	var habitacion_inicio = generador.habitacion_inicio
	if habitacion_inicio == null:
		push_warning("El generador no tiene habitacion_inicio registrada.")
		return

	# Buscar punto de spawn
	var punto_spawn = habitacion_inicio.get_node_or_null("spawn")
	var pos_spawn: Vector2

	if punto_spawn and punto_spawn is Marker2D:
		pos_spawn = punto_spawn.global_position
		print("Spawn encontrado en: ", pos_spawn)
	else:
		var area = _obtener_area(habitacion_inicio)
		if area != Rect2():
			pos_spawn = area.get_center()
			push_warning("Marker2D 'spawn' no encontrado, usando centro de habitación inicial.")
		else:
			pos_spawn = Vector2.ZERO
			push_warning("Sin punto de spawn, usando (0,0).")

	# Instanciar jugador
	var jugador = escena_jugador.instantiate()
	generador.add_child(jugador)
	jugador.global_position = pos_spawn

	# Configurar límites de cámara
	var camara = jugador.get_node_or_null("Camera2D")
	if camara != null:
		var limites = _calcular_limites(generador.habitaciones_colocadas)
		camara.limit_left   = int(limites.position.x)
		camara.limit_top    = int(limites.position.y)
		camara.limit_right  = int(limites.position.x + limites.size.x)
		camara.limit_bottom = int(limites.position.y + limites.size.y)
		print("Límites → L:", camara.limit_left, " T:", camara.limit_top, " R:", camara.limit_right, " B:", camara.limit_bottom)
	else:
		push_warning("El jugador no tiene Camera2D hijo.")

	# Instanciar el mapa UI y conectarlo
	if escena_mapa_ui != null:
		var mapa_ui = escena_mapa_ui.instantiate()
		generador.add_child(mapa_ui)
		mapa_ui.generador = generador
		mapa_ui.jugador = jugador

	# NUEVO: Si no hay escena de mapa UI pero el script existe, podemos intentar añadirlo directamente
	# si es que no se pasó como escena (para mayor flexibilidad)

	var gestor = generador.get_node_or_null("gestorEnemigos")
	if gestor != null:
		gestor.iniciar(generador, jugador, generador.adyacencia)
	else:
		push_warning("No se encontró el nodo 'gestorEnemigos' en el generador. " +
					 "Añade un Node hijo con el script gestor_enemigos.gd y nómbralo 'gestorEnemigos'.")
	# ────────────────────────────────────────────────────────

func _calcular_limites(habitaciones: Array) -> Rect2:
	if habitaciones.is_empty():
		return Rect2(0, 0, 1280, 720)

	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for hab in habitaciones:
		var area = _obtener_area(hab)
		if area == Rect2():
			continue
		min_x = min(min_x, area.position.x)
		min_y = min(min_y, area.position.y)
		max_x = max(max_x, area.position.x + area.size.x)
		max_y = max(max_y, area.position.y + area.size.y)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _obtener_area(hab: Node2D) -> Rect2:
	var r = hab.get_node_or_null("ReferenceRect")
	if r == null:
		return Rect2()
	return Rect2(hab.global_position + r.position, r.size)
