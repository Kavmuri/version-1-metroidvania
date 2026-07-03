extends Node

const DEFAULT_HUD_SCENE := preload("res://UI/scenes/gameplay_hud.tscn")
const DEFAULT_PAUSE_SCENE := preload("res://UI/scenes/pause_menu.tscn")

@export var escena_jugador: PackedScene
@export var escena_mapa_ui: PackedScene
@export var escena_player2: PackedScene
@export var escena_hud: PackedScene
@export var escena_pausa: PackedScene

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
	var jugador = _escena_jugador_principal().instantiate()
	jugador.name = "Player1"
	generador.add_child(jugador)
	jugador.global_position = pos_spawn
	_configurar_modo_input(jugador, "both" if GameManager.current_game_mode == "single" else "keyboard")
	GameManager.register_player1(jugador)

	# Configurar límites de cámara
	var camara = jugador.get_node_or_null("Camera2D")
	if camara == null:
		camara = Camera2D.new()
		camara.name = "Camera2D"
		camara.position = Vector2(0, -21)
		jugador.add_child(camara)
	if camara != null:
		var limites = _calcular_limites(generador.habitaciones_colocadas)
		_aplicar_limites_camara(camara, limites)
		camara.make_current()
		print("Límites → L:", camara.limit_left, " T:", camara.limit_top, " R:", camara.limit_right, " B:", camara.limit_bottom)
	else:
		push_warning("El jugador no tiene Camera2D hijo.")

	# Instanciar el mapa UI y conectarlo
	if escena_mapa_ui != null:
		var mapa_ui = escena_mapa_ui.instantiate()
		generador.add_child(mapa_ui)
		mapa_ui.generador = generador
		mapa_ui.jugador = jugador

	var player2_guardado: Node2D = null
	if GameManager.should_restore_player2() and escena_player2 != null:
		player2_guardado = escena_player2.instantiate()
		player2_guardado.name = "Player2"
		generador.add_child(player2_guardado)
		player2_guardado.global_position = jugador.global_position + Vector2(72, -24)
		_configurar_modo_input(player2_guardado, "gamepad")
		GameManager.register_player2(player2_guardado)

	GameManager.apply_pending_positions(jugador, player2_guardado)
	GameManager.save_initial_spawn_if_needed()

	var hud_scene: PackedScene = escena_hud if escena_hud != null else DEFAULT_HUD_SCENE
	if hud_scene != null:
		var hud = hud_scene.instantiate()
		generador.add_child(hud)
		if hud.has_method("setup"):
			hud.setup(jugador, player2_guardado)

	var pause_scene: PackedScene = escena_pausa if escena_pausa != null else DEFAULT_PAUSE_SCENE
	if pause_scene != null:
		var pausa = pause_scene.instantiate()
		generador.add_child(pausa)
		if pausa.has_method("setup"):
			pausa.setup(jugador)

	# NUEVO: Si no hay escena de mapa UI pero el script existe, podemos intentar añadirlo directamente
	# si es que no se pasó como escena (para mayor flexibilidad)

	var debug_ui = load("res://Scripts/debug_unlock_ui.gd").new()
	generador.add_child(debug_ui)
	debug_ui.jugador = jugador
	debug_ui.camara = camara
	debug_ui.escena_player2 = escena_player2
	debug_ui.player2 = player2_guardado

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

func _aplicar_limites_camara(camara: Camera2D, limites: Rect2) -> void:
	var viewport_size = camara.get_viewport_rect().size
	var centro = limites.get_center()
	var ancho = max(limites.size.x, viewport_size.x)
	var alto = max(limites.size.y, viewport_size.y)
	var ajustado = Rect2(centro - Vector2(ancho, alto) * 0.5, Vector2(ancho, alto))

	camara.limit_left = floori(ajustado.position.x)
	camara.limit_top = floori(ajustado.position.y)
	camara.limit_right = ceili(ajustado.position.x + ajustado.size.x)
	camara.limit_bottom = ceili(ajustado.position.y + ajustado.size.y)

func _escena_jugador_principal() -> PackedScene:
	if GameManager.current_game_mode == "single" and GameManager.selected_single_player == "player2" and escena_player2 != null:
		return escena_player2
	return escena_jugador

func _configurar_modo_input(jugador: Node, modo: String) -> void:
	if "input_mode" in jugador:
		jugador.set("input_mode", modo)

func _obtener_area(hab: Node2D) -> Rect2:
	var r = hab.get_node_or_null("ReferenceRect")
	if r == null:
		return Rect2()
	return Rect2(hab.global_position + r.position, r.size)
