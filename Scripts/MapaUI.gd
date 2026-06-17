extends CanvasLayer

# Referencias que se asignan desde el exterior
var generador: Node2D = null
var jugador: Node2D = null

# Nodos internos creados por código
var _fondo: ColorRect
var _panel: Control
var _dibujo: Control
var _abierto: bool = false

# Tamaño del panel del mapa
const PANEL_W = 700
const PANEL_H = 480
const SCREEN_MARGIN = 24.0
const PADDING = 24.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_construir_ui()

func _construir_ui():
	# Fondo semitransparente que cubre toda la pantalla
	_fondo = ColorRect.new()
	_fondo.color = Color(0, 0, 0, 0.75)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)

	# Panel centrado
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	# Fondo del panel
	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.08, 0.08, 0.12, 0.97)
	var panel_rect = _calcular_panel_rect()
	panel_bg.position = panel_rect.position
	panel_bg.size = panel_rect.size
	_panel.add_child(panel_bg)

	# Borde del panel
	var borde = ReferenceRect.new()
	borde.position = panel_bg.position
	borde.size = panel_bg.size
	borde.border_color = Color(0.4, 0.8, 0.7, 0.8)
	borde.border_width = 2.0
	_panel.add_child(borde)

	# Título
	var titulo = Label.new()
	titulo.text = "MAPA"
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color(0.6, 0.95, 0.85))
	titulo.position = panel_bg.position + Vector2(PADDING, PADDING - 4)
	_panel.add_child(titulo)

	# Instrucción de cierre
	var instruccion = Label.new()
	instruccion.text = "M / TAB — cerrar"
	instruccion.add_theme_font_size_override("font_size", 12)
	instruccion.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	instruccion.position = panel_bg.position + Vector2(panel_bg.size.x - 148, panel_bg.size.y - 28)
	_panel.add_child(instruccion)

	# Control de dibujo del mapa (área interior del panel)
	_dibujo = Control.new()
	_dibujo.position = panel_bg.position + Vector2(PADDING, PADDING + 28)
	_dibujo.size = Vector2(panel_bg.size.x - PADDING * 2, panel_bg.size.y - PADDING * 2 - 28)
	_dibujo.draw.connect(_on_dibujar_mapa)
	_panel.add_child(_dibujo)

func _calcular_panel_rect() -> Rect2:
	var vp_size = get_viewport().get_visible_rect().size
	var panel_size = Vector2(
		min(PANEL_W, max(280.0, vp_size.x - SCREEN_MARGIN * 2.0)),
		min(PANEL_H, max(220.0, vp_size.y - SCREEN_MARGIN * 2.0))
	)
	return Rect2((vp_size - panel_size) * 0.5, panel_size)

func _input(event: InputEvent):
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_M or event.keycode == KEY_TAB:
			if event.pressed:
				_toggle()
			get_viewport().set_input_as_handled()

func _toggle():
	_abierto = !_abierto
	visible = _abierto
	if _abierto:
		_dibujo.queue_redraw()
		get_tree().paused = true   # Pausa el juego mientras el mapa está abierto
	else:
		get_tree().paused = false

func _process(_delta: float):
	# Redibujar cada frame solo si el mapa está abierto (para el punto del jugador)
	if _abierto and jugador != null:
		_dibujo.queue_redraw()

func _on_dibujar_mapa():
	if generador == null:
		return

	var habitaciones = generador.habitaciones_colocadas
	if habitaciones.is_empty():
		return

	# Calcular bounding box del mundo
	var min_x = INF; var min_y = INF
	var max_x = -INF; var max_y = -INF

	for hab in habitaciones:
		var area = _obtener_area(hab)
		if area == Rect2():
			continue
		min_x = min(min_x, area.position.x)
		min_y = min(min_y, area.position.y)
		max_x = max(max_x, area.position.x + area.size.x)
		max_y = max(max_y, area.position.y + area.size.y)

	var mundo_w = max_x - min_x
	var mundo_h = max_y - min_y
	if mundo_w <= 0 or mundo_h <= 0:
		return

	# Escala uniforme para que quepa en el área de dibujo con margen
	var area_w = _dibujo.size.x - 16
	var area_h = _dibujo.size.y - 16
	var escala = min(area_w / mundo_w, area_h / mundo_h)

	# Offset para centrar el mapa en el área de dibujo
	var mapa_w = mundo_w * escala
	var mapa_h = mundo_h * escala
	var mapa_offset = Vector2(
		(area_w - mapa_w) / 2.0 + 8,
		(area_h - mapa_h) / 2.0 + 8
	)

	# Dibujar cada habitación
	for hab in habitaciones:
		var area = _obtener_area(hab)
		if area == Rect2():
			continue

		var rect_mapa = Rect2(
			Vector2(
				(area.position.x - min_x) * escala + mapa_offset.x,
				(area.position.y - min_y) * escala + mapa_offset.y
			),
			Vector2(area.size.x * escala, area.size.y * escala)
		)

		# Relleno de la habitación
		_dibujo.draw_rect(rect_mapa, Color(0.25, 0.35, 0.45, 0.85))
		# Borde de la habitación
		_dibujo.draw_rect(rect_mapa, Color(0.4, 0.75, 0.7, 0.9), false, 1.5)

	# Dibujar posición del jugador
	if jugador != null:
		var jp = jugador.global_position
		var punto = Vector2(
			(jp.x - min_x) * escala + mapa_offset.x,
			(jp.y - min_y) * escala + mapa_offset.y
		)
		# Halo exterior
		_dibujo.draw_circle(punto, 6.0, Color(1.0, 0.85, 0.2, 0.35))
		# Punto sólido
		_dibujo.draw_circle(punto, 4.0, Color(1.0, 0.9, 0.2, 1.0))

func _obtener_area(hab: Node2D) -> Rect2:
	var r = hab.get_node_or_null("ReferenceRect")
	if r == null:
		return Rect2()
	return Rect2(hab.global_position + r.position, r.size)
