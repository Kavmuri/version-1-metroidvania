extends CanvasLayer

const HOLD_SECONDS = 2.0
const ZOOM_STEP = 0.1
const MIN_ZOOM = 0.1
const MAX_ZOOM = 2.2

var jugador: Node = null
var camara: Camera2D = null
var escena_player2: PackedScene = null
var player2: Node2D = null
var hold_time := 0.0
var abierto := false
var control_camara_activo := false
var _m_puede_abrir := true

var panel: ColorRect
var salto_infinito_check: CheckBox
var dash_check: CheckBox
var control_camara_check: CheckBox
var player2_derecha_check: CheckBox
var zoom_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_construir_ui()

func _construir_ui() -> void:
	panel = ColorRect.new()
	panel.visible = false
	panel.color = Color(0.03, 0.04, 0.05, 0.9)
	panel.position = Vector2(16, 16)
	panel.size = Vector2(360, 232)
	add_child(panel)

	var titulo = Label.new()
	titulo.text = "DEBUG MENU"
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	titulo.position = Vector2(14, 12)
	panel.add_child(titulo)

	salto_infinito_check = CheckBox.new()
	salto_infinito_check.text = "Salto infinito"
	salto_infinito_check.position = Vector2(12, 44)
	salto_infinito_check.toggled.connect(_on_salto_infinito_toggled)
	panel.add_child(salto_infinito_check)

	dash_check = CheckBox.new()
	dash_check.text = "Dash"
	dash_check.position = Vector2(12, 76)
	dash_check.toggled.connect(_on_dash_toggled)
	panel.add_child(dash_check)

	control_camara_check = CheckBox.new()
	control_camara_check.text = "Control camara"
	control_camara_check.position = Vector2(12, 108)
	control_camara_check.toggled.connect(_on_control_camara_toggled)
	panel.add_child(control_camara_check)

	player2_derecha_check = CheckBox.new()
	player2_derecha_check.text = "Player2"
	player2_derecha_check.position = Vector2(12, 140)
	player2_derecha_check.toggled.connect(_on_player2_derecha_toggled)
	panel.add_child(player2_derecha_check)

	zoom_label = Label.new()
	zoom_label.position = Vector2(14, 180)
	zoom_label.add_theme_font_size_override("font_size", 13)
	zoom_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	panel.add_child(zoom_label)

	var ayuda = Label.new()
	ayuda.text = "Arriba/Abajo: zoom | M: cerrar"
	ayuda.position = Vector2(14, 204)
	ayuda.add_theme_font_size_override("font_size", 12)
	ayuda.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	panel.add_child(ayuda)

func _process(delta: float) -> void:
	if abierto:
		return

	if Input.is_key_pressed(KEY_M):
		if _m_puede_abrir:
			hold_time += delta
			if hold_time >= HOLD_SECONDS:
				_abrir()
	else:
		hold_time = 0.0
		_m_puede_abrir = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if abierto and event.keycode == KEY_M and not event.echo:
			_cerrar()
			get_viewport().set_input_as_handled()
		elif control_camara_activo and event.keycode == KEY_UP:
			_cambiar_zoom(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif control_camara_activo and event.keycode == KEY_DOWN:
			_cambiar_zoom(-ZOOM_STEP)
			get_viewport().set_input_as_handled()

func _abrir() -> void:
	abierto = true
	_m_puede_abrir = false
	hold_time = 0.0
	panel.visible = true
	_sincronizar_estado()

func _cerrar() -> void:
	abierto = false
	panel.visible = false

func _sincronizar_estado() -> void:
	if jugador != null:
		salto_infinito_check.button_pressed = jugador.get("tiene_salto_infinito")
		dash_check.button_pressed = jugador.get("tiene_dash")
	control_camara_check.button_pressed = control_camara_activo
	player2_derecha_check.button_pressed = player2 != null and is_instance_valid(player2)
	_actualizar_zoom()

func _on_salto_infinito_toggled(activo: bool) -> void:
	if jugador != null and jugador.has_method("set_salto_infinito_activo"):
		jugador.set_salto_infinito_activo(activo)

func _on_dash_toggled(activo: bool) -> void:
	if jugador != null and jugador.has_method("set_dash_activo"):
		jugador.set_dash_activo(activo)

func _on_control_camara_toggled(activo: bool) -> void:
	control_camara_activo = activo
	_actualizar_zoom()

func _on_player2_derecha_toggled(activo: bool) -> void:
	if activo:
		crear_player2()
		return

	if player2 != null and is_instance_valid(player2):
		player2.queue_free()
	player2 = null
	GameManager.register_player2(null)

func crear_player2() -> void:
	if jugador == null:
		push_warning("DebugUnlockUI: jugador no asignado.")
		player2_derecha_check.button_pressed = false
		return
	if escena_player2 == null:
		push_warning("DebugUnlockUI: escena_player2 no asignada.")
		player2_derecha_check.button_pressed = false
		return

	if player2 == null or not is_instance_valid(player2):
		player2 = escena_player2.instantiate()
		player2.name = "Player2"
		jugador.get_parent().add_child(player2)
		GameManager.register_player2(player2)

	player2.global_position = jugador.global_position + Vector2(72, -24)

func _cambiar_zoom(delta_zoom: float) -> void:
	if camara == null:
		push_warning("DebugUnlockUI: camara no asignada.")
		return

	var nuevo_zoom = clamp(camara.zoom.x + delta_zoom, MIN_ZOOM, MAX_ZOOM)
	camara.zoom = Vector2(nuevo_zoom, nuevo_zoom)
	_actualizar_zoom()

func _actualizar_zoom() -> void:
	var zoom_text = "N/A"
	if camara != null:
		zoom_text = str(snapped(camara.zoom.x, 0.01)) + "x"
	var estado = "ON" if control_camara_activo else "OFF"
	zoom_label.text = "Zoom camara: " + zoom_text + " (" + estado + ")"
