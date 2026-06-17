extends CanvasLayer

# ── Configuración ─────────────────────────────────────
@export var tecla_abrir: String = "ui_cancel"   # Escape por defecto

# ── Estado interno ────────────────────────────────────
var _jugador: CharacterBody2D = null
var _panel: PanelContainer
var _visible_menu: bool = false

# ── Colores del tema ──────────────────────────────────
const C_FONDO       = Color(0.05, 0.05, 0.10, 0.95)
const C_TITULO      = Color(0.90, 0.85, 1.00)
const C_SEPARADOR   = Color(0.30, 0.25, 0.50)
const C_ON          = Color(0.30, 1.00, 0.55)   # verde activo
const C_OFF         = Color(0.50, 0.50, 0.55)   # gris inactivo
const C_BTN_HOVER   = Color(0.20, 0.18, 0.30)

# ─────────────────────────────────────────────────────
func _ready() -> void:
	layer = 10   # encima de todo
	# Seguir procesando input aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_ui()
	_panel.visible = false
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action(tecla_abrir) and event.is_pressed() and not event.is_echo():
		_toggle_menu()

# ─────────────────────────────────────────────────────
func _toggle_menu() -> void:
	_visible_menu = !_visible_menu
	_panel.visible = _visible_menu

	if _visible_menu:
		_buscar_jugador()
		_refrescar_estados()
		# Centrar en el viewport en el momento de abrir (no en _ready)
		var vp = get_viewport().get_visible_rect().size
		_panel.position = Vector2(
			(vp.x - _panel.size.x) / 2.0,
			(vp.y - _panel.size.y) / 2.0
		)
		get_tree().paused = true
	else:
		get_tree().paused = false

func _buscar_jugador() -> void:
	var lista = get_tree().get_nodes_in_group("jugador")
	if lista.size() > 0:
		_jugador = lista[0]
	else:
		push_warning("menu_debug: no se encontró el jugador en grupo 'jugador'.")

# ─────────────────────────────────────────────────────
# ── Construcción de la UI ─────────────────────────────
func _construir_ui() -> void:
	# Fondo semitransparente que bloquea clicks
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Panel central — posición se ajusta al abrir (en _toggle_menu)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 0)

	var estilo = StyleBoxFlat.new()
	estilo.bg_color = C_FONDO
	estilo.border_width_left   = 1
	estilo.border_width_right  = 1
	estilo.border_width_top    = 1
	estilo.border_width_bottom = 1
	estilo.border_color = C_SEPARADOR
	estilo.corner_radius_top_left     = 8
	estilo.corner_radius_top_right    = 8
	estilo.corner_radius_bottom_left  = 8
	estilo.corner_radius_bottom_right = 8
	estilo.content_margin_left   = 24
	estilo.content_margin_right  = 24
	estilo.content_margin_top    = 20
	estilo.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", estilo)
	add_child(_panel)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Título
	vbox.add_child(_label("⚙  MENÚ DE DEPURACIÓN", 15, C_TITULO, true))
	vbox.add_child(_separador())

	# Sección armas
	vbox.add_child(_label("ARMAS", 12, C_SEPARADOR))
	vbox.add_child(_boton_toggle("Punos",   "punos",   _on_arma_presionada))
	vbox.add_child(_boton_toggle("Espada",  "espada",  _on_arma_presionada))
	vbox.add_child(_boton_toggle("Pistola", "pistola", _on_arma_presionada))
	vbox.add_child(_separador())

	# Sección habilidades
	vbox.add_child(_label("HABILIDADES", 12, C_SEPARADOR))
	vbox.add_child(_boton_toggle("Doble Salto  (auto en el aire)", "doble_salto", _on_habilidad_presionada))
	vbox.add_child(_boton_toggle("Salto Alto   (W + Salto)",       "salto_alto",  _on_habilidad_presionada))
	vbox.add_child(_separador())

	# Botón cerrar
	var btn_cerrar = _boton_accion("Cerrar  [ESC]", _on_cerrar)
	vbox.add_child(btn_cerrar)

# ─────────────────────────────────────────────────────
# ── Callbacks de botones ──────────────────────────────

func _on_arma_presionada(tipo: String) -> void:
	if _jugador == null:
		return

	match tipo:
		"punos":
			# Limpiar slots → volver a puños
			_jugador.slots = [null, null]
			_jugador.slot_activo = 0
			_jugador.arma_activa = _jugador.Arma.PUNOS
		"espada":
			_toggle_arma_slot(_jugador.Arma.ESPADA, "espada")
		"pistola":
			_toggle_arma_slot(_jugador.Arma.PISTOLA, "pistola")

	_refrescar_estados()

func _toggle_arma_slot(tipo_arma, tipo_str: String) -> void:
	# Si el arma ya está en algún slot → quitarla; si no → añadirla
	var en_slot = false
	for i in range(_jugador.slots.size()):
		if _jugador.slots[i] == tipo_arma:
			en_slot = true
			_jugador.slots[i] = null
			break

	if not en_slot:
		_jugador.otorgar_arma(tipo_str)

	# Recalcular arma activa
	var arma_en_slot = _jugador.slots[_jugador.slot_activo]
	_jugador.arma_activa = arma_en_slot if arma_en_slot != null else _jugador.Arma.PUNOS

