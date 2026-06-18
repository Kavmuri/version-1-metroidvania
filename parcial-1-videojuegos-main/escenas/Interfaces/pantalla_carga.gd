extends Node

# ── Ruta de la escena a cargar ────────────────────────
const ESCENA_JUEGO = "res://generacionProcedural/generacion_procedural.tscn"

# ── Colores ───────────────────────────────────────────
const C_FONDO    = Color(0.04, 0.04, 0.08)
const C_TITULO   = Color(0.85, 0.95, 1.00)
const C_BARRA_BG = Color(0.10, 0.10, 0.18)
const C_BARRA_FG = Color(0.25, 0.75, 0.95)
const C_TEXTO    = Color(0.55, 0.65, 0.75)

# ── Estado de carga ───────────────────────────────────
var _progreso: Array = []
var _barra: ColorRect
var _label_estado: Label
var _carga_iniciada: bool = false

# ─────────────────────────────────────────────────────
func _ready() -> void:
	_construir_ui()
	# Esperar un frame para que la UI se renderice antes de empezar la carga
	await get_tree().process_frame
	_iniciar_carga()

func _iniciar_carga() -> void:
	var err = ResourceLoader.load_threaded_request(ESCENA_JUEGO)
	if err != OK:
		push_error("PantallaCarga: no se pudo iniciar la carga de " + ESCENA_JUEGO)
		return
	_carga_iniciada = true

func _process(_delta: float) -> void:
	if not _carga_iniciada:
		return

	var status = ResourceLoader.load_threaded_get_status(ESCENA_JUEGO, _progreso)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var pct = _progreso[0] if _progreso.size() > 0 else 0.0
			_actualizar_barra(pct)
			_label_estado.text = "Cargando...  %d%%" % int(pct * 100)

		ResourceLoader.THREAD_LOAD_LOADED:
			_actualizar_barra(1.0)
			_label_estado.text = "Listo"
			# Pequeña pausa visual antes de cambiar
			await get_tree().create_timer(0.3).timeout
			var escena: PackedScene = ResourceLoader.load_threaded_get(ESCENA_JUEGO)
			get_tree().change_scene_to_packed(escena)

		ResourceLoader.THREAD_LOAD_FAILED:
			_label_estado.text = "Error al cargar la escena."
			push_error("PantallaCarga: fallo al cargar " + ESCENA_JUEGO)

# ─────────────────────────────────────────────────────
func _actualizar_barra(pct: float) -> void:
	var ancho_max = _barra.get_parent().size.x
	_barra.size.x = ancho_max * clampf(pct, 0.0, 1.0)

func _construir_ui() -> void:
	# Fondo
	var fondo = ColorRect.new()
	fondo.color = C_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	# Contenedor central
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	add_child(vbox)

	# Texto "Cargando"
	var titulo = Label.new()
	titulo.text = "Generando el mapa..."
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", C_TITULO)
	vbox.add_child(titulo)

	# Contenedor de la barra de progreso
	var barra_contenedor = Control.new()
	barra_contenedor.custom_minimum_size = Vector2(380, 10)
	vbox.add_child(barra_contenedor)

	# Fondo de la barra
	var barra_bg = ColorRect.new()
	barra_bg.color = C_BARRA_BG
	barra_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	barra_contenedor.add_child(barra_bg)

	# Relleno de la barra (progreso real)
	_barra = ColorRect.new()
	_barra.color = C_BARRA_FG
	_barra.size = Vector2(0, 10)
	barra_contenedor.add_child(_barra)

	# Texto de porcentaje / estado
	_label_estado = Label.new()
	_label_estado.text = "Iniciando..."
	_label_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_estado.add_theme_font_size_override("font_size", 12)
	_label_estado.add_theme_color_override("font_color", C_TEXTO)
	vbox.add_child(_label_estado)

	# Centrar tras un frame
	await get_tree().process_frame
	var vp = get_viewport().get_visible_rect().size
	vbox.position = Vector2(
		(vp.x - vbox.size.x) / 2.0,
		(vp.y - vbox.size.y) / 2.0
	)