func _on_habilidad_presionada(tipo: String) -> void:
	if _jugador == null:
		return

	match tipo:
		"doble_salto":
			_jugador.tiene_doble_salto = !_jugador.tiene_doble_salto
		"salto_alto":
			_jugador.tiene_salto_alto = !_jugador.tiene_salto_alto

	_refrescar_estados()

func _on_cerrar() -> void:
	_toggle_menu()

# ─────────────────────────────────────────────────────
# ── Refresco visual del estado actual ─────────────────
func _refrescar_estados() -> void:
	if _jugador == null:
		return

	var estados = {
		"punos":       _jugador.arma_activa == _jugador.Arma.PUNOS and _jugador.slots[0] == null and _jugador.slots[1] == null,
		"espada":      _arma_en_slots(_jugador.Arma.ESPADA),
		"pistola":     _arma_en_slots(_jugador.Arma.PISTOLA),
		"doble_salto": _jugador.tiene_doble_salto,
		"salto_alto":  _jugador.tiene_salto_alto,
	}

	_actualizar_botones(estados)

func _arma_en_slots(tipo) -> bool:
	for s in _jugador.slots:
		if s == tipo:
			return true
	return false

func _actualizar_botones(estados: Dictionary) -> void:
	# Recorre todos los botones etiquetados con metadata "id"
	for nodo in _panel.find_children("*", "Button", true, false):
		var btn := nodo as Button
		if btn.has_meta("id"):
			var id: String = btn.get_meta("id")
			if estados.has(id):
				_aplicar_estado_boton(btn, estados[id])

func _aplicar_estado_boton(btn: Button, activo: bool) -> void:
	var estilo_normal = StyleBoxFlat.new()
	estilo_normal.bg_color          = C_ON.darkened(0.5) if activo else Color(0.12, 0.10, 0.18)
	estilo_normal.border_width_left   = 2
	estilo_normal.border_width_right  = 2
	estilo_normal.border_width_top    = 2
	estilo_normal.border_width_bottom = 2
	estilo_normal.border_color        = C_ON if activo else C_SEPARADOR
	estilo_normal.corner_radius_top_left     = 5
	estilo_normal.corner_radius_top_right    = 5
	estilo_normal.corner_radius_bottom_left  = 5
	estilo_normal.corner_radius_bottom_right = 5
	estilo_normal.content_margin_left   = 12
	estilo_normal.content_margin_right  = 12
	estilo_normal.content_margin_top    = 8
	estilo_normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", estilo_normal)

	var estilo_hover = estilo_normal.duplicate()
	estilo_hover.bg_color = C_ON.darkened(0.3) if activo else C_BTN_HOVER
	btn.add_theme_stylebox_override("hover", estilo_hover)

	btn.add_theme_color_override("font_color", C_ON if activo else C_OFF)

# ─────────────────────────────────────────────────────
# ── Helpers de construcción ───────────────────────────
func _label(texto: String, tamaño: int, color: Color, negrita: bool = false) -> Label:
	var l = Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamaño)
	l.add_theme_color_override("font_color", color)
	if negrita:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _separador() -> HSeparator:
	var sep = HSeparator.new()
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = C_SEPARADOR
	sep.add_theme_stylebox_override("separator", estilo)
	return sep

func _boton_toggle(texto: String, id: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.set_meta("id", id)
	btn.focus_mode = Control.FOCUS_NONE

	# Estilo base inactivo
	_aplicar_estado_boton(btn, false)
	btn.add_theme_font_size_override("font_size", 13)

	btn.pressed.connect(func(): callback.call(id))
	return btn

func _boton_accion(texto: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.focus_mode = Control.FOCUS_NONE

	var estilo = StyleBoxFlat.new()
	estilo.bg_color = Color(0.15, 0.10, 0.25)
	estilo.border_width_left   = 1
	estilo.border_width_right  = 1
	estilo.border_width_top    = 1
	estilo.border_width_bottom = 1
	estilo.border_color = C_SEPARADOR
	estilo.corner_radius_top_left     = 5
	estilo.corner_radius_top_right    = 5
	estilo.corner_radius_bottom_left  = 5
	estilo.corner_radius_bottom_right = 5
	estilo.content_margin_left   = 12
	estilo.content_margin_right  = 12
	estilo.content_margin_top    = 8
	estilo.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", estilo)

	var estilo_hover = estilo.duplicate()
	estilo_hover.bg_color = Color(0.25, 0.18, 0.40)
	btn.add_theme_stylebox_override("hover", estilo_hover)
	btn.add_theme_color_override("font_color", C_TITULO)
	btn.add_theme_font_size_override("font_size", 13)

	btn.pressed.connect(callback)
	return btn
